import 'dart:io' as io;
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:im_client/config/app_config.dart';
import 'package:im_client/network/ssl_config.dart';

class HttpClient {
  static HttpClient? _instance;
  late final Dio _dio;

  HttpClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.host,
        connectTimeout: const Duration(seconds: AppConfig.httpConnectTimeout),
        receiveTimeout: const Duration(seconds: AppConfig.httpReceiveTimeout),
        sendTimeout: const Duration(seconds: AppConfig.httpSendTimeout),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true),
    );

    if (kReleaseMode) {
      (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = io.HttpClient();
        client.badCertificateCallback = (cert, host, port) => SslConfig.verifyCertificate(cert);
        return client;
      };
    }
  }

  factory HttpClient() {
    _instance ??= HttpClient._();
    return _instance!;
  }

  Dio get dio => _dio;

  void updateBaseUrl(String baseUrl) {
    _dio.options.baseUrl = baseUrl;
  }

  void updateHeaders(Map<String, dynamic> headers) {
    _dio.options.headers.addAll(headers);
  }

  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  String _url(String path) {
    final base = _dio.options.baseUrl;
    final String fullUrl;
    if (base.isEmpty) {
      fullUrl = path;
    } else if (path.isEmpty) {
      fullUrl = base;
    } else if (base.endsWith('/') && path.startsWith('/')) {
      fullUrl = '$base${path.substring(1)}';
    } else if (!base.endsWith('/') && !path.startsWith('/')) {
      fullUrl = '$base/$path';
    } else {
      fullUrl = '$base$path';
    }
    debugPrint('[HTTP] $fullUrl');
    return fullUrl;
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.get<T>(
      _url(path),
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.post<T>(
      _url(path),
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.put<T>(
      _url(path),
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.delete<T>(
      _url(path),
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }
}
