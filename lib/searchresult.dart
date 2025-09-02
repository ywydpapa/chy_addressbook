import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'member.dart';
import 'config/api_config.dart';

class Member {
  final int memberNo;
  final String memberName;
  final String memberPhone;
  final String rankTitle;
  final String clubName;

  Member({
    required this.memberNo,
    required this.memberName,
    required this.memberPhone,
    required this.rankTitle,
    required this.clubName,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      memberNo: json['memberNo'],
      memberName: json['memberName'],
      memberPhone: json['memberPhone'] ?? '',
      rankTitle: json['rankTitle'] ?? '',
      clubName: json['clubName'] ?? '',
    );
  }
}

class MemberSearchScreen extends StatefulWidget {
  const MemberSearchScreen({super.key});

  @override
  _MemberSearchScreenState createState() => _MemberSearchScreenState();
}

class _MemberSearchScreenState extends State<MemberSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _errorMessage = '';
  List<Member> _searchResults = [];

  Future<void> _searchMembers() async {
    final keyword = _searchController.text;

    if (keyword.isEmpty) {
      setState(() {
        _errorMessage = '검색어를 입력하세요.';
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiConf.baseUrl}/phapp/searchmember/$keyword'),
      );

      if (response.statusCode == 200) {
        final decodedResponse = utf8.decode(response.bodyBytes);
        Map<String, dynamic> data = json.decode(decodedResponse);

        if (data.containsKey('members')) {
          List<dynamic> members = data['members'];
          setState(() {
            _searchResults =
                members.map((json) => Member.fromJson(json)).toList();
            _errorMessage = ''; // 에러 메시지 초기화
          });
        } else {
          setState(() {
            _errorMessage = '검색 결과가 없습니다.';
            _searchResults = [];
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
    final String? mclubNo =
    ModalRoute.of(context)?.settings.arguments as String?;
    print('SearchScreen - mclubNo: $mclubNo'); // 디버깅용 출력
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.yellow, title: Text('회원 검색')),
      backgroundColor: Colors.yellow,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: '검색어를 입력하세요',
                hintText: '이름 또는 전화번호로 검색',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ),
          ElevatedButton(onPressed: _searchMembers, child: Text('검색')),
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(_errorMessage, style: TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: _searchResults.isEmpty
                ? Center(child: Text('검색 결과가 없습니다.'))
                : ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final member = _searchResults[index];
                final imageUrl =
                    '${ApiConf.baseUrl}/thumbnails/${member.memberNo}.png';
                return Card(
                  margin: EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[200],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              'assets/default.png',
                              fit: BoxFit.cover,
                            );
                          },
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(member.memberName),
                        SizedBox(width: 8),
                        Text(
                          '(${member.clubName})',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('직책: ${member.rankTitle}'),
                        Text(
                          '연락처: ${member.memberPhone.isEmpty ? "N/A" : member.memberPhone}',
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MemberDetailScreen(
                            memberNo: member.memberNo,
                            memberName: member.memberName,
                            mclubNo: mclubNo,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
