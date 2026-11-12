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

  alias Edgehog.Campaigns.Campaign
  alias Edgehog.Campaigns.Channel
  alias Edgehog.Devices.Device
  alias Edgehog.Groups.DeviceGroup
  alias EdgehogWeb.ChannelsLive.ChannelFleetComponent

  require Ash.Query

  @active_campaign_statuses [:idle, :scheduled, :in_progress, :pausing, :paused]

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
    channels =
      Channel
      |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
      |> Ash.Query.load(:target_groups)
      |> Ash.read!(tenant: tenant, authorize?: false)

    total_channels = length(channels)

    empty_channels =
      Enum.count(channels, fn channel ->
        Enum.empty?(channel.target_groups || [])
      end)

    groups = Ash.read!(DeviceGroup, tenant: tenant, authorize?: false)
    total_groups = length(groups)
    assigned_groups = Enum.count(groups, &(not is_nil(&1.channel_id)))
    unassigned_groups = total_groups - assigned_groups

    covered_devices_by_id =
      channels
      |> Enum.flat_map(&(&1.target_groups || []))
      |> Enum.reduce(%{}, fn group, acc ->
        group.selector
        |> ChannelFleetComponent.matching_devices_for_selector(tenant)
        |> Enum.reduce(acc, fn device, inner_acc ->
          Map.put(inner_acc, device.id, device)
        end)
      end)

    covered_devices_list = Map.values(covered_devices_by_id)
    covered_devices = length(covered_devices_list)
    covered_online = Enum.count(covered_devices_list, &(&1.online == true))
    total_devices = Ash.count!(Device, tenant: tenant, authorize?: false)

    coverage_pct =
      if total_devices > 0 do
        round(covered_devices / total_devices * 100)
      else
        0
      end

    active_rollouts =
      Campaign
      |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
      |> Ash.Query.filter(status in ^@active_campaign_statuses)
      |> Ash.count!(tenant: tenant, authorize?: false)

    %{
      total_channels: total_channels,
      empty_channels: empty_channels,
      total_groups: total_groups,
      assigned_groups: assigned_groups,
      unassigned_groups: unassigned_groups,
      covered_devices: covered_devices,
      covered_online: covered_online,
      total_devices: total_devices,
      coverage_pct: coverage_pct,
      active_rollouts: active_rollouts
    }
  end
end
