import 'package:dio/dio.dart';
import '../storage/local_storage.dart';
import '../../shared/models/telemetry.dart';
import '../../shared/models/device_config.dart';

class ApiClient {
  final Dio _dio = Dio();

  ApiClient() {
    _dio.options.connectTimeout = const Duration(seconds: 4);
    _dio.options.receiveTimeout = const Duration(seconds: 4);
  }

  Future<String> _getBaseUrl() async {
    final ip = await LocalStorage.getDeviceIp();
    return 'http://$ip/api/v1';
  }

  Future<Options> _authOptions() async {
    final token = await LocalStorage.getToken() ?? 'sg_sec_default_dev_token';
    return Options(
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
  }

  Future<Telemetry> fetchTelemetry() async {
    final url = '${await _getBaseUrl()}/data';
    final res = await _dio.get(url);
    return Telemetry.fromJson(res.data);
  }

  Future<List<HistoryPoint>> fetchHistory({String range = 'day', String resolution = 'hour'}) async {
    final url = '${await _getBaseUrl()}/history?range=$range&resolution=$resolution';
    final res = await _dio.get(url);
    final pointsJson = res.data['points'] as List? ?? [];
    return pointsJson.map((e) => HistoryPoint.fromJson(e)).toList();
  }

  Future<String> pairDevice(String pinCode) async {
    final url = '${await _getBaseUrl()}/auth/pair';
    final res = await _dio.post(url, data: {
      'pin_code': pinCode,
      'client_name': 'SmartGas Flutter Client',
    });
    final token = res.data['token'] as String;
    await LocalStorage.setToken(token);
    return token;
  }

  Future<bool> tare() async {
    final url = '${await _getBaseUrl()}/tare';
    final opts = await _authOptions();
    final res = await _dio.post(url, options: opts);
    return res.data['success'] == true;
  }

  Future<bool> calibrate(double knownWeightKg) async {
    final url = '${await _getBaseUrl()}/calibrate';
    final opts = await _authOptions();
    final res = await _dio.post(url, data: {'known_weight_kg': knownWeightKg}, options: opts);
    return res.data['success'] == true;
  }

  Future<DeviceConfig> getConfig() async {
    final url = '${await _getBaseUrl()}/config';
    final res = await _dio.get(url);
    return DeviceConfig.fromJson(res.data);
  }

  Future<bool> updateConfig(DeviceConfig cfg) async {
    final url = '${await _getBaseUrl()}/config';
    final opts = await _authOptions();
    final res = await _dio.put(url, data: cfg.toJson(), options: opts);
    return res.data['success'] == true;
  }

  Future<bool> muteAlarm({int durationSeconds = 120}) async {
    final url = '${await _getBaseUrl()}/alarm/mute';
    final res = await _dio.post(url, data: {'duration_seconds': durationSeconds});
    return res.data['muted'] == true;
  }

  Future<String> controlValve(String action) async {
    final url = '${await _getBaseUrl()}/valve/control';
    final opts = await _authOptions();
    final res = await _dio.post(url, data: {'action': action}, options: opts);
    return res.data['valve_state'] ?? 'CLOSED';
  }
}
