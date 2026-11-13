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

defmodule EdgehogWeb.Components.OverlayComponents do
  @moduledoc """
  Shared stateless UI function components for non-blocking right-side floating
  pill drawers (`<.floating_pill_drawer>`, `<.drawer_footer>`) and guarded
  floating pill confirmation modals (`<.confirm_modal>`).
  """
  use Phoenix.Component
  use Gettext, backend: EdgehogWeb.Gettext

  import EdgehogWeb.Components.FormComponents, only: [button: 1]
  import EdgehogWeb.Components.IconComponents

  attr :id, :string, required: true
  attr :icon, :string, required: true
  attr :icon_class, :string, default: "bg-primary/15 text-primary"
  attr :title, :string, required: true
  attr :subtitle, :string, required: true
  attr :close_patch, :string, required: true
  attr :close_id, :string, default: nil
  slot :inner_block, required: true

  def floating_pill_drawer(assigns) do
    ~H"""
    <aside
      id={"#{@id}-panel"}
      class="card card-border rounded-3xl bg-base-100/95 backdrop-blur pointer-events-auto animate-floating-pill-right flex h-auto max-h-[calc(100vh-8rem)] w-[calc(100vw-2rem)] sm:w-120 lg:w-136 flex-col overflow-hidden shadow-xl"
    >
      <div class="flex items-center justify-between border-b border-base-300/70 px-6 py-4">
        <div class="flex items-center gap-2.5">
          <span class={["flex size-8 shrink-0 items-center justify-center rounded-xl", @icon_class]}>
            <.icon name={@icon} class="size-4" />
          </span>
          <div>
            <h2 id={"#{@id}-title"} class="text-base font-bold text-base-content">
              {@title}
            </h2>
            <p class="text-xs text-base-content/60">{@subtitle}</p>
          </div>
        </div>

        <.link
          id={@close_id || "#{@id}-close-btn"}
          patch={@close_patch}
          class="btn btn-ghost btn-sm btn-circle"
          aria-label={gettext("Close drawer")}
        >
          <.icon name="hero-x-mark" class="size-4" />
        </.link>
      </div>

      {render_slot(@inner_block)}
    </aside>
    """
  end

  attr :cancel_patch, :string, required: true
  attr :cancel_id, :string, default: nil
  attr :submit_id, :string, required: true
  attr :submit_label, :string, required: true
  attr :submit_disabled, :boolean, default: false

  attr :class, :string,
    default: "flex items-center justify-end gap-2 border-t border-base-300/70 pt-4"

  def drawer_footer(assigns) do
    ~H"""
    <div class={@class}>
      <.link
        id={@cancel_id}
        patch={@cancel_patch}
        class="btn btn-ghost btn-sm rounded-full px-4"
      >
        {gettext("Cancel")}
      </.link>

      <.button
        id={@submit_id}
        type="submit"
        variant="primary"
        class="btn-sm rounded-full px-5"
        disabled={@submit_disabled}
      >
        {@submit_label}
      </.button>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :entity_name, :string, required: true
  attr :entity_handle, :string, required: true
  attr :extra_question, :string, default: nil
  attr :target, :any, required: true
  attr :cancel_event, :string, default: "cancel_delete"
  attr :confirm_event, :string, default: "confirm_delete"
  attr :cancel_id, :string, required: true
  attr :confirm_id, :string, required: true
  attr :confirm_label, :string, required: true
  attr :confirm_disabled, :boolean, default: false
  attr :error_id, :string, default: nil
  attr :error, :string, default: nil

  slot :blocker do
    attr :id, :string, required: true
  end

  slot :notice do
    attr :id, :string, required: true
    attr :icon, :string
  end

  def confirm_modal(assigns) do
    ~H"""
    <div
      phx-click={@cancel_event}
      phx-target={@target}
      class="fixed inset-0 bg-base-content/20 transition-opacity"
    />

    <div class="relative z-10 w-full max-w-md rounded-3xl border border-base-300 bg-base-100/95 backdrop-blur p-6 shadow-xl space-y-4">
      <div class="flex items-start gap-3">
        <div class="flex size-10 shrink-0 items-center justify-center rounded-full bg-error/15 text-error">
          <.icon name="hero-exclamation-triangle" class="size-5" />
        </div>
        <div class="space-y-1">
          <h2 id={"#{@id}-title"} class="text-base font-bold text-base-content">
            {@title}
          </h2>
          <p class="text-sm text-base-content/70">
            {gettext("Are you sure you want to delete")}
            <span class="font-semibold text-base-content">{@entity_name}</span>
            <span class="font-mono text-xs text-base-content/55">(@{@entity_handle})</span>? {@extra_question}
          </p>
        </div>
      </div>

      <div
        :for={blocker <- @blocker}
        id={blocker.id}
        class="alert alert-error text-xs py-2.5 px-3"
      >
        <.icon name="hero-lock-closed" class="size-4 shrink-0" />
        <span>{render_slot(blocker)}</span>
      </div>

      <div
        :for={notice <- @notice}
        id={notice.id}
        class="alert alert-warning text-xs py-2.5 px-3"
      >
        <.icon
          name={Map.get(notice, :icon, "hero-exclamation-triangle")}
          class="size-4 shrink-0"
        />
        <span>{render_slot(notice)}</span>
      </div>

      <div
        :if={@error}
        id={@error_id}
        class="alert alert-error text-xs py-2.5 px-3"
      >
        <.icon name="hero-exclamation-circle" class="size-4 shrink-0" />
        <span>{@error}</span>
      </div>

      <div class="flex items-center justify-end gap-2 pt-2">
        <.button
          id={@cancel_id}
          type="button"
          variant="ghost"
          class="btn-sm rounded-full px-4"
          phx-click={@cancel_event}
          phx-target={@target}
        >
          {gettext("Cancel")}
        </.button>

        <.button
          id={@confirm_id}
          type="button"
          variant="error"
          class="btn-sm rounded-full px-5"
          disabled={@confirm_disabled}
          phx-click={@confirm_event}
          phx-target={@target}
        >
          {@confirm_label}
        </.button>
      </div>
    </div>
    """
  end
end
