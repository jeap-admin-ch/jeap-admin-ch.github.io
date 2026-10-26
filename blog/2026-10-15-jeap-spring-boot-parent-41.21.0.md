---
slug: jeap-spring-boot-parent-41.21.0
title: jeap-spring-boot-parent - Release 41.21.0
authors: [jeap-team]
tags: [release]
---

New version [`41.21.0`](https://github.com/jeap-admin-ch/jeap-spring-boot-parent/blob/v41.21.0/CHANGELOG.md) of `jeap-spring-boot-parent` is available.

<!-- truncate -->

### Changed
- update jeap-spring-boot-starters from 25.17.0 to 25.18.0
- Add the platform-independent `@RetryOnDatabaseFailover` annotation. Retryable failures remain
  limited to the supported AWS JDBC failover case.
- Deprecate `@RetryOnAwsJdbcFailover` in favor of `@RetryOnDatabaseFailover`; retain it as a
  compatibility alias with the same retry settings.
- update jeap-open-api-publisher from 8.17.0 to 8.18.0
- update jeap-spring-boot-security-client-starter from 25.17.0 to 25.18.0
- update jeap-opensearch-searchitem-api from 3.18.0 to 3.19.0
- update jeap-starter from 25.17.0 to 25.18.0
- update jeap-opensearch-client-starter from 3.18.0 to 3.19.0
- update jeap-crypto from 11.17.0 to 11.18.0
- update jeap-spring-boot-vault-starter from 25.17.0 to 25.18.0
- update jeap-messaging from 19.17.1 to 19.18.0
- update jeap-server-sent-events from 13.17.1 to 13.18.0
- update jeap-messaging-outbox from 18.18.1 to 18.19.0
- update jeap-reaction-observer from 11.17.1 to 11.18.0
- update jeap-messaging-sequential-inbox from 22.13.1 to 22.14.0
- update jeap-spring-boot-security-starter from 25.17.0 to 25.18.0
- update jeap-audit from 11.18.1 to 11.19.0
- update jeap-spring-modulith-error-handling-starter from 1.23.1 to 1.24.0

