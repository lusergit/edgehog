// This file is part of Edgehog.
//
// Copyright 2026 SECO Mind Srl
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

import Col from "@/components/ui/col/Col";
import Row from "@/components/ui/row/Row";

interface DeviceInformationProps {
  deviceId?: string | null;
  serialNumber?: string | null;
  partNumber?: string | null;
  systemModelName?: string | null;
  hardwareTypeName?: string | null;
}

interface InformationEntryProps {
  label: string;
  value?: string | null;
}

const InformationEntry = ({ label, value }: InformationEntryProps) => (
  <span className="text-nowrap">
    <span className="text-secondary">{label}</span> {value ?? "-"}
  </span>
);

const DeviceInformation = ({
  deviceId,
  serialNumber,
  partNumber,
  systemModelName,
  hardwareTypeName,
}: DeviceInformationProps) => (
  <Row className="gy-1">
    <Col xs={12} className="d-flex flex-wrap column-gap-3">
      <InformationEntry label="ID" value={deviceId} />
      <InformationEntry label="SN" value={serialNumber} />
      <InformationEntry label="PN" value={partNumber} />
    </Col>
    <Col xs={12} className="d-flex flex-wrap column-gap-3">
      <InformationEntry label="SM" value={systemModelName} />
      <InformationEntry label="HT" value={hardwareTypeName} />
    </Col>
  </Row>
);

export default DeviceInformation;
