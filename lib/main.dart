import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class Coin {
  final String name;
  final double change;

  Coin({
    required this.name,
    required this.change,
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Short Radar Pro',
      home: const HomePage(),
      theme: ThemeData.dark(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Coin> coins = [];
  bool loading = true;
  String error = '';

  @override
  void initState() {
    super.initState();
    fetchCoins();
  }

  Future<List<dynamic>> _fetchFromAnyEndpoint() async {
    final urls = [
      'https://api.gateio.ws/api/v4/futures/usdt/tickers',
      'https://fx-api.gateio.ws/api/v4/futures/usdt/tickers',
    ];

    Exception? lastError;

    for (final url in urls) {
      try {
        final res = await http.get(
          Uri.parse(url),
          headers: {'Accept': 'application/json'},
        );

        if (res.statusCode == 200) {
          final decoded = json.decode(res.body);
          if (decoded is List) {
            return decoded;
          } else {
            throw Exception('Beklenmeyen veri formatı');
          }
        } else {
          lastError = Exception('API hata verdi: ${res.statusCode}');
        }
      } catch (e) {
        lastError = Exception(e.toString());
      }
    }

    throw lastError ?? Exception('Veri alınamadı');
  }

  Future<void> fetchCoins() async {
    setState(() {
      loading = true;
      error = '';
    });

    try {
      final data = await _fetchFromAnyEndpoint();

      final List<Coin> temp = [];

      for (final item in data) {
        if (item is! Map<String, dynamic>) continue;

        final contract = item['contract']?.toString() ?? '';
        if (!contract.endsWith('_USDT')) continue;

        final changeRaw = item['change_percentage'];
        final double change = double.tryParse(changeRaw?.toString() ?? '0') ?? 0.0;

        temp.add(
          Coin(
            name: contract,
            change: change,
          ),
        );
      }

      temp.sort((a, b) => b.change.compareTo(a.change));

      setState(() {
        coins = temp.take(10).toList();
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topCoin = coins.isNotEmpty ? coins.first : null;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF050014), Color(0xFF4A248A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : error.isNotEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Veri alınamadı',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              error,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: fetchCoins,
                              child: const Text('Tekrar dene'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: fetchCoins,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (topCoin != null)
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF3B1F), Color(0xFFFF8A00)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.35),
                                    blurRadius: 18,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'EN GÜÇLÜ SHORT ADAYI',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    topCoin.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${topCoin.change >= 0 ? '+' : ''}${topCoin.change.toStringAsFixed(2)}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 20),
                          ...coins.asMap().entries.map((entry) {
                            final rank = entry.key + 1;
                            final coin = entry.value;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 18,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                color: const Color(0xFF041734),
                                border: Border.all(
                                  color: const Color(0xFF35A8FF),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF35A8FF).withOpacity(0.25),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF1E4FB5),
                                      border: Border.all(
                                        color: const Color(0xFF66C2FF),
                                        width: 1.5,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '$rank',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      coin.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${coin.change >= 0 ? '+' : ''}${coin.change.toStringAsFixed(2)}%',
                                    style: const TextStyle(
                                      color: Color(0xFF46F0A6),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}
