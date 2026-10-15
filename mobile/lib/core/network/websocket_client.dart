import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../storage/local_storage.dart';
import '../../shared/models/telemetry.dart';

class WebSocketClient {
  WebSocketChannel? _channel;
  final StreamController<Telemetry> _telemetryController = StreamController<Telemetry>.broadcast();
  final StreamController<Map<String, dynamic>> _eventController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _connectionStateController = StreamController<bool>.broadcast();

  Timer? _reconnectTimer;
  bool _isClosed = false;

  Stream<Telemetry> get telemetryStream => _telemetryController.stream;
  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;
  Stream<bool> get isConnectedStream => _connectionStateController.stream;

  void connect() async {
    _isClosed = false;
    final ip = await LocalStorage.getDeviceIp();
    final url = Uri.parse('ws://$ip/ws');

    try {
      _channel = IOWebSocketChannel.connect(url, pingInterval: const Duration(seconds: 5));
      _connectionStateController.add(true);

      _channel!.stream.listen(
        (message) {
          try {
            final json = jsonDecode(message);
            final type = json['type'];
            if (type == 'telemetry' && json['data'] != null) {
              final tel = Telemetry.fromJson(json['data']);
              _telemetryController.add(tel);
            } else if (type == 'event') {
              _eventController.add(json);
            }
          } catch (e) {
            // Ignore format error
          }
        },
        onError: (err) {
          _connectionStateController.add(false);
          _scheduleReconnect();
        },
        onDone: () {
          _connectionStateController.add(false);
          _scheduleReconnect();
        },
      );
    } catch (e) {
      _connectionStateController.add(false);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_isClosed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      connect();
    });
  }

  void disconnect() {
    _isClosed = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _connectionStateController.add(false);
  }

  void dispose() {
    disconnect();
    _telemetryController.close();
    _eventController.close();
    _connectionStateController.close();
  }
}
