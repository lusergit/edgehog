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

defmodule EdgehogWeb.SystemModelsLive.PartNumbersStripComponent do
  @moduledoc """
  Stateless function component rendering a system model's registered part
  numbers as monospace chips with per-part-number device counts and an optional
  overflow badge. Reusable across `Index` Bento cards and `Show` detail strips.
  """
  use EdgehogWeb, :html

  attr :part_numbers, :list, required: true
  attr :counts_by_part_number, :map, default: %{}
  attr :max_visible, :any, default: 3

  def part_numbers_strip(assigns) do
    normalized = normalize_part_numbers(assigns.part_numbers)
    {visible, overflow_count} = split_visible(normalized, assigns.max_visible)

    assigns =
      assigns
      |> assign(:normalized_part_numbers, normalized)
      |> assign(:visible_part_numbers, visible)
      |> assign(:overflow_count, overflow_count)

    ~H"""
    <div class="border-t border-base-200 pt-3.5">
      <div class="flex items-center justify-between gap-2 mb-2">
        <span class="text-xs font-semibold uppercase tracking-wider text-base-content/60">
          {gettext("Part Numbers")}
        </span>
        <span
          data-role="part-numbers-count"
          class="font-mono text-xs font-medium tabular-nums text-base-content/60"
        >
          {length(@normalized_part_numbers)}
        </span>
      </div>

      <div
        :if={@visible_part_numbers != []}
        data-role="part-numbers-list"
        class="flex flex-wrap items-center gap-1.5"
      >
        <span
          :for={pn <- @visible_part_numbers}
          data-part-number={pn}
          class="inline-flex items-center gap-1.5 rounded-lg border border-base-300 bg-base-200/45 px-2.5 py-1 text-xs font-medium text-base-content"
        >
          <.icon name="hero-qr-code" class="size-3.5 text-base-content/65 shrink-0" />
          <span class="font-mono text-[11px]">{pn}</span>
          <span
            data-role="part-number-device-count"
            class="rounded bg-base-300/70 px-1.5 py-0.5 font-mono text-[10px] font-semibold tabular-nums text-base-content/75"
          >
            {part_number_total(@counts_by_part_number, pn)}
          </span>
        </span>

        <span
          :if={@overflow_count > 0}
          data-role="part-numbers-overflow"
          class="badge badge-soft badge-neutral border-base-300 bg-base-200/70 text-base-content/75 badge-sm font-mono tabular-nums"
        >
          +{@overflow_count} more
        </span>
      </div>
    </div>
    """
  end

  defp normalize_part_numbers(part_numbers) when is_list(part_numbers) do
    part_numbers
    |> Enum.map(fn
      %{part_number: pn} when is_binary(pn) -> pn
      pn when is_binary(pn) -> pn
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp normalize_part_numbers(_other), do: []

  defp split_visible(list, max_visible)
       when is_integer(max_visible) and max_visible > 0 and length(list) > max_visible do
    {Enum.take(list, max_visible), length(list) - max_visible}
  end

  defp split_visible(list, _max_visible), do: {list, 0}

  defp part_number_total(counts_by_part_number, pn) do
    case Map.get(counts_by_part_number, pn) do
      %{total: total} when is_integer(total) -> total
      total when is_integer(total) -> total
      _ -> 0
    end
  end
end
