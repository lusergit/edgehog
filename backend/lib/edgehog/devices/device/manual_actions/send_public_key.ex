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

defmodule Edgehog.Devices.Device.ManualActions.SendPublicKey do
  @moduledoc false

  use Ash.Resource.ManualUpdate

  alias Edgehog.Astarte.Device.PublicKey, as: AstartePublicKey
  alias Edgehog.Containers.PublicKey.Fingerprint

  @impl Ash.Resource.ManualUpdate
  def update(changeset, _opts, context) do
    device = changeset.data
    tenant = context.tenant

    with {:ok, public_key} <- Ash.Changeset.fetch_argument(changeset, :public_key),
         {:ok, der_bytes} <- Fingerprint.der_from_pem(public_key.pem),
         {:ok, device} <- Ash.load(device, :appengine_client, tenant: tenant),
         :ok <-
           AstartePublicKey.set(
             device.appengine_client,
             device.device_id,
             public_key.fingerprint,
             der_bytes
           ) do
      {:ok, device}
    end
  end
end
