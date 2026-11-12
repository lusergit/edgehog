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

defmodule EdgehogWeb.ChannelsLive.ChannelFormComponent do
  @moduledoc """
  Floating right-side pill `Phoenix.LiveComponent` for creating and editing an
  `Edgehog.Campaigns.Channel`.

  Supports auto-derived handle slugs on creation, target device group selection
  with group-stealing warnings and running-campaign locks via
  `ChannelGroupPickerComponent`, and a live deduplicated blast-radius preview
  without blurring the underlying page.
  """
  use EdgehogWeb, :live_component

  alias Edgehog.Campaigns.Channel
  alias EdgehogWeb.ChannelsLive.ChannelFleetComponent
  alias EdgehogWeb.ChannelsLive.ChannelGroupPickerComponent

  @impl Phoenix.LiveComponent
  def update(%{channel: channel, tenant: tenant, action: action} = assigns, socket) do
    current_channel_id = if action == :edit, do: channel.id, else: nil
    group_items = ChannelGroupPickerComponent.load_group_items(current_channel_id, tenant)

    selected_group_ids =
      group_items
      |> Enum.filter(&(&1.group.channel_id != nil and &1.group.channel_id == current_channel_id))
      |> MapSet.new(& &1.group.id)

    ash_form = build_ash_form(channel, action, tenant)

    socket =
      socket
      |> assign(assigns)
      |> assign(:group_items, group_items)
      |> assign(:selected_group_ids, selected_group_ids)
      |> assign(:group_error, nil)
      |> assign(:handle_touched?, action == :edit)
      |> assign(:ash_form, ash_form)
      |> assign(:form, to_form(ash_form))
      |> recompute_picker_state()

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def handle_event("validate", %{"channel" => channel_params} = full_params, socket) do
    {channel_params, handle_touched?} =
      maybe_auto_slug_handle(channel_params, full_params, socket.assigns)

    ash_form =
      AshPhoenix.Form.validate(
        socket.assigns.ash_form,
        Map.take(channel_params, ["name", "handle"])
      )

    {:noreply,
     socket
     |> assign(:handle_touched?, handle_touched?)
     |> assign(:group_error, nil)
     |> assign(:ash_form, ash_form)
     |> assign(:form, to_form(ash_form))}
  end

  def handle_event("toggle_group", %{"group-id" => raw_id}, socket) do
    with {group_id, ""} <- Integer.parse(raw_id),
         %{state: state} when state not in [:locked_other, :locked_current] <-
           Enum.find(socket.assigns.group_items, &(&1.group.id == group_id)) do
      selected = socket.assigns.selected_group_ids

      updated =
        if MapSet.member?(selected, group_id) do
          MapSet.delete(selected, group_id)
        else
          MapSet.put(selected, group_id)
        end

      {:noreply,
       socket
       |> assign(:selected_group_ids, updated)
       |> assign(:group_error, nil)
       |> recompute_picker_state()}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("save", %{"channel" => channel_params}, socket) do
    tenant = socket.assigns.tenant
    selected_ids = socket.assigns.selected_group_ids
    current_id = if socket.assigns.action == :edit, do: socket.assigns.channel.id, else: nil
    form_params = Map.take(channel_params, ["name", "handle"])

    with :ok <-
           ChannelGroupPickerComponent.validate_group_selection(selected_ids, current_id, tenant),
         {:ok, saved_channel} <-
           AshPhoenix.Form.submit(socket.assigns.ash_form, params: form_params) do
      ChannelGroupPickerComponent.reconcile_target_groups(saved_channel, selected_ids, tenant)
      {:noreply, navigate_after_save(socket, saved_channel, tenant)}
    else
      {:error, %AshPhoenix.Form{} = ash_form} ->
        {:noreply,
         socket
         |> assign(:ash_form, ash_form)
         |> assign(:form, to_form(ash_form))}

      {:error, message} when is_binary(message) ->
        {:noreply, assign(socket, :group_error, message)}
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
        icon="hero-signal"
        icon_class="bg-info/15 text-info"
        title={
          if(@action == :new,
            do: gettext("Create Rollout Channel"),
            else: gettext("Edit Rollout Channel")
          )
        }
        subtitle={gettext("Configure channel identity and target device group rings.")}
        close_patch={@return_to}
        close_id="close-channel-drawer-btn"
      >
        <.form
          for={@form}
          id="channel-form"
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save"
          class="flex-1 overflow-y-auto px-6 py-4 space-y-4"
        >
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <.input
              field={@form[:name]}
              type="text"
              label={gettext("Channel Name")}
              placeholder="Stable Production Ring"
              required
            />

            <.input
              field={@form[:handle]}
              type="text"
              label={gettext("Handle")}
              placeholder="stable-prod"
              required
            />
          </div>

          <div
            :if={@group_error}
            id="channel-group-error"
            class="alert alert-error text-xs py-2 px-3"
          >
            <.icon name="hero-exclamation-circle" class="size-4 shrink-0" />
            <span>{@group_error}</span>
          </div>

          <ChannelGroupPickerComponent.group_picker
            group_items={@group_items}
            selected_group_ids={@selected_group_ids}
            myself={@myself}
          />

          <ChannelGroupPickerComponent.steal_warning stolen_items={@stolen_items} />

          <ChannelGroupPickerComponent.live_preview preview_reach={@preview_reach} />

          <.drawer_footer
            cancel_patch={@return_to}
            cancel_id="cancel-channel-form-btn"
            submit_id="submit-channel-form-btn"
            submit_label={
              if(@action == :new, do: gettext("Create Channel"), else: gettext("Save Changes"))
            }
          />
        </.form>
      </.floating_pill_drawer>
    </div>
    """
  end

  defp recompute_picker_state(socket) do
    selected_ids = socket.assigns.selected_group_ids
    tenant = socket.assigns.tenant

    selected_items =
      Enum.filter(socket.assigns.group_items, &MapSet.member?(selected_ids, &1.group.id))

    stolen_items = Enum.filter(selected_items, &(&1.state == :stealable))
    selected_groups = Enum.map(selected_items, & &1.group)
    preview_reach = ChannelFleetComponent.compute_groups_reach(selected_groups, tenant)

    socket
    |> assign(:stolen_items, stolen_items)
    |> assign(:preview_reach, preview_reach)
  end

  defp build_ash_form(channel, :new, tenant) do
    Channel
    |> AshPhoenix.Form.for_create(:create,
      as: "channel",
      tenant: tenant,
      authorize?: false,
      forms: [auto?: false]
    )
    |> Map.put(:data, channel)
  end

  defp build_ash_form(channel, :edit, tenant) do
    AshPhoenix.Form.for_update(channel, :update,
      as: "channel",
      tenant: tenant,
      authorize?: false,
      forms: [auto?: false]
    )
  end

  defp maybe_auto_slug_handle(channel_params, full_params, assigns) do
    target = Map.get(full_params, "_target", [])
    handle_touched? = assigns.handle_touched? or target == ["channel", "handle"]

    if assigns.action == :new and not handle_touched? do
      slug = slugify_name(channel_params["name"] || "")
      {Map.put(channel_params, "handle", slug), false}
    else
      {channel_params, handle_touched?}
    end
  end

  defp slugify_name(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
    |> String.replace(~r/^[^a-z]+/, "")
  end

  defp navigate_after_save(%{assigns: %{action: :new}} = socket, saved_channel, tenant) do
    socket
    |> put_flash(:info, gettext("Rollout channel created."))
    |> push_navigate(to: "/tenants/#{tenant.slug}/channels/#{saved_channel.id}")
  end

  defp navigate_after_save(socket, _saved_channel, _tenant) do
    socket
    |> put_flash(:info, gettext("Rollout channel updated."))
    |> push_patch(to: socket.assigns.return_to)
  end
end
