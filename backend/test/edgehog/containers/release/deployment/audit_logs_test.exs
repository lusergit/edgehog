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

defmodule Edgehog.Containers.Release.Deployment.AuditLogsTest do
  @moduledoc """
  Captures and validates the production `PrettyLog.LogfmtFormatter` log entry
  emitted for every `Edgehog.Containers.Release.Deployment.Audit` lifecycle event.

  Each event has its own test so placing `dbg(log)` (or `IO.puts(log)`) in a test
  prints a realistic example log line as emitted in production.
  """

  use Edgehog.DataCase, async: false

  import Edgehog.AstarteFixtures
  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures
  import ExUnit.CaptureLog

  alias Edgehog.Actors.Actor
  alias Edgehog.Config
  alias Edgehog.Containers.Release.Deployment.Audit

  setup do
    previous_log_level = Logger.level()
    Logger.configure(level: :info)

    on_exit(fn ->
      Logger.configure(level: previous_log_level)
    end)

    stub(Config, :audit_log_events?, fn -> true end)
    stub(Config, :audit_store_events?, fn -> false end)

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

    deployment =
      deployment_fixture(
        tenant: tenant,
        device_id: device.id,
        release_id: release.id
      )

    actor = %Actor{sub: "user-123", preferred_username: "alice"}

    %{
      tenant: tenant,
      device: device,
      deployment: deployment,
      actor: actor
    }
  end

  describe "deployment provisioning logfmt entries" do
    test "deployment_init", %{
      tenant: tenant,
      device: device,
      deployment: deployment,
      actor: actor
    } do
      log =
        capture_prod_log(fn ->
          assert :ok = Audit.deployment_initiated(deployment, tenant, actor: actor)
        end)

      decoded = Logfmt.decode(log)
      assert_base_fields(decoded, tenant, device, deployment)
      assert decoded["level"] == "info"
      assert decoded["event"] == "deployment_init"
      assert decoded["msg"] == "Deployment #{deployment.id} provisioning started."
      assert decoded["username"] == "alice"
      refute Map.has_key?(decoded, "error")
    end

    test "deployment_ok", %{tenant: tenant, device: device, deployment: deployment} do
      log =
        capture_prod_log(fn ->
          assert :ok = Audit.deployment_succeeded(deployment, tenant)
        end)

      decoded = Logfmt.decode(log)
      assert_base_fields(decoded, tenant, device, deployment)
      assert decoded["level"] == "info"
      assert decoded["event"] == "deployment_ok"
      assert decoded["msg"] == "Deployment #{deployment.id} successfully provisioned."
      refute Map.has_key?(decoded, "username")
      refute Map.has_key?(decoded, "error")
    end

    test "deployment_fail", %{tenant: tenant, device: device, deployment: deployment} do
      log =
        capture_prod_log(fn ->
          assert :ok =
                   Audit.deployment_failed(deployment, tenant, :deployment_provisioner_failed)
        end)

      decoded = Logfmt.decode(log)
      assert_base_fields(decoded, tenant, device, deployment)
      assert decoded["level"] == "error"
      assert decoded["event"] == "deployment_fail"
      assert decoded["msg"] == "Deployment #{deployment.id} provisioning failed."
      assert decoded["error"] == ":deployment_provisioner_failed"
      refute Map.has_key?(decoded, "username")
    end
  end

  describe "deployment undeployment logfmt entries" do
    test "undeployment_init", %{
      tenant: tenant,
      device: device,
      deployment: deployment,
      actor: actor
    } do
      log =
        capture_prod_log(fn ->
          assert :ok = Audit.undeployment_initiated(deployment, tenant, actor: actor)
        end)

      decoded = Logfmt.decode(log)
      assert_base_fields(decoded, tenant, device, deployment)
      assert decoded["level"] == "info"
      assert decoded["event"] == "undeployment_init"
      assert decoded["msg"] == "Deployment #{deployment.id} delete command sent."
      assert decoded["username"] == "alice"
      refute Map.has_key?(decoded, "error")
    end

    test "undeployment_ok", %{tenant: tenant, device: device, deployment: deployment} do
      log =
        capture_prod_log(fn ->
          assert :ok = Audit.undeployment_succeeded(deployment, tenant)
        end)

      decoded = Logfmt.decode(log)
      assert_base_fields(decoded, tenant, device, deployment)
      assert decoded["level"] == "info"
      assert decoded["event"] == "undeployment_ok"
      assert decoded["msg"] == "Deployment #{deployment.id} successfully deleted."
      refute Map.has_key?(decoded, "username")
      refute Map.has_key?(decoded, "error")
    end

    test "undeployment_fail", %{tenant: tenant, device: device, deployment: deployment} do
      log =
        capture_prod_log(fn ->
          assert :ok =
                   Audit.audit_error_event(
                     %{deployment | context: :delete_message_sent},
                     %{message: "volume still mounted", add_info: ["device busy", "retry later"]},
                     tenant
                   )
        end)

      decoded = Logfmt.decode(log)
      assert_base_fields(decoded, tenant, device, deployment)
      assert decoded["level"] == "error"
      assert decoded["event"] == "undeployment_fail"
      assert decoded["msg"] == "Deployment #{deployment.id} deletion failed."
      assert decoded["error"] == "volume still mounted"
      assert decoded["add_info"] == "device busy,retry later"
      refute Map.has_key?(decoded, "username")
    end
  end

  describe "deployment start logfmt entries" do
    test "start_init", %{
      tenant: tenant,
      device: device,
      deployment: deployment,
      actor: actor
    } do
      log =
        capture_prod_log(fn ->
          assert :ok = Audit.start_initiated(deployment, tenant, actor: actor)
        end)

      decoded = Logfmt.decode(log)
      assert_base_fields(decoded, tenant, device, deployment)
      assert decoded["level"] == "info"
      assert decoded["event"] == "start_init"
      assert decoded["msg"] == "Deployment #{deployment.id} start command sent."
      assert decoded["username"] == "alice"
      refute Map.has_key?(decoded, "error")
    end

    test "start_ok", %{tenant: tenant, device: device, deployment: deployment} do
      log =
        capture_prod_log(fn ->
          assert :ok = Audit.start_succeeded(deployment, tenant)
        end)

      decoded = Logfmt.decode(log)
      assert_base_fields(decoded, tenant, device, deployment)
      assert decoded["level"] == "info"
      assert decoded["event"] == "start_ok"
      assert decoded["msg"] == "Deployment #{deployment.id} successfully started."
      refute Map.has_key?(decoded, "username")
      refute Map.has_key?(decoded, "error")
    end

    test "start_fail", %{tenant: tenant, device: device, deployment: deployment} do
      log =
        capture_prod_log(fn ->
          assert :ok =
                   Audit.audit_error_event(
                     %{deployment | context: :start_message_sent},
                     %{message: "container crashed", add_info: ["exit code 137", "oom killed"]},
                     tenant
                   )
        end)

      decoded = Logfmt.decode(log)
      assert_base_fields(decoded, tenant, device, deployment)
      assert decoded["level"] == "error"
      assert decoded["event"] == "start_fail"
      assert decoded["msg"] == "Deployment #{deployment.id} failed to start."
      assert decoded["error"] == "container crashed"
      assert decoded["add_info"] == "exit code 137,oom killed"
      refute Map.has_key?(decoded, "username")
    end
  end

  describe "deployment stop logfmt entries" do
    test "stop_init", %{
      tenant: tenant,
      device: device,
      deployment: deployment,
      actor: actor
    } do
      log =
        capture_prod_log(fn ->
          assert :ok = Audit.stop_initiated(deployment, tenant, actor: actor)
        end)

      decoded = Logfmt.decode(log)
      assert_base_fields(decoded, tenant, device, deployment)
      assert decoded["level"] == "info"
      assert decoded["event"] == "stop_init"
      assert decoded["msg"] == "Deployment #{deployment.id} stop command sent."
      assert decoded["username"] == "alice"
      refute Map.has_key?(decoded, "error")
    end

    test "stop_ok", %{tenant: tenant, device: device, deployment: deployment} do
      log =
        capture_prod_log(fn ->
          assert :ok = Audit.stop_succeeded(deployment, tenant)
        end)

      decoded = Logfmt.decode(log)
      assert_base_fields(decoded, tenant, device, deployment)
      assert decoded["level"] == "info"
      assert decoded["event"] == "stop_ok"
      assert decoded["msg"] == "Deployment #{deployment.id} successfully stopped."
      refute Map.has_key?(decoded, "username")
      refute Map.has_key?(decoded, "error")
    end

    test "stop_fail", %{tenant: tenant, device: device, deployment: deployment} do
      log =
        capture_prod_log(fn ->
          assert :ok =
                   Audit.audit_error_event(
                     %{deployment | context: :stop_message_sent},
                     %{message: "stop timeout", add_info: ["sigkill failed"]},
                     tenant
                   )
        end)

      decoded = Logfmt.decode(log)
      assert_base_fields(decoded, tenant, device, deployment)
      assert decoded["level"] == "error"
      assert decoded["event"] == "stop_fail"
      assert decoded["msg"] == "Deployment #{deployment.id} failed to stop."
      assert decoded["error"] == "stop timeout"
      assert decoded["add_info"] == "sigkill failed"
      refute Map.has_key?(decoded, "username")
    end
  end

  describe "deployment upgrade logfmt entries" do
    test "upgrade_init", %{
      tenant: tenant,
      device: device,
      deployment: deployment,
      actor: actor
    } do
      log =
        capture_prod_log(fn ->
          assert :ok = Audit.upgrade_initiated(deployment, tenant, actor: actor)
        end)

      decoded = Logfmt.decode(log)
      assert_base_fields(decoded, tenant, device, deployment)
      assert decoded["level"] == "info"
      assert decoded["event"] == "upgrade_init"
      assert decoded["msg"] == "Deployment #{deployment.id} upgrade command sent."
      assert decoded["username"] == "alice"
      refute Map.has_key?(decoded, "error")
    end

    test "upgrade_fail", %{tenant: tenant, device: device, deployment: deployment} do
      log =
        capture_prod_log(fn ->
          assert :ok =
                   Audit.audit_error_event(
                     %{deployment | context: :upgrade_message_sent},
                     %{message: "image pull failed", add_info: ["404 not found"]},
                     tenant
                   )
        end)

      decoded = Logfmt.decode(log)
      assert_base_fields(decoded, tenant, device, deployment)
      assert decoded["level"] == "error"
      assert decoded["event"] == "upgrade_fail"
      assert decoded["msg"] == "Deployment #{deployment.id} upgrade failed."
      assert decoded["error"] == "image pull failed"
      assert decoded["add_info"] == "404 not found"
      refute Map.has_key?(decoded, "username")
    end
  end

  defp capture_prod_log(fun) do
    logger_metadata = Application.fetch_env!(:logger, :console)[:metadata]

    formatter =
      Logger.Formatter.new(
        format: {PrettyLog.LogfmtFormatter, :format},
        metadata: logger_metadata,
        colors: [enabled: false]
      )

    [level: :info, formatter: formatter]
    |> capture_log(fun)
    |> String.trim()
  end

  defp assert_base_fields(decoded, tenant, device, deployment) do
    assert is_binary(decoded["ts"])
    assert decoded["tenant"] == tenant.slug
    assert decoded["resource_type"] == "release_deployment"
    assert decoded["resource_id"] == deployment.id
    assert decoded["device_id"] == device.device_id
    assert decoded["application_name"] == "edge-app"
    assert decoded["release_version"] == "1.2.3"
    assert decoded["container_names"] == "api,worker"
  end
end
