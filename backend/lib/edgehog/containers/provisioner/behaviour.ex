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

defmodule Edgehog.Containers.Provisioner.Behaviour do
  @moduledoc """
  Behaviour describing the API of a Provisioner for a deployment.
  This module shouldn't be used directly. Rather, it's best to
  use `Edgehog.Containers.Provisioner`), i.e.:

  ```ex
  defmodule ResourceProvisioner do
    use Edgehog.Containers.Provisioner, resource: :resource_name
  end
  ```

  which will add the default implementation of a `Provisioner`.
  All of the functions of this behaviour are overridable.
  Note that a `Provisioner` is `GenServer`, so you can also override any of its
  callbacks, if you need.
  """

  alias Edgehog.Containers.Container.Deployment, as: ContainerDeployment
  alias Edgehog.Containers.Deployment
  alias Edgehog.Containers.DeviceMapping.Deployment, as: DeviceMappingDeployment
  alias Edgehog.Containers.DeviceRequest.Deployment, as: DeviceRequestDeployment
  alias Edgehog.Containers.Image.Deployment, as: ImageDeployment
  alias Edgehog.Containers.Network.Deployment, as: NetworkDeployment
  alias Edgehog.Containers.Volume.Deployment, as: VolumeDeployment
  alias Edgehog.Tenants.Tenant

  @callback provision(
              resource_deployment(),
              release_deployment(),
              Tenant.t() | pos_integer(),
              provision_opts()
            ) :: GenServer.on_start()

  @callback start_link(start_opts()) :: GenServer.on_start()

  @callback start(start_opts()) :: GenServer.on_start()

  @callback name(resource_deployment()) :: {:via, Registry, {provisioner_registry(), id()}}

  @typedoc """
  An `Ash.Resource.record()` belonging to the resource's deployment type.
  """
  @type resource_deployment() ::
          ImageDeployment.t()
          | NetworkDeployment.t()
          | VolumeDeployment.t()
          | DeviceMappingDeployment.t()
          | DeviceRequestDeployment.t()
          | ContainerDeployment.t()

  @typedoc """
  An `Ash.Resource.record()` belonging to the `Edgehog.Containers.Deployment` type.
  """
  @type release_deployment() :: Deployment.t()

  @type provision_opts() :: start_opts() | keyword()

  @type start_opts() :: [
          resource_deployment: resource_deployment(),
          deployment: release_deployment(),
          tenant: Tenant.t(),
          mode: :auto | :manual
        ]

  @typedoc """
  The state map of the provisioner.
  """
  @type state() :: map()

  @type provisioner_registry() :: term()

  @type id() :: term()
end
