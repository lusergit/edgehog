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

import type { ConfigurationRecord } from "@/components/apps/configurations/configurations-table/ConfigurationsTable";
import type { MockContainerSpec } from "@/components/apps/configurations/configuration-container-inspector/ConfigurationContainerInspector";
import type { TagRecord } from "@/components/apps/tags/tags-table/TagsTable";
import type { DeviceGroupOption } from "@/components/apps/tags/create-tag-modal/CreateTagModal";

export type { ConfigurationRecord, TagRecord, DeviceGroupOption };

export const initialMockConfigurations: ConfigurationRecord[] = [
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

export const initialMockTags: TagRecord[] = [
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

export const defaultDeviceGroups: DeviceGroupOption[] = [
  { id: "group-prod", name: "Production Fleet" },
  { id: "group-beta", name: "Beta Testing Group" },
  { id: "group-factory", name: "Factory Floor Devices" },
  { id: "group-staging", name: "Staging Devices" },
];

export type MockInstalledApplication = {
  id: string;
  applicationId: string;
  applicationName: string;
  sourceType: "tag" | "configuration";
  sourceLabel: string;
  configHash: string;
  edited: boolean;
  installedAt: string;
};

export const mockContainersByConfigHash: Record<string, MockContainerSpec[]> = {
  "cfg-7f3a9b12": [
    {
      id: "cont-1",
      name: "web-gateway",
      image: "nginx:1.25-alpine",
      ports: ["80:80/tcp", "443:443/tcp"],
      environment: {
        NGINX_HOST: "edgehog.local",
        CLIENT_MAX_BODY_SIZE: "50m",
        WORKER_PROCESSES: "auto",
      },
      restartPolicy: "always",
      volumes: [{ target: "/etc/nginx/nginx.conf", driver: "bind" }],
      memoryLimit: "512 MB",
      cpuQuota: "50000 µs",
      privileged: false,
    },
    {
      id: "cont-2",
      name: "backend-api",
      image: "node:20-alpine",
      ports: ["4000:4000/tcp"],
      environment: {
        NODE_ENV: "production",
        PORT: "4000",
        LOG_LEVEL: "info",
      },
      restartPolicy: "unless-stopped",
      volumes: [{ target: "/app/uploads", driver: "local" }],
      memoryLimit: "1024 MB",
      cpuQuota: "100000 µs",
      privileged: false,
    },
  ],
  "cfg-4e8c10a3": [
    {
      id: "cont-1",
      name: "web-gateway",
      image: "nginx:1.25-alpine",
      ports: ["80:80/tcp", "443:443/tcp"],
      environment: {
        NGINX_HOST: "edgehog.local",
        CLIENT_MAX_BODY_SIZE: "50m",
      },
      restartPolicy: "always",
      volumes: [{ target: "/etc/nginx/nginx.conf", driver: "bind" }],
      memoryLimit: "512 MB",
      cpuQuota: "50000 µs",
      privileged: false,
    },
    {
      id: "cont-2",
      name: "backend-api",
      image: "node:20.1-alpine",
      ports: ["4000:4000/tcp"],
      environment: {
        NODE_ENV: "production",
        PORT: "4000",
        DB_HOST: "redis-cache",
        DB_PORT: "6379",
        LOG_LEVEL: "info",
      },
      restartPolicy: "unless-stopped",
      dependsOn: ["redis-cache"],
      volumes: [{ target: "/app/uploads", driver: "local" }],
      memoryLimit: "1024 MB",
      cpuQuota: "100000 µs",
      privileged: false,
    },
    {
      id: "cont-3",
      name: "redis-cache",
      image: "redis:7-alpine",
      ports: ["6379:6379/tcp"],
      environment: {
        ALLOW_EMPTY_PASSWORD: "yes",
        MAXMEMORY: "256mb",
      },
      restartPolicy: "always",
      volumes: [{ target: "/data", driver: "local" }],
      memoryLimit: "256 MB",
      cpuQuota: "25000 µs",
      privileged: false,
    },
  ],
  "cfg-9b2f61e8": [
    {
      id: "cont-1",
      name: "edge-agent",
      image: "edgehog/agent:v2",
      environment: {
        EDGEHOG_API_URL: "https://edgehog.example.com",
        LOG_LEVEL: "debug",
      },
      restartPolicy: "always",
      memoryLimit: "256 MB",
      cpuQuota: "25000 µs",
      privileged: true,
    },
  ],
};
