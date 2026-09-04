import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sante/models/user.dart';
import 'package:sante/services/api_service.dart';
import 'package:sante/services/local_storage_service.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
      final apiService = ref.watch(apiServiceProvider);
      return AuthNotifier(apiService);
    });

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final ApiService apiService;

  AuthNotifier(this.apiService) : super(const AsyncValue.loading());

  Future<void> restoreSession() async {
    state = const AsyncValue.loading();
    try {
      await apiService.init();
      final token = apiService.getAccessToken();
      final refreshToken = apiService.getRefreshToken();
      final cachedUser = LocalStorageService.getUserData();

      if ((token == null || token.isEmpty) &&
          (refreshToken == null || refreshToken.isEmpty)) {
        await LocalStorageService.clearUserData();
        state = const AsyncValue.data(null);
        return;
      }

      if (cachedUser != null) {
        state = AsyncValue.data(User.fromJson(cachedUser));
      }

      try {
        final user = await apiService.getMe();
        await LocalStorageService.saveUserData(user.toJson());
        state = AsyncValue.data(user);
        return;
      } catch (_) {
        // The access token may simply be expired after reopening the app.
      }

      try {
        await apiService.refreshToken();
        final user = await apiService.getMe();
        await LocalStorageService.saveUserData(user.toJson());
        state = AsyncValue.data(user);
        return;
      } catch (_) {
        if (cachedUser != null) {
          state = AsyncValue.data(User.fromJson(cachedUser));
          return;
        }
        await apiService.clearTokens();
        await LocalStorageService.clearUserData();
        state = const AsyncValue.data(null);
      }
    } catch (e) {
      final cachedUser = LocalStorageService.getUserData();
      if (cachedUser != null) {
        state = AsyncValue.data(User.fromJson(cachedUser));
      } else {
        await apiService.clearTokens();
        await LocalStorageService.clearUserData();
        state = const AsyncValue.data(null);
      }
    }
  }

  Future<void> login(String email, String password) async {
    try {
      await apiService.init();
      final result = await apiService.login(email, password);
      final user = User.fromJson(result['user']);
      await LocalStorageService.saveUserData(user.toJson());
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = const AsyncValue.data(null);
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    try {
      await apiService.logout();
      await LocalStorageService.clearUserData();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      await LocalStorageService.clearUserData();
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refreshUser() async {
    try {
      final user = await apiService.getMe();
      await LocalStorageService.saveUserData(user.toJson());
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
