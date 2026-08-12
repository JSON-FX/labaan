import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labaan/core/data/models.dart';
import 'package:labaan/features/system/credit_topup_sheet.dart';

void main() {
  test('PayMongo top-ups are limited to web and direct Android', () {
    expect(
      paymongoTopupPlatform(isWeb: true, targetPlatform: TargetPlatform.iOS),
      CreditPackPlatform.web,
    );
    expect(
      paymongoTopupPlatform(
        isWeb: false,
        targetPlatform: TargetPlatform.android,
      ),
      CreditPackPlatform.androidDirect,
    );
    expect(
      paymongoTopupPlatform(isWeb: false, targetPlatform: TargetPlatform.iOS),
      isNull,
    );
  });

  test('Android return URLs stay inside the allow-listed app-link route', () {
    final urls = TopupReturnUrls.forPlatform(CreditPackPlatform.androidDirect);

    expect(
      urls.success.toString(),
      'labaan://payment/success?purpose=credit_topup',
    );
    expect(
      urls.cancel.toString(),
      'labaan://payment/cancel?purpose=credit_topup',
    );
  });

  test('web return URLs preserve the deployment origin', () {
    final urls = TopupReturnUrls.forPlatform(
      CreditPackPlatform.web,
      webBase: Uri.parse('https://play.labaan.example/app'),
    );

    expect(
      urls.success.toString(),
      'https://play.labaan.example/wallet?topupResult=pending',
    );
    expect(
      urls.cancel.toString(),
      'https://play.labaan.example/wallet?topupResult=cancelled',
    );
  });
}
