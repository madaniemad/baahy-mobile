import 'package:baahy_customer/core/utils/arabic_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeArabic', () {
    test('unifies alef forms', () {
      expect(normalizeArabic('أجدابيا'), normalizeArabic('اجدابيا'));
      expect(normalizeArabic('إبراهيم'), 'ابراهيم');
      expect(normalizeArabic('آمن'), 'امن');
      expect(normalizeArabic('ٱلله'), 'الله');
    });

    test('teh marbuta, alef maksura, hamza carriers', () {
      expect(normalizeArabic('مصراتة'), normalizeArabic('مصراته'));
      expect(normalizeArabic('مصطفى'), 'مصطفي');
      expect(normalizeArabic('مؤمن'), 'مومن');
      expect(normalizeArabic('رئيس'), 'رييس');
    });

    test('strips tashkeel and tatweel', () {
      expect(normalizeArabic('مُحَمَّد'), 'محمد');
      expect(normalizeArabic('بـــاهي'), 'باهي');
    });

    test('maps Arabic-Indic digits', () {
      expect(normalizeArabic('٠١٢٣٤٥٦٧٨٩'), '0123456789');
      expect(normalizeArabic('شارع ١٢'), 'شارع 12');
    });

    test('lower-cases, trims and collapses spaces', () {
      expect(normalizeArabic('  Ajdabiya   CITY '), 'ajdabiya city');
      expect(normalizeArabic(''), '');
    });
  });

  group('matchesArabic', () {
    test('finds across alef variants', () {
      expect(matchesArabic('أجدابيا', 'اجدابيا'), isTrue);
      expect(matchesArabic('اجدابيا', 'أجدابيا'), isTrue);
    });

    test('finds across teh marbuta', () {
      expect(matchesArabic('مصراتة', 'مصراته'), isTrue);
      expect(matchesArabic('مصراته', 'مصراتة'), isTrue);
    });

    test('ignores tashkeel in either side', () {
      expect(matchesArabic('مُصْرَاتَة', 'مصراته'), isTrue);
    });

    test('digits match across scripts', () {
      expect(matchesArabic('Store 12', '١٢'), isTrue);
    });

    test('Latin is case-insensitive', () {
      expect(matchesArabic('Ajdabiya', 'ajda'), isTrue);
    });

    test('empty needle matches everything', () {
      expect(matchesArabic('طرابلس', ''), isTrue);
      expect(matchesArabic('', ''), isTrue);
      expect(matchesArabic('طرابلس', '   '), isTrue);
    });

    test('non-matching text is rejected', () {
      expect(matchesArabic('طرابلس', 'بنغازي'), isFalse);
    });
  });
}
