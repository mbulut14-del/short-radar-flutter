import 'package:flutter/material.dart';
import 'detail_page_analysis_helpers.dart';

class OiPriceAnalysisCard extends StatelessWidget {
  final String oiDirection;
  final String priceDirection;
  final String oiPriceSignal;
  final String orderFlowDirection;
  final String openInterestDisplay;

  const OiPriceAnalysisCard({
    super.key,
    required this.oiDirection,
    required this.priceDirection,
    required this.oiPriceSignal,
    required this.orderFlowDirection,
    required this.openInterestDisplay,
  });

  @override
  Widget build(BuildContext context) {
    final Color signalColor =
        DetailPageAnalysisHelpers.getSignalColor(oiPriceSignal);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.36),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: signalColor.withOpacity(0.55), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: signalColor.withOpacity(0.10),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'OI + Fiyat Analizi',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                DetailPageAnalysisHelpers.getSignalIcon(oiPriceSignal),
                color: signalColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  DetailPageAnalysisHelpers.getSignalTitle(oiPriceSignal),
                  style: TextStyle(
                    color: signalColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            DetailPageAnalysisHelpers.getSignalDescription(oiPriceSignal),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMiniBadge(
                label: 'OI Yönü',
                value: DetailPageAnalysisHelpers.getOiDirectionLabel(
                  oiDirection: oiDirection,
                  openInterestDisplay: openInterestDisplay,
                ),
                valueColor: DetailPageAnalysisHelpers.getOiColor(
                  oiDirection: oiDirection,
                  openInterestDisplay: openInterestDisplay,
                ),
              ),
              _buildMiniBadge(
                label: 'Fiyat Yönü',
                value: DetailPageAnalysisHelpers.getPriceDirectionLabel(
                  priceDirection,
                ),
                valueColor: DetailPageAnalysisHelpers.getPriceDirectionColor(
                  priceDirection,
                ),
              ),
              _buildMiniBadge(
                label: 'Order Flow',
                value: DetailPageAnalysisHelpers.getOrderFlowLabel(
                  orderFlowDirection,
                ),
                valueColor: DetailPageAnalysisHelpers.getOrderFlowColor(
                  orderFlowDirection,
                ),
              ),
              _buildMiniBadge(
                label: 'Sinyal',
                value: oiPriceSignal.toUpperCase(),
                valueColor: signalColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Durum Değerlendirmesi',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  DetailPageAnalysisHelpers.getMarketStateTitle(
                    oiPriceSignal: oiPriceSignal,
                    orderFlowDirection: orderFlowDirection,
                  ),
                  style: TextStyle(
                    color: signalColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DetailPageAnalysisHelpers.getMarketStateDescription(
                    oiPriceSignal: oiPriceSignal,
                    orderFlowDirection: orderFlowDirection,
                  ),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBadge({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: valueColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
