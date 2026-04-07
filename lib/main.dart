import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class Coin {
  final String name;
  final double change;

  Coin({required this.name, required this.change});
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
  List<Coin> coins = [];
  bool loading = true;
  String error = '';

  @override
  void initState() {
    super.initState();
    fetchCoins();
  }

  Future<void> fetchCoins() async {
    setState(() {
      loading = true;
      error = '';
    });

    try {
      final url = Uri.parse(
          'https://fx-api.gateio.ws/api/v4/futures/usdt/tickers');

      final res = await http.get(url);

      if (res.statusCode == 200) {
        List data = json.decode(res.body);

        List<Coin> temp = [];

        for (var item in data) {
          double change =
              double.tryParse(item['change_percentage'] ?? '0') ?? 0.0;

          temp.add(Coin(
            name: item['contract'],
            change: change,
          ));
        }

        temp.sort((a, b) => b.change.compareTo(a.change));

        setState(() {
          coins = temp.take(10).toList();
          loading = false;
        });
      } else {
        throw Exception('API hata verdi');
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, Colors.deepPurple],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error.isNotEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Veri alınamadı",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 20)),
                          const SizedBox(height: 10),
                          Text(error,
                              style: const TextStyle(color: Colors.white70)),
                          const SizedBox(height: 20),
                          ElevatedButton(
                              onPressed: fetchCoins,
                              child: const Text("Tekrar dene"))
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // 🔥 TOP CARD
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(
                              colors: [Colors.red, Colors.orange],
                            ),
                          ),
                          child: Column(
                            children: [
                              const Text("EN GÜÇLÜ SHORT ADAYI",
                                  style: TextStyle(color: Colors.white)),
                              const SizedBox(height: 10),
                              Text(coins[0].name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 5),
                              Text(
                                "+${coins[0].change.toStringAsFixed(2)}%",
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 18),
                              )
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // LIST
                        ...coins.asMap().entries.map((entry) {
                          int i = entry.key;
                          Coin c = entry.value;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              color: Colors.blue.withOpacity(0.2),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "${i + 1}. ${c.name}",
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 16),
                                ),
                                Text(
                                  "+${c.change.toStringAsFixed(2)}%",
                                  style: const TextStyle(
                                      color: Colors.green, fontSize: 16),
                                ),
                              ],
                            ),
                          );
                        }).toList()
                      ],
                    ),
        ),
      ),
    );
  }
}
