---
slug: jeap-spring-boot-parent-41.33.0
title: jeap-spring-boot-parent - Release 41.33.0
authors: [jeap-team]
tags: [release]
---

New version [`41.33.0`](https://github.com/jeap-admin-ch/jeap-spring-boot-parent/blob/v41.33.0/CHANGELOG.md) of `jeap-spring-boot-parent` is available.

<!-- truncate -->

### Changed
- update jeap-messaging from 19.29.0 to 19.30.0
- Message type registry verifier compares existing schema files by the schema they define: comments,
  documentation and formatting may change, schema changes are still rejected
- Unused-import check of the message type registry verifier no longer depends on comments or formatting
- Message type registry verifier reports changed common files and changed message type schemas in one run
- Lexical errors in Avro IDL files (e.g. an unterminated comment or an invalid unicode escape such as a Windows path
  in a comment) are reported as parse errors instead of aborting the build
- update jeap-reaction-observer from 11.29.0 to 11.30.0
- update jeap-server-sent-events from 13.29.0 to 13.30.0
- update jeap-messaging-sequential-inbox from 22.25.0 to 22.26.0
- update jeap-messaging-outbox from 18.30.0 to 18.31.0
- update jeap-spring-modulith-error-handling-starter from 1.35.0 to 1.36.0
- update jeap-audit from 11.30.0 to 11.31.0

