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

defmodule Edgehog.Triggers.IncomingData.Handlers.AvailablePublicKeys do
  @moduledoc """
  Available PublicKeys handler.
  """
  @behaviour Ash.Astarte.Triggers.HandlerBehavior

  alias Edgehog.Containers
  alias Edgehog.Devices

  @impl Ash.Astarte.Triggers.HandlerBehavior
  def handle_event(event, _opts, context) do
    %{realm_id: realm_id, device_id: device_id, tenant: tenant} = context

    with {:ok, key_id} <- parse_path(event.path),
         {:ok, device} <- Devices.fetch_device_by_identity(device_id, realm_id, tenant: tenant) do
      handle_status(key_id, event.value, device.id, tenant)
    end
  end

  defp parse_path(path) when is_binary(path) do
    case String.split(path, "/") do
      ["", key_id, "status"] when key_id != "" -> {:ok, key_id}
      _ -> {:error, :invalid_event_path}
    end
  end

  defp parse_path(_), do: {:error, :invalid_event_path}

  defp handle_status(key_id, nil, device_id, tenant) do
    case Containers.fetch_public_key_deployment(key_id, device_id, tenant: tenant) do
      {:ok, deployment} ->
        with :ok <- Containers.destroy_public_key_deployment(deployment, tenant: tenant) do
          {:ok, deployment}
        end

      {:error, _reason} ->
        :ok
    end
  end

  defp handle_status(key_id, value, device_id, tenant) do
    with {:ok, state} <- parse_status(value) do
      Containers.upsert_public_key_deployment_from_device(
        %{
          public_key_fingerprint: key_id,
          device_id: device_id,
          state: state
        },
        tenant: tenant
      )
    end
  end

  defp parse_status("Present"), do: {:ok, :present}
  defp parse_status("Missing"), do: {:ok, :missing}
  defp parse_status("Error"), do: {:ok, :error}
  defp parse_status(_), do: {:error, :invalid_status}
end
