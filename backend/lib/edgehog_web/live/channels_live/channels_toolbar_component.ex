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

defmodule EdgehogWeb.ChannelsLive.ChannelsToolbarComponent do
  @moduledoc """
  Stateless function components rendering the Channels search and quick-filter
  pill bar (`channels_toolbar/1`) and the empty/filtered-out state callout
  (`channels_empty_state/1`).
  """
  use EdgehogWeb, :html

  attr :search, :string, required: true
  attr :filter, :string, required: true
  attr :filter_counts, :map, required: true

  def channels_toolbar(assigns) do
    ~H"""
    <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
      <form
        id="channels-search-form"
        phx-change="search"
        phx-submit="search"
        class="relative w-full sm:max-w-xs"
      >
        <.icon
          name="hero-magnifying-glass"
          class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-base-content/45"
        />
        <input
          type="search"
          name="search"
          value={@search}
          placeholder="Search channels or target groups..."
          phx-debounce="150"
          class="input input-sm w-full pl-9 bg-base-100"
          aria-label="Search channels or target groups"
        />
      </form>

      <div
        id="channels-filter-pills"
        role="group"
        aria-label="Filter channels"
        class="flex flex-wrap items-center gap-1.5"
      >
        <button
          :for={
            {key, label, count} <- [
              {"all", "All", @filter_counts.all},
              {"active_rollout", "Active Rollout", @filter_counts.active_rollout},
              {"empty_groups", "Empty (0 Groups)", @filter_counts.empty_groups},
              {"zero_devices", "0 Devices", @filter_counts.zero_devices}
            ]
          }
          type="button"
          phx-click="filter"
          phx-value-filter={key}
          data-filter={key}
          data-active={to_string(@filter == key)}
          class={[
            "btn btn-xs rounded-full gap-1.5 font-medium transition-colors",
            if(@filter == key,
              do: "btn-primary",
              else: "btn-ghost border border-base-300 bg-base-100 text-base-content/70"
            )
          ]}
        >
          <span>{label}</span>
          <span class="font-mono text-[11px] tabular-nums opacity-75">{count}</span>
        </button>
      </div>
    </div>
    """
  end

  attr :has_channels?, :boolean, required: true

  def channels_empty_state(assigns) do
    ~H"""
    <div
      id="channels-empty-state"
      class="card card-border bg-base-100 p-10 text-center shadow-xs"
    >
      <div class="mx-auto flex size-12 items-center justify-center rounded-full bg-base-200 text-base-content/50">
        <.icon name="hero-signal" class="size-6" />
      </div>
      <h2 class="mt-3 text-base font-semibold text-base-content">
        {if(@has_channels?,
          do: "No channels match your current filters",
          else: "No rollout channels configured"
        )}
      </h2>
      <p class="mt-1 text-sm text-base-content/60 max-w-md mx-auto">
        {if(@has_channels?,
          do:
            "Try clearing the search query or switching back to the All filter to view all configured channels.",
          else:
            "Create rollout channels to organize device groups into staged deployment rings for firmware updates and applications."
        )}
      </p>
      <div :if={@has_channels?} class="mt-4">
        <button
          id="clear-channel-filters-btn"
          type="button"
          phx-click="clear_filters"
          class="btn btn-sm btn-ghost border border-base-300"
        >
          Reset filters
        </button>
      </div>
    </div>
    """
  end
end
