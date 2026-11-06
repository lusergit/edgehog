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
      <div
        phx-click="cancel_delete"
        phx-target={@myself}
        class="fixed inset-0 bg-base-content/20 transition-opacity"
      />

      <div class="relative z-10 w-full max-w-md rounded-3xl border border-base-300 bg-base-100/95 backdrop-blur p-6 shadow-xl space-y-4">
        <div class="flex items-start gap-3">
          <div class="flex size-10 shrink-0 items-center justify-center rounded-full bg-error/15 text-error">
            <.icon name="hero-exclamation-triangle" class="size-5" />
          </div>
          <div class="space-y-1">
            <h2 id={"#{@id}-title"} class="text-base font-bold text-base-content">
              {gettext("Delete Device Group")}
            </h2>
            <p class="text-sm text-base-content/70">
              {gettext("Are you sure you want to delete")}
              <span class="font-semibold text-base-content">{@group.name}</span>
              <span class="font-mono text-xs text-base-content/55">(@{@group.handle})</span>? {gettext(
                "Devices will not be deleted."
              )}
            </p>
          </div>
        </div>

        <div
          :if={@group.channel}
          id="delete-group-channel-warning"
          class="alert alert-warning text-xs py-2.5 px-3"
        >
          <.icon name="hero-signal" class="size-4 shrink-0" />
          <span>
            {gettext("This group is currently assigned to rollout channel")}
            <strong class="font-semibold">{@group.channel.name}</strong>
            <span class="font-mono">(@{@group.channel.handle})</span>. {gettext(
              "Deleting it will remove it from that channel."
            )}
          </span>
        </div>

        <div class="flex items-center justify-end gap-2 pt-2">
          <.button
            id="cancel-delete-group-btn"
            type="button"
            variant="ghost"
            class="btn-sm rounded-full px-4"
            phx-click="cancel_delete"
            phx-target={@myself}
          >
            {gettext("Cancel")}
          </.button>

          <.button
            id="confirm-delete-group-btn"
            type="button"
            variant="error"
            class="btn-sm rounded-full px-5"
            phx-click="confirm_delete"
            phx-target={@myself}
          >
            {gettext("Delete Group")}
          </.button>
        </div>
      </div>
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
