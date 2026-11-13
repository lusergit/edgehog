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

defmodule EdgehogWeb.SystemModelsLive.Index do
  @moduledoc """
  LiveView for browsing, searching, and monitoring a tenant's system models
  catalog in real time using a Product Catalog Bento Grid.

  Composes `StatsComponent`, `ToolbarComponent`, a responsive grid of
  `SystemModelCardComponent`s, and `UnmappedPartNumbersComponent`.
  """
  use EdgehogWeb, :live_view

  alias Edgehog.Devices.HardwareType
  alias Edgehog.Devices.SystemModel
  alias EdgehogWeb.SystemModelsLive.StatsComponent
  alias EdgehogWeb.SystemModelsLive.SystemModelCardComponent
  alias EdgehogWeb.SystemModelsLive.SystemModelFormComponent
  alias EdgehogWeb.SystemModelsLive.ToolbarComponent
  alias EdgehogWeb.SystemModelsLive.UnmappedPartNumbersComponent

  require Ash.Query

  @valid_filters ~w(all active_fleet empty_fleet no_picture)

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_tenant

    if connected?(socket) do
      EdgehogWeb.Endpoint.subscribe("system_models:tenant:#{tenant.tenant_id}")
      EdgehogWeb.Endpoint.subscribe("devices:tenant:#{tenant.tenant_id}")
    end

    socket =
      socket
      |> assign(:page_title, "System Models · #{tenant.name}")
      |> assign(:search, "")
      |> assign(:filter, "all")
      |> assign(:hardware_type_id, nil)
      |> assign(:initial_part_number, nil)
      |> load_system_models()

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    tenant = socket.assigns.current_tenant

    page_title =
      case socket.assigns.live_action do
        :new -> "New System Model · #{tenant.name}"
        _ -> "System Models · #{tenant.name}"
      end

    {:noreply,
     socket
     |> assign(:page_title, page_title)
     |> assign(:initial_part_number, params["part_number"])}
  end

  @impl Phoenix.LiveView
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply,
     socket
     |> assign(:search, String.trim(search))
     |> load_filtered_models()}
  end

  def handle_event("filter", %{"filter" => filter}, socket) when filter in @valid_filters do
    {:noreply,
     socket
     |> assign(:filter, filter)
     |> load_filtered_models()}
  end

  def handle_event("filter_hardware_type", %{"hardware_type_id" => raw_id}, socket) do
    {:noreply,
     socket
     |> assign(:hardware_type_id, parse_optional_id(raw_id))
     |> load_filtered_models()}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:search, "")
     |> assign(:filter, "all")
     |> assign(:hardware_type_id, nil)
     |> load_filtered_models()}
  end

  @impl Phoenix.LiveView
  def handle_info(%Phoenix.Socket.Broadcast{topic: topic}, socket) when is_binary(topic) do
    tenant = socket.assigns.current_tenant
    send_update(StatsComponent, id: "system-models-stats", tenant: tenant)
    send_update(UnmappedPartNumbersComponent, id: "unmapped-part-numbers-tray", tenant: tenant)

    {:noreply, load_system_models(socket)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-6 space-y-6">
      <.page_header
        title={gettext("System Models")}
        live_title="Subscribed to live system model catalog and fleet telemetry updates"
      >
        <:subtitle>
          Product definitions mapping hardware platforms and part numbers to your connected fleet in <span class="font-medium text-base-content/80">{@current_tenant.name}</span>.
        </:subtitle>
        <:actions>
          <.link
            id="create-system-model-btn"
            patch={~p"/tenants/#{@current_tenant.slug}/system-models/new"}
            class="btn btn-primary btn-sm gap-1.5"
          >
            <.icon name="hero-plus" class="size-4" />
            <span>{gettext("Create System Model")}</span>
          </.link>
        </:actions>
      </.page_header>

      <.live_component module={StatsComponent} id="system-models-stats" tenant={@current_tenant} />

      <ToolbarComponent.system_models_toolbar
        search={@search}
        filter={@filter}
        hardware_type_id={@hardware_type_id}
        hardware_types={@hardware_types}
        filter_counts={@filter_counts}
      />

      <section
        :if={@filtered_models != []}
        id="system-models-grid"
        aria-label="System models catalog grid"
        class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4"
      >
        <.live_component
          :for={model <- @filtered_models}
          module={SystemModelCardComponent}
          id={"system-model-card-#{model.id}"}
          model={model}
          tenant={@current_tenant}
        />
      </section>

      <ToolbarComponent.system_models_empty_state
        :if={@filtered_models == []}
        has_models?={@filter_counts.all > 0}
      />

      <.live_component
        module={UnmappedPartNumbersComponent}
        id="unmapped-part-numbers-tray"
        tenant={@current_tenant}
      />

      <.live_component
        :if={@live_action == :new}
        module={SystemModelFormComponent}
        id="system-model-form-drawer"
        action={:new}
        system_model={%SystemModel{}}
        initial_part_number={@initial_part_number}
        tenant={@current_tenant}
        return_to={~p"/tenants/#{@current_tenant.slug}/system-models"}
      />
    </div>
    """
  end

  defp load_system_models(socket) do
    tenant = socket.assigns.current_tenant

    all_models =
      SystemModel
      |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
      |> Ash.Query.load([:device_count, :has_picture])
      |> Ash.read!(tenant: tenant, authorize?: false)

    hardware_types =
      HardwareType
      |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
      |> Ash.Query.sort(name: :asc)
      |> Ash.read!(tenant: tenant, authorize?: false)

    filter_counts = %{
      all: length(all_models),
      active_fleet: Enum.count(all_models, &(&1.device_count > 0)),
      empty_fleet: Enum.count(all_models, &(&1.device_count == 0)),
      no_picture: Enum.count(all_models, &(not &1.has_picture))
    }

    socket
    |> assign(:hardware_types, hardware_types)
    |> assign(:filter_counts, filter_counts)
    |> load_filtered_models()
  end

  defp load_filtered_models(socket) do
    tenant = socket.assigns.current_tenant
    search = socket.assigns.search || ""
    filter = socket.assigns.filter || "all"
    hardware_type_id = socket.assigns.hardware_type_id

    models =
      SystemModel
      |> Ash.Query.for_read(:list, %{search: search}, tenant: tenant, authorize?: false)
      |> apply_model_filter(filter)
      |> apply_hardware_type_filter(hardware_type_id)
      |> Ash.Query.load([
        :hardware_type,
        :device_count,
        :online_device_count,
        :has_picture,
        :default_description,
        part_numbers: [:device_count, :online_device_count]
      ])
      |> Ash.Query.sort(name: :asc)
      |> Ash.read!(tenant: tenant, authorize?: false)

    assign(socket, :filtered_models, models)
  end

  defp apply_model_filter(query, "active_fleet"), do: Ash.Query.filter(query, device_count > 0)
  defp apply_model_filter(query, "empty_fleet"), do: Ash.Query.filter(query, device_count == 0)
  defp apply_model_filter(query, "no_picture"), do: Ash.Query.filter(query, has_picture == false)
  defp apply_model_filter(query, _other), do: query

  defp apply_hardware_type_filter(query, nil), do: query

  defp apply_hardware_type_filter(query, hardware_type_id) do
    Ash.Query.filter(query, hardware_type_id == ^hardware_type_id)
  end

  defp parse_optional_id(nil), do: nil
  defp parse_optional_id(""), do: nil

  defp parse_optional_id(raw) do
    case raw |> to_string() |> Integer.parse() do
      {id, ""} -> id
      _ -> nil
    end
  end
end
