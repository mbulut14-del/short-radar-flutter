import 'package:flutter/material.dart';
import 'detail_page_analysis_helpers.dart';

class OiPriceAnalysisCard extends StatelessWidget {
  final String oiDirection;
  final String priceDirection;
  final String oiPriceSignal;
  final String orderFlowDirection;
  final String openInterestDisplay;
  final double? finalScore;

  const OiPriceAnalysisCard({
    super.key,
    required this.oiDirection,
    required this.priceDirection,
    required this.oiPriceSignal,
    required this.orderFlowDirection,
    required this.openInterestDisplay,
    this.finalScore,
  });

  bool get _isLowConfidence => finalScore != null && finalScore! < 40;
  bool get _isMediumConfidence =>
      finalScore != null && finalScore! >= 40 && finalScore! < 70;

  String _buildDisplayTitle() {
    if (_isLowConfidence) {
      switch (oiPriceSignal.toUpperCase()) {
        case 'EARLY_DISTRIBUTION':
          return 'Dağılım İhtimali';
        case 'FAKE_PUMP':
          return 'Pump Zayıflama İhtimali';
        case 'STRONG_SHORT':
          return 'Short Baskı İşaretleri';
        case 'WEAK_DROP':
          return 'Zayıflama İşaretleri';
        case 'SHORT_SQUEEZE':
          return 'Squeeze Riski';
        case 'EARLY_ACCUMULATION':
          return 'Toparlanma İhtimali';
        default:
          return 'Kararsız / Gözlem';
      }
    }

    if (_isMediumConfidence) {
      switch (oiPriceSignal.toUpperCase()) {
        case 'EARLY_DISTRIBUTION':
          return 'Erken Dağılım İşareti';
        case 'FAKE_PUMP':
          return 'Pump Zayıflıyor';
        default:
          return DetailPageAnalysisHelpers.getSignalTitle(oiPriceSignal);
      }
    }

    return DetailPageAnalysisHelpers.getSignalTitle(oiPriceSignal);
  }

  String _buildDisplayDescription() {
    if (_isLowConfidence) {
      switch (oiPriceSignal.toUpperCase()) {
        case 'EARLY_DISTRIBUTION':
          return 'OI ve fiyat henüz net yön üretmiyor. Satış baskısı öne çıkmaya başlamış olabilir.';
        case 'FAKE_PUMP':
          return 'Pump sonrası zayıflama işaretleri var, ancak merkezi skor henüz aktif short kalitesi vermiyor.';
        case 'STRONG_SHORT':
          return 'Short tarafını destekleyen bazı işaretler var, fakat henüz tam teyit oluşmuş değil.';
        case 'WEAK_DROP':
          return 'Kısa vadede zayıflama görülüyor, ancak bu aşamada daha çok gözlem yapmak sağlıklı olur.';
        case 'SHORT_SQUEEZE':
          return 'Yukarı yönlü sıkışma riski dikkat çekiyor. Short tarafında temkinli olunmalı.';
        case 'EARLY_ACCUMULATION':
          return 'Toparlanma ihtimali short tarafı için net avantaj oluşturmuyor.';
        default:
          return 'Şu an net bir baskı ya da güçlü fırsat görünmüyor.';
      }
    }

    if (_isMediumConfidence) {
      switch (oiPriceSignal.toUpperCase()) {
        case 'EARLY_DISTRIBUTION':
          return 'Satış baskısı erken aşamada öne çıkıyor. Kurulum gelişebilir ama teyit henüz sınırlı.';
        case 'FAKE_PUMP':
          return 'Pump sonrası zayıflama artıyor olabilir. Takip edilmeli.';
        default:
          return DetailPageAnalysisHelpers.getSignalDescription(oiPriceSignal);
      }
    }

    return DetailPageAnalysisHelpers.getSignalDescription(oiPriceSignal);
  }

