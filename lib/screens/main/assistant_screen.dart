import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/theme.dart';
import '../../utils/icon_mapper.dart';
import '../../services/api.service.dart';
import '../../services/chat_history_service.dart';

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

// ─── Starter prompt model ─────────────────────────────────────────────────────
class _Starter {
  final String emoji, text, context;
  const _Starter(this.emoji, this.text, this.context);
}

const _defaultStarters = [
  _Starter('🌟', "Je veux prendre soin de moi", 'neutral'),
  _Starter('💪', "Comment rester motivé(e) ?", 'neutral'),
  _Starter('🧘', "J'aimerais apprendre à gérer mon stress", 'neutral'),
  _Starter('📚', "Conseils pour les révisions et l'étude", 'neutral'),
  _Starter('💚', "Je cherche du soutien et des encouragements", 'neutral'),
  _Starter('🎯', "Comment mieux organiser ma journée ?", 'neutral'),
];

// ─── Assistant Screen ──────────────────────────────────────────────────────────
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});
  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen>
    with TickerProviderStateMixin {
  final List<_ChatMessage> _messages = [];
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _chatHistoryService = ChatHistoryService();
  bool _isTyping = false;
  bool _hasStarted = false;
  Map<String, dynamic>? _userContext;
  int _messagesUsed = 0;
  List<_Starter> _starters = _defaultStarters;
  int _messagesLimit = 10;
  bool _isPremium = false;
  bool _limitReached = false;

  late AnimationController _typingController;

  @override
  void initState() {
    super.initState();
    _typingController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _loadStarters();
    _loadHistoryAndContext();
  }

  Future<void> _loadHistoryAndContext() async {
    try {
      // Charger le contexte utilisateur persistant
      final context = await _chatHistoryService.getUserContext();
      if (context.isNotEmpty && mounted) {
        setState(() => _userContext = context);
        debugPrint('📚 Contexte utilisateur chargé: $context');
      }

      // Optionnel: charger les messages précédents
      final history = await _chatHistoryService.getHistory();
      if (history.isNotEmpty && mounted) {
        setState(() {
          _hasStarted = true;
          for (final msg in history) {
            _messages.add(_ChatMessage(
              content: msg['content'] as String? ?? '',
              isUser: (msg['role'] as String?) == 'user',
              time: DateTime.tryParse(msg['timestamp'] as String? ?? '') ??
                  DateTime.now(),
            ));
          }
        });
        _scrollToBottom();
        debugPrint('📚 ${history.length} messages chargés de l\'historique');
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement historique: $e');
    }
  }

  @override
  void dispose() {
    _typingController.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStarters() async {
    try {
      final data = await ApiService().getAssistantStarters();
      final list = data['starters'] as List? ?? [];
      if (list.isNotEmpty && mounted) {
        setState(() {
          _starters = list
              .map((s) => _Starter(
                    s['emoji'] ?? '💭',
                    s['text'] ?? '',
                    s['context'] ?? 'neutral',
                  ))
              .toList();
        });
      }
    } catch (_) {} // garde les defaults
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted && _scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text,
      {Map<String, dynamic>? userCtx}) async {
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

    // 💾 Sauvegarde du message utilisateur dans l'historique
    await _chatHistoryService.addMessage('user', text.trim());

    _scrollToBottom();

    try {
      // Affiche ce qui est envoyé
      debugPrint('📤 Envoi message: "$text", contexte: $userCtx');

      final response = await ApiService().chatWithAssistant(
        message: text.trim(),
        context: userCtx ?? _userContext,
      );

      if (!mounted) return;

      // 🔍 Log complet de la réponse pour analyse
      debugPrint('📦 Réponse API brute: $response');
      debugPrint('📦 Type de response: ${response.runtimeType}');
      debugPrint('📦 Clés de la réponse: ${response.keys}');
    
      // Extraction ultra-robuste
      String aiMessage = '';
      Map<String, dynamic>? data;

      // Cas 1 : réponse avec 'data'
      if (response.containsKey('data') && response['data'] is Map) {
        data = response['data'] as Map<String, dynamic>;
        debugPrint('📂 Data trouvée: $data');
        aiMessage = data['message'] as String? ?? '';
      }
      // Cas 2 : réponse directe (certaines versions)
      else if (response.containsKey('message')) {
        data = response;
        aiMessage = response['message'] as String? ?? '';
      }
      // Cas 3 : réponse inattendue, on parcourt toutes les clés
      else {
        debugPrint('⚠️ Structure inattendue, recherche d\'un champ texte...');
        for (var key in response.keys) {
          if (key.toLowerCase().contains('message') ||
              key.toLowerCase().contains('reply') ||
              key.toLowerCase().contains('response') ||
              key.toLowerCase().contains('text')) {
            aiMessage = response[key].toString();
            debugPrint('✅ Trouvé dans clé "$key": $aiMessage');
            break;
          }
        }
      }

      // Si toujours vide, dernier recours
      if (aiMessage.isEmpty && data != null) {
        // Cherche parmi les clés secondaires
        aiMessage = data['reply'] as String? ??
            data['response'] as String? ??
            data['text'] as String? ??
            '';
      }

      debugPrint('📝 Message final extrait: "$aiMessage"');

      // Métadonnées
      final severity = data?['severity'] as String?;
      final suggestProfessional = data?['suggestProfessional'] == true;
      final professionalMessage = data?['professionalMessage'] as String?;
      final quickActions = List<String>.from(data?['quickActions'] ?? []);
      final messagesUsed = data?['messagesUsed'] as int? ?? _messagesUsed;
      final messagesLimit = data?['messagesLimit'] as int? ?? _messagesLimit;
      final isPremium = data?['isPremium'] as bool? ?? _isPremium;

      // 💾 Sauvegarde du message AI et mise à jour du contexte
      final finalMessage = aiMessage.isNotEmpty
          ? aiMessage
          : "Je suis là pour toi. Peux-tu reformuler ? 💚";
      await _chatHistoryService
          .addMessage('assistant', finalMessage, metadata: {
        'severity': severity,
        'suggestProfessional': suggestProfessional,
        'professionalMessage': professionalMessage,
      });

      // 💾 Mise à jour du contexte utilisateur avec les infos de la requête
      if (userCtx != null || data?['userContextUpdate'] != null) {
        final contextUpdate = userCtx ?? data?['userContextUpdate'] ?? {};
        await _chatHistoryService.updateUserContext(contextUpdate);
        if (mounted) {
          setState(() => _userContext = contextUpdate);
        }
      }

      setState(() {
        _isTyping = false;
        _messagesUsed = messagesUsed;
        _messagesLimit = messagesLimit;
        _isPremium = isPremium;
        _limitReached = !isPremium && messagesUsed >= messagesLimit;

        _messages.add(_ChatMessage(
          content: aiMessage.isNotEmpty
              ? aiMessage
              : "Je suis là pour toi. Peux-tu reformuler ? 💚",
          isUser: false,
          time: DateTime.now(),
          severity: severity,
          suggestProfessional: suggestProfessional,
          professionalMessage: professionalMessage,
          quickActions: quickActions,
        ));
      });
      _scrollToBottom();
    } on ApiException catch (e) {
      debugPrint('❌ ApiException: ${e.message}, status: ${e.statusCode}');
      if (mounted) {
        setState(() => _isTyping = false);
        if (e.message.contains('limit_reached') ||
            e.message.contains('limite')) {
          setState(() => _limitReached = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tu as atteint ta limite quotidienne'),
              backgroundColor: AppColors.accent,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          setState(() {
            _messages.add(_ChatMessage(
              content:
                  'Je rencontre un problème technique. Réessaie dans un instant. 🌐',
              isUser: false,
              time: DateTime.now(),
            ));
          });
          _scrollToBottom();
        }
      }
    } catch (e, stack) {
      debugPrint('❌ Exception inattendue: $e');
      debugPrint(stack.toString());
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(_ChatMessage(
            content:
                'Je rencontre un problème technique. Réessaie dans un instant. 🌐',
            isUser: false,
            time: DateTime.now(),
          ));
        });
        _scrollToBottom();
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
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                  child: Image.asset('assets/images/logo.png',
                      width: 36, height: 36, fit: BoxFit.cover)),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mindo',
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w800)),
                Text('Assistant bien-être · IA',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.onSurfaceMuted)),
              ],
            ),
          ],
        ),
        actions: [
          if (_hasStarted)
            IconButton(
              icon: const Icon(Icons.refresh_outlined,
                  color: AppColors.onSurfaceMuted),
              tooltip: 'Nouvelle conversation',
              onPressed: _confirmReset,
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.primary.withValues(alpha: 0.08),
            child: Row(
              children: [
                Icon(Icons.lock_outline,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(
                  'Conversation confidentielle — Mindo ne partage rien',
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                )),
              ],
            ),
          ),
          Expanded(
            child: !_hasStarted
                ? _WelcomeView(
                    starters: _starters,
                    onStarterTapped: (text, ctx) =>
                        _sendMessage(text, userCtx: ctx))
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == _messages.length) {
                        return _TypingIndicator(controller: _typingController);
                      }
                      return _MessageBubble(
                        message: _messages[i],
                        onQuickAction: (action) => _sendMessage(action),
                      );
                    },
                  ),
          ),
          if (_limitReached)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2))),
              child: Column(children: [
                Icon(Icons.lock, size: 32, color: AppColors.primary),
                const SizedBox(height: 8),
                Text('Limite quotidienne atteinte',
                    style: AppTextStyles.h4.copyWith(color: AppColors.primary)),
                const SizedBox(height: 4),
                Text(
                    "Tu as utilisé tes $_messagesLimit messages Mindo aujourd'hui.\nReviens demain ou passe en Premium pour des conversations illimitées.",
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.onSurfaceMuted, height: 1.5),
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Redirection vers l'écran Premium
                    },
                    icon: Icon(Icons.workspace_premium, color: Colors.white),
                    label: const Text('Passer en Premium'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        minimumSize: const Size.fromHeight(46)),
                  ),
                ),
              ]),
            ),
          if (!_limitReached)
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
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiService().clearAssistantSession();
              } catch (_) {}
              try {
                // 💾 Effacer l'historique local
                await _chatHistoryService.clearHistory();
                debugPrint('📚 Historique effacé');
              } catch (e) {
                debugPrint('❌ Erreur suppression historique: $e');
              }
              if (mounted) {
                setState(() {
                  _messages.clear();
                  _hasStarted = false;
                });
              }
            },
            child: const Text('Recommencer'),
          ),
        ],
      ),
    );
  }
}

