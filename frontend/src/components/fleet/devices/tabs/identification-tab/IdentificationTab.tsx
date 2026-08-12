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

import { useState } from "react";
import { graphql, useFragment } from "react-relay/hooks";
import { useIntl } from "react-intl";
import { Card } from "react-bootstrap";

import type { IdentificationTab_device$key } from "@/api/__generated__/IdentificationTab_device.graphql";

import Alert from "@/components/ui/alert/Alert";
import Figure from "@/components/ui/figure/Figure";
import Stack from "@/components/ui/stack/Stack";
import { Tab } from "@/components/ui/tabs/Tabs";
import LedBehaviorButtons from "@/components/fleet/devices/led-behavior-buttons/LedBehaviorButtons";
import RemoteTerminal from "@/components/fleet/devices/remote-terminal/RemoteTerminal";
import assets from "@/assets";

const IDENTIFICATION_TAB_FRAGMENT = graphql`
  fragment IdentificationTab_device on Device {
    id
    name
    online
    capabilities
    systemModel {
      pictureUrl
    }
  }
`;

interface IdentificationTabProps {
  deviceRef: IdentificationTab_device$key;
  isForwarderSupported: boolean;
}

const DeviceIdentificationTab = ({
  deviceRef,
  isForwarderSupported,
}: IdentificationTabProps) => {
  const intl = useIntl();
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const device = useFragment(IDENTIFICATION_TAB_FRAGMENT, deviceRef);

  const isRemoteTerminalSupported =
    isForwarderSupported && device.capabilities.includes("REMOTE_TERMINAL");

  return (
    <Tab
      className="pt-3 d-flex flex-column flex-grow-1"
      eventKey="device-identification-tab"
      title={intl.formatMessage({
        id: "components.fleet.devices.tabs.identification-tab.IdentificationTab.title",
        defaultMessage: "Identification",
      })}
    >
      <Card className="gap-2 border-0 shadow-sm flex-grow-1 p-4">
        <Alert
          className="mt-3"
          show={!!errorFeedback}
          variant="danger"
          onClose={() => setErrorFeedback(null)}
          dismissible
        >
          {errorFeedback}
        </Alert>
        <Figure
          alt={device.name}
          src={device.systemModel?.pictureUrl || assets.images.devices}
        />
        <Stack gap={3} className="align-items-start">
          {isRemoteTerminalSupported && (
            <RemoteTerminal
              deviceId={device.id}
              disabled={!device.online}
              onError={setErrorFeedback}
            />
          )}
          {device.capabilities.includes("LED_BEHAVIORS") && (
            <LedBehaviorButtons
              deviceId={device.id}
              disabled={!device.online}
              onError={setErrorFeedback}
            />
          )}
        </Stack>
      </Card>
    </Tab>
  );
};

export default DeviceIdentificationTab;
