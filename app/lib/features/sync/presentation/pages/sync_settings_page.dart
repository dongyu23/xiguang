import 'package:flutter/material.dart';
import 'package:xiguang/ui/primitives/overlay_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../app/providers.dart';
import '../../../../ui/composites/settings_widgets.dart';
import '../../../../ui/primitives/night_background.dart';
import '../../../../ui/primitives/page_back_button.dart';
import '../../../../ui/spaces/space_canvas.dart';
import '../../domain/sync_config.dart';
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
    final config = ref.watch(syncConfigProvider);
    final status = ref.watch(syncStatusProvider);
    final nightMode = ref.watch(nightModeProvider);
    final baseUrl = ref.watch(apiBaseUrlProvider);

    baseUrl.whenData((url) {
      if (_lastBaseUrl != url && !_savingUrl) {
        _lastBaseUrl = url;
        _urlController.text = url;
      }
    });

    final overlayStyle =
        nightMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Stack(children: [
        const Positioned.fill(child: NightBackgroundPlaceholder()),
        const Positioned.fill(child: AtmosphereBackground()),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(22, 12, 22,
                  64 + 10 + MediaQuery.paddingOf(context).bottom + 30),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SyncHeader(nightMode: nightMode),
                        const SizedBox(height: AppSpacing.s18),
                        _ConnectionCard(
                          status: status,
                          nightMode: nightMode,
                          testing: _testing,
                          syncing: _syncing,
                          onTestConnection: () => _testConnection(),
                          onSyncNow: () => _syncNow(),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _SectionLabel('连接参数', nightMode: nightMode),
                        const SizedBox(height: AppSpacing.sm),
                        _ServerUrlCard(
                          baseUrl: baseUrl,
                          controller: _urlController,
                          nightMode: nightMode,
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
                        const SizedBox(height: AppSpacing.md),
                        _SectionLabel('同步时机', nightMode: nightMode),
                        const SizedBox(height: AppSpacing.sm),
                        _Card(nightMode: nightMode, children: [
                          for (final freq in SyncFrequency.values)
                            _FrequencyTile(
                              frequency: freq,
                              selected: config.frequency == freq,
                              nightMode: nightMode,
                              onTap: () => _updateConfig(
                                  config.copyWith(frequency: freq)),
                            ),
                        ]),
                        const SizedBox(height: AppSpacing.md),
                        _SectionLabel('网络限制', nightMode: nightMode),
                        const SizedBox(height: AppSpacing.sm),
                        _Card(nightMode: nightMode, children: [
                          SettingsSwitchRow(
                            label: '仅在 Wi-Fi 下同步',
                            subtitle: '开启后，使用移动数据时不自动同步。',
                            value: config.wifiOnly,
                            nightMode: nightMode,
                            onChanged: (v) =>
                                _updateConfig(config.copyWith(wifiOnly: v)),
                          ),
                        ]),
                        const SizedBox(height: AppSpacing.md),
                        _SectionLabel('同步开关', nightMode: nightMode),
                        const SizedBox(height: AppSpacing.sm),
                        _Card(nightMode: nightMode, children: [
                          SettingsSwitchRow(
                            label: '启用云同步',
                            subtitle: '关闭后，光片仅保存在本地，不会推送到服务器。',
                            value: config.enabled,
                            nightMode: nightMode,
                            onChanged: (v) =>
                                _updateConfig(config.copyWith(enabled: v)),
                          ),
                        ]),
                      ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  void _updateConfig(SyncConfig config) {
    ref.read(syncConfigProvider.notifier).update(config);
    ref.read(syncEngineProvider).updateConfig(config);
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
      final engine = ref.read(syncEngineProvider);
      final status = await engine.syncNow();
      ref.read(syncStatusProvider.notifier).state = status;
      if (!mounted) return;
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
    required this.nightMode,
    required this.testing,
    required this.syncing,
    required this.onTestConnection,
    required this.onSyncNow,
  });

  final SyncStatus status;
  final bool nightMode;
  final bool testing;
  final bool syncing;
  final VoidCallback onTestConnection;
  final VoidCallback onSyncNow;

  @override
  Widget build(BuildContext context) {
    final hasError = status.error != null && status.error!.isNotEmpty;
    final statusTitle = status.connected
        ? '已连接'
        : hasError
            ? '后端暂时没有回应'
            : '等待连接确认';
    final statusHint = status.connected
        ? '本地修改会按下面的策略同步。'
        : hasError
            ? '请确认服务器地址、网络和后端服务状态。'
            : '点一下测试连接，确认当前服务器是否可用。';
    return _Card(nightMode: nightMode, children: [
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
              style: AppText.onNight(AppText.titleSmall, nightMode),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              statusHint,
              style: AppText.onNight(AppText.caption, nightMode),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
      ]),
      const SizedBox(height: AppSpacing.s12),
      _InfoRow(
          label: '服务端版本',
          value: 'Rev ${status.lastServerRev}',
          nightMode: nightMode),
      _InfoRow(
          label: '待推送',
          value: '${status.pendingCount} 条',
          nightMode: nightMode),
      _InfoRow(
          label: '上次同步',
          value: status.lastSyncAt != null
              ? '${status.lastSyncAt!.hour.toString().padLeft(2, '0')}:${status.lastSyncAt!.minute.toString().padLeft(2, '0')}:${status.lastSyncAt!.second.toString().padLeft(2, '0')}'
              : '尚未同步',
          nightMode: nightMode),
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
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.teaGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ]),
    ]);
  }
}

