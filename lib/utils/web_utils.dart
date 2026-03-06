// Platform-conditional export for web utilities
// On web: uses real web APIs
// On non-web (Android, iOS, desktop): uses stub implementation
export 'web_utils_stub.dart'
    if (dart.library.js_interop) 'web_utils_web.dart';
