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

  @impl Phoenix.LiveComponent
  def update(%{group: group, scope: scope} = assigns, socket) do
    counts = compute_fleet_counts(group, scope, Map.get(assigns, :reload?, false))

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
      <.fleet_health_bar compact total={@total_count} online={@online_count} pct={@online_pct} />
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

  defp compute_fleet_counts(group, scope, reload?) do
    loaded =
      if not reload? and is_integer(group.device_count) and is_integer(group.online_device_count) do
        group
      else
        Ash.load!(group, [:device_count, :online_device_count],
          scope: scope,
          reuse_values?: false
        )
      end

    total_count = loaded.device_count
    online_count = loaded.online_device_count
    online_pct = if total_count > 0, do: round(online_count / total_count * 100), else: 0

    %{total_count: total_count, online_count: online_count, online_pct: online_pct}
  end
end
