import 'package:dio/dio.dart';
import '../network/api_client.dart';

class ApiService {
  final ApiClient _apiClient;

  ApiService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Dio get dio => _apiClient.dio;

  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await dio.get(path, queryParameters: queryParameters);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> post(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await dio.post(path, data: data, queryParameters: queryParameters);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> put(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await dio.put(path, data: data, queryParameters: queryParameters);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> delete(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await dio.delete(path, queryParameters: queryParameters);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }
}
