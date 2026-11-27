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

defmodule EdgehogWeb.Controllers.AstarteTriggerController.ImagePolicyTriggersTest do
  use EdgehogWeb.ConnCase, async: true

  import Edgehog.AstarteFixtures
  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures

  alias Edgehog.Containers

  setup %{tenant: tenant} do
    cluster = cluster_fixture()
    realm = realm_fixture(cluster_id: cluster.id, tenant: tenant)
    device = device_fixture(realm_id: realm.id, tenant: tenant)

    {:ok, cluster: cluster, realm: realm, device: device}
  end

  describe "AvailablePublicKeys and PublicKeyEvent triggers" do
    test "AvailablePublicKeys creates/updates and unsets PublicKey.Deployment", %{
      conn: conn,
      realm: realm,
      device: device,
      tenant: tenant
    } do
      public_key = public_key_fixture(tenant: tenant)
      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      payload = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.AvailablePublicKeys",
          path: "/#{public_key.fingerprint}/status",
          value: "Present"
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, payload)
      |> response(200)

      assert {:ok, deployment} =
               Containers.fetch_public_key_deployment(public_key.fingerprint, device.id,
                 tenant: tenant
               )

      assert deployment.state == :present

      unset_payload = put_in(payload, [:event, :value], nil)

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, unset_payload)
      |> response(200)

      assert {:error, _} =
               Containers.fetch_public_key_deployment(public_key.fingerprint, device.id,
                 tenant: tenant
               )
    end

    test "PublicKeyEvent trigger is accepted for an existing PublicKey.Deployment", %{
      conn: conn,
      realm: realm,
      device: device,
      tenant: tenant
    } do
      deployment = public_key_deployment_fixture(tenant: tenant, device_id: device.id)
      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      payload = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.PublicKeyEvent",
          path: "/#{deployment.public_key_fingerprint}",
          value: %{
            "status" => "Created",
            "message" => "Public key stored",
            "addInfo" => ["x509"]
          }
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, payload)
      |> response(200)
    end

    test "PublicKeyEvent accepts omitted message and addInfo fields", %{
      conn: conn,
      realm: realm,
      device: device,
      tenant: tenant
    } do
      deployment = public_key_deployment_fixture(tenant: tenant, device_id: device.id)
      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      payload = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.PublicKeyEvent",
          path: "/#{deployment.public_key_fingerprint}",
          value: %{"status" => "Created"}
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, payload)
      |> response(200)
    end

    test "PublicKeyEvent returns 422 when deployment does not exist or payload/path is invalid",
         %{
           conn: conn,
           realm: realm,
           device: device,
           tenant: tenant
         } do
      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)
      missing_fingerprint = String.duplicate("9", 64)

      for {event_path, event_value} <- [
            {"/#{missing_fingerprint}", %{"status" => "Created"}},
            {"/", %{"status" => "Created"}},
            {"/#{missing_fingerprint}/extra", %{"status" => "Created"}},
            {"/#{missing_fingerprint}", %{"message" => "missing status"}}
          ] do
        payload = %{
          device_id: device.device_id,
          event: %{
            type: "incoming_data",
            interface: "io.edgehog.devicemanager.apps.PublicKeyEvent",
            path: event_path,
            value: event_value
          },
          timestamp: DateTime.to_iso8601(DateTime.utc_now())
        }

        conn
        |> put_req_header("astarte-realm", realm.name)
        |> post(path, payload)
        |> response(422)
      end
    end

    test "AvailablePublicKeys returns 422 for unknown device or empty key_id path", %{
      conn: conn,
      realm: realm,
      device: device,
      tenant: tenant
    } do
      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      for {dev_id, event_path} <- [
            {"unknown-device", "/#{String.duplicate("a", 64)}/status"},
            {device.device_id, "//status"}
          ] do
        payload = %{
          device_id: dev_id,
          event: %{
            type: "incoming_data",
            interface: "io.edgehog.devicemanager.apps.AvailablePublicKeys",
            path: event_path,
            value: "Present"
          },
          timestamp: DateTime.to_iso8601(DateTime.utc_now())
        }

        conn
        |> put_req_header("astarte-realm", realm.name)
        |> post(path, payload)
        |> response(422)
      end
    end
  end

  describe "AvailableImagePolicies and ImagePolicyEvent triggers" do
    test "AvailableImagePolicies creates/updates and unsets ImagePolicy.Deployment", %{
      conn: conn,
      realm: realm,
      device: device,
      tenant: tenant
    } do
      policy = image_policy_fixture(tenant: tenant)
      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      payload = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.AvailableImagePolicies",
          path: "/#{policy.registry_id}/status",
          value: "Present"
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, payload)
      |> response(200)

      assert {:ok, deployment} =
               Containers.fetch_image_policy_deployment(policy.registry_id, device.id,
                 tenant: tenant
               )

      assert deployment.state == :present

      unset_payload = put_in(payload, [:event, :value], nil)

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, unset_payload)
      |> response(200)

      assert {:error, _} =
               Containers.fetch_image_policy_deployment(policy.registry_id, device.id,
                 tenant: tenant
               )
    end

    test "ImagePolicyEvent trigger is accepted for an existing ImagePolicy.Deployment", %{
      conn: conn,
      realm: realm,
      device: device,
      tenant: tenant
    } do
      deployment = image_policy_deployment_fixture(tenant: tenant, device_id: device.id)
      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      payload = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.ImagePolicyEvent",
          path: "/#{deployment.registry_id}",
          value: %{
            "status" => "Created",
            "message" => "Policy applied",
            "addInfo" => []
          }
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, payload)
      |> response(200)
    end

    test "ImagePolicyEvent accepts omitted message and addInfo fields", %{
      conn: conn,
      realm: realm,
      device: device,
      tenant: tenant
    } do
      deployment = image_policy_deployment_fixture(tenant: tenant, device_id: device.id)
      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      payload = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.ImagePolicyEvent",
          path: "/#{deployment.registry_id}",
          value: %{"status" => "Created"}
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, payload)
      |> response(200)
    end

    test "ImagePolicyEvent returns 422 when deployment does not exist or payload/path is invalid",
         %{
           conn: conn,
           realm: realm,
           device: device,
           tenant: tenant
         } do
      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)
      missing_registry_id = String.duplicate("8", 64)

      for {event_path, event_value} <- [
            {"/#{missing_registry_id}", %{"status" => "Created"}},
            {"/", %{"status" => "Created"}},
            {"/#{missing_registry_id}/extra", %{"status" => "Created"}},
            {"/#{missing_registry_id}", %{"message" => "missing status"}}
          ] do
        payload = %{
          device_id: device.device_id,
          event: %{
            type: "incoming_data",
            interface: "io.edgehog.devicemanager.apps.ImagePolicyEvent",
            path: event_path,
            value: event_value
          },
          timestamp: DateTime.to_iso8601(DateTime.utc_now())
        }

        conn
        |> put_req_header("astarte-realm", realm.name)
        |> post(path, payload)
        |> response(422)
      end
    end

    test "AvailableImagePolicies returns 422 for unknown device or empty registry_id path", %{
      conn: conn,
      realm: realm,
      device: device,
      tenant: tenant
    } do
      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      for {dev_id, event_path} <- [
            {"unknown-device", "/#{String.duplicate("b", 64)}/status"},
            {device.device_id, "//status"}
          ] do
        payload = %{
          device_id: dev_id,
          event: %{
            type: "incoming_data",
            interface: "io.edgehog.devicemanager.apps.AvailableImagePolicies",
            path: event_path,
            value: "Present"
          },
          timestamp: DateTime.to_iso8601(DateTime.utc_now())
        }

        conn
        |> put_req_header("astarte-realm", realm.name)
        |> post(path, payload)
        |> response(422)
      end
    end
  end
end
