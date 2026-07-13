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

defmodule Edgehog.Containers.Network.Deployment.Provisioner.Core do
  @moduledoc """
  Network deployment core functions

  This module contains all functions required by the provisioner that handle the business logic
  e.g., sending data to the device
  """

  alias Edgehog.Devices

  require Logger

  def send(network_deployment, opts) do
    tenant = Keyword.fetch!(opts, :tenant)
    deployment = Keyword.fetch!(opts, :deployment)

    with {:ok, network_deployment} <-
           Ash.load(network_deployment, [:network, :device], tenant: tenant),
         {:ok, network} <-
           Map.fetch(network_deployment, :network),
         {:ok, device} <- Map.fetch(network_deployment, :device),
         {:ok, device} <-
           Devices.send_create_network_request(device, network, deployment, tenant: tenant) do
      Logger.info("""
        network #{network.id} provisioned on device #{device.device_id}. Waiting events
      """)

      :ok
    end
  end
end
