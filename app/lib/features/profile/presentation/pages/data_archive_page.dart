import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/composites/xiguang_page.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../application/local_archive_controller.dart';
import '../../domain/archive_models.dart';

// PAGE_SIZE_EXEMPT: 本轮保留导入导出、预检、进度与结果状态编排；
// 后续将归档操作区和各状态面板拆为独立 widgets 后移除此豁免。
class DataArchivePage extends ConsumerStatefulWidget {
  const DataArchivePage({super.key});

  @override
  ConsumerState<DataArchivePage> createState() => _DataArchivePageState();
}

class _DataArchivePageState extends ConsumerState<DataArchivePage> {
  ArchivePreflight? _preflight;
  ArchiveProgress? _progress;
  ArchiveExportResult? _exportResult;
  ArchiveImportPreview? _preview;
  ArchiveImportResult? _importResult;
  StreamSubscription<ArchiveProgress>? _operation;
  String? _error;

  bool get _busy => _operation != null;

  @override
  void initState() {
    super.initState();
    _loadPreflight();
  }

  @override
  void dispose() {
    _operation?.cancel();
    super.dispose();
  }

  Future<void> _loadPreflight() async {
    try {
      final result =
          await ref.read(localArchiveControllerProvider).preflightExport();
      if (mounted) setState(() => _preflight = result);
    } catch (error) {
      if (mounted) setState(() => _error = '无法读取本地数据：$error');
    }
  }

  Future<void> _startExport() async {
    if (_busy) return;
    final session = ref.read(authSessionProvider);
    if (session == null) return;
    setState(() {
      _error = null;
      _exportResult = null;
      _progress = const ArchiveProgress(
        phase: ArchivePhase.preflight,
        fraction: 0,
        message: '准备完整归档',
      );
    });
    final stream = ref.read(localArchiveControllerProvider).exportArchive(
          ArchiveExportRequest(
            sourceAccountPublicId: session.publicId,
            username: session.username,
            nickname: session.nickname,
          ),
        );
    late final StreamSubscription<ArchiveProgress> subscription;
    subscription = stream.listen(
      (event) {
        if (!mounted) return;
        setState(() {
          _progress = event;
          _exportResult = event.exportResult ?? _exportResult;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _error = _friendlyError(error);
          _operation = null;
        });
      },
      onDone: () {
        if (mounted) setState(() => _operation = null);
      },
      cancelOnError: true,
    );
    setState(() => _operation = subscription);
  }

  Future<void> _pickArchive() async {
    if (_busy) return;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    setState(() {
      _error = null;
      _preview = null;
      _importResult = null;
    });
    try {
      final preview =
          await ref.read(localArchiveControllerProvider).inspectArchive(path);
      if (!mounted) return;
      setState(() => _preview = preview);
      await _confirmImport(path, preview);
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    }
  }

