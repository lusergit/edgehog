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

defmodule EdgehogWeb.Components.DataDisplayComponents do
  @moduledoc """
  Shared stateless UI function components for LiveView page headers, Live PubSub
  indicators, 4-band KPI summary strips, and fleet health progress bars.
  """
  use Phoenix.Component
  use Gettext, backend: EdgehogWeb.Gettext

  import EdgehogWeb.Components.IconComponents

  attr :id, :string, default: "live-pubsub-indicator"
  attr :title, :string, default: "Subscribed to live telemetry updates"

  def live_badge(assigns) do
    ~H"""
    <span
      id={@id}
      class="badge badge-soft badge-success badge-sm gap-1.5 font-medium"
      title={@title}
    >
      <span class="status status-success animate-pulse"></span> Live
    </span>
    """
  end

  attr :title, :string, required: true
  attr :title_id, :string, default: nil
  attr :handle, :string, default: nil
  attr :handle_id, :string, default: nil
  attr :live_title, :string, default: "Subscribed to live telemetry updates"
  attr :back_navigate, :string, default: nil
  attr :back_id, :string, default: nil
  attr :back_label, :string, default: nil
  slot :subtitle
  slot :actions

  def page_header(assigns) do
    ~H"""
    <div class="flex flex-col gap-3">
      <div :if={@back_navigate}>
        <.link
          id={@back_id}
          navigate={@back_navigate}
          class="inline-flex items-center gap-1.5 text-xs font-medium text-base-content/60 hover:text-base-content transition-colors"
        >
          <.icon name="hero-arrow-left" class="size-3.5" />
          <span>{@back_label}</span>
        </.link>
      </div>

      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <div class="flex flex-wrap items-center gap-2">
            <h1 id={@title_id} class="text-2xl font-bold tracking-tight text-base-content">
              {@title}
            </h1>
            <span
              :if={@handle}
              id={@handle_id}
              class="badge badge-ghost border-base-300 font-mono text-xs text-base-content/70"
            >
              @{@handle}
            </span>
            <.live_badge title={@live_title} />
          </div>
          <p :if={@subtitle != []} class="mt-1 text-sm text-base-content/60">
            {render_slot(@subtitle)}
          </p>
        </div>

        <div :if={@actions != []} class="flex items-center gap-2 self-start sm:self-auto">
          {render_slot(@actions)}
        </div>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  slot :inner_block, required: true

  def stat_strip(assigns) do
    ~H"""
    <section
      id={@id}
      aria-label={@label}
      class="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4"
    >
      {render_slot(@inner_block)}
    </section>
    """
  end

  attr :label, :string, required: true
  attr :icon, :string, required: true
  attr :icon_class, :string, default: "text-base-content/55"
  attr :value_id, :string, required: true
  attr :value, :any, required: true
  attr :value_class, :string, default: "text-base-content"
  attr :total, :any, default: nil
  attr :badge, :string, default: nil
  attr :badge_id, :string, default: nil

  attr :badge_class, :string,
    default: "font-mono text-xs font-medium tabular-nums text-base-content/60"

  attr :caption, :string, default: nil
  attr :caption_id, :string, default: nil
  attr :progress, :integer, default: nil
  attr :progress_class, :string, default: "progress-primary"

  def stat_card(assigns) do
    ~H"""
    <div class="card card-border bg-base-100 p-4 shadow-xs">
      <div class="flex items-center justify-between">
        <span class="text-xs font-semibold uppercase tracking-wider text-base-content/60">
          {@label}
        </span>
        <.icon name={@icon} class={["size-4", @icon_class]} />
      </div>
      <div class="mt-2 flex items-baseline justify-between gap-2">
        <p id={@value_id} class={["font-mono text-2xl font-bold tabular-nums", @value_class]}>
          {@value}
          <span :if={not is_nil(@total)} class="text-base font-medium text-base-content/60">
            / {@total}
          </span>
        </p>
        <span :if={@badge} id={@badge_id} class={@badge_class}>
          {@badge}
        </span>
      </div>
      <progress
        :if={not is_nil(@progress)}
        class={["progress mt-2 w-full", @progress_class]}
        value={@progress}
        max="100"
      />
      <p
        :if={@caption}
        id={@caption_id}
        class="mt-0.5 text-xs tabular-nums text-base-content/60"
      >
        {@caption}
      </p>
    </div>
    """
  end

  attr :compact, :boolean, default: false
  attr :label, :string, default: nil
  attr :total, :integer, required: true
  attr :online, :integer, required: true
  attr :pct, :integer, required: true
  attr :total_role, :string, default: nil
  attr :online_role, :string, default: nil
  attr :pct_role, :string, default: nil
  slot :footer

  def fleet_health_bar(%{compact: true} = assigns) do
    ~H"""
    <div class="inline-flex items-center">
      <span
        :if={@total == 0}
        data-fleet-state="empty"
        class="badge badge-soft badge-warning badge-sm gap-1.5 font-medium"
      >
        <.icon name="hero-exclamation-triangle" class="size-3.5" /> 0 devices
      </span>

      <div :if={@total > 0} data-fleet-state="active" class="flex flex-col gap-1 min-w-28">
        <div class="flex items-center gap-1.5">
          <span class={if(@online > 0, do: "status status-success", else: "status")}></span>
          <span class="font-mono text-xs font-semibold tabular-nums text-base-content">
            {@online} / {@total} online
          </span>
        </div>
        <progress class="progress progress-success h-1.5 w-24" value={@pct} max="100" />
      </div>
    </div>
    """
  end

  def fleet_health_bar(assigns) do
    ~H"""
    <div class="border-t border-base-200 pt-3.5">
      <div class="flex items-center justify-between gap-2">
        <span class="text-xs font-semibold uppercase tracking-wider text-base-content/60">
          {@label}
        </span>
        <span
          data-role={@pct_role}
          class="font-mono text-xs font-medium tabular-nums text-base-content/60"
        >
          {@pct}% online
        </span>
      </div>

      <div class="mt-1.5 flex items-baseline justify-between gap-2">
        <div class="flex items-baseline gap-1.5">
          <span
            data-role={@total_role}
            class="font-mono text-lg font-bold tabular-nums text-base-content"
          >
            {@total}
          </span>
          <span class="text-xs text-base-content/55">
            {if(@total == 1, do: gettext("device"), else: gettext("devices"))}
          </span>
        </div>
        <span
          data-role={@online_role}
          class="font-mono text-xs font-medium tabular-nums text-success"
        >
          {@online} online
        </span>
      </div>

      <progress
        class={["progress mt-2 w-full", reach_progress_color(@total, @online)]}
        value={@pct}
        max="100"
      />

      {render_slot(@footer)}
    </div>
    """
  end

  defp reach_progress_color(0, _online), do: "progress-warning"
  defp reach_progress_color(_total, 0), do: "progress-error"
  defp reach_progress_color(_total, _online), do: "progress-success"
end