class _SyncHeader extends StatelessWidget {
  const _SyncHeader({required this.nightMode});

  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PageBackButton(
          onTap: () => Navigator.of(context).maybePop(),
          nightMode: nightMode,
          iconColor: nightMode ? AppText.nightInk : AppColors.ink,
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Text(
            '云同步',
            style: AppText.onNight(
              AppText.titleLarge,
              nightMode,
            ),
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
    required this.nightMode,
    required this.saving,
    required this.errorText,
    required this.onChanged,
    required this.onSave,
    required this.onReset,
  });

  final AsyncValue<String> baseUrl;
  final TextEditingController controller;
  final bool nightMode;
  final bool saving;
  final String? errorText;
  final ValueChanged<String> onChanged;
  final VoidCallback onSave;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final loading = baseUrl.isLoading || saving;
    final inputFill = nightMode
        ? AppColors.white.withValues(alpha: .08)
        : AppColors.mistBlue.withValues(alpha: .12);
    final borderColor =
        nightMode ? AppColors.white.withValues(alpha: .14) : AppColors.line;

    return _Card(nightMode: nightMode, children: [
      TextField(
        controller: controller,
        enabled: !loading,
        keyboardType: TextInputType.url,
        autocorrect: false,
        onChanged: onChanged,
        style: AppText.onNight(AppText.body, nightMode),
        decoration: InputDecoration(
          labelText: '后端地址',
          hintText: 'http://127.0.0.1:8088/api/v1',
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
            style: AppText.onNight(AppText.caption, nightMode)
                .copyWith(color: AppColors.sunsetCoral)),
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

class _FrequencyTile extends StatelessWidget {
  const _FrequencyTile({
    required this.frequency,
    required this.selected,
    required this.nightMode,
    required this.onTap,
  });

  final SyncFrequency frequency;
  final bool selected;
  final bool nightMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.s12, horizontal: AppSpacing.xs),
        child: Row(children: [
          Expanded(
            child: Text(frequency.label,
                style: AppText.onNight(AppText.titleSmall, nightMode)),
          ),
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 20,
            color: selected
                ? AppColors.teaGreen
                : (nightMode ? AppText.nightInkMuted : AppColors.inkMuted),
          ),
        ]),
      ),
    );
  }
}

// _SwitchTile 已删除，统一用 ui/composites/settings_widgets.dart 的 SettingsSwitchRow。

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {required this.nightMode});
  final String label;
  final bool nightMode;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: AppSpacing.s2),
        child: Text(label, style: AppText.onNight(AppText.eyebrow, nightMode)),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.nightMode, required this.children});
  final bool nightMode;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.s18),
        decoration:
            nightMode ? nightDecoration() : softDecoration(AppColors.white),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.label, required this.value, required this.nightMode});
  final String label, value;
  final bool nightMode;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.s10),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              SizedBox(
                  width: 80,
                  child: Text(label,
                      style: AppText.onNight(AppText.caption, nightMode))),
              Expanded(
                  child: Text(value,
                      style: AppText.onNight(AppText.body, nightMode))),
            ]),
      );
}

// nightDecoration() 已移除，使用 shadows.dart 中的 nightDecoration()
