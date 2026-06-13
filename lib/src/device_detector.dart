import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Contrato para detectar el tipo de dispositivo/entorno.
///
/// Implementa esta interfaz en tests para simular cualquier plataforma
/// sin depender de `dart:io` ni `device_info_plus`:
///
/// ```dart
/// class FakeAndroidEmulator implements DeviceDetectorOverride {
///   @override
///   Future<bool> detectIfRunningOnEmulator() async => true;
/// }
/// ```
abstract class DeviceDetectorOverride {
  /// `true` si la app corre en emulador Android o simulador iOS.
  Future<bool> detectIfRunningOnEmulator();
}

/// Contrato para detectar la plataforma de ejecución.
///
/// Implementa esta interfaz en tests para simular cualquier plataforma
/// sin depender de [Platform] ni de [kIsWeb]:
///
/// ```dart
/// class FakeAndroidPlatform implements TargetPlatformOverride {
///   @override bool get isWeb => false;
///   @override bool get isAndroid => true;
///   @override bool get isIOS => false;
///   @override bool get isDesktop => false;
/// }
/// ```
abstract class TargetPlatformOverride {
  /// `true` si la app corre en Flutter Web.
  bool get isWeb;

  /// `true` si la app corre en Android.
  bool get isAndroid;

  /// `true` si la app corre en iOS.
  bool get isIOS;

  /// `true` si la app corre en macOS, Windows o Linux.
  bool get isDesktop;
}

/// Implementación real de [DeviceDetectorOverride].
/// Usada internamente por [DevBaseUrl.instance].
class RealDeviceDetector implements DeviceDetectorOverride {
  /// Crea el detector real basado en `device_info_plus`.
  const RealDeviceDetector();

  /// `true` si la app corre en emulador Android o simulador iOS.
  ///
  /// - Flutter Web  → `false` (tiene su propia lógica de HOST)
  /// - Desktop      → `false` (tiene su propia lógica de HOST)
  /// - Android      → `true` si no es dispositivo físico
  /// - iOS          → `true` si no es dispositivo físico
  ///
  /// [kIsWeb] se evalúa antes de [Platform] porque `dart:io`
  /// no existe en Flutter Web.
  @override
  Future<bool> detectIfRunningOnEmulator() async {
    if (kIsWeb) return false;

    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return !androidInfo.isPhysicalDevice;
    }

    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return !iosInfo.isPhysicalDevice;
    }

    return false;
  }
}

/// Implementación real de [TargetPlatformOverride].
/// Usada internamente por [DevBaseUrl.instance].
///
/// [kIsWeb] se chequea antes que [Platform] en cada getter —
/// `Platform` lanza [UnsupportedError] en Flutter Web.
class RealPlatformOverride implements TargetPlatformOverride {
  /// Crea la implementación real basada en [kIsWeb] y [Platform].
  const RealPlatformOverride();

  @override
  bool get isWeb => kIsWeb;

  @override
  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  @override
  bool get isIOS => !kIsWeb && Platform.isIOS;

  @override
  bool get isDesktop =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);
}
