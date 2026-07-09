import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../data/fragment_repository.dart';

final fragmentRepositoryProvider = Provider<FragmentRepository>((ref) {
  return FragmentRepository(
    ref.watch(apiClientProvider),
    ref.watch(authRepositoryProvider),
    db: ref.watch(appDatabaseProvider),
  );
});

final fragmentsProvider =
    AsyncNotifierProvider<FragmentsNotifier, List<LightFragmentModel>>(
  FragmentsNotifier.new,
);

class FragmentsNotifier extends AsyncNotifier<List<LightFragmentModel>> {
  @override
  Future<List<LightFragmentModel>> build() async {
    final repo = ref.watch(fragmentRepositoryProvider);
    final local = await repo.listLocalFragments();
    if (local.isNotEmpty) {
      // 本地优先：先把已知内容渲染出来，避免远端响应到达前页面只能显示空态/骨架，
      // 切换到远端后端时尤其能消除文本"突变"。远端结果在后台刷新。
      unawaited(_refreshFromRemote(repo, hasLocal: true));
      return local;
    }
    // 本地暂时为空（新装/重装），只有等远端响应才知道该不该显示空态。
    final remote = await repo.tryListRemoteFragments();
    return remote ?? const [];
  }

  Future<void> _refreshFromRemote(
    FragmentRepository repo, {
    required bool hasLocal,
  }) async {
    final remote = await repo.tryListRemoteFragments();
    if (remote == null) return;
    // 远端返回空但本地有内容时不要覆盖本地；避免清空已有展示。
    if (remote.isEmpty && hasLocal) return;
    state = AsyncData(remote);
    _invalidateDerived();
  }

  Future<void> capture({
    required String text,
    required String emotion,
    required List<String> tags,
    List<String> mediaUrls = const [],
  }) async {
    await captureWithResult(
      text: text,
      emotion: emotion,
      tags: tags,
      mediaUrls: mediaUrls,
    );
  }

  Future<LightFragmentModel> captureWithResult({
    required String text,
    required String emotion,
    required List<String> tags,
    List<String> mediaUrls = const [],
  }) async {
    final previous = state.value ?? const [];
    state =
        const AsyncLoading<List<LightFragmentModel>>().copyWithPrevious(state);
    try {
      final created = await ref.read(fragmentRepositoryProvider).createFragment(
            text: text,
            emotion: emotion,
            tags: tags,
            mediaUrls: mediaUrls,
          );
      _commitCapturedFragment(created, previous);
      return created;
    } on LocalDraftException catch (error) {
      _commitCapturedFragment(error.fragment, previous);
      return error.fragment;
    } catch (error, stackTrace) {
      state = AsyncError<List<LightFragmentModel>>(error, stackTrace)
          .copyWithPrevious(AsyncData(previous));
      rethrow;
    }
  }

  void _commitCapturedFragment(
    LightFragmentModel fragment,
    List<LightFragmentModel> previous,
  ) {
    state = AsyncData([
      fragment,
      ...previous.where((item) => item.id != fragment.id),
    ]);
    _invalidateDerived();
  }

  Future<void> refresh() async {
    state =
        const AsyncLoading<List<LightFragmentModel>>().copyWithPrevious(state);
    state = await AsyncValue.guard(
        () => ref.watch(fragmentRepositoryProvider).listFragments());
  }

  /// H5: Centralized update — updates fragment text and invalidates derived providers.
  Future<void> updateText(
    int id,
    String newText, {
    String emotion = '说不清',
    List<String> tags = const [],
    List<String>? mediaUrls,
  }) async {
    final previous = state.value ?? const [];
    try {
      await ref.read(fragmentRepositoryProvider).updateFragmentText(
            id,
            newText,
            emotion: emotion,
            tags: tags,
            mediaUrls: mediaUrls,
          );
      // Update local state optimistically
      state = AsyncData(previous.map((f) {
        if (f.id != id) return f;
        return LightFragmentModel(
          id: f.id,
          contentText: newText,
          emotion: emotion,
          tags: tags,
          mediaUrls: mediaUrls ?? f.mediaUrls,
          createdAt: f.createdAt,
          status: f.status,
        );
      }).toList());
      _invalidateDerived();
    } catch (error, stackTrace) {
      state = AsyncError<List<LightFragmentModel>>(error, stackTrace)
          .copyWithPrevious(AsyncData(previous));
      rethrow;
    }
  }

  void _invalidateDerived() {
    try {
      ref.invalidate(islandsProvider);
      ref.invalidate(localTimelineGroupsProvider);
    } catch (_) {}
  }

  Future<void> deleteMany(Set<int> ids) async {
    if (ids.isEmpty) return;
    final previous = state.value ?? const [];
    state =
        AsyncData(previous.where((item) => !ids.contains(item.id)).toList());
    try {
      final repository = ref.watch(fragmentRepositoryProvider);
      for (final id in ids) {
        await repository.deleteFragment(id);
      }
      _invalidateDerived();
    } catch (error, stackTrace) {
      state = AsyncError<List<LightFragmentModel>>(error, stackTrace)
          .copyWithPrevious(AsyncData(previous));
      rethrow;
    }
  }
}
