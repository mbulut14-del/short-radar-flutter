
import 'package:flutter/material.dart';
import '../models/short_setup_result.dart';

class SetupStatusCard extends StatelessWidget {
  final ShortSetupResult setup;

  const SetupStatusCard({
    super.key,
    required this.setup,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (setup.status) {
      case 'Güçlü':
        statusColor = Colors.redAccent;
        break;
      case 'Orta':
        statusColor = Colors.orangeAccent;
        break;
      default:
        statusColor = Colors.amberAccent;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.36),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'SETUP DURUMU',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: statusColor.withOpacity(0.55),
                  ),
                ),
                child: Text(
                  setup.status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'RR: ${setup.rr.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.orangeAccent,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            setup.summary,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
