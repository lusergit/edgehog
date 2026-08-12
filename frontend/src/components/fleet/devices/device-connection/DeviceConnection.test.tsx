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

import { it, expect } from "vitest";

import { renderWithProviders } from "@/setupTests";
import DeviceConnection from "./DeviceConnection";

it("shows Online for a connected device", () => {
  const { container } = renderWithProviders(
    <DeviceConnection online lastConnection="2021-11-08T15:43:34.706Z" />,
  );
  expect(container).toHaveTextContent("Online");
});

it("shows Offline and the last time online for a disconnected device", () => {
  const { container } = renderWithProviders(
    <DeviceConnection
      online={false}
      lastConnection="2021-11-08T15:43:34.706Z"
    />,
  );
  expect(container).toHaveTextContent("Offline");
  expect(container).toHaveTextContent(/Last seen/);
});

it("shows only Offline when the device never connected", () => {
  const { container } = renderWithProviders(
    <DeviceConnection online={false} lastConnection={null} />,
  );
  expect(container).toHaveTextContent("Offline");
  expect(container).not.toHaveTextContent(/Last seen/);
});
