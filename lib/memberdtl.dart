import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart'; // 📞 url_launcher 패키지 추가

class MemberDetailScreen extends StatefulWidget {
  final int memberNo;
  final String memberName;

  const MemberDetailScreen({
    super.key,
    required this.memberNo,
    required this.memberName,
  });

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  Map<String, dynamic>? _memberDtl;
  List<dynamic> _memberInfoList = [];

  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchMemberDetail();
  }

  Future<void> _fetchMemberDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('access_token');

      if (token == null) {
        setState(() {
          _errorMessage = '로그인 정보가 없습니다.';
          _isLoading = false;
        });
        return;
      }

      final url = Uri.parse('https://chyaddr.chycollege.kr/phapp/memberdtl/${widget.memberNo}');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));

        setState(() {
          _memberDtl = data['memberdtl'];
          _memberInfoList = data['memberinfo'] ?? [];
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

  // 📞 전화 걸기 함수
  Future<void> _makePhoneCall(String phoneNumber) async {
    // 전화번호에서 숫자와 '+' 기호만 남기고 필터링 (예: 010-1234-5678 -> 01012345678)
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: cleanNumber,
    );

    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('전화를 걸 수 없는 기기입니다.')),
        );
      }
    }
  }

  // 전화번호 항목인지 확인하는 함수
  bool _isPhoneNumber(String title) {
    return title.contains('전화') || title.contains('연락처') || title.contains('휴대폰');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.memberName} 상세정보'),
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
      return Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)));
    }

    final displayMemberName = _memberDtl?['memberName']?.toString() ?? widget.memberName;
    final displayMemberNo = _memberDtl?['memberNo']?.toString() ?? widget.memberNo.toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey[300],
            child: const Icon(Icons.person, size: 50, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Text(
            displayMemberName,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '회원번호: $displayMemberNo',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 30),
          const Divider(thickness: 2),

          if (_memberInfoList.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text('등록된 상세 정보가 없습니다.', style: TextStyle(color: Colors.grey)),
            )
          else
            ..._memberInfoList.map((info) {
              final title = info['catTitle']?.toString() ?? '항목 없음';
              final content = info['infoContents']?.toString() ?? '내용 없음';

              return Column(
                children: [
                  _buildInfoRow(title, content),
                  const Divider(),
                ],
              );
            }).toList(),
        ],
      ),
    );
  }

  IconData _getIconForTitle(String title) {
    if (_isPhoneNumber(title)) {
      return Icons.phone;
    } else if (title.contains('주소')) {
      return Icons.home;
    } else if (title.contains('이메일') || title.contains('메일')) {
      return Icons.email;
    } else if (title.contains('소속') || title.contains('회사') || title.contains('직장')) {
      return Icons.business;
    } else if (title.contains('팩스') || title.contains('fax')) {
      return Icons.fax;
    } else if (title.contains('생일') || title.contains('생년월일')) {
      return Icons.cake;
    }
    return Icons.info_outline;
  }

  // 상세 정보 한 줄을 그려주는 위젯
  Widget _buildInfoRow(String label, String value) {
    final isPhone = _isPhoneNumber(label); // 전화번호 여부 확인

    return InkWell(
      // 전화번호 항목이면 해당 줄을 탭했을 때도 전화가 걸리도록 설정
      onTap: isPhone ? () => _makePhoneCall(value) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(_getIconForTitle(label), color: Colors.green),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
            // 📞 전화번호 항목일 경우 우측에 전화 걸기 버튼 추가
            if (isPhone)
              IconButton(
                icon: const Icon(Icons.call, color: Colors.green),
                onPressed: () => _makePhoneCall(value),
                tooltip: '전화 걸기',
              ),
          ],
        ),
      ),
    );
  }
}
