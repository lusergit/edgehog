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

defmodule EdgehogWeb.Schema.Mutation.ImagePolicyTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Containers.ImagePolicy
  alias Edgehog.Containers.ImagePolicy.RegistryId

  describe "createImagePolicy mutation" do
    test "creates a REJECT image policy", %{tenant: tenant} do
      result =
        [tenant: tenant, repository: "docker.io", type: "REJECT"]
        |> create_image_policy_mutation()
        |> extract_create_result!()

      assert result["repository"] == "docker.io"
      assert result["registryId"] == RegistryId.compute("docker.io")
      assert result["type"] == "REJECT"
      assert is_nil(result["publicKey"])
    end

    test "creates a SIGNED_BY image policy translating publicKeyId Relay ID", %{tenant: tenant} do
      public_key = public_key_fixture(tenant: tenant)
      key_relay_id = AshGraphql.Resource.encode_relay_id(public_key)

      result =
        [
          tenant: tenant,
          repository: "quay.io/my-org",
          type: "SIGNED_BY",
          public_key_id: key_relay_id
        ]
        |> create_image_policy_mutation()
        |> extract_create_result!()

      assert result["repository"] == "quay.io/my-org"
      assert result["registryId"] == RegistryId.compute("quay.io/my-org")
      assert result["type"] == "SIGNED_BY"
      assert result["publicKey"]["id"] == key_relay_id
    end

    test "returns error for SIGNED_BY without publicKeyId", %{tenant: tenant} do
      error =
        [
          tenant: tenant,
          repository: "quay.io/my-org",
          type: "SIGNED_BY"
        ]
        |> create_image_policy_mutation()
        |> extract_error!()

      assert error[:message]
    end

    test "returns error for REJECT with publicKeyId", %{tenant: tenant} do
      public_key = public_key_fixture(tenant: tenant)
      key_relay_id = AshGraphql.Resource.encode_relay_id(public_key)

      error =
        [
          tenant: tenant,
          repository: "quay.io/my-org",
          type: "REJECT",
          public_key_id: key_relay_id
        ]
        |> create_image_policy_mutation()
        |> extract_error!()

      assert error[:message]
    end

    test "returns error for SIGNED_BY with another tenant's publicKeyId", %{tenant: tenant} do
      other_tenant = tenant_fixture()
      other_public_key = public_key_fixture(tenant: other_tenant)
      other_key_relay_id = AshGraphql.Resource.encode_relay_id(other_public_key)

      error =
        [
          tenant: tenant,
          repository: "quay.io/cross-tenant",
          type: "SIGNED_BY",
          public_key_id: other_key_relay_id
        ]
        |> create_image_policy_mutation()
        |> extract_error!()

      assert error[:message]
    end
  end

  describe "deleteImagePolicy mutation" do
    test "deletes an image policy", %{tenant: tenant} do
      policy = image_policy_fixture(tenant: tenant)
      relay_id = AshGraphql.Resource.encode_relay_id(policy)

      result =
        [tenant: tenant, id: relay_id]
        |> delete_image_policy_mutation()
        |> extract_delete_result!()

      assert result["id"] == relay_id
      assert {:error, _} = Ash.get(ImagePolicy, policy.id, tenant: tenant)
    end
  end

  defp create_image_policy_mutation(opts) do
    document = """
    mutation CreateImagePolicy($input: CreateImagePolicyInput!) {
      createImagePolicy(input: $input) {
        result {
          id
          repository
          registryId
          type
          publicKey {
            id
          }
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {repository, opts} = Keyword.pop!(opts, :repository)
    {type, opts} = Keyword.pop!(opts, :type)
    {public_key_id, _opts} = Keyword.pop(opts, :public_key_id)

    base_input = %{"repository" => repository, "type" => type}

    input =
      if public_key_id,
        do: Map.put(base_input, "publicKeyId", public_key_id),
        else: base_input

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: %{"input" => input},
      context: %{tenant: tenant, actor: %{}}
    )
  end

  defp delete_image_policy_mutation(opts) do
    document = """
    mutation DeleteImagePolicy($id: ID!) {
      deleteImagePolicy(id: $id) {
        result {
          id
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {id, _opts} = Keyword.pop!(opts, :id)

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: %{"id" => id},
      context: %{tenant: tenant, actor: %{}}
    )
  end

  defp extract_create_result!(result) do
    refute :errors in Map.keys(result)
    assert %{data: %{"createImagePolicy" => %{"result" => policy}}} = result
    assert policy
    policy
  end

  defp extract_delete_result!(result) do
    refute :errors in Map.keys(result)
    assert %{data: %{"deleteImagePolicy" => %{"result" => policy}}} = result
    assert policy
    policy
  end

  defp extract_error!(result) do
    assert %{errors: [error | _], data: data} = result
    assert data |> Map.values() |> Enum.all?(&is_nil/1)
    error
  end
end
