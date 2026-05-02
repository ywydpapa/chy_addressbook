import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ClassListScreen extends StatefulWidget {
  const ClassListScreen({super.key});

  @override
  State<ClassListScreen> createState() => _ClassListScreenState();
}

class _ClassListScreenState extends State<ClassListScreen> {
  List<dynamic> _classes = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchClasses();
  }

  Future<void> _fetchClasses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 1. 저장된 JWT 토큰 불러오기
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('access_token');

      if (token == null) {
        setState(() {
          _errorMessage = '로그인 정보가 없습니다. 다시 로그인 해주세요.';
          _isLoading = false;
        });
        return;
      }

      // 2. 백엔드 API 호출 (토큰을 Authorization 헤더에 포함)
      final response = await http.get(
        Uri.parse('https://chyaddr.chycollege.kr/phapp/classes'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // 3. 응답 처리
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _classes = data['classes'] ?? [];
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        setState(() {
          _errorMessage = '인증이 만료되었습니다. 다시 로그인 해주세요.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = '서버 오류가 발생했습니다. (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '네트워크 오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('기수별 연락처'),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.green));
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage, style: const TextStyle(color: Colors.red, fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchClasses,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_classes.isEmpty) {
      return const Center(child: Text('등록된 기수 목록이 없습니다.'));
    }

    // 목록을 버튼(Card + ListTile) 형태로 나열
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _classes.length,
      itemBuilder: (context, index) {
        final classItem = _classes[index];

        // 백엔드에서 넘어오는 실제 데이터 매핑
        final classNo = classItem['classNo']?.toString() ?? '';
        final classTitle = classItem['classTitle']?.toString() ?? '기수명 없음';
        //final classFrom = classItem['classFrom']?.toString() ?? '';
        //final classTo = classItem['classTo']?.toString() ?? '';

        // 기간 텍스트 만들기 (둘 다 빈 값이 아닐 때만 '~' 표시)
        // String periodText = '';
        //if (classFrom.isNotEmpty || classTo.isNotEmpty) {
        //  periodText = '$classFrom ~ $classTo';
        //}

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            title: Text(
              classTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            // 기간 데이터가 있으면 부제목으로 표시
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.green),
            onTap: () {
              // TODO: 해당 기수를 눌렀을 때 상세 명단 화면으로 이동하는 코드 작성
              // 나중에 classNo를 다음 화면으로 넘겨주어 해당 기수의 회원 목록을 불러오게 됩니다.
              print('클릭됨: $classTitle (번호: $classNo)');
            },
          ),
        );
      },
    );
  }
}
