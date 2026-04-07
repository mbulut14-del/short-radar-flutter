import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const ShortRadarApp());
}

class ShortRadarApp extends StatelessWidget {
  const ShortRadarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Short Radar Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class GateFuturesService {
  static const String _base = 'https://api.gateeu.com/api/v4';

  Future<List<ShortCandidate>> fetchTopShortCandidates() async {
    final tickersUri = Uri.parse('$_base/futures/usdt/tickers');
    final contractsUri = Uri.parse('$_base/futures/usdt/contracts');

    final responses = await Future.wait([
      http.get(tickersUri, headers: {'Accept': 'application/json'}),
      http.get(contractsUri, headers: {'Accept': 'application/json'}),
    ]);

    final tickersRes = responses[0];
    final contractsRes = responses[1];

    if (tickersRes.statusCode != 200) {
      throw Exception('Ticker verisi alınamadı: ${tickersRes.statusCode}');
    }
    if (contractsRes.statusCode != 200) {
      throw Exception('Contract verisi alınamadı: ${contractsRes.statusCode}');
    }

    final List<dynamic> tickersJson = jsonDecode(tickersRes.body);
    final List<dynamic> contractsJson = jsonDecode(contractsRes.body);

    final Map<String, Map<String, dynamic>> contractsMap = {
      for (final c in contractsJson)
        if (c is Map<String, dynamic>) _string(c['name']): c,
    };

    final List<ShortCandidate> candidates = [];

    for (final raw in tickersJson) {
      if (raw is! Map<String, dynamic>) continue;

      final contract = _string(raw['contract']);
      if (!_isUsdtPerp(contract)) continue;

      final contractInfo = contractsMap[contract] ?? const <String, dynamic>{};

      final double changePct = _firstDouble(raw, const [
        'change_percentage',
        'change_percentage_24h',
        'price_24h_pcnt',
      ]);

      final double fundingRate = _firstDouble(raw, const [
        'funding_rate',
        'funding_rate_indicative',
      ]);

      final double markPrice = _firstDouble(raw, const [
        'mark_price',
        'mark_price_round',
        'last',
      ]);

      final double lastPrice = _firstDouble(raw, const ['last', 'last_price']);
      final double indexPrice = _firstDouble(raw, const ['index_price']);
      final double volumeUsd = _firstDouble(raw, const [
        'volume_24h_usd',
        'volume_24h_quote',
        'volume_24h',
      ]);

      final double volumeBase = _firstDouble(raw, const [
        'volume_24h_base',
        'volume_24h_btc',
      ]);

      final double quantoMultiplier = _firstDouble(
        contractInfo,
        const ['quanto_multiplier'],
      );

      final double riskVolume = volumeUsd > 0
          ? volumeUsd
          : (volumeBase > 0 && lastPrice > 0 ? volumeBase * lastPrice : 0.0);

      if (changePct <= 0) continue;
      if (riskVolume <= 0) continue;

      final double premiumPct = (markPrice > 0 && indexPrice > 0)
          ? ((markPrice - indexPrice) / indexPrice) * 100
          : 0.0;

      final double score = _scoreCandidate(
        changePct: changePct,
        fundingRate: fundingRate,
        volumeUsd: riskVolume,
        premiumPct: premiumPct,
      );

      candidates.add(
        ShortCandidate(
          contract: contract,
          score: score,
          changePct: changePct,
          fundingRatePct: fundingRate * 100,
          markPrice: markPrice,
          lastPrice: lastPrice,
          indexPrice: indexPrice,
          premiumPct: premiumPct,
          volumeUsd: riskVolume,
          quantoMultiplier: quantoMultiplier,
          explanation: _buildExplanation(
            changePct: changePct,
            fundingRate: fundingRate,
            premiumPct: premiumPct,
            volumeUsd: riskVolume,
          ),
        ),
      );
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.take(10).toList();
  }

  static bool _isUsdtPerp(String contract) {
    if (contract.isEmpty) return false;
    if (!contract.endsWith('_USDT')) return false;
    return true;
  }

  static double _scoreCandidate({
    required double changePct,
    required double fundingRate,
    required double volumeUsd,
    required double premiumPct,
  }) {
    final double changeScore = (changePct * 1.6).clamp(0, 45).toDouble();
    final double fundingScore =
        (fundingRate > 0 ? fundingRate * 18000 : 0).clamp(0, 30).toDouble();
    final double premiumScore =
        (premiumPct > 0 ? premiumPct * 8 : 0).clamp(0, 15).toDouble();
    final double volumeScore =
        (_log10Safe(volumeUsd) * 3.8).clamp(0, 10).toDouble();

    return (changeScore + fundingScore + premiumScore + volumeScore)
        .clamp(0, 100)
        .toDouble();
  }

  static String _buildExplanation({
    required double changePct,
    required double fundingRate,
    required double premiumPct,
    required double volumeUsd,
  }) {
    final parts = <String>[];

    if (changePct >= 20) {
      parts.add('24s yükseliş çok sert');
    } else if (changePct >= 10) {
      parts.add('yükseliş güçlü');
    }

    if (fundingRate > 0.0001) {
      parts.add('funding pozitif');
    }

    if (premiumPct > 0.2) {
      parts.add('mark/index primi yüksek');
    }

    if (volumeUsd > 5000000) {
      parts.add('hacim güçlü');
    }

    if (parts.isEmpty) {
      parts.add('short için izlemeye değer');
    }

    return parts.join(', ');
  }

  static double _firstDouble(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      final parsed = _toDouble(value);
      if (parsed != null) return parsed;
    }
    return 0.0;
  }

  static String _string(dynamic v) => v?.toString() ?? '';

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static double _log10Safe(double x) {
    if (x <= 0) return 0;
    return math.log(x) / math.ln10;
  }
}

class ShortCandidate {
  final String contract;
  final double score;
  final double changePct;
  final double fundingRatePct;
  final double markPrice;
  final double lastPrice;
  final double indexPrice;
  final double premiumPct;
  final double volumeUsd;
  final double quantoMultiplier;
  final String explanation;

