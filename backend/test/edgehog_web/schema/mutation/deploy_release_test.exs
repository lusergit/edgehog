#
# This file is part of Edgehog.
#
# Copyright 2021-2024 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Mutation.DeployReleaseTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures

  alias Edgehog.Astarte.Device.CreateContainerRequestMock
  alias Edgehog.Astarte.Device.CreateDeploymentRequestMock
  alias Edgehog.Astarte.Device.CreateImageRequestMock
  alias Edgehog.Astarte.Device.CreateNetworkRequestMock

  test "deployRelease creates the deployment on the device", %{tenant: tenant} do
    containers = 3
    # one image per container
    images = containers
    # one network for the release
    networks = 1
    device = device_fixture(tenant: tenant)
    release = release_fixture(tenant: tenant, containers: containers)

    expect(CreateImageRequestMock, :send_create_image_request, images, fn _, _, _ -> :ok end)

    expect(CreateContainerRequestMock, :send_create_container_request, containers, fn _, _, data ->
      assert data.networkIds != []
      :ok
    end)

    expect(CreateNetworkRequestMock, :send_create_network_request, networks, fn _, _, _ ->
      :ok
    end)

    expect(CreateDeploymentRequestMock, :send_create_deployment_request, 1, fn _, _, data ->
      assert Enum.count(data.containers) == containers
      :ok
    end)

    [
      tenant: tenant,
      release_id: AshGraphql.Resource.encode_relay_id(release),
      device_id: AshGraphql.Resource.encode_relay_id(device)
    ]
    |> deploy_release_mutation()
    |> extract_result!()
  end

  defp deploy_release_mutation(opts) do
    default_document = """
    mutation DeployRelease($input: DeployReleaseInput!) {
      deployRelease(input: $input) {
        result {
          id
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {device_id, opts} =
      Keyword.pop_lazy(opts, :device_id, fn ->
        [tenant: tenant]
        |> device_fixture()
        |> AshGraphql.Resource.encode_relay_id()
      end)

    {release_id, opts} =
      Keyword.pop_lazy(opts, :release_id, fn ->
        [tenant: tenant]
        |> release_fixture()
        |> AshGraphql.Resource.encode_relay_id()
      end)

    input = %{
      "deviceId" => device_id,
      "releaseId" => release_id
    }

    variables = %{"input" => input}

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  defp extract_result!(result) do
    refute :errors in Map.keys(result)
    refute "errors" in Map.keys(result[:data])

    assert %{data: %{"deployRelease" => %{"result" => deployment}}} = result

    assert deployment != nil

    deployment
  end
end