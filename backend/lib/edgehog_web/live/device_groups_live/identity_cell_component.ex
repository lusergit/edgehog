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

defmodule EdgehogWeb.DeviceGroupsLive.IdentityCellComponent do
  @moduledoc """
  Reactive table cell LiveComponent displaying a device group's display name
  and `@handle` identifier.

  Subscribes to `"device_groups:identity:<id>"` to update the cell in place.
  """
  use EdgehogWeb, :live_component

  @impl Phoenix.LiveComponent
  def update(%{group: group} = assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:name, group.name)
      |> assign(:handle, group.handle)
      |> ensure_subscribed(group.id)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id={@id} class="flex flex-col">
      <span class="font-semibold text-base-content">
        {@name}
      </span>
      <span class="font-mono text-xs text-base-content/55">
        @{@handle}
      </span>
    </div>
    """
  end

  defp ensure_subscribed(socket, group_id) do
    if connected?(socket) and not Map.get(socket.assigns, :subscribed?, false) do
      EdgehogWeb.Endpoint.subscribe("device_groups:identity:#{group_id}")
      assign(socket, :subscribed?, true)
    else
      socket
    end
  end
end
