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

defmodule Edgehog.Containers.DeviceRequest.Deployment.Provisioner.Core do
  @moduledoc """
  Device request deployment core functions

  This module contains all functions required by the provisioner that handle the business logic
  e.g., sending data to the device
  """

  alias Edgehog.Devices

  require Logger

  def send(device_request_deployment, opts) do
    tenant = Keyword.fetch!(opts, :tenant)
    deployment = Keyword.fetch!(opts, :deployment)

    with {:ok, device_request_deployment} <-
           Ash.load(device_request_deployment, [device: [], device_request: [:capabilities]],
             tenant: tenant
           ),
         {:ok, device_request} <-
           Map.fetch(device_request_deployment, :device_request),
         {:ok, device} <- Map.fetch(device_request_deployment, :device),
         {:ok, device} <-
           Devices.send_create_device_request_request(device, device_request, deployment,
             tenant: tenant
           ) do
      Logger.info("""
        Device_Request #{device_request.id} provisioned on device #{device.device_id}. Waiting events
      """)

      :ok
    end
  end
end
