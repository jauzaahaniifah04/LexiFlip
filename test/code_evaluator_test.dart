import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/code_auto_indent_formatter.dart';
import 'package:flutter_application_1/code_evaluator.dart';

void main() {
  const expected = 'for (int i = 0; i < 5; i++) {\n  cout << i;\n}';

  group('evaluateCppAnswer', () {
    test('accepts standard indentation', () {
      final result = evaluateCppAnswer(expected, expected);
      expect(result.isCorrect, isTrue);
    });

    test('accepts missing indentation and changed operator spacing', () {
      const answer = 'for (int i = 0; i<5; i++){\ncout <<i;\n}';
      final result = evaluateCppAnswer(answer, expected);
      expect(result.isCorrect, isTrue);
    });

    test('rejects changed operators or numbers', () {
      expect(
        evaluateCppAnswer(
          'for (int i = 0; i <= 5; i++) { cout << i; }',
          expected,
        ).isCorrect,
        isFalse,
      );
      expect(
        evaluateCppAnswer(
          'for (int i = 0; i < 4; i++) { cout << i; }',
          expected,
        ).isCorrect,
        isFalse,
      );
    });

    test('rejects incomplete delimiters with helpful feedback', () {
      final result = evaluateCppAnswer(
        'for (int i = 0; i < 5; i++) {\n  cout << i;',
        expected,
      );
      expect(result.isCorrect, isFalse);
      expect(result.feedback, contains('Kurung belum lengkap'));
    });

    test('keeps string literal contents significant', () {
      final result = evaluateCppAnswer(
        'if (nilai >= 75) { cout << "Lulus"; }',
        'if (nilai >= 75) { cout << "Lu lus"; }',
      );
      expect(result.isCorrect, isFalse);
    });

    test('accepts the reported if answer with changed whitespace', () {
      const answer = 'if (nilai>=75) {\ncout<<"Lulus";\n}';
      const ifKey = 'if (nilai >= 75) {\n  cout << "Lulus";\n}';
      final result = evaluateCppAnswer(answer, ifKey);
      expect(result.isCorrect, isTrue, reason: result.feedback);
    });

    test('rejects a wrong condition operator in the reported if answer', () {
      const answer = 'if (nilai > 75) {\ncout<<"Lulus";\n}';
      const ifKey = 'if (nilai >= 75) {\n  cout << "Lulus";\n}';
      expect(evaluateCppAnswer(answer, ifKey).isCorrect, isFalse);
    });

    test('rejects a different output string in the reported if answer', () {
      const answer = 'if (nilai>=75) {\ncout<<"Tidak Lulus";\n}';
      const ifKey = 'if (nilai >= 75) {\n  cout << "Lulus";\n}';
      expect(evaluateCppAnswer(answer, ifKey).isCorrect, isFalse);
    });

    test('rejects a missing closing brace in the reported if answer', () {
      const answer = 'if (nilai>=75) {\ncout<<"Lulus";\n';
      const ifKey = 'if (nilai >= 75) {\n  cout << "Lulus";\n}';
      final result = evaluateCppAnswer(answer, ifKey);
      expect(result.isCorrect, isFalse);
      expect(result.feedback, contains('Kurung belum lengkap'));
    });

    test('ignores comments but preserves code tokens', () {
      final result = evaluateCppAnswer(
        'for (int i = 0; i < 5; i++) { // loop\n cout << i; }',
        expected,
      );
      expect(result.isCorrect, isTrue);
    });
  });

  group('CodeAutoIndentFormatter', () {
    const formatter = CodeAutoIndentFormatter();

    test('indents the next line after an opening brace', () {
      const code = 'for (int i = 0; i < 5; i++) {';
      final oldValue = TextEditingValue(
        text: code,
        selection: TextSelection.collapsed(offset: code.length),
      );
      final newValue = TextEditingValue(
        text: '$code\n',
        selection: TextSelection.collapsed(offset: code.length + 1),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '$code\n  ');
      expect(result.selection.baseOffset, result.text.length);
    });

    test('aligns a closing brace with its block', () {
      const code = 'if (ready) {\n  ';
      final oldValue = TextEditingValue(
        text: code,
        selection: TextSelection.collapsed(offset: code.length),
      );
      final newValue = TextEditingValue(
        text: '$code}',
        selection: TextSelection.collapsed(offset: code.length + 1),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, 'if (ready) {\n}');
      expect(result.selection.baseOffset, result.text.length);
    });

    test('keeps Enter outside a block unindented', () {
      const code = 'int nilai = 80;';
      final oldValue = TextEditingValue(
        text: code,
        selection: TextSelection.collapsed(offset: code.length),
      );
      final newValue = TextEditingValue(
        text: '$code\n',
        selection: TextSelection.collapsed(offset: code.length + 1),
      );

      expect(formatter.formatEditUpdate(oldValue, newValue).text, '$code\n');
    });

    test('leaves pasted multiline code and mid-line edits intact', () {
      const code = 'int nilai = 80;';
      const pasted = 'if (nilai > 75) {\ncout << "Lulus";\n}';
      final oldValue = TextEditingValue(
        text: code,
        selection: TextSelection.collapsed(offset: code.length),
      );
      final pastedValue = TextEditingValue(
        text: pasted,
        selection: TextSelection.collapsed(offset: pasted.length),
      );
      expect(formatter.formatEditUpdate(oldValue, pastedValue).text, pasted);

      const prefix = 'int';
      final midLineValue = TextEditingValue(
        text:
            '${code.substring(0, prefix.length)}\n${code.substring(prefix.length)}',
        selection: TextSelection.collapsed(offset: prefix.length + 1),
      );
      final midLineResult = formatter.formatEditUpdate(
        oldValue.copyWith(
          selection: const TextSelection.collapsed(offset: prefix.length),
        ),
        midLineValue,
      );
      expect(midLineResult.text, midLineValue.text);
      expect(midLineResult.selection.baseOffset, prefix.length + 1);
    });
  });
}
