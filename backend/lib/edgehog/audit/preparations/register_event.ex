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

defmodule Edgehog.Audit.Preparations.RegisterEvent do
  @moduledoc """
  A preparation that registers an audit event about the manual action
  being run on the resource, through `Edgehog.Audit.AuditService`.

  The event is registered after the action completed, for both success and failures,
  and the auditing never fails the action.

  Read actions are currently not implemented.
  For create, update and destroy actions, see `Edgehog.Audit.Changes.RegisterEvent`
  instead.

  Opts:
  - `:actor?`   :: boolean. Whether to include the actor (present in the context,
    if any) in the registered event. Defaults to `true`.
  - `:metadata` :: map, optional. the metadata to be registered with the event,
    which can also include information usually returned by other action types,
    like a record id created or edited through the action
  """
  use Ash.Resource.Preparation

  alias Edgehog.Audit.AuditService

  require Logger

  @needed_keys [:actor?]

  @impl Ash.Resource.Preparation
  def init(opts) do
    opts = Keyword.put_new(opts, :metadata, %{})
    {_, errors} = Enum.reduce(@needed_keys, {opts, []}, &error_if_not_present/2)

    if Enum.empty?(errors) do
      {:ok, opts}
    else
      {:error, errors}
    end
  end

  # by default, preparations support only Ash.Query
  @impl Ash.Resource.Preparation
  def supports(_opts), do: [Ash.ActionInput]

  @impl Ash.Resource.Preparation
  def prepare(subject, opts, context) do
    attach_hooks(subject, opts, context)
  end

  defp attach_hooks(subject, opts, context) do
    Ash.Subject.after_transaction(subject, fn
      subject, {:error, error} ->
        register_failure(subject, error, opts, context)
        {:error, error}

      subject, result ->
        register_success(subject, opts, context)
        result
    end)
  end

  defp register_success(subject, opts, context) do
    info = event_info(subject, opts, context)
    message = "Running #{subject.resource}.#{subject.action.name}"

    register_event(&AuditService.info/2, message, info, context, opts[:metadata])
  end

  defp register_failure(subject, error, opts, context) do
    info = event_info(subject, opts, context)
    metadata = Map.put(opts[:metadata], :error, serialize_error(error))
    message = "Failed to run #{subject.resource}.#{subject.action.name}"

    register_event(&AuditService.error/2, message, info, context, metadata)
  end

  defp register_event(register, message, info, context, metadata) do
    case register.(
           message,
           ash_action_info: info,
           metadata: metadata,
           tenant: context.tenant
         ) do
      :ok ->
        :ok

      {:error, reason} ->
        # Ash storage failure must never affect the audited action
        Logger.error("Failed to register the audit event: #{inspect(reason)}")
        :ok
    end
  end

  defp event_info(subject, opts, context) do
    resource = subject.resource
    action = subject.action

    # the result of a manual action is an arbitrary value, not a record: there
    # is no automatic record_id to point at; it could be read from the metadata
    # opt in the future, if required
    %{
      resource_module: resource,
      record_id: nil,
      action_name: action.name,
      action_type: action.type,
      action_inputs: action_inputs(subject),
      changed_attributes: %{},
      actor: maybe_actor(opts, context)
    }
  end

  defp maybe_actor(opts, context) do
    if Keyword.fetch!(opts, :actor?), do: maybe_actor(context.actor), else: nil
  end

  defp maybe_actor(actor) when is_struct(actor) do
    actor
    |> Map.from_struct()
    |> maybe_actor()
  end

  defp maybe_actor(actor) when is_map(actor) do
    Map.filter(actor, fn {_key, value} -> json_encodable?(value) end)
  end

  defp maybe_actor(_actor), do: nil

  defp action_inputs(subject) do
    subject.arguments
    |> Enum.filter(fn {_key, value} -> json_encodable?(value) end)
    |> Map.new()
  end

  # values that cannot be Jason-encoded (e.g. Plug.Upload or Ecto.Schema.Metadata)
  # make the audit event fail to store: skip them instead.
  defp json_encodable?(value) do
    match?({:ok, _}, Jason.encode(value))
  rescue
    _ -> false
  end

  # Ash error structs
  defp serialize_error(error) when is_exception(error), do: Exception.message(error)

  defp serialize_error(errors) when is_list(errors),
    do: Enum.map_join(errors, "; ", &serialize_error/1)

  defp serialize_error(error), do: inspect(error)

  defp error_if_not_present(key, {opts, errors}) do
    error = "Missing key #{inspect(key)}."

    if Keyword.has_key?(opts, key) do
      {opts, errors}
    else
      {opts, [error | errors]}
    end
  end
end
