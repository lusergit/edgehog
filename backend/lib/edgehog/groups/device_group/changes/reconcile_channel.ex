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

defmodule Edgehog.Groups.DeviceGroup.Changes.ReconcileChannel do
  @moduledoc """
  Handles optional `channel_id` assignment or unassignment during `DeviceGroup`
  `:create` and `:update` actions.

  When `:channel_id` is omitted from the action arguments, the existing
  `channel_id` attribute is left untouched.
  """
  use Ash.Resource.Change

  alias Edgehog.Campaigns.Channel

  @impl Ash.Resource.Change
  def change(changeset, _opts, context) do
    if Map.has_key?(changeset.arguments, :channel_id) do
      reconcile(changeset, Map.get(changeset.arguments, :channel_id), context.tenant)
    else
      changeset
    end
  end

  defp reconcile(changeset, nil, _tenant) do
    Ash.Changeset.force_change_attribute(changeset, :channel_id, nil)
  end

  defp reconcile(changeset, channel_id, tenant) do
    case Ash.get(Channel, channel_id, tenant: tenant, authorize?: false) do
      {:ok, %Channel{id: id}} ->
        Ash.Changeset.force_change_attribute(changeset, :channel_id, id)

      {:error, _reason} ->
        Ash.Changeset.add_error(changeset,
          field: :channel_id,
          message: "Channel could not be found"
        )
    end
  end
end
