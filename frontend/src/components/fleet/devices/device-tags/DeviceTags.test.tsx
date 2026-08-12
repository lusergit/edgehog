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
import { act, fireEvent, screen, waitFor } from "@testing-library/react";
import { createMockEnvironment } from "relay-test-utils";

import { renderWithProviders } from "@/setupTests";
import DeviceTags from "./DeviceTags";

const renderDeviceTags = () => {
  const relayEnvironment = createMockEnvironment();
  const refreshTags = vi.fn();
  const onError = vi.fn();

  renderWithProviders(
    <DeviceTags
      deviceId="device-1"
      tags={[
        { id: "tag-1", name: "tag-one" },
        { id: "tag-2", name: "tag-two" },
      ]}
      options={[{ label: "existing-tag", value: "existing-tag" }]}
      refreshTags={refreshTags}
      onError={onError}
    />,
    { relayEnvironment },
  );

  return { relayEnvironment, refreshTags, onError };
};

it("renders the tags and the add button", () => {
  renderDeviceTags();

  expect(screen.getByText("tag-one")).toBeVisible();
  expect(screen.getByText("tag-two")).toBeVisible();
  expect(screen.getByRole("button", { name: "Add tag" })).toBeVisible();
});

it("adds a tag through the add button", async () => {
  const { relayEnvironment, refreshTags } = renderDeviceTags();

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

it("removes a tag through its remove button", async () => {
  const { relayEnvironment } = renderDeviceTags();

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
