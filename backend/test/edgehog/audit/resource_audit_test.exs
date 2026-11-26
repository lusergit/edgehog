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

defmodule Edgehog.Audit.ResourceAuditTest do
  @moduledoc """
  Tests for the `Ash.Audit` extension: which actions of a resource get audited
  and what the registered events look like.

  Uses `Edgehog.Containers.Network` (simplest audited resource, defaults) and
  `Edgehog.Groups.DeviceGroup` for the bulk update path.
  """

  use Edgehog.DataCase, async: false

  import Edgehog.ContainersFixtures
  import Edgehog.GroupsFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Actors.Actor
  alias Edgehog.Audit.Event
  alias Edgehog.Config
  alias Edgehog.Containers.Network
  alias Edgehog.Groups.DeviceGroup

  setup do
    stub(Config, :audit_log_events?, fn -> false end)
    stub(Config, :audit_store_events?, fn -> true end)

    %{tenant: tenant_fixture()}
  end

  describe "audited resource actions" do
    test "registers events for create, update and destroy", %{tenant: tenant} do
      network =
        Ash.create!(
          Network,
          %{
            label: "audit-network",
            driver: "bridge",
            internal: false,
            enable_ipv6: false,
            options: %{}
          },
          tenant: tenant
        )

      assert create_event = event_for(tenant, Network, :create)
      assert create_event.ash_action_info.action_type == :create
      assert create_event.log_level == :info
      assert %Ash.Union{type: :uuid, value: id} = create_event.ash_action_info.record_id
      assert id == network.id

      network
      |> Ash.Changeset.for_update(:update, %{label: "audit-network-updated"}, tenant: tenant)
      |> Ash.update!()

      assert update_event = event_for(tenant, Network, :update)
      assert update_event.ash_action_info.action_type == :update
      assert %Ash.Union{type: :uuid, value: id} = update_event.ash_action_info.record_id
      assert id == network.id

      Ash.destroy!(network, tenant: tenant)

      assert destroy_event = event_for(tenant, Network, :destroy)
      assert destroy_event.ash_action_info.action_type == :destroy
      assert %Ash.Union{type: :uuid, value: id} = destroy_event.ash_action_info.record_id
      assert id == network.id

      assert length(events_for(tenant)) == 3
    end

    test "registers events for bulk updates running through the atomic path", %{
      tenant: tenant
    } do
      # use bulk, since it uses atomic by default

      group = device_group_fixture(tenant: tenant)

      assert %Ash.BulkResult{status: :success} =
               Ash.bulk_update!([group], :unassign_channel, %{}, tenant: tenant)

      assert event = event_for(tenant, DeviceGroup, :unassign_channel)
      assert event.ash_action_info.action_type == :update
      assert %Ash.Union{type: :integer, value: id} = event.ash_action_info.record_id
      assert id == group.id
    end

    test "serializes embedded Ash actor structs without failing on :__meta__", %{
      tenant: tenant
    } do
      actor = %Actor{sub: "user-123", preferred_username: "alice"}

      Ash.create!(
        Network,
        %{
          label: "audit-network-with-actor",
          driver: "bridge",
          internal: false,
          enable_ipv6: false,
          options: %{}
        },
        tenant: tenant,
        actor: actor
      )

      assert event = event_for(tenant, Network, :create)
      assert event.ash_action_info.actor["sub"] == "user-123"
      assert event.ash_action_info.actor["preferred_username"] == "alice"
      refute Map.has_key?(event.ash_action_info.actor, "__meta__")
    end
  end

  describe "failed audited resource actions" do
    test "registers an error event when a network create fails", %{tenant: tenant} do
      params = %{
        label: "audit-network-dup",
        driver: "bridge",
        internal: false,
        enable_ipv6: false,
        options: %{}
      }

      Ash.create!(Network, params, tenant: tenant)

      assert {:error, _error} = Ash.create(Network, params, tenant: tenant)

      assert event = event_for(tenant, Network, :create, :error)
      assert event.log_level == :error
      assert event.message == "Failed to run #{Network}.create"
      assert event.ash_action_info.action_type == :create
      assert is_nil(Map.get(event.ash_action_info, :record_id))
      assert event.ash_action_info.action_inputs["label"] == "audit-network-dup"
      assert event.metadata["error"] =~ "has already been taken"
    end

    test "registers an error event when a network update fails", %{tenant: tenant} do
      network =
        Ash.create!(
          Network,
          %{
            label: "audit-network-a",
            driver: "bridge",
            internal: false,
            enable_ipv6: false,
            options: %{}
          },
          tenant: tenant
        )

      Ash.create!(
        Network,
        %{
          label: "audit-network-b",
          driver: "bridge",
          internal: false,
          enable_ipv6: false,
          options: %{}
        },
        tenant: tenant
      )

      # use the label of another network to fail uniqueness validation
      assert {:error, _error} =
               network
               |> Ash.Changeset.for_update(:update, %{label: "audit-network-b"}, tenant: tenant)
               |> Ash.update()

      assert event = event_for(tenant, Network, :update, :error)
      assert event.log_level == :error
      assert event.message == "Failed to run #{Network}.update"
      assert event.ash_action_info.action_type == :update
      assert %Ash.Union{type: :uuid, value: id} = event.ash_action_info.record_id
      assert id == network.id
      assert event.metadata["error"] =~ "has already been taken"
      refute event_for(tenant, Network, :update, :info)
    end

    test "registers an error event when a network destroy fails", %{tenant: tenant} do
      network =
        Ash.create!(
          Network,
          %{
            label: "audit-network-busy",
            driver: "bridge",
            internal: false,
            enable_ipv6: false,
            options: %{}
          },
          tenant: tenant
        )

      container_fixture(tenant: tenant, networks: [network])

      assert {:error, _error} =
               Ash.destroy(network, action: :destroy_if_dangling, tenant: tenant)

      assert event = event_for(tenant, Network, :destroy_if_dangling, :error)
      assert event.log_level == :error
      assert event.message == "Failed to run #{Network}.destroy_if_dangling"
      assert event.ash_action_info.action_name == :destroy_if_dangling
      assert event.ash_action_info.action_type == :destroy
      assert %Ash.Union{type: :uuid, value: id} = event.ash_action_info.record_id
      assert id == network.id
      assert event.metadata["error"] =~ "in use"
      refute event_for(tenant, Network, :destroy_if_dangling, :info)
    end
  end

  defp events_for(tenant) do
    Ash.read!(Event, tenant: tenant)
  end

  defp event_for(tenant, resource_module, action_name, log_level \\ nil) do
    tenant
    |> events_for()
    |> Enum.find(fn event ->
      event.ash_action_info &&
        event.ash_action_info.resource_module == resource_module &&
        event.ash_action_info.action_name == action_name &&
        (is_nil(log_level) || event.log_level == log_level)
    end)
  end
end
