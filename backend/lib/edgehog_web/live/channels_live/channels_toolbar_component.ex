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
    <.search_toolbar
      form_id="channels-search-form"
      search={@search}
      placeholder="Search channels or target groups..."
      aria_label="Search channels or target groups"
      pills_id="channels-filter-pills"
      pills_label="Filter channels"
      filter={@filter}
      pills={[
        {"all", "All", @filter_counts.all},
        {"active_rollout", "Active Rollout", @filter_counts.active_rollout},
        {"empty_groups", "Empty (0 Groups)", @filter_counts.empty_groups},
        {"zero_devices", "0 Devices", @filter_counts.zero_devices}
      ]}
    />
    """
  end

  attr :has_channels?, :boolean, required: true

  def channels_empty_state(assigns) do
    ~H"""
    <.empty_state
      id="channels-empty-state"
      icon="hero-signal"
      filtered?={@has_channels?}
      filtered_title="No channels match your current filters"
      empty_title="No rollout channels configured"
      filtered_subtitle="Try clearing the search query or switching back to the All filter to view all configured channels."
      empty_subtitle="Create rollout channels to organize device groups into staged deployment rings for firmware updates and applications."
      clear_button_id="clear-channel-filters-btn"
    />
    """
  end
end
