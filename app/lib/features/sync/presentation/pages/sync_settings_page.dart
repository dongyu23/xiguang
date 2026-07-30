// PAGE_SIZE_EXEMPT: migration in progress; connection and server configuration cards will be extracted.
import 'package:flutter/material.dart';
import 'package:xiguang/ui/primitives/overlay_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../../design/tokens/colors.dart';
import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../app/providers.dart';
import '../providers/sync_providers.dart';
import '../providers/sync_provider.dart';
import '../../../../ui/primitives/page_back_button.dart';
import '../../../../ui/spaces/space_canvas.dart';
import '../../../../ui/composites/xiguang_card.dart';
import '../../../../ui/composites/xiguang_page.dart';
import '../../domain/sync_status.dart';

class SyncSettingsPage extends ConsumerStatefulWidget {
  const SyncSettingsPage({super.key});

  @override
  ConsumerState<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends ConsumerState<SyncSettingsPage> {
  final _urlController = TextEditingController();
  bool _testing = false;
  bool _syncing = false;
  bool _savingUrl = false;
  String? _lastBaseUrl;
  String? _urlError;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(syncStatusProvider);
    final theme = NightTheme.of(context);
    final baseUrl = ref.watch(apiBaseUrlProvider);

    baseUrl.whenData((url) {
      if (_lastBaseUrl != url && !_savingUrl) {
        _lastBaseUrl = url;
        _urlController.text = url;
      }
    });

    final overlayStyle =
        theme.isNight ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: XiguangPage(
        backgroundLayer: const AtmosphereBackground(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.s22,
          AppSpacing.s12,
          AppSpacing.s22,
          AppSpacing.pageBottomNav + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _SyncHeader(),
          const SizedBox(height: AppSpacing.s18),
          _ConnectionCard(
            status: status,
            testing: _testing,
            syncing: _syncing,
            onTestConnection: () => _testConnection(),
            onSyncNow: () => _syncNow(),
          ),
          const SizedBox(height: AppSpacing.md),
          const _SectionLabel('连接参数'),
          const SizedBox(height: AppSpacing.sm),
          _ServerUrlCard(
            baseUrl: baseUrl,
            controller: _urlController,
            saving: _savingUrl,
            errorText: _urlError,
            onChanged: (_) {
              if (_urlError != null) {
                setState(() => _urlError = null);
              }
            },
            onSave: _saveBaseUrl,
            onReset: _resetBaseUrl,
          ),
        ]),
      ),
    );
  }

  Future<void> _saveBaseUrl() async {
    final input = _urlController.text;
    final error = validateApiBaseUrl(input);
    if (error != null) {
      setState(() => _urlError = error);
      return;
    }
    setState(() {
      _savingUrl = true;
      _urlError = null;
    });
    try {
      await ref.read(apiBaseUrlProvider.notifier).save(input);
      _markConnectionUntested();
      ref.invalidate(syncConnectionProvider);
      if (!mounted) return;
      showOverlaySnackBar(
          context,
          const SnackBar(
            content: Text('后端地址已保存。'),
            behavior: SnackBarBehavior.floating,
          ));
    } on ArgumentError catch (error) {
      if (mounted) {
        setState(() => _urlError = error.message.toString());
      }
    } catch (_) {
      if (!mounted) return;
      showOverlaySnackBar(
          context,
          const SnackBar(
            content: Text('保存失败，请稍后再试。'),
            behavior: SnackBarBehavior.floating,
          ));
    } finally {
      if (mounted) setState(() => _savingUrl = false);
    }
  }

  Future<void> _resetBaseUrl() async {
    setState(() {
      _savingUrl = true;
      _urlError = null;
    });
    try {
      await ref.read(apiBaseUrlProvider.notifier).reset();
      _markConnectionUntested();
      ref.invalidate(syncConnectionProvider);
      if (!mounted) return;
      showOverlaySnackBar(
          context,
          const SnackBar(
            content: Text('已恢复默认后端地址。'),
            behavior: SnackBarBehavior.floating,
          ));
    } catch (_) {
      if (!mounted) return;
      showOverlaySnackBar(
          context,
          const SnackBar(
            content: Text('恢复默认地址失败，请稍后再试。'),
            behavior: SnackBarBehavior.floating,
          ));
    } finally {
      if (mounted) setState(() => _savingUrl = false);
    }
  }

  void _markConnectionUntested() {
    final status = ref.read(syncStatusProvider);
    ref.read(syncStatusProvider.notifier).state = SyncStatus(
      lastServerRev: status.lastServerRev,
      pendingCount: status.pendingCount,
      lastSyncAt: status.lastSyncAt,
      isSyncing: status.isSyncing,
      connected: false,
    );
  }

  Future<void> _testConnection() async {
    setState(() => _testing = true);
    try {
      ref.invalidate(syncConnectionProvider);
      final ok = await ref.read(syncConnectionProvider.future);
      if (!mounted) return;
      showOverlaySnackBar(
          context,
          SnackBar(
            content: Text(ok ? '服务器连接正常。' : '无法连接到服务器，请检查网络和后端状态。'),
            behavior: SnackBarBehavior.floating,
          ));
    } catch (_) {
      if (!mounted) return;
      showOverlaySnackBar(
          context,
          const SnackBar(
            content: Text('连接测试失败，请检查网络和后端状态。'),
            behavior: SnackBarBehavior.floating,
          ));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    try {
      final status = await syncManually(ref);
      if (!mounted) return;
      if (status.error != null) {
        showOverlaySnackBar(
            context,
            const SnackBar(
              content: Text('同步失败，请检查网络和后端状态。'),
              behavior: SnackBarBehavior.floating,
            ));
        return;
      }
      final pending = status.pendingCount;
      final msg = pending == 0 ? '同步完成，没有待推送的变更。' : '同步完成，仍有 $pending 条待推送。';
      showOverlaySnackBar(
          context,
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
          ));
    } catch (_) {
      if (!mounted) return;
      showOverlaySnackBar(
          context,
          const SnackBar(
            content: Text('同步失败，请检查网络和后端状态。'),
            behavior: SnackBarBehavior.floating,
          ));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.status,
    required this.testing,
    required this.syncing,
    required this.onTestConnection,
    required this.onSyncNow,
  });

  final SyncStatus status;
  final bool testing;
  final bool syncing;
  final VoidCallback onTestConnection;
  final VoidCallback onSyncNow;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final hasError = status.error != null && status.error!.isNotEmpty;
    final statusTitle = status.connected
        ? '已连接'
        : hasError
            ? '后端暂时没有回应'
            : '等待连接确认';
    final statusHint = status.connected
        ? '服务器连接正常，可以安全推送本地修改。'
        : hasError
            ? '请确认服务器地址、网络和后端服务状态。'
            : '点一下测试连接，确认当前服务器是否可用。';
    return _Card(children: [
      Row(children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: status.connected
                ? AppColors.teaGreen
                : (hasError ? AppColors.sunsetCoral : AppColors.inkMuted),
          ),
        ),
        const SizedBox(width: AppSpacing.s10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              statusTitle,
              style: AppText.titleSmall.copyWith(color: theme.foreground),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              statusHint,
              style: AppText.caption.copyWith(color: theme.foregroundMuted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
      ]),
      const SizedBox(height: AppSpacing.s14),
      Wrap(
        spacing: AppSpacing.s10,
        runSpacing: AppSpacing.s10,
        children: [
          _StatusMetric(
            label: '服务端版本',
            value: 'Rev ${status.lastServerRev}',
          ),
          _StatusMetric(label: '待推送', value: '${status.pendingCount} 条'),
          _StatusMetric(
            label: '上次同步',
            value: status.lastSyncAt != null
                ? '${status.lastSyncAt!.hour.toString().padLeft(2, '0')}:${status.lastSyncAt!.minute.toString().padLeft(2, '0')}'
                : '尚未同步',
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.s12),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: testing ? null : onTestConnection,
            icon: testing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_find_outlined, size: 17),
            label: Text(testing ? '测试中...' : '测试连接'),
          ),
        ),
        const SizedBox(width: AppSpacing.s10),
        Expanded(
          child: FilledButton.icon(
            onPressed: syncing || !status.connected ? null : onSyncNow,
            icon: syncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sync_rounded, size: 17),
            label: Text(syncing ? '同步中...' : '立即同步'),
          ),
        ),
      ]),
    ]);
  }
}

