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

defmodule EdgehogWeb.ChannelsLive.Show do
  @moduledoc """
  LiveView for inspecting a single `Edgehog.Campaigns.Channel`, its assigned
  target device groups, deduplicated fleet reach, active/latest campaign
  rollout progress, and live searchable cohort of reachable devices.
  """
  use EdgehogWeb, :live_view

  alias Edgehog.Campaigns.Campaign
  alias Edgehog.Campaigns.Channel
  alias EdgehogWeb.ChannelsLive.CampaignStripComponent
  alias EdgehogWeb.ChannelsLive.ChannelFleetComponent
  alias EdgehogWeb.ChannelsLive.ChannelFormComponent
  alias EdgehogWeb.ChannelsLive.DeleteChannelModalComponent
  alias EdgehogWeb.ChannelsLive.TargetGroupsComponent
  alias EdgehogWeb.DevicesLive.LastSeenCellComponent
  alias EdgehogWeb.DevicesLive.NameCellComponent
  alias EdgehogWeb.DevicesLive.StatusCellComponent
  alias EdgehogWeb.DevicesLive.TagsCellComponent

  @impl Phoenix.LiveView
  def mount(%{"id" => id}, _session, socket) do
    tenant = socket.assigns.current_tenant

    case fetch_channel(id, tenant) do
      {:ok, channel} ->
        if connected?(socket) do
          EdgehogWeb.Endpoint.subscribe("channels:#{channel.id}")
          EdgehogWeb.Endpoint.subscribe("campaigns:tenant:#{tenant.tenant_id}")
          EdgehogWeb.Endpoint.subscribe("device_groups:tenant:#{tenant.tenant_id}")
          EdgehogWeb.Endpoint.subscribe("devices:tenant:#{tenant.tenant_id}")
        end

        {:ok,
         socket
         |> assign(:show_delete_modal, false)
         |> apply_channel_state(channel)}

      :error ->
        {:ok,
         socket
         |> assign(:channel, nil)
         |> put_flash(:error, gettext("Rollout channel not found."))
         |> push_navigate(to: ~p"/tenants/#{tenant.slug}/channels")}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _uri, %{assigns: %{channel: nil}} = socket) do
    {:noreply, socket}
  end

  def handle_params(_params, _uri, socket) do
    tenant = socket.assigns.current_tenant
    channel = socket.assigns.channel

    page_title =
      case socket.assigns.live_action do
        :edit -> "Edit #{channel.name} · Channels · #{tenant.name}"
        _ -> "#{channel.name} · Channels · #{tenant.name}"
      end

    {:noreply, assign(socket, :page_title, page_title)}
  end

  @impl Phoenix.LiveView
  def handle_event("open_delete_modal", _params, socket) do
    {:noreply, assign(socket, :show_delete_modal, true)}
  end

  @impl Phoenix.LiveView
  def handle_info(:close_delete_channel_modal, socket) do
    {:noreply, assign(socket, :show_delete_modal, false)}
  end

  def handle_info({:channel_deleted, _channel}, socket) do
    tenant = socket.assigns.current_tenant

    {:noreply,
     socket
     |> put_flash(:info, gettext("Rollout channel deleted."))
     |> push_navigate(to: ~p"/tenants/#{tenant.slug}/channels")}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "channels:" <> _id,
          payload: %Ash.Notifier.Notification{action: %{type: :destroy}}
        },
        socket
      ) do
    tenant = socket.assigns.current_tenant
    {:noreply, push_navigate(socket, to: ~p"/tenants/#{tenant.slug}/channels")}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "devices:" <> rest,
          payload: %Ash.Notifier.Notification{data: device}
        } = broadcast,
        socket
      ) do
    case String.split(rest, ":", parts: 2) do
      [event, id] when event in ["online", "offline"] ->
        send_update(StatusCellComponent, id: "device-status-#{id}", device: device)
        {:noreply, socket}

      ["name", id] ->
        send_update(NameCellComponent, id: "device-name-#{id}", device: device)
        {:noreply, socket}

      ["connection", id] ->
        send_update(LastSeenCellComponent, id: "device-last-seen-#{id}", device: device)
        {:noreply, socket}

      ["tags", id] ->
        send_update(TagsCellComponent,
          id: "device-tags-#{id}",
          device: device,
          tenant: socket.assigns.current_tenant
        )

        {:noreply, socket}

      _ ->
        refresh_channel_state(broadcast, socket)
    end
  end

  def handle_info(%Phoenix.Socket.Broadcast{} = broadcast, socket) do
    refresh_channel_state(broadcast, socket)
  end

  defp refresh_channel_state(
         _broadcast,
         %{assigns: %{channel: %Channel{} = channel}} = socket
       ) do
    tenant = socket.assigns.current_tenant

    case fetch_channel(channel.id, tenant) do
      {:ok, refreshed} ->
        {:noreply,
         socket
         |> apply_channel_state(refreshed)
         |> Cinder.Refresh.refresh_table("channel-devices-table")}

      :error ->
        {:noreply, push_navigate(socket, to: ~p"/tenants/#{tenant.slug}/channels")}
    end
  end

  defp refresh_channel_state(_broadcast, socket), do: {:noreply, socket}

  @impl Phoenix.LiveView
  def render(%{channel: nil} = assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-6"></div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-6 space-y-6">
      <div class="flex flex-col gap-3">
        <div>
          <.link
            id="back-to-channels-link"
            navigate={~p"/tenants/#{@current_tenant.slug}/channels"}
            class="inline-flex items-center gap-1.5 text-xs font-medium text-base-content/60 hover:text-base-content transition-colors"
          >
            <.icon name="hero-arrow-left" class="size-3.5" />
            <span>{gettext("Back to Channels")}</span>
          </.link>
        </div>

        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div>
            <div class="flex flex-wrap items-center gap-2.5">
              <h1
                id="channel-detail-name"
                class="text-2xl font-bold tracking-tight text-base-content"
              >
                {@channel.name}
              </h1>
              <span
                id="channel-detail-handle"
                class="badge badge-ghost border-base-300 font-mono text-xs text-base-content/70"
              >
                @{@channel.handle}
              </span>
              <span
                id="live-pubsub-indicator"
                class="badge badge-soft badge-success badge-sm gap-1.5 font-medium"
                title="Subscribed to live rollout channel and fleet telemetry updates"
              >
                <span class="status status-success animate-pulse"></span> Live
              </span>
            </div>
            <p class="text-sm text-base-content/60 mt-1">
              {gettext("Rollout ring target groups, deduplicated fleet reach, and campaign status in")}
              <span class="font-medium text-base-content/80">{@current_tenant.name}</span>.
            </p>
          </div>

          <div class="flex items-center gap-2 self-start sm:self-auto">
            <.link
              id="edit-channel-btn"
              patch={~p"/tenants/#{@current_tenant.slug}/channels/#{@channel.id}/edit"}
              class="btn btn-sm btn-outline border-base-300 bg-base-100 gap-1.5"
            >
              <.icon name="hero-pencil-square" class="size-4" />
              <span>{gettext("Edit Channel")}</span>
            </.link>

            <.button
              id="delete-channel-btn"
              type="button"
              variant="error"
              class="btn-sm btn-soft gap-1.5"
              phx-click="open_delete_modal"
            >
              <.icon name="hero-trash" class="size-4" />
              <span>{gettext("Delete")}</span>
            </.button>
          </div>
        </div>
      </div>

      <section
        id="channel-inspector-strip"
        aria-label="Rollout channel summary"
        class="grid grid-cols-1 md:grid-cols-3 gap-4"
      >
        <div class="card card-border bg-base-100 p-4 shadow-xs">
          <TargetGroupsComponent.target_groups
            target_groups={@target_groups}
            tenant={@current_tenant}
          />
        </div>

        <div class="card card-border bg-base-100 p-4 shadow-xs">
          <ChannelFleetComponent.fleet_reach reach={@reach} />
        </div>

        <div class="card card-border bg-base-100 p-4 shadow-xs">
          <div class="flex items-center justify-between mb-1">
            <span class="text-xs font-semibold uppercase tracking-wider text-base-content/60">
              {gettext("Rollout Status")}
            </span>
            <.icon name="hero-rocket-launch" class="size-4 text-primary" />
          </div>
          <CampaignStripComponent.campaign_strip campaign={@latest_campaign} />
        </div>
      </section>

      <div class="space-y-3">
        <h2 class="text-base font-bold text-base-content">
          {gettext("Reachable Devices")}
        </h2>

        <Cinder.collection
          id="channel-devices-table"
          query={@devices_query}
          tenant={@current_tenant}
          page_size={[default: 15, options: [10, 15, 25, 50]]}
          search={false}
        >
          <:col :let={device} field="online" sort label="Status">
            <.live_component
              module={StatusCellComponent}
              id={"device-status-#{device.id}"}
              device={device}
            />
          </:col>

          <:col :let={device} field="name" sort search label="Device">
            <.live_component
              module={NameCellComponent}
              id={"device-name-#{device.id}"}
              device={device}
            />
          </:col>

          <:col :let={device} field="device_id" hidden label="Device ID">
            <span class="font-mono text-base-content/55 tabular-nums">
              {device.device_id}
            </span>
          </:col>

          <:col :let={device} field="last_connection" sort label="Last Seen">
            <.live_component
              module={LastSeenCellComponent}
              id={"device-last-seen-#{device.id}"}
              device={device}
            />
          </:col>

          <:col :let={device} field="tags" label="Tags">
            <.live_component
              module={TagsCellComponent}
              id={"device-tags-#{device.id}"}
              device={device}
              tenant={@current_tenant}
            />
          </:col>
        </Cinder.collection>
      </div>

      <.live_component
        :if={@live_action == :edit}
        module={ChannelFormComponent}
        id="edit-channel-drawer"
        action={:edit}
        channel={@channel}
        tenant={@current_tenant}
        return_to={~p"/tenants/#{@current_tenant.slug}/channels/#{@channel.id}"}
      />

      <.live_component
        :if={@show_delete_modal}
        module={DeleteChannelModalComponent}
        id="delete-channel-modal"
        channel={@channel}
        tenant={@current_tenant}
      />
    </div>
    """
  end

  defp apply_channel_state(socket, channel) do
    tenant = socket.assigns.current_tenant
    target_groups = Enum.sort_by(channel.target_groups || [], & &1.name)
    reach = ChannelFleetComponent.compute_groups_reach(target_groups, tenant)
    latest_campaign = CampaignStripComponent.pick_featured_campaign(channel.campaigns || [])
    devices_query = ChannelFleetComponent.channel_devices_query(target_groups, tenant)

    socket
    |> assign(:channel, channel)
    |> assign(:target_groups, target_groups)
    |> assign(:reach, reach)
    |> assign(:latest_campaign, latest_campaign)
    |> assign(:devices_query, devices_query)
    |> assign(:page_title, "#{channel.name} · Channels · #{tenant.name}")
  end

  defp fetch_channel(id, tenant) do
    campaigns_query =
      Campaign
      |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
      |> Ash.Query.load(CampaignStripComponent.campaign_loads())

    with {int_id, ""} <- id |> to_string() |> Integer.parse(),
         {:ok, channel} <- Ash.get(Channel, int_id, tenant: tenant, authorize?: false) do
      {:ok,
       Ash.load!(channel, [:target_groups, campaigns: campaigns_query],
         tenant: tenant,
         authorize?: false,
         reuse_values?: false
       )}
    else
      _ -> :error
    end
  end
end
