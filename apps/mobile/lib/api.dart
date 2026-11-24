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

class RemitBank {
  RemitBank.fromJson(Map<String, dynamic> json)
    : code = json['code'] as String,
      name = json['name'] as String;

  final String code;
  final String name;
}

class RemitSample {
  RemitSample.fromJson(Map<String, dynamic> json)
    : bank = json['bank'] as String,
      account = json['account'] as String,
      name = json['name'] as String;

  final String bank;
  final String account;
  final String name;
}

class Corridor {
  Corridor.fromJson(Map<String, dynamic> json)
    : code = json['code'] as String,
      country = json['country'] as String,
      currency = json['currency'] as String,
      type = json['type'] as String,
      typeLabel = json['typeLabel'] as String,
      rail = json['rail'] as String,
      reason = json['reason'] as String,
      partner = json['partner'] as String,
      volume2025 = json['volume2025'] as int? ?? 0,
      banks = ((json['banks'] as List?) ?? const [])
          .map((item) => RemitBank.fromJson(item as Map<String, dynamic>))
          .toList(),
      samples = ((json['samples'] as List?) ?? const [])
          .map((item) => RemitSample.fromJson(item as Map<String, dynamic>))
          .toList(),
      funding = {
        for (final entry
            in ((json['funding'] as Map<String, dynamic>?) ?? const {}).entries)
          entry.key: (entry.value as List).cast<String>(),
      };

  final String code;
  final String country;
  final String currency;
  final String type;
  final String typeLabel;
  final String rail;
  final String reason;
  final String partner;
  final int volume2025;
  final List<RemitBank> banks;
  final List<RemitSample> samples;
  final Map<String, List<String>> funding;
}

class RemitCatalog {
  RemitCatalog.fromJson(Map<String, dynamic> json)
    : mode = json['mode'] as String,
      corridors = (json['corridors'] as List)
          .map((item) => Corridor.fromJson(item as Map<String, dynamic>))
          .toList(),
      idBanks = ((json['indonesia'] as Map<String, dynamic>)['banks'] as List)
          .map((item) => RemitBank.fromJson(item as Map<String, dynamic>))
          .toList(),
      idSamples =
          ((json['indonesia'] as Map<String, dynamic>)['samples'] as List)
              .map((item) => RemitSample.fromJson(item as Map<String, dynamic>))
              .toList();

  final String mode;
  final List<Corridor> corridors;
  final List<RemitBank> idBanks;
  final List<RemitSample> idSamples;

  bool get isSimulation => mode != 'live';
}

class RemitStep {
  RemitStep.fromJson(Map<String, dynamic> json)
    : status = json['status'] as String,
      label = json['label'] as String,
      detail = json['detail'] as String,
      real = json['real'] as bool;

  final String status;
  final String label;
  final String detail;

  /// Moves real value in live mode; every other step is simulated.
  final bool real;
}

class RemitParty {
  RemitParty.fromJson(Map<String, dynamic> json)
    : name = json['name'] as String,
      country = json['country'] as String,
      bankName = json['bankName'] as String?,
      account = json['account'] as String?;

  final String name;
  final String country;
  final String? bankName;
  final String? account;
}

class PriceLine {
  PriceLine.fromJson(Map<String, dynamic> json)
    : label = json['label'] as String,
      value = json['value'] as String;

  final String label;
  final String value;
}

