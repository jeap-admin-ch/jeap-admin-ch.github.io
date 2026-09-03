---
slug: jeap-spring-boot-parent-40.9.0
title: jeap-spring-boot-parent - Release 40.9.0
authors: [jeap-team]
tags: [release]
---

New version [`40.9.0`](https://github.com/jeap-admin-ch/jeap-spring-boot-parent/blob/v40.9.0/CHANGELOG.md) of `jeap-spring-boot-parent` is available.

<!-- truncate -->

### Changed
- update jeap-spring-boot-starters from 24.27.0 to 24.28.0
- Error responses from paths handled by `jeap-spring-boot-web-config-starter` now use
  `Cache-Control: no-store` instead of inheriting long-lived caching based on the request suffix.
  Cacheable responses now also emit standards-compliant HTTP dates in the `Expires` header.
- Resolve the built-in introspection conditions' fallback with `BindResult.orElseGet` instead of `orElse` so that the
  unboxed result is non-null by contract, addressing a SonarQube null-pointer finding. No behavior change.
- update jeap-open-api-publisher from 7.26.0 to 7.27.0
- update jeap-spring-boot-security-client-starter from 24.27.0 to 24.28.0
- update jeap-opensearch-searchitem-api from 2.25.0 to 2.26.0
- update jeap-starter from 24.27.0 to 24.28.0
- update jeap-opensearch-client-starter from 2.26.0 to 2.27.0
- update jeap-crypto from 10.25.0 to 10.26.0
- update jeap-spring-boot-vault-starter from 24.27.0 to 24.28.0
- update jeap-messaging from 18.8.0 to 18.9.0
- update jeap-messaging-outbox from 17.25.0 to 17.26.0
- update jeap-server-sent-events from 12.25.0 to 12.26.0
- update jeap-reaction-observer from 10.25.0 to 10.26.0
- update jeap-messaging-sequential-inbox from 20.25.0 to 20.26.0
- update jeap-spring-boot-security-starter from 24.27.0 to 24.28.0
- update jeap-audit from 10.23.0 to 10.24.0

