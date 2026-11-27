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

defmodule Edgehog.Containers.PublicKey.FingerprintTest do
  use ExUnit.Case, async: true

  import Edgehog.ContainersFixtures

  alias Edgehog.Containers.PublicKey.Fingerprint

  describe "der_from_pem/1" do
    test "returns DER bytes for a valid single X.509 certificate PEM" do
      pem = x509_certificate_pem_fixture()
      {:ok, cert} = X509.Certificate.from_pem(pem)
      expected_der = X509.Certificate.to_der(cert)

      assert {:ok, ^expected_der} = Fingerprint.der_from_pem(pem)
    end

    test "returns error for multi-entry or invalid PEM inputs" do
      pem1 = x509_certificate_pem_fixture()
      pem2 = x509_certificate_pem_fixture()

      assert {:error, :invalid_pem} = Fingerprint.der_from_pem(pem1 <> "\n" <> pem2)
      assert {:error, :invalid_pem} = Fingerprint.der_from_pem("invalid")
      assert {:error, :invalid_pem} = Fingerprint.der_from_pem(nil)
    end
  end

  describe "from_pem/1" do
    test "returns lowercase hex SHA-256 of the X.509 certificate DER bytes" do
      pem = x509_certificate_pem_fixture()
      {:ok, cert} = X509.Certificate.from_pem(pem)

      expected =
        :sha256
        |> :crypto.hash(X509.Certificate.to_der(cert))
        |> Base.encode16(case: :lower)

      assert {:ok, ^expected} = Fingerprint.from_pem(pem)
      assert String.length(expected) == 64
    end

    test "returns the same fingerprint for the same certificate" do
      pem = x509_certificate_pem_fixture()

      assert {:ok, fp1} = Fingerprint.from_pem(pem)
      assert {:ok, fp2} = Fingerprint.from_pem(pem)
      assert fp1 == fp2
    end

    test "returns distinct fingerprints for distinct certificates" do
      assert {:ok, fp1} = Fingerprint.from_pem(x509_certificate_pem_fixture())
      assert {:ok, fp2} = Fingerprint.from_pem(x509_certificate_pem_fixture())
      assert fp1 != fp2
    end

    test "returns error for a raw PEM public key instead of an X.509 certificate" do
      key = X509.PrivateKey.new_ec(:secp256r1)
      pub_pem = key |> X509.PublicKey.derive() |> X509.PublicKey.to_pem()

      assert {:error, _reason} = Fingerprint.from_pem(pub_pem)
    end

    test "returns error for combined private-key and certificate PEM bundles" do
      key = X509.PrivateKey.new_ec(:secp256r1)
      key_pem = X509.PrivateKey.to_pem(key)

      cert_pem =
        key |> X509.Certificate.self_signed("/CN=combined-test") |> X509.Certificate.to_pem()

      assert {:error, :invalid_pem} = Fingerprint.from_pem(key_pem <> "\n" <> cert_pem)
      assert {:error, :invalid_pem} = Fingerprint.from_pem(cert_pem <> "\n" <> key_pem)
    end

    test "returns error for multi-certificate PEM bundles" do
      pem1 = x509_certificate_pem_fixture()
      pem2 = x509_certificate_pem_fixture()

      assert {:error, :invalid_pem} = Fingerprint.from_pem(pem1 <> "\n" <> pem2)
    end

    test "returns error for invalid PEM strings or non-binaries" do
      assert {:error, _reason} = Fingerprint.from_pem("not a certificate")
      assert {:error, _reason} = Fingerprint.from_pem("")
      assert {:error, :invalid_pem} = Fingerprint.from_pem(nil)
    end
  end
end
