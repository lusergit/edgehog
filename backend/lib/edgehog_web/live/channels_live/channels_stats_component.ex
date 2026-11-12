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
      <div class="card card-border bg-base-100 p-4 shadow-xs">
        <div class="flex items-center justify-between">
          <span class="text-xs font-semibold uppercase tracking-wider text-base-content/60">
            Rollout Channels
          </span>
          <.icon name="hero-signal" class="size-4 text-info" />
        </div>
        <div class="mt-2 flex items-baseline gap-2">
          <p id="stat-total-channels" class="text-2xl font-bold tabular-nums text-base-content">
            {@total_channels}
          </p>
          <span
            :if={@empty_channels > 0}
            id="stat-empty-channels-warning"
            class="badge badge-soft badge-warning badge-xs font-medium tabular-nums"
          >
            {@empty_channels} empty
          </span>
        </div>
        <p class="mt-0.5 text-xs text-base-content/55">Configured deployment rings</p>
      </div>

      <div class="card card-border bg-base-100 p-4 shadow-xs">
        <div class="flex items-center justify-between">
          <span class="text-xs font-semibold uppercase tracking-wider text-base-content/60">
            Group Allocation
          </span>
          <.icon name="hero-user-group" class="size-4 text-base-content/45" />
        </div>
        <p id="stat-assigned-groups" class="mt-2 text-2xl font-bold tabular-nums text-base-content">
          {@assigned_groups}
          <span class="text-base font-medium text-base-content/45">/ {@total_groups}</span>
        </p>
        <p id="stat-unassigned-groups" class="mt-0.5 text-xs tabular-nums text-base-content/55">
          {@unassigned_groups} unassigned
        </p>
      </div>

      <div class="card card-border bg-base-100 p-4 shadow-xs">
        <div class="flex items-center justify-between">
          <span class="text-xs font-semibold uppercase tracking-wider text-base-content/60">
            Channel-Covered Fleet
          </span>
          <.icon name="hero-cpu-chip" class="size-4 text-primary" />
        </div>
        <div class="mt-2 flex items-baseline justify-between gap-2">
          <p id="stat-covered-devices" class="text-2xl font-bold tabular-nums text-base-content">
            {@covered_devices}
            <span class="text-base font-medium text-base-content/45">/ {@total_devices}</span>
          </p>
          <span
            id="stat-covered-online"
            class="text-xs font-medium tabular-nums text-success"
          >
            {@covered_online} online
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
            Active Rollouts
          </span>
          <.icon
            name="hero-rocket-launch"
            class={
              if(@active_rollouts > 0,
                do: "size-4 text-primary",
                else: "size-4 text-base-content/45"
              )
            }
          />
        </div>
        <p id="stat-active-rollouts" class="mt-2 text-2xl font-bold tabular-nums text-base-content">
          {@active_rollouts}
        </p>
        <p class="mt-0.5 text-xs text-base-content/55">Running or scheduled campaigns</p>
      </div>
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
