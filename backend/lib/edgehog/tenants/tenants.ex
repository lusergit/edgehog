#
# This file is part of Edgehog.
#
# Copyright 2023 SECO Mind Srl
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

defmodule Edgehog.Tenants do
  use Ash.Api,
    extensions: [AshGraphql.Api, AshJsonApi.Api]

  graphql do
    root_level_errors? true
  end

  json_api do
    prefix "/admin-api/v1"
    log_errors? false
  end

  resources do
    resource Edgehog.Tenants.Tenant
  end
end
