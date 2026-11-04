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

defmodule EdgehogWeb.DevicesLive.IndexTest do
  use EdgehogWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Edgehog.DevicesFixtures
  alias EdgehogWeb.Auth.Token
  alias EdgehogWeb.LiveAuth

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

  describe "live-updating devices index and cell LiveComponents" do
    test "updates fleet stats and individual cell LiveComponents via granular PubSub topics",
         %{
           conn: conn,
           tenant: tenant,
           tenant_private_key: tenant_private_key
         } do
      jwt = generate_jwt(tenant_private_key)

      device1 =
        DevicesFixtures.device_fixture(
          tenant: tenant,
          name: "Gateway One",
          online: true,
          last_connection: ~U[2026-10-21 10:00:00Z]
        )

      conn =
        post(conn, ~p"/session", %{
          "session" => %{"tenant_slug" => tenant.slug, "auth_token" => jwt}
        })

      {:ok, devices_view, html} = live(recycle(conn), ~p"/tenants/#{tenant.slug}/devices")

      assert html =~ device1.name
      assert has_element?(devices_view, "#stat-total-devices", "1")
      assert has_element?(devices_view, "#stat-online-devices", "1")
      assert has_element?(devices_view, "#stat-offline-devices", "0")
      assert has_element?(devices_view, "#device-status-#{device1.id} [data-status='online']")
      assert has_element?(devices_view, "#device-name-#{device1.id}", "Gateway One")
      assert has_element?(devices_view, "#device-last-seen-#{device1.id}", "2026-10-21 10:00 UTC")

      # Provision a new online device while the LiveView is mounted
      device2 =
        DevicesFixtures.device_fixture(tenant: tenant, name: "Edge Sensor Two", online: true)

      _ = render(devices_view)
      updated_html = render_async(devices_view)
      assert updated_html =~ device2.name
      assert has_element?(devices_view, "#stat-total-devices", "2")
      assert has_element?(devices_view, "#stat-online-devices", "2")

      # 1. Transition device1 to offline via :from_device_status when last_connection is already set ->
      # updates StatusCellComponent, LastSeenCellComponent (selecting the newer last_disconnection),
      # and FleetStatsComponent
      Ash.update!(
        device1,
        %{online: false, last_disconnection: ~U[2026-10-21 15:30:00Z]},
        action: :from_device_status,
        tenant: tenant
      )

      _ = render(devices_view)
      assert has_element?(devices_view, "#device-status-#{device1.id} [data-status='offline']")
      assert has_element?(devices_view, "#device-last-seen-#{device1.id}", "2026-10-21 15:30 UTC")
      assert has_element?(devices_view, "#stat-online-devices", "1")
      assert has_element?(devices_view, "#stat-offline-devices", "1")

      # 2. Rename device1 via :update -> updates NameCellComponent via "devices:name:<id>"
      Ash.update!(device1, %{name: "Gateway One Renamed"},
        action: :update,
        tenant: tenant,
        authorize?: false
      )

      _ = render(devices_view)
      assert has_element?(devices_view, "#device-name-#{device1.id}", "Gateway One Renamed")

      # 3. Add tags to device1 via :add_tags -> updates TagsCellComponent via "devices:tags:<id>"
      Ash.update!(device1, %{tags: ["production", "eu-west"]},
        action: :add_tags,
        tenant: tenant,
        authorize?: false
      )

      _ = render(devices_view)
      assert has_element?(devices_view, "#device-tags-#{device1.id}", "production")
      assert has_element?(devices_view, "#device-tags-#{device1.id}", "eu-west")
    end

    test "renders navigation left dock, contextual bottom dock, and floating corner controls",
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

      {:ok, devices_view, _html} = live(recycle(conn), ~p"/tenants/#{tenant.slug}/devices")

      # Primary left dock renders all 5 sections with Fleet active and hero-server-stack icon
      assert has_element?(devices_view, "#primary-nav-dock")
      assert has_element?(devices_view, "#nav-section-fleet[data-active='true']", "Fleet")
      assert has_element?(devices_view, "#nav-section-fleet span.hero-server-stack")
      assert has_element?(devices_view, "#nav-section-files[data-active='false']", "Files")
      assert has_element?(devices_view, "#nav-section-ota[data-active='false']", "OTA Updates")
      assert has_element?(devices_view, "#nav-section-apps[data-active='false']", "Apps")

      assert has_element?(
               devices_view,
               "#nav-section-campaigns[data-active='false']",
               "Campaigns"
             )

      # Secondary contextual bottom dock renders Fleet sub-items with Devices active
      assert has_element?(devices_view, "#secondary-nav-dock[data-section='fleet']")
      assert has_element?(devices_view, "#nav-subitem-devices[data-active='true']", "Devices")

      assert has_element?(
               devices_view,
               "#nav-subitem-device_groups[data-active='false']",
               "Groups"
             )

      assert has_element?(
               devices_view,
               "#nav-subitem-channels[data-active='false']",
               "Channels"
             )

      assert has_element?(
               devices_view,
               "#nav-subitem-system_models[data-active='false']",
               "System Models"
             )

      assert has_element?(
               devices_view,
               "#nav-subitem-hardware_types[data-active='false']",
               "Hardware Types"
             )

      # Floating corner pills: top-right tenant badge, bottom-left theme selector, bottom-right sign-out
      assert has_element?(devices_view, "#tenant-badge-pill", tenant.slug)
      assert has_element?(devices_view, "#theme-selector-pill #navbar-theme-selector")
      assert has_element?(devices_view, "#sign-out-pill #nav-sign-out-button", "Sign out")

      # Collapsible dock controls dispatch phx:set-left-dock and keep #app-main-content stationary
      assert has_element?(
               devices_view,
               "#nav-dock-collapse-button[phx-click*='phx:set-left-dock']"
             )

      assert has_element?(
               devices_view,
               "#nav-dock-open-button[phx-click*='phx:set-left-dock']"
             )

      assert has_element?(devices_view, "#app-main-content")
      refute has_element?(devices_view, "#app-main-content.md\\:pl-32")

      # Verify route segment resolution for all top-level sections and sub-items
      assert LiveAuth.resolve_active_navigation("/tenants/acme/devices") == {:fleet, :devices}

      assert LiveAuth.resolve_active_navigation("/tenants/acme/device-groups") ==
               {:fleet, :device_groups}

      assert LiveAuth.resolve_active_navigation("/tenants/acme/channels") ==
               {:fleet, :channels}

      assert LiveAuth.resolve_active_navigation("/tenants/acme/system-models") ==
               {:fleet, :system_models}

      assert LiveAuth.resolve_active_navigation("/tenants/acme/hardware-types") ==
               {:fleet, :hardware_types}

      assert LiveAuth.resolve_active_navigation("/tenants/acme/repositories") ==
               {:files, :repositories}

      assert LiveAuth.resolve_active_navigation("/tenants/acme/base-image-collections") ==
               {:ota, :base_image_collections}

      assert LiveAuth.resolve_active_navigation("/tenants/acme/applications") ==
               {:apps, :applications}

      assert LiveAuth.resolve_active_navigation("/tenants/acme/containers") ==
               {:apps, :containers}

      assert LiveAuth.resolve_active_navigation("/tenants/acme/deployments") ==
               {:apps, :deployments}

      assert LiveAuth.resolve_active_navigation("/tenants/acme/image-credentials") ==
               {:apps, :image_credentials}

      assert LiveAuth.resolve_active_navigation("/tenants/acme/volumes") ==
               {:apps, :volumes}

      assert LiveAuth.resolve_active_navigation("/tenants/acme/networks") ==
               {:apps, :networks}

      assert LiveAuth.resolve_active_navigation("/tenants/acme/update-campaigns") ==
               {:campaigns, :update_campaigns}

      assert LiveAuth.resolve_active_navigation("/tenants/acme/deployment-campaigns") ==
               {:campaigns, :deployment_campaigns}

      assert LiveAuth.resolve_active_navigation("/tenants/acme/file-download-campaigns") ==
               {:campaigns, :file_download_campaigns}
    end
  end
end
