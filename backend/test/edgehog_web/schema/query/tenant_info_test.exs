#
# This file is part of Edgehog.
#
# Copyright 2021-2026 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Query.TenantInfoTest do
  use Edgehog.DataCase, async: true

  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Tenants.Tenant

  describe "tenantInfo query" do
    test "returns the tenant info" do
      tenant = tenant_fixture()
      %Tenant{tenant_id: id, name: name, slug: slug, default_locale: default_locale} = tenant

      doc = """
      query {
        tenantInfo {
          id
          name
          slug
          defaultLocale
        }
      }
      """

      assert %{
               data: %{
                 "tenantInfo" => %{
                   "id" => graphql_id,
                   "name" => ^name,
                   "slug" => ^slug,
                   "defaultLocale" => ^default_locale
                 }
               }
             } = Absinthe.run!(doc, EdgehogWeb.Schema, context: %{tenant: tenant, actor: %{}})

      assert {:ok, %{type: :tenant_info, id: decoded_id}} =
               AshGraphql.Resource.decode_relay_id(graphql_id)

      assert decoded_id == to_string(id)
    end

    test "returns tenant-scoped device fleet aggregates" do
      tenant = tenant_fixture()
      other_tenant = tenant_fixture()

      _online = device_fixture(tenant: tenant, online: true)
      _offline = device_fixture(tenant: tenant, online: false)
      _other = device_fixture(tenant: other_tenant, online: true)

      doc = """
      query {
        tenantInfo {
          deviceCount
          onlineDeviceCount
        }
      }
      """

      assert %{
               data: %{
                 "tenantInfo" => %{
                   "deviceCount" => 2,
                   "onlineDeviceCount" => 1
                 }
               }
             } = Absinthe.run!(doc, EdgehogWeb.Schema, context: %{tenant: tenant, actor: %{}})
    end
  end
end
