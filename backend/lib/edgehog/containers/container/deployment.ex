#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Edgehog.Containers.Container.Deployment do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Containers.Container.Calculations
  alias Edgehog.Containers.Container.Changes

  graphql do
    type :container_deployment
  end

  actions do
    defaults [:read, :destroy]

    create :deploy do
      description """
      Deploys an image on a device, the status according to device triggers.
      """

      accept [:container_id]

      argument :device_id, :id do
        allow_nil? false
      end

      change set_attribute(:state, :created)
      change manage_relationship(:device_id, :device, type: :append)
      change Changes.DeployContainerOnDevice
    end

    update :sent do
      change set_attribute(:state, :sent)
    end

    update :received do
      change set_attribute(:state, :received)
    end

    update :created do
      change set_attribute(:state, :device_created)
    end

    update :stopped do
      change set_attribute(:state, :stopped)
    end

    update :running do
      change set_attribute(:state, :running)
    end

    update :errored do
      argument :message, :string do
        allow_nil? false
      end

      change set_attribute(:last_message, arg(:message))
      change set_attribute(:state, :error)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :last_message, :string

    attribute :state, :atom,
      constraints: [
        one_of: [:created, :sent, :received, :device_created, :stopped, :running, :error]
      ]

    timestamps()
  end

  relationships do
    belongs_to :container, Edgehog.Containers.Container do
      attribute_type :uuid
      public? true
    end

    belongs_to :device, Edgehog.Devices.Device
  end

  calculations do
    calculate :ready?, :boolean, Calculations.ContainerReady
  end

  identities do
    identity :container_instance, [:container_id, :device_id]
  end

  postgres do
    table "container_deployments"

    references do
      reference :container, on_delete: :delete
      reference :device, on_delete: :delete
    end
  end
end
