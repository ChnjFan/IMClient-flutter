import 'dart:async';
import 'package:flutter/material.dart';
import 'package:im_client/config/error_code.dart';
import 'package:im_client/network/http_client.dart';
import 'package:im_client/utils/crypto_util.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _accountController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  bool _sendingCode = false;
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _accountController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _countdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown <= 1) {
        timer.cancel();
        setState(() => _countdown = 0);
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _sendCode() async {
    final account = _accountController.text.trim();
    if (account.isEmpty) {
      _showError('请先输入账号');
      return;
    }

    setState(() => _sendingCode = true);

    try {
      final response = await HttpClient().post(
        '/get_verify_code',
        data: {'email': account},
      );
      if (!mounted) return;
      setState(() => _sendingCode = false);

      final error = ErrorCode.fromValue(response.data['error'] as int? ?? -1);
      if (error == ErrorCode.ok) {
        _showError('验证码已发送');
        _startCountdown();
      } else {
        final msg = response.data['msg'] as String?;
        _showError(msg ?? '获取验证码失败');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendingCode = false);
      _showError('请求失败: $e');
    }
  }

  Future<void> _handleReset() async {
    final account = _accountController.text.trim();
    final code = _codeController.text.trim();
    final password = _passwordController.text;

    if (account.isEmpty) {
      _showError('请输入账号');
      return;
    }
    if (code.isEmpty) {
      _showError('请输入验证码');
      return;
    }
    if (password.isEmpty) {
      _showError('请输入新密码');
      return;
    }
    if (password.length < 6) {
      _showError('密码长度不能少于6位');
      return;
    }

    setState(() => _loading = true);

    try {
      final String passwordSalt = 'salt_$account';
      final response = await HttpClient().post(
        '/reset_passwd',
        data: {
          'email': account,
          'verify_code': code,
          'passwd': CryptoUtil.sha256WithSalt(password, passwordSalt),
        },
      );

      if (!mounted) return;

      final error = ErrorCode.fromValue(response.data['error'] as int? ?? -1);
      if (error != ErrorCode.ok) {
        setState(() => _loading = false);
        final msg = response.data['msg'] as String?;
        _showError(msg ?? '密码重置失败');
        return;
      }

      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('密码重置成功，请登录')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('请求失败: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('忘记密码')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            const SizedBox(height: 32),
            TextField(
              controller: _accountController,
              decoration: const InputDecoration(
                labelText: '账号',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: '验证码',
                      prefixIcon: Icon(Icons.pin_outlined),
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed:
                        _countdown > 0 || _sendingCode ? null : _sendCode,
                    child:
                        _sendingCode
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : Text(_countdown > 0 ? '${_countdown}s' : '获取验证码'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: '新密码',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleReset(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _loading ? null : _handleReset,
                child:
                    _loading
                        ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Text('重置密码', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('返回登录'),
            ),
          ],
        ),
      ),
    );
  }
}
