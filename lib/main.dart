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
    try {
      final res = await http.get(
        Uri.parse(
            'https://api.gateio.ws/api/v4/futures/usdt/contracts'),
      );

      final data = json.decode(res.body);

      List<Coin> temp = [];

      for (var item in data) {
        String name = item['name'] ?? '';
        double change = double.tryParse(
                item['change_percentage']?.toString() ?? '0') ??
            0;

        temp.add(Coin(name: name, change: change));
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
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A001F), Color(0xFF4B1FA5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Veri alınamadı",
                          style: TextStyle(
                              color: Colors.white, fontSize: 22),
                        ),
                        const SizedBox(height: 10),
                        Text(error,
                            style:
                                const TextStyle(color: Colors.white)),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: fetchCoins,
                          child: const Text("Tekrar dene"),
                        )
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: coins.length,
                    itemBuilder: (context, index) {
                      final coin = coins[index];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${index + 1}. ${coin.name}",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18),
                            ),
                            Text(
                              "+${coin.change.toStringAsFixed(2)}%",
                              style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 18),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
