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

defmodule Edgehog.Containers.PublicKey.Deployment.Provisioner.CoreTest do
  @moduledoc """
  Tests for the public key deployment provisioner Core.
  """

  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Astarte.Device.AvailablePublicKeys
  alias Edgehog.Astarte.Device.AvailablePublicKeys.PublicKeyStatus
  alias Edgehog.Astarte.Device.PublicKey, as: AstartePublicKey
  alias Edgehog.Containers
  alias Edgehog.Containers.PublicKey.Deployment.Provisioner.Core
  alias Edgehog.Containers.PublicKey.Fingerprint

  describe "PublicKey deployment provisioner Core" do
    setup do
      tenant = tenant_fixture()
      public_key = public_key_fixture(tenant: tenant)
      device = device_fixture(tenant: tenant)

      {:ok, deployment} = Containers.deploy_public_key(public_key, device, tenant: tenant)

      %{
        tenant: tenant,
        public_key: public_key,
        device: device,
        deployment: deployment
      }
    end

    test "ready?/1 returns true only for :present and :missing" do
      assert Core.ready?(%{state: :present})
      assert Core.ready?(%{state: :missing})

      refute Core.ready?(%{state: :created})
      refute Core.ready?(%{state: :sent})
      refute Core.ready?(%{state: :error})
    end

    test "topic/1, subscribe_topic/1, and name/1 return expected identifiers" do
      assert Core.topic(%{id: "pk-dep-1"}) == "ready:public_key_deployments:pk-dep-1"
      assert Core.topic("pk-dep-1") == "ready:public_key_deployments:pk-dep-1"

      assert Core.subscribe_topic(%{id: "pk-dep-1"}) == "public_key_deployments:pk-dep-1"
      assert Core.subscribe_topic("pk-dep-1") == "public_key_deployments:pk-dep-1"

      assert Core.name(%{id: "pk-dep-1"}) ==
               {:via, Registry,
                {Edgehog.Containers.PublicKey.Deployment.Provisioner.Registry, "pk-dep-1"}}
    end

    test "send_to_device/2 sends the public key DER bytes to the device", %{
      tenant: tenant,
      public_key: public_key,
      device: device,
      deployment: deployment
    } do
      {:ok, expected_der} = Fingerprint.der_from_pem(public_key.pem)
      expected_device_id = device.device_id
      expected_fp = public_key.fingerprint

      expect(AstartePublicKey, :set, fn _client,
                                        ^expected_device_id,
                                        ^expected_fp,
                                        ^expected_der ->
        :ok
      end)

      assert :ok == Core.send_to_device(deployment, tenant: tenant)
    end

    test "send_to_device/2 returns :public_key_not_found for device-only deployments", %{
      tenant: tenant,
      device: device
    } do
      unknown_fp = String.duplicate("a", 64)

      deployment =
        public_key_deployment_fixture(
          tenant: tenant,
          device_id: device.id,
          public_key_fingerprint: unknown_fp
        )

      reject(AstartePublicKey, :set, 4)

      assert {:error, :public_key_not_found} == Core.send_to_device(deployment, tenant: tenant)
    end

    test "reconcile/2 updates state for :present, :missing, and first :error transition", %{
      tenant: tenant,
      public_key: public_key,
      deployment: deployment
    } do
      for {status, expected_state} <- [
            {:present, :present},
            {:missing, :missing},
            {:error, :error}
          ] do
        expect(AvailablePublicKeys, :get, fn _client, _device_id ->
          {:ok, [%PublicKeyStatus{id: public_key.fingerprint, status: status}]}
        end)

        assert {:ok, updated} = Core.reconcile(deployment, tenant: tenant)
        assert updated.id == deployment.id
        assert updated.state == expected_state
      end
    end

    test "reconcile/2 returns :not_found when already :error, when status is nil, missing, or Astarte fails",
         %{tenant: tenant, public_key: public_key, deployment: deployment} do
      {:ok, errored_deployment} =
        deployment
        |> Ash.Changeset.for_update(:set_state, %{state: :error})
        |> Ash.update(tenant: tenant)

      expect(AvailablePublicKeys, :get, fn _client, _device_id ->
        {:ok, [%PublicKeyStatus{id: public_key.fingerprint, status: :error}]}
      end)

      assert :not_found == Core.reconcile(errored_deployment, tenant: tenant)

      expect(AvailablePublicKeys, :get, fn _client, _device_id ->
        {:ok, [%PublicKeyStatus{id: public_key.fingerprint, status: nil}]}
      end)

      assert :not_found == Core.reconcile(deployment, tenant: tenant)

      expect(AvailablePublicKeys, :get, fn _client, _device_id ->
        {:ok, []}
      end)

      assert :not_found == Core.reconcile(deployment, tenant: tenant)

      expect(AvailablePublicKeys, :get, fn _client, _device_id ->
        {:error, :timeout}
      end)

      assert :not_found == Core.reconcile(deployment, tenant: tenant)
    end

    test "temporary_error?/1 classifies transient and permanent errors" do
      assert Core.temporary_error?("connection refused")
      assert Core.temporary_error?({:error, %Edgehog.Error.DeviceOffline{}})
      assert Core.temporary_error?(%Edgehog.Error.AstarteAPIError{status: 503})
      refute Core.temporary_error?({:error, :public_key_not_found})
      refute Core.temporary_error?(%Edgehog.Error.AstarteAPIError{status: 400})
    end
  end
end
