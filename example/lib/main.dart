import 'package:flutter/material.dart';
import 'package:dev_base_url/dev_base_url.dart';

/// Tres formas de consumir la URL resuelta — las tres comparten el
/// mismo caché por `key`, así que la plataforma se detecta una sola vez:
///
/// A. Síncrona  — `prepare()` en main, `baseUrl()` donde se necesite.
/// B. Asíncrona — `resolveAsync()` directo desde un `FutureBuilder`.
/// C. Inyectada — resuelta en main y pasada por constructor.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A — prepare() cachea la URL y habilita el acceso síncrono baseUrl().
  // Llamarlo ANTES de construir el árbol de widgets (o tu contenedor DI).
  await DevBaseUrl.instance.prepare(port: 3000);

  // C — misma key 'default': retorna el valor ya cacheado por prepare(),
  // sin volver a detectar la plataforma.
  final injectedBaseUrl = await DevBaseUrl.instance.resolveAsync(
    port: 3000,
  );

  runApp(ExampleApp(injectedBaseUrl: injectedBaseUrl));
}

/// App de ejemplo que muestra las tres formas de consumir la URL.
class ExampleApp extends StatelessWidget {
  /// Crea la app de ejemplo.
  const ExampleApp({required this.injectedBaseUrl, super.key});

  /// URL resuelta en [main] e inyectada por constructor (patrón C).
  final String injectedBaseUrl;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'dev_base_url example',
      home: _HomePage(injectedBaseUrl: injectedBaseUrl),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({required this.injectedBaseUrl});

  final String injectedBaseUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('dev_base_url')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _Section(
            title: 'A — Síncrono (prepare + baseUrl)',
            description: 'prepare() corrió en main. baseUrl() es síncrono: '
                'ideal para contenedores DI que construyen singletons.',
            child: _SyncExample(),
          ),
          const _Section(
            title: 'B — Asíncrono (resolveAsync)',
            description: 'resolveAsync() cachea por key — seguro llamarlo '
                'desde múltiples widgets o constructores create().',
            child: _AsyncExample(),
          ),
          _Section(
            title: 'C — Inyectado por constructor',
            description: 'La URL se resolvió en main y bajó por el árbol. '
                'Los widgets no conocen el paquete.',
            child: _UrlLabel(injectedBaseUrl),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta con título, explicación y el resultado de cada patrón.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(description, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Patrón A — acceso síncrono. Solo funciona porque [main] ya
/// llamó a [DevBaseUrl.prepare]; sin eso lanza [StateError].
class _SyncExample extends StatelessWidget {
  const _SyncExample();

  @override
  Widget build(BuildContext context) {
    return _UrlLabel(DevBaseUrl.instance.baseUrl());
  }
}

/// Patrón B — [DevBaseUrl.resolveAsync] desde un [FutureBuilder].
///
/// No requiere [DevBaseUrl.prepare]: resuelve y cachea en la primera
/// llamada. Aquí la key 'default' ya está cacheada, así que retorna
/// de inmediato.
class _AsyncExample extends StatelessWidget {
  const _AsyncExample();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: DevBaseUrl.instance.resolveAsync(port: 3000),
      builder: (context, snapshot) {
        return switch (snapshot.connectionState) {
          ConnectionState.waiting => const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ConnectionState.done when snapshot.hasError => Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          _ => _UrlLabel(snapshot.data ?? ''),
        };
      },
    );
  }
}

/// Muestra una URL en estilo monoespaciado, seleccionable para copiar.
class _UrlLabel extends StatelessWidget {
  const _UrlLabel(this.url);

  final String url;

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      url,
      style: const TextStyle(fontFamily: 'monospace'),
    );
  }
}
