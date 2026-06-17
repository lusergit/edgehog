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

defmodule Edgehog.Containers.Image.Deployment.Provisioner do
  @moduledoc """
  An image deployment provisioner.

  Each and every time an image should be deployed, it can be done trough this
  provisioner. The provisioner sends the appropriate messages to the device and
  emits an `image:deployment:id` event whenever the image is acknowledged by the
  device.
  """

  use GenServer, restart: :transient

  def start_link(args) do
    image_deployment = Keyword.fetch!(args, :image_deployment)

    GenServer.start_link(__MODULE__, args, name: name(image_deployment))
  end

  def name(%{id: id} = image_deployment) do
    {:via, Registry, {Image.Deployment.Provisioner.Registry}}
  end

  @impl GenServer
  def init(args) do
    image_deployment = Keyword.fetch!(args, :image_deployment)
    deployment = Keyword.fetch!(args, :deployment)
    tenant = Keyword.fetch!(args, :tenant)

    state = %{
      image_deployment: image_deployment,
      deployment: deployment,
      tenant: tenant,
      state: :init
    }

    {:ok, state, {:continue, :send}}
  end

  @impl GenServer
  def handle_continue(:send, state) do
    %{
      image_deployment: image_deployment,
      deployment: deployment,
      tenant: tenant
    } = state

    %{id: id} = image_deployment

    upid = 
      image_deployment
      |> Ash.Changeset.for_update(:send_deployment, %{deployment: deployment}, tenant: tenant)
      |> Ash.update()

    case upid do
      {:ok, image_deployment} -> {:noreply, state}
      {:error, error} -> {:noreply, state}
    end
  end
end
