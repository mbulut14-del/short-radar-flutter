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

  factory Coin.fromJson(Map<String, dynamic> json) {
    return Coin(
      name: json['contract'] ?? '',
      change: double.tryParse(json['change_percentage'] ?? '0') ?? 0,
    );
  }
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
  String error = "";

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.allorigins.win/raw?url=https://api.gateio.ws/api/v4/futures/usdt/tickers',
        ),
      );

      if (response.statusCode == 200) {
        List data = json.decode(response.body);

        List<Coin> temp =
            data.map((e) => Coin.fromJson(e)).toList();

        temp.sort((a, b) => b.change.compareTo(a.change));

        setState(() {
          coins = temp.take(10).toList();
          loading = false;
        });
      } else {
        setState(() {
          error = "API hata verdi";
          loading = false;
        });
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
      backgroundColor: const Color(0xFF12002A),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("SHORT RADAR"),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Veri alınamadı",
                          style: TextStyle(color: Colors.white)),
                      const SizedBox(height: 10),
                      Text(error,
                          style: const TextStyle(color: Colors.white54)),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            loading = true;
                            error = "";
                          });
                          fetchData();
                        },
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
                      margin: const EdgeInsets.all(10),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${index + 1}. ${coin.name}",
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16),
                          ),
                          Text(
                            "%${coin.change.toStringAsFixed(2)}",
                            style: TextStyle(
                              color: coin.change > 0
                                  ? Colors.green
                                  : Colors.red,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
