import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'clubLogo.dart';
import 'config/api_config.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: ClubListScreen());
  }
}

class Club {
  final int clubNo;
  final String clubName;
  final int regionNo;

  Club({required this.clubNo, required this.clubName, required this.regionNo});

  factory Club.fromJson(Map<String, dynamic> json) {
    return Club(
      clubNo: json['clubNo'],
      clubName: json['clubName'],
      regionNo: json['regionNo'],
    );
  }
}

class ClubListScreen extends StatefulWidget {
  const ClubListScreen({super.key});

  @override
  _ClubListScreenState createState() => _ClubListScreenState();
}

class _ClubListScreenState extends State<ClubListScreen> {
  late Future<List<Club>> _clubList;

  @override
  void initState() {
    super.initState();
    _clubList = fetchClubList();
  }

  Future<List<Club>> fetchClubList() async {
    final response = await http.get(
      Uri.parse('${ApiConf.baseUrl}/phapp/clubList/15'),
    );

    if (response.statusCode == 200) {
      final decodedResponse = utf8.decode(response.bodyBytes);
      Map<String, dynamic> data = json.decode(decodedResponse);
      List<dynamic> clubs = data['clubs'];
      return clubs.map((json) => Club.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load club list');
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? mclubNo =
        ModalRoute.of(context)?.settings.arguments as String?;
    print('ClubListScreen - mclubNo: $mclubNo'); // 디버깅용 출력
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.yellow, title: Text('클럽 리스트')),
      backgroundColor: Colors.yellow,
      body: FutureBuilder<List<Club>>(
        future: _clubList,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No clubs found'));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final club = snapshot.data![index];
                return Card(
                  margin: EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: CircleAvatar(child: Text(club.clubNo.toString())),
                    title: Text(club.clubName),
                    onTap: () {
                      // 리스트 항목 클릭 시 memberList.dart 화면으로 이동
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => LoadingScreen(
                                clubNo: club.clubNo,
                                clubName: club.clubName,
                                mclubNo: mclubNo,
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
    );
  }
}
