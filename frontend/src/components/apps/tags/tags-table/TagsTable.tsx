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

import Icon from "@/components/ui/icon/Icon";

export type TagRecord = {
  id: string;
  name: string;
  isPreRelease: boolean;
  configurationHash: string;
  deviceGroupId: string;
  deviceGroupName: string;
  createdAt: string;
};

type TagsTableProps = {
  className?: string;
  tags: TagRecord[];
  onEditTag: (tag: TagRecord) => void;
  onDeleteTag: (tag: TagRecord) => void;
  onCreateTag: () => void;
};

const TagsTable = ({
  className,
  tags,
  onEditTag,
  onDeleteTag,
  onCreateTag,
}: TagsTableProps) => {
  const [searchText, setSearchText] = useState("");
  const [copiedHash, setCopiedHash] = useState<string | null>(null);

  const filteredTags = useMemo(() => {
    if (!searchText.trim()) return tags;
    const term = searchText.toLowerCase().trim();
    return tags.filter(
      (t) =>
        t.name.toLowerCase().includes(term) ||
        t.deviceGroupName.toLowerCase().includes(term) ||
        t.configurationHash.toLowerCase().includes(term),
    );
  }, [tags, searchText]);

  const handleCopyHash = (hash: string) => {
    navigator.clipboard.writeText(hash);
    setCopiedHash(hash);
    setTimeout(() => setCopiedHash(null), 2000);
  };

  return (
    <div className={className}>
      <div className="d-flex justify-content-between align-items-center mb-3">
        <InputGroup style={{ maxWidth: "320px" }}>
          <InputGroup.Text className="bg-white border-end-0">
            <Icon icon="search" className="text-muted" />
          </InputGroup.Text>
          <Form.Control
            placeholder="Search tags, groups or hash..."
            className="border-start-0 ps-0"
            value={searchText}
            onChange={(e) => setSearchText(e.target.value)}
          />
        </InputGroup>

        <Button variant="primary" onClick={onCreateTag}>
          <Icon icon="plus" className="me-2" />
          <FormattedMessage
            id="components.apps.tags.TagsTable.createTag"
            defaultMessage="Create Tag"
          />
        </Button>
      </div>

      {filteredTags.length === 0 ? (
        <div className="text-center py-5 border rounded bg-light">
          <Icon
            icon="tag"
            size="2.5em"
            className="text-secondary mb-3 d-block mx-auto"
          />
          <h5 className="text-muted">No tags found</h5>
          <p className="text-secondary small mb-3">
            Tags associate semver version names and pre-release flags with a
            device group and a configuration.
          </p>
          <Button variant="outline-primary" size="sm" onClick={onCreateTag}>
            <Icon icon="plus" className="me-1" />
            Create your first Tag
          </Button>
        </div>
      ) : (
        <div className="table-responsive border rounded">
          <table className="table table-hover align-middle mb-0">
            <thead className="table-light">
              <tr>
                <th>
                  <FormattedMessage
                    id="components.apps.tags.TagsTable.tagName"
                    defaultMessage="Tag Name (SemVer)"
                  />
                </th>
                <th>
                  <FormattedMessage
                    id="components.apps.tags.TagsTable.releaseType"
                    defaultMessage="Release Type"
                  />
                </th>
                <th>
                  <FormattedMessage
                    id="components.apps.tags.TagsTable.targetGroup"
                    defaultMessage="Target Device Group"
                  />
                </th>
                <th>
                  <FormattedMessage
                    id="components.apps.tags.TagsTable.configuration"
                    defaultMessage="Configuration Hash"
                  />
                </th>
                <th>
                  <FormattedMessage
                    id="components.apps.tags.TagsTable.createdAt"
                    defaultMessage="Created At"
                  />
                </th>
                <th className="text-end">
                  <FormattedMessage
                    id="components.apps.tags.TagsTable.actions"
                    defaultMessage="Actions"
                  />
                </th>
              </tr>
            </thead>
            <tbody>
              {filteredTags.map((tag) => (
                <tr key={tag.id}>
                  <td>
                    <div className="d-flex align-items-center gap-2">
                      <Icon icon="tag" className="text-primary" />
                      <span className="fw-bold font-monospace text-dark">
                        {tag.name}
                      </span>
                    </div>
                  </td>
                  <td>
                    {tag.isPreRelease ? (
                      <Badge
                        bg="warning"
                        text="dark"
                        className="px-2 py-1 fw-normal"
                      >
                        Pre-release
                      </Badge>
                    ) : (
                      <Badge bg="success" className="px-2 py-1 fw-normal">
                        Release
                      </Badge>
                    )}
                  </td>
                  <td>
                    <div className="d-flex align-items-center gap-2">
                      <Icon icon="deviceGroups" className="text-muted" />
                      <span>{tag.deviceGroupName}</span>
                    </div>
                  </td>
                  <td>
                    <div className="d-inline-flex align-items-center gap-1 bg-light border px-2 py-1 rounded">
                      <code className="text-primary fw-semibold">
                        {tag.configurationHash}
                      </code>
                      <Button
                        variant="link"
                        className="p-0 text-muted border-0 ms-1"
                        style={{ lineHeight: 1 }}
                        title="Copy configuration hash"
                        onClick={() => handleCopyHash(tag.configurationHash)}
                      >
                        <Icon
                          icon={
                            copiedHash === tag.configurationHash
                              ? "checkSimple"
                              : "copy"
                          }
                          className={
                            copiedHash === tag.configurationHash
                              ? "text-success"
                              : ""
                          }
                        />
                      </Button>
                    </div>
                  </td>
                  <td className="text-muted small">{tag.createdAt}</td>
                  <td className="text-end">
                    <Button
                      variant="light"
                      size="sm"
                      className="me-2 text-secondary"
                      onClick={() => onEditTag(tag)}
                      title="Edit tag"
                    >
                      <Icon icon="edit" />
                    </Button>
                    <Button
                      variant="light"
                      size="sm"
                      className="text-danger"
                      onClick={() => onDeleteTag(tag)}
                      title="Delete tag"
                    >
                      <Icon icon="delete" />
                    </Button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
};

export default TagsTable;
