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

defmodule EdgehogWeb.SystemModelsLive.Show do
  @moduledoc """
  LiveView for inspecting a single `Edgehog.Devices.SystemModel`, its product
  picture and localized description, registered part numbers and per-part-number
  device distribution, fleet availability, software compatibility links, and
  live Cinder table of matching devices.
  """
  use EdgehogWeb, :live_view

  alias Edgehog.BaseImages.BaseImageCollection
  alias Edgehog.Devices.SystemModel
  alias EdgehogWeb.SystemModelsLive.DeleteSystemModelModalComponent
  alias EdgehogWeb.SystemModelsLive.ModelFleetComponent
  alias EdgehogWeb.SystemModelsLive.ModelHeaderComponent
  alias EdgehogWeb.SystemModelsLive.PartNumbersStripComponent
  alias EdgehogWeb.SystemModelsLive.SystemModelFormComponent

  require Ash.Query

  @impl Phoenix.LiveView
  def mount(%{"id" => id}, _session, socket) do
    tenant = socket.assigns.current_tenant

    case fetch_system_model(id, tenant) do
      {:ok, model, collections} ->
        if connected?(socket) do
          EdgehogWeb.Endpoint.subscribe("system_models:#{model.id}")
          EdgehogWeb.Endpoint.subscribe("system_models:tenant:#{tenant.tenant_id}")
          EdgehogWeb.Endpoint.subscribe("devices:tenant:#{tenant.tenant_id}")
        end

        {:ok,
         socket
         |> assign(:show_delete_modal, false)
         |> apply_model_state(model, collections)}

      :error ->
        {:ok,
         socket
         |> assign(:system_model, nil)
         |> put_flash(:error, gettext("System model not found."))
         |> push_navigate(to: ~p"/tenants/#{tenant.slug}/system-models")}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _uri, %{assigns: %{system_model: nil}} = socket) do
    {:noreply, socket}
  end

  def handle_params(_params, _uri, socket) do
    tenant = socket.assigns.current_tenant
    model = socket.assigns.system_model

    page_title =
      case socket.assigns.live_action do
        :edit -> "Edit #{model.name} · System Models · #{tenant.name}"
        _ -> "#{model.name} · System Models · #{tenant.name}"
      end

    {:noreply, assign(socket, :page_title, page_title)}
  end

  @impl Phoenix.LiveView
  def handle_event("open_delete_modal", _params, socket) do
    {:noreply, assign(socket, :show_delete_modal, true)}
  end

  @impl Phoenix.LiveView
  def handle_info(:close_delete_system_model_modal, socket) do
    {:noreply, assign(socket, :show_delete_modal, false)}
  end

  def handle_info({:system_model_deleted, _model}, socket) do
    tenant = socket.assigns.current_tenant

    {:noreply,
     socket
     |> put_flash(:info, gettext("System model deleted."))
     |> push_navigate(to: ~p"/tenants/#{tenant.slug}/system-models")}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "system_models:" <> id,
          payload: %Ash.Notifier.Notification{action: %{type: :destroy}}
        },
        %{assigns: %{system_model: %SystemModel{id: current_id}}} = socket
      ) do
    if id == to_string(current_id) do
      tenant = socket.assigns.current_tenant
      {:noreply, push_navigate(socket, to: ~p"/tenants/#{tenant.slug}/system-models")}
    else
      refresh_model_state(socket)
    end
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "devices:" <> rest,
          payload: %Ash.Notifier.Notification{data: device}
        },
        socket
      ) do
    case forward_device_cell_broadcast(rest, device, socket) do
      :handled -> {:noreply, socket}
      :unhandled -> refresh_model_state(socket)
    end
  end

  def handle_info(%Phoenix.Socket.Broadcast{}, socket) do
    refresh_model_state(socket)
  end

  defp refresh_model_state(%{assigns: %{system_model: %SystemModel{} = model}} = socket) do
    tenant = socket.assigns.current_tenant

    case fetch_system_model(model.id, tenant) do
      {:ok, refreshed, collections} ->
        {:noreply,
         socket
         |> apply_model_state(refreshed, collections)
         |> Cinder.Refresh.refresh_table("system-model-devices-table")}

      :error ->
        {:noreply, push_navigate(socket, to: ~p"/tenants/#{tenant.slug}/system-models")}
    end
  end

  defp refresh_model_state(socket), do: {:noreply, socket}

  @impl Phoenix.LiveView
  def render(%{system_model: nil} = assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-6"></div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-6 space-y-6">
      <ModelHeaderComponent.model_header
        system_model={@system_model}
        description_entry={@description_entry}
        tenant={@current_tenant}
      />

      <section
        id="system-model-inspector-strip"
        aria-label="System model summary"
        class="grid grid-cols-1 md:grid-cols-3 gap-4"
      >
        <div class="card card-border bg-base-100 p-4 shadow-xs">
          <PartNumbersStripComponent.part_numbers_strip
            part_numbers={@part_numbers}
            counts_by_part_number={@reach.counts_by_part_number}
            max_visible={nil}
          />
        </div>

        <div class="card card-border bg-base-100 p-4 shadow-xs">
          <ModelFleetComponent.fleet_reach reach={@reach} />
        </div>

        <ModelHeaderComponent.compatibility_card
          base_image_collections={@base_image_collections}
          releases={@system_model.releases}
        />
      </section>

      <div class="space-y-3">
        <h2 class="text-base font-bold text-base-content">
          {gettext("Matched Devices")}
        </h2>

        <.devices_cinder_table
          id="system-model-devices-table"
          query={@devices_query}
          tenant={@current_tenant}
          show_hardware_columns
        />
      </div>

      <.live_component
        :if={@live_action == :edit}
        module={SystemModelFormComponent}
        id="edit-system-model-drawer"
        action={:edit}
        system_model={@system_model}
        tenant={@current_tenant}
        return_to={~p"/tenants/#{@current_tenant.slug}/system-models/#{@system_model.id}"}
      />

      <.live_component
        :if={@show_delete_modal}
        module={DeleteSystemModelModalComponent}
        id="delete-system-model-modal"
        system_model={@system_model}
        tenant={@current_tenant}
      />
    </div>
    """
  end

  defp apply_model_state(socket, model, collections) do
    tenant = socket.assigns.current_tenant
    part_numbers = ModelFleetComponent.extract_part_number_strings(model)
    reach = ModelFleetComponent.compute_model_reach(model, tenant)
    description_entry = ModelFleetComponent.localized_description(model, tenant)
    devices_query = ModelFleetComponent.model_devices_query(model, tenant)

    socket
    |> assign(:system_model, model)
    |> assign(:part_numbers, part_numbers)
    |> assign(:reach, reach)
    |> assign(:description_entry, description_entry)
    |> assign(:base_image_collections, collections)
    |> assign(:devices_query, devices_query)
    |> assign(:page_title, "#{model.name} · System Models · #{tenant.name}")
  end

  defp fetch_system_model(id, tenant) do
    with {int_id, ""} <- id |> to_string() |> Integer.parse(),
         {:ok, model} <- Ash.get(SystemModel, int_id, tenant: tenant, authorize?: false) do
      loaded =
        Ash.load!(
          model,
          [:hardware_type, :part_numbers, :localized_descriptions, :releases],
          tenant: tenant,
          authorize?: false,
          reuse_values?: false
        )

      collections =
        BaseImageCollection
        |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
        |> Ash.Query.filter(system_model_id == ^loaded.id)
        |> Ash.read!(tenant: tenant, authorize?: false)

      {:ok, loaded, collections}
    else
      _ -> :error
    end
  end
end
