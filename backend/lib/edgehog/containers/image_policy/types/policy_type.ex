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

defmodule Edgehog.Containers.ImagePolicy.Types.PolicyType do
  @moduledoc """
  Expresses the image verification policy requirement for a repository scope.
  """

  use Ash.Type.Enum,
    values: [
      reject: "Reject images matching the repository scope.",
      signed_by:
        "Require images matching the repository scope to be signed by the specified public key."
    ]

  def graphql_type(_), do: :image_policy_type
end