  Future<void> _confirmImport(String path, ArchiveImportPreview preview) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final night = NightTheme.of(context);
        return AlertDialog(
          title: Text('确认安全合并',
              style: AppText.titleLarge.copyWith(color: night.foreground)),
          content: Text(
            '预计新增 ${preview.additions} 束光，跳过 ${preview.duplicates} 条重复内容，'
            '${preview.conflicts} 条冲突将保留本机版本。现有内容不会被覆盖。',
            style: AppText.body.copyWith(color: night.foregroundMuted),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('暂不恢复')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('开始恢复')),
          ],
        );
      },
    );
    if (confirmed == true) _startImport(path);
  }

  void _startImport(String path) {
    final stream = ref
        .read(localArchiveControllerProvider)
        .importArchive(ArchiveImportRequest(zipPath: path));
    late final StreamSubscription<ArchiveProgress> subscription;
    subscription = stream.listen(
      (event) {
        if (!mounted) return;
        setState(() {
          _progress = event;
          _importResult = event.importResult ?? _importResult;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _error = _friendlyError(error);
          _operation = null;
        });
      },
      onDone: () {
        if (mounted) setState(() => _operation = null);
      },
      cancelOnError: true,
    );
    setState(() {
      _operation = subscription;
      _error = null;
    });
  }

  Future<void> _cancel() async {
    await _operation?.cancel();
    if (mounted) {
      setState(() {
        _operation = null;
        _progress = null;
      });
    }
  }

  Future<void> _saveOrShare() async {
    final result = _exportResult;
    if (result == null) return;
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      final destination = await FilePicker.platform.saveFile(
        dialogTitle: '保存隙光完整归档',
        fileName: p.basename(result.zipPath),
        type: FileType.custom,
        allowedExtensions: const ['zip'],
      );
      if (destination != null) {
        final target = destination.toLowerCase().endsWith('.zip')
            ? destination
            : '$destination.zip';
        await File(result.zipPath).copy(target);
      }
      return;
    }
    await SharePlus.instance.share(ShareParams(
      files: [XFile(result.zipPath, mimeType: 'application/zip')],
      title: '隙光完整数据归档',
    ));
  }

  Future<void> _reveal() async {
    final path = _exportResult?.zipPath;
    if (path == null) return;
    if (Platform.isMacOS) {
      await Process.run('open', ['-R', path]);
    } else {
      await OpenFilex.open(path);
    }
  }

  Future<void> _verifyAgain() async {
    final path = _exportResult?.zipPath;
    if (path == null) return;
    try {
      await ref.read(localArchiveControllerProvider).verifyArchive(path);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('归档完整性校验通过')));
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    }
  }

  String _friendlyError(Object error) {
    if (error is ArchiveIntegrityException) {
      final detail = error.issues.isEmpty
          ? ''
          : '\n${error.issues.map((e) => e.source ?? e.message).take(3).join('\n')}';
      return '${error.message}$detail';
    }
    return '操作没有完成：$error';
  }

  @override
  Widget build(BuildContext context) {
    final night = NightTheme.of(context);
    return XiguangPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            IconButton(
                onPressed: context.pop,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20)),
            const SizedBox(width: AppSpacing.s6),
            Text('数据归档',
                style: AppText.subHero.copyWith(color: night.foreground)),
          ]),
          const SizedBox(height: AppSpacing.s10),
          Text('把散落的光完整收好，也能在另一台设备上安全恢复。',
              style: AppText.body.copyWith(color: night.foregroundMuted)),
          const SizedBox(height: AppSpacing.s18),
          _ArchiveActionCard(
            icon: Icons.archive_rounded,
            color: AppColors.teaGreen,
            title: '导出完整归档',
            description: _preflight == null
                ? '正在清点本地内容…'
                : '${_preflight!.fragmentCount} 束光 · ${_preflight!.mediaCount} 个媒体 · ${_formatBytes(_preflight!.estimatedBytes)}',
            buttonLabel: '开始完整归档',
            onPressed:
                _busy || _preflight?.canExport != true ? null : _startExport,
          ),
          const SizedBox(height: AppSpacing.s12),
          _ArchiveActionCard(
            icon: Icons.settings_backup_restore_rounded,
            color: AppColors.lilac,
            title: '从归档恢复',
            description: '先只读检查，再补齐缺失数据；本机已有内容不会被覆盖。',
            buttonLabel: '选择 ZIP 归档',
            onPressed: _busy ? null : _pickArchive,
          ),
          const SizedBox(height: AppSpacing.s14),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s14),
            decoration: BoxDecoration(
                color: night.surface.withValues(alpha: .66),
                borderRadius: BorderRadius.circular(AppRadius.xl)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.lock_open_rounded,
                  size: 18, color: night.foregroundMuted),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                  child: Text(
                      '归档是未加密的标准 ZIP，可能包含私人文字、图片与声音。请保存在可信位置，不要直接发送给不信任的人。',
                      style: AppText.caption
                          .copyWith(color: night.foregroundMuted))),
            ]),
          ),
          if (_progress != null) ...[
            const SizedBox(height: AppSpacing.s18),
            _ProgressPanel(
                progress: _progress!, busy: _busy, onCancel: _cancel),
          ],
          if (_exportResult != null) ...[
            const SizedBox(height: AppSpacing.s12),
            _ResultPanel(
              title: '归档已通过完整性校验',
              detail:
                  '${_exportResult!.fragmentCount} 束光 · ${_exportResult!.mediaCount} 个去重媒体 · ${_formatBytes(_exportResult!.bytes)}',
              primaryLabel: Platform.isMacOS ? '另存为' : '保存或分享',
              onPrimary: _saveOrShare,
              actions: [
                TextButton.icon(
                    onPressed: _reveal,
                    icon: const Icon(Icons.folder_open_rounded, size: 18),
                    label: Text(Platform.isMacOS ? '在访达中显示' : '打开文件')),
                TextButton.icon(
                    onPressed: _verifyAgain,
                    icon: const Icon(Icons.verified_rounded, size: 18),
                    label: const Text('再次校验')),
              ],
            ),
          ],
          if (_preview != null && _importResult == null) ...[
            const SizedBox(height: AppSpacing.s12),
            Text(
                '预检：新增 ${_preview!.additions} · 重复 ${_preview!.duplicates} · 冲突 ${_preview!.conflicts}',
                style: AppText.body.copyWith(color: night.foreground)),
          ],
          if (_importResult != null) ...[
            const SizedBox(height: AppSpacing.s12),
            _ResultPanel(
              title: '本机恢复完成',
              detail:
                  '新增 ${_importResult!.added} · 跳过 ${_importResult!.skipped} · 冲突 ${_importResult!.conflicts} · 待同步 ${_importResult!.pendingCloud}',
              primaryLabel: '查看冲突报告',
              onPrimary: () => OpenFilex.open(_importResult!.reportPath),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.s12),
            Text(_error!, style: AppText.body.copyWith(color: night.danger)),
          ],
        ],
      ),
    );
  }
}

