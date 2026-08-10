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

import { useState, useEffect } from "react";
import { Modal, Button, Form, Alert } from "react-bootstrap";
import { FormattedMessage } from "react-intl";
import semverValid from "semver/functions/valid";

import type { TagRecord } from "../tags-table/TagsTable";

export type DeviceGroupOption = {
  id: string;
  name: string;
};

export type ConfigurationOption = {
  hash: string;
  containersSummary: string;
};

type CreateTagModalProps = {
  show: boolean;
  tagToEdit?: TagRecord | null;
  configurations: ConfigurationOption[];
  deviceGroups: DeviceGroupOption[];
  onClose: () => void;
  onSave: (tag: Omit<TagRecord, "id" | "createdAt"> & { id?: string }) => void;
};

const CreateTagModal = ({
  show,
  tagToEdit,
  configurations,
  deviceGroups,
  onClose,
  onSave,
}: CreateTagModalProps) => {
  const [name, setName] = useState("");
  const [isPreRelease, setIsPreRelease] = useState(false);
  const [configurationHash, setConfigurationHash] = useState("");
  const [deviceGroupId, setDeviceGroupId] = useState("");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (tagToEdit) {
      setName(tagToEdit.name);
      setIsPreRelease(tagToEdit.isPreRelease);
      setConfigurationHash(tagToEdit.configurationHash);
      setDeviceGroupId(tagToEdit.deviceGroupId);
    } else {
      setName("");
      setIsPreRelease(false);
      setConfigurationHash(configurations[0]?.hash || "");
      setDeviceGroupId(deviceGroups[0]?.id || "");
    }
    setError(null);
  }, [tagToEdit, show, configurations, deviceGroups]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const cleanName = name.trim();

    if (!cleanName) {
      setError("Tag name is required.");
      return;
    }

    // Standard semver validation (allowing optional 'v' prefix)
    const versionToCheck = cleanName.startsWith("v")
      ? cleanName.slice(1)
      : cleanName;
    if (!semverValid(versionToCheck)) {
      setError(
        "Tag name must be a valid SemVer string (e.g., v1.0.0 or 1.0.0-beta.1).",
      );
      return;
    }

    if (!configurationHash) {
      setError("Please select a target configuration.");
      return;
    }

    if (!deviceGroupId) {
      setError("Please select a target device group.");
      return;
    }

    const groupObj = deviceGroups.find((g) => g.id === deviceGroupId);

    onSave({
      id: tagToEdit?.id,
      name: cleanName.startsWith("v") ? cleanName : `v${cleanName}`,
      isPreRelease,
      configurationHash,
      deviceGroupId,
      deviceGroupName: groupObj?.name || "Selected Device Group",
    });

    onClose();
  };

  return (
    <Modal show={show} onHide={onClose} centered>
      <Form onSubmit={handleSubmit}>
        <Modal.Header closeButton>
          <Modal.Title>
            {tagToEdit ? (
              <FormattedMessage
                id="components.apps.tags.CreateTagModal.editTitle"
                defaultMessage="Edit Tag"
              />
            ) : (
              <FormattedMessage
                id="components.apps.tags.CreateTagModal.createTitle"
                defaultMessage="Create Tag"
              />
            )}
          </Modal.Title>
        </Modal.Header>
        <Modal.Body>
          {error && <Alert variant="danger">{error}</Alert>}

          <Form.Group className="mb-3" controlId="tagName">
            <Form.Label className="fw-semibold">
              <FormattedMessage
                id="components.apps.tags.CreateTagModal.nameLabel"
                defaultMessage="Tag Name (SemVer)"
              />
            </Form.Label>
            <Form.Control
              type="text"
              placeholder="e.g. v1.0.0, v2.1.0-beta.1"
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
            />
            <Form.Text className="text-muted">
              Must be a valid Semantic Versioning string (e.g. v1.0.0).
            </Form.Text>
          </Form.Group>

          <Form.Group className="mb-3" controlId="configurationHash">
            <Form.Label className="fw-semibold">
              <FormattedMessage
                id="components.apps.tags.CreateTagModal.configLabel"
                defaultMessage="Target Configuration"
              />
            </Form.Label>
            <Form.Select
              value={configurationHash}
              onChange={(e) => setConfigurationHash(e.target.value)}
              required
            >
              {configurations.length === 0 ? (
                <option value="">No configurations available</option>
              ) : (
                configurations.map((cfg) => (
                  <option key={cfg.hash} value={cfg.hash}>
                    {cfg.hash} ({cfg.containersSummary})
                  </option>
                ))
              )}
            </Form.Select>
          </Form.Group>

          <Form.Group className="mb-3" controlId="deviceGroupId">
            <Form.Label className="fw-semibold">
              <FormattedMessage
                id="components.apps.tags.CreateTagModal.groupLabel"
                defaultMessage="Target Device Group"
              />
            </Form.Label>
            <Form.Select
              value={deviceGroupId}
              onChange={(e) => setDeviceGroupId(e.target.value)}
              required
            >
              {deviceGroups.length === 0 ? (
                <option value="">No device groups available</option>
              ) : (
                deviceGroups.map((group) => (
                  <option key={group.id} value={group.id}>
                    {group.name}
                  </option>
                ))
              )}
            </Form.Select>
          </Form.Group>

          <Form.Group className="mb-3" controlId="isPreRelease">
            <Form.Check
              type="switch"
              id="pre-release-switch"
              label="Flag as pre-release version"
              checked={isPreRelease}
              onChange={(e) => setIsPreRelease(e.target.checked)}
            />
            <Form.Text className="text-muted">
              Pre-release tags indicate beta or testing versions before general
              release.
            </Form.Text>
          </Form.Group>
        </Modal.Body>
        <Modal.Footer>
          <Button variant="secondary" onClick={onClose}>
            Cancel
          </Button>
          <Button variant="primary" type="submit">
            {tagToEdit ? "Update Tag" : "Create Tag"}
          </Button>
        </Modal.Footer>
      </Form>
    </Modal>
  );
};

export default CreateTagModal;
