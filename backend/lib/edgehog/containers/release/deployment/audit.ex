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

defmodule Edgehog.Containers.Release.Deployment.Audit do
  @moduledoc """
  Emits structured `Edgehog.Audit.AuditService` events for the lifecycle of a
  `Edgehog.Containers.Release.Deployment` (provisioning, deletion, start, stop,
  and upgrade).
  """

  alias Edgehog.Audit.AuditService
  alias Edgehog.Containers.Release.Deployment

  require Logger

  @deployment_loads [:device, release: [:application, :containers]]

  @type deployment_or_metadata :: Deployment.t() | map()

  @doc """
  Builds the base audit metadata map for a deployment by loading its device,
  application, release, and container names.

  Calling this before a destructive action (such as `:destroy_and_gc`) captures
  the metadata snapshot before related records are removed from the database.
  """
  @spec build_metadata(Deployment.t(), term(), keyword()) :: map()
  def build_metadata(%Deployment{} = deployment, tenant, opts \\ []) do
    actor = Keyword.get(opts, :actor)
    loaded = load_deployment(deployment, tenant)

    metadata = %{
      resource_type: "release_deployment",
      resource_id: deployment.id,
      device_id: device_id(loaded),
      application_name: application_name(loaded),
      release_version: release_version(loaded),
      container_names: container_names(loaded)
    }

    maybe_put_username(metadata, actor)
  end

  @doc "Audits the initiation of a release deployment provisioning."
  @spec deployment_initiated(deployment_or_metadata(), term(), keyword()) :: :ok
  def deployment_initiated(target, tenant, opts \\ []) do
    emit(
      :info,
      "deployment_init",
      "Deployment #{resource_id(target)} provisioning started.",
      target,
      tenant,
      opts
    )
  end

  @doc "Audits the successful completion of a release deployment provisioning."
  @spec deployment_succeeded(deployment_or_metadata(), term(), keyword()) :: :ok
  def deployment_succeeded(target, tenant, opts \\ []) do
    emit(
      :info,
      "deployment_ok",
      "Deployment #{resource_id(target)} successfully provisioned.",
      target,
      tenant,
      opts
    )
  end

  @doc "Audits the failure of a release deployment provisioning."
  @spec deployment_failed(deployment_or_metadata(), term(), term(), keyword()) :: :ok
  def deployment_failed(target, tenant, reason, opts \\ []) do
    extra = %{error: format_reason(reason)}

    emit(
      :error,
      "deployment_fail",
      "Deployment #{resource_id(target)} provisioning failed.",
      target,
      tenant,
      Keyword.put(opts, :extra, extra)
    )
  end

  @doc "Audits the submission of a release deployment delete (undeployment) command."
  @spec undeployment_initiated(deployment_or_metadata(), term(), keyword()) :: :ok
  def undeployment_initiated(target, tenant, opts \\ []) do
    emit(
      :info,
      "undeployment_init",
      "Deployment #{resource_id(target)} delete command sent.",
      target,
      tenant,
      opts
    )
  end

  @doc "Audits the successful removal of a release deployment."
  @spec undeployment_succeeded(deployment_or_metadata(), term(), keyword()) :: :ok
  def undeployment_succeeded(target, tenant, opts \\ []) do
    emit(
      :info,
      "undeployment_ok",
      "Deployment #{resource_id(target)} successfully deleted.",
      target,
      tenant,
      opts
    )
  end

  @doc "Audits a failed release deployment deletion."
  @spec undeployment_failed(deployment_or_metadata(), term(), keyword()) :: :ok
  def undeployment_failed(target, tenant, opts \\ []) do
    emit(
      :error,
      "undeployment_fail",
      "Deployment #{resource_id(target)} deletion failed.",
      target,
      tenant,
      opts
    )
  end

  @doc "Audits the submission of a release deployment start command."
  @spec start_initiated(deployment_or_metadata(), term(), keyword()) :: :ok
  def start_initiated(target, tenant, opts \\ []) do
    emit(
      :info,
      "start_init",
      "Deployment #{resource_id(target)} start command sent.",
      target,
      tenant,
      opts
    )
  end

  @doc "Audits the successful start of a release deployment."
  @spec start_succeeded(deployment_or_metadata(), term(), keyword()) :: :ok
  def start_succeeded(target, tenant, opts \\ []) do
    emit(
      :info,
      "start_ok",
      "Deployment #{resource_id(target)} successfully started.",
      target,
      tenant,
      opts
    )
  end

  @doc "Audits a failed release deployment start."
  @spec start_failed(deployment_or_metadata(), term(), keyword()) :: :ok
  def start_failed(target, tenant, opts \\ []) do
    emit(
      :error,
      "start_fail",
      "Deployment #{resource_id(target)} failed to start.",
      target,
      tenant,
      opts
    )
  end

  @doc "Audits the submission of a release deployment stop command."
  @spec stop_initiated(deployment_or_metadata(), term(), keyword()) :: :ok
  def stop_initiated(target, tenant, opts \\ []) do
    emit(
      :info,
      "stop_init",
      "Deployment #{resource_id(target)} stop command sent.",
      target,
      tenant,
      opts
    )
  end

  @doc "Audits the successful stop of a release deployment."
  @spec stop_succeeded(deployment_or_metadata(), term(), keyword()) :: :ok
  def stop_succeeded(target, tenant, opts \\ []) do
    emit(
      :info,
      "stop_ok",
      "Deployment #{resource_id(target)} successfully stopped.",
      target,
      tenant,
      opts
    )
  end

  @doc "Audits a failed release deployment stop."
  @spec stop_failed(deployment_or_metadata(), term(), keyword()) :: :ok
  def stop_failed(target, tenant, opts \\ []) do
    emit(
      :error,
      "stop_fail",
      "Deployment #{resource_id(target)} failed to stop.",
      target,
      tenant,
      opts
    )
  end

  @doc "Audits the submission of a release deployment upgrade command."
  @spec upgrade_initiated(deployment_or_metadata(), term(), keyword()) :: :ok
  def upgrade_initiated(target, tenant, opts \\ []) do
    emit(
      :info,
      "upgrade_init",
      "Deployment #{resource_id(target)} upgrade command sent.",
      target,
      tenant,
      opts
    )
  end

  @doc "Audits a failed release deployment upgrade."
  @spec upgrade_failed(deployment_or_metadata(), term(), keyword()) :: :ok
  def upgrade_failed(target, tenant, opts \\ []) do
    emit(
      :error,
      "upgrade_fail",
      "Deployment #{resource_id(target)} upgrade failed.",
      target,
      tenant,
      opts
    )
  end

  @doc """
  Audits a device-reported `DeploymentEvent` error based on `deployment.context`.

  Returns `:ok` if a pending command context was matched and audited, or `:noop`
  when `deployment.context` is `nil`.
  """
  @spec audit_error_event(Deployment.t(), map(), term()) :: :ok | :noop
  def audit_error_event(%Deployment{context: nil}, _raw_event, _tenant), do: :noop

  def audit_error_event(%Deployment{context: context} = deployment, raw_event, tenant) do
    extra = error_event_extra(raw_event)

    case context do
      :start_message_sent -> start_failed(deployment, tenant, extra: extra)
      :stop_message_sent -> stop_failed(deployment, tenant, extra: extra)
      :delete_message_sent -> undeployment_failed(deployment, tenant, extra: extra)
      :upgrade_message_sent -> upgrade_failed(deployment, tenant, extra: extra)
    end
  end

  defp emit(level, event_name, message, target, tenant, opts) do
    extra = Keyword.get(opts, :extra, %{})

    metadata =
      target
      |> resolve_metadata(tenant, opts)
      |> Map.put(:event, event_name)
      |> Map.merge(extra)

    case AuditService.register_event(message, level, nil, metadata, tenant: tenant) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to register the deployment audit event: #{inspect(reason)}")
        :ok
    end
  end

  defp resolve_metadata(%Deployment{} = deployment, tenant, opts) do
    build_metadata(deployment, tenant, opts)
  end

  defp resolve_metadata(metadata, _tenant, _opts) when is_map(metadata), do: metadata

  defp load_deployment(deployment, tenant) do
    case Ash.load(deployment, @deployment_loads, tenant: tenant, reuse_values?: true) do
      {:ok, loaded} ->
        loaded

      {:error, reason} ->
        Logger.warning(
          "Failed to load metadata for deployment #{deployment.id} audit event: #{inspect(reason)}"
        )

        deployment
    end
  end

  defp resource_id(%Deployment{id: id}), do: id
  defp resource_id(%{resource_id: id}), do: id

  defp device_id(%{device: %{device_id: device_id}}), do: device_id
  defp device_id(_deployment), do: nil

  defp application_name(%{release: %{application: %{name: name}}}), do: name
  defp application_name(_deployment), do: nil

  defp release_version(%{release: %{version: version}}), do: version
  defp release_version(_deployment), do: nil

  defp container_names(%{release: %{containers: containers}}) when is_list(containers) do
    containers
    |> Enum.map(& &1.name)
    |> Enum.sort()
  end

  defp container_names(_deployment), do: []

  defp maybe_put_username(metadata, actor) when is_map(actor) do
    username = Map.get(actor, :preferred_username) || Map.get(actor, "preferred_username")

    if is_binary(username) and username != "" do
      Map.put(metadata, :username, username)
    else
      metadata
    end
  end

  defp maybe_put_username(metadata, _actor), do: metadata

  defp error_event_extra(raw_event) do
    %{}
    |> maybe_put_non_empty_string(:error, Map.get(raw_event, :message))
    |> maybe_put_non_empty_list(:add_info, Map.get(raw_event, :add_info))
  end

  defp maybe_put_non_empty_string(map, key, value) when is_binary(value) and value != "" do
    Map.put(map, key, value)
  end

  defp maybe_put_non_empty_string(map, _key, _value), do: map

  defp maybe_put_non_empty_list(map, key, value) when is_list(value) and value != [] do
    Map.put(map, key, value)
  end

  defp maybe_put_non_empty_list(map, _key, _value), do: map

  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason), do: inspect(reason)
end
