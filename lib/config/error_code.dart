enum ErrorCode {
  ok(0),
  errorJson(1001),
  rpcFailed(1002),
  verifyCodeExpired(1003),
  verifyCodeNotReached(1004),
  userExists(1005),
  userEmailNotExists(1006),
  chatLoginTokenError(1007),
  chatLoginUidError(1008),
  unknown(1);

  const ErrorCode(this.value);

  final int value;

  static ErrorCode fromValue(int value) {
    return ErrorCode.values.firstWhere(
      (e) => e.value == value,
      orElse: () => unknown,
    );
  }
}
