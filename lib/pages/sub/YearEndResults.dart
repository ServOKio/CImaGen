import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cimagen/Utils.dart';
import 'package:cimagen/main.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../utils/ImageManager.dart';

class YearEndResults extends StatefulWidget{
  int year;
  YearEndResults({ super.key, required this.year });

  @override
  State<YearEndResults> createState() => _YearEndResultsState();
}

class _YearEndResultsState extends State<YearEndResults> {
  bool loaded = false;

  List<Member> members = [];
  List<List<int>> yearsComparison = [];
  int NNNCount = -1;
  List<List<dynamic>> topArtists = [];
  List<ImageMeta> topFileSize = [];

  final _random = Random();
  int next(int min, int max) => min + _random.nextInt(max - min);

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    final response = await http.Client().get(Uri.parse('https://discord.com/api/guilds/280435323983364097/widget.json'));
    if(response.statusCode == 200){
      Map<String, dynamic> main = jsonDecode(response.body);
      if (main['members'] != null) {
        main['members'].forEach((alb) {
          members.add(Member(id: int.parse(alb['id']), username: alb['username'], discriminator: alb['discriminator'], status: alb['status'], avatarUrl: alb['avatar_url']));
        });
      }
      sqLite.yearsComparison(2025).then((data){
        sqLite.countCumInNovember(2025).then((dataCum){
          sqLite.topArtists(host: context.read<ImageManager>().getter.host, year: 2025, limit: 30).then((dataArtist){
            sqLite.getTopByFileSize(2025, host: context.read<ImageManager>().getter.host, limit: 10).then((dataFileSize) {
              setState(() {
                topArtists = dataArtist;
                NNNCount = dataCum;
                yearsComparison = data;
                topFileSize = dataFileSize;
                loaded = true;
              });
            });
          });
        });
      });

    } else {

    }
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.sizeOf(context).width;
    double height = MediaQuery.sizeOf(context).height;

    // width = 100%
    //     ? = 90%

