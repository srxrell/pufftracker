import 'dart:convert';
import 'dart:io';
import 'package:untitled/services/locale_service.dart';

enum ImageSearchSource {
  all('All', 'Все'),
  bingCdn('Bing CDN', 'Bing CDN'),
  transparentPng('Transparent PNG', 'PNG без фона'),
  vapeShops('Device Catalog', 'Vape Каталог'),
  webPhotos('Web Photos', 'Web Фото');

  final String labelEn;
  final String labelRu;
  const ImageSearchSource(this.labelEn, this.labelRu);

  String get label => tr(labelEn, labelRu);
}

class ImageSearchService {
  static final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 6)
    ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;

  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  static const List<String> _blockedPatterns = [
    'favicon',
    'logo',
    'collidu.com',
    'eleapsoftware.com',
    'canva.com',
    'graphicsfamily.com',
    'wallstreetmojo.com',
    'transferpricingsolutions',
    'facebook_sharing',
    'avatar',
    'sprite',
  ];

  static const Map<String, String> _ruBrandDictionary = {
    'вака': 'waka sopro',
    'гик бар': 'geek bar pulse',
    'гикбар': 'geek bar pulse',
    'лост мэри': 'lost mary',
    'лост мари': 'lost mary',
    'лостмери': 'lost mary',
    'элф бар': 'elf bar',
    'эльф бар': 'elf bar',
    'эльфбар': 'elf bar',
    'элфбар': 'elf bar',
    'чарон': 'smoant charon baby',
    'шарон': 'smoant charon baby',
    'пасито': 'smoant pasito',
    'найт 80': 'smoant knight 80',
    'найт': 'smoant knight 80',
    'смоант': 'smoant',
    'иксрос': 'vaporesso xros',
    'хрос': 'vaporesso xros',
    'вапорессо': 'vaporesso xros',
    'аегис': 'geekvape aegis',
    'аэгис': 'geekvape aegis',
    'гиквейп': 'geekvape aegis',
    'драг': 'voopoo drag',
    'вупу': 'voopoo',
    'возол': 'vozol gear',
    'миникан': 'brusko minican',
    'бруско': 'brusko minican',
    'инфлейв': 'inflave',
    'инфлэйв': 'inflave',
    'хаски': 'husky',
    'плонк': 'plonq',
    'удно': 'udn bar',
    'юдно': 'udn bar',
    'ашкьюди': 'hqd cuvie',
    'чапман': 'chapman',
    'манго': 'mango',
    'вишня': 'cherry',
    'яблоко': 'apple',
    'арбуз': 'watermelon',
    'клубника': 'strawberry',
    'виноград': 'grape',
    'мята': 'mint',
    'холодок': 'ice',
    'энергетик': 'energy',
    'черника': 'blueberry',
    'персик': 'peach',
  };

  /// Normalizes Russian slang/brand queries into search-friendly terms
  static String normalizeQuery(String raw) {
    String q = raw.trim().toLowerCase();
    if (q.isEmpty) return '';

    for (final entry in _ruBrandDictionary.entries) {
      if (q.contains(entry.key)) {
        q = q.replaceAll(entry.key, entry.value);
      }
    }

    // Remove generic filler words that trigger search engine adult blocks
    q = q
        .replaceAll(RegExp(r'\b(ашка|ашки|вейп|под|сигареты)\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return q.isEmpty ? raw.trim() : q;
  }

  static bool _isValidImageUrl(String url) {
    if (!url.startsWith('http://') && !url.startsWith('https://')) return false;
    final lower = url.toLowerCase();
    for (final b in _blockedPatterns) {
      if (lower.contains(b)) return false;
    }
    return true;
  }

  static Future<List<String>> searchVapeImages(
    String query, {
    ImageSearchSource source = ImageSearchSource.all,
  }) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];

    final norm = normalizeQuery(clean);
    final results = <String>[];

    void addUnique(Iterable<String> urls) {
      for (final u in urls) {
        if (_isValidImageUrl(u) && !results.contains(u)) {
          results.add(u);
        }
      }
    }

    if (source == ImageSearchSource.bingCdn) {
      addUnique(await _fetchBingAsync(norm, transparent: false, preferCdnThumb: true));
      if (norm != clean) {
        addUnique(await _fetchBingAsync(clean, transparent: false, preferCdnThumb: true));
      }
      return results;
    }

    if (source == ImageSearchSource.transparentPng) {
      addUnique(await _fetchBingAsync(norm, transparent: true, preferCdnThumb: true));
      addUnique(await _fetchBingAsync('$norm png', transparent: true, preferCdnThumb: false));
      return results;
    }

    if (source == ImageSearchSource.vapeShops) {
      final shopFutures = await Future.wait([
        _fetchShopifyStore('https://ca.wakavaping.com', norm),
        _fetchShopifyStore('https://www.vapevol.com', norm),
        _fetchWordPressMedia('https://escovape.com', norm),
        _fetchWordPressMedia('https://vapeobservation.com', norm),
        _fetchWordPressMedia('https://touchvapes.com', norm),
      ]);
      for (final list in shopFutures) {
        addUnique(list);
      }
      if (results.length < 6) {
        addUnique(await _fetchBingAsync('$norm pod kit product', transparent: false, preferCdnThumb: true));
      }
      return results;
    }

    if (source == ImageSearchSource.webPhotos) {
      final webFutures = await Future.wait([
        _fetchBingAsync('$norm device photo', transparent: false, preferCdnThumb: false, firstOffset: 0),
        _fetchBingAsync(norm, transparent: false, preferCdnThumb: true, firstOffset: 15),
        _fetchDuckDuckGo(norm),
      ]);
      for (final list in webFutures) {
        addUnique(list);
      }
      return results;
    }

    // Default: ImageSearchSource.all -> query multiple sources in parallel and interleave!
    final parallelLists = await Future.wait([
      _fetchBingAsync(norm, transparent: true, preferCdnThumb: true),
      _fetchShopifyStore('https://ca.wakavaping.com', norm),
      _fetchShopifyStore('https://www.vapevol.com', norm),
      _fetchBingAsync(norm, transparent: false, preferCdnThumb: true),
      _fetchWordPressMedia('https://escovape.com', norm),
      _fetchWordPressMedia('https://vapeobservation.com', norm),
      _fetchBingAsync(norm, transparent: false, preferCdnThumb: false),
    ]);

    // Interleave results from different sources so the user sees diverse images first
    int maxLen = 0;
    for (final l in parallelLists) {
      if (l.length > maxLen) maxLen = l.length;
    }
    for (int i = 0; i < maxLen; i++) {
      for (final l in parallelLists) {
        if (i < l.length) {
          addUnique([l[i]]);
        }
      }
    }

    return results.take(35).toList();
  }

  /// Source 1 & 2: Bing `/images/async` endpoint (extracts both Microsoft CDN `turl` and direct `murl`)
  static Future<List<String>> _fetchBingAsync(
    String query, {
    required bool transparent,
    required bool preferCdnThumb,
    int firstOffset = 0,
  }) async {
    try {
      final encoded = Uri.encodeComponent(query);
      var urlStr =
          'https://www.bing.com/images/async?q=$encoded&first=$firstOffset&count=25&adlt=off';
      if (transparent) {
        urlStr += '&qft=+filterui:photo-transparent';
      }

      final request = await _client.getUrl(Uri.parse(urlStr));
      request.headers.set('User-Agent', _userAgent);
      request.headers.set('Accept-Language', 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7');
      request.headers.set('Cookie', 'SRCHHPGUSR=ADLT=OFF;');

      final response = await request.close().timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return [];
      final body = await response.transform(utf8.decoder).join();

      // Match URLs inside &quot;turl&quot;:&quot;...&quot; and &quot;murl&quot;:&quot;...&quot;
      // Properly handles &amp; inside query strings!
      final turlRegex = RegExp(r'turl&quot;:&quot;(https?://(?:[^&]|&amp;)+?)&quot;');
      final murlRegex = RegExp(r'murl&quot;:&quot;(https?://(?:[^&]|&amp;)+?)&quot;');

      final turls = <String>[];
      for (final m in turlRegex.allMatches(body)) {
        final raw = m.group(1)?.replaceAll('&amp;', '&');
        if (raw != null && _isValidImageUrl(raw) && !turls.contains(raw)) {
          turls.add(raw);
        }
      }

      final murls = <String>[];
      for (final m in murlRegex.allMatches(body)) {
        final raw = m.group(1)?.replaceAll('&amp;', '&');
        if (raw != null && _isValidImageUrl(raw) && !murls.contains(raw)) {
          murls.add(raw);
        }
      }

      final combined = <String>[];
      if (preferCdnThumb) {
        combined.addAll(turls);
        combined.addAll(murls);
      } else {
        combined.addAll(murls);
        combined.addAll(turls);
      }
      return combined;
    } catch (_) {
      return [];
    }
  }

  /// Source 3: Shopify Vape Store JSON Catalog API (`/search/suggest.json`)
  static Future<List<String>> _fetchShopifyStore(String baseUrl, String query) async {
    try {
      final encoded = Uri.encodeComponent(query);
      final uri = Uri.parse(
        '$baseUrl/search/suggest.json?q=$encoded&resources[type]=product&resources[limit]=10',
      );
      final request = await _client.getUrl(uri);
      request.headers.set('User-Agent', _userAgent);
      request.headers.set('Accept', 'application/json');

      final response = await request.close().timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return [];
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);

      final products = decoded['resources']?['results']?['products'];
      if (products is! List) return [];

      final list = <String>[];
      for (final p in products) {
        if (p is Map) {
          String? img = p['image']?.toString() ?? p['featured_image']?['url']?.toString();
          if (img != null && img.isNotEmpty) {
            if (img.startsWith('//')) img = 'https:$img';
            if (_isValidImageUrl(img) && !list.contains(img)) {
              list.add(img);
            }
          }
        }
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Source 4: WooCommerce / WordPress Vape Store Media REST API (`/wp-json/wp/v2/media`)
  static Future<List<String>> _fetchWordPressMedia(String baseUrl, String query) async {
    try {
      final encoded = Uri.encodeComponent(query);
      final uri = Uri.parse('$baseUrl/wp-json/wp/v2/media?search=$encoded&per_page=10');
      final request = await _client.getUrl(uri);
      request.headers.set('User-Agent', _userAgent);
      request.headers.set('Accept', 'application/json');

      final response = await request.close().timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return [];
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is! List) return [];

      final list = <String>[];
      for (final item in decoded) {
        if (item is Map) {
          final url = item['source_url']?.toString() ??
              item['media_details']?['sizes']?['medium']?['source_url']?.toString();
          if (url != null && _isValidImageUrl(url) && !list.contains(url)) {
            list.add(url);
          }
        }
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Source 5: DuckDuckGo Image API (`vqd` token + `i.js`)
  static Future<List<String>> _fetchDuckDuckGo(String query) async {
    try {
      final encoded = Uri.encodeComponent(query);
      final tokenUri = Uri.parse('https://duckduckgo.com/?q=$encoded&kp=-2&iax=images&ia=images');
      final tokenReq = await _client.getUrl(tokenUri);
      tokenReq.headers.set('User-Agent', _userAgent);
      tokenReq.headers.set('Cookie', 'p=-2');
      final tokenRes = await tokenReq.close().timeout(const Duration(seconds: 5));
      if (tokenRes.statusCode != 200) return [];
      final tokenHtml = await tokenRes.transform(utf8.decoder).join();

      final vqdMatch = RegExp(r'''vqd=['"]?([0-9-]+)['"]?''').firstMatch(tokenHtml);
      final vqd = vqdMatch?.group(1);
      if (vqd == null || vqd.isEmpty) return [];

      final imgUri = Uri.parse(
        'https://duckduckgo.com/i.js?l=wt-wt&o=json&q=$encoded&vqd=$vqd&f=,,,&p=-2',
      );
      final imgReq = await _client.getUrl(imgUri);
      imgReq.headers.set('User-Agent', _userAgent);
      imgReq.headers.set('Referer', 'https://duckduckgo.com/');
      imgReq.headers.set('Cookie', 'p=-2');
      final imgRes = await imgReq.close().timeout(const Duration(seconds: 5));
      if (imgRes.statusCode != 200) return [];
      final imgBody = await imgRes.transform(utf8.decoder).join();
      final decoded = jsonDecode(imgBody);
      final results = decoded['results'];
      if (results is! List) return [];

      final list = <String>[];
      for (final r in results) {
        if (r is Map) {
          final thumb = r['thumbnail']?.toString();
          final img = r['image']?.toString();
          if (thumb != null && _isValidImageUrl(thumb) && !list.contains(thumb)) {
            list.add(thumb);
          }
          if (img != null && _isValidImageUrl(img) && !list.contains(img)) {
            list.add(img);
          }
        }
      }
      return list;
    } catch (_) {
      return [];
    }
  }
}
