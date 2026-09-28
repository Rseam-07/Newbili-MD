// Async I/O here avoids blocking touch and animation frames during cleanup.
// ignore_for_file: avoid_slow_async_io

import 'dart:io';

import 'package:path/path.dart' as p;

/// Owns export/upload files. An active lease survives storage cleanup, including
/// an export waiting for the system share sheet.
class TransientFileStore {
  TransientFileStore(this.root);
  final Directory root;
  final Set<String> _active = {};
  int _creating = 0;

  Future<Directory> create(String purpose) async {
    _creating++;
    try {
      await root.create(recursive: true);
      final directory = await root.createTemp('$purpose-');
      _active.add(directory.path);
      return directory;
    } finally {
      _creating--;
    }
  }

  Future<void> release(Directory directory) async {
    if (!_active.remove(directory.path)) return;
    try {
      await directory.delete(recursive: true);
    } on FileSystemException {
      // A failed deletion remains eligible for the next maintenance pass.
    }
  }

  Future<int> prune({bool allInactive = false, DateTime? now}) async {
    if (!await root.exists()) return 0;
    final cutoff = (now ?? DateTime.now()).subtract(const Duration(days: 1));
    var removed = 0;
    await for (final entity in root.list(followLinks: false)) {
      if (_creating > 0 || _active.contains(entity.path) || entity is Link) {
        continue;
      }
      final stat = await entity.stat();
      if (!allInactive && !stat.modified.isBefore(cutoff)) continue;
      final bytes = await sizeOf(entity);
      try {
        await entity.delete(recursive: true);
        removed += bytes;
      } on FileSystemException {
        // Continue with other entries; remaining bytes are shown in the UI.
      }
    }
    return removed;
  }

  static Future<int> sizeOf(FileSystemEntity entity) async {
    var bytes = 0;
    try {
      if (entity is File) return await entity.length();
      if (entity is Directory) {
        await for (final file in entity.list(
          recursive: true,
          followLinks: false,
        )) {
          if (file is File) {
            try {
              bytes += await file.length();
            } on FileSystemException {
              // An export can finish while storage is being scanned.
            }
          }
        }
      }
    } on FileSystemException {
      // A directory can disappear between listing and scanning.
    }
    return bytes;
  }

  /// Reclaim recognizable leftovers from releases before managed leases.
  /// Never recurse into arbitrary plugin, WebKit, download or account folders.
  static Future<void> pruneLegacy(Directory temp, {DateTime? now}) async {
    final cutoff = (now ?? DateTime.now()).subtract(const Duration(days: 1));
    final generated = RegExp(
      r'^(video_.+|[a-zA-Z0-9]{8}\.png|\d+-\d+\.\d{3}_\d+\.\d{3}\.webp)$',
    );
    await for (final entity in temp.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (!(entity is File && generated.hasMatch(name)) &&
          !(entity is Directory && name.startsWith('web-download-'))) {
        continue;
      }
      try {
        if ((await entity.stat()).modified.isBefore(cutoff)) {
          await entity.delete(recursive: true);
        }
      } on FileSystemException {
        // Retry on the next launch without preventing startup.
      }
    }
  }
}
