#
# This file is part of Edgehog.
#
# Copyright 2023 - 2026 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Query.ChannelsTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.CampaignsFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.GroupsFixtures

  describe "channels query" do
    setup %{tenant: tenant} do
      {:ok, target_group: device_group_fixture(tenant: tenant)}
    end

    test "returns empty channels", %{tenant: tenant} do
      assert [] == [tenant: tenant] |> channels_query() |> extract_result!()
    end

    test "returns channels if present", %{tenant: tenant, target_group: target_group} do
      channel = channel_fixture(target_group_ids: [target_group.id], tenant: tenant)

      [channel_data] =
        [tenant: tenant] |> channels_query() |> extract_result!() |> extract_nodes!()

      assert channel_data["id"] == AshGraphql.Resource.encode_relay_id(channel)
      assert channel_data["handle"] == channel.handle
      assert channel_data["name"] == channel.name

      assert [target_group_data] =
               extract_nodes!(channel_data["targetGroups"]["edges"])

      assert target_group_data["id"] == AshGraphql.Resource.encode_relay_id(target_group)
      assert target_group_data["handle"] == target_group.handle
      assert target_group_data["name"] == target_group.name
    end

    test "exposes aggregates, featuredCampaign, fleetReach, search, and channel device queries",
         %{
           tenant: tenant
         } do
      model =
        system_model_fixture(
          tenant: tenant,
          name: "EdgeBox",
          handle: "edgebox",
          part_numbers: ["EB-1"]
        )

      g1 =
        device_group_fixture(
          tenant: tenant,
          name: "Canary EU",
          handle: "canary-eu",
          selector: ~s<"canary" in tags>
        )

      g2 =
        device_group_fixture(
          tenant: tenant,
          name: "Nightly",
          handle: "nightly",
          selector: ~s<"nightly" in tags>
        )

      d1 =
        [tenant: tenant, online: true, part_number: "EB-1"]
        |> device_fixture()
        |> add_tags(["canary", "nightly"])

      _d2 =
        [tenant: tenant, online: false, part_number: "EB-1"]
        |> device_fixture()
        |> add_tags(["nightly"])

      channel =
        channel_fixture(
          tenant: tenant,
          name: "Stable Ring",
          handle: "stable-ring",
          target_group_ids: [g1.id, g2.id]
        )

      _empty_channel =
        channel_fixture(
          tenant: tenant,
          name: "Empty Ring",
          handle: "empty-ring",
          target_group_ids: []
        )

      finished_campaign =
        campaign_fixture(tenant: tenant, channel_id: channel.id, name: "Old Release")

      _finished =
        Ash.update!(finished_campaign, %{},
          action: :mark_as_successful,
          tenant: tenant,
          authorize?: false
        )

      active_campaign =
        campaign_fixture(tenant: tenant, channel_id: channel.id, name: "Active Rollout")

      active =
        Ash.update!(active_campaign, %{},
          action: :mark_as_in_progress,
          tenant: tenant,
          authorize?: false
        )

      channel_relay_id = AshGraphql.Resource.encode_relay_id(channel)
      g1_relay_id = AshGraphql.Resource.encode_relay_id(g1)
      g2_relay_id = AshGraphql.Resource.encode_relay_id(g2)

      doc = """
      query ($channelId: ID!, $groupIds: [ID!]!) {
        channels(search: "canary") {
          edges {
            node {
              name
              targetGroupCount
              campaignCount
              hasActiveRollout
              hasRunningCampaign
              featuredCampaign {
                name
                isActive
                isRunning
              }
              fleetReach {
                totalCount
                onlineCount
                systemModelCounts {
                  name
                  handle
                  deviceCount
                }
              }
            }
          }
        }
        activeCampaigns {
          count
        }
        devicesForChannel(channelId: $channelId) {
          count
        }
        devicesForDeviceGroups(deviceGroupIds: $groupIds) {
          count
        }
        devicesInAnyChannel {
          count
        }
      }
      """

      result =
        Absinthe.run!(doc, EdgehogWeb.Schema,
          variables: %{"channelId" => channel_relay_id, "groupIds" => [g1_relay_id, g2_relay_id]},
          context: %{tenant: tenant, actor: %{}}
        )

      active_name = active.name
      model_name = model.name
      model_handle = model.handle
      _ = d1

      assert %{
               data: %{
                 "channels" => %{
                   "edges" => [
                     %{
                       "node" => %{
                         "name" => "Stable Ring",
                         "targetGroupCount" => 2,
                         "campaignCount" => 2,
                         "hasActiveRollout" => true,
                         "hasRunningCampaign" => true,
                         "featuredCampaign" => %{
                           "name" => ^active_name,
                           "isActive" => true,
                           "isRunning" => true
                         },
                         "fleetReach" => %{
                           "totalCount" => 2,
                           "onlineCount" => 1,
                           "systemModelCounts" => [
                             %{
                               "name" => ^model_name,
                               "handle" => ^model_handle,
                               "deviceCount" => 2
                             }
                           ]
                         }
                       }
                     }
                   ]
                 },
                 "activeCampaigns" => %{"count" => 1},
                 "devicesForChannel" => %{"count" => 2},
                 "devicesForDeviceGroups" => %{"count" => 2},
                 "devicesInAnyChannel" => %{"count" => 2}
               }
             } = result
    end
  end

  defp channels_query(opts) do
    default_document = """
    query {
      channels {
        edges {
          node {
            id
            handle
            name
            targetGroups {
              edges {
                node {
                  id
                  name
                  handle
                }
              }
            }
          }
        }
      }
    }
    """

    tenant = Keyword.fetch!(opts, :tenant)
    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, context: %{tenant: tenant, actor: %{}})
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "channels" => %{
                 "edges" => channels
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert channels

    channels
  end

  defp extract_nodes!(data) do
    Enum.map(data, &Map.fetch!(&1, "node"))
  end
end
