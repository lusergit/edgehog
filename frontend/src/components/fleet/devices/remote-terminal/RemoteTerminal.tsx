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

import { ReactNode, useCallback, useState } from "react";
import {
  graphql,
  useMutation,
  fetchQuery,
  useRelayEnvironment,
} from "react-relay/hooks";
import { FormattedMessage, useIntl } from "react-intl";
import type { PayloadError } from "relay-runtime";

import type { RemoteTerminal_getForwarderSession_Query } from "@/api/__generated__/RemoteTerminal_getForwarderSession_Query.graphql";
import type { RemoteTerminal_requestForwarderSession_Mutation } from "@/api/__generated__/RemoteTerminal_requestForwarderSession_Mutation.graphql";

import Alert from "@/components/ui/alert/Alert";
import Button from "@/components/ui/button/Button";
import Icon from "@/components/ui/icon/Icon";
import Spinner from "@/components/ui/spinner/Spinner";

const REQUEST_FORWARDER_SESSION_MUTATION = graphql`
  mutation RemoteTerminal_requestForwarderSession_Mutation(
    $input: RequestForwarderSessionInput!
  ) {
    requestForwarderSession(input: $input)
  }
`;

const GET_FORWARDER_SESSION_QUERY = graphql`
  query RemoteTerminal_getForwarderSession_Query(
    $deviceId: ID!
    $sessionToken: String!
  ) {
    forwarderSession(deviceId: $deviceId, token: $sessionToken) {
      status
      secure
      forwarderHostname
      forwarderPort
    }
  }
`;

const TTYD_PORT = 7681;

interface RemoteTerminalProps {
  deviceId: string;
  disabled: boolean;
  onError: (feedback: ReactNode) => void;
}

function timeoutPromise<T>(promise: Promise<T>, millis: number) {
  return Promise.race([
    promise,
    new Promise((_resolve, reject) => setTimeout(() => reject(), millis)),
  ]);
}

async function retryWithExponentialBackoff<T>(
  fn: () => Promise<T>,
  attempt = 1,
  maxAttempts = 4,
  baseDelayMs = 1000,
): Promise<T> {
  try {
    return await fn();
  } catch (error) {
    if (attempt >= maxAttempts) {
      throw error;
    }
    const delayMs = baseDelayMs * (2 ** attempt - 1);
    await new Promise((resolve) => setTimeout(resolve, delayMs));
    return await retryWithExponentialBackoff(
      fn,
      attempt + 1,
      maxAttempts,
      baseDelayMs,
    );
  }
}

const RemoteTerminal = ({
  deviceId,
  disabled,
  onError,
}: RemoteTerminalProps) => {
  const intl = useIntl();
  const relayEnvironment = useRelayEnvironment();
  const [isOpeningRemoteTerminal, setIsOpeningRemoteTerminal] = useState(false);
  const [remoteTerminalErrorFeedback, setRemoteTerminalErrorFeedback] =
    useState<ReactNode>(null);

  const [requestForwarderSession, isRequestingForwarderSession] =
    useMutation<RemoteTerminal_requestForwarderSession_Mutation>(
      REQUEST_FORWARDER_SESSION_MUTATION,
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

  const handleOpenRemoteTerminal = useCallback(
    async (sessionToken: string) => {
      const data = await fetchQuery<RemoteTerminal_getForwarderSession_Query>(
        relayEnvironment,
        GET_FORWARDER_SESSION_QUERY,
        { deviceId, sessionToken },
      ).toPromise();

      if (!data?.forwarderSession) {
        throw new Error("The forwarder session does not exist.");
      }

      const { forwarderHostname, forwarderPort, secure, status } =
        data.forwarderSession;

      if (status !== "CONNECTED") {
        throw new Error("The forwarder session is not connected.");
      }

      const forwarderProtocol = secure ? "https" : "http";

      window.open(
        `${forwarderProtocol}://${forwarderHostname}:${forwarderPort}/v1/${sessionToken}/http/${TTYD_PORT}`,
        "_blank",
      );
    },
    [relayEnvironment, deviceId],
  );

  const handleRequestForwarderSession = useCallback(() => {
    requestForwarderSession({
      variables: { input: { deviceId } },
      onCompleted(data, errors) {
        if (errors) {
          handleAPIErrors(errors);
          return;
        }
        const sessionToken = data.requestForwarderSession;

        setIsOpeningRemoteTerminal(true);
        timeoutPromise(
          retryWithExponentialBackoff(() =>
            handleOpenRemoteTerminal(sessionToken),
          ),
          10_000,
        )
          .catch(() => {
            setRemoteTerminalErrorFeedback(
              <FormattedMessage
                id="components.fleet.devices.remote-terminal.RemoteTerminal.openRemoteTerminalErrorFeedback"
                defaultMessage="Could not access the remote terminal, please try again."
                description="Feedback for unknown error while opening a remote terminal session"
              />,
            );
          })
          .finally(() => {
            setIsOpeningRemoteTerminal(false);
          });
      },
      onError() {
        onError(
          <FormattedMessage
            id="components.fleet.devices.remote-terminal.RemoteTerminal.openRemoteTerminalErrorFeedback"
            defaultMessage="Could not access the remote terminal, please try again."
            description="Feedback for unknown error while opening a remote terminal session"
          />,
        );
      },
    });
  }, [
    requestForwarderSession,
    handleOpenRemoteTerminal,
    deviceId,
    handleAPIErrors,
    onError,
  ]);

  return (
    <>
      <Button
        variant="secondary"
        onClick={handleRequestForwarderSession}
        disabled={
          disabled || isRequestingForwarderSession || isOpeningRemoteTerminal
        }
        aria-label={intl.formatMessage({
          id: "components.fleet.devices.remote-terminal.RemoteTerminal.openTerminalButton",
          defaultMessage: "Open terminal",
        })}
      >
        {(isRequestingForwarderSession || isOpeningRemoteTerminal) && (
          <Spinner size="sm" className="me-2" />
        )}
        <Icon icon="terminal" className="me-2" />
        <FormattedMessage
          id="components.fleet.devices.remote-terminal.RemoteTerminal.openTerminalButton"
          defaultMessage="Open terminal"
        />
      </Button>
      <Alert
        show={!!remoteTerminalErrorFeedback}
        variant="danger"
        onClose={() => setRemoteTerminalErrorFeedback(null)}
        dismissible
        className="mt-3"
      >
        {remoteTerminalErrorFeedback}
      </Alert>
    </>
  );
};

export default RemoteTerminal;
