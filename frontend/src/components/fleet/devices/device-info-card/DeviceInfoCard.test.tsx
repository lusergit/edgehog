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
import selectEvent from "react-select-event";
import { createMockEnvironment } from "relay-test-utils";
import { graphql, useLazyLoadQuery } from "react-relay/hooks";

import { renderWithProviders } from "@/setupTests";
import type { DeviceInfoCard_TestQuery } from "@/api/__generated__/DeviceInfoCard_TestQuery.graphql";
import DeviceInfoCard from "./DeviceInfoCard";

beforeAll(() => {
  Element.prototype.scrollTo = vi.fn();
});

const TEST_QUERY = graphql`
  query DeviceInfoCard_TestQuery($id: ID!) @relay_test_operation {
    device(id: $id) {
      ...DeviceInfoCard_device
    }
  }
`;

type DevicePayload = {
  id: string;
  name: string;
  deviceId: string;
  serialNumber: string;
  partNumber: string;
  online: boolean;
  capabilities: string[];
  systemModel: {
    name: string;
    hardwareType: {
      name: string;
    };
  };
  tags: {
    edges: {
      node: {
        id: string;
        name: string;
      };
    }[];
  };
  deviceGroups: {
    id: string;
    name: string;
  }[];
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
  deviceId: "device-1",
  serialNumber: "SN-123",
  partNumber: "PN-456",
  online,
  capabilities,
  systemModel: {
    name: "Test System Model",
    hardwareType: {
      name: "Test Hardware Type",
    },
  },
  tags: {
    edges: [
      {
        node: {
          id: "tag-1",
          name: "tag-one",
        },
      },
    ],
  },
  deviceGroups: [
    {
      id: "group-1",
      name: "Group One",
    },
  ],
});

type RenderCardParams = {
  device?: DevicePayload;
  isForwarderSupported?: boolean;
  tags?: { label: string; value: string }[];
};

const renderCard = ({
  device = createDevicePayload(),
  isForwarderSupported = true,
  tags = [{ label: "existing-tag", value: "existing-tag" }],
}: RenderCardParams = {}) => {
  const relayEnvironment = createMockEnvironment();
  const refreshTags = vi.fn();
  const onError = vi.fn();

  const ComponentWithQuery = () => {
    const data = useLazyLoadQuery<DeviceInfoCard_TestQuery>(TEST_QUERY, {
      id: "device-1",
    });

    if (!data.device) {
      return null;
    }

    return (
      <DeviceInfoCard
        deviceRef={data.device}
        tags={tags}
        refreshTags={refreshTags}
        isForwarderSupported={isForwarderSupported}
        onError={onError}
      />
    );
  };

  renderWithProviders(
    <Suspense fallback={null}>
      <ComponentWithQuery />
    </Suspense>,
    {
      relayEnvironment,
      path: "/devices/device-1",
      route: "/devices/:deviceId",
    },
  );

  act(() => {
    const operation = relayEnvironment.mock.findOperation(
      (op) => op.request.node.params.name === "DeviceInfoCard_TestQuery",
    );
    relayEnvironment.mock.resolve(operation, { data: { device } });
  });

  return { relayEnvironment, refreshTags, onError };
};

it("renders the device details", async () => {
  renderCard();

  expect(await screen.findByDisplayValue("Test Device")).toBeVisible();
  expect(screen.getByText("device-1")).toBeVisible();
  expect(screen.getByText("SN-123")).toBeVisible();
  expect(screen.getByText("PN-456")).toBeVisible();
  expect(screen.getByText("Test System Model")).toBeVisible();
  expect(screen.getByText("Test Hardware Type")).toBeVisible();
  expect(screen.getByText("Group One")).toBeVisible();
  expect(screen.getByText("Online")).toBeVisible();
  expect(screen.getByText("Now")).toBeVisible();
});

it("shows the LED behaviors and remote terminal rows when supported", async () => {
  renderCard();

  await screen.findByDisplayValue("Test Device");
  expect(screen.getByText("Check my Device")).toBeVisible();
  expect(screen.getByRole("button", { name: "Open" })).toBeVisible();
});

it("hides the remote terminal row when the capability or forwarder support is missing", async () => {
  renderCard({
    device: createDevicePayload({ capabilities: ["LED_BEHAVIORS"] }),
    isForwarderSupported: false,
  });

  await screen.findByDisplayValue("Test Device");
  expect(screen.getByText("Check my Device")).toBeVisible();
  expect(
    screen.queryByRole("button", { name: "Open" }),
  ).not.toBeInTheDocument();
  expect(screen.queryByText("Remote Terminal")).not.toBeInTheDocument();
});

it("disables the remote terminal button while the device is offline", async () => {
  renderCard({
    device: createDevicePayload({ online: false }),
  });

  await screen.findByDisplayValue("Test Device");
  expect(screen.getByRole("button", { name: "Open" })).toBeDisabled();
});

it("updates the device name by committing the update mutation", async () => {
  const { relayEnvironment } = renderCard();

  await screen.findByDisplayValue("Test Device");

  fireEvent.change(screen.getByLabelText("Name"), {
    target: { value: "New Device Name" },
  });

  await waitFor(() => {
    const operation = relayEnvironment.mock
      .getAllOperations()
      .find(
        (op) =>
          op.request.node.params.name ===
          "DeviceInfoCard_updateDevice_Mutation",
      );
    expect(operation?.request.variables).toEqual({
      deviceId: "device-1",
      input: { name: "New Device Name" },
    });
  });
});

