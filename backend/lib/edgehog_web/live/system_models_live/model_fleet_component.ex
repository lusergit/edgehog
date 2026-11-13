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
  Stateless function component and batch fleet query helpers for computing and
  rendering a `SystemModel`'s matched device counts, online availability ratio,
  per-part-number distribution, and localized description.
  """
  use EdgehogWeb, :html

  alias Edgehog.Devices.Device
  alias Edgehog.Tenants.Tenant

  require Ash.Query

  attr :reach, :map, required: true

  def fleet_reach(assigns) do
    ~H"""
    <div class="border-t border-base-200 pt-3.5">
      <div class="flex items-center justify-between gap-2">
        <span class="text-xs font-semibold uppercase tracking-wider text-base-content/60">
          {gettext("Matched Fleet")}
        </span>
        <span
          data-role="model-reach-pct"
          class="font-mono text-xs font-medium tabular-nums text-base-content/60"
        >
          {@reach.pct}% online
        </span>
      </div>

      <div class="mt-1.5 flex items-baseline justify-between gap-2">
        <div class="flex items-baseline gap-1.5">
          <span
            data-role="model-total-devices"
            class="font-mono text-lg font-bold tabular-nums text-base-content"
          >
            {@reach.total}
          </span>
          <span class="text-xs text-base-content/55">
            {if(@reach.total == 1, do: gettext("device"), else: gettext("devices"))}
          </span>
        </div>
        <span
          data-role="model-online-devices"
          class="font-mono text-xs font-medium tabular-nums text-success"
        >
          {@reach.online} online
        </span>
      </div>

      <progress
        class={["progress mt-2 w-full", reach_progress_color(@reach)]}
        value={@reach.pct}
        max="100"
      />
    </div>
    """
  end

  @doc """
  Loads all devices in `tenant` in a single query (`[:id, :online, :part_number]`)
  and groups them by non-empty `part_number` so callers can compute reach across
  all `SystemModel`s without N+1 queries.
  """
  def load_devices_by_part_number(%Tenant{} = tenant) do
    devices =
      Device
      |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
      |> Ash.Query.select([:id, :online, :part_number])
      |> Ash.read!(tenant: tenant, authorize?: false)

    by_part_number =
      Enum.reduce(devices, %{}, fn device, acc ->
        accumulate_device_by_part_number(device, acc)
      end)

    %{
      total_devices: length(devices),
      by_part_number: by_part_number
    }
  end

  @doc """
  Computes matched device counts, online count, availability percentage, and
  per-part-number totals for `model` using either a precomputed
  `devices_by_part_number` map or a `%Tenant{}`.
  """
  def compute_model_reach(model, %Tenant{} = tenant) do
    model = ensure_part_numbers_loaded(model, tenant)
    %{by_part_number: by_part_number} = load_devices_by_part_number(tenant)
    compute_model_reach(model, by_part_number)
  end

  def compute_model_reach(model, by_part_number) when is_map(by_part_number) do
    part_numbers = extract_part_number_strings(model)

    {total, online, device_ids, counts_by_pn} =
      Enum.reduce(part_numbers, {0, 0, MapSet.new(), %{}}, fn pn, {tot, onl, ids, counts} ->
        bucket = Map.get(by_part_number, pn, %{total: 0, online: 0, device_ids: MapSet.new()})

        {
          tot + bucket.total,
          onl + bucket.online,
          MapSet.union(ids, bucket.device_ids),
          Map.put(counts, pn, %{total: bucket.total, online: bucket.online})
        }
      end)

    pct = if total > 0, do: round(online / total * 100), else: 0

    %{
      total: total,
      online: online,
      pct: pct,
      counts_by_part_number: counts_by_pn,
      device_ids: device_ids
    }
  end

  @doc """
  Builds an `Ash.Query` on `Edgehog.Devices.Device` matching devices whose
  `part_number` belongs to `model`.
  """
  def model_devices_query(model, tenant) do
    model = ensure_part_numbers_loaded(model, tenant)
    part_numbers = extract_part_number_strings(model)

    Device
    |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
    |> Ash.Query.load(:tags)
    |> Ash.Query.filter(part_number in ^part_numbers)
  end

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

  @doc """
  Extracts `{language_tag, text}` for `model`'s localized description,
  preferring `tenant.default_locale` and falling back to the first non-empty
  translation sorted by language tag, or `nil` if no description is defined.
  """
  def localized_description(model, tenant) do
    default_locale = Map.get(tenant || %{}, :default_locale, "en-US")
    entries = extract_description_entries(model)

    case Enum.find(entries, fn {tag, _val} -> tag == default_locale end) do
      {_tag, _val} = preferred -> preferred
      nil -> List.first(entries)
    end
  end

  defp extract_description_entries(%{localized_descriptions: list}) when is_list(list) do
    list
    |> Enum.flat_map(fn
      %{language_tag: tag, value: val} when is_binary(tag) and is_binary(val) ->
        trimmed = String.trim(val)
        if trimmed != "", do: [{tag, trimmed}], else: []

      _ ->
        []
    end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp extract_description_entries(%{description: map}) when is_map(map) do
    map
    |> Enum.flat_map(fn
      {tag, val} when is_binary(tag) and is_binary(val) ->
        trimmed = String.trim(val)
        if trimmed != "", do: [{tag, trimmed}], else: []

      _ ->
        []
    end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp extract_description_entries(_model), do: []

  defp accumulate_device_by_part_number(%{part_number: pn} = device, acc)
       when is_binary(pn) and pn != "" do
    online_inc = if device.online == true, do: 1, else: 0

    Map.update(
      acc,
      pn,
      %{total: 1, online: online_inc, device_ids: MapSet.new([device.id])},
      fn bucket ->
        %{
          bucket
          | total: bucket.total + 1,
            online: bucket.online + online_inc,
            device_ids: MapSet.put(bucket.device_ids, device.id)
        }
      end
    )
  end

  defp accumulate_device_by_part_number(_device, acc), do: acc

  defp ensure_part_numbers_loaded(%{part_numbers: pns} = model, _tenant) when is_list(pns),
    do: model

  defp ensure_part_numbers_loaded(model, tenant) do
    Ash.load!(model, :part_numbers, tenant: tenant, authorize?: false)
  end

  defp reach_progress_color(%{total: 0}), do: "progress-warning"
  defp reach_progress_color(%{online: 0}), do: "progress-error"
  defp reach_progress_color(_reach), do: "progress-success"
end
