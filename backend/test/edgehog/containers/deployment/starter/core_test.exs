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

defmodule Edgehog.Containers.Deployment.Starter.CoreTest do
  @moduledoc false

  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.TenantsFixtures
  import Edgehog.DevicesFixtures

  alias Edgehog.Containers.Deployment.Starter, as: Data
  alias Edgehog.Containers.Deployment.Starter.Core

  describe "load/1" do
    setup do
      tenant = tenant_fixture()

      device = device_fixture(tenant: tenant)

      %{tenant: tenant, device: device}
    end

    test "returns all pending deployments", %{tenant: tenant, device: device} do
      d1 = deployment_fixture(state: :pending, device_id: device.id, tenant: tenant)
      d2 = deployment_fixture(state: :pending, device_id: device.id, tenant: tenant)

      # Make some more dpleoyments, these should not be returned
      deployment_fixture(state: :started, device_id: device.id, tenant: tenant)
      deployment_fixture(state: :stopped, device_id: device.id, tenant: tenant)

      state = %Data{
        tenant: tenant,
        device: device
      }

      {:ok, new_state} = Core.load(state)

      %Data{deployments: deployments} = new_state

      expected_deployments =
        [d1, d2]
        |> Enum.map(&%{id: &1.id, state: &1.state})
        |> Enum.sort()

      db_deployments =
        deployments
        |> Enum.map(&%{id: &1.id, state: &1.state})
        |> Enum.sort()

      assert expected_deployments == db_deployments
    end
  end
end