class _ArchiveActionCard extends StatelessWidget {
  const _ArchiveActionCard(
      {required this.icon,
      required this.color,
      required this.title,
      required this.description,
      required this.buttonLabel,
      required this.onPressed});
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final night = NightTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: night.surface.withValues(alpha: .86),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: night.border.withValues(alpha: .7)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(AppRadius.lg)),
              child: Icon(icon, color: night.foreground, size: 21)),
          const SizedBox(width: AppSpacing.s12),
          Text(title,
              style: AppText.titleMedium.copyWith(color: night.foreground)),
        ]),
        const SizedBox(height: AppSpacing.s10),
        Text(description,
            style: AppText.body.copyWith(color: night.foregroundMuted)),
        const SizedBox(height: AppSpacing.s14),
        SizedBox(
            width: double.infinity,
            child:
                FilledButton(onPressed: onPressed, child: Text(buttonLabel))),
      ]),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel(
      {required this.progress, required this.busy, required this.onCancel});
  final ArchiveProgress progress;
  final bool busy;
  final VoidCallback onCancel;
  @override
  Widget build(BuildContext context) {
    final night = NightTheme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: Text(progress.message,
                style: AppText.body.copyWith(color: night.foreground))),
        if (busy) TextButton(onPressed: onCancel, child: const Text('取消'))
      ]),
      const SizedBox(height: AppSpacing.s6),
      LinearProgressIndicator(
          value: progress.fraction.clamp(0, 1),
          minHeight: 6,
          borderRadius: BorderRadius.circular(99)),
      if (progress.totalFiles > 0) ...[
        const SizedBox(height: AppSpacing.s6),
        Text('${progress.processedFiles}/${progress.totalFiles} 个文件',
            style: AppText.caption.copyWith(color: night.foregroundMuted)),
      ],
    ]);
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel(
      {required this.title,
      required this.detail,
      required this.primaryLabel,
      required this.onPrimary,
      this.actions = const []});
  final String title;
  final String detail;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    final night = NightTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s14),
      decoration: BoxDecoration(
          color: AppColors.teaGreen.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: AppText.titleMedium.copyWith(color: night.foreground)),
        const SizedBox(height: AppSpacing.s6),
        Text(detail,
            style: AppText.caption.copyWith(color: night.foregroundMuted)),
        const SizedBox(height: AppSpacing.s12),
        SizedBox(
            width: double.infinity,
            child:
                FilledButton(onPressed: onPrimary, child: Text(primaryLabel))),
        if (actions.isNotEmpty) Wrap(spacing: AppSpacing.s6, children: actions),
      ]),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}
