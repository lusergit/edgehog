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
  alias EdgehogWeb.SystemModelsLive.ModelFleetComponent
  alias EdgehogWeb.SystemModelsLive.StatsComponent
  alias EdgehogWeb.SystemModelsLive.SystemModelCardComponent
  alias EdgehogWeb.SystemModelsLive.SystemModelFormComponent
  alias EdgehogWeb.SystemModelsLive.ToolbarComponent
  alias EdgehogWeb.SystemModelsLive.UnmappedPartNumbersComponent

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
     |> recompute_filtered_models()}
  end

  def handle_event("filter", %{"filter" => filter}, socket) when filter in @valid_filters do
    {:noreply,
     socket
     |> assign(:filter, filter)
     |> recompute_filtered_models()}
  end

  def handle_event("filter_hardware_type", %{"hardware_type_id" => raw_id}, socket) do
    {:noreply,
     socket
     |> assign(:hardware_type_id, parse_optional_id(raw_id))
     |> recompute_filtered_models()}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:search, "")
     |> assign(:filter, "all")
     |> assign(:hardware_type_id, nil)
     |> recompute_filtered_models()}
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
          :for={entry <- @filtered_models}
          module={SystemModelCardComponent}
          id={"system-model-card-#{entry.model.id}"}
          model={entry.model}
          reach={entry.reach}
          tenant={@current_tenant}
        />
      </section>

      <ToolbarComponent.system_models_empty_state
        :if={@filtered_models == []}
        has_models?={@model_entries != []}
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

    models =
      SystemModel
      |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
      |> Ash.Query.load([:hardware_type, :part_numbers, :localized_descriptions])
      |> Ash.Query.sort(name: :asc)
      |> Ash.read!(tenant: tenant, authorize?: false)

    hardware_types =
      HardwareType
      |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
      |> Ash.Query.sort(name: :asc)
      |> Ash.read!(tenant: tenant, authorize?: false)

    %{by_part_number: by_part_number} = ModelFleetComponent.load_devices_by_part_number(tenant)

    model_entries =
      Enum.map(models, fn model ->
        reach = ModelFleetComponent.compute_model_reach(model, by_part_number)
        part_numbers = ModelFleetComponent.extract_part_number_strings(model)

        %{
          model: model,
          reach: reach,
          part_numbers: part_numbers,
          has_picture?: has_picture?(model.picture_url)
        }
      end)

    filter_counts = %{
      all: length(model_entries),
      active_fleet: Enum.count(model_entries, &(&1.reach.total > 0)),
      empty_fleet: Enum.count(model_entries, &(&1.reach.total == 0)),
      no_picture: Enum.count(model_entries, &(not &1.has_picture?))
    }

    socket
    |> assign(:model_entries, model_entries)
    |> assign(:hardware_types, hardware_types)
    |> assign(:filter_counts, filter_counts)
    |> recompute_filtered_models()
  end

  defp recompute_filtered_models(socket) do
    search = String.downcase(socket.assigns.search || "")
    filter = socket.assigns.filter || "all"
    hardware_type_id = socket.assigns.hardware_type_id

    filtered =
      Enum.filter(socket.assigns.model_entries, fn entry ->
        matches_filter?(entry, filter) and
          matches_hardware_type?(entry, hardware_type_id) and
          matches_search?(entry, search)
      end)

    assign(socket, :filtered_models, filtered)
  end

  defp matches_filter?(_entry, "all"), do: true
  defp matches_filter?(entry, "active_fleet"), do: entry.reach.total > 0
  defp matches_filter?(entry, "empty_fleet"), do: entry.reach.total == 0
  defp matches_filter?(entry, "no_picture"), do: not entry.has_picture?
  defp matches_filter?(_entry, _other), do: true

  defp matches_hardware_type?(_entry, nil), do: true

  defp matches_hardware_type?(%{model: model}, hardware_type_id) do
    model.hardware_type_id == hardware_type_id
  end

  defp matches_search?(_entry, ""), do: true

  defp matches_search?(%{model: model, part_numbers: part_numbers}, query) do
    model_match? =
      contains_query?(model.name, query) or contains_query?(model.handle, query)

    hardware_type_match? =
      case model.hardware_type do
        %{name: ht_name, handle: ht_handle} ->
          contains_query?(ht_name, query) or contains_query?(ht_handle, query)

        _ ->
          false
      end

    part_number_match? =
      Enum.any?(part_numbers, &contains_query?(&1, query))

    model_match? or hardware_type_match? or part_number_match?
  end

  defp contains_query?(text, query) when is_binary(text) do
    text
    |> String.downcase()
    |> String.contains?(query)
  end

  defp contains_query?(_text, _query), do: false

  defp has_picture?(url) when is_binary(url), do: String.trim(url) != ""
  defp has_picture?(_url), do: false

  defp parse_optional_id(nil), do: nil
  defp parse_optional_id(""), do: nil

  defp parse_optional_id(raw) do
    case raw |> to_string() |> Integer.parse() do
      {id, ""} -> id
      _ -> nil
    end
  end
end
