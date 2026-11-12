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

defmodule EdgehogWeb.ChannelsLive.TargetGroupsComponent do
  @moduledoc """
  Stateless function component rendering a channel's assigned target device
  group chips (linking to `/tenants/:tenant_slug/device-groups/:id`) or an
  empty-groups warning callout.
  """
  use EdgehogWeb, :html

  attr :target_groups, :list, required: true
  attr :tenant, :map, required: true

  def target_groups(assigns) do
    ~H"""
    <div class="border-t border-base-200 pt-3.5">
      <div class="flex items-center justify-between gap-2 mb-2">
        <span class="text-xs font-semibold uppercase tracking-wider text-base-content/60">
          Target Groups
        </span>
        <span
          data-role="target-groups-count"
          class="text-xs font-medium tabular-nums text-base-content/55"
        >
          {length(@target_groups)}
        </span>
      </div>

      <div
        :if={@target_groups != []}
        data-role="target-groups-list"
        class="flex flex-wrap gap-1.5"
      >
        <.link
          :for={group <- @target_groups}
          navigate={~p"/tenants/#{@tenant.slug}/device-groups/#{group.id}"}
          data-group-handle={group.handle}
          class="badge badge-soft badge-neutral gap-1.5 py-2.5 px-2.5 text-xs font-medium transition-colors hover:badge-primary"
        >
          <.icon name="hero-user-group" class="size-3 opacity-65" />
          <span>{group.name}</span>
          <span class="font-mono text-[11px] opacity-60">@{group.handle}</span>
        </.link>
      </div>

      <div
        :if={@target_groups == []}
        data-role="empty-target-groups"
        class="flex items-center justify-between gap-2 rounded-lg border border-dashed border-warning/40 bg-warning/5 px-3 py-2 text-xs text-warning"
      >
        <div class="flex items-center gap-1.5">
          <.icon name="hero-exclamation-triangle" class="size-3.5 shrink-0" />
          <span>No target groups assigned</span>
        </div>
        <.link
          navigate={~p"/tenants/#{@tenant.slug}/device-groups"}
          class="font-semibold underline hover:opacity-80"
        >
          Assign groups
        </.link>
      </div>
    </div>
    """
  end
end
