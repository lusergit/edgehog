#
# This file is part of Edgehog.
#
# Copyright 2025 - 2026 SECO Mind Srl
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

defmodule Edgehog.Campaigns.Status do
  @moduledoc false
  use Ash.Type.Enum,
    values: [
      idle: "The campaign has been created but is not being rolled-out yet.",
      scheduled: "The campaign has been scheduled to start at a future time.",
      in_progress: "The campaign is being rolled-out.",
      pausing: "The campaign rollout is being paused.",
      paused: "The campaign rollout is temporarily suspended.",
      finished: "The campaign has finished."
    ]

  @active_statuses [:idle, :scheduled, :in_progress, :pausing, :paused]
  @running_statuses [:idle, :in_progress, :pausing, :paused]

  def active_statuses, do: @active_statuses
  def running_statuses, do: @running_statuses

  def active?(status), do: status in @active_statuses
  def running?(status), do: status in @running_statuses

  def graphql_type(_), do: :campaign_status
end
