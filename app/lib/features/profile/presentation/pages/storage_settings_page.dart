import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/motion.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/composites/xiguang_card.dart';
import '../../../../ui/composites/xiguang_page.dart';

enum _CacheKind { images, audio, archive, other }

class _CacheBucket {
  const _CacheBucket({
    required this.bytes,
    required this.files,
  });

  final int bytes;
  final List<File> files;
  int get count => files.length;
}

class _CacheSnapshot {
  const _CacheSnapshot({
    required this.buckets,
    required this.cacheRoots,
    required this.installationBytes,
    required this.personalDataBytes,
    required this.personalDataFileCount,
    required this.memoryImageBytes,
    required this.memoryImageCount,
    required this.scannedAt,
  });

  final Map<_CacheKind, _CacheBucket> buckets;
  final List<Directory> cacheRoots;
  final int installationBytes;
  final int personalDataBytes;
  final int personalDataFileCount;
  final int memoryImageBytes;
  final int memoryImageCount;
  final DateTime scannedAt;

  int get diskBytes =>
      buckets.values.fold(0, (total, bucket) => total + bucket.bytes);
  int get fileCount =>
      buckets.values.fold(0, (total, bucket) => total + bucket.count);
  int get totalStorageBytes =>
      installationBytes + personalDataBytes + diskBytes;
}

class _DirectoryUsage {
  const _DirectoryUsage({required this.bytes, required this.fileCount});

  final int bytes;
  final int fileCount;
}

class StorageSettingsPage extends StatefulWidget {
  const StorageSettingsPage({super.key});

  @override
  State<StorageSettingsPage> createState() => _StorageSettingsPageState();
}

class _StorageSettingsPageState extends State<StorageSettingsPage> {
  static const _storageChannel = MethodChannel('com.xiguang.xiguang/storage');
  static const _imageExtensions = {
    'png',
    'jpg',
    'jpeg',
    'webp',
    'gif',
    'heic',
  };
  static const _audioExtensions = {
    'aac',
    'caf',
    'm4a',
    'mp3',
    'ogg',
    'opus',
    'wav',
  };

