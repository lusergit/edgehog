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

defmodule EdgehogWeb.DeviceGroupsLive.ShowTest do
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

  describe "device group detail show page, live cohort table, edit drawer, and delete modal" do
    test "renders cohort inspector strip and matched devices table with live PubSub updates",
         %{
           conn: conn,
           tenant: tenant,
           tenant_private_key: tenant_private_key
         } do
      jwt = generate_jwt(tenant_private_key)

      device1 =
        [tenant: tenant, name: "Gateway Alpha", online: true]
        |> DevicesFixtures.device_fixture()
        |> DevicesFixtures.add_tags(["fleet-a"])

      device2 =
        DevicesFixtures.device_fixture(
          tenant: tenant,
          name: "Gateway Beta",
          online: true
        )

      group =
        GroupsFixtures.device_group_fixture(
          tenant: tenant,
          name: "Alpha Cohort",
          handle: "alpha-cohort",
          selector: ~s("fleet-a" in tags)
        )

      conn =
        post(conn, ~p"/session", %{
          "session" => %{"tenant_slug" => tenant.slug, "auth_token" => jwt}
        })

      {:ok, show_view, html} =
        live(recycle(conn), ~p"/tenants/#{tenant.slug}/device-groups/#{group.id}")

      assert html =~ "Gateway Alpha"
      refute html =~ "Gateway Beta"

      assert has_element?(show_view, "#group-detail-name", "Alpha Cohort")
      assert has_element?(show_view, "#group-detail-handle", "@alpha-cohort")

      assert has_element?(
               show_view,
               "#group-detail-fleet-#{group.id} [data-fleet-state='active']",
               "1 / 1 online"
             )

      assert has_element?(
               show_view,
               "#group-detail-selector-#{group.id} [data-selector-token='tag-filter']",
               "fleet-a"
             )

      assert has_element?(
               show_view,
               "#group-detail-channel-#{group.id} [data-channel='unassigned']",
               "Unassigned"
             )

      assert has_element?(show_view, "#device-status-#{device1.id} [data-status='online']")

      # Transition device1 offline -> updates both device row cell and cohort fleet card
      Ash.update!(device1, %{online: false},
        action: :from_device_status,
        tenant: tenant,
        authorize?: false
      )

      _ = render(show_view)
      assert has_element?(show_view, "#device-status-#{device1.id} [data-status='offline']")

      assert has_element?(
               show_view,
               "#group-detail-fleet-#{group.id} [data-fleet-state='active']",
               "0 / 1 online"
             )

      # Tag device2 with "fleet-a" -> joins the group table and updates cohort count to 1 / 2 online
      Ash.update!(device2, %{tags: ["fleet-a"]},
        action: :add_tags,
        tenant: tenant,
        authorize?: false
      )

      _ = render(show_view)
      updated_html = render_async(show_view)
      assert updated_html =~ "Gateway Beta"

      assert has_element?(
               show_view,
               "#group-detail-fleet-#{group.id} [data-fleet-state='active']",
               "1 / 2 online"
             )
    end

    test "edits group attributes and switches rollout channel via the slide-over edit drawer",
         %{
           conn: conn,
           tenant: tenant,
           tenant_private_key: tenant_private_key
         } do
      jwt = generate_jwt(tenant_private_key)

      group =
        GroupsFixtures.device_group_fixture(
          tenant: tenant,
          name: "Initial Group",
          handle: "initial-group",
          selector: ~s("v1" in tags)
        )

      channel1 =
        CampaignsFixtures.channel_fixture(
          tenant: tenant,
          name: "Alpha Channel",
          handle: "alpha-channel",
          target_group_ids: [group.id]
        )

      channel2 =
        CampaignsFixtures.channel_fixture(
          tenant: tenant,
          name: "Beta Channel",
          handle: "beta-channel",
          target_group_ids: []
        )

      conn =
        post(conn, ~p"/session", %{
          "session" => %{"tenant_slug" => tenant.slug, "auth_token" => jwt}
        })

      {:ok, show_view, _html} =
        live(recycle(conn), ~p"/tenants/#{tenant.slug}/device-groups/#{group.id}")

      assert has_element?(
               show_view,
               "#group-detail-channel-#{group.id} [data-channel='#{channel1.handle}']",
               "Alpha Channel"
             )

      # Open the slide-over edit drawer
      show_view
      |> element("#edit-device-group-btn")
      |> render_click()

      assert_patch(show_view, ~p"/tenants/#{tenant.slug}/device-groups/#{group.id}/edit")
      assert has_element?(show_view, "#edit-device-group-drawer[aria-modal='false']")

      assert has_element?(
               show_view,
               "#edit-device-group-drawer-panel.rounded-3xl.animate-floating-pill-right"
             )

      # Update name, handle, selector, and switch from channel1 to channel2
      show_view
      |> form("#device-group-form", %{
        "group" => %{
          "name" => "Renamed Group",
          "handle" => "renamed-group",
          "channel_id" => to_string(channel2.id),
          "selector" => ~s("v2" in tags)
        }
      })
      |> render_submit()

      assert_patch(show_view, ~p"/tenants/#{tenant.slug}/device-groups/#{group.id}")
      _ = render(show_view)

      assert has_element?(show_view, "#group-detail-name", "Renamed Group")
      assert has_element?(show_view, "#group-detail-handle", "@renamed-group")
      assert has_element?(show_view, "#group-detail-raw-selector", ~s("v2" in tags))

      assert has_element?(
               show_view,
               "#group-detail-channel-#{group.id} [data-channel='#{channel2.handle}']",
               "Beta Channel"
             )
    end

    test "deletes a channel-linked group via the confirmation modal and redirects to index",
         %{
           conn: conn,
           tenant: tenant,
           tenant_private_key: tenant_private_key
         } do
      jwt = generate_jwt(tenant_private_key)

      group =
        GroupsFixtures.device_group_fixture(
          tenant: tenant,
          name: "Disposable Group",
          handle: "disposable-group",
          selector: ~s("temp" in tags)
        )

      _channel =
        CampaignsFixtures.channel_fixture(
          tenant: tenant,
          name: "Linked Channel",
          handle: "linked-channel",
          target_group_ids: [group.id]
        )

      conn =
        post(conn, ~p"/session", %{
          "session" => %{"tenant_slug" => tenant.slug, "auth_token" => jwt}
        })

      {:ok, show_view, _html} =
        live(recycle(conn), ~p"/tenants/#{tenant.slug}/device-groups/#{group.id}")

      show_view
      |> element("#delete-device-group-btn")
      |> render_click()

      assert has_element?(show_view, "#delete-group-modal")
      assert has_element?(show_view, "#delete-group-channel-warning", "Linked Channel")

      show_view
      |> element("#confirm-delete-group-btn")
      |> render_click()

      assert_redirect(show_view, ~p"/tenants/#{tenant.slug}/device-groups")

      assert {:error, _} =
               Ash.get(DeviceGroup, group.id, tenant: tenant, authorize?: false)
    end

    test "redirects to groups index when navigating to a non-existent group ID",
         %{
           conn: conn,
           tenant: tenant,
           tenant_private_key: tenant_private_key
         } do
      jwt = generate_jwt(tenant_private_key)

      conn =
        post(conn, ~p"/session", %{
          "session" => %{"tenant_slug" => tenant.slug, "auth_token" => jwt}
        })

      assert {:error, {:live_redirect, %{to: to_path}}} =
               live(recycle(conn), ~p"/tenants/#{tenant.slug}/device-groups/999999")

      assert to_path == ~p"/tenants/#{tenant.slug}/device-groups"
    end
  end
end
