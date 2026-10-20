class CodeEvaluation {
  final bool isCorrect;
  final String feedback;

  const CodeEvaluation({required this.isCorrect, required this.feedback});
}

CodeEvaluation evaluateCppAnswer(String submitted, String expected) {
  final submittedTokens = _tokenizeCpp(submitted);
  if (submittedTokens == null) {
    return const CodeEvaluation(
      isCorrect: false,
      feedback: 'String literal atau komentar belum ditutup dengan benar.',
    );
  }

  final submittedDelimiterError = _delimiterError(submittedTokens);
  if (submittedDelimiterError != null) {
    return CodeEvaluation(isCorrect: false, feedback: submittedDelimiterError);
  }

  final expectedTokens = _tokenizeCpp(expected);
  if (expectedTokens == null || _delimiterError(expectedTokens) != null) {
    return const CodeEvaluation(
      isCorrect: false,
      feedback: 'Kunci jawaban latihan tidak valid.',
    );
  }

  if (normalisasiKode(submitted) == normalisasiKode(expected)) {
    return const CodeEvaluation(
      isCorrect: true,
      feedback: 'Kriteria latihan terpenuhi.',
    );
  }

  return const CodeEvaluation(
    isCorrect: false,
    feedback:
        'Periksa kembali struktur, nama variabel, operator, angka, dan '
        'keluaran yang diminta. Spasi dan indentasi di luar literal tidak '
        'memengaruhi penilaian.',
  );
}

String normalisasiKode(String source) {
  final tokens = _tokenizeCpp(source);
  return tokens?.join('\u0000') ?? '';
}

List<String>? _tokenizeCpp(String source) {
  final tokens = <String>[];
  var index = 0;

  while (index < source.length) {
    final character = source[index];

    if (_isWhitespace(character)) {
      index++;
      continue;
    }

    if (character == '/' && index + 1 < source.length) {
      final next = source[index + 1];
      if (next == '/') {
        index += 2;
        while (index < source.length && source[index] != '\n') {
          index++;
        }
        continue;
      }
      if (next == '*') {
        final commentEnd = source.indexOf('*/', index + 2);
        if (commentEnd < 0) return null;
        index = commentEnd + 2;
        continue;
      }
    }

    if (character == '"' || character == "'") {
      final literalEnd = _literalEnd(source, index, character);
      if (literalEnd == null) return null;
      tokens.add(source.substring(index, literalEnd));
      index = literalEnd;
      continue;
    }

    if (_isIdentifierStart(character)) {
      final start = index++;
      while (index < source.length && _isIdentifierPart(source[index])) {
        index++;
      }
      tokens.add(source.substring(start, index));
      continue;
    }

    if (_isDigit(character)) {
      final start = index++;
      while (index < source.length && _isNumberPart(source[index])) {
        index++;
      }
      tokens.add(source.substring(start, index));
      continue;
    }

    final operator = _matchOperator(source, index);
    if (operator != null) {
      tokens.add(operator);
      index += operator.length;
    } else {
      tokens.add(character);
      index++;
    }
  }

  return tokens;
}

int? _literalEnd(String source, int start, String quote) {
  var index = start + 1;
  while (index < source.length) {
    final character = source[index];
    if (character == '\\') {
      index += 2;
      continue;
    }
    if (character == quote) return index + 1;
    if (character == '\n' && quote == "'") return null;
    index++;
  }
  return null;
}

String? _delimiterError(List<String> tokens) {
  final expectedClosers = <String>[];
  const matchingClosers = {'(': ')', '[': ']', '{': '}'};

  for (final token in tokens) {
    if (matchingClosers.containsKey(token)) {
      expectedClosers.add(matchingClosers[token]!);
      continue;
    }

    if (token == ')' || token == ']' || token == '}') {
      if (expectedClosers.isEmpty || expectedClosers.removeLast() != token) {
        return 'Kurung penutup "$token" tidak cocok dengan pembukanya.';
      }
    }
  }

  if (expectedClosers.isNotEmpty) {
    return 'Kurung belum lengkap. Tambahkan "${expectedClosers.last}".';
  }
  return null;
}

String? _matchOperator(String source, int index) {
  const operators = [
    '<<=',
    '>>=',
    '++',
    '--',
    '==',
    '!=',
    '<=',
    '>=',
    '&&',
    '||',
    '+=',
    '-=',
    '*=',
    '/=',
    '%=',
    '<<',
    '>>',
    '->',
    '::',
  ];
  for (final operator in operators) {
    if (source.startsWith(operator, index)) return operator;
  }
  return null;
}

bool _isWhitespace(String value) =>
    value == ' ' || value == '\t' || value == '\n' || value == '\r';

bool _isIdentifierStart(String value) =>
    (value.codeUnitAt(0) >= 65 && value.codeUnitAt(0) <= 90) ||
    (value.codeUnitAt(0) >= 97 && value.codeUnitAt(0) <= 122) ||
    value == '_';

bool _isIdentifierPart(String value) =>
    _isIdentifierStart(value) || _isDigit(value);

bool _isDigit(String value) =>
    value.codeUnitAt(0) >= 48 && value.codeUnitAt(0) <= 57;

bool _isNumberPart(String value) =>
    _isIdentifierPart(value) || value == '.' || value == '\'';
