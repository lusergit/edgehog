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

defmodule Edgehog.Containers.Deployment.Starter.Core do
  @moduledoc """
  Deployment starter core functions.

  This is a collection of pure functions that handle the business logic. They
  primarely are functions that interact with other parts of the application
  (e.g., read the database, send signals, subscribe to events, etc.).
  """

  alias Edgehog.Containers.Deployment
  alias Edgehog.Containers.Deployment.Starter, as: Data

  require Ash.Query

  @doc """
  Loads pending deployments into the state.

  Runs an `Ash.Query` to load all deployments in a :pending state and populates
  the state in the :deployments key.
  """
  def load(state) do
    %Data{
      tenant: tenant,
      device: device
    } = state

    device_id = device.id

    deployments_query =
      Deployment
      |> Ash.Query.filter(state: :pending)
      |> Ash.Query.filter(device_id: device_id)
      |> Ash.read(tenant: tenant)

    with {:ok, deployments} <- deployments_query do
      new_state = %Data{state | deployments: deployments}

      {:ok, new_state}
    end
  end

  def start(state) do
    %Data{deployments: deployments} = state

    deployments
    |> Enum.reduce([], &start_deployment/2)
    |> maybe_error(state)
  end

  # For the time being, `supervise` is not returing errors
  # TODO: when it will, update this to gather errors
  defp start_deployment(deployment, errors) do
    Deployment.Supervisor.supervise(deployment, tenant)

    errors
  end

  defp maybe_error([], state), do: {:ok, state}
  defp maybe_error(errors, _state), do: {:errors, errors}
end
