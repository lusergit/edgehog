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

import { useMemo, useState } from "react";
import {
  Alert,
  Badge,
  Button,
  ButtonGroup,
  Form,
  Modal,
} from "react-bootstrap";
import { FormattedMessage, useIntl } from "react-intl";
import { graphql, useLazyLoadQuery } from "react-relay/hooks";
import { SingleValue } from "react-select";

import type { InstallApplicationModal_Applications_Query } from "@/api/__generated__/InstallApplicationModal_Applications_Query.graphql";
import type { MockContainerSpec } from "@/components/apps/configurations/configuration-container-inspector/ConfigurationContainerInspector";

import Select from "@/components/ui/select/Select";
import Icon from "@/components/ui/icon/Icon";
import {
  initialMockConfigurations,
  initialMockTags,
  mockContainersByConfigHash,
  type MockInstalledApplication,
} from "@/mocks/applicationInfo";

const APPLICATIONS_QUERY = graphql`
  query InstallApplicationModal_Applications_Query(
    $filter: ApplicationFilterInput = {}
  ) {
    applications(first: 10000, filter: $filter) {
      edges {
        node {
          id
          name
        }
      }
    }
  }
`;

type InstallApplicationModalProps = {
  show: boolean;
  systemModelName?: string;
  isOnline: boolean;
  onClose: () => void;
  onInstalled: (installed: MockInstalledApplication) => void;
};

type AppOption = {
  value: string;
  label: string;
};

const ContainerEditorRow = ({
  container,
  image,
  edited,
  onImageChange,
}: {
  container: MockContainerSpec;
  image: string;
  edited: boolean;
  onImageChange: (image: string) => void;
}) => {
  const envEntries = Object.entries(container.environment ?? {});

  return (
    <div className="border rounded p-3 mb-2 bg-light">
      <div className="d-flex align-items-center justify-content-between mb-2">
        <div className="d-flex align-items-center gap-2">
          <Icon icon="containers" className="text-primary" />
          <span className="fw-semibold">{container.name}</span>
          {edited && (
            <Badge bg="warning" text="dark" className="fw-normal">
              <FormattedMessage
                id="components.fleet.devices.tabs.applications-tab.install-application-modal.InstallApplicationModal.editedContainerBadge"
                defaultMessage="Edited"
              />
            </Badge>
          )}
        </div>
        {container.ports && container.ports.length > 0 && (
          <div className="d-flex gap-1">
            {container.ports.map((port) => (
              <Badge
                key={port}
                bg="secondary"
                className="fw-normal font-monospace"
              >
                {port}
              </Badge>
            ))}
          </div>
        )}
      </div>

      <Form.Group
        controlId={`container-image-${container.id}`}
        className="mb-2"
      >
        <Form.Label className="text-secondary small fw-semibold mb-1">
          <FormattedMessage
            id="components.fleet.devices.tabs.applications-tab.install-application-modal.InstallApplicationModal.imageLabel"
            defaultMessage="Image"
          />
        </Form.Label>
        <Form.Control
          type="text"
          value={image}
          onChange={(e) => onImageChange(e.target.value)}
          className="font-monospace"
        />
      </Form.Group>

      {envEntries.length > 0 && (
        <div className="d-flex flex-wrap gap-1">
          {envEntries.map(([key, value]) => (
            <span
              key={key}
              className="bg-white border rounded px-2 py-1 small font-monospace"
            >
              {key}={value}
            </span>
          ))}
        </div>
      )}
    </div>
  );
};

