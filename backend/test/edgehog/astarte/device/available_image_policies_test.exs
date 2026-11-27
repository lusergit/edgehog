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

defmodule Edgehog.Astarte.Device.AvailableImagePoliciesTest do
  use Edgehog.DataCase, async: true

  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures
  import Tesla.Mock

  alias Astarte.Client.APIError
  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.AvailableImagePolicies
  alias Edgehog.Astarte.Device.AvailableImagePolicies.ImagePolicyStatus

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
        "reg1" => %{"status" => "Present"},
        "reg2" => %{"status" => "Missing"},
        "reg3" => %{"status" => "Error"},
        "reg4" => %{"status" => "Static"},
        "reg5" => %{}
      }
    }

    mock(fn %{method: :get, url: url} ->
      assert String.ends_with?(
               url,
               "/devices/#{device.device_id}/interfaces/io.edgehog.devicemanager.apps.AvailableImagePolicies"
             )

      json(response)
    end)

    assert {:ok, policies} = AvailableImagePolicies.get(client, device.device_id)

    assert Enum.sort_by(policies, & &1.id) == [
             %ImagePolicyStatus{id: "reg1", status: :present},
             %ImagePolicyStatus{id: "reg2", status: :missing},
             %ImagePolicyStatus{id: "reg3", status: :error},
             %ImagePolicyStatus{id: "reg4", status: nil},
             %ImagePolicyStatus{id: "reg5", status: nil}
           ]
  end

  test "get/2 returns empty list when no properties are set and propagates API errors", %{
    device: device,
    appengine_client: client
  } do
    mock(fn %{method: :get} -> json(%{"data" => %{}}) end)
    assert {:ok, []} = AvailableImagePolicies.get(client, device.device_id)

    mock(fn %{method: :get} -> json(%{"errors" => %{}}, status: 404) end)
    assert {:error, %APIError{status: 404}} = AvailableImagePolicies.get(client, device.device_id)
  end
end
