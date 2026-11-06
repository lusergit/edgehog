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

  alias Edgehog.Groups.DeviceGroup
  alias EdgehogWeb.DeviceGroupsLive.SelectorPreviewComponent

  @impl Phoenix.LiveComponent
  def update(%{group: group, tenant: tenant, action: action} = assigns, socket) do
    channel_options = SelectorPreviewComponent.load_channel_options(tenant)
    available_tags = SelectorPreviewComponent.load_available_tags(tenant)
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
      |> assign(
        :preview,
        SelectorPreviewComponent.evaluate_selector_preview(initial_selector, tenant)
      )

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

    preview =
      SelectorPreviewComponent.evaluate_selector_preview(
        group_params["selector"] || "",
        socket.assigns.tenant
      )

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

    preview =
      SelectorPreviewComponent.evaluate_selector_preview(new_selector, socket.assigns.tenant)

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
         {:ok, final_group} <-
           SelectorPreviewComponent.reconcile_channel(saved_group, selected_channel_id, tenant) do
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
      <.floating_pill_drawer
        id={@id}
        icon="hero-user-group"
        icon_class="bg-primary/12 text-primary"
        title={
          if(@action == :new,
            do: gettext("Create Device Group"),
            else: gettext("Edit Device Group")
          )
        }
        subtitle={gettext("Dynamic selector rule and rollout channel")}
        close_patch={@return_to}
      >
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

              <SelectorPreviewComponent.tag_suggestions
                available_tags={@available_tags}
                myself={@myself}
              />
            </div>

            <SelectorPreviewComponent.selector_live_preview preview={@preview} />
          </div>

          <.drawer_footer
            cancel_patch={@return_to}
            submit_id="save-device-group-btn"
            submit_label={
              if(@action == :new, do: gettext("Create Group"), else: gettext("Save Changes"))
            }
            class="flex items-center justify-end gap-2 border-t border-base-300/80 bg-base-100/80 px-6 py-3.5"
          />
        </.form>
      </.floating_pill_drawer>
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
end
