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

defmodule Edgehog.Containers.Deployment.Starter do
  @moduledoc """
  Deployments starter.

  This server can be started when a device goes online. It will load all the
  pending deployments of such device and start them trough the `Supervisor`.
  """

  use GenServer, restart: :transient

  require Logger

  # the state struct, we can reference it with the %Data{} struct
  defstruct [
    :device,
    :tenant,
    :mode,
    :deployments
  ]

  alias __MODULE__, as: Data
  alias Edgehog.Containers.Deployment.Starter.Core

  @impl GenServer
  def init(args) do
    device = Keyword.fetch!(args, :device)
    tenant = Keyword.fetch!(args, :tenant)

    mode = Keyword.get(args, :mode, :auto)

    state = %Data{
      device: device,
      tenant: tenant,
      mode: mode
    }

    {:ok, state, {:continue, :load_pending_deployments}}
  end

  @impl GenServer
  def handle_continue(:load_pending_deployments, state) do
    state
    |> Core.load()
    |> maybe_next(state, :start_deployments)
  end

  @impl GenServer
  def handle_continue(:start_deployments, state) do
    state
    |> Core.start()
    |> maybe_terminate(state, :normal)
  end

  @impl GenServer
  def terminate(:normal, state) do
    %{device: %{device_id: device_id}} = state

    Logger.info("""
    Successfully started provisioning of all pending deployments on device #{device_id}
    """)
  end

  @impl GenServer
  def terminate({:shutdown, error}, state) do
    error = with {:error, error} <- error, do: error

    Logger.error("""
    Unexpected error while starting deployments: #{inspect(error)}. Shutting down the starter
    """)
  end

  @impl GenServer
  def terminate(reason, state) do
    %{device: %{device_id: device_id}} = state
     
    Logger.debug("""
    Terminating deployments starter server for device #{device_id} with reason #{inspect(reason)}.
    """)
  end


  defp maybe_shutdown({:ok, new_state}, _old_state, next_state) do
    {:noreply, new_state, {:continue, next_state}}
  end

  defp maybe_shutdown(error, state, _next_state) do
    {:stop, state, {:shutdown, error}}
  end

  defp maybe_terminate({:ok, new_state}, _old_state, reason) do
    {:stop, reason, new_state}
  end

  defp maybe_terminate(error, state, _reason) do
    {:stop, state, {:shutdown, error}}
  end
end
