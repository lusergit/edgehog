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

defmodule Edgehog.Containers.ImagePolicyTest do
  use Edgehog.DataCase, async: true
  use Mimic

  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Astarte.Device.ResourceEvent
  alias Edgehog.Containers
  alias Edgehog.Containers.ImagePolicy
  alias Edgehog.Containers.ImagePolicy.RegistryId

  setup do
    %{tenant: tenant_fixture()}
  end

  describe "ImagePolicy" do
    test "creates a reject policy and derives registry_id from repository", %{tenant: tenant} do
      assert {:ok, policy} =
               Ash.create(
                 ImagePolicy,
                 %{repository: "docker.io", type: :reject},
                 tenant: tenant
               )

      assert policy.repository == "docker.io"
      assert policy.registry_id == RegistryId.compute("docker.io")
      assert policy.type == :reject
      assert is_nil(policy.public_key_id)
    end

    test "creates a signed_by policy referencing a public key", %{tenant: tenant} do
      public_key = public_key_fixture(tenant: tenant)

      assert {:ok, policy} =
               Ash.create(
                 ImagePolicy,
                 %{
                   repository: "registry.example.com:5000/team/app",
                   type: :signed_by,
                   public_key_id: public_key.id
                 },
                 tenant: tenant
               )

      assert policy.repository == "registry.example.com:5000/team/app"
      assert policy.registry_id == RegistryId.compute("registry.example.com:5000/team/app")
      assert policy.type == :signed_by
      assert policy.public_key_id == public_key.id

      loaded = Ash.load!(policy, [:public_key], tenant: tenant)
      assert loaded.public_key.id == public_key.id
    end

    test "requires public_key_id when type is signed_by", %{tenant: tenant} do
      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               Ash.create(
                 ImagePolicy,
                 %{repository: "quay.io/my-org", type: :signed_by},
                 tenant: tenant
               )

      assert Enum.any?(errors, fn
               %{field: :public_key_id} -> true
               %{fields: fields} -> :public_key_id in fields
               _ -> false
             end)
    end

    test "forbids public_key_id when type is reject", %{tenant: tenant} do
      public_key = public_key_fixture(tenant: tenant)

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               Ash.create(
                 ImagePolicy,
                 %{
                   repository: "quay.io/my-org",
                   type: :reject,
                   public_key_id: public_key.id
                 },
                 tenant: tenant
               )

      assert Enum.any?(errors, fn
               %{field: :public_key_id} -> true
               %{fields: fields} -> :public_key_id in fields
               _ -> false
             end)
    end

    test "validates repository scope formats", %{tenant: tenant} do
      for valid_repo <- [
            "docker.io",
            "quay.io/my-org",
            "registry.example.com:5000/team/app",
            "127.0.0.1:5000/my_repo/sub.app",
            "[::1]:5000/team",
            "[2001:db8::1]"
          ] do
        assert {:ok, _policy} =
                 Ash.create(
                   ImagePolicy,
                   %{repository: valid_repo, type: :reject},
                   tenant: tenant
                 )
      end

      for invalid_repo <- [
            "",
            "/docker.io",
            "docker.io/",
            "docker.io//library",
            "docker.io/Library",
            "docker.io/library/nginx:latest",
            "docker.io/library/nginx@sha256:abcdef",
            "docker.io:0/library",
            "docker.io:0080/library",
            "docker.io:+5000/library",
            "docker.io:70000/library",
            "[127.0.0.1]/library",
            "[127.0.0.1]:5000/library",
            "010.0.0.1/library",
            "127.0.0.9999/library",
            "12345/library",
            "not a host/repo"
          ] do
        assert {:error, %Ash.Error.Invalid{}} =
                 Ash.create(
                   ImagePolicy,
                   %{repository: invalid_repo, type: :reject},
                   tenant: tenant
                 )
      end

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               Ash.create(
                 ImagePolicy,
                 %{repository: nil, type: :reject},
                 tenant: tenant
               )

      repository_errors = Enum.filter(errors, &(&1.field == :repository))
      assert length(repository_errors) == 1
    end

    test "rejects creating a signed_by policy referencing another tenant's public key", %{
      tenant: tenant_a
    } do
      tenant_b = tenant_fixture()
      other_public_key = public_key_fixture(tenant: tenant_b)

      assert {:error, %Ash.Error.Invalid{}} =
               Ash.create(
                 ImagePolicy,
                 %{
                   repository: "quay.io/cross-tenant",
                   type: :signed_by,
                   public_key_id: other_public_key.id
                 },
                 tenant: tenant_a
               )
    end

    test "enforces unique repository within a tenant but allows same repository across tenants",
         %{
           tenant: tenant_a
         } do
      tenant_b = tenant_fixture()

      policy_a = image_policy_fixture(tenant: tenant_a, repository: "docker.io", type: :reject)

      assert {:error, %Ash.Error.Invalid{}} =
               Ash.create(
                 ImagePolicy,
                 %{repository: "docker.io", type: :reject},
                 tenant: tenant_a
               )

      policy_b = image_policy_fixture(tenant: tenant_b, repository: "docker.io", type: :reject)
      assert policy_a.registry_id == policy_b.registry_id
      assert policy_a.id != policy_b.id
    end

    test "prevents deleting a public key referenced by an image policy", %{tenant: tenant} do
      public_key = public_key_fixture(tenant: tenant)

      _policy =
        image_policy_fixture(
          tenant: tenant,
          type: :signed_by,
          public_key_id: public_key.id
        )

      assert {:error, %Ash.Error.Invalid{}} =
               Containers.destroy_public_key(public_key, tenant: tenant)
    end

    test "allows deleting a tenant that owns a public key referenced by a signed_by policy" do
      ephemeral_tenant = tenant_fixture()
      public_key = public_key_fixture(tenant: ephemeral_tenant)

      _policy =
        image_policy_fixture(
          tenant: ephemeral_tenant,
          type: :signed_by,
          public_key_id: public_key.id
        )

      assert :ok = Ash.destroy(ephemeral_tenant, action: :destroy)
    end
  end

  describe "ImagePolicy.Deployment" do
    test "deploy creates a deployment linked to the cloud image policy and device", %{
      tenant: tenant
    } do
      policy = image_policy_fixture(tenant: tenant)
      device = device_fixture(tenant: tenant)

      assert {:ok, deployment} =
               Containers.deploy_image_policy(policy, device, tenant: tenant)

      assert deployment.registry_id == policy.registry_id
      assert deployment.device_id == device.id
      assert deployment.state == :created

      loaded = Ash.load!(deployment, [:image_policy, :device, :is_ready], tenant: tenant)
      assert loaded.image_policy.id == policy.id
      assert loaded.device.id == device.id
      refute loaded.is_ready
    end

    test "supports device-reported unknown registry_id and links automatically when policy is added",
         %{tenant: tenant} do
      device = device_fixture(tenant: tenant)
      repository = "quay.io/unmanaged"
      registry_id = RegistryId.compute(repository)

      assert {:ok, deployment} =
               Containers.upsert_image_policy_deployment_from_device(
                 %{
                   registry_id: registry_id,
                   device_id: device.id,
                   state: :present
                 },
                 tenant: tenant
               )

      loaded_before = Ash.load!(deployment, [:image_policy, :is_ready], tenant: tenant)
      assert is_nil(loaded_before.image_policy)
      assert loaded_before.is_ready

      policy = image_policy_fixture(tenant: tenant, repository: repository, type: :reject)

      loaded_after = Ash.load!(deployment, [:image_policy], tenant: tenant)
      assert loaded_after.image_policy.id == policy.id

      loaded_policy = Ash.load!(policy, [:image_policy_deployments, :devices], tenant: tenant)
      assert Enum.map(loaded_policy.image_policy_deployments, & &1.id) == [deployment.id]
      assert Enum.map(loaded_policy.devices, & &1.id) == [device.id]
    end

    test "state transition actions update state, last_message, and is_ready", %{tenant: tenant} do
      deployment = image_policy_deployment_fixture(tenant: tenant)
      refute Ash.load!(deployment, [:is_ready], tenant: tenant).is_ready

      assert {:ok, sent} =
               Containers.mark_image_policy_deployment_as_sent(deployment, tenant: tenant)

      assert sent.state == :sent
      refute Ash.load!(sent, [:is_ready], tenant: tenant).is_ready

      assert {:ok, present} =
               Containers.mark_image_policy_deployment_as_present(sent, tenant: tenant)

      assert present.state == :present
      assert Ash.load!(present, [:is_ready], tenant: tenant).is_ready

      assert {:ok, missing} =
               Containers.mark_image_policy_deployment_as_missing(present, tenant: tenant)

      assert missing.state == :missing
      assert Ash.load!(missing, [:is_ready], tenant: tenant).is_ready

      assert {:ok, errored} =
               Containers.mark_image_policy_deployment_as_errored(missing, "policy write failed",
                 tenant: tenant
               )

      assert errored.state == :error
      assert errored.last_message == "policy write failed"
      refute Ash.load!(errored, [:is_ready], tenant: tenant).is_ready
    end

    test "loads events from ImagePolicyEvent Astarte interface using registry_id", %{
      tenant: tenant
    } do
      device = device_fixture(tenant: tenant)
      policy = image_policy_fixture(tenant: tenant)

      deployment =
        image_policy_deployment_fixture(
          tenant: tenant,
          device_id: device.id,
          registry_id: policy.registry_id
        )

      device_id = device.device_id
      registry_id = policy.registry_id
      timestamp = ~U[2026-11-27 10:05:00Z]

      expect(ResourceEvent, :get, fn _client,
                                     ^device_id,
                                     "io.edgehog.devicemanager.apps.ImagePolicyEvent",
                                     ^registry_id,
                                     [] ->
        {:ok,
         [
           %ResourceEvent.Data{
             status: "Created",
             message: "Policy applied",
             add_info: ["type=Reject"],
             timestamp: timestamp
           },
           %ResourceEvent.Data{
             status: "Removed",
             message: "Policy removed",
             add_info: [],
             timestamp: ~U[2026-11-27 10:06:00Z]
           }
         ]}
      end)

      loaded = Ash.load!(deployment, [:events], tenant: tenant)
      relay_id = AshGraphql.Resource.encode_relay_id(deployment)

      assert [
               %{
                 resource_id: ^relay_id,
                 status: :created,
                 message: "Policy applied",
                 add_info: ["type=Reject"],
                 timestamp: ^timestamp
               },
               %{
                 resource_id: ^relay_id,
                 status: :removed,
                 message: "Policy removed",
                 add_info: [],
                 timestamp: ~U[2026-11-27 10:06:00Z]
               }
             ] = loaded.events
    end

    test "isolates image_policy, image_policy_deployments, and devices across tenants sharing a repository",
         %{tenant: tenant_a} do
      tenant_b = tenant_fixture()
      repository = "quay.io/shared-org/app"

      policy_a = image_policy_fixture(tenant: tenant_a, repository: repository, type: :reject)
      policy_b = image_policy_fixture(tenant: tenant_b, repository: repository, type: :reject)
      device_a = device_fixture(tenant: tenant_a)

      assert {:ok, deployment_a} =
               Containers.deploy_image_policy(policy_a, device_a, tenant: tenant_a)

      loaded_deployment_a = Ash.load!(deployment_a, [:image_policy], tenant: tenant_a)
      assert loaded_deployment_a.image_policy.id == policy_a.id

      loaded_policy_a =
        Ash.load!(policy_a, [:image_policy_deployments, :devices], tenant: tenant_a)

      assert Enum.map(loaded_policy_a.image_policy_deployments, & &1.id) == [deployment_a.id]
      assert Enum.map(loaded_policy_a.devices, & &1.id) == [device_a.id]

      loaded_policy_b =
        Ash.load!(policy_b, [:image_policy_deployments, :devices], tenant: tenant_b)

      assert loaded_policy_b.image_policy_deployments == []
      assert loaded_policy_b.devices == []
    end
  end
end
