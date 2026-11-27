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

defmodule Edgehog.Containers.PublicKeyTest do
  use Edgehog.DataCase, async: true
  use Mimic

  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Astarte.Device.ResourceEvent
  alias Edgehog.Containers
  alias Edgehog.Containers.PublicKey

  setup do
    %{tenant: tenant_fixture()}
  end

  describe "PublicKey" do
    test "creates a public key and derives its fingerprint from the X.509 PEM", %{tenant: tenant} do
      pem = x509_certificate_pem_fixture()
      {:ok, expected_fingerprint} = PublicKey.Fingerprint.from_pem(pem)

      assert {:ok, public_key} =
               Ash.create(
                 PublicKey,
                 %{label: "signing-cert-1", pem: pem},
                 tenant: tenant
               )

      assert public_key.label == "signing-cert-1"
      assert public_key.pem == String.trim(pem)
      assert public_key.fingerprint == expected_fingerprint
    end

    test "rejects invalid PEM certificates", %{tenant: tenant} do
      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               Ash.create(
                 PublicKey,
                 %{label: "invalid-cert", pem: "not-a-cert"},
                 tenant: tenant
               )

      assert Enum.any?(errors, &(&1.field == :pem))
    end

    test "enforces unique label and fingerprint within a tenant", %{tenant: tenant} do
      pem = x509_certificate_pem_fixture()
      _existing = public_key_fixture(tenant: tenant, label: "shared-label", pem: pem)

      assert {:error, %Ash.Error.Invalid{}} =
               Ash.create(
                 PublicKey,
                 %{label: "shared-label", pem: x509_certificate_pem_fixture()},
                 tenant: tenant
               )

      assert {:error, %Ash.Error.Invalid{}} =
               Ash.create(
                 PublicKey,
                 %{label: "another-label", pem: pem},
                 tenant: tenant
               )
    end

    test "allows multiple tenants to define the same certificate and label", %{tenant: tenant_a} do
      tenant_b = tenant_fixture()
      pem = x509_certificate_pem_fixture()

      key_a = public_key_fixture(tenant: tenant_a, label: "vendor-key", pem: pem)
      key_b = public_key_fixture(tenant: tenant_b, label: "vendor-key", pem: pem)

      assert key_a.fingerprint == key_b.fingerprint
      assert key_a.id != key_b.id
    end
  end

  describe "PublicKey.Deployment" do
    test "deploy creates a deployment linked to the cloud public key and device", %{
      tenant: tenant
    } do
      public_key = public_key_fixture(tenant: tenant)
      device = device_fixture(tenant: tenant)

      assert {:ok, deployment} =
               Containers.deploy_public_key(public_key, device, tenant: tenant)

      assert deployment.public_key_fingerprint == public_key.fingerprint
      assert deployment.device_id == device.id
      assert deployment.state == :created

      loaded = Ash.load!(deployment, [:public_key, :device, :is_ready], tenant: tenant)
      assert loaded.public_key.id == public_key.id
      assert loaded.device.id == device.id
      refute loaded.is_ready
    end

    test "supports device-reported unknown fingerprints and links automatically when key is added",
         %{tenant: tenant} do
      device = device_fixture(tenant: tenant)
      pem = x509_certificate_pem_fixture()
      {:ok, fingerprint} = PublicKey.Fingerprint.from_pem(pem)

      assert {:ok, deployment} =
               Containers.upsert_public_key_deployment_from_device(
                 %{
                   public_key_fingerprint: fingerprint,
                   device_id: device.id,
                   state: :present
                 },
                 tenant: tenant
               )

      loaded_before = Ash.load!(deployment, [:public_key, :is_ready], tenant: tenant)
      assert is_nil(loaded_before.public_key)
      assert loaded_before.is_ready

      # Later defining the PublicKey in the cloud automatically resolves the relationship
      public_key = public_key_fixture(tenant: tenant, pem: pem)

      loaded_after = Ash.load!(deployment, [:public_key], tenant: tenant)
      assert loaded_after.public_key.id == public_key.id

      loaded_key = Ash.load!(public_key, [:public_key_deployments, :devices], tenant: tenant)
      assert Enum.map(loaded_key.public_key_deployments, & &1.id) == [deployment.id]
      assert Enum.map(loaded_key.devices, & &1.id) == [device.id]
    end

    test "upsert_from_device updates state on an existing deployment", %{tenant: tenant} do
      public_key = public_key_fixture(tenant: tenant)
      device = device_fixture(tenant: tenant)
      {:ok, deployment} = Containers.deploy_public_key(public_key, device, tenant: tenant)

      assert {:ok, updated} =
               Containers.upsert_public_key_deployment_from_device(
                 %{
                   public_key_fingerprint: public_key.fingerprint,
                   device_id: device.id,
                   state: :present
                 },
                 tenant: tenant
               )

      assert updated.id == deployment.id
      assert updated.state == :present
    end

    test "state transition actions update state, last_message, and is_ready", %{tenant: tenant} do
      deployment = public_key_deployment_fixture(tenant: tenant)
      refute Ash.load!(deployment, [:is_ready], tenant: tenant).is_ready

      assert {:ok, sent} =
               Containers.mark_public_key_deployment_as_sent(deployment, tenant: tenant)

      assert sent.state == :sent
      refute Ash.load!(sent, [:is_ready], tenant: tenant).is_ready

      assert {:ok, present} =
               Containers.mark_public_key_deployment_as_present(sent, tenant: tenant)

      assert present.state == :present
      assert Ash.load!(present, [:is_ready], tenant: tenant).is_ready

      assert {:ok, missing} =
               Containers.mark_public_key_deployment_as_missing(present, tenant: tenant)

      assert missing.state == :missing
      assert Ash.load!(missing, [:is_ready], tenant: tenant).is_ready

      assert {:ok, errored} =
               Containers.mark_public_key_deployment_as_errored(missing, "disk full",
                 tenant: tenant
               )

      assert errored.state == :error
      assert errored.last_message == "disk full"
      refute Ash.load!(errored, [:is_ready], tenant: tenant).is_ready
    end

    test "loads events from PublicKeyEvent Astarte interface using fingerprint as resource_id", %{
      tenant: tenant
    } do
      device = device_fixture(tenant: tenant)
      public_key = public_key_fixture(tenant: tenant)

      deployment =
        public_key_deployment_fixture(
          tenant: tenant,
          device_id: device.id,
          public_key_fingerprint: public_key.fingerprint
        )

      device_id = device.device_id
      fingerprint = public_key.fingerprint
      timestamp = ~U[2026-11-27 10:00:00Z]

      expect(ResourceEvent, :get, fn _client,
                                     ^device_id,
                                     "io.edgehog.devicemanager.apps.PublicKeyEvent",
                                     ^fingerprint,
                                     [] ->
        {:ok,
         [
           %ResourceEvent.Data{
             status: "Created",
             message: "Key installed",
             add_info: ["x509"],
             timestamp: timestamp
           }
         ]}
      end)

      loaded = Ash.load!(deployment, [:events], tenant: tenant)
      relay_id = AshGraphql.Resource.encode_relay_id(deployment)

      assert [
               %{
                 resource_id: ^relay_id,
                 status: :created,
                 message: "Key installed",
                 add_info: ["x509"],
                 timestamp: ^timestamp
               }
             ] = loaded.events
    end

    test "isolates public_key, public_key_deployments, and devices across tenants sharing a fingerprint",
         %{tenant: tenant_a} do
      tenant_b = tenant_fixture()
      pem = x509_certificate_pem_fixture()

      key_a = public_key_fixture(tenant: tenant_a, pem: pem)
      key_b = public_key_fixture(tenant: tenant_b, pem: pem)
      device_a = device_fixture(tenant: tenant_a)

      assert {:ok, deployment_a} =
               Containers.deploy_public_key(key_a, device_a, tenant: tenant_a)

      loaded_deployment_a = Ash.load!(deployment_a, [:public_key], tenant: tenant_a)
      assert loaded_deployment_a.public_key.id == key_a.id

      loaded_key_a = Ash.load!(key_a, [:public_key_deployments, :devices], tenant: tenant_a)
      assert Enum.map(loaded_key_a.public_key_deployments, & &1.id) == [deployment_a.id]
      assert Enum.map(loaded_key_a.devices, & &1.id) == [device_a.id]

      loaded_key_b = Ash.load!(key_b, [:public_key_deployments, :devices], tenant: tenant_b)
      assert loaded_key_b.public_key_deployments == []
      assert loaded_key_b.devices == []
    end
  end
end
