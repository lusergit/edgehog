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

defmodule Edgehog.Campaigns.Channel.SystemModelCount do
  @moduledoc """
  Embedded struct representing the count of reachable devices for a specific
  `SystemModel` within a rollout channel's fleet reach.
  """
  use Ash.Resource,
    data_layer: :embedded,
    extensions: [AshGraphql.Resource]

  graphql do
    type :channel_system_model_count
  end

  attributes do
    attribute :id, :integer do
      public? true
      allow_nil? false
      description "The ID of the system model."
    end

    attribute :name, :string do
      public? true
      allow_nil? false
      description "The display name of the system model."
    end

    attribute :handle, :string do
      public? true
      allow_nil? false
      description "The handle of the system model."
    end

    attribute :device_count, :integer do
      public? true
      allow_nil? false
      description "The number of reachable devices with this system model."
    end
  end
end
