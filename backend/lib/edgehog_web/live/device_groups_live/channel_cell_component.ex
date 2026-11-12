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

defmodule EdgehogWeb.DeviceGroupsLive.ChannelCellComponent do
  @moduledoc """
  Reactive table cell LiveComponent displaying a device group's assigned rollout
  channel badge or an unassigned state indicator.

  Subscribes to `"device_groups:channel:<id>"` so channel assignments and
  unassignments update the cell in place.
  """
  use EdgehogWeb, :live_component

  @impl Phoenix.LiveComponent
  def update(%{group: group, tenant: tenant} = assigns, socket) do
    channel = resolve_channel(group, tenant)

    socket =
      socket
      |> assign(assigns)
      |> assign(:channel, channel)
      |> ensure_subscribed(group.id)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id={@id} class="inline-flex items-center">
      <.link
        :if={@channel}
        navigate={~p"/tenants/#{@tenant.slug}/channels/#{@channel.id}"}
        data-channel={@channel.handle}
        class="badge badge-soft badge-info gap-1.5 font-medium transition-opacity hover:opacity-80"
      >
        <.icon name="hero-signal" class="size-3.5" />
        <span>{@channel.name}</span>
        <span class="font-mono text-xs opacity-65">@{@channel.handle}</span>
      </.link>

      <span
        :if={is_nil(@channel)}
        data-channel="unassigned"
        class="badge badge-ghost border-base-300 text-xs text-base-content/50"
      >
        Unassigned
      </span>
    </div>
    """
  end

  defp ensure_subscribed(socket, group_id) do
    if connected?(socket) and not Map.get(socket.assigns, :subscribed?, false) do
      EdgehogWeb.Endpoint.subscribe("device_groups:channel:#{group_id}")
      assign(socket, :subscribed?, true)
    else
      socket
    end
  end

  defp resolve_channel(%{channel_id: nil}, _tenant), do: nil

  defp resolve_channel(%{channel_id: channel_id, channel: %{id: channel_id} = channel}, _tenant) do
    channel
  end

  defp resolve_channel(group, tenant) do
    group
    |> Ash.load!(:channel, tenant: tenant, authorize?: false, reuse_values?: false)
    |> Map.get(:channel)
  end
end
