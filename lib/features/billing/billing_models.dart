class BillingCredentials {
  const BillingCredentials(this.accessKey, this.secretKey);
  final String accessKey;
  final String secretKey;
  bool get isComplete => accessKey.isNotEmpty && secretKey.isNotEmpty;
}

/// Exact decimal arithmetic; billing amounts must not be added as doubles.
class BillingAmount {
  BillingAmount._(this.units, this.scale);
  final BigInt units;
  final int scale;

  factory BillingAmount.parse(Object? value) {
    if (value is! String ||
        !RegExp(r'^-?\d{1,30}(\.\d{1,18})?$').hasMatch(value)) {
      throw const FormatException('Invalid billing amount');
    }
    final parts = value.split('.');
    return BillingAmount._(
      BigInt.parse(parts.join()),
      parts.length == 2 ? parts[1].length : 0,
    );
  }

  static final zero = BillingAmount._(BigInt.zero, 0);

  BillingAmount operator +(BillingAmount other) {
    final digits = scale > other.scale ? scale : other.scale;
    final ten = BigInt.from(10);
    return BillingAmount._(
      units * ten.pow(digits - scale) +
          other.units * ten.pow(digits - other.scale),
      digits,
    );
  }

  @override
  String toString() {
    final digits = units.abs().toString().padLeft(scale + 1, '0');
    final whole = digits.substring(0, digits.length - scale);
    final fraction = digits
        .substring(digits.length - scale)
        .replaceFirst(RegExp(r'0+$'), '')
        .padRight(2, '0');
    return '${units.isNegative ? '-' : ''}$whole.$fraction';
  }
}

class BillingBalance {
  BillingBalance.fromJson(Map<String, dynamic> json)
    : available = BillingAmount.parse(json['AvailableBalance']),
      cash = BillingAmount.parse(json['CashBalance']),
      arrears = BillingAmount.parse(json['ArrearsBalance']),
      currency = billingCurrency(json['Currency']);
  final BillingAmount available;
  final BillingAmount cash;
  final BillingAmount arrears;
  final String currency;
}

String billingCurrency(Object? value) {
  if (value is! String || !RegExp(r'^[A-Z]{3}$').hasMatch(value)) {
    throw const FormatException('Missing billing currency');
  }
  return value;
}

class BillingRow {
  BillingRow.fromJson(Map<String, dynamic> json)
    : product = (json['ProductZh'] ?? json['Product'] ?? '未命名产品').toString(),
      category = (json['BillCategory'] ?? json['BillCategoryParent'] ?? '')
          .toString(),
      payable = BillingAmount.parse(json['PayableAmount']),
      paid = BillingAmount.parse(json['PaidAmount']),
      unpaid = BillingAmount.parse(json['UnpaidAmount']),
      currency = billingCurrency(json['Currency']);
  final String product;
  final String category;
  final BillingAmount payable;
  final BillingAmount paid;
  final BillingAmount unpaid;
  final String currency;
}

class BillingPage {
  const BillingPage({
    required this.rows,
    required this.total,
    required this.offset,
    required this.limit,
    this.hasWarning = false,
  });
  final List<BillingRow> rows;
  final int total;
  final int offset;
  final int limit;
  final bool hasWarning;
  int get nextOffset => offset + limit;
  bool get hasMore =>
      total >= 0 ? offset + rows.length < total : rows.length == limit;
}

class BillingException implements Exception {
  const BillingException(this.message);
  final String message;
  @override
  String toString() => message;
}
