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

defmodule EdgehogWeb.ChannelsLive.ChannelFleetComponent do
  @moduledoc """
  Stateless function component rendering a rollout channel's `%FleetReach{}`
  (deduplicated device reach, online availability ratio, and system model
  compatibility pills).
  """
  use EdgehogWeb, :html

  attr :reach, :map, required: true

  def fleet_reach(assigns) do
    total = assigns.reach.total_count
    online = assigns.reach.online_count
    pct = if total > 0, do: round(online / total * 100), else: 0

    assigns =
      assigns
      |> assign(:total, total)
      |> assign(:online, online)
      |> assign(:pct, pct)
      |> assign(:system_models, assigns.reach.system_model_counts || [])

    ~H"""
    <.fleet_health_bar
      label="Deduplicated Fleet Reach"
      total={@total}
      online={@online}
      pct={@pct}
      total_role="channel-total-devices"
      online_role="channel-online-devices"
      pct_role="channel-reach-pct"
    >
      <:footer>
        <div
          :if={@system_models != []}
          data-role="channel-system-models"
          class="mt-2.5 flex flex-wrap gap-1.5"
        >
          <span
            :for={model <- @system_models}
            data-system-model={model.handle}
            class="inline-flex items-center gap-1 rounded-md border border-base-300 bg-base-200/50 px-2 py-0.5 text-[11px] font-medium text-base-content/75"
          >
            <.icon name="hero-cpu-chip" class="size-3 text-base-content/50" />
            <span>{model.name}</span>
            <span class="font-mono tabular-nums text-base-content/55">({model.device_count})</span>
          </span>
        </div>
      </:footer>
    </.fleet_health_bar>
    """
  end
end