class _SyncHeader extends StatelessWidget {
  const _SyncHeader();

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Row(
      children: [
        PageBackButton(
          onTap: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Text(
            '同步详情',
            style: AppText.titleLarge.copyWith(color: theme.foreground),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ServerUrlCard extends StatelessWidget {
  const _ServerUrlCard({
    required this.baseUrl,
    required this.controller,
    required this.saving,
    required this.errorText,
    required this.onChanged,
    required this.onSave,
    required this.onReset,
  });

  final AsyncValue<String> baseUrl;
  final TextEditingController controller;
  final bool saving;
  final String? errorText;
  final ValueChanged<String> onChanged;
  final VoidCallback onSave;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final loading = baseUrl.isLoading || saving;
    final inputFill = theme.surface;
    final borderColor = theme.border;

    return _Card(children: [
      TextField(
        controller: controller,
        enabled: !loading,
        keyboardType: TextInputType.url,
        autocorrect: false,
        onChanged: onChanged,
        style: AppText.body.copyWith(color: theme.foreground),
        decoration: InputDecoration(
          labelText: '后端地址',
          hintText: 'https://api.frozenfish.cn/api/v1',
          errorText: errorText,
          prefixIcon: const Icon(Icons.dns_outlined, size: 19),
          filled: true,
          fillColor: inputFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.teaGreen),
          ),
        ),
      ),
      if (baseUrl.hasError) ...[
        const SizedBox(height: AppSpacing.sm),
        Text('读取地址失败，将使用默认地址。',
            style: AppText.caption.copyWith(color: theme.danger)),
      ],
      const SizedBox(height: AppSpacing.s12),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: loading ? null : onReset,
            icon: const Icon(Icons.restart_alt_rounded, size: 17),
            label: const Text('恢复默认'),
          ),
        ),
        const SizedBox(width: AppSpacing.s10),
        Expanded(
          child: FilledButton.icon(
            onPressed: loading ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_outlined, size: 17),
            label: Text(saving ? '保存中...' : '保存地址'),
          ),
        ),
      ]),
    ]);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.s2),
      child: Text(label,
          style: AppText.eyebrow.copyWith(color: theme.foregroundMuted)),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => XiguangCard(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}

class _StatusMetric extends StatelessWidget {
  const _StatusMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 92),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s10,
        vertical: AppSpacing.s6,
      ),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: theme.isNight ? .60 : .72),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: theme.border.withValues(alpha: .72)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: AppText.caption.copyWith(color: theme.foregroundMuted)),
        const SizedBox(height: AppSpacing.s2),
        Text(value,
            style: AppText.bodyStrong.copyWith(color: theme.foreground)),
      ]),
    );
  }
}

// nightDecoration() 已移除，使用 shadows.dart 中的 nightDecoration()
