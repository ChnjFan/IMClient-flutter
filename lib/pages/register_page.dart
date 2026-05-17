import 'dart:async';
import 'package:flutter/material.dart';
import 'package:im_client/config/error_code.dart';
import 'package:im_client/network/http_client.dart';
import 'package:im_client/utils/crypto_util.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nicknameController = TextEditingController();
  final _accountController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  bool _sendingCode = false;
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _nicknameController.dispose();
    _accountController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _countdown = 10); // 测试用 10s
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

  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  Future<void> _sendCode() async {
    final account = _accountController.text.trim();
    if (account.isEmpty) {
      _showError('请先输入邮箱');
      return;
    }
    if (!_emailRegex.hasMatch(account)) {
      _showError('请输入正确的邮箱格式');
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

  Future<void> _handleRegister() async {
    final nickname = _nicknameController.text.trim();
    final account = _accountController.text.trim();
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (nickname.isEmpty) {
      _showError('请输入昵称');
      return;
    }
    if (account.isEmpty) {
      _showError('请输入账号');
      return;
    }
    if (!_emailRegex.hasMatch(account)) {
      _showError('请输入正确的邮箱格式');
      return;
    }
    if (code.isEmpty) {
      _showError('请输入验证码');
      return;
    }
    if (password.isEmpty) {
      _showError('请输入密码');
      return;
    }
    if (password.length < 6) {
      _showError('密码长度不能少于6位');
      return;
    }
    if (password != confirm) {
      _showError('两次密码输入不一致');
      return;
    }

    setState(() => _loading = true);

    try {
      final String passwordSalt = 'salt_$account';
      final response = await HttpClient().post(
        '/user_register',
        data: {
          'user': nickname,
          'email': account,
          'verify_code': code,
          'passwd': CryptoUtil.sha256WithSalt(password, passwordSalt),
          'confirm': CryptoUtil.sha256WithSalt(confirm, passwordSalt),
        },
      );
      if (!mounted) return;

      final error = ErrorCode.fromValue(response.data['error'] as int? ?? -1);
      if (error != ErrorCode.ok) {
        setState(() => _loading = false);
        if (error == ErrorCode.userExists) {
          _showError('账号已存在');
        } else if (error == ErrorCode.verifyCodeExpired) {
          _showError('验证码已过期');
        } else {
          _showError('注册失败');
        }
        return;
      }

      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('注册成功，请登录')));
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
      appBar: AppBar(title: const Text('注册')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            const SizedBox(height: 32),
            TextField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: '昵称',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
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
                labelText: '密码',
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
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: '确认密码',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() => _obscureConfirm = !_obscureConfirm);
                  },
                ),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleRegister(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _loading ? null : _handleRegister,
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
                        : const Text('注册', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('已有账号？'),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('返回登录'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
