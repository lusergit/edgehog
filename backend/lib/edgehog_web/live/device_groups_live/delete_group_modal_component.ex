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

defmodule EdgehogWeb.DeviceGroupsLive.DeleteGroupModalComponent do
  @moduledoc """
  One-click confirmation modal `Phoenix.LiveComponent` for deleting an
  `Edgehog.Groups.DeviceGroup`.

  Displays an explicit warning when the group is linked to a rollout channel.
  """
  use EdgehogWeb, :live_component

  @impl Phoenix.LiveComponent
  def update(%{group: group, tenant: tenant} = assigns, socket) do
    group = ensure_channel_loaded(group, tenant)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:group, group)}
  end

  @impl Phoenix.LiveComponent
  def handle_event("cancel_delete", _params, socket) do
    send(self(), :close_delete_group_modal)
    {:noreply, socket}
  end

  def handle_event("confirm_delete", _params, socket) do
    group = socket.assigns.group
    tenant = socket.assigns.tenant

    Ash.destroy!(group, tenant: tenant, authorize?: false)
    send(self(), {:group_deleted, group})

    {:noreply, socket}
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
        title={gettext("Delete Device Group")}
        entity_name={@group.name}
        entity_handle={@group.handle}
        extra_question={gettext("Devices will not be deleted.")}
        target={@myself}
        cancel_id="cancel-delete-group-btn"
        confirm_id="confirm-delete-group-btn"
        confirm_label={gettext("Delete Group")}
      >
        <:notice :if={@group.channel} id="delete-group-channel-warning" icon="hero-signal">
          {gettext("This group is currently assigned to rollout channel")}
          <strong class="font-semibold">{@group.channel.name}</strong>
          <span class="font-mono">(@{@group.channel.handle})</span>. {gettext(
            "Deleting it will remove it from that channel."
          )}
        </:notice>
      </.confirm_modal>
    </div>
    """
  end

  defp ensure_channel_loaded(%{channel_id: nil} = group, _tenant) do
    %{group | channel: nil}
  end

  defp ensure_channel_loaded(
         %{channel_id: channel_id, channel: %{id: channel_id}} = group,
         _tenant
       ) do
    group
  end

  defp ensure_channel_loaded(group, tenant) do
    Ash.load!(group, :channel, tenant: tenant, authorize?: false, reuse_values?: false)
  end
end
