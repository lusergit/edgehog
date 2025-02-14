#
# This file is part of Edgehog.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Edgehog.Containers.Deployment.Deployer do
  @moduledoc """
  Deployer state machine.
  This module once started is responsible for interacting with the device sending
  all the necessary data to deploy a release on a device.
  """
  use GenStateMachine, restart: :transient, callback_mode: [:handle_event_function, :state_enter]

  alias __MODULE__, as: Data
  alias Edgehog.Containers
  alias Edgehog.Devices

  require Logger

  # All elements in the struct are either IDs or lists of IDs, so that the state
  # is more lightweight and the correct informations are retrived from the
  # database when needed.
  defstruct [
    :images,
    :networks,
    :volumes,
    :containers,
    :release,
    :device,
    :tenant
  ]

  # Public API
  def start_link(opts) do
    name = opts[:args] || __MODULE__

    GenStateMachine.start_link(__MODULE__, opts, name: name)
  end

  # Callbacks

  @impl GenStateMachine
  def init(opts) do
    tenant = Keyword.fetch!(opts, :tenant_id)
    release = Keyword.fetch!(opts, :release_id)
    device = Keyword.fetch!(opts, :device_id)

    data = %Data{
      tenant: tenant,
      release: release,
      device: device
    }

    {:ok, :initialization, data, internal_event(:init_data)}
  end

  # State: :initialization

  def handle_event(:enter, _old_state, :initialization, data) do
    %Data{release: release_id} = data

    Logger.info("Deployment of release #{release_id}: entering the :initialization state")

    :keep_state_and_data
  end

  def handle_event(:internal, :init_data, :initialization, data) do
    %Data{
      release: release_id,
      device: device_id,
      tenant: tenant_id
    } = data

    release =
      Containers.fetch_release!(release_id,
        tenant: tenant_id,
        load: [containers: [:image, :networks, :volumes]]
      )

    device = Devices.fetch_device!(device_id, tenant: tenant_id)

    containers = release.containers

    images =
      containers
      |> Enum.map(& &1.image_id)
      |> Enum.uniq()

    networks =
      containers
      |> Enum.flat_map(& &1.networks)
      |> Enum.map(& &1.id)
      |> Enum.uniq()

    volumes =
      containers
      |> Enum.flat_map(& &1.volumes)
      |> Enum.map(& &1.id)
      |> Enum.uniq()

    containers = Enum.map(containers, & &1.id)

    new_data = %Data{
      images: images,
      networks: networks,
      volumes: volumes,
      containers: containers,
      device: device_id,
      release: release_id,
      tenant: tenant_id
    }

    {:netx_state, :deploy_images, new_data, internal_event(:deploy_next_image)}
  end

  # State: :deploy_images

  def handle_event(:enter, _old_state, :deploy_images, data) do
    Logger.info("Deployment of release #{data.release_id}: entering :deploy_images state")

    :keep_state_and_data
  end

  # Fetch the next image, updating the remaining images list, if all images have
  # been deployed, (hence removed from the list), deploy networks.
  def handle_event(:internal, :deploy_next_image, :deploy_images, data) do
    %Data{images: images, tenant: tenant, device: device} = data

    case images do
      [] ->
        {:next_state, :deploy_networks, data, internal_event(:deploy_next_network)}

      [image | rest] ->
        new_data = Map.put(data, :images, rest)
        {:keep_state, new_data, internal_event({:deploy_image, image})}
    end
  end

  def handle_event(:internal, {:deploy_image, image_id}, :deploy_images, data) do
    %Data{device: device_id, tenant: tenant} = data

    with {:ok, image} <- Containers.fetch_image(image_id, tenant: tenant),
         {:ok, device} <- Devices.fetch_device(device_id, tenant: tenant),
         {:ok, image_deployment} <- Containers.deploy_image(image, device, tenant: tenant) do
      {:keep_state_and_data, internal_event(:deploy_next_image)}
    else
      error -> terminate_on_error(error, data)
    end
  end

  # State: :deploy_networks

  def handle_event(:enter, _old_state, :deploy_networks, data) do
    Logger.info("Deployment of release #{data.release_id}: entering :deploy_networks state")

    :keep_state_and_data
  end

  # Fetch the next network, updating the remaining networks list, if all networks have
  # been deployed, (hence removed from the list), deploy volumes.
  def handle_event(:internal, :deploy_next_network, :deploy_networks, data) do
    %Data{networks: networks, tenant: tenant, device: device} = data

    case networks do
      [] ->
        {:next_state, :deploy_volumes, data, internal_event(:deploy_next_volume)}

      [network | rest] ->
        new_data = Map.put(data, :networks, rest)
        {:keep_state, new_data, internal_event({:deploy_network, network})}
    end
  end

  def handle_event(:internal, {:deploy_network, network_id}, :deploy_networks, data) do
    %Data{device: device_id, tenant: tenant} = data

    with {:ok, network} <- Containers.fetch_network(network_id, tenant: tenant),
         {:ok, device} <- Devices.fetch_device(device_id, tenant: tenant),
         {:ok, network_deployment} <- Containers.deploy_network(network, device, tenant: tenant) do
      {:keep_state_and_data, internal_event(:deploy_next_network)}
    else
      error -> terminate_on_error(error, data)
    end
  end

  # State: :deploy_volumes

  def handle_event(:enter, _old_state, :deploy_volumes, data) do
    Logger.info("Deployment of release #{data.release_id}: entering :deploy_volumes state")

    :keep_state_and_data
  end

  # Fetch the next volume, updating the remaining volumes list, if all volumes have
  # been deployed, (hence removed from the list), deploy containers.
  def handle_event(:internal, :deploy_next_volume, :deploy_volumes, data) do
    %Data{volumes: volumes, tenant: tenant, device: device} = data

    case volumes do
      [] ->
        {:next_state, :deploy_containers, data, internal_event(:deploy_next_container)}

      [volume | rest] ->
        new_data = Map.put(data, :volumes, rest)
        {:keep_state, new_data, internal_event({:deploy_volume, volume})}
    end
  end

  def handle_event(:internal, {:deploy_volume, volume_id}, :deploy_volumes, data) do
    %Data{device: device_id, tenant: tenant} = data

    with {:ok, volume} <- Containers.fetch_volume(volume_id, tenant: tenant),
         {:ok, device} <- Devices.fetch_device(device_id, tenant: tenant),
         {:ok, volume_deployment} <- Containers.deploy_volume(volume, device, tenant: tenant) do
      {:keep_state_and_data, internal_event(:deploy_next_volume)}
    else
      error -> terminate_on_error(error, data)
    end
  end

  # State: :deploy_containers

  def handle_event(:enter, _old_state, :deploy_containers, data) do
    Logger.info("Deployment of release #{data.release_id}: entering :deploy_containers state")

    :keep_state_and_data
  end

  # Fetch the next container, updating the remaining containers list, if all containers have
  # been deployed, (hence removed from the list), deploy the release.
  def handle_event(:internal, :deploy_next_container, :deploy_containers, data) do
    %Data{containers: containers, tenant: tenant, device: device} = data

    case containers do
      [] ->
        {:next_state, :deploy_release, data}

      [container | rest] ->
        new_data = Map.put(data, :containers, rest)
        {:keep_state, new_data, internal_event({:deploy_container, container})}
    end
  end

  def handle_event(:internal, {:deploy_container, container_id}, :deploy_containers, data) do
    %Data{device: device_id, tenant: tenant} = data

    with {:ok, container} <- Containers.fetch_container(container_id, tenant: tenant),
         {:ok, device} <- Devices.fetch_device(device_id, tenant: tenant),
         {:ok, container_deployment} <-
           Containers.deploy_container(container, device, tenant: tenant) do
      {:keep_state_and_data, internal_event(:deploy_next_container)}
    else
      error -> terminate_on_error(error, data)
    end
  end

  # State: :deploy_release

  def handle_event(:enter, _old_state, :deploy_release, data) do
    Logger.info("Deployment of release #{data.release_id}: entering :deploy_release state")

    :keep_state_and_data
  end

  def handle_event(:internal, :deploy_release, :deploy_releasess, data) do
    %Data{release: release_id, tenant: tenant, device: device} = data

    with {:ok, release} <- Containers.fetch_release(release_id, tenant: tenant),
         {:ok, deployment} <- Containers.deploy(release, device, tenant: tenant) do
    else
      error -> terminate_on_error(error, data)
    end
  end

  # State: :error

  def handle_event(:enter, old_state, :deployment_failure, data) do
    %Data{release: release_id} = data

    Logger.info(
      "Entering :deployment_failure from state #{inspect(old_state)} for release #{release_id}",
      tag: "deployment_failure"
    )

    :keep_state_and_data
  end

  def handle_event(:internal, {:failure, reason}, :deployment_failure, data) do
    %Data{release: release_id} = data

    Logger.error("Failed deployment for release #{release_id} with reason #{inspect(reason)}",
      tag: "deployment_failure"
    )

    terminate_deployer(release_id)
  end

  # Util functions

  defp terminate_on_error(error, data) do
    {:next_state, :deployment_failure, data, internal_event({:failure, error})}
  end

  defp terminate_deployer(release_id) do
    Logger.info("Terminating deployer process for release #{release_id}",
      tag: "terminating_deployment"
    )

    {:stop, :normal}
  end

  defp internal_event(payload) do
    {:next_event, :internal, payload}
  end
end
