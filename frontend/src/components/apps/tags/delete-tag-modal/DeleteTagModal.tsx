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

import { Modal, Button } from "react-bootstrap";
import type { TagRecord } from "../tags-table/TagsTable";

type DeleteTagModalProps = {
  tagToDelete: TagRecord | null;
  onConfirm: () => void;
  onCancel: () => void;
};

const DeleteTagModal = ({
  tagToDelete,
  onConfirm,
  onCancel,
}: DeleteTagModalProps) => {
  if (!tagToDelete) return null;

  return (
    <Modal show={!!tagToDelete} onHide={onCancel} centered>
      <Modal.Header closeButton>
        <Modal.Title>Delete Tag</Modal.Title>
      </Modal.Header>
      <Modal.Body>
        Are you sure you want to delete tag{" "}
        <strong className="font-monospace">{tagToDelete.name}</strong> pointing
        to configuration{" "}
        <code className="text-primary">{tagToDelete.configurationHash}</code>{" "}
        for group <strong>{tagToDelete.deviceGroupName}</strong>?
      </Modal.Body>
      <Modal.Footer>
        <Button variant="secondary" onClick={onCancel}>
          Cancel
        </Button>
        <Button variant="danger" onClick={onConfirm}>
          Delete Tag
        </Button>
      </Modal.Footer>
    </Modal>
  );
};

export default DeleteTagModal;
