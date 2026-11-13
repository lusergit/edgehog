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

defmodule EdgehogWeb.Components.CatalogComponents do
  @moduledoc """
  Shared UI components and PubSub routing helpers for catalog search/filter
  toolbars (`<.search_toolbar>`), empty states (`<.empty_state>`), discovery
  trays (`<.discovery_tray>`), and live device cohort Cinder tables
  (`<.devices_cinder_table>` + `forward_device_cell_broadcast/3`).
  """
  use Phoenix.Component
  use Gettext, backend: EdgehogWeb.Gettext

  import EdgehogWeb.Components.IconComponents

  alias EdgehogWeb.DevicesLive.LastSeenCellComponent
  alias EdgehogWeb.DevicesLive.NameCellComponent
  alias EdgehogWeb.DevicesLive.StatusCellComponent
  alias EdgehogWeb.DevicesLive.TagsCellComponent

  attr :form_id, :string, required: true
  attr :search, :string, required: true
  attr :placeholder, :string, required: true
  attr :aria_label, :string, required: true
  attr :pills_id, :string, required: true
  attr :pills_label, :string, required: true
  attr :filter, :string, required: true
  attr :pills, :list, required: true
  slot :filter_control

  def search_toolbar(assigns) do
    ~H"""
    <div class="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
      <div class={[
        "flex flex-col sm:flex-row sm:items-center gap-2.5 w-full",
        if(@filter_control != [], do: "lg:max-w-xl", else: "sm:max-w-xs")
      ]}>
        <form
          id={@form_id}
          phx-change="search"
          phx-submit="search"
          class="relative flex-1"
        >
          <.icon
            name="hero-magnifying-glass"
            class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-base-content/45"
          />
          <input
            type="search"
            name="search"
            value={@search}
            placeholder={@placeholder}
            phx-debounce="150"
            class="input input-sm w-full pl-9 bg-base-100"
            aria-label={@aria_label}
          />
        </form>

        {render_slot(@filter_control)}
      </div>

      <div
        id={@pills_id}
        role="group"
        aria-label={@pills_label}
        class="flex flex-wrap items-center gap-1.5"
      >
        <button
          :for={{key, label, count} <- @pills}
          type="button"
          phx-click="filter"
          phx-value-filter={key}
          data-filter={key}
          data-active={to_string(@filter == key)}
          class={[
            "btn btn-xs rounded-full gap-1.5 font-medium transition-colors",
            if(@filter == key,
              do: "btn-primary",
              else: "btn-ghost border border-base-300 bg-base-100 text-base-content/70"
            )
          ]}
        >
          <span>{label}</span>
          <span class="font-mono text-[11px] tabular-nums opacity-75">{count}</span>
        </button>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :query, :any, required: true
  attr :tenant, :map, required: true
  attr :show_hardware_columns, :boolean, default: false

  def devices_cinder_table(assigns) do
    ~H"""
    <Cinder.collection
      id={@id}
      query={@query}
      tenant={@tenant}
      page_size={[default: 15, options: [10, 15, 25, 50]]}
      search={false}
    >
      <:col :let={device} field="online" sort label="Status">
        <.live_component
          module={StatusCellComponent}
          id={"device-status-#{device.id}"}
          device={device}
        />
      </:col>

      <:col :let={device} field="name" sort search label="Device">
        <.live_component
          module={NameCellComponent}
          id={"device-name-#{device.id}"}
          device={device}
        />
      </:col>

      <:col :let={device} :if={not @show_hardware_columns} field="device_id" hidden label="Device ID">
        <span class="font-mono text-base-content/55 tabular-nums">
          {device.device_id}
        </span>
      </:col>

      <:col :let={device} :if={@show_hardware_columns} field="part_number" sort label="Part Number">
        <span class="font-mono text-xs text-base-content/75">
          {device.part_number}
        </span>
      </:col>

      <:col :let={device} :if={@show_hardware_columns} field="serial_number" label="Serial Number">
        <span class="font-mono text-xs text-base-content/60">
          {device.serial_number || "—"}
        </span>
      </:col>

      <:col :let={device} field="last_connection" sort label="Last Seen">
        <.live_component
          module={LastSeenCellComponent}
          id={"device-last-seen-#{device.id}"}
          device={device}
        />
      </:col>

      <:col :let={device} field="tags" label="Tags">
        <.live_component
          module={TagsCellComponent}
          id={"device-tags-#{device.id}"}
          device={device}
          tenant={@tenant}
        />
      </:col>
    </Cinder.collection>
    """
  end

  @doc """
  Routes granular `"devices:" <> rest` Ash PubSub broadcasts to the matching
  `DevicesLive` cell LiveComponent (`StatusCellComponent`, `NameCellComponent`,
  `LastSeenCellComponent`, or `TagsCellComponent`).

  Returns `:handled` when a cell component was targeted, or `:unhandled` for
  tenant-level broadcasts (`"devices:tenant:..."`).
  """
  def forward_device_cell_broadcast(rest, device, socket) when is_binary(rest) do
    case String.split(rest, ":", parts: 2) do
      [event, id] when event in ["online", "offline"] ->
        Phoenix.LiveView.send_update(StatusCellComponent,
          id: "device-status-#{id}",
          device: device
        )

        :handled

      ["name", id] ->
        Phoenix.LiveView.send_update(NameCellComponent, id: "device-name-#{id}", device: device)
        :handled

      ["connection", id] ->
        Phoenix.LiveView.send_update(LastSeenCellComponent,
          id: "device-last-seen-#{id}",
          device: device
        )

        :handled

      ["tags", id] ->
        Phoenix.LiveView.send_update(TagsCellComponent,
          id: "device-tags-#{id}",
          device: device,
          tenant: socket.assigns.current_tenant
        )

        :handled

      _ ->
        :unhandled
    end
  end

  attr :id, :string, required: true
  attr :icon, :string, required: true
  attr :filtered?, :boolean, required: true
  attr :filtered_title, :string, required: true
  attr :empty_title, :string, required: true
  attr :filtered_subtitle, :string, required: true
  attr :empty_subtitle, :string, required: true
  attr :clear_button_id, :string, required: true
  attr :clear_event, :string, default: "clear_filters"

  def empty_state(assigns) do
    ~H"""
    <div id={@id} class="card card-border bg-base-100 p-10 text-center shadow-xs">
      <div class="mx-auto flex size-12 items-center justify-center rounded-full bg-base-200 text-base-content/50">
        <.icon name={@icon} class="size-6" />
      </div>
      <h2 class="mt-3 text-base font-semibold text-base-content">
        {if(@filtered?, do: @filtered_title, else: @empty_title)}
      </h2>
      <p class="mt-1 text-sm text-base-content/60 max-w-md mx-auto">
        {if(@filtered?, do: @filtered_subtitle, else: @empty_subtitle)}
      </p>
      <div :if={@filtered?} class="mt-4">
        <button
          id={@clear_button_id}
          type="button"
          phx-click={@clear_event}
          class="btn btn-sm btn-ghost border border-base-300"
        >
          {gettext("Reset filters")}
        </button>
      </div>
    </div>
    """
  end

  attr :icon, :string, required: true
  attr :icon_class, :string, default: "text-base-content/60"
  attr :title, :string, required: true
  attr :count, :integer, required: true
  attr :count_id, :string, required: true

  attr :count_badge_class, :string,
    default: "badge-neutral border-base-300 bg-base-200/80 text-base-content/80"

  attr :subtitle, :string, required: true
  attr :list_id, :string, required: true
  attr :empty_notice_id, :string, required: true
  attr :empty_notice_text, :string, required: true
  slot :inner_block

  def discovery_tray(assigns) do
    ~H"""
    <div class="flex flex-col gap-1 sm:flex-row sm:items-center sm:justify-between">
      <div class="flex items-center gap-2">
        <.icon name={@icon} class={["size-4", @icon_class]} />
        <h2 class="text-sm font-semibold text-base-content">{@title}</h2>
        <span
          id={@count_id}
          class={["badge badge-soft badge-xs font-mono tabular-nums", @count_badge_class]}
        >
          {@count}
        </span>
      </div>
      <p class="text-xs text-base-content/60">{@subtitle}</p>
    </div>

    <div :if={@count > 0} id={@list_id} class="mt-3 flex flex-wrap gap-2">
      {render_slot(@inner_block)}
    </div>

    <p
      :if={@count == 0}
      id={@empty_notice_id}
      class="mt-2.5 text-xs text-success flex items-center gap-1.5"
    >
      <.icon name="hero-check-circle" class="size-4 shrink-0" />
      <span>{@empty_notice_text}</span>
    </p>
    """
  end
end
