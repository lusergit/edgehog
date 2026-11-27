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

defmodule EdgehogWeb.Schema.Query.ImagePolicyTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Astarte.Device.ResourceEvent

  describe "imagePolicy and imagePolicies queries" do
    test "fetches an image policy and lists all image policies", %{tenant: tenant} do
      public_key = public_key_fixture(tenant: tenant)

      policy =
        image_policy_fixture(
          tenant: tenant,
          repository: "quay.io/seco",
          type: :signed_by,
          public_key_id: public_key.id
        )

      policy_relay_id = AshGraphql.Resource.encode_relay_id(policy)
      key_relay_id = AshGraphql.Resource.encode_relay_id(public_key)

      fetched =
        [tenant: tenant, id: policy_relay_id]
        |> image_policy_query()
        |> extract_result!()

      assert %{
               "id" => ^policy_relay_id,
               "repository" => "quay.io/seco",
               "registryId" => registry_id,
               "type" => "SIGNED_BY",
               "publicKey" => %{"id" => ^key_relay_id}
             } = fetched

      assert registry_id == policy.registry_id

      listed =
        [tenant: tenant]
        |> image_policies_query()
        |> extract_result!()

      assert %{
               "edges" => [
                 %{"node" => %{"id" => ^policy_relay_id, "repository" => "quay.io/seco"}}
               ]
             } = listed
    end

    test "fetches an image policy deployment via root imagePolicyDeployment query", %{
      tenant: tenant
    } do
      policy = image_policy_fixture(tenant: tenant)
      device = device_fixture(tenant: tenant)

      deployment =
        image_policy_deployment_fixture(
          tenant: tenant,
          device_id: device.id,
          registry_id: policy.registry_id,
          state: :present
        )

      deployment_relay_id = AshGraphql.Resource.encode_relay_id(deployment)
      policy_relay_id = AshGraphql.Resource.encode_relay_id(policy)
      device_relay_id = AshGraphql.Resource.encode_relay_id(device)

      fetched =
        [tenant: tenant, id: deployment_relay_id]
        |> image_policy_deployment_query()
        |> extract_result!()

      assert %{
               "id" => ^deployment_relay_id,
               "registryId" => registry_id,
               "state" => "present",
               "isReady" => true,
               "imagePolicy" => %{"id" => ^policy_relay_id},
               "device" => %{"id" => ^device_relay_id}
             } = fetched

      assert registry_id == policy.registry_id

      other_tenant = tenant_fixture()

      assert %{data: %{"imagePolicyDeployment" => nil}} =
               image_policy_deployment_query(tenant: other_tenant, id: deployment_relay_id)
    end

    test "fetches device imagePolicyDeployments including unknown registryIds and Astarte events",
         %{tenant: tenant} do
      device = device_fixture(tenant: tenant)
      unknown_registry_id = String.duplicate("f", 64)

      deployment =
        image_policy_deployment_fixture(
          tenant: tenant,
          device_id: device.id,
          registry_id: unknown_registry_id,
          state: :present
        )

      device_id = device.device_id
      timestamp = ~U[2026-11-27 11:05:00Z]

      expect(ResourceEvent, :get, fn _client,
                                     ^device_id,
                                     "io.edgehog.devicemanager.apps.ImagePolicyEvent",
                                     ^unknown_registry_id,
                                     [] ->
        {:ok,
         [
           %ResourceEvent.Data{
             status: "Created",
             message: "Policy applied",
             add_info: ["type=Reject"],
             timestamp: timestamp
           }
         ]}
      end)

      device_relay_id = AshGraphql.Resource.encode_relay_id(device)
      deployment_relay_id = AshGraphql.Resource.encode_relay_id(deployment)

      device_data =
        [tenant: tenant, id: device_relay_id]
        |> device_image_policy_deployments_query()
        |> extract_result!()

      assert %{
               "imagePolicyDeployments" => %{
                 "edges" => [
                   %{
                     "node" => %{
                       "id" => ^deployment_relay_id,
                       "registryId" => ^unknown_registry_id,
                       "state" => "present",
                       "isReady" => true,
                       "imagePolicy" => nil,
                       "events" => [
                         %{
                           "resourceId" => ^deployment_relay_id,
                           "status" => "CREATED",
                           "message" => "Policy applied",
                           "addInfo" => ["type=Reject"],
                           "timestamp" => "2026-11-27T11:05:00Z"
                         }
                       ]
                     }
                   }
                 ]
               }
             } = device_data
    end
  end

  defp image_policy_query(opts) do
    default_document = """
    query GetImagePolicy($id: ID!) {
      imagePolicy(id: $id) {
        id
        repository
        registryId
        type
        publicKey {
          id
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {id, opts} = Keyword.pop!(opts, :id)
    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: %{"id" => id},
      context: %{tenant: tenant, actor: %{}}
    )
  end

  defp image_policies_query(opts) do
    default_document = """
    query ListImagePolicies {
      imagePolicies {
        edges {
          node {
            id
            repository
          }
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, context: %{tenant: tenant, actor: %{}})
  end

  defp image_policy_deployment_query(opts) do
    default_document = """
    query GetImagePolicyDeployment($id: ID!) {
      imagePolicyDeployment(id: $id) {
        id
        registryId
        state
        isReady
        imagePolicy {
          id
        }
        device {
          id
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {id, opts} = Keyword.pop!(opts, :id)
    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: %{"id" => id},
      context: %{tenant: tenant, actor: %{}}
    )
  end

  defp device_image_policy_deployments_query(opts) do
    default_document = """
    query DeviceImagePolicyDeployments($id: ID!) {
      device(id: $id) {
        imagePolicyDeployments {
          edges {
            node {
              id
              registryId
              state
              isReady
              imagePolicy {
                id
              }
              events {
                resourceId
                status
                message
                addInfo
                timestamp
              }
            }
          }
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {id, opts} = Keyword.pop!(opts, :id)
    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: %{"id" => id},
      context: %{tenant: tenant, actor: %{}}
    )
  end

  defp extract_result!(result) do
    refute :errors in Map.keys(result)
    assert %{data: data} = result
    [{_field, value}] = Map.to_list(data)
    assert value
    value
  end
end