// ─── Welcome View (inchangé) ─────────────────────────────────────────────────
class _WelcomeView extends StatelessWidget {
  final Function(String, Map<String, dynamic>?) onStarterTapped;
  final List<_Starter> starters;
  const _WelcomeView({required this.onStarterTapped, required this.starters});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: ClipOval(
                child: Image.asset('assets/images/logo.png',
                    width: 80, height: 80, fit: BoxFit.cover)),
          ),
          const SizedBox(height: 20),
          const Text('Bonjour, je suis Mindo 👋',
              style: AppTextStyles.h2, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(
            'Ton assistant bien-être personnel. Je suis là pour t\'écouter, t\'aider à gérer le stress, l\'anxiété et les difficultés de la vie universitaire.',
            style: AppTextStyles.body
                .copyWith(color: AppColors.onSurfaceMuted, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Je ne remplace pas un professionnel de santé, mais je peux t\'orienter si besoin.',
            style: AppTextStyles.caption.copyWith(
                color: AppColors.onSurfaceMuted, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          const Text('Par quoi veux-tu commencer ?', style: AppTextStyles.h4),
          const SizedBox(height: 14),
          ...starters.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => onStarterTapped(s.text, {'mood': s.context}),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.lg,
                      border: Border.all(color: AppColors.divider),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8)
                      ],
                    ),
                    child: Row(
                      children: [
                        IconMapper.getIcon(s.emoji, size: 22),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(s.text,
                              style: AppTextStyles.body
                                  .copyWith(fontWeight: FontWeight.w700)),
                        ),
                        const Icon(Icons.arrow_forward_ios,
                            size: 14, color: AppColors.onSurfaceMuted),
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

// ─── Message Bubble (inchangé) ───────────────────────────────────────────────
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
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                      child: Text('🧠', style: TextStyle(fontSize: 16))),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8)
                    ],
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
          Padding(
            padding: EdgeInsets.only(
              top: 4,
              left: isUser ? 0 : 40,
              right: isUser ? 0 : 0,
            ),
            child: Text(
              _formatTime(message.time),
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.onSurfaceMuted),
            ),
          ),
          if (!isUser && message.quickActions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: message.quickActions
                    .map((action) => GestureDetector(
                          onTap: () => onQuickAction(action),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: AppRadius.full,
                              border: Border.all(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.3)),
                            ),
                            child: Text(action,
                                style: AppTextStyles.caption.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
          if (!isUser && message.suggestProfessional) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: _ProfessionalCard(message: message.professionalMessage),
            ),
          ],
          if (!isUser &&
              message.severity == 'medium' &&
              !message.suggestProfessional) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accentOrange.withValues(alpha: 0.08),
                  borderRadius: AppRadius.md,
                  border: Border.all(
                      color: AppColors.accentOrange.withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  Icon(Icons.favorite, size: 14, color: AppColors.accentOrange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Si tu te sens souvent comme ça, parler à un conseiller peut vraiment aider.',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.accentOrange,
                          fontWeight: FontWeight.w700,
                          height: 1.4),
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

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

// ─── Professional Card (inchangé) ────────────────────────────────────────────
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
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFFF6B6B).withValues(alpha: 0.25),
              blurRadius: 12)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.local_hospital, size: 20, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Je te recommande un professionnel',
                  style: AppTextStyles.body.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            message ??
                'Ce que tu vis mérite un accompagnement professionnel. Un psychologue ou conseiller peut vraiment t\'aider. Tu n\'as pas à traverser ça seul(e).',
            style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white.withValues(alpha: 0.9), height: 1.5),
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
                    style: AppTextStyles.caption.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                _helpItem(Icons.school, 'Service de santé universitaire (SUMP)'),
                _helpItem(Icons.phone, 'Ligne d\'écoute étudiante de ton université'),
                _helpItem(Icons.local_hospital, 'Centre Médical le plus proche'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => context.go('/professionals'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                  color: Colors.white, borderRadius: AppRadius.md),
              child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.medical_information, color: AppColors.accentRed, size: 18),
                      const SizedBox(width: 6),
                      Text('Voir les professionnels LinkMind',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _helpItem(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Expanded(
              child: Text(text,
                  style: AppTextStyles.caption
                      .copyWith(color: Colors.white.withValues(alpha: 0.9)))),
        ]),
      );
}

// ─── Typing Indicator (inchangé) ─────────────────────────────────────────────
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
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
                child: Image.asset('assets/images/logo.png',
                    width: 32, height: 32, fit: BoxFit.cover)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                  3,
                  (i) => AnimatedBuilder(
                        animation: controller,
                        builder: (_, __) {
                          final delay = i * 0.3;
                          final value =
                              (controller.value - delay).clamp(0.0, 1.0);
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: AppColors.primary
                                  .withValues(alpha: 0.3 + value * 0.7),
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

// ─── Input Bar (inchangé) ────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool isTyping;
  final VoidCallback onSend;
  const _InputBar(
      {required this.ctrl, required this.isTyping, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -2))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: isTyping
                    ? 'Mindo réfléchit...'
                    : 'Écris ce que tu ressens...',
                hintStyle: AppTextStyles.body
                    .copyWith(color: AppColors.onSurfaceMuted),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: const OutlineInputBorder(
                  borderRadius: AppRadius.lg,
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isTyping ? AppColors.divider : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: isTyping
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2))
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}
