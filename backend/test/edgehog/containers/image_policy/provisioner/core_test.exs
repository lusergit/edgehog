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

defmodule Edgehog.Containers.ImagePolicy.Deployment.Provisioner.CoreTest do
  @moduledoc """
  Tests for the image policy deployment provisioner Core.
  """

  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Astarte.Device.AvailableImagePolicies
  alias Edgehog.Astarte.Device.AvailableImagePolicies.ImagePolicyStatus
  alias Edgehog.Astarte.Device.ImagePolicy, as: AstarteImagePolicy
  alias Edgehog.Astarte.Device.ImagePolicy.RequestData
  alias Edgehog.Containers
  alias Edgehog.Containers.ImagePolicy.Deployment.Provisioner.Core

  describe "ImagePolicy deployment provisioner Core" do
    setup do
      tenant = tenant_fixture()
      policy = image_policy_fixture(tenant: tenant, repository: "docker.io", type: :reject)
      device = device_fixture(tenant: tenant)

      {:ok, deployment} = Containers.deploy_image_policy(policy, device, tenant: tenant)

      %{
        tenant: tenant,
        policy: policy,
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
      assert Core.topic(%{id: "ip-dep-1"}) == "ready:image_policy_deployments:ip-dep-1"
      assert Core.topic("ip-dep-1") == "ready:image_policy_deployments:ip-dep-1"

      assert Core.subscribe_topic(%{id: "ip-dep-1"}) == "image_policy_deployments:ip-dep-1"
      assert Core.subscribe_topic("ip-dep-1") == "image_policy_deployments:ip-dep-1"

      assert Core.name(%{id: "ip-dep-1"}) ==
               {:via, Registry,
                {Edgehog.Containers.ImagePolicy.Deployment.Provisioner.Registry, "ip-dep-1"}}
    end

    test "send_to_device/2 sends :reject and :signed_by image policies to the device", %{
      tenant: tenant,
      policy: reject_policy,
      device: device,
      deployment: reject_deployment
    } do
      expected_device_id = device.device_id
      expected_reg_id = reject_policy.registry_id

      expect(AstarteImagePolicy, :set, fn _client, ^expected_device_id, %RequestData{} = data ->
        assert data.registry_id == expected_reg_id
        assert data.repository == "docker.io"
        assert data.type == :reject
        assert is_nil(data.key_id)
        :ok
      end)

      assert :ok == Core.send_to_device(reject_deployment, tenant: tenant)

      public_key = public_key_fixture(tenant: tenant)

      signed_policy =
        image_policy_fixture(
          tenant: tenant,
          repository: "quay.io/signed-org",
          type: :signed_by,
          public_key_id: public_key.id
        )

      {:ok, signed_deployment} =
        Containers.deploy_image_policy(signed_policy, device, tenant: tenant)

      expected_signed_reg_id = signed_policy.registry_id
      expected_fp = public_key.fingerprint

      expect(AstarteImagePolicy, :set, fn _client, ^expected_device_id, %RequestData{} = data ->
        assert data.registry_id == expected_signed_reg_id
        assert data.repository == "quay.io/signed-org"
        assert data.type == :signed_by
        assert data.key_id == expected_fp
        :ok
      end)

      assert :ok == Core.send_to_device(signed_deployment, tenant: tenant)
    end

    test "send_to_device/2 returns :image_policy_not_found for device-only deployments", %{
      tenant: tenant,
      device: device
    } do
      deployment =
        image_policy_deployment_fixture(
          tenant: tenant,
          device_id: device.id,
          registry_id: String.duplicate("e", 64)
        )

      reject(AstarteImagePolicy, :set, 3)

      assert {:error, :image_policy_not_found} == Core.send_to_device(deployment, tenant: tenant)
    end

    test "reconcile/2 updates state for :present, :missing, and first :error transition", %{
      tenant: tenant,
      policy: policy,
      deployment: deployment
    } do
      for {status, expected_state} <- [
            {:present, :present},
            {:missing, :missing},
            {:error, :error}
          ] do
        expect(AvailableImagePolicies, :get, fn _client, _device_id ->
          {:ok, [%ImagePolicyStatus{id: policy.registry_id, status: status}]}
        end)

        assert {:ok, updated} = Core.reconcile(deployment, tenant: tenant)
        assert updated.id == deployment.id
        assert updated.state == expected_state
      end
    end

    test "reconcile/2 returns :not_found when already :error, when status is nil, missing, or Astarte fails",
         %{tenant: tenant, policy: policy, deployment: deployment} do
      {:ok, errored_deployment} =
        deployment
        |> Ash.Changeset.for_update(:set_state, %{state: :error})
        |> Ash.update(tenant: tenant)

      expect(AvailableImagePolicies, :get, fn _client, _device_id ->
        {:ok, [%ImagePolicyStatus{id: policy.registry_id, status: :error}]}
      end)

      assert :not_found == Core.reconcile(errored_deployment, tenant: tenant)

      expect(AvailableImagePolicies, :get, fn _client, _device_id ->
        {:ok, [%ImagePolicyStatus{id: policy.registry_id, status: nil}]}
      end)

      assert :not_found == Core.reconcile(deployment, tenant: tenant)

      expect(AvailableImagePolicies, :get, fn _client, _device_id ->
        {:ok, []}
      end)

      assert :not_found == Core.reconcile(deployment, tenant: tenant)

      expect(AvailableImagePolicies, :get, fn _client, _device_id ->
        {:error, :timeout}
      end)

      assert :not_found == Core.reconcile(deployment, tenant: tenant)
    end

    test "temporary_error?/1 classifies transient and permanent errors" do
      assert Core.temporary_error?("connection refused")
      assert Core.temporary_error?({:error, %Edgehog.Error.DeviceOffline{}})
      assert Core.temporary_error?(%Edgehog.Error.AstarteAPIError{status: 502})
      refute Core.temporary_error?({:error, :image_policy_not_found})
      refute Core.temporary_error?(%Edgehog.Error.AstarteAPIError{status: 400})
    end
  end
end
