import '../models/spend_tag.dart';

class Categorization {
  const Categorization({
    required this.categoryId,
    required this.tag,
    this.isTransfer = false,
  });

  final String categoryId;
  final SpendTag tag;
  final bool isTransfer;
}

class TransactionCategorizer {
  const TransactionCategorizer();

  static const _rules = <_Rule>[
    _Rule(
      ['perkėlim', 'pavedimas tarp', 'internal transfer', 'to revolut', 'from revolut', 'to wise', 'from wise', 'own account', 'savo sąskait'],
      'transfers',
      SpendTag.essential,
      transfer: true,
    ),
    _Rule(
      ['algal', 'salary', 'darbo užmok', 'payroll', 'atlyginim'],
      'income',
      SpendTag.essential,
    ),
    _Rule(
      ['nuoma', 'rent', 'būsto paskola', 'busto paskola', 'hipotek', 'swedbank lizing', 'citadele lizing'],
      'housing',
      SpendTag.essential,
    ),
    _Rule(
      ['ignitis', 'eso', 'vilniaus vandenys', 'šilumos tinklai', 'silumos', 'energijos skirstymo', 'elektra', 'dujos', 'water'],
      'utilities',
      SpendTag.essential,
    ),
    _Rule(
      ['telia', 'bitė', 'bite', 'tele2', 'cgates', 'internet'],
      'utilities',
      SpendTag.essential,
    ),
    _Rule(
      ['maxima', 'iki', 'rimi', 'lidl', 'norfa', 'express market', 'barbora', 'lastmile'],
      'groceries',
      SpendTag.essential,
    ),
    _Rule(
      ['wolt', 'bolt food', 'can can', 'can can pizza', 'mc donald', 'mcdonald', 'hesburger', 'kfc', 'pizza', 'sushi', 'restoran', 'kavinė', 'kavine', 'cafe', 'baras', 'pub '],
      'dining',
      SpendTag.optional,
    ),
    _Rule(
      ['circle k', 'viada', 'neste', 'orlen', 'emsi', 'degalin', 'bolt', 'citybee', 'spark', 'trafik', 'autobus', 'traukini', 'ltg link'],
      'transport',
      SpendTag.essential,
    ),
    _Rule(
      ['gintaras', 'gintarine', 'eurovaist', 'camelia', 'benu', 'polis', 'gydytoj', 'odontolog', 'klinik'],
      'health',
      SpendTag.essential,
    ),
    _Rule(
      ['darželis', 'darzelis', 'mokykl', 'vaik', 'pampers', 'ikea'],
      'family',
      SpendTag.essential,
    ),
    _Rule(
      ['zara', 'h&m', 'reserved', 'about you', 'zalando', 'sports direct', 'decathlon'],
      'clothes',
      SpendTag.optional,
    ),
    _Rule(
      ['netflix', 'spotify', 'disney', 'youtube', 'apple.com/bill', 'icloud', 'google one', 'chatgpt', 'openai', 'hbo', 'prime video'],
      'subscriptions',
      SpendTag.optional,
    ),
    _Rule(
      ['cinema', 'forum cinemas', 'multikino', 'steam', 'playstation', 'nintendo', 'concert', 'bilietai', 'kakava', 'ticket'],
      'leisure',
      SpendTag.optional,
    ),
    _Rule(
      ['ryanair', 'wizz', 'airbnb', 'booking.com', 'hotel', 'apgyvendin', 'kelion'],
      'travel',
      SpendTag.optional,
    ),
  ];

  Categorization categorize({
    required String description,
    required String merchant,
    required double amount,
  }) {
    if (amount > 0) {
      final hay = _hay(description, merchant);
      if (_looksLikeTransfer(hay)) {
        return const Categorization(
          categoryId: 'transfers',
          tag: SpendTag.essential,
          isTransfer: true,
        );
      }
      return const Categorization(
        categoryId: 'income',
        tag: SpendTag.essential,
      );
    }

    final hay = _hay(description, merchant);
    if (_looksLikeTransfer(hay)) {
      return const Categorization(
        categoryId: 'transfers',
        tag: SpendTag.essential,
        isTransfer: true,
      );
    }

    for (final rule in _rules) {
      if (rule.matches(hay)) {
        return Categorization(
          categoryId: rule.categoryId,
          tag: rule.tag,
          isTransfer: rule.transfer,
        );
      }
    }

    return const Categorization(
      categoryId: 'other',
      tag: SpendTag.optional,
    );
  }

  bool _looksLikeTransfer(String hay) {
    return hay.contains('perkėlim') ||
        hay.contains('pavedimas tarp') ||
        hay.contains('internal') ||
        hay.contains('to revolut') ||
        hay.contains('from revolut') ||
        hay.contains('to wise') ||
        hay.contains('from wise') ||
        hay.contains('savo sąskait') ||
        hay.contains('own account');
  }

  String _hay(String description, String merchant) {
    return '${description.toLowerCase()} ${merchant.toLowerCase()}';
  }
}

class _Rule {
  const _Rule(this.needles, this.categoryId, this.tag, {this.transfer = false});

  final List<String> needles;
  final String categoryId;
  final SpendTag tag;
  final bool transfer;

  bool matches(String hay) => needles.any((n) => hay.contains(n));
}
