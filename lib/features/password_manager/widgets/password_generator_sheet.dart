import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../services/pass_gen_service.dart';

/// Password Generator Bottom Sheet & Modal inspired by pass-gen
class PasswordGeneratorSheet extends StatefulWidget {
  final ValueChanged<String>? onSelectPassword;

  const PasswordGeneratorSheet({super.key, this.onSelectPassword});

  static Future<String?> show(BuildContext context, {ValueChanged<String>? onSelectPassword}) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => PasswordGeneratorSheet(
        onSelectPassword: (pwd) {
          if (onSelectPassword != null) {
            onSelectPassword(pwd);
          }
          Navigator.pop(ctx, pwd);
        },
      ),
    );
  }

  @override
  State<PasswordGeneratorSheet> createState() => _PasswordGeneratorSheetState();
}

class _PasswordGeneratorSheetState extends State<PasswordGeneratorSheet> {
  bool _isPassphrase = false;

  // Password options
  int _length = 16;
  bool _upper = true;
  bool _lower = true;
  bool _nums = true;
  bool _syms = true;
  bool _excludeAmbiguous = false;

  // Passphrase options
  int _wordCount = 4;
  String _separator = '-';
  bool _capitalize = true;
  bool _includeNumber = true;

  String _generatedPassword = '';
  bool _obscure = false;
  Timer? _clipboardTimer;

  @override
  void initState() {
    super.initState();
    _regenerate();
  }

  @override
  void dispose() {
    _clipboardTimer?.cancel();
    super.dispose();
  }

  void _regenerate() {
    setState(() {
      if (!_isPassphrase) {
        _generatedPassword = PassGenService.generatePassword(
          length: _length,
          uppercase: _upper,
          lowercase: _lower,
          numbers: _nums,
          symbols: _syms,
          excludeAmbiguous: _excludeAmbiguous,
        );
      } else {
        _generatedPassword = PassGenService.generatePassphrase(
          wordCount: _wordCount,
          separator: _separator,
          capitalize: _capitalize,
          includeNumber: _includeNumber,
        );
      }
    });
  }

  int get _entropyBits {
    return PassGenService.calcEntropyBits(
      isPassphrase: _isPassphrase,
      length: _length,
      uppercase: _upper,
      lowercase: _lower,
      numbers: _nums,
      symbols: _syms,
      excludeAmbiguous: _excludeAmbiguous,
      wordCount: _wordCount,
      includeNumber: _includeNumber,
    );
  }

  String get _crackTime => PassGenService.estimateCrackTime(_entropyBits);
  String get _strengthLabel => PassGenService.strengthLabel(_entropyBits);
  double get _strengthProgress => PassGenService.strengthProgress(_entropyBits);

