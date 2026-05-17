import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:im_client/config/app_config.dart';

typedef MessageHandler = void Function(int msgId, Map<String, dynamic> data);
typedef ErrorHandler = void Function(dynamic error);

class TcpClient {
  Socket? _socket;
  String? _host;
  int? _port;
  bool _reconnecting = false;
  int _reconnectCount = 0;

  static const int maxReconnectAttempts = 5;

  final List<MessageHandler> _messageHandlers = [];
  final List<ErrorHandler> _errorHandlers = [];
  final List<void Function()> _connectedHandlers = [];
  final List<void Function()> _disconnectedHandlers = [];

  final List<int> _buffer = [];
  static const int _headerSize = 4;

  bool get isConnected => _socket != null;

  void onMessage(MessageHandler handler) {
    _messageHandlers.add(handler);
  }

  void onError(ErrorHandler handler) {
    _errorHandlers.add(handler);
  }

  void onConnected(void Function() handler) {
    _connectedHandlers.add(handler);
  }

  void onDisconnected(void Function() handler) {
    _disconnectedHandlers.add(handler);
  }

  Future<void> connect(String host, int port) async {
    _host = host;
    _port = port;
    await _connect();
  }

  Future<void> _connect() async {
    if (_host == null || _port == null) return;

    try {
      _socket = await Socket.connect(_host!, _port!,
          timeout: const Duration(seconds: 10));
      _reconnecting = false;
      _reconnectCount = 0;
      _buffer.clear();

      for (final handler in _connectedHandlers) {
        handler();
      }

      _socket!.listen(
        _onData,
        onError: (error) {
          for (final handler in _errorHandlers) {
            handler(error);
          }
          _handleDisconnect();
        },
        onDone: () {
          _handleDisconnect();
        },
      );
    } catch (e) {
      for (final handler in _errorHandlers) {
        handler(e);
      }
      _handleDisconnect();
    }
  }

  void _onData(Uint8List data) {
    _buffer.addAll(data);

    while (_buffer.length >= _headerSize) {
      final msgId = (_buffer[0] << 8) | _buffer[1];
      final msgLen = (_buffer[2] << 8) | _buffer[3];

      if (_buffer.length < _headerSize + msgLen) {
        return;
      }

      final bodyBytes = _buffer.sublist(_headerSize, _headerSize + msgLen);
      _buffer.removeRange(0, _headerSize + msgLen);

      try {
        final bodyStr = utf8.decode(bodyBytes);
        final data = jsonDecode(bodyStr) as Map<String, dynamic>;
        for (final handler in _messageHandlers) {
          handler(msgId, data);
        }
      } catch (e) {
        for (final handler in _errorHandlers) {
          handler(e);
        }
      }
    }
  }

  void _handleDisconnect() {
    _socket?.destroy();
    _socket = null;

    for (final handler in _disconnectedHandlers) {
      handler();
    }

    _reconnectCount++;
    if (_reconnectCount > maxReconnectAttempts) {
      for (final handler in _errorHandlers) {
        handler('连接服务器失败，已重试$maxReconnectAttempts次，请检查网络后重新登录');
      }
      return;
    }

    if (!_reconnecting && _host != null && _port != null) {
      _reconnecting = true;
      Timer(const Duration(seconds: AppConfig.tcpReconnectDelay), () {
        _reconnecting = false;
        _connect();
      });
    }
  }

  void sendMessage(int msgId, Map<String, dynamic> data) {
    if (_socket == null) return;

    final bodyStr = jsonEncode(data);
    final bodyBytes = utf8.encode(bodyStr);
    final msgLen = bodyBytes.length;

    final packet = Uint8List(_headerSize + msgLen);
    packet[0] = (msgId >> 8) & 0xFF;
    packet[1] = msgId & 0xFF;
    packet[2] = (msgLen >> 8) & 0xFF;
    packet[3] = msgLen & 0xFF;
    packet.setRange(_headerSize, _headerSize + msgLen, bodyBytes);

    _socket!.add(packet);
  }

  void disconnect() {
    _socket?.destroy();
    _socket = null;
    _host = null;
    _port = null;
  }

  void removeMessageHandler(MessageHandler handler) {
    _messageHandlers.remove(handler);
  }

  void removeErrorHandler(ErrorHandler handler) {
    _errorHandlers.remove(handler);
  }

  void removeConnectedHandler(void Function() handler) {
    _connectedHandlers.remove(handler);
  }

  void removeDisconnectedHandler(void Function() handler) {
    _disconnectedHandlers.remove(handler);
  }
}
