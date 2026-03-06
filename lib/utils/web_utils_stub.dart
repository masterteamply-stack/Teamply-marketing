// Stub implementation for non-web platforms (Android, iOS, desktop)
// These functions do nothing on non-web platforms

/// Opens a URL in a new browser tab (web only). No-op on native.
void openUrlInBrowser(String url) {
  // No-op on Android/iOS/desktop
}

/// Triggers a web file input dialog for CSV selection. No-op on native.
/// [onFileRead] is called with the file content when a file is selected.
void pickCsvFile({required void Function(String fileName, String content) onFileRead}) {
  // No-op on Android/iOS/desktop
}

/// Triggers a web file input dialog for any file type. No-op on native.
/// [onFilePicked] is called with fileName, fileSize, and objectUrl.
void pickAnyFile({required void Function(String fileName, int fileSize, String objectUrl) onFilePicked}) {
  // No-op on Android/iOS/desktop
}
