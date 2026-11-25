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

defmodule Edgehog.Tenants.Tenant.Calculations.UnmappedPartNumbers do
  @moduledoc """
  Ash calculation returning distinct non-empty device part numbers in each
  tenant that have no corresponding `SystemModelPartNumber` entry, grouped in
  SQL with total and online device counts.
  """
  use Ash.Resource.Calculation

  import Ecto.Query

  alias Edgehog.Devices.SystemModelPartNumber.UnmappedPartNumber
  alias Edgehog.Repo

  @impl Ash.Resource.Calculation
  def calculate(tenants, _opts, _context) do
    tenant_ids = Enum.map(tenants, & &1.tenant_id)

    query =
      from(d in "devices",
        left_join: smpn in "system_model_part_numbers",
        on: smpn.tenant_id == d.tenant_id and smpn.part_number == d.part_number,
        where:
          d.tenant_id in ^tenant_ids and
            not is_nil(d.part_number) and
            fragment("btrim(?) <> ''", d.part_number) and
            is_nil(smpn.id),
        group_by: [d.tenant_id, d.part_number],
        order_by: [asc: d.part_number],
        select: {
          d.tenant_id,
          d.part_number,
          count(d.id),
          fragment("COUNT(*) FILTER (WHERE ?)", d.online)
        }
      )

    rows = Repo.all(query)

    by_tenant =
      Enum.group_by(
        rows,
        &elem(&1, 0),
        fn {_tenant_id, part_number, total, online} ->
          %UnmappedPartNumber{
            part_number: part_number,
            device_count: total,
            online_device_count: online
          }
        end
      )

    Enum.map(tenants, &Map.get(by_tenant, &1.tenant_id, []))
  end
end
