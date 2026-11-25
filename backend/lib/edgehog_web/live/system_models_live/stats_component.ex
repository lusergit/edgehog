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

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    scope = assigns.scope
    stats = compute_stats(scope)

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
      <.stat_card
        label={gettext("System Models")}
        icon="hero-device-tablet"
        icon_class="text-primary"
        value_id="stat-total-models"
        value={@total_models}
        caption_id="stat-hardware-types-covered"
        caption={"#{@covered_hardware_types} / #{@total_hardware_types} hardware types"}
      />
      <.stat_card
        label={gettext("Mapped Fleet")}
        icon="hero-cpu-chip"
        icon_class="text-info"
        value_id="stat-mapped-devices"
        value={@mapped_devices}
        total={@total_devices}
        badge={"#{@coverage_pct}%"}
        badge_id="stat-mapped-coverage-pct"
        progress={@coverage_pct}
      />
      <.stat_card
        label={gettext("Online Matched")}
        icon="hero-signal"
        icon_class="text-success"
        value_id="stat-online-mapped-devices"
        value={@online_mapped_devices}
        total={@mapped_devices}
        badge={"#{@online_mapped_pct}% online"}
        badge_id="stat-online-mapped-pct"
        badge_class="font-mono text-xs font-medium tabular-nums text-success"
        caption={gettext("Connected devices with a catalog model")}
      />
      <.stat_card
        label={gettext("Part Numbers")}
        icon="hero-qr-code"
        value_id="stat-total-part-numbers"
        value={@total_part_numbers}
        badge={if(@unmapped_part_numbers_count > 0, do: "#{@unmapped_part_numbers_count} unmapped")}
        badge_id="stat-unmapped-part-numbers"
        badge_class="badge badge-soft badge-warning badge-xs font-mono font-medium tabular-nums"
        caption={
          if(@unmapped_part_numbers_count > 0,
            do: "#{@unmapped_devices_count} fleet devices with unmapped PNs",
            else: gettext("All fleet part numbers mapped")
          )
        }
      />
    </section>
    """
  end

  defp compute_stats(scope) do
    loaded =
      Ash.load!(
        scope.current_tenant,
        [
          :system_model_count,
          :hardware_type_count,
          :covered_hardware_type_count,
          :system_model_part_number_count,
          :device_count,
          :mapped_device_count,
          :online_mapped_device_count,
          :unmapped_device_count,
          :unmapped_part_numbers
        ],
        scope: scope,
        reuse_values?: false
      )

    coverage_pct =
      if loaded.device_count > 0 do
        round(loaded.mapped_device_count / loaded.device_count * 100)
      else
        0
      end

    online_mapped_pct =
      if loaded.mapped_device_count > 0 do
        round(loaded.online_mapped_device_count / loaded.mapped_device_count * 100)
      else
        0
      end

    %{
      total_models: loaded.system_model_count,
      covered_hardware_types: loaded.covered_hardware_type_count,
      total_hardware_types: loaded.hardware_type_count,
      total_part_numbers: loaded.system_model_part_number_count,
      total_devices: loaded.device_count,
      mapped_devices: loaded.mapped_device_count,
      online_mapped_devices: loaded.online_mapped_device_count,
      coverage_pct: coverage_pct,
      online_mapped_pct: online_mapped_pct,
      unmapped_part_numbers_count: length(loaded.unmapped_part_numbers),
      unmapped_devices_count: loaded.unmapped_device_count
    }
  end
end
