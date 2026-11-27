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

defmodule Edgehog.Containers.ImagePolicy.Deployment.Changes.SetRegistryId do
  @moduledoc false
  use Ash.Resource.Change

  alias Edgehog.Containers.ImagePolicy

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_argument(changeset, :image_policy) do
      %ImagePolicy{registry_id: registry_id} ->
        Ash.Changeset.force_change_attribute(changeset, :registry_id, registry_id)

      _ ->
        changeset
    end
  end
end
