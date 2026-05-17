import 'package:flutter/material.dart';
import 'package:im_client/config/error_code.dart';
import 'package:im_client/network/http_client.dart';
import 'package:im_client/network/tcp_client.dart';
import 'package:im_client/network/tcp_message_handler.dart';
import 'package:im_client/network/tcp_msg_id.dart';
import 'package:im_client/session/user_session.dart';
import 'package:im_client/utils/crypto_util.dart';
import 'register_page.dart';
import 'forgot_password_page.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  final _msgHandler = TcpMessageHandler();
  bool _obscurePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final account = _accountController.text.trim();
    final password = _passwordController.text;

    if (account.isEmpty) {
      _showError('请输入账号');
      return;
    }
    if (password.isEmpty) {
      _showError('请输入密码');
      return;
    }

    setState(() => _loading = true);

    try {
      final String passwordSalt = 'salt_$account';
      final response = await HttpClient().post(
        '/user_login',
        data: {
          'email': account,
          'passwd': CryptoUtil.sha256WithSalt(password, passwordSalt),
        },
      );

      if (!mounted) return;

      final error = ErrorCode.fromValue(response.data['error'] as int? ?? -1);
      if (error != ErrorCode.ok) {
        setState(() => _loading = false);
        _showError('登录失败');
        return;
      }

      final session = UserSession();
      session.saveLoginResponse(response.data);

      _setupMessageHandlers();

      final tcpClient = TcpClient();
      tcpClient.onConnected(_onTcpConnected);
      tcpClient.onDisconnected(_onTcpDisconnected);
      tcpClient.onMessage(_onTcpMessage);
      tcpClient.onError(_onTcpError);

      session.tcpClient = tcpClient;
      await tcpClient.connect(session.tcpHost, session.tcpPort);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('登录失败: $e');
    }
  }

  void _setupMessageHandlers() {
    _msgHandler.on(TcpMsgId.authRsp, (msgId, data) {
      if (!mounted) return;
      final error = ErrorCode.fromValue(data['error'] as int? ?? -1);
      if (error == ErrorCode.ok) {
        setState(() => _loading = false);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      } else {
        setState(() => _loading = false);
        _showError('授权失败');
        UserSession().clear();
      }
    });
  }

  void _onTcpConnected() {
    final session = UserSession();
    _showError('长连接已建立，正在授权...');
    session.tcpClient!.sendMessage(TcpMsgId.authReq.value, {
      'uid': session.uid,
      'token': session.token,
    });
  }

  void _onTcpMessage(int msgId, Map<String, dynamic> data) {
    _msgHandler.handle(msgId, data);
  }

  void _onTcpDisconnected() {
    if (!mounted) return;
    _showError('长连接断开，正在重连...');
  }

  void _onTcpError(dynamic error) {
    if (!mounted) return;
    setState(() => _loading = false);
    _showError(error.toString());
    UserSession().clear();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.chat, size: 80, color: Color(0xFF07C160)),
                const SizedBox(height: 16),
                Text(
                  'IM Client',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 48),
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
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: '密码',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleLogin(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _loading ? null : _handleLogin,
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
                            : const Text('登录', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const RegisterPage(),
                          ),
                        );
                      },
                      child: const Text('注册'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordPage(),
                          ),
                        );
                      },
                      child: const Text('忘记密码'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
