import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'classlist.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _memberName = '';
  String _activeYN = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  // SharedPreferences에서 사용자 정보 불러오기
  Future<void> _loadUserInfo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _memberName = prefs.getString('memberName') ?? '회원';
      _activeYN = prefs.getString('activeYN') ?? 'N';
    });
  }

  // 로그아웃
  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('memberNo');
    await prefs.remove('memberName');
    await prefs.remove('activeYN');

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  // 대시보드 버튼을 만드는 공통 위젯 함수
  Widget _buildDashboardButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('(사)충효예 대학 주소록'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: '로그아웃',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 환영 메시지
            Row(
              children: [
                const Icon(Icons.account_circle, size: 40, color: Colors.green),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '환영합니다, $_memberName님!',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '상태: ${_activeYN == 'ACTIV' ? '정상(활성)' : '비활성'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: _activeYN == 'ACTIV' ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 30),

            // 4개의 메뉴 버튼 (2x2 그리드)
            Expanded(
              child: GridView.count(
                crossAxisCount: 2, // 2열로 배치
                crossAxisSpacing: 16, // 가로 간격
                mainAxisSpacing: 16, // 세로 간격
                children: [
                  _buildDashboardButton(
                    title: '기수별 연락처',
                    icon: Icons.groups,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ClassListScreen()),
                      );
                    },
                  ),
                  _buildDashboardButton(
                    title: '직책별 연락처',
                    icon: Icons.assignment_ind,
                    onTap: () {
                      // TODO: 직책별 연락처 화면으로 이동
                      print('직책별 연락처 클릭됨');
                    },
                  ),
                  _buildDashboardButton(
                    title: '공지사항',
                    icon: Icons.campaign,
                    onTap: () {
                      // TODO: 공지사항 화면으로 이동
                      print('공지사항 클릭됨');
                    },
                  ),
                  _buildDashboardButton(
                    title: '충효예 대학\n홈페이지',
                    icon: Icons.language,
                    onTap: () {
                      // TODO: 웹뷰나 외부 브라우저로 홈페이지 열기
                      print('홈페이지 클릭됨');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
