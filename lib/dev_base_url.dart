/// dev_base_url
///
/// Resuelve la URL base de tu backend de desarrollo según la plataforma
/// donde corre tu app Flutter — emulador, simulador, web, desktop o físico.
library;

// Configuración — inyectable para tests
export 'src/config.dart';
// Contratos de plataforma — exportados para que los devs
// puedan implementar sus propios fakes en tests
export 'src/device_detector.dart'
    show
        DeviceDetectorOverride,
        TargetPlatformOverride,
        RealDeviceDetector,
        RealPlatformOverride;
// API pública del paquete
export 'src/resolver.dart' show DevBaseUrl;

// Internos — no exportados, detalles de implementación
// constants.dart
// network_guard.dart
// network_warnings.dart
