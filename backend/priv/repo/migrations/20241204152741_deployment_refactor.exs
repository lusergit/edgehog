#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Edgehog.Repo.Migrations.DeploymentRefactor do
  @moduledoc """
  Updates resources based on their most recent snapshots.

  This file was autogenerated with `mix ash_postgres.generate_migrations`
  """

  use Ecto.Migration

  def up do
    drop constraint(:deployment_ready_actions, "deployment_ready_actions_deployment_id_fkey")

    create table(:release_deployments, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
    end

    alter table(:deployment_ready_actions) do
      modify :deployment_id,
             references(:release_deployments,
               column: :id,
               name: "deployment_ready_actions_deployment_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :delete_all
             )
    end

    alter table(:release_deployments) do
      add :last_message, :text

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :tenant_id,
          references(:tenants,
            column: :tenant_id,
            name: "release_deployments_tenant_id_fkey",
            type: :bigint,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false

      add :device_id,
          references(:devices,
            column: :id,
            name: "release_deployments_device_id_fkey",
            type: :bigint,
            prefix: "public",
            on_delete: :delete_all
          )

      add :release_id,
          references(:application_releases,
            column: :id,
            name: "release_deployments_release_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          )

      add :state, :text, null: false, default: "created"
    end

    create index(:release_deployments, [:tenant_id])

    create index(:release_deployments, [:id, :tenant_id], unique: true)

    create unique_index(:release_deployments, [:tenant_id, :device_id, :release_id],
             name: "release_deployments_release_instance_index"
           )

    create table(:image_deployments, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :last_message, :text

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :tenant_id,
          references(:tenants,
            column: :tenant_id,
            name: "image_deployments_tenant_id_fkey",
            type: :bigint,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false

      add :image_id,
          references(:images,
            column: :id,
            name: "image_deployments_image_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          )

      add :device_id,
          references(:devices,
            column: :id,
            name: "image_deployments_device_id_fkey",
            type: :bigint,
            prefix: "public",
            on_delete: :delete_all
          )

      add :state, :text, null: false, default: "created"
    end

    create index(:image_deployments, [:tenant_id])

    create index(:image_deployments, [:id, :tenant_id], unique: true)

    create unique_index(:image_deployments, [:tenant_id, :image_id, :device_id],
             name: "image_deployments_image_instance_index"
           )

    create table(:container_deployments, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :tenant_id,
          references(:tenants,
            column: :tenant_id,
            name: "container_deployments_tenant_id_fkey",
            type: :bigint,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false

      add :container_id,
          references(:containers,
            column: :id,
            name: "container_deployments_container_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          )

      add :device_id,
          references(:devices,
            column: :id,
            name: "container_deployments_device_id_fkey",
            type: :bigint,
            prefix: "public",
            on_delete: :delete_all
          )

      add :state, :text, null: false, default: "init"
    end

    create index(:container_deployments, [:tenant_id])

    create index(:container_deployments, [:id, :tenant_id], unique: true)

    create unique_index(:container_deployments, [:tenant_id, :container_id, :device_id],
             name: "container_deployments_container_instance_index"
           )

    create table(:ready_action_upgrades, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true

      add :tenant_id,
          references(:tenants,
            column: :tenant_id,
            name: "ready_action_upgrades_tenant_id_fkey",
            type: :bigint,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false

      add :upgrade_target_id,
          references(:release_deployments,
            column: :id,
            name: "ready_action_upgrades_upgrade_target_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :ready_action_id,
          references(:deployment_ready_actions,
            column: :id,
            name: "ready_action_upgrades_ready_action_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false
    end

    create index(:ready_action_upgrades, [:tenant_id])

    create index(:ready_action_upgrades, [:id, :tenant_id], unique: true)

    create table(:application_volume_deployments, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :tenant_id,
          references(:tenants,
            column: :tenant_id,
            name: "application_volume_deployments_tenant_id_fkey",
            type: :bigint,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false

      add :volume_id,
          references(:volumes,
            column: :id,
            name: "application_volume_deployments_volume_id_fkey",
            type: :uuid,
            prefix: "public"
          )

      add :device_id,
          references(:devices,
            column: :id,
            name: "application_volume_deployments_device_id_fkey",
            type: :bigint,
            prefix: "public"
          )

      add :state, :text, null: false, default: "init"
    end

    create index(:application_volume_deployments, [:tenant_id])

    create index(:application_volume_deployments, [:id, :tenant_id], unique: true)

    create unique_index(:application_volume_deployments, [:tenant_id, :volume_id, :device_id],
             name: "application_volume_deployments_volume_instance_index"
           )

    create table(:network_deployments, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :last_message, :text

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :tenant_id,
          references(:tenants,
            column: :tenant_id,
            name: "network_deployments_tenant_id_fkey",
            type: :bigint,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false

      add :network_id,
          references(:networks,
            column: :id,
            name: "network_deployments_network_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          )

      add :device_id,
          references(:devices,
            column: :id,
            name: "network_deployments_device_id_fkey",
            type: :bigint,
            prefix: "public",
            on_delete: :delete_all
          )

      add :state, :text, null: false, default: "init"
    end

    create index(:network_deployments, [:tenant_id])

    create index(:network_deployments, [:id, :tenant_id], unique: true)

    create unique_index(:network_deployments, [:tenant_id, :network_id, :device_id],
             name: "network_deployments_network_instance_index"
           )

    execute(
      "ALTER TABLE deployment_ready_actions alter CONSTRAINT deployment_ready_actions_deployment_id_fkey NOT DEFERRABLE"
    )
  end

  def down do
    drop_if_exists unique_index(:network_deployments, [:tenant_id, :network_id, :device_id],
                     name: "network_deployments_network_instance_index"
                   )

    drop constraint(:network_deployments, "network_deployments_tenant_id_fkey")

    drop constraint(:network_deployments, "network_deployments_network_id_fkey")

    drop constraint(:network_deployments, "network_deployments_device_id_fkey")

    drop_if_exists index(:network_deployments, [:id, :tenant_id])

    drop_if_exists index(:network_deployments, [:tenant_id])

    drop table(:network_deployments)

    drop_if_exists unique_index(
                     :application_volume_deployments,
                     [:tenant_id, :volume_id, :device_id],
                     name: "application_volume_deployments_volume_instance_index"
                   )

    drop constraint(
           :application_volume_deployments,
           "application_volume_deployments_tenant_id_fkey"
         )

    drop constraint(
           :application_volume_deployments,
           "application_volume_deployments_volume_id_fkey"
         )

    drop constraint(
           :application_volume_deployments,
           "application_volume_deployments_device_id_fkey"
         )

    drop_if_exists index(:application_volume_deployments, [:id, :tenant_id])

    drop_if_exists index(:application_volume_deployments, [:tenant_id])

    drop table(:application_volume_deployments)

    drop constraint(:ready_action_upgrades, "ready_action_upgrades_tenant_id_fkey")

    drop constraint(:ready_action_upgrades, "ready_action_upgrades_upgrade_target_id_fkey")

    drop constraint(:ready_action_upgrades, "ready_action_upgrades_ready_action_id_fkey")

    drop_if_exists index(:ready_action_upgrades, [:id, :tenant_id])

    drop_if_exists index(:ready_action_upgrades, [:tenant_id])

    drop table(:ready_action_upgrades)

    drop_if_exists unique_index(:container_deployments, [:tenant_id, :container_id, :device_id],
                     name: "container_deployments_container_instance_index"
                   )

    drop constraint(:container_deployments, "container_deployments_tenant_id_fkey")

    drop constraint(:container_deployments, "container_deployments_container_id_fkey")

    drop constraint(:container_deployments, "container_deployments_device_id_fkey")

    drop_if_exists index(:container_deployments, [:id, :tenant_id])

    drop_if_exists index(:container_deployments, [:tenant_id])

    drop table(:container_deployments)

    drop_if_exists unique_index(:image_deployments, [:tenant_id, :image_id, :device_id],
                     name: "image_deployments_image_instance_index"
                   )

    drop constraint(:image_deployments, "image_deployments_tenant_id_fkey")

    drop constraint(:image_deployments, "image_deployments_image_id_fkey")

    drop constraint(:image_deployments, "image_deployments_device_id_fkey")

    drop_if_exists index(:image_deployments, [:id, :tenant_id])

    drop_if_exists index(:image_deployments, [:tenant_id])

    drop table(:image_deployments)

    drop_if_exists unique_index(:release_deployments, [:tenant_id, :device_id, :release_id],
                     name: "release_deployments_release_instance_index"
                   )

    drop constraint(:release_deployments, "release_deployments_tenant_id_fkey")

    drop constraint(:release_deployments, "release_deployments_device_id_fkey")

    drop constraint(:release_deployments, "release_deployments_release_id_fkey")

    drop_if_exists index(:release_deployments, [:id, :tenant_id])

    drop_if_exists index(:release_deployments, [:tenant_id])

    alter table(:release_deployments) do
      remove :state
      remove :release_id
      remove :device_id
      remove :tenant_id
      remove :updated_at
      remove :inserted_at
      remove :last_message
    end

    drop constraint(:deployment_ready_actions, "deployment_ready_actions_deployment_id_fkey")

    alter table(:deployment_ready_actions) do
      modify :deployment_id,
             references(:application_deployments,
               column: :id,
               name: "deployment_ready_actions_deployment_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :delete_all
             )
    end

    drop table(:release_deployments)
  end
end