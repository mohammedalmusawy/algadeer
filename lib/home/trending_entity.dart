/// كيان مرتّب حسب الطلب/الاستخدام داخل تطبيق الغدير.
class TrendingEntity {
  const TrendingEntity({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.kind,
    this.imageUrl,
    this.demandScore = 0,
    this.profileViews = 0,
    this.callTaps = 0,
    this.whatsappTaps = 0,
  });

  final String id;
  final String title;
  final String subtitle;
  final String kind; // doctor | lab
  final String? imageUrl;
  final int demandScore;
  final int profileViews;
  final int callTaps;
  final int whatsappTaps;

  /// وزن بسيط: مشاهدة + تفاعل اتصال/واتساب أقوى.
  static int score({
    required int views,
    required int calls,
    required int whatsapp,
  }) {
    return views + (calls * 3) + (whatsapp * 3);
  }
}
