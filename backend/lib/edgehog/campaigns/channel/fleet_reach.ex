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

defmodule Edgehog.Campaigns.Channel.FleetReach do
  @moduledoc """
  Embedded struct representing a rollout channel's deduplicated device reach,
  online device count, and per-system-model breakdown.
  """
  use Ash.Resource,
    data_layer: :embedded,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Campaigns.Channel.SystemModelCount

  graphql do
    type :channel_fleet_reach
  end

  attributes do
    attribute :total_count, :integer do
      public? true
      allow_nil? false
      default 0
      description "The deduplicated total number of devices reachable by the channel."
    end

    attribute :online_count, :integer do
      public? true
      allow_nil? false
      default 0
      description "The number of reachable devices currently online."
    end

    attribute :system_model_counts, {:array, SystemModelCount} do
      public? true
      allow_nil? false
      default []
      description "Breakdown of reachable devices by system model."
    end
  end
end
