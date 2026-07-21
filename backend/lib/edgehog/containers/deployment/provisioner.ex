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

defmodule Edgehog.Containers.Deployment.Provisioner do
  @moduledoc """
  Service to provision a given deployment.
  """

  use GenServer, restart: :transient

  alias Deployment.Provisioner.Registry, as: ProvisionerRegistry
  alias Edgehog.Containers.Deployment
  alias Edgehog.Containers.Deployment.Provisioner.Core

  require Logger

  @test Mix.env() == :test
  @deployment_ready_states [:started, :stopped]

  # API

  def provision(deployment, tenant, opts \\ []) do
    opts
    |> Keyword.put(:deployment, deployment)
    |> Keyword.put(:tenant, tenant)
    |> start_link()
  end

  def start_link(args) do
    deployment = Keyword.fetch!(args, :deployment)

    GenServer.start_link(__MODULE__, args, name: name(deployment))
  end

  @doc """
  Returns the readiness topic the provisioner will publish onto when the resource
  is ready.

  it accepts either an entire %Edgehog.Containers.Deployment{} resource, or just
  an ID.
  """
  def topic(%Deployment{id: id}), do: "deployments:provisioning:#{id}"
  def topic(id), do: "deployments:provisioning:#{id}"

  def name(%Deployment{id: id}) do
    {:via, Registry, {ProvisionerRegistry, id}}
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

  @impl GenServer
  def init(args) do
    deployment = Keyword.fetch!(args, :deployment)
    tenant = Keyword.fetch!(args, :tenant)

    mode = Keyword.get(args, :mode, :auto)

    %{id: id} = deployment

    state = %{
      deployment: deployment,
      tenant: tenant,
      state: :init,
      mode: mode,
      retries: 0
    }

    Logger.info("Starting the provisioner for deployment #{id}")
    Phoenix.PubSub.subscribe(Edgehog.PubSub, "deployments:#{id}")

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
  def handle_continue(
        :check_deployment_state,
        %{deployment: deployment} = state
      ) do
    deployment =
      Ash.load!(deployment, :is_ready, tenant: deployment.tenant_id)

    if deployment.is_ready do
      new_state = Map.put(state, :deployment, deployment)
      {:stop, :normal, new_state}
    else
      {:noreply, state, {:continue, :send}}
    end
  end

  @impl GenServer
  def handle_continue(:send, old_state) do
    %{
      deployment: deployment,
      tenant: tenant
    } = old_state

    sent = Core.send(deployment, tenant: tenant)

    new_state = Map.put(old_state, :state, :sent)

    case sent do
      :ok -> {:noreply, new_state}
      error -> retry_or_stop(error, old_state)
    end
  end

  @impl GenServer
  def handle_continue(:maybe_ready, state) do
    %{deployment: deployment} = state

    # Here we have to compute readiness of the single `deployment` resource. We
    # cannot delegate this to the `is_ready` calculation as it computes global
    # readiness for the public.
    if ready?(deployment),
      do: {:stop, :normal, state},
      else: {:noreply, state}
  end

  # We were not able to send the message to the device. retry
  @impl GenServer
  def handle_info(:timeout, %{state: :init} = old_state) do
    %{
      deployment: deployment,
      tenant: tenant
    } = old_state

    sent = Core.send(deployment, tenant: tenant, deployment: deployment)

    new_state = Map.put(old_state, :state, :sent)

    case sent do
      :ok -> {:noreply, new_state}
      error -> retry_or_stop(error, old_state)
    end
  end

  # We get the deployment from the broadcast, which is in the :payload -> :data
  # section. This deployment is more recent, as it comes from an update in the
  # database.
  @impl GenServer
  def handle_info(%Phoenix.Socket.Broadcast{payload: %{data: deployment}}, state) do
    new_state = Map.put(state, :deployment, deployment)

    # Somewhere the has been marked in some state (pulled/unpulled). For
    # now we can just shutdown gracefully
    {:noreply, new_state, {:continue, :maybe_ready}}
  end

  # NOTICE: we crash on messages that do not come from the notification system for the correct topic

  @impl GenServer
  def terminate(:normal, state) do
    %{
      deployment: deployment,
      retries: retries
    } = state

    %{id: id} = deployment

    topic = topic(deployment)

    # Broadcast readiness
    Phoenix.PubSub.broadcast(Edgehog.PubSub, topic, {:ready, deployment})

    # Log
    Logger.info("""
    Deployment #{id} successfully provisioned after #{retries} retries.
    """)

    # Unsubscribe from events, we're terminating
    Phoenix.PubSub.unsubscribe(Edgehog.PubSub, "deployments:#{id}")
  end

  defp retry_or_stop(error, state) do
    %{deployment: %{id: id}} = state

    error = with {:error, error} <- error, do: error

    retries = Map.fetch!(state, :retries)
    max_retries = Application.get_env(:edgehog, :max_deployment_retries, 100)

    if retries > max_retries do
      {:stop, {:shutdown, :max_retries}, state}
    else
      timeout = timeout(state)
      timeout_seconds = round(timeout / 1000)

      Logger.error("""
      An error occurred while sending the deployment #{id}:
      #{inspect(error)}

      Retrying in #{timeout_seconds} seconds.
      """)

      {:noreply, increase_retries(state), timeout}
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

  defp ready?(deployment) do
    %{state: state} = deployment

    state in @deployment_ready_states
  end
end
