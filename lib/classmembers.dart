import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'memberdtl.dart';

class ClassMembersScreen extends StatefulWidget {
  final int classNo;
  final String classTitle;

  const ClassMembersScreen({
    super.key,
    required this.classNo,
    required this.classTitle,
  });

  @override
  State<ClassMembersScreen> createState() => _ClassMembersScreenState();
}

class _ClassMembersScreenState extends State<ClassMembersScreen> {
  List<dynamic> _members = []; // 원본 전체 데이터
  List<dynamic> _filteredMembers = []; // 검색 필터링된 데이터
  bool _isLoading = true;
  String _errorMessage = '';

  // 검색창 컨트롤러
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  @override
  void dispose() {
    _searchController.dispose(); // 메모리 누수 방지
    super.dispose();
  }

  Future<void> _fetchMembers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('access_token');

      if (token == null) {
        setState(() {
          _errorMessage = '로그인 정보가 없습니다. 다시 로그인 해주세요.';
          _isLoading = false;
        });
        return;
      }

      final url = Uri.parse('https://chyaddr.chycollege.kr/phapp/class_members/${widget.classNo}');
      print('요청 URL: $url');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('=== 서버 응답 결과 ===');
      print('상태 코드: ${response.statusCode}');
      try {
        print('응답 데이터: ${utf8.decode(response.bodyBytes)}');
      } catch (e) {
        print('응답 데이터(디코딩 실패): ${response.body}');
      }
      print('======================');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _members = data['classmembers'] ?? [];
          _filteredMembers = _members; // 처음에는 전체 목록을 보여줌
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

  // 검색어에 따라 리스트를 필터링하는 함수
  void _filterMembers(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredMembers = _members; // 검색어가 없으면 전체 목록 복구
      });
    } else {
      setState(() {
        _filteredMembers = _members.where((member) {
          final memberName = member['memberName']?.toString() ?? '';
          return memberName.contains(query); // 이름에 검색어가 포함되어 있는지 확인
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.classTitle),
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
              onPressed: _fetchMembers,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_members.isEmpty) {
      return const Center(child: Text('등록된 회원이 없습니다.'));
    }

    return Column(
      children: [
        // 1. 상단 검색창 영역
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _searchController,
            onChanged: _filterMembers, // 글자가 입력될 때마다 필터링 함수 실행
            decoration: InputDecoration(
              labelText: '이름 검색',
              hintText: '회원 이름을 입력하세요',
              prefixIcon: const Icon(Icons.search, color: Colors.green),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _filterMembers(''); // 지우기 버튼 누르면 검색 초기화
                },
              )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: const BorderSide(color: Colors.green, width: 2.0),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),

        // 2. 하단 회원 목록 영역 (Expanded로 남은 공간 모두 차지)
        Expanded(
          child: _filteredMembers.isEmpty
              ? const Center(child: Text('검색 결과가 없습니다.'))
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: _filteredMembers.length,
            itemBuilder: (context, index) {
              final member = _filteredMembers[index];

              // ⚠️ DB 컬럼명에 맞게 memberNo 추출 (정수형 변환)
              final memberNo = int.tryParse(member['memberNo']?.toString() ?? '0') ?? 0;

              final memberName = member['memberName']?.toString() ?? '이름 없음';
              final rankTitleKor = member['rankTitleKor']?.toString() ?? '직책 없음';
              final photoUrl = member['photoUrl']?.toString() ?? '';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: _buildProfileImage(photoUrl),
                      ),
                    ),
                    title: Text(
                      memberName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        rankTitleKor,
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () {
                      print('$memberName 클릭됨, memberNo: $memberNo');

                      // 상세 화면으로 이동하며 memberNo 전달
                      if (memberNo > 0) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MemberDetailScreen(
                              memberNo: memberNo,
                              memberName: memberName,
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('회원 번호가 유효하지 않습니다.')),
                        );
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProfileImage(String url) {
    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultGrayscaleImage();
        },
      );
    } else {
      return _buildDefaultGrayscaleImage();
    }
  }

  Widget _buildDefaultGrayscaleImage() {
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(
        Colors.grey,
        BlendMode.saturation,
      ),
      child: Image.asset(
        'assets/loginlogo.png',
        fit: BoxFit.cover,
      ),
    );
  }
}
