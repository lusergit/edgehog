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

defmodule EdgehogWeb.DeviceGroupsLive.Show do
  @moduledoc """
  LiveView for inspecting a single `Edgehog.Groups.DeviceGroup`, its selector
  rule, rollout channel assignment, and live cohort of matching devices.
  """
  use EdgehogWeb, :live_view

  alias Edgehog.Devices.Device
  alias Edgehog.Groups.DeviceGroup
  alias EdgehogWeb.DeviceGroupsLive.ChannelCellComponent
  alias EdgehogWeb.DeviceGroupsLive.DeleteGroupModalComponent
  alias EdgehogWeb.DeviceGroupsLive.GroupFleetCellComponent
  alias EdgehogWeb.DeviceGroupsLive.GroupFormComponent
  alias EdgehogWeb.DeviceGroupsLive.GroupsStatsComponent
  alias EdgehogWeb.DeviceGroupsLive.SelectorCellComponent

  require Ash.Query

  @impl Phoenix.LiveView
  def mount(%{"id" => id}, _session, socket) do
    tenant = socket.assigns.current_tenant

    case fetch_group(id, tenant) do
      {:ok, group} ->
        if connected?(socket) do
          EdgehogWeb.Endpoint.subscribe("device_groups:identity:#{group.id}")
          EdgehogWeb.Endpoint.subscribe("device_groups:tenant:#{tenant.tenant_id}")
          EdgehogWeb.Endpoint.subscribe("devices:tenant:#{tenant.tenant_id}")
        end

        {:ok,
         socket
         |> assign(:group, group)
         |> assign(:devices_query, build_devices_query(group.selector, tenant))
         |> assign(:show_delete_modal, false)
         |> assign(:page_title, "#{group.name} · Groups · #{tenant.name}")}

      :error ->
        {:ok,
         socket
         |> assign(:group, nil)
         |> put_flash(:error, gettext("Device group not found."))
         |> push_navigate(to: ~p"/tenants/#{tenant.slug}/device-groups")}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _uri, %{assigns: %{group: nil}} = socket) do
    {:noreply, socket}
  end

  def handle_params(_params, _uri, socket) do
    tenant = socket.assigns.current_tenant
    group = socket.assigns.group

    page_title =
      case socket.assigns.live_action do
        :edit -> "Edit #{group.name} · Groups · #{tenant.name}"
        _ -> "#{group.name} · Groups · #{tenant.name}"
      end

    {:noreply, assign(socket, :page_title, page_title)}
  end

  @impl Phoenix.LiveView
  def handle_event("open_delete_modal", _params, socket) do
    {:noreply, assign(socket, :show_delete_modal, true)}
  end

  @impl Phoenix.LiveView
  def handle_info({:register_group_fleet_cell, _group_id}, socket) do
    {:noreply, socket}
  end

  def handle_info(:close_delete_group_modal, socket) do
    {:noreply, assign(socket, :show_delete_modal, false)}
  end

  def handle_info({:group_deleted, _group}, socket) do
    tenant = socket.assigns.current_tenant

    {:noreply,
     socket
     |> put_flash(:info, gettext("Device group deleted."))
     |> push_navigate(to: ~p"/tenants/#{tenant.slug}/device-groups")}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "device_groups:identity:" <> _id,
          payload: %Ash.Notifier.Notification{data: updated_group}
        },
        socket
      ) do
    tenant = socket.assigns.current_tenant

    group =
      %{socket.assigns.group | name: updated_group.name, handle: updated_group.handle}

    {:noreply,
     socket
     |> assign(:group, group)
     |> assign(:page_title, "#{group.name} · Groups · #{tenant.name}")}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "device_groups:selector:" <> id,
          payload: %Ash.Notifier.Notification{data: updated_group}
        },
        socket
      ) do
    tenant = socket.assigns.current_tenant
    group = %{socket.assigns.group | selector: updated_group.selector}

    send_update(SelectorCellComponent, id: "group-detail-selector-#{id}", group: group)

    send_update(GroupFleetCellComponent,
      id: "group-detail-fleet-#{id}",
      group: group,
      tenant: tenant
    )

    {:noreply,
     socket
     |> assign(:group, group)
     |> assign(:devices_query, build_devices_query(group.selector, tenant))
     |> Cinder.Refresh.refresh_table("group-devices-table")}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "device_groups:channel:" <> id,
          payload: %Ash.Notifier.Notification{data: updated_group}
        },
        socket
      ) do
    tenant = socket.assigns.current_tenant

    group =
      Ash.load!(updated_group, :channel, tenant: tenant, authorize?: false, reuse_values?: false)

    send_update(ChannelCellComponent,
      id: "group-detail-channel-#{id}",
      group: group,
      tenant: tenant
    )

    {:noreply, assign(socket, :group, group)}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "device_groups:tenant:" <> _tenant_id,
          payload: %Ash.Notifier.Notification{action: %{type: :destroy}, data: destroyed}
        },
        socket
      ) do
    if socket.assigns.group && destroyed.id == socket.assigns.group.id do
      tenant = socket.assigns.current_tenant
      {:noreply, push_navigate(socket, to: ~p"/tenants/#{tenant.slug}/device-groups")}
    else
      {:noreply, socket}
    end
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "devices:" <> rest,
          payload: %Ash.Notifier.Notification{data: device}
        },
        socket
      ) do
    case forward_device_cell_broadcast(rest, device, socket) do
      :handled ->
        {:noreply, socket}

      :unhandled ->
        tenant = socket.assigns.current_tenant
        group = socket.assigns.group

        send_update(GroupFleetCellComponent,
          id: "group-detail-fleet-#{group.id}",
          group: group,
          tenant: tenant
        )

        {:noreply, Cinder.Refresh.refresh_table(socket, "group-devices-table")}
    end
  end

  def handle_info(%Phoenix.Socket.Broadcast{}, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def render(%{group: nil} = assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-6"></div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-6 space-y-6">
      <.page_header
        back_navigate={~p"/tenants/#{@current_tenant.slug}/device-groups"}
        back_id="back-to-groups-link"
        back_label={gettext("Back to Groups")}
        title={@group.name}
        title_id="group-detail-name"
        handle={@group.handle}
        handle_id="group-detail-handle"
        live_title="Subscribed to live group and cohort telemetry updates"
      >
        <:subtitle>
          {gettext("Live device cohort and rollout channel configuration in")}
          <span class="font-medium text-base-content/80">{@current_tenant.name}</span>.
        </:subtitle>
        <:actions>
          <.link
            id="edit-device-group-btn"
            patch={~p"/tenants/#{@current_tenant.slug}/device-groups/#{@group.id}/edit"}
            class="btn btn-sm btn-outline border-base-300 bg-base-100 gap-1.5"
          >
            <.icon name="hero-pencil-square" class="size-4" />
            <span>{gettext("Edit Group")}</span>
          </.link>

          <.button
            id="delete-device-group-btn"
            type="button"
            variant="error"
            class="btn-sm btn-soft gap-1.5"
            phx-click="open_delete_modal"
          >
            <.icon name="hero-trash" class="size-4" />
            <span>{gettext("Delete")}</span>
          </.button>
        </:actions>
      </.page_header>

      <section
        id="group-cohort-strip"
        aria-label="Device group cohort summary"
        class="grid grid-cols-1 md:grid-cols-3 gap-4"
      >
        <div class="card card-border bg-base-100 p-4 shadow-xs space-y-2.5">
          <div class="flex items-center justify-between">
            <span class="text-xs font-semibold uppercase tracking-wider text-base-content/60">
              {gettext("Matched Fleet")}
            </span>
            <.icon name="hero-cpu-chip" class="size-4 text-primary" />
          </div>
          <.live_component
            module={GroupFleetCellComponent}
            id={"group-detail-fleet-#{@group.id}"}
            group={@group}
            tenant={@current_tenant}
          />
        </div>

        <div class="card card-border bg-base-100 p-4 shadow-xs space-y-2.5">
          <div class="flex items-center justify-between">
            <span class="text-xs font-semibold uppercase tracking-wider text-base-content/60">
              {gettext("Selector Rule")}
            </span>
            <.icon name="hero-funnel" class="size-4 text-base-content/45" />
          </div>
          <.live_component
            module={SelectorCellComponent}
            id={"group-detail-selector-#{@group.id}"}
            group={@group}
          />
          <code
            id="group-detail-raw-selector"
            class="block truncate text-xs font-mono text-base-content/50"
          >
            {@group.selector}
          </code>
        </div>

        <div class="card card-border bg-base-100 p-4 shadow-xs space-y-2.5">
          <div class="flex items-center justify-between">
            <span class="text-xs font-semibold uppercase tracking-wider text-base-content/60">
              {gettext("Rollout Channel")}
            </span>
            <.icon name="hero-signal" class="size-4 text-info" />
          </div>
          <.live_component
            module={ChannelCellComponent}
            id={"group-detail-channel-#{@group.id}"}
            group={@group}
            tenant={@current_tenant}
          />
        </div>
      </section>

      <div class="space-y-3">
        <h2 class="text-base font-bold text-base-content">
          {gettext("Matched Devices")}
        </h2>

        <.devices_cinder_table
          id="group-devices-table"
          query={@devices_query}
          tenant={@current_tenant}
        />
      </div>

      <.live_component
        :if={@live_action == :edit}
        module={GroupFormComponent}
        id="edit-device-group-drawer"
        action={:edit}
        group={@group}
        tenant={@current_tenant}
        return_to={~p"/tenants/#{@current_tenant.slug}/device-groups/#{@group.id}"}
      />

      <.live_component
        :if={@show_delete_modal}
        module={DeleteGroupModalComponent}
        id="delete-group-modal"
        group={@group}
        tenant={@current_tenant}
      />
    </div>
    """
  end

  defp fetch_group(id, tenant) do
    with {int_id, ""} <- id |> to_string() |> Integer.parse(),
         {:ok, group} <- Ash.get(DeviceGroup, int_id, tenant: tenant, authorize?: false) do
      {:ok, Ash.load!(group, :channel, tenant: tenant, authorize?: false)}
    else
      _ -> :error
    end
  end

  defp build_devices_query(selector, tenant) do
    base_query =
      Device
      |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
      |> Ash.Query.load([:system_model, :tags])

    case GroupsStatsComponent.selector_filter_expr(selector) do
      {:ok, expr} -> Ash.Query.filter(base_query, ^expr)
      :error -> Ash.Query.filter(base_query, false)
    end
  end
end
