import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drink_water_app/core/widgets/app_form_fields.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: SizedBox(width: 320, child: child))),
);

void main() {
  group('AppTextField', () {
    testWidgets('renders label above the field and forwards input config', (
      tester,
    ) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        _host(
          AppTextField(
            key: const Key('probeField'),
            controller: controller,
            label: '手机号',
            hintText: '请输入手机号',
            keyboardType: TextInputType.phone,
            maxLength: 11,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ),
      );

      expect(find.text('手机号'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, TextInputType.phone);
      expect(field.maxLength, 11);
      expect(field.inputFormatters, hasLength(1));
    });

    testWidgets('keeps the same corner radius in every border state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          AppTextField(controller: TextEditingController(), label: 'Token'),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      final decoration = field.decoration!;
      for (final border in <InputBorder?>[
        decoration.border,
        decoration.enabledBorder,
        decoration.focusedBorder,
      ]) {
        expect(
          border,
          isA<OutlineInputBorder>(),
          reason: 'all border states must share one shape',
        );
        expect(
          (border! as OutlineInputBorder).borderRadius,
          BorderRadius.circular(AppTextField.cornerRadius),
        );
      }
      expect(decoration.counterText, '');
    });

    testWidgets('filters non-digits when digitsOnly is supplied', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        _host(
          AppTextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 6,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'a1b2');
      await tester.pump();
      expect(controller.text, '12');
    });
  });

  group('AppPrimaryButton', () {
    testWidgets('shows a spinner and refuses taps while loading', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          AppPrimaryButton(
            onPressed: () => taps++,
            loading: true,
            child: const Text('获取验证码'),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
      await tester.tap(find.byType(FilledButton));
      expect(taps, 0);
    });

    testWidgets('is full width and tappable when idle', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          AppPrimaryButton(
            onPressed: () => taps++,
            child: const Text('登录'),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.byType(FilledButton));
      expect(taps, 1);
      final size = tester.getSize(find.byType(AppPrimaryButton));
      expect(size.width, 320);
      expect(size.height, 56);
    });
  });
}
