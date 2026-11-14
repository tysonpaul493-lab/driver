import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'reverb_service.dart';

final reverbServiceProvider = Provider<ReverbService>((ref) {
  final service = ReverbService();

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

final reverbConnectionStateProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(reverbServiceProvider);
  return service.onConnectionStateChanged;
});
