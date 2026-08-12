// This file is part of Edgehog.
//
// Copyright 2022-2026 SECO Mind Srl
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

import { useCallback, useEffect, useState } from "react";
import { graphql, useMutation } from "react-relay/hooks";
import { defineMessages, FormattedMessage, useIntl } from "react-intl";
import type { MessageDescriptor } from "react-intl";

import ButtonGroup from "react-bootstrap/ButtonGroup";
import OverlayTrigger from "react-bootstrap/OverlayTrigger";
import Tooltip from "react-bootstrap/Tooltip";

import Button from "@/components/ui/button/Button";
import Icon from "@/components/ui/icon/Icon";
import Spinner from "@/components/ui/spinner/Spinner";

import type { LedBehaviorButtons_setLedBehavior_Mutation } from "@/api/__generated__/LedBehaviorButtons_setLedBehavior_Mutation.graphql";

const SET_LED_BEHAVIOR_MUTATION = graphql`
  mutation LedBehaviorButtons_setLedBehavior_Mutation(
    $deviceId: ID!
    $input: SetDeviceLedBehaviorInput!
  ) {
    setDeviceLedBehavior(id: $deviceId, input: $input) {
      result {
        __typename
      }
    }
  }
`;

const SUPPORTED_LED_BEHAVIORS = [
  "BLINK",
  "DOUBLE_BLINK",
  "SLOW_BLINK",
] as const;
type SupportedLedBehavior = (typeof SUPPORTED_LED_BEHAVIORS)[number];

const supportedBehaviorMessages: Record<
  SupportedLedBehavior,
  MessageDescriptor
> = defineMessages({
  BLINK: {
    id: "components.fleet.devices.led-behavior-buttons.LedBehaviorButtons.behavior.blinkLED",
    defaultMessage: "Blink LED",
  },
  DOUBLE_BLINK: {
    id: "components.fleet.devices.led-behavior-buttons.LedBehaviorButtons.behavior.doubleBlinkLED",
    defaultMessage: "Double blink LED",
  },
  SLOW_BLINK: {
    id: "components.fleet.devices.led-behavior-buttons.LedBehaviorButtons.behavior.slowBlinkLED",
    defaultMessage: "Slow blink LED",
  },
});

const supportedBehaviorIcons: Record<
  SupportedLedBehavior,
  "lightbulb" | "zap" | "sun"
> = {
  BLINK: "lightbulb",
  DOUBLE_BLINK: "zap",
  SLOW_BLINK: "sun",
};

function isSupportedLedBehavior(value: unknown): value is SupportedLedBehavior {
  return (
    typeof value === "string" &&
    SUPPORTED_LED_BEHAVIORS.includes(value as SupportedLedBehavior)
  );
}

interface Props {
  deviceId: string;
  disabled: boolean;
  onError: (error: React.ReactNode) => void;
}

const LedBehaviorButtons = ({ deviceId, disabled, onError }: Props) => {
  const intl = useIntl();

  const [setLedBehavior, isSettingLedBehavior] =
    useMutation<LedBehaviorButtons_setLedBehavior_Mutation>(
      SET_LED_BEHAVIOR_MUTATION,
    );

  const [currentBehavior, setCurrentBehavior] =
    useState<SupportedLedBehavior | null>(null);

  useEffect(() => {
    if (!currentBehavior) {
      return;
    }
    const timeout = setTimeout(() => {
      setCurrentBehavior(null);
    }, 10000);

    return () => clearTimeout(timeout);
  }, [currentBehavior, setCurrentBehavior]);

  const handleSetLedBehavior = useCallback(
    (ledBehavior: unknown) => {
      if (!isSupportedLedBehavior(ledBehavior)) {
        return;
      }
      setCurrentBehavior(null);

      setLedBehavior({
        variables: {
          deviceId,
          input: {
            behavior: ledBehavior,
          },
        },
        onCompleted(_data, errors) {
          if (errors) {
            const errorFeedback = errors
              .map(({ fields, message }) =>
                fields.length ? `${fields.join(" ")} ${message}` : message,
              )
              .join(". \n");
            return onError(errorFeedback);
          }
          setCurrentBehavior(ledBehavior);
        },
        onError() {
          onError(
            <FormattedMessage
              id="components.fleet.devices.led-behavior-buttons.LedBehaviorButtons.genericErrorFeedback"
              defaultMessage="The request could not reach the server, please try again."
            />,
          );
        },
      });
    },
    [setLedBehavior, deviceId, onError, setCurrentBehavior],
  );

  return (
    <OverlayTrigger
      overlay={
        <Tooltip>
          <FormattedMessage
            id="components.fleet.devices.led-behavior-buttons.LedBehaviorButtons.tooltip"
            defaultMessage="The device LED will blink for 60s."
          />
        </Tooltip>
      }
    >
      <ButtonGroup
        aria-label={intl.formatMessage({
          id: "components.fleet.devices.led-behavior-buttons.LedBehaviorButtons.identify",
          defaultMessage: "Identify device",
        })}
      >
        {SUPPORTED_LED_BEHAVIORS.map((behavior) => {
          const isActive = currentBehavior === behavior;
          return (
            <Button
              key={behavior}
              variant={isActive ? "success" : "secondary"}
              disabled={disabled || isSettingLedBehavior}
              onClick={() => handleSetLedBehavior(behavior)}
              aria-pressed={isActive}
            >
              {isActive && <Icon icon="check" className="me-2" />}
              {isSettingLedBehavior && !isActive && (
                <Spinner
                  as="span"
                  size="sm"
                  className="me-2"
                  aria-hidden="true"
                />
              )}
              <Icon icon={supportedBehaviorIcons[behavior]} className="me-2" />
              {intl.formatMessage(supportedBehaviorMessages[behavior])}
            </Button>
          );
        })}
      </ButtonGroup>
    </OverlayTrigger>
  );
};

export default LedBehaviorButtons;
