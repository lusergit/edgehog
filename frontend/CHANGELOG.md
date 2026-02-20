# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!-- NOTICE -->
<!-- Starting from v0.11 changelogs are separated per-project. The changes below
refer to both the frontend *and* the backend of edgehog -->

## [0.13.0](https://github.com/lusergit/edgehog/compare/v0.12.0...v0.13.0) (2026-02-20)


### Features

* `chevronDown` and `chevronUp` icon ([6d5dc58](https://github.com/lusergit/edgehog/commit/6d5dc582a37f3a1278f623d3baf3d2baf67996d3))
* `MonacoJsonEditor` for `Network` and `Volume` options ([37aa65e](https://github.com/lusergit/edgehog/commit/37aa65ef6a2eeaadcaf1eaec515c9cada9a23d34))
* `MonacoJsonEditor` fro `Network` and `Volume` options ([78325cb](https://github.com/lusergit/edgehog/commit/78325cb701fc35508ec95ac929fadfc99111efe0))
* Add `Pause` and `Resume` functionality for campaigns ([#1204](https://github.com/lusergit/edgehog/issues/1204)) ([35a9aab](https://github.com/lusergit/edgehog/commit/35a9aab42a458358bf87a60e37453b26a7ac0228)), closes [#277](https://github.com/lusergit/edgehog/issues/277)
* Add Application field to Deployment Campaign form and reorder ([1ef74e4](https://github.com/lusergit/edgehog/commit/1ef74e42f1a00ce289dcc27c59299b9dcf859c0c))
* add binds field for container directory mappings  ([#1009](https://github.com/lusergit/edgehog/issues/1009)) ([1dcfea1](https://github.com/lusergit/edgehog/commit/1dcfea1cddd1c185b571cf147e01e1ab31b083da))
* add confirmation modal for removing container ([#1068](https://github.com/lusergit/edgehog/issues/1068)) ([a3d0a1f](https://github.com/lusergit/edgehog/commit/a3d0a1f3258661a527e7667f56822dd643c711cb))
* Add Container deployment status visibility ([#968](https://github.com/lusergit/edgehog/issues/968)) ([8c3e2de](https://github.com/lusergit/edgehog/commit/8c3e2de747f3f3de27a8de5b0fc34225caeadfae))
* Add default image for devices without system model image ([#1005](https://github.com/lusergit/edgehog/issues/1005)) ([0af6a9a](https://github.com/lusergit/edgehog/commit/0af6a9a30a264ccc7c844ce82ac4fc7e7ade453d))
* add deployment details ([#1060](https://github.com/lusergit/edgehog/issues/1060)) ([51b9503](https://github.com/lusergit/edgehog/commit/51b9503eacb60d33eb874537f71839033e0d6de9))
* add device group subscription ([#1198](https://github.com/lusergit/edgehog/issues/1198)) ([adb91f4](https://github.com/lusergit/edgehog/commit/adb91f4e5f7011cdf424b77371ebf4f8858f66d1))
* add GraphQL subscription for device creation ([1d5a0ba](https://github.com/lusergit/edgehog/commit/1d5a0ba36a7a6c3940ae61215fc03614e6817db6))
* Add operation type selection when creating a deployment campaign ([#1033](https://github.com/lusergit/edgehog/issues/1033)) ([dea311f](https://github.com/lusergit/edgehog/commit/dea311f8571694ed2a4bc8ba2fb0aacfe95d5a79))
* Add visual feedback for imported containers in CreateRelease form ([119f61c](https://github.com/lusergit/edgehog/commit/119f61cbc2e78cb30def59eae1dbc8ab96aa41dc))
* add volume driver filed to container view ([#1051](https://github.com/lusergit/edgehog/issues/1051)) ([27cfd0d](https://github.com/lusergit/edgehog/commit/27cfd0d87766759f3dcf8388d152ee8e476820f4))
* allow users to re-send deployment messages ([#1041](https://github.com/lusergit/edgehog/issues/1041)) ([64a5dd9](https://github.com/lusergit/edgehog/commit/64a5dd939dfef35dca69ba8e91489e295a3566ee))
* application management ([#934](https://github.com/lusergit/edgehog/issues/934)) ([c1f8421](https://github.com/lusergit/edgehog/commit/c1f84219e056da81ee82f0171cc0ffdb0191f6c1))
* **backend:** allow deletion of BaseImage used in completed campaign ([46f7aa3](https://github.com/lusergit/edgehog/commit/46f7aa34f585aabf2a37f4baef10a8ac4a5ea33d)), closes [#598](https://github.com/lusergit/edgehog/issues/598)
* **backend:** manual OTA with base image from collection ([1af4b8d](https://github.com/lusergit/edgehog/commit/1af4b8d8b9f10ca480a2aacf6073e8c2f2297b1c))
* block actions until deployment is ready ([#988](https://github.com/lusergit/edgehog/issues/988)) ([ea12c0b](https://github.com/lusergit/edgehog/commit/ea12c0b03be3b6c2359dd76a3d51d25de71cc184))
* Collapsible headers in container form ([0ac3199](https://github.com/lusergit/edgehog/commit/0ac3199635ce23176a01f465cd7ca57aadfa29a0))
* **containers:** Add searchable selection in Deployment Campaigns ([0fc29d8](https://github.com/lusergit/edgehog/commit/0fc29d835e53dcb88bf3ae452c6d27fc53cfce3b))
* **containers:** Add searchable selection in Deployment Campaigns ([0c3b663](https://github.com/lusergit/edgehog/commit/0c3b6631ee42daabf6e716cce3f9eb86f2cd0739))
* **containers:** device mappings form input component ([5b4735f](https://github.com/lusergit/edgehog/commit/5b4735f8e41931c02cfc7eedbeb6c20955f70fe2))
* **containers:** device mappings form input component ([ec3cd57](https://github.com/lusergit/edgehog/commit/ec3cd57a425fd90f1af403d282a5643a04a1c890))
* Expose deployment campaigns in deployments ([#979](https://github.com/lusergit/edgehog/issues/979)) ([65217e4](https://github.com/lusergit/edgehog/commit/65217e425a03a5515b4b655c9780c37aefd697cd))
* **forms:** add field explanations to container form ([#976](https://github.com/lusergit/edgehog/issues/976)) ([c11b8c5](https://github.com/lusergit/edgehog/commit/c11b8c5afc869f55f10b8c95382c78ba6e77df80))
* **frontend:** add retry count column to campaign targets tables ([dfe0649](https://github.com/lusergit/edgehog/commit/dfe0649be89060cd67f44e31909892549644363e))
* **frontend:** add subscriptions ([ec7fe9c](https://github.com/lusergit/edgehog/commit/ec7fe9c4badcd90ba211071b6d6be513ced36f36))
* **frontend:** add subscriptions for campaigns ([6269990](https://github.com/lusergit/edgehog/commit/6269990e2318acf9484608e0cafff6bf6fe65462))
* **frontend:** allow deletion of BaseImage used in completed campaign ([b182943](https://github.com/lusergit/edgehog/commit/b182943608d7076303b8c7542035fe156779fa8a)), closes [#598](https://github.com/lusergit/edgehog/issues/598)
* **frontend:** manual OTA with base image from collection ([11f9a83](https://github.com/lusergit/edgehog/commit/11f9a83cd08f1e2d810813dea72ac41704717e94))
* GraphQL subscription for device updates in table ([#1118](https://github.com/lusergit/edgehog/issues/1118)) ([be6a629](https://github.com/lusergit/edgehog/commit/be6a6295f2767cf3ae766984aedbc29833a95a06))
* integrate Absinthe WebSocket ([50fd9fc](https://github.com/lusergit/edgehog/commit/50fd9fc3319932a8bc00ce84c12d1cb396beaacd))
* Make Hardware Type clearable in Create System Model ([becc958](https://github.com/lusergit/edgehog/commit/becc95896919b33f056622d8e36ee239d10f1914))
* paginate options in forms ([#1046](https://github.com/lusergit/edgehog/issues/1046)) ([4ce8aa8](https://github.com/lusergit/edgehog/commit/4ce8aa8b113d5703e91e07ebd17989a521a97584))
* prompt user to create a group before creating a channel ([983a295](https://github.com/lusergit/edgehog/commit/983a2958b8f6069abd20e75053ce20df2371a7e9))
* prompt user to create a group before creating a channel ([2d08f10](https://github.com/lusergit/edgehog/commit/2d08f103cef3f1eaa29f076d441b4713c4c51a83))
* server side pagination ([#888](https://github.com/lusergit/edgehog/issues/888)) ([946571b](https://github.com/lusergit/edgehog/commit/946571b19bc0c5ff7f3ace00c8e0d8d3b043d597))
* show `partNumber` and `serialNumber` in `Device` page if available ([#1123](https://github.com/lusergit/edgehog/issues/1123)) ([c2261bb](https://github.com/lusergit/edgehog/commit/c2261bb7397c4ca956013d245dc16a537e308267)), closes [#226](https://github.com/lusergit/edgehog/issues/226)
* UI for deployment events' additional information ([b03f50a](https://github.com/lusergit/edgehog/commit/b03f50aaf10b9cff00e5a782bfdbdec1c5e034ba))


### Bug Fixes

* add text reporters to coverage output for visibility ([e7c56f8](https://github.com/lusergit/edgehog/commit/e7c56f8c5bca9d5517b67041e3537a6bf2e8abb5))
* align retry icon position in Deployments table ([#1069](https://github.com/lusergit/edgehog/issues/1069)) ([fa048e4](https://github.com/lusergit/edgehog/commit/fa048e444b8bcbd522882ce2d1e4fad1868bcbee))
* auto-focus Image Reference field when adding new container ([0e150fa](https://github.com/lusergit/edgehog/commit/0e150fa8756ef10f59ded602d4311e0cfac40436))
* Clean up deleted device group from channel targetGroups ([73ed9a2](https://github.com/lusergit/edgehog/commit/73ed9a2e2f61c8ba682eb21fc2a2dae4d0082fb5))
* Clean up deleted device group from updateChannel targetGroups ([fb8f38d](https://github.com/lusergit/edgehog/commit/fb8f38daf791890cbe274e82bd2177cc50ab2557))
* Clean up deleted device group from updateChannel targetGroups ([37e7988](https://github.com/lusergit/edgehog/commit/37e7988701071a2b8150f74c47717b635e49e03a))
* Clear target release on version conflict ([#1066](https://github.com/lusergit/edgehog/issues/1066)) ([641cffd](https://github.com/lusergit/edgehog/commit/641cffdafd3662751408635d61666faa18bd6ba8))
* **containers:** Add validation for unique volume targets ([b1e65f7](https://github.com/lusergit/edgehog/commit/b1e65f73c0a9207d59bdb041fd6c3186640fe048))
* **containers:** Add validation for unique volume targets ([288246a](https://github.com/lusergit/edgehog/commit/288246adfef250b621352f3d39492e64b0fac338))
* **containers:** refresh application list after deletion ([0b41cf5](https://github.com/lusergit/edgehog/commit/0b41cf5b344cdd2e582438ccf6642637d5fbc5b2))
* **containers:** refresh application list after deletion ([f18f44e](https://github.com/lusergit/edgehog/commit/f18f44ee2a820e352a07c561b9ed74b8bf9ee6ca))
* Correct GraphQL field name in subscription updater ([#1134](https://github.com/lusergit/edgehog/issues/1134)) ([f5ac89b](https://github.com/lusergit/edgehog/commit/f5ac89b3da2dde8ef741f370c93a2a8bfbfe47b4))
* deployment state color mismatch when isReady is false ([#1012](https://github.com/lusergit/edgehog/issues/1012)) ([3ffa28a](https://github.com/lusergit/edgehog/commit/3ffa28a90906ced69556082501f4fbe752c83724))
* display release version instead of channel name in release link ([9716b04](https://github.com/lusergit/edgehog/commit/9716b04125a6a7b97b24393f38cb8e6185e2ceca))
* Eliminate unnecessary loading delays in campaign details ([b364661](https://github.com/lusergit/edgehog/commit/b36466172448d0e49b84410d42860fa1770f9747))
* Eliminate unnecessary loading delays in campaign details ([3afec8c](https://github.com/lusergit/edgehog/commit/3afec8cf286875cfdc5f1f522b497f39a8af66fa))
* Eliminate unnecessary loading delays in update campaign details ([883e5cb](https://github.com/lusergit/edgehog/commit/883e5cb770db3a4eff0e463249dd611792fb2aa7))
* Eliminate unnecessary loading delays in update campaign details ([5e0697c](https://github.com/lusergit/edgehog/commit/5e0697c8dcb1d0fea201ea83abfe56d652297983))
* **frontend:** fix Campaigns create subscription data ([898ad56](https://github.com/lusergit/edgehog/commit/898ad56e5c2bac7413e1fdf031b5c9c6243cad6a))
* Hide Applications tab when offline or unsupported ([004cbce](https://github.com/lusergit/edgehog/commit/004cbce7fc9b1764469c09ff022375ddaf7f0488))
* icon alignment in field help ([#1056](https://github.com/lusergit/edgehog/issues/1056)) ([d81d049](https://github.com/lusergit/edgehog/commit/d81d0498a561db5e388fe65afe973acd9964a204))
* null `env` in `Container`s ([#1000](https://github.com/lusergit/edgehog/issues/1000)) ([38bbb13](https://github.com/lusergit/edgehog/commit/38bbb13c6e63b35b3739a556441a65e9c8157440))
* Remove Dockerfile Warnings for Casing and ENV Format ([1c6b09e](https://github.com/lusergit/edgehog/commit/1c6b09ea4678318ef290d8b63779bb1c62c971b7))
* Remove Dockerfile Warnings for Casing and ENV Format ([112e369](https://github.com/lusergit/edgehog/commit/112e369eae9795898c32e65879c0fc6fcedc3ffc))
* Restrict collapse toggle to icon click only ([eeb59e4](https://github.com/lusergit/edgehog/commit/eeb59e48bd2d2b2948397dca333d4e5b614c9fed))
* Reused container data removal ([#1062](https://github.com/lusergit/edgehog/issues/1062)) ([7f82300](https://github.com/lusergit/edgehog/commit/7f82300ac04008920adaf4acd1d8beb815c587a6))
* Stabilize field help icon alignment across browsers ([bfda785](https://github.com/lusergit/edgehog/commit/bfda785fa4acc3559c655fdacd8986dc388f0165))
* stale validation error on create/edit ([#998](https://github.com/lusergit/edgehog/issues/998)) ([64d7375](https://github.com/lusergit/edgehog/commit/64d7375414b88d49e51e3238ebc3c4e1450e8ae9))
* trim JWT for websockets in frontend ([#1130](https://github.com/lusergit/edgehog/issues/1130)) ([a633e01](https://github.com/lusergit/edgehog/commit/a633e01d0cb41fd6f55adc609ada1298a50a4bda))
* unify device creation and update subscriptions ([c09e7de](https://github.com/lusergit/edgehog/commit/c09e7de8d5570cd15f158ade835e9a332c602597))

## [0.12.0](https://github.com/edgehog-device-manager/edgehog/compare/v0.11.0...v0.12.0) (2026-02-18)


### Features

* Add `Pause` and `Resume` functionality for campaigns ([#1204](https://github.com/edgehog-device-manager/edgehog/issues/1204)) ([35a9aab](https://github.com/edgehog-device-manager/edgehog/commit/35a9aab42a458358bf87a60e37453b26a7ac0228)), closes [#277](https://github.com/edgehog-device-manager/edgehog/issues/277)
* **backend:** allow deletion of BaseImage used in completed campaign ([46f7aa3](https://github.com/edgehog-device-manager/edgehog/commit/46f7aa34f585aabf2a37f4baef10a8ac4a5ea33d)), closes [#598](https://github.com/edgehog-device-manager/edgehog/issues/598)
* **frontend:** add retry count column to campaign targets tables ([dfe0649](https://github.com/edgehog-device-manager/edgehog/commit/dfe0649be89060cd67f44e31909892549644363e))
* **frontend:** add subscriptions ([ec7fe9c](https://github.com/edgehog-device-manager/edgehog/commit/ec7fe9c4badcd90ba211071b6d6be513ced36f36))
* **frontend:** add subscriptions for campaigns ([6269990](https://github.com/edgehog-device-manager/edgehog/commit/6269990e2318acf9484608e0cafff6bf6fe65462))
* **frontend:** allow deletion of BaseImage used in completed campaign ([b182943](https://github.com/edgehog-device-manager/edgehog/commit/b182943608d7076303b8c7542035fe156779fa8a)), closes [#598](https://github.com/edgehog-device-manager/edgehog/issues/598)


### Bug Fixes

* add text reporters to coverage output for visibility ([e7c56f8](https://github.com/edgehog-device-manager/edgehog/commit/e7c56f8c5bca9d5517b67041e3537a6bf2e8abb5))
* **frontend:** fix Campaigns create subscription data ([898ad56](https://github.com/edgehog-device-manager/edgehog/commit/898ad56e5c2bac7413e1fdf031b5c9c6243cad6a))
* Hide Applications tab when offline or unsupported ([004cbce](https://github.com/edgehog-device-manager/edgehog/commit/004cbce7fc9b1764469c09ff022375ddaf7f0488))

## [0.11.0](https://github.com/edgehog-device-manager/edgehog/compare/v0.10.0...v0.11.0) (2026-02-03)


### Features

* `chevronDown` and `chevronUp` icon ([6d5dc58](https://github.com/edgehog-device-manager/edgehog/commit/6d5dc582a37f3a1278f623d3baf3d2baf67996d3))
* add device group subscription ([#1198](https://github.com/edgehog-device-manager/edgehog/issues/1198)) ([adb91f4](https://github.com/edgehog-device-manager/edgehog/commit/adb91f4e5f7011cdf424b77371ebf4f8858f66d1))
* add GraphQL subscription for device creation ([1d5a0ba](https://github.com/edgehog-device-manager/edgehog/commit/1d5a0ba36a7a6c3940ae61215fc03614e6817db6))
* **backend:** manual OTA with base image from collection ([1af4b8d](https://github.com/edgehog-device-manager/edgehog/commit/1af4b8d8b9f10ca480a2aacf6073e8c2f2297b1c))
* Collapsible headers in container form ([0ac3199](https://github.com/edgehog-device-manager/edgehog/commit/0ac3199635ce23176a01f465cd7ca57aadfa29a0))
* **frontend:** manual OTA with base image from collection ([11f9a83](https://github.com/edgehog-device-manager/edgehog/commit/11f9a83cd08f1e2d810813dea72ac41704717e94))
* GraphQL subscription for device updates in table ([#1118](https://github.com/edgehog-device-manager/edgehog/issues/1118)) ([be6a629](https://github.com/edgehog-device-manager/edgehog/commit/be6a6295f2767cf3ae766984aedbc29833a95a06))
* integrate Absinthe WebSocket ([50fd9fc](https://github.com/edgehog-device-manager/edgehog/commit/50fd9fc3319932a8bc00ce84c12d1cb396beaacd))
* Make Hardware Type clearable in Create System Model ([becc958](https://github.com/edgehog-device-manager/edgehog/commit/becc95896919b33f056622d8e36ee239d10f1914))
* show `partNumber` and `serialNumber` in `Device` page if available ([#1123](https://github.com/edgehog-device-manager/edgehog/issues/1123)) ([c2261bb](https://github.com/edgehog-device-manager/edgehog/commit/c2261bb7397c4ca956013d245dc16a537e308267)), closes [#226](https://github.com/edgehog-device-manager/edgehog/issues/226)
* UI for deployment events' additional information ([b03f50a](https://github.com/edgehog-device-manager/edgehog/commit/b03f50aaf10b9cff00e5a782bfdbdec1c5e034ba))


### Bug Fixes

* Correct GraphQL field name in subscription updater ([#1134](https://github.com/edgehog-device-manager/edgehog/issues/1134)) ([f5ac89b](https://github.com/edgehog-device-manager/edgehog/commit/f5ac89b3da2dde8ef741f370c93a2a8bfbfe47b4))
* Restrict collapse toggle to icon click only ([eeb59e4](https://github.com/edgehog-device-manager/edgehog/commit/eeb59e48bd2d2b2948397dca333d4e5b614c9fed))
* Stabilize field help icon alignment across browsers ([bfda785](https://github.com/edgehog-device-manager/edgehog/commit/bfda785fa4acc3559c655fdacd8986dc388f0165))
* trim JWT for websockets in frontend ([#1130](https://github.com/edgehog-device-manager/edgehog/issues/1130)) ([a633e01](https://github.com/edgehog-device-manager/edgehog/commit/a633e01d0cb41fd6f55adc609ada1298a50a4bda))
* unify device creation and update subscriptions ([c09e7de](https://github.com/edgehog-device-manager/edgehog/commit/c09e7de8d5570cd15f158ade835e9a332c602597))

## [0.10.0] - 2025-12-09

### Fixed

- Migrations now account for the change in constraints in deployment states.
- Delete campaigns now correctly display the state of targets, without duplicate reports of a success.

## [0.10.0-alpha.9] - 2025-12-03

### Added

- Initial draft of the documentation for the container management system.

### Changed

- Astarte `1.3.0-rc.0` is now the first version allowed for device registration
  and deletion triggers.

### Fixed

- `422` answer when trying to delete a tenant. The API now correctly handles the
  `tenant_id`.

## [0.10.0-alpha.8] - 2025-10-28

### Added

- Support for stop campaigns: a deployment campaign can send a `stop` operation on a target release on all devices in a channel.
- Support for start campaigns: a deployment campaign can send a `start` operation on a target release on all devices in a channel.
- Support for upgrade campaigns: a deployment campaign can `update` a container to a newer version on all devices in a channel.
- Support for delete campaigns: a deployment campaign can send a `delete` message on a target release on all devices in a channel.
- Reconciliation logic: container information gets reconciled with astarte if some messages get lost. The polling system acts on time windows to avoid traffic spikes in astarte.
- Retry mechanism: users can manually retry to send necessary messages to a device to deploy a container.

### Changed

- The deployment state does no longer incorporate events, instead events are available in the `events` field of deployments. Users can access them in a _log_ fashion.
- Removed `last_message` field in deployment.
- With Astarte versions >= 1.3, devices are available in Edgehog upon registration, without waiting for their first connection.

### Fixed

- Type error on network and volume options prevented users from using advanced driver options both on volumes and networks.
- Update messages were sent each time a deployment with some ready actions was stopped. This prevented updated releases from actually being stopped.

## [0.10.0-alpha.7] - 2025-10-28

### Changed

- Added a default image for devices that don’t have an associated system model image, replacing the plain grey placeholder
- Containers now allow to specify binds.
- Frontend validation for port bindings support the full docker specification: [docker documentation](https://docs.docker.com/reference/compose-file/services/#ports).
- Adds garbage collection utilities for container resources

## [0.10.0-alpha.6] - 2025-10-16

### Added

- The backend now allows to define different images with the same reference but different image credentials associated.

### Changed

- CPU Period and CPU Quota get validated on the frontend.
- Updated the postgres version in dev, test still run on all versions.
- Added validation for unique volume targets
- Deployment readiness is now a single field
- Deployments now report in the UI the state of each single container. Showing whether the container is running, exited or encountered some error.
- Key-value structure for container environment variables is enforced on backend level.

### Fixed

- Reconciler wrongful map comparison.
- Properly update relay connections to avoid out-of sync errors.

## [0.10.0-alpha.5] - 2025-10-06

### Changed

- When no device group exist, on the Channel List page prompt the user to create at least one group before creating a Channel ([#972](https://github.com/edgehog-device-manager/edgehog/issues/972)).
- Improved how Network and Volumes options can be displayed and edited in the Applications section ([#963](https://github.com/edgehog-device-manager/edgehog/issues/963)).

### Fixed

- Remove application displayed in the application list after deleting it ([#967](https://github.com/edgehog-device-manager/edgehog/issues/967)).
- On the device page, propose only options compatible with the device when users want to upgrade an app's release ([#970](https://github.com/edgehog-device-manager/edgehog/issues/970)).
- Use uniform and readable labels for displaying Restart Policy values of containers ([#971](https://github.com/edgehog-device-manager/edgehog/issues/971)).
- Add logic to resume app campaigns when Edgehog starts up ([#969](https://github.com/edgehog-device-manager/edgehog/issues/969)).

## [0.10.0-alpha.4] - 2025-09-29

### Fixed

- Correctly use Docker's default `false` value for container's readonly root filesystem option.

## [0.10.0-alpha.3] - 2025-09-26

### Fixed

- Astarte reconciler not correctly comparing trigger delivery policies, thus continuously reinstalling them.

## [0.10.0-alpha.2] - 2025-09-26

### Changed

- Improved the web page to create new app releases, with UI adjustments to help users better understand and operate the page.

### Fixed

- Deletion of existing app deployments, not working due to incorrect handling of database constraints.

## [0.10.0-alpha.1] - 2025-09-25

### Fixed

- Failures in handling device events regarding container deployments.
- Incorrect `cGroupPermissions` option not delivered when deploying containers.

## [0.10.0-alpha.0] - 2025-09-24

### Added

- Managed OTA operations expose the update target that created them in graphql ([#356](https://github.com/edgehog-device-manager/edgehog/issues/356)).
- Expose the associated UpdateCampaign (if any) from an OTA Operation on the Software Updates tab ([#356](https://github.com/edgehog-device-manager/edgehog/issues/356)).
- Support for using Azure Storage as the persistence layer for asset uploads ([#233](https://github.com/edgehog-device-manager/edgehog/issues/233)).
- Ecto SSL configuration is exposed through `DATABASE_*` environment variables (see [.env](./.env))
- Adds support for trigger delivery policies in the tenant reconciler, allowing Edgehog to automatically provision and manage trigger delivery policies on Astarte realms that support them (v1.1.1+).
- Added Applications tab to Device page ([#662](https://github.com/edgehog-device-manager/edgehog/issues/662))
- Implemented a application management feature, enabling users to view and navigate through applications and their release details ([#704](https://github.com/edgehog-device-manager/edgehog/issues/704))
  - **Applications page**: Displays a list of all existing applications, with navigation to individual Application pages.
  - **Application page**: Shows the details of a selected application, including its name, description and a list of releases, with navigation to individual Release pages.
  - **Release page**: Provides details of a specific release, including a list of containers and configurations, such as image reference, image credentials (label, username), networks, and port bindings.
- Added `ApplicationCreate` page to enable users to create a new application with fields for application name and description.
- Added `ReleaseCreate` page to enable users to create a new release for an application with fields for release Version and a list of Containers.
- Add upgrade deployment functionality with version selection ([#703](https://github.com/edgehog-device-manager/edgehog/issues/703))
- **Volumes management feature**:
  - **Volumes page** – lists all existing volumes and allows navigation to individual volume pages.
  - **Volume page** – displays details of a selected volume, including its label, driver, and options.
  - **VolumeCreate page** – enables creating a new volume with fields for label, driver, and options.
- Added delete action for release in the releases table of an application
- Added delete action for application in the applications table
- Implemented networks management feature, enabling users to view and create networks.
  - **Networks page** – lists all existing networks and allows navigation to individual network pages.
  - **Network page** – displays details of a selected network, including its label, driver, internal, enableIpv6, and options.
  - **NetworkCreate page** – enables creating a new network with fields for label, driver, internal, enableIpv6, and options.
- Implemented deployments overview with **Deployments page** - lists all deployments and enables filtering by app, release, device.

### Changed

- BREAKING: GraphQL API that return unbounded lists now use Relay/keyset pagination. Edgehog's dashboard now relies on server-side pagination for queries and filtering, and uses tables with infinite scrolling instead of client-side paginated tables.

## [0.9.3] - 2025-05-22

### Fixed

- Base Image deletion in S3 storage
- Update Campaign executor crashing when handling events because of `device` relationship not loaded ([#828](https://github.com/edgehog-device-manager/edgehog/pull/828)).

## [0.9.2] - 2024-12-09

### Added

- Add pattern matching support to device selector DSL with new `~=` and `!~=` operators

### Changed

- Update the docker-compose configuration to allow both physical and virtual devices
  to connect to Edgehog, provided that the devices and the host are on the same LAN.

## [0.9.1] - 2024-10-28

### Fixed

- Allow receiving `trigger_name` key in trigger payload, which is sent by Astarte >= 1.2.0.

## [0.9.0] - 2024-10-25

### Fixed

- Correctly support automatic login attempts on the frontend regardless of existing auth sessions ([#596](https://github.com/edgehog-device-manager/edgehog/pull/596)).
- Fix file upload for creating base images that was failing due to a regression that left out the `version` parameter, needed for uploading the file ([#600](https://github.com/edgehog-device-manager/edgehog/pull/600)).

### Added

- Check whether `URL_HOST` is a valid host and not a url ([#595](https://github.com/edgehog-device-manager/edgehog/issues/595)).

## [0.9.0-rc.2] - 2024-09-11

### Fixed

- Correctly scope Base Image uploads to their Base Image Collection bucket.
- Show a better error when trying to delete a Base Image or Update Channel connected to an existing
  Update Campaign.

### Added

- Support redirection to a specific page after successful authentication

## [0.9.0-rc.1] - 2024-07-10

### Fixed

- Wrong input params used in GraphQL mutation when creating a base image, leading to a rejected operation ([#574](https://github.com/edgehog-device-manager/edgehog/pull/574)).
- Fix docker-compose local build.
- Fix OTA operation events not being handled, leading to a successful OTA operation while the device was still pending.

## [0.9.0-rc.0] - 2024-07-08

### Added

- Allow generating admin JWT using `gen-edgehog-jwt`.

### Changed

- Change logo and brand images with the latest brand revision.
- BREAKING: The Admin API is now JSON-API compliant, which implies a slightly different format,
  check out the newly added OpenAPI document.
- BREAKING: This release includes some breaking changes in the GraphQL API, make sure to check out
  the GraphQL schema if you were using the APIs directly. Note that we _could_ add more breaking
  changes before the final release.

## [0.8.0] - 2024-03-29

### Changed

- Configure cookie attribute based on protocol.
- Normalize triggers when comparing them for reconciliation to avoid useless reconciliations.

## [0.8.0-rc.1] - 2024-03-22

### Fixed

- Fix query limits on Astarte datastream interfaces, leading to parsing failures on some interfaces.

## [0.8.0-rc.0] - 2024-03-21

### Added

- Add support for an instance of [Edgehog Device Forwarder](https://github.com/edgehog-device-manager/edgehog_device_forwarder). When configured,
  forwarding functionalities are enabled for devices that support forwarding connections to their
  internal services, allowing features such as remote terminal sessions
  ([#447](https://github.com/edgehog-device-manager/edgehog/pull/447)).

## [0.7.1] - 2024-02-01

### Added

- Add Admin API to [create](https://github.com/edgehog-device-manager/edgehog/pull/400) and
  to [delete](https://github.com/edgehog-device-manager/edgehog/pull/416) tenants.
- Add a reconciler that takes care of installing Astarte resources (interfaces and triggers) for a
  tenant ([#403](https://github.com/edgehog-device-manager/edgehog/pull/403)).
- BREAKING: Add mandatory `URL_HOST` env variable. It must point to the host where the Edgehog
  backend is exposed.

### Fixed

- Fix seeds not working when used outside docker.
- Fix seeds's default values not working correctly.

## [0.7.0] - 2023-10-06

### Fixed

- Don't crash the OTA campaign if a misconfigured device doesn't send its base image version.
- Correctly return stats even for OTA campaigns with no targets.
- Handle empty string when translating legacy OTAResponse messages.
- Deduplicate tags in list of existing device tags.

## [0.7.0-alpha.1] - 2023-09-12

### Added

- Expose OTA Campaigns stats.

### Fixed

- Fix DevicesTable component for devices without SystemModel.

### Changed

- Enhance the OTA Campaigns frontend, using the exposed stats.

## [0.7.0-alpha.0] - 2023-07-28

### Added

- Add support for device tags ([#191](https://github.com/edgehog-device-manager/edgehog/pull/191), [#212](https://github.com/edgehog-device-manager/edgehog/pull/212)).
- Add support for device custom attributes
  ([#205](https://github.com/edgehog-device-manager/edgehog/pull/205)).
- Add `MAX_UPLOAD_SIZE_BYTES` env variable to define the maximum dimension for uploads (particularly
  relevant for OTA updates). Defaults to 4 GB.
- Allow creating and managing groups based on selectors.
- Add support for device's `network_interfaces` ([#231](https://github.com/edgehog-device-manager/edgehog/pull/231), [#232](https://github.com/edgehog-device-manager/edgehog/pull/232)).
- Add support for base image collections ([#229](https://github.com/edgehog-device-manager/edgehog/pull/229), [#230](https://github.com/edgehog-device-manager/edgehog/pull/230)).
- Add support for base images ([#240](https://github.com/edgehog-device-manager/edgehog/pull/240), [#244](https://github.com/edgehog-device-manager/edgehog/pull/244)).
- Add support for update channels
  ([#243](https://github.com/edgehog-device-manager/edgehog/pull/243), [#245](https://github.com/edgehog-device-manager/edgehog/pull/245)).
- Add support for
  [`io.edgehog.devicemanager.OTAEvent`](https://github.com/edgehog-device-manager/edgehog-astarte-interfaces/pull/58).
- Add support for
  [`io.edgehog.devicemanager.OTARequest`
  v1.0](https://github.com/edgehog-device-manager/edgehog-astarte-interfaces/pull/57).
- Add OTA Campaigns execution support.

### Changed

- Handle Device part numbers for nonexistent system models.
- BREAKING: The `Description` field in the `SystemModel` object is now a `String` instead of a
  `LocalizedText`.

### Deprecated

- Support for `io.edgehog.devicemanager.OTAResponse` is deprecated and will be removed in future
  releases. Switch to `io.edgehog.devicemanager.OTAEvent` instead.
- Support for `io.edgehog.devicemanager.OTARequest` with major version `0` is deprecated and will be
  removed in future releases. Switch to `io.edgehog.devicemanager.OTARequest` major version `1`
  instead.

## [0.5.2] - 2022-06-22

### Added

- Expose Prometheus metrics and a /health API endpoint.

### Changed

- Start using logfmt as logging format.

### Fixed

- Use the tenant's default locale when managing translated descriptions if the user's locale is not
  available.

## [0.5.1] - 2022-06-01

### Added

- Add `connected` field to wifi scan result and highlight the latest connected network
  ([#193](https://github.com/edgehog-device-manager/edgehog/pull/193)).

### Changed

- Change Geo IP provider from FreeGeoIP to IPBase
  ([#190](https://github.com/edgehog-device-manager/edgehog/pull/190)). This is a breaking change,
  make sure to update the `FREEGEOIP_API_KEY` env to `IPBASE_API_KEY`.

### Fixed

- Add a workaround to correctly parse Astarte datastreams even if AppEngine API shows them with a
  inconsistent format ([#194](https://github.com/edgehog-device-manager/edgehog/pull/194)).

## [0.5.0] - 2022-03-22

### Added

- Initial Edgehog release.
