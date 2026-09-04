---
slug: jeap-spring-boot-parent-40.9.2
title: jeap-spring-boot-parent - Release 40.9.2
authors: [jeap-team]
tags: [release]
---

New version [`40.9.2`](https://github.com/jeap-admin-ch/jeap-spring-boot-parent/blob/v40.9.2/CHANGELOG.md) of `jeap-spring-boot-parent` is available.

<!-- truncate -->

### Changed
- update jeap-spring-modulith-error-handling-starter from 1.2.0 to 1.2.1
- Replace the mocked tests of the starter with integration tests that run a real Spring Modulith application,
  with asynchronous and synchronous persistent listeners, PostgreSQL created from the reference DDL, the transactional
  outbox, and Kafka.
- Support asynchronous `@ApplicationModuleListener` and synchronous `@TransactionalEventListener(AFTER_COMMIT)`
  publications, and document that `max-completion-attempts` includes the first invocation of the listener.
- Make the initial delay of retry and reconciliation jobs configurable.
- Announce a new release to the jEAP parent dependency update job, so the managed version of this starter is
  updated automatically.

