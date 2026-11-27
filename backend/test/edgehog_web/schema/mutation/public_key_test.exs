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

defmodule EdgehogWeb.Schema.Mutation.PublicKeyTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures

  alias Edgehog.Containers.PublicKey

  describe "createPublicKey mutation" do
    test "creates a public key with valid X.509 PEM certificate", %{tenant: tenant} do
      pem = x509_certificate_pem_fixture()
      {:ok, expected_fingerprint} = PublicKey.Fingerprint.from_pem(pem)

      result =
        [tenant: tenant, label: "prod-signing-key", pem: pem]
        |> create_public_key_mutation()
        |> extract_create_result!()

      assert result["label"] == "prod-signing-key"
      assert result["pem"] == String.trim(pem)
      assert result["fingerprint"] == expected_fingerprint
    end

    test "returns error for invalid PEM certificate", %{tenant: tenant} do
      error =
        [tenant: tenant, label: "bad-key", pem: "not-a-cert"]
        |> create_public_key_mutation()
        |> extract_error!()

      assert error[:message] =~ "X.509"
    end
  end

  describe "deletePublicKey mutation" do
    test "deletes an unreferenced public key", %{tenant: tenant} do
      public_key = public_key_fixture(tenant: tenant)
      relay_id = AshGraphql.Resource.encode_relay_id(public_key)

      result =
        [tenant: tenant, id: relay_id]
        |> delete_public_key_mutation()
        |> extract_delete_result!()

      assert result["id"] == relay_id
      assert {:error, _} = Ash.get(PublicKey, public_key.id, tenant: tenant)
    end

    test "fails when public key is still referenced by an image policy", %{tenant: tenant} do
      public_key = public_key_fixture(tenant: tenant)

      _policy =
        image_policy_fixture(tenant: tenant, type: :signed_by, public_key_id: public_key.id)

      relay_id = AshGraphql.Resource.encode_relay_id(public_key)

      assert error =
               [tenant: tenant, id: relay_id]
               |> delete_public_key_mutation()
               |> extract_error!()

      assert error[:message]
      assert {:ok, _} = Ash.get(PublicKey, public_key.id, tenant: tenant)
    end
  end

  defp create_public_key_mutation(opts) do
    document = """
    mutation CreatePublicKey($input: CreatePublicKeyInput!) {
      createPublicKey(input: $input) {
        result {
          id
          label
          pem
          fingerprint
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {label, opts} = Keyword.pop!(opts, :label)
    {pem, _opts} = Keyword.pop!(opts, :pem)

    variables = %{"input" => %{"label" => label, "pem" => pem}}

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: variables,
      context: %{tenant: tenant, actor: %{}}
    )
  end

  defp delete_public_key_mutation(opts) do
    document = """
    mutation DeletePublicKey($id: ID!) {
      deletePublicKey(id: $id) {
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
    assert %{data: %{"createPublicKey" => %{"result" => public_key}}} = result
    assert public_key
    public_key
  end

  defp extract_delete_result!(result) do
    refute :errors in Map.keys(result)
    assert %{data: %{"deletePublicKey" => %{"result" => public_key}}} = result
    assert public_key
    public_key
  end

  defp extract_error!(result) do
    assert %{errors: [error | _], data: data} = result
    assert data |> Map.values() |> Enum.all?(&is_nil/1)
    error
  end
end
