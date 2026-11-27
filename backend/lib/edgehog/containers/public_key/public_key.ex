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

defmodule Edgehog.Containers.PublicKey do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Containers.PublicKey.Changes

  resource do
    description """
    A trusted X.509 certificate used by devices to verify container image
    signatures, uniquely identified on devices by its derived fingerprint.
    """
  end

  graphql do
    type :public_key

    subscriptions do
      pubsub EdgehogWeb.Endpoint

      subscribe :public_key do
        actions [:create, :destroy]
      end
    end

    paginate_relationship_with devices: :relay,
                               image_policies: :relay,
                               public_key_deployments: :relay
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:label, :pem]

      change Changes.ComputeFingerprint
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :label, :string do
      description "A human-readable label identifying this public key."
      allow_nil? false
      public? true
    end

    attribute :pem, :string do
      description "The PEM-encoded X.509 certificate."
      allow_nil? false
      public? true
    end

    attribute :fingerprint, :string do
      description "The certificate fingerprint used to identify this key on devices."
      allow_nil? false
      writable? false
      public? true
    end

    timestamps()
  end

  relationships do
    has_many :image_policies, Edgehog.Containers.ImagePolicy do
      public? true
    end

    has_many :public_key_deployments, Edgehog.Containers.PublicKey.Deployment do
      source_attribute :fingerprint
      destination_attribute :public_key_fingerprint
      public? true
    end

    many_to_many :devices, Edgehog.Devices.Device do
      through Edgehog.Containers.PublicKey.Deployment
      join_relationship :public_key_deployments
      source_attribute :fingerprint
      source_attribute_on_join_resource :public_key_fingerprint
      destination_attribute_on_join_resource :device_id
      public? true
    end
  end

  identities do
    identity :unique_fingerprint, [:fingerprint]
    identity :unique_label, [:label]
  end

  postgres do
    table "public_keys"
  end
end
