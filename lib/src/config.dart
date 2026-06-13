import 'constants.dart';

/// Configuración de HOST y PORT para el entorno LAN.
///
/// En producción usa [DevBaseUrlConfig.fromEnvironment] que lee los valores
/// de `--dart-define-from-file`. En tests, instancia directamente
/// con los valores que necesites:
///
/// ```dart
/// // Producción
/// final config = DevBaseUrlConfig.fromEnvironment();
///
/// // Tests — valores controlados, sin depender de constantes de compilación
/// final config = DevBaseUrlConfig(host: '192.168.1.5', port: '3000');
/// final configEmpty = DevBaseUrlConfig(host: '', port: '80');
/// ```
class DevBaseUrlConfig {
  /// Host del backend. Puede ser IP (`"192.168.1.5"`) o incluir
  /// puerto (`"192.168.1.5:3000"`). Vacío si no está configurado.
  final String host;

  /// Puerto del backend. Default `'80'` si no está configurado.
  final String port;

  /// `true` si PORT fue definido explícitamente en `config.json`.
  /// Usado para decidir si emitir advertencia de puerto default.
  ///
  /// Siempre `false` en tests — las constantes de compilación no
  /// están disponibles en ese entorno.
  final bool isPortExplicitlyConfigured;

  /// Crea una configuración con valores explícitos — pensado para tests.
  const DevBaseUrlConfig({
    required this.host,
    required this.port,
    this.isPortExplicitlyConfigured = false,
  });

  /// Lee HOST y PORT de las constantes de compilación
  /// (`--dart-define-from-file=config.json`).
  ///
  /// [isPortExplicitlyConfigured] será `true` solo si PORT fue
  /// definido en `config.json`.
  factory DevBaseUrlConfig.fromEnvironment() {
    return DevBaseUrlConfig(
      host: kEnvHost,
      port: kEnvPort,
      isPortExplicitlyConfigured: const bool.hasEnvironment(kKeyPort),
    );
  }
}