  Color get _strengthColor {
    final bits = _entropyBits;
    if (bits < 35) return AppTheme.danger;
    if (bits < 60) return AppTheme.warning;
    if (bits < 80) return AppTheme.primary;
    return AppTheme.safe;
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _generatedPassword));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password copied! Clipboard auto-clears in 30s'),
        duration: Duration(seconds: 3),
      ),
    );
    _clipboardTimer?.cancel();
    _clipboardTimer = Timer(const Duration(seconds: 30), () {
      Clipboard.setData(const ClipboardData(text: ''));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header bar
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.key_outlined, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Secure Password Generator',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    Text('Cryptographically Secure • Offline',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Mode Selector Tabs (Password vs Passphrase)
            Container(
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _isPassphrase = false);
                        _regenerate();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: !_isPassphrase ? AppTheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Password',
                          style: TextStyle(
                            color: !_isPassphrase ? AppTheme.background : AppTheme.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _isPassphrase = true);
                        _regenerate();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: _isPassphrase ? AppTheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Passphrase (Diceware)',
                          style: TextStyle(
                            color: _isPassphrase ? AppTheme.background : AppTheme.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Generated Output Display Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          _obscure ? '•' * _generatedPassword.length : _generatedPassword,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontFamily: _obscure ? null : 'monospace',
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: _obscure ? 2 : 0.5,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: AppTheme.textSecondary, size: 20),
                        onPressed: () => setState(() => _obscure = !_obscure),
                        tooltip: _obscure ? 'Show' : 'Hide',
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary, size: 22),
                        onPressed: _regenerate,
                        tooltip: 'Regenerate',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Strength Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _strengthProgress,
                      backgroundColor: AppTheme.divider,
                      valueColor: AlwaysStoppedAnimation(_strengthColor),
                      minHeight: 5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Metrics Badges: Entropy & Crack Time
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _strengthColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$_strengthLabel ($_entropyBits bits)',
                          style: TextStyle(
                              color: _strengthColor, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Crack time: $_crackTime (100B GPU/s)',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Controls Section
            if (!_isPassphrase) _buildPasswordControls() else _buildPassphraseControls(),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyToClipboard,
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: const Text('COPY'),
                  ),
                ),
                if (widget.onSelectPassword != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => widget.onSelectPassword!(_generatedPassword),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('USE PASSWORD'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordControls() {
    return Column(
      children: [
        // Length Slider
        Row(
          children: [
            const Text('Length:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            Expanded(
              child: Slider(
                value: _length.toDouble(),
                min: 4,
                max: 64,
                divisions: 60,
                activeColor: AppTheme.primary,
                onChanged: (v) {
                  setState(() => _length = v.toInt());
                  _regenerate();
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$_length',
                style: const TextStyle(
                    color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Character Sets Toggles
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip('A-Z (Uppercase)', _upper, (v) {
              setState(() => _upper = v);
              _regenerate();
            }),
            _chip('a-z (Lowercase)', _lower, (v) {
              setState(() => _lower = v);
              _regenerate();
            }),
            _chip('0-9 (Numbers)', _nums, (v) {
              setState(() => _nums = v);
              _regenerate();
            }),
            _chip('!@#\$ (Symbols)', _syms, (v) {
              setState(() => _syms = v);
              _regenerate();
            }),
          ],
        ),
        const SizedBox(height: 12),

        // Exclude Ambiguous Characters Switch
        SwitchListTile(
          value: _excludeAmbiguous,
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Exclude Ambiguous Characters',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          ),
          subtitle: const Text(
            'Strips l, 1, I, O, 0, o, Q, S, 5, Z, 2',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
          onChanged: (v) {
            setState(() => _excludeAmbiguous = v);
            _regenerate();
          },
        ),
      ],
    );
  }

  Widget _buildPassphraseControls() {
    return Column(
      children: [
        // Word Count Slider
        Row(
          children: [
            const Text('Words:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            Expanded(
              child: Slider(
                value: _wordCount.toDouble(),
                min: 3,
                max: 10,
                divisions: 7,
                activeColor: AppTheme.primary,
                onChanged: (v) {
                  setState(() => _wordCount = v.toInt());
                  _regenerate();
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$_wordCount words',
                style: const TextStyle(
                    color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Separator Selection
        Row(
          children: [
            const Text('Separator:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 6,
                children: [
                  _sepBtn('-', 'Hyphen (-)'),
                  _sepBtn(' ', 'Space ( )'),
                  _sepBtn('.', 'Dot (.)'),
                  _sepBtn('_', 'Underscore (_)'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Capitalize & Inject Number
        SwitchListTile(
          value: _capitalize,
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Capitalize Words',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
          onChanged: (v) {
            setState(() => _capitalize = v);
            _regenerate();
          },
        ),
        SwitchListTile(
          value: _includeNumber,
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Inject Random Number',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
          subtitle: const Text('Adds 2-digit number (e.g. word94)',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          onChanged: (v) {
            setState(() => _includeNumber = v);
            _regenerate();
          },
        ),
      ],
    );
  }

  Widget _chip(String label, bool value, ValueChanged<bool> onChanged) {
    return FilterChip(
      selected: value,
      label: Text(label,
          style: TextStyle(
            color: value ? AppTheme.primary : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: value ? FontWeight.bold : FontWeight.normal,
          )),
      backgroundColor: AppTheme.surfaceVariant,
      selectedColor: AppTheme.primary.withValues(alpha: 0.15),
      checkmarkColor: AppTheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: onChanged,
    );
  }

  Widget _sepBtn(String sep, String tooltip) {
    final selected = _separator == sep;
    return GestureDetector(
      onTap: () {
        setState(() => _separator = sep);
        _regenerate();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          sep == ' ' ? 'Space' : sep,
          style: TextStyle(
            color: selected ? AppTheme.background : AppTheme.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
