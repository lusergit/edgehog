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

defmodule Edgehog.Campaigns.Channel.Changes.UnrelateCurrentTargetGroups do
  @moduledoc false
  use Ash.Resource.Change

  alias Edgehog.Groups.DeviceGroup

  require Ash.Query

  @impl Ash.Resource.Change
  def change(changeset, _opts, context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      unrelate_target_groups(context, changeset)
    end)
  end

  defp unrelate_target_groups(context, changeset) do
    channel_id = changeset.data.id

    keep_ids =
      if changeset.action.type == :update do
        Ash.Changeset.get_argument(changeset, :target_group_ids) || []
      else
        []
      end

    query =
      DeviceGroup
      |> Ash.Query.for_read(:read, %{}, scope: context)
      |> Ash.Query.filter(channel_id == ^channel_id)

    query =
      if keep_ids == [] do
        query
      else
        Ash.Query.filter(query, id not in ^keep_ids)
      end

    groups_to_unrelate = Ash.read!(query, scope: context)

    Enum.reduce_while(groups_to_unrelate, changeset, fn group, acc ->
      case Ash.update(group, %{}, action: :unassign_channel, scope: context) do
        {:ok, _updated} ->
          {:cont, acc}

        {:error, error} ->
          message =
            "Cannot remove group #{group.name} while this channel has a running campaign."

          {:halt,
           Ash.Changeset.add_error(acc,
             field: :target_group_ids,
             message: message,
             vars: [cause: Exception.message(error)]
           )}
      end
    end)
  end
end