class RemitQuote {
  RemitQuote.fromJson(Map<String, dynamic> json)
    : quoteId = json['quoteId'] as String,
      direction = json['direction'] as String,
      fundingCurrency = json['fundingCurrency'] as String,
      sendAmount = json['sendAmount'] as String,
      usdcAmount = json['usdcAmount'] as String,
      receiveAmount = json['receiveAmount'] as String,
      receiveCurrency = json['receiveCurrency'] as String,
      rate = (json['pricing'] as Map<String, dynamic>)['rate'] as String,
      lines = ((json['pricing'] as Map<String, dynamic>)['lines'] as List)
          .map((item) => PriceLine.fromJson(item as Map<String, dynamic>))
          .toList(),
      assumptions =
          ((json['pricing'] as Map<String, dynamic>)['assumptions'] as List)
              .cast<String>(),
      sender = RemitParty.fromJson(json['sender'] as Map<String, dynamic>),
      recipient = RemitParty.fromJson(
        json['recipient'] as Map<String, dynamic>,
      ),
      steps = (json['steps'] as List)
          .map((item) => RemitStep.fromJson(item as Map<String, dynamic>))
          .toList(),
      blocked = json['blocked'] as String?,
      expiresAt = DateTime.parse(json['expiresAt'] as String),
      ttlSeconds = json['ttlSeconds'] as int;

  final String quoteId;
  final String direction;
  final String fundingCurrency;
  final String sendAmount;
  final String usdcAmount;
  final String receiveAmount;
  final String receiveCurrency;
  final String rate;
  final List<PriceLine> lines;
  final List<String> assumptions;
  final RemitParty sender;
  final RemitParty recipient;
  final List<RemitStep> steps;
  final String? blocked;
  final DateTime expiresAt;
  final int ttlSeconds;
}

class Remittance {
  Remittance.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      mode = json['mode'] as String,
      direction = json['direction'] as String,
      status = json['status'] as String,
      country =
          (json['corridor'] as Map<String, dynamic>?)?['country'] as String? ??
          '',
      fundingCurrency = json['fundingCurrency'] as String,
      sendAmount = json['sendAmount'] as String,
      usdcAmount = json['usdcAmount'] as String,
      receiveAmount = json['receiveAmount'] as String,
      receiveCurrency = json['receiveCurrency'] as String,
      sender = RemitParty.fromJson(json['sender'] as Map<String, dynamic>),
      recipient = RemitParty.fromJson(
        json['recipient'] as Map<String, dynamic>,
      ),
      steps = ((json['steps'] as List?) ?? const [])
          .map((item) => RemitStep.fromJson(item as Map<String, dynamic>))
          .toList(),
      txId = (json['transfer'] as Map<String, dynamic>?)?['txId'] as String?,
      payoutReference = json['payoutReference'] as String?,
      failureReason = json['failureReason'] as String?,
      createdAt = DateTime.parse(json['createdAt'] as String),
      completedAt = json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String);

  final String id;
  final String mode;
  final String direction;
  final String status;
  final String country;
  final String fundingCurrency;
  final String sendAmount;
  final String usdcAmount;
  final String receiveAmount;
  final String receiveCurrency;
  final RemitParty sender;
  final RemitParty recipient;
  final List<RemitStep> steps;
  final String? txId;
  final String? payoutReference;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime? completedAt;

  bool get isSuccess => status == 'SUCCESS';
  bool get isFailed => status == 'FAILED' || status == 'NEEDS_REVIEW';
  bool get inbound => direction == 'INBOUND';
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

  Future<RemitCatalog> remitCatalog() async => RemitCatalog.fromJson(
    await _get('/remit/catalog') as Map<String, dynamic>,
  );

  Future<RemitQuote> remitQuote({
    required String direction,
    required String corridor,
    required String fundingCurrency,
    required num amount,
    required String senderName,
    required String bank,
    required String account,
  }) async => RemitQuote.fromJson(
    await _post('/remit/quotes', {
          'direction': direction,
          'corridor': corridor,
          'fundingCurrency': fundingCurrency,
          'amount': amount,
          'senderName': senderName,
          'bank': bank,
          'account': account,
        })
        as Map<String, dynamic>,
  );

  Future<Remittance> remitSend(String quoteId) async => Remittance.fromJson(
    await _post('/remit/transfers', {'quoteId': quoteId})
        as Map<String, dynamic>,
  );

  Future<Remittance> remittance(String id) async => Remittance.fromJson(
    await _get('/remit/transfers/$id') as Map<String, dynamic>,
  );

  Future<String> sampleQr() async =>
      (await _get('/dev/sample-qr') as Map<String, dynamic>)['qr'] as String;
}
