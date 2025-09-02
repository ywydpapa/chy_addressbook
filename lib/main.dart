import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'clubList.dart';
import 'searchresult.dart';
import 'rankMember.dart';
import 'clubDocs.dart';
import 'docViewer.dart';
import 'settings.dart';
import 'config/api_config.dart';
import 'dart:io';
import 'package:flutter/services.dart'; // 추가
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';


Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<List<dynamic>> fetchCircleList(String memberNo) async {
  try {
    final response = await http.get(
      Uri.parse('${ApiConf.baseUrl}/phapp/getmycircle/$memberNo'),
    );
    if (response.statusCode == 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final data = jsonDecode(decodedBody);
      if (data is Map && data.containsKey('circles')) {
        final circles = data['circles'];
        if (circles is List) {
          return circles;
        }
      }
    }
  } catch (e) {
    print('써클 리스트 조회 오류: $e');
  }
  return [];
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print(e);
  }
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  HttpOverrides.global = MyHttpOverrides(); //테스트용 우회 설정
  NotificationSettings settings = await messaging.requestPermission();
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  // Android 및 iOS 초기화 설정 추가
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  final DarwinInitializationSettings initializationSettingsIOS =
  DarwinInitializationSettings(); // iOS용 설정 추가

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS, // 반드시 추가!
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  runApp(MyApp());
}


void subscribeToTopics(String regionNo, String clubNo, String memberNo) async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  SharedPreferences prefs = await SharedPreferences.getInstance();

  final regionTopic = 'region_$regionNo';
  final clubTopic = 'club_$clubNo';
  final memberTopic = 'member_$memberNo';

  String? prevClubNo = prefs.getString('prevClubNo');
  String? prevRegionNo = prefs.getString('prevRegionNo');
  String? prevMemberNo = prefs.getString('prevMemberNo');

  if (prevClubNo != null && prevClubNo != clubNo) {
    await messaging.unsubscribeFromTopic('club_$prevClubNo');
  }
  if (prevRegionNo != null && prevRegionNo != regionNo) {
    await messaging.unsubscribeFromTopic('region_$prevRegionNo');
  }
  if (prevMemberNo != null && prevMemberNo != memberNo) {
    await messaging.unsubscribeFromTopic('member_$prevMemberNo');
  }

  await messaging.subscribeToTopic(clubTopic);
  await messaging.subscribeToTopic(regionTopic);
  await messaging.subscribeToTopic(memberTopic);

  await prefs.setString('prevClubNo', clubNo);
  await prefs.setString('prevRegionNo', regionNo);
  await prefs.setString('prevMemberNo', memberNo);
}

