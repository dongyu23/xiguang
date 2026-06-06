import 'dart:io';

import 'package:xiguang/features/auth/data/auth_repository.dart';
import 'package:xiguang/features/shared/data/api_client.dart';

Future<void> main(List<String> args) async {
  final baseUrl = Platform.environment['API_BASE_URL'] ??
      (args.isNotEmpty ? args.first : 'http://127.0.0.1:8088/api/v1');
  final api = ApiClient(baseUrl: baseUrl);
  final auth = AuthRepository(api);

  final usernameSuffix = DateTime.now().microsecondsSinceEpoch;
  try {
    await auth.me();
    throw StateError('AuthRepository.me should require login first');
  } on StateError {
    _check(!api.hasToken, 'me() before login should not create a local token');
  }

  final account = await auth.register(
    username: 'flutter_contract_$usernameSuffix',
    password: 'xiguang-contract',
    nickname: '契约试光者',
  );
  _check(account.username == 'flutter_contract_$usernameSuffix',
      'registered user should round-trip username');
  _check(api.hasToken && api.debugAccessTokenForVerification() != null,
      'ApiClient should hold a bearer token after remote auth');

  final me = await auth.me();
  _check(me.publicId.isNotEmpty, 'GET /users/me should expose public_id');
  _check(me.nickname == '契约试光者', 'GET /users/me should expose nickname');

  final updatedUser = await auth.updateMe(
    nickname: '契约试光者$usernameSuffix',
    avatarKey: 'avatars/contract-$usernameSuffix.png',
    aiEnabled: true,
    privacyMode: 'local',
  );
  _check(updatedUser.nickname == '契约试光者$usernameSuffix',
      'PUT /users/me should update nickname');
  _check(updatedUser.avatarKey == 'avatars/contract-$usernameSuffix.png',
      'PUT /users/me should update avatar_key');
  _check(updatedUser.aiEnabled, 'PUT /users/me should update ai_enabled');
  _check(updatedUser.privacyMode == 'local',
      'PUT /users/me should update privacy_mode');

  final updatedMe = await auth.me();
  _check(updatedMe.nickname == updatedUser.nickname,
      'GET /users/me should read back updated profile');

  final createdIDs = <int>[];
  for (var i = 1; i <= 3; i++) {
    final created = await api.post('/fragments', {
      'content_text': 'flutter contract light $i',
      'emotion': '平静',
      'tag_names': ['flutter-contract', '微光'],
      'client_op_id': 'flutter-contract-$usernameSuffix-$i',
    });
    _check(created['id'] is int, 'created fragment should include integer id');
    createdIDs.add(created['id'] as int);
  }

  final fragments = await api.get('/fragments', query: {'limit': 20});
  final fragmentItems = fragments['value'] as List<dynamic>? ?? const [];
  _check(
    fragmentItems.any((item) =>
        item is Map<String, dynamic> &&
        item['content_text'] == 'flutter contract light 1'),
    'ApiClient should unwrap list responses from /fragments',
  );

  final detail = await api.get('/fragments/${createdIDs.first}');
  _check(
      detail['emotion'] == '平静', 'fragment detail should round-trip emotion');

  final weave = await api.post('/fragments/${createdIDs.first}/weave', {
    'target_fragment_id': createdIDs[1],
    'relation_type': 'reminds_me',
    'note': 'flutter contract weave',
  });
  _check(weave['relation_type'] == 'reminds_me',
      'weave endpoint should return the created relation');

  final timeline = await api.get('/timeline');
  final groups = timeline['groups'] as List<dynamic>? ?? const [];
  _check(groups.isNotEmpty, 'timeline should return date groups');

  final islands = await api.get('/islands');
  final islandItems = islands['islands'] as List<dynamic>? ?? const [];
  _check(
    islandItems.any((item) =>
        item is Map<String, dynamic> &&
        item['name'] == 'flutter-contract' &&
        item['fragment_count'] == 3),
    'islands should include rule-grown flutter-contract star point',
  );

  stdout.writeln('flutter-backend-contract-ok');
}

void _check(bool condition, String message) {
  if (!condition) {
    throw StateError(message);
  }
}
