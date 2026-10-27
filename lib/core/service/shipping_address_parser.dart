import 'shipping_address_region_data.dart';

enum ShippingAddressFieldConfidence { empty, inferred, confirmed }

class ShippingAddressParseResult {
  const ShippingAddressParseResult({
    this.recipientName = '',
    this.phoneNumber = '',
    this.region = '',
    this.detailedAddress = '',
    this.fieldConfidence = const {},
  });

  final String recipientName;
  final String phoneNumber;
  final String region;
  final String detailedAddress;
  final Map<String, ShippingAddressFieldConfidence> fieldConfidence;

  bool get hasAnyValue =>
      recipientName.isNotEmpty ||
      phoneNumber.isNotEmpty ||
      region.isNotEmpty ||
      detailedAddress.isNotEmpty;

  Map<String, String> toFieldValues() => {
    'recipient_name': recipientName,
    'phone_number': phoneNumber,
    'region': region,
    'detailed_address': detailedAddress,
  };
}

abstract final class ShippingAddressParser {
  static final _phone = RegExp(
    r'(?<!\d)(?:\+?86[\s-]?)?(1[3-9]\d)[\s-]?(\d{4})[\s-]?(\d{4})(?!\d)',
  );
  static final _label = RegExp(
    r'(收件人|收货人|联系人|姓名|手机号码|手机号|联系电话|电话|所在地区|地区|详细地址|地址)\s*[：:]',
  );
  static final _byCode = {
    for (final division in ShippingAddressRegionData.all)
      division.code: division,
  };
  static final _aliases = _buildAliases();

  static ShippingAddressParseResult parse(String source) {
    final text = _normalize(source);
    if (text.isEmpty) return const ShippingAddressParseResult();

    final labels = _parseLabels(text);
    final phoneMatch = _phone.firstMatch(text);
    final phone = labels['phone_number'] ?? _phoneValue(phoneMatch);
    var remainder = text;
    for (final value in labels.values) {
      remainder = _removeOnce(remainder, value);
    }
    if (phoneMatch != null) {
      remainder = _removeOnce(remainder, phoneMatch.group(0)!);
    }
    remainder = _normalize(remainder.replaceAll(_label, ' '));

    final labeledRegion = labels['region'] ?? '';
    final labeledDetail = labels['detailed_address'] ?? '';
    final regionSource = labeledDetail.isEmpty ? remainder : labeledDetail;
    final resolved = labeledRegion.isNotEmpty
        ? _RegionResolution(labeledRegion, regionSource)
        : _resolveRegion(regionSource);

    var recipient = labels['recipient_name'] ?? '';
    var detail = resolved.remaining;
    if (recipient.isEmpty &&
        labeledDetail.isEmpty &&
        resolved.region.isNotEmpty) {
      recipient = _inferRecipient(detail);
      if (recipient.isNotEmpty) {
        detail = _normalize(_removeOnce(detail, recipient));
      }
    }
    if (labeledDetail.isEmpty && resolved.region.isEmpty) detail = remainder;

    return ShippingAddressParseResult(
      recipientName: recipient,
      phoneNumber: phone,
      region: resolved.region,
      detailedAddress: detail,
      fieldConfidence: {
        'recipient_name': _confidence(
          recipient,
          labels.containsKey('recipient_name'),
        ),
        'phone_number': _confidence(phone, labels.containsKey('phone_number')),
        'region': _confidence(resolved.region, labeledRegion.isNotEmpty),
        'detailed_address': _confidence(detail, labeledDetail.isNotEmpty),
      },
    );
  }

  static ShippingAddressFieldConfidence _confidence(
    String value,
    bool labeled,
  ) {
    if (value.isEmpty) return ShippingAddressFieldConfidence.empty;
    return labeled
        ? ShippingAddressFieldConfidence.confirmed
        : ShippingAddressFieldConfidence.inferred;
  }

