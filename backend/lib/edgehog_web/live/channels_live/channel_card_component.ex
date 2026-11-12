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

defmodule EdgehogWeb.ChannelsLive.ChannelCardComponent do
  @moduledoc """
  Reactive Bento Rollout Ring Card `LiveComponent` shell (`#channel-card-<id>`)
  subscribing to `"channels:<id>"` and composing `TargetGroupsComponent`,
  `ChannelFleetComponent`, and `CampaignStripComponent`.
  """
  use EdgehogWeb, :live_component

  alias Edgehog.Campaigns.Campaign
  alias EdgehogWeb.ChannelsLive.CampaignStripComponent
  alias EdgehogWeb.ChannelsLive.ChannelFleetComponent
  alias EdgehogWeb.ChannelsLive.TargetGroupsComponent

  @impl Phoenix.LiveComponent
  def update(%{channel: channel, tenant: tenant} = assigns, socket) do
    channel = ensure_associations_loaded(channel, tenant)

    reach =
      Map.get_lazy(assigns, :reach, fn ->
        ChannelFleetComponent.compute_channel_reach(channel, tenant)
      end)

    latest_campaign = CampaignStripComponent.pick_featured_campaign(channel.campaigns || [])

    socket =
      socket
      |> assign(assigns)
      |> assign(:channel, channel)
      |> assign(:target_groups, Enum.sort_by(channel.target_groups || [], & &1.name))
      |> assign(:reach, reach)
      |> assign(:latest_campaign, latest_campaign)
      |> ensure_subscribed(channel.id)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <article
      id={@id}
      data-channel-handle={@channel.handle}
      class="card card-border bg-base-100 p-5 shadow-xs flex flex-col justify-between gap-4 transition-colors hover:border-base-300"
    >
      <div class="flex flex-col gap-4">
        <div class="flex items-start justify-between gap-3">
          <div class="flex items-start gap-2.5 min-w-0">
            <div class="mt-0.5 flex size-8 shrink-0 items-center justify-center rounded-lg bg-info/10 text-info">
              <.icon name="hero-signal" class="size-4" />
            </div>
            <div class="min-w-0">
              <h2
                data-role="channel-name"
                class="font-semibold text-base text-base-content leading-tight truncate"
              >
                {@channel.name}
              </h2>
              <p
                data-role="channel-handle"
                class="mt-0.5 font-mono text-xs text-base-content/55 truncate"
              >
                @{@channel.handle}
              </p>
            </div>
          </div>

          {render_channel_badge(assigns)}
        </div>

        <TargetGroupsComponent.target_groups target_groups={@target_groups} tenant={@tenant} />
        <ChannelFleetComponent.fleet_reach reach={@reach} />
      </div>

      <CampaignStripComponent.campaign_strip campaign={@latest_campaign} />
    </article>
    """
  end

  defp render_channel_badge(assigns) do
    cond do
      assigns.target_groups == [] ->
        ~H"""
        <span
          data-role="channel-status-badge"
          class="badge badge-soft badge-warning badge-sm gap-1 font-medium"
        >
          <.icon name="hero-exclamation-triangle" class="size-3" /> Empty Ring
        </span>
        """

      not is_nil(assigns.latest_campaign) and
          CampaignStripComponent.active_campaign_status?(assigns.latest_campaign.status) ->
        ~H"""
        <span
          data-role="channel-status-badge"
          class="badge badge-soft badge-primary badge-sm gap-1 font-medium"
        >
          <span class="size-1.5 rounded-full bg-primary animate-pulse" /> Active Rollout
        </span>
        """

      true ->
        ~H"""
        <span
          data-role="channel-status-badge"
          class="badge badge-soft badge-success badge-sm gap-1 font-medium"
        >
          <.icon name="hero-check-circle" class="size-3" /> Ready
        </span>
        """
    end
  end

  defp ensure_associations_loaded(
         %{target_groups: groups, campaigns: campaigns} = channel,
         _tenant
       )
       when is_list(groups) and is_list(campaigns) do
    channel
  end

  defp ensure_associations_loaded(channel, tenant) do
    campaigns_query =
      Campaign
      |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
      |> Ash.Query.load(CampaignStripComponent.campaign_loads())

    Ash.load!(
      channel,
      [:target_groups, campaigns: campaigns_query],
      tenant: tenant,
      authorize?: false,
      reuse_values?: false
    )
  end

  defp ensure_subscribed(socket, channel_id) do
    if connected?(socket) and not Map.get(socket.assigns, :subscribed?, false) do
      EdgehogWeb.Endpoint.subscribe("channels:#{channel_id}")
      assign(socket, :subscribed?, true)
    else
      socket
    end
  end
end
