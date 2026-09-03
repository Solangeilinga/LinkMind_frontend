import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../main/community/models/post_type_config.dart';

// Types que le pro peut choisir en publiant — cohérent avec la restriction
// déjà en place côté serveur (PRO_ALLOWED_POST_TYPES).
const _proTypes = ['tip', 'support', 'general'];

class ProComposePage extends StatefulWidget {
  final Future<void> Function(String content, String type) onSubmit;
  const ProComposePage({super.key, required this.onSubmit});

  @override
  State<ProComposePage> createState() => _ProComposePageState();
}

class _ProComposePageState extends State<ProComposePage> {
  final _ctrl = TextEditingController();
  String _type = 'tip';
  int _charCount = 0;
  bool _isPosting = false;
  static const _maxChars = 1500;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      if (mounted) setState(() => _charCount = _ctrl.text.length);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_ctrl.text.trim().isEmpty || _isPosting) return;
    setState(() => _isPosting = true);
    try {
      await widget.onSubmit(_ctrl.text.trim(), _type);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeConf = postTypeConfig[_type]!;
    final canSubmit = _ctrl.text.trim().isNotEmpty && _charCount <= _maxChars;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('Nouveau post', style: AppTextStyles.h4),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: AppRadius.full),
            child: const Text('Professionnel', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
          ),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: canSubmit ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: typeConf.color,
                disabledBackgroundColor: AppColors.divider,
                minimumSize: const Size(80, 36),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: _isPosting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Publier'),
            ),
          ),
        ],
      ),
      body: Column(children: [
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Type de partage', style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _proTypes.map((id) {
                  final e = postTypeConfig[id]!;
                  final sel = _type == id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _type = id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? e.color.withValues(alpha: 0.15) : AppColors.surfaceVariant,
                          borderRadius: AppRadius.full,
                          border: Border.all(color: sel ? e.color : Colors.transparent, width: 1.5),
                        ),
                        child: Text('${e.emoji} ${e.label}',
                          style: AppTextStyles.caption.copyWith(color: sel ? e.color : AppColors.onSurfaceMuted, fontWeight: sel ? FontWeight.w900 : FontWeight.w600)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ]),
        ),
        const Divider(height: 1, color: AppColors.divider),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _ctrl,
              maxLines: null,
              expands: true,
              maxLength: _maxChars,
              autofocus: true,
              textAlignVertical: TextAlignVertical.top,
              style: AppTextStyles.body.copyWith(height: 1.7),
              decoration: InputDecoration(
                hintText: 'Partage un conseil ou un mot de soutien avec la communauté…',
                hintStyle: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted.withValues(alpha: 0.5), height: 1.7),
                border: InputBorder.none,
                counterStyle: AppTextStyles.caption.copyWith(color: _charCount > _maxChars * 0.9 ? AppColors.accent : AppColors.onSurfaceMuted),
              ),
            ),
          ),
        ),

        // ⚠️ Rappel contextuel, exactement au moment où il compte — remplace
        // l'ancienne bannière permanente en haut du fil, qui prenait de la
        // place en continu pour une information qui n'a d'importance qu'au
        // moment précis de publier.
        Container(
          padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
          decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.divider))),
          child: Row(children: [
            const Icon(Icons.badge_outlined, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Expanded(child: Text('Publié sous ton nom et ton badge professionnel — jamais anonyme.',
              style: AppTextStyles.caption.copyWith(color: AppColors.primary))),
            Text('$_charCount / $_maxChars',
              style: AppTextStyles.caption.copyWith(color: _charCount > _maxChars * 0.9 ? AppColors.accent : AppColors.onSurfaceMuted)),
          ]),
        ),
      ]),
    );
  }
}