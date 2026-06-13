import 'package:flutter/foundation.dart';

import 'network_warnings.dart';

/// Validaciones y guards para la configuración LAN.
///
/// Todos los [StateError] del paquete se lanzan desde aquí —
/// un solo lugar para encontrar qué puede fallar y por qué.
abstract class NetworkGuard {
  // ─── Colores ANSI ────────────────────────────────────────────────────────
  static const _reset = '\x1B[0m';
  static const _bold = '\x1B[1m';
  static const _red = '\x1B[31m';

  static const _top = '╔══════════════════════════════════════════╗';
  static const _mid = '╠══════════════════════════════════════════╣';
  static const _bot = '╚══════════════════════════════════════════╝';
  static const _header = '║  dev_base_url';

  /// Imprime el error estilizado en consola y lanza [StateError].
  ///
  /// El mensaje ANSI aparece en consola antes del stack trace —
  /// más legible que el mensaje plano del error.
  static Never _fail(String body, String errorMessage) {
    debugPrint('$_red$_bold$_top\n$_header\n$_mid\n$body\n$_bot$_reset');
    throw StateError(errorMessage);
  }

  /// Valida PORT y emite advertencia si se usa el default 80.
  ///
  /// - PORT vacío → lanza [StateError]
  /// - PORT no numérico o fuera de rango → lanza [StateError]
  /// - PORT válido y explícito → no hace nada
  /// - PORT default (no configurado) → advierte via [NetworkWarnings]
  ///
  /// [isPortExplicitlyConfigured] indica si PORT fue definido en
  /// `config.json` o pasado por parámetro directo.
  static void validatePort(
    String port, {
    required bool isPortExplicitlyConfigured,
  }) {
    if (port.trim().isEmpty) {
      _fail(
        '║  ✖ PORT no puede ser una cadena vacía\n'
            '║\n'
            '║  Configúralo por parámetro:\n'
            '║    DevBaseUrl.instance.prepare(port: 3000)\n'
            '║\n'
            '║  O en config.json:\n'
            '║    { "PORT": "3000" }',
        'PORT no puede ser una cadena vacía.',
      );
    }

    final portNumber = int.tryParse(port.trim());

    if (portNumber == null || portNumber < 1 || portNumber > 65535) {
      _fail(
        '║  ✖ PORT "$port" no es válido\n'
            '║\n'
            '║  Debe ser un número entero entre 1 y 65535.\n'
            '║\n'
            '║  Configúralo por parámetro:\n'
            '║    DevBaseUrl.instance.prepare(port: 3000)\n'
            '║\n'
            '║  O en config.json:\n'
            '║    { "PORT": "3000" }',
        'PORT "$port" no es válido. Debe ser un número entre 1 y 65535.',
      );
    }

    if (!isPortExplicitlyConfigured) {
      NetworkWarnings.warnIfPortIsDefault();
    }
  }

  /// Valida que [value] sea una IPv4 válida o "localhost",
  /// con puerto opcional.
  ///
  /// Válidos:   `192.168.1.5`, `localhost`, `10.0.0.2:3000`
  /// Inválidos: `mi-servidor`, `256.0.0.1`, `192.168.1.5:3000:extra`
  static bool isValidHostOrIp(String value) {
    final segments = value.split(':');
    if (segments.length > 2) return false;

    final hostPart = segments[0];
    final portPart = segments.length == 2 ? segments[1] : null;

    final ipv4Pattern = RegExp(
      r'^((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}'
      r'(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$',
    );

    final isHostValid =
        ipv4Pattern.hasMatch(hostPart) || hostPart == 'localhost';
    if (!isHostValid) return false;

    if (portPart == null) return true;

    final portNumber = int.tryParse(portPart);
    return portNumber != null && portNumber >= 1 && portNumber <= 65535;
  }

