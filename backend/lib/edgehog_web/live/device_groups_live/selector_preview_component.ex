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

defmodule EdgehogWeb.DeviceGroupsLive.SelectorPreviewComponent do
  @moduledoc """
  Stateless function components and domain helpers for device group selector
  tag suggestions, real-time selector AST evaluation/preview, and rollout
  channel reconciliation.
  """
  use EdgehogWeb, :html

  alias Edgehog.Campaigns.Channel
  alias Edgehog.Devices.Device
  alias Edgehog.Labeling.Tag
  alias Edgehog.Selector
  alias EdgehogWeb.DeviceGroupsLive.GroupsStatsComponent

  require Ash.Query

  attr :available_tags, :list, required: true
  attr :myself, :any, required: true

  def tag_suggestions(assigns) do
    ~H"""
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
    """
  end

  attr :preview, :map, required: true

  def selector_live_preview(assigns) do
    ~H"""
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
    """
  end

  def load_channel_options(tenant) do
    Channel
    |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
    |> Ash.Query.sort(:name)
    |> Ash.read!(tenant: tenant, authorize?: false)
    |> Enum.map(&{"#{&1.name} (@#{&1.handle})", to_string(&1.id)})
  end

  def load_available_tags(tenant) do
    Tag
    |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
    |> Ash.Query.sort(:name)
    |> Ash.read!(tenant: tenant, authorize?: false)
    |> Enum.map(& &1.name)
  end

  def evaluate_selector_preview(selector, tenant) when is_binary(selector) do
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

  def reconcile_channel(saved_group, raw_channel_id, tenant) do
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
