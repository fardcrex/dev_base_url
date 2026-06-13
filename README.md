# dev_base_url

[![CI](https://github.com/fardcrex/dev_base_url/actions/workflows/ci.yaml/badge.svg)](https://github.com/fardcrex/dev_base_url/actions/workflows/ci.yaml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

> 🇪🇸 [Leer en español](README.es.md)

Your backend runs on `localhost:3000`. Your Flutter app can only reach it there from web and desktop — the Android emulator needs `10.0.2.2`, the iOS simulator `127.0.0.1`, and a physical phone needs your machine's LAN IP. So every project with a local backend ends up with this block:

```dart
String baseUrl;
if (!kIsWeb && Platform.isAndroid) {
  final info = await DeviceInfoPlugin().androidInfo;
  baseUrl = info.isPhysicalDevice
      ? 'http://192.168.1.5:3000' // ← changes every time your network does
      : 'http://10.0.2.2:3000';
} else {
  baseUrl = 'http://localhost:3000';
}
// ...and it's async, so your DI container can't build a singleton with it.
```

With `dev_base_url`, that whole block becomes:

```dart
await DevBaseUrl.instance.prepare(port: 3000); // once, in main()
final url = DevBaseUrl.instance.baseUrl();     // sync, anywhere
// → http://10.0.2.2:3000 on the Android emulator, http://localhost:3000 on desktop/web
```

A physical device is the only case with no stable alias — there you set your LAN IP once in a gitignored `config.json`, and anything misconfigured fails immediately with a message that includes the fix.

And none of this ships to your users: with [separate entry points](#entry-points-per-environment), tree shaking excludes the package completely from the production binary.

> Zero config where it's possible, fail-fast with instructions where it's not.

## Features

- 🔍 **Automatic platform detection** — Android emulator (`10.0.2.2`), iOS simulator (`127.0.0.1`), web/desktop (`localhost`), physical device (explicit IP).
- ⚡ **Sync access after a one-time async prepare** — plays well with DI containers (`get_it`, `riverpod`, …) that build singletons synchronously.
- 🗂️ **Multiple backends** — each `key` caches an independent URL.
- 🛡️ **Fail-fast validation** — invalid HOST/PORT throw immediately, on every platform, with styled error messages that include the fix.
- 🔁 **Concurrency-safe caching** — parallel calls with the same `key` share a single resolution; a failed attempt never poisons retries.
- 🧪 **Fully testable** — inject fakes for platform and device detection; no `dart:io` or `device_info_plus` needed in tests.
- 🌐 **Configurable** — direct parameters, `--dart-define-from-file`, optional `https` scheme.
- 🌳 **Zero footprint in production** — with separate entry points, tree shaking excludes the package completely from the release binary.

## Contents

- [Why does this package exist?](#why-does-this-package-exist)
- [Why not just hardcode my LAN IP?](#why-not-just-hardcode-my-lan-ip)
- [Per-platform resolution](#per-platform-resolution)
- [Installation](#installation)
- [How do I get the backend IP?](#how-do-i-get-the-backend-ip)
- [Configuration](#configuration)
- [VS Code setup](#vs-code-setup-launchjson)
- [API](#api)
- [Use cases](#use-cases)
- [Entry points per environment](#entry-points-per-environment)
- [Example](#example)
- [Tests](#tests)
- [Console warnings](#console-warnings)
- [Errors](#errors)
- [Valid HOST values](#valid-host-values)
- [HTTP on the LAN](#http-on-the-lan)
- [FAQ](#faq)

---

## Why does this package exist?

Detecting whether you run on an emulator requires `await` — but DI containers like `get_it`, `riverpod`, or any other build their singletons **synchronously**. Without this package you would have to solve that manually in every project.

```dart
// Without dev_base_url — the problem
class HttpClientModule {
  // ❌ You can't await while constructing a singleton
  final baseUrl = await detectEmulatorAndBuildUrl();
}

// With dev_base_url — solved
class HttpClientModule {
  // ✅ Already resolved before the container builds this
  final baseUrl = DevBaseUrl.instance.baseUrl();
}
```

The first call to `resolveAsync` — either through `prepare()` or directly — detects the platform and **caches** the URL per `key`. Later calls with the same `key` return the cached value without recomputing.

---

## Why not just hardcode my LAN IP?

Fair question — `HOST: 192.168.1.5` does work on every platform at once. Until it doesn't:

**Your LAN IP changes. The aliases never do.**
DHCP reassigns it. You move from home to the office to a phone hotspot. Every change means looking the IP up again and editing your config — even if you only ever run on the emulator. Meanwhile `10.0.2.2`, `127.0.0.1` and `localhost` are stable forever: with no HOST configured, your daily emulator/simulator/desktop loop is **zero config, zero maintenance**.

**Most dev backends only listen on localhost.**
Vite, Rails, `go run`, most dev servers bind to `127.0.0.1` by default. Your LAN IP can't reach them — from anywhere. But `10.0.2.2` can: inside the Android emulator it maps to the **host's loopback**. The automatic route works with your backend's safe default binding; the hardcoded-IP route forces you to bind to `0.0.0.0` and open your firewall.

**Your team doesn't share your IP.**
Every developer has a different one. With automatic resolution, anyone working on emulator or simulator clones the repo and runs — no setup, no "what IP do I put here?" in the team chat. Only whoever tests on a physical device needs a (gitignored) `config.json`.

**And "just use the real IP" doesn't enforce itself.**
The real cost of doing this by hand isn't the IP — it's the silent failures when the convention breaks. Someone shares a config with `localhost`, runs it on the emulator, and loses an hour to a connection error that says nothing. This package turns every one of those dead ends into a console message that names the problem and shows the fix.

> **The whole package in one line:** zero config where it's possible, fail-fast with instructions where it's not.

---

## Per-platform resolution

| Platform                          | Auto-resolved HOST | Manually configurable HOST |
| --------------------------------- | ------------------ | -------------------------- |
| Android Emulator (AVD)            | `10.0.2.2`         | ✅ overrides the automatic |
| iOS Simulator                     | `127.0.0.1`        | ✅ overrides the automatic |
| Flutter Web                       | `localhost`        | ✅ overrides the automatic |
| Desktop (macOS / Windows / Linux) | `localhost`        | ✅ overrides the automatic |
| Physical device                   | ❌ no automatic    | ✅ required                |

> On a physical device HOST is required — the package throws a `StateError` with clear instructions if it is not configured. An explicit HOST is validated on **every** platform: an invalid value fails fast instead of silently producing a broken URL.

---

## Installation

```yaml
dependencies:
  dev_base_url: ^0.2.0
```

---

## How do I get the backend IP?

You need the IP of the machine running the backend to configure `HOST` when using a physical device, or when the backend lives on another PC in your LAN.

### The backend runs on your dev machine

**macOS**

```sh
ipconfig getifaddr en0
# → 192.168.1.5
```

**Windows**

```sh
ipconfig
# Look for "IPv4 Address" under your WiFi or Ethernet adapter
# → 192.168.1.5
```

**Linux**

```sh
ip addr show | grep "inet " | grep -v 127.0.0.1
# → inet 192.168.1.5/24
```

### The backend runs on another PC in the LAN

Run the command for **that PC's** OS and use the resulting IP as `HOST`.

### Verify the backend is reachable

```sh
# From your dev machine
curl http://192.168.1.5:3000/health

# From Android (adb shell)
adb shell curl http://192.168.1.5:3000/health
```

> ⚠️ Make sure the firewall on the backend machine allows inbound connections on the configured port.

---

## Configuration

### Option A — direct parameters

No extra files. Useful for small projects or teams that prefer not to use `config.json`.

```dart
await DevBaseUrl.instance.prepare(host: '192.168.1.5', port: 3000);
```

### Option B — `config.json` with `--dart-define-from-file`

Create `config.json` at the project root (next to `pubspec.yaml`):

```json
{
  "HOST": "192.168.1.5",
  "PORT": "3000"
}
```

> ⚠️ Add `config.json` to your `.gitignore` — it contains local IPs that vary per developer.

```gitignore
config.json
```

Call `prepare()` without parameters — it reads HOST and PORT automatically:

```dart
await DevBaseUrl.instance.prepare();
```

Pass it to the compiler:

```sh
flutter run --dart-define-from-file=config.json
```

### Priority when using both

Direct parameters always take priority over `config.json`:

```dart
// config.json → HOST: "192.168.1.5"
await DevBaseUrl.instance.prepare(host: '10.0.0.55');
// → uses 10.0.0.55, ignores config.json
```

### HOST with embedded port

If HOST already includes a port, the PORT value is ignored:

```json
{ "HOST": "192.168.1.5:3000" }
```

```dart
await DevBaseUrl.instance.prepare(host: '192.168.1.5:3000');
// → http://192.168.1.5:3000  (PORT ignored)
```

If you set both an embedded port **and** an explicit PORT, the embedded one wins and a console warning tells you so.

---

## VS Code setup (`launch.json`)

`.vscode/launch.json`:

```jsonc
{
  "version": "0.2.0",
  "configurations": [
    {
      // LAN development — points at the backend on your local network
      "name": "MyApp (LAN)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main_dev.dart",
      "args": ["--dart-define-from-file=config.json"],
    },
    {
      // Production — separate entry point, no LAN code
      "name": "MyApp (Production)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main_prod.dart",
    },
  ],
}
```

---

## API

### `prepare()` — sync access afterwards

Resolves and caches the URL under a `key`. Call it before your DI container builds any HTTP client.

```dart
Future<void> prepare({String? host, int? port, String scheme = 'http', String key = 'default'})
```

After `prepare()`, access synchronously with `baseUrl()`:

```dart
DevBaseUrl.instance.baseUrl();              // default backend
DevBaseUrl.instance.baseUrl(key: 'media'); // specific backend
```

Throws a `StateError` if called more than once with the same `key` — the error message includes the offending key.

### `resolveAsync()` — async with cache

Resolves and returns the URL. Caches the result per `key` — later calls with the same `key` return the cached value without recomputing. Safe to call concurrently: parallel calls with the same `key` share a single resolution.

```dart
Future<String> resolveAsync({String? host, int? port, String scheme = 'http', String key = 'default'})
```

If the `key` is already resolved and you pass different `host`/`port`/`scheme` values, the new parameters are **ignored** and a console warning is emitted — use a different `key` for a different backend.

### `baseUrl()` — sync

Returns the URL cached by `prepare()`. Only `prepare()` enables sync access — it is the explicit opt-in; `resolveAsync()` alone does not.

```dart
String baseUrl({String key = 'default'})
```

Throws a `StateError` if `prepare()` was not called with that `key`.

### `reset()` — testing only

Clears all caches and prepared keys. Annotated `@visibleForTesting` — useful in integration tests that share `DevBaseUrl.instance`. In unit tests prefer creating your own instance.

---

## Use cases

### With a DI container (get_it, riverpod, etc.)

```dart
// main_dev.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DevBaseUrl.instance.prepare(port: 3000); // ← first
  await yourContainer.init();                         // ← then
  runApp(const App());
}
```

```dart
// In your HTTP module — sync, already resolved
class HttpClientModule {
  final client = HttpClient(
    baseUrl: DevBaseUrl.instance.baseUrl(),
  );
}
```

### Multiple LAN backends

Each `key` caches an independent URL — no conflicts between backends:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await DevBaseUrl.instance.prepare(
    host: '192.168.1.45', port: 2000, key: 'auth',
  );
  await DevBaseUrl.instance.prepare(
    host: '192.168.1.50', port: 3000, key: 'media',
  );

  await yourContainer.init();
  runApp(const App());
}

// In each HTTP module
final authUrl  = DevBaseUrl.instance.baseUrl(key: 'auth');
// → http://192.168.1.45:2000

final mediaUrl = DevBaseUrl.instance.baseUrl(key: 'media');
// → http://192.168.1.50:3000
```

### Without a DI container — `create()` pattern

Encapsulate the resolution in a static async constructor. It is called once and the resulting object is reused.

```dart
class ApiClient {
  final String _baseUrl;

  ApiClient._({required String baseUrl}) : _baseUrl = baseUrl;

  static Future<ApiClient> create({int? port, String key = 'default'}) async {
    final baseUrl = await DevBaseUrl.instance.resolveAsync(
      port: port,
      key: key,
    );
    return ApiClient._(baseUrl: baseUrl);
  }

  Future<http.Response> get(String path) =>
      http.get(Uri.parse('$_baseUrl$path'));
}

// main_dev.dart — a single instance for the whole app
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final apiClient = await ApiClient.create(port: 3000);
  runApp(App(apiClient: apiClient));
}
```

### Resolve once and inject — zero package coupling

The most testable pattern: resolve in `main()` and pass the resulting `String` down. The rest of your app depends on a plain `String`, not on this package — trivial to fake in widget and unit tests.

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final baseUrl = await DevBaseUrl.instance.resolveAsync(port: 3000);

  // Widgets and services receive a plain String.
  runApp(App(baseUrl: baseUrl));
}

class App extends StatelessWidget {
  const App({required this.baseUrl, super.key});

  final String baseUrl;

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: HomePage(api: ApiClient(baseUrl: baseUrl)),
      );
}
```

### With Dio

```dart
class DioClient {
  final Dio _dio;

  DioClient._({required String baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 12),
        ));

  static Future<DioClient> create({int? port, String key = 'default'}) async {
    final baseUrl = await DevBaseUrl.instance.resolveAsync(
      port: port,
      key: key,
    );
    return DioClient._(baseUrl: baseUrl);
  }
}
```

### With Riverpod

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DevBaseUrl.instance.prepare(port: 3000);
  runApp(const ProviderScope(child: App()));
}

final httpClientProvider = Provider<HttpClient>((ref) {
  return HttpClient(baseUrl: DevBaseUrl.instance.baseUrl());
});
```

### Emulator pointing at another PC in the LAN

The Android emulator and the iOS simulator have full access to the local network — they can point at any LAN IP.

```dart
await DevBaseUrl.instance.prepare(host: '192.168.1.50', port: 3000);
// Android Emulator → http://192.168.1.50:3000  (does not use 10.0.2.2)
// iOS Simulator    → http://192.168.1.50:3000  (does not use 127.0.0.1)
```

---

## Entry points per environment

So that LAN code **does not enter the production binary**, use separate entry points.

```
lib/
├── main_dev.dart    ← LAN development
└── main_prod.dart   ← production (no dev_base_url import)
```

```dart
// main_prod.dart — no dev_base_url imports
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await yourContainer.initProduction();
  runApp(const App());
}
```

The compiler's tree shaking completely excludes the package from the production binary when it is not imported from the entry point.

---

## Example

The [`example/`](example/lib/main.dart) app shows the three consumption patterns side by side — sync (`prepare` + `baseUrl`), async (`resolveAsync` + `FutureBuilder`) and constructor injection — all sharing the same per-`key` cache:

```sh
cd example
flutter run
```

---

## Tests

The package was designed to be testable without `dart:io` or `device_info_plus`. Inject fake implementations through the testing constructor:

```dart
class FakeAndroidEmulator implements DeviceDetectorOverride {
  @override
  Future<bool> detectIfRunningOnEmulator() async => true;
}

class FakeAndroidPlatform implements TargetPlatformOverride {
  @override bool get isWeb => false;
  @override bool get isAndroid => true;
  @override bool get isIOS => false;
  @override bool get isDesktop => false;
}

test('Android emulator without HOST → 10.0.2.2', () async {
  final resolver = DevBaseUrl(
    config: DevBaseUrlConfig(host: '', port: '3000', isPortExplicitlyConfigured: true),
    deviceDetector: FakeAndroidEmulator(),
    platformOverride: FakeAndroidPlatform(),
  );

  final url = await resolver.resolveAsync();
  expect(url, 'http://10.0.2.2:3000');
});
```

Every `DevBaseUrl` instance has its own cache — no `tearDown` needed to clean state between tests. For integration tests sharing `DevBaseUrl.instance`, call `reset()` between tests.

---

## Console warnings

The package emits warnings during development. They never interrupt execution.

| Situation                                       | Warning                                                                      |
| ----------------------------------------------- | ---------------------------------------------------------------------------- |
| PORT not configured                             | Port 80 will be used — in development the backend almost never runs on 80   |
| HOST not configured on Web or Desktop           | localhost will be used — if the backend is on another PC, configure HOST    |
| Different params for an already-resolved `key`  | The new parameters are ignored — use a different `key` for another backend  |
| HOST has an embedded port and PORT is also set  | The port embedded in HOST wins — PORT is ignored                            |
| `localhost`/`127.0.0.1` on the Android emulator | Points at the AVD itself — remove HOST (auto `10.0.2.2`) or use a LAN IP    |
| `localhost`/`127.0.0.1` on a physical device    | Points at the phone itself — use your machine's LAN IP (or `adb reverse`)   |
| `10.0.2.2` outside the Android emulator         | That alias only exists inside the AVD — remove HOST or use a LAN IP         |

---

## Errors

`StateError` with a detailed message in the following cases:

| Situation                                                  | Error                                                          |
| ---------------------------------------------------------- | -------------------------------------------------------------- |
| `baseUrl()` before `prepare()`                             | Accessed before calling `prepare()` with that `key`            |
| PORT is an empty string `""` in `config.json`              | PORT cannot be an empty string                                 |
| PORT is not a valid number (`"abc"`, `"99999"`)            | PORT is not valid. Must be between 1 and 65535                 |
| Physical device without HOST                               | HOST is not defined — required on a physical device            |
| Invalid HOST format (`"mi-servidor"`) — **any platform**   | HOST is not valid                                              |
| HOST includes a scheme (`"http://192.168.1.5"`)            | HOST must not include the scheme — it is configured separately |
| Invalid `scheme` (anything other than `http`/`https`)      | SCHEME is not valid. Use "http" or "https"                     |
| `prepare()` called twice with the same `key`               | prepare() was called more than once with key: "..."            |

---

## Valid HOST values

| Value                    | Valid | Notes                                          |
| ------------------------ | ----- | ---------------------------------------------- |
| `192.168.1.5`            | ✅    | Typical LAN IP                                 |
| `10.0.0.25`              | ✅    | Typical LAN IP                                 |
| `localhost`              | ✅    | Only if the backend runs on the same machine   |
| `192.168.1.5:3000`       | ✅    | With embedded port — PORT is ignored           |
| `mi-servidor`            | ❌    | Hostnames not supported                        |
| `256.0.0.1`              | ❌    | IP out of range                                |
| `192.168.1.5:0`          | ❌    | Embedded port out of range (valid: 1–65535)    |
| `192.168.1.5:3000:extra` | ❌    | Invalid format                                 |

---

## HTTP on the LAN

The package defaults to `http://` intentionally. HTTPS requires a valid TLS certificate — on a local development network you usually neither have nor need one. If your local setup does have TLS (mkcert, Caddy, tunnels), pass `scheme: 'https'`:

```dart
await DevBaseUrl.instance.prepare(port: 3000, scheme: 'https');
// → https://localhost:3000
```

---

## FAQ

**Why does the Android emulator use `10.0.2.2` instead of `localhost`?**

The AVD runs in an isolated virtual network. `10.0.2.2` is the special alias pointing at the real host (your dev machine). `localhost` inside the emulator would point at the emulator itself.

**Why not use `localhost` on a physical device?**

`localhost` on the device points at the phone itself, not your machine. You need your machine's real IP on the local network.

**Does it work with any HTTP client?**

Yes. `baseUrl()` and `resolveAsync()` return a `String` — compatible with Dio, http, Retrofit, or any other client.

**Does it work with any DI container?**

Yes. The package has no dependency on any specific container.

**Can I call `resolveAsync()` multiple times with the same key?**

Yes, it's safe — even concurrently. The first call detects the platform and caches the result; the rest return the cached value. If you pass *different* parameters for an already-resolved key, they are ignored and a console warning tells you so.

**Can I call `prepare()` more than once with the same key?**

No. It throws a `StateError` that names the key. If you need multiple backends, use a different `key` for each.

**Can I call `prepare()` and `resolveAsync()` with the same key?**

Yes. `prepare()` internally calls `resolveAsync()` — they share the same per-`key` cache. A later `resolveAsync()` returns the already-cached value. Note that only `prepare()` enables synchronous `baseUrl()` access.

**Does the package end up in the production binary?**

Only if your production entry point imports it. Using `main_prod.dart` without `dev_base_url` imports, the compiler's tree shaking excludes it completely.
