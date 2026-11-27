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

defmodule Edgehog.Astarte.Device.AvailablePublicKeysTest do
  use Edgehog.DataCase, async: true

  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures
  import Tesla.Mock

  alias Astarte.Client.APIError
  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.AvailablePublicKeys
  alias Edgehog.Astarte.Device.AvailablePublicKeys.PublicKeyStatus

  setup do
    tenant = tenant_fixture()
    cluster = cluster_fixture()
    realm = realm_fixture(cluster_id: cluster.id, tenant: tenant)
    device = device_fixture(realm_id: realm.id, tenant: tenant)

    {:ok, appengine_client} =
      AppEngine.new(cluster.base_api_url, realm.name, private_key: realm.private_key)

    {:ok, device: device, appengine_client: appengine_client}
  end

  test "get/2 parses Present, Missing, Error, unknown, and absent statuses", %{
    device: device,
    appengine_client: client
  } do
    response = %{
      "data" => %{
        "fp1" => %{"status" => "Present"},
        "fp2" => %{"status" => "Missing"},
        "fp3" => %{"status" => "Error"},
        "fp4" => %{"status" => "Static"},
        "fp5" => %{}
      }
    }

    mock(fn %{method: :get, url: url} ->
      assert String.ends_with?(
               url,
               "/devices/#{device.device_id}/interfaces/io.edgehog.devicemanager.apps.AvailablePublicKeys"
             )

      json(response)
    end)

    assert {:ok, keys} = AvailablePublicKeys.get(client, device.device_id)

    assert Enum.sort_by(keys, & &1.id) == [
             %PublicKeyStatus{id: "fp1", status: :present},
             %PublicKeyStatus{id: "fp2", status: :missing},
             %PublicKeyStatus{id: "fp3", status: :error},
             %PublicKeyStatus{id: "fp4", status: nil},
             %PublicKeyStatus{id: "fp5", status: nil}
           ]
  end

  test "get/2 returns empty list when no properties are set and propagates API errors", %{
    device: device,
    appengine_client: client
  } do
    mock(fn %{method: :get} -> json(%{"data" => %{}}) end)
    assert {:ok, []} = AvailablePublicKeys.get(client, device.device_id)

    mock(fn %{method: :get} -> json(%{"errors" => %{}}, status: 404) end)
    assert {:error, %APIError{status: 404}} = AvailablePublicKeys.get(client, device.device_id)
  end
end
