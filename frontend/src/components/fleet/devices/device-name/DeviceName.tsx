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

import { KeyboardEvent, ReactNode, useCallback, useState } from "react";
import { graphql, useMutation } from "react-relay/hooks";
import { FormattedMessage, useIntl } from "react-intl";
import type { PayloadError } from "relay-runtime";

import type { DeviceName_updateDevice_Mutation } from "@/api/__generated__/DeviceName_updateDevice_Mutation.graphql";

import Button from "@/components/ui/button/Button";
import Form from "@/components/ui/form/Form";
import Icon from "@/components/ui/icon/Icon";
import Stack from "@/components/ui/stack/Stack";

const UPDATE_DEVICE_MUTATION = graphql`
  mutation DeviceName_updateDevice_Mutation(
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

interface DeviceNameProps {
  name: string;
  deviceId: string;
  onError: (feedback: ReactNode) => void;
}

const DeviceName = ({ name, deviceId, onError }: DeviceNameProps) => {
  const intl = useIntl();
  const [isEditing, setIsEditing] = useState(false);
  const [draftName, setDraftName] = useState(name);

  const [updateDevice] = useMutation<DeviceName_updateDevice_Mutation>(
    UPDATE_DEVICE_MUTATION,
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

  const handleSave = useCallback(() => {
    const newName = draftName.trim();
    if (!newName || newName === name) {
      setDraftName(name);
      setIsEditing(false);
      return;
    }

    updateDevice({
      variables: { deviceId, input: { name: newName } },
      onCompleted(_data, errors) {
        if (errors) {
          handleAPIErrors(errors);
          return;
        }
        setIsEditing(false);
      },
      onError() {
        setIsEditing(false);
        onError(
          <FormattedMessage
            id="components.fleet.devices.device-name.DeviceName.updateDeviceErrorFeedback"
            defaultMessage="Could not update the device, please try again."
            description="Feedback for unknown error while updating a device"
          />,
        );
      },
    });
  }, [draftName, name, updateDevice, deviceId, handleAPIErrors, onError]);

  const handleCancel = useCallback(() => {
    setDraftName(name);
    setIsEditing(false);
  }, [name]);

  const handleKeyDown = useCallback(
    (e: KeyboardEvent<HTMLInputElement>) => {
      if (e.key === "Enter") {
        handleSave();
      } else if (e.key === "Escape") {
        handleCancel();
      }
    },
    [handleSave, handleCancel],
  );

  return (
    <Stack direction="horizontal" gap={2} className="align-items-center">
      {isEditing ? (
        <>
          <Form.Control
            type="text"
            value={draftName}
            onChange={(e) => setDraftName(e.target.value)}
            onKeyDown={handleKeyDown}
            autoFocus
          />
          <Button
            variant="success"
            onClick={handleSave}
            aria-label={intl.formatMessage({
              id: "components.fleet.devices.device-name.DeviceName.saveButton",
              defaultMessage: "Save device name",
            })}
          >
            <Icon icon="check" />
          </Button>
          <Button
            variant="secondary"
            onClick={handleCancel}
            aria-label={intl.formatMessage({
              id: "components.fleet.devices.device-name.DeviceName.cancelButton",
              defaultMessage: "Cancel",
            })}
          >
            <Icon icon="xMark" />
          </Button>
        </>
      ) : (
        <>
          <Button
            variant="link"
            className="p-0 border-0"
            onClick={() => setIsEditing(true)}
            aria-label={intl.formatMessage({
              id: "components.fleet.devices.device-name.DeviceName.editButton",
              defaultMessage: "Edit device name",
            })}
          >
            <Icon icon="edit" />
          </Button>
          <span className="fw-bold">{name}</span>
        </>
      )}
    </Stack>
  );
};

export default DeviceName;
