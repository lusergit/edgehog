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

import { it, expect, vi } from "vitest";
import { fireEvent, screen, waitFor } from "@testing-library/react";
import { createMockEnvironment } from "relay-test-utils";

import { renderWithProviders } from "@/setupTests";
import DeviceName from "./DeviceName";

const renderDeviceName = () => {
  const relayEnvironment = createMockEnvironment();
  const onError = vi.fn();

  renderWithProviders(
    <DeviceName name="Test Device" deviceId="device-1" onError={onError} />,
    { relayEnvironment },
  );

  return { relayEnvironment, onError };
};

it("renders the device name as plain text", () => {
  renderDeviceName();

  expect(screen.getByText("Test Device")).toBeVisible();
  expect(screen.queryByRole("textbox", { name: "" })).not.toBeInTheDocument();
});

it("makes the name editable after clicking the edit button", async () => {
  renderDeviceName();

  fireEvent.click(screen.getByRole("button", { name: "Edit device name" }));

  expect(await screen.findByDisplayValue("Test Device")).toBeVisible();
  expect(
    screen.getByRole("button", { name: "Save device name" }),
  ).toBeVisible();
  expect(screen.getByRole("button", { name: "Cancel" })).toBeVisible();
});

it("commits the update mutation when saving", async () => {
  const { relayEnvironment } = renderDeviceName();

  fireEvent.click(screen.getByRole("button", { name: "Edit device name" }));
  fireEvent.change(await screen.findByDisplayValue("Test Device"), {
    target: { value: "New Device Name" },
  });
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

it("restores the name when canceling", async () => {
  renderDeviceName();

  fireEvent.click(screen.getByRole("button", { name: "Edit device name" }));
  fireEvent.change(await screen.findByDisplayValue("Test Device"), {
    target: { value: "Discarded Name" },
  });
  fireEvent.click(screen.getByRole("button", { name: "Cancel" }));

  expect(screen.getByText("Test Device")).toBeVisible();
  expect(screen.queryByDisplayValue("Discarded Name")).not.toBeInTheDocument();
});
