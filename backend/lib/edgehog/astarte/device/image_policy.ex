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

defmodule Edgehog.Astarte.Device.ImagePolicy do
  @moduledoc false
  @behaviour Edgehog.Astarte.Device.ImagePolicy.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.ImagePolicy.RequestData
  alias Edgehog.Error

  @interface "io.edgehog.devicemanager.apps.ImagePolicy"

  @impl Edgehog.Astarte.Device.ImagePolicy.Behaviour
  def set(%AppEngine{} = client, device_id, %RequestData{} = data) when is_binary(device_id) do
    with {:ok, encoded_type} <- encode_type(data.type),
         :ok <- validate_key_id(data),
         :ok <-
           set_property(
             client,
             device_id,
             "/policy/#{data.registry_id}/repository",
             data.repository
           ),
         :ok <- maybe_set_key_id(client, device_id, data) do
      set_property(client, device_id, "/policy/#{data.registry_id}/type", encoded_type)
    end
  end

  @impl Edgehog.Astarte.Device.ImagePolicy.Behaviour
  def unset(%AppEngine{} = client, device_id, registry_id, opts \\ [])
      when is_binary(device_id) and is_binary(registry_id) do
    unset_key_id? = Keyword.get(opts, :unset_key_id?, false)

    with :ok <- unset_property(client, device_id, "/policy/#{registry_id}/type"),
         :ok <- unset_property(client, device_id, "/policy/#{registry_id}/repository") do
      maybe_unset_key_id(client, device_id, registry_id, unset_key_id?)
    end
  end

  defp encode_type(:reject), do: {:ok, "Reject"}
  defp encode_type(:signed_by), do: {:ok, "SignedBy"}
  defp encode_type(_), do: {:error, :invalid_policy_type}

  defp validate_key_id(%RequestData{type: :signed_by, key_id: key_id})
       when is_binary(key_id) and key_id != "",
       do: :ok

  defp validate_key_id(%RequestData{type: :signed_by}), do: {:error, :missing_key_id}
  defp validate_key_id(%RequestData{type: :reject}), do: :ok

  defp maybe_set_key_id(client, device_id, %RequestData{
         type: :signed_by,
         registry_id: registry_id,
         key_id: key_id
       }) do
    set_property(client, device_id, "/policy/#{registry_id}/keyId", key_id)
  end

  defp maybe_set_key_id(_client, _device_id, _data), do: :ok

  defp maybe_unset_key_id(client, device_id, registry_id, true) do
    unset_property(client, device_id, "/policy/#{registry_id}/keyId")
  end

  defp maybe_unset_key_id(_client, _device_id, _registry_id, false), do: :ok

  defp set_property(client, device_id, path, value) do
    client
    |> AppEngine.Devices.set_property(device_id, @interface, path, value)
    |> Error.maybe_match_error(device_id, @interface)
  end

  defp unset_property(client, device_id, path) do
    client
    |> AppEngine.Devices.unset_property(device_id, @interface, path)
    |> Error.maybe_match_error(device_id, @interface)
  end
end
