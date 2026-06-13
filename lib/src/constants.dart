/// Clave para leer HOST desde `--dart-define-from-file`.
const kKeyHost = 'HOST';

/// Clave para leer PORT desde `--dart-define-from-file`.
const kKeyPort = 'PORT';

/// Host del backend en red local leído de `config.json`.
///
/// Puede ser una IP (`"192.168.1.5"`) o incluir puerto
/// (`"192.168.1.5:3000"`). Si incluye puerto, [kEnvPort] se ignora.
///
/// Será `''` si no se pasa `--dart-define-from-file` — incluyendo
/// en tests, donde las constantes de compilación no están disponibles.
///
/// config.json:
///
///     { "HOST": "192.168.1.5" }
const kEnvHost = String.fromEnvironment(kKeyHost);

/// Puerto del backend en red local leído de `config.json`.
///
/// Default `'80'` — se emitirá una advertencia si no está configurado
/// explícitamente. Si [kEnvHost] ya incluye puerto, este valor se ignora.
///
/// Siempre será `'80'` en tests porque las constantes de compilación
/// no están disponibles en ese entorno.
///
/// config.json:
///
///     { "PORT": "3000" }
const kEnvPort = String.fromEnvironment(kKeyPort, defaultValue: '80');
