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

defmodule EdgehogWeb.SystemModelsLive.PictureInputComponent do
  @moduledoc """
  Stateless function components and parameter-building helpers for the hardware
  type selector, localized description textarea, and product picture URL/upload
  well inside `SystemModelFormComponent`.
  """
  use EdgehogWeb, :html

  alias Edgehog.Devices.HardwareType
  alias EdgehogWeb.SystemModelsLive.ModelFleetComponent
  alias EdgehogWeb.SystemModelsLive.PartNumbersInputComponent

  attr :action, :atom, required: true
  attr :hardware_types, :list, required: true
  attr :selected_hardware_type_id, :any, default: nil
  attr :system_model, :map, required: true

  def hardware_type_field(assigns) do
    ~H"""
    <div>
      <div :if={@action == :new} class="space-y-1.5">
        <label
          for="system-model-hardware-type-select"
          class="text-xs font-semibold uppercase tracking-wider text-base-content/70"
        >
          {gettext("Hardware Type")} <span class="text-error">*</span>
        </label>
        <select
          :if={@hardware_types != []}
          id="system-model-hardware-type-select"
          name="system_model[hardware_type_id]"
          class="select select-sm w-full bg-base-100"
          required
        >
          <option
            :for={ht <- @hardware_types}
            value={ht.id}
            selected={@selected_hardware_type_id == ht.id}
          >
            {ht.name} (@{ht.handle})
          </option>
        </select>
        <div
          :if={@hardware_types == []}
          id="no-hardware-types-warning"
          class="alert alert-warning text-xs py-2 px-3"
        >
          <.icon name="hero-exclamation-triangle" class="size-4 shrink-0" />
          <span>
            {gettext("No hardware types exist yet. Create a hardware type first.")}
          </span>
        </div>
      </div>

      <div :if={@action == :edit and @system_model.hardware_type} class="space-y-1">
        <span class="text-xs font-semibold uppercase tracking-wider text-base-content/60">
          {gettext("Hardware Type")}
        </span>
        <div
          id="system-model-hardware-type-readonly"
          class="flex items-center justify-between rounded-2xl border border-base-300/80 bg-base-200/30 px-3 py-2 text-xs"
        >
          <span class="flex items-center gap-1.5 font-medium text-base-content">
            <.icon name="hero-cpu-chip" class="size-4 text-info" />
            <span>{@system_model.hardware_type.name}</span>
            <span class="font-mono text-base-content/55">
              (@{@system_model.hardware_type.handle})
            </span>
          </span>
          <span class="badge badge-ghost badge-xs">{gettext("Immutable")}</span>
        </div>
      </div>
    </div>
    """
  end

  attr :description_text, :string, required: true
  attr :default_locale, :string, required: true

  def description_field(assigns) do
    ~H"""
    <div class="space-y-1.5">
      <div class="flex items-center justify-between">
        <label
          for="system-model-description-input"
          class="text-xs font-semibold uppercase tracking-wider text-base-content/70"
        >
          {gettext("Localized Description")}
        </label>
        <span class="badge badge-ghost badge-xs font-mono">{@default_locale}</span>
      </div>
      <textarea
        id="system-model-description-input"
        name="system_model[description]"
        rows="2"
        placeholder="Short product summary shown on catalog cards and the detail view..."
        phx-debounce="150"
        class="textarea textarea-sm w-full bg-base-100 text-xs"
      >{@description_text}</textarea>
    </div>
    """
  end

  attr :picture_url_text, :string, required: true
  attr :picture_upload, :any, required: true
  attr :myself, :any, required: true

  def picture_input(assigns) do
    ~H"""
    <div class="rounded-2xl border border-base-300/80 bg-base-200/30 p-3 space-y-2.5">
      <div class="flex items-center justify-between gap-2">
        <label
          for="system-model-picture-url-input"
          class="text-xs font-semibold uppercase tracking-wider text-base-content/70"
        >
          {gettext("Product Picture")}
        </label>
        <button
          :if={String.trim(@picture_url_text) != "" or @picture_upload.entries != []}
          id="clear-picture-btn"
          type="button"
          phx-click="clear_picture"
          phx-target={@myself}
          class="btn btn-ghost btn-xs rounded-full text-error"
        >
          {gettext("Clear picture")}
        </button>
      </div>

      <div class="flex items-center gap-3">
        <div
          id="system-model-picture-preview"
          class="flex size-14 shrink-0 items-center justify-center overflow-hidden rounded-2xl border border-base-300 bg-base-100"
        >
          <%= cond do %>
            <% @picture_upload.entries != [] -> %>
              <.live_img_preview
                entry={List.first(@picture_upload.entries)}
                class="size-14 object-cover"
              />
            <% String.trim(@picture_url_text) != "" -> %>
              <img
                src={String.trim(@picture_url_text)}
                alt="Preview"
                data-role="picture-url-preview"
                class="size-14 object-cover"
              />
            <% true -> %>
              <.icon name="hero-photo" class="size-6 text-base-content/40" />
          <% end %>
        </div>

        <div class="flex-1 space-y-1.5 min-w-0">
          <input
            type="text"
            id="system-model-picture-url-input"
            name="system_model[picture_url]"
            value={@picture_url_text}
            placeholder="https://example.com/product.png"
            phx-debounce="150"
            class="input input-sm w-full bg-base-100 text-xs"
          />
          <div class="flex items-center gap-2 text-[11px] text-base-content/55">
            <.live_file_input
              upload={@picture_upload}
              class="file-input file-input-xs max-w-52"
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Returns the initial description text for `model` on `:edit`, or `""` on `:new`.
  """
  def initial_description(model, :edit, tenant) do
    case ModelFleetComponent.localized_description(model, tenant) do
      {_locale, text} -> text
      nil -> ""
    end
  end

  def initial_description(_model, _action, _tenant), do: ""

  @doc """
  Injects `"picture_file"` or `"picture_url"` into `params` for Ash validation
  and submission.
  """
  def put_picture_param(params, _picture_url_text, %Plug.Upload{} = upload_struct),
    do: Map.put(params, "picture_file", upload_struct)

  def put_picture_param(params, picture_url_text, nil) do
    case String.trim(picture_url_text || "") do
      "" -> Map.put(params, "picture_url", nil)
      url -> Map.put(params, "picture_url", url)
    end
  end

  @doc """
  Injects `"localized_descriptions"` into `params` for `UpsertLocalizedAttribute`,
  omitting empty descriptions on `:new` and passing `value: nil` when cleared on
  `:edit`.
  """
  def put_localized_descriptions_param(params, action, description_text, tenant) do
    locale = tenant.default_locale || "en-US"
    trimmed_desc = String.trim(description_text || "")

    case {action, trimmed_desc} do
      {:new, ""} ->
        params

      {:new, desc} ->
        Map.put(params, "localized_descriptions", [%{language_tag: locale, value: desc}])

      {:edit, ""} ->
        Map.put(params, "localized_descriptions", [%{language_tag: locale, value: nil}])

      {:edit, desc} ->
        Map.put(params, "localized_descriptions", [%{language_tag: locale, value: desc}])
    end
  end

  @doc """
  Loads all tenant `HardwareType`s sorted alphabetically by name.
  """
  def load_hardware_types(tenant) do
    HardwareType
    |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
    |> Ash.Query.sort(name: :asc)
    |> Ash.read!(tenant: tenant, authorize?: false)
  end

  @doc """
  Builds the Ash parameter map for `SystemModel` `:create` or `:update`.
  """
  def build_ash_params(
        sm_params,
        selected_hw_id,
        part_number_rows,
        description_text,
        picture_url_text,
        upload_struct,
        assigns
      ) do
    %{
      "name" => Map.get(sm_params, "name", ""),
      "handle" => Map.get(sm_params, "handle", ""),
      "part_numbers" => PartNumbersInputComponent.clean_part_numbers(part_number_rows)
    }
    |> maybe_put_hardware_type_id(assigns.action, selected_hw_id)
    |> put_picture_param(picture_url_text, upload_struct)
    |> put_localized_descriptions_param(assigns.action, description_text, assigns.tenant)
  end

  @doc """
  Copies a LiveView uploaded file entry to a temporary path and wraps it in a
  `%Plug.Upload{}` struct.
  """
  def copy_upload_entry(%{path: path}, entry) do
    dest =
      Path.join(
        System.tmp_dir!(),
        "edgehog-sm-#{System.unique_integer([:positive])}-#{entry.client_name}"
      )

    File.cp!(path, dest)

    upload = %Plug.Upload{
      path: dest,
      content_type: entry.client_type,
      filename: entry.client_name
    }

    {:ok, {upload, dest}}
  end

  @doc """
  Parses an optional integer ID from form params.
  """
  def parse_optional_id(nil), do: nil
  def parse_optional_id(""), do: nil

  def parse_optional_id(raw) do
    case raw |> to_string() |> Integer.parse() do
      {id, ""} -> id
      _ -> nil
    end
  end

  defp maybe_put_hardware_type_id(params, :new, selected_hw_id),
    do: Map.put(params, "hardware_type_id", selected_hw_id)

  defp maybe_put_hardware_type_id(params, _action, _selected_hw_id), do: params
end
