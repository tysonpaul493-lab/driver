import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'reverb_service.dart';

final reverbServiceProvider = Provider<ReverbService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final service = ReverbService(storage);

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

final reverbConnectionStateProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(reverbServiceProvider);
  return service.onConnectionStateChanged;
});
