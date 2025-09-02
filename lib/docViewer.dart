import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_all/flutter_html_all.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config/api_config.dart';

class DocViewerScreen extends StatefulWidget {
  const DocViewerScreen({super.key});

  @override
  DocViewerScreenState createState() => DocViewerScreenState();
}

class DocViewerScreenState extends State<DocViewerScreen> {
  final staticAnchorKey = GlobalKey();
  String htmlData = ""; // API에서 가져온 HTML 데이터를 저장할 변수
  String htmlTitle = ""; // API에서 가져온 타이틀 데이터를 저장할 변수
  bool isLoading = true; // 로딩 상태를 관리하는 변수

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    fetchHtmlData(); // 화면 초기화 시 HTML 데이터를 가져옴
  }

  Future<void> fetchHtmlData() async {
    // 이전 화면에서 전달받은 docNo 값
    final dynamic docNo = ModalRoute.of(context)?.settings.arguments;

    // docNo를 URL에 반영
    final String url = "${ApiConf.baseUrl}/phapp/docviewer/$docNo";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(
          utf8.decode(response.bodyBytes),
        );
        setState(() {
          htmlData = jsonResponse["doc"][0]["cDoc"]; // API에서 받은 HTML 본문
          htmlTitle =
              jsonResponse["doc"][0]["title"] ?? "문서 제목 없음"; // 타이틀 데이터, 없으면 기본값
          isLoading = false; // 로딩 완료
        });
        print("HTML data and title loaded successfully."); // 성공 메시지
      } else {
        throw Exception("Failed to load HTML data: ${response.statusCode}");
      }
    } catch (e) {
      print("Error occurred: ${e.toString()}"); // 에러 메시지 출력
      setState(() {
        htmlData = "<p>Error loading content: ${e.toString()}</p>";
        htmlTitle = "Error"; // 에러 발생 시 기본 타이틀
        isLoading = false; // 로딩 종료
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text(htmlTitle), // JSON에서 가져온 타이틀을 표시
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.arrow_downward),
        onPressed: () {
          final anchorContext =
              AnchorKey.forId(staticAnchorKey, "bottom")?.currentContext;
          if (anchorContext != null) {
            Scrollable.ensureVisible(anchorContext);
          }
        },
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator()) // 로딩 중 표시
              : SingleChildScrollView(
                child: Html(
                  anchorKey: staticAnchorKey,
                  data: htmlData,
                  // API에서 가져온 HTML 데이터 사용
                  style: {
                    "table": Style(
                      backgroundColor: const Color.fromARGB(
                        0x50,
                        0xee,
                        0xee,
                        0xee,
                      ),
                    ),
                    "th": Style(
                      padding: HtmlPaddings.all(6),
                      backgroundColor: Colors.grey,
                    ),
                    "td": Style(
                      padding: HtmlPaddings.all(6),
                      border: const Border(
                        bottom: BorderSide(color: Colors.grey),
                      ),
                    ),
                    'h5': Style(
                      maxLines: 2,
                      textOverflow: TextOverflow.ellipsis,
                    ),
                    'flutter': Style(
                      display: Display.block,
                      fontSize: FontSize(5, Unit.em),
                    ),
                    ".second-table": Style(backgroundColor: Colors.transparent),
                    ".second-table tr td:first-child": Style(
                      fontWeight: FontWeight.bold,
                      textAlign: TextAlign.end,
                    ),
                  },
                  extensions: [
                    TagWrapExtension(
                      tagsToWrap: {"table"},
                      builder: (child) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: child,
                        );
                      },
                    ),
                    TagExtension(
                      tagsToExtend: {"tex"},
                      builder:
                          (context) => Math.tex(
                            context.innerHtml,
                            mathStyle: MathStyle.display,
                            textStyle:
                                context.styledElement?.style
                                    .generateTextStyle(),
                            onErrorFallback: (FlutterMathException e) {
                              return Text(e.message);
                            },
                          ),
                    ),
                    TagExtension.inline(
                      tagsToExtend: {"bird"},
                      child: const TextSpan(text: "🐦"),
                    ),
                    TagExtension(
                      tagsToExtend: {"flutter"},
                      builder:
                          (context) => CssBoxWidget(
                            style: context.styledElement!.style,
                            child: FlutterLogo(
                              style:
                                  context.attributes['horizontal'] != null
                                      ? FlutterLogoStyle.horizontal
                                      : FlutterLogoStyle.markOnly,
                              textColor: context.styledElement!.style.color!,
                              size:
                                  context.styledElement!.style.fontSize!.value,
                            ),
                          ),
                    ),
                    ImageExtension(
                      handleAssetImages: false,
                      handleDataImages: false,
                      networkDomains: {"flutter.dev"},
                      child: const FlutterLogo(size: 36),
                    ),
                    ImageExtension(
                      handleAssetImages: false,
                      handleDataImages: false,
                      networkDomains: {"mydomain.com"},
                      networkHeaders: {"Custom-Header": "some-value"},
                    ),
                    const MathHtmlExtension(),
                    const AudioHtmlExtension(),
                    const VideoHtmlExtension(),
                    const IframeHtmlExtension(),
                    const TableHtmlExtension(),
                    const SvgHtmlExtension(),
                  ],
                  onLinkTap: (url, _, __) {
                    debugPrint("Opening $url...");
                  },
                  onCssParseError: (css, messages) {
                    debugPrint("css that errored: $css");
                    debugPrint("error messages:");
                    for (var element in messages) {
                      debugPrint(element.toString());
                    }
                    return '';
                  },
                ),
              ),
    );
  }
}
