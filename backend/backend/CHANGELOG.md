# Changelog

## [0.11.0](https://github.com/lusergit/edgehog/compare/backend-v0.10.0...backend-v0.11.0) (2026-01-22)


### ⚠ BREAKING CHANGES

* events are treated as events ([#953](https://github.com/lusergit/edgehog/issues/953))
* enforce key-value structure for `Container.env`
* aggregate readiness
* This change is only breaking if you have already applied the original migration. If you haven't applied it yet, you should not experience any problems. If you have already applied the original migration, you will need to manually reconcile your database state before applying this updated version.

### Features

* add `delete` operation support to deployment campaigns ([#1031](https://github.com/lusergit/edgehog/issues/1031)) ([4d535d8](https://github.com/lusergit/edgehog/commit/4d535d892d14278e5b9d5bef6a25ee54275638da))
* add Ash GraphQL subscriptions ([#1028](https://github.com/lusergit/edgehog/issues/1028)) ([faefc93](https://github.com/lusergit/edgehog/commit/faefc9380e1c5d4416618260c6100fecd481622a))
* add azure support ([ed8f2f7](https://github.com/lusergit/edgehog/commit/ed8f2f75dcbdc53f01633d70396ac929ff4d4b0e))
* add calculation to expose Base Image name ([d3affa5](https://github.com/lusergit/edgehog/commit/d3affa57af400440a26bccc6c29b3fb9c3534b23))
* Add container binds ([#1008](https://github.com/lusergit/edgehog/issues/1008)) ([5e8d5e1](https://github.com/lusergit/edgehog/commit/5e8d5e1bde6c2c11ed642a305318793df9209b92))
* add deployment details ([#1060](https://github.com/lusergit/edgehog/issues/1060)) ([51b9503](https://github.com/lusergit/edgehog/commit/51b9503eacb60d33eb874537f71839033e0d6de9))
* Add filtering for deployment targets with deployed applications ([#1002](https://github.com/lusergit/edgehog/issues/1002)) ([c847e77](https://github.com/lusergit/edgehog/commit/c847e77ecad9c35d5618b91687635682d7805475))
* Add operation_type and target_release to deployment campaigns ([#999](https://github.com/lusergit/edgehog/issues/999)) ([8d8b34e](https://github.com/lusergit/edgehog/commit/8d8b34e2a74937e7ed1ac97fefd6dfc7f857921f))
* add start operation support to deployment campaigns ([#1017](https://github.com/lusergit/edgehog/issues/1017)) ([1fe5bd1](https://github.com/lusergit/edgehog/commit/1fe5bd1734109a1e5a49e8a48706ba9a762cf911))
* add stop operation support to deployment campaigns ([#1027](https://github.com/lusergit/edgehog/issues/1027)) ([13a639a](https://github.com/lusergit/edgehog/commit/13a639acbc7c6bbea1e60015f96f363790c07e6e))
* Add support for regex and glob pattern matching in device selector DSL ([#835](https://github.com/lusergit/edgehog/issues/835)) ([479eb81](https://github.com/lusergit/edgehog/commit/479eb8100af62d72ffc21825f2cf743a27ac376a))
* Add trigger delivery policies support to tenant reconciler ([#838](https://github.com/lusergit/edgehog/issues/838)) ([8892e0f](https://github.com/lusergit/edgehog/commit/8892e0f1bd60b123cd933af39436f86f5e148785))
* add upgrade operation support to deployment campaigns ([#1029](https://github.com/lusergit/edgehog/issues/1029)) ([2eb965e](https://github.com/lusergit/edgehog/commit/2eb965e354b67b1659c24dfcf296208f64f16ed6))
* add validation for deployment campaign operation type requirements ([#1004](https://github.com/lusergit/edgehog/issues/1004)) ([396d995](https://github.com/lusergit/edgehog/commit/396d9953347072117965d8eac07a87851e815cca))
* Additional information on deployment events ([ba27473](https://github.com/lusergit/edgehog/commit/ba2747342f3b048a695f81deab856ce943aa39ab))
* allow administrators to delete tenants ([#1037](https://github.com/lusergit/edgehog/issues/1037)) ([64300c3](https://github.com/lusergit/edgehog/commit/64300c354e38d0c0c4661a778b3fcbcbc36929cb))
* allow users to re-send deployment messages ([#1041](https://github.com/lusergit/edgehog/issues/1041)) ([64a5dd9](https://github.com/lusergit/edgehog/commit/64a5dd939dfef35dca69ba8e91489e295a3566ee))
* application management ([#934](https://github.com/lusergit/edgehog/issues/934)) ([c1f8421](https://github.com/lusergit/edgehog/commit/c1f84219e056da81ee82f0171cc0ffdb0191f6c1))
* azure support ([6d3e198](https://github.com/lusergit/edgehog/commit/6d3e19821df639bb05adcf2c582f31d372b015ed))
* block actions until deployment is ready ([#988](https://github.com/lusergit/edgehog/issues/988)) ([ea12c0b](https://github.com/lusergit/edgehog/commit/ea12c0b03be3b6c2359dd76a3d51d25de71cc184))
* create device upon registration in astarte ([#1007](https://github.com/lusergit/edgehog/issues/1007)) ([05e8e16](https://github.com/lusergit/edgehog/commit/05e8e16d3042a1c878d04ef8166d6c7cb25df688))
* Expose deployment campaigns in deployments ([#979](https://github.com/lusergit/edgehog/issues/979)) ([65217e4](https://github.com/lusergit/edgehog/commit/65217e425a03a5515b4b655c9780c37aefd697cd))
* expose is_ready field of deployment via GraphQL ([4b5064c](https://github.com/lusergit/edgehog/commit/4b5064c7d05e5ba76795b2a66884bef5292fa8a0))
* expose underlying deployments ([73f21a6](https://github.com/lusergit/edgehog/commit/73f21a69f8c93c0f9217ebf050a84bbbdf6b059d))
* expose underlying resources to the user ([a50e4fa](https://github.com/lusergit/edgehog/commit/a50e4fa39dea68afe9e604ec5688a6ce005d87c8))
* filter deployment targets by operation type ([#1015](https://github.com/lusergit/edgehog/issues/1015)) ([11541e2](https://github.com/lusergit/edgehog/commit/11541e2c19160242180a557c0fe35fd74af05d66))
* GraphQL subscription for device updates in table ([#1118](https://github.com/lusergit/edgehog/issues/1118)) ([be6a629](https://github.com/lusergit/edgehog/commit/be6a6295f2767cf3ae766984aedbc29833a95a06))
* implement GraphQL subscriptions for device events ([32badc9](https://github.com/lusergit/edgehog/commit/32badc94a5705f3003ce66c1837430863a0217e3))
* implement retry logic for all deployment campaign operation types ([#1032](https://github.com/lusergit/edgehog/issues/1032)) ([a1c6a81](https://github.com/lusergit/edgehog/commit/a1c6a81de28019c9edadd90a70db5865b336856c))
* log outcome for successful or failed OTA operations ([#943](https://github.com/lusergit/edgehog/issues/943)) ([#944](https://github.com/lusergit/edgehog/issues/944)) ([fb0a7ba](https://github.com/lusergit/edgehog/commit/fb0a7ba3410806f1a578a78c91cd9147353b127d))
* **ota:** exposing optional update target of OTA ([2d4403e](https://github.com/lusergit/edgehog/commit/2d4403eab9e9ff3daf7e9b809a8791deb1bd21ca))
* **ota:** exposing optional update target of OTA ([8acace2](https://github.com/lusergit/edgehog/commit/8acace251d36bc6ba1c8f69ae7772739e253a0cf)), closes [#356](https://github.com/lusergit/edgehog/issues/356)
* Prevent deployment actions during conflicting campaigns ([#1058](https://github.com/lusergit/edgehog/issues/1058)) ([71ccb38](https://github.com/lusergit/edgehog/commit/71ccb38c4e98ee7b3f03228c5d822063d1ba54bc))
* **reconciler:** implement partial map comparison ([#980](https://github.com/lusergit/edgehog/issues/980)) ([d43824f](https://github.com/lusergit/edgehog/commit/d43824ff0a2f145808375cda4d32f9432c2707b7))
* remove device upon deletion finished in astarte ([6879933](https://github.com/lusergit/edgehog/commit/687993393d51bdc15cd743da8041a8bd0187945b))
* server side pagination ([#888](https://github.com/lusergit/edgehog/issues/888)) ([946571b](https://github.com/lusergit/edgehog/commit/946571b19bc0c5ff7f3ace00c8e0d8d3b043d597))
* show `partNumber` and `serialNumber` in `Device` page if available ([#1123](https://github.com/lusergit/edgehog/issues/1123)) ([c2261bb](https://github.com/lusergit/edgehog/commit/c2261bb7397c4ca956013d245dc16a537e308267)), closes [#226](https://github.com/lusergit/edgehog/issues/226)


### Bug Fixes

* add image_credentials_id to image identity ([#996](https://github.com/lusergit/edgehog/issues/996)) ([de1b8dc](https://github.com/lusergit/edgehog/commit/de1b8dcb9c85eb739e09314d3ecea07893e75576))
* avoid 422 in tenant deletion ([#1103](https://github.com/lusergit/edgehog/issues/1103)) ([de8c0d9](https://github.com/lusergit/edgehog/commit/de8c0d9a6f5a61c19ec222463046643b3154b9dc))
* avoid re-sending update messages ([#1081](https://github.com/lusergit/edgehog/issues/1081)) ([a718c95](https://github.com/lusergit/edgehog/commit/a718c95dc56ed291c6516e08245477bacc8b8637))
* **bucket_storage:** image deletion ([5517c6e](https://github.com/lusergit/edgehog/commit/5517c6ebd51b6a844bf13cf56ad54f9caddbec7c))
* **bucket_storage:** image deletion ([178a825](https://github.com/lusergit/edgehog/commit/178a825f94ef3323a6e601faf29eeec76de0bbaa))
* **config:** Azure and edgehog config clash ([fa032dc](https://github.com/lusergit/edgehog/commit/fa032dc4fca80063f872bf759d17af40df6f2b1d))
* **config:** Azure and edgehog config clash ([9c42aa6](https://github.com/lusergit/edgehog/commit/9c42aa6acf39c68026824be83d48b24647b31db3))
* **containers:** Add validation for unique volume targets ([b1e65f7](https://github.com/lusergit/edgehog/commit/b1e65f73c0a9207d59bdb041fd6c3186640fe048))
* **containers:** Add validation for unique volume targets ([288246a](https://github.com/lusergit/edgehog/commit/288246adfef250b621352f3d39492e64b0fac338))
* **containers:** remove usage of non-existing status_code deployment key ([#946](https://github.com/lusergit/edgehog/issues/946)) ([8988cee](https://github.com/lusergit/edgehog/commit/8988ceebe6c51201ad6ca4ad96355574a1380d41))
* correctly deploy resources only if not already deployed ([a6e4b78](https://github.com/lusergit/edgehog/commit/a6e4b78573ad95d6f43e97824b2178450c094dc7))
* correctly relate image and container deployments ([b21ee6e](https://github.com/lusergit/edgehog/commit/b21ee6e3ae2dd3ac10d7b025adcb2cb5428fd23e))
* device registration triggers are available from `1.3.0-rc.0` ([#1096](https://github.com/lusergit/edgehog/issues/1096)) ([dea4d3c](https://github.com/lusergit/edgehog/commit/dea4d3cde31c1988d36f8029c8d9e0ed0b0b87cb))
* do not crash on available networks ([ee4111d](https://github.com/lusergit/edgehog/commit/ee4111defbea75bc4bb0bc40fce17d2da79766b0))
* do not crash on available networks ([41fa223](https://github.com/lusergit/edgehog/commit/41fa2233de37199300143b42b53920b1e61d02d8))
* double free of campaign slots ([664788b](https://github.com/lusergit/edgehog/commit/664788baed26db6ded426f7dbb06b6d6f88e753e))
* double free of slots ([4884ad8](https://github.com/lusergit/edgehog/commit/4884ad8e4fde1ee807d52dea3ec583d772e52c9c))
* ensure migrations can be successfully rolled back ([#949](https://github.com/lusergit/edgehog/issues/949)) ([2981b1c](https://github.com/lusergit/edgehog/commit/2981b1ccba3d3e674af1f1038625b1ecdf666270))
* ignore prefetch_count in comparison of delivery policies ([#961](https://github.com/lusergit/edgehog/issues/961)) ([f78f597](https://github.com/lusergit/edgehog/commit/f78f597e24688b306759981d15b6314be8f4f340))
* include tenant in socket options ([d3c8921](https://github.com/lusergit/edgehog/commit/d3c89212ca7c4fb25cab293985da144eac3f9188))
* Migrate old deployment states ([#1113](https://github.com/lusergit/edgehog/issues/1113)) ([c7389e4](https://github.com/lusergit/edgehog/commit/c7389e416987a0dcb67ad9a9396600b4cd60f330)), closes [#1086](https://github.com/lusergit/edgehog/issues/1086)
* null `env` in `Container`s ([#1000](https://github.com/lusergit/edgehog/issues/1000)) ([38bbb13](https://github.com/lusergit/edgehog/commit/38bbb13c6e63b35b3739a556441a65e9c8157440))
* only reconcile when really needed ([#1072](https://github.com/lusergit/edgehog/issues/1072)) ([49cca31](https://github.com/lusergit/edgehog/commit/49cca31b81e4c2ccc5de34db258b58d2535f358f))
* OTA operation success event not being handled ([f7b1ac6](https://github.com/lusergit/edgehog/commit/f7b1ac68059852be8849940b2f0635d3b8f0a8f6))
* Preserve existing data when migrating update_channels to channels ([6169fc0](https://github.com/lusergit/edgehog/commit/6169fc0eb2953818bf6d956dbaf30dd2fb135c85))
* Prevent duplicate success in campaigns ([#1110](https://github.com/lusergit/edgehog/issues/1110)) ([c39b387](https://github.com/lusergit/edgehog/commit/c39b387667dd0cedeb2871938e7faf666fa7937d))
* reconcile backend snapshots ([#993](https://github.com/lusergit/edgehog/issues/993)) ([2fd8d14](https://github.com/lusergit/edgehog/commit/2fd8d149e19fba297692044d1fdcabe63536eee2))
* Remove Dockerfile Warnings for Casing and ENV Format ([1c6b09e](https://github.com/lusergit/edgehog/commit/1c6b09ea4678318ef290d8b63779bb1c62c971b7))
* Remove Dockerfile Warnings for Casing and ENV Format ([112e369](https://github.com/lusergit/edgehog/commit/112e369eae9795898c32e65879c0fc6fcedc3ffc))
* revert reconciliation condition ([#1079](https://github.com/lusergit/edgehog/issues/1079)) ([cbf9a0f](https://github.com/lusergit/edgehog/commit/cbf9a0f5297e6edf6e9bd15da605ddbc235bdcf4))
* unify device creation and update subscriptions ([c09e7de](https://github.com/lusergit/edgehog/commit/c09e7de8d5570cd15f158ade835e9a332c602597))
* update a deployment state to `:sent` only when necessary ([6e4371a](https://github.com/lusergit/edgehog/commit/6e4371ad59fc5b4be48ebe250b3eaed12b151c74))
* updating is not deleting ([ed33f33](https://github.com/lusergit/edgehog/commit/ed33f331583d6fcae926fb545913056f4bcddec5))
* updating is not deleting ([ad209c7](https://github.com/lusergit/edgehog/commit/ad209c7a91a2b037b293c487f982bff07003816b))
* use correct default for `read_only_rootfs` ([24a7c72](https://github.com/lusergit/edgehog/commit/24a7c7208d0f99c5e135c143c74727c2d55c994e))
* use correct default for `read_only_rootfs` ([2b08567](https://github.com/lusergit/edgehog/commit/2b0856792e0745df9eda636026646a63905f5fd5))


### Miscellaneous Chores

* aggregate readiness ([b2ed432](https://github.com/lusergit/edgehog/commit/b2ed432d5e39a973fc99013ace97f3dae376381c))


### Code Refactoring

* enforce key-value structure for `Container.env` ([510217b](https://github.com/lusergit/edgehog/commit/510217b1ab0c7a77040788931f7dffbf1fd90bb5))
* events are treated as events ([#953](https://github.com/lusergit/edgehog/issues/953)) ([7753a77](https://github.com/lusergit/edgehog/commit/7753a773a1da97c22f161c379b76cf784c1d2d79))
