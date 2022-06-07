#
# This file is part of Edgehog.
#
# Copyright 2022 SECO Mind Srl
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

defmodule Edgehog.Repo.Migrations.CreateDeviceAttributes do
  use Ecto.Migration

  def change do
    create table(:device_attributes) do
      add :namespace, :string
      add :key, :string
      add :typed_value, :map
      add :tenant_id, references(:tenants, on_delete: :nothing)
      add :device_id, references(:devices, on_delete: :nothing)

      timestamps()
    end

    create index(:device_attributes, [:tenant_id])
    create index(:device_attributes, [:device_id])
  end
end
