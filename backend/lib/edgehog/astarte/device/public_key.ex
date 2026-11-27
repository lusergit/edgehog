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

defmodule Edgehog.Astarte.Device.PublicKey do
  @moduledoc false
  @behaviour Edgehog.Astarte.Device.PublicKey.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Error

  @interface "io.edgehog.devicemanager.PublicKey"

  @impl Edgehog.Astarte.Device.PublicKey.Behaviour
  def set(%AppEngine{} = client, device_id, key_id, der_bytes)
      when is_binary(device_id) and is_binary(key_id) and is_binary(der_bytes) do
    client
    |> AppEngine.Devices.set_property(
      device_id,
      @interface,
      "/image/signing/#{key_id}",
      Base.encode64(der_bytes)
    )
    |> Error.maybe_match_error(device_id, @interface)
  end

  @impl Edgehog.Astarte.Device.PublicKey.Behaviour
  def unset(%AppEngine{} = client, device_id, key_id)
      when is_binary(device_id) and is_binary(key_id) do
    client
    |> AppEngine.Devices.unset_property(
      device_id,
      @interface,
      "/image/signing/#{key_id}"
    )
    |> Error.maybe_match_error(device_id, @interface)
  end
end
