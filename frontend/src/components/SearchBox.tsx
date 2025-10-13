/*
  This file is part of Edgehog.

  Copyright 2021 SECO Mind Srl

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  SPDX-License-Identifier: Apache-2.0
*/

import React, { useCallback } from "react";
import { useIntl } from "react-intl";
import Form from "react-bootstrap/Form";
import InputGroup from "react-bootstrap/InputGroup";

import Icon from "components/Icon";
import { IconArrowRight, IconSearch } from "@tabler/icons-react";
import {
  ActionIcon,
  TextInput,
  TextInputProps,
  useMantineTheme,
} from "@mantine/core";

interface Props {
  className?: string;
  onChange?: (searchText: string) => void;
}

const SearchBox = ({ className = "", onChange }: Props) => {
  const theme = useMantineTheme();
  const intl = useIntl();

  const handleChange: React.ChangeEventHandler<HTMLInputElement> = useCallback(
    (event) => {
      const searchText = event.target.value;
      onChange && onChange(searchText);
    },
    [onChange],
  );

  return (
    <TextInput
      radius="xl"
      size="md"
      placeholder={intl.formatMessage({
        id: "components.SearchBox.searchPlaceholder",
        defaultMessage: "Search",
        description: "Placeholder for the search input of the SearchBox",
      })}
      rightSectionWidth={42}
      leftSection={<IconSearch size={18} stroke={1.5} />}
      rightSection={
        <ActionIcon
          size={32}
          radius="xl"
          color={theme.primaryColor}
          variant="filled"
        >
          <IconArrowRight size={18} stroke={1.5} />
        </ActionIcon>
      }
      onChange={handleChange}
    />
  );
};

export default SearchBox;
