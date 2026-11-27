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

defmodule Edgehog.Containers.ImagePolicy.RegistryIdTest do
  use ExUnit.Case, async: true

  alias Edgehog.Containers.ImagePolicy.RegistryId

  describe "compute/1" do
    test "returns lowercase hex SHA-256 of the repository scope" do
      expected =
        :sha256
        |> :crypto.hash("docker.io/library")
        |> Base.encode16(case: :lower)

      assert RegistryId.compute("docker.io/library") == expected
      assert String.length(expected) == 64
    end

    test "is deterministic and distinguishes distinct repository scopes" do
      assert RegistryId.compute("quay.io/my-org") == RegistryId.compute("quay.io/my-org")
      assert RegistryId.compute("quay.io/my-org") != RegistryId.compute("quay.io/other-org")
    end
  end
end
