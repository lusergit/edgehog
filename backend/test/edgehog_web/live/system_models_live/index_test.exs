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

defmodule EdgehogWeb.SystemModelsLive.IndexTest do
  use EdgehogWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Edgehog.DevicesFixtures
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

  describe "live-updating system models catalog Bento grid, KPI strip, filters, and unmapped tray" do
    test "renders catalog stats, Bento cards, 4-way search, filter pills, unmapped part numbers, and updates via PubSub",
         %{
           conn: conn,
           tenant: tenant,
           tenant_private_key: tenant_private_key
         } do
      jwt = generate_jwt(tenant_private_key)

      ht_pi5 =
        DevicesFixtures.hardware_type_fixture(
          tenant: tenant,
          name: "Strawberry Pi 5",
          handle: "strawberry-pi-5",
          part_numbers: ["STBEPI-5-REV1"]
        )

      ht_imx8 =
        DevicesFixtures.hardware_type_fixture(
          tenant: tenant,
          name: "i.MX8M Industrial",
          handle: "imx8m-industrial",
          part_numbers: ["IMX8M-REV2"]
        )

      _ht_unused =
        DevicesFixtures.hardware_type_fixture(
          tenant: tenant,
          name: "Unused Board",
          handle: "unused-board",
          part_numbers: ["UNUSED-REV1"]
        )

      # Model 1: Has picture_url, localized description, 4 part numbers
      # (triggers +1 more overflow), and 2 matched devices
      model1 =
        DevicesFixtures.system_model_fixture(
          tenant: tenant,
          hardware_type_id: ht_pi5.id,
          name: "Connected E-Scooter 1",
          handle: "e-scooter-1",
          picture_url: "https://example.com/images/e-scooter-1.png",
          part_numbers: [
            "C-E-SCOOTER-1",
            "C-E-SCOOTER-1-PRO",
            "C-E-SCOOTER-1-LITE",
            "C-E-SCOOTER-1-MAX"
          ],
          localized_descriptions: [
            %{
              language_tag: tenant.default_locale,
              value: "High-mobility urban shared scooter with LTE telemetry."
            }
          ]
        )

      # Model 2: No picture_url, no description, 1 part number, 0 matched devices
      model2 =
        DevicesFixtures.system_model_fixture(
          tenant: tenant,
          hardware_type_id: ht_imx8.id,
          name: "Industrial Gateway v3",
          handle: "ind-gw-v3",
          part_numbers: ["GW-V3-A"]
        )

      # 2 devices matching model1 ("C-E-SCOOTER-1" and "C-E-SCOOTER-1-PRO")
      device1 =
        DevicesFixtures.device_fixture(
          tenant: tenant,
          name: "Scooter Milan 01",
          online: true,
          part_number: "C-E-SCOOTER-1"
        )

      device2 =
        DevicesFixtures.device_fixture(
          tenant: tenant,
          name: "Scooter Milan 02",
          online: false,
          part_number: "C-E-SCOOTER-1-PRO"
        )

      # 1 device reporting an unmapped part number ("ORPHAN-REV-1")
      _orphan_device =
        DevicesFixtures.device_fixture(
          tenant: tenant,
          name: "Prototype Board 99",
          online: true,
          part_number: "ORPHAN-REV-1"
        )

      conn =
        post(conn, ~p"/session", %{
          "session" => %{"tenant_slug" => tenant.slug, "auth_token" => jwt}
        })

      {:ok, view, _html} = live(recycle(conn), ~p"/tenants/#{tenant.slug}/system-models")

      # 1. Verify active Fleet / System Models dock highlights and Live PubSub badge
      assert has_element?(view, "#nav-section-fleet[data-active='true']")
      assert has_element?(view, "#nav-subitem-system_models[data-active='true']")
      assert has_element?(view, "#live-pubsub-indicator", "Live")

      # 2. Verify 4-band KPI strip (#system-models-stats)
      assert has_element?(view, "#stat-total-models", "2")
      assert has_element?(view, "#stat-hardware-types-covered", "2 / 3 hardware types")
      assert has_element?(view, "#stat-mapped-devices", "2")
      assert has_element?(view, "#stat-mapped-coverage-pct", "67%")
      assert has_element?(view, "#stat-online-mapped-devices", "1")
      assert has_element?(view, "#stat-online-mapped-pct", "50% online")
      assert has_element?(view, "#stat-total-part-numbers", "5")
      assert has_element?(view, "#stat-unmapped-part-numbers", "1 unmapped")

      # 3. Verify Model 1 Bento Card (picture, hardware type badge, localized
      # description, part numbers + overflow, fleet reach)
      assert has_element?(
               view,
               "#system-model-card-#{model1.id} [data-role='model-picture'][src='https://example.com/images/e-scooter-1.png']"
             )

      assert has_element?(
               view,
               "#system-model-card-#{model1.id} [data-role='model-name']",
               "Connected E-Scooter 1"
             )

      assert has_element?(
               view,
               "#system-model-card-#{model1.id} [data-role='model-handle']",
               "@e-scooter-1"
             )

      assert has_element?(
               view,
               "#system-model-card-#{model1.id} [data-role='model-hardware-type']",
               "Strawberry Pi 5"
             )

      assert has_element?(
               view,
               "#system-model-card-#{model1.id} [data-role='model-status-badge']",
               "Active Fleet"
             )

      assert has_element?(
               view,
               "#system-model-card-#{model1.id} [data-role='model-description']",
               "High-mobility urban shared scooter with LTE telemetry."
             )

      assert has_element?(
               view,
               "#system-model-card-#{model1.id} [data-role='model-description-locale']",
               tenant.default_locale
             )

      assert has_element?(
               view,
               "#system-model-card-#{model1.id} [data-role='part-numbers-count']",
               "4"
             )

      assert has_element?(
               view,
               "#system-model-card-#{model1.id} [data-part-number='C-E-SCOOTER-1'] [data-role='part-number-device-count']",
               "1"
             )

      assert has_element?(
               view,
               "#system-model-card-#{model1.id} [data-role='part-numbers-overflow']",
               "+1 more"
             )

      assert has_element?(
               view,
               "#system-model-card-#{model1.id} [data-role='model-total-devices']",
               "2"
             )

      assert has_element?(
               view,
               "#system-model-card-#{model1.id} [data-role='model-online-devices']",
               "1 online"
             )

      assert has_element?(
               view,
               "#system-model-card-#{model1.id} [data-role='model-reach-pct']",
               "50% online"
             )

      # 4. Verify Model 2 Bento Card (placeholder icon, no description fallback, 0 devices)
      assert has_element?(
               view,
               "#system-model-card-#{model2.id} [data-role='model-picture-placeholder']"
             )

      assert has_element?(
               view,
               "#system-model-card-#{model2.id} [data-role='model-no-description']",
               "No product description provided."
             )

      assert has_element?(
               view,
               "#system-model-card-#{model2.id} [data-role='model-status-badge']",
               "No Devices"
             )

      assert has_element?(
               view,
               "#system-model-card-#{model2.id} [data-role='model-total-devices']",
               "0"
             )

      # 5. Verify Unmapped Device Part Numbers Discovery Tray
      assert has_element?(view, "#unmapped-part-numbers-count", "1")

      assert has_element?(
               view,
               "#unmapped-pn-ORPHAN-REV-1 [data-role='unmapped-pn-device-count']",
               "1 device (1 online)"
             )

      assert has_element?(
               view,
               "#unmapped-pn-ORPHAN-REV-1 [data-role='create-model-from-pn'][href*='part_number=ORPHAN-REV-1']"
             )

      # 6. Verify 4-way Search (by name, handle, hardware type, and part number)
      # 6a. Search by part number
      view
      |> form("#system-models-search-form", %{"search" => "C-E-SCOOTER-1-MAX"})
      |> render_change()

      assert has_element?(view, "#system-model-card-#{model1.id}")
      refute has_element?(view, "#system-model-card-#{model2.id}")

      # 6b. Search by hardware type name
      view
      |> form("#system-models-search-form", %{"search" => "i.MX8M"})
      |> render_change()

      refute has_element?(view, "#system-model-card-#{model1.id}")
      assert has_element?(view, "#system-model-card-#{model2.id}")

      # 6c. Search with no match -> shows empty state and reset button
      view
      |> form("#system-models-search-form", %{"search" => "nonexistent-part-number"})
      |> render_change()

      assert has_element?(
               view,
               "#system-models-empty-state",
               "No system models match your current filters"
             )

      view
      |> element("#clear-system-model-filters-btn")
      |> render_click()

      assert has_element?(view, "#system-model-card-#{model1.id}")
      assert has_element?(view, "#system-model-card-#{model2.id}")

      # 7. Verify Quick Filter Pills & Hardware Type Filter
      view
      |> element("#system-models-filter-pills button[data-filter='no_picture']")
      |> render_click()

      refute has_element?(view, "#system-model-card-#{model1.id}")
      assert has_element?(view, "#system-model-card-#{model2.id}")

      # Filter-safe PubSub check: update device2 online status while model1 is filtered out
      device2 =
        Ash.update!(device2, %{online: true},
          action: :from_device_status,
          tenant: tenant,
          authorize?: false
        )

      _ = render(view)

      assert has_element?(view, "#stat-online-mapped-devices", "2")
      assert has_element?(view, "#stat-online-mapped-pct", "100% online")
      refute has_element?(view, "#system-model-card-#{model1.id}")

      # Switch to "active_fleet" filter -> model1 is visible with 2 online (100% online)
      view
      |> element("#system-models-filter-pills button[data-filter='active_fleet']")
      |> render_click()

      assert has_element?(view, "#system-model-card-#{model1.id}")
      refute has_element?(view, "#system-model-card-#{model2.id}")

      assert has_element?(
               view,
               "#system-model-card-#{model1.id} [data-role='model-online-devices']",
               "2 online"
             )

      assert has_element?(
               view,
               "#system-model-card-#{model1.id} [data-role='model-reach-pct']",
               "100% online"
             )

      # Reset to "all" and filter by Hardware Type dropdown
      view
      |> element("#system-models-filter-pills button[data-filter='all']")
      |> render_click()

      view
      |> form("#system-models-hardware-type-filter", %{"hardware_type_id" => to_string(ht_pi5.id)})
      |> render_change()

      assert has_element?(view, "#system-model-card-#{model1.id}")
      refute has_element?(view, "#system-model-card-#{model2.id}")

      view
      |> form("#system-models-hardware-type-filter", %{"hardware_type_id" => ""})
      |> render_change()

      # 8. Real-time Ash PubSub: create a new SystemModel claiming "ORPHAN-REV-1"
      model3 =
        DevicesFixtures.system_model_fixture(
          tenant: tenant,
          hardware_type_id: ht_pi5.id,
          name: "Prototype Scooter v2",
          handle: "proto-scooter-v2",
          part_numbers: ["ORPHAN-REV-1"]
        )

      _ = render(view)

      assert has_element?(view, "#stat-total-models", "3")
      assert has_element?(view, "#stat-mapped-devices", "3")
      assert has_element?(view, "#stat-mapped-coverage-pct", "100%")
      refute has_element?(view, "#stat-unmapped-part-numbers")

      assert has_element?(
               view,
               "#system-model-card-#{model3.id} [data-role='model-name']",
               "Prototype Scooter v2"
             )

      assert has_element?(
               view,
               "#all-part-numbers-mapped-notice",
               "All device part numbers in this tenant are mapped to a System Model."
             )

      # 9. Destroy model2 -> removes card and updates total models counter
      _ = Ash.destroy!(model2, tenant: tenant, authorize?: false)

      _ = render(view)

      assert has_element?(view, "#stat-total-models", "2")
      refute has_element?(view, "#system-model-card-#{model2.id}")

      assert device1.id != device2.id
    end
  end
end
