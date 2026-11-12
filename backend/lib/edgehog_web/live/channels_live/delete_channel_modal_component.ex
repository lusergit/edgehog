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

defmodule EdgehogWeb.ChannelsLive.DeleteChannelModalComponent do
  @moduledoc """
  One-click confirmation floating pill modal `Phoenix.LiveComponent` for
  deleting an `Edgehog.Campaigns.Channel`.

  Blocks deletion when the channel is referenced by any campaign and informs
  operators how many assigned target groups will become unassigned.
  """
  use EdgehogWeb, :live_component

  @impl Phoenix.LiveComponent
  def update(%{channel: channel, tenant: tenant} = assigns, socket) do
    channel = ensure_associations_loaded(channel, tenant)
    target_groups_count = length(channel.target_groups || [])
    campaigns_count = length(channel.campaigns || [])

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:channel, channel)
     |> assign(:target_groups_count, target_groups_count)
     |> assign(:campaigns_count, campaigns_count)
     |> assign(:delete_error, nil)}
  end

  @impl Phoenix.LiveComponent
  def handle_event("cancel_delete", _params, socket) do
    send(self(), :close_delete_channel_modal)
    {:noreply, socket}
  end

  def handle_event("confirm_delete", _params, socket) do
    channel = socket.assigns.channel
    tenant = socket.assigns.tenant

    case Ash.destroy(channel, tenant: tenant, authorize?: false) do
      :ok ->
        send(self(), {:channel_deleted, channel})
        {:noreply, socket}

      {:error, _error} ->
        {:noreply,
         assign(
           socket,
           :delete_error,
           gettext("Cannot delete a channel that is referenced by existing campaigns.")
         )}
    end
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div
      id={@id}
      role="dialog"
      aria-modal="true"
      aria-labelledby={"#{@id}-title"}
      class="fixed inset-0 z-50 flex items-center justify-center p-4"
    >
      <.confirm_modal
        id={@id}
        title={gettext("Delete Rollout Channel")}
        entity_name={@channel.name}
        entity_handle={@channel.handle}
        target={@myself}
        cancel_id="cancel-delete-channel-btn"
        confirm_id="confirm-delete-channel-btn"
        confirm_label={gettext("Delete Channel")}
        confirm_disabled={@campaigns_count > 0}
        error_id="delete-channel-error"
        error={@delete_error}
      >
        <:blocker :if={@campaigns_count > 0} id="delete-channel-campaigns-blocker">
          {gettext("This channel is referenced by")}
          <strong class="font-semibold tabular-nums">{@campaigns_count}</strong>
          {if(@campaigns_count == 1, do: gettext("campaign"), else: gettext("campaigns"))}
          {gettext("and cannot be deleted.")}
        </:blocker>

        <:notice
          :if={@campaigns_count == 0 and @target_groups_count > 0}
          id="delete-channel-groups-notice"
          icon="hero-user-group"
        >
          <strong class="font-semibold tabular-nums">{@target_groups_count}</strong>
          {if(@target_groups_count == 1,
            do: gettext("assigned device group"),
            else: gettext("assigned device groups")
          )}
          {gettext("will become unassigned. Device groups and devices will not be deleted.")}
        </:notice>
      </.confirm_modal>
    </div>
    """
  end

  defp ensure_associations_loaded(
         %{target_groups: groups, campaigns: campaigns} = channel,
         _tenant
       )
       when is_list(groups) and is_list(campaigns),
       do: channel

  defp ensure_associations_loaded(channel, tenant) do
    Ash.load!(channel, [:target_groups, :campaigns],
      tenant: tenant,
      authorize?: false,
      reuse_values?: false
    )
  end
end
