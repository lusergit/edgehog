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

defmodule EdgehogWeb.Controllers.AstarteTriggerController.DeploymentEventsTest do
  use EdgehogWeb.ConnCase, async: true

  import Edgehog.AstarteFixtures
  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures

  alias Edgehog.Audit.Event
  alias Edgehog.Containers.Release.Deployment
  alias Edgehog.Repo

  describe "deployment events" do
    setup %{tenant: tenant} do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster_id: cluster.id, tenant: tenant)
      device = device_fixture(realm_id: realm.id, tenant: tenant)
      deployment = deployment_fixture(tenant: tenant, device_id: device.id)

      {:ok, cluster: cluster, realm: realm, device: device, deployment: deployment}
    end

    test "do not update the state", context do
      %{
        conn: conn,
        realm: realm,
        device: device,
        tenant: tenant,
        deployment: deployment
      } = context

      deployment_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.DeploymentEvent",
          path: "/" <> deployment.id,
          value: %{
            "status" => "Error",
            "message" => "error message"
          }
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, deployment_event)
      |> response(200)

      # Deployment must be reloaded from the db
      new_deployment = Ash.get!(Deployment, deployment.id, tenant: tenant)

      assert deployment.state == new_deployment.state
    end

    for event <- [:starting, :stopping, :error] do
      test "A new #{event} event triggers a deployment event notification on interface publish",
           context do
        %{
          conn: conn,
          realm: realm,
          device: device,
          tenant: tenant,
          deployment: deployment
        } = context

        event_value = event_value(unquote(event), "test_event_message")
        timestamp = DateTime.to_iso8601(DateTime.utc_now())

        deployment_event = %{
          device_id: device.device_id,
          event: %{
            type: "incoming_data",
            interface: "io.edgehog.devicemanager.apps.DeploymentEvent",
            path: "/" <> deployment.id,
            value: event_value
          },
          timestamp: timestamp
        }

        path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

        conn
        |> put_req_header("astarte-realm", realm.name)
        |> post(path, deployment_event)
        |> response(200)
      end
    end

    for event <- [:starting, :stopping, :error] do
      test "A new #{event} event triggers a deployment event notification on interface publish (event with add_info field)",
           context do
        %{
          conn: conn,
          realm: realm,
          device: device,
          tenant: tenant,
          deployment: deployment
        } = context

        event_value =
          event_value(unquote(event), "test_event_message", ["additional information about event"])

        timestamp = DateTime.to_iso8601(DateTime.utc_now())

        deployment_event = %{
          device_id: device.device_id,
          event: %{
            type: "incoming_data",
            interface: "io.edgehog.devicemanager.apps.DeploymentEvent",
            path: "/" <> deployment.id,
            value: event_value
          },
          timestamp: timestamp
        }

        path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

        conn
        |> put_req_header("astarte-realm", realm.name)
        |> post(path, deployment_event)
        |> response(200)
      end
    end

    test "returns 422 when deployment does not exist", context do
      %{
        conn: conn,
        realm: realm,
        device: device,
        tenant: tenant
      } = context

      deployment_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.DeploymentEvent",
          path: "/" <> Ecto.UUID.generate(),
          value: %{
            "status" => "Starting",
            "message" => "starting"
          }
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, deployment_event)
      |> response(422)
    end

    for {context_value, event_name} <- [
          {:start_message_sent, "start_fail"},
          {:stop_message_sent, "stop_fail"},
          {:delete_message_sent, "undeployment_fail"},
          {:upgrade_message_sent, "upgrade_fail"}
        ] do
      test "audits #{event_name} once and clears context on Error event when context is #{context_value}",
           %{
             conn: conn,
             realm: realm,
             device: device,
             tenant: tenant
           } do
        application = application_fixture(name: "edge-app", tenant: tenant)
        container = container_fixture(name: "web", tenant: tenant)

        release =
          release_fixture(
            application_id: application.id,
            version: "1.0.0",
            container_ids: [container.id],
            tenant: tenant
          )

        deployment =
          deployment_fixture(
            tenant: tenant,
            device_id: device.id,
            release_id: release.id
          )

        deployment =
          deployment
          |> Ecto.Changeset.change(context: unquote(context_value))
          |> Repo.update!()

        deployment_event = %{
          device_id: device.device_id,
          event: %{
            type: "incoming_data",
            interface: "io.edgehog.devicemanager.apps.DeploymentEvent",
            path: "/" <> deployment.id,
            value: %{
              "status" => "Error",
              "message" => "command failed on device",
              "addInfo" => ["exit code 137"]
            }
          },
          timestamp: DateTime.to_iso8601(DateTime.utc_now())
        }

        path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

        conn
        |> put_req_header("astarte-realm", realm.name)
        |> post(path, deployment_event)
        |> response(200)

        assert [audit_event] = lifecycle_events(tenant, unquote(event_name))
        assert audit_event.log_level == :error
        assert audit_event.metadata["resource_id"] == deployment.id
        assert audit_event.metadata["device_id"] == device.device_id
        assert audit_event.metadata["application_name"] == "edge-app"
        assert audit_event.metadata["release_version"] == "1.0.0"
        assert audit_event.metadata["container_names"] == ["web"]
        assert audit_event.metadata["error"] == "command failed on device"
        assert audit_event.metadata["add_info"] == ["exit code 137"]

        updated_deployment = Ash.get!(Deployment, deployment.id, tenant: tenant)
        assert is_nil(updated_deployment.context)

        # A duplicate Error event does not re-emit the failure audit event
        conn
        |> put_req_header("astarte-realm", realm.name)
        |> post(path, deployment_event)
        |> response(200)

        assert length(lifecycle_events(tenant, unquote(event_name))) == 1
      end
    end

    test "does not emit a failure audit event when deployment context is nil", %{
      conn: conn,
      realm: realm,
      device: device,
      tenant: tenant,
      deployment: deployment
    } do
      deployment_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.DeploymentEvent",
          path: "/" <> deployment.id,
          value: %{
            "status" => "Error",
            "message" => "spontaneous error"
          }
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, deployment_event)
      |> response(200)

      assert lifecycle_events(tenant, "start_fail") == []
      assert lifecycle_events(tenant, "stop_fail") == []
      assert lifecycle_events(tenant, "undeployment_fail") == []
      assert lifecycle_events(tenant, "upgrade_fail") == []
    end
  end

  defp lifecycle_events(tenant, event_name) do
    Event
    |> Ash.read!(tenant: tenant)
    |> Enum.filter(fn event ->
      is_nil(event.ash_action_info) and event.metadata["event"] == event_name
    end)
  end

  defp event_value(event, message),
    do: %{
      "status" => event |> to_string() |> String.capitalize(),
      "message" => message
    }

  defp event_value(event, message, add_info),
    do: %{
      "status" => event |> to_string() |> String.capitalize(),
      "message" => message,
      "addInfo" => add_info
    }
end
