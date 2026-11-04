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

defmodule EdgehogWeb.Components.BottomDock do
  @moduledoc """
  Floating horizontal card dock for contextual sub-navigation.

  Accepts declarative `:item` slots so layouts can compose contextual sub-items
  for the active section without relying on a monolithic navigation tree map.
  """

  use Phoenix.Component

  import EdgehogWeb.Components.IconComponents

  @doc """
  Renders the contextual horizontal navigation dock at the bottom center of the viewport.
  """
  attr :id, :string, default: "secondary-nav-dock"
  attr :label, :string, default: "Contextual navigation"
  attr :section, :any, default: nil

  slot :item, required: true do
    attr :id, :any, required: true
    attr :label, :string, required: true
    attr :icon, :string, required: true
    attr :navigate, :string, required: true
    attr :active, :boolean
  end

  def bottom_dock(assigns) do
    ~H"""
    <div
      :if={@item != []}
      class="fixed inset-x-0 bottom-5 z-30 pointer-events-none flex justify-center pl-4 pr-16 sm:pr-36 md:pl-28 lg:px-52"
    >
      <nav
        id={@id}
        aria-label={@label}
        data-section={@section && to_string(@section)}
        class="card card-border bg-base-100/95 backdrop-blur pointer-events-auto flex max-w-full flex-row items-center gap-1 overflow-x-auto p-1 shadow-xs no-scrollbar transition-all duration-200"
      >
        <%= for item <- @item do %>
          <% active? = Map.get(item, :active, false) %>
          <.link
            id={"nav-subitem-#{item.id}"}
            navigate={item.navigate}
            data-active={to_string(active?)}
            aria-current={if(active?, do: "page", else: nil)}
            class={[
              "group flex shrink-0 items-center gap-1.5 whitespace-nowrap rounded-field px-3 py-1.5 text-xs transition-colors select-none",
              if(active?,
                do: "bg-primary/12 text-primary font-semibold",
                else: "text-base-content/65 font-medium hover:bg-base-200/80 hover:text-base-content"
              )
            ]}
          >
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
            <span>{item.label}</span>
          </.link>
        <% end %>
      </nav>
    </div>
    """
  end
end
