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

defmodule Edgehog.Devices.Device.ManualActions.SendImagePolicy do
  @moduledoc false

  use Ash.Resource.ManualUpdate

  alias Edgehog.Astarte.Device.ImagePolicy, as: AstarteImagePolicy
  alias Edgehog.Astarte.Device.ImagePolicy.RequestData

  @impl Ash.Resource.ManualUpdate
  def update(changeset, _opts, context) do
    device = changeset.data
    tenant = context.tenant

    with {:ok, image_policy} <-
           Ash.Changeset.fetch_argument(changeset, :image_policy, load: :public_key),
         {:ok, key_id} <- extract_key_id(image_policy),
         {:ok, device} <- Ash.load(device, :appengine_client, tenant: tenant) do
      data = %RequestData{
        registry_id: image_policy.registry_id,
        repository: image_policy.repository,
        type: image_policy.type,
        key_id: key_id
      }

      with :ok <- AstarteImagePolicy.set(device.appengine_client, device.device_id, data) do
        {:ok, device}
      end
    end
  end

  defp extract_key_id(%{type: :reject}), do: {:ok, nil}
  defp extract_key_id(%{type: :signed_by, public_key: %{fingerprint: fp}}), do: {:ok, fp}
  defp extract_key_id(%{type: :signed_by}), do: {:error, :public_key_not_found}
end