const InstallApplicationModal = ({
  show,
  systemModelName,
  isOnline,
  onClose,
  onInstalled,
}: InstallApplicationModalProps) => {
  const intl = useIntl();

  const [selectedAppId, setSelectedAppId] = useState<string | null>(null);
  const [sourceType, setSourceType] = useState<"tag" | "configuration">("tag");
  const [selectedTagId, setSelectedTagId] = useState<string | null>(null);
  const [selectedConfigHash, setSelectedConfigHash] = useState<string | null>(
    null,
  );
  const [wantsChanges, setWantsChanges] = useState(false);
  const [editedImages, setEditedImages] = useState<Record<string, string>>({});

  const data = useLazyLoadQuery<InstallApplicationModal_Applications_Query>(
    APPLICATIONS_QUERY,
    {
      filter: {
        releases: {
          or: [
            {
              systemModels: {
                name: { eq: systemModelName },
              },
            },
            {
              systemModels: {
                name: { isNil: true },
              },
            },
          ],
        },
      },
    },
    { fetchPolicy: "store-and-network" },
  );

  const applicationOptions: AppOption[] = useMemo(
    () =>
      (data.applications?.edges ?? []).map((app) => ({
        value: app.node.id,
        label: app.node.name,
      })),
    [data.applications?.edges],
  );

  const selectedApplicationOption = useMemo(
    () =>
      applicationOptions.find((option) => option.value === selectedAppId) ||
      null,
    [applicationOptions, selectedAppId],
  );

  const selectedTag = useMemo(
    () => initialMockTags.find((tag) => tag.id === selectedTagId) ?? null,
    [selectedTagId],
  );

  const baseConfigHash = useMemo(() => {
    if (sourceType === "tag") {
      return selectedTag?.configurationHash ?? null;
    }
    return selectedConfigHash;
  }, [sourceType, selectedTag, selectedConfigHash]);

  const selectedConfiguration = useMemo(
    () =>
      initialMockConfigurations.find(
        (config) => config.hash === baseConfigHash,
      ) ?? null,
    [baseConfigHash],
  );

  const containers = useMemo(
    () =>
      baseConfigHash ? (mockContainersByConfigHash[baseConfigHash] ?? []) : [],
    [baseConfigHash],
  );

  const editedContainers = useMemo(
    () =>
      containers.filter((container) => {
        const image = editedImages[container.id];
        return image !== undefined && image !== container.image;
      }),
    [containers, editedImages],
  );

  const resetForm = () => {
    setSelectedAppId(null);
    setSourceType("tag");
    setSelectedTagId(null);
    setSelectedConfigHash(null);
    setWantsChanges(false);
    setEditedImages({});
  };

  const selectSourceType = (type: "tag" | "configuration") => {
    setSourceType(type);
    setEditedImages({});
    setWantsChanges(false);
  };

  const handleApplicationChange = (option: SingleValue<AppOption>) => {
    setSelectedAppId(option?.value || null);
  };

  const handleSourceSelect = (
    tagId: string | null,
    configHash: string | null,
  ) => {
    if (sourceType === "tag") {
      setSelectedTagId(tagId);
    } else {
      setSelectedConfigHash(configHash);
    }
    setEditedImages({});
    setWantsChanges(false);
  };

  const handleImageChange = (containerId: string, image: string) => {
    setEditedImages((prev) => ({ ...prev, [containerId]: image }));
  };

  const handleInstall = () => {
    if (!selectedAppId || !baseConfigHash) return;

    const appName =
      applicationOptions.find((app) => app.value === selectedAppId)?.label ??
      "Unknown";

    const edited = wantsChanges && editedContainers.length > 0;

    onInstalled({
      id: `mock-install-${Date.now()}`,
      applicationId: selectedAppId,
      applicationName: appName,
      sourceType,
      sourceLabel:
        sourceType === "tag" ? (selectedTag?.name ?? "") : baseConfigHash,
      configHash: edited ? `${baseConfigHash}-edit` : baseConfigHash,
      edited,
      installedAt: new Date().toLocaleString(),
    });

    onClose();
  };

  const isInstallDisabled = !isOnline || !selectedAppId || !baseConfigHash;

  return (
    <Modal show={show} onEnter={resetForm} onHide={onClose} size="lg" centered>
      <Modal.Header closeButton>
        <Modal.Title>
          <FormattedMessage
            id="components.fleet.devices.tabs.applications-tab.install-application-modal.InstallApplicationModal.title"
            defaultMessage="Install Application"
          />
        </Modal.Title>
      </Modal.Header>
      <Modal.Body>
        {!isOnline && (
          <Alert variant="warning" className="mb-3">
            <Icon icon="warning" className="me-2" />
            <FormattedMessage
              id="components.fleet.devices.tabs.applications-tab.install-application-modal.InstallApplicationModal.offlineWarning"
              defaultMessage="The device is disconnected. Installation is not possible while the device is offline."
            />
          </Alert>
        )}

        <Form.Group className="mb-4" controlId="install-application">
          <Form.Label className="fw-semibold">
            <FormattedMessage
              id="components.fleet.devices.tabs.applications-tab.install-application-modal.InstallApplicationModal.applicationLabel"
              defaultMessage="Application"
            />
          </Form.Label>
          <Select
            value={selectedApplicationOption}
            onChange={handleApplicationChange}
            options={applicationOptions}
            isClearable
            placeholder={intl.formatMessage({
              id: "components.fleet.devices.tabs.applications-tab.install-application-modal.InstallApplicationModal.applicationPlaceholder",
              defaultMessage: "Search or select an application...",
            })}
          />
        </Form.Group>

        <Form.Group className="mb-4" controlId="install-source">
          <Form.Label className="fw-semibold">
            <FormattedMessage
              id="components.fleet.devices.tabs.applications-tab.install-application-modal.InstallApplicationModal.sourceLabel"
              defaultMessage="Source"
            />
          </Form.Label>
          <ButtonGroup className="w-100">
            <Button
              variant={sourceType === "tag" ? "primary" : "outline-primary"}
              onClick={() => selectSourceType("tag")}
            >
              <Icon icon="tag" className="me-2" />
              <FormattedMessage
                id="components.fleet.devices.tabs.applications-tab.install-application-modal.InstallApplicationModal.tagOption"
                defaultMessage="Tag"
              />
            </Button>
            <Button
              variant={
                sourceType === "configuration" ? "primary" : "outline-primary"
              }
              onClick={() => selectSourceType("configuration")}
            >
              <Icon icon="containers" className="me-2" />
              <FormattedMessage
                id="components.fleet.devices.tabs.applications-tab.install-application-modal.InstallApplicationModal.configurationOption"
                defaultMessage="Configuration"
              />
            </Button>
          </ButtonGroup>
        </Form.Group>

        {sourceType === "tag" ? (
          <Form.Group className="mb-4" controlId="install-tag">
            <Form.Label className="fw-semibold">
              <FormattedMessage
                id="components.fleet.devices.tabs.applications-tab.install-application-modal.InstallApplicationModal.tagLabel"
                defaultMessage="Select Tag"
              />
            </Form.Label>
            <Form.Select
              value={selectedTagId ?? ""}
              onChange={(e) => handleSourceSelect(e.target.value || null, null)}
            >
              <option value="">
                <FormattedMessage
                  id="components.fleet.devices.tabs.applications-tab.install-application-modal.InstallApplicationModal.chooseTagPlaceholder"
                  defaultMessage="Choose a tag..."
                />
              </option>
              {initialMockTags.map((tag) => (
                <option key={tag.id} value={tag.id}>
                  {tag.name} · {tag.deviceGroupName}
                </option>
              ))}
            </Form.Select>
          </Form.Group>
        ) : (
          <Form.Group className="mb-4" controlId="install-configuration">
            <Form.Label className="fw-semibold">
              <FormattedMessage
                id="components.fleet.devices.tabs.applications-tab.install-application-modal.InstallApplicationModal.configurationLabel"
                defaultMessage="Select Configuration"
              />
            </Form.Label>
            <Form.Select
              value={selectedConfigHash ?? ""}
              onChange={(e) => handleSourceSelect(null, e.target.value || null)}
            >
              <option value="">
                <FormattedMessage
                  id="components.fleet.devices.tabs.applications-tab.install-application-modal.InstallApplicationModal.chooseConfigurationPlaceholder"
                  defaultMessage="Choose a configuration..."
                />
              </option>
              {initialMockConfigurations.map((config) => (
                <option key={config.hash} value={config.hash}>
                  {config.hash} ({config.containersSummary})
                </option>
              ))}
            </Form.Select>
          </Form.Group>
        )}

        {selectedConfiguration && (
          <div className="bg-light border rounded p-3 mb-4">
            <div className="d-flex align-items-center justify-content-between mb-2">
              <span className="text-secondary small fw-semibold">
                <FormattedMessage
                  id="components.fleet.devices.tabs.applications-tab.install-application-modal.InstallApplicationModal.configSummaryLabel"
                  defaultMessage="Configuration"
                />
              </span>
              <Badge bg="info" className="fw-normal">
                {selectedConfiguration.containersCount}{" "}
                <FormattedMessage
                  id="components.fleet.devices.tabs.applications-tab.install-application-modal.InstallApplicationModal.containersCountLabel"
                  defaultMessage="containers"
                />
              </Badge>
            </div>
            <div className="font-monospace text-primary fw-semibold">
              {selectedConfiguration.hash}
            </div>
            <div className="text-secondary small mt-1">
              {selectedConfiguration.systemModelsSummary}
            </div>
          </div>
        )}

        <Form.Group className="mb-3" controlId="edit-configuration">
          <Form.Check
            type="switch"
            id="edit-configuration-switch"
            label={intl.formatMessage({
              id: "components.fleet.devices.tabs.applications-tab.install-application-modal.InstallApplicationModal.editConfigurationLabel",
              defaultMessage: "I want to make changes to this configuration",
            })}
            checked={wantsChanges}
            disabled={!baseConfigHash}
            onChange={(e) => setWantsChanges(e.target.checked)}
          />
        </Form.Group>

        {wantsChanges && baseConfigHash && (
          <div className="border rounded p-3 mb-3">
            <div className="d-flex align-items-center justify-content-between mb-3">
              <h6 className="mb-0 fw-semibold">
                <Icon icon="edit" className="me-2 text-muted" />
                <FormattedMessage
                  id="components.fleet.devices.tabs.applications-tab.install-application-modal.InstallApplicationModal.editContainersTitle"
                  defaultMessage="Edit Containers"
                />
              </h6>
              <Badge bg="warning" text="dark" className="fw-normal">
                <FormattedMessage
                  id="components.fleet.devices.tabs.applications-tab.install-application-modal.InstallApplicationModal.editedBadge"
                  defaultMessage="{count, plural, one {# container edited} other {# containers edited}}"
                  values={{ count: editedContainers.length }}
                />
              </Badge>
            </div>

            {containers.length === 0 ? (
              <div className="text-muted small fst-italic">
                <FormattedMessage
                  id="components.fleet.devices.tabs.applications-tab.install-application-modal.InstallApplicationModal.noContainersMsg"
                  defaultMessage="No containers available for the selected configuration."
                />
              </div>
            ) : (
              containers.map((container) => {
                const image = editedImages[container.id] ?? container.image;

                return (
                  <ContainerEditorRow
                    key={container.id}
                    container={container}
                    image={image}
                    edited={image !== container.image}
                    onImageChange={(value) =>
                      handleImageChange(container.id, value)
                    }
                  />
                );
              })
            )}
          </div>
        )}
      </Modal.Body>
      <Modal.Footer>
        <Button variant="secondary" onClick={onClose}>
          <FormattedMessage
            id="components.fleet.devices.tabs.applications-tab.install-application-modal.InstallApplicationModal.cancelButton"
            defaultMessage="Cancel"
          />
        </Button>
        <Button
          variant="primary"
          disabled={isInstallDisabled}
          onClick={handleInstall}
        >
          <Icon icon="plus" className="me-2" />
          <FormattedMessage
            id="components.fleet.devices.tabs.applications-tab.install-application-modal.InstallApplicationModal.installButton"
            defaultMessage="Install"
          />
        </Button>
      </Modal.Footer>
    </Modal>
  );
};

export default InstallApplicationModal;
