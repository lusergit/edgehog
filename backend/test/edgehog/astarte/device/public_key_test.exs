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

defmodule Edgehog.Astarte.Device.PublicKeyTest do
  use Edgehog.DataCase, async: true

  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures
  import Tesla.Mock

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.PublicKey
  alias Edgehog.Error.AstarteAPIError
  alias Edgehog.Error.DeviceOffline

  setup do
    tenant = tenant_fixture()
    cluster = cluster_fixture()
    realm = realm_fixture(cluster_id: cluster.id, tenant: tenant)
    device = device_fixture(realm_id: realm.id, tenant: tenant)

    {:ok, appengine_client} =
      AppEngine.new(cluster.base_api_url, realm.name, private_key: realm.private_key)

    {:ok, device: device, appengine_client: appengine_client}
  end

  describe "set/4" do
    test "sends base64-encoded DER bytes to /image/signing/:key_id", %{
      device: device,
      appengine_client: client
    } do
      key_id = String.duplicate("a", 64)
      der_bytes = <<48, 130, 1, 10, 2, 1, 0>>
      expected_payload = Jason.encode!(%{data: Base.encode64(der_bytes)})

      mock(fn %{method: :put, url: url, body: body} ->
        assert String.ends_with?(
                 url,
                 "/devices/#{device.device_id}/interfaces/io.edgehog.devicemanager.PublicKey/image/signing/#{key_id}"
               )

        assert body == expected_payload
        json(%{}, status: 200)
      end)

      assert :ok = PublicKey.set(client, device.device_id, key_id, der_bytes)
    end

    test "maps 404 to DeviceOffline and 500 to AstarteAPIError", %{
      device: device,
      appengine_client: client
    } do
      mock(fn %{method: :put} -> json(%{"errors" => %{"detail" => "not found"}}, status: 404) end)

      assert {:error, %DeviceOffline{interface: "io.edgehog.devicemanager.PublicKey"}} =
               PublicKey.set(client, device.device_id, "key-1", <<1, 2, 3>>)

      mock(fn %{method: :put} -> json(%{"errors" => %{"detail" => "boom"}}, status: 500) end)

      assert {:error,
              %AstarteAPIError{status: 500, interface: "io.edgehog.devicemanager.PublicKey"}} =
               PublicKey.set(client, device.device_id, "key-1", <<1, 2, 3>>)
    end
  end

  describe "unset/3" do
    test "deletes /image/signing/:key_id property", %{
      device: device,
      appengine_client: client
    } do
      key_id = String.duplicate("b", 64)

      mock(fn %{method: :delete, url: url} ->
        assert String.ends_with?(
                 url,
                 "/devices/#{device.device_id}/interfaces/io.edgehog.devicemanager.PublicKey/image/signing/#{key_id}"
               )

        %Tesla.Env{status: 204, body: ""}
      end)

      assert :ok = PublicKey.unset(client, device.device_id, key_id)
    end

    test "maps API errors on unset", %{device: device, appengine_client: client} do
      mock(fn %{method: :delete} -> json(%{"errors" => %{}}, status: 404) end)

      assert {:error, %DeviceOffline{interface: "io.edgehog.devicemanager.PublicKey"}} =
               PublicKey.unset(client, device.device_id, "key-1")
    end
  end
end