void unsubscribeAllTopics() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? prevClubNo = prefs.getString('prevClubNo');
  String? prevRegionNo = prefs.getString('prevRegionNo');
  String? prevMemberNo = prefs.getString('prevMemberNo');
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  if (prevClubNo != null) {
    await messaging.unsubscribeFromTopic('club_$prevClubNo');
  }
  if (prevRegionNo != null) {
    await messaging.unsubscribeFromTopic('region_$prevRegionNo');
  }
  if (prevMemberNo != null) {
    await messaging.unsubscribeFromTopic('member_$prevMemberNo');
  }

  await prefs.remove('prevClubNo');
  await prefs.remove('prevRegionNo');
  await prefs.remove('prevMemberNo');
}
// 테스트용 우회설정 클래스
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '(사)충효예 대학 주소록',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/login', // 초기 화면을 로그인 화면으로 설정
      routes: {
        '/login': (context) => LoginScreen(),
        '/': (context) => HomeScreen(),
        '/clubList': (context) => ClubListScreen(),
        '/search': (context) => MemberSearchScreen(),
        '/rankMembers': (context) => RankMemberScreen(),
        '/clubDocs': (context) => ClubDocsScreen(),
        '/docViewer': (context) => DocViewerScreen(),
        '/settings': (context) => SettingScreen(),
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
  String _errorMessage = '';
  String _clubNo = '';
  String _memberNo = '';

  Future<void> _login() async {
    final phoneno = _usernameController.text;

    if (phoneno.isEmpty) {
      setState(() {
        _errorMessage = '전화번호를 입력하세요.';
      });
      return;
    }

    try {
      // 서버 요청
      final response = await http.get(
        Uri.parse('${ApiConf.baseUrl}/phapp/zlogin/$phoneno'),
      );

      // 상태 코드 확인
      if (response.statusCode == 200) {
        // JSON 파싱
        final data = json.decode(response.body);

        // 반환된 데이터 처리
        if (data.containsKey('clubno')) {
          setState(() {
            _clubNo = data['clubno'].toString();
            _memberNo = data['memberno'].toString();
            _errorMessage = '';
          });

          // 메인 화면으로 이동
          Navigator.pushReplacementNamed(context,'/',arguments: {'clubNo': _clubNo,'memberNo': _memberNo,},);
        } else if (data.containsKey('error')) {
          setState(() {
            _errorMessage = data['error'];
          });
        } else {
          setState(() {
            _errorMessage = '자신의 전화번호로 로그인해 주세요. 숫자로만 입력해 주세요.';
          });
        }
      } else {
        setState(() {
          _errorMessage = '서버 오류 (${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '네트워크 오류: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text('충효예 대학 주소록'),
      ),
      backgroundColor: Colors.green,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/loginlogo.png',
              width: 300, // 로고 너비 설정
              height: 300, // 로고 높이 설정
            ),
            SizedBox(height: 8), // 로고와 입력창 사이 간격
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: '전화번호',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 8),
            if (_errorMessage.isNotEmpty)
              Text(_errorMessage, style: TextStyle(color: Colors.red)),
            SizedBox(height: 8),
            ElevatedButton(onPressed: _login, child: Text('로그인')),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String? mclubNo = args?['clubNo'];
    final String? memberNo = args?['memberNo'];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text('(사)충효예 대학 원우 주소록'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings), // 기어 아이콘
            onPressed: () {
              Navigator.pushNamed(context, '/settings', arguments: memberNo,);
            },
          ),
        ],
      ),
      backgroundColor: Colors.green,
      body: Column(
        children: [
          // 상단 이미지 배치 (액자 스타일)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0), // 좌우 간격 추가
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white, // 배경색 (액자 배경)
                border: Border.all(color: Colors.black, width: 2), // 테두리 설정
                borderRadius: BorderRadius.circular(8), // 테두리에 둥글기 추가
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withAlpha((0.5 * 255).toInt()),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: Offset(0, 3), // 그림자 위치
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0), // 이미지와 테두리 사이 패딩
                child: Image.asset(
                  'assets/homeImage.png', // 이미지 파일 이름
                  width: double.infinity,
                  height: 400, // 이미지 높이 설정
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Spacer(),
          // 버튼 배치
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/clubList', arguments: mclubNo);
                        },
                        child: Text('기수별 회원 목록'),
                      ),
                    ),
                    SizedBox(width: 8), // 버튼 사이 간격
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/rankMembers', arguments: mclubNo);
                        },
                        child: Text('임원 목록'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16), // 버튼 사이 간격
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/search', arguments: mclubNo);
                        },
                        child: Text('키워드 회원 검색'),
                      ),
                    ),
                    SizedBox(width: 8), // 버튼 사이 간격
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (mclubNo != null) {
                            Navigator.pushNamed(context, '/clubDocs', arguments: mclubNo);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('로그인세션이 만료되었습니다. 다시 로그인해야 합니다.')),
                            );
                            Future.delayed(Duration(seconds: 2), () {
                              Navigator.pushReplacementNamed(context, '/login');
                            });
                          }
                        },
                        child: Text('참고 문서'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Spacer(),
        ],
      ),
    );
  }
}
