---
slug: jeap-spring-boot-parent-40.7.0
title: jeap-spring-boot-parent - Release 40.7.0
authors: [jeap-team]
tags: [release]
---

New version [`40.7.0`](https://github.com/jeap-admin-ch/jeap-spring-boot-parent/blob/v40.7.0/CHANGELOG.md) of `jeap-spring-boot-parent` is available.

<!-- truncate -->


### Changed
- Update parent from 9.2.0 to 9.2.1
- update jeap-opensearch-index-type from 1.29.0 to 1.30.0
- update jeap-db-schema-publisher from 3.33.0 to 3.34.0
- update jeap-spring-boot-roles-anywhere-starter from 3.34.0 to 3.35.0
- update jeap-spring-boot-tls-starter from 19.32.0 to 19.33.0
- update jeap-spring-boot-db-migration-starter from 19.32.0 to 19.33.0
- update jeap-spring-boot-config-aws-starter from 19.34.0 to 19.35.0
- update jeap-spring-boot-jwe-starter from 1.27.0 to 1.28.0
- update jeap-opensearch-index-type-registry-maven-plugin from 3.9.0 to 3.10.0
- update jeap-spring-boot-starters from 24.24.0 to 24.25.0
- update jeap-open-api-publisher from 7.23.0 to 7.24.0
- update jeap-spring-boot-security-client-starter from 24.24.0 to 24.25.0
- update jeap-opensearch-searchitem-api from 2.22.0 to 2.23.0
- update jeap-starter from 24.24.0 to 24.25.0
- update jeap-opensearch-client-starter from 2.23.0 to 2.24.0
- update jeap-crypto from 10.22.0 to 10.23.0
- update jeap-spring-boot-vault-starter from 24.24.0 to 24.25.0
- update jeap-messaging from 18.5.0 to 18.6.0
- update jeap-messaging-outbox from 17.22.0 to 17.23.0
- update jeap-server-sent-events from 12.22.0 to 12.23.0
- update jeap-reaction-observer from 10.22.0 to 10.23.0
- update jeap-messaging-sequential-inbox from 20.22.0 to 20.23.0
- update jeap-spring-boot-security-starter from 24.24.0 to 24.25.0
- update jeap-audit from 10.20.0 to 10.21.0
- update jeap-spring-boot-starters from 24.25.0 to 24.26.0
- `jeap.security.oauth2.resourceserver.strict-audience-validation` (`off`/`on`/`warn`, default `off`): with `on`,
  access tokens in the USER and SYS contexts without an `aud` claim are rejected instead of being treated as valid for
  every resource; `warn` keeps accepting them but logs a warning identifying the token as a migration aid. Tokens in the
  B2B context remain unchecked. `on` will become the default in a future release.
- `JwsBuilder.withEmptyAudience()` (security test support): mints a token with an explicitly empty `aud` claim
  (`"aud": []`), which Nimbus' `JWTClaimsSet` cannot express, to test how a resource server treats such tokens.
- Introspection mode `CUSTOM` now actually uses the `JeapJwtIntrospectionCondition` bean provided by the application:
  the built-in condition previously did not back off because it checked a wrong property key. A custom condition bean
  combined with any other introspection mode now fails the application startup with a descriptive error, as such a bean
  would not be used.
- `jeap.security.oauth2.resourceserver.b2b-gateway.jwks-connect-timeout-in-millis` and
  `...b2b-gateway.jwks-read-timeout-in-millis` are now applied when fetching the B2B gateway's JWKS. They were
  accepted but silently ignored, the defaults of 15000 ms being used instead.
- The token introspection client id (`...introspection.client-id`) is now optional: if not configured, the resource id
  (`resource-id`, defaulting to `spring.application.name`) is used, as Keycloak requires the introspection client id to
  be identical to the resource id.
- update jeap-open-api-publisher from 7.24.0 to 7.25.0
- update jeap-spring-boot-security-client-starter from 24.25.0 to 24.26.0
- update jeap-opensearch-searchitem-api from 2.23.0 to 2.24.0
- update jeap-starter from 24.25.0 to 24.26.0
- update jeap-opensearch-client-starter from 2.24.0 to 2.25.0
- update jeap-crypto from 10.23.0 to 10.24.0
- update jeap-spring-boot-vault-starter from 24.25.0 to 24.26.0
- update jeap-messaging from 18.6.0 to 18.7.0
- update jeap-messaging-outbox from 17.23.0 to 17.24.0
- update jeap-reaction-observer from 10.23.0 to 10.24.0
- update jeap-server-sent-events from 12.23.0 to 12.24.0
- update jeap-messaging-sequential-inbox from 20.23.0 to 20.24.0
- update jeap-spring-boot-security-starter from 24.25.0 to 24.26.0
- update jeap-audit from 10.21.0 to 10.22.0

