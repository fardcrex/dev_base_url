# Changelog

## 0.2.0

First version prepared for pub.dev publication.

### Fixed

- `prepare()` no longer silently ignores `host`/`port` when `resolveAsync()`
  already resolved the same `key` — a console warning is now emitted whenever
  explicit parameters differ from the cached resolution.
- An explicit `HOST` is now validated on **every** platform (emulator, web,
  desktop), not only on physical devices. Invalid hosts such as
  `mi-servidor`, `256.0.0.1` or `192.168.1.5:` throw a `StateError` instead
  of silently producing a broken URL.
- `host` values are trimmed before use — `' 192.168.1.5 '` no longer produces
  a URL with embedded spaces.
- Concurrent `resolveAsync()` calls with the same `key` now share a single
  resolution (the `Future` is cached, not the result). Concurrent `prepare()`
  calls with the same `key` fail deterministically: exactly one wins.
- A failed resolution no longer poisons the cache — retrying with corrected
  parameters works.
- Embedded port range in `HOST` (`"ip:port"`) is now consistent with the
  standalone `PORT` validation: `1–65535` (port `0` was previously accepted).
- The "prepare called twice" error message now includes the offending `key`.
- Removed stale documentation references to a non-existent `LanBaseUrl` API.

### Added

- `scheme` parameter on `prepare()` and `resolveAsync()` (defaults to
  `http`) for local TLS setups (mkcert, Caddy, tunnels).
- `isWeb` getter on `TargetPlatformOverride` — the web resolution path is
  now fully testable through injected fakes.
- `reset()` (`@visibleForTesting`) to clear all caches between integration
  tests that use `DevBaseUrl.instance`.
- Console warning when `HOST` includes an embedded port **and** `PORT` is
  also explicitly configured — the embedded port wins and the warning says
  so, instead of silently ignoring `PORT`.
- Semantic HOST warnings for values that are syntactically valid but almost
  certainly wrong on the current platform:
  - `localhost`/`127.0.0.1` on the Android emulator (points at the AVD
    itself, not your machine).
  - `localhost`/`127.0.0.1` on a physical device (points at the phone —
    valid only with `adb reverse`).
  - `10.0.2.2` outside the Android emulator (the alias only exists inside
    the AVD's virtual network).
- `scheme` is validated — anything other than `http`/`https` throws a
  `StateError`.
- A `HOST` that includes a scheme (`http://192.168.1.5`, a common
  copy-paste mistake) now throws a specific error explaining that the
  scheme is configured separately, instead of the generic "invalid HOST".

### Changed

- **Breaking:** `TargetPlatformOverride` implementations must now provide
  `isWeb`. Update your test fakes with `@override bool get isWeb => false;`.
- `kEnvHost`, `kEnvPort`, `kKeyHost` and `kKeyPort` are no longer part
  of the public API — they are implementation details of
  `DevBaseUrlConfig.fromEnvironment()`.
- `RealPlatformOverride` getters are now web-safe (`kIsWeb` is checked
  before touching `Platform`).

## 0.1.1

- Refined LAN URL resolution caching and added production entry point
  guidance.

## 0.1.0

- Initial version: per-platform base URL resolution (Android emulator,
  iOS simulator, web, desktop, physical device), sync access via
  `prepare()`/`baseUrl()`, async resolution with per-`key` caching,
  `--dart-define-from-file` support and styled console diagnostics.
