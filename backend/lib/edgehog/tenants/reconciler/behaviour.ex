==> picosat_elixir
make: Nothing to be done for 'all'.

10:22:54.682 [debug] Copying NIF from cache and extracting to /home/luser/seco/edgehog/backend/_build/dev/lib/nimble_lz4/priv/native/libnimblelz4-v1.1.0-nif-2.15-x86_64-unknown-linux-gnu.so
# This file is part of Edgehog.
#
# Copyright 2023-2026 SECO Mind Srl
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

defmodule Edgehog.Tenants.Reconciler.Behaviour do
  @moduledoc false

  @type tenant :: Ash.Resource.record()

  @callback reconcile_tenant(tenant :: tenant()) :: :ok
  @callback reconcile(tenant :: tenant()) :: :ok
end
