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

defmodule Edgehog.Audit.ImagePolicyAuditTest do
  @moduledoc """
  Tests verifying default `Ash.Audit` event recording across `PublicKey`,
  `PublicKey.Deployment`, `ImagePolicy`, and `ImagePolicy.Deployment` actions.
  """

  use Edgehog.DataCase, async: false

  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Audit.Event
  alias Edgehog.Config
  alias Edgehog.Containers
  alias Edgehog.Containers.ImagePolicy
  alias Edgehog.Containers.PublicKey

  setup do
    stub(Config, :audit_log_events?, fn -> false end)
    stub(Config, :audit_store_events?, fn -> true end)

    %{tenant: tenant_fixture()}
  end

  describe "PublicKey auditing" do
    test "records create, failed create, and destroy audit events", %{tenant: tenant} do
      actor = %{"sub" => "user-1", "preferred_username" => "ops"}
      pem = x509_certificate_pem_fixture()

      public_key =
        Ash.create!(
          PublicKey,
          %{label: "audited-key", pem: pem},
          tenant: tenant,
          actor: actor
        )

      assert create_event = event_for(tenant, PublicKey, :create, :info)
      assert create_event.ash_action_info.action_type == :create
      assert %Ash.Union{type: :uuid, value: id} = create_event.ash_action_info.record_id
      assert id == public_key.id
      assert create_event.ash_action_info.actor["sub"] == "user-1"

      assert {:error, _} =
               Ash.create(
                 PublicKey,
                 %{label: "audited-key", pem: x509_certificate_pem_fixture()},
                 tenant: tenant
               )

      assert failed_event = event_for(tenant, PublicKey, :create, :error)
      assert failed_event.log_level == :error
      assert is_nil(Map.get(failed_event.ash_action_info, :record_id))
      assert failed_event.metadata["error"] =~ "has already been taken"

      assert :ok = Containers.destroy_public_key(public_key, tenant: tenant)

      assert destroy_event = event_for(tenant, PublicKey, :destroy, :info)
      assert destroy_event.ash_action_info.action_type == :destroy
      assert %Ash.Union{type: :uuid, value: destroy_id} = destroy_event.ash_action_info.record_id
      assert destroy_id == public_key.id
    end
  end

  describe "PublicKey.Deployment auditing" do
    test "records deploy (with struct args filtered), upsert_from_device, send_deployment, mark_as_present, and destroy",
         %{tenant: tenant} do
      public_key = public_key_fixture(tenant: tenant)
      device = device_fixture(tenant: tenant)

      {:ok, deployment} = Containers.deploy_public_key(public_key, device, tenant: tenant)

      assert deploy_event = event_for(tenant, PublicKey.Deployment, :deploy, :info)
      assert deploy_event.ash_action_info.action_type == :create
      assert %Ash.Union{type: :uuid, value: deploy_id} = deploy_event.ash_action_info.record_id
      assert deploy_id == deployment.id
      refute Map.has_key?(deploy_event.ash_action_info.action_inputs, "public_key")
      refute Map.has_key?(deploy_event.ash_action_info.action_inputs, "device")

      {:ok, _upserted} =
        Containers.upsert_public_key_deployment_from_device(
          %{
            public_key_fingerprint: public_key.fingerprint,
            device_id: device.id,
            state: :sent
          },
          tenant: tenant
        )

      assert upsert_event = event_for(tenant, PublicKey.Deployment, :upsert_from_device, :info)
      assert upsert_event.ash_action_info.action_type == :create

      expect(PublicKey.Deployment.Provisioner, :provision, fn _dep, _tenant -> {:ok, self()} end)
      {:ok, deployment} = Containers.send_public_key_deployment(deployment, tenant: tenant)

      assert send_event = event_for(tenant, PublicKey.Deployment, :send_deployment, :info)
      assert send_event.ash_action_info.action_type == :update

      {:ok, deployment} =
        Containers.mark_public_key_deployment_as_present(deployment, tenant: tenant)

      assert present_event = event_for(tenant, PublicKey.Deployment, :mark_as_present, :info)
      assert present_event.ash_action_info.action_type == :update

      assert :ok = Containers.destroy_public_key_deployment(deployment, tenant: tenant)

      assert destroy_event = event_for(tenant, PublicKey.Deployment, :destroy, :info)
      assert destroy_event.ash_action_info.action_type == :destroy
    end
  end

  describe "ImagePolicy auditing" do
    test "records create, failed create, and destroy audit events", %{tenant: tenant} do
      policy =
        Ash.create!(
          ImagePolicy,
          %{repository: "docker.io/audited", type: :reject},
          tenant: tenant
        )

      assert create_event = event_for(tenant, ImagePolicy, :create, :info)
      assert create_event.ash_action_info.action_type == :create
      assert %Ash.Union{type: :uuid, value: id} = create_event.ash_action_info.record_id
      assert id == policy.id

      assert {:error, _} =
               Ash.create(
                 ImagePolicy,
                 %{repository: "docker.io/audited", type: :reject},
                 tenant: tenant
               )

      assert failed_event = event_for(tenant, ImagePolicy, :create, :error)
      assert failed_event.log_level == :error
      assert is_nil(Map.get(failed_event.ash_action_info, :record_id))
      assert failed_event.metadata["error"] =~ "has already been taken"

      assert :ok = Containers.destroy_image_policy(policy, tenant: tenant)

      assert destroy_event = event_for(tenant, ImagePolicy, :destroy, :info)
      assert destroy_event.ash_action_info.action_type == :destroy
      assert %Ash.Union{type: :uuid, value: destroy_id} = destroy_event.ash_action_info.record_id
      assert destroy_id == policy.id
    end
  end

  describe "ImagePolicy.Deployment auditing" do
    test "records deploy (with struct args filtered), upsert_from_device, send_deployment, mark_as_present, and destroy",
         %{tenant: tenant} do
      policy = image_policy_fixture(tenant: tenant)
      device = device_fixture(tenant: tenant)

      {:ok, deployment} = Containers.deploy_image_policy(policy, device, tenant: tenant)

      assert deploy_event = event_for(tenant, ImagePolicy.Deployment, :deploy, :info)
      assert deploy_event.ash_action_info.action_type == :create
      assert %Ash.Union{type: :uuid, value: deploy_id} = deploy_event.ash_action_info.record_id
      assert deploy_id == deployment.id
      refute Map.has_key?(deploy_event.ash_action_info.action_inputs, "image_policy")
      refute Map.has_key?(deploy_event.ash_action_info.action_inputs, "device")

      {:ok, _upserted} =
        Containers.upsert_image_policy_deployment_from_device(
          %{
            registry_id: policy.registry_id,
            device_id: device.id,
            state: :sent
          },
          tenant: tenant
        )

      assert upsert_event = event_for(tenant, ImagePolicy.Deployment, :upsert_from_device, :info)
      assert upsert_event.ash_action_info.action_type == :create

      expect(ImagePolicy.Deployment.Provisioner, :provision, fn _dep, _tenant -> {:ok, self()} end)

      {:ok, deployment} = Containers.send_image_policy_deployment(deployment, tenant: tenant)

      assert send_event = event_for(tenant, ImagePolicy.Deployment, :send_deployment, :info)
      assert send_event.ash_action_info.action_type == :update

      {:ok, deployment} =
        Containers.mark_image_policy_deployment_as_present(deployment, tenant: tenant)

      assert present_event = event_for(tenant, ImagePolicy.Deployment, :mark_as_present, :info)
      assert present_event.ash_action_info.action_type == :update

      assert :ok = Containers.destroy_image_policy_deployment(deployment, tenant: tenant)

      assert destroy_event = event_for(tenant, ImagePolicy.Deployment, :destroy, :info)
      assert destroy_event.ash_action_info.action_type == :destroy
    end
  end

  defp event_for(tenant, resource_module, action_name, log_level) do
    Event
    |> Ash.read!(tenant: tenant)
    |> Enum.find(fn event ->
      event.ash_action_info &&
        event.ash_action_info.resource_module == resource_module &&
        event.ash_action_info.action_name == action_name &&
        event.log_level == log_level
    end)
  end
end
