import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sante/config/app_constants.dart';
import 'package:sante/models/user.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();

  factory ApiService() => _instance;

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
        contentType: Headers.jsonContentType,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    SharedPreferences.getInstance().then((p) => _prefs = p);
    _dio.interceptors.add(_TokenInterceptor(this));
  }

  late Dio _dio;
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Auth endpoints
  Future<Map<String, dynamic>> login(String email, String password) async {
    // Debug log for tracing login attempts in browser console
    // ignore: avoid_print
    print('ApiService.login called for: $email');

    late final Response<dynamic> response;
    try {
      response = await _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
    } on DioException catch (e) {
      throw Exception(
        e.type == DioExceptionType.connectionTimeout
            ? 'Serveur inaccessible. Vérifiez que le backend est lancé et que l’URL API est joignable.'
            : 'Connexion réseau impossible. Vérifiez l’adresse API et le téléphone.',
      );
    }

    // ignore: avoid_print
    print(
      'ApiService.login response status: ${response.statusCode}, data: ${response.data}',
    );

    if (response.statusCode == 200) {
      final data = response.data;
      await saveTokens(data['accessToken'], data['refreshToken']);
      return data;
    } else {
      throw Exception(response.data['message'] ?? 'Login failed');
    }
  }

  /// Register a clinic (POST /inscription/clinique)
  Future<Map<String, dynamic>> registerClinique(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post('/inscription/clinique', data: payload);
    if (response.statusCode == 201 || response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data);
    } else {
      throw Exception(response.data['message'] ?? 'Registration failed');
    }
  }

  Future<Map<String, dynamic>> registerPharmacie(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post('/inscription/pharmacie', data: payload);
    if (response.statusCode == 201 || response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data);
    } else {
      throw Exception(response.data['message'] ?? 'Registration failed');
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (_) {
      // Logout should still clear the local session if the server is unreachable.
    }
    await clearTokens();
  }

  Future<Map<String, dynamic>> refreshToken() async {
    final refreshToken = getRefreshToken();
    if (refreshToken == null) throw Exception('No refresh token');

    final response = await _dio.post(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );

    if (response.statusCode == 200) {
      await saveAccessToken(response.data['accessToken']);
      return response.data;
    } else {
      throw Exception('Token refresh failed');
    }
  }

  Future<User> getMe() async {
    final response = await _dio.get('/auth/me');
    if (response.statusCode == 200) {
      return User.fromJson(response.data['user']);
    } else {
      throw Exception('Failed to fetch current user');
    }
  }

  Future<Map<String, dynamic>> getMyProfile() async {
    final response = await _dio.get('/auth/me');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data ?? {});
    } else {
      throw Exception(response.data['message'] ?? 'Failed to fetch profile');
    }
  }

  Future<Map<String, dynamic>> updateMyProfile(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.patch('/auth/me', data: payload);
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data ?? {});
    } else {
      throw Exception(response.data['message'] ?? 'Failed to update profile');
    }
  }

  // Patient endpoints
  Future<Map<String, dynamic>> getPatientDossier(String patientId) async {
    final response = await _dio.get('/patients/$patientId');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data ?? {});
    } else {
      throw Exception(
        response.data['message'] ?? 'Failed to fetch patient dossier',
      );
    }
  }

  Future<List<Map<String, dynamic>>> getPatients({String? search}) async {
    final response = await _dio.get(
      '/patients',
      queryParameters: search != null ? {'search': search} : {},
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(response.data ?? []);
    } else {
      throw Exception('Failed to fetch patients');
    }
  }

  Future<Map<String, dynamic>> createPatient(Map<String, dynamic> data) async {
    final response = await _dio.post('/patients', data: data);
    if (response.statusCode == 201 || response.statusCode == 200) {
      final body = Map<String, dynamic>.from(response.data ?? {});
      return Map<String, dynamic>.from(body['patient'] ?? body);
    } else {
      throw Exception(response.data['message'] ?? 'Failed to create patient');
    }
  }

  Future<Map<String, dynamic>> getPatientByDossierNumber(
    String dossierNumber,
  ) async {
    final response = await _dio.get('/patients/numero/$dossierNumber');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data ?? {});
    } else {
      throw Exception(response.data['message'] ?? 'Patient introuvable');
    }
  }

  Future<Map<String, dynamic>> getPatientByQrToken(String qrToken) async {
    final response = await _dio.get('/patients/qr/$qrToken');
    if (response.statusCode == 200) {
      final body = Map<String, dynamic>.from(response.data ?? {});
      return Map<String, dynamic>.from(body['patient'] ?? body);
    } else {
      throw Exception(response.data['message'] ?? 'QR patient invalide');
    }
  }

  Future<Map<String, dynamic>> getAdminStats() async {
    final response = await _dio.get('/admin/stats');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data ?? {});
    } else {
      throw Exception(
        response.data['message'] ?? 'Failed to fetch admin stats',
      );
    }
  }

  Future<List<Map<String, dynamic>>> getAdminClinics({String? status}) async {
    final response = await _dio.get(
      '/admin/cliniques',
      queryParameters: status != null ? {'status': status} : {},
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(response.data ?? []);
    } else {
      throw Exception(response.data['message'] ?? 'Failed to fetch clinics');
    }
  }

  Future<List<Map<String, dynamic>>> getAdminPharmacies({
    String? status,
  }) async {
    final response = await _dio.get(
      '/admin/pharmacies',
      queryParameters: status != null ? {'status': status} : {},
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(response.data ?? []);
    } else {
      throw Exception(response.data['message'] ?? 'Failed to fetch pharmacies');
    }
  }

  Future<List<Map<String, dynamic>>> getAdminPatients() async {
    final response = await _dio.get('/admin/patients');
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(response.data ?? []);
    } else {
      throw Exception(response.data['message'] ?? 'Failed to fetch patients');
    }
  }

  Future<List<Map<String, dynamic>>> getAdminCartes() async {
    final response = await _dio.get('/admin/cartes');
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(response.data ?? []);
    } else {
      throw Exception(response.data['message'] ?? 'Failed to fetch cards');
    }
  }

  Future<List<Map<String, dynamic>>> getAdminLogs() async {
    final response = await _dio.get('/admin/logs');
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(response.data ?? []);
    } else {
      throw Exception(response.data['message'] ?? 'Failed to fetch logs');
    }
  }

  Future<Map<String, dynamic>> approveClinique(String id) async {
    final response = await _dio.patch('/admin/cliniques/$id/approve');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data ?? {});
    } else {
      throw Exception(response.data['message'] ?? 'Failed to approve clinic');
    }
  }

  Future<Map<String, dynamic>> rejectClinique(String id) async {
    final response = await _dio.patch('/admin/cliniques/$id/reject');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data ?? {});
    } else {
      throw Exception(response.data['message'] ?? 'Failed to reject clinic');
    }
  }

  Future<Map<String, dynamic>> approvePharmacie(String id) async {
    final response = await _dio.patch('/admin/pharmacies/$id/approve');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data ?? {});
    } else {
      throw Exception(response.data['message'] ?? 'Failed to approve pharmacy');
    }
  }

  Future<Map<String, dynamic>> rejectPharmacie(String id) async {
    final response = await _dio.patch('/admin/pharmacies/$id/reject');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data ?? {});
    } else {
      throw Exception(response.data['message'] ?? 'Failed to reject pharmacy');
    }
  }

  Future<Map<String, dynamic>> updateCarteStatus(
    String id,
    String status,
  ) async {
    final response = await _dio.patch(
      '/admin/cartes/$id/status',
      data: {'status': status},
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data ?? {});
    } else {
      throw Exception(
        response.data['message'] ?? 'Failed to update card status',
      );
    }
  }

  // Ordonnance endpoints
  Future<Map<String, dynamic>> scanOrdonnance(String qrToken) async {
    final response = await _dio.get('/ordonnances/qr/$qrToken');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data ?? {});
    } else if (response.statusCode == 409) {
      throw Exception('DÉJÀ UTILISÉE');
    } else {
      throw Exception(response.data['message'] ?? 'ORDONNANCE INVALIDE');
    }
  }

  Future<List<Map<String, dynamic>>> getPharmacyDeliveries() async {
    final response = await _dio.get('/pharmacie/delivrances');
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(response.data ?? []);
    } else {
      throw Exception(response.data['message'] ?? 'Failed to fetch deliveries');
    }
  }

  Future<Map<String, dynamic>> getPharmacyStats() async {
    final response = await _dio.get('/pharmacie/stats');
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data ?? {});
    } else {
      throw Exception(
        response.data['message'] ?? 'Failed to fetch pharmacy stats',
      );
    }
  }

  Future<Map<String, dynamic>> deliverOrdonnance(
    String ordonnanceId,
    List<Map<String, dynamic>> medicaments,
  ) async {
    final response = await _dio.patch(
      '/ordonnances/$ordonnanceId/deliver',
      data: {'medicamentsDelivres': medicaments},
    );
    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception(response.data['message'] ?? 'Failed to confirm delivery');
    }
  }

  Future<Map<String, dynamic>> createConsultation(
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.post('/consultations', data: data);
    if (response.statusCode == 201 || response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data ?? {});
    } else {
      throw Exception(
        response.data['message'] ?? 'Failed to create consultation',
      );
    }
  }

  Future<Map<String, dynamic>> createOrdonnance(
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.post('/ordonnances', data: data);
    if (response.statusCode == 201 || response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data ?? {});
    } else {
      throw Exception(
        response.data['message'] ?? 'Failed to create ordonnance',
      );
    }
  }

  Future<Map<String, dynamic>> orderPatientCard(String patientId) async {
    final response = await _dio.post('/patients/$patientId/commande-carte');
    if (response.statusCode == 201 || response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data ?? {});
    } else {
      throw Exception(response.data['message'] ?? 'Failed to order card');
    }
  }

  Future<List<Map<String, dynamic>>> getClinicConsultations() async {
    final response = await _dio.get('/consultations');
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(response.data ?? []);
    } else {
      throw Exception(
        response.data['message'] ?? 'Failed to fetch consultations',
      );
    }
  }

  Future<List<Map<String, dynamic>>> getClinicOrdonnances() async {
    final response = await _dio.get('/ordonnances');
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(response.data ?? []);
    } else {
      throw Exception(
        response.data['message'] ?? 'Failed to fetch ordonnances',
      );
    }
  }

  // Token management
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await init();
    await _prefs?.setString(AppConstants.keyAccessToken, accessToken);
    await _prefs?.setString(AppConstants.keyRefreshToken, refreshToken);
  }

  Future<void> saveAccessToken(String accessToken) async {
    await init();
    await _prefs?.setString(AppConstants.keyAccessToken, accessToken);
  }

  String? getAccessToken() {
    return _prefs?.getString(AppConstants.keyAccessToken);
  }

  String? getRefreshToken() {
    return _prefs?.getString(AppConstants.keyRefreshToken);
  }

  Future<void> clearTokens() async {
    await init();
    await _prefs?.remove(AppConstants.keyAccessToken);
    await _prefs?.remove(AppConstants.keyRefreshToken);
  }
}

class _TokenInterceptor extends Interceptor {
  final ApiService apiService;

  _TokenInterceptor(this.apiService);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = apiService.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Try to refresh token
    }
    handler.next(err);
  }
}
