import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/models/entity_social_links.dart';

void main() {
  group('EntitySocialLinks', () {
    test('hasAny false when empty', () {
      expect(EntitySocialLinks.empty.hasAny, isFalse);
      expect(EntitySocialLinks.empty.channels, isEmpty);
    });

    test('channel order is website then social platforms', () {
      const links = EntitySocialLinks(
        website: 'ghadeer.iq',
        telegram: 'ghadeer_clinic',
        instagram: '@ghadeer',
        facebook: 'ghadeer.page',
        tiktok: 'ghadeer',
      );
      expect(
        links.channels.map((c) => c.id).toList(),
        ['website', 'instagram', 'facebook', 'tiktok', 'telegram'],
      );
      expect(links.channels.first.titleAr, 'الموقع الإلكتروني');
      expect(links.channels.first.launchUrl, 'https://ghadeer.iq');
      expect(links.channels[1].launchUrl, contains('instagram.com/ghadeer'));
    });

    test('fromMap tolerates missing columns including website', () {
      final links = EntitySocialLinks.fromMap({'phone': '1'});
      expect(links.hasAny, isFalse);
      expect(links.website, isEmpty);
    });

    test('resolveWebsite adds https when missing', () {
      expect(
        EntitySocialLinks.resolveWebsite('example.com'),
        'https://example.com',
      );
      expect(
        EntitySocialLinks.resolveWebsite('https://example.com'),
        'https://example.com',
      );
    });

    test('keeps full http urls', () {
      expect(
        EntitySocialLinks.resolveFacebook('https://facebook.com/page'),
        'https://facebook.com/page',
      );
    });

    test('toDbMap includes website_url first among social keys', () {
      const links = EntitySocialLinks(website: 'a.com', instagram: '@a');
      final map = links.toDbMap();
      expect(map['website_url'], 'a.com');
      expect(map['instagram_url'], '@a');
      expect(map.keys.first, 'website_url');
    });
  });
}