  String _buildMarketStateTitle() {
    if (_isLowConfidence) {
      switch (oiPriceSignal.toUpperCase()) {
        case 'EARLY_DISTRIBUTION':
          return 'İlk dağılım işaretleri';
        case 'FAKE_PUMP':
          return 'Pump sonrası zayıflama';
        case 'STRONG_SHORT':
          return 'Short lehine işaretler';
        case 'WEAK_DROP':
          return 'Sınırlı zayıflama';
        case 'SHORT_SQUEEZE':
          return 'Yukarı risk baskın';
        default:
          return 'Net baskı yok';
      }
    }

    if (_isMediumConfidence) {
      switch (oiPriceSignal.toUpperCase()) {
        case 'EARLY_DISTRIBUTION':
          return 'Erken dağılım işareti';
        case 'FAKE_PUMP':
          return 'Pump zayıflıyor';
        default:
          return DetailPageAnalysisHelpers.getMarketStateTitle(
            oiPriceSignal: oiPriceSignal,
            orderFlowDirection: orderFlowDirection,
          );
      }
    }

    return DetailPageAnalysisHelpers.getMarketStateTitle(
      oiPriceSignal: oiPriceSignal,
      orderFlowDirection: orderFlowDirection,
    );
  }

  String _buildMarketStateDescription() {
    if (_isLowConfidence) {
      switch (oiPriceSignal.toUpperCase()) {
        case 'EARLY_DISTRIBUTION':
          return 'Fiyat ve OI hâlâ net yön üretmiyor. Satış tarafı erken üstünlük kuruyor olabilir, ancak bu aşamada yalnızca gözlem olarak değerlendirilmelidir.';
        case 'FAKE_PUMP':
          return 'Pump yapısı tam güçlenememiş görünüyor. Buna rağmen aktif short kurulumu için daha fazla teyit gerekir.';
        case 'STRONG_SHORT':
          return 'Bazı short lehine işaretler olsa da merkezi skor henüz güçlü işlem kalitesi vermiyor.';
        case 'WEAK_DROP':
          return 'Zayıflama mevcut ama tek başına işlem kararı için yeterli güçte değil.';
        case 'SHORT_SQUEEZE':
          return 'Alıcı baskısı short tarafı için risk oluşturabilir. Bu yüzden temkinli olmak gerekir.';
        default:
          return 'Pozisyon akışı ve fiyat ilişkisi henüz güçlü bir avantaj üretmiyor.';
      }
    }

    if (_isMediumConfidence) {
      switch (oiPriceSignal.toUpperCase()) {
        case 'EARLY_DISTRIBUTION':
          return 'Satış baskısı erken aşamada hissediliyor. İzlenmeli, ancak tam giriş teyidi olarak görülmemeli.';
        case 'FAKE_PUMP':
          return 'Pump sonrası güç kaybı var. Kurulum ilerlerse daha net short fırsatı oluşabilir.';
        default:
          return DetailPageAnalysisHelpers.getMarketStateDescription(
            oiPriceSignal: oiPriceSignal,
            orderFlowDirection: orderFlowDirection,
          );
      }
    }

    return DetailPageAnalysisHelpers.getMarketStateDescription(
      oiPriceSignal: oiPriceSignal,
      orderFlowDirection: orderFlowDirection,
    );
  }

  String _buildSectionTitle() {
    if (_isLowConfidence) return 'OI + Fiyat Gözlemi';
    if (_isMediumConfidence) return 'OI + Fiyat Erken Sinyal Analizi';
    return 'OI + Fiyat Analizi';
  }

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
          Text(
            _buildSectionTitle(),
            style: const TextStyle(
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
                  _buildDisplayTitle(),
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
            _buildDisplayDescription(),
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
                Text(
                  _isLowConfidence ? 'Gözlem Notu' : 'Durum Değerlendirmesi',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _buildMarketStateTitle(),
                  style: TextStyle(
                    color: signalColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _buildMarketStateDescription(),
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
