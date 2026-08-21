---
slug: jeap-spring-boot-parent-40.0.0
title: jeap-spring-boot-parent - Release 40.0.0
authors: [jeap-team]
tags: [release]
---

New version [`40.0.0`](https://github.com/jeap-admin-ch/jeap-spring-boot-parent/blob/v40.0.0/CHANGELOG.md) of `jeap-spring-boot-parent` is available.

<!-- truncate -->


### Changed
- update jeap-spring-boot-starters from 24.18.0 to 24.19.0
    - Fix failing token introspection when a client id contains colons by URL-encoding the client id and secret before
      using them as basic auth credentials (see RFC 6749).
- update jeap-messaging from 17.16.0 to 18.0.0
- Update parent from 8.13.0 to 9.0.0, which updates Avro from 1.12.1 to 1.12.2
    - Breaking test change: Major release because this parent updates jeap-messaging from 17.16.0 to 18.0.0, which
      introduces the Avro class whitelist. Tests without a Spring context that build, serialize or deserialize a
      generated Avro message have to install the whitelist themselves, see the notes below.
- Avro 1.12.2 only resolves classes from a schema when they are trusted, so jEAP Messaging installs an Avro
  `ClassSecurityValidator` whitelist. Trusted are the Avro generated types in `ch.admin.bit.jeap` and - as long as
  nothing is configured - in `ch.admin`, the common JDK collection and value types (`UUID`, `java.time`, the legacy
  `java.util.Date` / `java.sql` date types) that a schema can reference via `java-class` / `java-key-class`, and
  whatever `jeap.messaging.avro.trusted-packages` / `jeap.messaging.avro.trusted-classes` name - those regardless of
  whether the class is Avro generated. Being an Avro generated type narrows the built-in packages, it never trusts a
  class on its own.
- Tests without a Spring context have to install the avro class whitelist themselves. A plain unit test that builds,
  serializes or deserializes a generated Avro message now fails with `SecurityException: Forbidden ...` unless it
  installs the whitelist first:
  ```java
  @BeforeAll
  static void installAvroClassWhitelist() {
      AvroClassSecurity.installDefaultIfMissing();
  }
  ```

