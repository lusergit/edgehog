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

defmodule Edgehog.Triggers.IncomingData.Handlers.AvailableImagePoliciesTest do
  use Edgehog.DataCase, async: true

  import Edgehog.AstarteFixtures
  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Containers
  alias Edgehog.Triggers.IncomingData.Handlers.AvailableImagePolicies

  setup do
    tenant = tenant_fixture()
    realm = realm_fixture(tenant: tenant)
    device = device_fixture(realm_id: realm.id, tenant: tenant)

    context = %{
      realm_id: realm.id,
      device_id: device.device_id,
      tenant: tenant
    }

    %{tenant: tenant, realm: realm, device: device, context: context}
  end

  test "creates a deployment for a registry_id unknown to the cloud", %{
    tenant: tenant,
    device: device,
    context: context
  } do
    registry_id = String.duplicate("c", 64)

    event = %{
      path: "/#{registry_id}/status",
      value: "Present"
    }

    assert {:ok, deployment} = AvailableImagePolicies.handle_event(event, [], context)
    assert deployment.registry_id == registry_id
    assert deployment.device_id == device.id
    assert deployment.state == :present

    loaded = Ash.load!(deployment, [:image_policy], tenant: tenant)
    assert is_nil(loaded.image_policy)
  end

  test "updates state for a cloud-defined image policy deployment across Present, Missing, Error",
       %{tenant: tenant, device: device, context: context} do
    policy = image_policy_fixture(tenant: tenant)
    {:ok, deployment} = Containers.deploy_image_policy(policy, device, tenant: tenant)

    for {raw_status, expected_state} <- [
          {"Present", :present},
          {"Missing", :missing},
          {"Error", :error}
        ] do
      event = %{path: "/#{policy.registry_id}/status", value: raw_status}

      assert {:ok, updated} = AvailableImagePolicies.handle_event(event, [], context)
      assert updated.id == deployment.id
      assert updated.state == expected_state
    end
  end

  test "destroys existing deployment on nil unset and is idempotent when missing", %{
    tenant: tenant,
    device: device,
    context: context
  } do
    registry_id = String.duplicate("d", 64)
    event = %{path: "/#{registry_id}/status", value: "Present"}
    assert {:ok, _deployment} = AvailableImagePolicies.handle_event(event, [], context)

    unset_event = %{path: "/#{registry_id}/status", value: nil}
    assert {:ok, _destroyed} = AvailableImagePolicies.handle_event(unset_event, [], context)

    assert {:error, _} =
             Containers.fetch_image_policy_deployment(registry_id, device.id, tenant: tenant)

    assert :ok = AvailableImagePolicies.handle_event(unset_event, [], context)
  end

  test "returns errors on invalid paths, empty registry_id, unknown status, or unknown device", %{
    context: context
  } do
    assert {:error, :invalid_event_path} =
             AvailableImagePolicies.handle_event(
               %{path: "/invalid", value: "Present"},
               [],
               context
             )

    assert {:error, :invalid_event_path} =
             AvailableImagePolicies.handle_event(
               %{path: "//status", value: "Present"},
               [],
               context
             )

    assert {:error, :invalid_status} =
             AvailableImagePolicies.handle_event(
               %{path: "/abc/status", value: "Invalid"},
               [],
               context
             )

    unknown_device_context = Map.put(context, :device_id, "unknown-device-id")

    assert {:error, %Ash.Error.Invalid{}} =
             AvailableImagePolicies.handle_event(
               %{path: "/abc/status", value: "Present"},
               [],
               unknown_device_context
             )
  end
end
