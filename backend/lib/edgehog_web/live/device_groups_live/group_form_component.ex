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

defmodule EdgehogWeb.DeviceGroupsLive.GroupFormComponent do
  @moduledoc """
  Floating right-side pill `Phoenix.LiveComponent` for creating and editing an
  `Edgehog.Groups.DeviceGroup`.

  Provides auto-derived handle slugs on creation, an optional rollout channel
  selector dropdown (`Edgehog.Campaigns.Channel`), clickable tenant tag helper
  chips (`Edgehog.Labeling.Tag`), and a real-time selector preview that
  evaluates syntax and matched devices on every change without blurring or
  blocking the underlying page.
  """
  use EdgehogWeb, :live_component

  alias Edgehog.Campaigns.Channel
  alias Edgehog.Devices.Device
  alias Edgehog.Groups.DeviceGroup
  alias Edgehog.Labeling.Tag
  alias Edgehog.Selector
  alias EdgehogWeb.DeviceGroupsLive.GroupsStatsComponent

  require Ash.Query

  @impl Phoenix.LiveComponent
  def update(%{group: group, tenant: tenant, action: action} = assigns, socket) do
    channel_options = load_channel_options(tenant)
    available_tags = load_available_tags(tenant)
    ash_form = build_ash_form(group, action, tenant)
    selected_channel_id = if group.channel_id, do: to_string(group.channel_id), else: ""
    initial_selector = group.selector || ""

    socket =
      socket
      |> assign(assigns)
      |> assign(:channel_options, channel_options)
      |> assign(:available_tags, available_tags)
      |> assign(:selected_channel_id, selected_channel_id)
      |> assign(:channel_error, nil)
      |> assign(:handle_touched?, action == :edit)
      |> assign(:ash_form, ash_form)
      |> assign(:form, to_form(ash_form))
      |> assign(:preview, evaluate_selector_preview(initial_selector, tenant))

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def handle_event("validate", %{"group" => group_params} = full_params, socket) do
    {group_params, handle_touched?} =
      maybe_auto_slug_handle(group_params, full_params, socket.assigns)

    selected_channel_id =
      Map.get(group_params, "channel_id", socket.assigns.selected_channel_id)

    ash_form =
      AshPhoenix.Form.validate(
        socket.assigns.ash_form,
        Map.take(group_params, ["name", "handle", "selector"])
      )

    preview = evaluate_selector_preview(group_params["selector"] || "", socket.assigns.tenant)

    {:noreply,
     socket
     |> assign(:handle_touched?, handle_touched?)
     |> assign(:selected_channel_id, selected_channel_id)
     |> assign(:channel_error, nil)
     |> assign(:ash_form, ash_form)
     |> assign(:form, to_form(ash_form))
     |> assign(:preview, preview)}
  end

  def handle_event("append_tag", %{"tag" => tag}, socket) do
    current_params = socket.assigns.ash_form.params || %{}

    current_selector =
      Map.get(current_params, "selector") ||
        AshPhoenix.Form.value(socket.assigns.ash_form, :selector) ||
        ""

    trimmed = String.trim(current_selector)

    new_selector =
      if trimmed == "" do
        ~s("#{tag}" in tags)
      else
        ~s(#{trimmed} and "#{tag}" in tags)
      end

    updated_params =
      current_params
      |> Map.put_new("name", AshPhoenix.Form.value(socket.assigns.ash_form, :name) || "")
      |> Map.put_new("handle", AshPhoenix.Form.value(socket.assigns.ash_form, :handle) || "")
      |> Map.put("selector", new_selector)

    ash_form = AshPhoenix.Form.validate(socket.assigns.ash_form, updated_params)
    preview = evaluate_selector_preview(new_selector, socket.assigns.tenant)

    {:noreply,
     socket
     |> assign(:ash_form, ash_form)
     |> assign(:form, to_form(ash_form))
     |> assign(:preview, preview)}
  end

  def handle_event("save", %{"group" => group_params}, socket) do
    tenant = socket.assigns.tenant
    form_params = Map.take(group_params, ["name", "handle", "selector"])
    selected_channel_id = Map.get(group_params, "channel_id", socket.assigns.selected_channel_id)

    with {:ok, saved_group} <-
           AshPhoenix.Form.submit(socket.assigns.ash_form, params: form_params),
         {:ok, final_group} <- reconcile_channel(saved_group, selected_channel_id, tenant) do
      {:noreply, navigate_after_save(socket, final_group, tenant)}
    else
      {:error, %AshPhoenix.Form{} = ash_form} ->
        {:noreply,
         socket
         |> assign(:selected_channel_id, selected_channel_id)
         |> assign(:ash_form, ash_form)
         |> assign(:form, to_form(ash_form))}

      {:error, error} ->
        {:noreply,
         socket
         |> assign(:selected_channel_id, selected_channel_id)
         |> assign(:channel_error, Exception.message(error))}
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
      <aside
        id={"#{@id}-panel"}
        class="card card-border rounded-3xl bg-base-100/95 backdrop-blur pointer-events-auto animate-floating-pill-right flex h-auto max-h-[calc(100vh-8rem)] w-[calc(100vw-2rem)] sm:w-120 lg:w-136 flex-col overflow-hidden shadow-xl"
      >
        <div class="flex items-center justify-between border-b border-base-300/80 px-6 py-4">
          <div class="flex items-center gap-3">
            <div class="flex size-9 shrink-0 items-center justify-center rounded-full bg-primary/12 text-primary">
              <.icon name="hero-user-group" class="size-4" />
            </div>
            <div>
              <h2 id={"#{@id}-title"} class="text-base font-bold text-base-content">
                {if @action == :new,
                  do: gettext("Create Device Group"),
                  else: gettext("Edit Device Group")}
              </h2>
              <p class="text-xs text-base-content/60">
                {gettext("Dynamic selector rule and rollout channel")}
              </p>
            </div>
          </div>

          <.link
            id={"#{@id}-close-btn"}
            patch={@return_to}
            class="btn btn-ghost btn-sm btn-circle text-base-content/60 hover:text-base-content"
            aria-label={gettext("Close")}
          >
            <.icon name="hero-x-mark" class="size-4" />
          </.link>
        </div>

        <.form
          for={@form}
          id="device-group-form"
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save"
          class="flex flex-1 flex-col overflow-y-auto no-scrollbar"
        >
          <div class="flex-1 space-y-4 px-6 py-5">
            <.input
              field={@form[:name]}
              type="text"
              label={gettext("Group Name")}
              placeholder="EU Production Gateways"
              required
            />

            <.input
              field={@form[:handle]}
              type="text"
              label={gettext("Handle")}
              placeholder="eu-production-gateways"
              hint={gettext("Lowercase ASCII letters, digits, and hyphens; starts with a letter")}
              required
            />

            <.input
              type="select"
              id="group-form-channel-id"
              name="group[channel_id]"
              label={gettext("Rollout Channel (Optional)")}
              prompt={gettext("Unassigned (No channel)")}
              options={@channel_options}
              value={@selected_channel_id}
              errors={if @channel_error, do: [@channel_error], else: []}
              hint={gettext("Assign this group to an update or deployment rollout channel")}
            />

            <div class="space-y-2">
              <.input
                field={@form[:selector]}
                type="textarea"
                rows="3"
                label={gettext("Selector Expression")}
                placeholder={~s("eu-west" in tags and "production" in tags)}
                hint={gettext("Combine tag filters with boolean AND / OR operators")}
                required
              />

              <div :if={@available_tags != []} class="space-y-1.5 pt-1">
                <span class="text-xs font-medium text-base-content/60">
                  {gettext("Insert tenant tag filter:")}
                </span>
                <div id="selector-tag-suggestions" class="flex flex-wrap gap-1.5">
                  <button
                    :for={tag <- @available_tags}
                    type="button"
                    data-tag-chip={tag}
                    phx-click="append_tag"
                    phx-value-tag={tag}
                    phx-target={@myself}
                    class="badge badge-soft badge-primary badge-sm rounded-full font-mono cursor-pointer hover:badge-primary transition-colors"
                  >
                    + "{tag}"
                  </button>
                </div>
              </div>
            </div>

            <div
              id="selector-live-preview"
              data-preview-state={@preview.state}
              class="rounded-2xl border border-base-300 bg-base-200/55 p-4 space-y-2.5"
            >
              <div class="flex items-center justify-between">
                <span class="text-xs font-semibold uppercase tracking-wider text-base-content/65">
                  {gettext("Live Selector Preview")}
                </span>

                <span
                  :if={@preview.state == "valid"}
                  class="badge badge-soft badge-success badge-xs rounded-full gap-1 font-medium"
                >
                  <.icon name="hero-check-circle" class="size-3" /> {gettext("Valid syntax")}
                </span>
                <span
                  :if={@preview.state == "invalid"}
                  class="badge badge-soft badge-error badge-xs rounded-full gap-1 font-medium"
                >
                  <.icon name="hero-exclamation-circle" class="size-3" /> {gettext("Syntax error")}
                </span>
              </div>

              <p :if={@preview.state == "empty"} class="text-xs text-base-content/55">
                {gettext("Enter a selector rule above to preview matching devices in real time.")}
              </p>

              <p
                :if={@preview.state == "invalid"}
                id="selector-preview-error"
                class="text-xs font-mono text-error"
              >
                {@preview.error}
              </p>

              <div :if={@preview.state == "valid"} class="space-y-2.5">
                <div class="flex items-center justify-between text-xs">
                  <span class="text-base-content/70">{gettext("Matched fleet:")}</span>
                  <span
                    id="selector-preview-count"
                    class="font-semibold tabular-nums text-base-content"
                  >
                    {@preview.online_count} / {@preview.total_count} {gettext("online")} ({@preview.total_count} {gettext(
                      "matched"
                    )})
                  </span>
                </div>

                <ul
                  :if={@preview.sample_devices != []}
                  id="selector-preview-samples"
                  class="divide-y divide-base-300/70 rounded-xl border border-base-300 bg-base-100 px-3 py-1.5"
                >
                  <li
                    :for={device <- @preview.sample_devices}
                    class="flex items-center justify-between py-1 text-xs"
                  >
                    <div class="flex items-center gap-2">
                      <span class={if(device.online, do: "status status-success", else: "status")}></span>
                      <span class="font-medium text-base-content">{device.name}</span>
                    </div>
                    <span class="font-mono text-base-content/50">{device.device_id}</span>
                  </li>
                </ul>

                <p
                  :if={@preview.total_count == 0 and @preview.ast_supported?}
                  class="text-xs text-warning flex items-center gap-1.5"
                >
                  <.icon name="hero-exclamation-triangle" class="size-3.5 shrink-0" />
                  <span>{gettext("Zero devices in this tenant currently match this selector.")}</span>
                </p>
              </div>
            </div>
          </div>

          <div class="flex items-center justify-end gap-2 border-t border-base-300/80 bg-base-100/80 px-6 py-3.5">
            <.link patch={@return_to} class="btn btn-ghost btn-sm rounded-full px-4">
              {gettext("Cancel")}
            </.link>
            <.button id="save-device-group-btn" type="submit" class="btn-sm rounded-full px-5">
              {if @action == :new, do: gettext("Create Group"), else: gettext("Save Changes")}
            </.button>
          </div>
        </.form>
      </aside>
    </div>
    """
  end

  defp build_ash_form(_group, :new, tenant) do
    AshPhoenix.Form.for_create(DeviceGroup, :create,
      as: "group",
      tenant: tenant,
      authorize?: false
    )
  end

  defp build_ash_form(group, :edit, tenant) do
    AshPhoenix.Form.for_update(group, :update,
      as: "group",
      tenant: tenant,
      authorize?: false
    )
  end

  defp load_channel_options(tenant) do
    Channel
    |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
    |> Ash.Query.sort(:name)
    |> Ash.read!(tenant: tenant, authorize?: false)
    |> Enum.map(&{"#{&1.name} (@#{&1.handle})", to_string(&1.id)})
  end

  defp load_available_tags(tenant) do
    Tag
    |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
    |> Ash.Query.sort(:name)
    |> Ash.read!(tenant: tenant, authorize?: false)
    |> Enum.map(& &1.name)
  end

  defp maybe_auto_slug_handle(group_params, full_params, assigns) do
    target = Map.get(full_params, "_target", [])
    prev_handle = AshPhoenix.Form.value(assigns.ash_form, :handle) || ""
    submitted_handle = Map.get(group_params, "handle", "")

    handle_edited_directly? =
      target == ["group", "handle"] or
        (submitted_handle != "" and submitted_handle != prev_handle and
           target != ["group", "name"])

    handle_touched? = assigns.handle_touched? or handle_edited_directly?

    updated_params =
      if assigns.action == :new and not handle_touched? do
        Map.put(group_params, "handle", slugify_handle(group_params["name"] || ""))
      else
        group_params
      end

    {updated_params, handle_touched?}
  end

  defp navigate_after_save(socket, group, tenant) do
    detail_path = "/tenants/#{tenant.slug}/device-groups/#{group.id}"

    if socket.assigns.action == :new do
      socket
      |> put_flash(:info, gettext("Device group created."))
      |> push_navigate(to: detail_path)
    else
      socket
      |> put_flash(:info, gettext("Device group updated."))
      |> push_patch(to: detail_path)
    end
  end

  defp slugify_handle(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
    |> String.replace(~r/^[^a-z]+/, "")
  end

  defp evaluate_selector_preview(selector, tenant) when is_binary(selector) do
    if String.trim(selector) == "" do
      %{
        state: "empty",
        total_count: 0,
        online_count: 0,
        sample_devices: [],
        error: nil,
        ast_supported?: true
      }
    else
      case Selector.parse(selector) do
        {:ok, _ast} ->
          compute_preview_matches(selector, tenant)

        {:error, %Selector.Parser.Error{message: message}} ->
          %{
            state: "invalid",
            total_count: 0,
            online_count: 0,
            sample_devices: [],
            error: message,
            ast_supported?: false
          }
      end
    end
  end

  defp compute_preview_matches(selector, tenant) do
    case GroupsStatsComponent.selector_filter_expr(selector) do
      {:ok, expr} ->
        base_query =
          Device
          |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
          |> Ash.Query.filter(^expr)

        total_count = Ash.count!(base_query, tenant: tenant, authorize?: false)

        online_count =
          base_query
          |> Ash.Query.filter(online == true)
          |> Ash.count!(tenant: tenant, authorize?: false)

        sample_devices =
          base_query
          |> Ash.Query.sort(name: :asc)
          |> Ash.Query.limit(5)
          |> Ash.read!(tenant: tenant, authorize?: false)

        %{
          state: "valid",
          total_count: total_count,
          online_count: online_count,
          sample_devices: sample_devices,
          error: nil,
          ast_supported?: true
        }

      :error ->
        %{
          state: "valid",
          total_count: 0,
          online_count: 0,
          sample_devices: [],
          error: nil,
          ast_supported?: false
        }
    end
  end

  defp reconcile_channel(saved_group, raw_channel_id, tenant) do
    target_channel_id = parse_channel_id(raw_channel_id)
    current_channel_id = saved_group.channel_id

    cond do
      target_channel_id == current_channel_id ->
        {:ok, saved_group}

      is_nil(target_channel_id) and not is_nil(current_channel_id) ->
        Ash.update(saved_group, %{},
          action: :unassign_channel,
          tenant: tenant,
          authorize?: false
        )

      not is_nil(target_channel_id) and is_nil(current_channel_id) ->
        Ash.update(saved_group, %{channel_id: target_channel_id},
          action: :assign_channel,
          tenant: tenant,
          authorize?: false
        )

      true ->
        with {:ok, unassigned} <-
               Ash.update(saved_group, %{},
                 action: :unassign_channel,
                 tenant: tenant,
                 authorize?: false
               ) do
          Ash.update(unassigned, %{channel_id: target_channel_id},
            action: :assign_channel,
            tenant: tenant,
            authorize?: false
          )
        end
    end
  end

  defp parse_channel_id(nil), do: nil
  defp parse_channel_id(""), do: nil
  defp parse_channel_id(id) when is_integer(id), do: id

  defp parse_channel_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> int
      _ -> nil
    end
  end
end
