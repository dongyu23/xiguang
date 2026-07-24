import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/device_session.dart';
import '../domain/auth_repository.dart';

final deviceManagementControllerProvider =
    Provider<DeviceManagementController>((ref) {
  return DeviceManagementController(ref.watch(authRepositoryProvider));
});

class DeviceManagementController {
  const DeviceManagementController(this._repository);

  final AuthRepositoryContract _repository;

  Future<(List<DeviceSession>, String)> load() async {
    final values = await Future.wait([
      _repository.listDevices(),
      _repository.currentDeviceId(),
    ]);
    return (values[0] as List<DeviceSession>, values[1] as String);
  }

  Future<void> revoke(int id) => _repository.revokeDevice(id);
}
