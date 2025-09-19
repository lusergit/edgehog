#
# This file is part of Edgehog.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Edgehog.Containers.Container.Changes.DeployContainerOnDevice do
  @moduledoc false
  use Ash.Resource.Change

  alias Edgehog.Containers
  alias Edgehog.Devices

  require Logger

  @impl Ash.Resource.Change
  def change(changeset, _opts, %{tenant: tenant}) do
    deployment = changeset.data |> Ash.load!([:device, :container], tenant: tenant)
    device = deployment.device
    container = deployment.container

    Ash.Changeset.after_action(changeset, fn changeset, deployment ->
      case Devices.send_create_container_request(device, container, deployment) do
        {:ok, _device} -> Ash.Changeset.for_update(changeset, :mark_as_sent, tenant: tenant)
        {:error, reason} ->
          Logger.warning("Failed to send container deployment request: #{inspect(reason)}")
          Ash.Changeset.add_error(changeset, send_error(reason))
      end
    end)
  end

  # TODO: provvisory, make something that makes sense here
  defp send_error(reason), do: %Edgehog.Error.AstarteAPIError{status: 500, response: reason}
end
