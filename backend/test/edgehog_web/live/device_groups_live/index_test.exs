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

defmodule EdgehogWeb.DeviceGroupsLive.IndexTest do
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

  describe "live-updating device groups index and cell LiveComponents" do
    test "renders group stats, tokenized selectors, and updates cells via granular PubSub topics",
         %{
           conn: conn,
           tenant: tenant,
           tenant_private_key: tenant_private_key
         } do
      jwt = generate_jwt(tenant_private_key)

      device1 =
        [tenant: tenant, name: "Gateway EU-1", online: true]
        |> DevicesFixtures.device_fixture()
        |> DevicesFixtures.add_tags(["eu-west", "production"])

      device2 =
        DevicesFixtures.device_fixture(
          tenant: tenant,
          name: "Gateway US-1",
          online: false
        )

      group1 =
        GroupsFixtures.device_group_fixture(
          tenant: tenant,
          name: "EU Production Gateways",
          handle: "eu-prod-gateways",
          selector: ~s<"eu-west" in tags and "production" in tags>
        )

      group2 =
        GroupsFixtures.device_group_fixture(
          tenant: tenant,
          name: "Staging Fleet",
          handle: "staging-fleet",
          selector: ~s<"staging" in tags>
        )

      conn =
        post(conn, ~p"/session", %{
          "session" => %{"tenant_slug" => tenant.slug, "auth_token" => jwt}
        })

      {:ok, groups_view, html} = live(recycle(conn), ~p"/tenants/#{tenant.slug}/device-groups")

      assert html =~ group1.name
      assert html =~ group2.name

      # Navigation dock highlights Fleet -> Groups
      assert has_element?(groups_view, "#nav-section-fleet[data-active='true']", "Fleet")

      assert has_element?(
               groups_view,
               "#nav-subitem-device_groups[data-active='true']",
               "Groups"
             )

      # Summary strip counters: 2 total groups, 0 linked, 1 empty, 50% fleet coverage (1 of 2 devices)
      assert has_element?(groups_view, "#stat-total-groups", "2")
      assert has_element?(groups_view, "#stat-linked-groups", "0")
      assert has_element?(groups_view, "#stat-empty-groups", "1")
      assert has_element?(groups_view, "#stat-fleet-coverage-pct", "50%")

      # Identity, tokenized selector, matched fleet, and unassigned channel cells
      assert has_element?(groups_view, "#group-identity-#{group1.id}", "EU Production Gateways")
      assert has_element?(groups_view, "#group-identity-#{group1.id}", "@eu-prod-gateways")
      assert has_element?(groups_view, "#group-selector-#{group1.id} [data-selector-op='AND']")
      assert has_element?(groups_view, "#group-selector-#{group1.id}", "eu-west")
      assert has_element?(groups_view, "#group-selector-#{group1.id}", "production")

      assert has_element?(
               groups_view,
               "#group-fleet-#{group1.id} [data-fleet-state='active']",
               "1 / 1 online"
             )

      assert has_element?(
               groups_view,
               "#group-fleet-#{group2.id} [data-fleet-state='empty']",
               "0 devices"
             )

      assert has_element?(
               groups_view,
               "#group-channel-#{group1.id} [data-channel='unassigned']",
               "Unassigned"
             )

      # 1. Rename group1 and update handle -> updates IdentityCellComponent in place
      group1 =
        Ash.update!(group1, %{name: "EU Core Gateways", handle: "eu-core-gateways"},
          action: :update,
          tenant: tenant,
          authorize?: false
        )

      _ = render(groups_view)
      assert has_element?(groups_view, "#group-identity-#{group1.id}", "EU Core Gateways")
      assert has_element?(groups_view, "#group-identity-#{group1.id}", "@eu-core-gateways")

      # 2. Assign group1 to a rollout Channel -> updates ChannelCellComponent and #stat-linked-groups
      _channel =
        CampaignsFixtures.channel_fixture(
          tenant: tenant,
          name: "Stable Channel",
          handle: "stable",
          target_group_ids: [group1.id]
        )

      _ = render(groups_view)

      assert has_element?(
               groups_view,
               "#group-channel-#{group1.id} [data-channel='stable']",
               "Stable Channel"
             )

      assert has_element?(groups_view, "#stat-linked-groups", "1")

      # Unassign channel from group1 -> restores Unassigned badge and decrements #stat-linked-groups
      group1 =
        group1
        |> Ash.reload!(tenant: tenant, authorize?: false)
        |> Ash.update!(%{}, action: :unassign_channel, tenant: tenant, authorize?: false)

      _ = render(groups_view)

      assert has_element?(
               groups_view,
               "#group-channel-#{group1.id} [data-channel='unassigned']",
               "Unassigned"
             )

      assert has_element?(groups_view, "#stat-linked-groups", "0")

      # 3. Add "staging" tag to device2 -> updates group2's fleet cell from empty to active
      # and updates summary strip (#stat-empty-groups -> 0, #stat-fleet-coverage-pct -> 100%)
      Ash.update!(device2, %{tags: ["staging"]},
        action: :add_tags,
        tenant: tenant,
        authorize?: false
      )

      _ = render(groups_view)

      assert has_element?(
               groups_view,
               "#group-fleet-#{group2.id} [data-fleet-state='active']",
               "0 / 1 online"
             )

      assert has_element?(groups_view, "#stat-empty-groups", "0")
      assert has_element?(groups_view, "#stat-fleet-coverage-pct", "100%")

      # 4. Transition device1 offline via :from_device_status -> updates group1's online count
      Ash.update!(device1, %{online: false},
        action: :from_device_status,
        tenant: tenant,
        authorize?: false
      )

      _ = render(groups_view)

      assert has_element?(
               groups_view,
               "#group-fleet-#{group1.id} [data-fleet-state='active']",
               "0 / 1 online"
             )

      # 5. Update group2's selector -> updates SelectorCellComponent and GroupFleetCellComponent
      Ash.update!(group2, %{selector: ~s<"canary" not in tags>},
        action: :update,
        tenant: tenant,
        authorize?: false
      )

      _ = render(groups_view)
      assert has_element?(groups_view, "#group-selector-#{group2.id}", "canary")
      assert has_element?(groups_view, "#group-selector-#{group2.id}", "not in tags")

      assert has_element?(
               groups_view,
               "#group-fleet-#{group2.id} [data-fleet-state='active']",
               "0 / 2 online"
             )

      # 6. Create a new group and destroy it -> refreshes table and #stat-total-groups
      group3 =
        GroupsFixtures.device_group_fixture(
          tenant: tenant,
          name: "Canary Edge Nodes",
          handle: "canary-edge",
          selector: ~s<"canary" in tags>
        )

      _ = render(groups_view)
      updated_html = render_async(groups_view)
      assert updated_html =~ group3.name
      assert has_element?(groups_view, "#stat-total-groups", "3")

      Ash.destroy!(group3, tenant: tenant, authorize?: false)

      _ = render(groups_view)
      _ = render_async(groups_view)
      assert has_element?(groups_view, "#stat-total-groups", "2")
    end

    test "renders tokenized AttributeFilter and nested BinaryOp selectors safely",
         %{
           conn: conn,
           tenant: tenant,
           tenant_private_key: tenant_private_key
         } do
      jwt = generate_jwt(tenant_private_key)

      group =
        GroupsFixtures.device_group_fixture(
          tenant: tenant,
          name: "Attribute Filtered Group",
          handle: "attr-filtered-group",
          selector:
            ~s<("pos" in tags or "neg" not in tags) and attributes["custom:env"] == "prod">
        )

      conn =
        post(conn, ~p"/session", %{
          "session" => %{"tenant_slug" => tenant.slug, "auth_token" => jwt}
        })

      {:ok, groups_view, _html} = live(recycle(conn), ~p"/tenants/#{tenant.slug}/device-groups")

      assert has_element?(
               groups_view,
               "#group-selector-#{group.id} [data-selector-token='tag-filter']",
               "pos"
             )

      assert has_element?(
               groups_view,
               "#group-selector-#{group.id} [data-selector-op='OR']",
               "OR"
             )

      assert has_element?(
               groups_view,
               "#group-selector-#{group.id} [data-selector-op='AND']",
               "AND"
             )

      assert has_element?(
               groups_view,
               "#group-selector-#{group.id} [data-selector-token='attribute-filter']",
               ~s(attributes["custom:env"])
             )

      assert has_element?(
               groups_view,
               "#group-fleet-#{group.id} [data-fleet-state='empty']",
               "0 devices"
             )
    end

    test "creates a device group via the slide-over drawer with live selector preview and tag chips",
         %{
           conn: conn,
           tenant: tenant,
           tenant_private_key: tenant_private_key
         } do
      jwt = generate_jwt(tenant_private_key)

      _device =
        [tenant: tenant, name: "Gateway EU-North-1", online: true]
        |> DevicesFixtures.device_fixture()
        |> DevicesFixtures.add_tags(["eu-north", "edge"])

      channel =
        CampaignsFixtures.channel_fixture(
          tenant: tenant,
          name: "Canary Rollout",
          handle: "canary-rollout",
          target_group_ids: []
        )

      conn =
        post(conn, ~p"/session", %{
          "session" => %{"tenant_slug" => tenant.slug, "auth_token" => jwt}
        })

      {:ok, groups_view, _html} = live(recycle(conn), ~p"/tenants/#{tenant.slug}/device-groups")

      # Open the slide-over creation drawer
      groups_view
      |> element("#create-device-group-btn")
      |> render_click()

      assert_patch(groups_view, ~p"/tenants/#{tenant.slug}/device-groups/new")
      assert has_element?(groups_view, "#new-device-group-drawer[aria-modal='false']")

      assert has_element?(
               groups_view,
               "#new-device-group-drawer-panel.rounded-3xl.animate-floating-pill-right"
             )

      assert has_element?(groups_view, "#selector-live-preview[data-preview-state='empty']")

      # Typing a name auto-derives the handle slug; invalid selector shows syntax error in preview
      groups_view
      |> form("#device-group-form", %{
        "group" => %{
          "name" => "Nordic Edge Gateways",
          "selector" => ~s("eu-north" in)
        }
      })
      |> render_change()

      assert has_element?(
               groups_view,
               "#device-group-form input[name='group[handle]'][value='nordic-edge-gateways']"
             )

      assert has_element?(groups_view, "#selector-live-preview[data-preview-state='invalid']")
      assert has_element?(groups_view, "#selector-preview-error")

      # Clear selector and click tenant tag chips to compose a valid selector
      groups_view
      |> form("#device-group-form", %{
        "group" => %{
          "name" => "Nordic Edge Gateways",
          "handle" => "nordic-edge-gateways",
          "selector" => ""
        }
      })
      |> render_change()

      groups_view
      |> element("button[data-tag-chip='eu-north']")
      |> render_click()

      assert has_element?(groups_view, "#selector-live-preview[data-preview-state='valid']")
      assert has_element?(groups_view, "#selector-preview-count", "1 / 1 online")
      assert has_element?(groups_view, "#selector-preview-samples", "Gateway EU-North-1")

      # Submit form with optional channel assignment -> navigates to the new group's detail page
      groups_view
      |> form("#device-group-form", %{
        "group" => %{
          "name" => "Nordic Edge Gateways",
          "handle" => "nordic-edge-gateways",
          "channel_id" => to_string(channel.id),
          "selector" => ~s("eu-north" in tags)
        }
      })
      |> render_submit()

      {redirect_path, _flash} = assert_redirect(groups_view)
      assert redirect_path =~ "/tenants/#{tenant.slug}/device-groups/"

      {:ok, show_view, _show_html} = live(recycle(conn), redirect_path)
      assert has_element?(show_view, "#group-detail-name", "Nordic Edge Gateways")
      assert has_element?(show_view, "#group-detail-handle", "@nordic-edge-gateways")
      assert has_element?(show_view, "[data-channel='canary-rollout']", "Canary Rollout")
    end
  end
end
