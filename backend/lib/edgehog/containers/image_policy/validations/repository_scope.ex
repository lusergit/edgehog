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

defmodule Edgehog.Containers.ImagePolicy.Validations.RepositoryScope do
  @moduledoc false
  use Ash.Resource.Validation

  @path_segment_regex ~r/\A[a-z0-9]+(?:(?:[._]|__|[-]+)[a-z0-9]+)*\z/
  @domain_label_regex ~r/\A[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\z/
  @all_numeric_host_regex ~r/\A\d+(?:\.\d+)*\z/
  @port_regex ~r/\A[1-9]\d{0,4}\z/

  @impl Ash.Resource.Validation
  def validate(changeset, _opts, _context) do
    repository = Ash.Changeset.get_attribute(changeset, :repository)

    if valid_repository_scope?(repository) do
      :ok
    else
      {:error,
       field: :repository,
       message:
         "must be a valid container registry or repository scope (e.g. docker.io, quay.io/my-org, registry.example.com:5000/team/app)"}
    end
  end

  defp valid_repository_scope?(repository) when is_binary(repository) and repository != "" do
    [host_part | path_segments] = String.split(repository, "/")

    valid_host_and_port?(host_part) and
      Enum.all?(path_segments, &valid_path_segment?/1)
  end

  defp valid_repository_scope?(_), do: false

  defp valid_host_and_port?("[" <> rest) do
    case String.split(rest, "]", parts: 2) do
      [ipv6, ""] -> valid_ipv6?(ipv6)
      [ipv6, ":" <> port] -> valid_ipv6?(ipv6) and valid_port?(port)
      _ -> false
    end
  end

  defp valid_host_and_port?(host_part) do
    case String.split(host_part, ":") do
      [host] -> valid_host?(host)
      [host, port] -> valid_host?(host) and valid_port?(port)
      _ -> false
    end
  end

  defp valid_host?(host) do
    if Regex.match?(@all_numeric_host_regex, host) do
      valid_ipv4?(host)
    else
      valid_domain?(host)
    end
  end

  defp valid_ipv4?(host) do
    match?({:ok, _}, host |> String.to_charlist() |> :inet.parse_ipv4strict_address())
  end

  defp valid_ipv6?(address) do
    match?({:ok, _}, address |> String.to_charlist() |> :inet.parse_ipv6strict_address())
  end

  defp valid_domain?(host) do
    String.length(host) in 1..253 and
      host
      |> String.split(".")
      |> Enum.all?(&valid_domain_label?/1)
  end

  defp valid_domain_label?(label) do
    String.length(label) in 1..63 and Regex.match?(@domain_label_regex, label)
  end

  defp valid_port?(port_str) do
    Regex.match?(@port_regex, port_str) and String.to_integer(port_str) in 1..65_535
  end

  defp valid_path_segment?(segment) do
    Regex.match?(@path_segment_regex, segment)
  end
end
