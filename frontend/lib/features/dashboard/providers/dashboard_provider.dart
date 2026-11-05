import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/websocket/reverb_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../location/providers/location_provider.dart';
import '../models/dashboard_summary_model.dart';
import '../repositories/dashboard_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final dio = ref.watch(dioClientProvider);
  final storage = ref.watch(storageServiceProvider);
  return DashboardRepository(dio, storage);
});

final dashboardSummaryProvider = FutureProvider<DashboardSummaryModel>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  return await repo.getSummary();
});

class OnlineStatusState {
  final bool isOnline;
  final bool isLoading;
  final String? errorMessage;

  const OnlineStatusState({
    this.isOnline = false,
    this.isLoading = false,
    this.errorMessage,
  });

  OnlineStatusState copyWith({
    bool? isOnline,
    bool? isLoading,
    String? errorMessage,
  }) {
    return OnlineStatusState(
      isOnline: isOnline ?? this.isOnline,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class OnlineStatusNotifier extends StateNotifier<OnlineStatusState> {
  final DashboardRepository _repository;
  final Ref _ref;

  OnlineStatusNotifier(this._repository, this._ref) : super(const OnlineStatusState()) {
    _initFromStorage();
  }

  Future<void> _initFromStorage() async {
    final storage = _ref.read(storageServiceProvider);
    final isOnline = await storage.getOnlineStatus();
    state = state.copyWith(isOnline: isOnline);

    if (isOnline) {
      final driver = _ref.read(currentDriverProvider);
      if (driver != null) {
        _ref.read(reverbServiceProvider).connect(driver.id);
        _ref.read(driverLocationProvider.notifier).startTracking();
      }
    }
  }

  /// Toggle online / offline switch with full pre-flight validation
  Future<bool> toggleOnline(bool targetOnline) async {
    final driver = _ref.read(currentDriverProvider);

    // 1. Validate driver verification status
    if (targetOnline && (driver == null || !driver.verificationStatus.isApproved)) {
      state = state.copyWith(
        errorMessage: 'Administrative approval required. Your documents are currently under review.',
      );
      return false;
    }

    // 2. Validate vehicle eligibility
    if (targetOnline && !(driver?.assignedVehicle?.isEligible ?? true)) {
      state = state.copyWith(
        errorMessage: 'Assigned ambulance vehicle is not marked eligible for emergency operations.',
      );
      return false;
    }

    // 3. Validate GPS Location permission
    if (targetOnline) {
      final locationService = _ref.read(locationServiceProvider);
      final hasPermission = await locationService.checkAndRequestPermissions();
      if (!hasPermission) {
        state = state.copyWith(
          errorMessage: 'High accuracy GPS permission is required to receive ambulance dispatch requests.',
        );
        return false;
      }
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final locationState = _ref.read(driverLocationProvider);
      final newStatus = await _repository.toggleOnlineStatus(
        targetOnline,
        latitude: locationState.latitude,
        longitude: locationState.longitude,
      );

      state = state.copyWith(isOnline: newStatus, isLoading: false);

      if (newStatus && driver != null) {
        // Connect to Laravel Reverb WebSocket
        await _ref.read(reverbServiceProvider).connect(driver.id);
        // Start telemetry tracking
        await _ref.read(driverLocationProvider.notifier).startTracking();
      } else {
        // Stop telemetry tracking and disconnect Reverb
        await _ref.read(driverLocationProvider.notifier).stopTracking();
        await _ref.read(reverbServiceProvider).disconnect();
      }

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to update online status: $e',
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final onlineStatusProvider = StateNotifierProvider<OnlineStatusNotifier, OnlineStatusState>((ref) {
  final repo = ref.watch(dashboardRepositoryProvider);
  return OnlineStatusNotifier(repo, ref);
});
