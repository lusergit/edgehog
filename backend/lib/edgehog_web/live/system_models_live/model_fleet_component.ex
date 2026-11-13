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

defmodule EdgehogWeb.SystemModelsLive.ModelFleetComponent do
  @moduledoc """
  Stateless function component and pure presentation helpers for rendering a
  `SystemModel`'s SQL-aggregated fleet reach and per-part-number counts.
  """
  use EdgehogWeb, :html

  attr :total, :integer, required: true
  attr :online, :integer, required: true

  def fleet_reach(assigns) do
    pct = if assigns.total > 0, do: round(assigns.online / assigns.total * 100), else: 0
    assigns = assign(assigns, :pct, pct)

    ~H"""
    <.fleet_health_bar
      label={gettext("Matched Fleet")}
      total={@total}
      online={@online}
      pct={@pct}
      total_role="model-total-devices"
      online_role="model-online-devices"
      pct_role="model-reach-pct"
    />
    """
  end

  @doc """
  Builds a `%{part_number => %{total: integer, online: integer}}` lookup map
  from `SystemModelPartNumber` structs whose `:device_count` and
  `:online_device_count` aggregates are already loaded.
  """
  def counts_by_part_number(part_numbers) when is_list(part_numbers) do
    Map.new(part_numbers, fn pn ->
      total = if is_integer(pn.device_count), do: pn.device_count, else: 0
      online = if is_integer(pn.online_device_count), do: pn.online_device_count, else: 0
      {pn.part_number, %{total: total, online: online}}
    end)
  end

  def counts_by_part_number(_part_numbers), do: %{}

  @doc """
  Returns the sorted, deduplicated list of part number strings for `model`.
  """
  def extract_part_number_strings(%{part_numbers: part_numbers}) when is_list(part_numbers) do
    part_numbers
    |> Enum.map(fn
      %{part_number: pn} when is_binary(pn) -> pn
      pn when is_binary(pn) -> pn
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  def extract_part_number_strings(_model), do: []
end
