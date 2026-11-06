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

defmodule EdgehogWeb.DeviceGroupsLive.SelectorCellComponent do
  @moduledoc """
  Reactive table cell LiveComponent that parses a device group's selector
  expression into tokenized AST badges (`TagFilter`, `AttributeFilter`, and
  `BinaryOp` combinators).

  Subscribes to `"device_groups:selector:<id>"` so selector edits update the
  rendered tokens in place.
  """
  use EdgehogWeb, :live_component

  alias Edgehog.Selector
  alias Edgehog.Selector.AST.AttributeFilter
  alias Edgehog.Selector.AST.BinaryOp
  alias Edgehog.Selector.AST.TagFilter

  @impl Phoenix.LiveComponent
  def update(%{group: group} = assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:selector, group.selector)
      |> assign(:tokens, tokenize_selector(group.selector))
      |> ensure_subscribed(group.id)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id={@id} class="flex flex-wrap items-center gap-1.5">
      <%= for token <- @tokens do %>
        <%= case token do %>
          <% {:tag_filter, %{tag: tag, operator: operator}} -> %>
            <span
              data-selector-token="tag-filter"
              class="inline-flex items-center gap-1 rounded-field border border-base-300 bg-base-200/50 px-1.5 py-0.5"
            >
              <span class="badge badge-soft badge-primary badge-xs font-mono">
                "{tag}"
              </span>
              <span class="text-xs font-mono text-base-content/65">
                {operator}
              </span>
            </span>
          <% {:attribute_filter, %{path: path, operator: operator, value: value}} -> %>
            <span
              data-selector-token="attribute-filter"
              class="inline-flex items-center gap-1 rounded-field border border-base-300 bg-base-200/50 px-1.5 py-0.5"
            >
              <span class="badge badge-soft badge-secondary badge-xs font-mono">
                {path}
              </span>
              <span class="text-xs font-mono text-base-content/65">
                {operator}
              </span>
              <span class="badge badge-ghost badge-xs font-mono">
                {value}
              </span>
            </span>
          <% {:op, op} -> %>
            <span
              data-selector-op={op}
              class="badge badge-ghost badge-xs font-mono font-bold uppercase tracking-wider text-base-content/70"
            >
              {op}
            </span>
          <% {:paren, paren} -> %>
            <span class="font-mono text-xs font-bold text-base-content/50">
              {paren}
            </span>
          <% {:raw, raw} -> %>
            <code class="badge badge-ghost badge-sm font-mono">
              {raw}
            </code>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp ensure_subscribed(socket, group_id) do
    if connected?(socket) and not Map.get(socket.assigns, :subscribed?, false) do
      EdgehogWeb.Endpoint.subscribe("device_groups:selector:#{group_id}")
      assign(socket, :subscribed?, true)
    else
      socket
    end
  end

  defp tokenize_selector(selector) when is_binary(selector) do
    case Selector.parse(selector) do
      {:ok, ast_root} -> flatten_ast(ast_root)
      {:error, _} -> [{:raw, selector}]
    end
  end

  defp tokenize_selector(selector), do: [{:raw, to_string(selector)}]

  defp flatten_ast(%TagFilter{tag: tag, operator: operator}) do
    [{:tag_filter, %{tag: tag, operator: format_tag_operator(operator)}}]
  end

  defp flatten_ast(%AttributeFilter{
         namespace: namespace,
         key: key,
         operator: operator,
         type: type,
         value: value
       }) do
    [
      {:attribute_filter,
       %{
         path: ~s(attributes["#{namespace}:#{key}"]),
         operator: Atom.to_string(operator),
         value: format_attribute_value(type, value)
       }}
    ]
  end

  defp flatten_ast(%BinaryOp{operator: operator, lhs: lhs, rhs: rhs}) do
    op_label = operator |> Atom.to_string() |> String.upcase()
    lhs_tokens = flatten_child(lhs, operator)
    rhs_tokens = flatten_child(rhs, operator)

    lhs_tokens ++ [{:op, op_label}] ++ rhs_tokens
  end

  defp flatten_child(%BinaryOp{operator: :or} = child, :and) do
    [{:paren, "("}] ++ flatten_ast(child) ++ [{:paren, ")"}]
  end

  defp flatten_child(child, _parent_op), do: flatten_ast(child)

  defp format_tag_operator(:in), do: "in tags"
  defp format_tag_operator(:not_in), do: "not in tags"
  defp format_tag_operator(:matches), do: "matches"
  defp format_tag_operator(:not_matches), do: "not matches"

  defp format_attribute_value(:string, value), do: ~s("#{value}")
  defp format_attribute_value(:datetime, %DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp format_attribute_value(_type, value), do: to_string(value)
end
