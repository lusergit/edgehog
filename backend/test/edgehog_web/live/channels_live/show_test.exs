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

defmodule EdgehogWeb.ChannelsLive.ShowTest do
  use EdgehogWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Edgehog.CampaignsFixtures
  alias Edgehog.DevicesFixtures
  alias Edgehog.Groups.DeviceGroup
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

  describe "channel detail page, edit floating pill drawer, and delete modal" do
    test "renders 3-card inspector, deduplicated devices table, edits target groups, and handles live PubSub updates",
         %{
           conn: conn,
           tenant: tenant,
           tenant_private_key: tenant_private_key
         } do
      jwt = generate_jwt(tenant_private_key)

      device1 =
        [tenant: tenant, name: "Gateway Ring-1", online: true]
        |> DevicesFixtures.device_fixture()
        |> DevicesFixtures.add_tags(["eu", "prod"])

      device2 =
        [tenant: tenant, name: "Gateway Ring-2", online: false]
        |> DevicesFixtures.device_fixture()
        |> DevicesFixtures.add_tags(["us"])

      group1 =
        GroupsFixtures.device_group_fixture(
          tenant: tenant,
          name: "EU Ring Group",
          handle: "eu-ring-group",
          selector: ~s<"eu" in tags>
        )

      group2 =
        GroupsFixtures.device_group_fixture(
          tenant: tenant,
          name: "Prod Ring Group",
          handle: "prod-ring-group",
          selector: ~s<"prod" in tags>
        )

      group3 =
        GroupsFixtures.device_group_fixture(
          tenant: tenant,
          name: "US Ring Group",
          handle: "us-ring-group",
          selector: ~s<"us" in tags>
        )

      channel =
        CampaignsFixtures.channel_fixture(
          tenant: tenant,
          name: "Core Fleet Ring",
          handle: "core-fleet",
          target_group_ids: [group1.id, group2.id]
        )

      conn =
        post(conn, ~p"/session", %{
          "session" => %{"tenant_slug" => tenant.slug, "auth_token" => jwt}
        })

      {:ok, view, _html} = live(recycle(conn), ~p"/tenants/#{tenant.slug}/channels/#{channel.id}")

      # 1. Header and 3-Card Inspector Strip
      assert has_element?(view, "#channel-detail-name", "Core Fleet Ring")
      assert has_element?(view, "#channel-detail-handle", "@core-fleet")
      assert has_element?(view, "#channel-inspector-strip [data-role='target-groups-count']", "2")

      assert has_element?(
               view,
               "#channel-inspector-strip [data-role='channel-total-devices']",
               "1"
             )

      assert has_element?(
               view,
               "#channel-inspector-strip [data-role='channel-online-devices']",
               "1 online"
             )

      assert has_element?(view, "#channel-inspector-strip [data-role='no-campaigns']")

      # 2. Reachable Devices Cinder Table shows device1 (deduplicated) and not device2
      assert has_element?(view, "#device-name-#{device1.id}", "Gateway Ring-1")
      refute has_element?(view, "#device-name-#{device2.id}")

      # 3. Open Edit Floating Pill Drawer and add group3
      view
      |> element("#edit-channel-btn")
      |> render_click()

      assert_patch(view, ~p"/tenants/#{tenant.slug}/channels/#{channel.id}/edit")
      assert has_element?(view, "#edit-channel-drawer[aria-modal='false']")

      assert has_element?(
               view,
               "#edit-channel-drawer-panel.rounded-3xl.animate-floating-pill-right"
             )

      view
      |> element("#picker-group-#{group3.id}")
      |> render_click()

      assert has_element?(view, "#channel-live-preview [data-role='channel-total-devices']", "2")

      view
      |> form("#channel-form", %{
        "channel" => %{"name" => "Global Fleet Ring", "handle" => "global-fleet"}
      })
      |> render_submit()

      assert_patch(view, ~p"/tenants/#{tenant.slug}/channels/#{channel.id}")
      _ = render(view)
      updated_html = render_async(view)

      assert has_element?(view, "#channel-detail-name", "Global Fleet Ring")
      assert has_element?(view, "#channel-detail-handle", "@global-fleet")
      assert has_element?(view, "#channel-inspector-strip [data-role='target-groups-count']", "3")

      assert has_element?(
               view,
               "#channel-inspector-strip [data-role='channel-total-devices']",
               "2"
             )

      assert updated_html =~ "Gateway Ring-2"

      # 4. Real-time PubSub update when device2 comes online
      _device2 =
        Ash.update!(device2, %{online: true},
          action: :from_device_status,
          tenant: tenant,
          authorize?: false
        )

      _ = render(view)

      assert has_element?(
               view,
               "#channel-inspector-strip [data-role='channel-online-devices']",
               "2 online"
             )

      assert device1.id != device2.id
    end

    test "blocks deleting a channel referenced by a campaign and deletes an unreferenced channel while keeping groups intact",
         %{
           conn: conn,
           tenant: tenant,
           tenant_private_key: tenant_private_key
         } do
      jwt = generate_jwt(tenant_private_key)

      group =
        GroupsFixtures.device_group_fixture(
          tenant: tenant,
          name: "Protected Group",
          handle: "protected-group",
          selector: ~s<"eu" in tags>
        )

      channel_with_campaign =
        CampaignsFixtures.channel_fixture(
          tenant: tenant,
          name: "Campaign Ring",
          handle: "campaign-ring",
          target_group_ids: [group.id]
        )

      _campaign =
        CampaignsFixtures.campaign_fixture(
          tenant: tenant,
          name: "Scheduled Delivery",
          channel_id: channel_with_campaign.id,
          mechanism_type: :file_download
        )

      deletable_group =
        GroupsFixtures.device_group_fixture(
          tenant: tenant,
          name: "Temporary Group",
          handle: "temp-group",
          selector: ~s<"temp" in tags>
        )

      deletable_channel =
        CampaignsFixtures.channel_fixture(
          tenant: tenant,
          name: "Ephemeral Ring",
          handle: "ephemeral-ring",
          target_group_ids: [deletable_group.id]
        )

      conn =
        post(conn, ~p"/session", %{
          "session" => %{"tenant_slug" => tenant.slug, "auth_token" => jwt}
        })

      # 1. Channel with campaign shows blocker in DeleteChannelModalComponent
      {:ok, blocked_view, _html} =
        live(recycle(conn), ~p"/tenants/#{tenant.slug}/channels/#{channel_with_campaign.id}")

      blocked_view
      |> element("#delete-channel-btn")
      |> render_click()

      assert has_element?(blocked_view, "#delete-channel-campaigns-blocker")
      assert has_element?(blocked_view, "#confirm-delete-channel-btn[disabled]")

      blocked_view
      |> element("#cancel-delete-channel-btn")
      |> render_click()

      refute has_element?(blocked_view, "#delete-channel-modal")

      # 2. Deletable channel shows unassigned groups notice and deletes cleanly
      {:ok, delete_view, _html} =
        live(recycle(conn), ~p"/tenants/#{tenant.slug}/channels/#{deletable_channel.id}")

      delete_view
      |> element("#delete-channel-btn")
      |> render_click()

      assert has_element?(
               delete_view,
               "#delete-channel-groups-notice",
               "will become unassigned"
             )

      delete_view
      |> element("#confirm-delete-channel-btn")
      |> render_click()

      assert_redirect(delete_view, ~p"/tenants/#{tenant.slug}/channels")

      {:ok, index_view, _html} = live(recycle(conn), ~p"/tenants/#{tenant.slug}/channels")

      refute has_element?(index_view, "#channel-card-#{deletable_channel.id}")

      assert has_element?(
               index_view,
               "#unassigned-group-#{deletable_group.id}",
               "Temporary Group"
             )

      # Verify deletable_group still exists in DB with channel_id == nil
      reloaded_group =
        Ash.get!(DeviceGroup, deletable_group.id, tenant: tenant, authorize?: false)

      assert is_nil(reloaded_group.channel_id)
    end
  end
end
