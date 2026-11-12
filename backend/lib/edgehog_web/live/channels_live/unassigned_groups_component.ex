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

defmodule EdgehogWeb.ChannelsLive.UnassignedGroupsComponent do
  @moduledoc """
  Reactive `Phoenix.LiveComponent` rendering the bottom tray of device groups
  that are not currently assigned to any rollout channel ring.
  """
  use EdgehogWeb, :live_component

  alias Edgehog.Groups.DeviceGroup

  require Ash.Query

  @impl Phoenix.LiveComponent
  def update(%{tenant: tenant} = assigns, socket) do
    unassigned_groups =
      DeviceGroup
      |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
      |> Ash.Query.filter(is_nil(channel_id))
      |> Ash.Query.sort(name: :asc)
      |> Ash.read!(tenant: tenant, authorize?: false)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:unassigned_groups, unassigned_groups)}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <section
      id={@id}
      aria-label="Unassigned device groups"
      class="card card-border bg-base-100 p-4 sm:p-5 shadow-xs"
    >
      <div class="flex flex-col gap-1 sm:flex-row sm:items-center sm:justify-between">
        <div class="flex items-center gap-2">
          <.icon name="hero-inbox-stack" class="size-4 text-base-content/55" />
          <h2 class="text-sm font-semibold text-base-content">
            Unassigned Device Groups
          </h2>
          <span
            id="unassigned-groups-count"
            class="badge badge-soft badge-neutral badge-xs font-mono tabular-nums"
          >
            {length(@unassigned_groups)}
          </span>
        </div>
        <p class="text-xs text-base-content/55">
          Device groups not currently linked to any rollout channel ring.
        </p>
      </div>

      <div
        :if={@unassigned_groups != []}
        id="unassigned-groups-list"
        class="mt-3 flex flex-wrap gap-2"
      >
        <.link
          :for={group <- @unassigned_groups}
          id={"unassigned-group-#{group.id}"}
          data-group-handle={group.handle}
          navigate={~p"/tenants/#{@tenant.slug}/device-groups/#{group.id}"}
          class="inline-flex items-center gap-2 rounded-lg border border-base-300 bg-base-200/40 px-3 py-1.5 text-xs font-medium text-base-content transition-colors hover:border-primary/40 hover:bg-primary/5"
        >
          <.icon name="hero-user-group" class="size-3.5 text-base-content/55" />
          <span>{group.name}</span>
          <span class="font-mono text-[11px] text-base-content/55">@{group.handle}</span>
        </.link>
      </div>

      <p
        :if={@unassigned_groups == []}
        id="all-groups-assigned-notice"
        class="mt-2.5 text-xs text-success flex items-center gap-1.5"
      >
        <.icon name="hero-check-circle" class="size-4 shrink-0" />
        <span>All device groups in this tenant are assigned to a rollout channel.</span>
      </p>
    </section>
    """
  end
end
