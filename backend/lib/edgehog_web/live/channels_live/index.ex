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

defmodule EdgehogWeb.ChannelsLive.Index do
  @moduledoc """
  LiveView for browsing, searching, and monitoring a tenant's rollout channels
  in real time using a Bento Grid of Rollout Ring Cards.

  Composes `ChannelsStatsComponent`, `ChannelsToolbarComponent`, a responsive
  grid of `ChannelCardComponent`s, and `UnassignedGroupsComponent`.
  """
  use EdgehogWeb, :live_view

  alias Edgehog.Campaigns.Campaign
  alias Edgehog.Campaigns.Channel
  alias EdgehogWeb.ChannelsLive.CampaignStripComponent
  alias EdgehogWeb.ChannelsLive.ChannelCardComponent
  alias EdgehogWeb.ChannelsLive.ChannelFleetComponent
  alias EdgehogWeb.ChannelsLive.ChannelFormComponent
  alias EdgehogWeb.ChannelsLive.ChannelsStatsComponent
  alias EdgehogWeb.ChannelsLive.ChannelsToolbarComponent
  alias EdgehogWeb.ChannelsLive.UnassignedGroupsComponent

  @valid_filters ~w(all active_rollout empty_groups zero_devices)

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_tenant

    if connected?(socket) do
      EdgehogWeb.Endpoint.subscribe("channels:tenant:#{tenant.tenant_id}")
      EdgehogWeb.Endpoint.subscribe("campaigns:tenant:#{tenant.tenant_id}")
      EdgehogWeb.Endpoint.subscribe("device_groups:tenant:#{tenant.tenant_id}")
      EdgehogWeb.Endpoint.subscribe("devices:tenant:#{tenant.tenant_id}")
    end

    socket =
      socket
      |> assign(:page_title, "Channels · #{tenant.name}")
      |> assign(:search, "")
      |> assign(:filter, "all")
      |> load_channels()

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _uri, socket) do
    tenant = socket.assigns.current_tenant

    page_title =
      case socket.assigns.live_action do
        :new -> "New Channel · #{tenant.name}"
        _ -> "Channels · #{tenant.name}"
      end

    {:noreply, assign(socket, :page_title, page_title)}
  end

  @impl Phoenix.LiveView
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply,
     socket
     |> assign(:search, String.trim(search))
     |> recompute_filtered_channels()}
  end

  def handle_event("filter", %{"filter" => filter}, socket) when filter in @valid_filters do
    {:noreply,
     socket
     |> assign(:filter, filter)
     |> recompute_filtered_channels()}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:search, "")
     |> assign(:filter, "all")
     |> recompute_filtered_channels()}
  end

  @impl Phoenix.LiveView
  def handle_info(%Phoenix.Socket.Broadcast{topic: topic}, socket) when is_binary(topic) do
    tenant = socket.assigns.current_tenant
    send_update(ChannelsStatsComponent, id: "channels-stats", tenant: tenant)
    send_update(UnassignedGroupsComponent, id: "unassigned-groups-tray", tenant: tenant)

    {:noreply, load_channels(socket)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-6 space-y-6">
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <div class="flex items-center gap-2">
            <h1 class="text-2xl font-bold tracking-tight text-base-content">
              Channels
            </h1>
            <span
              id="live-pubsub-indicator"
              class="badge badge-soft badge-success badge-sm gap-1.5 font-medium"
              title="Subscribed to live rollout channel and fleet telemetry updates"
            >
              <span class="status status-success animate-pulse"></span> Live
            </span>
          </div>
          <p class="mt-1 text-sm text-base-content/60">
            Rollout rings grouping target cohorts for staged OTA updates, container deployments, and file deliveries in <span class="font-medium text-base-content/80">{@current_tenant.name}</span>.
          </p>
        </div>

        <div class="flex items-center gap-2 self-start sm:self-auto">
          <.link
            id="create-channel-btn"
            patch={~p"/tenants/#{@current_tenant.slug}/channels/new"}
            class="btn btn-primary btn-sm gap-1.5"
          >
            <.icon name="hero-plus" class="size-4" />
            <span>{gettext("Create Channel")}</span>
          </.link>
        </div>
      </div>

      <.live_component module={ChannelsStatsComponent} id="channels-stats" tenant={@current_tenant} />

      <ChannelsToolbarComponent.channels_toolbar
        search={@search}
        filter={@filter}
        filter_counts={@filter_counts}
      />

      <section
        :if={@filtered_channels != []}
        id="channels-grid"
        aria-label="Rollout channels grid"
        class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4"
      >
        <.live_component
          :for={entry <- @filtered_channels}
          module={ChannelCardComponent}
          id={"channel-card-#{entry.channel.id}"}
          channel={entry.channel}
          reach={entry.reach}
          tenant={@current_tenant}
        />
      </section>

      <ChannelsToolbarComponent.channels_empty_state
        :if={@filtered_channels == []}
        has_channels?={@channel_entries != []}
      />

      <.live_component
        module={UnassignedGroupsComponent}
        id="unassigned-groups-tray"
        tenant={@current_tenant}
      />

      <.live_component
        :if={@live_action == :new}
        module={ChannelFormComponent}
        id="channel-form-drawer"
        action={:new}
        channel={%Channel{}}
        tenant={@current_tenant}
        return_to={~p"/tenants/#{@current_tenant.slug}/channels"}
      />
    </div>
    """
  end

  defp load_channels(socket) do
    tenant = socket.assigns.current_tenant

    campaigns_query =
      Campaign
      |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
      |> Ash.Query.load(CampaignStripComponent.campaign_loads())

    channels =
      Channel
      |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
      |> Ash.Query.load([:target_groups, campaigns: campaigns_query])
      |> Ash.Query.sort(name: :asc)
      |> Ash.read!(tenant: tenant, authorize?: false)

    channel_entries =
      Enum.map(channels, fn channel ->
        reach = ChannelFleetComponent.compute_channel_reach(channel, tenant)

        has_active_rollout =
          Enum.any?(channel.campaigns || [], fn campaign ->
            CampaignStripComponent.active_campaign_status?(campaign.status)
          end)

        %{
          channel: channel,
          reach: reach,
          has_active_rollout: has_active_rollout
        }
      end)

    filter_counts = %{
      all: length(channel_entries),
      active_rollout: Enum.count(channel_entries, & &1.has_active_rollout),
      empty_groups: Enum.count(channel_entries, &Enum.empty?(&1.channel.target_groups || [])),
      zero_devices: Enum.count(channel_entries, &(&1.reach.total == 0))
    }

    socket
    |> assign(:channel_entries, channel_entries)
    |> assign(:filter_counts, filter_counts)
    |> recompute_filtered_channels()
  end

  defp recompute_filtered_channels(socket) do
    search = String.downcase(socket.assigns.search || "")
    filter = socket.assigns.filter || "all"

    filtered =
      Enum.filter(socket.assigns.channel_entries, fn entry ->
        matches_filter?(entry, filter) and matches_search?(entry, search)
      end)

    assign(socket, :filtered_channels, filtered)
  end

  defp matches_filter?(_entry, "all"), do: true
  defp matches_filter?(entry, "active_rollout"), do: entry.has_active_rollout

  defp matches_filter?(entry, "empty_groups"),
    do: Enum.empty?(entry.channel.target_groups || [])

  defp matches_filter?(entry, "zero_devices"), do: entry.reach.total == 0
  defp matches_filter?(_entry, _other), do: true

  defp matches_search?(_entry, ""), do: true

  defp matches_search?(%{channel: channel}, query) do
    channel_match? =
      contains_query?(channel.name, query) or contains_query?(channel.handle, query)

    group_match? =
      Enum.any?(channel.target_groups || [], fn group ->
        contains_query?(group.name, query) or contains_query?(group.handle, query)
      end)

    channel_match? or group_match?
  end

  defp contains_query?(text, query) do
    text
    |> String.downcase()
    |> String.contains?(query)
  end
end
