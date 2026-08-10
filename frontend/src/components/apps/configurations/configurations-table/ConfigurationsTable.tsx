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

import { useState, useMemo } from "react";
import { Badge, Button, Form, InputGroup } from "react-bootstrap";
import { FormattedMessage } from "react-intl";

import { Link, Route } from "@/Navigation";
import Icon from "@/components/ui/icon/Icon";
import type { TagRecord } from "@/components/apps/tags/tags-table/TagsTable";

export type ConfigurationRecord = {
  id: string;
  hash: string;
  containersSummary: string;
  containersCount: number;
  systemModelsSummary: string;
  createdAt: string;
};

type ConfigurationsTableProps = {
  className?: string;
  applicationId: string;
  configurations: ConfigurationRecord[];
  tags?: TagRecord[];
  onDeleteConfiguration: (config: ConfigurationRecord) => void;
  onCreateConfiguration: () => void;
};

const ConfigurationsTable = ({
  className,
  applicationId,
  configurations,
  tags = [],
  onDeleteConfiguration,
  onCreateConfiguration,
}: ConfigurationsTableProps) => {
  const [searchText, setSearchText] = useState("");
  const [copiedHash, setCopiedHash] = useState<string | null>(null);

  const filteredConfigurations = useMemo(() => {
    if (!searchText.trim()) return configurations;
    const term = searchText.toLowerCase().trim();
    return configurations.filter(
      (c) =>
        c.hash.toLowerCase().includes(term) ||
        c.containersSummary.toLowerCase().includes(term) ||
        c.systemModelsSummary.toLowerCase().includes(term),
    );
  }, [configurations, searchText]);

  const handleCopyHash = (hash: string) => {
    navigator.clipboard.writeText(hash);
    setCopiedHash(hash);
    setTimeout(() => setCopiedHash(null), 2000);
  };

  const getTagsForHash = (hash: string) => {
    return tags.filter((t) => t.configurationHash === hash);
  };

  return (
    <div className={className}>
      <div className="d-flex justify-content-between align-items-center mb-3">
        <InputGroup style={{ maxWidth: "320px" }}>
          <InputGroup.Text className="bg-white border-end-0">
            <Icon icon="search" className="text-muted" />
          </InputGroup.Text>
          <Form.Control
            placeholder="Search configuration hash or containers..."
            className="border-start-0 ps-0"
            value={searchText}
            onChange={(e) => setSearchText(e.target.value)}
          />
        </InputGroup>

        <Button variant="primary" onClick={onCreateConfiguration}>
          <Icon icon="plus" className="me-2" />
          <FormattedMessage
            id="components.apps.configurations.configurations-table.ConfigurationsTable.createConfiguration"
            defaultMessage="Create Configuration"
          />
        </Button>
      </div>

      {filteredConfigurations.length === 0 ? (
        <div className="text-center py-5 border rounded bg-light">
          <Icon
            icon="models"
            size="2.5em"
            className="text-secondary mb-3 d-block mx-auto"
          />
          <h5 className="text-muted">No configurations found</h5>
          <p className="text-secondary small mb-3">
            Configurations contain container definitions and hardware system
            model requirements.
          </p>
          <Button
            variant="outline-primary"
            size="sm"
            onClick={onCreateConfiguration}
          >
            <Icon icon="plus" className="me-1" />
            Create your first Configuration
          </Button>
        </div>
      ) : (
        <div className="table-responsive border rounded">
          <table className="table table-hover align-middle mb-0">
            <thead className="table-light">
              <tr>
                <th>
                  <FormattedMessage
                    id="components.apps.configurations.configurations-table.ConfigurationsTable.hash"
                    defaultMessage="Configuration Hash"
                  />
                </th>
                <th>
                  <FormattedMessage
                    id="components.apps.configurations.configurations-table.ConfigurationsTable.containers"
                    defaultMessage="Containers"
                  />
                </th>
                <th>
                  <FormattedMessage
                    id="components.apps.configurations.configurations-table.ConfigurationsTable.supportedModels"
                    defaultMessage="System Models"
                  />
                </th>
                <th>
                  <FormattedMessage
                    id="components.apps.configurations.configurations-table.ConfigurationsTable.associatedTags"
                    defaultMessage="Associated Tags"
                  />
                </th>
                <th>
                  <FormattedMessage
                    id="components.apps.configurations.configurations-table.ConfigurationsTable.createdAt"
                    defaultMessage="Created At"
                  />
                </th>
                <th className="text-end">
                  <FormattedMessage
                    id="components.apps.configurations.configurations-table.ConfigurationsTable.actions"
                    defaultMessage="Actions"
                  />
                </th>
              </tr>
            </thead>
            <tbody>
              {filteredConfigurations.map((config) => {
                const configTags = getTagsForHash(config.hash);

                return (
                  <tr key={config.id}>
                    <td>
                      <div className="d-inline-flex align-items-center gap-2 bg-light border px-2 py-1 rounded">
                        <Link
                          route={Route.release}
                          params={{
                            applicationId,
                            releaseId: config.id,
                          }}
                          className="font-monospace fw-bold text-primary text-decoration-none"
                        >
                          {config.hash}
                        </Link>
                        <Button
                          variant="link"
                          className="p-0 text-muted border-0 ms-1"
                          style={{ lineHeight: 1 }}
                          title="Copy hash"
                          onClick={() => handleCopyHash(config.hash)}
                        >
                          <Icon
                            icon={
                              copiedHash === config.hash
                                ? "checkSimple"
                                : "copy"
                            }
                            className={
                              copiedHash === config.hash ? "text-success" : ""
                            }
                          />
                        </Button>
                      </div>
                    </td>
                    <td>
                      <div className="d-flex align-items-center gap-2">
                        <Icon icon="containers" className="text-muted" />
                        <span className="text-dark small fw-semibold">
                          {config.containersSummary}
                        </span>
                      </div>
                    </td>
                    <td>
                      <span className="text-secondary small">
                        {config.systemModelsSummary}
                      </span>
                    </td>
                    <td>
                      {configTags.length === 0 ? (
                        <span className="text-muted small fst-italic">
                          Untagged
                        </span>
                      ) : (
                        <div className="d-flex flex-wrap gap-1">
                          {configTags.map((t) => (
                            <Badge
                              key={t.id}
                              bg={t.isPreRelease ? "warning" : "info"}
                              text={t.isPreRelease ? "dark" : "white"}
                              className="px-2 py-1 font-monospace fw-normal"
                              title={`Target Group: ${t.deviceGroupName}`}
                            >
                              <Icon icon="tag" size="0.9em" className="me-1" />
                              {t.name}
                            </Badge>
                          ))}
                        </div>
                      )}
                    </td>
                    <td className="text-muted small">{config.createdAt}</td>
                    <td className="text-end">
                      <Button
                        variant="light"
                        size="sm"
                        className="text-danger"
                        onClick={() => onDeleteConfiguration(config)}
                        title="Delete configuration"
                      >
                        <Icon icon="delete" />
                      </Button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
};

export default ConfigurationsTable;
