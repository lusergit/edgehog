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

defmodule EdgehogWeb.Schema.Query.PublicKeyTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Astarte.Device.ResourceEvent

  describe "publicKey and publicKeys queries" do
    test "fetches a public key and lists all public keys", %{tenant: tenant} do
      public_key = public_key_fixture(tenant: tenant, label: "key-alpha")
      relay_id = AshGraphql.Resource.encode_relay_id(public_key)

      fetched =
        [tenant: tenant, id: relay_id]
        |> public_key_query()
        |> extract_result!()

      assert %{
               "id" => ^relay_id,
               "label" => "key-alpha",
               "fingerprint" => fingerprint
             } = fetched

      assert fingerprint == public_key.fingerprint

      listed =
        [tenant: tenant]
        |> public_keys_query()
        |> extract_result!()

      assert %{
               "edges" => [%{"node" => %{"id" => ^relay_id, "label" => "key-alpha"}}]
             } = listed
    end

    test "fetches a public key deployment via root publicKeyDeployment query", %{tenant: tenant} do
      public_key = public_key_fixture(tenant: tenant)
      device = device_fixture(tenant: tenant)

      deployment =
        public_key_deployment_fixture(
          tenant: tenant,
          device_id: device.id,
          public_key_fingerprint: public_key.fingerprint,
          state: :present
        )

      deployment_relay_id = AshGraphql.Resource.encode_relay_id(deployment)
      public_key_relay_id = AshGraphql.Resource.encode_relay_id(public_key)
      device_relay_id = AshGraphql.Resource.encode_relay_id(device)

      fetched =
        [tenant: tenant, id: deployment_relay_id]
        |> public_key_deployment_query()
        |> extract_result!()

      assert %{
               "id" => ^deployment_relay_id,
               "publicKeyFingerprint" => fingerprint,
               "state" => "present",
               "isReady" => true,
               "publicKey" => %{"id" => ^public_key_relay_id},
               "device" => %{"id" => ^device_relay_id}
             } = fetched

      assert fingerprint == public_key.fingerprint

      other_tenant = tenant_fixture()

      assert %{data: %{"publicKeyDeployment" => nil}} =
               public_key_deployment_query(tenant: other_tenant, id: deployment_relay_id)
    end

    test "fetches device publicKeyDeployments including unknown fingerprints and Astarte events",
         %{tenant: tenant} do
      device = device_fixture(tenant: tenant)
      unknown_fp = String.duplicate("e", 64)

      deployment =
        public_key_deployment_fixture(
          tenant: tenant,
          device_id: device.id,
          public_key_fingerprint: unknown_fp,
          state: :present
        )

      device_id = device.device_id
      timestamp = ~U[2026-11-27 11:00:00Z]

      expect(ResourceEvent, :get, fn _client,
                                     ^device_id,
                                     "io.edgehog.devicemanager.apps.PublicKeyEvent",
                                     ^unknown_fp,
                                     [] ->
        {:ok,
         [
           %ResourceEvent.Data{
             status: "Created",
             message: "Key installed",
             add_info: [],
             timestamp: timestamp
           }
         ]}
      end)

      device_relay_id = AshGraphql.Resource.encode_relay_id(device)
      deployment_relay_id = AshGraphql.Resource.encode_relay_id(deployment)

      device_data =
        [tenant: tenant, id: device_relay_id]
        |> device_public_key_deployments_query()
        |> extract_result!()

      assert %{
               "publicKeyDeployments" => %{
                 "edges" => [
                   %{
                     "node" => %{
                       "id" => ^deployment_relay_id,
                       "publicKeyFingerprint" => ^unknown_fp,
                       "state" => "present",
                       "isReady" => true,
                       "publicKey" => nil,
                       "events" => [
                         %{
                           "resourceId" => ^deployment_relay_id,
                           "status" => "CREATED",
                           "message" => "Key installed",
                           "addInfo" => [],
                           "timestamp" => "2026-11-27T11:00:00Z"
                         }
                       ]
                     }
                   }
                 ]
               }
             } = device_data
    end
  end

  defp public_key_query(opts) do
    default_document = """
    query GetPublicKey($id: ID!) {
      publicKey(id: $id) {
        id
        label
        fingerprint
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

  defp public_keys_query(opts) do
    default_document = """
    query ListPublicKeys {
      publicKeys {
        edges {
          node {
            id
            label
          }
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, context: %{tenant: tenant, actor: %{}})
  end

  defp public_key_deployment_query(opts) do
    default_document = """
    query GetPublicKeyDeployment($id: ID!) {
      publicKeyDeployment(id: $id) {
        id
        publicKeyFingerprint
        state
        isReady
        publicKey {
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

  defp device_public_key_deployments_query(opts) do
    default_document = """
    query DevicePublicKeyDeployments($id: ID!) {
      device(id: $id) {
        publicKeyDeployments {
          edges {
            node {
              id
              publicKeyFingerprint
              state
              isReady
              publicKey {
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
