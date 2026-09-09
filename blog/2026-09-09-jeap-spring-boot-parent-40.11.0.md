---
slug: jeap-spring-boot-parent-40.11.0
title: jeap-spring-boot-parent - Release 40.11.0
authors: [jeap-team]
tags: [release]
---

New version [`40.11.0`](https://github.com/jeap-admin-ch/jeap-spring-boot-parent/blob/v40.11.0/CHANGELOG.md) of `jeap-spring-boot-parent` is available.

<!-- truncate -->


### Changed
- Update parent from 9.3.0 to 9.4.0
- update jeap-spring-boot-roles-anywhere-starter from 3.37.0 to 3.38.0
- update jeap-spring-modulith-error-handling-starter from 1.3.1 to 1.4.0
- update jeap-spring-boot-tls-starter from 19.35.0 to 19.36.0
- update jeap-opensearch-index-type from 1.32.0 to 1.33.0
- update jeap-spring-boot-db-migration-starter from 19.35.0 to 19.36.0
- update jeap-spring-boot-config-aws-starter from 19.37.0 to 19.38.0
- update jeap-db-schema-publisher from 3.36.0 to 3.37.0
- update jeap-spring-boot-jwe-starter from 1.30.0 to 1.31.0
- update jeap-opensearch-index-type-registry-maven-plugin from 3.12.0 to 3.13.0
- update jeap-spring-boot-starters from 24.29.0 to 24.30.0
- update jeap-open-api-publisher from 7.28.0 to 7.29.0
- update jeap-spring-boot-security-client-starter from 24.29.0 to 24.30.0
- update jeap-opensearch-searchitem-api from 2.27.0 to 2.28.0
- update jeap-starter from 24.29.0 to 24.30.0
- update jeap-opensearch-client-starter from 2.28.0 to 2.29.0
- update jeap-crypto from 10.27.0 to 10.28.0
- update jeap-spring-boot-vault-starter from 24.29.0 to 24.30.0
- update jeap-messaging from 18.10.1 to 18.11.0
- update jeap-spring-boot-starters from 24.30.0 to 24.31.0
- Optional local caching of token introspection responses, configurable per authorization server and independently
  of the introspection mode (`...introspection.cache.enabled`, `.maximum-size`, `.time-to-live`; disabled by default)
  and backed by Caffeine. Whether the introspection responses may be cached is up to the application: only the
  transparent introspection enriching a token is served from the cache, explicit validity checks
  (`JeapJwtIntrospection.isValid`) always query the introspection endpoint and update the cache with the result.
  Cached responses are unmodifiable, never outlive the token or the response's own `exp`, and are keyed by issuer,
  `jti` and a SHA-256 hash of the token value; tokens without `jti` are not cached. Applications can replace the
  default cache by providing a `JeapTokenIntrospectionCacheFactory` bean. Added a new metric for cache lookups:
  `jeap.security.token.introspection.cache.lookups` (tags `issuer`, `result`). For analyzing the caching behavior,
  cache lookups and changes of the cache content are logged on level `trace` of the logger
  `ch.admin.bit.jeap.security.resource.introspection`. Note that Caffeine on the classpath makes Spring Boot's cache
  auto-configuration select Caffeine for applications using `@EnableCaching` without an explicit `spring.cache.type`
  advising otherwise.
- update jeap-open-api-publisher from 7.29.0 to 7.30.0
- update jeap-spring-boot-security-client-starter from 24.30.0 to 24.31.0
- update jeap-opensearch-client-starter from 2.29.0 to 2.30.0
- update jeap-starter from 24.30.0 to 24.31.0
- update jeap-reaction-observer from 10.27.1 to 10.28.0
- update jeap-opensearch-searchitem-api from 2.28.0 to 2.29.0
- update jeap-crypto from 10.28.0 to 10.29.0
- update jeap-spring-boot-vault-starter from 24.30.0 to 24.31.0
- update jeap-messaging from 18.11.0 to 18.12.0
- update jeap-messaging-outbox from 17.27.1 to 17.28.0
- update jeap-server-sent-events from 12.27.1 to 12.28.0
- update jeap-audit from 10.25.1 to 10.26.0
- update jeap-reaction-observer from 10.28.0 to 10.29.0
- update jeap-messaging-sequential-inbox from 20.27.1 to 20.28.0
- update jeap-spring-boot-security-starter from 24.29.0 to 24.30.0
- update jeap-spring-boot-security-starter from 24.30.0 to 24.31.0