  final Set<_CacheKind> _selected = Set.of(_CacheKind.values);
  _CacheSnapshot? _snapshot;
  bool _scanning = false;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    if (_scanning) return;
    setState(() => _scanning = true);
    try {
      final cacheRoots = await _cacheDirectories();
      final documents = await getApplicationDocumentsDirectory();
      final support = await getApplicationSupportDirectory();
      final files = <_CacheKind, List<File>>{
        for (final kind in _CacheKind.values) kind: <File>[],
      };
      final sizes = <_CacheKind, int>{
        for (final kind in _CacheKind.values) kind: 0,
      };
      for (final directory in cacheRoots) {
        if (!await directory.exists()) continue;
        await for (final entity
            in directory.list(recursive: true, followLinks: false)) {
          if (entity is! File) continue;
          try {
            final kind = _kindFor(entity.path);
            files[kind]!.add(entity);
            sizes[kind] = sizes[kind]! + await entity.length();
          } catch (_) {}
        }
      }
      final personalData =
          await _measurePersonalData(documents, support, cacheRoots);
      final installationBytes = await _installationBytes();
      final imageCache = PaintingBinding.instance.imageCache;
      final snapshot = _CacheSnapshot(
        buckets: {
          for (final kind in _CacheKind.values)
            kind: _CacheBucket(bytes: sizes[kind]!, files: files[kind]!),
        },
        cacheRoots: cacheRoots,
        installationBytes: installationBytes,
        personalDataBytes: personalData.bytes,
        personalDataFileCount: personalData.fileCount,
        memoryImageBytes: imageCache.currentSizeBytes,
        memoryImageCount: imageCache.currentSize,
        scannedAt: DateTime.now(),
      );
      if (mounted) setState(() => _snapshot = snapshot);
    } catch (_) {
      if (mounted) _showMessage('暂时无法读取缓存，请稍后再试。');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<List<Directory>> _cacheDirectories() async {
    final directories = <Directory>[await getTemporaryDirectory()];
    try {
      directories.add(await getApplicationCacheDirectory());
    } catch (_) {}
    return _uniqueDirectories(directories);
  }

  List<Directory> _uniqueDirectories(List<Directory> directories) {
    final sorted = directories
        .map((directory) => Directory(p.normalize(directory.absolute.path)))
        .toList()
      ..sort((a, b) => a.path.length.compareTo(b.path.length));
    final result = <Directory>[];
    for (final directory in sorted) {
      final duplicate = result.any((existing) =>
          existing.path == directory.path ||
          p.isWithin(existing.path, directory.path));
      if (!duplicate) result.add(directory);
    }
    return result;
  }

  Future<_DirectoryUsage> _measureDirectories(
    List<Directory> roots, {
    List<Directory> excludedRoots = const [],
  }) async {
    var bytes = 0;
    var fileCount = 0;
    for (final root in _uniqueDirectories(roots)) {
      if (!await root.exists()) continue;
      await for (final entity
          in root.list(recursive: true, followLinks: false)) {
        if (entity is! File || _isInsideAny(entity.path, excludedRoots)) {
          continue;
        }
        try {
          bytes += await entity.length();
          fileCount++;
        } catch (_) {}
      }
    }
    return _DirectoryUsage(bytes: bytes, fileCount: fileCount);
  }

  Future<_DirectoryUsage> _measurePersonalData(
    Directory documents,
    Directory support,
    List<Directory> excludedRoots,
  ) async {
    final entities = <FileSystemEntity>[
      support,
      Directory(p.join(documents.path, 'audio_library')),
    ];
    if (await documents.exists()) {
      await for (final entity
          in documents.list(recursive: false, followLinks: false)) {
        if (entity is File &&
            p.basename(entity.path).startsWith('xiguang.sqlite')) {
          entities.add(entity);
        }
      }
    }
    var bytes = 0;
    var fileCount = 0;
    final seen = <String>{};
    for (final entity in entities) {
      final path = p.normalize(entity.absolute.path);
      if (!seen.add(path) || _isInsideAny(path, excludedRoots)) continue;
      if (entity is File) {
        try {
          bytes += await entity.length();
          fileCount++;
        } catch (_) {}
        continue;
      }
      if (entity is Directory && await entity.exists()) {
        final usage = await _measureDirectories(
          [entity],
          excludedRoots: excludedRoots,
        );
        bytes += usage.bytes;
        fileCount += usage.fileCount;
      }
    }
    return _DirectoryUsage(bytes: bytes, fileCount: fileCount);
  }

  bool _isInsideAny(String path, List<Directory> roots) {
    final normalized = p.normalize(File(path).absolute.path);
    return roots.any((root) {
      final rootPath = p.normalize(root.absolute.path);
      return normalized == rootPath || p.isWithin(rootPath, normalized);
    });
  }

  Future<int> _installationBytes() async {
    if (Platform.isAndroid) {
      try {
        return await _storageChannel.invokeMethod<int>('installationBytes') ??
            0;
      } catch (_) {
        return 0;
      }
    }
    if (Platform.isIOS || Platform.isMacOS) {
      var directory = File(Platform.resolvedExecutable).parent;
      while (directory.parent.path != directory.path) {
        if (p.extension(directory.path).toLowerCase() == '.app') {
          return (await _measureDirectories([directory])).bytes;
        }
        directory = directory.parent;
      }
    }
    try {
      return await File(Platform.resolvedExecutable).length();
    } catch (_) {
      return 0;
    }
  }

  _CacheKind _kindFor(String path) {
    final value = path.toLowerCase();
    final filename = value.split(Platform.pathSeparator).last;
    final extension = filename.contains('.') ? filename.split('.').last : '';
    if (value.contains('archive') ||
        value.contains('export') ||
        extension == 'zip' ||
        extension == 'partial') {
      return _CacheKind.archive;
    }
    if (_imageExtensions.contains(extension)) return _CacheKind.images;
    if (_audioExtensions.contains(extension)) return _CacheKind.audio;
    return _CacheKind.other;
  }

  Future<void> _clearSelected() async {
    if (_clearing || _selected.isEmpty) return;
    setState(() => _clearing = true);
    try {
      if (_selected.contains(_CacheKind.images)) {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      }
      final snapshot = _snapshot;
      if (snapshot != null) {
        for (final kind in _selected) {
          for (final file in snapshot.buckets[kind]!.files) {
            try {
              await file.delete();
            } catch (_) {}
          }
        }
      }
      await _removeEmptyTemporaryDirectories(snapshot?.cacheRoots ?? const []);
      await _scan();
      if (mounted) _showMessage('所选缓存已经清理，光片和正式归档没有被删除。');
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  Future<void> _removeEmptyTemporaryDirectories(List<Directory> roots) async {
    final directories = <Directory>[];
    for (final root in roots) {
      if (!await root.exists()) continue;
      await for (final entity
          in root.list(recursive: true, followLinks: false)) {
        if (entity is Directory) directories.add(entity);
      }
    }
    directories.sort((a, b) => b.path.length.compareTo(a.path.length));
    for (final directory in directories) {
      try {
        if (!await directory.list().isEmpty) continue;
        await directory.delete();
      } catch (_) {}
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _toggle(_CacheKind kind) {
    if (_clearing) return;
    setState(() {
      if (!_selected.remove(kind)) _selected.add(kind);
    });
  }

  int get _selectedBytes {
    final snapshot = _snapshot;
    if (snapshot == null) return 0;
    var total = 0;
    for (final kind in _selected) {
      total += snapshot.buckets[kind]!.bytes;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final snapshot = _snapshot;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return XiguangPage(
      scrollable: false,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s22,
        AppSpacing.s12,
        AppSpacing.s22,
        AppSpacing.pageBottomNav + bottomInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: '返回',
                onPressed: () => context.pop(),
                icon: Icon(Icons.arrow_back_rounded, color: theme.foreground),
              ),
              const SizedBox(width: AppSpacing.s6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LOCAL SPACE',
                        style: AppText.eyebrow.copyWith(color: theme.accent)),
                    const SizedBox(height: AppSpacing.s3),
                    Text('存储与缓存',
                        style: AppText.titleLarge
                            .copyWith(color: theme.foreground)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          _StorageOverview(
            snapshot: snapshot,
            scanning: _scanning,
            onRefresh: _scanning ? null : _scan,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text('清理缓存',
                  style: AppText.titleMedium.copyWith(color: theme.foreground)),
              const Spacer(),
              Text('已选 ${_selected.length} 项',
                  style:
                      AppText.caption.copyWith(color: theme.foregroundMuted)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: XiguangCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _CacheKindTile(
                            kind: _CacheKind.images,
                            bucket: snapshot?.buckets[_CacheKind.images],
                            memoryImageBytes: snapshot?.memoryImageBytes ?? 0,
                            selected: _selected.contains(_CacheKind.images),
                            onTap: () => _toggle(_CacheKind.images),
                          ),
                        ),
                        VerticalDivider(
                          width: 1,
                          color: theme.border.withValues(alpha: .7),
                        ),
                        Expanded(
                          child: _CacheKindTile(
                            kind: _CacheKind.audio,
                            bucket: snapshot?.buckets[_CacheKind.audio],
                            memoryImageBytes: snapshot?.memoryImageBytes ?? 0,
                            selected: _selected.contains(_CacheKind.audio),
                            onTap: () => _toggle(_CacheKind.audio),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: theme.border.withValues(alpha: .7),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _CacheKindTile(
                            kind: _CacheKind.archive,
                            bucket: snapshot?.buckets[_CacheKind.archive],
                            memoryImageBytes: snapshot?.memoryImageBytes ?? 0,
                            selected: _selected.contains(_CacheKind.archive),
                            onTap: () => _toggle(_CacheKind.archive),
                          ),
                        ),
                        VerticalDivider(
                          width: 1,
                          color: theme.border.withValues(alpha: .7),
                        ),
                        Expanded(
                          child: _CacheKindTile(
                            kind: _CacheKind.other,
                            bucket: snapshot?.buckets[_CacheKind.other],
                            memoryImageBytes: snapshot?.memoryImageBytes ?? 0,
                            selected: _selected.contains(_CacheKind.other),
                            onTap: () => _toggle(_CacheKind.other),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s10),
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 16, color: theme.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '只清理所选缓存，不碰光片、个人数据和正式归档。',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(color: theme.foregroundMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _clearing ||
                      _scanning ||
                      _snapshot == null ||
                      _selected.isEmpty
                  ? null
                  : _clearSelected,
              icon: _clearing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cleaning_services_outlined, size: 19),
              label: Text(_clearing
                  ? '正在清理…'
                  : '清理所选缓存 · ${_formatBytes(_selectedBytes)}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StorageOverview extends StatelessWidget {
  const _StorageOverview({
    required this.snapshot,
    required this.scanning,
    required this.onRefresh,
  });

  final _CacheSnapshot? snapshot;
  final bool scanning;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final scannedAt = snapshot == null
        ? '扫描中'
        : MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay.fromDateTime(snapshot!.scannedAt),
          );
    return XiguangCard(
      variant: XiguangCardVariant.raised,
      padding: const EdgeInsets.all(AppSpacing.s14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: theme.accent.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child:
                    Icon(Icons.layers_outlined, size: 19, color: theme.accent),
              ),
              const SizedBox(width: AppSpacing.s10),
              Text('应用总占用',
                  style: AppText.bodyStrong.copyWith(color: theme.foreground)),
              const Spacer(),
              AnimatedSwitcher(
                duration: AppMotion.normal,
                child: Text(
                  snapshot == null
                      ? '正在统计'
                      : _formatBytes(snapshot!.totalStorageBytes),
                  key: ValueKey(snapshot?.totalStorageBytes),
                  style: AppText.titleLarge.copyWith(color: theme.foreground),
                ),
              ),
              IconButton(
                tooltip: '重新扫描',
                onPressed: onRefresh,
                icon: scanning
                    ? SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.accent,
                        ),
                      )
                    : Icon(Icons.refresh_rounded, color: theme.foregroundMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s10),
            decoration: BoxDecoration(
              color: theme.surface.withValues(alpha: .68),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: theme.border.withValues(alpha: .62)),
            ),
            child: Row(
              children: [
                _StorageStat(
                  label: '应用本体',
                  value: _formatBytes(snapshot?.installationBytes ?? 0),
                ),
                _StorageStatDivider(color: theme.border),
                _StorageStat(
                  label: '个人数据',
                  value: _formatBytes(snapshot?.personalDataBytes ?? 0),
                ),
                _StorageStatDivider(color: theme.border),
                _StorageStat(
                  label: '临时缓存',
                  value: _formatBytes(snapshot?.diskBytes ?? 0),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '数据 ${snapshot?.personalDataFileCount ?? 0} 个 · '
            '缓存 ${snapshot?.fileCount ?? 0} 个 · $scannedAt 更新',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption.copyWith(color: theme.foregroundMuted),
          ),
        ],
      ),
    );
  }
}

class _StorageStat extends StatelessWidget {
  const _StorageStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(label,
              maxLines: 1,
              style: AppText.caption.copyWith(color: theme.foregroundMuted)),
          const SizedBox(height: AppSpacing.s3),
          Text(value,
              maxLines: 1,
              style: AppText.bodyStrong.copyWith(color: theme.foreground)),
        ],
      ),
    );
  }
}

class _StorageStatDivider extends StatelessWidget {
  const _StorageStatDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: color.withValues(alpha: .6));
}

class _CacheKindTile extends StatelessWidget {
  const _CacheKindTile({
    required this.kind,
    required this.bucket,
    required this.memoryImageBytes,
    required this.selected,
    required this.onTap,
  });

  final _CacheKind kind;
  final _CacheBucket? bucket;
  final int memoryImageBytes;
  final bool selected;
  final VoidCallback onTap;

  String get _title => switch (kind) {
        _CacheKind.images => '图片与预览',
        _CacheKind.audio => '声音临时文件',
        _CacheKind.archive => '归档过程文件',
        _CacheKind.other => '其他临时文件',
      };

  IconData get _icon => switch (kind) {
        _CacheKind.images => Icons.image_outlined,
        _CacheKind.audio => Icons.graphic_eq_rounded,
        _CacheKind.archive => Icons.inventory_2_outlined,
        _CacheKind.other => Icons.more_horiz_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final count = bucket?.count ?? 0;
    final size = _formatBytes(bucket?.bytes ?? 0);
    final memory = kind == _CacheKind.images && memoryImageBytes > 0
        ? ' · 内存 ${_formatBytes(memoryImageBytes)}'
        : '';
    return Semantics(
      button: true,
      checked: selected,
      label: '$_title，$count 个文件，$size',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s10,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color:
                          theme.accent.withValues(alpha: selected ? .14 : .06),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(_icon,
                        size: 16,
                        color: selected ? theme.accent : theme.foregroundMuted),
                  ),
                  const Spacer(),
                  AnimatedContainer(
                    duration: AppMotion.fast,
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.accent
                          : theme.surface.withValues(alpha: 0),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? theme.accent : theme.border,
                        width: 1.4,
                      ),
                    ),
                    child: selected
                        ? Icon(Icons.check_rounded,
                            size: 14, color: theme.background)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(
                _title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodyStrong.copyWith(color: theme.foreground),
              ),
              const SizedBox(height: AppSpacing.s2),
              Text(
                '$count 个 · $size$memory',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.copyWith(color: theme.foregroundMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
}
