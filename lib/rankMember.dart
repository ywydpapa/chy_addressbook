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

class RankMemberScreen extends StatefulWidget {
  const RankMemberScreen({super.key});

  @override
  _RankMemberScreenState createState() => _RankMemberScreenState();
}

class _RankMemberScreenState extends State<RankMemberScreen> {
  late Future<List<Member>> _memberList;
  List<Member> _allMembers = []; // 전체 멤버 리스트
  List<Member> _filteredMembers = []; // 필터링된 멤버 리스트
  String? _selectedRank; // 선택된 직책
  List<String> _rankTitles = []; // 직책 목록

  @override
  void initState() {
    super.initState();
    _memberList = fetchMemberList();
  }

  Future<List<Member>> fetchMemberList() async {
    final response = await http.get(
      Uri.parse('${ApiConf.baseUrl}/phapp/rmemberList/'),
    );

    if (response.statusCode == 200) {
      final decodedResponse = utf8.decode(response.bodyBytes);
      Map<String, dynamic> data = json.decode(decodedResponse);
      List<dynamic> members = data['members'];
      List<Member> memberList =
      members.map((json) => Member.fromJson(json)).toList();

      // 직책 목록 추출
      final rankTitles =
      memberList.map((member) => member.rankTitle).toSet().toList();

      setState(() {
        _allMembers = memberList; // 전체 멤버 리스트 저장
        _filteredMembers = memberList; // 초기에는 전체 멤버를 표시
        _rankTitles = rankTitles..sort(); // 직책 목록 정렬
      });

      return memberList;
    } else {
      throw Exception('Failed to load member list');
    }
  }

  void _filterMembersByRank(String rankTitle) {
    setState(() {
      _selectedRank = rankTitle; // 선택된 직책 저장
      _filteredMembers =
          _allMembers.where((member) {
            return member.rankTitle == rankTitle;
          }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final String? mclubNo =
    ModalRoute.of(context)?.settings.arguments as String?;
    print('RankmemberScreen - mclubNo: $mclubNo'); // 디버깅용 출력
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.yellow, title: Text('직책별 회원 리스트')),
      backgroundColor: Colors.yellow,
      body: Column(
        children: [
          // 드롭다운 필터
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButtonFormField<String>(
              value: _selectedRank,
              items:
              _rankTitles.map((rank) {
                return DropdownMenuItem(value: rank, child: Text(rank));
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  _filterMembersByRank(value);
                }
              },
              decoration: InputDecoration(
                labelText: '직책 선택',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ),
          // 멤버 리스트
          Expanded(
            child: FutureBuilder<List<Member>>(
              future: _memberList,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('No members found'));
                } else {
                  return ListView.builder(
                    itemCount: _filteredMembers.length,
                    itemBuilder: (context, index) {
                      final member = _filteredMembers[index];
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
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
