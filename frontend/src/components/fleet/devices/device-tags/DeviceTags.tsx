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

import { ReactNode, useCallback, useMemo, useState } from "react";
import { graphql, useMutation } from "react-relay/hooks";
import { useIntl } from "react-intl";
import type { PayloadError } from "relay-runtime";

import type { DeviceTags_addDeviceTags_Mutation } from "@/api/__generated__/DeviceTags_addDeviceTags_Mutation.graphql";
import type { DeviceTags_removeDeviceTags_Mutation } from "@/api/__generated__/DeviceTags_removeDeviceTags_Mutation.graphql";

import Button from "@/components/ui/button/Button";
import Form from "@/components/ui/form/Form";
import Icon from "@/components/ui/icon/Icon";
import Stack from "@/components/ui/stack/Stack";
import Tag from "@/components/ui/tag/Tag";

const ADD_DEVICE_TAGS_MUTATION = graphql`
  mutation DeviceTags_addDeviceTags_Mutation(
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
  mutation DeviceTags_removeDeviceTags_Mutation(
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

interface DeviceTagsProps {
  deviceId: string;
  tags: { id: string; name: string }[];
  options: { label: string; value: string }[];
  refreshTags: () => void;
  onError: (feedback: ReactNode) => void;
}

const DeviceTags = ({
  deviceId,
  tags,
  options,
  refreshTags,
  onError,
}: DeviceTagsProps) => {
  const intl = useIntl();
  const [isAddingTag, setIsAddingTag] = useState(false);
  const [newTagInput, setNewTagInput] = useState("");

  const deviceTags = useMemo(
    () =>
      tags.map(({ name: tag }) => ({
        label: tag,
        value: tag,
      })),
    [tags],
  );

  const [addDeviceTags] = useMutation<DeviceTags_addDeviceTags_Mutation>(
    ADD_DEVICE_TAGS_MUTATION,
  );
  const [removeDeviceTags] = useMutation<DeviceTags_removeDeviceTags_Mutation>(
    REMOVE_DEVICE_TAGS_MUTATION,
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

  const handleAddDeviceTags = useCallback(
    (tagsToAdd: string[]) => {
      addDeviceTags({
        variables: {
          deviceId,
          input: { tags: tagsToAdd },
        },
        onCompleted(_data, errors) {
          if (errors) {
            handleAPIErrors(errors);
            return;
          }
          // TODO refresh tags only when adding unexisting tags
          refreshTags();
        },
        updater(store, data) {
          if (!data?.addDeviceTags?.result) {
            return;
          }

          const root = store.getRoot();
          const deviceGroups = root.getLinkedRecords("deviceGroups");
          if (!deviceGroups) {
            return;
          }

          const device = store
            .getRootField("addDeviceTags")
            .getLinkedRecord("result");
          const deviceId = device.getDataID();

          const linkedGroups = new Set(
            device
              .getLinkedRecords("deviceGroups")
              ?.map((deviceGroup) => deviceGroup.getDataID()),
          );

          deviceGroups.forEach((deviceGroup) => {
            const devices = deviceGroup.getLinkedRecords("devices");
            if (!devices) {
              return;
            }
            if (!linkedGroups.has(deviceGroup.getDataID())) {
              return deviceGroup.setLinkedRecords(
                devices.filter((device) => device.getDataID() !== deviceId),
                "devices",
              );
            }
            if (!devices.some((device) => device.getDataID() === deviceId)) {
              deviceGroup.setLinkedRecords([...devices, device], "devices");
            }
          });
        },
      });
    },
    [addDeviceTags, deviceId, handleAPIErrors, refreshTags],
  );

  const handleRemoveDeviceTags = useCallback(
    (tagsToRemove: string[]) => {
      removeDeviceTags({
        variables: {
          deviceId,
          input: { tags: tagsToRemove },
        },
        onCompleted(_data, errors) {
          if (errors) {
            handleAPIErrors(errors);
            return;
          }
        },
        updater(store, data) {
          if (!data?.removeDeviceTags?.result) {
            return;
          }

          const root = store.getRoot();
          const deviceGroups = root.getLinkedRecords("deviceGroups");
          if (!deviceGroups) {
            return;
          }

          const device = store
            .getRootField("removeDeviceTags")
            .getLinkedRecord("result");
          const deviceId = device.getDataID();

          const linkedGroups = new Set(
            device
              .getLinkedRecords("deviceGroups")
              ?.map((deviceGroup) => deviceGroup.getDataID()),
          );

          deviceGroups.forEach((deviceGroup) => {
            const devices = deviceGroup.getLinkedRecords("devices");
            if (!devices) {
              return;
            }
            if (!linkedGroups.has(deviceGroup.getDataID())) {
              return deviceGroup.setLinkedRecords(
                devices.filter((device) => device.getDataID() !== deviceId),
                "devices",
              );
            }
            if (!devices.some((device) => device.getDataID() === deviceId)) {
              deviceGroup.setLinkedRecords([...devices, device], "devices");
            }
          });
        },
      });
    },
    [deviceId, removeDeviceTags, handleAPIErrors],
  );

  const handleAddTag = useCallback(() => {
    const newTag = newTagInput.trim().toLowerCase();
    if (!newTag) {
      return;
    }
    setNewTagInput("");
    setIsAddingTag(false);
    handleAddDeviceTags([newTag]);
  }, [newTagInput, handleAddDeviceTags]);

  const handleRemoveTag = useCallback(
    (tag: string) => {
      handleRemoveDeviceTags([tag]);
    },
    [handleRemoveDeviceTags],
  );

  return (
    <Stack
      direction="horizontal"
      gap={2}
      className="align-items-center flex-wrap"
    >
      {deviceTags.map(({ value: tag }) => (
        <Tag key={tag} className="d-inline-flex align-items-center">
          {tag}
          <Button
            variant="link"
            className="p-0 ms-1 border-0"
            onClick={() => handleRemoveTag(tag)}
            aria-label={intl.formatMessage(
              {
                id: "components.fleet.devices.device-tags.DeviceTags.removeTag",
                defaultMessage: "Remove {tag} tag",
              },
              { tag },
            )}
          >
            <Icon icon="xMark" size="1em" />
          </Button>
        </Tag>
      ))}
      {isAddingTag ? (
        <>
          <Form.Control
            type="text"
            value={newTagInput}
            list="device-tags-options"
            onChange={(e) => setNewTagInput(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter") {
                handleAddTag();
              } else if (e.key === "Escape") {
                setNewTagInput("");
                setIsAddingTag(false);
              }
            }}
            autoFocus
            aria-label={intl.formatMessage({
              id: "components.fleet.devices.device-tags.DeviceTags.tagInputPlaceholder",
              defaultMessage: "New tag",
            })}
          />
          <datalist id="device-tags-options">
            {options.map((option) => (
              <option key={option.value} value={option.value} />
            ))}
          </datalist>
          <Button
            variant="success"
            onClick={handleAddTag}
            aria-label={intl.formatMessage({
              id: "components.fleet.devices.device-tags.DeviceTags.addTag",
              defaultMessage: "Add tag",
            })}
          >
            <Icon icon="check" />
          </Button>
        </>
      ) : (
        <Button
          variant="secondary"
          onClick={() => setIsAddingTag(true)}
          aria-label={intl.formatMessage({
            id: "components.fleet.devices.device-tags.DeviceTags.addTag",
            defaultMessage: "Add tag",
          })}
        >
          <Icon icon="plus" />
        </Button>
      )}
    </Stack>
  );
};

export default DeviceTags;
