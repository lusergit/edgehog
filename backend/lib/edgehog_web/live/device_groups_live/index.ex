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

defmodule EdgehogWeb.DeviceGroupsLive.Index do
  @moduledoc """
  LiveView for browsing, searching, and monitoring a tenant's dynamic device
  groups in real time.

  Composes `GroupsStatsComponent` and a `Cinder.collection` table whose cells are
  independent `Phoenix.LiveComponent`s subscribed to granular Ash PubSub topics.
  """
  use EdgehogWeb, :live_view

  alias Edgehog.Groups.DeviceGroup
  alias EdgehogWeb.DeviceGroupsLive.ChannelCellComponent
  alias EdgehogWeb.DeviceGroupsLive.GroupFleetCellComponent
  alias EdgehogWeb.DeviceGroupsLive.GroupsStatsComponent
  alias EdgehogWeb.DeviceGroupsLive.IdentityCellComponent
  alias EdgehogWeb.DeviceGroupsLive.SelectorCellComponent

  require Ash.Query

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_tenant

    if connected?(socket) do
      EdgehogWeb.Endpoint.subscribe("device_groups:tenant:#{tenant.tenant_id}")
      EdgehogWeb.Endpoint.subscribe("devices:tenant:#{tenant.tenant_id}")
    end

    query =
      DeviceGroup
      |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
      |> Ash.Query.load([:channel])

    {:ok,
     socket
     |> assign(:page_title, "Groups · #{tenant.name}")
     |> assign(:device_groups_query, query)
     |> assign(:mounted_group_ids, MapSet.new())}
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:register_group_fleet_cell, group_id}, socket) do
    {:noreply, update(socket, :mounted_group_ids, &MapSet.put(&1, group_id))}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "device_groups:identity:" <> id,
          payload: %Ash.Notifier.Notification{data: group}
        },
        socket
      ) do
    send_update(IdentityCellComponent, id: "group-identity-#{id}", group: group)
    {:noreply, socket}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "device_groups:selector:" <> id,
          payload: %Ash.Notifier.Notification{data: group}
        },
        socket
      ) do
    tenant = socket.assigns.current_tenant

    send_update(SelectorCellComponent, id: "group-selector-#{id}", group: group)
    send_update(GroupFleetCellComponent, id: "group-fleet-#{id}", group: group, tenant: tenant)
    send_update(GroupsStatsComponent, id: "groups-stats", tenant: tenant)

    {:noreply, socket}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "device_groups:channel:" <> id,
          payload: %Ash.Notifier.Notification{data: group}
        },
        socket
      ) do
    tenant = socket.assigns.current_tenant

    send_update(ChannelCellComponent, id: "group-channel-#{id}", group: group, tenant: tenant)
    send_update(GroupsStatsComponent, id: "groups-stats", tenant: tenant)

    {:noreply, socket}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "device_groups:tenant:" <> _tenant_id,
          payload: %Ash.Notifier.Notification{action: %{type: :create}}
        },
        socket
      ) do
    send_update(GroupsStatsComponent, id: "groups-stats", tenant: socket.assigns.current_tenant)
    {:noreply, Cinder.Refresh.refresh_table(socket, "device-groups-table")}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "device_groups:tenant:" <> _tenant_id,
          payload: %Ash.Notifier.Notification{action: %{type: :destroy}, data: group}
        },
        socket
      ) do
    socket = update(socket, :mounted_group_ids, &MapSet.delete(&1, group.id))
    send_update(GroupsStatsComponent, id: "groups-stats", tenant: socket.assigns.current_tenant)
    {:noreply, Cinder.Refresh.refresh_table(socket, "device-groups-table")}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "devices:tenant:" <> _tenant_id,
          payload: %Ash.Notifier.Notification{}
        },
        socket
      ) do
    tenant = socket.assigns.current_tenant
    mounted_ids = MapSet.to_list(socket.assigns.mounted_group_ids)

    send_update(GroupsStatsComponent, id: "groups-stats", tenant: tenant)

    if mounted_ids != [] do
      DeviceGroup
      |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
      |> Ash.Query.filter(id in ^mounted_ids)
      |> Ash.read!(tenant: tenant, authorize?: false)
      |> Enum.each(fn group ->
        send_update(GroupFleetCellComponent,
          id: "group-fleet-#{group.id}",
          group: group,
          tenant: tenant
        )
      end)
    end

    {:noreply, socket}
  end

  def handle_info(%Phoenix.Socket.Broadcast{}, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-6 space-y-6">
      <.page_header
        title="Groups"
        live_title="Subscribed to live group and fleet telemetry updates"
      >
        <:subtitle>
          Dynamic selector partitions and rollout channel assignments in <span class="font-medium text-base-content/80">{@current_tenant.name}</span>.
        </:subtitle>
      </.page_header>

      <.live_component
        module={GroupsStatsComponent}
        id="groups-stats"
        tenant={@current_tenant}
      />

      <Cinder.collection
        id="device-groups-table"
        query={@device_groups_query}
        tenant={@current_tenant}
        page_size={[default: 15, options: [10, 15, 25, 50]]}
        search={false}
      >
        <:col :let={group} field="name" sort search label="Group">
          <.live_component
            module={IdentityCellComponent}
            id={"group-identity-#{group.id}"}
            group={group}
          />
        </:col>

        <:col :let={group} field="handle" hidden sort search label="Handle">
          <span class="font-mono text-base-content/55">
            @{group.handle}
          </span>
        </:col>

        <:col :let={group} field="selector" search label="Selector Rule">
          <.live_component
            module={SelectorCellComponent}
            id={"group-selector-#{group.id}"}
            group={group}
          />
        </:col>

        <:col :let={group} field="id" label="Matched Devices">
          <.live_component
            module={GroupFleetCellComponent}
            id={"group-fleet-#{group.id}"}
            group={group}
            tenant={@current_tenant}
          />
        </:col>

        <:col :let={group} field="channel_id" label="Channel">
          <.live_component
            module={ChannelCellComponent}
            id={"group-channel-#{group.id}"}
            group={group}
            tenant={@current_tenant}
          />
        </:col>
      </Cinder.collection>
    </div>
    """
  end
end
