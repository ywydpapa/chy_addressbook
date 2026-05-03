import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'eventdetail.dart';

class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key});

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  List<dynamic> _events = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('access_token');

      final url = Uri.parse('https://chyaddr.chycollege.kr/phapp/events');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _events = data['events'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = '데이터를 불러오는데 실패했습니다. (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '네트워크 오류가 발생했습니다.\n서버 연결을 확인해주세요.';
        _isLoading = false;
      });
    }
  }

  // 날짜 문자열 포맷팅
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '미정';
    if (dateStr.length >= 10) return dateStr.substring(0, 10);
    return dateStr;
  }

  // ★ 추가된 핵심 로직: 취소자(XXXUPXXXUP) 제외 및 중복 memberNo 제거 후 실제 인원수 계산
  int _getValidMemberCount(dynamic membersData, int defaultCount) {
    if (membersData == null) return defaultCount;

    // Set을 사용하여 중복된 memberNo를 자동으로 하나로 처리합니다.
    Set<String> validMemberNos = {};
    bool canParse = false;

    if (membersData is List) {
      canParse = true;
      for (var member in membersData) {
        if (member is Map) {
          if (member['attrib'] == 'XXXUPXXXUP') continue; // 취소자 제외
          if (member['memberNo'] != null) {
            validMemberNos.add(member['memberNo'].toString());
          }
        } else {
          validMemberNos.add(member.toString());
        }
      }
    } else if (membersData is String) {
      if (membersData.trim().startsWith('[')) {
        try {
          List<dynamic> parsedList = json.decode(membersData);
          canParse = true;
          for (var member in parsedList) {
            if (member is Map) {
              if (member['attrib'] == 'XXXUPXXXUP') continue; // 취소자 제외
              if (member['memberNo'] != null) {
                validMemberNos.add(member['memberNo'].toString());
              }
            } else {
              validMemberNos.add(member.toString());
            }
          }
        } catch (e) {
          debugPrint('JSON 파싱 실패');
        }
      }
    }

    // 파싱에 성공했다면 중복이 제거된 실제 인원수를, 실패했다면 백엔드가 준 기본값을 반환
    return canParse ? validMemberNos.length : defaultCount;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('행사 일정'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(
        child: Text(
          _errorMessage,
          style: const TextStyle(color: Colors.red, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      )
          : _events.isEmpty
          ? const Center(child: Text('등록된 행사가 없습니다.', style: TextStyle(fontSize: 16)))
          : ListView.builder(
        itemCount: _events.length,
        itemBuilder: (context, index) {
          final event = _events[index];

          String fromDate = _formatDate(event['eventFrom']);
          String toDate = _formatDate(event['eventTo']);
          String dateDisplay = fromDate == toDate ? fromDate : '$fromDate ~ $toDate';

          // ★ 백엔드 카운트 대신 앱에서 정확하게 다시 계산한 카운트 사용
          int displayCount = _getValidMemberCount(
              event['members'],
              event['memberCount'] ?? 0
          );

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EventDetailScreen(eventData: event),
                  ),
                ).then((_) {
                  // 상세 화면에서 참석/취소 후 뒤로가기 시 목록 새로고침
                  _fetchEvents();
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.event_available, color: Colors.green, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            event['eventTitle'] ?? '제목 없음',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(dateDisplay, style: TextStyle(color: Colors.grey.shade700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.location_on, size: 16, color: Colors.grey),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  event['eventPlace'] ?? '장소 미정',
                                  style: TextStyle(color: Colors.grey.shade700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.people, size: 16, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(
                                '$displayCount명 참석', // ★ 수정된 변수 사용
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}