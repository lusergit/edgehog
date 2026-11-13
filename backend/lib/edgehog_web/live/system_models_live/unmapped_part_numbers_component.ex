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

defmodule EdgehogWeb.SystemModelsLive.UnmappedPartNumbersComponent do
  @moduledoc """
  Reactive `Phoenix.LiveComponent` rendering the discovery tray of connected
  fleet device `part_number`s that are not yet associated with any
  `Edgehog.Devices.SystemModel`.
  """
  use EdgehogWeb, :live_component

  alias Edgehog.Devices.SystemModel
  alias EdgehogWeb.SystemModelsLive.ModelFleetComponent

  @impl Phoenix.LiveComponent
  def update(%{tenant: tenant} = assigns, socket) do
    unmapped_entries = compute_unmapped_part_numbers(tenant)
    total_unmapped_devices = Enum.reduce(unmapped_entries, 0, &(&1.total + &2))

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:unmapped_entries, unmapped_entries)
     |> assign(:total_unmapped_devices, total_unmapped_devices)}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <section
      id={@id}
      aria-label="Unmapped device part numbers"
      class="card card-border bg-base-100 p-4 sm:p-5 shadow-xs"
    >
      <.discovery_tray
        icon={if(@unmapped_entries != [], do: "hero-exclamation-triangle", else: "hero-qr-code")}
        icon_class={if(@unmapped_entries != [], do: "text-warning", else: "text-base-content/55")}
        title={gettext("Unmapped Device Part Numbers")}
        count={length(@unmapped_entries)}
        count_id="unmapped-part-numbers-count"
        count_badge_class={if(@unmapped_entries != [], do: "badge-warning", else: "badge-neutral")}
        subtitle={
          if(@unmapped_entries != [],
            do:
              "#{@total_unmapped_devices} fleet device(s) reporting part numbers without a catalog System Model.",
            else: gettext("Part numbers reported by connected devices vs. catalog definitions.")
          )
        }
        list_id="unmapped-part-numbers-list"
        empty_notice_id="all-part-numbers-mapped-notice"
        empty_notice_text={
          gettext("All device part numbers in this tenant are mapped to a System Model.")
        }
      >
        <div
          :for={entry <- @unmapped_entries}
          id={"unmapped-pn-#{entry.part_number}"}
          data-part-number={entry.part_number}
          class="inline-flex items-center gap-2.5 rounded-xl border border-warning/35 bg-warning/5 px-3 py-1.5 text-xs text-base-content"
        >
          <div class="flex items-center gap-1.5">
            <.icon name="hero-qr-code" class="size-3.5 text-warning shrink-0" />
            <span class="font-mono font-semibold">{entry.part_number}</span>
          </div>

          <span
            data-role="unmapped-pn-device-count"
            class="font-mono text-[11px] tabular-nums text-base-content/70"
          >
            {entry.total} {if(entry.total == 1, do: gettext("device"), else: gettext("devices"))} ({entry.online} online)
          </span>

          <.link
            patch={~p"/tenants/#{@tenant.slug}/system-models/new?#{[part_number: entry.part_number]}"}
            data-role="create-model-from-pn"
            class="btn btn-xs btn-ghost rounded-full border border-base-300 bg-base-100 gap-1 px-2 text-[11px] font-medium hover:border-primary/40 hover:text-primary"
          >
            <.icon name="hero-plus" class="size-3" />
            <span>{gettext("Create Model")}</span>
          </.link>
        </div>
      </.discovery_tray>
    </section>
    """
  end

  defp compute_unmapped_part_numbers(tenant) do
    models =
      SystemModel
      |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
      |> Ash.Query.load(:part_numbers)
      |> Ash.read!(tenant: tenant, authorize?: false)

    registered_pns =
      models
      |> Enum.flat_map(&ModelFleetComponent.extract_part_number_strings/1)
      |> MapSet.new()

    %{by_part_number: by_part_number} = ModelFleetComponent.load_devices_by_part_number(tenant)

    by_part_number
    |> Enum.reduce([], fn {pn, bucket}, acc ->
      if MapSet.member?(registered_pns, pn) do
        acc
      else
        [%{part_number: pn, total: bucket.total, online: bucket.online} | acc]
      end
    end)
    |> Enum.sort_by(& &1.part_number)
  end
end
