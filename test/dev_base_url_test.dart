import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dev_base_url/dev_base_url.dart';

// ─── Fakes de plataforma ────────────────────────────────────────────────────

class _FakeEmulator implements DeviceDetectorOverride {
  @override
  Future<bool> detectIfRunningOnEmulator() async => true;
}

class _FakePhysicalDevice implements DeviceDetectorOverride {
  @override
  Future<bool> detectIfRunningOnEmulator() async => false;
}

class _FakeAndroid implements TargetPlatformOverride {
  @override
  bool get isWeb => false;
  @override
  bool get isAndroid => true;
  @override
  bool get isIOS => false;
  @override
  bool get isDesktop => false;
}

class _FakeIOS implements TargetPlatformOverride {
  @override
  bool get isWeb => false;
  @override
  bool get isAndroid => false;
  @override
  bool get isIOS => true;
  @override
  bool get isDesktop => false;
}

class _FakeDesktop implements TargetPlatformOverride {
  @override
  bool get isWeb => false;
  @override
  bool get isAndroid => false;
  @override
  bool get isIOS => false;
  @override
  bool get isDesktop => true;
}

class _FakeWeb implements TargetPlatformOverride {
  @override
  bool get isWeb => true;
  @override
  bool get isAndroid => false;
  @override
  bool get isIOS => false;
  @override
  bool get isDesktop => false;
}

class _FakePhysicalAndroid implements TargetPlatformOverride {
  @override
  bool get isWeb => false;
  @override
  bool get isAndroid => true;
  @override
  bool get isIOS => false;
  @override
  bool get isDesktop => false;
}

// ─── Helper ─────────────────────────────────────────────────────────────────

DevBaseUrl _resolver({
  String host = '',
  String configPort = '3000', // port en DevBaseUrlConfig sigue siendo String
  bool isPortExplicit = true,
  DeviceDetectorOverride? deviceDetector,
  TargetPlatformOverride? platformOverride,
}) {
  return DevBaseUrl(
    config: DevBaseUrlConfig(
      host: host,
      port: configPort,
      isPortExplicitlyConfigured: isPortExplicit,
    ),
    deviceDetector: deviceDetector ?? _FakePhysicalDevice(),
    platformOverride: platformOverride ?? _FakeDesktop(),
  );
}

// ─── Tests ──────────────────────────────────────────────────────────────────