  static String _normalize(String text) => text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(RegExp(r'[\t\n\u00a0\u3000]+'), ' ')
      .replaceAll(RegExp(r'[,，;；|、]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static Map<String, String> _parseLabels(String text) {
    final matches = _label.allMatches(text).toList();
    final values = <String, String>{};
    for (var index = 0; index < matches.length; index++) {
      final match = matches[index];
      final end = index + 1 < matches.length
          ? matches[index + 1].start
          : text.length;
      final value = _normalize(text.substring(match.end, end));
      if (value.isEmpty) continue;
      final label = match.group(1)!;
      if (label == '收件人' || label == '收货人' || label == '联系人' || label == '姓名') {
        values['recipient_name'] = value;
      } else if (label.contains('手机') || label.contains('电话')) {
        final phone = _phoneValue(_phone.firstMatch(value));
        if (phone.isNotEmpty) values['phone_number'] = phone;
      } else if (label == '所在地区' || label == '地区') {
        values['region'] = value;
      } else {
        values['detailed_address'] = value;
      }
    }
    return values;
  }

  static _RegionResolution _resolveRegion(String source) {
    final matches = <String, List<_RegionMatch>>{};
    for (final alias in _aliases) {
      var start = source.indexOf(alias.name);
      while (start >= 0) {
        matches
            .putIfAbsent(alias.division.code, () => [])
            .add(
              _RegionMatch(
                alias.division,
                start,
                start + alias.name.length,
                alias.name == alias.division.name,
              ),
            );
        start = source.indexOf(alias.name, start + alias.name.length);
      }
    }
    if (matches.isEmpty) return _RegionResolution('', source);

    final candidates = <_RegionCandidate>[];
    for (final county in ShippingAddressRegionData.all.where(
      (item) => item.level == 2,
    )) {
      final countyMatches = matches[county.code];
      if (countyMatches == null) continue;
      final city = _byCode[county.parentCode]!;
      final province = _byCode[city.parentCode]!;
      final cities = _placeholderCity(city)
          ? const <_RegionMatch?>[null]
          : <_RegionMatch?>[...?matches[city.code], null];
      final provinces = <_RegionMatch?>[...?matches[province.code], null];
      for (final countyMatch in countyMatches) {
        for (final cityMatch in cities) {
          for (final provinceMatch in provinces) {
            candidates.add(
              _RegionCandidate(province, city, county, [
                ?provinceMatch,
                ?cityMatch,
                countyMatch,
              ]),
            );
          }
        }
      }
    }
    for (final city in ShippingAddressRegionData.all.where(
      (item) => item.level == 1 && !_placeholderCity(item),
    )) {
      final cityMatches = matches[city.code];
      if (cityMatches == null) continue;
      final province = _byCode[city.parentCode]!;
      for (final cityMatch in cityMatches) {
        for (final provinceMatch in <_RegionMatch?>[
          ...?matches[province.code],
          null,
        ]) {
          candidates.add(
            _RegionCandidate(province, city, null, [?provinceMatch, cityMatch]),
          );
        }
      }
    }
    for (final province in ShippingAddressRegionData.all.where(
      (item) => item.level == 0,
    )) {
      for (final match in matches[province.code] ?? const <_RegionMatch>[]) {
        candidates.add(_RegionCandidate(province, null, null, [match]));
      }
    }

    candidates.sort((left, right) => right.score.compareTo(left.score));
    final best = candidates.first;
    _RegionCandidate? second;
    for (final candidate in candidates.skip(1)) {
      if (candidate.region != best.region) {
        second = candidate;
        break;
      }
    }
    if (best.score < 55 || (second != null && best.score - second.score < 8)) {
      return _RegionResolution('', source);
    }
    return _RegionResolution(best.region, _removeMatches(source, best.matches));
  }

  static List<_RegionAlias> _buildAliases() {
    final result = <_RegionAlias>[];
    for (final division in ShippingAddressRegionData.all) {
      final names = <String>{division.name, ..._aliasesFor(division.name)};
      for (final name in names) {
        if (name.length >= 2 && !_genericAliases.contains(name)) {
          result.add(_RegionAlias(division, name));
        }
      }
    }
    result.sort((left, right) => right.name.length.compareTo(left.name.length));
    return result;
  }

  static Iterable<String> _aliasesFor(String name) sync* {
    for (final suffix in _suffixes) {
      if (name.endsWith(suffix) && name.length > suffix.length + 1) {
        yield name.substring(0, name.length - suffix.length);
      }
    }
    for (final entry in _autonomousAliases.entries) {
      if (name.startsWith(entry.key)) yield entry.value;
    }
    final ethnic = name.indexOf('族');
    if (ethnic >= 2) yield name.substring(0, ethnic - 1);
  }

  static String _removeMatches(String source, List<_RegionMatch> matches) {
    final sorted = [...matches]
      ..sort((left, right) => right.start.compareTo(left.start));
    var result = source;
    var removedBefore = result.length;
    for (final match in sorted) {
      if (match.end > removedBefore) continue;
      result = result.replaceRange(match.start, match.end, ' ');
      removedBefore = match.start;
    }
    return _normalize(result);
  }

  static String _inferRecipient(String source) {
    final value = source.split(' ').first;
    return RegExp(r'^[\u4e00-\u9fff·]{2,8}$').hasMatch(value) ? value : '';
  }

  static String _phoneValue(RegExpMatch? match) =>
      match == null ? '' : match.group(1)! + match.group(2)! + match.group(3)!;

  static String _removeOnce(String source, String value) {
    final start = source.indexOf(value);
    return start < 0
        ? source
        : source.replaceRange(start, start + value.length, ' ');
  }

  static bool _placeholderCity(ShippingAddressAdministrativeDivision item) =>
      item.name == '市辖区' || item.name == '县';

  static const _genericAliases = {'市辖', '自治', '特别行政'};
  static const _suffixes = [
    '特别行政区',
    '维吾尔自治区',
    '壮族自治区',
    '回族自治区',
    '自治区',
    '自治州',
    '自治县',
    '自治旗',
    '林区',
    '特区',
    '地区',
    '省',
    '市',
    '区',
    '县',
    '旗',
    '盟',
  ];
  static const _autonomousAliases = {
    '内蒙古自治区': '内蒙古',
    '广西壮族自治区': '广西',
    '西藏自治区': '西藏',
    '宁夏回族自治区': '宁夏',
    '新疆维吾尔自治区': '新疆',
    '香港特别行政区': '香港',
    '澳门特别行政区': '澳门',
  };
}

class _RegionAlias {
  const _RegionAlias(this.division, this.name);
  final ShippingAddressAdministrativeDivision division;
  final String name;
}

class _RegionMatch {
  const _RegionMatch(this.division, this.start, this.end, this.formal);
  final ShippingAddressAdministrativeDivision division;
  final int start;
  final int end;
  final bool formal;
}

class _RegionCandidate {
  const _RegionCandidate(this.province, this.city, this.county, this.matches);
  final ShippingAddressAdministrativeDivision province;
  final ShippingAddressAdministrativeDivision? city;
  final ShippingAddressAdministrativeDivision? county;
  final List<_RegionMatch> matches;

