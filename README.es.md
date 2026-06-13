# dev_base_url

[![CI](https://github.com/fardcrex/dev_base_url/actions/workflows/ci.yaml/badge.svg)](https://github.com/fardcrex/dev_base_url/actions/workflows/ci.yaml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

> 🇬🇧 [Read in English](README.md)

Tu backend corre en `localhost:3000`. Tu app Flutter solo puede alcanzarlo ahí desde web y desktop — el emulador Android necesita `10.0.2.2`, el simulador iOS `127.0.0.1`, y un teléfono físico necesita la IP LAN de tu máquina. Así que cada proyecto con backend local termina con este bloque:

```dart
String baseUrl;
if (!kIsWeb && Platform.isAndroid) {
  final info = await DeviceInfoPlugin().androidInfo;
  baseUrl = info.isPhysicalDevice
      ? 'http://192.168.1.5:3000' // ← cambia cada vez que cambia tu red
      : 'http://10.0.2.2:3000';
} else {
  baseUrl = 'http://localhost:3000';
}
// ...y es async, así que tu contenedor DI no puede construir un singleton con esto.
```

Con `dev_base_url`, todo ese bloque se convierte en:

```dart
await DevBaseUrl.instance.prepare(port: 3000); // una vez, en main()
final url = DevBaseUrl.instance.baseUrl();     // síncrono, en cualquier parte
// → http://10.0.2.2:3000 en el emulador Android, http://localhost:3000 en desktop/web
```

Un dispositivo físico es el único caso sin alias estable — ahí configuras tu IP LAN una sola vez en un `config.json` gitignoreado, y cualquier configuración incorrecta falla de inmediato con un mensaje que incluye la solución.

Y nada de esto llega a tus usuarios: con [entry points separados](#entry-points-por-entorno), el tree shaking excluye el paquete por completo del binario de producción.

> Cero config donde es posible, fail-fast con instrucciones donde no.

## Características

- 🔍 **Detección automática de plataforma** — emulador Android (`10.0.2.2`), simulador iOS (`127.0.0.1`), web/desktop (`localhost`), dispositivo físico (IP explícita).
- ⚡ **Acceso síncrono tras un prepare asíncrono único** — compatible con contenedores DI (`get_it`, `riverpod`, …) que construyen singletons de forma síncrona.
- 🗂️ **Múltiples backends** — cada `key` cachea una URL independiente.
- 🛡️ **Validación fail-fast** — HOST/PORT inválidos lanzan de inmediato, en cualquier plataforma, con mensajes de error estilizados que incluyen la solución.
- 🔁 **Caché seguro ante concurrencia** — llamadas paralelas con la misma `key` comparten una sola resolución; un intento fallido nunca envenena los reintentos.
- 🧪 **Totalmente testeable** — inyecta fakes de plataforma y detección de dispositivo; sin `dart:io` ni `device_info_plus` en tests.
- 🌐 **Configurable** — parámetros directos, `--dart-define-from-file`, scheme `https` opcional.
- 🌳 **Cero huella en producción** — con entry points separados, el tree shaking excluye el paquete por completo del binario de release.

## Contenido

- [¿Por qué existe este paquete?](#por-qué-existe-este-paquete)
- [¿Por qué no simplemente hardcodear mi IP LAN?](#por-qué-no-simplemente-hardcodear-mi-ip-lan)
- [Resolución por plataforma](#resolución-por-plataforma)
- [Instalación](#instalación)
- [¿Cómo obtener la IP del backend?](#cómo-obtener-la-ip-del-backend)
- [Configuración](#configuración)
- [Configuración con VS Code](#configuración-con-vs-code-launchjson)
- [API](#api)
- [Casos de uso](#casos-de-uso)
- [Entry points por entorno](#entry-points-por-entorno)
- [Ejemplo](#ejemplo)
- [Tests](#tests)
- [Advertencias en consola](#advertencias-en-consola)
- [Errores](#errores)
- [Valores válidos para HOST](#valores-válidos-para-host)
- [HTTP en LAN](#http-en-lan)
- [Preguntas frecuentes](#preguntas-frecuentes)

---

## ¿Por qué existe este paquete?

Detectar si corres en emulador requiere `await` — pero los contenedores de dependencias como `get_it`, `riverpod`, o cualquier otro construyen sus singletons de forma **síncrona**. Sin este paquete tendrías que resolver eso manualmente en cada proyecto.

```dart
// Sin dev_base_url — problema
class HttpClientModule {
  // ❌ No puedes hacer await en la construcción de un singleton
  final baseUrl = await detectEmulatorAndBuildUrl();
}

// Con dev_base_url — resuelto
class HttpClientModule {
  // ✅ Ya resuelto antes de que el contenedor construya esto
  final baseUrl = DevBaseUrl.instance.baseUrl();
}
```

La primera llamada a `resolveAsync` — ya sea desde `prepare()` o directamente — detecta la plataforma y **cachea** la URL por `key`. Llamadas posteriores con la misma `key` retornan el valor cacheado sin recalcular.

---

## ¿Por qué no simplemente hardcodear mi IP LAN?

Pregunta justa — `HOST: 192.168.1.5` sí funciona en todas las plataformas a la vez. Hasta que deja de hacerlo:

**Tu IP LAN cambia. Los alias nunca.**
DHCP te la reasigna. Pasas de tu casa a la oficina a un hotspot del celular. Cada cambio significa averiguar la IP de nuevo y editar tu config — incluso si solo corres en el emulador. Mientras tanto `10.0.2.2`, `127.0.0.1` y `localhost` son estables para siempre: sin HOST configurado, tu ciclo diario de emulador/simulador/desktop es **cero config, cero mantenimiento**.

**La mayoría de backends de desarrollo solo escuchan en localhost.**
Vite, Rails, `go run` — la mayoría de dev servers se bindean a `127.0.0.1` por defecto. Tu IP LAN no puede alcanzarlos — desde ninguna parte. Pero `10.0.2.2` sí: dentro del emulador Android mapea al **loopback del host**. La ruta automática funciona con el binding seguro por defecto de tu backend; la ruta de IP hardcodeada te obliga a bindear a `0.0.0.0` y abrir el firewall.

**Tu equipo no comparte tu IP.**
Cada desarrollador tiene una distinta. Con resolución automática, cualquiera que trabaje en emulador o simulador clona el repo y corre — sin setup, sin "¿qué IP pongo aquí?" en el chat del equipo. Solo quien prueba en dispositivo físico necesita un `config.json` (gitignoreado).

**Y "usa la IP real" no se cumple solo.**
El costo real de hacer esto a mano no es la IP — son las fallas silenciosas cuando la convención se rompe. Alguien comparte una config con `localhost`, la corre en el emulador, y pierde una hora con un error de conexión que no dice nada. Este paquete convierte cada uno de esos callejones sin salida en un mensaje de consola que nombra el problema y muestra la solución.

> **Todo el paquete en una línea:** cero config donde es posible, fail-fast con instrucciones donde no.

---

## Resolución por plataforma

| Plataforma                        | HOST resuelto automáticamente | HOST configurable manualmente |
| --------------------------------- | ----------------------------- | ----------------------------- |
| Android Emulator (AVD)            | `10.0.2.2`                    | ✅ sobreescribe el automático |
| iOS Simulator                     | `127.0.0.1`                   | ✅ sobreescribe el automático |
| Flutter Web                       | `localhost`                   | ✅ sobreescribe el automático |
| Desktop (macOS / Windows / Linux) | `localhost`                   | ✅ sobreescribe el automático |
| Dispositivo físico                | ❌ no existe automático       | ✅ obligatorio                |

> En dispositivo físico HOST es obligatorio — el paquete lanza un `StateError` con instrucciones claras si no está configurado. Un HOST explícito se valida en **todas** las plataformas: un valor inválido falla de inmediato en vez de producir una URL rota silenciosa.

---

## Instalación

```yaml
dependencies:
  dev_base_url: ^0.2.0
```

---

## ¿Cómo obtener la IP del backend?

Necesitas la IP de la máquina donde corre el backend para configurar `HOST` cuando usas dispositivo físico o cuando el backend está en otra PC de la LAN.

### El backend corre en tu máquina de desarrollo

**macOS**

```sh
ipconfig getifaddr en0
# → 192.168.1.5
```

**Windows**

```sh
ipconfig
# Busca "Dirección IPv4" bajo tu adaptador WiFi o Ethernet
# → 192.168.1.5
```

**Linux**

```sh
ip addr show | grep "inet " | grep -v 127.0.0.1
# → inet 192.168.1.5/24
```

### El backend corre en otra PC de la LAN

Ejecuta el comando correspondiente al OS de **esa PC** y usa la IP que obtienes como `HOST`.

### Verificar que el backend es accesible

```sh
# Desde tu máquina de desarrollo
curl http://192.168.1.5:3000/health

# Desde Android (adb shell)
adb shell curl http://192.168.1.5:3000/health
```

> ⚠️ Asegúrate de que el firewall de la máquina con el backend permite conexiones entrantes en el puerto configurado.

---

## Configuración

### Opción A — parámetros directos

Sin archivos extra. Útil en proyectos pequeños o cuando el equipo prefiere no usar `config.json`.

```dart
await DevBaseUrl.instance.prepare(host: '192.168.1.5', port: 3000);
```

### Opción B — `config.json` con `--dart-define-from-file`

Crea `config.json` en la raíz del proyecto (junto a `pubspec.yaml`):

```json
{
  "HOST": "192.168.1.5",
  "PORT": "3000"
}
```

> ⚠️ Agrega `config.json` a tu `.gitignore` — contiene IPs locales que varían por desarrollador.

```gitignore
config.json
```

Llama a `prepare()` sin parámetros — lee HOST y PORT automáticamente:

```dart
await DevBaseUrl.instance.prepare();
```

Pásalo al compilador:

```sh
flutter run --dart-define-from-file=config.json
```

### Prioridad cuando usas ambas

Los parámetros directos siempre tienen prioridad sobre `config.json`:

```dart
// config.json → HOST: "192.168.1.5"
await DevBaseUrl.instance.prepare(host: '10.0.0.55');
// → usa 10.0.0.55, ignora config.json
```

### HOST con puerto incluido

Si HOST ya incluye puerto, el valor de PORT se ignora:

```json
{ "HOST": "192.168.1.5:3000" }
```

```dart
await DevBaseUrl.instance.prepare(host: '192.168.1.5:3000');
// → http://192.168.1.5:3000  (PORT ignorado)
```

Si seteas un puerto embebido **y además** un PORT explícito, gana el embebido y una advertencia en consola te lo indica.

---

## Configuración con VS Code (`launch.json`)

`.vscode/launch.json`:

```jsonc
{
  "version": "0.2.0",
  "configurations": [
    {
      // Desarrollo LAN — apunta al backend en tu red local
      "name": "MyApp (LAN)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main_dev.dart",
      "args": ["--dart-define-from-file=config.json"],
    },
    {
      // Producción — entry point separado, sin código LAN
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

### `prepare()` — síncrono posterior

Resuelve y cachea la URL bajo una `key`. Llámalo antes de que tu contenedor de dependencias construya cualquier cliente HTTP.

```dart
Future<void> prepare({String? host, int? port, String scheme = 'http', String key = 'default'})
```

Después de `prepare()`, accede síncronamente con `baseUrl()`:

```dart
DevBaseUrl.instance.baseUrl();              // backend default
DevBaseUrl.instance.baseUrl(key: 'media'); // backend específico
```

Throws `StateError` si se llama más de una vez con la misma `key` — el mensaje de error incluye la key conflictiva.

### `resolveAsync()` — asíncrono con caché

Resuelve y retorna la URL. Cachea el resultado por `key` — llamadas posteriores con la misma `key` retornan el valor cacheado sin recalcular. Seguro incluso en llamadas concurrentes: llamadas paralelas con la misma `key` comparten una sola resolución.

```dart
Future<String> resolveAsync({String? host, int? port, String scheme = 'http', String key = 'default'})
```

Si la `key` ya está resuelta y pasas `host`/`port`/`scheme` distintos, los parámetros nuevos se **ignoran** y se emite una advertencia en consola — usa otra `key` para otro backend.

### `baseUrl()` — síncrono

Retorna la URL cacheada por `prepare()`. Solo `prepare()` habilita el acceso síncrono — es el opt-in explícito; `resolveAsync()` por sí solo no lo hace.

```dart
String baseUrl({String key = 'default'})
```

Throws `StateError` si `prepare()` no fue llamado con esa `key`.

### `reset()` — solo para tests

Limpia todos los cachés y keys preparadas. Anotado `@visibleForTesting` — útil en integration tests que comparten `DevBaseUrl.instance`. En unit tests prefiere crear tu propia instancia.

---

## Casos de uso

### Con contenedor de dependencias (get_it, riverpod, etc.)

```dart
// main_dev.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DevBaseUrl.instance.prepare(port: 3000); // ← primero
  await yourContainer.init();                         // ← luego
  runApp(const App());
}
```

```dart
// En tu módulo HTTP — síncrono, ya resuelto
class HttpClientModule {
  final client = HttpClient(
    baseUrl: DevBaseUrl.instance.baseUrl(),
  );
}
```

### Múltiples backends LAN

Cada `key` cachea una URL independiente — sin conflicto entre backends:

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

// En cada módulo HTTP
final authUrl  = DevBaseUrl.instance.baseUrl(key: 'auth');
// → http://192.168.1.45:2000

final mediaUrl = DevBaseUrl.instance.baseUrl(key: 'media');
// → http://192.168.1.50:3000
```

### Sin contenedor de dependencias — patrón `create()`

Encapsula la resolución en un constructor async estático. Se llama una sola vez y el objeto resultante se reutiliza.

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

// main_dev.dart — una sola instancia para toda la app
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final apiClient = await ApiClient.create(port: 3000);
  runApp(App(apiClient: apiClient));
}
```

### Resolver una vez e inyectar — cero acoplamiento al paquete

El patrón más testeable: resuelve en `main()` y pasa el `String` resultante hacia abajo. El resto de tu app depende de un `String` plano, no de este paquete — trivial de fakear en widget tests y unit tests.

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final baseUrl = await DevBaseUrl.instance.resolveAsync(port: 3000);

  // Widgets y servicios reciben un String plano.
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

### Con Dio

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

### Con Riverpod

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

### Emulador apuntando a otra PC de la LAN

El emulador Android y el simulador iOS tienen acceso completo a la red local — pueden apuntar a cualquier IP de la LAN.

```dart
await DevBaseUrl.instance.prepare(host: '192.168.1.50', port: 3000);
// Android Emulator → http://192.168.1.50:3000  (no usa 10.0.2.2)
// iOS Simulator    → http://192.168.1.50:3000  (no usa 127.0.0.1)
```

---

## Entry points por entorno

Para que el código LAN **no entre al binario de producción**, usa entry points separados.

```
lib/
├── main_dev.dart    ← desarrollo LAN
└── main_prod.dart   ← producción (sin ningún import de dev_base_url)
```

```dart
// main_prod.dart — sin imports de dev_base_url
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await yourContainer.initProduction();
  runApp(const App());
}
```

El tree shaking del compilador excluye completamente el paquete del binario de producción cuando no es importado desde el entry point.

---

## Ejemplo

La app en [`example/`](example/lib/main.dart) muestra los tres patrones de consumo lado a lado — síncrono (`prepare` + `baseUrl`), asíncrono (`resolveAsync` + `FutureBuilder`) e inyección por constructor — compartiendo el mismo caché por `key`:

```sh
cd example
flutter run
```

---

## Tests

El paquete fue diseñado para ser testeable sin `dart:io` ni `device_info_plus`. Inyecta implementaciones fake via el constructor de testing:

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

test('Android emulator sin HOST → 10.0.2.2', () async {
  final resolver = DevBaseUrl(
    config: DevBaseUrlConfig(host: '', port: '3000', isPortExplicitlyConfigured: true),
    deviceDetector: FakeAndroidEmulator(),
    platformOverride: FakeAndroidPlatform(),
  );

  final url = await resolver.resolveAsync();
  expect(url, 'http://10.0.2.2:3000');
});
```

Cada instancia de `DevBaseUrl` tiene su propio caché — no necesitas `tearDown` para limpiar estado entre tests. En integration tests que comparten `DevBaseUrl.instance`, llama a `reset()` entre tests.

---

## Advertencias en consola

El paquete emite advertencias durante el desarrollo. No interrumpen la ejecución.

| Situación                                      | Advertencia                                                                |
| ---------------------------------------------- | -------------------------------------------------------------------------- |
| PORT no configurado                            | Se usará el puerto 80 — en desarrollo casi nunca el backend corre en el 80 |
| HOST no configurado en Web o Desktop           | Se usará localhost — si el backend está en otra PC, configura HOST         |
| Params distintos con `key` ya resuelta         | Los parámetros nuevos se ignoran — usa otra `key` para otro backend        |
| HOST con puerto embebido y PORT también seteado | El puerto embebido en HOST gana — PORT se ignora                           |
| `localhost`/`127.0.0.1` en emulador Android    | Apunta al propio AVD — quita HOST (usa `10.0.2.2` automático) o IP LAN     |
| `localhost`/`127.0.0.1` en dispositivo físico  | Apunta al propio teléfono — usa la IP LAN de tu máquina (o `adb reverse`)  |
| `10.0.2.2` fuera del emulador Android          | Ese alias solo existe dentro del AVD — quita HOST o usa IP LAN             |

---

## Errores

`StateError` con mensaje detallado en los siguientes casos:

| Situación                                                       | Error                                                        |
| --------------------------------------------------------------- | ------------------------------------------------------------ |
| `baseUrl()` antes de `prepare()`                                | Acceso antes de llamar a `prepare()` con esa `key`           |
| PORT es cadena vacía `""` en `config.json`                      | PORT no puede ser una cadena vacía                           |
| PORT no es número válido (`"abc"`, `"99999"`)                   | PORT no es válido. Debe ser entre 1 y 65535                  |
| Dispositivo físico sin HOST                                     | HOST no está definido — en dispositivo físico es obligatorio |
| HOST con formato inválido — **en cualquier plataforma**         | HOST no es válido                                            |
| HOST incluye scheme (`"http://192.168.1.5"`)                    | HOST no debe incluir el scheme — se configura aparte         |
| `scheme` inválido (distinto de `http`/`https`)                  | SCHEME no es válido. Usa "http" o "https"                    |
| `prepare()` llamado dos veces con la misma `key`                | prepare() fue llamado más de una vez con key: "..."          |

---

## Valores válidos para HOST

| Valor                    | Válido | Notas                                          |
| ------------------------ | ------ | ---------------------------------------------- |
| `192.168.1.5`            | ✅     | IP LAN típica                                  |
| `10.0.0.25`              | ✅     | IP LAN típica                                  |
| `localhost`              | ✅     | Solo si el backend corre en la misma máquina   |
| `192.168.1.5:3000`       | ✅     | Con puerto incluido — PORT se ignora           |
| `mi-servidor`            | ❌     | Hostname no soportado                          |
| `256.0.0.1`              | ❌     | IP fuera de rango                              |
| `192.168.1.5:0`          | ❌     | Puerto embebido fuera de rango (válido: 1–65535) |
| `192.168.1.5:3000:extra` | ❌     | Formato inválido                               |

---

## HTTP en LAN

El paquete usa `http://` por defecto de forma intencional. HTTPS requiere certificado TLS válido — en red local de desarrollo normalmente no tienes ni necesitas uno. Si tu entorno local sí tiene TLS (mkcert, Caddy, túneles), pasa `scheme: 'https'`:

```dart
await DevBaseUrl.instance.prepare(port: 3000, scheme: 'https');
// → https://localhost:3000
```

---

## Preguntas frecuentes

**¿Por qué el emulador Android usa `10.0.2.2` y no `localhost`?**

El AVD corre en una red virtual aislada. `10.0.2.2` es el alias especial que apunta al host real (tu máquina de desarrollo). `localhost` dentro del emulador apuntaría al propio emulador.

**¿Por qué no usar `localhost` en dispositivo físico?**

`localhost` en el dispositivo apunta al propio teléfono, no a tu máquina. Necesitas la IP real de tu máquina en la red local.

**¿Funciona con cualquier cliente HTTP?**

Sí. `baseUrl()` y `resolveAsync()` retornan un `String` — compatible con Dio, http, Retrofit, o cualquier otro cliente.

**¿Funciona con cualquier contenedor de dependencias?**

Sí. El paquete no tiene dependencia de ningún contenedor específico.

**¿Puedo llamar a `resolveAsync()` varias veces con la misma key?**

Sí, es seguro — incluso de forma concurrente. La primera llamada detecta la plataforma y cachea el resultado; las siguientes retornan el valor cacheado. Si pasas parámetros *distintos* para una key ya resuelta, se ignoran y una advertencia en consola te lo indica.

**¿Puedo llamar a `prepare()` más de una vez con la misma key?**

No. Lanza `StateError` indicando la key. Si necesitas múltiples backends usa `key` distinta para cada uno.

**¿Puedo llamar a `prepare()` y `resolveAsync()` con la misma key?**

Sí. `prepare()` internamente llama a `resolveAsync()` — comparten el mismo caché por `key`. `resolveAsync()` posterior retorna el valor ya cacheado. Ten en cuenta que solo `prepare()` habilita el acceso síncrono via `baseUrl()`.

**¿El paquete entra al binario de producción?**

Solo si tu entry point de producción lo importa. Usando `main_prod.dart` sin imports de `dev_base_url`, el tree shaking del compilador lo excluye completamente.
