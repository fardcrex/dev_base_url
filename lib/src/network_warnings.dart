import 'package:flutter/foundation.dart';

/// Mensajes en consola para el desarrollador sobre la configuración LAN.
///
/// Usa ANSI para colorear — renderiza en VS Code y Android Studio.
/// Se elimina automáticamente en release builds via [debugPrint].
abstract class NetworkWarnings {
  static const _package = 'dev_base_url';

  // ─── Colores ANSI ────────────────────────────────────────────────────────
  static const _reset = '\x1B[0m';
  static const _bold = '\x1B[1m';
  static const _green = '\x1B[32m';
  static const _yellow = '\x1B[33m';

  // ─── Bordes ──────────────────────────────────────────────────────────────
  static const _top = '╔══════════════════════════════════════════╗';
  static const _mid = '╠══════════════════════════════════════════╣';
  static const _bot = '╚══════════════════════════════════════════╝';
  static const _header = '║  $_package';

  static void _print(String color, String body) {
    debugPrint('$color$_bold$_top\n$_header\n$_mid\n$body\n$_bot$_reset');
  }

  /// Advierte cuando PORT no fue configurado explícitamente y se usa
  /// el puerto 80 por defecto.
  ///
  /// En desarrollo casi nunca el backend corre en el puerto 80 —
  /// un error de conexión por puerto incorrecto es silencioso y confuso.
  ///
  /// Para silenciar esta advertencia, configura PORT:
  ///
  ///   Por parámetro:   `DevBaseUrl.instance.prepare(port: 3000)`
  ///   Por config.json: `{ "PORT": "3000" }`
  static void warnIfPortIsDefault() {
    _print(
      _yellow,
      '║  ⚠ PORT no configurado → puerto 80 por defecto\n'
      '║\n'
      '║  Si tu backend corre en otro puerto, configúralo:\n'
      '║\n'
      '║    Por parámetro:\n'
      '║      DevBaseUrl.instance.prepare(port: 3000)\n'
      '║\n'
      '║    O en config.json:\n'
      '║      {\n'
      '║        "HOST": "192.168.1.5",\n'
      '║        "PORT": "3000"          ← agrega esta línea\n'
      '║      }\n'
      '║\n'
      '║    Pásalo al compilador con:\n'
      '║      flutter run --dart-define-from-file=config.json',
    );
  }

  /// Advierte cuando HOST no fue configurado en Web o Desktop
  /// y se usará localhost como fallback.
  ///
  /// Web y Desktop siempre corren en la misma máquina de desarrollo,
  /// pero el backend puede estar en otra PC de la LAN.
  ///
  /// Para silenciar esta advertencia, configura HOST:
  ///
  ///   Por parámetro:   `DevBaseUrl.instance.prepare(host: '192.168.1.5')`
  ///   Por config.json: `{ "HOST": "192.168.1.5", "PORT": "3000" }`
  static void warnHostFallbackToLocalhost() {
    _print(
      _yellow,
      '║  ⚠ HOST no configurado → usando localhost por defecto\n'
      '║\n'
      '║  Esto funciona si el backend corre en esta misma máquina.\n'
      '║  Si el backend corre en otra PC de la LAN, configúralo:\n'
      '║\n'
      '║    Por parámetro:\n'
      '║      DevBaseUrl.instance.prepare(host: "192.168.1.5")\n'
      '║\n'
      '║    O en config.json:\n'
      '║      {\n'
      '║        "HOST": "192.168.1.5",   ← IP de la PC con el backend\n'
      '║        "PORT": "3000"\n'
      '║      }\n'
      '║\n'
      '║    Pásalo al compilador con:\n'
      '║      flutter run --dart-define-from-file=config.json',
    );
  }

  /// Advierte cuando HOST es `localhost`/`127.0.0.1` en el emulador
  /// Android — ahí el loopback apunta al propio AVD, no a tu máquina.
  ///
  /// Error típico al compartir `config.json` entre plataformas:
  /// funciona en desktop/web y rompe silenciosamente en el emulador.
  static void warnLoopbackOnAndroidEmulator({required String host}) {
    _print(
      _yellow,
      '║  ⚠ HOST "$host" apunta al propio emulador\n'
      '║\n'
      '║  Dentro del AVD, localhost/127.0.0.1 es el emulador\n'
      '║  mismo — no tu máquina de desarrollo.\n'
      '║\n'
      '║  Si el backend corre en tu máquina, quita HOST:\n'
      '║  el paquete usa 10.0.2.2 automáticamente.\n'
      '║\n'
      '║  Si está en otra PC, usa su IP LAN:\n'
      '║    { "HOST": "192.168.1.5" }',
    );
  }

