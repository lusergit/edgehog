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

defmodule Edgehog.Containers.ImagePolicy.RegistryId do
  @moduledoc """
  Computes the deterministic `registry_id` thumbprint from an image policy's
  repository scope string.

  Encapsulated in a dedicated module so the derivation algorithm can be
  adjusted in one place without requiring database migrations.
  """

  @spec compute(String.t()) :: String.t()
  def compute(repository) when is_binary(repository) do
    :sha256
    |> :crypto.hash(repository)
    |> Base.encode16(case: :lower)
  end
end