    return Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: loaded ? SingleChildScrollView(clipBehavior: Clip.none, child: Column(
          children: [
            mainBlock(),
            yearOverallPercentBlock(),
            NNNovemberBlock(),
            TopArtist(),
            SizedBox(
              width: width, height: height/2,
              child: Stack(
                children: [
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [1,2,3,4,5,6,7,6,5,4,3,2,1].asMap().map((i, element) => MapEntry(i, Container(
                        width: width/13,
                        height: (height/2)/(element),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Color(0xFF6C5CE3),
                            Colors.transparent
                          ], begin: AlignmentGeometry.bottomCenter, end: Alignment.topCenter)
                        )
                      ))).values.toList(),
                    ),
                  ),
                  Positioned.fill(child: Center(child: Container(
                    constraints: BoxConstraints(maxWidth: width * 70 / 100),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Top of the most mind-blowing ones', textAlign: TextAlign.center, style: TextStyle(fontSize: 42, fontFamily: 'Montserrat', fontWeight: FontWeight.w600, color: Colors.white)),
                        Text('Let\'s see what people are capable of', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontFamily: 'Open Sans', color: Colors.white54))
                      ],
                    ),
                  )))
                ],
              )
            ),
            SizedBox(
              width: width, height: height/2,
              child: Row(
                children: topFileSize.map((item) => Stack(
                  children: [
                    Image.memory(
                      width: width/topFileSize.length-7,
                      item.thumbnail!,
                      gaplessPlayback: true,
                    ),
                    Container(
                      color: Colors.black.withAlpha(120),
                      child: Text('${readableFileSize(item.fileSize!)}\n${item.size.toString()}'),
                    )
                  ],
                )).expand((x) => [const Gap(7), x]).skip(1).toList(),
              ),
            )
          ],
        )) : Center(child: CircularProgressIndicator())
    );
  }

  Widget mainBlock(){
    double width = MediaQuery.sizeOf(context).width;
    double height = MediaQuery.sizeOf(context).height;
    return Container(
      clipBehavior: Clip.none,
      constraints: BoxConstraints(
        minHeight: height,
      ),
      width: width, height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ...members.map((member){
            double size = next(30, 60).toDouble();
            return Positioned(
                left: next(0, MediaQuery.of(context).size.width.round()).toDouble(),
                top: next(0, MediaQuery.of(context).size.height.round()).toDouble(),
                child: Opacity(opacity: 0.5, child: CachedNetworkImage(
                    imageUrl: member.avatarUrl,
                    imageBuilder: (context, imageProvider) {
                      return Container(
                        height: size,
                        width: size,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                              image: imageProvider,
                              fit: BoxFit.cover
                          ),
                          shape: BoxShape.circle,
                        ),
                      );
                    },
                    placeholder: (context, url) => Container(width: 50, height: 50, decoration: BoxDecoration(shape: BoxShape.circle)),
                    errorWidget: (context, url, error) => Center(child: Icon(Icons.error))
                ))
            );
          }),
          Positioned.fill(child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
            child: Container(
              color: Colors.black.withOpacity(0.1),
            ),
          )),
          Positioned(
            top: 14,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image(image: AssetImage('assets/icons/icon128white.png'), width: 27),
                Gap(8),
                Text('CImaGen', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w500, fontFamily: 'Montserrat'))
              ],
            ),
          ),
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.transparent,
                        Colors.white,
                      ],
                    ),
                  ),
                  width: (width * 10 / 100),
                  height: 2,
                ),
                Gap(8),
                Text('fox\'s ass is no longer empty, yay!', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, fontFamily: 'Montserrat')),
                Gap(8),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        Colors.transparent,
                        Colors.white,
                      ],
                    ),
                  ),
                  width: (width * 10 / 100),
                  height: 2,
                ),
              ],
            ),
          ),
          Positioned(
            left: -(width * 30 / 100) / 2,
            bottom: (width * 30 / 100) / 2,
            child: Transform.rotate(
              angle: -0.785398, // -45 degrees in radians
              child:Stack(
                alignment: Alignment.center,
                children: [
                  // Glow effect
                  Container(
                    width: width * 30 / 100,
                    height: width * 30 / 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.transparent,
                          Color(0xFFBB86FC), // glowing purple
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFBB86FC).withOpacity(0.7),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: width * 26 / 100,
                    height: width * 26 / 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF3700B3), // dark purple
                          Color(0xFFBB86FC), // bright purple
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: -(width * 30 / 100) / 2,
            top: (width * 30 / 100) / 2,
            child: Transform.rotate(
              angle: -0.785398, // -45 degrees in radians
              child:Stack(
                alignment: Alignment.center,
                children: [
                  // Glow effect
                  Container(
                    width: width * 30 / 100,
                    height: width * 30 / 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFBB86FC),
                          Colors.transparent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFBB86FC).withOpacity(0.7),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: width * 26 / 100,
                    height: width * 26 / 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFBB86FC),
                          Color(0xFF3700B3), // dark purple
                          // bright purple
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Furry Diffusion 2025', style: TextStyle(fontSize: 18, fontFamily: 'Open Sans')),
                Text('Year In Review', style: TextStyle(fontSize: 84, fontWeight: FontWeight.w600, fontFamily: 'Montserrat')),
                Container(
                  constraints: BoxConstraints(maxWidth: width * 50 / 100),
                  child: Text('Dive into the numbers, the trends, and the incredible images community conjured this year\n—\nfrom epic prompts to favorite LoRAs and beyond', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontFamily: 'Open Sans', color: Colors.white54)),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
  Widget yearOverallPercentBlock(){
    double width = MediaQuery.sizeOf(context).width;
    double height = MediaQuery.sizeOf(context).height;
    int yearOP = yearOverallPercent(yearsComparison);

    return Container(
      constraints: BoxConstraints(
        minHeight: height,
      ),
      width: width, height: height,
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Number of artworks increased by $yearOP%\ncompared to last year', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, fontFamily: 'Montserrat'), textAlign: TextAlign.center),
                Text('$yearOP%', style: TextStyle(fontSize: height/4, fontWeight: FontWeight.w600, fontFamily: 'Montserrat', color: Color(0xFF3bb2e7))),
              ],
            ),
          ),
          Positioned(bottom: 0, left: 0, right: 0, child: SizedBox(
            height: (height * 80 / 100),
            child: LineChart(
              LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(
                      show: false
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: toFlSpots(yearsComparison[0]),
                      color: Color(0xFF3bb2e7), // color for current year
                      barWidth: 4,
                      isCurved: true,
                      belowBarData: BarAreaData(
                          show: true,
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xff3b8be7),
                              Colors.transparent,
                            ],
                          )
                      ),
                      dotData: FlDotData(
                          getDotPainter: (FlSpot spot,
                              double xPercentage,
                              LineChartBarData bar,
                              int index, {
                                double? size,
                              }) => FlDotCirclePainter(
                              radius: 10,
                              color: Colors.white,
                              strokeColor: Colors.white.withAlpha(120),
                              strokeWidth: 4
                          )
                      ),
                    ),
                    LineChartBarData(
                      spots: toFlSpots(yearsComparison[1]),
                      color: Color(0xff8096f0),
                      barWidth: 4,
                      isCurved: true,
                    ),
                  ]
              ),
            ),
          )),
        ],
      ),
    );
  }
  Widget NNNovemberBlock(){
    double width = MediaQuery.sizeOf(context).width;
    double height = MediaQuery.sizeOf(context).height;

    // width = 100%
    //     ? = 90%

    return Container(
      constraints: BoxConstraints(
        minHeight: height,
      ),
      width: width, height: height,
      child: Stack(
        children: [
          Center(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final text = NNNCount.toString();
                final style = TextStyle(fontWeight: FontWeight.w800, fontFamily: 'Montserrat', color: Colors.black); // apply your barcode font here
                final fontSize = calculateAutoscaleFontSize(text, style, 30.0, width);
                return Stack(
                  children: [
                    Positioned(top: -30, child: ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) => LinearGradient(
                          colors: [Color(0xFF1196c7), Color(0xFF951cb1)],
                          begin: AlignmentGeometry.topCenter,
                          end: AlignmentGeometry.bottomCenter
                      ).createShader(
                        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                      ),
                      child: Text(text, style: style.copyWith(fontSize: fontSize, color: Colors.white)),
                    )),
                    Positioned.fill(child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Container(),
                    )),
                    Text(text, style: style.copyWith(fontSize: fontSize, color: Colors.white)),
                    Positioned(
                        top: 10,
                        child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                            child: Text(
                              text,
                              style: style.copyWith(fontSize: fontSize),
                              maxLines: 1,
                            )
                        )
                    ),
                  ],
                );
              },
            ),
          ),
          Positioned(
            bottom: width/12,
            left: width/12,
            child: Container(
              constraints: BoxConstraints(maxWidth: width * 50 / 100),
              child: Text('times "cum" tag was used during NNNovember', style: TextStyle(fontSize: width * 4 / 100, fontWeight: FontWeight.w500, fontFamily: 'Montserrat', color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }
  Widget TopArtist(){
    double width = MediaQuery.sizeOf(context).width;
    double height = MediaQuery.sizeOf(context).height;

    // width = 100%
    //     ? = 90%

    LinearGradient _barsGradient = LinearGradient(
      colors: [Colors.blue, Colors.cyan,],
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
    );

    return SizedBox(
      width: width, height: height,
      child: Padding(padding: EdgeInsetsGeometry.only(right: 56, bottom: 28, top: 28),
          child: Stack(
            children: [
              Positioned.fill(child: BarChart(
                BarChartData(
                  rotationQuarterTurns: 1,
                  alignment: BarChartAlignment.spaceAround,
                  barTouchData: BarTouchData(
                    enabled: false,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => Colors.transparent,
                      tooltipPadding: EdgeInsets.zero,
                      tooltipMargin: 8,
                      getTooltipItem: (BarChartGroupData group, int groupIndex, BarChartRodData rod, int rodIndex) {
                        return BarTooltipItem(
                          rod.toY.round().toString(),
                          const TextStyle(
                            color: Colors.cyan,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 130,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final style = TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          );
                          return SideTitleWidget(
                            meta: meta,
                            space: 4,
                            child: Text(topArtists[value.toInt()][0], style: style),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles:const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.blue.withValues(alpha: 0.5),
                      strokeWidth: 1,
                    ),
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(
                    show: false,
                  ),
                  // groupsSpace: barsSpace,
                  barGroups: topArtists.asMap().map((i, element) => MapEntry(i, BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: element[1].toDouble(),
                        gradient: _barsGradient,
                      )
                    ],
                    showingTooltipIndicators: [0],
                  ))).values.toList(),
                ),
              )),
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                child: Container(
                  constraints: BoxConstraints(maxWidth: width * 50 / 100),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) => LinearGradient(
                            colors: [Colors.cyan, Colors.blue],
                            begin: AlignmentGeometry.topCenter,
                            end: AlignmentGeometry.bottomCenter
                        ).createShader(
                          Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                        ),
                        child: Text(topArtists[0][0], style: TextStyle(fontSize: height * 10 / 100, fontWeight: FontWeight.w500, fontFamily: 'Montserrat', color: Colors.white)),
                      ),
                      Text('is the most beloved artist of 2025 - ${topArtists[0][1]} times', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w400, fontFamily: 'Montserrat', color: Colors.white))
                    ],
                  ),
                ),
              )
            ],
          )
      ),
    );
  }
}

