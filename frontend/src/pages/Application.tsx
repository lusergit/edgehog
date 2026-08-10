/*
 * This file is part of Edgehog.
 *
 * Copyright 2024-2026 SECO Mind Srl
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

import { Suspense, useCallback, useEffect, useMemo, useState } from "react";
import { Card, Col, Form, Row } from "react-bootstrap";
import { ErrorBoundary } from "react-error-boundary";
import { FormattedMessage, useIntl } from "react-intl";
import type { PreloadedQuery } from "react-relay/hooks";
import { graphql, usePreloadedQuery, useQueryLoader } from "react-relay/hooks";
import { useParams } from "react-router-dom";

import type {
  Application_getApplication_Query,
  Application_getApplication_Query$data,
} from "@/api/__generated__/Application_getApplication_Query.graphql";

import { Link, Route, useNavigate } from "@/Navigation";
import Alert from "@/components/ui/alert/Alert";
import Button from "@/components/ui/button/Button";
import Center from "@/components/ui/center/Center";
import DeleteReleaseModal from "@/components/apps/releases/delete-release-modal/DeleteReleaseModal";
import Page from "@/components/ui/page/Page";
import Result from "@/components/ui/result/Result";
import Spinner from "@/components/ui/spinner/Spinner";
import Tabs, { Tab } from "@/components/ui/tabs/Tabs";

import ConfigurationsTable, {
  ConfigurationRecord,
} from "@/components/apps/configurations/configurations-table/ConfigurationsTable";
import TagsTable, {
  TagRecord,
} from "@/components/apps/tags/tags-table/TagsTable";
import CreateTagModal, {
  DeviceGroupOption,
  ConfigurationOption,
} from "@/components/apps/tags/create-tag-modal/CreateTagModal";
import DeleteTagModal from "@/components/apps/tags/delete-tag-modal/DeleteTagModal";
import Icon from "@/components/ui/icon/Icon";

const GET_APPLICATION_QUERY = graphql`
  query Application_getApplication_Query($applicationId: ID!) {
    application(id: $applicationId) {
      id
      name
      description
    }
  }
`;

const TAB_KEYS = ["tags-tab", "configurations-tab"];

const initialMockConfigurations: ConfigurationRecord[] = [
  {
    id: "cfg-1",
    hash: "cfg-7f3a9b12",
    containersSummary: "web-gateway (nginx:1.25), backend-api (node:20)",
    containersCount: 2,
    systemModelsSummary: "SECO SM-C12, Gateway 500",
    createdAt: "2026-08-01 10:30",
  },
  {
    id: "cfg-2",
    hash: "cfg-4e8c10a3",
    containersSummary:
      "web-gateway (nginx:1.25), backend-api (node:20.1), redis-cache (redis:7)",
    containersCount: 3,
    systemModelsSummary: "SECO SM-C12",
    createdAt: "2026-08-08 14:15",
  },
  {
    id: "cfg-3",
    hash: "cfg-9b2f61e8",
    containersSummary: "edge-agent (edgehog/agent:v2)",
    containersCount: 1,
    systemModelsSummary: "All System Models",
    createdAt: "2026-08-09 16:45",
  },
];

const initialMockTags: TagRecord[] = [
  {
    id: "tag-1",
    name: "v1.0.0",
    isPreRelease: false,
    configurationHash: "cfg-7f3a9b12",
    deviceGroupId: "group-prod",
    deviceGroupName: "Production Fleet",
    createdAt: "2026-08-02 09:00",
  },
  {
    id: "tag-2",
    name: "v1.1.0-beta.1",
    isPreRelease: true,
    configurationHash: "cfg-4e8c10a3",
    deviceGroupId: "group-beta",
    deviceGroupName: "Beta Testing Group",
    createdAt: "2026-08-08 15:00",
  },
];

const defaultDeviceGroups: DeviceGroupOption[] = [
  { id: "group-prod", name: "Production Fleet" },
  { id: "group-beta", name: "Beta Testing Group" },
  { id: "group-factory", name: "Factory Floor Devices" },
  { id: "group-staging", name: "Staging Devices" },
];

interface ApplicationContentProps {
  application: NonNullable<
    Application_getApplication_Query$data["application"]
  >;
}

const ApplicationContent = ({ application }: ApplicationContentProps) => {
  const intl = useIntl();
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const { applicationId = "", activeTab } = useParams();
  const navigate = useNavigate();

  const currentTabKey = activeTab || TAB_KEYS[0];

  // Interactive mock states
  const [configurations, setConfigurations] = useState<ConfigurationRecord[]>(
    initialMockConfigurations,
  );
  const [tags, setTags] = useState<TagRecord[]>(initialMockTags);

  // Modal states
  const [isTagModalOpen, setIsTagModalOpen] = useState(false);
  const [editingTag, setEditingTag] = useState<TagRecord | null>(null);
  const [deletingTag, setDeletingTag] = useState<TagRecord | null>(null);
  const [deletingConfig, setDeletingConfig] =
    useState<ConfigurationRecord | null>(null);

  const configurationOptions: ConfigurationOption[] = useMemo(
    () =>
      configurations.map((c) => ({
        hash: c.hash,
        containersSummary: c.containersSummary,
      })),
    [configurations],
  );

  const handleSaveTag = (
    tagData: Omit<TagRecord, "id" | "createdAt"> & { id?: string },
  ) => {
    if (tagData.id) {
      setTags((prev) =>
        prev.map((t) => (t.id === tagData.id ? { ...t, ...tagData } : t)),
      );
    } else {
      const newTag: TagRecord = {
        ...tagData,
        id: `tag-${Date.now()}`,
        createdAt: new Date().toISOString().slice(0, 16).replace("T", " "),
      };
      setTags((prev) => [newTag, ...prev]);
    }
  };

  const handleDeleteTag = () => {
    if (deletingTag) {
      setTags((prev) => prev.filter((t) => t.id !== deletingTag.id));
      setDeletingTag(null);
    }
  };

  const handleDeleteConfig = () => {
    if (deletingConfig) {
      setConfigurations((prev) =>
        prev.filter((c) => c.id !== deletingConfig.id),
      );
      setTags((prev) =>
        prev.filter((t) => t.configurationHash !== deletingConfig.hash),
      );
      setDeletingConfig(null);
    }
  };

  return (
    <Page>
      <Page.Header title={application.name}>
        <div className="d-flex gap-2">
          <Button
            variant="outline-primary"
            onClick={() => {
              setEditingTag(null);
              setIsTagModalOpen(true);
            }}
          >
            <Icon icon="tag" className="me-2" />
            <FormattedMessage
              id="pages.Application.createTagButton"
              defaultMessage="Create Tag"
            />
          </Button>
          <Button
            as={Link}
            route={Route.releaseNew}
            params={{ applicationId: applicationId }}
          >
            <Icon icon="plus" className="me-2" />
            <FormattedMessage
              id="pages.Application.createConfigButton"
              defaultMessage="Create Configuration"
            />
          </Button>
        </div>
      </Page.Header>
      <Page.Main>
        <Alert
          show={!!errorFeedback}
          variant="danger"
          onClose={() => setErrorFeedback(null)}
          dismissible
        >
          {errorFeedback}
        </Alert>

        <Card className="h-100 border-0 p-3 shadow-sm mb-3">
          <Form.Group as={Row} controlId="application" className="mt-3 mb-4">
            <Form.Label column sm={2}>
              <FormattedMessage
                id="pages.Application.description"
                defaultMessage="Description"
              />
            </Form.Label>
            <Col sm={10}>
              <Form.Control
                as="textarea"
                value={application.description ?? ""}
                rows={3}
                readOnly
              />
            </Col>
          </Form.Group>
        </Card>

        <Tabs
          className="d-flex flex-column flex-grow-1"
          activeKey={currentTabKey}
          tabsOrder={TAB_KEYS}
          onChange={(tabKey) =>
            navigate(
              {
                route: Route.application,
                params: { applicationId, activeTab: tabKey },
              },
              { replace: true },
            )
          }
        >
          <Tab
            eventKey="tags-tab"
            className="pt-3 d-flex flex-column flex-grow-1"
            title={intl.formatMessage({
              id: "pages.Application.tags",
              defaultMessage: "Tags",
            })}
          >
            <Card className="gap-2 border-0 shadow-sm flex-grow-1 p-4">
              <TagsTable
                tags={tags}
                onEditTag={(tag) => {
                  setEditingTag(tag);
                  setIsTagModalOpen(true);
                }}
                onDeleteTag={(tag) => setDeletingTag(tag)}
                onCreateTag={() => {
                  setEditingTag(null);
                  setIsTagModalOpen(true);
                }}
              />
            </Card>
          </Tab>

          <Tab
            eventKey="configurations-tab"
            className="pt-3 d-flex flex-column flex-grow-1"
            title={intl.formatMessage({
              id: "pages.Application.configurations",
              defaultMessage: "Configurations",
            })}
          >
            <Card className="gap-2 border-0 shadow-sm flex-grow-1 p-4">
              <ConfigurationsTable
                applicationId={applicationId}
                configurations={configurations}
                tags={tags}
                onDeleteConfiguration={(config) => setDeletingConfig(config)}
                onCreateConfiguration={() =>
                  navigate({
                    route: Route.releaseNew,
                    params: { applicationId },
                  })
                }
              />
            </Card>
          </Tab>
        </Tabs>

        <CreateTagModal
          show={isTagModalOpen}
          tagToEdit={editingTag}
          configurations={configurationOptions}
          deviceGroups={defaultDeviceGroups}
          onClose={() => setIsTagModalOpen(false)}
          onSave={handleSaveTag}
        />

        <DeleteTagModal
          tagToDelete={deletingTag}
          onConfirm={handleDeleteTag}
          onCancel={() => setDeletingTag(null)}
        />

        {deletingConfig && (
          <DeleteReleaseModal
            releaseToDelete={{
              id: deletingConfig.id,
              version: deletingConfig.hash,
              application: { id: applicationId },
            }}
            onConfirm={handleDeleteConfig}
            onCancel={() => setDeletingConfig(null)}
            setErrorFeedback={setErrorFeedback}
          />
        )}
      </Page.Main>
    </Page>
  );
};

type ApplicationWrapperProps = {
  getApplicationQuery: PreloadedQuery<Application_getApplication_Query>;
};

const ApplicationWrapper = ({
  getApplicationQuery,
}: ApplicationWrapperProps) => {
  const { application } = usePreloadedQuery<Application_getApplication_Query>(
    GET_APPLICATION_QUERY,
    getApplicationQuery,
  );

  if (!application) {
    return (
      <Result.NotFound
        title={
          <FormattedMessage
            id="pages.Application.applicationNotFound.title"
            defaultMessage="Application not found."
          />
        }
      >
        <Link route={Route.applications}>
          <FormattedMessage
            id="pages.Application.applicationNotFound.message"
            defaultMessage="Return to the applications list."
          />
        </Link>
      </Result.NotFound>
    );
  }

  return <ApplicationContent application={application} />;
};

const ApplicationPage = () => {
  const { applicationId = "" } = useParams();

  const [getApplicationQuery, getApplication] =
    useQueryLoader<Application_getApplication_Query>(GET_APPLICATION_QUERY);

  const fetchApplication = useCallback(
    () => getApplication({ applicationId }, { fetchPolicy: "network-only" }),
    [getApplication, applicationId],
  );

  useEffect(fetchApplication, [fetchApplication]);

  return (
    <Suspense
      fallback={
        <Center data-testid="page-loading">
          <Spinner />
        </Center>
      }
    >
      <ErrorBoundary
        FallbackComponent={(props) => (
          <Center data-testid="page-error">
            <Page.LoadingError onRetry={props.resetErrorBoundary} />
          </Center>
        )}
        onReset={fetchApplication}
      >
        {getApplicationQuery && (
          <ApplicationWrapper getApplicationQuery={getApplicationQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default ApplicationPage;
