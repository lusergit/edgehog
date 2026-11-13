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

defmodule EdgehogWeb.SystemModelsLive.StatsComponent do
  @moduledoc """
  LiveComponent rendering the 4-band operational KPI strip for a tenant's
  system models catalog (`System Models`, `Mapped Fleet`, `Online Matched`, and
  `Part Numbers`).
  """
  use EdgehogWeb, :live_component

  alias Edgehog.Devices.HardwareType
  alias Edgehog.Devices.SystemModel
  alias EdgehogWeb.SystemModelsLive.ModelFleetComponent

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    tenant = assigns.tenant
    stats = compute_stats(tenant)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(stats)}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <section
      id={@id}
      aria-label="System models catalog summary"
      class="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4"
    >
      <div class="card card-border bg-base-100 p-4 shadow-xs">
        <div class="flex items-center justify-between">
          <span class="text-xs font-semibold uppercase tracking-wider text-base-content/60">
            {gettext("System Models")}
          </span>
          <.icon name="hero-device-tablet" class="size-4 text-primary" />
        </div>
        <div class="mt-2 flex items-baseline gap-2">
          <p
            id="stat-total-models"
            class="font-mono text-2xl font-bold tabular-nums text-base-content"
          >
            {@total_models}
          </p>
        </div>
        <p id="stat-hardware-types-covered" class="mt-0.5 text-xs tabular-nums text-base-content/55">
          {@covered_hardware_types} / {@total_hardware_types} hardware types
        </p>
      </div>

      <div class="card card-border bg-base-100 p-4 shadow-xs">
        <div class="flex items-center justify-between">
          <span class="text-xs font-semibold uppercase tracking-wider text-base-content/60">
            {gettext("Mapped Fleet")}
          </span>
          <.icon name="hero-cpu-chip" class="size-4 text-info" />
        </div>
        <div class="mt-2 flex items-baseline justify-between gap-2">
          <p
            id="stat-mapped-devices"
            class="font-mono text-2xl font-bold tabular-nums text-base-content"
          >
            {@mapped_devices}
            <span class="text-base font-medium text-base-content/45">/ {@total_devices}</span>
          </p>
          <span
            id="stat-mapped-coverage-pct"
            class="font-mono text-xs font-medium tabular-nums text-base-content/60"
          >
            {@coverage_pct}%
          </span>
        </div>
        <progress
          class="progress progress-primary mt-2 w-full"
          value={@coverage_pct}
          max="100"
        />
      </div>

      <div class="card card-border bg-base-100 p-4 shadow-xs">
        <div class="flex items-center justify-between">
          <span class="text-xs font-semibold uppercase tracking-wider text-base-content/60">
            {gettext("Online Matched")}
          </span>
          <.icon name="hero-signal" class="size-4 text-success" />
        </div>
        <div class="mt-2 flex items-baseline justify-between gap-2">
          <p
            id="stat-online-mapped-devices"
            class="font-mono text-2xl font-bold tabular-nums text-base-content"
          >
            {@online_mapped_devices}
            <span class="text-base font-medium text-base-content/45">/ {@mapped_devices}</span>
          </p>
          <span
            id="stat-online-mapped-pct"
            class="font-mono text-xs font-medium tabular-nums text-success"
          >
            {@online_mapped_pct}% online
          </span>
        </div>
        <p class="mt-0.5 text-xs text-base-content/55">
          {gettext("Connected devices with a catalog model")}
        </p>
      </div>

      <div class="card card-border bg-base-100 p-4 shadow-xs">
        <div class="flex items-center justify-between">
          <span class="text-xs font-semibold uppercase tracking-wider text-base-content/60">
            {gettext("Part Numbers")}
          </span>
          <.icon name="hero-qr-code" class="size-4 text-base-content/45" />
        </div>
        <div class="mt-2 flex items-baseline gap-2">
          <p
            id="stat-total-part-numbers"
            class="font-mono text-2xl font-bold tabular-nums text-base-content"
          >
            {@total_part_numbers}
          </p>
          <span
            :if={@unmapped_part_numbers_count > 0}
            id="stat-unmapped-part-numbers"
            class="badge badge-soft badge-warning badge-xs font-mono font-medium tabular-nums"
          >
            {@unmapped_part_numbers_count} unmapped
          </span>
        </div>
        <p class="mt-0.5 text-xs text-base-content/55">
          {if(@unmapped_part_numbers_count > 0,
            do: "#{@unmapped_devices_count} fleet devices with unmapped PNs",
            else: gettext("All fleet part numbers mapped")
          )}
        </p>
      </div>
    </section>
    """
  end

  defp compute_stats(tenant) do
    models =
      SystemModel
      |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
      |> Ash.Query.load(:part_numbers)
      |> Ash.read!(tenant: tenant, authorize?: false)

    total_models = length(models)

    covered_hardware_types =
      models
      |> Enum.map(& &1.hardware_type_id)
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()
      |> MapSet.size()

    total_hardware_types = Ash.count!(HardwareType, tenant: tenant, authorize?: false)

    registered_pns =
      models
      |> Enum.flat_map(&ModelFleetComponent.extract_part_number_strings/1)
      |> MapSet.new()

    total_part_numbers = MapSet.size(registered_pns)

    %{total_devices: total_devices, by_part_number: by_part_number} =
      ModelFleetComponent.load_devices_by_part_number(tenant)

    {mapped_devices, online_mapped_devices} =
      Enum.reduce(registered_pns, {0, 0}, fn pn, {tot, onl} ->
        bucket = Map.get(by_part_number, pn, %{total: 0, online: 0})
        {tot + bucket.total, onl + bucket.online}
      end)

    {unmapped_part_numbers_count, unmapped_devices_count} =
      Enum.reduce(by_part_number, {0, 0}, fn {pn, bucket}, {pn_count, dev_count} ->
        if MapSet.member?(registered_pns, pn) do
          {pn_count, dev_count}
        else
          {pn_count + 1, dev_count + bucket.total}
        end
      end)

    coverage_pct =
      if total_devices > 0 do
        round(mapped_devices / total_devices * 100)
      else
        0
      end

    online_mapped_pct =
      if mapped_devices > 0 do
        round(online_mapped_devices / mapped_devices * 100)
      else
        0
      end

    %{
      total_models: total_models,
      covered_hardware_types: covered_hardware_types,
      total_hardware_types: total_hardware_types,
      total_part_numbers: total_part_numbers,
      total_devices: total_devices,
      mapped_devices: mapped_devices,
      online_mapped_devices: online_mapped_devices,
      coverage_pct: coverage_pct,
      online_mapped_pct: online_mapped_pct,
      unmapped_part_numbers_count: unmapped_part_numbers_count,
      unmapped_devices_count: unmapped_devices_count
    }
  end
end
