import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'notice_view.dart';

class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  List<dynamic> _notices = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchNotices();
  }

  Future<void> _fetchNotices() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('access_token');

      final url = Uri.parse('https://chyaddr.chycollege.kr/phapp/notices');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // 한글 깨짐 방지를 위해 utf8.decode 사용
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _notices = data['notices'];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('공지사항 / 자료실'),
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
          )
      )
          : _notices.isEmpty
          ? const Center(child: Text('등록된 게시글이 없습니다.', style: TextStyle(fontSize: 16)))
          : ListView.builder(
        itemCount: _notices.length,
        itemBuilder: (context, index) {
          final notice = _notices[index];
          final isNotice = notice['is_notice'] == 'Y';

          // 날짜 포맷팅 (예: 2026-05-04T02:15:00 -> 2026-05-04)
          String dateStr = notice['created_at'] ?? '';
          if (dateStr.length >= 10) {
            dateStr = dateStr.substring(0, 10);
          }

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: isNotice ? 3 : 1,
            // 공지사항(Y)일 경우 배경색을 약간 다르게 주어 강조
            color: isNotice ? Colors.orange.shade50 : Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isNotice ? Colors.orange.shade200 : Colors.grey.shade200,
                )
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: isNotice
                  ? const Icon(Icons.campaign, color: Colors.orange, size: 32)
                  : const Icon(Icons.article_outlined, color: Colors.grey, size: 32),
              title: Text(
                notice['title'] ?? '제목 없음',
                style: TextStyle(
                  fontWeight: isNotice ? FontWeight.bold : FontWeight.w600,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${notice['author']}  |  $dateStr',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.visibility, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${notice['view_count']}',
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              onTap: () {
                // 상세 보기 화면으로 이동하고, 뒤로 돌아왔을 때 조회수 갱신을 위해 목록을 다시 불러옵니다.
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NoticeViewScreen(noticeId: notice['id']),
                  ),
                ).then((_) {
                  // 상세 화면에서 뒤로가기를 눌러 돌아오면 조회수가 올라가 있으므로 새로고침
                  _fetchNotices();
                });
              },
            ),
          );
        },
      ),
    );
  }
}