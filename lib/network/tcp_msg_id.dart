enum TcpMsgId {
  authReq(1005), // 登录授权请求
  authRsp(1006), // 登录授权响应
  userSearchReq(1007), // 搜索用户请求
  userSearchRsp(1008), // 搜索用户响应
  friendAddReq(1009), // 添加好友请求
  friendAddRsp(1010), // 添加好友响应
  notifyFriendReq(1011), // 通知好友添加请求
  friendAuthReq(1012), // 好友认证请求
  friendAuthRsp(1013), // 好友认证响应
  notifyFriendAuth(1014), // 通知好友认证结果
  chatMsgReq(1015), // 聊天消息请求
  chatMsgRsp(1016), // 聊天消息响应
  notifyChatMsg(1017), // 聊天消息推送
  conversationReq(1018), // 会话请求
  conversationRsp(1019), // 会话响应
  fileUploadReq(1022), // 文件上传请求
  fileUploadRsp(1023), // 文件上传响应
  fileDownloadReq(1024), // 文件下载请求
  fileDownloadRsp(1025), // 文件下载响应
  notifyOffline(1026); // 通知离线

  const TcpMsgId(this.value);

  final int value;

  static TcpMsgId fromValue(int value) {
    return TcpMsgId.values.firstWhere(
      (e) => e.value == value,
      orElse: () => authReq,
    );
  }
}
