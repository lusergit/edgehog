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

defmodule Edgehog.Containers.Deployment.Provisioner.Core do
  @moduledoc """
  Deployment provisioner core functions.

  The function here down below handle and manage the state of the provisioner,
  trying to bubble up error and let the provisioner how to handle that
  """

  @doc """
  Loads resources associated to the deployment, adding them to the state
  """
  def load_resources(state) do
    %{deployment: deployment} = state

    with {:ok, loaded_deployment} <- Ash.load(deployment, [container_deployments: [image_deployment: :image, network_deployments: :network, volume_deployments: :volume, device_mapping_deployments: :device_mapping]]) do
      new_state =
        state
        |> add_container_deployments()
        |> add_image_deployments()
        |> add_network_deployments()
        |> add_volume_deployments()
        |> add_device_mapping_deployments()
        |> Map.put(:init, true)

      {:ok, new_state}
    end
  end

  @doc """
  Sends the resources 
  """
  def send_resources(state) do
    state
    |> send_image_deployments()
    |> send_network_deployments()
    |> send_volume_deployments()
    |> send_device_mapping_deployments()
    |> send_container_deployments()
  end 

  # Precondition: Loading succeeded, we only have to navigate valid maps
  defp add_container_deployments(%{deployment: deployment} = state) do
    %{container_deployments: container_deployments} = deployment

    Map.put(state, :container_deployments, container_deployments)
  end

  # Precondition: Loading succeeded, and container deployments are loaded, we only have to navigate valid maps
  defp add_image_deployments(%{container_deployments: deployments} = state) do
    image_deployments =
      deployments
      |> Enum.map(&Map.fetch!(&1, :image_deployment))
      |> Enum.uniq_by(& &1.id)

    Map.put(state, :image_deployments, image_deployments)
  end

  # Precondition: Loading succeeded, and container deployments are loaded, we only have to navigate valid maps
  defp add_network_deployments(%{container_deployments: deployments}i = state) do
    network_deployments =
      deployments
      |> Enum.flat_map(&Map.fetch!(&1, :network_deployments))
      |> Enum.uniq_by(& &1.id)

    Map.put(state, :network_deployments, network_deployments)
  end

  # Precondition: Loading succeeded, and container deployments are loaded, we only have to navigate valid maps
  defp add_volume_deployments(%{container_deployments: deployments} = state) do
    volume_deployments =
      deployments
      |> Enum.flat_map(&Map.fetch!(&1, :volume_deployments))
      |> Enum.uniq_by(& &1.id)

    Map.put(state, :volume_deployments, volume_deployments)
  end

  # Precondition: Loading succeeded, and container deployments are loaded, we only have to navigate valid maps
  defp add_device_mapping_deployments(%{container_deployments: deployments} = state) do
    device_mapping_deployments =
      deployments
      |> Enum.flat_map(&Map.fetch!(&1, :device_mapping_deployments))
      |> Enum.uniq_by(& &1.id)

    Map.put(state, :device_mapping_deployments, device_mapping_deployments)
  end

  defp send_image_deployments(%{image_deployments: image_deployments} = state) do
    pending = image_deployments
    
  end
end
