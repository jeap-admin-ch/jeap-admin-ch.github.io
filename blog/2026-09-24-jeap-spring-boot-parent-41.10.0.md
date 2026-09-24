---
slug: jeap-spring-boot-parent-41.10.0
title: jeap-spring-boot-parent - Release 41.10.0
authors: [jeap-team]
tags: [release]
---

New version [`41.10.0`](https://github.com/jeap-admin-ch/jeap-spring-boot-parent/blob/v41.10.0/CHANGELOG.md) of `jeap-spring-boot-parent` is available.

<!-- truncate -->

### Changed
- update jeap-spring-boot-starters from 25.9.0 to 25.10.0
- Add configurable transaction retries for AWS JDBC Wrapper `FailoverSuccessSQLException` errors with SQL state
  `08S02`. Applications can opt in individual methods with `@RetryOnAwsJdbcFailover` or enable retries globally;
  every retryable top-level invocation gets a new transaction per attempt, existing `REQUIRED` transactions retain
  their atomicity, and unknown transaction outcomes are not retried.
- Retry failover errors only after observed rollback or transaction-begin failure; exclude committed attempts
  and uncertain completion outcomes, preserving checked-exception and `noRollbackFor` semantics.
- Preserve the original database failure when failover retry backoff is interrupted, attaching the interruption
  as a suppressed exception and retaining the thread's interrupt flag.
- Use the transaction context stack instead of a redundant nesting-depth counter.
- update jeap-open-api-publisher from 8.9.0 to 8.10.0
- update jeap-spring-boot-security-client-starter from 25.9.0 to 25.10.0
- update jeap-opensearch-searchitem-api from 3.10.0 to 3.11.0
- update jeap-starter from 25.9.0 to 25.10.0
- update jeap-opensearch-client-starter from 3.10.0 to 3.11.0
- update jeap-crypto from 11.9.0 to 11.10.0
- update jeap-spring-boot-vault-starter from 25.9.0 to 25.10.0
- update jeap-messaging from 19.7.0 to 19.8.0
- update jeap-reaction-observer from 11.7.0 to 11.8.0
- update jeap-server-sent-events from 13.7.0 to 13.8.0
- update jeap-messaging-outbox from 18.8.0 to 18.9.0
- update jeap-messaging-sequential-inbox from 22.2.0 to 22.3.0
- update jeap-spring-boot-security-starter from 25.9.0 to 25.10.0
- update jeap-spring-modulith-error-handling-starter from 1.13.0 to 1.14.0

