import 'package:dio/dio.dart';
import '../../config/constants.dart';
import '../services/storage_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: _getBaseUrl(),
      connectTimeout: Duration(milliseconds: _getRequestTimeout()),
      receiveTimeout: Duration(milliseconds: _getRequestTimeout()),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    
    // Add interceptors
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await StorageService().getAuthToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        // Handle 401 errors - auto logout
        if (error.response?.statusCode == 401) {
          await StorageService().clearAll();
        }
        return handler.next(error);
      },
    ));
  }

  late Dio _dio;

  // Helper methods with fallback values
  String _getBaseUrl() {
    try {
      // Try to get from AppConstants, fallback to localhost
      return '${AppConstants.baseUrl}${AppConstants.apiVersion}';
    } catch (e) {
      return 'http://localhost:5000/api/v1';
    }
  }

  int _getRequestTimeout() {
    try {
      // Try to get from AppConstants, fallback to 30 seconds
      return AppConstants.requestTimeout;
    } catch (e) {
      return 30000; // 30 seconds default
    }
  }

  // API endpoints with fallback values
  String get _loginEndpoint => '/auth/login';
  String get _doctorLoginEndpoint => '/auth/doctor/login';
  String get _registerEndpoint => '/auth/register';
  String get _profileEndpoint => '/user/profile';
  String get _setupPinEndpoint => '/user/setup-pin';
  String get _appointmentsEndpoint => '/appointments';
  String get _medicalRecordsEndpoint => '/medical-records';

  // =============================================
  // PATIENT LOGIN
  // =============================================
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _dio.post(
        _loginEndpoint,
        data: {'email': email, 'password': password},
      );
      
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final token = data['token'] ?? data['access_token'];
        if (token != null) {
          await StorageService().saveAuthToken(token.toString());
        }
        return {'success': true, 'data': data};
      }
      return {'success': false, 'error': 'Invalid credentials'};
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return {'success': false, 'error': 'An unexpected error occurred: $e'};
    }
  }

  // =============================================
  // DOCTOR LOGIN
  // =============================================
  Future<Map<String, dynamic>> loginDoctor(String email, String password) async {
    try {
      final response = await _dio.post(
        _doctorLoginEndpoint,
        data: {'email': email, 'password': password},
      );
      
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final token = data['token'] ?? data['access_token'];
        if (token != null) {
          await StorageService().saveAuthToken(token.toString());
        }
        return {'success': true, 'data': data};
      }
      return {'success': false, 'error': 'Invalid doctor credentials'};
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return {'success': false, 'error': 'An unexpected error occurred: $e'};
    }
  }

  // =============================================
  // REGISTER
  // =============================================
  Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    try {
      final response = await _dio.post(
        _registerEndpoint,
        data: userData,
      );
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final token = data['token'] ?? data['access_token'];
        if (token != null) {
          await StorageService().saveAuthToken(token.toString());
        }
        return {'success': true, 'data': data};
      }
      return {'success': false, 'error': 'Registration failed'};
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return {'success': false, 'error': 'An unexpected error occurred: $e'};
    }
  }

  // =============================================
  // PROFILE
  // =============================================
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await _dio.get(_profileEndpoint);
      
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        await StorageService().saveUserProfile(data);
        return {'success': true, 'data': data};
      }
      return {'success': false, 'error': 'Failed to fetch profile'};
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return {'success': false, 'error': 'An unexpected error occurred: $e'};
    }
  }

  // =============================================
  // PIN SETUP
  // =============================================
  Future<Map<String, dynamic>> setupPin(String pin, String confirmPin) async {
    try {
      final response = await _dio.post(
        _setupPinEndpoint,
        data: {'pin': pin, 'confirm_pin': confirmPin},
      );
      
      if (response.statusCode == 200) {
        return {'success': true, 'data': response.data};
      }
      return {'success': false, 'error': 'Failed to setup PIN'};
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return {'success': false, 'error': 'An unexpected error occurred: $e'};
    }
  }

  // =============================================
  // APPOINTMENTS
  // =============================================
  Future<Map<String, dynamic>> getAppointments() async {
    try {
      final response = await _dio.get(_appointmentsEndpoint);
      
      if (response.statusCode == 200) {
        // IMPORTANT FIX: Return the raw response data directly
        // The backend returns { "appointments": [...], "count": 8 }
        final data = response.data as Map<String, dynamic>;
        return {'success': true, ...data};
      }
      return {'success': false, 'error': 'Failed to fetch appointments'};
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return {'success': false, 'error': 'An unexpected error occurred: $e'};
    }
  }

  Future<Map<String, dynamic>> bookAppointment(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(
        _appointmentsEndpoint,
        data: data,
      );
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'data': response.data};
      }
      return {'success': false, 'error': 'Failed to book appointment'};
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return {'success': false, 'error': 'An unexpected error occurred: $e'};
    }
  }

  // =============================================
  // MEDICAL RECORDS
  // =============================================
  Future<Map<String, dynamic>> getMedicalRecords({String? token}) async {
    try {
      // If token is provided, add to headers
      if (token != null && token.isNotEmpty) {
        _dio.options.headers['Authorization'] = 'Bearer $token';
      }
      
      final response = await _dio.get(_medicalRecordsEndpoint);
      
      if (response.statusCode == 200) {
        return {'success': true, 'data': response.data};
      }
      return {'success': false, 'error': 'Failed to fetch medical records'};
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return {'success': false, 'error': 'An unexpected error occurred: $e'};
    }
  }

  Future<Map<String, dynamic>> getMedicalRecordsLegacy() async {
    try {
      final response = await _dio.get(_medicalRecordsEndpoint);
      
      if (response.statusCode == 200) {
        return {'success': true, 'data': response.data};
      }
      return {'success': false, 'error': 'Failed to fetch medical records'};
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return {'success': false, 'error': 'An unexpected error occurred: $e'};
    }
  }

  // =============================================
  // GENERIC REQUEST METHOD (FIXED)
  // =============================================
  Future<Map<String, dynamic>> request({
    required String method,
    required String endpoint,
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      Response response;
      
      switch (method.toLowerCase()) {
        case 'get':
          response = await _dio.get(
            endpoint,
            queryParameters: queryParameters,
          );
          break;
        case 'post':
          response = await _dio.post(
            endpoint,
            data: data,
            queryParameters: queryParameters,
          );
          break;
        case 'put':
          response = await _dio.put(
            endpoint,
            data: data,
            queryParameters: queryParameters,
          );
          break;
        case 'delete':
          response = await _dio.delete(
            endpoint,
            data: data,
            queryParameters: queryParameters,
          );
          break;
        default:
          return {'success': false, 'error': 'Invalid HTTP method'};
      }
      
      if (response.statusCode! >= 200 && response.statusCode! < 300) {
        // FIX: Return the raw response data without wrapping it in 'data'
        // This preserves the backend's response structure
        final responseData = response.data as Map<String, dynamic>;
        return {'success': true, ...responseData};
      }
      return {'success': false, 'error': 'Request failed with status ${response.statusCode}'};
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return {'success': false, 'error': 'An unexpected error occurred: $e'};
    }
  }

  // =============================================
  // ERROR HANDLER
  // =============================================
  Map<String, dynamic> _handleDioError(DioException e) {
    if (e.response != null) {
      final responseData = e.response!.data;
      String errorMessage = 'Server error';
      
      if (responseData is Map) {
        errorMessage = responseData['error'] ?? 
                     responseData['message'] ?? 
                     responseData['detail'] ?? 
                     'Server error';
      } else if (responseData is String) {
        errorMessage = responseData;
      }
      
      return {
        'success': false, 
        'error': errorMessage,
        'statusCode': e.response!.statusCode,
      };
    } else if (e.type == DioExceptionType.connectionTimeout ||
               e.type == DioExceptionType.receiveTimeout) {
      return {'success': false, 'error': 'Connection timeout. Please try again.'};
    } else if (e.type == DioExceptionType.connectionError) {
      return {'success': false, 'error': 'No internet connection. Please check your network.'};
    } else if (e.type == DioExceptionType.sendTimeout) {
      return {'success': false, 'error': 'Request timeout. Please try again.'};
    } else if (e.type == DioExceptionType.cancel) {
      return {'success': false, 'error': 'Request was cancelled'};
    } else if (e.type == DioExceptionType.unknown) {
      return {'success': false, 'error': 'Network error. Please check your connection.'};
    }
    
    return {'success': false, 'error': 'An unexpected error occurred: ${e.message}'};
  }
}