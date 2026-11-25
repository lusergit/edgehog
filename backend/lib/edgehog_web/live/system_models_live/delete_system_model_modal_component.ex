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

defmodule EdgehogWeb.SystemModelsLive.DeleteSystemModelModalComponent do
  @moduledoc """
  Guarded floating pill confirmation modal `Phoenix.LiveComponent` for deleting
  an `Edgehog.Devices.SystemModel`.

  Proactively checks for referencing `Edgehog.BaseImages.BaseImageCollection`s
  (which have `on_delete: :nothing`), disables deletion when blocked, and
  summarizes affected part numbers and fleet devices when deletion is allowed.
  """
  use EdgehogWeb, :live_component

  @impl Phoenix.LiveComponent
  def update(%{system_model: model, scope: scope} = assigns, socket) do
    model =
      Ash.load!(model, [:part_number_count, :device_count, :base_image_collection],
        scope: scope,
        reuse_values?: false
      )

    blocking_collections = List.wrap(model.base_image_collection)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:system_model, model)
     |> assign(:part_numbers_count, model.part_number_count)
     |> assign(:device_count, model.device_count)
     |> assign(:blocking_collections, blocking_collections)
     |> assign(:delete_error, nil)}
  end

  @impl Phoenix.LiveComponent
  def handle_event("cancel_delete", _params, socket) do
    send(self(), :close_delete_system_model_modal)
    {:noreply, socket}
  end

  def handle_event("confirm_delete", _params, socket) do
    model = socket.assigns.system_model
    scope = socket.assigns.scope

    case Ash.destroy(model, scope: scope) do
      :ok ->
        send(self(), {:system_model_deleted, model})
        {:noreply, socket}

      {:error, %Ash.Error.Forbidden{}} ->
        {:noreply,
         assign(
           socket,
           :delete_error,
           gettext("You are not authorized to delete this system model.")
         )}

      {:error, _error} ->
        {:noreply,
         assign(
           socket,
           :delete_error,
           gettext("Cannot delete a system model referenced by a base image collection.")
         )}
    end
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div
      id={@id}
      role="dialog"
      aria-modal="true"
      aria-labelledby={"#{@id}-title"}
      class="fixed inset-0 z-50 flex items-center justify-center p-4"
    >
      <.confirm_modal
        id={@id}
        title={gettext("Delete System Model")}
        entity_name={@system_model.name}
        entity_handle={@system_model.handle}
        target={@myself}
        cancel_id="cancel-delete-system-model-btn"
        confirm_id="confirm-delete-system-model-btn"
        confirm_label={gettext("Delete System Model")}
        confirm_disabled={@blocking_collections != []}
        error_id="delete-system-model-error"
        error={@delete_error}
      >
        <:blocker :if={@blocking_collections != []} id="delete-system-model-blocker">
          {gettext("This system model is referenced by base image collection")}
          <strong class="font-semibold">
            {Enum.map_join(@blocking_collections, ", ", &"#{&1.name} (@#{&1.handle})")}
          </strong>
          {gettext("and cannot be deleted until the collection is removed.")}
        </:blocker>

        <:notice
          :if={@blocking_collections == []}
          id="delete-system-model-impact-notice"
          icon="hero-qr-code"
        >
          <strong class="font-mono font-semibold tabular-nums">{@part_numbers_count}</strong>
          {if(@part_numbers_count == 1,
            do: gettext("part number"),
            else: gettext("part numbers")
          )} ({gettext("matching")}
          <strong class="font-mono font-semibold tabular-nums">{@device_count}</strong>
          {if(@device_count == 1, do: gettext("device"), else: gettext("devices"))}) {gettext(
            "will be removed from the catalog. Fleet devices will not be deleted."
          )}
        </:notice>
      </.confirm_modal>
    </div>
    """
  end
end
