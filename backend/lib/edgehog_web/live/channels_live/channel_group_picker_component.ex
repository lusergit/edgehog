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

defmodule EdgehogWeb.ChannelsLive.ChannelGroupPickerComponent do
  @moduledoc """
  Stateless function components and domain helpers for selecting target device
  groups in `ChannelFormComponent`, enforcing running-campaign locks,
  displaying group stealing warnings, reconciling assignments, and rendering
  the real-time blast-radius fleet preview.
  """
  use EdgehogWeb, :html

  alias Edgehog.Campaigns.Channel
  alias Edgehog.Groups.DeviceGroup
  alias EdgehogWeb.ChannelsLive.CampaignStripComponent
  alias EdgehogWeb.ChannelsLive.ChannelFleetComponent

  attr :group_items, :list, required: true
  attr :selected_group_ids, :any, required: true
  attr :myself, :any, required: true

  def group_picker(assigns) do
    ~H"""
    <div id="channel-target-groups-picker" class="space-y-2">
      <div class="flex items-center justify-between">
        <label class="text-xs font-semibold uppercase tracking-wider text-base-content/70">
          {gettext("Target Device Groups")}
        </label>
        <span class="text-xs font-medium tabular-nums text-base-content/55">
          {MapSet.size(@selected_group_ids)} {gettext("selected")}
        </span>
      </div>

      <div
        :if={@group_items == []}
        class="rounded-xl border border-dashed border-base-300 bg-base-200/30 p-3 text-xs text-base-content/60"
      >
        {gettext("No device groups exist in this tenant yet.")}
      </div>

      <div
        :if={@group_items != []}
        class="max-h-56 overflow-y-auto rounded-2xl border border-base-300 bg-base-100 divide-y divide-base-200"
      >
        <button
          :for={item <- @group_items}
          id={"picker-group-#{item.group.id}"}
          type="button"
          disabled={item.state in [:locked_other, :locked_current]}
          phx-click="toggle_group"
          phx-value-group-id={item.group.id}
          phx-target={@myself}
          data-group-handle={item.group.handle}
          data-group-selected={to_string(MapSet.member?(@selected_group_ids, item.group.id))}
          data-group-stealable={to_string(item.state == :stealable)}
          data-group-locked={to_string(item.state in [:locked_other, :locked_current])}
          class={[
            "w-full flex items-center justify-between gap-3 px-3.5 py-2.5 text-left transition-colors",
            if(item.state in [:locked_other, :locked_current],
              do: "opacity-60 cursor-not-allowed bg-base-200/30",
              else: "hover:bg-base-200/50 cursor-pointer"
            )
          ]}
        >
          <div class="flex items-center gap-2.5 min-w-0">
            <input
              type="checkbox"
              checked={MapSet.member?(@selected_group_ids, item.group.id)}
              disabled={item.state in [:locked_other, :locked_current]}
              tabindex="-1"
              class="checkbox checkbox-xs checkbox-primary pointer-events-none"
            />
            <div class="min-w-0">
              <div class="flex items-center gap-1.5">
                <span class="text-xs font-semibold text-base-content truncate">
                  {item.group.name}
                </span>
                <span class="font-mono text-[11px] text-base-content/50 truncate">
                  @{item.group.handle}
                </span>
              </div>
              <p class="text-[11px] tabular-nums text-base-content/55">
                {item.device_count} {if(item.device_count == 1, do: "device", else: "devices")}
              </p>
            </div>
          </div>

          {render_item_badge(assign(assigns, :item, item))}
        </button>
      </div>
    </div>
    """
  end

  attr :stolen_items, :list, required: true

  def steal_warning(assigns) do
    ~H"""
    <div
      :if={@stolen_items != []}
      id="channel-steal-warning"
      class="rounded-2xl border border-warning/40 bg-warning/10 px-3.5 py-2.5 text-xs text-warning space-y-1"
    >
      <div class="flex items-center gap-1.5 font-semibold">
        <.icon name="hero-arrows-right-left" class="size-4 shrink-0" />
        <span>{gettext("Reassigning groups from existing channels")}</span>
      </div>
      <ul class="list-disc pl-5 space-y-0.5 text-base-content/80">
        <li :for={item <- @stolen_items}>
          <strong class="font-semibold">{item.group.name}</strong>
          <span class="font-mono">(@{item.group.handle})</span>
          {gettext("will be moved from")}
          <span class="font-mono font-semibold">@{item.old_channel.handle}</span>
          {gettext("to this channel on save.")}
        </li>
      </ul>
    </div>
    """
  end

  attr :preview_reach, :map, required: true

  def live_preview(assigns) do
    ~H"""
    <div
      id="channel-live-preview"
      class="rounded-2xl border border-base-300 bg-base-200/35 p-3.5"
    >
      <ChannelFleetComponent.fleet_reach reach={@preview_reach} />
    </div>
    """
  end

  @doc """
  Loads all tenant `DeviceGroup`s with their device counts, currently assigned
  channels, and `:available | :current | :stealable | :locked_other | :locked_current`
  picker states.
  """
  def load_group_items(current_channel_id, tenant) do
    channels_by_id =
      Channel
      |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
      |> Ash.Query.load(:campaigns)
      |> Ash.read!(tenant: tenant, authorize?: false)
      |> Map.new(&{&1.id, &1})

    DeviceGroup
    |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
    |> Ash.Query.sort(name: :asc)
    |> Ash.read!(tenant: tenant, authorize?: false)
    |> Enum.map(&build_group_item(&1, current_channel_id, channels_by_id, tenant))
  end

  @doc """
  Validates server-side that no selected group belongs to another channel with a
  running campaign and that no existing group was removed from the current
  channel while it has a running campaign.
  """
  def validate_group_selection(selected_ids, current_channel_id, tenant) do
    items = load_group_items(current_channel_id, tenant)

    locked_stolen =
      Enum.find(items, fn item ->
        MapSet.member?(selected_ids, item.group.id) and item.state == :locked_other
      end)

    locked_removed =
      Enum.find(items, fn item ->
        item.state == :locked_current and not MapSet.member?(selected_ids, item.group.id)
      end)

    cond do
      not is_nil(locked_stolen) ->
        {:error,
         gettext(
           "Cannot move group %{name} because its channel (@%{handle}) has a running campaign.",
           name: locked_stolen.group.name,
           handle: locked_stolen.old_channel.handle
         )}

      not is_nil(locked_removed) ->
        {:error,
         gettext(
           "Cannot remove group %{name} while this channel has a running campaign.",
           name: locked_removed.group.name
         )}

      true ->
        :ok
    end
  end

  @doc """
  Reconciles target group assignments for `saved_channel` after form submission,
  unassigning removed or stolen groups before assigning selected groups.
  """
  def reconcile_target_groups(saved_channel, selected_ids, tenant) do
    groups = Ash.read!(DeviceGroup, tenant: tenant, authorize?: false)

    Enum.each(groups, fn group ->
      reconcile_group(group, saved_channel.id, MapSet.member?(selected_ids, group.id), tenant)
    end)
  end

  defp build_group_item(group, current_channel_id, channels_by_id, tenant) do
    device_count =
      group.selector
      |> ChannelFleetComponent.matching_devices_for_selector(tenant)
      |> length()

    old_channel = if group.channel_id, do: Map.get(channels_by_id, group.channel_id), else: nil
    running? = channel_has_running_campaign?(old_channel)

    state =
      cond do
        is_nil(group.channel_id) -> :available
        group.channel_id == current_channel_id and running? -> :locked_current
        group.channel_id == current_channel_id -> :current
        running? -> :locked_other
        true -> :stealable
      end

    %{
      group: group,
      device_count: device_count,
      old_channel: old_channel,
      state: state
    }
  end

  defp channel_has_running_campaign?(nil), do: false

  defp channel_has_running_campaign?(channel) do
    Enum.any?(channel.campaigns || [], fn campaign ->
      CampaignStripComponent.running_campaign_status?(campaign.status)
    end)
  end

  defp reconcile_group(%{channel_id: channel_id} = group, channel_id, false, tenant) do
    Ash.update!(group, %{}, action: :unassign_channel, tenant: tenant, authorize?: false)
  end

  defp reconcile_group(group, channel_id, true, tenant) when group.channel_id != channel_id do
    group =
      if is_nil(group.channel_id) do
        group
      else
        Ash.update!(group, %{}, action: :unassign_channel, tenant: tenant, authorize?: false)
      end

    Ash.update!(group, %{channel_id: channel_id},
      action: :assign_channel,
      tenant: tenant,
      authorize?: false
    )
  end

  defp reconcile_group(_group, _channel_id, _selected?, _tenant), do: :ok

  defp render_item_badge(%{item: %{state: :available}} = assigns) do
    ~H"""
    <span class="badge badge-ghost badge-xs border-base-300 text-[11px] text-base-content/60 shrink-0">
      {gettext("Unassigned")}
    </span>
    """
  end

  defp render_item_badge(%{item: %{state: :current}} = assigns) do
    ~H"""
    <span class="badge badge-soft badge-info badge-xs text-[11px] shrink-0">
      {gettext("Assigned here")}
    </span>
    """
  end

  defp render_item_badge(%{item: %{state: :locked_current}} = assigns) do
    ~H"""
    <span class="badge badge-soft badge-error badge-xs gap-1 text-[11px] shrink-0">
      <.icon name="hero-lock-closed" class="size-3" />
      <span>{gettext("Locked · Running campaign")}</span>
    </span>
    """
  end

  defp render_item_badge(%{item: %{state: :stealable, old_channel: old_channel}} = assigns) do
    assigns = assign(assigns, :old_handle, old_channel.handle)

    ~H"""
    <span class="badge badge-soft badge-warning badge-xs gap-1 text-[11px] shrink-0">
      <.icon name="hero-arrows-right-left" class="size-3" />
      <span>Assigned to @{@old_handle} · Will move here</span>
    </span>
    """
  end

  defp render_item_badge(%{item: %{state: :locked_other, old_channel: old_channel}} = assigns) do
    assigns = assign(assigns, :old_handle, old_channel.handle)

    ~H"""
    <span class="badge badge-soft badge-error badge-xs gap-1 text-[11px] shrink-0">
      <.icon name="hero-lock-closed" class="size-3" />
      <span>Locked · Running campaign on @{@old_handle}</span>
    </span>
    """
  end
end
