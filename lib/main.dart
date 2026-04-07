import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, String>> coins = const [
    {"name": "KOMA_USDT", "change": "+58.22%"},
    {"name": "BULLA_USDT", "change": "+44.77%"},
    {"name": "PLAY_USDT", "change": "+34.27%"},
    {"name": "APR_USDT", "change": "+31.12%"},
    {"name": "TRU_USDT", "change": "+28.90%"},
    {"name": "DOGE_USDT", "change": "+25.61%"},
    {"name": "SOL_USDT", "change": "+22.10%"},
    {"name": "ETH_USDT", "change": "+19.85%"},
    {"name": "BTC_USDT", "change": "+17.40%"},
    {"name": "XRP_USDT", "change": "+15.12%"},
  ];

  bool isLoading = true;
  String errorText = '';

  @override
  void initState() {
    super.initState();
    fetchCoins();
  }

  Future<void> fetchCoins() async {
    setState(() {
      isLoading = true;
      errorText = '';
    });

    final urls = [
     'https://api.allorigins.win/raw?url=https://fx-api.gateio.ws/api/v4/futures/usdt/tickers',
]; 

    try {
      List<dynamic>? data;

      for (final url in urls) {
        try {
          final response = await http.get(
            Uri.parse(url),
            headers: {'Accept': 'application/json'},
          );

          if (response.statusCode == 200) {
            final decoded = jsonDecode(response.body);
            if (decoded is List) {
              data = decoded;
              break;
            }
          }
        } catch (_) {}
      }

      if (data == null) {
        throw Exception('Gate.io verisi alınamadı');
      }

      final List<Map<String, String>> tempCoins = [];

      for (final item in data) {
        if (item is! Map<String, dynamic>) continue;

        final contract = (item['contract'] ?? '').toString();
        if (!contract.endsWith('_USDT')) continue;

        final rawChange = (item['change_percentage'] ?? '0').toString();
        final parsedChange = double.tryParse(rawChange) ?? 0.0;

        final changeText =
            '${parsedChange >= 0 ? '+' : ''}${parsedChange.toStringAsFixed(2)}%';

        tempCoins.add({
          "name": contract,
          "change": changeText,
        });
      }

      tempCoins.sort((a, b) {
        final aValue = double.tryParse(
              a["change"]!.replaceAll('%', '').replaceAll('+', ''),
            ) ??
            0;
        final bValue = double.tryParse(
              b["change"]!.replaceAll('%', '').replaceAll('+', ''),
            ) ??
            0;
        return bValue.compareTo(aValue);
      });

      if (!mounted) return;

      setState(() {
        coins = tempCoins.take(10).toList();
        isLoading = false;
        errorText = '';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorText = 'Canlı veri alınamadı';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/bg.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: fetchCoins,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/hero.png',
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isLoading
                                  ? Colors.orangeAccent
                                  : Colors.greenAccent,
                            ),
                          ),
                          child: Text(
                            isLoading ? 'Yükleniyor' : 'Canlı Veri',
                            style: TextStyle(
                              color: isLoading
                                  ? Colors.orangeAccent
                                  : Colors.greenAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (errorText.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.redAccent.withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        errorText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  ...coins.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final coin = entry.value;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetailPage(
                                coin: coin["name"]!,
                                change: coin["change"]!,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          height: 78,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            gradient: const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Color(0xFF07122A),
                                Color(0xFF091933),
                                Color(0xFF07122A),
                              ],
                            ),
                            border: Border.all(
                              color: const Color(0xFF3EA6FF),
                              width: 1.4,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x663EA6FF),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                              BoxShadow(
                                color: Color(0x3300FFFF),
                                blurRadius: 18,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF123D9B),
                                    border: Border.all(
                                      color: const Color(0xFF5AA8FF),
                                      width: 1.6,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x663EA6FF),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    "$index",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    coin["name"]!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  coin["change"]!,
                                  style: TextStyle(
                                    color: coin["change"]!.startsWith('-')
                                        ? Colors.redAccent
                                        : const Color(0xFF3CFFB2),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DetailPage extends StatelessWidget {
  final String coin;
  final String change;

  const DetailPage({
    super.key,
    required this.coin,
    required this.change,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/bg.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/hero.png',
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: Colors.redAccent.withOpacity(0.4)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              "Long / Short",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 18),
                            ),
                            Text(
                              "73%",
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 27,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.7),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(10),
                                      bottomLeft: Radius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 73,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withOpacity(0.85),
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(10),
                                      bottomRight: Radius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 190,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.orangeAccent.withOpacity(0.4),
                      ),
                    ),
                    child: CustomPaint(
                      painter: ChartPainter(),
                      child: const Center(
                        child: Text(
                          "24H",
                          style:
                              TextStyle(color: Colors.white54, fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: Colors.redAccent.withOpacity(0.6)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "SHORT İÇİN GÜÇLÜ SİNYAL!",
                          style: TextStyle(
                            color: Colors.orangeAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "$coin için canlı değişim verisi: $change",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1;

    for (double i = 0; i <= size.width; i += size.width / 6) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i <= size.height; i += size.height / 4) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    final linePaint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = Colors.orangeAccent.withOpacity(0.35)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final path = Path();
    path.moveTo(0, size.height * 0.20);
    path.lineTo(size.width * 0.10, size.height * 0.24);
    path.lineTo(size.width * 0.18, size.height * 0.30);
    path.lineTo(size.width * 0.28, size.height * 0.34);
    path.lineTo(size.width * 0.38, size.height * 0.46);
    path.lineTo(size.width * 0.50, size.height * 0.52);
    path.lineTo(size.width * 0.63, size.height * 0.60);
    path.lineTo(size.width * 0.75, size.height * 0.67);
    path.lineTo(size.width * 0.87, size.height * 0.76);
    path.lineTo(size.width, size.height * 0.88);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
