import 'package:flutter/material.dart';
import 'cmemberList.dart'; // MemberListScreen import
import 'config/api_config.dart';

class LoadingScreen extends StatefulWidget {
  final int clubNo;
  final String clubName;
  final String? mclubNo;

  const LoadingScreen({
    super.key,
    required this.clubNo,
    required this.clubName,
    required this.mclubNo,
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              MemberListScreen(
                clubNo: widget.clubNo,
                clubName: widget.clubName,
                mclubNo: widget.mclubNo,
              ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double logoSize = screenWidth * 0.8;
    String logoUrl = '${ApiConf.baseUrl}/thumbnails/${widget.clubNo}logo.png';

    return Scaffold(
      backgroundColor: Colors.yellow,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(
              logoUrl,
              width: logoSize,
              height: logoSize,
              errorBuilder: (context, error, stackTrace) {
                // 네트워크 이미지가 없을 때 assets/default.png로 대체
                return Image.asset(
                  'assets/default.png',
                  width: logoSize,
                  height: logoSize,
                  fit: BoxFit.contain,
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return SizedBox(
                  width: logoSize,
                  height: logoSize,
                  child: Center(child: CircularProgressIndicator()),
                );
              },
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Colors.black),
            const SizedBox(height: 16),
            Text(
              '${widget.clubName} 회원 목록을 불러오는 중...',
              style: const TextStyle(fontSize: 16, color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}
