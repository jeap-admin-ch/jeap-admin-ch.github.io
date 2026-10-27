---
slug: jeap-spring-boot-parent-41.26.0
title: jeap-spring-boot-parent - Release 41.26.0
authors: [jeap-team]
tags: [release]
---

New version [`41.26.0`](https://github.com/jeap-admin-ch/jeap-spring-boot-parent/blob/v41.26.0/CHANGELOG.md) of `jeap-spring-boot-parent` is available.

<!-- truncate -->

### Changed
- update jeap-messaging from 19.22.0 to 19.23.0
- Classify a database failover with the AWS Advanced JDBC Wrapper (`SQLException` with SQLState `08S02`) as
  `TEMPORARY`, also when it is wrapped, e.g. in a `DataAccessResourceFailureException`.
- update jeap-server-sent-events from 13.22.0 to 13.23.0
- update jeap-reaction-observer from 11.22.0 to 11.23.0
- update jeap-messaging-outbox from 18.23.0 to 18.24.0
- update jeap-messaging-sequential-inbox from 22.18.0 to 22.19.0
- update jeap-spring-modulith-error-handling-starter from 1.28.0 to 1.29.0
- update jeap-audit from 11.23.0 to 11.24.0