  /// Lanza [StateError] si [scheme] no es `http` ni `https`.
  static void validateScheme(String scheme) {
    if (scheme != 'http' && scheme != 'https') {
      _fail(
        '║  ✖ SCHEME "$scheme" no es válido\n'
            '║\n'
            '║  Solo se admite "http" o "https":\n'
            '║    prepare(port: 3000, scheme: "https")',
        'SCHEME "$scheme" no es válido. Usa "http" o "https".',
      );
    }
  }

  /// Lanza [StateError] si HOST es inválido o está vacío.
  ///
  /// Un HOST explícito se valida en **todas** las plataformas — una URL
  /// rota silenciosa es peor que un error temprano. El HOST vacío solo
  /// es error en dispositivo físico (el resto tiene fallback automático).
  ///
  /// Si HOST incluye un scheme (`http://...`) — error típico de
  /// copy-paste — el mensaje lo dice explícitamente en vez del
  /// genérico "no es válido".
  static void assertHostIsValid(String host) {
    if (host.contains('://')) {
      _fail(
        '║  ✖ HOST "$host" no debe incluir el scheme\n'
            '║\n'
            '║  HOST es solo la IP o localhost, con puerto opcional.\n'
            '║  El scheme se configura aparte:\n'
            '║    prepare(host: "192.168.1.5", scheme: "https")',
        'HOST "$host" no debe incluir el scheme (http:// / https://).',
      );
    }
    if (host.isEmpty || !isValidHostOrIp(host)) {
      _fail(
        '║  ✖ HOST "${host.isEmpty ? '<vacío>' : host}" no es válido\n'
            '║\n'
            '${host.isEmpty ? '║  En dispositivo físico no existe IP automática.\n' : '║  Debe ser una IPv4 o localhost, con puerto opcional.\n'}'
            '║\n'
            '║  Configúralo por parámetro:\n'
            '║    DevBaseUrl.instance.prepare(\n'
            '║      host: "192.168.1.5",\n'
            '║      port: 3000,\n'
            '║    )\n'
            '║\n'
            '║  O en config.json:\n'
            '║    {\n'
            '║      "HOST": "192.168.1.5",   ← IP del backend en tu LAN\n'
            '║      "PORT": "3000"\n'
            '║    }\n'
            '║\n'
            '║  Valores válidos:\n'
            '║    192.168.x.x / 10.x.x.x / localhost\n'
            '║\n'
            '║  ⚠ NO uses localhost si el backend está en otra máquina.',
        'HOST "${host.isEmpty ? '<vacío>' : host}" no está definido o es inválido.',
      );
    }
  }

  /// Lanza [StateError] si [DevBaseUrl.prepare] fue llamado
  /// más de una vez con la misma [key].
  static void assertPrepareNotCalledTwice(
    bool alreadyPrepared, {
    required String key,
  }) {
    if (alreadyPrepared) {
      _fail(
        '║  ✖ prepare(key: "$key") llamado más de una vez\n'
            '║\n'
            '║  prepare() debe llamarse una sola vez por key antes\n'
            '║  de inicializar tu contenedor de dependencias.\n'
            '║\n'
            '║  Si necesitas la URL en múltiples lugares usa:\n'
            '║    final url = await DevBaseUrl.instance\n'
            '║        .resolveAsync(port: 3000);\n'
            '║\n'
            '║  Si es otro backend, usa una key distinta:\n'
            '║    prepare(port: 3000, key: "media")',
        'DevBaseUrl.prepare() fue llamado más de una vez con key: "$key".',
      );
    }
  }

  /// Lanza [StateError] si [DevBaseUrl.baseUrl] fue accedido
  /// antes de [DevBaseUrl.prepare].
  static void assertBaseUrlIsResolved(String? cache, {String key = 'default'}) {
    if (cache == null) {
      _fail(
        '║  ✖ baseUrl(key: "$key") accedido antes de prepare()\n'
            '║\n'
            '║  Solución:\n'
            '║    await DevBaseUrl.instance.prepare(\n'
            '║      port: 3000,\n'
            '║      key: "$key",\n'
            '║    );',
        'baseUrl(key: "$key") accedido antes de prepare().',
      );
    }
  }
}
