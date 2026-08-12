// This file is part of Edgehog.
//
// Copyright 2021-2026 SECO Mind Srl
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

import { ReactNode, useMemo } from "react";
import { graphql, useFragment } from "react-relay/hooks";
import { FormattedMessage } from "react-intl";
import { Card } from "react-bootstrap";

import type { DeviceInfoCard_device$key } from "@/api/__generated__/DeviceInfoCard_device.graphql";

import { Link, Route } from "@/Navigation";
import DeviceConnection from "@/components/fleet/devices/device-connection/DeviceConnection";
import DeviceInformation from "@/components/fleet/devices/device-information/DeviceInformation";
import DeviceName from "@/components/fleet/devices/device-name/DeviceName";
import DeviceTags from "@/components/fleet/devices/device-tags/DeviceTags";
import Stack from "@/components/ui/stack/Stack";

const DEVICE_INFO_CARD_FRAGMENT = graphql`
  fragment DeviceInfoCard_device on Device {
    id
    name
    deviceId
    serialNumber
    partNumber
    online
    lastConnection
    lastDisconnection
    systemModel {
      name
      hardwareType {
        name
      }
    }
    tags {
      edges {
        node {
          id
          name
        }
      }
    }
    deviceGroups {
      id
      name
    }
  }
`;

interface DeviceInfoCardProps {
  deviceRef: DeviceInfoCard_device$key;
  tags?: { label: string; value: string }[];
  refreshTags: () => void;
  onError: (feedback: ReactNode) => void;
}

const DeviceInfoCard = ({
  deviceRef,
  tags,
  refreshTags,
  onError,
}: DeviceInfoCardProps) => {
  const device = useFragment(DEVICE_INFO_CARD_FRAGMENT, deviceRef);

  const deviceTags = useMemo(
    () =>
      device.tags?.edges?.map(({ node: { id, name: tag } }) => ({
        id,
        name: tag,
      })) || [],
    [device.tags],
  );

  return (
    <Card className="h-100 border-0 p-3 shadow-sm mb-2">
      <Stack gap={3}>
        <DeviceName name={device.name} deviceId={device.id} onError={onError} />
        <DeviceConnection
          online={device.online}
          lastConnection={device.lastConnection}
        />
        <DeviceTags
          deviceId={device.id}
          tags={deviceTags}
          options={tags || []}
          refreshTags={refreshTags}
          onError={onError}
        />
        <DeviceInformation
          deviceId={device.deviceId}
          serialNumber={device.serialNumber}
          partNumber={device.partNumber}
          systemModelName={device.systemModel?.name}
          hardwareTypeName={device.systemModel?.hardwareType?.name}
        />
        {device.deviceGroups.length > 0 && (
          <div className="d-flex flex-wrap align-items-center column-gap-3">
            <span className="text-secondary">
              <FormattedMessage
                id="components.fleet.devices.device-info-card.DeviceInfoCard.groups"
                defaultMessage="Groups"
              />
            </span>
            {device.deviceGroups.map((deviceGroup) => (
              <Link
                key={`device-group-link-${deviceGroup.id}`}
                route={Route.deviceGroupsEdit}
                params={{ deviceGroupId: deviceGroup.id }}
              >
                {deviceGroup.name}
              </Link>
            ))}
          </div>
        )}
      </Stack>
    </Card>
  );
};

export default DeviceInfoCard;
