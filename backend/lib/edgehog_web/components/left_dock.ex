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

defmodule EdgehogWeb.Components.LeftDock do
  @moduledoc """
  Floating vertical card dock for primary top-level navigation.

  Accepts declarative `:item` slots so layouts can compose top-level domain
  sections without relying on a monolithic navigation tree structure.
  """

  use Phoenix.Component
  use Gettext, backend: EdgehogWeb.Gettext

  import EdgehogWeb.Components.IconComponents

  alias Phoenix.LiveView.JS

  @doc """
  Renders the primary vertical navigation dock on the left edge of the viewport,
  along with a floating button to reopen the dock when collapsed.
  """
  attr :id, :string, default: "primary-nav-dock"
  attr :label, :string, default: "Primary navigation"

  slot :item, required: true do
    attr :id, :any, required: true
    attr :label, :string, required: true
    attr :icon, :string, required: true
    attr :navigate, :string, required: true
    attr :active, :boolean
  end

  def left_dock(assigns) do
    ~H"""
    <button
      type="button"
      id="nav-dock-open-button"
      phx-click={show_left_dock(@id)}
      class="btn btn-sm btn-square border border-base-300 bg-base-100/95 backdrop-blur shadow-xs fixed top-4 left-4 z-40 inline-flex text-base-content/70 hover:text-base-content"
      title={gettext("Show navigation dock")}
      aria-label={gettext("Show navigation dock")}
    >
      <.icon name="hero-bars-3-bottom-left" class="size-4" />
    </button>

    <div class="fixed inset-y-0 left-4 z-40 pointer-events-none flex items-center">
      <aside
        id={@id}
        aria-label={@label}
        class="card card-border bg-base-100/95 backdrop-blur pointer-events-auto flex h-auto max-h-[calc(100vh-8rem)] w-22 flex-col items-center gap-1 p-1.5 shadow-xs"
      >
        <button
          type="button"
          id="nav-dock-collapse-button"
          phx-click={hide_left_dock(@id)}
          class="btn btn-ghost btn-xs w-full rounded-field text-base-content/60 hover:text-base-content"
          title={gettext("Hide navigation dock")}
          aria-label={gettext("Hide navigation dock")}
        >
          <.icon name="hero-chevron-left-mini" class="size-4" />
        </button>

        <nav
          class="flex w-full flex-col items-center gap-1 overflow-y-auto no-scrollbar"
          aria-label={@label}
        >
          <%= for item <- @item do %>
            <% active? = Map.get(item, :active, false) %>
            <.link
              id={"nav-section-#{item.id}"}
              navigate={item.navigate}
              data-active={to_string(active?)}
              aria-current={if(active?, do: "page", else: nil)}
              class={[
                "group relative isolate flex w-full flex-col items-center justify-center gap-1 rounded-field px-1.5 py-2 text-center transition-colors select-none",
                if(active?,
                  do: "text-primary font-semibold",
                  else:
                    "text-base-content/65 font-medium hover:bg-base-200/80 hover:text-base-content"
                )
              ]}
            >
              <span
                :if={active?}
                data-role="dock-active-pill"
                class="pointer-events-none absolute inset-0 -z-10 rounded-field bg-primary/12"
              />
              <.icon
                name={item.icon}
                class={[
                  "size-4 transition-colors",
                  if(active?,
                    do: "text-primary",
                    else: "text-base-content/55 group-hover:text-base-content"
                  )
                ]}
              />
              <span class="text-[11px] leading-tight tracking-tight">{item.label}</span>
            </.link>
          <% end %>
        </nav>
      </aside>
    </div>
    """
  end

  @doc """
  Collapses the left primary dock and reveals the floating reopen button.
  """
  def hide_left_dock(dock_id \\ "primary-nav-dock", js \\ %JS{}) do
    JS.dispatch(js, "phx:set-left-dock",
      to: "##{dock_id}",
      detail: %{state: "collapsed"}
    )
  end

  @doc """
  Expands the left primary dock and hides the floating reopen button.
  """
  def show_left_dock(dock_id \\ "primary-nav-dock", js \\ %JS{}) do
    JS.dispatch(js, "phx:set-left-dock",
      to: "##{dock_id}",
      detail: %{state: "expanded"}
    )
  end
end
