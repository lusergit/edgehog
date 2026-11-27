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

defmodule Edgehog.Astarte.Device.ImagePolicyTest do
  use Edgehog.DataCase, async: true

  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures
  import Tesla.Mock

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.ImagePolicy
  alias Edgehog.Astarte.Device.ImagePolicy.RequestData
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

  describe "set/3" do
    test "sets repository and type for :reject policy without writing keyId", %{
      device: device,
      appengine_client: client
    } do
      parent = self()

      mock(fn %{method: :put, url: url, body: body} ->
        send(parent, {:put, url, Jason.decode!(body)})
        json(%{}, status: 200)
      end)

      data = %RequestData{
        registry_id: "reg-1",
        repository: "docker.io",
        type: :reject
      }

      assert :ok = ImagePolicy.set(client, device.device_id, data)

      assert_received {:put, url1, %{"data" => "docker.io"}}

      assert String.ends_with?(
               url1,
               "/io.edgehog.devicemanager.apps.ImagePolicy/policy/reg-1/repository"
             )

      assert_received {:put, url2, %{"data" => "Reject"}}

      assert String.ends_with?(
               url2,
               "/io.edgehog.devicemanager.apps.ImagePolicy/policy/reg-1/type"
             )

      refute_received {:put, _, _}
    end

    test "sets repository, keyId, and type in order for :signed_by policy", %{
      device: device,
      appengine_client: client
    } do
      parent = self()

      mock(fn %{method: :put, url: url, body: body} ->
        send(parent, {:put, url, Jason.decode!(body)})
        json(%{}, status: 200)
      end)

      data = %RequestData{
        registry_id: "reg-2",
        repository: "quay.io/my-org",
        type: :signed_by,
        key_id: "key-fp-123"
      }

      assert :ok = ImagePolicy.set(client, device.device_id, data)

      assert_received {:put, url1, %{"data" => "quay.io/my-org"}}
      assert String.ends_with?(url1, "/policy/reg-2/repository")

      assert_received {:put, url2, %{"data" => "key-fp-123"}}
      assert String.ends_with?(url2, "/policy/reg-2/keyId")

      assert_received {:put, url3, %{"data" => "SignedBy"}}
      assert String.ends_with?(url3, "/policy/reg-2/type")
    end

    test "rejects :signed_by with missing or empty key_id before issuing any HTTP requests", %{
      device: device,
      appengine_client: client
    } do
      parent = self()

      mock(fn env ->
        send(parent, {:http, env})
        json(%{}, status: 200)
      end)

      for invalid_key_id <- [nil, ""] do
        data = %RequestData{
          registry_id: "reg-3",
          repository: "quay.io/my-org",
          type: :signed_by,
          key_id: invalid_key_id
        }

        assert {:error, :missing_key_id} = ImagePolicy.set(client, device.device_id, data)
      end

      refute_received {:http, _}
    end

    test "short-circuits and translates errors mid-sequence", %{
      device: device,
      appengine_client: client
    } do
      parent = self()

      mock(fn %{method: :put, url: url} ->
        send(parent, {:put, url})

        if String.ends_with?(url, "/keyId") do
          json(%{"errors" => %{"detail" => "server error"}}, status: 500)
        else
          json(%{}, status: 200)
        end
      end)

      data = %RequestData{
        registry_id: "reg-4",
        repository: "quay.io/my-org",
        type: :signed_by,
        key_id: "key-fp"
      }

      assert {:error,
              %AstarteAPIError{
                status: 500,
                interface: "io.edgehog.devicemanager.apps.ImagePolicy"
              }} = ImagePolicy.set(client, device.device_id, data)

      assert_received {:put, url1}
      assert String.ends_with?(url1, "/repository")
      assert_received {:put, url2}
      assert String.ends_with?(url2, "/keyId")
      refute_received {:put, _}
    end
  end

  describe "unset/4" do
    test "unsets type and repository by default, and optionally keyId", %{
      device: device,
      appengine_client: client
    } do
      parent = self()

      mock(fn %{method: :delete, url: url} ->
        send(parent, {:delete, url})
        %Tesla.Env{status: 204, body: ""}
      end)

      assert :ok = ImagePolicy.unset(client, device.device_id, "reg-1")
      assert_received {:delete, url1}
      assert String.ends_with?(url1, "/policy/reg-1/type")
      assert_received {:delete, url2}
      assert String.ends_with?(url2, "/policy/reg-1/repository")
      refute_received {:delete, _}

      assert :ok = ImagePolicy.unset(client, device.device_id, "reg-2", unset_key_id?: true)
      assert_received {:delete, url3}
      assert String.ends_with?(url3, "/policy/reg-2/type")
      assert_received {:delete, url4}
      assert String.ends_with?(url4, "/policy/reg-2/repository")
      assert_received {:delete, url5}
      assert String.ends_with?(url5, "/policy/reg-2/keyId")
    end

    test "maps 404 to DeviceOffline on unset", %{device: device, appengine_client: client} do
      mock(fn %{method: :delete} -> json(%{"errors" => %{}}, status: 404) end)

      assert {:error, %DeviceOffline{interface: "io.edgehog.devicemanager.apps.ImagePolicy"}} =
               ImagePolicy.unset(client, device.device_id, "reg-1")
    end
  end
end
