---
slug: jeap-spring-boot-parent-41.18.0
title: jeap-spring-boot-parent - Release 41.18.0
authors: [jeap-team]
tags: [release]
---

New version [`41.18.0`](https://github.com/jeap-admin-ch/jeap-spring-boot-parent/blob/v41.18.0/CHANGELOG.md) of `jeap-spring-boot-parent` is available.

<!-- truncate -->

### Changed
- update jeap-messaging from 19.14.0 to 19.15.0
- Generate and upload Avro schemas with message contracts without executing message classes, avoiding registry access in the Message Contract Service. Schema generation and upload can be disabled independently.
- update jeap-server-sent-events from 13.14.0 to 13.15.0
- update jeap-reaction-observer from 11.14.0 to 11.15.0
- update jeap-messaging-outbox from 18.15.0 to 18.16.0
- update jeap-messaging-sequential-inbox from 22.10.1 to 22.11.0
- update jeap-spring-modulith-error-handling-starter from 1.20.0 to 1.21.0
- update jeap-audit from 11.14.0 to 11.15.0
- update jeap-spring-modulith-error-handling-starter from 1.21.0 to 1.21.1
- Architecture documentation: a diagram of how a failed Spring Modulith publication reaches an operator and comes
  back, showing the boundary between the application's own tables and the jEAP Error Handling Service's. The
  diagram is kept as a draw.io source next to the SVG exported from it, `docs/images/failed-publication-flow.drawio`
  and `.svg`; edit the source, export it over the SVG and commit both files. The build refuses a source that was
  committed without re-exporting its image.
- update jeap-audit from 11.15.0 to 11.16.0
- Support scheduled audit command delivery through `auditEventScheduled`.

