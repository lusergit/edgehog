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

defmodule Edgehog.Triggers.IncomingData.Handlers.PublicKeyEvent do
  @moduledoc """
  PublicKey Event handler.
  """
  @behaviour Ash.Astarte.Triggers.HandlerBehavior

  alias Edgehog.Containers
  alias Edgehog.Containers.Calculations.ResourceEvents
  alias Edgehog.Containers.PublicKey.Deployment.Types.Event
  alias Edgehog.Devices
  alias EdgehogWeb.Endpoint

  @impl Ash.Astarte.Triggers.HandlerBehavior
  def handle_event(event, _opts, context) do
    %{realm_id: realm_id, device_id: device_id, timestamp: timestamp, tenant: tenant} = context

    with {:ok, key_id} <- parse_path(event.path),
         {:ok, raw_event} <- parse_value(event.value, timestamp),
         {:ok, device} <- Devices.fetch_device_by_identity(device_id, realm_id, tenant: tenant),
         {:ok, public_key_deployment} <-
           Containers.fetch_public_key_deployment(key_id, device.id, tenant: tenant) do
      payload =
        public_key_deployment
        |> ResourceEvents.cast_event!(raw_event, Event)
        |> Map.put(:__type__, Event.graphql_type([]))

      topic = "#{tenant.tenant_id}:public_key:#{public_key_deployment.id}"

      Absinthe.Subscription.publish(Endpoint, payload, public_key_deployment_events: topic)

      :ok
    end
  end

  defp parse_path(path) when is_binary(path) do
    case String.split(path, "/") do
      ["", key_id] when key_id != "" -> {:ok, key_id}
      _ -> {:error, :invalid_event_path}
    end
  end

  defp parse_path(_), do: {:error, :invalid_event_path}

  defp parse_value(%{"status" => status} = value, timestamp) do
    {:ok,
     %{
       status: status,
       message: Map.get(value, "message", "") || "",
       add_info: Map.get(value, "addInfo", []) || [],
       timestamp: timestamp
     }}
  end

  defp parse_value(_value, _timestamp), do: {:error, :invalid_event_value}
end
