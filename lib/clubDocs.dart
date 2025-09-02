import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config/api_config.dart';

class ClubDocsScreen extends StatelessWidget {
  const ClubDocsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String? mclubNo = ModalRoute.of(context)?.settings.arguments as String?;
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.yellow, title: Text('클럽 문서 목록')),
      backgroundColor: Colors.yellow,
      body:
          mclubNo != null
              ? FutureBuilder<List<Map<String, dynamic>>>(
                future: fetchClubDocs(mclubNo),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Text('문서를 불러오는 중 오류가 발생했습니다: ${snapshot.error}'),
                    );
                  } else if (snapshot.hasData) {
                    final docs = snapshot.data!;
                    if (docs.isEmpty) {
                      return Center(child: Text('문서가 없습니다.'));
                    }
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        return Card(
                          margin: EdgeInsets.all(8.0),
                          child: ListTile(
                            title: Text(doc['docTitle'] ?? '제목 없음'),
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/docViewer',
                                arguments: doc['docNo'], // 문서 번호 전달
                              );
                            },
                          ),
                        );
                      },
                    );
                  } else {
                    return Center(child: Text('문서를 불러오는 중 문제가 발생했습니다.'));
                  }
                },
              )
              : Center(child: Text('클럽 번호가 없습니다.')),
    );
  }

  Future<List<Map<String, dynamic>>> fetchClubDocs(String mclubNo) async {
    try {
      // API 호출
      final response = await http.get(
        Uri.parse('${ApiConf.baseUrl}/phapp/clubdocs/$mclubNo'),
      );

      if (response.statusCode == 200) {
        // UTF-8 디코딩을 통해 한글 처리
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = json.decode(decodedBody);
        if (data['docs'] != null && data['docs'] is List) {
          return List<Map<String, dynamic>>.from(data['docs']);
        } else {
          throw Exception('Invalid response format');
        }
      } else {
        throw Exception('Failed to load documents: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching club docs: $e');
      throw Exception('문서를 불러오는 중 오류가 발생했습니다.');
    }
  }
}
