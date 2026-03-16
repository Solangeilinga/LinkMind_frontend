import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/theme.dart';
import '../../services/api.service.dart';

// ─── Message model ────────────────────────────────────────────────────────────
class _ChatMessage {
  final String content;
  final bool isUser;
  final DateTime time;
  final String? severity;
  final bool suggestProfessional;
  final String? professionalMessage;
  final List<String> quickActions;

  _ChatMessage({
    required this.content,
    required this.isUser,
    required this.time,
    this.severity,
    this.suggestProfessional = false,
    this.professionalMessage,
    this.quickActions = const [],
  });
}

// ─── Starter prompts ──────────────────────────────────────────────────────────
const _starters = [
  ('😰', 'Je suis stressé par mes examens', 'stressed'),
  ('😔', 'Je me sens seul(e) à l\'université', 'sad'),
  ('😴', 'Je n\'arrive plus à me concentrer', 'tired'),
  ('💭', 'J\'ai du mal à me motiver', 'neutral'),
  ('😟', 'J\'ai des pensées qui me pèsent', 'anxious'),
  ('🎯', 'Comment mieux organiser mes révisions ?', 'neutral'),
];

// ─── Assistant Screen ──────────────────────────────────────────────────────────
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});
  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> with TickerProviderStateMixin {
  final List<_ChatMessage> _messages = [];
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isTyping = false;
  bool _hasStarted = false;
  Map<String, dynamic>? _userContext;

  late AnimationController _typingController;

  @override
  void initState() {
    super.initState();
    _typingController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _typingController.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text, {Map<String, dynamic>? userCtx}) async {
    if (text.trim().isEmpty || _isTyping) return;
    _inputCtrl.clear();
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _hasStarted = true;
      _messages.add(_ChatMessage(
        content: text.trim(),
        isUser: true,
        time: DateTime.now(),
      ));
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final response = await ApiService().chatWithAssistant(
        message: text.trim(),
        context: userCtx ?? _userContext,
      );

      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(_ChatMessage(
            content: response['message'] ?? '',
            isUser: false,
            time: DateTime.now(),
            severity: response['severity'],
            suggestProfessional: response['suggestProfessional'] == true,
            professionalMessage: response['professionalMessage'],
            quickActions: List<String>.from(response['quickActions'] ?? []),
          ));
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(_ChatMessage(
            content: 'Je rencontre un problème de connexion. Réessaie dans un moment. 🌐',
            isUser: false,
            time: DateTime.now(),
          ));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Center(child: Text('🧠', style: TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mindo', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w800)),
                Text('Assistant bien-être · IA',
                    style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted)),
              ],
            ),
          ],
        ),
        actions: [
          if (_hasStarted)
            IconButton(
              icon: const Icon(Icons.refresh_outlined, color: AppColors.onSurfaceMuted),
              tooltip: 'Nouvelle conversation',
              onPressed: _confirmReset,
            ),
        ],
      ),
      body: Column(
        children: [
          // Confidentiality banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.primary.withValues(alpha: 0.08),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Conversation confidentielle — Mindo ne partage rien avec personne',
                  style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),

          // Messages area
          Expanded(
            child: !_hasStarted
                ? _WelcomeView(onStarterTapped: (text, ctx) => _sendMessage(text, userCtx: ctx))
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == _messages.length) return _TypingIndicator(controller: _typingController);
                      return _MessageBubble(
                        message: _messages[i],
                        onQuickAction: (action) => _sendMessage(action),
                      );
                    },
                  ),
          ),

          // Input bar
          _InputBar(
            ctrl: _inputCtrl,
            isTyping: _isTyping,
            onSend: () => _sendMessage(_inputCtrl.text),
          ),
        ],
      ),
    );
  }

  void _confirmReset() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelle conversation'),
        content: const Text('Effacer cette conversation et recommencer ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiService().clearAssistantSession();
              setState(() { _messages.clear(); _hasStarted = false; });
            },
            child: const Text('Recommencer'),
          ),
        ],
      ),
    );
  }
}