void main() {
  group('Android Emulator', () {
    test('sin HOST → 10.0.2.2', () async {
      final url = await _resolver(
        deviceDetector: _FakeEmulator(),
        platformOverride: _FakeAndroid(),
      ).resolveAsync();
      expect(url, 'http://10.0.2.2:3000');
    });

    test('con HOST explícito → usa HOST (backend en otra PC)', () async {
      final url = await _resolver(
        host: '192.168.1.50',
        deviceDetector: _FakeEmulator(),
        platformOverride: _FakeAndroid(),
      ).resolveAsync();
      expect(url, 'http://192.168.1.50:3000');
    });
  });

  group('iOS Simulator', () {
    test('sin HOST → 127.0.0.1', () async {
      final url = await _resolver(
        deviceDetector: _FakeEmulator(),
        platformOverride: _FakeIOS(),
      ).resolveAsync();
      expect(url, 'http://127.0.0.1:3000');
    });

    test('con HOST explícito → usa HOST', () async {
      final url = await _resolver(
        host: '192.168.1.50',
        deviceDetector: _FakeEmulator(),
        platformOverride: _FakeIOS(),
      ).resolveAsync();
      expect(url, 'http://192.168.1.50:3000');
    });
  });

  group('Desktop', () {
    test('sin HOST → localhost', () async {
      final url = await _resolver(
        deviceDetector: _FakePhysicalDevice(),
        platformOverride: _FakeDesktop(),
      ).resolveAsync();
      expect(url, 'http://localhost:3000');
    });

    test('con HOST → usa HOST (backend en otra PC de la LAN)', () async {
      final url = await _resolver(
        host: '192.168.1.5',
        deviceDetector: _FakePhysicalDevice(),
        platformOverride: _FakeDesktop(),
      ).resolveAsync();
      expect(url, 'http://192.168.1.5:3000');
    });
  });

  group('Dispositivo físico', () {
    test('con HOST válido → construye URL correcta', () async {
      final url = await _resolver(
        host: '192.168.1.5',
        deviceDetector: _FakePhysicalDevice(),
        platformOverride: _FakePhysicalAndroid(),
      ).resolveAsync();
      expect(url, 'http://192.168.1.5:3000');
    });

    test('sin HOST → StateError', () async {
      expect(
        () => _resolver(
          host: '',
          deviceDetector: _FakePhysicalDevice(),
          platformOverride: _FakePhysicalAndroid(),
        ).resolveAsync(),
        throwsStateError,
      );
    });

    test('HOST inválido → StateError', () async {
      expect(
        () => _resolver(
          host: 'mi-servidor',
          deviceDetector: _FakePhysicalDevice(),
          platformOverride: _FakePhysicalAndroid(),
        ).resolveAsync(),
        throwsStateError,
      );
    });
  });

  group('HOST con puerto incluido', () {
    test('HOST con puerto → PORT ignorado', () async {
      final url = await _resolver(
        host: '192.168.1.5:8080',
        configPort: '3000',
      ).resolveAsync();
      expect(url, 'http://192.168.1.5:8080');
    });

    test('HOST con puerto + PORT explícito → advierte el conflicto', () async {
      final logs = <String>[];
      final original = debugPrint;
      debugPrint =
          (String? message, {int? wrapWidth}) => logs.add(message ?? '');
      try {
        await _resolver(
          host: '192.168.1.5:8080',
          configPort: '3000',
        ).resolveAsync();
        expect(logs.join('\n'), contains('ya incluye puerto'));
      } finally {
        debugPrint = original;
      }
    });

    test('HOST sin puerto + PORT explícito → no advierte conflicto', () async {
      final logs = <String>[];
      final original = debugPrint;
      debugPrint =
          (String? message, {int? wrapWidth}) => logs.add(message ?? '');
      try {
        await _resolver(host: '192.168.1.5').resolveAsync();
        expect(logs.join('\n'), isNot(contains('ya incluye puerto')));
      } finally {
        debugPrint = original;
      }
    });

    test(
        'HOST con puerto + PORT default (no explícito) → no advierte '
        'conflicto', () async {
      final logs = <String>[];
      final original = debugPrint;
      debugPrint =
          (String? message, {int? wrapWidth}) => logs.add(message ?? '');
      try {
        await _resolver(
          host: '192.168.1.5:8080',
          configPort: '80',
          isPortExplicit: false,
        ).resolveAsync();
        expect(logs.join('\n'), isNot(contains('ya incluye puerto')));
      } finally {
        debugPrint = original;
      }
    });
  });

  group('HOST sospechoso — advertencias semánticas', () {
    Future<String> capturedLogs(Future<void> Function() body) async {
      final logs = <String>[];
      final original = debugPrint;
      debugPrint =
          (String? message, {int? wrapWidth}) => logs.add(message ?? '');
      try {
        await body();
      } finally {
        debugPrint = original;
      }
      return logs.join('\n');
    }

    test('localhost en emulador Android → advierte (apunta al AVD)', () async {
      final logs = await capturedLogs(() async {
        await _resolver(
          host: 'localhost',
          deviceDetector: _FakeEmulator(),
          platformOverride: _FakeAndroid(),
        ).resolveAsync();
      });
      expect(logs, contains('propio emulador'));
    });

    test('127.0.0.1 con puerto en emulador Android → advierte', () async {
      final logs = await capturedLogs(() async {
        await _resolver(
          host: '127.0.0.1:3000',
          deviceDetector: _FakeEmulator(),
          platformOverride: _FakeAndroid(),
        ).resolveAsync();
      });
      expect(logs, contains('propio emulador'));
    });

    test('localhost en simulador iOS → NO advierte (comparte red)', () async {
      final logs = await capturedLogs(() async {
        await _resolver(
          host: 'localhost',
          deviceDetector: _FakeEmulator(),
          platformOverride: _FakeIOS(),
        ).resolveAsync();
      });
      expect(logs, isNot(contains('propio emulador')));
      expect(logs, isNot(contains('propio dispositivo')));
    });

    test('localhost en dispositivo físico → advierte (apunta al teléfono)',
        () async {
      final logs = await capturedLogs(() async {
        await _resolver(
          host: 'localhost',
          deviceDetector: _FakePhysicalDevice(),
          platformOverride: _FakePhysicalAndroid(),
        ).resolveAsync();
      });
      expect(logs, contains('propio dispositivo'));
    });

    test('IP LAN en dispositivo físico → no advierte', () async {
      final logs = await capturedLogs(() async {
        await _resolver(
          host: '192.168.1.5',
          deviceDetector: _FakePhysicalDevice(),
          platformOverride: _FakePhysicalAndroid(),
        ).resolveAsync();
      });
      expect(logs, isNot(contains('propio dispositivo')));
    });

    test('10.0.2.2 en simulador iOS → advierte (alias solo del AVD)', () async {
      final logs = await capturedLogs(() async {
        await _resolver(
          host: '10.0.2.2',
          deviceDetector: _FakeEmulator(),
          platformOverride: _FakeIOS(),
        ).resolveAsync();
      });
      expect(logs, contains('solo funciona dentro del emulador Android'));
    });

    test('10.0.2.2 en dispositivo físico → advierte', () async {
      final logs = await capturedLogs(() async {
        await _resolver(
          host: '10.0.2.2',
          deviceDetector: _FakePhysicalDevice(),
          platformOverride: _FakePhysicalAndroid(),
        ).resolveAsync();
      });
      expect(logs, contains('solo funciona dentro del emulador Android'));
    });

    test('10.0.2.2 en emulador Android → no advierte (es su alias)', () async {
      final logs = await capturedLogs(() async {
        await _resolver(
          host: '10.0.2.2',
          deviceDetector: _FakeEmulator(),
          platformOverride: _FakeAndroid(),
        ).resolveAsync();
      });
      expect(
        logs,
        isNot(contains('solo funciona dentro del emulador Android')),
      );
    });
  });

  group('HOST con scheme incluido', () {
    test('host "http://..." → StateError con hint de scheme', () async {
      expect(
        () => _resolver(host: 'http://192.168.1.5').resolveAsync(),
        throwsA(
          isA<StateError>()
              .having((e) => e.message, 'message', contains('scheme')),
        ),
      );
    });

    test('host "https://..." → StateError con hint de scheme', () async {
      expect(
        () => _resolver(host: 'https://192.168.1.5:3000').resolveAsync(),
        throwsA(
          isA<StateError>()
              .having((e) => e.message, 'message', contains('scheme')),
        ),
      );
    });
  });

  group('Scheme — validación', () {
    test('scheme inválido → StateError', () async {
      expect(
        () => _resolver().resolveAsync(scheme: 'ftp'),
        throwsA(
          isA<StateError>()
              .having((e) => e.message, 'message', contains('SCHEME')),
        ),
      );
    });

    test('scheme http y https → no lanzan', () async {
      await expectLater(
        _resolver().resolveAsync(scheme: 'http', key: 'a'),
        completes,
      );
      await expectLater(
        _resolver().resolveAsync(scheme: 'https', key: 'b'),
        completes,
      );
    });
  });

  group('PORT — desde config (String interno)', () {
    test('PORT inválido en config → StateError', () async {
      expect(
        () => _resolver(configPort: 'abc').resolveAsync(),
        throwsStateError,
      );
    });

    test('PORT fuera de rango en config → StateError', () async {
      expect(
        () => _resolver(configPort: '99999').resolveAsync(),
        throwsStateError,
      );
    });

    test('PORT vacío en config → StateError', () async {
      expect(() => _resolver(configPort: '').resolveAsync(), throwsStateError);
    });

    test('PORT válido en config → no lanza', () async {
      expect(
        () => _resolver(configPort: '3000').resolveAsync(),
        returnsNormally,
      );
    });
  });

  group('PORT — desde parámetro (int público)', () {
    test('PORT por parámetro sobreescribe config', () async {
      final url = await _resolver(configPort: '8080').resolveAsync(port: 9000);
      expect(url, 'http://localhost:9000');
    });

    test('PORT por parámetro válido → no lanza', () async {
      expect(() => _resolver().resolveAsync(port: 4000), returnsNormally);
    });
  });

  group('Caché por key', () {
    test('resolveAsync misma key dos veces → retorna mismo valor', () async {
      final resolver = _resolver();
      final url1 = await resolver.resolveAsync();
      final url2 = await resolver.resolveAsync();
      expect(url1, url2);
    });

    test('keys distintas → URLs independientes', () async {
      final resolver = DevBaseUrl(
        config: DevBaseUrlConfig(
          host: '',
          port: '3000',
          isPortExplicitlyConfigured: true,
        ),
        deviceDetector: _FakePhysicalDevice(),
        platformOverride: _FakeDesktop(),
      );

      final url1 = await resolver.resolveAsync(
        host: '192.168.1.45',
        port: 2000,
        key: 'auth',
      );
      final url2 = await resolver.resolveAsync(
        host: '192.168.1.50',
        port: 3000,
        key: 'media',
      );

      expect(url1, 'http://192.168.1.45:2000');
      expect(url2, 'http://192.168.1.50:3000');
    });

    test('key default sin prepare → StateError en baseUrl', () {
      expect(() => _resolver().baseUrl(), throwsStateError);
    });

    test('key específica sin prepare → StateError en baseUrl', () {
      expect(() => _resolver().baseUrl(key: 'auth'), throwsStateError);
    });

    test('prepare() → baseUrl() disponible síncronamente', () async {
      final resolver = _resolver();
      await resolver.prepare();
      expect(resolver.baseUrl(), isNotEmpty);
    });

    test('prepare() con key → baseUrl(key:) disponible', () async {
      final resolver = DevBaseUrl(
        config: DevBaseUrlConfig(
          host: '',
          port: '3000',
          isPortExplicitlyConfigured: true,
        ),
        deviceDetector: _FakePhysicalDevice(),
        platformOverride: _FakeDesktop(),
      );
      await resolver.prepare(host: '192.168.1.45', port: 2000, key: 'auth');
      expect(resolver.baseUrl(key: 'auth'), 'http://192.168.1.45:2000');
    });

    test('prepare() misma key dos veces → StateError', () async {
      final resolver = _resolver();
      await resolver.prepare();
      expect(() => resolver.prepare(), throwsStateError);
    });

    test('prepare() misma key específica dos veces → StateError', () async {
      final resolver = _resolver();
      await resolver.prepare(key: 'auth');
      expect(() => resolver.prepare(key: 'auth'), throwsStateError);
    });

    test('prepare() keys distintas → no lanza', () async {
      final resolver = DevBaseUrl(
        config: DevBaseUrlConfig(
          host: '',
          port: '3000',
          isPortExplicitlyConfigured: true,
        ),
        deviceDetector: _FakePhysicalDevice(),
        platformOverride: _FakeDesktop(),
      );
      await resolver.prepare(key: 'auth');
      expect(() => resolver.prepare(key: 'media'), returnsNormally);
    });
  });

  group('Parámetros vs config', () {
    test('host por parámetro tiene prioridad sobre config', () async {
      final url = await DevBaseUrl(
        config: DevBaseUrlConfig(
          host: '192.168.1.5',
          port: '3000',
          isPortExplicitlyConfigured: true,
        ),
        deviceDetector: _FakePhysicalDevice(),
        platformOverride: _FakeDesktop(),
      ).resolveAsync(host: '10.0.0.55');
      expect(url, 'http://10.0.0.55:3000');
    });

    test('port por parámetro tiene prioridad sobre config', () async {
      final url = await DevBaseUrl(
        config: DevBaseUrlConfig(
          host: '',
          port: '8080',
          isPortExplicitlyConfigured: true,
        ),
        deviceDetector: _FakePhysicalDevice(),
        platformOverride: _FakeDesktop(),
      ).resolveAsync(port: 9000);
      expect(url, 'http://localhost:9000');
    });
  });

  group('Flutter Web', () {
    test('sin HOST → localhost', () async {
      final url = await _resolver(
        deviceDetector: _FakePhysicalDevice(),
        platformOverride: _FakeWeb(),
      ).resolveAsync();
      expect(url, 'http://localhost:3000');
    });

    test('con HOST explícito → usa HOST', () async {
      final url = await _resolver(
        host: '192.168.1.50',
        deviceDetector: _FakePhysicalDevice(),
        platformOverride: _FakeWeb(),
      ).resolveAsync();
      expect(url, 'http://192.168.1.50:3000');
    });

    test('con HOST inválido → StateError', () async {
      expect(
        () => _resolver(
          host: 'mi-servidor',
          deviceDetector: _FakePhysicalDevice(),
          platformOverride: _FakeWeb(),
        ).resolveAsync(),
        throwsStateError,
      );
    });
  });

  group('HOST — validación en todas las plataformas', () {
    test('emulador Android con HOST inválido → StateError', () async {
      expect(
        () => _resolver(
          host: 'mi-servidor',
          deviceDetector: _FakeEmulator(),
          platformOverride: _FakeAndroid(),
        ).resolveAsync(),
        throwsStateError,
      );
    });

    test('desktop con HOST fuera de rango → StateError', () async {
      expect(
        () => _resolver(host: '256.0.0.1').resolveAsync(),
        throwsStateError,
      );
    });

    test('desktop con HOST con puerto vacío ("ip:") → StateError', () async {
      expect(
        () => _resolver(host: '192.168.1.5:').resolveAsync(),
        throwsStateError,
      );
    });

    test('HOST con puerto 0 embebido → StateError', () async {
      expect(
        () => _resolver(host: '192.168.1.5:0').resolveAsync(),
        throwsStateError,
      );
    });

    test('HOST con puerto embebido fuera de rango → StateError', () async {
      expect(
        () => _resolver(host: '192.168.1.5:99999').resolveAsync(),
        throwsStateError,
      );
    });

    test('HOST con espacios alrededor → se trimea', () async {
      final url = await _resolver().resolveAsync(host: ' 192.168.1.5 ');
      expect(url, 'http://192.168.1.5:3000');
    });
  });

  group('Caché — coherencia y concurrencia', () {
    test(
      'resolveAsync con params distintos al caché → advierte y retorna caché',
      () async {
        final logs = <String>[];
        final original = debugPrint;
        debugPrint =
            (String? message, {int? wrapWidth}) => logs.add(message ?? '');
        try {
          final resolver = _resolver();
          final first = await resolver.resolveAsync(port: 3000);
          final second = await resolver.resolveAsync(port: 9999);
          expect(second, first);
          expect(logs.join('\n'), contains('ignorados'));
        } finally {
          debugPrint = original;
        }
      },
    );

    test('resolveAsync con los mismos params → no advierte', () async {
      final logs = <String>[];
      final original = debugPrint;
      debugPrint =
          (String? message, {int? wrapWidth}) => logs.add(message ?? '');
      try {
        final resolver = _resolver();
        await resolver.resolveAsync(port: 3000);
        await resolver.resolveAsync(port: 3000);
        expect(logs.join('\n'), isNot(contains('ignorados')));
      } finally {
        debugPrint = original;
      }
    });

    test(
      'prepare tras resolveAsync con params distintos → advierte, no falla silenciosamente',
      () async {
        final logs = <String>[];
        final original = debugPrint;
        debugPrint =
            (String? message, {int? wrapWidth}) => logs.add(message ?? '');
        try {
          final resolver = _resolver();
          await resolver.resolveAsync(port: 3000);
          await resolver.prepare(port: 9999);
          expect(resolver.baseUrl(), 'http://localhost:3000');
          expect(logs.join('\n'), contains('ignorados'));
        } finally {
          debugPrint = original;
        }
      },
    );

    test('resolveAsync concurrente misma key → una sola resolución', () async {
      final resolver = _resolver();
      final urls = await Future.wait([
        resolver.resolveAsync(port: 3000),
        resolver.resolveAsync(port: 9999),
      ]);
      expect(urls[0], urls[1]);
    });

    test('prepare concurrente misma key → solo uno gana', () async {
      final resolver = _resolver();
      final outcomes = await Future.wait([
        resolver
            .prepare(port: 3000)
            .then((_) => 'ok')
            .catchError((_) => 'error'),
        resolver
            .prepare(port: 3000)
            .then((_) => 'ok')
            .catchError((_) => 'error'),
      ]);
      expect(outcomes.where((o) => o == 'ok'), hasLength(1));
      expect(outcomes.where((o) => o == 'error'), hasLength(1));
    });

    test('resolución fallida no envenena el caché', () async {
      final resolver = _resolver(platformOverride: _FakePhysicalAndroid());
      await expectLater(resolver.resolveAsync(), throwsStateError);
      final url = await resolver.resolveAsync(host: '192.168.1.5');
      expect(url, 'http://192.168.1.5:3000');
    });

    test('prepare dos veces misma key → el error menciona la key', () async {
      final resolver = _resolver();
      await resolver.prepare(key: 'auth');
      expect(
        () => resolver.prepare(key: 'auth'),
        throwsA(
          isA<StateError>()
              .having((e) => e.message, 'message', contains('auth')),
        ),
      );
    });
  });

  group('Scheme', () {
    test('default → http', () async {
      final url = await _resolver().resolveAsync(host: '192.168.1.5');
      expect(url, startsWith('http://'));
    });

    test('https en resolveAsync → URL con https', () async {
      final url = await _resolver().resolveAsync(
        host: '192.168.1.5',
        scheme: 'https',
      );
      expect(url, 'https://192.168.1.5:3000');
    });

    test('https en prepare → baseUrl con https', () async {
      final resolver = _resolver();
      await resolver.prepare(scheme: 'https');
      expect(resolver.baseUrl(), 'https://localhost:3000');
    });
  });

  group('reset()', () {
    test('después de reset → baseUrl lanza StateError', () async {
      final resolver = _resolver();
      await resolver.prepare();
      resolver.reset();
      expect(() => resolver.baseUrl(), throwsStateError);
    });

    test('después de reset → prepare misma key no lanza', () async {
      final resolver = _resolver();
      await resolver.prepare();
      resolver.reset();
      await resolver.prepare(port: 9000);
      expect(resolver.baseUrl(), 'http://localhost:9000');
    });
  });
}
