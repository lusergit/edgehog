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

defmodule Edgehog.Astarte.Device.AvailableImagePolicies do
  @moduledoc false
  @behaviour Edgehog.Astarte.Device.AvailableImagePolicies.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.AvailableImagePolicies.ImagePolicyStatus

  @interface "io.edgehog.devicemanager.apps.AvailableImagePolicies"

  @impl Edgehog.Astarte.Device.AvailableImagePolicies.Behaviour
  def get(%AppEngine{} = client, device_id) do
    with {:ok, %{"data" => data}} <-
           AppEngine.Devices.get_properties_data(client, device_id, @interface) do
      {:ok, parse_data(data)}
    end
  end

  def parse_data(data) when is_map(data) do
    for {registry_id, properties} when is_map(properties) <- data do
      %ImagePolicyStatus{
        id: registry_id,
        status: parse_status(properties["status"])
      }
    end
  end

  defp parse_status("Present"), do: :present
  defp parse_status("Missing"), do: :missing
  defp parse_status("Error"), do: :error
  defp parse_status(_), do: nil
end
