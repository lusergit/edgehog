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
import RemoteTerminal from "./RemoteTerminal";

const renderRemoteTerminal = ({ disabled = false } = {}) => {
  const relayEnvironment = createMockEnvironment();
  const onError = vi.fn();

  renderWithProviders(
    <RemoteTerminal
      deviceId="device-1"
      disabled={disabled}
      onError={onError}
    />,
    { relayEnvironment },
  );

  return { relayEnvironment, onError };
};

it("renders the terminal button with an icon", () => {
  renderRemoteTerminal();

  expect(screen.getByRole("button", { name: "Open terminal" })).toBeVisible();
});

it("disables the terminal button when disabled", () => {
  renderRemoteTerminal({ disabled: true });

  expect(screen.getByRole("button", { name: "Open terminal" })).toBeDisabled();
});

it("requests a forwarder session when clicked", async () => {
  const { relayEnvironment } = renderRemoteTerminal();

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
