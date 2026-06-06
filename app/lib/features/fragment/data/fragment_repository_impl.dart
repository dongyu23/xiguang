import '../domain/create_params.dart';
import '../domain/fragment.dart';
import '../domain/fragment_repository.dart';
import 'remote/fragment_api.dart';

class FragmentRepositoryImpl implements FragmentRepositoryContract {
  const FragmentRepositoryImpl(this._api);

  final FragmentApi _api;

  @override
  Future<Fragment> create(CreateFragmentParams params) async {
    final body = await _api.create({
      'content_text': params.contentText,
      'emotion': params.emotion,
      'tag_names': params.tagNames,
    });
    return _fragmentFromJson(body);
  }

  @override
  Future<void> delete(int id) async {}

  @override
  Future<Fragment?> getById(int id) async =>
      _fragmentFromJson(await _api.getById(id));

  @override
  Future<List<Fragment>> list() async => const [];

  @override
  Future<Fragment> update(Fragment fragment) async => fragment;

  Fragment _fragmentFromJson(Map<String, dynamic> json) {
    return Fragment(
      id: json['id'] as int? ?? 0,
      publicId: json['public_id'] as String? ?? '',
      userId: json['user_id'] as int? ?? 0,
      contentText: json['content_text'] as String? ?? '',
      emotion: json['emotion'] as String?,
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((e) => '$e')
          .toList(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
