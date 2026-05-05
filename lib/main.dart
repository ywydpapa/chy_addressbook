import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// 방금 만든 dashboard.dart 파일을 불러옵니다.
import 'dashboard.dart';

class ApiConf {
  static const String baseUrl = 'https://chyaddr.chycollege.kr';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '(사)충효예 대학 주소록',
      theme: ThemeData(
        primarySwatch: Colors.green,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        // '/' 경로를 기존 HomeScreen에서 DashboardScreen으로 변경합니다.
        '/': (context) => const DashboardScreen(),
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _errorMessage = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 화면이 시작될 때 자동 로그인 여부를 확인합니다.
    _checkAutoLogin();
  }

  // ★ 자동 로그인 체크 로직 추가 ★
  Future<void> _checkAutoLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isAutoLogin = prefs.getBool('auto_login') ?? false;

    if (isAutoLogin) {
      String savedId = prefs.getString('saved_id') ?? '';
      String savedPw = prefs.getString('saved_pw') ?? '';

      if (savedId.isNotEmpty && savedPw.isNotEmpty) {
        setState(() {
          _usernameController.text = savedId;
          _passwordController.text = savedPw;
        });

        // 화면 렌더링이 끝난 직후 자동으로 로그인 함수를 실행합니다.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _login();
        });
      }
    }
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = '아이디와 비밀번호를 모두 입력하세요.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConf.baseUrl}/phapp/mlogin'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));

        final String accessToken = data['access_token'];
        final userInfo = data['user_info'];

        // 백엔드에서 넘겨주는 키(userNo, userName, activeYN)를 member 기준으로 저장
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', accessToken);
        await prefs.setString('memberNo', userInfo['userNo'].toString());
        await prefs.setString('memberName', userInfo['userName'].toString());
        await prefs.setString('activeYN', userInfo['activeYN'].toString());
        await prefs.setString('maskIndex', userInfo['maskIndex'].toString());

        if (!mounted) return;

        // 로그인 성공 시 메인 홈으로 이동
        Navigator.pushReplacementNamed(context, '/');
      } else if (response.statusCode == 401) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _errorMessage = data['detail'] ?? '아이디 또는 비밀번호가 올바르지 않습니다.';
        });
      } else {
        setState(() {
          _errorMessage = '서버 오류 (${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '네트워크 오류: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('충효예 대학 주소록'),
        centerTitle: true,
      ),
      backgroundColor: Colors.green,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/loginlogo.png',
                  width: 200,
                  height: 200,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.account_circle,
                    size: 100,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: '아이디',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '비밀번호',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                if (_errorMessage.isNotEmpty)
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('로그인'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _memberName = '';
  String _activeYN = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  // SharedPreferences에서 member 정보 불러오기
  Future<void> _loadUserInfo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _memberName = prefs.getString('memberName') ?? '회원';
      _activeYN = prefs.getString('activeYN') ?? 'N';
    });
  }

  // 로그아웃 (저장된 정보 모두 삭제)
  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('memberNo');
    await prefs.remove('memberName');
    await prefs.remove('activeYN');
    await prefs.remove('maskIndex');

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('(사)충효예 대학 원우 주소록'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: '로그아웃',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '환영합니다, $_memberName님!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              '활동 상태: ${_activeYN == 'ACTIV' ? '활성' : '비활성'}',
              style: TextStyle(
                fontSize: 16,
                color: _activeYN == 'Y' ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 20),
            const Text('로그인에 성공하여 토큰이 기기에 저장되었습니다.'),
          ],
        ),
      ),
    );
  }
}