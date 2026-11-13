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

defmodule EdgehogWeb.SystemModelsLive.SystemModelFormComponent do
  @moduledoc """
  Floating right-side pill `Phoenix.LiveComponent` for creating and editing an
  `Edgehog.Devices.SystemModel`.

  Composes `PictureInputComponent` and `PartNumbersInputComponent` to manage
  product identity, hardware type assignment, localized descriptions, picture
  previews, and dynamic part numbers with live stealing warnings.
  """
  use EdgehogWeb, :live_component

  alias Edgehog.Devices.SystemModel
  alias EdgehogWeb.SystemModelsLive.PartNumbersInputComponent
  alias EdgehogWeb.SystemModelsLive.PictureInputComponent

  @impl Phoenix.LiveComponent
  def mount(socket) do
    {:ok,
     allow_upload(socket, :picture,
       accept: ~w(.jpg .jpeg .gif .png .svg),
       max_entries: 1,
       max_file_size: 5_000_000,
       auto_upload: true
     )}
  end

  @impl Phoenix.LiveComponent
  def update(%{system_model: model, tenant: tenant, action: action} = assigns, socket) do
    model = ensure_model_loaded(model, action, tenant)
    current_model_id = if action == :edit, do: model.id, else: nil
    hardware_types = PictureInputComponent.load_hardware_types(tenant)
    pn_context = PartNumbersInputComponent.load_part_number_context(current_model_id, tenant)

    initial_rows =
      PartNumbersInputComponent.initial_part_number_rows(
        model,
        action,
        assigns[:initial_part_number]
      )

    initial_desc = PictureInputComponent.initial_description(model, action, tenant)

    initial_hw_id =
      case {action, hardware_types} do
        {:edit, _} -> model.hardware_type_id
        {:new, [first | _]} -> first.id
        _ -> nil
      end

    ash_form = build_ash_form(model, action, tenant)

    socket =
      socket
      |> assign(assigns)
      |> assign(:system_model, model)
      |> assign(:hardware_types, hardware_types)
      |> assign(:selected_hardware_type_id, initial_hw_id)
      |> assign(:description_text, initial_desc)
      |> assign(:picture_url_text, model.picture_url || "")
      |> assign(:part_number_rows, initial_rows)
      |> assign(:pn_context, pn_context)
      |> assign(:part_numbers_error, nil)
      |> assign(:handle_touched?, action == :edit)
      |> assign(:ash_form, ash_form)
      |> assign(:form, to_form(ash_form))
      |> recompute_part_number_analysis()

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def handle_event("validate", %{"system_model" => sm_params} = full_params, socket) do
    {sm_params, handle_touched?} =
      maybe_auto_slug_handle(sm_params, full_params, socket.assigns)

    part_number_rows = Map.get(sm_params, "part_numbers", socket.assigns.part_number_rows)
    description_text = Map.get(sm_params, "description", socket.assigns.description_text)
    picture_url_text = Map.get(sm_params, "picture_url", socket.assigns.picture_url_text)

    selected_hw_id =
      case Map.fetch(sm_params, "hardware_type_id") do
        {:ok, raw} -> PictureInputComponent.parse_optional_id(raw)
        :error -> socket.assigns.selected_hardware_type_id
      end

    validate_params =
      PictureInputComponent.build_ash_params(
        sm_params,
        selected_hw_id,
        part_number_rows,
        description_text,
        picture_url_text,
        nil,
        socket.assigns
      )

    ash_form = AshPhoenix.Form.validate(socket.assigns.ash_form, validate_params, errors: false)

    {:noreply,
     socket
     |> assign(:handle_touched?, handle_touched?)
     |> assign(:selected_hardware_type_id, selected_hw_id)
     |> assign(:description_text, description_text)
     |> assign(:picture_url_text, picture_url_text)
     |> assign(:part_number_rows, part_number_rows)
     |> assign(:part_numbers_error, nil)
     |> assign(:ash_form, ash_form)
     |> assign(:form, to_form(ash_form))
     |> recompute_part_number_analysis()}
  end

  def handle_event("add_part_number", _params, socket) do
    rows = socket.assigns.part_number_rows ++ [""]

    {:noreply,
     socket
     |> assign(:part_number_rows, rows)
     |> assign(:part_numbers_error, nil)
     |> recompute_part_number_analysis()}
  end

  def handle_event("remove_part_number", %{"index" => raw_index}, socket) do
    rows = socket.assigns.part_number_rows

    updated_rows =
      case raw_index |> to_string() |> Integer.parse() do
        {idx, ""} when length(rows) > 1 -> List.delete_at(rows, idx)
        _ -> rows
      end

    {:noreply,
     socket
     |> assign(:part_number_rows, updated_rows)
     |> assign(:part_numbers_error, nil)
     |> recompute_part_number_analysis()}
  end

  def handle_event("clear_picture", _params, socket) do
    socket =
      Enum.reduce(socket.assigns.uploads.picture.entries, socket, fn entry, acc ->
        cancel_upload(acc, :picture, entry.ref)
      end)

    {:noreply, assign(socket, :picture_url_text, "")}
  end

  def handle_event("save", %{"system_model" => sm_params}, socket) do
    part_number_rows = Map.get(sm_params, "part_numbers", socket.assigns.part_number_rows)
    cleaned_pns = PartNumbersInputComponent.clean_part_numbers(part_number_rows)
    description_text = Map.get(sm_params, "description", socket.assigns.description_text)
    picture_url_text = Map.get(sm_params, "picture_url", socket.assigns.picture_url_text)

    selected_hw_id =
      case Map.fetch(sm_params, "hardware_type_id") do
        {:ok, raw} -> PictureInputComponent.parse_optional_id(raw)
        :error -> socket.assigns.selected_hardware_type_id
      end

    if cleaned_pns == [] do
      {:noreply,
       socket
       |> assign(:part_number_rows, part_number_rows)
       |> assign(:part_numbers_error, gettext("At least one part number is required."))
       |> recompute_part_number_analysis()}
    else
      {upload_struct, temp_paths} = consume_picture_upload(socket)

      submit_params =
        PictureInputComponent.build_ash_params(
          sm_params,
          selected_hw_id,
          cleaned_pns,
          description_text,
          picture_url_text,
          upload_struct,
          socket.assigns
        )

      result = AshPhoenix.Form.submit(socket.assigns.ash_form, params: submit_params)
      Enum.each(temp_paths, &File.rm/1)

      case result do
        {:ok, saved_model} ->
          {:noreply, navigate_after_save(socket, saved_model, socket.assigns.tenant)}

        {:error, %AshPhoenix.Form{} = ash_form} ->
          {:noreply,
           socket
           |> assign(:part_number_rows, part_number_rows)
           |> assign(:description_text, description_text)
           |> assign(:picture_url_text, picture_url_text)
           |> assign(:ash_form, ash_form)
           |> assign(:form, to_form(ash_form))
           |> recompute_part_number_analysis()}
      end
    end
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div
      id={@id}
      role="dialog"
      aria-modal="false"
      aria-labelledby={"#{@id}-title"}
      class="fixed inset-y-0 right-4 z-40 pointer-events-none flex items-center pl-4"
    >
      <.floating_pill_drawer
        id={@id}
        icon="hero-device-tablet"
        title={
          if(@action == :new,
            do: gettext("Create System Model"),
            else: gettext("Edit System Model")
          )
        }
        subtitle={gettext("Configure product identity, hardware platform, and part numbers.")}
        close_patch={@return_to}
        close_id="close-system-model-drawer-btn"
      >
        <.form
          for={@form}
          id="system-model-form"
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save"
          class="flex-1 overflow-y-auto px-6 py-4 space-y-4"
        >
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <.input
              field={@form[:name]}
              type="text"
              label={gettext("Model Name")}
              placeholder="Connected E-Scooter 1"
              required
            />

            <.input
              field={@form[:handle]}
              type="text"
              label={gettext("Handle")}
              placeholder="e-scooter-1"
              required
            />
          </div>

          <PictureInputComponent.hardware_type_field
            action={@action}
            hardware_types={@hardware_types}
            selected_hardware_type_id={@selected_hardware_type_id}
            system_model={@system_model}
          />

          <PictureInputComponent.description_field
            description_text={@description_text}
            default_locale={@tenant.default_locale}
          />

          <PictureInputComponent.picture_input
            picture_url_text={@picture_url_text}
            picture_upload={@uploads.picture}
            myself={@myself}
          />

          <PartNumbersInputComponent.part_numbers_input
            rows={@pn_analysis.rows}
            part_numbers_error={@part_numbers_error}
            myself={@myself}
          />

          <PartNumbersInputComponent.steal_warning stolen_entries={@pn_analysis.stolen_entries} />

          <PartNumbersInputComponent.live_preview preview_reach={@pn_analysis.preview_reach} />

          <.drawer_footer
            cancel_patch={@return_to}
            cancel_id="cancel-system-model-form-btn"
            submit_id="submit-system-model-form-btn"
            submit_label={
              if(@action == :new,
                do: gettext("Create System Model"),
                else: gettext("Save Changes")
              )
            }
            submit_disabled={@action == :new and @hardware_types == []}
          />
        </.form>
      </.floating_pill_drawer>
    </div>
    """
  end

  defp recompute_part_number_analysis(socket) do
    analysis =
      PartNumbersInputComponent.analyze_part_numbers(
        socket.assigns.part_number_rows,
        socket.assigns.pn_context
      )

    assign(socket, :pn_analysis, analysis)
  end

  defp consume_picture_upload(socket) do
    case consume_uploaded_entries(socket, :picture, &PictureInputComponent.copy_upload_entry/2) do
      [{upload, dest} | _] -> {upload, [dest]}
      _ -> {nil, []}
    end
  end

  defp build_ash_form(model, :new, tenant) do
    SystemModel
    |> AshPhoenix.Form.for_create(:create,
      as: "system_model",
      tenant: tenant,
      authorize?: false,
      forms: [auto?: false]
    )
    |> Map.put(:data, model)
  end

  defp build_ash_form(model, :edit, tenant) do
    AshPhoenix.Form.for_update(model, :update,
      as: "system_model",
      tenant: tenant,
      authorize?: false,
      forms: [auto?: false]
    )
  end

  defp ensure_model_loaded(model, :edit, tenant) do
    Ash.load!(model, [:hardware_type, :part_numbers, :localized_descriptions],
      tenant: tenant,
      authorize?: false
    )
  end

  defp ensure_model_loaded(model, _action, _tenant), do: model

  defp maybe_auto_slug_handle(sm_params, full_params, assigns) do
    target = Map.get(full_params, "_target", [])
    handle_touched? = assigns.handle_touched? or target == ["system_model", "handle"]

    if assigns.action == :new and not handle_touched? do
      slug = slugify_name(sm_params["name"] || "")
      {Map.put(sm_params, "handle", slug), false}
    else
      {sm_params, handle_touched?}
    end
  end

  defp slugify_name(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
    |> String.replace(~r/^[^a-z]+/, "")
  end

  defp navigate_after_save(%{assigns: %{action: :new}} = socket, saved_model, tenant) do
    socket
    |> put_flash(:info, gettext("System model created."))
    |> push_navigate(to: ~p"/tenants/#{tenant.slug}/system-models/#{saved_model.id}")
  end

  defp navigate_after_save(socket, _saved_model, _tenant) do
    socket
    |> put_flash(:info, gettext("System model updated."))
    |> push_patch(to: socket.assigns.return_to)
  end
end