it("adds a tag to the device by committing the add tags mutation", async () => {
  const { relayEnvironment, refreshTags } = renderCard();

  await screen.findByDisplayValue("Test Device");

  await selectEvent.select(screen.getAllByRole("combobox")[0], "existing-tag");

  await waitFor(() => {
    const operation = relayEnvironment.mock
      .getAllOperations()
      .find(
        (op) =>
          op.request.node.params.name ===
          "DeviceInfoCard_addDeviceTags_Mutation",
      );
    expect(operation?.request.variables).toEqual({
      deviceId: "device-1",
      input: { tags: ["existing-tag"] },
    });
  });

  act(() => {
    relayEnvironment.mock.resolveMostRecentOperation({
      data: {
        addDeviceTags: {
          result: {
            id: "device-1",
            tags: {
              edges: [
                {
                  node: { id: "tag-1", name: "tag-one" },
                },
                {
                  node: { id: "tag-2", name: "existing-tag" },
                },
              ],
            },
            deviceGroups: [
              {
                id: "group-1",
                name: "Group One",
              },
            ],
          },
        },
      },
    });
  });

  expect(refreshTags).toHaveBeenCalled();
});

it("shows the port input with default 7681 and secure checkbox unchecked", async () => {
  renderCard();

  await screen.findByDisplayValue("Test Device");
  const portInput = screen.getByLabelText("Port");
  const secureCheckbox = screen.getByLabelText("Secure (HTTPS)");

  expect(portInput).toBeVisible();
  expect(portInput).toHaveValue(7681);
  expect(secureCheckbox).toBeVisible();
  expect(secureCheckbox).not.toBeChecked();
});

it("disables the remote terminal button when an invalid port is entered", async () => {
  renderCard();
  await screen.findByDisplayValue("Test Device");

  const portInput = screen.getByLabelText("Port");
  const openButton = screen.getByRole("button", { name: "Open" });

  expect(openButton).toBeEnabled();

  // Empty port
  fireEvent.change(portInput, { target: { value: "" } });
  expect(openButton).toBeDisabled();
  expect(portInput).toHaveClass("is-invalid");

  // Port 0
  fireEvent.change(portInput, { target: { value: "0" } });
  expect(openButton).toBeDisabled();
  expect(portInput).toHaveClass("is-invalid");

  // Port > 65535
  fireEvent.change(portInput, { target: { value: "70000" } });
  expect(openButton).toBeDisabled();
  expect(portInput).toHaveClass("is-invalid");

  // Valid port
  fireEvent.change(portInput, { target: { value: "8080" } });
  expect(openButton).toBeEnabled();
  expect(portInput).not.toHaveClass("is-invalid");
});

it("opens remote terminal with default port and protocol", async () => {
  const windowOpenSpy = vi.spyOn(window, "open").mockImplementation(() => null);
  const { relayEnvironment } = renderCard();

  await screen.findByDisplayValue("Test Device");

  fireEvent.click(screen.getByRole("button", { name: "Open" }));

  await waitFor(() => {
    const operation = relayEnvironment.mock
      .getAllOperations()
      .find(
        (op) =>
          op.request.node.params.name ===
          "DeviceInfoCard_requestForwarderSession_Mutation",
      );
    expect(operation).toBeDefined();
  });

  act(() => {
    relayEnvironment.mock.resolveMostRecentOperation({
      data: {
        requestForwarderSession: "token-abc-123",
      },
    });
  });

  await waitFor(() => {
    const operation = relayEnvironment.mock
      .getAllOperations()
      .find(
        (op) =>
          op.request.node.params.name ===
          "DeviceInfoCard_getForwarderSession_Query",
      );
    expect(operation).toBeDefined();
  });

  act(() => {
    relayEnvironment.mock.resolveMostRecentOperation({
      data: {
        forwarderSession: {
          status: "CONNECTED",
          secure: false,
          forwarderHostname: "forwarder.local",
          forwarderPort: 4001,
        },
      },
    });
  });

  await waitFor(() => {
    expect(windowOpenSpy).toHaveBeenCalledWith(
      "http://forwarder.local:4001/token-abc-123/http/7681",
      "_blank",
    );
  });

  windowOpenSpy.mockRestore();
});

it("opens remote terminal with custom port and https protocol", async () => {
  const windowOpenSpy = vi.spyOn(window, "open").mockImplementation(() => null);
  const { relayEnvironment } = renderCard();

  await screen.findByDisplayValue("Test Device");

  const portInput = screen.getByLabelText("Port");
  const secureCheckbox = screen.getByLabelText("Secure (HTTPS)");

  fireEvent.change(portInput, { target: { value: "8443" } });
  fireEvent.click(secureCheckbox);

  fireEvent.click(screen.getByRole("button", { name: "Open" }));

  await waitFor(() => {
    const operation = relayEnvironment.mock
      .getAllOperations()
      .find(
        (op) =>
          op.request.node.params.name ===
          "DeviceInfoCard_requestForwarderSession_Mutation",
      );
    expect(operation).toBeDefined();
  });

  act(() => {
    relayEnvironment.mock.resolveMostRecentOperation({
      data: {
        requestForwarderSession: "token-xyz-456",
      },
    });
  });

  await waitFor(() => {
    const operation = relayEnvironment.mock
      .getAllOperations()
      .find(
        (op) =>
          op.request.node.params.name ===
          "DeviceInfoCard_getForwarderSession_Query",
      );
    expect(operation).toBeDefined();
  });

  act(() => {
    relayEnvironment.mock.resolveMostRecentOperation({
      data: {
        forwarderSession: {
          status: "CONNECTED",
          secure: true,
          forwarderHostname: "forwarder.local",
          forwarderPort: 4001,
        },
      },
    });
  });

  await waitFor(() => {
    expect(windowOpenSpy).toHaveBeenCalledWith(
      "https://forwarder.local:4001/token-xyz-456/https/8443",
      "_blank",
    );
  });

  windowOpenSpy.mockRestore();
});
