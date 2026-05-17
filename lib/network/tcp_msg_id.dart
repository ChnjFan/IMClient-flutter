enum TcpMsgId {
  authReq(1005), // 登录授权请求
  authRsp(1006); // 登录授权响应

  const TcpMsgId(this.value);

  final int value;

  static TcpMsgId fromValue(int value) {
    return TcpMsgId.values.firstWhere(
      (e) => e.value == value,
      orElse: () => authReq,
    );
  }
}
