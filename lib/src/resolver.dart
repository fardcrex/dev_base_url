import 'dart:async';

import 'package:flutter/foundation.dart';

import 'config.dart';
import 'device_detector.dart';
import 'network_guard.dart';
import 'network_warnings.dart';

/// Resuelve la URL base del backend LAN según la plataforma de ejecución.
///
/// **Modo síncrono** — ideal con contenedores de dependencias (get_it,
/// riverpod, etc.) que construyen singletons de forma síncrona:
///
/// ```dart
/// void main() async {
///   await DevBaseUrl.instance.prepare(port: 3000);
///   await yourContainer.init();
///   runApp(const App());
/// }
///
/// // En tu módulo HTTP — síncrono, ya resuelto
/// baseUrl: DevBaseUrl.instance.baseUrl(),
/// ```
///
/// **Modo asíncrono** — ideal con constructores `create()` o sin
/// contenedor de dependencias:
///
/// ```dart
/// static Future<ApiClient> create({int? port}) async {
///   final baseUrl = await DevBaseUrl.instance.resolveAsync(port: port);
///   return ApiClient._(baseUrl: baseUrl);
/// }
/// ```
///
/// Para tests, usa el constructor con dependencias inyectadas:
///
/// ```dart
/// final resolver = DevBaseUrl(
///   config: DevBaseUrlConfig(host: '', port: '3000'),
///   deviceDetector: FakeAndroidEmulator(),
///   platformOverride: FakeAndroidPlatform(),
/// );
/// ```
class DevBaseUrl {
  final Map<String, String> _cachePrepare = {};
  final Map<String, Future<String>> _cacheResolve = {};
  final Map<String, ({String host, String port, String scheme})>
      _resolvedInputs = {};
  final Set<String> _preparedKeys = {};
  final DevBaseUrlConfig _config;
  final DeviceDetectorOverride _deviceDetector;
  final TargetPlatformOverride _platformOverride;

  static const _defaultKey = 'default';
  static const _defaultScheme = 'http';

  /// Instancia de producción — lee configuración de `--dart-define-from-file`
  /// y usa detección real de plataforma.
  static final instance = DevBaseUrl._();

  DevBaseUrl._()
      : _config = DevBaseUrlConfig.fromEnvironment(),
        _deviceDetector = const RealDeviceDetector(),
        _platformOverride = const RealPlatformOverride();

  /// Constructor para tests — inyecta configuración y dependencias fake.
  ///
  /// Permite probar cualquier combinación de plataforma y configuración
  /// sin depender de `dart:io`, `device_info_plus`, ni constantes
  /// de compilación.
  ///
  /// ```dart
  /// final resolver = DevBaseUrl(
  ///   config: DevBaseUrlConfig(host: '', port: '3000'),
  ///   deviceDetector: FakeAndroidEmulator(),
  ///   platformOverride: FakeAndroidPlatform(),
  /// );
  /// ```
  @visibleForTesting
  DevBaseUrl({
    required DevBaseUrlConfig config,
    required DeviceDetectorOverride deviceDetector,
    required TargetPlatformOverride platformOverride,
  })  : _config = config,
        _deviceDetector = deviceDetector,
        _platformOverride = platformOverride;

  /// Resuelve y cachea la URL base del backend LAN bajo [key].
  ///
  /// Llama a este método **una sola vez por key** antes de inicializar
  /// tu contenedor de dependencias. Para acceder al resultado después
  /// usa [baseUrl].
  ///
  /// Los parámetros [host] y [port] tienen prioridad sobre los valores
  /// de `config.json`. Si se omiten, se usan los valores de
  /// `--dart-define-from-file`. [scheme] es `http` por defecto — usa
  /// `https` solo si tu entorno de desarrollo tiene TLS local.
  ///
  /// Throws [StateError] si:
  /// - Se llama más de una vez con la misma [key].
  /// - PORT es inválido.
  /// - HOST explícito es inválido (en cualquier plataforma).
  /// - Es dispositivo físico y HOST no está configurado.
  Future<void> prepare({
    String? host,
    int? port,
    String scheme = _defaultScheme,
    String key = _defaultKey,
  }) async {
    NetworkGuard.assertPrepareNotCalledTwice(
      _preparedKeys.contains(key),
      key: key,
    );
    // Marca la key ANTES del await — dos prepare() concurrentes con la
    // misma key deben fallar igual que dos prepare() secuenciales.
    _preparedKeys.add(key);
    try {
      final url = await resolveAsync(
        host: host,
        port: port,
        scheme: scheme,
        key: key,
      );
      NetworkWarnings.logResolvedUrl(url, key: key);
      _cachePrepare[key] = url;
    } catch (_) {
      _preparedKeys.remove(key);
      rethrow;
    }
  }

