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

defmodule EdgehogWeb.SystemModelsLive.ShowTest do
  use EdgehogWeb.ConnCase, async: false
  use Mimic

  import Phoenix.LiveViewTest

  alias Edgehog.Assets.SystemModelPicture
  alias Edgehog.BaseImagesFixtures
  alias Edgehog.DevicesFixtures
  alias EdgehogWeb.Auth.Token

  setup do
    stub(SystemModelPicture, :delete, fn _, _ -> :ok end)
    :ok
  end

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

  describe "system model detail Show view, Cinder matched devices table, and real-time PubSub" do
    test "renders product hero, all part numbers, fleet reach, software compatibility, Cinder devices table, and updates via PubSub",
         %{
           conn: conn,
           tenant: tenant,
           tenant_private_key: tenant_private_key
         } do
      jwt = generate_jwt(tenant_private_key)

      ht =
        DevicesFixtures.hardware_type_fixture(
          tenant: tenant,
          name: "Strawberry Pi 5",
          handle: "strawberry-pi-5",
          part_numbers: ["STBEPI-5-REV1"]
        )

      model =
        DevicesFixtures.system_model_fixture(
          tenant: tenant,
          hardware_type_id: ht.id,
          name: "Connected E-Scooter 1",
          handle: "e-scooter-1",
          picture_url: "https://example.com/images/e-scooter-1.png",
          part_numbers: ["PN-SCOOT-1", "PN-SCOOT-2", "PN-SCOOT-3", "PN-SCOOT-4"],
          localized_descriptions: [
            %{
              language_tag: tenant.default_locale,
              value: "Urban scooter with dual battery telemetry."
            }
          ]
        )

      _collection =
        BaseImagesFixtures.base_image_collection_fixture(
          tenant: tenant,
          system_model_id: model.id,
          name: "Scooter OS Images",
          handle: "scooter-os"
        )

      device1 =
        DevicesFixtures.device_fixture(
          tenant: tenant,
          name: "Scooter Rome 01",
          online: true,
          part_number: "PN-SCOOT-1"
        )

      device2 =
        DevicesFixtures.device_fixture(
          tenant: tenant,
          name: "Scooter Rome 02",
          online: false,
          part_number: "PN-SCOOT-2"
        )

      other_device =
        DevicesFixtures.device_fixture(
          tenant: tenant,
          name: "Unrelated Gateway",
          online: true,
          part_number: "OTHER-GW-PN"
        )

      conn =
        post(conn, ~p"/session", %{
          "session" => %{"tenant_slug" => tenant.slug, "auth_token" => jwt}
        })

      {:ok, view, _html} =
        live(recycle(conn), ~p"/tenants/#{tenant.slug}/system-models/#{model.id}")

      _ = render_async(view)

      # 1. Verify Hero Product Header
      assert has_element?(
               view,
               "#system-model-detail-picture[src='https://example.com/images/e-scooter-1.png']"
             )

      assert has_element?(view, "#system-model-detail-name", "Connected E-Scooter 1")
      assert has_element?(view, "#system-model-detail-handle", "@e-scooter-1")
      assert has_element?(view, "#system-model-detail-hardware-type", "Strawberry Pi 5")

      assert has_element?(
               view,
               "#system-model-detail-description",
               "Urban scooter with dual battery telemetry."
             )

      # 2. Verify 3-Card Inspector Strip (all 4 part numbers shown without +N overflow)
      assert has_element?(view, "#system-model-inspector-strip [data-part-number='PN-SCOOT-1']")
      assert has_element?(view, "#system-model-inspector-strip [data-part-number='PN-SCOOT-2']")
      assert has_element?(view, "#system-model-inspector-strip [data-part-number='PN-SCOOT-3']")
      assert has_element?(view, "#system-model-inspector-strip [data-part-number='PN-SCOOT-4']")

      refute has_element?(
               view,
               "#system-model-inspector-strip [data-role='part-numbers-overflow']"
             )

      assert has_element?(
               view,
               "#system-model-inspector-strip [data-role='model-total-devices']",
               "2"
             )

      assert has_element?(
               view,
               "#system-model-inspector-strip [data-role='model-online-devices']",
               "1 online"
             )

      assert has_element?(
               view,
               "#system-model-compatibility-card [data-role='linked-base-image-collection']",
               "Scooter OS Images"
             )

      # 3. Verify Cinder Matched Devices Table
      assert has_element?(view, "#device-name-#{device1.id}", "Scooter Rome 01")
      assert has_element?(view, "#device-name-#{device2.id}", "Scooter Rome 02")
      refute has_element?(view, "#device-name-#{other_device.id}")

      # 4. Real-time PubSub: device2 comes online -> updates reach strip and status cell
      _device2 =
        Ash.update!(device2, %{online: true},
          action: :from_device_status,
          tenant: tenant,
          authorize?: false
        )

      _ = render(view)
      _ = render_async(view)

      assert has_element?(
               view,
               "#system-model-inspector-strip [data-role='model-online-devices']",
               "2 online"
             )

      assert has_element?(
               view,
               "#system-model-inspector-strip [data-role='model-reach-pct']",
               "100% online"
             )
    end

    test "redirects to system models index when visiting a non-existent ID", %{
      conn: conn,
      tenant: tenant,
      tenant_private_key: tenant_private_key
    } do
      jwt = generate_jwt(tenant_private_key)

      conn =
        post(conn, ~p"/session", %{
          "session" => %{"tenant_slug" => tenant.slug, "auth_token" => jwt}
        })

      assert {:error, {:live_redirect, %{to: to}}} =
               live(recycle(conn), ~p"/tenants/#{tenant.slug}/system-models/999999")

      assert to == ~p"/tenants/#{tenant.slug}/system-models"
    end
  end

  describe "floating pill edit drawer and guarded delete modal on Show" do
    test "edits model attributes, clears description and picture, and guards deletion when referenced by BaseImageCollection",
         %{
           conn: conn,
           tenant: tenant,
           tenant_private_key: tenant_private_key
         } do
      jwt = generate_jwt(tenant_private_key)

      ht =
        DevicesFixtures.hardware_type_fixture(
          tenant: tenant,
          name: "Strawberry Pi 5",
          handle: "strawberry-pi-5",
          part_numbers: ["STBEPI-5-REV1"]
        )

      model =
        DevicesFixtures.system_model_fixture(
          tenant: tenant,
          hardware_type_id: ht.id,
          name: "Industrial Gateway v1",
          handle: "ind-gw-v1",
          picture_url: "https://example.com/images/gw-v1.png",
          part_numbers: ["GW-PN-1"],
          localized_descriptions: [
            %{
              language_tag: tenant.default_locale,
              value: "Initial gateway description."
            }
          ]
        )

      collection =
        BaseImagesFixtures.base_image_collection_fixture(
          tenant: tenant,
          system_model_id: model.id,
          name: "Gateway Firmware",
          handle: "gw-firmware"
        )

      conn =
        post(conn, ~p"/session", %{
          "session" => %{"tenant_slug" => tenant.slug, "auth_token" => jwt}
        })

      {:ok, view, _html} =
        live(recycle(conn), ~p"/tenants/#{tenant.slug}/system-models/#{model.id}")

      # 1. Open Edit Floating Pill Drawer
      view
      |> element("#edit-system-model-btn")
      |> render_click()

      assert_patch(view, ~p"/tenants/#{tenant.slug}/system-models/#{model.id}/edit")
      assert has_element?(view, "#edit-system-model-drawer[aria-modal='false']")

      assert has_element?(
               view,
               "#edit-system-model-drawer-panel.rounded-3xl.animate-floating-pill-right"
             )

      assert has_element?(
               view,
               "#system-model-hardware-type-readonly",
               "Strawberry Pi 5"
             )

      # Clear picture via #clear-picture-btn, update name/handle, clear description, and add a part number
      view
      |> element("#clear-picture-btn")
      |> render_click()

      view
      |> element("#add-part-number-btn")
      |> render_click()

      view
      |> form("#system-model-form", %{
        "system_model" => %{
          "name" => "Industrial Gateway v2",
          "handle" => "ind-gw-v2",
          "description" => "",
          "picture_url" => "",
          "part_numbers" => ["GW-PN-1", "GW-PN-2"]
        }
      })
      |> render_submit()

      assert_patch(view, ~p"/tenants/#{tenant.slug}/system-models/#{model.id}")
      assert has_element?(view, "#system-model-detail-name", "Industrial Gateway v2")
      assert has_element?(view, "#system-model-detail-handle", "@ind-gw-v2")
      assert has_element?(view, "#system-model-detail-picture-placeholder")

      assert has_element?(
               view,
               "#system-model-detail-no-description",
               "No product description provided."
             )

      assert has_element?(view, "#system-model-inspector-strip [data-part-number='GW-PN-2']")

      # 2. Open Delete Modal while BaseImageCollection references the model -> blocked!
      view
      |> element("#delete-system-model-btn")
      |> render_click()

      assert has_element?(
               view,
               "#delete-system-model-blocker",
               "Gateway Firmware (@gw-firmware)"
             )

      assert has_element?(view, "#confirm-delete-system-model-btn[disabled]")

      view
      |> element("#cancel-delete-system-model-btn")
      |> render_click()

      refute has_element?(view, "#delete-system-model-modal")

      # 3. Destroy the blocking BaseImageCollection, reopen Delete Modal -> allowed!
      _ = Ash.destroy!(collection, tenant: tenant, authorize?: false)

      view
      |> element("#delete-system-model-btn")
      |> render_click()

      refute has_element?(view, "#delete-system-model-blocker")
      assert has_element?(view, "#delete-system-model-impact-notice", "2")

      view
      |> element("#confirm-delete-system-model-btn")
      |> render_click()

      assert_redirect(view, ~p"/tenants/#{tenant.slug}/system-models")
    end
  end
end
