enum TcpMsgId {
  authReq(1005), // 登录授权请求
  authRsp(1006), // 登录授权响应
  userSearchReq(1007), // 搜索用户请求
  userSearchRsp(1008), // 搜索用户响应
  friendAddReq(1009), // 添加好友请求
  friendAddRsp(1010), // 添加好友响应
  notifyFriendReq(1011), // 通知好友添加请求
  friendAuthReq(1012), // 好友认证请求
  friendAuthRsp(1013); // 好友认证响应

  const TcpMsgId(this.value);

  final int value;

  static TcpMsgId fromValue(int value) {
    return TcpMsgId.values.firstWhere(
      (e) => e.value == value,
      orElse: () => authReq,
    );
  }
}
