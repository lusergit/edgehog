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
import LedBehaviorButtons from "./LedBehaviorButtons";

const renderLedBehaviorButtons = ({ disabled = false } = {}) => {
  const relayEnvironment = createMockEnvironment();
  const onError = vi.fn();

  renderWithProviders(
    <LedBehaviorButtons
      deviceId="device-1"
      disabled={disabled}
      onError={onError}
    />,
    { relayEnvironment },
  );

  return { relayEnvironment, onError };
};

it("renders the three LED behavior buttons", () => {
  renderLedBehaviorButtons();

  expect(screen.getByRole("button", { name: "Blink LED" })).toBeVisible();
  expect(
    screen.getByRole("button", { name: "Double blink LED" }),
  ).toBeVisible();
  expect(screen.getByRole("button", { name: "Slow blink LED" })).toBeVisible();
});

it("disables the buttons when disabled", () => {
  renderLedBehaviorButtons({ disabled: true });

  expect(screen.getByRole("button", { name: "Blink LED" })).toBeDisabled();
  expect(
    screen.getByRole("button", { name: "Double blink LED" }),
  ).toBeDisabled();
  expect(screen.getByRole("button", { name: "Slow blink LED" })).toBeDisabled();
});

it("sets the LED behavior when a button is clicked", async () => {
  const { relayEnvironment } = renderLedBehaviorButtons();

  fireEvent.click(screen.getByRole("button", { name: "Slow blink LED" }));

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
      input: { behavior: "SLOW_BLINK" },
    });
  });
});
