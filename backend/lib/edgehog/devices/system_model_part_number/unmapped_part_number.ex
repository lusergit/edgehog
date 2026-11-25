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

defmodule Edgehog.Devices.SystemModelPartNumber.UnmappedPartNumber do
  @moduledoc """
  Embedded struct representing a device part number reported by connected fleet
  devices that is not yet associated with any catalog `SystemModel`.
  """
  use Ash.Resource,
    data_layer: :embedded,
    extensions: [AshGraphql.Resource]

  graphql do
    type :unmapped_part_number
  end

  attributes do
    attribute :part_number, :string do
      public? true
      allow_nil? false
      description "The unmapped part number string reported by devices."
    end

    attribute :device_count, :integer do
      public? true
      allow_nil? false
      description "The total number of devices reporting this unmapped part number."
    end

    attribute :online_device_count, :integer do
      public? true
      allow_nil? false
      description "The number of online devices reporting this unmapped part number."
    end
  end
end