  const ShortCandidate({
    required this.contract,
    required this.score,
    required this.changePct,
    required this.fundingRatePct,
    required this.markPrice,
    required this.lastPrice,
    required this.indexPrice,
    required this.premiumPct,
    required this.volumeUsd,
    required this.quantoMultiplier,
    required this.explanation,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GateFuturesService _service = GateFuturesService();
  late Future<List<ShortCandidate>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchTopShortCandidates();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _service.fetchTopShortCandidates();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundFrame(
        child: SafeArea(
          child: FutureBuilder<List<ShortCandidate>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Veri alınamadı',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refresh,
                          child: const Text('Tekrar dene'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return Center(
                  child: ElevatedButton(
                    onPressed: _refresh,
                    child: const Text('Liste boş, tekrar dene'),
                  ),
                );
              }

              final top = items.first;

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                  children: [
                    TopHeroCard(candidate: top),
                    const SizedBox(height: 16),
                    ...List.generate(items.length, (index) {
                      final c = items[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: ShortListCard(
                          rank: index + 1,
                          candidate: c,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DetailPage(candidate: c),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class BackgroundFrame extends StatelessWidget {
  final Widget child;

  const BackgroundFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/bg.png',
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.18),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class TopHeroCard extends StatelessWidget {
  final ShortCandidate candidate;

  const TopHeroCard({super.key, required this.candidate});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        image: const DecorationImage(
          image: AssetImage('assets/hero.png'),
          fit: BoxFit.cover,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.22),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 18, 26, 18),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Center(
                child: Text(
                  candidate.score.round().toString(),
                  style: const TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  const Text(
                    'EN GÜÇLÜ SHORT ADAYI',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFFB36B),
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    candidate.contract,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  _heroMetricRow(
                    leftLabel: 'Puan',
                    leftValue: candidate.score.round().toString(),
                    rightLabel: 'Funding',
                    rightValue: _formatPercent(candidate.fundingRatePct),
                  ),
                  const SizedBox(height: 8),
                  _heroMetricRow(
                    leftLabel: 'Değişim',
                    leftValue: _formatPercent(candidate.changePct),
                    rightLabel: 'Premium',
                    rightValue: _formatPercent(candidate.premiumPct),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    candidate.explanation,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFFFFD7C2),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroMetricRow({
    required String leftLabel,
    required String leftValue,
    required String rightLabel,
    required String rightValue,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$leftLabel: ',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                TextSpan(
                  text: leftValue,
                  style: const TextStyle(
                    color: Color(0xFF46F0A6),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$rightLabel: ',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                TextSpan(
                  text: rightValue,
                  style: const TextStyle(
                    color: Color(0xFF46F0A6),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ShortListCard extends StatelessWidget {
  final int rank;
  final ShortCandidate candidate;
  final VoidCallback onTap;

  const ShortListCard({
    super.key,
    required this.rank,
    required this.candidate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF041A3F),
              Color(0xFF00122B),
            ],
          ),
          border: Border.all(
            color: const Color(0xFF35A8FF),
            width: 1.6,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF35A8FF).withOpacity(0.28),
              blurRadius: 16,
              spreadRadius: 1.5,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF153A94),
                  border: Border.all(
                    color: const Color(0xFF56B1FF),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  candidate.contract,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatPercent(candidate.changePct),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF46F0A6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Puan ${candidate.score.round()}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DetailPage extends StatelessWidget {
  final ShortCandidate candidate;

  const DetailPage({super.key, required this.candidate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundFrame(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                alignment: Alignment.centerLeft,
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  candidate.contract,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  _formatPercent(candidate.changePct),
                  style: const TextStyle(
                    fontSize: 30,
                    color: Color(0xFF46F0A6),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 26),
              _infoCard(
                title: 'Long / Short Aşırı Hype Skoru',
                right: '${candidate.score.round()}%',
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: (candidate.score.clamp(0, 100)) / 100,
                      minHeight: 18,
                      borderRadius: BorderRadius.circular(20),
                      backgroundColor: Colors.green.withOpacity(0.45),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFFF5E63),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      candidate.explanation,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _infoCard(
                title: 'Detaylar',
                child: Column(
                  children: [
                    _detailRow('Funding', _formatPercent(candidate.fundingRatePct)),
                    _detailRow('24s Değişim', _formatPercent(candidate.changePct)),
                    _detailRow('Mark Price', _formatPrice(candidate.markPrice)),
                    _detailRow('Last Price', _formatPrice(candidate.lastPrice)),
                    _detailRow('Index Price', _formatPrice(candidate.indexPrice)),
                    _detailRow('Premium', _formatPercent(candidate.premiumPct)),
                    _detailRow('24s Hacim', _formatUsd(candidate.volumeUsd)),
                    _detailRow(
                      'Quanto Multiplier',
                      candidate.quantoMultiplier == 0
                          ? '-'
                          : candidate.quantoMultiplier.toString(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 22,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: const Color(0x55A4000D),
                  border: Border.all(color: const Color(0x99FF6B6B)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'SHORT İÇİN GÜÇLÜ SİNYAL',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        color: Color(0xFFFFB54A),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '${candidate.contract} son 24 saatte sert yükselmiş, funding pozitif ve short squeeze sonrası geri çekilme adayı olabilir.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard({
    required String title,
    String? right,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.black.withOpacity(0.28),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (right != null)
                Text(
                  right,
                  style: const TextStyle(
                    fontSize: 22,
                    color: Color(0xFFFF6B6B),
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatPercent(double value) {
  final sign = value > 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(2)}%';
}

String _formatPrice(double value) {
  if (value == 0) return '-';
  if (value >= 1000) return value.toStringAsFixed(2);
  if (value >= 1) return value.toStringAsFixed(4);
  return value.toStringAsFixed(6);
}

String _formatUsd(double value) {
  if (value >= 1000000000) {
    return '\$${(value / 1000000000).toStringAsFixed(2)}B';
  }
  if (value >= 1000000) {
    return '\$${(value / 1000000).toStringAsFixed(2)}M';
  }
  if (value >= 1000) {
    return '\$${(value / 1000).toStringAsFixed(2)}K';
  }
  return '\$${value.toStringAsFixed(2)}';
}
