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

defmodule Edgehog.Groups.DeviceGroup.Calculations.DeviceCount do
  @moduledoc """
  Ash calculation returning the number of tenant devices matched by each
  `DeviceGroup`'s selector (optionally restricted to online devices).
  """
  use Ash.Resource.Calculation

  alias Edgehog.Devices.Device
  alias Edgehog.Selector

  require Ash.Query

  @impl Ash.Resource.Calculation
  def init(opts) do
    online_only? = Keyword.get(opts, :online_only?, false)

    if is_boolean(online_only?) do
      {:ok, Keyword.put(opts, :online_only?, online_only?)}
    else
      {:error, "expected :online_only? to be a boolean"}
    end
  end

  @impl Ash.Resource.Calculation
  def load(_query, _opts, _context) do
    [:selector]
  end

  @impl Ash.Resource.Calculation
  def calculate(groups, opts, context) do
    online_only? = Keyword.get(opts, :online_only?, false)
    Enum.map(groups, &count_for_group(&1, online_only?, context))
  end

  defp count_for_group(group, online_only?, context) do
    case Selector.to_ash_expr_safe(group.selector) do
      {:ok, expr} ->
        Device
        |> Ash.Query.for_read(:read, %{}, scope: context)
        |> Ash.Query.filter(^expr)
        |> maybe_filter_online(online_only?)
        |> Ash.count!(scope: context)

      {:error, _reason} ->
        0
    end
  end

  defp maybe_filter_online(query, true), do: Ash.Query.filter(query, online == true)
  defp maybe_filter_online(query, false), do: query
end
