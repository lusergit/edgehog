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

defmodule EdgehogWeb.DeviceGroupsLive.GroupsStatsComponent do
  @moduledoc """
  LiveComponent rendering reactive summary metrics for a tenant's device groups
  (Total Groups, Channel-Linked, Empty Groups, and Fleet Coverage ratio).
  """
  use EdgehogWeb, :live_component

  alias Edgehog.Devices.Device

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
      aria-label="Device groups summary"
      class="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4"
    >
      <.stat_card
        label="Total Groups"
        icon="hero-user-group"
        value_id="stat-total-groups"
        value={@total_groups}
        caption="Dynamic selector partitions"
      />
      <.stat_card
        label="Channel-Linked"
        icon="hero-signal"
        icon_class="text-info"
        value_id="stat-linked-groups"
        value={@linked_groups}
        caption="Assigned to rollout channels"
      />
      <.stat_card
        label="Empty Groups"
        icon="hero-exclamation-triangle"
        icon_class={if(@empty_groups > 0, do: "text-warning", else: "text-base-content/45")}
        value_id="stat-empty-groups"
        value={@empty_groups}
        value_class={if(@empty_groups > 0, do: "text-warning", else: "text-base-content")}
        caption="Matching zero devices"
      />
      <.stat_card
        label="Fleet Coverage"
        icon="hero-cpu-chip"
        icon_class="text-primary"
        value_id="stat-fleet-coverage-pct"
        value={"#{@coverage_pct}%"}
        progress={@coverage_pct}
      />
    </section>
    """
  end

  defp compute_stats(scope) do
    loaded =
      Ash.load!(
        scope.current_tenant,
        [
          :device_group_count,
          :assigned_device_group_count,
          :empty_device_group_count,
          :device_count
        ],
        scope: scope,
        reuse_values?: false
      )

    covered_devices =
      Device
      |> Ash.Query.for_read(:in_any_device_group, %{}, scope: scope)
      |> Ash.count!(scope: scope)

    coverage_pct =
      if loaded.device_count > 0 do
        round(covered_devices / loaded.device_count * 100)
      else
        0
      end

    %{
      total_groups: loaded.device_group_count,
      linked_groups: loaded.assigned_device_group_count,
      empty_groups: loaded.empty_device_group_count,
      coverage_pct: coverage_pct
    }
  end
end
