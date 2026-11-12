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

defmodule EdgehogWeb.ChannelsLive.ChannelsStatsComponent do
  @moduledoc """
  LiveComponent rendering the 4-card operational summary strip for a tenant's
  rollout channels (Rollout Channels, Group Allocation, Channel-Covered Fleet,
  and Active Rollouts).
  """
  use EdgehogWeb, :live_component

  alias Edgehog.Devices.Device

  require Ash.Query

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
      aria-label="Rollout channels summary"
      class="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4"
    >
      <.stat_card
        label="Rollout Channels"
        icon="hero-signal"
        icon_class="text-info"
        value_id="stat-total-channels"
        value={@total_channels}
        badge={if(@empty_channels > 0, do: "#{@empty_channels} empty")}
        badge_id="stat-empty-channels-warning"
        badge_class="badge badge-soft badge-warning badge-xs font-medium tabular-nums"
        caption="Configured deployment rings"
      />
      <.stat_card
        label="Group Allocation"
        icon="hero-user-group"
        value_id="stat-assigned-groups"
        value={@assigned_groups}
        total={@total_groups}
        caption_id="stat-unassigned-groups"
        caption={"#{@unassigned_groups} unassigned"}
      />
      <.stat_card
        label="Channel-Covered Fleet"
        icon="hero-cpu-chip"
        icon_class="text-primary"
        value_id="stat-covered-devices"
        value={@covered_devices}
        total={@total_devices}
        badge={"#{@covered_online} online"}
        badge_id="stat-covered-online"
        badge_class="text-xs font-medium tabular-nums text-success"
        progress={@coverage_pct}
      />
      <.stat_card
        label="Active Rollouts"
        icon="hero-rocket-launch"
        icon_class={if(@active_rollouts > 0, do: "text-primary", else: "text-base-content/55")}
        value_id="stat-active-rollouts"
        value={@active_rollouts}
        caption="Running or scheduled campaigns"
      />
    </section>
    """
  end

  defp compute_stats(tenant) do
    loaded =
      Ash.load!(
        tenant,
        [
          :channel_count,
          :empty_channel_count,
          :device_group_count,
          :assigned_device_group_count,
          :active_campaign_count,
          :device_count
        ],
        tenant: tenant,
        authorize?: false,
        reuse_values?: false
      )

    in_channels_query =
      Ash.Query.for_read(Device, :in_any_channel, %{}, tenant: tenant, authorize?: false)

    covered_devices = Ash.count!(in_channels_query, tenant: tenant, authorize?: false)

    covered_online =
      in_channels_query
      |> Ash.Query.filter(online == true)
      |> Ash.count!(tenant: tenant, authorize?: false)

    coverage_pct =
      if loaded.device_count > 0 do
        round(covered_devices / loaded.device_count * 100)
      else
        0
      end

    %{
      total_channels: loaded.channel_count,
      empty_channels: loaded.empty_channel_count,
      total_groups: loaded.device_group_count,
      assigned_groups: loaded.assigned_device_group_count,
      unassigned_groups: max(loaded.device_group_count - loaded.assigned_device_group_count, 0),
      covered_devices: covered_devices,
      covered_online: covered_online,
      total_devices: loaded.device_count,
      coverage_pct: coverage_pct,
      active_rollouts: loaded.active_campaign_count
    }
  end
end
