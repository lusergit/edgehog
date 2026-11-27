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

defmodule Edgehog.Containers.ImagePolicy.Deployment.Provisioner.Core do
  @moduledoc """
  The module describing the Core functions required by the image policy deployment provisioner.

  For more information, check the `Edgehog.Provisioner.Core.Behaviour` docs.
  """
  use Edgehog.Provisioner.Core

  alias Edgehog.Astarte.Device.AvailableImagePolicies.ImagePolicyStatus
  alias Edgehog.Containers.ImagePolicy.Deployment.Provisioner.Audit
  alias Edgehog.Devices

  @impl Edgehog.Provisioner.Core.Behaviour
  def ready?(%{state: state}), do: state in [:present, :missing]

  @impl Edgehog.Provisioner.Core.Behaviour
  def topic(%{id: id}), do: "ready:image_policy_deployments:#{id}"
  def topic(id), do: "ready:image_policy_deployments:#{id}"

  @impl Edgehog.Provisioner.Core.Behaviour
  def subscribe_topic(%{id: id}), do: "image_policy_deployments:#{id}"
  def subscribe_topic(id), do: "image_policy_deployments:#{id}"

  @impl Edgehog.Provisioner.Core.Behaviour
  def name(%{id: id}),
    do: {:via, Registry, {Edgehog.Containers.ImagePolicy.Deployment.Provisioner.Registry, id}}

  @impl Edgehog.Provisioner.Core.Behaviour
  def send_to_device(resource, opts) do
    tenant = Keyword.fetch!(opts, :tenant)

    with {:ok, resource} <-
           Ash.load(resource, [image_policy: [:public_key], device: []], tenant: tenant),
         {:ok, image_policy} <- fetch_image_policy(resource),
         {:ok, device} <- Map.fetch(resource, :device),
         {:ok, device} <- Devices.send_image_policy(device, image_policy, tenant: tenant) do
      _ = Audit.sent_to_device(resource, device, tenant)
      :ok
    end
  end

  @impl Edgehog.Provisioner.Core.Behaviour
  def reconcile(resource, opts) do
    tenant = Keyword.fetch!(opts, :tenant)

    with {:ok, resource} <-
           Ash.load(resource, [device: [:available_image_policies]], tenant: tenant),
         {:ok, %{available_image_policies: available_policies}}
         when is_list(available_policies) <-
           Map.fetch(resource, :device) do
      available_policies
      |> Enum.find(:not_found, &(&1.id == resource.registry_id))
      |> maybe_update(resource, tenant)
    else
      {:ok, %{available_image_policies: nil}} -> :not_found
      error -> error
    end
  end

  defp fetch_image_policy(%{image_policy: nil}), do: {:error, :image_policy_not_found}

  defp fetch_image_policy(%{image_policy: %{type: :signed_by, public_key: nil}}),
    do: {:error, :public_key_not_found}

  defp fetch_image_policy(%{image_policy: image_policy}), do: {:ok, image_policy}

  defp maybe_update(%ImagePolicyStatus{status: :present}, resource, tenant) do
    resource
    |> Ash.Changeset.for_update(:mark_as_present)
    |> Ash.update(tenant: tenant)
  end

  defp maybe_update(%ImagePolicyStatus{status: :missing}, resource, tenant) do
    resource
    |> Ash.Changeset.for_update(:mark_as_missing)
    |> Ash.update(tenant: tenant)
  end

  defp maybe_update(%ImagePolicyStatus{status: :error}, %{state: :error}, _tenant), do: :not_found

  defp maybe_update(%ImagePolicyStatus{status: :error}, resource, tenant) do
    resource
    |> Ash.Changeset.for_update(:set_state, %{state: :error})
    |> Ash.update(tenant: tenant)
  end

  defp maybe_update(%ImagePolicyStatus{status: nil}, _resource, _tenant), do: :not_found
  defp maybe_update(other, _resource, _tenant), do: other
end
