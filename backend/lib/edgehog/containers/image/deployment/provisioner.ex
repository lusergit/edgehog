#
# This file is part of Edgehog.
#
# Copyright 2026 SECO Mind Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0
#

defmodule Edgehog.Containers.Image.Deployment.Provisioner do
  @moduledoc """
  A image deployment provisioner.

  Each and every time an image should be deployed, it can be done trough this
  provisioner. The provisioner sends the appropriate messages to the device and
  emits a `ready:image_deployments:id` event whenever image is present in the
  device.

  The provisioning flow can be described as follows:

  - start_link/1 called, init the process
  - The server subscribes to events on 'image_deployments:id' (id of the image
    deployment)
  - Core.send/2 is called, sending the appropriate messages to the device (see
    Core.send/1 docs for more info)

  Nice flow (everything goes ok)
  - Astarte triggers update the image deployment state, marking it as present or
    not present and emitting an event on the correct topic
  - The server reacts to the event, handles the message and emits an event on
    'ready:image_deployment:id' when the resource is ready
  - listening processes can react to this information

  Timeouts (something goes wrong)
  - Core.send/2 failed, maybe the device is offline, or there was some problem
    with astarte
  - an exponential backoff timeout is started
  - A :timeout hits the server, it retries to send the image information to the
    device

  TODOs, shortcomigs:
  The logic to handle send succeeding but no message coming back from astarte is
  not there yet
  """

  use GenServer, restart: :transient

  alias Edgehog.Containers.Image.Deployment
  alias Edgehog.Containers.Image.Deployment.Provisioner.Core

  require Logger

  @test Mix.env() == :test

  # API

  def provision(image_deployment, deployment, tenant, opts \\ []) do
    opts
    |> Keyword.put(:image_deployment, image_deployment)
    |> Keyword.put(:deployment, deployment)
    |> Keyword.put(:tenant, tenant)
    |> start_link()
  end

  def start_link(args) do
    image_deployment = Keyword.fetch!(args, :image_deployment)

    GenServer.start_link(__MODULE__, args, name: name(image_deployment))
  end

  def name(%Deployment{id: id}) do
    {:via, Registry, {Image.Deployment.Provisioner.Registry, id}}
  end

  # Test additional API
  # In test environment, allow to start the process with a message, so that the
  # test process can attach and monitor it
  if @test do
    def start(provisioner) do
      GenServer.cast(provisioner, :start)
    end

    @impl GenServer
    def handle_cast(:start, state) do
      {:noreply, state, {:continue, :check_deployment_state}}
    end
  end

  # Callbacks

  @impl GenServer
  def init(args) do
    image_deployment = Keyword.fetch!(args, :image_deployment)
    deployment = Keyword.fetch!(args, :deployment)
    tenant = Keyword.fetch!(args, :tenant)

    mode = Keyword.get(args, :mode, :auto)

    state = %{
      image_deployment: image_deployment,
      deployment: deployment,
      tenant: tenant,
      state: :init,
      mode: mode,
      retries: 0
    }

    %{id: id} = image_deployment

    Logger.info("Subscribing to events on image deployment #{id}")
    Phoenix.PubSub.subscribe(Edgehog.PubSub, "image_deployments:#{id}")

    {:ok, state, {:continue, :maybe_send}}
  end

  @impl GenServer
  def handle_continue(:maybe_send, %{mode: :auto} = state) do
    {:noreply, state, {:continue, :check_deployment_state}}
  end

  @impl GenServer
  def handle_continue(:maybe_send, %{mode: :manual} = state) do
    {:noreply, state}
  end

  @impl GenServer
  def handle_continue(:check_deployment_state, %{image_deployment: image_deployment} = state) do
    image_deployment = Ash.load!(image_deployment, :is_ready, tenant: image_deployment.tenant_id)

    if image_deployment.is_ready do
      new_state = Map.put(state, :image_deployment, image_deployment)
      {:stop, :normal, new_state}
    else
      {:noreply, state, {:continue, :send}}
    end
  end

  @impl GenServer
  def handle_continue(:send, old_state) do
    %{
      image_deployment: image_deployment,
      deployment: deployment,
      tenant: tenant
    } = old_state

    sent = Core.send(image_deployment, tenant: tenant, deployment: deployment)

    new_state = Map.put(old_state, :state, :sent)

    case sent do
      :ok -> {:noreply, new_state}
      error -> retry_or_stop(error, old_state)
    end
  end

  # We were not able to send the message to the device. retry
  @impl GenServer
  def handle_info(:timeout, %{state: :init} = old_state) do
    %{
      image_deployment: image_deployment,
      deployment: deployment,
      tenant: tenant
    } = old_state

    sent = Core.send(image_deployment, tenant: tenant, deployment: deployment)

    new_state = Map.put(old_state, :state, :sent)

    case sent do
      :ok -> {:noreply, new_state}
      error -> retry_or_stop(error, old_state)
    end
  end

  # We get the image deployment from the broadcast, which is in the :payload ->
  # :data section. This image deployment is more recent, as it comes from an
  # update in the database.
  @impl GenServer
  def handle_info(%Phoenix.Socket.Broadcast{payload: %{data: image_deployment}}, state) do
    # We can publish on readiness topic.
    id = image_deployment.id

    Phoenix.PubSub.broadcast(
      Edgehog.PubSub,
      "ready:image_deployments:#{id}",
      {:ready, image_deployment}
    )

    new_state = Map.put(state, :image_deployment, image_deployment)

    # Somewhere the image has been marked in some state (pulled/unpulled). For
    # now we can just shutdown gracefully
    {:stop, :normal, new_state}
  end

  # NOTICE: we crash on messages that do not come from the notification system for the correct topic

  @impl GenServer
  def terminate(:normal, state) do
    %{
      image_deployment: %{id: id},
      retries: retries
    } = state

    Logger.info("""
    Image deployment #{id} successfully provisioned after #{retries} retries.
    """)

    # Unsubscribe from events, we're terminating
    Phoenix.PubSub.unsubscribe(Edgehog.PubSub, "image_deployments:#{id}")
  end

  defp retry_or_stop(error, state) do
    %{image_deployment: %{id: id}} = state

    error = with {:error, error} <- error, do: error

    retries = Map.fetch!(state, :retries)
    max_retries = Application.get_env(:edgehog, :max_image_deployment_retries, 100)

    if retries < max_retries do
      timeout = timeout(state)
      timeout_seconds = round(timeout / 1000)

      Logger.error("""
      An error occurred while sending the image deployment #{id}:
      #{inspect(error)}

      Retrying in #{timeout_seconds} seconds.
      """)

      {:noreply, increase_retries(state), timeout}
    else
      {:stop, {:shutdown, :max_retries}, state}
    end
  end

  defp increase_retries(state) do
    Map.update!(state, :retries, &Kernel.+(&1, 1))
  end

  # Exponential backoff timeout
  defp timeout(state) do
    retries = Map.fetch!(state, :retries)

    random_n = Enum.random(0..1000)
    timeout = :math.pow(2, retries) + random_n
    max_timeout = to_timeout(day: 1)

    timeout
    |> min(max_timeout)
    |> round()
  end
end