  /// Resuelve y retorna la URL base del backend LAN.
  ///
  /// La primera llamada detecta la plataforma, valida la configuración
  /// y cachea el resultado por [key]. Las siguientes retornan el valor
  /// cacheado sin recalcular — seguro llamarlo desde múltiples `create()`,
  /// incluso de forma concurrente.
  ///
  /// Si la [key] ya está resuelta y se pasan [host] o [port] distintos
  /// a los de la primera resolución, se emite una advertencia en consola
  /// y los parámetros nuevos se ignoran. Usa otra [key] para otro backend.
  ///
  /// Los parámetros [host] y [port] tienen prioridad sobre los valores
  /// de `config.json`. Si se omiten, se usan los valores de
  /// `--dart-define-from-file`. [scheme] es `http` por defecto — usa
  /// `https` solo si tu entorno de desarrollo tiene TLS local.
  ///
  /// Throws [StateError] si PORT es inválido, si HOST explícito es
  /// inválido, o si es dispositivo físico y HOST no está configurado.
  Future<String> resolveAsync({
    String? host,
    int? port,
    String scheme = _defaultScheme,
    String key = _defaultKey,
  }) {
    final trimmedHost = host?.trim();
    final resolvedHost = (trimmedHost != null && trimmedHost.isNotEmpty)
        ? trimmedHost
        : _config.host.trim();
    // Convierte int a String internamente — el dev pasa int, nosotros manejamos el resto
    final resolvedPort = port != null ? port.toString() : _config.port;

    final cached = _cacheResolve[key];
    if (cached != null) {
      final first = _resolvedInputs[key];
      final paramsProvided =
          host != null || port != null || scheme != _defaultScheme;
      final paramsDiffer = first != null &&
          (first.host != resolvedHost ||
              first.port != resolvedPort ||
              first.scheme != scheme);
      if (paramsProvided && paramsDiffer) {
        NetworkWarnings.warnParamsIgnoredOnCacheHit(key: key);
      }
      return cached;
    }

    final isPortExplicit = port != null || _config.isPortExplicitlyConfigured;

    // Cachea el Future, no el resultado — llamadas concurrentes con la
    // misma key comparten una sola resolución en vez de competir.
    final future = _resolve(
      host: resolvedHost,
      port: resolvedPort,
      scheme: scheme,
      isPortExplicit: isPortExplicit,
      key: key,
    );
    _cacheResolve[key] = future;
    _resolvedInputs[key] = (
      host: resolvedHost,
      port: resolvedPort,
      scheme: scheme,
    );
    return future;
  }

  /// URL resuelta síncronamente después de [prepare].
  ///
  /// Sin [key] retorna el backend por defecto registrado con [prepare].
  /// Con [key] retorna el backend específico.
  ///
  /// Solo [prepare] habilita el acceso síncrono — [resolveAsync] por sí
  /// solo no lo hace. Es el opt-in explícito al modo síncrono.
  ///
  /// ```dart
  /// // Backend por defecto
  /// resolver.baseUrl();
  ///
  /// // Backend específico
  /// resolver.baseUrl(key: 'media');
  /// ```
  ///
  /// Throws [StateError] si [prepare] no fue llamado con esa [key].
  String baseUrl({String key = _defaultKey}) {
    NetworkGuard.assertBaseUrlIsResolved(_cachePrepare[key], key: key);
    return _cachePrepare[key]!;
  }

  /// Limpia todos los cachés y keys preparadas.
  ///
  /// Útil en integration tests que usan [instance] y necesitan
  /// estado limpio entre tests. En unit tests prefiere instanciar
  /// un [DevBaseUrl] propio — cada instancia tiene su caché.
  @visibleForTesting
  void reset() {
    _cachePrepare.clear();
    _cacheResolve.clear();
    _resolvedInputs.clear();
    _preparedKeys.clear();
  }

  // ─── Internos ────────────────────────────────────────────────────────────

