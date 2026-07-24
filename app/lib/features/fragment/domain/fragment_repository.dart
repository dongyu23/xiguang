import 'create_params.dart';
import 'fragment.dart';
import '../../relation/domain/relation.dart';

class CursorPage<T> {
  const CursorPage({
    required this.items,
    this.nextCursor,
    this.hasMore = false,
  });

  final List<T> items;
  final String? nextCursor;
  final bool hasMore;
}

class LocalDraftException implements Exception {
  const LocalDraftException(this.fragment);

  final Fragment fragment;
}

typedef FragmentChangedCallback = void Function(
  String entityType,
  String opType,
  int fragmentId,
  Map<String, dynamic> payload,
);

abstract interface class FragmentRepositoryContract {
  FragmentChangedCallback? get onFragmentChanged;
  set onFragmentChanged(FragmentChangedCallback? callback);

  Future<List<Fragment>> listFragments();
  Future<List<Fragment>> listLocalFragments();
  Future<List<Fragment>?> tryListRemoteFragments();
  Future<List<Fragment>> searchFragments(String query);
  Future<List<Fragment>> listDeletedFragments();
  Future<void> restoreFragment(int id);
  Future<void> permanentlyDeleteFragment(int id);
  Future<CursorPage<Fragment>> listFragmentsPaged({
    String? cursor,
    int limit = 20,
  });
  Future<Fragment> createFragment({
    required String text,
    required String emotion,
    required List<String> tags,
    List<String> mediaUrls = const [],
  });
  Future<Fragment?> getFragment(int id);
  Future<void> updateFragmentText(
    int id,
    String newText, {
    String emotion = '说不清',
    List<String> tags = const [],
    List<String>? mediaUrls,
  });
  Future<void> deleteFragment(int id);
  Future<Relation?> weave({
    required int sourceFragmentId,
    required int targetFragmentId,
    String relationType = 'reminds_me',
    String? note,
  });

  Future<List<Fragment>> list();
  Future<Fragment?> getById(int id);
  Future<Fragment> create(CreateFragmentParams params);
  Future<Fragment> update(Fragment fragment);
  Future<void> delete(int id);
}
