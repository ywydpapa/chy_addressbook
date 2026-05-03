import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 자동 로그인 관련 변수
  bool _isAutoLogin = false;
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();

  // 개인정보 노출 설정 관련 변수 (0: 비공개, 1: 최소공개, 2: 기수공개, 3: 전체공개)
  double _privacyLevel = 3;

  final List<String> _privacyLabels = ['비공개', '최소공개', '기수공개', '전체공개'];
  final List<String> _privacyDescriptions = [
    '모든 개인정보를 숨깁니다. (이름, 기수만 표시)',
    '최소한의 정보(휴대폰 번호 등)만 공개합니다.',
    '같은 기수 원우에게만 모든 정보를 공개합니다.',
    '모든 원우에게 모든 정보를 공개합니다.'
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // 저장된 설정 불러오기
  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAutoLogin = prefs.getBool('auto_login') ?? false;
      _idController.text = prefs.getString('saved_id') ?? '';
      _pwController.text = prefs.getString('saved_pw') ?? '';
      _privacyLevel = prefs.getDouble('privacy_level') ?? 3.0;
    });
  }

  // 설정 저장하기
  Future<void> _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // 자동 로그인이 켜져있는데 아이디/비번이 비어있으면 경고
    if (_isAutoLogin && (_idController.text.isEmpty || _pwController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('자동 로그인을 사용하려면 아이디와 비밀번호를 입력해주세요.')),
      );
      return;
    }

    await prefs.setBool('auto_login', _isAutoLogin);
    await prefs.setString('saved_id', _idController.text);
    await prefs.setString('saved_pw', _pwController.text);
    await prefs.setDouble('privacy_level', _privacyLevel);

    // TODO: 개인정보 노출 정도(_privacyLevel)는 추후 백엔드 API를 호출하여 DB에도 업데이트해야 합니다.

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('설정이 성공적으로 저장되었습니다.')),
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(), // 빈 화면 터치 시 키보드 내림
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 자동 로그인 설정 영역
              const Text(
                '로그인 설정',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('자동 로그인', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('앱 실행 시 자동으로 로그인합니다.'),
                        activeColor: Colors.green,
                        value: _isAutoLogin,
                        onChanged: (bool value) {
                          setState(() {
                            _isAutoLogin = value;
                          });
                        },
                      ),
                      // 자동 로그인이 켜져 있을 때만 입력창 활성화 (또는 항상 보이게 하되 시각적 피드백 제공)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: _isAutoLogin ? 140 : 0,
                        curve: Curves.easeInOut,
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            children: [
                              const Divider(),
                              TextField(
                                controller: _idController,
                                decoration: const InputDecoration(
                                  labelText: '아이디',
                                  prefixIcon: Icon(Icons.person),
                                  border: InputBorder.none,
                                ),
                              ),
                              TextField(
                                controller: _pwController,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: '비밀번호',
                                  prefixIcon: Icon(Icons.lock),
                                  border: InputBorder.none,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // 2. 개인정보 노출 설정 영역
              const Text(
                '개인정보 노출 설정',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('현재 상태:', style: TextStyle(fontSize: 16)),
                          Text(
                            _privacyLabels[_privacyLevel.toInt()],
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _privacyDescriptions[_privacyLevel.toInt()],
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.green,
                          inactiveTrackColor: Colors.green.shade100,
                          thumbColor: Colors.green,
                          overlayColor: Colors.green.withOpacity(0.2),
                          valueIndicatorColor: Colors.green,
                          valueIndicatorTextStyle: const TextStyle(color: Colors.white),
                        ),
                        child: Slider(
                          value: _privacyLevel,
                          min: 0,
                          max: 3,
                          divisions: 3,
                          label: _privacyLabels[_privacyLevel.toInt()],
                          onChanged: (double value) {
                            setState(() {
                              _privacyLevel = value;
                            });
                          },
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('비공개', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text('전체공개', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // 3. 저장 버튼
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _saveSettings,
                  child: const Text(
                    '설정 저장하기',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}