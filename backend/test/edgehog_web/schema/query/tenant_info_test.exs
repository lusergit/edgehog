#
# This file is part of Edgehog.
#
# Copyright 2021-2026 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Query.TenantInfoTest do
  use Edgehog.DataCase, async: true

  import Edgehog.CampaignsFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.GroupsFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Tenants.Tenant

  describe "tenantInfo query" do
    test "returns the tenant info" do
      tenant = tenant_fixture()
      %Tenant{tenant_id: id, name: name, slug: slug, default_locale: default_locale} = tenant

      doc = """
      query {
        tenantInfo {
          id
          name
          slug
          defaultLocale
        }
      }
      """

      assert %{
               data: %{
                 "tenantInfo" => %{
                   "id" => graphql_id,
                   "name" => ^name,
                   "slug" => ^slug,
                   "defaultLocale" => ^default_locale
                 }
               }
             } = Absinthe.run!(doc, EdgehogWeb.Schema, context: %{tenant: tenant, actor: %{}})

      assert {:ok, %{type: :tenant_info, id: decoded_id}} =
               AshGraphql.Resource.decode_relay_id(graphql_id)

      assert decoded_id == to_string(id)
    end

    test "returns tenant-scoped device fleet aggregates" do
      tenant = tenant_fixture()
      other_tenant = tenant_fixture()

      _online = device_fixture(tenant: tenant, online: true)
      _offline = device_fixture(tenant: tenant, online: false)
      _other = device_fixture(tenant: other_tenant, online: true)

      doc = """
      query {
        tenantInfo {
          deviceCount
          onlineDeviceCount
        }
      }
      """

      assert %{
               data: %{
                 "tenantInfo" => %{
                   "deviceCount" => 2,
                   "onlineDeviceCount" => 1
                 }
               }
             } = Absinthe.run!(doc, EdgehogWeb.Schema, context: %{tenant: tenant, actor: %{}})
    end

    test "returns tenant-scoped device group aggregates" do
      tenant = tenant_fixture()

      matched_group =
        device_group_fixture(tenant: tenant, name: "Matched", selector: ~s<"alpha" in tags>)

      _empty_group =
        device_group_fixture(tenant: tenant, name: "Empty", selector: ~s<"none" in tags>)

      _channel = channel_fixture(tenant: tenant, target_group_ids: [matched_group.id])
      [tenant: tenant] |> device_fixture() |> add_tags(["alpha"])

      doc = """
      query {
        tenantInfo {
          deviceGroupCount
          assignedDeviceGroupCount
          emptyDeviceGroupCount
        }
      }
      """

      assert %{
               data: %{
                 "tenantInfo" => %{
                   "deviceGroupCount" => 2,
                   "assignedDeviceGroupCount" => 1,
                   "emptyDeviceGroupCount" => 1
                 }
               }
             } = Absinthe.run!(doc, EdgehogWeb.Schema, context: %{tenant: tenant, actor: %{}})
    end

    test "returns tenant-scoped channel and active campaign aggregates" do
      tenant = tenant_fixture()
      group = device_group_fixture(tenant: tenant)
      channel = channel_fixture(tenant: tenant, target_group_ids: [group.id])
      _empty_channel = channel_fixture(tenant: tenant, target_group_ids: [])

      active_campaign = campaign_fixture(tenant: tenant, channel_id: channel.id)

      _active =
        Ash.update!(active_campaign, %{},
          action: :mark_as_in_progress,
          tenant: tenant,
          authorize?: false
        )

      finished_campaign = campaign_fixture(tenant: tenant, channel_id: channel.id)

      _finished =
        Ash.update!(finished_campaign, %{},
          action: :mark_as_successful,
          tenant: tenant,
          authorize?: false
        )

      doc = """
      query {
        tenantInfo {
          channelCount
          emptyChannelCount
          activeCampaignCount
        }
      }
      """

      assert %{
               data: %{
                 "tenantInfo" => %{
                   "channelCount" => 2,
                   "emptyChannelCount" => 1,
                   "activeCampaignCount" => 1
                 }
               }
             } = Absinthe.run!(doc, EdgehogWeb.Schema, context: %{tenant: tenant, actor: %{}})
    end

    test "returns tenant-scoped system model catalog aggregates and unmapped part numbers" do
      tenant = tenant_fixture()
      hw_covered = hardware_type_fixture(tenant: tenant)
      _hw_unused = hardware_type_fixture(tenant: tenant)

      _model =
        system_model_fixture(
          tenant: tenant,
          hardware_type_id: hw_covered.id,
          part_numbers: ["PN-MAPPED"]
        )

      _d1 = device_fixture(tenant: tenant, part_number: "PN-MAPPED", online: true)
      _d2 = device_fixture(tenant: tenant, part_number: "PN-MAPPED", online: false)
      _d3 = device_fixture(tenant: tenant, part_number: "PN-ORPHAN", online: true)
      _d4 = device_fixture(tenant: tenant, part_number: "PN-ORPHAN", online: false)

      doc = """
      query {
        tenantInfo {
          systemModelCount
          hardwareTypeCount
          coveredHardwareTypeCount
          systemModelPartNumberCount
          mappedDeviceCount
          onlineMappedDeviceCount
          unmappedDeviceCount
          unmappedPartNumbers {
            partNumber
            deviceCount
            onlineDeviceCount
          }
        }
      }
      """

      assert %{
               data: %{
                 "tenantInfo" => %{
                   "systemModelCount" => 1,
                   "hardwareTypeCount" => 2,
                   "coveredHardwareTypeCount" => 1,
                   "systemModelPartNumberCount" => 1,
                   "mappedDeviceCount" => 2,
                   "onlineMappedDeviceCount" => 1,
                   "unmappedDeviceCount" => 2,
                   "unmappedPartNumbers" => [
                     %{
                       "partNumber" => "PN-ORPHAN",
                       "deviceCount" => 2,
                       "onlineDeviceCount" => 1
                     }
                   ]
                 }
               }
             } = Absinthe.run!(doc, EdgehogWeb.Schema, context: %{tenant: tenant, actor: %{}})
    end
  end
end
