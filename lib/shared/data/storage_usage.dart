class StorageUsage {
  final int databases;
  final int clinicalFiles;
  final int preferences;
  final int temporaryFiles;
  final int otherFiles;
  final int pendingOrders;
  final int pendingChanges;

  const StorageUsage({
    this.databases = 0,
    this.clinicalFiles = 0,
    this.preferences = 0,
    this.temporaryFiles = 0,
    this.otherFiles = 0,
    this.pendingOrders = 0,
    this.pendingChanges = 0,
  });

  int get total =>
      databases + clinicalFiles + preferences + temporaryFiles + otherFiles;
  static String formatBytes(int bytes) =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(1)} ميغا';
}
