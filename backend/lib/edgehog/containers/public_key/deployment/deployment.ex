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

defmodule Edgehog.Containers.PublicKey.Deployment do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource],
    notifiers: [Ash.Notifier.PubSub]

  alias Edgehog.Containers.Calculations.ResourceEvents
  alias Edgehog.Containers.PublicKey
  alias Edgehog.Containers.PublicKey.Deployment.Changes
  alias Edgehog.Containers.PublicKey.Deployment.Types
  alias Edgehog.Devices.Device

  resource do
    description """
    Tracks the availability and deployment state of a public key on a device.

    A deployment may reference a key fingerprint reported by the device that
    does not yet have a corresponding cloud-defined `PublicKey`.
    """
  end

  graphql do
    type :public_key_deployment
  end

  actions do
    defaults [:read, :destroy, create: [:public_key_fingerprint, :device_id, :state]]

    create :deploy do
      description """
      Deploys a public key on a device.
      """

      argument :public_key, :struct do
        constraints instance_of: PublicKey
        allow_nil? false
      end

      argument :device, :struct do
        constraints instance_of: Device
        allow_nil? false
      end

      change Changes.SetFingerprint
      change set_attribute(:state, :created)
      change manage_relationship(:device, type: :append)
    end

    create :upsert_from_device do
      description """
      Creates or updates a public key deployment from device-reported availability.
      """

      upsert? true
      upsert_identity :public_key_instance
      upsert_fields [:state, :updated_at]

      accept [:public_key_fingerprint, :device_id, :state]
    end

    update :mark_as_sent do
      change set_attribute(:state, :sent)
    end

    update :mark_as_present do
      change set_attribute(:state, :present)
    end

    update :mark_as_missing do
      change set_attribute(:state, :missing)
    end

    update :mark_as_errored do
      argument :message, :string do
        allow_nil? false
      end

      change set_attribute(:last_message, arg(:message))
      change set_attribute(:state, :error)
    end

    update :set_state do
      accept [:state]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :public_key_fingerprint, :string do
      description "The fingerprint (`key_id`) of the public key on the device."
      allow_nil? false
      public? true
    end

    attribute :state, :atom do
      description "The availability or provisioning state of the public key on the device."
      constraints one_of: [:created, :sent, :present, :missing, :error]
      allow_nil? false
      default :created
      public? true
    end

    attribute :last_message, :string do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :device, Device do
      allow_nil? false
      attribute_public? false
      public? true
    end

    belongs_to :public_key, PublicKey do
      source_attribute :public_key_fingerprint
      destination_attribute :fingerprint
      attribute_type :string
      define_attribute? false
      allow_nil? true
      public? true
    end
  end

  calculations do
    calculate :is_ready, :boolean, expr(state in [:present, :missing]) do
      public? true
    end

    calculate :events,
              {:array, Types.Event},
              {ResourceEvents,
               interface: "io.edgehog.devicemanager.apps.PublicKeyEvent",
               resource_id_key: :public_key_fingerprint,
               event_type: Types.Event} do
      description "Lifecycle events reported by the device for this public key deployment."
      public? true
    end
  end

  identities do
    identity :public_key_instance, [:public_key_fingerprint, :device_id]
  end

  pub_sub do
    prefix "public_key_deployments"
    module EdgehogWeb.Endpoint

    publish :upsert_from_device, [[:id, "*"]]
    publish :mark_as_sent, [[:id, "*"]]
    publish :mark_as_present, [[:id, "*"]]
    publish :mark_as_missing, [[:id, "*"]]
    publish :mark_as_errored, [[:id, "*"]]
    publish :set_state, [[:id, "*"]]
  end

  postgres do
    table "public_key_deployments"

    references do
      reference :device, on_delete: :delete, match_with: [tenant_id: :tenant_id]

      # Devices may report available public keys that are not defined in the cloud
      reference :public_key, ignore?: true
    end
  end
end
