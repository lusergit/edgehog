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

defmodule EdgehogWeb.SystemModelsLive.ModelHeaderComponent do
  @moduledoc """
  Stateless function components rendering the Product Model Hero Header card
  (`model_header/1`) and Software Compatibility summary card
  (`compatibility_card/1`) on `SystemModelsLive.Show`.
  """
  use EdgehogWeb, :html

  attr :system_model, :map, required: true
  attr :description_entry, :any, default: nil
  attr :tenant, :map, required: true

  def model_header(assigns) do
    ~H"""
    <div class="flex flex-col gap-3">
      <div>
        <.link
          id="back-to-system-models-link"
          navigate={~p"/tenants/#{@tenant.slug}/system-models"}
          class="inline-flex items-center gap-1.5 text-xs font-medium text-base-content/60 hover:text-base-content transition-colors"
        >
          <.icon name="hero-arrow-left" class="size-3.5" />
          <span>{gettext("Back to System Models")}</span>
        </.link>
      </div>

      <div class="card card-border bg-base-100 p-5 shadow-xs space-y-4">
        <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
          <div class="flex items-start gap-4 min-w-0">
            <img
              :if={has_picture?(@system_model.picture_url)}
              id="system-model-detail-picture"
              src={@system_model.picture_url}
              alt={@system_model.name}
              class="size-20 rounded-2xl border border-base-300 bg-base-200/40 object-cover shrink-0"
            />
            <div
              :if={not has_picture?(@system_model.picture_url)}
              id="system-model-detail-picture-placeholder"
              class="flex size-20 shrink-0 items-center justify-center rounded-2xl border border-base-300/80 bg-base-200/50 text-primary/70"
            >
              <.icon name="hero-device-tablet" class="size-10" />
            </div>

            <div class="min-w-0 space-y-1.5">
              <div class="flex flex-wrap items-center gap-2.5">
                <h1
                  id="system-model-detail-name"
                  class="text-2xl font-bold tracking-tight text-base-content"
                >
                  {@system_model.name}
                </h1>
                <span
                  id="system-model-detail-handle"
                  class="badge badge-ghost border-base-300 font-mono text-xs text-base-content/70"
                >
                  @{@system_model.handle}
                </span>
                <.live_badge title="Subscribed to live system model and fleet telemetry updates" />
              </div>

              <div
                :if={@system_model.hardware_type}
                class="flex flex-wrap items-center gap-2 text-xs text-base-content/70"
              >
                <span class="text-base-content/60">{gettext("Hardware Platform:")}</span>
                <span
                  id="system-model-detail-hardware-type"
                  data-hardware-type-handle={@system_model.hardware_type.handle}
                  class="inline-flex items-center gap-1.5 rounded-lg border border-base-300 bg-base-200/50 px-2.5 py-0.5 font-medium text-base-content"
                >
                  <.icon name="hero-cpu-chip" class="size-3.5 text-info" />
                  <span>{@system_model.hardware_type.name}</span>
                  <span class="font-mono text-[11px] text-base-content/60">
                    (@{@system_model.hardware_type.handle})
                  </span>
                </span>
              </div>

              <p
                :if={@description_entry}
                id="system-model-detail-description"
                class="text-sm text-base-content/75 leading-relaxed pt-0.5"
              >
                {elem(@description_entry, 1)}
                <span
                  id="system-model-detail-description-locale"
                  class="ml-1.5 rounded bg-base-200 px-1.5 py-0.5 font-mono text-[10px] text-base-content/65"
                >
                  {elem(@description_entry, 0)}
                </span>
              </p>

              <p
                :if={is_nil(@description_entry)}
                id="system-model-detail-no-description"
                class="text-xs italic text-base-content/60 pt-0.5"
              >
                {gettext("No product description provided.")}
              </p>
            </div>
          </div>

          <div class="flex items-center gap-2 self-start">
            <.link
              id="edit-system-model-btn"
              patch={~p"/tenants/#{@tenant.slug}/system-models/#{@system_model.id}/edit"}
              class="btn btn-sm btn-outline border-base-300 bg-base-100 gap-1.5"
            >
              <.icon name="hero-pencil-square" class="size-4" />
              <span>{gettext("Edit System Model")}</span>
            </.link>

            <.button
              id="delete-system-model-btn"
              type="button"
              variant="error"
              class="btn-sm btn-soft gap-1.5"
              phx-click="open_delete_modal"
            >
              <.icon name="hero-trash" class="size-4" />
              <span>{gettext("Delete")}</span>
            </.button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :base_image_collections, :list, required: true
  attr :releases, :list, default: []

  def compatibility_card(assigns) do
    ~H"""
    <div id="system-model-compatibility-card" class="card card-border bg-base-100 p-4 shadow-xs">
      <div class="border-t border-base-200 pt-3.5 space-y-2.5">
        <div class="flex items-center justify-between gap-2">
          <span class="text-xs font-semibold uppercase tracking-wider text-base-content/60">
            {gettext("Software Compatibility")}
          </span>
          <.icon name="hero-circle-stack" class="size-4 text-primary" />
        </div>

        <div class="space-y-1.5 text-xs">
          <div class="flex items-center justify-between gap-2">
            <span class="text-base-content/60">{gettext("Base Image Collection")}</span>
            <span
              :if={@base_image_collections != []}
              data-role="linked-base-image-collection"
              class="font-medium text-base-content truncate"
            >
              {Enum.map_join(@base_image_collections, ", ", & &1.name)}
            </span>
            <span
              :if={@base_image_collections == []}
              data-role="no-base-image-collection"
              class="text-base-content/60 italic"
            >
              {gettext("None linked")}
            </span>
          </div>

          <div class="flex items-center justify-between gap-2">
            <span class="text-base-content/60">{gettext("Compatible App Releases")}</span>
            <span
              data-role="compatible-releases-count"
              class="font-mono font-semibold tabular-nums text-base-content"
            >
              {length(@releases || [])}
            </span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp has_picture?(url) when is_binary(url), do: String.trim(url) != ""
  defp has_picture?(_url), do: false
end
