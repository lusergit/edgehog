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

defmodule Edgehog.Campaigns.Channel.Calculations.FleetReach do
  @moduledoc """
  Ash calculation returning the deduplicated `%FleetReach{}` across a channel's
  assigned `target_groups` using a single OR-disjunction query per channel.
  """
  use Ash.Resource.Calculation

  alias Edgehog.Campaigns.Channel.FleetReach
  alias Edgehog.Campaigns.Channel.SystemModelCount
  alias Edgehog.Devices.Device
  alias Edgehog.Selector

  require Ash.Query

  @impl Ash.Resource.Calculation
  def load(_query, _opts, _context) do
    [target_groups: [:selector]]
  end

  @impl Ash.Resource.Calculation
  def calculate(channels, _opts, %{tenant: tenant}) do
    Enum.map(channels, fn channel ->
      selectors =
        channel.target_groups
        |> List.wrap()
        |> Enum.map(& &1.selector)

      compute_for_selectors(selectors, tenant)
    end)
  end

  @doc """
  Computes `%FleetReach{}` from a list of loaded `Device` structs (each with
  `:online` and `:system_model` loaded).
  """
  def from_devices(devices) when is_list(devices) do
    total_count = length(devices)
    online_count = Enum.count(devices, &(&1.online == true))

    system_model_counts =
      devices
      |> Enum.reduce(%{}, &accumulate_system_model/2)
      |> Map.values()
      |> Enum.sort_by(&{&1.name, &1.id})

    %FleetReach{
      total_count: total_count,
      online_count: online_count,
      system_model_counts: system_model_counts
    }
  end

  defp compute_for_selectors(selectors, tenant) do
    case Selector.union_ash_expr(selectors) do
      {:ok, filter_expr} ->
        Device
        |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
        |> Ash.Query.filter(^filter_expr)
        |> Ash.Query.select([:id, :online, :part_number])
        |> Ash.Query.load(:system_model)
        |> Ash.read!(tenant: tenant, authorize?: false)
        |> from_devices()

      :empty ->
        %FleetReach{total_count: 0, online_count: 0, system_model_counts: []}
    end
  end

  defp accumulate_system_model(%{system_model: %{id: id, name: name, handle: handle}}, acc) do
    Map.update(
      acc,
      id,
      %SystemModelCount{id: id, name: name, handle: handle, device_count: 1},
      fn entry -> %{entry | device_count: entry.device_count + 1} end
    )
  end

  defp accumulate_system_model(_device, acc), do: acc
end
