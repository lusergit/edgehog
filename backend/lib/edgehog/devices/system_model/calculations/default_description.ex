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

defmodule Edgehog.Devices.SystemModel.Calculations.DefaultDescription do
  @moduledoc """
  Resolves a `SystemModel`'s single best localized description, preferring
  `preferred_locale` (or the tenant's `default_locale`) and falling back to the
  first non-empty translation sorted by language tag.
  """
  use Ash.Resource.Calculation

  alias Edgehog.Tenants.Tenant

  @impl Ash.Resource.Calculation
  def load(_query, _opts, _context) do
    [:description]
  end

  @impl Ash.Resource.Calculation
  def calculate(models, _opts, context) do
    preferred_locale = resolve_preferred_locale(context)
    Enum.map(models, &resolve_model_description(&1, preferred_locale))
  end

  defp resolve_model_description(model, preferred_locale) do
    entries =
      (model.description || %{})
      |> Enum.flat_map(&normalize_entry/1)
      |> Enum.sort_by(&elem(&1, 0))

    chosen =
      Enum.find(entries, fn {tag, _val} -> tag == preferred_locale end) ||
        List.first(entries)

    case chosen do
      {tag, value} -> %{language_tag: tag, value: value}
      nil -> nil
    end
  end

  defp normalize_entry({tag, val}) when is_binary(tag) and is_binary(val) do
    case String.trim(val) do
      "" -> []
      trimmed -> [{tag, trimmed}]
    end
  end

  defp normalize_entry(_entry), do: []

  defp resolve_preferred_locale(%{arguments: %{preferred_locale: locale}})
       when is_binary(locale) and locale != "",
       do: locale

  defp resolve_preferred_locale(%{tenant: %Tenant{default_locale: locale}})
       when is_binary(locale) and locale != "",
       do: locale

  defp resolve_preferred_locale(%{tenant: tenant_id}) when is_integer(tenant_id) do
    # System-level lookup of the already-authenticated tenant's default_locale.
    case Ash.get(Tenant, tenant_id, authorize?: false) do
      {:ok, %Tenant{default_locale: locale}} when is_binary(locale) and locale != "" -> locale
      _ -> "en-US"
    end
  end

  defp resolve_preferred_locale(_context), do: "en-US"
end
