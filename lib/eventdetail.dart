import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class EventDetailScreen extends StatefulWidget {
  final Map<String, dynamic> eventData;

  const EventDetailScreen({super.key, required this.eventData});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _isAttending = false;
  int _memberCount = 0;
  String _memberNo = '';

  bool _isProcessing = false; // 참석/취소 API 통신 중 상태
  bool _isLoadingAttendance = true; // 초기 진입 시 참석 여부 확인 중 상태

  @override
  void initState() {
    super.initState();
    _memberCount = widget.eventData['memberCount'] ?? 0;
    _loadMemberNoAndCheckAttendance();
  }

  // 기기에 저장된 로그인 사용자의 memberNo를 불러오고 참석 여부 확인
  Future<void> _loadMemberNoAndCheckAttendance() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // memberNo가 int 또는 String으로 저장된 모든 경우 대응 및 공백 제거
    String savedMemberNo = prefs.getString('memberNo') ??
        prefs.getInt('memberNo')?.toString() ?? '';
    savedMemberNo = savedMemberNo.trim();

    Set<String> validMemberNos = {};
    bool canParse = false;
    var membersData = widget.eventData['members'];

    // 백엔드 데이터 파싱 로직 (대소문자, 스네이크 케이스 모두 대응)
    if (membersData != null) {
      if (membersData is List) {
        canParse = true;
        for (var member in membersData) {
          if (member is Map) {
            if (member['attrib'] == 'XXXUPXXXUP') continue; // 취소자 제외

            // 다양한 키 이름 방어 로직
            var mNo = member['memberNo'] ?? member['memberno'] ?? member['MEMBERNO'] ?? member['member_no'];
            if (mNo != null) {
              validMemberNos.add(mNo.toString().trim());
            }
          } else {
            validMemberNos.add(member.toString().trim());
          }
        }
      } else if (membersData is String) {
        canParse = true;
        if (membersData.trim().startsWith('[')) {
          try {
            List<dynamic> parsedList = json.decode(membersData);
            for (var member in parsedList) {
              if (member is Map) {
                if (member['attrib'] == 'XXXUPXXXUP') continue;

                var mNo = member['memberNo'] ?? member['memberno'] ?? member['MEMBERNO'] ?? member['member_no'];
                if (mNo != null) {
                  validMemberNos.add(mNo.toString().trim());
                }
              } else {
                validMemberNos.add(member.toString().trim());
              }
            }
          } catch (e) {
            debugPrint('JSON 파싱 실패');
          }
        } else {
          // 쉼표로 구분된 문자열일 경우
          List<String> splitList = membersData.split(',');
          for (var m in splitList) {
            if (m.trim().isNotEmpty) {
              validMemberNos.add(m.trim());
            }
          }
        }
      }
    }

    // UI 업데이트
    setState(() {
      _memberNo = savedMemberNo;

      // 내 memberNo가 유효한 참석자 명단(Set)에 포함되어 있는지 확인
      if (_memberNo.isNotEmpty) {
        _isAttending = validMemberNos.contains(_memberNo);
      }

      // 파싱에 성공했다면, 상세 화면의 인원수도 정확한 Set의 길이로 덮어씌움
      if (canParse) {
        _memberCount = validMemberNos.length;
      }

      _isLoadingAttendance = false; // 참석 여부 확인 완료
    });
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '미정';
    if (dateStr.length >= 16) {
      return dateStr.substring(0, 16).replaceFirst('T', ' ');
    }
    return dateStr;
  }

  Future<void> _toggleAttendance() async {
    if (_memberNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사용자 정보를 확인할 수 없습니다. 다시 로그인해주세요.')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('access_token');
      int eventNo = widget.eventData['eventNo'];

      String endpoint = _isAttending ? 'emember_minus' : 'emember_add';
      final url = Uri.parse('https://chyaddr.chycollege.kr/phapp/$endpoint/$eventNo/$_memberNo');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));

        if (data['result'] == 'ok') {
          setState(() {
            _isAttending = !_isAttending;
            _memberCount += _isAttending ? 1 : -1;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isAttending ? '행사 참석 신청이 완료되었습니다.' : '행사 참석이 취소되었습니다.'),
              backgroundColor: _isAttending ? Colors.green : Colors.redAccent,
            ),
          );
        } else {
          _showError('처리에 실패했습니다. 다시 시도해주세요.');
        }
      } else {
        _showError('서버 오류가 발생했습니다. (${response.statusCode})');
      }
    } catch (e) {
      _showError('네트워크 오류가 발생했습니다.');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    String fromDate = _formatDate(widget.eventData['eventFrom']);
    String toDate = _formatDate(widget.eventData['eventTo']);
    String dateDisplay = fromDate == toDate ? fromDate : '$fromDate ~ $toDate';

    return Scaffold(
      appBar: AppBar(
        title: const Text('행사 상세 정보'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.eventData['eventTitle'] ?? '제목 없음',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.3),
            ),
            if (widget.eventData['eventTitleEng'] != null && widget.eventData['eventTitleEng'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(widget.eventData['eventTitleEng'], style: const TextStyle(fontSize: 16, color: Colors.grey)),
              ),
            if (widget.eventData['eventTitleCn'] != null && widget.eventData['eventTitleCn'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(widget.eventData['eventTitleCn'], style: const TextStyle(fontSize: 16, color: Colors.grey)),
              ),

            const SizedBox(height: 24),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.calendar_today, '일시', dateDisplay),
                    const Divider(height: 24),
                    _buildInfoRow(Icons.location_on, '장소', widget.eventData['eventPlace'] ?? '장소 미정'),
                    const Divider(height: 24),
                    _buildInfoRow(Icons.people, '참석 인원', '$_memberCount명'),
                    const Divider(height: 24),
                    _buildInfoRow(Icons.repeat, '반복 여부', widget.eventData['eventRepeat'] ?? '없음'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('등록일: ${_formatDate(widget.eventData['regDate'])}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),

            const SizedBox(height: 40),

            // 4. 참석/불참 버튼 (상태에 따라 동적 렌더링)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  // 로딩 중이거나 미참석이면 녹색, 참석 중이면 붉은색
                  backgroundColor: _isLoadingAttendance ? Colors.grey : (_isAttending ? Colors.redAccent : Colors.green),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: (_isLoadingAttendance || _isProcessing)
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(_isAttending ? Icons.cancel : Icons.how_to_reg, color: Colors.white),
                label: Text(
                  _isLoadingAttendance
                      ? '참석 여부 확인 중...'
                      : (_isProcessing ? '처리 중...' : (_isAttending ? '참석 취소하기' : '행사 참석 신청하기')),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                onPressed: (_isLoadingAttendance || _isProcessing) ? null : _toggleAttendance,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String content) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.green, size: 24),
        const SizedBox(width: 16),
        SizedBox(width: 70, child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87))),
        Expanded(child: Text(content, style: const TextStyle(fontSize: 16, color: Colors.black87))),
      ],
    );
  }
}