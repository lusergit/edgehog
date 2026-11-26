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

defmodule Edgehog.Containers.Release.Deployment.Changes.AuditLifecycle do
  @moduledoc """
  An `Ash.Resource.Change` that registers a semantic lifecycle audit event via
  `Edgehog.Containers.Release.Deployment.Audit` after the action transaction
  succeeds.
  """

  use Ash.Resource.Change

  alias Edgehog.Containers.Release.Deployment.Audit

  @allowed_events [
    :deployment_initiated,
    :undeployment_initiated,
    :undeployment_succeeded,
    :start_initiated,
    :start_succeeded,
    :stop_initiated,
    :stop_succeeded,
    :upgrade_initiated
  ]

  @impl Ash.Resource.Change
  def init(opts) do
    case Keyword.fetch(opts, :event) do
      {:ok, event} when event in @allowed_events -> {:ok, opts}
      {:ok, invalid} -> {:error, "Unsupported lifecycle audit event: #{inspect(invalid)}"}
      :error -> {:error, "Missing required option :event"}
    end
  end

  @impl Ash.Resource.Change
  def change(%{valid?: false} = changeset, _opts, _context), do: changeset
  def change(changeset, opts, context), do: attach_hook(changeset, opts, context)

  @impl Ash.Resource.Change
  def atomic(%{valid?: false} = changeset, _opts, _context), do: {:ok, changeset}
  def atomic(changeset, opts, context), do: {:ok, attach_hook(changeset, opts, context)}

  defp attach_hook(changeset, opts, %{tenant: tenant} = context) do
    event = Keyword.fetch!(opts, :event)
    actor = Map.get(context, :actor)

    # Capture deployment metadata before destroy removes related release and containers
    preloaded_metadata =
      if changeset.action_type == :destroy do
        Audit.build_metadata(changeset.data, tenant, actor: actor)
      end

    Ash.Changeset.after_transaction(changeset, fn
      changeset, {:ok, deployment} ->
        target =
          preloaded_metadata ||
            if changeset.action_type == :create, do: deployment, else: changeset.data

        dispatch_event(event, target, tenant, actor: actor)
        {:ok, deployment}

      _changeset, {:error, error} ->
        {:error, error}
    end)
  end

  defp dispatch_event(:deployment_initiated, target, tenant, opts),
    do: Audit.deployment_initiated(target, tenant, opts)

  defp dispatch_event(:undeployment_initiated, target, tenant, opts),
    do: Audit.undeployment_initiated(target, tenant, opts)

  defp dispatch_event(:undeployment_succeeded, target, tenant, opts),
    do: Audit.undeployment_succeeded(target, tenant, opts)

  defp dispatch_event(:start_initiated, target, tenant, opts),
    do: Audit.start_initiated(target, tenant, opts)

  defp dispatch_event(:start_succeeded, target, tenant, opts),
    do: Audit.start_succeeded(target, tenant, opts)

  defp dispatch_event(:stop_initiated, target, tenant, opts),
    do: Audit.stop_initiated(target, tenant, opts)

  defp dispatch_event(:stop_succeeded, target, tenant, opts),
    do: Audit.stop_succeeded(target, tenant, opts)

  defp dispatch_event(:upgrade_initiated, target, tenant, opts),
    do: Audit.upgrade_initiated(target, tenant, opts)
end
