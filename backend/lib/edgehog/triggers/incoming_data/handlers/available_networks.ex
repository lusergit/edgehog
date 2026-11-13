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

defmodule Edgehog.Triggers.IncomingData.Handlers.AvailableNetworks do
  @moduledoc """
  Available Images handler
  """
  @behaviour Ash.Astarte.Triggers.HandlerBehavior

  alias Edgehog.Containers
  alias Edgehog.Devices

  @impl Ash.Astarte.Triggers.HandlerBehavior
  def handle_event(event, _opts, context) do
    %{realm_id: realm_id, device_id: device_id, tenant: tenant} = context

    with {:ok, device} <- Devices.fetch_device_by_identity(device_id, realm_id, tenant: tenant) do
      case String.split(event.path, "/") do
        ["", network_id, "created"] ->
          handle_created(network_id, event.value, device.id, tenant)

        _ ->
          {:error, :invalid_event_path}
      end
    end
  end

  defp handle_created(network_id, value, device_id, tenant) do
    with {:ok, network_deployment} <-
           Containers.fetch_network_deployment(network_id, device_id, tenant: tenant) do
      update_network_deployment(network_deployment, value, tenant)
    end
  end

  defp update_network_deployment(network_deployment, true, tenant) do
    Containers.mark_network_deployment_as_available(network_deployment, tenant: tenant)
  end

  defp update_network_deployment(network_deployment, false, tenant) do
    Containers.mark_network_deployment_as_unavailable(network_deployment, tenant: tenant)
  end

  defp update_network_deployment(network_deployment, nil, tenant) do
    with :ok <- Containers.destroy_network_deployment(network_deployment, tenant: tenant) do
      {:ok, network_deployment}
    end
  end
end