class Member {
  final int id;
  final String username;
  final String discriminator;
  final String status;
  final String avatarUrl;

  Member({
    required this.id,
    required this.username,
    required this.discriminator,
    required this.status,
    required this.avatarUrl
  });
}

List<FlSpot> toFlSpots(List<int> monthlyCounts) {
  return List.generate(monthlyCounts.length, (i) => FlSpot(i.toDouble(), monthlyCounts[i].toDouble()));
}

int yearOverallPercent(List<List<int>> years) {
  final currentYearTotal = years[0].reduce((a, b) => a + b);
  final previousYearTotal = years[1].reduce((a, b) => a + b);

  if (previousYearTotal == 0) {
    return currentYearTotal > 0 ? 100 : 0;
  }

  return (((currentYearTotal - previousYearTotal) / previousYearTotal) * 100.0).round();
}

double calculateAutoscaleFontSize(String text, TextStyle style, double startFontSize, double maxWidth) {
  final textPainter = TextPainter(textDirection: TextDirection.ltr);

  var currentFontSize = startFontSize;

  for (var i = 0; i < 500; i++) {
    // limit max iterations to 100
    final nextFontSize = currentFontSize + 1;
    final nextTextStyle = style.copyWith(fontSize: nextFontSize);
    textPainter.text = TextSpan(text: text, style: nextTextStyle);
    textPainter.layout();
    if (textPainter.width >= maxWidth) {
      break;
    } else {
      currentFontSize = nextFontSize;
      // continue iteration
    }
  }

  return currentFontSize;
}