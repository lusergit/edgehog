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

defmodule EdgehogWeb.DeviceGroupsLive.GroupFleetCellComponent do
  @moduledoc """
  Reactive table cell LiveComponent displaying the live count and online ratio
  of devices matched by a device group's selector.

  Registers itself with the parent LiveView so both selector updates and tenant
  device telemetry changes recompute this cell in place.
  """
  use EdgehogWeb, :live_component

  alias Edgehog.Devices.Device
  alias EdgehogWeb.DeviceGroupsLive.GroupsStatsComponent

  require Ash.Query

  @impl Phoenix.LiveComponent
  def update(%{group: group, tenant: tenant} = assigns, socket) do
    counts = compute_fleet_counts(group.selector, tenant)

    socket =
      socket
      |> assign(assigns)
      |> assign(counts)
      |> ensure_registered(group.id)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id={@id} class="inline-flex items-center">
      <span
        :if={@total_count == 0}
        data-fleet-state="empty"
        class="badge badge-soft badge-warning badge-sm gap-1.5 font-medium"
      >
        <.icon name="hero-exclamation-triangle" class="size-3.5" /> 0 devices
      </span>

      <div :if={@total_count > 0} data-fleet-state="active" class="flex flex-col gap-1 min-w-28">
        <div class="flex items-center gap-1.5">
          <span class={if(@online_count > 0, do: "status status-success", else: "status")}></span>
          <span class="text-xs font-semibold tabular-nums text-base-content">
            {@online_count} / {@total_count} online
          </span>
        </div>
        <progress
          class="progress progress-success h-1.5 w-24"
          value={@online_pct}
          max="100"
        />
      </div>
    </div>
    """
  end

  defp ensure_registered(socket, group_id) do
    if connected?(socket) and not Map.get(socket.assigns, :registered?, false) do
      send(self(), {:register_group_fleet_cell, group_id})
      assign(socket, :registered?, true)
    else
      socket
    end
  end

  defp compute_fleet_counts(selector, tenant) do
    case GroupsStatsComponent.selector_filter_expr(selector) do
      {:ok, expr} ->
        base_query =
          Device
          |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
          |> Ash.Query.filter(^expr)

        total_count = Ash.count!(base_query, tenant: tenant, authorize?: false)

        online_count =
          base_query
          |> Ash.Query.filter(online == true)
          |> Ash.count!(tenant: tenant, authorize?: false)

        online_pct =
          if total_count > 0 do
            round(online_count / total_count * 100)
          else
            0
          end

        %{total_count: total_count, online_count: online_count, online_pct: online_pct}

      :error ->
        %{total_count: 0, online_count: 0, online_pct: 0}
    end
  end
end
