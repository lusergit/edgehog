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

defmodule Edgehog.Users.User do
  @moduledoc """
  Edgehog Users.

  An edgehog user is not managed internally, instead, edgehog relies on external
  services implementing OpenID Connect to authenticate and authorize users.
  """

  use Edgehog.MultitenantResource,
    domain: Edgehog.Users,
    extensions: [AshAuthentication]

  alias Users.Authentication.Config

  authentication do
    strategies do
      oidc :keycloak do
        client_id(Config)
        base_url(Config)
        redirect_uri(Config)
        client_secret(Users.Authentication.Secrets)
        registration_enabled?(false)
      end
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    read :sign_in_with_keycloak do
      argument :user_info, :map, allow_nil?: false
      argument :oauth_tokens, :map, allow_nil?: false
      prepare AshAuthentication.Strategy.OAuth2.SignInPreparation

      filter expr(email == get_path(^arg(:user_info), [:email]))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :username, :string, allow_nil?: false, public?: true
    attribute :email, :string
    attribute :name, :string, public?: true
    attribute :surname, :string, public?: true

    timestamps()
  end

  identities do
    identity :tenant_users_email, [:email, :tenant_id]
  end

  postgres do
    table "users"
    repo Edgehog.Repo
  end
end
