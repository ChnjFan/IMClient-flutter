import 'package:im_client/network/tcp_msg_id.dart';

typedef TcpMsgCallback = void Function(TcpMsgId msgId, Map<String, dynamic> data);

class TcpMessageHandler {
  final Map<TcpMsgId, List<TcpMsgCallback>> _handlers = {};

  void on(TcpMsgId msgId, TcpMsgCallback callback) {
    _handlers.putIfAbsent(msgId, () => []).add(callback);
  }

  void handle(int rawMsgId, Map<String, dynamic> data) {
    final msgId = TcpMsgId.fromValue(rawMsgId);
    final callbacks = _handlers[msgId];
    if (callbacks != null) {
      for (final cb in callbacks) {
        cb(msgId, data);
      }
    }
  }

  void remove(TcpMsgId msgId, TcpMsgCallback callback) {
    _handlers[msgId]?.remove(callback);
  }

  void removeAll(TcpMsgId msgId) {
    _handlers.remove(msgId);
  }
}
