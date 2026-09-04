---
slug: jeap-spring-boot-parent-40.9.1
title: jeap-spring-boot-parent - Release 40.9.1
authors: [jeap-team]
tags: [release]
---

New version [`40.9.1`](https://github.com/jeap-admin-ch/jeap-spring-boot-parent/blob/v40.9.1/CHANGELOG.md) of `jeap-spring-boot-parent` is available.

<!-- truncate -->

### Changed
- update jeap-server-sent-events from 12.26.0 to 12.26.1
- Consume SSE notification commands from all Kafka partitions, including partitions added at runtime, without creating
  consumer groups or committing offsets.
- update jeap-server-sent-events from 12.26.1 to 12.26.2
- Improve null safety and concurrency handling in the groupless SSE Kafka consumers.

