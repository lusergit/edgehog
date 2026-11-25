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

defmodule Edgehog.Tenants.Tenant.Calculations.EmptyDeviceGroupCount do
  @moduledoc """
  Ash calculation returning the number of device groups in each tenant that
  currently match zero devices.
  """
  use Ash.Resource.Calculation

  alias Edgehog.Groups.DeviceGroup

  @impl Ash.Resource.Calculation
  def calculate(tenants, _opts, context) do
    Enum.map(tenants, fn tenant ->
      DeviceGroup
      |> Ash.Query.for_read(:read, %{}, scope: context, tenant: tenant)
      |> Ash.Query.load(:device_count)
      |> Ash.read!(scope: context, tenant: tenant)
      |> Enum.count(&(&1.device_count == 0))
    end)
  end
end
