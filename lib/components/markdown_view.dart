import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

/// Interactive Code Block Widget with Syntax Highlighting and One-Click Copy (CORE-001, CORE-003)
class CodeBlockWidget extends StatefulWidget {
  final String code;
  final String language;
  final Key? copyButtonKey;

  const CodeBlockWidget({
    super.key,
    required this.code,
    this.language = '',
    this.copyButtonKey,
  });

  @override
  State<CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<CodeBlockWidget> {
  bool _copied = false;
  Timer? _copyTimer;

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.code));
    setState(() {
      _copied = true;
    });
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _copied = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final langUpper = widget.language.trim().isEmpty ? 'TEXT' : widget.language.trim().toUpperCase();
    final lines = widget.code.split('\n');
    final lineCount = lines.length;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: OllivoTheme.onyxDark,
        borderRadius: BorderRadius.circular(OllivoTheme.radiusSm),
        border: Border.all(color: OllivoTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: OllivoTheme.surfaceDark,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(OllivoTheme.radiusSm),
                topRight: Radius.circular(OllivoTheme.radiusSm),
              ),
              border: Border(
                bottom: BorderSide(color: OllivoTheme.borderDark),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: OllivoTheme.oliveEmerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: OllivoTheme.oliveEmerald.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        langUpper,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: OllivoTheme.oliveEmerald,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$lineCount line${lineCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: OllivoTheme.textSecondaryDark,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  key: widget.copyButtonKey ?? Key('copyCodeButton_$langUpper'),
                  onTap: _copyToClipboard,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _copied
                          ? OllivoTheme.oliveEmerald.withValues(alpha: 0.2)
                          : OllivoTheme.cardDark,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _copied ? OllivoTheme.oliveEmerald : OllivoTheme.borderDark,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _copied ? Icons.check_circle_outline : Icons.copy_rounded,
                          size: 13,
                          color: _copied ? OllivoTheme.oliveEmerald : OllivoTheme.textSecondaryDark,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _copied ? 'Copied!' : 'Copy Code',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: _copied ? FontWeight.bold : FontWeight.normal,
                            color: _copied ? OllivoTheme.oliveEmerald : OllivoTheme.textSecondaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Code Container with Line Numbers & Syntax Highlighting
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Line numbers
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(lineCount, (index) {
                    return Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                        height: 1.5,
                        color: Color(0xFF555555),
                      ),
                    );
                  }),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 1,
                  height: lineCount * 18.75,
                  color: OllivoTheme.borderDark.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 14),
                // Highlighted Code Lines
                SelectableText.rich(
                  TextSpan(
                    children: _highlightSyntax(widget.code, widget.language.toLowerCase()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Multi-language Syntax Highlighting Tokenizer
  static List<TextSpan> _highlightSyntax(String code, String language) {
    final List<TextSpan> spans = [];

    final Set<String> keywords = _getKeywords(language);
    final Set<String> types = _getTypes(language);

    // Regex pattern matching Comments, Strings, Numbers, Identifiers, Operators
    final RegExp tokenPattern = RegExp(
      r'(//[^\n]*|#[^\n]*|--[^\n]*|/\*[\s\S]*?\*/)' // 1: comments
      r'|("""[\s\S]*?"""|"""[\s\S]*?"""|"(?:\\.|[^"\\])*"|\x27(?:\\.|[^\x27\\])*\x27|`[^`]*`)' // 2: strings
      r'|\b(\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|0x[0-9a-fA-F]+)\b' // 3: numbers
      r'|\b([a-zA-Z_][a-zA-Z0-9_]*)\b' // 4: words/identifiers
      r'|([{}()\[\],;:.])' // 5: punctuation
      r'|([+\-*\/%=<>!&|^~?:]+)' // 6: operators
      r'|(\s+)' // 7: whitespace
      r'|(.)', // 8: other
      multiLine: true,
    );

    final matches = tokenPattern.allMatches(code);
    for (final match in matches) {
      final comment = match.group(1);
      final stringLit = match.group(2);
      final number = match.group(3);
      final word = match.group(4);
      final punctuation = match.group(5);
      final operator = match.group(6);
      final whitespace = match.group(7);
      final other = match.group(8);

      if (comment != null) {
        spans.add(TextSpan(
          text: comment,
          style: const TextStyle(
            color: Color(0xFF7F848E),
            fontStyle: FontStyle.italic,
            fontFamily: 'monospace',
            fontSize: 12.5,
            height: 1.5,
          ),
        ));
      } else if (stringLit != null) {
        spans.add(TextSpan(
          text: stringLit,
          style: const TextStyle(
            color: Color(0xFFE5C07B), // Amber string
            fontFamily: 'monospace',
            fontSize: 12.5,
            height: 1.5,
          ),
        ));
      } else if (number != null) {
        spans.add(TextSpan(
          text: number,
          style: const TextStyle(
            color: Color(0xFFD19A66), // Warm orange number
            fontFamily: 'monospace',
            fontSize: 12.5,
            height: 1.5,
          ),
        ));
      } else if (word != null) {
        if (keywords.contains(word)) {
          spans.add(TextSpan(
            text: word,
            style: const TextStyle(
              color: OllivoTheme.oliveEmerald, // Olive Emerald keywords
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              fontSize: 12.5,
              height: 1.5,
            ),
          ));
        } else if (types.contains(word) || RegExp(r'^[A-Z][a-zA-Z0-9_]*$').hasMatch(word)) {
          spans.add(TextSpan(
            text: word,
            style: const TextStyle(
              color: Color(0xFF56B6C2), // Cyan class / type
              fontFamily: 'monospace',
              fontSize: 12.5,
              height: 1.5,
            ),
          ));
        } else {
          spans.add(TextSpan(
            text: word,
            style: const TextStyle(
              color: Color(0xFFABB2BF), // Light grey identifier
              fontFamily: 'monospace',
              fontSize: 12.5,
              height: 1.5,
            ),
          ));
        }
      } else if (punctuation != null) {
        spans.add(TextSpan(
          text: punctuation,
          style: const TextStyle(
            color: Color(0xFFABB2BF),
            fontFamily: 'monospace',
            fontSize: 12.5,
            height: 1.5,
          ),
        ));
      } else if (operator != null) {
        spans.add(TextSpan(
          text: operator,
          style: const TextStyle(
            color: Color(0xFF61AFEF), // Blue operator
            fontFamily: 'monospace',
            fontSize: 12.5,
            height: 1.5,
          ),
        ));
      } else if (whitespace != null) {
        spans.add(TextSpan(
          text: whitespace,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12.5,
            height: 1.5,
          ),
        ));
      } else if (other != null) {
        spans.add(TextSpan(
          text: other,
          style: const TextStyle(
            color: Color(0xFFABB2BF),
            fontFamily: 'monospace',
            fontSize: 12.5,
            height: 1.5,
          ),
        ));
      }
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(
        text: code,
        style: const TextStyle(
          color: Color(0xFFABB2BF),
          fontFamily: 'monospace',
          fontSize: 12.5,
          height: 1.5,
        ),
      ));
    }

    return spans;
  }

  static Set<String> _getKeywords(String language) {
    const commonKeywords = {
      'import', 'export', 'from', 'as', 'class', 'struct', 'enum', 'interface',
      'extends', 'implements', 'with', 'mixin', 'var', 'let', 'const', 'final',
      'static', 'return', 'if', 'else', 'switch', 'case', 'default', 'for', 'while',
      'do', 'break', 'continue', 'try', 'catch', 'finally', 'throw', 'new', 'this',
      'super', 'true', 'false', 'null', 'nil', 'void', 'async', 'await', 'yield',
      'function', 'def', 'func', 'fn', 'lambda',
    };

    const sqlKeywords = {
      'select', 'from', 'where', 'insert', 'into', 'values', 'update', 'set',
      'delete', 'join', 'left', 'right', 'inner', 'outer', 'group', 'by', 'order',
      'having', 'limit', 'offset', 'create', 'table', 'alter', 'drop', 'index',
      'primary', 'key', 'foreign', 'references', 'distinct', 'as', 'and', 'or',
      'not', 'null', 'is', 'in', 'between', 'like', 'union', 'all',
      'SELECT', 'FROM', 'WHERE', 'INSERT', 'INTO', 'VALUES', 'UPDATE', 'SET',
      'DELETE', 'JOIN', 'LEFT', 'RIGHT', 'INNER', 'OUTER', 'GROUP', 'BY', 'ORDER',
      'HAVING', 'LIMIT', 'OFFSET', 'CREATE', 'TABLE', 'ALTER', 'DROP', 'INDEX',
      'PRIMARY', 'KEY', 'FOREIGN', 'REFERENCES', 'DISTINCT', 'AS', 'AND', 'OR',
      'NOT', 'NULL', 'IS', 'IN', 'BETWEEN', 'LIKE', 'UNION', 'ALL',
    };

    if (language == 'sql') return sqlKeywords;
    return commonKeywords;
  }

  static Set<String> _getTypes(String language) {
    return {
      'String', 'int', 'double', 'num', 'bool', 'List', 'Map', 'Set', 'Future',
      'Stream', 'Widget', 'BuildContext', 'State', 'Object', 'dynamic', 'void',
      'Promise', 'Array', 'Record', 'any', 'unknown', 'never', 'undefined',
      'float', 'char', 'long', 'short', 'byte', 'boolean', 'Integer', 'Double',
    };
  }
}

