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

defmodule EdgehogWeb.Schema.Subscriptions.Containers.PublicKeyAndImagePolicyEventsTest do
  @moduledoc false
  use EdgehogWeb.SubsCase

  import Edgehog.AstarteFixtures
  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures

  alias Ash.Astarte.Triggers.Handler

  setup %{tenant: tenant} do
    cluster = cluster_fixture()
    realm = realm_fixture(cluster_id: cluster.id, tenant: tenant)
    device = device_fixture(realm_id: realm.id, tenant: tenant)

    public_key_deployment =
      public_key_deployment_fixture(tenant: tenant, device_id: device.id)

    image_policy_deployment =
      image_policy_deployment_fixture(tenant: tenant, device_id: device.id)

    %{
      realm: realm,
      device: device,
      public_key_deployment: public_key_deployment,
      image_policy_deployment: image_policy_deployment
    }
  end

  describe "publicKeyDeploymentEvents subscription" do
    test "receives PublicKeyEvent for the subscribed public key deployment", %{
      socket: socket,
      tenant: tenant,
      realm: realm,
      device: device,
      public_key_deployment: deployment
    } do
      relay_id = AshGraphql.Resource.encode_relay_id(deployment)
      subscribe(socket, leaf_subscription_query("publicKeyDeploymentEvents"), %{"id" => relay_id})

      send_trigger(
        tenant,
        realm,
        device,
        "io.edgehog.devicemanager.apps.PublicKeyEvent",
        "/" <> deployment.public_key_fingerprint,
        %{"status" => "Created", "message" => "Certificate stored", "addInfo" => ["x509"]}
      )

      assert_push "subscription:data", push

      assert %{
               result: %{
                 data: %{
                   "publicKeyDeploymentEvents" => %{
                     "__typename" => "PublicKeyDeploymentEvent",
                     "resourceId" => ^relay_id,
                     "status" => "CREATED",
                     "message" => "Certificate stored",
                     "addInfo" => ["x509"],
                     "timestamp" => "2026-11-27T11:00:00Z"
                   }
                 }
               }
             } = push
    end

    test "does not receive events for a different public key deployment", %{
      socket: socket,
      tenant: tenant,
      realm: realm,
      device: device,
      public_key_deployment: deployment
    } do
      subscribe(socket, leaf_subscription_query("publicKeyDeploymentEvents"), %{
        "id" => Ecto.UUID.generate()
      })

      send_trigger(
        tenant,
        realm,
        device,
        "io.edgehog.devicemanager.apps.PublicKeyEvent",
        "/" <> deployment.public_key_fingerprint,
        %{"status" => "Error", "message" => "Failed"}
      )

      refute_push "subscription:data", _push
    end
  end

  describe "imagePolicyDeploymentEvents subscription" do
    test "receives ImagePolicyEvent for the subscribed image policy deployment", %{
      socket: socket,
      tenant: tenant,
      realm: realm,
      device: device,
      image_policy_deployment: deployment
    } do
      relay_id = AshGraphql.Resource.encode_relay_id(deployment)

      subscribe(socket, leaf_subscription_query("imagePolicyDeploymentEvents"), %{
        "id" => relay_id
      })

      send_trigger(
        tenant,
        realm,
        device,
        "io.edgehog.devicemanager.apps.ImagePolicyEvent",
        "/" <> deployment.registry_id,
        %{"status" => "Removed", "message" => "Policy removed", "addInfo" => ["docker.io"]}
      )

      assert_push "subscription:data", push

      assert %{
               result: %{
                 data: %{
                   "imagePolicyDeploymentEvents" => %{
                     "__typename" => "ImagePolicyDeploymentEvent",
                     "resourceId" => ^relay_id,
                     "status" => "REMOVED",
                     "message" => "Policy removed",
                     "addInfo" => ["docker.io"],
                     "timestamp" => "2026-11-27T11:00:00Z"
                   }
                 }
               }
             } = push
    end

    test "does not receive events for a different image policy deployment", %{
      socket: socket,
      tenant: tenant,
      realm: realm,
      device: device,
      image_policy_deployment: deployment
    } do
      subscribe(socket, leaf_subscription_query("imagePolicyDeploymentEvents"), %{
        "id" => Ecto.UUID.generate()
      })

      send_trigger(
        tenant,
        realm,
        device,
        "io.edgehog.devicemanager.apps.ImagePolicyEvent",
        "/" <> deployment.registry_id,
        %{"status" => "Created", "message" => "Policy applied"}
      )

      refute_push "subscription:data", _push
    end
  end

  defp subscribe(socket, query, variables) do
    ref = push_doc(socket, query, variables: variables)
    assert_reply ref, :ok, %{subscriptionId: subscription_id}
    subscription_id
  end

  defp send_trigger(tenant, realm, device, interface, path, value) do
    payload = %{
      "device_id" => device.device_id,
      "timestamp" => "2026-11-27T11:00:00Z",
      "event" => %{
        "type" => "incoming_data",
        "interface" => interface,
        "path" => path,
        "value" => value
      }
    }

    assert :ok = Handler.handle_trigger(tenant, realm.name, payload)
  end

  defp leaf_subscription_query(field_name) do
    """
    subscription($id: ID!) {
      #{field_name}(id: $id) {
        __typename
        resourceId
        status
        message
        addInfo
        timestamp
      }
    }
    """
  end
end
