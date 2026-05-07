import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'dart:io';
import 'dashboard.dart';

class ApiConf {
  static const String baseUrl = 'https://chyaddr.chycollege.kr';
}

// ★ 백그라운드 메시지 처리를 위한 최상위 함수 ★
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("백그라운드 메시지 수신: ${message.messageId}");
}

void main() async {
  // 비동기 방식으로 main 함수를 실행하기 위해 필수
  WidgetsFlutterBinding.ensureInitialized();

  // ★ Firebase 초기화 ★
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ★ 백그라운드 메시지 핸들러 등록 ★
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

// FCM 설정을 위해 MyApp을 StatefulWidget으로 변경
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupFCM(); // 앱 시작 시 FCM 설정 실행
  }

  // ★ FCM 초기 설정 및 권한, 토큰 관리 ★
  Future<void> _setupFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // 1. 알림 권한 요청 (Android 13 이상 및 iOS에서 팝업 발생)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('사용자 권한 상태: ${settings.authorizationStatus}');

    // 2. FCM 기기 토큰 가져오기 (이 토큰을 서버로 전송하여 특정 기기에 알림을 보냅니다)
    String? token = await messaging.getToken();
    print("FCM 기기 토큰: $token");

    // 나중에 서버로 토큰을 전송하기 위해 SharedPreferences에 임시 저장할 수도 있습니다.
    if (token != null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
    }

    // 토큰이 갱신될 때마다 감지
    messaging.onTokenRefresh.listen((newToken) async {
      print("FCM 기기 토큰 갱신: $newToken");
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', newToken);
      // TODO: 로그인된 상태라면 갱신된 토큰을 서버(DB)에 업데이트하는 API 호출
    });

    // 3. 포그라운드(앱 화면을 보고 있을 때) 메시지 수신 처리
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('포그라운드에서 메시지 수신: ${message.data}');

      if (message.notification != null) {
        print('알림 제목: ${message.notification!.title}');
        print('알림 내용: ${message.notification!.body}');

        // 포그라운드에서는 시스템 알림 팝업이 안 뜨므로 SnackBar로 간단히 표시
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${message.notification!.title}\n${message.notification!.body}'),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });
  }

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
    _checkAutoLogin();
  }

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

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', accessToken);
        await prefs.setString('memberNo', userInfo['userNo'].toString());
        await prefs.setString('memberName', userInfo['userName'].toString());
        await prefs.setString('activeYN', userInfo['activeYN'].toString());
        await prefs.setString('maskIndex', userInfo['maskIndex'].toString());

        // ★ (선택) 로그인 성공 시 서버로 FCM 토큰 전송 로직 추가 가능 ★
        // String? fcmToken = prefs.getString('fcm_token');
        // if (fcmToken != null) {
        //   await _sendTokenToServer(fcmToken, userInfo['userNo']);
        // }

        if (!mounted) return;

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

  Future<void> _loadUserInfo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _memberName = prefs.getString('memberName') ?? '회원';
      _activeYN = prefs.getString('activeYN') ?? 'N';
    });
  }

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

Future<void> _setupFCM() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // 1. 권한 요청
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  print('사용자 권한 상태: ${settings.authorizationStatus}');

  // ★ [iOS 전용] 앱이 켜져 있을 때도 상단 알림 배너를 띄우도록 설정 ★
  if (Platform.isIOS) {
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // ★ [iOS 전용] APNs 토큰이 정상적으로 발급되었는지 확인 ★
    // APNs 토큰이 없으면 FCM 알림을 받을 수 없습니다.
    String? apnsToken = await messaging.getAPNSToken();
    print("APNs 토큰: $apnsToken");
    if (apnsToken == null) {
      print("🚨 경고: APNs 토큰을 받지 못했습니다. 잠시 후 다시 시도되거나, 인증서 설정을 다시 확인해야 합니다.");
    }
  }

  // 2. FCM 토큰 가져오기
  String? token = await messaging.getToken();
  print("FCM 기기 토큰: $token");

  messaging.onTokenRefresh.listen((newToken) async {
    print("FCM 기기 토큰 갱신: $newToken");
  });

  // 3. 포그라운드 메시지 수신
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('포그라운드에서 메시지 수신: ${message.data}');
    if (message.notification != null) {
      print('알림 제목: ${message.notification!.title}');
    }
  });
}