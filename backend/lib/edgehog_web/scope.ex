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

defmodule EdgehogWeb.Scope do
  @moduledoc """
  Phoenix/Ash scope bundling the authenticated `current_tenant` and
  `current_actor` for LiveViews, LiveComponents, `AshPhoenix.Form`, and
  `Cinder.collection`.

  Implements `Ash.Scope.ToOpts` so passing `scope: @current_scope` supplies
  `:tenant`, `:actor`, and `:authorize?` (`true` whenever an actor is present),
  ensuring both `Ash.Query.for_read/4` preparations and runtime reads/mutations
  authorize under the authenticated actor.
  """

  alias Edgehog.Actors.Actor
  alias Edgehog.Tenants.Tenant

  @type t :: %__MODULE__{
          current_tenant: Tenant.t() | nil,
          current_actor: Actor.t() | nil
        }

  defstruct [:current_tenant, :current_actor]

  @spec new(Tenant.t(), Actor.t()) :: t()
  def new(%Tenant{} = tenant, %Actor{} = actor) do
    %__MODULE__{current_tenant: tenant, current_actor: actor}
  end

  defimpl Ash.Scope.ToOpts do
    def get_actor(%{current_actor: actor}), do: {:ok, actor}
    def get_tenant(%{current_tenant: tenant}), do: {:ok, tenant}
    def get_context(_), do: :error
    def get_tracer(_), do: :error
    def get_authorize?(%{current_actor: actor}), do: {:ok, not is_nil(actor)}
  end
end