/// LaTeX / Mathematical Expression Block Widget (CORE-002)
class MathBlockWidget extends StatefulWidget {
  final String formula;

  const MathBlockWidget({super.key, required this.formula});

  @override
  State<MathBlockWidget> createState() => _MathBlockWidgetState();
}

class _MathBlockWidgetState extends State<MathBlockWidget> {
  bool _copied = false;
  Timer? _copyTimer;

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  void _copyLatex() {
    Clipboard.setData(ClipboardData(text: widget.formula));
    setState(() => _copied = true);
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final formattedMath = _formatLatexSymbols(widget.formula.trim());

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OllivoTheme.onyxDark,
        borderRadius: BorderRadius.circular(OllivoTheme.radiusSm),
        border: Border.all(color: OllivoTheme.oliveEmerald.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.functions, size: 14, color: OllivoTheme.oliveEmerald),
                  const SizedBox(width: 6),
                  Text(
                    'MATH FORMULA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: OllivoTheme.oliveEmerald.withValues(alpha: 0.9),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: _copyLatex,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        _copied ? Icons.check : Icons.copy,
                        size: 12,
                        color: _copied ? OllivoTheme.oliveEmerald : OllivoTheme.textSecondaryDark,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _copied ? 'Copied' : 'Copy LaTeX',
                        style: TextStyle(
                          fontSize: 10,
                          color: _copied ? OllivoTheme.oliveEmerald : OllivoTheme.textSecondaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: SelectableText(
                formattedMath,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: 'serif',
                  fontStyle: FontStyle.italic,
                  color: OllivoTheme.textPrimaryDark,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Translates LaTeX macros to clean unicode mathematical symbols
  static String _formatLatexSymbols(String latex) {
    String text = latex;
    const replacements = {
      r'\alpha': 'α', r'\beta': 'β', r'\gamma': 'γ', r'\delta': 'δ', r'\epsilon': 'ε',
      r'\theta': 'θ', r'\lambda': 'λ', r'\mu': 'μ', r'\pi': 'π', r'\sigma': 'σ',
      r'\tau': 'τ', r'\omega': 'ω', r'\Gamma': 'Γ', r'\Delta': 'Δ', r'\Theta': 'Θ',
      r'\Lambda': 'Λ', r'\Sigma': 'Σ', r'\Omega': 'Ω',
      r'\sum': '∑', r'\int': '∫', r'\iint': '∬', r'\oint': '∮', r'\prod': '∏',
      r'\sqrt': '√', r'\infty': '∞', r'\pm': '±', r'\mp': '∓', r'\times': '×',
      r'\div': '÷', r'\cdot': '·', r'\le': '≤', r'\ge': '≥', r'\neq': '≠',
      r'\approx': '≈', r'\equiv': '≡', r'\forall': '∀', r'\exists': '∃',
      r'\in': '∈', r'\notin': '∉', r'\subset': '⊂', r'\supset': '⊃',
      r'\cup': '∪', r'\cap': '∩', r'\rightarrow': '→', r'\leftarrow': '←',
      r'\Rightarrow': '⇒', r'\Leftarrow': '⇐', r'\partial': '∂', r'\nabla': '∇',
    };

    replacements.forEach((tex, symbol) {
      text = text.replaceAll(tex, symbol);
    });

    // Replace fractions \frac{a}{b} -> (a / b)
    text = text.replaceAllMapped(RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}'), (m) {
      return '(${m.group(1)} / ${m.group(2)})';
    });

    // Replace superscripts ^2 -> ²
    const superscripts = {
      '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
      '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
      '+': '⁺', '-': '⁻', '=': '⁼', 'n': 'ⁿ', 'i': 'ⁱ',
    };
    text = text.replaceAllMapped(RegExp(r'\^([0-9\+\-n])'), (m) {
      return superscripts[m.group(1)] ?? m.group(0)!;
    });

    // Replace subscripts _2 -> ₂
    const subscripts = {
      '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄',
      '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉',
    };
    text = text.replaceAllMapped(RegExp(r'_([0-9])'), (m) {
      return subscripts[m.group(1)] ?? m.group(0)!;
    });

    return text.replaceAll(RegExp(r'\\[a-zA-Z]+'), '');
  }
}

/// Complete Rich Markdown View with Code Blocks, LaTeX Math, and Typography
class RichMarkdownView extends StatelessWidget {
  final String markdown;
  final bool isUser;
  final TextStyle? baseStyle;

  const RichMarkdownView({
    super.key,
    required this.markdown,
    this.isUser = false,
    this.baseStyle,
  });

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(markdown);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks.map((block) {
        if (block is _CodeBlockData) {
          return CodeBlockWidget(
            code: block.code,
            language: block.language,
          );
        } else if (block is _MathBlockData) {
          return MathBlockWidget(formula: block.formula);
        } else if (block is _HeadingBlockData) {
          return _buildHeading(block);
        } else if (block is _BlockquoteData) {
          return _buildBlockquote(block);
        } else if (block is _ListBlockData) {
          return _buildListItem(block);
        } else {
          final p = block as _ParagraphBlockData;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SelectableText.rich(
              TextSpan(
                children: _parseInlineSpans(p.text, isUser: isUser),
              ),
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isUser ? OllivoTheme.textPrimaryDark : OllivoTheme.textPrimaryDark,
              ),
            ),
          );
        }
      }).toList(),
    );
  }

  Widget _buildHeading(_HeadingBlockData data) {
    double size = 16.0;
    if (data.level == 1) size = 20.0;
    if (data.level == 2) size = 18.0;
    if (data.level == 3) size = 16.0;

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: SelectableText.rich(
        TextSpan(children: _parseInlineSpans(data.text, isUser: isUser)),
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.bold,
          color: OllivoTheme.textPrimaryDark,
        ),
      ),
    );
  }

  Widget _buildBlockquote(_BlockquoteData data) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4, right: 8),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: OllivoTheme.oliveEmerald, width: 3),
        ),
      ),
      child: SelectableText.rich(
        TextSpan(children: _parseInlineSpans(data.text, isUser: isUser)),
        style: const TextStyle(
          fontStyle: FontStyle.italic,
          fontSize: 13.5,
          color: OllivoTheme.textSecondaryDark,
        ),
      ),
    );
  }

  Widget _buildListItem(_ListBlockData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: data.isOrdered
                ? Text(
                    '${data.number}.',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: OllivoTheme.oliveEmerald,
                    ),
                  )
                : Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: OllivoTheme.oliveEmerald,
                      shape: BoxShape.circle,
                    ),
                  ),
          ),
          Expanded(
            child: SelectableText.rich(
              TextSpan(children: _parseInlineSpans(data.text, isUser: isUser)),
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  static List<_BlockData> _parseBlocks(String input) {
    final List<_BlockData> blocks = [];
    final lines = input.split('\n');

    int i = 0;
    while (i < lines.length) {
      final line = lines[i];

      // 1. Fenced Code Block ```
      if (line.trim().startsWith('```')) {
        final lang = line.trim().substring(3).trim();
        final codeLines = <String>[];
        i++;
        while (i < lines.length && !lines[i].trim().startsWith('```')) {
          codeLines.add(lines[i]);
          i++;
        }
        blocks.add(_CodeBlockData(
          code: codeLines.join('\n'),
          language: lang,
        ));
        i++;
        continue;
      }

      // 2. LaTeX Block $$
      if (line.trim().startsWith(r'$$')) {
        final mathLines = <String>[];
        if (line.trim().length > 2 && line.trim().endsWith(r'$$') && line.trim() != r'$$') {
          // Single line $$formula$$
          final inner = line.trim().substring(2, line.trim().length - 2).trim();
          blocks.add(_MathBlockData(formula: inner));
          i++;
          continue;
        }

        i++;
        while (i < lines.length && !lines[i].trim().endsWith(r'$$')) {
          mathLines.add(lines[i]);
          i++;
        }
        if (i < lines.length && lines[i].trim().endsWith(r'$$') && lines[i].trim() != r'$$') {
          mathLines.add(lines[i].trim().substring(0, lines[i].trim().length - 2));
        }
        blocks.add(_MathBlockData(formula: mathLines.join('\n')));
        i++;
        continue;
      }

      // 3. Headings #, ##, ###
      if (line.startsWith('#')) {
        int level = 0;
        while (level < line.length && line[level] == '#') {
          level++;
        }
        if (level < line.length && line[level] == ' ') {
          blocks.add(_HeadingBlockData(
            text: line.substring(level + 1).trim(),
            level: level,
          ));
          i++;
          continue;
        }
      }

      // 4. Blockquote >
      if (line.startsWith('>')) {
        blocks.add(_BlockquoteData(text: line.substring(1).trim()));
        i++;
        continue;
      }

      // 5. Unordered List - or *
      if (line.trim().startsWith('- ') || line.trim().startsWith('* ')) {
        blocks.add(_ListBlockData(
          text: line.trim().substring(2).trim(),
          isOrdered: false,
        ));
        i++;
        continue;
      }

      // 6. Ordered List 1.
      final orderedMatch = RegExp(r'^(\d+)\.\s+(.*)').firstMatch(line.trim());
      if (orderedMatch != null) {
        blocks.add(_ListBlockData(
          text: orderedMatch.group(2) ?? '',
          isOrdered: true,
          number: int.tryParse(orderedMatch.group(1) ?? '1') ?? 1,
        ));
        i++;
        continue;
      }

      // 7. Regular paragraph / line
      if (line.trim().isNotEmpty) {
        final paragraphLines = <String>[line];
        i++;
        while (i < lines.length &&
            lines[i].trim().isNotEmpty &&
            !lines[i].trim().startsWith('```') &&
            !lines[i].trim().startsWith(r'$$') &&
            !lines[i].startsWith('#') &&
            !lines[i].startsWith('>') &&
            !lines[i].trim().startsWith('- ') &&
            !lines[i].trim().startsWith('* ') &&
            !RegExp(r'^\d+\.\s+').hasMatch(lines[i].trim())) {
          paragraphLines.add(lines[i]);
          i++;
        }
        blocks.add(_ParagraphBlockData(text: paragraphLines.join('\n')));
        continue;
      }

      i++;
    }

    if (blocks.isEmpty && input.isNotEmpty) {
      blocks.add(_ParagraphBlockData(text: input));
    }

    return blocks;
  }

  /// Parses inline markdown: bold, italic, inline code, inline math
  static List<InlineSpan> _parseInlineSpans(String text, {bool isUser = false}) {
    final List<InlineSpan> spans = [];

    // Pattern for inline code, inline math, bold, italic
    final RegExp inlinePattern = RegExp(
      r'(`[^`]+`)' // 1. inline code
      r'|(\$[^$\n]+\$)' // 2. inline math
      r'|(\*\*[^*]+\*\*)' // 3. bold
      r'|(\*[^*]+\*|_[^_]+_)', // 4. italic
    );

    int lastIndex = 0;
    for (final match in inlinePattern.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
        ));
      }

      final inlineCode = match.group(1);
      final inlineMath = match.group(2);
      final bold = match.group(3);
      final italic = match.group(4);

      if (inlineCode != null) {
        final codeContent = inlineCode.substring(1, inlineCode.length - 1);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: OllivoTheme.cardDark,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: OllivoTheme.borderDark),
            ),
            child: Text(
              codeContent,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: OllivoTheme.oliveEmerald,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ));
      } else if (inlineMath != null) {
        final mathContent = inlineMath.substring(1, inlineMath.length - 1);
        final formatted = _MathBlockWidgetState._formatLatexSymbols(mathContent);
        spans.add(TextSpan(
          text: formatted,
          style: const TextStyle(
            fontFamily: 'serif',
            fontStyle: FontStyle.italic,
            color: OllivoTheme.oliveEmerald,
            fontWeight: FontWeight.w600,
          ),
        ));
      } else if (bold != null) {
        spans.add(TextSpan(
          text: bold.substring(2, bold.length - 2),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ));
      } else if (italic != null) {
        spans.add(TextSpan(
          text: italic.substring(1, italic.length - 1),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ));
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
      ));
    }

    return spans;
  }
}

// Block Data Classes
abstract class _BlockData {}

class _ParagraphBlockData extends _BlockData {
  final String text;
  _ParagraphBlockData({required this.text});
}

class _CodeBlockData extends _BlockData {
  final String code;
  final String language;
  _CodeBlockData({required this.code, required this.language});
}

class _MathBlockData extends _BlockData {
  final String formula;
  _MathBlockData({required this.formula});
}

class _HeadingBlockData extends _BlockData {
  final String text;
  final int level;
  _HeadingBlockData({required this.text, required this.level});
}

class _BlockquoteData extends _BlockData {
  final String text;
  _BlockquoteData({required this.text});
}

class _ListBlockData extends _BlockData {
  final String text;
  final bool isOrdered;
  final int number;
  _ListBlockData({required this.text, required this.isOrdered, this.number = 1});
}
