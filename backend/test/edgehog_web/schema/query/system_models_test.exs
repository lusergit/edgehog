# This file is part of Edgehog.
#
# Copyright 2021 - 2026 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Query.SystemModelsTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.BaseImagesFixtures
  import Edgehog.DevicesFixtures

  describe "systemModels query" do
    test "returns empty system models", %{tenant: tenant} do
      assert [] == [tenant: tenant] |> system_models_query() |> extract_result!()
    end

    test "returns system models if they're present", %{tenant: tenant} do
      hardware_type = hardware_type_fixture(tenant: tenant)

      fixture =
        [
          tenant: tenant,
          hardware_type_id: hardware_type.id,
          picture_url: "https://example.com/image.jpg"
        ]
        |> system_model_fixture()
        |> Ash.load!(:part_number_strings)

      assert [system_model] = [tenant: tenant] |> system_models_query() |> extract_result!()

      assert system_model["name"] == fixture.name
      assert system_model["handle"] == fixture.handle
      assert system_model["pictureUrl"] == fixture.picture_url
      assert length(system_model["partNumbers"]["edges"]) == length(fixture.part_number_strings)

      Enum.each(fixture.part_number_strings, fn pn ->
        assert(%{"node" => %{"partNumber" => pn}} in system_model["partNumbers"]["edges"])
      end)

      assert system_model["hardwareType"]["id"] ==
               AshGraphql.Resource.encode_relay_id(hardware_type)
    end

    test "allows filtering", %{tenant: tenant} do
      _ = system_model_fixture(tenant: tenant, handle: "foo")
      _ = system_model_fixture(tenant: tenant, handle: "bar", part_numbers: ["123-bar"])
      _ = system_model_fixture(tenant: tenant, handle: "baz")

      filter = %{
        "or" => [
          %{"handle" => %{"eq" => "foo"}},
          %{
            "partNumbers" => %{"partNumber" => %{"eq" => "123-bar"}}
          }
        ]
      }

      assert system_models =
               [tenant: tenant, filter: filter] |> system_models_query() |> extract_result!()

      assert length(system_models) == 2
      assert "foo" in Enum.map(system_models, & &1["handle"])
      assert "bar" in Enum.map(system_models, & &1["handle"])
      refute "baz" in Enum.map(system_models, & &1["handle"])
    end

    test "allows sorting", %{tenant: tenant} do
      _ = system_model_fixture(tenant: tenant, handle: "3")
      _ = system_model_fixture(tenant: tenant, handle: "2")
      _ = system_model_fixture(tenant: tenant, handle: "1")

      sort = [
        %{"field" => "HANDLE", "order" => "ASC"}
      ]

      assert system_models =
               [tenant: tenant, sort: sort] |> system_models_query() |> extract_result!()

      assert [
               %{"handle" => "1"},
               %{"handle" => "2"},
               %{"handle" => "3"}
             ] = system_models
    end

    test "exposes aggregates, baseImageCollection, hasPicture, defaultDescription, search, and device queries",
         %{tenant: tenant} do
      hw = hardware_type_fixture(tenant: tenant, name: "ARM Gateway", handle: "arm-gateway")

      model =
        system_model_fixture(
          tenant: tenant,
          name: "Edge Sensor",
          handle: "edge-sensor",
          hardware_type_id: hw.id,
          part_numbers: ["PN-100", "PN-200"],
          picture_url: "https://example.com/sensor.png",
          localized_descriptions: [
            %{language_tag: "it-IT", value: "Sensore industriale"},
            %{language_tag: "en-US", value: "Industrial sensor"}
          ]
        )

      bic =
        base_image_collection_fixture(
          tenant: tenant,
          name: "Sensor OS",
          handle: "sensor-os",
          system_model_id: model.id
        )

      _d1 = device_fixture(tenant: tenant, part_number: "PN-100", online: true)
      _d2 = device_fixture(tenant: tenant, part_number: "PN-200", online: false)
      _unmapped = device_fixture(tenant: tenant, part_number: "PN-UNMAPPED", online: true)

      model_relay_id = AshGraphql.Resource.encode_relay_id(model)
      bic_name = bic.name

      doc = """
      query ($modelId: ID!) {
        systemModels(search: "PN-200") {
          edges {
            node {
              name
              hasPicture
              partNumberCount
              deviceCount
              onlineDeviceCount
              releaseCount
              hasBaseImageCollection
              baseImageCollection {
                name
              }
              defaultDescription {
                languageTag
                value
              }
              hardwareType {
                systemModelCount
              }
              partNumbers(sort: [{ field: PART_NUMBER, order: ASC }]) {
                edges {
                  node {
                    partNumber
                    deviceCount
                    onlineDeviceCount
                  }
                }
              }
            }
          }
        }
        systemModelPartNumbers(filter: { partNumber: { in: ["PN-100"] } }) {
          count
          edges {
            node {
              partNumber
              deviceCount
              onlineDeviceCount
              systemModel {
                name
              }
            }
          }
        }
        devicesForSystemModel(systemModelId: $modelId) {
          count
        }
        mappedDevices: devices(filter: { hasSystemModel: { eq: true } }) {
          count
        }
      }
      """

      result =
        Absinthe.run!(doc, EdgehogWeb.Schema,
          variables: %{"modelId" => model_relay_id},
          context: %{tenant: tenant, actor: %{}}
        )

      assert %{
               data: %{
                 "systemModels" => %{
                   "edges" => [
                     %{
                       "node" => %{
                         "name" => "Edge Sensor",
                         "hasPicture" => true,
                         "partNumberCount" => 2,
                         "deviceCount" => 2,
                         "onlineDeviceCount" => 1,
                         "releaseCount" => 0,
                         "hasBaseImageCollection" => true,
                         "baseImageCollection" => %{"name" => ^bic_name},
                         "defaultDescription" => %{
                           "languageTag" => "en-US",
                           "value" => "Industrial sensor"
                         },
                         "hardwareType" => %{"systemModelCount" => 1},
                         "partNumbers" => %{
                           "edges" => [
                             %{
                               "node" => %{
                                 "partNumber" => "PN-100",
                                 "deviceCount" => 1,
                                 "onlineDeviceCount" => 1
                               }
                             },
                             %{
                               "node" => %{
                                 "partNumber" => "PN-200",
                                 "deviceCount" => 1,
                                 "onlineDeviceCount" => 0
                               }
                             }
                           ]
                         }
                       }
                     }
                   ]
                 },
                 "systemModelPartNumbers" => %{
                   "count" => 1,
                   "edges" => [
                     %{
                       "node" => %{
                         "partNumber" => "PN-100",
                         "deviceCount" => 1,
                         "onlineDeviceCount" => 1,
                         "systemModel" => %{"name" => "Edge Sensor"}
                       }
                     }
                   ]
                 },
                 "devicesForSystemModel" => %{"count" => 2},
                 "mappedDevices" => %{"count" => 2}
               }
             } = result
    end
  end

  defp system_models_query(opts) do
    default_document =
      """
      query SystemModels($filter: SystemModelFilterInput, $sort: [SystemModelSortInput]) {
        systemModels(filter: $filter, sort: $sort) {
          count
          edges {
            node {
              name
              handle
              pictureUrl
              partNumbers {
                edges {
                  node {
                    partNumber
                  }
                }
              }
              hardwareType {
                id
              }
            }
          }
        }
      }
      """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    document = Keyword.get(opts, :document, default_document)

    variables =
      %{
        "filter" => opts[:filter] || %{},
        "sort" => opts[:sort] || []
      }

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: variables,
      context: %{tenant: tenant, actor: %{}}
    )
  end

  defp extract_result!(result) do
    assert %{data: %{"systemModels" => %{"count" => count, "edges" => edges}}} = result
    refute :errors in Map.keys(result)

    system_models = Enum.map(edges, & &1["node"])

    assert length(system_models) == count

    system_models
  end
end
