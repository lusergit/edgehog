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
import assets from "@/assets";
import { openRemoteTerminal } from "@/lib/remoteTerminal";

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
    ...DeviceInfoCard_connectionStatus
  }
`;

const CONNECTION_STATUS_FRAGMENT = graphql`
  fragment DeviceInfoCard_connectionStatus on Device {
    online
    lastConnection
    lastDisconnection
  }
`;

const UPDATE_DEVICE_MUTATION = graphql`
  mutation DeviceInfoCard_updateDevice_Mutation(
    $deviceId: ID!
    $input: UpdateDeviceInput!
  ) {
    updateDevice(id: $deviceId, input: $input) {
      result {
        id
        name
      }
    }
  }
`;

const ADD_DEVICE_TAGS_MUTATION = graphql`
  mutation DeviceInfoCard_addDeviceTags_Mutation(
    $deviceId: ID!
    $input: AddDeviceTagsInput!
  ) {
    addDeviceTags(id: $deviceId, input: $input) {
      result {
        id
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
    }
  }
`;

const REMOVE_DEVICE_TAGS_MUTATION = graphql`
  mutation DeviceInfoCard_removeDeviceTags_Mutation(
    $deviceId: ID!
    $input: RemoveDeviceTagsInput!
  ) {
    removeDeviceTags(id: $deviceId, input: $input) {
      result {
        id
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
    }
  }
`;

const REQUEST_FORWARDER_SESSION_MUTATION = graphql`
  mutation DeviceInfoCard_requestForwarderSession_Mutation(
    $input: RequestForwarderSessionInput!
  ) {
    requestForwarderSession(input: $input)
  }
`;

const GET_FORWARDER_SESSION_QUERY = graphql`
  query DeviceInfoCard_getForwarderSession_Query(
    $deviceId: ID!
    $sessionToken: String!
  ) {
    forwarderSession(deviceId: $deviceId, token: $sessionToken) {
      status
      secure
      forwarderHostname
      forwarderPort
      token
    }
  }
`;

const FORM_ROW = { labelCol: 3, valueCol: 9 };

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

  const handleAPIErrors = useCallback(
    (errors: PayloadError[]) => {
      const errorFeedback = errors
        .map(({ fields, message }) =>
          fields.length ? `${fields.join(" ")} ${message}` : message,
        )
        .join(". \n");
      onError(errorFeedback);
    },
    [onError],
  );

  const [requestForwarderSession, isRequestingForwarderSession] =
    useMutation<DeviceInfoCard_requestForwarderSession_Mutation>(
      REQUEST_FORWARDER_SESSION_MUTATION,
    );

  const handleOpenRemoteTerminal = useCallback(
    async (sessionToken: string) => {
      const data = await fetchQuery<DeviceInfoCard_getForwarderSession_Query>(
        relayEnvironment,
        GET_FORWARDER_SESSION_QUERY,
        { deviceId, sessionToken },
      ).toPromise();

      if (!data?.forwarderSession) {
        throw new Error("The forwarder session does not exist.");
      }

      const { forwarderHostname, forwarderPort, secure, status, token } =
        data.forwarderSession;

      if (status !== "CONNECTED") {
        throw new Error("The forwarder session is not connected.");
      }

      openRemoteTerminal({
        forwarderVersion,
        forwarderHostname,
        forwarderPort,
        secure,
        sessionToken,
        token,
      });
    },
    [relayEnvironment, deviceId],
  );

  const handleRequestForwarderSession = useCallback(() => {
    requestForwarderSession({
      variables: { input: { deviceId } },
      onCompleted(data, errors) {
        if (errors) {
          handleAPIErrors(errors);
          return;
        }
        const sessionToken = data.requestForwarderSession;

        setIsOpeningRemoteTerminal(true);
        timeoutPromise(
          retryWithExponentialBackoff(() =>
            handleOpenRemoteTerminal(sessionToken),
          ),
          10_000,
        )
          .catch(() => {
            setRemoteTerminalErrorFeedback(
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
