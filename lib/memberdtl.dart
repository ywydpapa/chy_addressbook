import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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
  String _loggedInUserActiveYN = 'N'; // 로그인한 사용자의 활성 상태 저장

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

      // 로그인한 사용자의 활성 상태 가져오기 (기본값 N)
      _loggedInUserActiveYN = prefs.getString('activeYN') ?? 'N';

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

  Future<void> _makePhoneCall(String phoneNumber) async {
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

    // 📸 회원 사진 URL 생성
    final photoUrl = 'https://chyaddr.chycollege.kr/static/img/members/mphoto_${widget.memberNo}.png';

    // ★ 마스킹 레벨에 따른 정보 필터링 로직 ★
    int maskIndex = 0;
    if (_memberDtl != null && _memberDtl!['maskIndex'] != null) {
      maskIndex = int.tryParse(_memberDtl!['maskIndex'].toString()) ?? 0;
    }

    List<dynamic> filteredInfoList = [];

    if (maskIndex == 3) {
      filteredInfoList = [];
    } else if (maskIndex == 2) {
      filteredInfoList = _memberInfoList.where((info) {
        final title = info['catTitle']?.toString() ?? '';
        return _isPhoneNumber(title);
      }).toList();
    } else if (maskIndex == 1) {
      if (_loggedInUserActiveYN == 'ACTIV') {
        filteredInfoList = List.from(_memberInfoList);
      } else {
        filteredInfoList = [];
      }
    } else {
      filteredInfoList = List.from(_memberInfoList);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipOval(
            child: Image.network(
              photoUrl,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 100,
                  height: 100,
                  color: Colors.grey[300],
                  child: const Icon(Icons.person, size: 50, color: Colors.grey),
                );
              },
            ),
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
          if (filteredInfoList.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                maskIndex == 3 || (maskIndex == 1 && _loggedInUserActiveYN != 'ACTIV')
                    ? '해당 회원의 설정에 의해 상세 정보가 비공개 처리되었습니다.'
                    : '등록된 상세 정보가 없습니다.',
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...filteredInfoList.map((info) {
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

  Widget _buildInfoRow(String label, String value) {
    final isPhone = _isPhoneNumber(label);

    return InkWell(
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
