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

defmodule Edgehog.Containers.CDI do
  @moduledoc """
  A container CDI.

  CDIs are container device interfaces, and allow containers to use some device
  specific capabilities on demand.

  For example, setting up a CDI with capability `gpu` would allow the container
  to run using the GPU embedded in the controller, without special settings.
  """

  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Containers.Container
  alias Edgehog.Containers.Validations

  graphql do
    type :cdi
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [:path_on_host, :path_in_container, :cgroup_permissions],
      update: [:path_on_host, :path_in_container, :cgroup_permissions]
    ]

    destroy :destroy_if_dangling do
      description "Destroys the network if it's dangling (not referenced by any container)"

      require_atomic? false
      validate Validations.Dangling
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :path_on_host, :string do
      public? true
      allow_nil? false
    end

    attribute :path_in_container, :string do
      public? true
      allow_nil? false
    end

    attribute :cgroup_permissions, :string do
      public? true
      allow_nil? false
    end
  end

  relationships do
    belongs_to :container, Container do
      source_attribute :container_id
      attribute_type :uuid
      public? true
    end
  end

  calculations do
    calculate :dangling?,
              :boolean,
              {Edgehog.Containers.Calculations.Dangling, [parent: :containers]}
  end

  postgres do
    table "cdis"
    repo Edgehog.Repo
  end
end
