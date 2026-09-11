---
slug: jeap-spring-boot-parent-41.0.0
title: jeap-spring-boot-parent - Release 41.0.0
authors: [jeap-team]
tags: [release]
---

New version [`41.0.0`](https://github.com/jeap-admin-ch/jeap-spring-boot-parent/blob/v41.0.0/CHANGELOG.md) of `jeap-spring-boot-parent` is available.

<!-- truncate -->

### Changed
- update jeap-spring-boot-starters from 24.33.0 to 25.0.0
- Default the AWS Advanced JDBC Wrapper dialect to `aurora-pg`, avoiding database-dialect auto-detection for Aurora
  PostgreSQL. Applications using standard RDS PostgreSQL must override
  `jeap.datasource.aws.wrapper.target-data-source-properties.wrapperDialect=rds-pg`.
- update jeap-open-api-publisher from 7.32.0 to 8.0.0
- update jeap-spring-boot-security-client-starter from 24.33.0 to 25.0.0
- update jeap-opensearch-searchitem-api from 2.31.0 to 3.0.0
- update jeap-starter from 24.33.0 to 25.0.0
- update jeap-opensearch-client-starter from 2.32.0 to 3.0.0
- update jeap-crypto from 10.31.0 to 11.0.0
- update jeap-spring-boot-vault-starter from 24.33.0 to 25.0.0
- update jeap-messaging from 18.14.0 to 19.0.0
- update jeap-messaging-outbox from 17.31.0 to 18.0.0
- update jeap-reaction-observer from 10.31.0 to 11.0.0
- update jeap-messaging-sequential-inbox from 20.30.0 to 21.0.0
- update jeap-spring-boot-security-starter from 24.33.0 to 25.0.0
- update jeap-audit from 10.28.0 to 11.0.0
- update jeap-server-sent-events from 12.30.0 to 13.0.0