  /// Advierte cuando HOST es `localhost`/`127.0.0.1` en dispositivo
  /// físico — ahí el loopback apunta al propio teléfono.
  ///
  /// Solo es válido si el desarrollador configuró un túnel
  /// (`adb reverse tcp:PORT tcp:PORT`) — por eso advierte y no falla.
  static void warnLoopbackOnPhysicalDevice({required String host}) {
    _print(
      _yellow,
      '║  ⚠ HOST "$host" apunta al propio dispositivo\n'
      '║\n'
      '║  En un teléfono físico, localhost/127.0.0.1 es el\n'
      '║  teléfono mismo — no tu máquina de desarrollo.\n'
      '║\n'
      '║  Usa la IP LAN de la máquina con el backend:\n'
      '║    { "HOST": "192.168.1.5" }\n'
      '║\n'
      '║  (Ignora esto si configuraste un túnel con\n'
      '║   adb reverse tcp:3000 tcp:3000)',
    );
  }

  /// Advierte cuando HOST es `10.0.2.2` fuera del emulador Android —
  /// ese alias solo existe dentro de la red virtual del AVD.
  static void warnAvdAliasOutsideAndroidEmulator({required String host}) {
    _print(
      _yellow,
      '║  ⚠ HOST "$host" no funcionará en esta plataforma\n'
      '║\n'
      '║  10.0.2.2 solo funciona dentro del emulador Android —\n'
      '║  es el alias del host real en la red virtual del AVD.\n'
      '║\n'
      '║  Quita HOST (el paquete resuelve el correcto por\n'
      '║  plataforma) o usa la IP LAN de tu máquina:\n'
      '║    { "HOST": "192.168.1.5" }',
    );
  }

  /// Advierte cuando HOST ya incluye puerto y además se configuró
  /// PORT explícitamente — el puerto embebido en HOST tiene prioridad.
  ///
  /// Sin esta advertencia el desarrollador podría cambiar PORT y no
  /// entender por qué la URL sigue apuntando al puerto anterior.
  static void warnPortIgnoredBecauseHostHasPort({
    required String host,
    required String ignoredPort,
  }) {
    final hostWithoutPort = host.split(':').first;
    _print(
      _yellow,
      '║  ⚠ HOST ya incluye puerto → PORT ignorado\n'
      '║\n'
      '║  HOST          → $host\n'
      '║  PORT ignorado → $ignoredPort\n'
      '║\n'
      '║  El puerto embebido en HOST tiene prioridad.\n'
      '║  Si quieres usar PORT, quita el puerto de HOST:\n'
      '║    {\n'
      '║      "HOST": "$hostWithoutPort",\n'
      '║      "PORT": "$ignoredPort"\n'
      '║    }',
    );
  }

  /// Advierte cuando se llama a `resolveAsync()` o `prepare()` con
  /// parámetros distintos a los usados en la primera resolución de [key].
  ///
  /// La URL ya está cacheada — los parámetros nuevos se ignoran.
  /// Sin esta advertencia el desarrollador creería que su nuevo
  /// host/port se aplicó cuando en realidad recibe el valor anterior.
  static void warnParamsIgnoredOnCacheHit({required String key}) {
    _print(
      _yellow,
      '║  ⚠ Parámetros ignorados — key "$key" ya resuelta\n'
      '║\n'
      '║  La primera resolución de una key cachea su URL.\n'
      '║  Las llamadas posteriores retornan ese valor y\n'
      '║  los parámetros host/port nuevos se descartan.\n'
      '║\n'
      '║  Si es otro backend, usa una key distinta:\n'
      '║    resolveAsync(host: "...", port: ..., key: "media")',
    );
  }

  /// Confirma que la URL del backend LAN fue resuelta correctamente.
  static void logResolvedUrl(String url, {String key = 'default'}) {
    _print(
      _green,
      '║  ✓ Backend LAN resuelto\n'
      '║  key → $key\n'
      '║  url → $url',
    );
  }
}
