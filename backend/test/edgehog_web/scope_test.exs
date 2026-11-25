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

defmodule EdgehogWeb.ScopeTest do
  use EdgehogWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Edgehog.Actors.Actor
  alias Edgehog.Campaigns.Channel
  alias Edgehog.CampaignsFixtures
  alias Edgehog.Devices.Device
  alias Edgehog.Devices.HardwareType
  alias Edgehog.Devices.SystemModel
  alias Edgehog.DevicesFixtures
  alias Edgehog.Groups.DeviceGroup
  alias Edgehog.GroupsFixtures
  alias Edgehog.Tenants.Tenant
  alias EdgehogWeb.Auth.Token
  alias EdgehogWeb.LiveAuth
  alias EdgehogWeb.Scope
  alias Phoenix.LiveView.Socket

  defmodule ActionSpyTracer do
    @moduledoc false
    use Ash.Tracer

    @impl Ash.Tracer
    def start_span(_type, name) do
      stack = Process.get(:scope_test_span_stack, [])
      Process.put(:scope_test_span_stack, [name | stack])
      :ok
    end

    @impl Ash.Tracer
    def stop_span do
      case Process.get(:scope_test_span_stack, []) do
        [_head | rest] -> Process.put(:scope_test_span_stack, rest)
        [] -> :ok
      end

      :ok
    end

    @impl Ash.Tracer
    def get_span_context, do: Process.get(:scope_test_span_stack, [])

    @impl Ash.Tracer
    def set_span_context(stack) do
      Process.put(:scope_test_span_stack, List.wrap(stack))
      :ok
    end

    @impl Ash.Tracer
    def set_metadata(type, metadata) do
      if type == :action do
        stack = Process.get(:scope_test_span_stack, [])

        calc_dep? =
          Enum.any?(stack, fn name ->
            is_binary(name) and String.contains?(name, "__calc_dep__")
          end)

        record_event(Map.put(metadata, :calc_dep?, calc_dep?))
      end

      :ok
    end

    @impl Ash.Tracer
    def set_error(_error, _opts \\ []), do: :ok

    defp record_event(event) do
      case Application.get_env(:edgehog, :scope_test_spy_agent) do
        pid when is_pid(pid) ->
          if Process.alive?(pid) do
            Agent.update(pid, &[event | &1])
          end

        _ ->
          :ok
      end
    end
  end

  defp generate_jwt(tenant_private_key, sub) do
    jwk =
      tenant_private_key
      |> X509.PrivateKey.to_pem()
      |> JOSE.JWK.from_pem()

    now = DateTime.utc_now()

    claims = %{
      iss: "https://example.issuer.com/current",
      sub: sub,
      aud: "edgehog-test",
      exp: now |> DateTime.shift(hour: 2, day: 1) |> DateTime.to_unix(),
      iat: DateTime.to_unix(now),
      auth_time: now |> DateTime.shift(hour: 1) |> DateTime.to_unix(),
      preferred_username: "operator",
      email: "operator@example.com",
      given_name: "Ada",
      family_name: "Lovelace",
      e_tga: true
    }

    {:ok, jwt, _claims} =
      Token.encode_and_sign("dontcare", claims,
        secret: jwk,
        allowed_algos: ["ES256"]
      )

    jwt
  end

  defp tagged_device_fixture(tenant, part_number, tags) do
    device =
      DevicesFixtures.device_fixture(
        tenant: tenant,
        online: true,
        part_number: part_number
      )

    Ash.update!(device, %{tags: tags}, action: :add_tags, tenant: tenant, authorize?: false)
  end

  defp routed_socket do
    %Socket{
      router: EdgehogWeb.Router,
      private: %{lifecycle: %Phoenix.LiveView.Lifecycle{}}
    }
  end

  defp with_action_spy(fun) do
    {:ok, agent} = Agent.start_link(fn -> [] end)
    prev_tracer = Application.get_env(:ash, :tracer)
    Application.put_env(:edgehog, :scope_test_spy_agent, agent)
    Application.put_env(:ash, :tracer, List.wrap(prev_tracer) ++ [ActionSpyTracer])

    try do
      result = fun.()
      events = agent |> Agent.get(& &1) |> Enum.reverse()
      {result, events}
    after
      Application.delete_env(:edgehog, :scope_test_spy_agent)

      if is_nil(prev_tracer) do
        Application.delete_env(:ash, :tracer)
      else
        Application.put_env(:ash, :tracer, prev_tracer)
      end

      if Process.alive?(agent), do: Agent.stop(agent)
    end
  end

  describe "EdgehogWeb.Scope Ash.Scope.ToOpts implementation" do
    test "extracts actor, tenant, and authorize?: true", %{tenant: tenant} do
      actor = %Actor{sub: "user-123", claims: %{e_tga: true}}
      scope = Scope.new(tenant, actor)

      opts = Ash.Scope.to_opts(scope)

      assert opts[:actor] == actor
      assert opts[:tenant] == tenant
      assert opts[:authorize?] == true
    end

    test "allows explicit tenant override while preserving actor", %{tenant: tenant} do
      other_tenant = Edgehog.TenantsFixtures.tenant_fixture()
      actor = %Actor{sub: "user-456", claims: %{e_tga: true}}
      scope = Scope.new(tenant, actor)

      opts = Ash.Scope.to_opts(scope, tenant: other_tenant)

      assert opts[:actor] == actor
      assert opts[:tenant] == other_tenant
      assert opts[:authorize?] == true
    end
  end

  describe "EdgehogWeb.LiveAuth :current_scope assignment" do
    test "assigns nil current_scope for unauthenticated :redirect_if_authenticated" do
      {:cont, socket} = LiveAuth.on_mount(:redirect_if_authenticated, %{}, %{}, %Socket{})

      assert socket.assigns.current_tenant == nil
      assert socket.assigns.current_actor == nil
      assert socket.assigns.current_scope == nil
    end

    test "assigns current_scope with authenticated actor for JWT sessions", %{
      tenant: tenant,
      tenant_private_key: tenant_private_key
    } do
      jwt = generate_jwt(tenant_private_key, Ash.UUIDv7.generate())
      session = %{"tenant_slug" => tenant.slug, "auth_token" => jwt}
      params = %{"tenant_slug" => tenant.slug}

      {:cont, socket} =
        LiveAuth.on_mount(:require_authenticated, params, session, routed_socket())

      assert %Scope{current_tenant: scope_tenant, current_actor: scope_actor} =
               socket.assigns.current_scope

      assert scope_tenant.tenant_id == tenant.tenant_id
      assert scope_actor.sub == "test"
      assert scope_actor.preferred_username == "operator"
      assert scope_actor.claims == %{e_tga: true}
      assert socket.assigns.current_actor == scope_actor
      assert socket.assigns.current_tenant == scope_tenant
    end

    test "assigns normalized dev actor in current_scope for dev_bypass sessions", %{
      tenant: tenant
    } do
      prev_dev_routes = Application.get_env(:edgehog, :dev_routes)
      Application.put_env(:edgehog, :dev_routes, true)

      on_exit(fn ->
        if is_nil(prev_dev_routes) do
          Application.delete_env(:edgehog, :dev_routes)
        else
          Application.put_env(:edgehog, :dev_routes, prev_dev_routes)
        end
      end)

      session = %{"tenant_slug" => tenant.slug, "dev_bypass" => true}
      params = %{"tenant_slug" => tenant.slug}

      {:cont, socket} =
        LiveAuth.on_mount(:require_authenticated, params, session, routed_socket())

      assert %Scope{current_tenant: scope_tenant, current_actor: scope_actor} =
               socket.assigns.current_scope

      assert scope_tenant.tenant_id == tenant.tenant_id
      assert scope_actor == %Actor{sub: "dev", preferred_username: "dev", claims: %{e_tga: true}}
    end
  end

  describe "domain internal scope propagation" do
    test "propagates caller actor and authorize?: true into nested reads and calculations", %{
      tenant: tenant
    } do
      actor = %Actor{sub: "domain-actor-1", claims: %{e_tga: true}}
      scope = Scope.new(tenant, actor)

      hw_type = DevicesFixtures.hardware_type_fixture(tenant: tenant)

      model =
        DevicesFixtures.system_model_fixture(
          tenant: tenant,
          hardware_type_id: hw_type.id,
          part_numbers: ["PN-SCOPE-1"]
        )

      _device = tagged_device_fixture(tenant, hd(model.part_numbers).part_number, ["prod"])

      group =
        GroupsFixtures.device_group_fixture(
          tenant: tenant,
          selector: ~s("prod" in tags)
        )

      channel =
        CampaignsFixtures.channel_fixture(
          tenant: tenant,
          target_group_ids: [group.id]
        )

      {_result, events} =
        with_action_spy(fn ->
          Device
          |> Ash.Query.for_read(:for_device_group, %{device_group_id: group.id}, scope: scope)
          |> Ash.read!(scope: scope)

          Device
          |> Ash.Query.for_read(:for_channel, %{channel_id: channel.id}, scope: scope)
          |> Ash.read!(scope: scope)

          Ash.load!(group, [:device_count, :online_device_count], scope: scope)
          Ash.load!(channel, [:fleet_reach], scope: scope)
          Ash.load!(tenant, [:empty_device_group_count], scope: scope)
        end)

      assert events != []

      for event <- events do
        op = Map.get(event, :action) || Map.get(event, :calculation)

        assert event.actor == actor,
               "expected actor #{inspect(actor)} on #{inspect(event.resource)}.#{op}, got #{inspect(event.actor)}"

        if not event.calc_dep? do
          assert event.authorize? == true,
                 "expected authorize?: true on #{inspect(event.resource)}.#{op}, got #{inspect(event.authorize?)}"
        end
      end
    end
  end

  describe "LiveView end-to-end actor propagation" do
    test "passes authenticated actor and authorize?: true across Devices, Groups, Channels, and System Models LiveViews",
         %{
           conn: conn,
           tenant: tenant,
           tenant_private_key: tenant_private_key
         } do
      jwt = generate_jwt(tenant_private_key, Ash.UUIDv7.generate())

      hw_type = DevicesFixtures.hardware_type_fixture(tenant: tenant)

      model =
        DevicesFixtures.system_model_fixture(
          tenant: tenant,
          hardware_type_id: hw_type.id,
          part_numbers: ["PN-LV-1"]
        )

      _device = tagged_device_fixture(tenant, hd(model.part_numbers).part_number, ["fleet"])

      group =
        GroupsFixtures.device_group_fixture(
          tenant: tenant,
          selector: ~s("fleet" in tags)
        )

      channel =
        CampaignsFixtures.channel_fixture(
          tenant: tenant,
          target_group_ids: [group.id]
        )

      conn =
        post(conn, ~p"/session", %{
          "session" => %{"tenant_slug" => tenant.slug, "auth_token" => jwt}
        })

      paths = [
        ~p"/tenants/#{tenant.slug}/devices",
        ~p"/tenants/#{tenant.slug}/device-groups",
        ~p"/tenants/#{tenant.slug}/device-groups/#{group.id}",
        ~p"/tenants/#{tenant.slug}/channels",
        ~p"/tenants/#{tenant.slug}/channels/#{channel.id}",
        ~p"/tenants/#{tenant.slug}/system-models",
        ~p"/tenants/#{tenant.slug}/system-models/#{model.id}"
      ]

      {_views, events} =
        with_action_spy(fn ->
          Enum.map(paths, fn path ->
            {:ok, view, _html} = live(recycle(conn), path)
            _ = render_async(view)
            view
          end)
        end)

      # Exclude pre-auth session verification lookups (`Tenant` / `Actor` from `LiveAuth` & `Token`).
      liveview_events =
        Enum.reject(events, fn event ->
          event.resource in [Tenant, Actor]
        end)

      assert liveview_events != []

      for event <- liveview_events do
        op = Map.get(event, :action) || Map.get(event, :calculation)

        assert match?(
                 %Actor{sub: "test", preferred_username: "operator", claims: %{e_tga: true}},
                 event.actor
               ),
               "expected authenticated actor on #{inspect(event.resource)}.#{op}, got #{inspect(event.actor)}"

        if not event.calc_dep? do
          assert event.authorize? == true,
                 "expected authorize?: true on #{inspect(event.resource)}.#{op}, got #{inspect(event.authorize?)}"
        end
      end

      assert Enum.any?(liveview_events, &(&1.resource == Device))
      assert Enum.any?(liveview_events, &(&1.resource == DeviceGroup))
      assert Enum.any?(liveview_events, &(&1.resource == Channel))
      assert Enum.any?(liveview_events, &(&1.resource == SystemModel))
      assert Enum.any?(liveview_events, &(&1.resource == HardwareType))
    end
  end
end
