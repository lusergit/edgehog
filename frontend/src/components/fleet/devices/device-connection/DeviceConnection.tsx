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

import { FormattedDate, FormattedMessage } from "react-intl";

import ConnectionStatus from "@/components/fleet/devices/connection-status/ConnectionStatus";

interface DeviceConnectionProps {
  online: boolean;
  lastConnection: string | null;
}

const DeviceConnection = ({
  online,
  lastConnection,
}: DeviceConnectionProps) => (
  <div className="d-flex flex-wrap align-items-center">
    <ConnectionStatus connected={online} />
    {!online && lastConnection && (
      <span className="text-secondary ms-2">
        <FormattedMessage
          id="components.fleet.devices.device-connection.DeviceConnection.lastSeen"
          defaultMessage="Last seen {date}"
          values={{
            date: (
              <FormattedDate
                value={new Date(lastConnection)}
                year="numeric"
                month="long"
                day="numeric"
                hour="numeric"
                minute="numeric"
              />
            ),
          }}
        />
      </span>
    )}
  </div>
);

export default DeviceConnection;
