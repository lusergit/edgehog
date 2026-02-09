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

defmodule Edgehog.Users.Authentication.Secrets do
  @moduledoc """
  Ash Authentication secrets configuration.

  This module is responsible for loading at runtime the OpenID Connect
  configuration. It reads the application's configuration to get the
  necessary variables out of the runtime environment.
  """
  use AshAuthentication.Secret

  alias AshAuthentication.Secret
  alias Edgehog.Users.User

  @impl Secret
  def secret_for(secret, user, opts, context)

  def secret_for([:authentication, :strategies, :keycloak, :client_id], User, _opts, _context) do
    get_config(:client_id)
  end

  def secret_for([:authentication, :strategies, :keycloak, :redirect_uri], User, _opts, _context) do
    get_config(:redirect_uri)
  end

  def secret_for([:authentication, :strategies, :keycloak, :client_secret], User, _opts, _context) do
    get_config(:client_secret)
  end

  def secret_for([:authentication, :strategies, :keycloak, :base_url], User, _opts, _context) do
    get_config(:base_url)
  end

  defp get_config(key) do
    :edgehog
    |> Application.fetch_env!(:keycloak)
    |> Keyword.fetch!(key)
    |> then(&{:ok, &1})
  end
end
