---
slug: jeap-spring-boot-parent-40.10.1
title: jeap-spring-boot-parent - Release 40.10.1
authors: [jeap-team]
tags: [release]
---

New version [`40.10.1`](https://github.com/jeap-admin-ch/jeap-spring-boot-parent/blob/v40.10.1/CHANGELOG.md) of `jeap-spring-boot-parent` is available.

<!-- truncate -->

### Changed
- update jeap-messaging from 18.10.0 to 18.10.1
- Exempt the framework-owned `ModulithPublicationProcessingFailedEvent` from producer contract validation.
- Clarify that source microservices still require retry/discard consumer contracts, checked by the enabled starter
  at startup.
- update jeap-server-sent-events from 12.27.0 to 12.27.1
- update jeap-messaging-outbox from 17.27.0 to 17.27.1
- update jeap-reaction-observer from 10.27.0 to 10.27.1
- update jeap-messaging-sequential-inbox from 20.27.0 to 20.27.1
- update jeap-audit from 10.25.0 to 10.25.1
- update jeap-spring-modulith-error-handling-starter from 1.3.0 to 1.3.1
- Require explicit retry/discard consumer contracts and validate their configured topics at application startup.
- Use the Messaging producer exemption for framework-owned failure events, verified through the real transactional
  outbox without a failure-event producer contract.

