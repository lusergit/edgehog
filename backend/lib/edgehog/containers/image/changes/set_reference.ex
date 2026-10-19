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

defmodule Edgehog.Containers.Image.Changes.SetReference do
  @moduledoc """
  Image change to compose the create input arguments into a cohesive image reference.
  """

  use Ash.Resource.Change

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    registry_host = Ash.Changeset.get_argument(changeset, :registry_host)
    registry_port = Ash.Changeset.get_argument(changeset, :registry_port)
    repo = Ash.Changeset.get_argument(changeset, :image_repo)
    name = Ash.Changeset.get_argument(changeset, :image_name)
    tag = Ash.Changeset.get_argument(changeset, :tag)
    digest = Ash.Changeset.get_argument(changeset, :digest)

    first_segment =
      case {registry_host, registry_port} do
        {nil, _} -> ""
        {host, nil} -> "#{host}/"
        {host, port} -> "#{host}:#{port}/"
      end

    second_segment =
      if repo,
        do: repo <> "/",
        else: ""

    third_segment =
      case {tag, digest} do
        {nil, nil} -> ""
        {nil, digest} -> ":" <> digest
        {tag, nil} -> ":" <> tag
      end

    full_ref = first_segment <> second_segment <> name <> third_segment

    Ash.Changeset.change_attribute(changeset, :reference, full_ref)
  end
end
