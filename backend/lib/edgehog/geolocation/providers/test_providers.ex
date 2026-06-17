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

if Mix.env() == :test do
  defmodule Edgehog.Geolocation.Providers.TestGeocoding do
    @moduledoc """
    Fake geocoding provider. Here with the sole purpouse of being mocked
    """

    @behaviour Edgehog.Geolocation.GeocodingProvider

    alias Edgehog.Geolocation.Location
    alias Edgehog.Geolocation.Position

    @impl Edgehog.Geolocation.GeocodingProvider
    def reverse_geocode(%Position{timestamp: timestamp} = _position) do
      location =
        %Location{
          formatted_address: "123 Fake st.",
          timestamp: timestamp,
          source: """
          Location estimated by reverse geocoding the available position.\
          """
        }

      {:ok, location}
    end
  end

  defmodule Edgehog.Geolocation.Providers.TestGeolocation do
    @moduledoc """
    Fake geolocation provider. Here with the sole purpouse of being mocked
    """

    @behaviour Edgehog.Geolocation.GeolocationProvider

    alias Edgehog.Devices.Device
    alias Edgehog.Geolocation.Position

    @impl Edgehog.Geolocation.GeolocationProvider
    def geolocate(%Device{} = _device) do
      timestamp = DateTime.utc_now()

      position = %Position{
        latitude: 0.0,
        longitude: 0.0,
        timestamp: timestamp,
        source: """
        GPS fake data.
        """
      }

      {:ok, position}
    end
  end
end
