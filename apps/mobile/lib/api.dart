import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class WalletAsset {
  WalletAsset.fromJson(Map<String, dynamic> json)
    : symbol = json['symbol'] as String,
      name = json['name'] as String,
      amount = json['amount'] as String,
      idrValue = json['idrValue'] as int;

  final String symbol;
  final String name;
  final String amount;
  final int idrValue;
}

class Wallet {
  Wallet.fromJson(Map<String, dynamic> json)
    : mode = json['mode'] as String,
      totalIdr = json['totalIdr'] as int,
      assets = (json['assets'] as List)
          .map((item) => WalletAsset.fromJson(item as Map<String, dynamic>))
          .toList();

  final String mode;
  final int totalIdr;
  final List<WalletAsset> assets;

  bool get isSimulation => mode != 'live';
}

class PaymentOption {
  PaymentOption.fromJson(Map<String, dynamic> json)
    : asset = json['asset'] as String,
      name = json['name'] as String,
      amount = json['amount'] as String,
      rate = json['rate'] as int,
      sufficient = json['sufficient'] as bool,
      blocked = json['blocked'] as String?;

  final String asset;
  final String name;
  final String amount;
  final int rate;
  final bool sufficient;

  /// Why this asset cannot be sent right now, or null when it can.
  final String? blocked;

  bool get payable => blocked == null && sufficient;
}

class Quote {
  Quote.fromJson(Map<String, dynamic> json, this.qr)
    : needsAmount = json['needsAmount'] as bool,
      quoteId = json['quoteId'] as String?,
      merchantName = json['merchantName'] as String,
      merchantCity = json['merchantCity'] as String,
      amountIdr = json['amountIdr'] as int?,
      asset = json['asset'] as String?,
      assetAmount = json['assetAmount'] as String?,
      rate = json['rate'] as int?,
      sufficient = json['sufficient'] as bool? ?? false,
      blocked = json['blocked'] as String?,
      options = ((json['options'] as List?) ?? const [])
          .map((item) => PaymentOption.fromJson(item as Map<String, dynamic>))
          .toList(),
      expiresAt = json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
      minIdr = json['minIdr'] as int?,
      maxIdr = json['maxIdr'] as int?;

  final String qr;
  final bool needsAmount;
  final String? quoteId;
  final String merchantName;
  final String merchantCity;
  final int? amountIdr;
  final String? asset;
  final String? assetAmount;
  final int? rate;
  final bool sufficient;
  final String? blocked;
  final List<PaymentOption> options;
  final DateTime? expiresAt;
  final int? minIdr;
  final int? maxIdr;
}

class Order {
  Order.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      status = json['status'] as String,
      merchantName = json['merchantName'] as String,
      merchantCity = json['merchantCity'] as String,
      amountIdr = json['amountIdr'] as int,
      asset = json['asset'] as String,
      assetAmount = json['assetAmount'] as String,
      feeIdr = json['feeIdr'] as int,
      failureReason = json['failureReason'] as String?,
      mode = json['mode'] as String? ?? 'SIMULATE',
      txId = (json['transfer'] as Map<String, dynamic>?)?['txId'] as String?,
      withdrawId =
          (json['transfer'] as Map<String, dynamic>?)?['withdrawId'] as String?,
      createdAt = DateTime.parse(json['createdAt'] as String),
      completedAt = json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String);

  final String id;
  final String status;
  final String merchantName;
  final String merchantCity;
  final int amountIdr;
  final String asset;
  final String assetAmount;
  final int feeIdr;
  final String? failureReason;
  final String mode;

  /// Exchange transfer reference, the payer's proof the asset left the wallet.
  final String? txId;
  final String? withdrawId;
  final DateTime createdAt;
  final DateTime? completedAt;

  bool get isSuccess => status == 'SUCCESS';
  bool get isFailed => status == 'FAILED' || status == 'NEEDS_REVIEW';
}

class Api {
  Api._();
  static final instance = Api._();

  static const _base = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://192.168.118.247:3000',
  );

  final _client = http.Client();

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(const Duration(seconds: 12));
    } on SocketException {
      throw ApiException('Server tidak terjangkau');
    } on TimeoutException {
      throw ApiException('Server terlalu lama merespons');
    } on http.ClientException {
      throw ApiException('Server tidak terjangkau');
    }

    final dynamic body = response.body.isEmpty
        ? null
        : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) return body;

    final message = body is Map ? body['message'] : null;
    throw ApiException(message is String ? message : 'Terjadi kesalahan');
  }

  Future<dynamic> _get(String path) =>
      _send(() => _client.get(Uri.parse('$_base$path')));

  Future<dynamic> _post(String path, Map<String, dynamic> body) => _send(
    () => _client.post(
      Uri.parse('$_base$path'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(body),
    ),
  );

  Future<Wallet> wallet() async =>
      Wallet.fromJson(await _get('/wallet') as Map<String, dynamic>);

  Future<List<Order>> orders() async => (await _get('/orders') as List)
      .map((item) => Order.fromJson(item as Map<String, dynamic>))
      .toList();

  Future<Order> order(String id) async =>
      Order.fromJson(await _get('/orders/$id') as Map<String, dynamic>);

  Future<Quote> quote(String qr, {int? amountIdr, String? asset}) async {
    final json = await _post('/quotes', {
      'qr': qr,
      'amountIdr': ?amountIdr,
      'asset': ?asset,
    });
    return Quote.fromJson(json as Map<String, dynamic>, qr);
  }

  Future<Order> pay(String quoteId) async => Order.fromJson(
    await _post('/orders', {'quoteId': quoteId}) as Map<String, dynamic>,
  );

  Future<String> sampleQr() async =>
      (await _get('/dev/sample-qr') as Map<String, dynamic>)['qr'] as String;
}
