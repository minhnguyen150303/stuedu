import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ApiClient {
  final Dio dio;

  ApiClient(String baseUrl)
    : dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          responseType: ResponseType.json,
        ),
      ) {
    _addInterceptors();
  }

  void _addInterceptors() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          developer.log(
            '[REQ] ${options.method} ${options.baseUrl}${options.path}',
            name: 'ApiClient',
          );
          developer.log('Headers: ${options.headers}', name: 'ApiClient');
          developer.log('Query: ${options.queryParameters}', name: 'ApiClient');
          developer.log('Body: ${options.data}', name: 'ApiClient');
          handler.next(options);
        },
        onResponse: (response, handler) {
          developer.log(
            '[RES] ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.path}',
            name: 'ApiClient',
          );
          developer.log('Data: ${response.data}', name: 'ApiClient');
          handler.next(response);
        },
        onError: (error, handler) {
          developer.log(
            '[ERR] ${error.requestOptions.method} ${error.requestOptions.path}',
            name: 'ApiClient',
            error: error.message,
          );
          developer.log(
            'Error response: ${error.response?.data}',
            name: 'ApiClient',
          );
          handler.next(error);
        },
      ),
    );
  }

  void setToken(String token) {
    dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearToken() {
    dio.options.headers.remove('Authorization');
  }

  void setHeader(String key, String value) {
    dio.options.headers[key] = value;
  }

  void removeHeader(String key) {
    dio.options.headers.remove(key);
  }

  Future<void> _attachFirebaseTokenIfNeeded() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();

    if (token == null || token.isEmpty) {
      throw Exception('Chưa đăng nhập');
    }

    setToken(token);
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    bool attachFirebaseToken = false,
  }) async {
    if (attachFirebaseToken) {
      await _attachFirebaseTokenIfNeeded();
    }
    try {
      final response = await dio.get(
        path,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: headers == null ? null : Options(headers: headers),
      );
      return response.data;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<dynamic> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    bool attachFirebaseToken = false,
  }) async {
    try {
      if (attachFirebaseToken) {
        await _attachFirebaseTokenIfNeeded();
      }
      final response = await dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: headers == null ? null : Options(headers: headers),
      );
      return response.data;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<dynamic> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    bool attachFirebaseToken = false,
  }) async {
    try {
      if (attachFirebaseToken) {
        await _attachFirebaseTokenIfNeeded();
      }

      final response = await dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: headers == null ? null : Options(headers: headers),
      );
      return response.data;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<dynamic> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    bool attachFirebaseToken = false,
  }) async {
    try {
      if (attachFirebaseToken) {
        await _attachFirebaseTokenIfNeeded();
      }

      final response = await dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: headers == null ? null : Options(headers: headers),
      );
      return response.data;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<dynamic> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    bool attachFirebaseToken = false,
  }) async {
    try {
      if (attachFirebaseToken) {
        await _attachFirebaseTokenIfNeeded();
      }

      final response = await dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: headers == null ? null : Options(headers: headers),
      );
      return response.data;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<dynamic> postFormData(
    String path, {
    required Map<String, dynamic> fields,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
  }) async {
    try {
      final formData = FormData.fromMap(fields);
      final response = await dio.post(
        path,
        data: formData,
        cancelToken: cancelToken,
        options: Options(
          headers: {...?headers, 'Content-Type': 'multipart/form-data'},
        ),
      );
      return response.data;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Exception _mapDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return Exception('Kết nối tới máy chủ bị timeout');
    }

    if (e.type == DioExceptionType.connectionError) {
      return Exception('Không thể kết nối tới máy chủ');
    }

    if (e.type == DioExceptionType.badResponse) {
      final statusCode = e.response?.statusCode;
      final data = e.response?.data;

      if (data is Map<String, dynamic>) {
        final message =
            data['error']?.toString() ??
            data['message']?.toString() ??
            'Lỗi máy chủ ($statusCode)';
        return Exception(message);
      }

      return Exception('Lỗi máy chủ ($statusCode)');
    }

    if (e.type == DioExceptionType.cancel) {
      return Exception('Yêu cầu đã bị huỷ');
    }

    return Exception(e.message ?? 'Đã xảy ra lỗi không xác định');
  }
}
