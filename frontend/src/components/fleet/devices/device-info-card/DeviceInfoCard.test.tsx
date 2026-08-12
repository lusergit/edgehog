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
  lastConnection: string | null;
  lastDisconnection: string | null;
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
  lastConnection = "2021-11-08T15:43:34.706Z",
}: {
  online?: boolean;
  lastConnection?: string | null;
} = {}): DevicePayload => ({
  id: "device-1",
  name: "Test Device",
  deviceId: "device-1",
  serialNumber: "SN-123",
  partNumber: "PN-456",
  online,
  lastConnection,
  lastDisconnection: online ? null : "2021-11-08T15:43:34.706Z",
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
  tags?: { label: string; value: string }[];
};

const renderCard = ({
  device = createDevicePayload(),
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

  expect(await screen.findByText("Test Device")).toBeVisible();
  expect(screen.getByText("device-1")).toBeVisible();
  expect(screen.getByText("SN-123")).toBeVisible();
  expect(screen.getByText("PN-456")).toBeVisible();
  expect(screen.getByText("Test System Model")).toBeVisible();
  expect(screen.getByText("Test Hardware Type")).toBeVisible();
  expect(screen.getByText("Group One")).toBeVisible();
  expect(screen.getByText("Online")).toBeVisible();
  expect(screen.getByText("tag-one")).toBeVisible();
});

it("shows the connection state and last time online when offline", async () => {
  renderCard({
    device: createDevicePayload({
      online: false,
      lastConnection: "2021-11-08T15:43:34.706Z",
    }),
  });

  expect(await screen.findByText("Offline")).toBeVisible();
  expect(screen.getByText(/Last seen/)).toBeVisible();
});

it("updates the device name after editing", async () => {
  const { relayEnvironment } = renderCard();

  await screen.findByText("Test Device");

  fireEvent.click(screen.getByRole("button", { name: "Edit device name" }));

  const input = await screen.findByDisplayValue("Test Device");
  fireEvent.change(input, { target: { value: "New Device Name" } });
  fireEvent.click(screen.getByRole("button", { name: "Save device name" }));

  await waitFor(() => {
    const operation = relayEnvironment.mock
      .getAllOperations()
      .find(
        (op) =>
          op.request.node.params.name === "DeviceName_updateDevice_Mutation",
      );
    expect(operation?.request.variables).toEqual({
      deviceId: "device-1",
      input: { name: "New Device Name" },
    });
  });
});

it("cancels the device name edit without committing", async () => {
  const { relayEnvironment } = renderCard();

  await screen.findByText("Test Device");

  fireEvent.click(screen.getByRole("button", { name: "Edit device name" }));
  fireEvent.change(await screen.findByDisplayValue("Test Device"), {
    target: { value: "Discarded Name" },
  });
  fireEvent.click(screen.getByRole("button", { name: "Cancel" }));

  expect(screen.getByText("Test Device")).toBeVisible();
  expect(
    relayEnvironment.mock
      .getAllOperations()
      .some(
        (op) =>
          op.request.node.params.name === "DeviceName_updateDevice_Mutation",
      ),
  ).toBe(false);
});

it("adds a tag through the add button", async () => {
  const { relayEnvironment, refreshTags } = renderCard();

  await screen.findByText("Test Device");

  fireEvent.click(screen.getByRole("button", { name: "Add tag" }));

  const input = await screen.findByDisplayValue("");
  fireEvent.change(input, { target: { value: "new-tag" } });
  fireEvent.keyDown(input, { key: "Enter" });

  await waitFor(() => {
    const operation = relayEnvironment.mock
      .getAllOperations()
      .find(
        (op) =>
          op.request.node.params.name === "DeviceTags_addDeviceTags_Mutation",
      );
    expect(operation?.request.variables).toEqual({
      deviceId: "device-1",
      input: { tags: ["new-tag"] },
    });
  });

  act(() => {
    relayEnvironment.mock.resolveMostRecentOperation({
      data: {
        addDeviceTags: {
          result: {
            id: "device-1",
            tags: { edges: [] },
            deviceGroups: [],
          },
        },
      },
    });
  });

  expect(refreshTags).toHaveBeenCalled();
});

it("removes a tag through the tag remove button", async () => {
  const { relayEnvironment } = renderCard();

  await screen.findByText("Test Device");

  fireEvent.click(screen.getByRole("button", { name: "Remove tag-one tag" }));

  await waitFor(() => {
    const operation = relayEnvironment.mock
      .getAllOperations()
      .find(
        (op) =>
          op.request.node.params.name ===
          "DeviceTags_removeDeviceTags_Mutation",
      );
    expect(operation?.request.variables).toEqual({
      deviceId: "device-1",
      input: { tags: ["tag-one"] },
    });
  });
});
