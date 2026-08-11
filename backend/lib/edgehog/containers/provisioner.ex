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

defmodule Edgehog.Containers.Provisioner do
  @moduledoc """
  This module provides the default implementation for `Edgehog.Containers.Provisioner.Behaviour`.
  It is sufficient to add a using statement like so:

  ```ex
  defmodule ResourceDeployment.Provisioner do
    use Edgehog.Containers.Provisioner, resource: :image
  end
  ```
  """

  @module_base Edgehog.Containers

  defmacro __using__(opts) do
    resource_name = Keyword.fetch!(opts, :resource)
    string_deployment = to_string(resource_name)

    {string_deployment, string_type} =
      if String.ends_with?(string_deployment, "_deployment") do
        {string_deployment, String.replace(string_deployment, "_deployment", "")}
      else
        {string_deployment <> "_deployment", string_deployment}
      end

    # all the calls for `String.to_atom/1` are at compile-time, and at a very restricted scope
    # credo:disable-for-lines:30 Credo.Check.Warning.UnsafeToAtom
    type_atom = String.to_existing_atom(string_type)
    deployment_atom = String.to_atom(string_deployment)
    deployment_string_lower = String.downcase(string_deployment)

    type_string_camel =
      snake_to_camel(string_type)

    type_string_lower = String.downcase(string_type)
    string_module_camel = String.replace(type_string_camel, " ", "")
    deployment_module_suffix = String.to_atom(string_module_camel <> ".Deployment")
    deployment_module = Module.safe_concat(@module_base, string_module_camel <> ".Deployment")
    core_module = Module.concat(deployment_module, Provisioner.Core)

    supervisor_module =
      Module.concat(@module_base, string_module_camel <> ".Provisioner.Supervisor")

    available_string = "available_" <> string_type <> "s"
    available_atom = String.to_atom(available_string)

    available_resources_module =
      available_string
      |> snake_to_camel("")
      |> then(&Module.safe_concat(Edgehog.Astarte.Device, &1))

    status_module =
      (string_module_camel <> "Status")
      |> String.to_atom()
      |> then(&Module.safe_concat(available_resources_module, &1))

    status_verb_key = Keyword.get(opts, :status_verb_key)

    # credo:disable-for-next-line Credo.Check.Refactor.LongQuoteBlocks
    quote do
      @moduledoc """
      A #{unquote(type_string_lower)} deployment provisioner.

      Each and every time an #{unquote(type_string_lower)} should be deployed, it can be done through this
      provisioner. The provisioner sends the appropriate messages to the device and
      emits a `ready:#{unquote(deployment_string_lower)}s:id` event whenever #{unquote(type_string_lower)} is present in the
      device.

      The provisioning flow can be described as follows:

      - start_link/1 called, initializing the process and subscribing to the
        events emitted on `#{unquote(deployment_string_lower)}s:<id>` (id of the #{unquote(type_string_lower)} deployment)
      - if the #{unquote(type_string_lower)} deployment is already ready, the provisioner terminates normally
        right away, broadcasting readiness
      - otherwise the appropriate messages are sent to the device through the
        `Core` module (see `Core.send/1` docs for more info)

      Nice flow (everything goes ok)
      - Astarte triggers update the #{unquote(type_string_lower)} deployment state, marking it as present or
      not present and emitting an event on the correct topic
      - The server reacts to the event, handles the message and emits an event on
      'ready:#{unquote(type_string_lower)}s:id' when the resource is ready
      - listening processes can react to this information

      Timeouts (something goes wrong)
      - `Core.send/1` failed, maybe the device is offline, or there was some
        problem with astarte
      - an exponential backoff timeout is started
      - A :timeout hits the server, it retries to send the #{unquote(type_string_lower)} information to the
      device

      TODOs, shortcomigs:
      The logic to handle send succeeding but no message coming back from astarte is
      not there yet
      """

      use GenServer, restart: :transient

      alias Edgehog.Config
      alias unquote(deployment_module)
      alias unquote(core_module)
      alias unquote(Module.safe_concat(@module_base, Provisioner))

      require Logger

      # credo:disable-for-lines:2
      @test Mix.env() == :test
      @sup unquote(supervisor_module)

      # Test additional API
      # In test environment, allow to run the process with a message, so that the
      # test process can attach and monitor it
      if @test do
        def run(provisioner) do
          GenServer.cast(provisioner, :run)
        end

        @impl GenServer
        def handle_cast(:run, state) do
          {:noreply, state, {:continue, :check_deployment_state}}
        end
      end

      @behaviour Provisioner.Behaviour

      defoverridable Provisioner.Behaviour

      #### API

      @doc """
      Starts the right process through the #{inspect(@sup)} dynamic supervisor.
      When creating the link, the server checks a registry to know whether the
      corresponding process is already up and running. Check `start_link/1` docs for
      more.
      """
      @impl Provisioner.Behaviour
      def provision(resource_deployment, deployment, tenant, opts \\ []) do
        args =
          opts
          |> Keyword.put(unquote(deployment_atom), resource_deployment)
          |> Keyword.put(:deployment, deployment)
          |> Keyword.put(:tenant, tenant)

        child_spec = Supervisor.child_spec({__MODULE__, args}, id: resource_deployment.id)

        with {:error, {:already_started, pid}} <- DynamicSupervisor.start_child(@sup, child_spec) do
          {:ok, pid}
        end
      end

      @doc """
      Starts a provisioner for an #{unquote(type_string_lower)} deployment.

      A provision for this resource follows the following flow:

      - checks that the resource is not ready already (i.e., the device never received it).
      - tries to send the deployment information to astarte (calling `&Devices.send_#{unquote(type_string_lower)}_deployment/2`)
      - if an unrecoverable error occurs, broadcasts a failure on the `topic/1` topic.
      - if successful, waits for events on the resource deployment itself.

      - if a trigger reaches edgehog, it changes a property in the #{unquote(type_string_lower)} deployment resource, emitting an event for the provsioner.
      - the provisioner understands that the #{unquote(type_string_lower)} is ready, it then exits successfully.

      - if the reconciler has no messages incoming after a timer defined through the `timeout/1` function:
      + checks for readiness of the resource, maybe we just missed the message
      + queries astarte, maybe the trigger was missing
      + retries to send the message to the device.
      + loops with a new timeout set by the `timeout/1` function.
      """
      @impl Provisioner.Behaviour
      def start_link(args) do
        resource_deployment =
          args |> Keyword.fetch!(unquote(deployment_atom)) |> Ash.load!(:device)

        args = Keyword.put(args, :resource_deployment, resource_deployment)

        GenServer.start_link(__MODULE__, args, name: name(resource_deployment))
      end

      @doc """
      Starts a provisioner for an #{unquote(type_string_lower)} deployment, without linking it to the
      current process.

      See `start_link/1` docs for more information
      """
      @impl Provisioner.Behaviour
      def start(args) do
        resource_deployment =
          args |> Keyword.fetch!(unquote(deployment_atom)) |> Ash.load!(:device)

        args = Keyword.put(args, :resource_deployment, resource_deployment)

        GenServer.start(__MODULE__, args, name: name(resource_deployment))
      end

      @impl Provisioner.Behaviour
      def name(%Deployment{id: id}) do
        {:via, Registry,
         {unquote(Module.concat(deployment_module_suffix, Provisioner.Registry)), id}}
      end

      #### Callbacks

      @impl GenServer
      def init(args) do
        resource_deployment = Keyword.fetch!(args, :resource_deployment)
        deployment = Keyword.fetch!(args, :deployment)
        tenant = Keyword.fetch!(args, :tenant)

        mode = Keyword.get(args, :mode, :auto)

        %{id: id, device: %{id: device_id, online: device_online?}} =
          resource_deployment

        state = %{
          resource_deployment: resource_deployment,
          deployment: deployment,
          device_online?: device_online?,
          tenant: tenant,
          state: :init,
          mode: mode,
          retries: 0
        }

        Logger.info("Subscribing to events on #{unquote(type_string_lower)} deployment #{id}")
        Phoenix.PubSub.subscribe(Edgehog.PubSub, "#{unquote(deployment_string_lower)}s:#{id}")

        Logger.info(
          "Subscribing to status events of device #{device_id} for #{unquote(type_string_lower)} deployment #{id}"
        )

        Phoenix.PubSub.subscribe(Edgehog.PubSub, "devices:offline:#{device_id}")

        Logger.debug(
          "Device #{device_id} is currently #{if device_online?, do: "online", else: "offline"}"
        )

        # If the provisioning does not complete within the deadline, the
        # provisioner gives up and broadcasts a failure that the orchestrator reacts
        # to
        deadline = Config.deployment_provisioning_timeout!()
        Process.send_after(self(), :give_up, deadline)

        {:ok, state, {:continue, :maybe_start}}
      end

      @impl GenServer
      def handle_continue(:maybe_start, %{mode: :auto} = state) do
        next_step = {:noreply, state, {:continue, :check_deployment_state}}
        Core.maybe_early_terminate(state, next_step)
      end

      @impl GenServer
      def handle_continue(:maybe_start, %{mode: :manual} = state) do
        next_step = {:noreply, state}
        Core.maybe_early_terminate(state, next_step)
      end

      @impl GenServer
      def handle_continue(
            :check_deployment_state,
            %{resource_deployment: resource_deployment} = state
          ) do
        resource_deployment =
          Ash.load!(resource_deployment, :is_ready, tenant: resource_deployment.tenant_id)

        if resource_deployment.is_ready do
          new_state = Map.put(state, :resource_deployment, resource_deployment)
          {:stop, :normal, new_state}
        else
          {:noreply, state, {:continue, :send}}
        end
      end

      @impl GenServer
      def handle_continue(:send, state), do: Core.send(state)

      # We were not able to send the message to the device. retry
      @impl GenServer
      def handle_info(:timeout, %{state: :init} = state), do: Core.send(state)

      # We sent the message to the device, but no trigger came back.
      # 1. Reconcile with astarte
      # 2. if still nothing has come back, retry to send
      @impl GenServer
      def handle_info(:timeout, %{state: :sent} = state) do
        %{resource_deployment: resource_deployment, tenant: tenant} = state

        rec = Core.reconcile(resource_deployment, tenant: tenant)

        case rec do
          :not_found ->
            Core.maybe_send(state)

          {:ok, resource_deployment} ->
            # Reconciliation updated the resource deployment, just update the state as a
            # new message will come in the queue
            new_state = Map.put(state, :resource_deployment, resource_deployment)

            # This just in case the message is not actually there, but I'd consider it a bug
            timeout = Core.timeout(state)

            {:noreply, new_state, timeout}
        end
      end

      # The resource deployment provisioning deadline was hit, give up and broadcast a
      # failure so that the orchestrator can react
      @impl GenServer
      def handle_info(:give_up, state) do
        Logger.warning("""
        #{unquote(type_string_camel)} deployment #{state.resource_deployment.id} provisioning timed out. Giving up.
        """)

        {:stop, {:shutdown, :timeout_hit}, state}
      end

      # We get the resource deployment from the broadcast, which is in the :payload ->
      # :data section. This resource deployment is more recent, as it comes from an
      # update in the database.
      @impl GenServer
      def handle_info(
            %Phoenix.Socket.Broadcast{payload: %{data: %Deployment{} = resource_deployment}},
            state
          ) do
        # We can publish on readiness topic.
        id = resource_deployment.id

        Phoenix.PubSub.broadcast(
          Edgehog.PubSub,
          "ready:#{unquote(deployment_string_lower)}s:#{id}",
          {:ready, resource_deployment}
        )

        new_state = Map.put(state, :resource_deployment, resource_deployment)

        # Somewhere the resource has been marked in some state (i.e: pulled/unpulled for images). For
        # now we can just shutdown gracefully
        {:stop, :normal, new_state}
      end

      @impl GenServer
      def handle_info(%Phoenix.Socket.Broadcast{topic: "devices:offline:" <> _id}, old_state) do
        new_state = Map.put(old_state, :device_online?, false)

        {:stop, {:shutdown, :device_offline}, new_state}
      end

      # NOTICE: we crash on messages that do not come from the notification system for the correct topics

      @impl GenServer
      def terminate(:normal, state) do
        %{
          resource_deployment: %{id: id, device_id: device_id} = resource_deployment,
          retries: retries
        } = state

        Logger.info("""
        #{unquote(type_string_camel)} deployment #{id} successfully provisioned after #{retries} retries.
        """)

        # Broadcast readiness so that the orchestrator can proceed
        Phoenix.PubSub.broadcast(
          Edgehog.PubSub,
          "ready:#{unquote(deployment_string_lower)}s:#{id}",
          {:ready, resource_deployment}
        )

        # Unsubscribe from events, we're terminating
        Phoenix.PubSub.unsubscribe(Edgehog.PubSub, "#{unquote(deployment_string_lower)}s:#{id}")
        Phoenix.PubSub.unsubscribe(Edgehog.PubSub, "devices:offline:#{device_id}")
      end

      @impl GenServer
      def terminate({:shutdown, reason}, %{resource_deployment: resource_deployment})
          when reason in [:max_retries, :device_offline, :timeout_hit] do
        %{id: id, device_id: device_id} = resource_deployment

        Logger.info("""
        Provisioner for #{unquote(type_string_lower)} deployment #{id} gave up with reason #{inspect(reason)}.
        """)

        # Broadcast readiness so that the orchestrator can proceed
        Phoenix.PubSub.broadcast(
          Edgehog.PubSub,
          "ready:#{unquote(deployment_string_lower)}s:#{id}",
          {:failure, resource_deployment}
        )

        # Unsubscribe from events, we're terminating
        Phoenix.PubSub.unsubscribe(Edgehog.PubSub, "#{unquote(deployment_string_lower)}s:#{id}")
        Phoenix.PubSub.unsubscribe(Edgehog.PubSub, "devices:offline:#{device_id}")
      end

      @impl GenServer
      def terminate(reason, state) do
        %{
          resource_deployment: %{id: id, device: %{id: device_id}}
        } = state

        Logger.warning(
          """
          Unexpectedly terminating provisioner for #{unquote(type_string_lower)} deployment #{id} on device #{device_id}.
          Reason: #{inspect(reason)}
          """,
          reason: reason,
          provisioner_state: state
        )
      end

      @status_module unquote(status_module)
      @type_atom unquote(type_atom)
      @string_type unquote(string_type)
      @type_string_camel unquote(type_string_camel)
      @type_string_lower unquote(type_string_lower)
      @deployment_string_lower unquote(deployment_string_lower)
      @available_atom unquote(available_atom)

      defmodule unquote(core_module) do
        use Provisioner.Core, status_verb_key: unquote(status_verb_key)
      end
    end
  end

  defp snake_to_camel(str, camel_delimiter \\ " ") do
    str |> String.split("_") |> Enum.map_join(camel_delimiter, &String.capitalize/1)
  end
end
