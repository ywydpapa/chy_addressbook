import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'memberdtl.dart';

class RankMembersScreen extends StatefulWidget {
  const RankMembersScreen({super.key});

  @override
  State<RankMembersScreen> createState() => _RankMembersScreenState();
}

class _RankMembersScreenState extends State<RankMembersScreen> {
  List<dynamic> _members = []; // 원본 전체 데이터 (600명)
  List<dynamic> _filteredMembers = []; // 검색 및 필터링된 데이터

  // 직책 필터링을 위한 변수
  List<String> _rankList = ['전체'];
  String _selectedRank = '전체';

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

      // ⚠️ 백엔드 라우터 주소에 맞게 수정 (필요시 /phapp/rank_members 등으로 변경)
      final url = Uri.parse('https://chyaddr.chycollege.kr/phapp/rank_members');
      print('요청 URL: $url');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));

        // 백엔드에서 넘겨주는 키값 'rankmembers' 사용
        final List<dynamic> fetchedMembers = data['rankmembers'] ?? [];

        // 데이터에서 존재하는 모든 직책(Rank)을 추출하여 중복 제거 후 리스트 생성
        Set<String> ranks = {'전체'};
        for (var member in fetchedMembers) {
          final rank = member['rankTitlekor']?.toString() ?? '';
          if (rank.isNotEmpty && rank != '직책 없음') {
            ranks.add(rank);
          }
        }

        setState(() {
          _members = fetchedMembers;
          _filteredMembers = _members; // 처음에는 전체 목록을 보여줌
          _rankList = ranks.toList();  // 추출한 직책 리스트 적용
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

  // 검색어 및 직책에 따라 리스트를 필터링하는 함수 (클라이언트 사이드 필터링)
  void _applyFilters() {
    String query = _searchController.text.trim();

    setState(() {
      _filteredMembers = _members.where((member) {
        final memberName = member['memberName']?.toString() ?? '';
        final rankTitle = member['rankTitlekor']?.toString() ?? '직책 없음';

        // 1. 이름 검색 조건 확인
        final matchesName = query.isEmpty || memberName.contains(query);

        // 2. 직책 필터 조건 확인
        final matchesRank = _selectedRank == '전체' || rankTitle == _selectedRank;

        // 두 조건(이름, 직책)을 모두 만족하는 사람만 남김
        return matchesName && matchesRank;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('전체 회원 목록'),
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
        // 1. 상단 검색 및 필터 영역
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // 직책 선택 드롭다운
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _selectedRank,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: const BorderSide(color: Colors.green, width: 2.0),
                    ),
                  ),
                  items: _rankList.map((String rank) {
                    return DropdownMenuItem<String>(
                      value: rank,
                      child: Text(rank, style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      _selectedRank = newValue;
                      _applyFilters(); // 직책 변경 시 즉시 필터링 적용
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              // 이름 검색창
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => _applyFilters(), // 글자 입력 시 즉시 필터링 적용
                  decoration: InputDecoration(
                    labelText: '이름 검색',
                    hintText: '이름 입력',
                    prefixIcon: const Icon(Icons.search, color: Colors.green),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _applyFilters(); // 지우기 버튼 누르면 초기화
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
            ],
          ),
        ),

        // 2. 하단 회원 목록 영역 (Expanded로 남은 공간 모두 차지)
        Expanded(
          child: _filteredMembers.isEmpty
              ? const Center(child: Text('조건에 맞는 회원이 없습니다.'))
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: _filteredMembers.length,
            itemBuilder: (context, index) {
              final member = _filteredMembers[index];

              final memberNo = int.tryParse(member['memberNo']?.toString() ?? '0') ?? 0;
              final memberName = member['memberName']?.toString() ?? '이름 없음';
              final rankTitleKor = member['rankTitlekor']?.toString() ?? '직책 없음';

              // 1. 기수 데이터를 가져와서 정수(int)로 변환합니다.
              final classNoStr = member['classNo']?.toString() ?? '';
              final classNoInt = int.tryParse(classNoStr);

              // 2. 조건에 따라 표시할 부제목(subtitle)을 결정합니다.
              String displaySubtitle = rankTitleKor; // 기본값은 직책만 표시

              if (classNoInt != null) {
                if (classNoInt == 0) {
                  // 0이면 (본부) 직책
                  displaySubtitle = '(본부) $rankTitleKor';
                } else if (classNoInt > 0) {
                  // 1 이상이면 (N기) 직책
                  displaySubtitle = '($classNoInt기) $rankTitleKor';
                }
              }

              final photoUrl = 'https://chyaddr.chycollege.kr/static/img/members/mphoto_$memberNo.png';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListTile(
                    // ... leading, title 생략 ...
                    title: Text(
                      memberName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),

                    // 3. 조합된 displaySubtitle 변수를 여기에 적용합니다.
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        displaySubtitle,
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ),

                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () {
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
      // Image.network 는 Flutter 내부적으로 캐싱 및 Lazy Loading을 자동으로 처리합니다.
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
