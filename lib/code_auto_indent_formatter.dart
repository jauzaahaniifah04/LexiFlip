import 'package:flutter/services.dart';

class CodeAutoIndentFormatter extends TextInputFormatter {
  const CodeAutoIndentFormatter();

  static const String _indentUnit = '  ';

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final change = _TextChange.between(oldValue.text, newValue.text);
    if (change == null) return newValue;

    if (change.inserted == '\n') {
      final prefix = oldValue.text.substring(0, change.start);
      final lineStart = prefix.lastIndexOf('\n') + 1;
      final currentLinePrefix = prefix.substring(lineStart);
      final indentation = RegExp(r'^[ \t]*').stringMatch(currentLinePrefix)!;
      final codeBeforeCursor = currentLinePrefix.trimRight();
      final addedIndent = codeBeforeCursor.endsWith('{') ? _indentUnit : '';
      final insertedIndent = '$indentation$addedIndent';
      final text = newValue.text.replaceRange(
        change.start + 1,
        change.end,
        insertedIndent,
      );
      final caret = change.start + 1 + insertedIndent.length;
      return newValue.copyWith(
        text: text,
        selection: TextSelection.collapsed(offset: caret),
        composing: TextRange.empty,
      );
    }

    if (change.inserted == '}' && change.removed.isEmpty) {
      final prefix = oldValue.text.substring(0, change.start);
      final lineStart = prefix.lastIndexOf('\n') + 1;
      final currentLinePrefix = prefix.substring(lineStart);
      if (currentLinePrefix.trim().isNotEmpty) return newValue;

      final indentation = currentLinePrefix;
      final adjustedIndentation = indentation.endsWith(_indentUnit)
          ? indentation.substring(0, indentation.length - _indentUnit.length)
          : indentation.endsWith('\t')
          ? indentation.substring(0, indentation.length - 1)
          : indentation;
      final text = newValue.text.replaceRange(
        lineStart,
        change.start,
        adjustedIndentation,
      );
      final caret = lineStart + adjustedIndentation.length + 1;
      return newValue.copyWith(
        text: text,
        selection: TextSelection.collapsed(offset: caret),
        composing: TextRange.empty,
      );
    }

    return newValue;
  }
}

class _TextChange {
  final int start;
  final int end;
  final String inserted;
  final String removed;

  const _TextChange({
    required this.start,
    required this.end,
    required this.inserted,
    required this.removed,
  });

  static _TextChange? between(String oldText, String newText) {
    var prefixLength = 0;
    final commonLength = oldText.length < newText.length
        ? oldText.length
        : newText.length;
    while (prefixLength < commonLength &&
        oldText.codeUnitAt(prefixLength) == newText.codeUnitAt(prefixLength)) {
      prefixLength++;
    }

    var oldSuffix = oldText.length;
    var newSuffix = newText.length;
    while (oldSuffix > prefixLength &&
        newSuffix > prefixLength &&
        oldText.codeUnitAt(oldSuffix - 1) ==
            newText.codeUnitAt(newSuffix - 1)) {
      oldSuffix--;
      newSuffix--;
    }

    if (prefixLength == oldSuffix && prefixLength == newSuffix) return null;
    return _TextChange(
      start: prefixLength,
      end: newSuffix,
      inserted: newText.substring(prefixLength, newSuffix),
      removed: oldText.substring(prefixLength, oldSuffix),
    );
  }
}
