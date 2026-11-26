---
slug: jeap-spring-boot-parent-41.44.0
title: jeap-spring-boot-parent - Release 41.44.0
authors: [jeap-team]
tags: [release]
---

New version [`41.44.0`](https://github.com/jeap-admin-ch/jeap-spring-boot-parent/blob/v41.44.0/CHANGELOG.md) of `jeap-spring-boot-parent` is available.

<!-- truncate -->


### Changed
- **Spring Boot 4.2.0**: update parent from 11.17.0 to 12.0.0 (Spring Framework 7.1, Spring Security 7.2,
  Spring Cloud 2026.0.0, Spring AI 2.1.0)
- Update all jEAP libraries to their releases built on Spring Boot 4.2.0
- Application starter: the forwarded header default is now `server.request.header.forwarded.strategy=web-server`
  (replacing the deprecated `server.forward-headers-strategy`), applied only if the application sets neither
- Reaction observer: periodic reidentification of reactions (`jeap.reaction.observer.reidentification-period`),
  new metrics for identified and dropped executions, `QUERY` requests are observed as triggers