  /// Valida la configuración y construye la URL. Si algo falla, desaloja
  /// la entrada del caché — un intento fallido no debe envenenar los
  /// reintentos con parámetros corregidos.
  Future<String> _resolve({
    required String host,
    required String port,
    required String scheme,
    required bool isPortExplicit,
    required String key,
  }) async {
    try {
      NetworkGuard.validateScheme(scheme);
      NetworkGuard.validatePort(
        port,
        isPortExplicitlyConfigured: isPortExplicit,
      );

      final isRunningOnEmulator =
          await _deviceDetector.detectIfRunningOnEmulator();

      if (host.isNotEmpty) {
        // HOST explícito se valida en TODAS las plataformas — una URL
        // rota silenciosa es peor que un error temprano.
        NetworkGuard.assertHostIsValid(host);
        if (host.contains(':') && isPortExplicit) {
          NetworkWarnings.warnPortIgnoredBecauseHostHasPort(
            host: host,
            ignoredPort: port,
          );
        }
        _warnIfHostIsSuspicious(
          host: host,
          isRunningOnEmulator: isRunningOnEmulator,
        );
      } else if (!isRunningOnEmulator) {
        if (_platformOverride.isWeb || _platformOverride.isDesktop) {
          NetworkWarnings.warnHostFallbackToLocalhost();
        } else {
          // Dispositivo físico sin HOST — no existe fallback posible.
          NetworkGuard.assertHostIsValid(host);
        }
      }

      return _buildBaseUrl(
        isRunningOnEmulator: isRunningOnEmulator,
        host: host,
        port: port,
        scheme: scheme,
      );
    } catch (_) {
      unawaited(_cacheResolve.remove(key));
      _resolvedInputs.remove(key);
      rethrow;
    }
  }

  /// Advierte sobre HOSTs válidos sintácticamente pero que casi seguro
  /// no apuntan a donde el desarrollador cree en esta plataforma:
  ///
  /// - loopback en emulador Android → apunta al propio AVD
  /// - loopback en dispositivo físico → apunta al propio teléfono
  /// - `10.0.2.2` fuera del emulador Android → alias inexistente
  ///
  /// Advertencias, no errores: hay setups legítimos (adb reverse).
  void _warnIfHostIsSuspicious({
    required String host,
    required bool isRunningOnEmulator,
  }) {
    final hostOnly = host.split(':').first;
    final isLoopback = hostOnly == 'localhost' || hostOnly == '127.0.0.1';
    final isAndroidEmulator =
        _platformOverride.isAndroid && isRunningOnEmulator;
    final isPhysicalDevice = !isRunningOnEmulator &&
        !_platformOverride.isWeb &&
        !_platformOverride.isDesktop;

    if (isLoopback && isAndroidEmulator) {
      NetworkWarnings.warnLoopbackOnAndroidEmulator(host: host);
    } else if (isLoopback && isPhysicalDevice) {
      NetworkWarnings.warnLoopbackOnPhysicalDevice(host: host);
    }

    if (hostOnly == '10.0.2.2' && !isAndroidEmulator) {
      NetworkWarnings.warnAvdAliasOutsideAndroidEmulator(host: host);
    }
  }

  /// HOST explícito tiene prioridad en cualquier plataforma.
  /// Sin HOST, cada plataforma tiene su propia IP de acceso al host real.
  String _buildBaseUrl({
    required bool isRunningOnEmulator,
    required String host,
    required String port,
    required String scheme,
  }) {
    if (host.isNotEmpty) return '$scheme://${_withPort(host, port)}';

    if (_platformOverride.isWeb) return '$scheme://localhost:$port';

    // 10.0.2.2: alias del host real dentro de la red virtual del AVD
    if (_platformOverride.isAndroid && isRunningOnEmulator) {
      return '$scheme://10.0.2.2:$port';
    }

    // El simulador iOS comparte la interfaz de red de la Mac
    if (_platformOverride.isIOS && isRunningOnEmulator) {
      return '$scheme://127.0.0.1:$port';
    }

    // Desktop sin HOST / fallback: backend en la misma máquina
    return '$scheme://localhost:$port';
  }

  /// Si [host] ya incluye puerto (`"192.168.1.5:3000"`), lo respeta.
  /// Si no, concatena [port].
  static String _withPort(String host, String port) {
    return host.contains(':') ? host : '$host:$port';
  }
}
