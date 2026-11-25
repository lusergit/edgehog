# This file is part of Edgehog.
#
# Copyright 2021-2026 SECO Mind Srl
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

defmodule Edgehog.Devices.SystemModel do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Devices,
    extensions: [
      AshGraphql.Resource
    ],
    notifiers: [
      Ash.Notifier.PubSub
    ]

  alias Edgehog.Devices.SystemModel.Calculations
  alias Edgehog.Devices.SystemModel.Changes
  alias Edgehog.Devices.SystemModel.Validations
  alias Edgehog.Localization
  alias Edgehog.Localization.Changes.UpsertLocalizedAttribute
  alias Edgehog.Types.Upload

  require Ash.Query

  resource do
    description """
    A system model corresponds to what the users thinks as functionally
    equivalent devices (e.g. two revisions of a device containing two different
    embedded chips but having the same enclosure and the same functionality).
    Each SystemModel must be associated to a specific HardwareType.
    """
  end

  graphql do
    type :system_model

    paginate_relationship_with part_numbers: :relay
  end

  actions do
    defaults [:read]

    read :list do
      description "Returns system models with optional case-insensitive search across models, hardware types, and part numbers."

      pagination do
        required? false
        offset? true
        keyset? true
        countable true
      end

      argument :search, :string do
        description "Optional case-insensitive substring filter matching model, hardware type, or part number."
      end

      prepare fn query, _context ->
        case Ash.Query.get_argument(query, :search) do
          search when is_binary(search) ->
            trimmed = String.trim(search)

            if trimmed == "" do
              query
            else
              escaped = String.replace(trimmed, ~r/([%_\\])/, "\\\\\\1")
              pattern = "%#{escaped}%"

              Ash.Query.filter(
                query,
                fragment("? ILIKE ?", name, ^pattern) or
                  fragment("? ILIKE ?", handle, ^pattern) or
                  exists(
                    hardware_type,
                    fragment("? ILIKE ?", name, ^pattern) or
                      fragment("? ILIKE ?", handle, ^pattern)
                  ) or
                  exists(part_numbers, fragment("? ILIKE ?", part_number, ^pattern))
              )
            end

          _ ->
            query
        end
      end
    end

    create :create do
      description "Creates a system model."
      primary? true

      accept [:handle, :name, :picture_url]

      argument :hardware_type_id, :id do
        description "The ID of the hardware type that can be used by devices of this model"
        allow_nil? false
      end

      argument :part_numbers, {:array, :string} do
        description "The list of part numbers associated with the system model."
        allow_nil? false
        constraints min_length: 1
      end

      argument :picture_file, Upload do
        description "A picture representing the system model that will be uploaded to a bucket."
      end

      argument :localized_descriptions, {:array, Localization.LocalizedAttribute} do
        description "A list of descriptions in different languages."
      end

      validate Validations.EitherPictureUrlOrPictureFile

      # TODO: see issue #228, which is still relevant
      change manage_relationship(:part_numbers,
               on_lookup: :relate,
               on_no_match: :create,
               value_is_key: :part_number,
               use_identities: [:part_number]
             )

      change manage_relationship(:hardware_type_id, :hardware_type, type: :append)
      change Changes.HandlePictureUpload

      change {UpsertLocalizedAttribute,
              input_argument: :localized_descriptions, target_attribute: :description}
    end

    update :update do
      description "Updates an system model."
      primary? true

      # Needed because manage_relationship and UpsertLocalizedAttribute are not atomic
      require_atomic? false

      accept [:handle, :name, :picture_url]

      argument :part_numbers, {:array, :string} do
        description "The list of part numbers associated with the system model."
        constraints min_length: 1
      end

      argument :picture_file, Upload do
        description "A picture representing the system model that will be uploaded to a bucket."
      end

      argument :localized_descriptions, {:array, Localization.LocalizedAttributeUpdateInput} do
        description """
        A list of descriptions in different languages.

        If a language already exists it is updated. If a null value is passed, the language
        is deleted.
        """
      end

      validate Validations.EitherPictureUrlOrPictureFile

      change manage_relationship(:part_numbers,
               on_lookup: :relate,
               on_no_match: :create,
               on_missing: :destroy,
               value_is_key: :part_number,
               use_identities: [:part_number]
             )

      change Changes.HandlePictureUpload
      change Changes.HandlePictureDeletion

      change {UpsertLocalizedAttribute,
              input_argument: :localized_descriptions, target_attribute: :description}
    end

    destroy :destroy do
      description "Deletes a system model."
      primary? true

      # Needed because HandlePictureDeletion is not atomic
      require_atomic? false

      change {Changes.HandlePictureDeletion, force?: true}
    end
  end

  validations do
    validate Edgehog.Validations.slug(:handle) do
      where changing(:handle)
    end
  end

  attributes do
    integer_primary_key :id

    attribute :handle, :string do
      public? true

      description """
      The identifier of the system model.

      It should start with a lower case ASCII letter and only contain \
      lower case ASCII letters, digits and the hyphen - symbol.
      """

      allow_nil? false
    end

    attribute :name, :string do
      public? true
      description "The display name of the system model."
      allow_nil? false
    end

    attribute :picture_url, :string do
      public? true
      description "A URL to a picture representing the system model."
    end

    attribute :description, :map

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :part_numbers, Edgehog.Devices.SystemModelPartNumber do
      public? true
      description "The list of part numbers associated with the system model."
    end

    belongs_to :hardware_type, Edgehog.Devices.HardwareType do
      public? true
      description "The Hardware type associated with the System Model"
      attribute_public? false
    end

    many_to_many :releases, Edgehog.Containers.Release do
      through Edgehog.Containers.ReleaseSystemModel
      public? true
      description "The various application releases that require the system model to be deployed."
    end

    has_one :base_image_collection, Edgehog.BaseImages.BaseImageCollection do
      public? true
      description "The base image collection targeting this system model, if present."
    end
  end

  calculations do
    calculate :localized_descriptions, {:array, Localization.LocalizedAttribute} do
      public? true
      description "A list of descriptions in different languages."
      calculation {Localization.Calculations.LocalizedAttributes, attribute: :description}
      argument :preferred_language_tags, {:array, :string}
    end

    calculate :default_description, Localization.LocalizedAttribute do
      public? true
      description "The preferred or fallback localized description for this system model."
      argument :preferred_locale, :string
      calculation Calculations.DefaultDescription
    end

    calculate :has_picture,
              :boolean,
              expr(not is_nil(picture_url) and fragment("btrim(?) <> ''", picture_url)) do
      public? true
      allow_nil? false
      description "Whether the system model has a non-empty product picture URL."
    end
  end

  aggregates do
    list :part_number_strings, :part_numbers, :part_number

    count :part_number_count, :part_numbers do
      public? true
      description "The number of part numbers registered for this system model."
    end

    count :device_count, [:part_numbers, :devices] do
      public? true
      description "The total number of devices matching this system model's part numbers."
    end

    count :online_device_count, [:part_numbers, :devices] do
      public? true
      filter expr(online == true)
      description "The number of online devices matching this system model's part numbers."
    end

    count :release_count, :releases do
      public? true
      description "The number of compatible application releases for this system model."
    end

    exists :has_base_image_collection, :base_image_collection do
      public? true
      description "Whether a base image collection references this system model."
    end
  end

  identities do
    identity :handle, [:handle]
    identity :name, [:name]
  end

  pub_sub do
    prefix "system_models"
    module EdgehogWeb.Endpoint

    publish :create, ["tenant", :tenant_id]
    publish :update, ["tenant", :tenant_id]
    publish :update, [:id]
    publish :destroy, ["tenant", :tenant_id]
    publish :destroy, [:id]
  end

  postgres do
    table "system_models"
    repo Edgehog.Repo

    references do
      reference :hardware_type,
        index?: true,
        on_delete: :nothing,
        match_type: :full,
        match_with: [tenant_id: :tenant_id]
    end
  end
end
