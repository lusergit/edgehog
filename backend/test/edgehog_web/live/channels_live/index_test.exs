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

defmodule EdgehogWeb.ChannelsLive.IndexTest do
  use EdgehogWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Edgehog.CampaignsFixtures
  alias Edgehog.DevicesFixtures
  alias Edgehog.GroupsFixtures
  alias EdgehogWeb.Auth.Token

  defp generate_jwt(tenant_private_key, claims \\ nil) do
    jwk =
      tenant_private_key
      |> X509.PrivateKey.to_pem()
      |> JOSE.JWK.from_pem()

    now = DateTime.utc_now()

    base_claims = %{
      iss: "https://example.issuer.com/current",
      sub: Ash.UUIDv7.generate(),
      aud: "edgehog-test",
      exp: now |> DateTime.shift(hour: 2, day: 1) |> DateTime.to_unix(),
      iat: DateTime.to_unix(now),
      auth_time: now |> DateTime.shift(hour: 1) |> DateTime.to_unix(),
      preferred_username: "username",
      email: "example@email.com",
      given_name: "John",
      family_name: "Doe"
    }

    claims = Map.merge(base_claims, claims || %{e_tga: true})

    {:ok, jwt, _claims} =
      Token.encode_and_sign("dontcare", claims,
        secret: jwk,
        allowed_algos: ["ES256"]
      )

    jwt
  end

  describe "live-updating channels index, Bento cards, filters, and unassigned groups tray" do
    test "renders channel stats, deduplicated fleet reach, system models, campaign strips, and updates via PubSub",
         %{
           conn: conn,
           tenant: tenant,
           tenant_private_key: tenant_private_key
         } do
      jwt = generate_jwt(tenant_private_key)

      system_model =
        DevicesFixtures.system_model_fixture(
          tenant: tenant,
          name: "Edge Gateway X1",
          handle: "edge-gateway-x1"
        )

      part_number =
        system_model
        |> Ash.load!(:part_numbers, tenant: tenant, authorize?: false)
        |> Map.fetch!(:part_numbers)
        |> List.first()
        |> Map.fetch!(:part_number)

      # device1 has both "eu-west" and "production" tags (matches both group1 and group2)
      device1 =
        [tenant: tenant, name: "Gateway EU-1", online: true, part_number: part_number]
        |> DevicesFixtures.device_fixture()
        |> DevicesFixtures.add_tags(["eu-west", "production"])

      # device2 has only "eu-west" tag (matches group1)
      device2 =
        [tenant: tenant, name: "Gateway EU-2", online: false, part_number: part_number]
        |> DevicesFixtures.device_fixture()
        |> DevicesFixtures.add_tags(["eu-west"])

      # device3 is untagged (not covered by any channel initially)
      _device3 =
        DevicesFixtures.device_fixture(
          tenant: tenant,
          name: "Unassigned Sensor",
          online: true
        )

      group1 =
        GroupsFixtures.device_group_fixture(
          tenant: tenant,
          name: "EU Gateways",
          handle: "eu-gateways",
          selector: ~s<"eu-west" in tags>
        )

      group2 =
        GroupsFixtures.device_group_fixture(
          tenant: tenant,
          name: "Production Gateways",
          handle: "prod-gateways",
          selector: ~s<"production" in tags>
        )

      unassigned_group =
        GroupsFixtures.device_group_fixture(
          tenant: tenant,
          name: "Staging Cohort",
          handle: "staging-cohort",
          selector: ~s<"staging" in tags>
        )

      # Channel 1 has two overlapping groups (group1 matches 2 devices,
      # group2 matches 1 device -> deduplicated reach = 2)
      channel1 =
        CampaignsFixtures.channel_fixture(
          tenant: tenant,
          name: "Stable Ring",
          handle: "stable",
          target_group_ids: [group1.id, group2.id]
        )

      # Channel 2 has 0 target groups (Empty Ring)
      channel2 =
        CampaignsFixtures.channel_fixture(
          tenant: tenant,
          name: "Canary Ring",
          handle: "canary",
          target_group_ids: []
        )

      conn =
        post(conn, ~p"/session", %{
          "session" => %{"tenant_slug" => tenant.slug, "auth_token" => jwt}
        })

      {:ok, view, _html} = live(recycle(conn), ~p"/tenants/#{tenant.slug}/channels")

      # 1. Verify active Fleet / Channels dock highlights and header indicator
      assert has_element?(view, "#nav-section-fleet[data-active='true']")
      assert has_element?(view, "#nav-subitem-channels[data-active='true']")
      assert has_element?(view, "#live-pubsub-indicator", "Live")

      # 2. Verify 4-card summary strip (#channels-stats)
      assert has_element?(view, "#stat-total-channels", "2")
      assert has_element?(view, "#stat-empty-channels-warning", "1 empty")
      assert has_element?(view, "#stat-assigned-groups", "2")
      assert has_element?(view, "#stat-unassigned-groups", "1 unassigned")
      assert has_element?(view, "#stat-covered-devices", "2")
      assert has_element?(view, "#stat-covered-online", "1 online")
      assert has_element?(view, "#stat-active-rollouts", "0")

      # 3. Verify Channel 1 card: deduplicated reach (2 devices, not 3), system model pill, target group links
      assert has_element?(
               view,
               "#channel-card-#{channel1.id} [data-role='channel-name']",
               "Stable Ring"
             )

      assert has_element?(
               view,
               "#channel-card-#{channel1.id} [data-role='channel-handle']",
               "@stable"
             )

      assert has_element?(
               view,
               "#channel-card-#{channel1.id} [data-role='channel-status-badge']",
               "Ready"
             )

      assert has_element?(
               view,
               "#channel-card-#{channel1.id} [data-role='target-groups-count']",
               "2"
             )

      assert has_element?(
               view,
               "#channel-card-#{channel1.id} [data-group-handle='eu-gateways']",
               "EU Gateways"
             )

      assert has_element?(
               view,
               "#channel-card-#{channel1.id} [data-group-handle='prod-gateways']",
               "Production Gateways"
             )

      assert has_element?(
               view,
               "#channel-card-#{channel1.id} [data-role='channel-total-devices']",
               "2"
             )

      assert has_element?(
               view,
               "#channel-card-#{channel1.id} [data-role='channel-online-devices']",
               "1 online"
             )

      assert has_element?(
               view,
               "#channel-card-#{channel1.id} [data-role='channel-reach-pct']",
               "50% online"
             )

      assert has_element?(
               view,
               "#channel-card-#{channel1.id} [data-system-model='edge-gateway-x1']",
               "Edge Gateway X1"
             )

      assert has_element?(
               view,
               "#channel-card-#{channel1.id} [data-system-model='edge-gateway-x1']",
               "(2)"
             )

      assert has_element?(
               view,
               "#channel-card-#{channel1.id} [data-role='no-campaigns']",
               "No campaigns executed yet"
             )

      # 4. Verify Channel 2 card: empty target groups warning
      assert has_element?(
               view,
               "#channel-card-#{channel2.id} [data-role='channel-status-badge']",
               "Empty Ring"
             )

      assert has_element?(
               view,
               "#channel-card-#{channel2.id} [data-role='empty-target-groups']",
               "No target groups assigned"
             )

      assert has_element?(
               view,
               "#channel-card-#{channel2.id} [data-role='channel-total-devices']",
               "0"
             )

      # 5. Verify Unassigned Groups Tray
      assert has_element?(view, "#unassigned-groups-count", "1")
      assert has_element?(view, "#unassigned-group-#{unassigned_group.id}", "Staging Cohort")

      # 6. Verify Search & Filter Pills (including filter-safe PubSub updates)
      view
      |> element("#channels-filter-pills button[data-filter='empty_groups']")
      |> render_click()

      refute has_element?(view, "#channel-card-#{channel1.id}")
      assert has_element?(view, "#channel-card-#{channel2.id}")

      # Trigger a PubSub update on device2 while channel1 is filtered out -> must not raise ArgumentError
      device2 =
        Ash.update!(device2, %{online: true},
          action: :from_device_status,
          tenant: tenant,
          authorize?: false
        )

      _ = render(view)

      assert has_element?(view, "#stat-covered-online", "2 online")

      # Switch back to "all" filter and verify channel1 reflects 2 online (100% online)
      view
      |> element("#channels-filter-pills button[data-filter='all']")
      |> render_click()

      assert has_element?(
               view,
               "#channel-card-#{channel1.id} [data-role='channel-online-devices']",
               "2 online"
             )

      assert has_element?(
               view,
               "#channel-card-#{channel1.id} [data-role='channel-reach-pct']",
               "100% online"
             )

      # Search by target group name
      view
      |> form("#channels-search-form", %{"search" => "prod-gateways"})
      |> render_change()

      assert has_element?(view, "#channel-card-#{channel1.id}")
      refute has_element?(view, "#channel-card-#{channel2.id}")

      # Search with no match -> shows empty state with Reset filters button
      view
      |> form("#channels-search-form", %{"search" => "nonexistent-ring"})
      |> render_change()

      assert has_element?(view, "#channels-empty-state", "No channels match your current filters")

      view
      |> element("#clear-channel-filters-btn")
      |> render_click()

      assert has_element?(view, "#channel-card-#{channel1.id}")
      assert has_element?(view, "#channel-card-#{channel2.id}")

      # 7. Assign unassigned_group to channel2 via PubSub -> Empty Ring warning
      # clears and unassigned tray shows all assigned
      _unassigned_group =
        Ash.update!(unassigned_group, %{channel_id: channel2.id},
          action: :assign_channel,
          tenant: tenant,
          authorize?: false
        )

      _ = render(view)

      assert has_element?(view, "#stat-assigned-groups", "3")
      assert has_element?(view, "#stat-unassigned-groups", "0 unassigned")
      refute has_element?(view, "#stat-empty-channels-warning")

      assert has_element?(
               view,
               "#channel-card-#{channel2.id} [data-group-handle='staging-cohort']",
               "Staging Cohort"
             )

      assert has_element?(
               view,
               "#all-groups-assigned-notice",
               "All device groups in this tenant are assigned to a rollout channel."
             )

      # 8. Create a campaign on channel1 -> Active Rollouts increments and campaign strip updates in real time
      campaign =
        CampaignsFixtures.campaign_fixture(
          tenant: tenant,
          name: "OTA v2.4.0 Rollout",
          channel_id: channel1.id,
          mechanism_type: :file_download
        )

      _ = render(view)

      assert has_element?(view, "#stat-active-rollouts", "1")

      assert has_element?(
               view,
               "#channel-card-#{channel1.id} [data-role='channel-status-badge']",
               "Active Rollout"
             )

      assert has_element?(
               view,
               "#channel-card-#{channel1.id} [data-role='latest-campaign-name']",
               "OTA v2.4.0 Rollout"
             )

      assert has_element?(
               view,
               "#channel-card-#{channel1.id} [data-role='latest-campaign-status']",
               "Starting"
             )

      # Transition campaign to in_progress and then finished (successful)
      campaign =
        Ash.update!(campaign, %{},
          action: :mark_as_in_progress,
          tenant: tenant,
          authorize?: false
        )

      _ = render(view)

      assert has_element?(
               view,
               "#channel-card-#{channel1.id} [data-role='latest-campaign-status']",
               "In Progress"
             )

      _campaign =
        Ash.update!(campaign, %{},
          action: :mark_as_successful,
          tenant: tenant,
          authorize?: false
        )

      _ = render(view)

      assert has_element?(view, "#stat-active-rollouts", "0")

      assert has_element?(
               view,
               "#channel-card-#{channel1.id} [data-role='channel-status-badge']",
               "Ready"
             )

      assert has_element?(
               view,
               "#channel-card-#{channel1.id} [data-role='latest-campaign-status']",
               "Succeeded"
             )

      # 9. Destroy channel2 -> removes card and updates total channels counter
      _ = Ash.destroy!(channel2, tenant: tenant, authorize?: false)

      _ = render(view)

      assert has_element?(view, "#stat-total-channels", "1")
      refute has_element?(view, "#channel-card-#{channel2.id}")

      # Verify device1 variable is used
      assert device1.id != device2.id
    end
  end
end
