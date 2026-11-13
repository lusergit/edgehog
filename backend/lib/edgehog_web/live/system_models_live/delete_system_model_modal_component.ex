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

  alias Edgehog.BaseImages.BaseImageCollection
  alias EdgehogWeb.SystemModelsLive.ModelFleetComponent

  require Ash.Query

  @impl Phoenix.LiveComponent
  def update(%{system_model: model, tenant: tenant} = assigns, socket) do
    model = ensure_part_numbers_loaded(model, tenant)
    part_numbers_count = length(ModelFleetComponent.extract_part_number_strings(model))
    reach = ModelFleetComponent.compute_model_reach(model, tenant)
    blocking_collections = load_blocking_collections(model.id, tenant)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:system_model, model)
     |> assign(:part_numbers_count, part_numbers_count)
     |> assign(:reach, reach)
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
    tenant = socket.assigns.tenant

    case Ash.destroy(model, tenant: tenant, authorize?: false) do
      :ok ->
        send(self(), {:system_model_deleted, model})
        {:noreply, socket}

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
          <strong class="font-mono font-semibold tabular-nums">{@reach.total}</strong>
          {if(@reach.total == 1, do: gettext("device"), else: gettext("devices"))}) {gettext(
            "will be removed from the catalog. Fleet devices will not be deleted."
          )}
        </:notice>
      </.confirm_modal>
    </div>
    """
  end

  defp load_blocking_collections(system_model_id, tenant) do
    BaseImageCollection
    |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
    |> Ash.Query.filter(system_model_id == ^system_model_id)
    |> Ash.read!(tenant: tenant, authorize?: false)
  end

  defp ensure_part_numbers_loaded(%{part_numbers: pns} = model, _tenant) when is_list(pns),
    do: model

  defp ensure_part_numbers_loaded(model, tenant) do
    Ash.load!(model, :part_numbers, tenant: tenant, authorize?: false, reuse_values?: false)
  end
end
