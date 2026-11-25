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

defmodule EdgehogWeb.SystemModelsLive.SystemModelCardComponent do
  @moduledoc """
  Reactive Product Catalog Bento Card `LiveComponent` (`#system-model-card-<id>`)
  subscribing to `"system_models:<id>"` and composing a 64×64 product thumbnail,
  hardware type badge, localized description snippet, `PartNumbersStripComponent`,
  and `ModelFleetComponent`.
  """
  use EdgehogWeb, :live_component

  alias EdgehogWeb.SystemModelsLive.ModelFleetComponent
  alias EdgehogWeb.SystemModelsLive.PartNumbersStripComponent

  @impl Phoenix.LiveComponent
  def update(%{model: model, scope: scope} = assigns, socket) do
    model = ensure_loaded(model, scope)
    part_numbers = ModelFleetComponent.extract_part_number_strings(model)
    counts_by_part_number = ModelFleetComponent.counts_by_part_number(model.part_numbers)

    socket =
      socket
      |> assign(assigns)
      |> assign(:model, model)
      |> assign(:part_numbers, part_numbers)
      |> assign(:counts_by_part_number, counts_by_part_number)
      |> assign(:description, model.default_description)
      |> ensure_subscribed(model.id)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <article
      id={@id}
      data-model-handle={@model.handle}
      class="card card-border bg-base-100 p-5 shadow-xs flex flex-col justify-between gap-4 transition-colors hover:border-base-300"
    >
      <div class="flex flex-col gap-4">
        <div class="flex items-start justify-between gap-3">
          <div class="flex items-start gap-3.5 min-w-0">
            <.link
              navigate={~p"/tenants/#{@scope.current_tenant.slug}/system-models/#{@model.id}"}
              class="shrink-0"
              tabindex="-1"
              aria-hidden="true"
            >
              <img
                :if={@model.has_picture}
                src={@model.picture_url}
                alt={@model.name}
                data-role="model-picture"
                class="size-16 rounded-2xl border border-base-300 bg-base-200/40 object-cover"
              />
              <div
                :if={not @model.has_picture}
                data-role="model-picture-placeholder"
                class="flex size-16 items-center justify-center rounded-2xl border border-base-300/80 bg-base-200/50 text-primary/70"
              >
                <.icon name="hero-device-tablet" class="size-8" />
              </div>
            </.link>

            <div class="min-w-0">
              <.link
                navigate={~p"/tenants/#{@scope.current_tenant.slug}/system-models/#{@model.id}"}
                data-role="model-name"
                class="font-semibold text-base text-base-content leading-tight truncate hover:text-primary transition-colors block"
              >
                {@model.name}
              </.link>
              <p
                data-role="model-handle"
                class="mt-0.5 font-mono text-xs text-base-content/55 truncate"
              >
                @{@model.handle}
              </p>

              <div :if={@model.hardware_type} class="mt-2 flex flex-wrap items-center gap-1.5">
                <span
                  data-role="model-hardware-type"
                  data-hardware-type-handle={@model.hardware_type.handle}
                  class="inline-flex items-center gap-1 rounded-md border border-base-300 bg-base-200/45 px-2 py-0.5 text-[11px] font-medium text-base-content/80"
                >
                  <.icon name="hero-cpu-chip" class="size-3 text-info shrink-0" />
                  <span class="truncate max-w-44">{@model.hardware_type.name}</span>
                </span>
              </div>
            </div>
          </div>

          {render_status_badge(assigns)}
        </div>

        <div
          :if={@description}
          data-role="model-description"
          class="rounded-2xl border border-base-300/70 bg-base-200/25 px-3 py-2 text-xs text-base-content/75 flex items-start justify-between gap-2"
        >
          <p class="line-clamp-2 leading-relaxed">{@description.value}</p>
          <span
            data-role="model-description-locale"
            class="shrink-0 rounded bg-base-300/60 px-1.5 py-0.5 font-mono text-[10px] text-base-content/65"
          >
            {@description.language_tag}
          </span>
        </div>

        <p
          :if={is_nil(@description)}
          data-role="model-no-description"
          class="text-xs italic text-base-content/60"
        >
          {gettext("No product description provided.")}
        </p>

        <PartNumbersStripComponent.part_numbers_strip
          part_numbers={@part_numbers}
          counts_by_part_number={@counts_by_part_number}
          max_visible={3}
        />
      </div>

      <ModelFleetComponent.fleet_reach
        total={@model.device_count}
        online={@model.online_device_count}
      />
    </article>
    """
  end

  defp render_status_badge(assigns) do
    cond do
      assigns.model.device_count == 0 ->
        ~H"""
        <span
          data-role="model-status-badge"
          class="badge badge-soft badge-neutral border-base-300 bg-base-200/70 text-base-content/75 badge-sm gap-1 font-medium shrink-0"
        >
          {gettext("No Devices")}
        </span>
        """

      assigns.model.online_device_count > 0 ->
        ~H"""
        <span
          data-role="model-status-badge"
          class="badge badge-soft badge-success badge-sm gap-1 font-medium shrink-0"
        >
          <span class="size-1.5 rounded-full bg-success animate-pulse" /> {gettext("Active Fleet")}
        </span>
        """

      true ->
        ~H"""
        <span
          data-role="model-status-badge"
          class="badge badge-soft badge-error badge-sm gap-1 font-medium shrink-0"
        >
          {gettext("Offline")}
        </span>
        """
    end
  end

  defp ensure_loaded(
         %{
           hardware_type: %Edgehog.Devices.HardwareType{},
           part_numbers: part_numbers,
           device_count: total,
           online_device_count: online,
           has_picture: has_picture?,
           default_description: desc
         } = model,
         _scope
       )
       when is_list(part_numbers) and is_integer(total) and is_integer(online) and
              is_boolean(has_picture?) and not is_struct(desc, Ash.NotLoaded) do
    model
  end

  defp ensure_loaded(model, scope) do
    Ash.load!(
      model,
      [
        :hardware_type,
        :device_count,
        :online_device_count,
        :has_picture,
        :default_description,
        part_numbers: [:device_count, :online_device_count]
      ],
      scope: scope,
      reuse_values?: false
    )
  end

  defp ensure_subscribed(socket, model_id) do
    if connected?(socket) and not Map.get(socket.assigns, :subscribed?, false) do
      EdgehogWeb.Endpoint.subscribe("system_models:#{model_id}")
      assign(socket, :subscribed?, true)
    else
      socket
    end
  end
end
