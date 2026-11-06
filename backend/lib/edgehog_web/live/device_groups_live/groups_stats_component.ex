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

defmodule EdgehogWeb.DeviceGroupsLive.GroupsStatsComponent do
  @moduledoc """
  LiveComponent rendering reactive summary metrics for a tenant's device groups
  (Total Groups, Channel-Linked, Empty Groups, and Fleet Coverage ratio).
  """
  use EdgehogWeb, :live_component

  alias Edgehog.Devices.Device
  alias Edgehog.Groups.DeviceGroup
  alias Edgehog.Selector
  alias Edgehog.Selector.AST.AttributeFilter
  alias Edgehog.Selector.AST.BinaryOp
  alias Edgehog.Selector.AST.TagFilter

  require Ash.Query

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    tenant = assigns.tenant
    stats = compute_stats(tenant)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(stats)}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <section
      id={@id}
      aria-label="Device groups summary"
      class="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4"
    >
      <div class="card card-border bg-base-100 p-4 shadow-xs">
        <div class="flex items-center justify-between">
          <span class="text-xs font-semibold uppercase tracking-wider text-base-content/60">
            Total Groups
          </span>
          <.icon name="hero-user-group" class="size-4 text-base-content/45" />
        </div>
        <p id="stat-total-groups" class="mt-2 text-2xl font-bold tabular-nums text-base-content">
          {@total_groups}
        </p>
        <p class="mt-0.5 text-xs text-base-content/55">Dynamic selector partitions</p>
      </div>

      <div class="card card-border bg-base-100 p-4 shadow-xs">
        <div class="flex items-center justify-between">
          <span class="text-xs font-semibold uppercase tracking-wider text-base-content/60">
            Channel-Linked
          </span>
          <.icon name="hero-signal" class="size-4 text-info" />
        </div>
        <p id="stat-linked-groups" class="mt-2 text-2xl font-bold tabular-nums text-base-content">
          {@linked_groups}
        </p>
        <p class="mt-0.5 text-xs text-base-content/55">Assigned to rollout channels</p>
      </div>

      <div class="card card-border bg-base-100 p-4 shadow-xs">
        <div class="flex items-center justify-between">
          <span class="text-xs font-semibold uppercase tracking-wider text-base-content/60">
            Empty Groups
          </span>
          <.icon
            name="hero-exclamation-triangle"
            class={
              if(@empty_groups > 0,
                do: "size-4 text-warning",
                else: "size-4 text-base-content/45"
              )
            }
          />
        </div>
        <p
          id="stat-empty-groups"
          class={[
            "mt-2 text-2xl font-bold tabular-nums",
            if(@empty_groups > 0, do: "text-warning", else: "text-base-content")
          ]}
        >
          {@empty_groups}
        </p>
        <p class="mt-0.5 text-xs text-base-content/55">Matching zero devices</p>
      </div>

      <div class="card card-border bg-base-100 p-4 shadow-xs">
        <div class="flex items-center justify-between">
          <span class="text-xs font-semibold uppercase tracking-wider text-base-content/60">
            Fleet Coverage
          </span>
          <.icon name="hero-cpu-chip" class="size-4 text-primary" />
        </div>
        <div class="mt-2 flex items-baseline gap-2">
          <p
            id="stat-fleet-coverage-pct"
            class="text-2xl font-bold tabular-nums text-base-content"
          >
            {@coverage_pct}%
          </p>
        </div>
        <progress
          class="progress progress-primary mt-2 w-full"
          value={@coverage_pct}
          max="100"
        />
      </div>
    </section>
    """
  end

  @doc """
  Safely parses a selector string and converts its AST into an `%Ash.Expr{}`
  when all filter nodes are supported by the Ash data layer.

  Returns `{:ok, expr}` or `:error`.
  """
  def selector_filter_expr(selector) when is_binary(selector) do
    with {:ok, ast_root} <- Selector.parse(selector),
         true <- ast_supported?(ast_root) do
      try do
        {:ok, Selector.to_ash_expr(ast_root)}
      rescue
        _ -> :error
      end
    else
      _ -> :error
    end
  end

  def selector_filter_expr(_selector), do: :error

  defp ast_supported?(%TagFilter{}), do: true
  defp ast_supported?(%AttributeFilter{}), do: false

  defp ast_supported?(%BinaryOp{lhs: lhs, rhs: rhs}) do
    ast_supported?(lhs) and ast_supported?(rhs)
  end

  defp ast_supported?(_node), do: false

  defp compute_stats(tenant) do
    groups = Ash.read!(DeviceGroup, tenant: tenant, authorize?: false)
    total_groups = length(groups)
    linked_groups = Enum.count(groups, &(not is_nil(&1.channel_id)))

    group_device_sets =
      Enum.map(groups, fn group ->
        matching_device_ids(group.selector, tenant)
      end)

    empty_groups = Enum.count(group_device_sets, &(MapSet.size(&1) == 0))

    covered_devices =
      group_device_sets
      |> Enum.reduce(MapSet.new(), &MapSet.union/2)
      |> MapSet.size()

    total_devices = Ash.count!(Device, tenant: tenant, authorize?: false)

    coverage_pct =
      if total_devices > 0 do
        round(covered_devices / total_devices * 100)
      else
        0
      end

    %{
      total_groups: total_groups,
      linked_groups: linked_groups,
      empty_groups: empty_groups,
      coverage_pct: coverage_pct
    }
  end

  defp matching_device_ids(selector, tenant) do
    case selector_filter_expr(selector) do
      {:ok, expr} ->
        Device
        |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
        |> Ash.Query.filter(^expr)
        |> Ash.Query.select([:id])
        |> Ash.read!(tenant: tenant, authorize?: false)
        |> MapSet.new(& &1.id)

      :error ->
        MapSet.new()
    end
  end
end
