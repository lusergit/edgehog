/*
  This file is part of Edgehog.

  Copyright 2021 SECO Mind Srl

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/

import { MockPayloadGenerator } from "relay-test-utils";

const relayMockResolvers: MockPayloadGenerator.MockResolvers = {
  ApplianceModel() {
    return {
      handle: "esp32-dev-kit-c",
      name: "ESP32-DevKitC",
      partNumbers: ["AM_0000001"],
    };
  },
  Device() {
    return {
      deviceId: "DqL4H107S42WBEHmDrvPLQ",
      id: "1",
      name: "Thingie",
    };
  },
  HardwareInfo() {
    return {
      cpuArchitecture: "Xtensa 32-bit",
      cpuModel: "ESP32-C3",
      cpuModelName: "ESP32-DevKitC",
      cpuVendor: "Espressif",
      memoryTotalBytes: 409600,
    };
  },
  HardwareType() {
    return {
      handle: "esp32",
      name: "ESP32",
      partNumbers: ["HT_0000001"],
    };
  },
  DeviceLocation() {
    return {
      latitude: 45.463,
      longitude: 9.188,
      accuracy: 10,
      address: "Via Speronari, 7, 20123 Milano MI",
      timestamp: "2021-11-11T09:43:54.437Z",
    };
  },
};

export { relayMockResolvers };
