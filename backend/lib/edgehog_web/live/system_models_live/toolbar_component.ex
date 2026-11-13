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

defmodule EdgehogWeb.SystemModelsLive.ToolbarComponent do
  @moduledoc """
  Stateless function components rendering the System Models search bar,
  hardware-type filter selector, quick-filter pill bar
  (`system_models_toolbar/1`), and the empty/filtered-out state callout
  (`system_models_empty_state/1`).
  """
  use EdgehogWeb, :html

  attr :search, :string, required: true
  attr :filter, :string, required: true
  attr :hardware_type_id, :any, default: nil
  attr :hardware_types, :list, default: []
  attr :filter_counts, :map, required: true

  def system_models_toolbar(assigns) do
    ~H"""
    <div class="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
      <div class="flex flex-col sm:flex-row sm:items-center gap-2.5 w-full lg:max-w-xl">
        <form
          id="system-models-search-form"
          phx-change="search"
          phx-submit="search"
          class="relative flex-1"
        >
          <.icon
            name="hero-magnifying-glass"
            class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-base-content/45"
          />
          <input
            type="search"
            name="search"
            value={@search}
            placeholder="Search models, handles, hardware types, or part numbers..."
            phx-debounce="150"
            class="input input-sm w-full pl-9 bg-base-100"
            aria-label="Search system models"
          />
        </form>

        <form
          :if={@hardware_types != []}
          id="system-models-hardware-type-filter"
          phx-change="filter_hardware_type"
          class="sm:w-52 shrink-0"
        >
          <select
            name="hardware_type_id"
            aria-label="Filter by hardware type"
            class="select select-sm w-full bg-base-100 text-xs font-medium"
          >
            <option value="" selected={is_nil(@hardware_type_id)}>
              {gettext("All Hardware Types")}
            </option>
            <option
              :for={ht <- @hardware_types}
              value={ht.id}
              selected={@hardware_type_id == ht.id}
            >
              {ht.name}
            </option>
          </select>
        </form>
      </div>

      <div
        id="system-models-filter-pills"
        role="group"
        aria-label="Filter system models"
        class="flex flex-wrap items-center gap-1.5"
      >
        <button
          :for={
            {key, label, count} <- [
              {"all", gettext("All"), @filter_counts.all},
              {"active_fleet", gettext("Active Fleet"), @filter_counts.active_fleet},
              {"empty_fleet", gettext("Empty (0 Devices)"), @filter_counts.empty_fleet},
              {"no_picture", gettext("No Picture"), @filter_counts.no_picture}
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

  attr :has_models?, :boolean, required: true

  def system_models_empty_state(assigns) do
    ~H"""
    <div
      id="system-models-empty-state"
      class="card card-border bg-base-100 p-10 text-center shadow-xs"
    >
      <div class="mx-auto flex size-12 items-center justify-center rounded-full bg-base-200 text-base-content/50">
        <.icon name="hero-device-tablet" class="size-6" />
      </div>
      <h2 class="mt-3 text-base font-semibold text-base-content">
        {if(@has_models?,
          do: gettext("No system models match your current filters"),
          else: gettext("No system models configured")
        )}
      </h2>
      <p class="mt-1 text-sm text-base-content/60 max-w-md mx-auto">
        {if(@has_models?,
          do:
            gettext(
              "Try clearing the search query or resetting the filter controls to view all configured system models."
            ),
          else:
            gettext(
              "Define system models to associate hardware types, product pictures, and part numbers with your connected fleet."
            )
        )}
      </p>
      <div :if={@has_models?} class="mt-4">
        <button
          id="clear-system-model-filters-btn"
          type="button"
          phx-click="clear_filters"
          class="btn btn-sm btn-ghost border border-base-300"
        >
          {gettext("Reset filters")}
        </button>
      </div>
    </div>
    """
  end
end