  String get region => [
    province.name,
    if (city != null && city!.name != '市辖区' && city!.name != '县') city!.name,
    if (county != null) county!.name,
  ].join();

  int get score {
    var result = 0;
    for (final match in matches) {
      result += switch (match.division.level) {
        0 => 20,
        1 => 24,
        _ => 28,
      };
      result += match.end - match.start;
      if (match.formal) result += 2;
    }
    final ordered = [...matches]
      ..sort((left, right) => left.start.compareTo(right.start));
    for (var index = 1; index < ordered.length; index++) {
      if (ordered[index - 1].end <= ordered[index].start) {
        result += 10;
        if (ordered[index].start - ordered[index - 1].end > 18) result -= 4;
      } else {
        result -= 14;
      }
    }
    return result;
  }
}

class _RegionResolution {
  const _RegionResolution(this.region, this.remaining);
  final String region;
  final String remaining;
}

abstract final class ShippingAddressTextBuilder {
  static const _fields = <(String, String)>[
    ('recipient_name', '收件人'),
    ('phone_number', '手机号码'),
    ('region', '所在地区'),
    ('detailed_address', '详细地址'),
  ];

  static String build(Map<String, String?> values) => _fields
      .map((field) => '${field.$2}：${values[field.$1]?.trim() ?? ''}')
      .join('\n');
}
