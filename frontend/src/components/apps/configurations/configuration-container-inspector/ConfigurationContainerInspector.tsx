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

import { useState } from "react";
import { Badge, Card, Col, Nav, Row, Table } from "react-bootstrap";

import Icon from "@/components/ui/icon/Icon";

export type MockContainerSpec = {
  id: string;
  name: string;
  image: string;
  ports?: string[];
  environment?: Record<string, string>;
  restartPolicy?: string;
  volumes?: Array<{ target: string; driver?: string }>;
  dependsOn?: string[];
  memoryLimit?: string;
  cpuQuota?: string;
  privileged?: boolean;
};

type ConfigurationContainerInspectorProps = {
  containers: MockContainerSpec[];
};

const ConfigurationContainerInspector = ({
  containers,
}: ConfigurationContainerInspectorProps) => {
  const [selectedIndex, setSelectedIndex] = useState(0);

  if (!containers || containers.length === 0) {
    return (
      <div className="text-center py-5 text-muted">
        <Icon icon="containers" size="2.5em" className="mb-2 d-block mx-auto" />
        No containers configured in this configuration.
      </div>
    );
  }

  const selectedContainer = containers[selectedIndex] || containers[0];

  return (
    <Row className="g-4">
      {/* Container Selector Sidebar */}
      <Col md={3}>
        <Card className="border-0 shadow-sm overflow-hidden h-100">
          <Card.Header className="bg-light fw-bold py-3 border-bottom d-flex align-items-center justify-content-between">
            <div className="d-flex align-items-center gap-2">
              <Icon icon="containers" className="text-primary" />
              <span>Containers</span>
            </div>
            <Badge bg="primary" pill>
              {containers.length}
            </Badge>
          </Card.Header>
          <Nav variant="pills" className="flex-column p-2 gap-1">
            {containers.map((container, idx) => {
              const isSelected = selectedIndex === idx;
              return (
                <Nav.Link
                  key={container.id || idx}
                  active={isSelected}
                  onClick={() => setSelectedIndex(idx)}
                  className={`d-flex flex-column align-items-start p-2 text-start rounded transition-all ${
                    isSelected ? "bg-primary text-white" : "text-dark hover-bg-light"
                  }`}
                  style={{ cursor: "pointer" }}
                >
                  <div className="d-flex align-items-center justify-content-between w-100 mb-1">
                    <span className="fw-semibold text-truncate">{container.name}</span>
                    <Badge
                      bg={isSelected ? "light" : "secondary"}
                      text={isSelected ? "dark" : "white"}
                      className="small"
                    >
                      #{idx + 1}
                    </Badge>
                  </div>
                  <small
                    className={`text-truncate w-100 ${
                      isSelected ? "text-white-50" : "text-muted"
                    }`}
                    style={{ fontSize: "0.78rem" }}
                  >
                    {container.image}
                  </small>
                </Nav.Link>
              );
            })}
          </Nav>
        </Card>
      </Col>

      {/* Selected Container Detailed View */}
      <Col md={9}>
        <Card className="border-0 shadow-sm p-4">
          <div className="d-flex align-items-center justify-content-between border-bottom pb-3 mb-4">
            <div>
              <div className="d-flex align-items-center gap-2">
                <Icon icon="containers" size="1.5em" className="text-primary" />
                <h4 className="mb-0 fw-bold">{selectedContainer.name}</h4>
              </div>
              <span className="text-muted font-monospace small">
                Image: <span className="text-dark fw-semibold">{selectedContainer.image}</span>
              </span>
            </div>
            <div className="d-flex gap-2">
              {selectedContainer.privileged && (
                <Badge bg="danger" className="px-3 py-2">
                  Privileged
                </Badge>
              )}
              <Badge bg="info" className="px-3 py-2">
                Restart: {selectedContainer.restartPolicy || "always"}
              </Badge>
            </div>
          </div>

          {/* Section 1: Image & Runtime Details */}
          <div className="mb-4">
            <h6 className="text-uppercase text-muted fw-bold small mb-3">
              Image & Dependencies
            </h6>
            <Table bordered hover size="sm" className="align-middle">
              <tbody>
                <tr>
                  <td className="bg-light fw-semibold text-secondary" style={{ width: "200px" }}>
                    Image Reference
                  </td>
                  <td className="font-monospace text-primary">{selectedContainer.image}</td>
                </tr>
                {selectedContainer.dependsOn && selectedContainer.dependsOn.length > 0 && (
                  <tr>
                    <td className="bg-light fw-semibold text-secondary">Depends On</td>
                    <td>
                      <div className="d-flex gap-1">
                        {selectedContainer.dependsOn.map((dep) => (
                          <Badge key={dep} bg="secondary" className="font-monospace">
                            {dep}
                          </Badge>
                        ))}
                      </div>
                    </td>
                  </tr>
                )}
                <tr>
                  <td className="bg-light fw-semibold text-secondary">Restart Policy</td>
                  <td>{selectedContainer.restartPolicy || "always"}</td>
                </tr>
              </tbody>
            </Table>
          </div>

          {/* Section 2: Network & Port Bindings */}
          <div className="mb-4">
            <h6 className="text-uppercase text-muted fw-bold small mb-3">
              Port Bindings & Networking
            </h6>
            {selectedContainer.ports && selectedContainer.ports.length > 0 ? (
              <div className="d-flex flex-wrap gap-2">
                {selectedContainer.ports.map((port) => (
                  <div
                    key={port}
                    className="border rounded px-3 py-2 bg-light d-flex align-items-center gap-2"
                  >
                    <Icon icon="networks" className="text-primary" />
                    <span className="font-monospace fw-semibold">{port}</span>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-muted small fst-italic">No port bindings specified</p>
            )}
          </div>

          {/* Section 3: Environment Variables */}
          <div className="mb-4">
            <h6 className="text-uppercase text-muted fw-bold small mb-3">
              Environment Variables
            </h6>
            {selectedContainer.environment &&
            Object.keys(selectedContainer.environment).length > 0 ? (
              <div className="table-responsive border rounded">
                <Table hover size="sm" className="mb-0 align-middle">
                  <thead className="table-light">
                    <tr>
                      <th>Key</th>
                      <th>Value</th>
                    </tr>
                  </thead>
                  <tbody>
                    {Object.entries(selectedContainer.environment).map(([k, v]) => (
                      <tr key={k}>
                        <td className="font-monospace fw-bold text-dark">{k}</td>
                        <td className="font-monospace text-secondary">{v}</td>
                      </tr>
                    ))}
                  </tbody>
                </Table>
              </div>
            ) : (
              <p className="text-muted small fst-italic">No environment variables set</p>
            )}
          </div>

          {/* Section 4: Volumes */}
          {selectedContainer.volumes && selectedContainer.volumes.length > 0 && (
            <div className="mb-4">
              <h6 className="text-uppercase text-muted fw-bold small mb-3">
                Volume Mounts
              </h6>
              <Table bordered size="sm" className="align-middle">
                <thead className="table-light">
                  <tr>
                    <th>Target Path</th>
                    <th>Driver</th>
                  </tr>
                </thead>
                <tbody>
                  {selectedContainer.volumes.map((vol, idx) => (
                    <tr key={idx}>
                      <td className="font-monospace">{vol.target}</td>
                      <td>{vol.driver || "local"}</td>
                    </tr>
                  ))}
                </tbody>
              </Table>
            </div>
          )}

          {/* Section 5: Resource Limits */}
          <div>
            <h6 className="text-uppercase text-muted fw-bold small mb-3">
              Resource Allocations
            </h6>
            <Row className="g-3">
              <Col md={6}>
                <div className="p-3 border rounded bg-light">
                  <div className="text-muted small">Memory Limit</div>
                  <div className="fw-bold">{selectedContainer.memoryLimit || "Unlimited (Host Memory)"}</div>
                </div>
              </Col>
              <Col md={6}>
                <div className="p-3 border rounded bg-light">
                  <div className="text-muted small">CPU Quota</div>
                  <div className="fw-bold">{selectedContainer.cpuQuota || "Unlimited (Host CPU)"}</div>
                </div>
              </Col>
            </Row>
          </div>
        </Card>
      </Col>
    </Row>
  );
};

export default ConfigurationContainerInspector;
