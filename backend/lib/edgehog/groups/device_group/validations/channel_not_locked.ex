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

defmodule Edgehog.Groups.DeviceGroup.Validations.ChannelNotLocked do
  @moduledoc """
  Prevents removing or moving a `DeviceGroup` away from a rollout channel that
  currently has a running or paused campaign.
  """
  use Ash.Resource.Validation

  alias Edgehog.Campaigns.Channel

  @impl Ash.Resource.Validation
  def validate(changeset, _opts, context) do
    current_channel_id = changeset.data.channel_id
    new_channel_id = Ash.Changeset.get_attribute(changeset, :channel_id)

    if not is_nil(current_channel_id) and new_channel_id != current_channel_id do
      check_channel_unlocked(changeset.data, current_channel_id, context.tenant)
    else
      :ok
    end
  end

  @impl Ash.Resource.Validation
  def batch_callbacks?(_changeset, _opts, _context), do: false

  @impl Ash.Resource.Validation
  def has_batch_validate?, do: false

  defp check_channel_unlocked(group, channel_id, tenant) do
    case Ash.get(Channel, channel_id,
           load: [:has_running_campaign],
           tenant: tenant,
           authorize?: false
         ) do
      {:ok, %Channel{has_running_campaign: true, handle: handle}} ->
        {:error,
         field: :channel_id,
         message:
           "Cannot move group #{group.name} because its channel (@#{handle}) has a running campaign.",
         short_message: "Channel has a running campaign"}

      _ ->
        :ok
    end
  end
end
