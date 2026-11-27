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

defmodule Edgehog.Triggers.IncomingData.Handlers.AvailablePublicKeysTest do
  use Edgehog.DataCase, async: true

  import Edgehog.AstarteFixtures
  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Containers
  alias Edgehog.Triggers.IncomingData.Handlers.AvailablePublicKeys

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

  test "creates a deployment for a key fingerprint unknown to the cloud", %{
    tenant: tenant,
    device: device,
    context: context
  } do
    fingerprint = String.duplicate("a", 64)

    event = %{
      path: "/#{fingerprint}/status",
      value: "Present"
    }

    assert {:ok, deployment} = AvailablePublicKeys.handle_event(event, [], context)
    assert deployment.public_key_fingerprint == fingerprint
    assert deployment.device_id == device.id
    assert deployment.state == :present

    loaded = Ash.load!(deployment, [:public_key], tenant: tenant)
    assert is_nil(loaded.public_key)
  end

  test "updates state for a cloud-defined public key deployment across Present, Missing, Error",
       %{tenant: tenant, device: device, context: context} do
    public_key = public_key_fixture(tenant: tenant)
    {:ok, deployment} = Containers.deploy_public_key(public_key, device, tenant: tenant)

    for {raw_status, expected_state} <- [
          {"Present", :present},
          {"Missing", :missing},
          {"Error", :error}
        ] do
      event = %{path: "/#{public_key.fingerprint}/status", value: raw_status}

      assert {:ok, updated} = AvailablePublicKeys.handle_event(event, [], context)
      assert updated.id == deployment.id
      assert updated.state == expected_state
    end
  end

  test "destroys existing deployment on nil unset and is idempotent when missing", %{
    tenant: tenant,
    device: device,
    context: context
  } do
    fingerprint = String.duplicate("b", 64)
    event = %{path: "/#{fingerprint}/status", value: "Present"}
    assert {:ok, _deployment} = AvailablePublicKeys.handle_event(event, [], context)

    unset_event = %{path: "/#{fingerprint}/status", value: nil}
    assert {:ok, _destroyed} = AvailablePublicKeys.handle_event(unset_event, [], context)

    assert {:error, _} =
             Containers.fetch_public_key_deployment(fingerprint, device.id, tenant: tenant)

    # Second unset is a no-op
    assert :ok = AvailablePublicKeys.handle_event(unset_event, [], context)
  end

  test "returns errors on invalid paths, empty key_id, unknown status, or unknown device", %{
    context: context
  } do
    assert {:error, :invalid_event_path} =
             AvailablePublicKeys.handle_event(%{path: "/invalid", value: "Present"}, [], context)

    assert {:error, :invalid_event_path} =
             AvailablePublicKeys.handle_event(%{path: "//status", value: "Present"}, [], context)

    assert {:error, :invalid_status} =
             AvailablePublicKeys.handle_event(
               %{path: "/abc/status", value: "UnknownStatus"},
               [],
               context
             )

    unknown_device_context = Map.put(context, :device_id, "unknown-device-id")

    assert {:error, %Ash.Error.Invalid{}} =
             AvailablePublicKeys.handle_event(
               %{path: "/abc/status", value: "Present"},
               [],
               unknown_device_context
             )
  end
end
