import 'package:flutter/material.dart';
import 'member.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config/api_config.dart';

class Member {
  final int memberNo;
  final String memberName;
  final String memberPhone;
  final String rankTitle;

  Member({
    required this.memberNo,
    required this.memberName,
    required this.memberPhone,
    required this.rankTitle,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      memberNo: json['memberNo'],
      memberName: json['memberName'],
      memberPhone: json['memberPhone'] ?? '',
      rankTitle: json['rankTitle'] ?? '',
    );
  }
}

class MemberListScreen extends StatefulWidget {
  final int clubNo;
  final String clubName;
  final String? mclubNo;

  const MemberListScreen({
    super.key,
    required this.clubNo,
    required this.clubName,
    required this.mclubNo,
  });

  @override
  _MemberListScreenState createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen> {
  late Future<List<Member>> _memberList;
  List<Member> _allMembers = []; // 전체 멤버 리스트
  List<Member> _filteredMembers = []; // 필터링된 멤버 리스트
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _memberList = fetchMemberList(widget.clubNo);
    _searchController.addListener(_filterMembers); // 검색어 변경 시 필터링
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Member>> fetchMemberList(int clubNo) async {
    final response = await http.get(
      Uri.parse('${ApiConf.baseUrl}/phapp/memberList/$clubNo'),
    );
    if (response.statusCode == 200) {
      final decodedResponse = utf8.decode(response.bodyBytes);
      Map<String, dynamic> data = json.decode(decodedResponse);
      List<dynamic> members = data['members'];
      List<Member> memberList =
          members.map((json) => Member.fromJson(json)).toList();

      setState(() {
        _allMembers = memberList; // 전체 멤버 리스트 저장
        _filteredMembers = memberList; // 초기에는 전체 멤버를 표시
      });

      return memberList;
    } else {
      throw Exception('Failed to load member list');
    }
  }

  void _filterMembers() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredMembers =
          _allMembers.where((member) {
            return member.memberName.toLowerCase().contains(query) ||
                member.memberPhone.toLowerCase().contains(query);
          }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.yellow,
        title: Text('${widget.clubName} 회원 목록'),
      ),
      backgroundColor: Colors.yellow,
      body: Column(
        children: [
          // 검색 입력 필드
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: '검색',
                hintText: '이름 또는 전화번호로 검색',
                prefixIcon: Icon(Icons.search),
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
                          title: Text(member.memberName),
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
                                builder:
                                    (context) => MemberDetailScreen(
                                      memberNo: member.memberNo,
                                      memberName: member.memberName,
                                      mclubNo: widget.mclubNo,
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
