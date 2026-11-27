#
# This file is part of Edgehog.
#
# Copyright 2025-2026 SECO Mind Srl
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

defmodule Edgehog.Containers.Reconciler.CoreTest do
  @moduledoc false

  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Astarte.Device.AvailableContainers
  alias Edgehog.Astarte.Device.AvailableContainers.ContainerStatus
  alias Edgehog.Astarte.Device.AvailableDeployments
  alias Edgehog.Astarte.Device.AvailableDeployments.DeploymentStatus
  alias Edgehog.Astarte.Device.AvailableDeviceMappings
  alias Edgehog.Astarte.Device.AvailableDeviceMappings.DeviceMappingStatus
  alias Edgehog.Astarte.Device.AvailableImagePolicies
  alias Edgehog.Astarte.Device.AvailableImagePolicies.ImagePolicyStatus
  alias Edgehog.Astarte.Device.AvailableImages
  alias Edgehog.Astarte.Device.AvailableImages.ImageStatus
  alias Edgehog.Astarte.Device.AvailableNetworks
  alias Edgehog.Astarte.Device.AvailableNetworks.NetworkStatus
  alias Edgehog.Astarte.Device.AvailablePublicKeys
  alias Edgehog.Astarte.Device.AvailablePublicKeys.PublicKeyStatus
  alias Edgehog.Astarte.Device.AvailableVolumes
  alias Edgehog.Astarte.Device.AvailableVolumes.VolumeStatus
  alias Edgehog.Containers
  alias Edgehog.Containers.Reconciler

  describe "reconcile_images/2" do
    setup do
      tenant = tenant_fixture()
      deployment = deployment_fixture(release_opts: [containers: 1], tenant: tenant)

      image_deployment =
        deployment
        |> Ash.load!(container_deployments: [:image_deployment])
        |> Map.get(:container_deployments, [])
        |> List.first()
        |> Map.get(:image_deployment)

      device =
        deployment
        |> Ash.load!(:device)
        |> Map.get(:device)

      %{
        tenant: tenant,
        deployment: deployment,
        image_deployment: image_deployment,
        device: device
      }
    end

    test "Updates the image state when something's off", %{
      tenant: tenant,
      image_deployment: image_deployment,
      device: device
    } do
      device_id = device.device_id

      expect(AvailableImages, :get, fn _client, ^device_id ->
        status =
          [
            struct!(%ImageStatus{
              id: image_deployment.image_id,
              pulled: false
            })
          ]

        {:ok, status}
      end)

      :ok = Reconciler.Core.reconcile_images(device, tenant)

      new_state =
        image_deployment
        |> Ash.load!(:state)
        |> Map.get(:state)

      assert :unpulled = new_state
    end

    test "let deployments be when everything's ok", %{
      image_deployment: image_deployment,
      tenant: tenant,
      device: device
    } do
      image_deployment
      |> Ash.Changeset.for_update(:set_state, %{state: :pulled})
      |> Ash.update!(tenant: tenant)

      device_id = device.device_id

      expect(AvailableImages, :get, fn _client, ^device_id ->
        status =
          [
            struct!(%ImageStatus{
              id: image_deployment.image_id,
              pulled: true
            })
          ]

        {:ok, status}
      end)

      :ok = Reconciler.Core.reconcile_images(device, tenant)

      new_state =
        image_deployment
        |> Ash.load!(:state)
        |> Map.get(:state)

      assert :pulled = new_state
    end
  end

  describe "reconcile_volumes/2" do
    setup do
      tenant = tenant_fixture()

      deployment =
        deployment_fixture(
          release_opts: [containers: 1, container_params: [volumes: 1]],
          tenant: tenant
        )

      volume_deployment =
        deployment
        |> Ash.load!(container_deployments: [:volume_deployments])
        |> Map.get(:container_deployments, [])
        |> List.first()
        |> Map.get(:volume_deployments, [])
        |> List.first()

      device =
        deployment
        |> Ash.load!(:device)
        |> Map.get(:device)

      %{
        tenant: tenant,
        deployment: deployment,
        volume_deployment: volume_deployment,
        device: device
      }
    end

    test "Updates the volume state when something's off", %{
      tenant: tenant,
      volume_deployment: volume_deployment,
      device: device
    } do
      device_id = device.device_id

      expect(AvailableVolumes, :get, fn _client, ^device_id ->
        status =
          [
            struct!(%VolumeStatus{
              id: volume_deployment.volume_id,
              created: false
            })
          ]

        {:ok, status}
      end)

      :ok = Reconciler.Core.reconcile_volumes(device, tenant)

      new_state =
        volume_deployment
        |> Ash.load!(:state)
        |> Map.get(:state)

      assert :unavailable = new_state
    end

    test "let deployments be when everything's ok", %{
      volume_deployment: volume_deployment,
      tenant: tenant,
      device: device
    } do
      volume_deployment
      |> Ash.Changeset.for_update(:set_state, %{state: :available})
      |> Ash.update!(tenant: tenant)

      device_id = device.device_id

      expect(AvailableVolumes, :get, fn _client, ^device_id ->
        status =
          [
            struct!(%VolumeStatus{
              id: volume_deployment.volume_id,
              created: true
            })
          ]

        {:ok, status}
      end)

      :ok = Reconciler.Core.reconcile_volumes(device, tenant)

      new_state =
        volume_deployment
        |> Ash.load!(:state)
        |> Map.get(:state)

      assert :available = new_state
    end
  end

  describe "reconcile_networks/2" do
    setup do
      tenant = tenant_fixture()

      network = network_fixture(tenant: tenant)

      deployment =
        deployment_fixture(
          release_opts: [containers: 1, container_params: [networks: [network]]],
          tenant: tenant
        )

      network_deployment =
        deployment
        |> Ash.load!(container_deployments: [:network_deployments])
        |> Map.get(:container_deployments, [])
        |> List.first()
        |> Map.get(:network_deployments, [])
        |> List.first()

      device =
        deployment
        |> Ash.load!(:device)
        |> Map.get(:device)

      %{
        tenant: tenant,
        deployment: deployment,
        network_deployment: network_deployment,
        device: device
      }
    end

    test "Updates the network state when something's off", %{
      tenant: tenant,
      network_deployment: network_deployment,
      device: device
    } do
      device_id = device.device_id

      expect(AvailableNetworks, :get, fn _client, ^device_id ->
        status =
          [
            struct!(%NetworkStatus{
              id: network_deployment.network_id,
              created: false
            })
          ]

        {:ok, status}
      end)

      :ok = Reconciler.Core.reconcile_networks(device, tenant)

      new_state =
        network_deployment
        |> Ash.load!(:state)
        |> Map.get(:state)

      assert :unavailable = new_state
    end

    test "let deployments be when everything's ok", %{
      network_deployment: network_deployment,
      tenant: tenant,
      device: device
    } do
      network_deployment
      |> Ash.Changeset.for_update(:set_state, %{state: :available})
      |> Ash.update!(tenant: tenant)

      device_id = device.device_id

      expect(AvailableNetworks, :get, fn _client, ^device_id ->
        status =
          [
            struct!(%NetworkStatus{
              id: network_deployment.network_id,
              created: true
            })
          ]

        {:ok, status}
      end)

      :ok = Reconciler.Core.reconcile_networks(device, tenant)

      new_state =
        network_deployment
        |> Ash.load!(:state)
        |> Map.get(:state)

      assert :available = new_state
    end
  end

  describe "reconcile_device_mappings/2" do
    setup do
      tenant = tenant_fixture()

      device_mapping = device_mapping_fixture(tenant: tenant)

      deployment =
        deployment_fixture(
          release_opts: [containers: 1, container_params: [device_mappings: [device_mapping]]],
          tenant: tenant
        )

      device_mapping_deployment =
        deployment
        |> Ash.load!(container_deployments: [:device_mapping_deployments])
        |> Map.get(:container_deployments, [])
        |> List.first()
        |> Map.get(:device_mapping_deployments, [])
        |> List.first()

      device =
        deployment
        |> Ash.load!(:device)
        |> Map.get(:device)

      %{
        tenant: tenant,
        deployment: deployment,
        device_mapping_deployment: device_mapping_deployment,
        device: device
      }
    end

    test "Updates the device_mapping state when something's off", %{
      tenant: tenant,
      device_mapping_deployment: device_mapping_deployment,
      device: device
    } do
      device_id = device.device_id

      expect(AvailableDeviceMappings, :get, fn _client, ^device_id ->
        status =
          [
            struct!(%DeviceMappingStatus{
              id: device_mapping_deployment.device_mapping_id,
              present: false
            })
          ]

        {:ok, status}
      end)

      :ok = Reconciler.Core.reconcile_device_mappings(device, tenant)

      new_state =
        device_mapping_deployment
        |> Ash.load!(:state)
        |> Map.get(:state)

      assert :not_present = new_state
    end

    test "let deployments be when everything's ok", %{
      device_mapping_deployment: device_mapping_deployment,
      tenant: tenant,
      device: device
    } do
      device_mapping_deployment
      |> Ash.Changeset.for_update(:set_state, %{state: :present})
      |> Ash.update!(tenant: tenant)

      device_id = device.device_id

      expect(AvailableDeviceMappings, :get, fn _client, ^device_id ->
        status =
          [
            struct!(%DeviceMappingStatus{
              id: device_mapping_deployment.device_mapping_id,
              present: true
            })
          ]

        {:ok, status}
      end)

      :ok = Reconciler.Core.reconcile_device_mappings(device, tenant)

      new_state =
        device_mapping_deployment
        |> Ash.load!(:state)
        |> Map.get(:state)

      assert :present = new_state
    end
  end

  describe "reconcile_containers/2" do
    setup do
      tenant = tenant_fixture()

      deployment =
        deployment_fixture(
          release_opts: [containers: 1],
          tenant: tenant
        )

      container_deployment =
        deployment
        |> Ash.load!(:container_deployments)
        |> Map.get(:container_deployments, [])
        |> List.first()

      device =
        deployment
        |> Ash.load!(:device)
        |> Map.get(:device)

      %{
        tenant: tenant,
        deployment: deployment,
        container_deployment: container_deployment,
        device: device
      }
    end

    test "Updates the container state when something's off", %{
      tenant: tenant,
      container_deployment: container_deployment,
      device: device
    } do
      device_id = device.device_id

      expect(AvailableContainers, :get, fn _client, ^device_id ->
        status =
          [
            struct!(%ContainerStatus{
              id: container_deployment.container_id,
              status: "Created"
            })
          ]

        {:ok, status}
      end)

      :ok = Reconciler.Core.reconcile_containers(device, tenant)

      new_state =
        container_deployment
        |> Ash.load!(:state)
        |> Map.get(:state)

      assert :device_created = new_state
    end

    test "let deployments be when everything's ok", %{
      container_deployment: container_deployment,
      tenant: tenant,
      device: device
    } do
      container_deployment
      |> Ash.Changeset.for_update(:set_state, %{state: :device_created})
      |> Ash.update!(tenant: tenant)

      device_id = device.device_id

      expect(AvailableContainers, :get, fn _client, ^device_id ->
        status =
          [
            struct!(%ContainerStatus{
              id: container_deployment.container_id,
              status: "Created"
            })
          ]

        {:ok, status}
      end)

      :ok = Reconciler.Core.reconcile_containers(device, tenant)

      new_state =
        container_deployment
        |> Ash.load!(:state)
        |> Map.get(:state)

      assert :device_created = new_state
    end

    test "Updates the container state for Missing, Starting, and Error statuses", %{
      tenant: tenant,
      container_deployment: container_deployment,
      device: device
    } do
      device_id = device.device_id

      for {status, expected_state} <- [
            {"Missing", :missing},
            {"Starting", :starting},
            {"Error", :error}
          ] do
        expect(AvailableContainers, :get, fn _client, ^device_id ->
          {:ok,
           [struct!(%ContainerStatus{id: container_deployment.container_id, status: status})]}
        end)

        assert :ok = Reconciler.Core.reconcile_containers(device, tenant)

        new_state =
          container_deployment
          |> Ash.load!(:state)
          |> Map.get(:state)

        assert ^expected_state = new_state
      end
    end
  end

  describe "reconcile_deployments/2" do
    setup do
      tenant = tenant_fixture()

      deployment =
        deployment_fixture(
          release_opts: [containers: 1],
          tenant: tenant
        )

      device =
        deployment
        |> Ash.load!(:device)
        |> Map.get(:device)

      %{
        tenant: tenant,
        deployment: deployment,
        device: device
      }
    end

    test "Updates the deployment state when something's off", %{
      tenant: tenant,
      deployment: deployment,
      device: device
    } do
      device_id = device.device_id

      expect(AvailableDeployments, :get, fn _client, ^device_id ->
        status =
          [
            struct!(%DeploymentStatus{
              id: deployment.id,
              status: "Stopped"
            })
          ]

        {:ok, status}
      end)

      :ok = Reconciler.Core.reconcile_deployments(device, tenant)

      new_state =
        deployment
        |> Ash.load!(:state)
        |> Map.get(:state)

      assert :stopped = new_state
    end

    test "let deployments be when everything's ok", %{
      deployment: deployment,
      tenant: tenant,
      device: device
    } do
      deployment
      |> Ash.Changeset.for_update(:set_state, %{state: :stopped})
      |> Ash.update!(tenant: tenant)

      device_id = device.device_id

      expect(AvailableDeployments, :get, fn _client, ^device_id ->
        status =
          [
            struct!(%DeploymentStatus{
              id: deployment.id,
              status: "Stopped"
            })
          ]

        {:ok, status}
      end)

      :ok = Reconciler.Core.reconcile_deployments(device, tenant)

      new_state =
        deployment
        |> Ash.load!(:state)
        |> Map.get(:state)

      assert :stopped = new_state
    end
  end

  describe "online_devices/1" do
    setup do
      tenant = tenant_fixture()

      {:ok, %{tenant: tenant}}
    end

    test "list online devices", %{tenant: tenant} do
      device = device_fixture(tenant: tenant, online: true)

      assert {1, stream} = Reconciler.Core.online_devices(tenant)

      read_device =
        stream
        |> Stream.take(1)
        |> Enum.at(0)

      assert device.id == read_device.id
      assert device.device_id == read_device.device_id
    end
  end

  describe "reconcile_public_keys/2" do
    setup do
      tenant = tenant_fixture()
      device = device_fixture(tenant: tenant)
      public_key = public_key_fixture(tenant: tenant)

      deployment =
        public_key_deployment_fixture(
          tenant: tenant,
          device_id: device.id,
          public_key_fingerprint: public_key.fingerprint,
          state: :sent
        )

      %{tenant: tenant, device: device, public_key: public_key, deployment: deployment}
    end

    test "updates drifted public key deployment states across :present, :missing, and :error", %{
      tenant: tenant,
      device: device,
      public_key: public_key,
      deployment: deployment
    } do
      device_id = device.device_id

      for status <- [:present, :missing, :error] do
        expect(AvailablePublicKeys, :get, fn _client, ^device_id ->
          {:ok, [%PublicKeyStatus{id: public_key.fingerprint, status: status}]}
        end)

        assert :ok = Reconciler.Core.reconcile_public_keys(device, tenant)

        reloaded = Ash.reload!(deployment, tenant: tenant)
        assert reloaded.state == status
      end
    end

    test "leaves in-sync public key deployment untouched", %{
      tenant: tenant,
      device: device,
      public_key: public_key,
      deployment: deployment
    } do
      {:ok, present} =
        Containers.mark_public_key_deployment_as_present(deployment, tenant: tenant)

      device_id = device.device_id

      expect(AvailablePublicKeys, :get, fn _client, ^device_id ->
        {:ok, [%PublicKeyStatus{id: public_key.fingerprint, status: :present}]}
      end)

      assert :ok = Reconciler.Core.reconcile_public_keys(device, tenant)

      reloaded = Ash.reload!(present, tenant: tenant)
      assert reloaded.state == :present
      assert reloaded.updated_at == present.updated_at
    end

    test "creates a deployment for a device-reported untracked public key", %{
      tenant: tenant,
      device: device
    } do
      device_id = device.device_id
      unknown_fp = String.duplicate("a", 64)

      expect(AvailablePublicKeys, :get, fn _client, ^device_id ->
        {:ok, [%PublicKeyStatus{id: unknown_fp, status: :present}]}
      end)

      assert :ok = Reconciler.Core.reconcile_public_keys(device, tenant)

      assert {:ok, created} =
               Containers.fetch_public_key_deployment(unknown_fp, device.id, tenant: tenant)

      assert created.state == :present
    end

    test "ignores nil status entries and Astarte errors gracefully", %{
      tenant: tenant,
      device: device
    } do
      device_id = device.device_id
      ignored_fp = String.duplicate("b", 64)

      expect(AvailablePublicKeys, :get, fn _client, ^device_id ->
        {:ok, [%PublicKeyStatus{id: ignored_fp, status: nil}]}
      end)

      assert :ok = Reconciler.Core.reconcile_public_keys(device, tenant)

      assert {:error, _} =
               Containers.fetch_public_key_deployment(ignored_fp, device.id, tenant: tenant)

      expect(AvailablePublicKeys, :get, fn _client, ^device_id ->
        {:error, :timeout}
      end)

      assert :ok = Reconciler.Core.reconcile_public_keys(device, tenant)
    end
  end

  describe "reconcile_image_policies/2" do
    setup do
      tenant = tenant_fixture()
      device = device_fixture(tenant: tenant)
      policy = image_policy_fixture(tenant: tenant)

      deployment =
        image_policy_deployment_fixture(
          tenant: tenant,
          device_id: device.id,
          registry_id: policy.registry_id,
          state: :sent
        )

      %{tenant: tenant, device: device, policy: policy, deployment: deployment}
    end

    test "updates drifted image policy deployment states across :present, :missing, and :error",
         %{
           tenant: tenant,
           device: device,
           policy: policy,
           deployment: deployment
         } do
      device_id = device.device_id

      for status <- [:present, :missing, :error] do
        expect(AvailableImagePolicies, :get, fn _client, ^device_id ->
          {:ok, [%ImagePolicyStatus{id: policy.registry_id, status: status}]}
        end)

        assert :ok = Reconciler.Core.reconcile_image_policies(device, tenant)

        reloaded = Ash.reload!(deployment, tenant: tenant)
        assert reloaded.state == status
      end
    end

    test "leaves in-sync image policy deployment untouched", %{
      tenant: tenant,
      device: device,
      policy: policy,
      deployment: deployment
    } do
      {:ok, present} =
        Containers.mark_image_policy_deployment_as_present(deployment, tenant: tenant)

      device_id = device.device_id

      expect(AvailableImagePolicies, :get, fn _client, ^device_id ->
        {:ok, [%ImagePolicyStatus{id: policy.registry_id, status: :present}]}
      end)

      assert :ok = Reconciler.Core.reconcile_image_policies(device, tenant)

      reloaded = Ash.reload!(present, tenant: tenant)
      assert reloaded.state == :present
      assert reloaded.updated_at == present.updated_at
    end

    test "creates a deployment for a device-reported untracked image policy", %{
      tenant: tenant,
      device: device
    } do
      device_id = device.device_id
      unknown_reg = String.duplicate("c", 64)

      expect(AvailableImagePolicies, :get, fn _client, ^device_id ->
        {:ok, [%ImagePolicyStatus{id: unknown_reg, status: :present}]}
      end)

      assert :ok = Reconciler.Core.reconcile_image_policies(device, tenant)

      assert {:ok, created} =
               Containers.fetch_image_policy_deployment(unknown_reg, device.id, tenant: tenant)

      assert created.state == :present
    end

    test "ignores nil status entries and Astarte errors gracefully", %{
      tenant: tenant,
      device: device
    } do
      device_id = device.device_id
      ignored_reg = String.duplicate("d", 64)

      expect(AvailableImagePolicies, :get, fn _client, ^device_id ->
        {:ok, [%ImagePolicyStatus{id: ignored_reg, status: nil}]}
      end)

      assert :ok = Reconciler.Core.reconcile_image_policies(device, tenant)

      assert {:error, _} =
               Containers.fetch_image_policy_deployment(ignored_reg, device.id, tenant: tenant)

      expect(AvailableImagePolicies, :get, fn _client, ^device_id ->
        {:error, :timeout}
      end)

      assert :ok = Reconciler.Core.reconcile_image_policies(device, tenant)
    end
  end
end
