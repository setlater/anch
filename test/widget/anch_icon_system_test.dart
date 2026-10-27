import 'package:anch/core/theme/anch_colors.dart';
import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/theme/anch_theme.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('15 类资料只通过统一语义映射取得已确认图标', () {
    expect(AnchIcons.forTypeKey('id_card'), same(AnchIcons.idCard));
    expect(
      AnchIcons.forTypeKey('household_book'),
      same(AnchIcons.householdBook),
    );
    expect(AnchIcons.forTypeKey('passport'), same(AnchIcons.passport));
    expect(AnchIcons.forTypeKey('hk_macao_pass'), same(AnchIcons.hkMacaoPass));
    expect(
      AnchIcons.forTypeKey('driver_license'),
      same(AnchIcons.driverLicense),
    );
    expect(
      AnchIcons.forTypeKey('vehicle_license'),
      same(AnchIcons.vehicleLicense),
    );
    expect(
      AnchIcons.forTypeKey('birth_certificate'),
      same(AnchIcons.birthCertificate),
    );
    expect(
      AnchIcons.forTypeKey('marriage_certificate'),
      same(AnchIcons.marriageCertificate),
    );
    expect(AnchIcons.forTypeKey('debit_card'), same(AnchIcons.debitCard));
    expect(AnchIcons.forTypeKey('credit_card'), same(AnchIcons.creditCard));
    expect(AnchIcons.forTypeKey('insurance'), same(AnchIcons.insurance));
    expect(
      AnchIcons.forTypeKey('property_certificate'),
      same(AnchIcons.propertyCertificate),
    );
    expect(
      AnchIcons.forTypeKey('education_certificate'),
      same(AnchIcons.educationCertificate),
    );
    expect(AnchIcons.forTypeKey('generic'), same(AnchIcons.generic));
    expect(
      AnchIcons.forTypeKey('shipping_address'),
      same(AnchIcons.shippingAddress),
    );
    expect(
      AnchIcons.shippingAddress.assetPath,
      endsWith('map-point-bold-duotone.svg'),
    );
    expect(AnchIcons.forTypeKey('unknown'), same(AnchIcons.generic));
  });

  test('底部导航统一提供默认与选中变体', () {
    for (final icon in <AnchNavigationIconData>[
      AnchIcons.homeNavigation,
      AnchIcons.memberNavigation,
      AnchIcons.documentNavigation,
      AnchIcons.settingsNavigation,
    ]) {
      expect(icon.normal, isNot(same(icon.selected)));
    }
  });

  test('设置导航使用同一 Solar 简洁图形的 Linear 与 Bold 变体', () {
    expect(
      AnchIcons.settingsNavigation.normal.assetPath,
      endsWith('settings-minimalistic-linear.svg'),
    );
    expect(
      AnchIcons.settingsNavigation.selected.assetPath,
      endsWith('settings-minimalistic-bold.svg'),
    );
  });

  test('添加操作使用不带圆环的 Solar 派生线性加号', () {
    expect(AnchIcons.add.assetPath, endsWith('add-linear.svg'));
  });

  testWidgets('Solar 图标在亮暗主题和不同宽度下稳定消费语义颜色', (tester) async {
    for (final theme in <ThemeData>[AnchTheme.light, AnchTheme.dark]) {
      for (final width in <double>[320, 390, 720]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (context) => SizedBox(
                width: width,
                child: Wrap(
                  children: [
                    for (final icon in AnchIcons.allTypeIcons)
                      AnchIcon(
                        icon,
                        size: 32,
                        color: context.anchColors.textSecondary,
                      ),
                    AnchIcon(
                      AnchIcons.search,
                      size: 24,
                      color: context.anchColors.accent,
                    ),
                    AnchIcon(
                      AnchIcons.warning,
                      size: 20,
                      color: context.anchColors.warning,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byType(AnchIcon),
          findsNWidgets(AnchIcons.allTypeIcons.length + 2),
        );
        expect(tester.getSize(find.byType(AnchIcon).first), const Size(32, 32));
        expect(tester.takeException(), isNull);
      }
    }
  });
}
