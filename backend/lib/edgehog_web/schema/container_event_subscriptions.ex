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

defmodule EdgehogWeb.Schema.ContainerEventSubscriptions do
  @moduledoc false
  use Absinthe.Schema.Notation

  alias AshGraphql.Resource, as: AshGraphqlResource
  alias AshGraphql.Resource.Info, as: AshGraphqlResourceInfo
  alias Edgehog.Containers
  alias Edgehog.Containers.Container
  alias Edgehog.Containers.DeploymentResources
  alias Edgehog.Containers.EnvFile
  alias Edgehog.Containers.FileBind
  alias Edgehog.Containers.Image
  alias Edgehog.Containers.ImagePolicy
  alias Edgehog.Containers.Network
  alias Edgehog.Containers.PublicKey
  alias Edgehog.Containers.Release
  alias Edgehog.Containers.Volume

  union :release_deployment_event_payload do
    description "An event occurring on a release deployment or any of its child container resources."

    types [
      :deployment_event,
      :container_deployment_event,
      :image_deployment_event,
      :volume_deployment_event,
      :network_deployment_event,
      :env_file_event,
      :file_bind_event
    ]

    resolve_type &resolve_event_type/2
  end

  union :container_deployment_event_payload do
    description "An event occurring on a container deployment or any of its child resources."

    types [
      :container_deployment_event,
      :image_deployment_event,
      :volume_deployment_event,
      :network_deployment_event,
      :env_file_event,
      :file_bind_event
    ]

    resolve_type &resolve_event_type/2
  end

  object :container_event_subscriptions do
    @desc "Subscribes to events for a release deployment and all of its child container resources."
    field :release_deployment_events, :release_deployment_event_payload do
      arg :id, non_null(:id)

      config fn args, resolution ->
        subscribe_to_release_deployment(args, resolution)
      end

      resolve &resolve_event/3
    end

    @desc "Subscribes to events for a container deployment and all of its child resources."
    field :container_deployment_events, :container_deployment_event_payload do
      arg :id, non_null(:id)

      config fn args, resolution ->
        subscribe_to_container_deployment(args, resolution)
      end

      resolve &resolve_event/3
    end

    @desc "Subscribes to events for an image deployment."
    field :image_deployment_events, :image_deployment_event do
      arg :id, non_null(:id)

      config fn args, resolution ->
        subscribe_to_resource(Image.Deployment, :image, args, resolution)
      end

      resolve &resolve_event/3
    end

    @desc "Subscribes to events for a volume deployment."
    field :volume_deployment_events, :volume_deployment_event do
      arg :id, non_null(:id)

      config fn args, resolution ->
        subscribe_to_resource(Volume.Deployment, :volume, args, resolution)
      end

      resolve &resolve_event/3
    end

    @desc "Subscribes to events for a network deployment."
    field :network_deployment_events, :network_deployment_event do
      arg :id, non_null(:id)

      config fn args, resolution ->
        subscribe_to_resource(Network.Deployment, :network, args, resolution)
      end

      resolve &resolve_event/3
    end

    @desc "Subscribes to events for an env file deployment."
    field :env_file_deployment_events, :env_file_event do
      arg :id, non_null(:id)

      config fn args, resolution ->
        subscribe_to_resource(EnvFile, :env_file, args, resolution)
      end

      resolve &resolve_event/3
    end

    @desc "Subscribes to events for a file bind deployment."
    field :file_bind_deployment_events, :file_bind_event do
      arg :id, non_null(:id)

      config fn args, resolution ->
        subscribe_to_resource(FileBind, :file_bind, args, resolution)
      end

      resolve &resolve_event/3
    end

    @desc "Subscribes to events for a public key deployment."
    field :public_key_deployment_events, :public_key_deployment_event do
      arg :id, non_null(:id)

      config fn args, resolution ->
        subscribe_to_resource(PublicKey.Deployment, :public_key, args, resolution)
      end

      resolve &resolve_event/3
    end

    @desc "Subscribes to events for an image policy deployment."
    field :image_policy_deployment_events, :image_policy_deployment_event do
      arg :id, non_null(:id)

      config fn args, resolution ->
        subscribe_to_resource(ImagePolicy.Deployment, :image_policy, args, resolution)
      end

      resolve &resolve_event/3
    end
  end

  def topic(tenant_id, resource_type, resource_id) do
    "#{tenant_id}:#{resource_type}:#{resource_id}"
  end

  defp resolve_event_type(%{__type__: type}, _), do: type
  defp resolve_event_type(_, _), do: nil

  defp resolve_event({:pre_resolved, item}, _args, _resolution), do: {:ok, item}

  defp resolve_event([first], _args, _resolution), do: {:ok, first}

  defp resolve_event([first | rest], _args, _resolution) do
    Process.put(:batch_resolved, rest)
    {:ok, first}
  end

  defp resolve_event(event, _args, _resolution), do: {:ok, event}

  defp subscribe_to_release_deployment(%{id: id}, %{context: context}) do
    with %{tenant_id: tenant_id} = tenant <- context[:tenant] || context[:current_tenant],
         {:ok, deployment_uuid} <- extract_uuid(Release.Deployment, id) do
      case Containers.fetch_deployment(deployment_uuid,
             tenant: tenant,
             load: DeploymentResources.release_child_resources_load()
           ) do
        {:ok, deployment} ->
          topics =
            deployment
            |> DeploymentResources.collect_unique_resources()
            |> resources_to_topics(tenant_id)

          {:ok, topic: topics}

        {:error, _} ->
          {:ok, topic: topic(tenant_id, :deployment, deployment_uuid)}
      end
    else
      nil -> {:error, "Unauthorized"}
      {:error, _} = error -> error
    end
  end

  defp subscribe_to_container_deployment(%{id: id}, %{context: context}) do
    with %{tenant_id: tenant_id} = tenant <- context[:tenant] || context[:current_tenant],
         {:ok, container_uuid} <- extract_uuid(Container.Deployment, id) do
      case Ash.get(Container.Deployment, container_uuid,
             tenant: tenant,
             load: DeploymentResources.container_child_resources_load()
           ) do
        {:ok, container_deployment} ->
          topics =
            container_deployment
            |> DeploymentResources.collect_unique_resources()
            |> resources_to_topics(tenant_id)

          {:ok, topic: topics}

        {:error, _} ->
          {:ok, topic: topic(tenant_id, :container, container_uuid)}
      end
    else
      nil -> {:error, "Unauthorized"}
      {:error, _} = error -> error
    end
  end

  defp subscribe_to_resource(resource_module, resource_type, %{id: id}, %{context: context}) do
    with %{tenant_id: tenant_id} <- context[:tenant] || context[:current_tenant],
         {:ok, resource_uuid} <- extract_uuid(resource_module, id) do
      {:ok, topic: topic(tenant_id, resource_type, resource_uuid)}
    else
      nil -> {:error, "Unauthorized"}
      {:error, _} = error -> error
    end
  end

  defp resources_to_topics(resources_by_type, tenant_id) do
    resources_by_type
    |> Enum.flat_map(fn {resource_type, records} ->
      Enum.map(records, &topic(tenant_id, resource_type, &1.id))
    end)
    |> Enum.uniq()
  end

  defp extract_uuid(resource_module, id) when is_binary(id) do
    expected_type = AshGraphqlResourceInfo.type(resource_module)

    case AshGraphqlResource.decode_relay_id(id) do
      {:ok, %{type: ^expected_type, id: decoded_id}} ->
        cast_uuid(decoded_id)

      {:ok, %{type: _other_type}} ->
        {:error, "Invalid resource ID"}

      {:error, _} ->
        cast_uuid(id)
    end
  end

  defp extract_uuid(_resource_module, _id), do: {:error, "Invalid resource ID"}

  defp cast_uuid(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> {:error, "Invalid resource ID"}
    end
  end
end