// ─── Welcome View ─────────────────────────────────────────────────────────────
class _WelcomeView extends StatelessWidget {
  final Function(String, Map<String, dynamic>?) onStarterTapped;
  const _WelcomeView({required this.onStarterTapped});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: const Center(child: Text('🧠', style: TextStyle(fontSize: 40))),
          ),
          const SizedBox(height: 20),
          Text('Bonjour, je suis Mindo 👋', style: AppTextStyles.h2, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(
            'Ton assistant bien-être personnel. Je suis là pour t\'écouter, t\'aider à gérer le stress, l\'anxiété et les difficultés de la vie universitaire.',
            style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Je ne remplace pas un professionnel de santé, mais je peux t\'orienter si besoin.',
            style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Text('Par quoi veux-tu commencer ?', style: AppTextStyles.h4),
          const SizedBox(height: 14),
          ..._starters.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => onStarterTapped(s.$2, {'mood': s.$3}),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.lg,
                  border: Border.all(color: AppColors.divider),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
                ),
                child: Row(
                  children: [
                    Text(s.$1, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(s.$2,
                          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.onSurfaceMuted),
                  ],
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }
}

// ─── Message Bubble ───────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  final Function(String) onQuickAction;
  const _MessageBubble({required this.message, required this.onQuickAction});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                Container(
                  width: 32, height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(child: Text('🧠', style: TextStyle(fontSize: 16))),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
                  ),
                  child: Text(
                    message.content,
                    style: AppTextStyles.body.copyWith(
                      color: isUser ? Colors.white : AppColors.onSurface,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              if (isUser) const SizedBox(width: 8),
            ],
          ),

          // Time
          Padding(
            padding: EdgeInsets.only(
              top: 4,
              left: isUser ? 0 : 40,
              right: isUser ? 0 : 0,
            ),
            child: Text(
              _formatTime(message.time),
              style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted),
            ),
          ),

          // Quick actions
          if (!isUser && message.quickActions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Wrap(
                spacing: 8, runSpacing: 6,
                children: message.quickActions.map((action) => GestureDetector(
                  onTap: () => onQuickAction(action),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: AppRadius.full,
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Text(action,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary, fontWeight: FontWeight.w700)),
                  ),
                )).toList(),
              ),
            ),
          ],

          // Professional suggestion card
          if (!isUser && message.suggestProfessional) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: _ProfessionalCard(message: message.professionalMessage),
            ),
          ],

          // Medium severity gentle nudge
          if (!isUser && message.severity == 'medium' && !message.suggestProfessional) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accentOrange.withValues(alpha: 0.08),
                  borderRadius: AppRadius.md,
                  border: Border.all(color: AppColors.accentOrange.withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  const Text('💛', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Si tu te sens souvent comme ça, parler à un conseiller peut vraiment aider.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.accentOrange, fontWeight: FontWeight.w700, height: 1.4),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ─── Professional Card ────────────────────────────────────────────────────────
class _ProfessionalCard extends StatelessWidget {
  final String? message;
  const _ProfessionalCard({this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: AppRadius.lg,
        boxShadow: [BoxShadow(color: const Color(0xFFFF6B6B).withValues(alpha: 0.25), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('🏥', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Je te recommande un professionnel',
                  style: AppTextStyles.body.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            message ?? 'Ce que tu vis mérite un accompagnement professionnel. Un psychologue ou conseiller peut vraiment t\'aider. Tu n\'as pas à traverser ça seul(e).',
            style: AppTextStyles.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.9), height: 1.5),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: AppRadius.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Où trouver de l\'aide :',
                    style: AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                _helpItem('🏫', 'Service de santé universitaire (SUMP)'),
                _helpItem('📞', 'Ligne d\'écoute étudiante de ton université'),
                _helpItem('👨‍⚕️', 'Centre Médical le plus proche'),
                _helpItem('🤝', 'Parle à un professeur ou référent pédagogique'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _helpItem(String icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(children: [
      Text(icon, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 6),
      Expanded(child: Text(text,
          style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.9)))),
    ]),
  );
}

// ─── Typing Indicator ─────────────────────────────────────────────────────────
class _TypingIndicator extends StatelessWidget {
  final AnimationController controller;
  const _TypingIndicator({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('🧠', style: TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18), topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4), bottomRight: Radius.circular(18),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) => AnimatedBuilder(
                animation: controller,
                builder: (_, __) {
                  final delay = i * 0.3;
                  final value = (controller.value - delay).clamp(0.0, 1.0);
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 7, height: 7,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.3 + value * 0.7),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              )),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Input Bar ────────────────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool isTyping;
  final VoidCallback onSend;
  const _InputBar({required this.ctrl, required this.isTyping, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              maxLines: 3, minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: isTyping ? 'Mindo réfléchit...' : 'Écris ce que tu ressens...',
                hintStyle: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.lg,
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: AppTextStyles.body,
              enabled: !isTyping,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: isTyping ? null : onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: isTyping ? AppColors.divider : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: isTyping
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}