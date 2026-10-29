---
slug: jeap-spring-boot-parent-41.29.1
title: jeap-spring-boot-parent - Release 41.29.1
authors: [jeap-team]
tags: [release]
---

New version [`41.29.1`](https://github.com/jeap-admin-ch/jeap-spring-boot-parent/blob/v41.29.1/CHANGELOG.md) of `jeap-spring-boot-parent` is available.

<!-- truncate -->

### Changed
- update jeap-spring-boot-jwe-starter from 1.56.0 to 1.56.1
- Maven wrapper: download Maven from the `maven-central` repository instead of `maven-public`. The mirror to GitHub only
  rewrites `maven-central` URLs to the public Maven Central, so the GitHub Actions security scan could not download
  Maven (Snyk scan error, exit code 2).

