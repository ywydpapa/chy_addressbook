import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class NoticeViewScreen extends StatefulWidget {
  final int noticeId;

  const NoticeViewScreen({super.key, required this.noticeId});

  @override
  State<NoticeViewScreen> createState() => _NoticeViewScreenState();
}

class _NoticeViewScreenState extends State<NoticeViewScreen> {
  Map<String, dynamic>? _notice;
  List<dynamic> _files = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchNoticeDetail();
  }

  Future<void> _fetchNoticeDetail() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('access_token');

      final url = Uri.parse('https://chyaddr.chycollege.kr/phapp/notices/${widget.noticeId}');

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
          _notice = data['notice'];
          _files = data['files'] ?? [];
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
        title: const Text('게시글 상세'),
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
          : _notice == null
          ? const Center(child: Text('게시글 정보를 찾을 수 없습니다.'))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    // 날짜 포맷팅
    String dateStr = _notice!['created_at'] ?? '';
    if (dateStr.length >= 16) {
      dateStr = dateStr.substring(0, 16).replaceFirst('T', ' '); // 2026-05-04 02:15 형태로 변환
    }

    final isNotice = _notice!['is_notice'] == 'Y';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 제목 영역
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isNotice)
                const Padding(
                  padding: EdgeInsets.only(right: 8.0, top: 2.0),
                  child: Icon(Icons.campaign, color: Colors.orange),
                ),
              Expanded(
                child: Text(
                  _notice!['title'] ?? '제목 없음',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. 작성자, 날짜, 조회수 정보
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    _notice!['author'] ?? '알 수 없음',
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    dateStr,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.visibility, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${_notice!['view_count']}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Divider(thickness: 1.5),
          ),

          // 3. 본문 내용 영역
          Container(
            constraints: const BoxConstraints(minHeight: 200),
            child: SelectableText(
              _notice!['content'] ?? '',
              style: const TextStyle(
                fontSize: 16,
                height: 1.6,
                color: Colors.black87,
              ),
            ),
          ),

          // 4. 첨부파일 영역 (파일이 있을 경우에만 표시)
          if (_files.isNotEmpty) ...[
            const SizedBox(height: 30),
            const Divider(thickness: 1.5),
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.attach_file, color: Colors.blueGrey),
                SizedBox(width: 8),
                Text(
                  '첨부파일',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _files.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final file = _files[index];
                  return ListTile(
                    leading: const Icon(Icons.insert_drive_file, color: Colors.grey),
                    title: Text(
                      file['original_name'],
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                    trailing: const Icon(Icons.download, color: Colors.blue),
                    onTap: () {
                      // TODO: 파일 다운로드 로직 구현 (url_launcher 패키지 등을 활용하여 file['file_url'] 열기)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${file['original_name']} 다운로드 준비중입니다.')),
                      );
                    },
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}