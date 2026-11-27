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

defmodule Edgehog.Containers.PublicKey.Deployment.ProvisionerTest do
  @moduledoc """
  Tests for the public key deployment provisioner, audit trail, and telemetry.
  """

  use Edgehog.DataCase, async: false

  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.TelemetryCapture
  import Edgehog.TenantsFixtures

  alias Ecto.Adapters.SQL.Sandbox
  alias Edgehog.Astarte.Device.AvailablePublicKeys
  alias Edgehog.Astarte.Device.AvailablePublicKeys.PublicKeyStatus
  alias Edgehog.Astarte.Device.PublicKey, as: AstartePublicKey
  alias Edgehog.Audit.Event
  alias Edgehog.Config
  alias Edgehog.Containers
  alias Edgehog.Containers.PublicKey.Deployment.Provisioner
  alias Edgehog.Containers.PublicKey.Fingerprint
  alias Edgehog.Containers.Telemetry

  describe "PublicKey.Deployment.Provisioner" do
    setup do
      tenant = tenant_fixture()
      public_key = public_key_fixture(tenant: tenant)
      device = online_device_fixture(tenant)

      {:ok, deployment} = Containers.deploy_public_key(public_key, device, tenant: tenant)
      deployment = Ash.load!(deployment, [:public_key, :device], tenant: tenant)

      %{
        tenant: tenant,
        public_key: public_key,
        device: device,
        deployment: deployment
      }
    end

    test "provisions a public key, persists audit events, and emits start/stop telemetry", %{
      tenant: tenant,
      public_key: public_key,
      device: device,
      deployment: deployment
    } do
      stub(Config, :audit_log_events?, fn -> false end)
      stub(Config, :audit_store_events?, fn -> true end)

      Edgehog.TelemetryCapture.start_capture([
        Telemetry.provisioning_start_event(),
        Telemetry.provisioning_stop_event()
      ])

      {provisioner, ref} = start_manual_provisioner(tenant, deployment)

      {_start_m, start_meta} = assert_receive_event(Telemetry.provisioning_start_event())
      assert start_meta.resource_type == "public_key_deployment"
      assert start_meta.resource_id == deployment.id
      assert is_nil(start_meta.deployment_id)
      assert start_meta.device_id == device.id
      assert start_meta.tenant == tenant.slug

      {:ok, expected_der} = Fingerprint.der_from_pem(public_key.pem)
      expected_device_id = device.device_id
      expected_fp = public_key.fingerprint

      AstartePublicKey
      |> allow(self(), provisioner)
      |> expect(:set, fn _client, ^expected_device_id, ^expected_fp, ^expected_der ->
        deployment
        |> Ash.Changeset.for_update(:mark_as_present, %{})
        |> Ash.update!(tenant: tenant)

        :ok
      end)

      ready_topic = Provisioner.Core.topic(deployment)
      Phoenix.PubSub.subscribe(Edgehog.PubSub, ready_topic)

      Provisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 1000
      assert_receive {:ready, ready_deployment}, 1000
      assert ready_deployment.id == deployment.id
      assert ready_deployment.state == :present
      assert Ash.load!(ready_deployment, :is_ready, tenant: tenant).is_ready

      {stop_m, stop_meta} = assert_receive_event(Telemetry.provisioning_stop_event())
      assert stop_m.count == 1
      assert stop_m.retries == 1
      assert stop_meta.result == :ok
      assert stop_meta.reason == :ready
      assert stop_meta.resource_type == "public_key_deployment"
      assert stop_meta.resource_id == deployment.id
      assert is_nil(stop_meta.deployment_id)
      assert stop_meta.tenant == tenant.slug

      events = Ash.read!(Event, tenant: tenant)

      assert Enum.any?(events, fn e ->
               e.metadata["resource_type"] == "public_key_deployment" and
                 e.metadata["resource_id"] == deployment.id and
                 e.metadata["public_key_fingerprint"] == expected_fp and
                 e.message =~ "sent to device"
             end)

      assert Enum.any?(events, fn e ->
               e.metadata["resource_type"] == "public_key_deployment" and
                 e.metadata["resource_id"] == deployment.id and
                 e.message =~ "successfully provisioned"
             end)

      Phoenix.PubSub.unsubscribe(Edgehog.PubSub, ready_topic)
    end

    test "retries on transient 5xx error and records warning audit event", %{
      tenant: tenant,
      deployment: deployment
    } do
      stub(Config, :audit_log_events?, fn -> false end)
      stub(Config, :audit_store_events?, fn -> true end)

      {provisioner, ref} = start_manual_provisioner(tenant, deployment)

      AstartePublicKey
      |> allow(self(), provisioner)
      |> expect(:set, fn _, _, _, _ ->
        {:error, %Edgehog.Error.AstarteAPIError{status: 500, response: "temporary"}}
      end)
      |> expect(:set, fn _, _, _, _ ->
        deployment
        |> Ash.Changeset.for_update(:mark_as_present, %{})
        |> Ash.update!(tenant: tenant)

        :ok
      end)

      Provisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 2500

      events = Ash.read!(Event, tenant: tenant)

      assert Enum.any?(events, fn e ->
               e.log_level == :warning and
                 e.metadata["resource_type"] == "public_key_deployment" and
                 e.metadata["resource_id"] == deployment.id
             end)
    end

    test "terminates immediately without sending when already ready (:present or :missing)", %{
      tenant: tenant,
      public_key: public_key,
      device: device
    } do
      for {action, expected_state} <- [
            {:mark_as_present, :present},
            {:mark_as_missing, :missing}
          ] do
        other_device = online_device_fixture(tenant)
        {:ok, dep} = Containers.deploy_public_key(public_key, other_device, tenant: tenant)
        dep = dep |> Ash.Changeset.for_update(action, %{}) |> Ash.update!(tenant: tenant)
        dep = Ash.load!(dep, [:public_key, :device], tenant: tenant)

        {provisioner, ref} = start_manual_provisioner(tenant, dep)

        AstartePublicKey
        |> allow(self(), provisioner)
        |> reject(:set, 4)

        ready_topic = Provisioner.Core.topic(dep)
        Phoenix.PubSub.subscribe(Edgehog.PubSub, ready_topic)

        Provisioner.run(provisioner)

        assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 1000
        assert_receive {:ready, ready_dep}, 1000
        assert ready_dep.state == expected_state

        Phoenix.PubSub.unsubscribe(Edgehog.PubSub, ready_topic)
      end

      assert device.online
    end

    test "reconciles with Astarte after timeout when trigger is missed", %{
      tenant: tenant,
      public_key: public_key,
      device: device,
      deployment: deployment
    } do
      {provisioner, ref} = start_manual_provisioner(tenant, deployment)

      Config
      |> allow(self(), provisioner)
      |> stub(:message_min_timeout!, fn -> 0 end)

      AstartePublicKey
      |> allow(self(), provisioner)
      |> expect(:set, fn _, _, _, _ -> :ok end)

      expected_device_id = device.device_id

      AvailablePublicKeys
      |> allow(self(), provisioner)
      |> expect(:get, fn _client, ^expected_device_id ->
        {:ok, [%PublicKeyStatus{id: public_key.fingerprint, status: :missing}]}
      end)

      ready_topic = Provisioner.Core.topic(deployment)
      Phoenix.PubSub.subscribe(Edgehog.PubSub, ready_topic)

      Provisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 3000
      assert_receive {:ready, reconciled_dep}, 1000
      assert reconciled_dep.state == :missing

      Phoenix.PubSub.unsubscribe(Edgehog.PubSub, ready_topic)
    end

    test "stops when device goes offline mid-flight", %{
      tenant: tenant,
      device: device,
      deployment: deployment
    } do
      {provisioner, ref} = start_manual_provisioner(tenant, deployment)

      AstartePublicKey
      |> allow(self(), provisioner)
      |> expect(:set, fn _, _, _, _ -> :ok end)

      Provisioner.run(provisioner)
      mark_device_offline!(device, tenant)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, {:shutdown, :device_offline}}, 2000
    end

    test "stops immediately when device is offline at startup", %{
      tenant: tenant,
      public_key: public_key
    } do
      offline_device = device_fixture(tenant: tenant, online: false)
      {:ok, deployment} = Containers.deploy_public_key(public_key, offline_device, tenant: tenant)
      deployment = Ash.load!(deployment, [:public_key, :device], tenant: tenant)

      Edgehog.TelemetryCapture.start_capture([Telemetry.provisioning_stop_event()])

      {provisioner, ref} = start_manual_provisioner(tenant, deployment)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, {:shutdown, :device_offline}}, 2000

      {_m, meta} = assert_receive_event(Telemetry.provisioning_stop_event())
      assert meta.result == :error
      assert meta.reason == :device_offline
      assert meta.resource_type == "public_key_deployment"
      assert is_nil(meta.deployment_id)
    end

    test "stops on unsolvable 400 error and records error audit event", %{
      tenant: tenant,
      deployment: deployment
    } do
      stub(Config, :audit_log_events?, fn -> false end)
      stub(Config, :audit_store_events?, fn -> true end)

      {provisioner, ref} = start_manual_provisioner(tenant, deployment)

      AstartePublicKey
      |> allow(self(), provisioner)
      |> expect(:set, fn _, _, _, _ ->
        {:error, %Edgehog.Error.AstarteAPIError{status: 400, response: "bad request"}}
      end)

      topic = Provisioner.Core.topic(deployment)
      Phoenix.PubSub.subscribe(Edgehog.PubSub, topic)

      Provisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, {:shutdown, :unsolvable_api_error}},
                     2000

      assert_receive {:failure, failed}, 2000
      assert failed.id == deployment.id

      events = Ash.read!(Event, tenant: tenant)

      assert Enum.any?(events, fn e ->
               e.log_level == :error and
                 e.metadata["resource_type"] == "public_key_deployment" and
                 e.metadata["resource_id"] == deployment.id
             end)

      Phoenix.PubSub.unsubscribe(Edgehog.PubSub, topic)
    end

    test "stops cleanly on device-only deployment without a cloud PublicKey", %{
      tenant: tenant,
      device: device
    } do
      deployment =
        public_key_deployment_fixture(
          tenant: tenant,
          device_id: device.id,
          public_key_fingerprint: String.duplicate("c", 64)
        )

      {provisioner, ref} = start_manual_provisioner(tenant, deployment)

      AstartePublicKey
      |> allow(self(), provisioner)
      |> reject(:set, 4)

      Provisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, {:shutdown, :unsolvable_api_error}},
                     2000
    end

    test "send_public_key_deployment action starts the provisioner", %{
      tenant: tenant,
      deployment: deployment
    } do
      expected_id = deployment.id
      expected_tenant_id = tenant.tenant_id

      expect(Provisioner, :provision, fn dep, prov_tenant ->
        assert dep.id == expected_id
        assert prov_tenant.tenant_id == expected_tenant_id
        {:ok, self()}
      end)

      assert {:ok, updated} = Containers.send_public_key_deployment(deployment, tenant: tenant)
      assert updated.id == deployment.id
    end
  end

  defp start_manual_provisioner(tenant, deployment) do
    pid =
      case Provisioner.start(tenant: tenant, resource: deployment, mode: :manual) do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
      end

    ref = Process.monitor(pid)
    Sandbox.allow(Edgehog.Repo, self(), pid)
    {pid, ref}
  end

  defp online_device_fixture(tenant) do
    timestamp = DateTime.now!("Etc/UTC")
    device = device_fixture(tenant: tenant)

    device
    |> Ash.Changeset.for_update(:from_device_status, %{
      online: true,
      last_connection: timestamp,
      last_disconnection: timestamp
    })
    |> Ash.update!(tenant: tenant)
  end

  defp mark_device_offline!(device, tenant) do
    timestamp = DateTime.now!("Etc/UTC")

    device
    |> Ash.Changeset.for_update(:from_device_status, %{
      online: false,
      last_connection: timestamp,
      last_disconnection: timestamp
    })
    |> Ash.update!(tenant: tenant)
  end
end
