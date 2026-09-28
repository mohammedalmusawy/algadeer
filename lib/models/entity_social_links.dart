import 'package:url_launcher/url_launcher.dart';

/// روابط مواقع التواصل + الموقع الإلكتروني — اختيارية؛ الفارغ لا يظهر في الورقة.
/// الترتيب الثابت: موقع إلكتروني → إنستغرام → فيسبوك → تيك توك → تليجرام.
class EntitySocialLinks {
  const EntitySocialLinks({
    this.website = '',
    this.instagram = '',
    this.facebook = '',
    this.tiktok = '',
    this.telegram = '',
  });

  final String website;
  final String instagram;
  final String facebook;
  final String tiktok;
  final String telegram;

  static const empty = EntitySocialLinks();

  static const dbColumns = <String>[
    'website_url',
    'instagram_url',
    'facebook_url',
    'tiktok_url',
    'telegram_url',
  ];

  bool get hasAny =>
      website.trim().isNotEmpty ||
      instagram.trim().isNotEmpty ||
      facebook.trim().isNotEmpty ||
      tiktok.trim().isNotEmpty ||
      telegram.trim().isNotEmpty;

  List<EntitySocialChannel> get channels {
    final out = <EntitySocialChannel>[];
    if (website.trim().isNotEmpty) {
      out.add(
        EntitySocialChannel(
          id: 'website',
          titleAr: 'الموقع الإلكتروني',
          launchUrl: resolveWebsite(website),
        ),
      );
    }
    if (instagram.trim().isNotEmpty) {
      out.add(
        EntitySocialChannel(
          id: 'instagram',
          titleAr: 'إنستغرام',
          launchUrl: resolveInstagram(instagram),
        ),
      );
    }
    if (facebook.trim().isNotEmpty) {
      out.add(
        EntitySocialChannel(
          id: 'facebook',
          titleAr: 'فيسبوك',
          launchUrl: resolveFacebook(facebook),
        ),
      );
    }
    if (tiktok.trim().isNotEmpty) {
      out.add(
        EntitySocialChannel(
          id: 'tiktok',
          titleAr: 'تيك توك',
          launchUrl: resolveTikTok(tiktok),
        ),
      );
    }
    if (telegram.trim().isNotEmpty) {
      out.add(
        EntitySocialChannel(
          id: 'telegram',
          titleAr: 'تليجرام',
          launchUrl: resolveTelegram(telegram),
        ),
      );
    }
    return out;
  }

  factory EntitySocialLinks.fromMap(Map<String, dynamic>? data) {
    if (data == null) return empty;
    return EntitySocialLinks(
      website: data['website_url']?.toString() ?? '',
      instagram: data['instagram_url']?.toString() ?? '',
      facebook: data['facebook_url']?.toString() ?? '',
      tiktok: data['tiktok_url']?.toString() ?? '',
      telegram: data['telegram_url']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toDbMap() => {
        'website_url': website.trim(),
        'instagram_url': instagram.trim(),
        'facebook_url': facebook.trim(),
        'tiktok_url': tiktok.trim(),
        'telegram_url': telegram.trim(),
      };

  EntitySocialLinks copyWith({
    String? website,
    String? instagram,
    String? facebook,
    String? tiktok,
    String? telegram,
  }) {
    return EntitySocialLinks(
      website: website ?? this.website,
      instagram: instagram ?? this.instagram,
      facebook: facebook ?? this.facebook,
      tiktok: tiktok ?? this.tiktok,
      telegram: telegram ?? this.telegram,
    );
  }

  static String resolveWebsite(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    if (_isHttp(t)) return t;
    return 'https://$t';
  }

  static String resolveInstagram(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    if (_isHttp(t)) return t;
    final handle = t.replaceFirst(RegExp(r'^@'), '');
    return 'https://instagram.com/$handle';
  }

  static String resolveFacebook(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    if (_isHttp(t)) return t;
    return 'https://facebook.com/${t.replaceFirst(RegExp(r'^@'), '')}';
  }

  static String resolveTikTok(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    if (_isHttp(t)) return t;
    var handle = t.replaceFirst(RegExp(r'^@'), '');
    return 'https://www.tiktok.com/@$handle';
  }

  static String resolveTelegram(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    if (_isHttp(t)) return t;
    if (t.startsWith('t.me/')) return 'https://$t';
    return 'https://t.me/${t.replaceFirst(RegExp(r'^@'), '')}';
  }

  static bool _isHttp(String t) =>
      t.startsWith('http://') || t.startsWith('https://');

  static Future<void> launch(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class EntitySocialChannel {
  const EntitySocialChannel({
    required this.id,
    required this.titleAr,
    required this.launchUrl,
  });

  final String id;
  final String titleAr;
  final String launchUrl;
}
