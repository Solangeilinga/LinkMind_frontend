import 'package:flutter/material.dart';
import '../../../../utils/theme.dart';
import '../models/post_type_config.dart';

class ComposePage extends StatefulWidget {
  final Future<void> Function(String content, String type, String? moodEmoji)?
      onSubmit;
  final String? initialContent;
  final String? initialType;
  final bool isEditing;

  const ComposePage({
    super.key,
    this.onSubmit,
    this.initialContent,
    this.initialType,
    this.isEditing = false,
  });

  @override
  State<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends State<ComposePage> {
  final _ctrl = TextEditingController();
  String _type = 'feeling';
  int _charCount = 0;
  bool _isPosting = false;
  static const _maxChars = 1500;
  static const _types = ['feeling', 'question', 'support', 'success', 'tip'];

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.initialContent != null) {
      _ctrl.text = widget.initialContent!;
      _charCount = _ctrl.text.length;
    }
    if (widget.isEditing && widget.initialType != null) {
      _type = widget.initialType!;
    }
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
    if (_charCount == 0 || _isPosting || widget.onSubmit == null) return;
    setState(() => _isPosting = true);
    try {
      await widget.onSubmit!(_ctrl.text.trim(), _type, null);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeConf = postTypeConfig[_type] ?? postTypeConfig['feeling']!;
    final canSubmit = _charCount > 0 &&
        _charCount <= _maxChars &&
        !_isPosting &&
        widget.onSubmit != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(children: [
          Flexible(
            child: Text(
              widget.isEditing ? 'Modifier le partage' : 'Nouveau partage',
              style: AppTextStyles.h4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: AppRadius.full,
              border:
                  Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('🔒', style: TextStyle(fontSize: 11)),
              SizedBox(width: 3),
              Text(
                'Anon',
                style: TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 11),
              ),
            ]),
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
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(widget.isEditing ? 'Enregistrer' : 'Publier'),
            ),
          ),
        ],
      ),
      body: Column(children: [
        // Type selector (disabled in edit mode)
        if (!widget.isEditing)
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'Type de partage',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.onSurfaceMuted,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _types.map((id) {
                    final e = postTypeConfig[id]!;
                    final sel = _type == id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _type = id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel
                                ? e.color.withValues(alpha: 0.15)
                                : AppColors.surfaceVariant,
                            borderRadius: AppRadius.full,
                            border: Border.all(
                                color: sel ? e.color : Colors.transparent,
                                width: 1.5),
                          ),
                          child: Text(
                            '${e.emoji} ${e.label}',
                            style: AppTextStyles.caption.copyWith(
                              color: sel ? e.color : AppColors.onSurfaceMuted,
                              fontWeight:
                                  sel ? FontWeight.w900 : FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ]),
          ),
        if (!widget.isEditing)
          const Divider(height: 1, color: AppColors.divider),

        // Zone de texte
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
                hintText: 'Partage ce que tu ressens… Tout est anonyme ici.',
                hintStyle: AppTextStyles.body.copyWith(
                    color: AppColors.onSurfaceMuted.withValues(alpha: 0.5),
                    height: 1.7),
                border: InputBorder.none,
                counterStyle: AppTextStyles.caption.copyWith(
                    color: _charCount > _maxChars * 0.9
                        ? AppColors.accent
                        : AppColors.onSurfaceMuted),
              ),
            ),
          ),
        ),

        // Barre info bas
        Container(
          padding: EdgeInsets.fromLTRB(
              16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: Row(children: [
            const Icon(Icons.lock_outline,
                size: 14, color: AppColors.onSurfaceMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                "Personne ne verra ton identité.",
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.onSurfaceMuted),
              ),
            ),
            Text(
              '$_charCount / $_maxChars',
              style: AppTextStyles.caption.copyWith(
                color: _charCount > _maxChars * 0.9
                    ? AppColors.accent
                    : AppColors.onSurfaceMuted,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
