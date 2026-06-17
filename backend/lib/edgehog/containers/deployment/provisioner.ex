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
  Deployment Provisioner.

  This server (spawned when creating a deployment) is resposible to orchestrate
  the connection with the device and update the deployment state, keeping track
  of the state and readiness of resources and logging errors, handling retry
  mechanisms and so on.
  """

  use GenServer, restart: :transient

  @backoff_timeout to_timeout(minute: 5)

  # APIs

  @doc """
  Starts the provisioning of a given deployment.

  Practically speaking, spawns a `GenServer` that tracks all the necessary resources and handle
  device's communication state, handling retries if necessary and so on.

  `opts` should include accepted opts (see ...).

  Required opts:
  - tenant :: the tenant for which the deployment is being provisioned
  """
  def provision(deployment, opts) do
    opts
    |> Keyword.put(:deployment, deployment)
    |> start_link()
  end

  def start_link(opts) do
    deployment = Keyword.fetch!(opts, :deployment)

    GenServer.start_link(__MODULE__, opts, name: name(deployment))
  end

  def name(%Edgehog.Containers.Deployment{id: id}) do
    {:via, Edgehog.Containers.Deployment.Provisioner.Registry, id}
  end

  @impl GenServer
  def init(opts) do
    tenant = Keyword.fetch!(opts, :tenant)
    deployment = Keyword.fetch!(opts, :deployment)

    state = %{
      tenant: tenant,
      deployment: deployment,
      init: false
    }

    {:ok, state, {:continue, :compute_resources}}
  end

  @impl GenServer
  def handle_continue(:compute_resources, state) do
    %{
      deployment: %{id: id},
      tenant: %{slug: slug}
    } = state

    timeout = @backoff_timeout

    case Core.load_resources(state) do
      {:ok, new_state} ->
        {:noreply, new_state, {:continue, :send_resources}}

      {:error, error} ->
        Logger.warning("""
        We could not provision the necessary resources to deploy deployment #{id} for tenant #{slug}.
        Retrying in #{timeout} seconds.
        """)

        {:noreply, state, timeout}
    end
  end

  def handle_continue(:send_resources, state) do
    %{
      deployment: %{id: id},
      tenant: %{slug: slug}
    } = state

    timeout = @backoff_timeout

    case Core.send_resources(state) do
      {:ok, new_state} ->
        {:noreply, new_state, {:continue, :send_resources}}

      {:error, error} ->
        Logger.warning("""
        We could not provision the necessary resources to deploy deployment #{id} for tenant #{slug}.
        Retrying in #{timeout} seconds.
        """)

        {:noreply, state, timeout}
    end
  end

  @impl GenServer
  def handle_info(:timeout, %{init: false}) do
    timeout = @backoff_timeout

    case Core.load_resources(state) do
      {:ok, new_state} ->
        {:noreply, new_state, {:continue, :send_resources}}

      {:error, error} ->
        Logger.warning("""
        We could not provision the necessary resources to deploy deployment #{id} for tenant #{slug}.
        Retrying in #{timeout} seconds.
        """)

        {:noreply, state, timeout}
    end
  end

  @impl GenServer
  def handle_info(:timeout, %{}) do
  end
end
