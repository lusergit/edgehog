/*
 * This file is part of Edgehog.
 *
 * Copyright 2026 SECO Mind Srl
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import { Suspense } from "react";
import { it, expect, vi, beforeAll } from "vitest";
import { act, screen, fireEvent, waitFor } from "@testing-library/react";
import { createMockEnvironment } from "relay-test-utils";
import { graphql, useLazyLoadQuery } from "react-relay/hooks";

import { renderWithProviders } from "@/setupTests";
import type { IdentificationTab_TestQuery } from "@/api/__generated__/IdentificationTab_TestQuery.graphql";
import Tabs from "@/components/ui/tabs/Tabs";
import DeviceIdentificationTab from "./IdentificationTab";

beforeAll(() => {
  Element.prototype.scrollTo = vi.fn();
});

const TEST_QUERY = graphql`
  query IdentificationTab_TestQuery($id: ID!) @relay_test_operation {
    device(id: $id) {
      ...IdentificationTab_device
    }
  }
`;

type DevicePayload = {
  id: string;
  name: string;
  online: boolean;
  capabilities: string[];
  systemModel: {
    pictureUrl: string | null;
  };
};

const createDevicePayload = ({
  online = true,
  capabilities = ["LED_BEHAVIORS", "REMOTE_TERMINAL"],
}: {
  online?: boolean;
  capabilities?: string[];
} = {}): DevicePayload => ({
  id: "device-1",
  name: "Test Device",
  online,
  capabilities,
  systemModel: {
    pictureUrl: "picture-url",
  },
});

type RenderTabParams = {
  device?: DevicePayload;
  isForwarderSupported?: boolean;
};

const renderTab = ({
  device = createDevicePayload(),
  isForwarderSupported = true,
}: RenderTabParams = {}) => {
  const relayEnvironment = createMockEnvironment();

  const ComponentWithQuery = () => {
    const data = useLazyLoadQuery<IdentificationTab_TestQuery>(TEST_QUERY, {
      id: "device-1",
    });

    if (!data.device) {
      return null;
    }

    return (
      <DeviceIdentificationTab
        deviceRef={data.device}
        isForwarderSupported={isForwarderSupported}
      />
    );
  };

  renderWithProviders(
    <Suspense fallback={null}>
      <Tabs activeKey="device-identification-tab">
        <ComponentWithQuery />
      </Tabs>
    </Suspense>,
    {
      relayEnvironment,
      path: "/devices/device-1",
      route: "/devices/:deviceId",
    },
  );

  act(() => {
    const operation = relayEnvironment.mock.findOperation(
      (op) => op.request.node.params.name === "IdentificationTab_TestQuery",
    );
    relayEnvironment.mock.resolve(operation, { data: { device } });
  });

  return { relayEnvironment };
};

it("renders the device image, terminal and LED behavior buttons", async () => {
  renderTab();

  expect(await screen.findByAltText("Test Device")).toBeVisible();
  expect(screen.getByRole("button", { name: "Open terminal" })).toBeVisible();
  expect(screen.getByRole("button", { name: "Blink LED" })).toBeVisible();
  expect(
    screen.getByRole("button", { name: "Double blink LED" }),
  ).toBeVisible();
  expect(screen.getByRole("button", { name: "Slow blink LED" })).toBeVisible();
});

it("hides the terminal when the capability or forwarder support is missing", async () => {
  renderTab({
    device: createDevicePayload({ capabilities: ["LED_BEHAVIORS"] }),
    isForwarderSupported: false,
  });

  await screen.findByAltText("Test Device");
  expect(screen.getByRole("button", { name: "Blink LED" })).toBeVisible();
  expect(
    screen.queryByRole("button", { name: "Open terminal" }),
  ).not.toBeInTheDocument();
});

it("disables the identification buttons while the device is offline", async () => {
  renderTab({
    device: createDevicePayload({ online: false }),
  });

  await screen.findByAltText("Test Device");
  expect(screen.getByRole("button", { name: "Open terminal" })).toBeDisabled();
  expect(screen.getByRole("button", { name: "Blink LED" })).toBeDisabled();
  expect(
    screen.getByRole("button", { name: "Double blink LED" }),
  ).toBeDisabled();
  expect(screen.getByRole("button", { name: "Slow blink LED" })).toBeDisabled();
});

it("requests a forwarder session when the terminal is opened", async () => {
  const { relayEnvironment } = renderTab();

  await screen.findByAltText("Test Device");

  fireEvent.click(screen.getByRole("button", { name: "Open terminal" }));

  await waitFor(() => {
    const operation = relayEnvironment.mock
      .getAllOperations()
      .find(
        (op) =>
          op.request.node.params.name ===
          "RemoteTerminal_requestForwarderSession_Mutation",
      );
    expect(operation?.request.variables).toEqual({
      input: { deviceId: "device-1" },
    });
  });
});

it("sets the LED behavior when a blink button is pressed", async () => {
  const { relayEnvironment } = renderTab();

  await screen.findByAltText("Test Device");

  fireEvent.click(screen.getByRole("button", { name: "Double blink LED" }));

  await waitFor(() => {
    const operation = relayEnvironment.mock
      .getAllOperations()
      .find(
        (op) =>
          op.request.node.params.name ===
          "LedBehaviorButtons_setLedBehavior_Mutation",
      );
    expect(operation?.request.variables).toEqual({
      deviceId: "device-1",
      input: { behavior: "DOUBLE_BLINK" },
    });
  });
});
