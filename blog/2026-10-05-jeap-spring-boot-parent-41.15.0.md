---
slug: jeap-spring-boot-parent-41.15.0
title: jeap-spring-boot-parent - Release 41.15.0
authors: [jeap-team]
tags: [release]
---

New version [`41.15.0`](https://github.com/jeap-admin-ch/jeap-spring-boot-parent/blob/v41.15.0/CHANGELOG.md) of `jeap-spring-boot-parent` is available.

<!-- truncate -->

### Changed
- update jeap-messaging-sequential-inbox from 22.7.0 to 22.8.0
- Support for consuming the same message type from several Kafka topics: declare `topics` instead of `topic`
  in the sequence declaration to let the sequential inbox start one consumer per topic. This makes it possible
  to consume from the old and the new topic at the same time during a topic migration.

