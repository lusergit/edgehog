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

defmodule Edgehog.Containers.Release.Deployment.AuditTest do
  use Edgehog.DataCase, async: false

  import Edgehog.AstarteFixtures
  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Actors.Actor
  alias Edgehog.Astarte.Device.DeploymentCommand
  alias Edgehog.Audit.Event
  alias Edgehog.Config
  alias Edgehog.Containers
  alias Edgehog.Containers.Release.Deployment
  alias Edgehog.Containers.Release.Deployment.Audit
  alias Edgehog.Containers.Release.Deployment.Orchestrator

  setup do
    stub(Config, :audit_log_events?, fn -> false end)
    stub(Config, :audit_store_events?, fn -> true end)

    tenant = tenant_fixture()
    realm = realm_fixture(tenant: tenant)
    device = device_fixture(realm_id: realm.id, tenant: tenant)
    application = application_fixture(name: "edge-app", tenant: tenant)
    container_b = container_fixture(name: "worker", tenant: tenant)
    container_a = container_fixture(name: "api", tenant: tenant)

    release =
      release_fixture(
        application_id: application.id,
        version: "1.2.3",
        container_ids: [container_b.id, container_a.id],
        tenant: tenant
      )

    actor = %Actor{sub: "user-123", preferred_username: "alice"}

    %{
      tenant: tenant,
      device: device,
      application: application,
      release: release,
      actor: actor
    }
  end

  describe "deploy lifecycle audit" do
    test "audits deployment_init with container names, release context, and username", %{
      tenant: tenant,
      device: device,
      release: release,
      actor: actor
    } do
      deployment =
        Deployment
        |> Ash.Changeset.for_create(
          :deploy,
          %{device_id: device.id, release_id: release.id},
          tenant: tenant,
          actor: actor,
          context: %{shared: %{run_provisioner: false}}
        )
        |> Ash.create!(tenant: tenant, actor: actor)

      assert [event] = lifecycle_events(tenant, "deployment_init")
      assert event.log_level == :info
      assert event.message == "Deployment #{deployment.id} provisioning started."

      assert event.metadata == %{
               "event" => "deployment_init",
               "resource_type" => "release_deployment",
               "resource_id" => deployment.id,
               "device_id" => device.device_id,
               "application_name" => "edge-app",
               "release_version" => "1.2.3",
               "container_names" => ["api", "worker"],
               "username" => "alice"
             }
    end

    test "omits username when deploy has no actor", %{
      tenant: tenant,
      device: device,
      release: release
    } do
      deployment =
        Deployment
        |> Ash.Changeset.for_create(
          :deploy,
          %{device_id: device.id, release_id: release.id},
          tenant: tenant,
          context: %{shared: %{run_provisioner: false}}
        )
        |> Ash.create!(tenant: tenant)

      assert [event] = lifecycle_events(tenant, "deployment_init")
      assert event.metadata["resource_id"] == deployment.id
      assert event.metadata["container_names"] == ["api", "worker"]
      refute Map.has_key?(event.metadata, "username")
    end
  end

  describe "start, stop, delete, and upgrade command audit" do
    setup %{tenant: tenant, device: device, release: release} do
      deployment =
        deployment_fixture(
          tenant: tenant,
          device_id: device.id,
          release_id: release.id
        )

      deployment = make_deployment_ready!(deployment, tenant)

      %{deployment: deployment}
    end

    test "audits start_init and context-gated start_ok", %{
      tenant: tenant,
      deployment: deployment,
      actor: actor
    } do
      expect(DeploymentCommand, :send_deployment_command, fn _client, _device_id, _data ->
        :ok
      end)

      deployment =
        deployment
        |> Ash.Changeset.for_update(:start, %{}, tenant: tenant, actor: actor)
        |> Ash.update!(tenant: tenant, actor: actor)

      assert [init_event] = lifecycle_events(tenant, "start_init")
      assert init_event.log_level == :info
      assert init_event.message == "Deployment #{deployment.id} start command sent."
      assert init_event.metadata["username"] == "alice"
      assert init_event.metadata["container_names"] == ["api", "worker"]
      assert init_event.metadata["application_name"] == "edge-app"
      assert init_event.metadata["release_version"] == "1.2.3"

      assert {:ok, _deployment} =
               Containers.mark_deployment_as_started(deployment, tenant: tenant)

      assert [ok_event] = lifecycle_events(tenant, "start_ok")
      assert ok_event.log_level == :info
      assert ok_event.message == "Deployment #{deployment.id} successfully started."
      assert ok_event.metadata["container_names"] == ["api", "worker"]
      refute Map.has_key?(ok_event.metadata, "username")
    end

    test "does not emit start_ok when context is not :start_message_sent", %{
      tenant: tenant,
      deployment: deployment
    } do
      assert {:ok, _deployment} =
               Containers.mark_deployment_as_started(deployment, tenant: tenant)

      assert lifecycle_events(tenant, "start_ok") == []
    end

    test "audits stop_init and context-gated stop_ok", %{
      tenant: tenant,
      deployment: deployment,
      actor: actor
    } do
      expect(DeploymentCommand, :send_deployment_command, fn _client, _device_id, _data ->
        :ok
      end)

      deployment =
        deployment
        |> Ash.Changeset.for_update(:stop, %{}, tenant: tenant, actor: actor)
        |> Ash.update!(tenant: tenant, actor: actor)

      assert [init_event] = lifecycle_events(tenant, "stop_init")
      assert init_event.log_level == :info
      assert init_event.message == "Deployment #{deployment.id} stop command sent."
      assert init_event.metadata["username"] == "alice"
      assert init_event.metadata["container_names"] == ["api", "worker"]

      assert {:ok, _deployment} =
               Containers.mark_deployment_as_stopped(deployment, tenant: tenant)

      assert [ok_event] = lifecycle_events(tenant, "stop_ok")
      assert ok_event.log_level == :info
      assert ok_event.message == "Deployment #{deployment.id} successfully stopped."
      assert ok_event.metadata["container_names"] == ["api", "worker"]
      refute Map.has_key?(ok_event.metadata, "username")
    end

    test "does not emit stop_ok during initial provisioning when context is nil", %{
      tenant: tenant
    } do
      # make_deployment_ready! in setup already called mark_deployment_as_stopped with context: nil
      assert lifecycle_events(tenant, "stop_ok") == []
    end

    test "audits undeployment_init and preserves metadata on destroy_and_gc", %{
      tenant: tenant,
      device: device,
      deployment: deployment,
      actor: actor
    } do
      expect(DeploymentCommand, :send_deployment_command, fn _client, _device_id, _data ->
        :ok
      end)

      deployment =
        deployment
        |> Ash.Changeset.for_update(:delete, %{}, tenant: tenant, actor: actor)
        |> Ash.update!(tenant: tenant, actor: actor)

      assert [init_event] = lifecycle_events(tenant, "undeployment_init")
      assert init_event.log_level == :info
      assert init_event.message == "Deployment #{deployment.id} delete command sent."
      assert init_event.metadata["username"] == "alice"
      assert init_event.metadata["container_names"] == ["api", "worker"]

      deployment
      |> Ash.Changeset.for_destroy(:destroy_and_gc, %{}, tenant: tenant)
      |> Ash.destroy!()

      assert [ok_event] = lifecycle_events(tenant, "undeployment_ok")
      assert ok_event.log_level == :info
      assert ok_event.message == "Deployment #{deployment.id} successfully deleted."

      assert ok_event.metadata == %{
               "event" => "undeployment_ok",
               "resource_type" => "release_deployment",
               "resource_id" => deployment.id,
               "device_id" => device.device_id,
               "application_name" => "edge-app",
               "release_version" => "1.2.3",
               "container_names" => ["api", "worker"]
             }
    end

    test "does not emit undeployment_ok when destroy_and_gc runs without :delete_message_sent", %{
      tenant: tenant,
      deployment: deployment
    } do
      deployment
      |> Ash.Changeset.for_destroy(:destroy_and_gc, %{}, tenant: tenant)
      |> Ash.destroy!()

      assert lifecycle_events(tenant, "undeployment_ok") == []
    end

    test "does not emit start_init when SendCommand fails", %{
      tenant: tenant,
      deployment: deployment,
      actor: actor
    } do
      expect(DeploymentCommand, :send_deployment_command, fn _client, _device_id, _data ->
        {:error, :device_offline}
      end)

      assert {:error, _error} =
               deployment
               |> Ash.Changeset.for_update(:start, %{}, tenant: tenant, actor: actor)
               |> Ash.update(tenant: tenant, actor: actor)

      assert lifecycle_events(tenant, "start_init") == []
    end

    test "audits upgrade_init and propagates actor username to target deployment_init", %{
      tenant: tenant,
      application: application,
      deployment: deployment,
      actor: actor
    } do
      next_container = container_fixture(name: "api-v2", tenant: tenant)

      next_release =
        release_fixture(
          application_id: application.id,
          version: "2.0.0",
          container_ids: [next_container.id],
          tenant: tenant
        )

      stub(Orchestrator, :conduct, fn _deployment, _tenant -> {:ok, self()} end)

      deployment
      |> Ash.Changeset.for_update(:upgrade_release, %{target: next_release.id},
        tenant: tenant,
        actor: actor
      )
      |> Ash.update!(tenant: tenant, actor: actor)

      assert [upgrade_event] = lifecycle_events(tenant, "upgrade_init")
      assert upgrade_event.metadata["username"] == "alice"
      assert upgrade_event.metadata["release_version"] == "1.2.3"

      target_init_event =
        tenant
        |> lifecycle_events("deployment_init")
        |> Enum.find(&(&1.metadata["release_version"] == "2.0.0"))

      assert target_init_event
      assert target_init_event.metadata["username"] == "alice"
      assert target_init_event.metadata["container_names"] == ["api-v2"]
    end
  end

  describe "Audit.audit_error_event/3" do
    setup %{tenant: tenant, device: device, release: release} do
      deployment =
        deployment_fixture(
          tenant: tenant,
          device_id: device.id,
          release_id: release.id
        )

      %{deployment: deployment}
    end

    test "returns :noop when deployment context is nil", %{tenant: tenant, deployment: deployment} do
      assert :noop =
               Audit.audit_error_event(
                 %{deployment | context: nil},
                 %{message: "boom", add_info: []},
                 tenant
               )

      assert lifecycle_events(tenant, "start_fail") == []
    end

    for {context, event_name} <- [
          {:start_message_sent, "start_fail"},
          {:stop_message_sent, "stop_fail"},
          {:delete_message_sent, "undeployment_fail"},
          {:upgrade_message_sent, "upgrade_fail"}
        ] do
      test "audits #{event_name} for context #{context}", %{
        tenant: tenant,
        deployment: deployment
      } do
        assert :ok =
                 Audit.audit_error_event(
                   %{deployment | context: unquote(context)},
                   %{message: "container crashed", add_info: ["exit code 1"]},
                   tenant
                 )

        assert [event] = lifecycle_events(tenant, unquote(event_name))
        assert event.log_level == :error
        assert event.metadata["error"] == "container crashed"
        assert event.metadata["add_info"] == ["exit code 1"]
        assert event.metadata["container_names"] == ["api", "worker"]
        assert event.metadata["application_name"] == "edge-app"
        assert event.metadata["release_version"] == "1.2.3"
      end
    end
  end

  defp lifecycle_events(tenant, event_name) do
    Event
    |> Ash.read!(tenant: tenant)
    |> Enum.filter(fn event ->
      is_nil(event.ash_action_info) and event.metadata["event"] == event_name
    end)
  end
end
