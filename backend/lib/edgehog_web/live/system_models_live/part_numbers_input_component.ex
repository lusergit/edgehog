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

defmodule EdgehogWeb.SystemModelsLive.PartNumbersInputComponent do
  @moduledoc """
  Stateless function components and domain helpers for the dynamic part-numbers
  editor inside `SystemModelFormComponent`.

  Detects when entered part numbers match unmapped fleet devices or will be
  reassociated ("stolen") from another `SystemModel`, and computes the live
  matched fleet preview.
  """
  use EdgehogWeb, :html

  alias Edgehog.Devices.SystemModelPartNumber
  alias EdgehogWeb.SystemModelsLive.ModelFleetComponent

  require Ash.Query

  @doc """
  Returns the initial part-number rows for `:edit` or `:new` (supporting
  `?part_number=` prefill).
  """
  def initial_part_number_rows(model, :edit, _initial_pn) do
    case ModelFleetComponent.extract_part_number_strings(model) do
      [] -> [""]
      pns -> pns
    end
  end

  def initial_part_number_rows(_model, :new, initial_pn)
      when is_binary(initial_pn) and initial_pn != "" do
    [String.trim(initial_pn)]
  end

  def initial_part_number_rows(_model, :new, _initial_pn), do: [""]

  @doc """
  Trims, deduplicates, and removes empty entries from `rows`.
  """
  def clean_part_numbers(rows) when is_list(rows) do
    rows
    |> Enum.map(&(&1 |> to_string() |> String.trim()))
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  def clean_part_numbers(_rows), do: []

  @doc """
  Analyzes the list of raw part-number input rows against registered
  `SystemModelPartNumber` SQL aggregates and `Tenant.unmapped_part_numbers`,
  returning annotated row items, stolen entries, and live fleet reach preview.
  """
  def analyze_part_numbers(raw_rows, current_model_id, scope) when is_list(raw_rows) do
    unique_pns = clean_part_numbers(raw_rows)
    lookup = build_lookup(unique_pns, current_model_id, scope)

    rows =
      raw_rows
      |> Enum.with_index()
      |> Enum.map(fn {raw_value, index} ->
        build_row_item(raw_value, index, lookup)
      end)

    unique_non_empty =
      rows
      |> Enum.reject(&(&1.trimmed == ""))
      |> Enum.uniq_by(& &1.trimmed)

    stolen_entries =
      Enum.filter(unique_non_empty, &(&1.state == :stolen))

    {total, online} =
      Enum.reduce(unique_non_empty, {0, 0}, fn row, {acc_total, acc_online} ->
        {acc_total + row.device_count, acc_online + row.online_count}
      end)

    pct = if total > 0, do: round(online / total * 100), else: 0

    %{
      rows: rows,
      stolen_entries: stolen_entries,
      preview_reach: %{total: total, online: online, pct: pct}
    }
  end

  defp build_lookup([], _current_model_id, _scope) do
    %{registered: %{}, unmapped: %{}, current_model_id: nil}
  end

  defp build_lookup(unique_pns, current_model_id, scope) do
    registered =
      SystemModelPartNumber
      |> Ash.Query.for_read(:read, %{}, scope: scope)
      |> Ash.Query.filter(part_number in ^unique_pns)
      |> Ash.Query.load([:system_model, :device_count, :online_device_count])
      |> Ash.read!(scope: scope)
      |> Map.new(&{&1.part_number, &1})

    unmapped =
      if length(unique_pns) > map_size(registered) do
        scope.current_tenant
        |> Ash.load!(:unmapped_part_numbers,
          scope: scope,
          reuse_values?: false
        )
        |> Map.fetch!(:unmapped_part_numbers)
        |> Map.new(&{&1.part_number, &1})
      else
        %{}
      end

    %{registered: registered, unmapped: unmapped, current_model_id: current_model_id}
  end

  defp build_row_item(raw_value, index, lookup) do
    value = to_string(raw_value || "")
    trimmed = String.trim(value)

    case resolve_part_number(trimmed, lookup) do
      {state, owner, device_count, online_count} ->
        %{
          index: index,
          value: value,
          trimmed: trimmed,
          state: state,
          owner: owner,
          device_count: device_count,
          online_count: online_count
        }
    end
  end

  defp resolve_part_number("", _lookup), do: {:empty, nil, 0, 0}

  defp resolve_part_number(pn, lookup) do
    case Map.get(lookup.registered, pn) do
      %SystemModelPartNumber{
        system_model_id: owner_id,
        system_model: owner,
        device_count: total,
        online_device_count: online
      }
      when is_integer(owner_id) and owner_id == lookup.current_model_id ->
        {:current, owner, total, online}

      %SystemModelPartNumber{
        system_model: %{id: _id} = owner,
        device_count: total,
        online_device_count: online
      } ->
        {:stolen, owner, total, online}

      _ ->
        case Map.get(lookup.unmapped, pn) do
          %{device_count: total, online_device_count: online} when total > 0 ->
            {:unmapped_match, nil, total, online}

          _ ->
            {:new, nil, 0, 0}
        end
    end
  end

  attr :rows, :list, required: true
  attr :part_numbers_error, :string, default: nil
  attr :myself, :any, required: true

  def part_numbers_input(assigns) do
    ~H"""
    <div class="space-y-2.5">
      <div class="flex items-center justify-between gap-2">
        <div>
          <label class="text-xs font-semibold uppercase tracking-wider text-base-content/70">
            {gettext("Part Numbers")} <span class="text-error">*</span>
          </label>
          <p class="text-[11px] text-base-content/55">
            {gettext("Devices reporting any of these part numbers resolve to this system model.")}
          </p>
        </div>

        <button
          id="add-part-number-btn"
          type="button"
          phx-click="add_part_number"
          phx-target={@myself}
          class="btn btn-xs btn-outline border-base-300 bg-base-100 rounded-full gap-1 font-medium"
        >
          <.icon name="hero-plus" class="size-3.5" />
          <span>{gettext("Add Part Number")}</span>
        </button>
      </div>

      <div
        :if={@part_numbers_error}
        id="system-model-part-numbers-error"
        class="alert alert-error text-xs py-2 px-3"
      >
        <.icon name="hero-exclamation-circle" class="size-4 shrink-0" />
        <span>{@part_numbers_error}</span>
      </div>

      <div id="system-model-part-numbers-list" class="space-y-2">
        <div
          :for={row <- @rows}
          id={"part-number-row-#{row.index}"}
          class="rounded-2xl border border-base-300/80 bg-base-200/30 p-2.5 space-y-1.5"
        >
          <div class="flex items-center gap-2">
            <div class="relative flex-1">
              <.icon
                name="hero-qr-code"
                class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-base-content/45"
              />
              <input
                type="text"
                id={"part-number-input-#{row.index}"}
                name="system_model[part_numbers][]"
                value={row.value}
                placeholder="e.g. C-E-SCOOTER-1"
                phx-debounce="150"
                class="input input-sm w-full pl-9 font-mono text-xs bg-base-100"
                aria-label={"Part number #{row.index + 1}"}
              />
            </div>

            <button
              id={"remove-part-number-btn-#{row.index}"}
              type="button"
              phx-click="remove_part_number"
              phx-value-index={row.index}
              phx-target={@myself}
              disabled={length(@rows) <= 1}
              class="btn btn-ghost btn-xs btn-circle text-base-content/55 hover:text-error disabled:opacity-30"
              aria-label={gettext("Remove part number")}
            >
              <.icon name="hero-trash" class="size-4" />
            </button>
          </div>

          {render_row_status(row)}
        </div>
      </div>
    </div>
    """
  end

  defp render_row_status(%{state: :stolen} = assigns) do
    ~H"""
    <div
      data-part-number-steal="true"
      class="flex items-center justify-between gap-2 text-[11px] text-warning px-1"
    >
      <span class="flex items-center gap-1 font-medium">
        <.icon name="hero-arrows-right-left" class="size-3.5 shrink-0" />
        <span>
          Assigned to <strong>{@owner.name}</strong>
          <span class="font-mono">(@{@owner.handle})</span> · Will move here
        </span>
      </span>
      <span class="font-mono tabular-nums shrink-0">
        {@device_count} {if(@device_count == 1, do: "device", else: "devices")}
      </span>
    </div>
    """
  end

  defp render_row_status(%{state: :unmapped_match} = assigns) do
    ~H"""
    <div
      data-part-number-unmapped-match="true"
      class="flex items-center justify-between gap-2 text-[11px] text-success px-1"
    >
      <span class="flex items-center gap-1 font-medium">
        <.icon name="hero-check-circle" class="size-3.5 shrink-0" />
        <span>Matches unmapped fleet devices</span>
      </span>
      <span class="font-mono tabular-nums shrink-0">
        {@device_count} {if(@device_count == 1, do: "device", else: "devices")} ({@online_count} online)
      </span>
    </div>
    """
  end

  defp render_row_status(%{state: :current} = assigns) do
    ~H"""
    <div
      data-part-number-current="true"
      class="flex items-center justify-between gap-2 text-[11px] text-base-content/60 px-1"
    >
      <span>Currently assigned to this model</span>
      <span class="font-mono tabular-nums shrink-0">
        {@device_count} {if(@device_count == 1, do: "device", else: "devices")} ({@online_count} online)
      </span>
    </div>
    """
  end

  defp render_row_status(%{state: :new} = assigns) do
    ~H"""
    <div
      data-part-number-new="true"
      class="flex items-center justify-between gap-2 text-[11px] text-base-content/50 px-1"
    >
      <span>New catalog part number</span>
      <span class="font-mono tabular-nums shrink-0">0 devices in fleet</span>
    </div>
    """
  end

  defp render_row_status(_assigns), do: nil

  attr :stolen_entries, :list, required: true

  def steal_warning(assigns) do
    ~H"""
    <div
      :if={@stolen_entries != []}
      id="system-model-steal-warning"
      role="alert"
      class="alert alert-warning text-xs py-2.5 px-3 flex items-start gap-2"
    >
      <.icon name="hero-exclamation-triangle" class="size-4 shrink-0 mt-0.5" />
      <div class="space-y-1">
        <p class="font-semibold">
          {gettext("Part number reassociation notice")}
        </p>
        <p>
          {Enum.map_join(@stolen_entries, ", ", fn entry ->
            "#{entry.trimmed} (from #{entry.owner.name} @#{entry.owner.handle})"
          end)} will be moved to this system model on save, along with any matching fleet devices.
        </p>
      </div>
    </div>
    """
  end

  attr :preview_reach, :map, required: true

  def live_preview(assigns) do
    ~H"""
    <div
      id="system-model-live-preview"
      class="rounded-2xl border border-base-300/80 bg-base-200/30 p-3.5"
    >
      <div class="flex items-center justify-between gap-2">
        <span class="text-xs font-semibold uppercase tracking-wider text-base-content/60">
          {gettext("Live Matched Fleet Preview")}
        </span>
        <span class="font-mono text-xs font-medium tabular-nums text-success">
          <span data-role="model-online-devices">{@preview_reach.online} online</span>
          ({@preview_reach.pct}%)
        </span>
      </div>

      <div class="mt-1 flex items-baseline gap-1.5">
        <span
          data-role="model-total-devices"
          class="font-mono text-xl font-bold tabular-nums text-base-content"
        >
          {@preview_reach.total}
        </span>
        <span class="text-xs text-base-content/55">
          {if(@preview_reach.total == 1,
            do: gettext("fleet device matches entered part numbers"),
            else: gettext("fleet devices match entered part numbers")
          )}
        </span>
      </div>
    </div>
    """
  end
end
