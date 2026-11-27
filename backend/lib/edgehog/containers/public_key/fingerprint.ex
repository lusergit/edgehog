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

defmodule Edgehog.Containers.PublicKey.Fingerprint do
  @moduledoc """
  Parses PEM-encoded X.509 certificates and computes their fingerprint.

  The fingerprint derivation is encapsulated in this module so the algorithm
  can be adjusted in one place without requiring database migrations.
  """

  @spec from_pem(term()) :: {:ok, String.t()} | {:error, term()}
  def from_pem(pem) when is_binary(pem) do
    with [{:Certificate, der, :not_encrypted}] <- :public_key.pem_decode(pem),
         {:ok, _cert} <- X509.Certificate.from_der(der) do
      fingerprint =
        :sha256
        |> :crypto.hash(der)
        |> Base.encode16(case: :lower)

      {:ok, fingerprint}
    else
      {:error, _} = error -> error
      _ -> {:error, :invalid_pem}
    end
  end

  def from_pem(_), do: {:error, :invalid_pem}
end
