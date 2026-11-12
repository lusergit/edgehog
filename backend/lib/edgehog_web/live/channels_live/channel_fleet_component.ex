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

defmodule EdgehogWeb.ChannelsLive.ChannelFleetComponent do
  @moduledoc """
  Stateless function component and domain helpers for computing and rendering a
  rollout channel's deduplicated device reach, online availability ratio, and
  system model compatibility pills.
  """
  use EdgehogWeb, :html

  alias Edgehog.Devices.Device
  alias EdgehogWeb.DeviceGroupsLive.GroupsStatsComponent

  require Ash.Query

  attr :reach, :map, required: true

  def fleet_reach(assigns) do
    ~H"""
    <div class="border-t border-base-200 pt-3.5">
      <div class="flex items-center justify-between gap-2">
        <span class="text-xs font-semibold uppercase tracking-wider text-base-content/60">
          Deduplicated Fleet Reach
        </span>
        <span
          data-role="channel-reach-pct"
          class="text-xs font-medium tabular-nums text-base-content/60"
        >
          {@reach.pct}% online
        </span>
      </div>

      <div class="mt-1.5 flex items-baseline justify-between gap-2">
        <div class="flex items-baseline gap-1.5">
          <span
            data-role="channel-total-devices"
            class="text-lg font-bold tabular-nums text-base-content"
          >
            {@reach.total}
          </span>
          <span class="text-xs text-base-content/55">
            {if(@reach.total == 1, do: "device", else: "devices")}
          </span>
        </div>
        <span
          data-role="channel-online-devices"
          class="text-xs font-medium tabular-nums text-success"
        >
          {@reach.online} online
        </span>
      </div>

      <progress
        class={["progress mt-2 w-full", reach_progress_color(@reach)]}
        value={@reach.pct}
        max="100"
      />

      <div
        :if={@reach.system_models != []}
        data-role="channel-system-models"
        class="mt-2.5 flex flex-wrap gap-1.5"
      >
        <span
          :for={model <- @reach.system_models}
          data-system-model={model.handle}
          class="inline-flex items-center gap-1 rounded-md border border-base-300 bg-base-200/50 px-2 py-0.5 text-[11px] font-medium text-base-content/75"
        >
          <.icon name="hero-cpu-chip" class="size-3 text-base-content/50" />
          <span>{model.name}</span>
          <span class="font-mono tabular-nums text-base-content/55">({model.count})</span>
        </span>
      </div>
    </div>
    """
  end

  @doc """
  Computes the deduplicated device reach, online count, availability percentage,
  and system model distribution across a channel's assigned `target_groups`.
  """
  def compute_channel_reach(channel, tenant) do
    channel = ensure_target_groups_loaded(channel, tenant)
    compute_groups_reach(channel.target_groups || [], tenant)
  end

  @doc """
  Computes the deduplicated device reach, online count, availability percentage,
  and system model distribution across a list of `DeviceGroup` structs.
  """
  def compute_groups_reach(groups, tenant) when is_list(groups) do
    devices_by_id =
      Enum.reduce(groups, %{}, fn group, acc ->
        group.selector
        |> matching_devices_for_selector(tenant)
        |> Enum.reduce(acc, fn device, inner_acc ->
          Map.put(inner_acc, device.id, device)
        end)
      end)

    devices = Map.values(devices_by_id)
    total = length(devices)
    online = Enum.count(devices, &(&1.online == true))
    pct = if total > 0, do: round(online / total * 100), else: 0

    system_models =
      devices
      |> Enum.reduce(%{}, &accumulate_system_model/2)
      |> Map.values()
      |> Enum.sort_by(&{&1.name, &1.id})

    device_ids =
      devices_by_id
      |> Map.keys()
      |> MapSet.new()

    %{
      total: total,
      online: online,
      pct: pct,
      system_models: system_models,
      device_ids: device_ids
    }
  end

  @doc """
  Builds an `Ash.Query` on `Edgehog.Devices.Device` matching the deduplicated
  union of devices across `groups`.
  """
  def channel_devices_query(groups, tenant) when is_list(groups) do
    ids =
      groups
      |> compute_groups_reach(tenant)
      |> Map.fetch!(:device_ids)
      |> MapSet.to_list()

    Device
    |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
    |> Ash.Query.load([:system_model, :tags])
    |> Ash.Query.filter(id in ^ids)
  end

  @doc """
  Returns all `Device` structs matching a selector expression for `tenant`,
  selecting `:id`, `:online`, `:part_number`, and loading `:system_model`.
  """
  def matching_devices_for_selector(selector, tenant) do
    case GroupsStatsComponent.selector_filter_expr(selector) do
      {:ok, expr} ->
        Device
        |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
        |> Ash.Query.filter(^expr)
        |> Ash.Query.select([:id, :online, :part_number])
        |> Ash.Query.load(:system_model)
        |> Ash.read!(tenant: tenant, authorize?: false)

      :error ->
        []
    end
  end

  defp accumulate_system_model(%{system_model: %{id: id, name: name, handle: handle}}, acc) do
    Map.update(acc, id, %{id: id, name: name, handle: handle, count: 1}, fn entry ->
      %{entry | count: entry.count + 1}
    end)
  end

  defp accumulate_system_model(_device, acc), do: acc

  defp ensure_target_groups_loaded(%{target_groups: groups} = channel, _tenant)
       when is_list(groups),
       do: channel

  defp ensure_target_groups_loaded(channel, tenant) do
    Ash.load!(channel, :target_groups, tenant: tenant, authorize?: false)
  end

  defp reach_progress_color(%{total: 0}), do: "progress-warning"
  defp reach_progress_color(%{online: 0}), do: "progress-error"
  defp reach_progress_color(_reach), do: "progress-success"
end
