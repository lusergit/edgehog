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

defmodule Edgehog.Devices.Device.PublicKeyAndImagePolicyTest do
  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Astarte.Device.AvailableImagePolicies
  alias Edgehog.Astarte.Device.AvailableImagePolicies.ImagePolicyStatus
  alias Edgehog.Astarte.Device.AvailablePublicKeys
  alias Edgehog.Astarte.Device.AvailablePublicKeys.PublicKeyStatus
  alias Edgehog.Astarte.Device.ImagePolicy, as: AstarteImagePolicy
  alias Edgehog.Astarte.Device.ImagePolicy.RequestData
  alias Edgehog.Astarte.Device.PublicKey, as: AstartePublicKey
  alias Edgehog.Containers.PublicKey.Fingerprint
  alias Edgehog.Devices
  alias Edgehog.Error.AstarteAPIError

  setup do
    tenant = tenant_fixture()
    device = device_fixture(tenant: tenant)

    %{tenant: tenant, device: device}
  end

  describe "send_public_key and unset_public_key actions" do
    test "send_public_key sends validated DER bytes with the key fingerprint", %{
      tenant: tenant,
      device: device
    } do
      public_key = public_key_fixture(tenant: tenant)
      {:ok, expected_der} = Fingerprint.der_from_pem(public_key.pem)
      expected_device_id = device.device_id
      expected_fp = public_key.fingerprint

      expect(AstartePublicKey, :set, fn _client,
                                        ^expected_device_id,
                                        ^expected_fp,
                                        ^expected_der ->
        :ok
      end)

      assert {:ok, updated_device} = Devices.send_public_key(device, public_key, tenant: tenant)
      assert updated_device.id == device.id
    end

    test "send_public_key propagates Astarte errors", %{tenant: tenant, device: device} do
      public_key = public_key_fixture(tenant: tenant)

      expect(AstartePublicKey, :set, fn _client, _device_id, _fp, _der ->
        {:error, %AstarteAPIError{status: 500, response: "boom"}}
      end)

      assert {:error, _error} = Devices.send_public_key(device, public_key, tenant: tenant)
    end

    test "unset_public_key unsets the key property by key_id", %{tenant: tenant, device: device} do
      expected_device_id = device.device_id
      key_id = String.duplicate("a", 64)

      expect(AstartePublicKey, :unset, fn _client, ^expected_device_id, ^key_id ->
        :ok
      end)

      assert {:ok, updated_device} = Devices.unset_public_key(device, key_id, tenant: tenant)
      assert updated_device.id == device.id
    end
  end

  describe "send_image_policy and unset_image_policy actions" do
    test "send_image_policy sends a :reject policy with nil key_id", %{
      tenant: tenant,
      device: device
    } do
      policy = image_policy_fixture(tenant: tenant, repository: "docker.io", type: :reject)
      expected_device_id = device.device_id

      expect(AstarteImagePolicy, :set, fn _client, ^expected_device_id, %RequestData{} = data ->
        assert data.registry_id == policy.registry_id
        assert data.repository == "docker.io"
        assert data.type == :reject
        assert is_nil(data.key_id)
        :ok
      end)

      assert {:ok, updated_device} = Devices.send_image_policy(device, policy, tenant: tenant)
      assert updated_device.id == device.id
    end

    test "send_image_policy loads public_key and sends its fingerprint for :signed_by", %{
      tenant: tenant,
      device: device
    } do
      public_key = public_key_fixture(tenant: tenant)

      policy =
        image_policy_fixture(
          tenant: tenant,
          repository: "quay.io/my-org",
          type: :signed_by,
          public_key_id: public_key.id
        )

      expected_device_id = device.device_id
      expected_fp = public_key.fingerprint

      expect(AstarteImagePolicy, :set, fn _client, ^expected_device_id, %RequestData{} = data ->
        assert data.registry_id == policy.registry_id
        assert data.repository == "quay.io/my-org"
        assert data.type == :signed_by
        assert data.key_id == expected_fp
        :ok
      end)

      assert {:ok, _device} = Devices.send_image_policy(device, policy, tenant: tenant)
    end

    test "unset_image_policy forwards unset_key_id? option with default false", %{
      tenant: tenant,
      device: device
    } do
      expected_device_id = device.device_id
      registry_id = String.duplicate("b", 64)

      expect(AstarteImagePolicy, :unset, fn _client,
                                            ^expected_device_id,
                                            ^registry_id,
                                            [unset_key_id?: false] ->
        :ok
      end)

      assert {:ok, _device} = Devices.unset_image_policy(device, registry_id, tenant: tenant)

      expect(AstarteImagePolicy, :unset, fn _client,
                                            ^expected_device_id,
                                            ^registry_id,
                                            [unset_key_id?: true] ->
        :ok
      end)

      assert {:ok, _device} =
               Devices.unset_image_policy(device, registry_id, %{unset_key_id?: true},
                 tenant: tenant
               )
    end
  end

  describe "available_public_keys and available_image_policies calculations" do
    test "loads available_public_keys and available_image_policies and returns nil on error", %{
      tenant: tenant,
      device: device
    } do
      expected_device_id = device.device_id

      expect(AvailablePublicKeys, :get, fn _client, ^expected_device_id ->
        {:ok, [%PublicKeyStatus{id: "fp-1", status: :present}]}
      end)

      expect(AvailableImagePolicies, :get, fn _client, ^expected_device_id ->
        {:ok, [%ImagePolicyStatus{id: "reg-1", status: :missing}]}
      end)

      loaded =
        Ash.load!(device, [:available_public_keys, :available_image_policies], tenant: tenant)

      assert loaded.available_public_keys == [%PublicKeyStatus{id: "fp-1", status: :present}]

      assert loaded.available_image_policies == [
               %ImagePolicyStatus{id: "reg-1", status: :missing}
             ]

      expect(AvailablePublicKeys, :get, fn _client, ^expected_device_id ->
        {:error, :timeout}
      end)

      expect(AvailableImagePolicies, :get, fn _client, ^expected_device_id ->
        {:error, :timeout}
      end)

      errored =
        Ash.load!(device, [:available_public_keys, :available_image_policies], tenant: tenant)

      assert is_nil(errored.available_public_keys)
      assert is_nil(errored.available_image_policies)
    end

    test "resolves availablePublicKeys and availableImagePolicies in GraphQL with camelized statuses",
         %{tenant: tenant, device: device} do
      expected_device_id = device.device_id

      expect(AvailablePublicKeys, :get, fn _client, ^expected_device_id ->
        {:ok,
         [
           %PublicKeyStatus{id: "fp-1", status: :present},
           %PublicKeyStatus{id: "fp-2", status: nil}
         ]}
      end)

      expect(AvailableImagePolicies, :get, fn _client, ^expected_device_id ->
        {:ok,
         [
           %ImagePolicyStatus{id: "reg-1", status: :missing},
           %ImagePolicyStatus{id: "reg-2", status: :error}
         ]}
      end)

      document = """
      query DeviceKeyAndPolicyStatus($id: ID!) {
        device(id: $id) {
          availablePublicKeys {
            id
            status
          }
          availableImagePolicies {
            id
            status
          }
        }
      }
      """

      relay_id = AshGraphql.Resource.encode_relay_id(device)

      result =
        Absinthe.run!(document, EdgehogWeb.Schema,
          variables: %{"id" => relay_id},
          context: %{tenant: tenant, actor: %{}}
        )

      refute :errors in Map.keys(result)

      assert %{
               data: %{
                 "device" => %{
                   "availablePublicKeys" => [
                     %{"id" => "fp-1", "status" => "Present"},
                     %{"id" => "fp-2", "status" => nil}
                   ],
                   "availableImagePolicies" => [
                     %{"id" => "reg-1", "status" => "Missing"},
                     %{"id" => "reg-2", "status" => "Error"}
                   ]
                 }
               }
             } = result
    end
  end
end
