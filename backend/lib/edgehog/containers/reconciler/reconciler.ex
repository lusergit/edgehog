#
# This file is part of Edgehog.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Edgehog.Containers.Reconciler do
  @moduledoc """
  Reconciler for container-related data between the device and the backend.

  When a device connects a timeout gets set up: after a configurable amount of
  time the reconciler goes trough all the data published by the device and
  reconciles the state of the backend with the state of the astarte messages.

  This is useful for a couple of reasons: the backend might have missed some
  messages in trigger handling, the device might have not re-published some
  property, not triggering a trigger and so on.

  This process ensures that the state of the device is eventually consistent
  with astarte state.
  """

  use GenServer

  alias Edgehog.Containers.Reconciler.Core
  alias Edgehog.Containers.Reconciler.Devices

  require Ash.Query
  require Logger

  defstruct [
    :device_id
  ]

  # 10s
  @reconcile_timeout 10 * 1000

  # APIs
  def start_link(args) do
    case Keyword.fetch(args, :device_id) do
      {:ok, device_id} ->
        name = {:via, Registry, {Devices, device_id}}
        GenServer.start_link(__MODULE__, args, name: name)

      :error ->
        {:error, :device_id_not_found}
    end
  end

  def stop(device_id) do
    name = {:via, Registry, {Devices, device_id}}

    GenServer.cast(name, :stop)
  end

  def register_device(device) do
    device_id = device.id

    if Edgehog.Devices.Device
       |> Ash.Query.filter(id == ^device_id)
       |> Ash.exists?(tenant: device.tenant_id),
       do: start_link(device_id: device_id, tenant: device.tenant_id),
       else: {:error, :device_not_found}
  end

  # Callbacks

  @impl GenServer
  def init(args) do
    state = Map.new(args)

    {:ok, state, @reconcile_timeout}
  end

  @impl GenServer
  def handle_cast(:stop, state) do
    device_id = Map.get(state, :device_id)
    Logger.info("Stopping server for device #{device_id}")
    Core.reconcile(device_id)

    {:stop, :normal}
  end

  @impl GenServer
  def handle_info(:timeout, state) do
    res =
      state
      |> Map.get(:device_id, nil)
      |> Core.reconcile()

    case res do
      :ok -> {:noreply, state, @reconcile_timeout}
      :not_found -> {:stop, :normal}
    end
  end
end
