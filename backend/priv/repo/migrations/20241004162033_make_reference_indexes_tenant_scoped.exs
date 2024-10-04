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

defmodule Edgehog.Repo.Migrations.MakeReferenceIndexesTenantScoped do
  @moduledoc """
  Updates resources based on their most recent snapshots.

  This file was autogenerated with `mix ash_postgres.generate_migrations`
  """

  use Ecto.Migration

  def up do
    drop_if_exists index(:update_campaigns, [:tenant_id, :update_channel_id])

    drop_if_exists index(:update_campaigns, [:tenant_id, :base_image_id])

    drop constraint(:update_campaigns, "update_campaigns_update_channel_id_fkey")

    drop constraint(:update_campaigns, "update_campaigns_base_image_id_fkey")

    alter table(:update_campaigns) do
      modify :base_image_id,
             references(:base_images,
               column: :id,
               with: [tenant_id: :tenant_id],
               match: :full,
               name: "update_campaigns_base_image_id_fkey",
               type: :bigint,
               prefix: "public",
               on_delete: :nothing
             )
    end

    drop_if_exists index(:update_campaign_targets, [:update_campaign_id])

    drop_if_exists index(:update_campaign_targets, [:device_id])

    drop constraint(:update_campaign_targets, "update_campaign_targets_device_id_fkey")

    drop constraint(:update_campaign_targets, "update_campaign_targets_update_campaign_id_fkey")

    alter table(:update_campaign_targets) do
      modify :update_campaign_id,
             references(:update_campaigns,
               column: :id,
               with: [tenant_id: :tenant_id],
               match: :full,
               name: "update_campaign_targets_update_campaign_id_fkey",
               type: :bigint,
               prefix: "public",
               on_delete: :delete_all
             )
    end

    drop_if_exists index(:system_models, [:hardware_type_id])

    drop constraint(:system_models, "system_models_hardware_type_id_fkey")

    alter table(:system_models) do
      modify :hardware_type_id,
             references(:hardware_types,
               column: :id,
               with: [tenant_id: :tenant_id],
               match: :full,
               name: "system_models_hardware_type_id_fkey",
               type: :bigint,
               prefix: "public",
               on_delete: :nothing
             )
    end

    drop_if_exists index(:system_model_part_numbers, [:system_model_id])

    drop constraint(:system_model_part_numbers, "system_model_part_numbers_system_model_id_fkey")

    alter table(:system_model_part_numbers) do
      modify :system_model_id,
             references(:system_models,
               column: :id,
               with: [tenant_id: :tenant_id],
               match: :simple,
               name: "system_model_part_numbers_system_model_id_fkey",
               type: :bigint,
               prefix: "public",
               on_delete: :delete_all
             )
    end

    drop_if_exists index(:ota_operations, [:device_id])

    drop constraint(:ota_operations, "ota_operations_device_id_fkey")

    alter table(:ota_operations) do
      modify :device_id,
             references(:devices,
               column: :id,
               with: [tenant_id: :tenant_id],
               match: :full,
               name: "ota_operations_device_id_fkey",
               type: :bigint,
               prefix: "public",
               on_delete: :nothing
             )
    end

    drop_if_exists index(:hardware_type_part_numbers, [:hardware_type_id])

    drop constraint(
           :hardware_type_part_numbers,
           "hardware_type_part_numbers_hardware_type_id_fkey"
         )

    alter table(:hardware_type_part_numbers) do
      modify :hardware_type_id,
             references(:hardware_types,
               column: :id,
               with: [tenant_id: :tenant_id],
               match: :simple,
               name: "hardware_type_part_numbers_hardware_type_id_fkey",
               type: :bigint,
               prefix: "public",
               on_delete: :delete_all
             )
    end

    drop_if_exists index(:devices, [:realm_id])

    drop constraint(:devices, "devices_realm_id_fkey")

    alter table(:devices) do
      modify :realm_id,
             references(:realms,
               column: :id,
               with: [tenant_id: :tenant_id],
               match: :full,
               name: "devices_realm_id_fkey",
               type: :bigint,
               prefix: "public",
               on_delete: :nothing
             )
    end

    execute("ALTER TABLE devices alter CONSTRAINT devices_realm_id_fkey NOT DEFERRABLE")

    create index(:devices, [:tenant_id, :realm_id])

    execute(
      "ALTER TABLE hardware_type_part_numbers alter CONSTRAINT hardware_type_part_numbers_hardware_type_id_fkey NOT DEFERRABLE"
    )

    create index(:hardware_type_part_numbers, [:tenant_id, :hardware_type_id])

    execute(
      "ALTER TABLE ota_operations alter CONSTRAINT ota_operations_device_id_fkey NOT DEFERRABLE"
    )

    create index(:ota_operations, [:tenant_id, :device_id])

    execute(
      "ALTER TABLE system_model_part_numbers alter CONSTRAINT system_model_part_numbers_system_model_id_fkey NOT DEFERRABLE"
    )

    create index(:system_model_part_numbers, [:tenant_id, :system_model_id])

    execute(
      "ALTER TABLE system_models alter CONSTRAINT system_models_hardware_type_id_fkey NOT DEFERRABLE"
    )

    create index(:system_models, [:tenant_id, :hardware_type_id])

    execute(
      "ALTER TABLE update_campaign_targets alter CONSTRAINT update_campaign_targets_update_campaign_id_fkey NOT DEFERRABLE"
    )

    alter table(:update_campaign_targets) do
      modify :device_id,
             references(:devices,
               column: :id,
               with: [tenant_id: :tenant_id],
               match: :full,
               name: "update_campaign_targets_device_id_fkey",
               type: :bigint,
               prefix: "public",
               on_delete: :nothing
             )
    end

    execute(
      "ALTER TABLE update_campaign_targets alter CONSTRAINT update_campaign_targets_device_id_fkey NOT DEFERRABLE"
    )

    create index(:update_campaign_targets, [:tenant_id, :update_campaign_id])

    create index(:update_campaign_targets, [:tenant_id, :device_id])

    execute(
      "ALTER TABLE update_campaigns alter CONSTRAINT update_campaigns_base_image_id_fkey NOT DEFERRABLE"
    )

    alter table(:update_campaigns) do
      modify :update_channel_id,
             references(:update_channels,
               column: :id,
               with: [tenant_id: :tenant_id],
               match: :full,
               name: "update_campaigns_update_channel_id_fkey",
               type: :bigint,
               prefix: "public",
               on_delete: :nothing
             )
    end

    execute(
      "ALTER TABLE update_campaigns alter CONSTRAINT update_campaigns_update_channel_id_fkey NOT DEFERRABLE"
    )

    create index(:update_campaigns, [:tenant_id, :base_image_id])

    create index(:update_campaigns, [:tenant_id, :update_channel_id])
  end

  def down do
    drop_if_exists index(:update_campaigns, [:tenant_id, :update_channel_id])

    drop_if_exists index(:update_campaigns, [:tenant_id, :base_image_id])

    drop constraint(:update_campaigns, "update_campaigns_update_channel_id_fkey")

    alter table(:update_campaigns) do
      modify :update_channel_id,
             references(:update_channels,
               column: :id,
               with: [tenant_id: :tenant_id],
               match: :full,
               name: "update_campaigns_update_channel_id_fkey",
               type: :bigint,
               prefix: "public",
               on_delete: :nothing
             )
    end

    drop_if_exists index(:update_campaign_targets, [:tenant_id, :device_id])

    drop_if_exists index(:update_campaign_targets, [:tenant_id, :update_campaign_id])

    drop constraint(:update_campaign_targets, "update_campaign_targets_device_id_fkey")

    alter table(:update_campaign_targets) do
      modify :device_id,
             references(:devices,
               column: :id,
               with: [tenant_id: :tenant_id],
               match: :full,
               name: "update_campaign_targets_device_id_fkey",
               type: :bigint,
               prefix: "public",
               on_delete: :nothing
             )
    end

    drop_if_exists index(:system_models, [:tenant_id, :hardware_type_id])

    drop_if_exists index(:system_model_part_numbers, [:tenant_id, :system_model_id])

    drop_if_exists index(:ota_operations, [:tenant_id, :device_id])

    drop_if_exists index(:hardware_type_part_numbers, [:tenant_id, :hardware_type_id])

    drop_if_exists index(:devices, [:tenant_id, :realm_id])

    drop constraint(:devices, "devices_realm_id_fkey")

    alter table(:devices) do
      modify :realm_id,
             references(:realms,
               column: :id,
               with: [tenant_id: :tenant_id],
               match: :full,
               name: "devices_realm_id_fkey",
               type: :bigint,
               prefix: "public",
               on_delete: :nothing
             )
    end

    create index(:devices, [:realm_id])

    drop constraint(
           :hardware_type_part_numbers,
           "hardware_type_part_numbers_hardware_type_id_fkey"
         )

    alter table(:hardware_type_part_numbers) do
      modify :hardware_type_id,
             references(:hardware_types,
               column: :id,
               with: [tenant_id: :tenant_id],
               match: :simple,
               name: "hardware_type_part_numbers_hardware_type_id_fkey",
               type: :bigint,
               prefix: "public",
               on_delete: :delete_all
             )
    end

    create index(:hardware_type_part_numbers, [:hardware_type_id])

    drop constraint(:ota_operations, "ota_operations_device_id_fkey")

    alter table(:ota_operations) do
      modify :device_id,
             references(:devices,
               column: :id,
               with: [tenant_id: :tenant_id],
               match: :full,
               name: "ota_operations_device_id_fkey",
               type: :bigint,
               prefix: "public",
               on_delete: :nothing
             )
    end

    create index(:ota_operations, [:device_id])

    drop constraint(:system_model_part_numbers, "system_model_part_numbers_system_model_id_fkey")

    alter table(:system_model_part_numbers) do
      modify :system_model_id,
             references(:system_models,
               column: :id,
               with: [tenant_id: :tenant_id],
               match: :simple,
               name: "system_model_part_numbers_system_model_id_fkey",
               type: :bigint,
               prefix: "public",
               on_delete: :delete_all
             )
    end

    create index(:system_model_part_numbers, [:system_model_id])

    drop constraint(:system_models, "system_models_hardware_type_id_fkey")

    alter table(:system_models) do
      modify :hardware_type_id,
             references(:hardware_types,
               column: :id,
               with: [tenant_id: :tenant_id],
               match: :full,
               name: "system_models_hardware_type_id_fkey",
               type: :bigint,
               prefix: "public",
               on_delete: :nothing
             )
    end

    create index(:system_models, [:hardware_type_id])

    drop constraint(:update_campaign_targets, "update_campaign_targets_update_campaign_id_fkey")

    alter table(:update_campaign_targets) do
      modify :update_campaign_id,
             references(:update_campaigns,
               column: :id,
               with: [tenant_id: :tenant_id],
               match: :full,
               name: "update_campaign_targets_update_campaign_id_fkey",
               type: :bigint,
               prefix: "public",
               on_delete: :delete_all
             )
    end

    create index(:update_campaign_targets, [:device_id])

    create index(:update_campaign_targets, [:update_campaign_id])

    drop constraint(:update_campaigns, "update_campaigns_base_image_id_fkey")

    alter table(:update_campaigns) do
      modify :base_image_id,
             references(:base_images,
               column: :id,
               with: [tenant_id: :tenant_id],
               match: :full,
               name: "update_campaigns_base_image_id_fkey",
               type: :bigint,
               prefix: "public",
               on_delete: :nothing
             )
    end

    create index(:update_campaigns, [:tenant_id, :base_image_id])

    create index(:update_campaigns, [:tenant_id, :update_channel_id])
  end
end