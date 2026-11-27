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

defmodule Edgehog.Containers.ImagePolicy do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Containers.ImagePolicy.Changes
  alias Edgehog.Containers.ImagePolicy.Types
  alias Edgehog.Containers.ImagePolicy.Validations
  alias Edgehog.Containers.PublicKey

  resource do
    description """
    Defines a container image verification policy for a target registry or
    repository scope (either rejecting matching images or requiring them to be
    signed by a specific public key).
    """
  end

  graphql do
    type :image_policy

    subscriptions do
      pubsub EdgehogWeb.Endpoint

      subscribe :image_policy do
        actions [:create, :destroy]
      end
    end

    paginate_relationship_with devices: :relay,
                               image_policy_deployments: :relay
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:repository, :type]

      argument :public_key_id, :uuid

      change Changes.ComputeRegistryId

      change manage_relationship(:public_key_id, :public_key, type: :append),
        where: [present(:public_key_id)]
    end
  end

  validations do
    validate {Validations.RepositoryScope, []} do
      where [present(:repository)]
    end

    validate present(:public_key_id) do
      where [attribute_equals(:type, :signed_by)]
      message "must be present when policy type is signed_by"
    end

    validate absent(:public_key_id) do
      where [attribute_equals(:type, :reject)]
      message "must not be set when policy type is reject"
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :repository, :string do
      description "The container registry or repository scope to which this policy applies."
      allow_nil? false
      public? true
    end

    attribute :registry_id, :string do
      description "The deterministic thumbprint derived from the repository scope used on devices."
      allow_nil? false
      writable? false
      public? true
    end

    attribute :type, Types.PolicyType do
      description "The verification policy requirement applied to images matching this repository."
      allow_nil? false
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :public_key, PublicKey do
      description "The trusted public key used when policy type is signed_by."
      attribute_type :uuid
      attribute_public? false
      allow_nil? true
      public? true
    end

    has_many :image_policy_deployments, Edgehog.Containers.ImagePolicy.Deployment do
      source_attribute :registry_id
      destination_attribute :registry_id
      public? true
    end

    many_to_many :devices, Edgehog.Devices.Device do
      through Edgehog.Containers.ImagePolicy.Deployment
      join_relationship :image_policy_deployments
      source_attribute :registry_id
      source_attribute_on_join_resource :registry_id
      destination_attribute_on_join_resource :device_id
      public? true
    end
  end

  identities do
    identity :unique_repository, [:repository]
    identity :unique_registry_id, [:registry_id]
  end

  postgres do
    table "image_policies"

    references do
      reference :public_key, on_delete: :nothing, match_with: [tenant_id: :tenant_id]
    end
  end
end
