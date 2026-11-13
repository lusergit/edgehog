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
    <.search_toolbar
      form_id="system-models-search-form"
      search={@search}
      placeholder="Search models, handles, hardware types, or part numbers..."
      aria_label="Search system models"
      pills_id="system-models-filter-pills"
      pills_label="Filter system models"
      filter={@filter}
      pills={[
        {"all", gettext("All"), @filter_counts.all},
        {"active_fleet", gettext("Active Fleet"), @filter_counts.active_fleet},
        {"empty_fleet", gettext("Empty (0 Devices)"), @filter_counts.empty_fleet},
        {"no_picture", gettext("No Picture"), @filter_counts.no_picture}
      ]}
    >
      <:filter_control :if={@hardware_types != []}>
        <form
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
      </:filter_control>
    </.search_toolbar>
    """
  end

  attr :has_models?, :boolean, required: true

  def system_models_empty_state(assigns) do
    ~H"""
    <.empty_state
      id="system-models-empty-state"
      icon="hero-device-tablet"
      filtered?={@has_models?}
      filtered_title={gettext("No system models match your current filters")}
      empty_title={gettext("No system models configured")}
      filtered_subtitle={
        gettext(
          "Try clearing the search query or resetting the filter controls to view all configured system models."
        )
      }
      empty_subtitle={
        gettext(
          "Define system models to associate hardware types, product pictures, and part numbers with your connected fleet."
        )
      }
      clear_button_id="clear-system-model-filters-btn"
    />
    """
  end
end
