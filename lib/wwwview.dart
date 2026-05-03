import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WwwViewScreen extends StatefulWidget {
  const WwwViewScreen({super.key});

  @override
  State<WwwViewScreen> createState() => _WwwViewScreenState();
}

class _WwwViewScreenState extends State<WwwViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // 웹뷰 컨트롤러 초기화 및 설정
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted) // 자바스크립트 허용
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true; // 페이지 로딩 시작 시 인디케이터 표시
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false; // 페이지 로딩 완료 시 인디케이터 숨김
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('Web Error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse('https://www.chycollege.kr')); // 접속할 URL
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('충효예대학 홈페이지'),
        centerTitle: true,
        actions: [
          // 새로고침 버튼
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _controller.reload();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 실제 웹뷰 영역
          WebViewWidget(controller: _controller),

          // 로딩 중일 때 화면 가운데에 동그란 프로그래스 바 표시
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}