#
# This file is part of Edgehog.
#
# Copyright 2021 SECO Mind Srl
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

alias Edgehog.{
  Appliances,
  Astarte,
  Tenants
}

{:ok, cluster} =
  Astarte.create_cluster(%{
    name: "Test Cluster",
    base_api_url: "https://api.astarte.example.com"
  })

{:ok, tenant} = Tenants.create_tenant(%{name: "ACME Inc", slug: "acme-inc"})

_ = Edgehog.Repo.put_tenant_id(tenant.tenant_id)

{:ok, realm} = Astarte.create_realm(cluster, %{name: "test", private_key: "notaprivatekey"})

{:ok, hardware_type} =
  Appliances.create_hardware_type(%{
    handle: "some-hardware-type",
    name: "Some hardware type",
    part_numbers: ["HT-1234"]
  })

{:ok, appliance_model} =
  Appliances.create_appliance_model(hardware_type, %{
    handle: "some-appliance-model",
    name: "Some appliance model",
    part_numbers: ["AM-1234"]
  })

{:ok, _device} =
  Astarte.create_device(realm, %{
    name: "Thingie",
    device_id: "DqL4H107S42WBEHmDrvPLQ",
    part_number: "AM-1234"
  })
