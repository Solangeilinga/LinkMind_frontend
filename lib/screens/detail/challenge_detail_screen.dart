import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../utils/theme.dart';
import '../../providers/content_provider.dart';
import '../../models/challenge.dart';
import '../../services/api.service.dart';

class ChallengeDetailScreen extends ConsumerStatefulWidget {
  final String challengeId;
  const ChallengeDetailScreen({super.key, required this.challengeId});

  @override
  ConsumerState<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends ConsumerState<ChallengeDetailScreen>
    with SingleTickerProviderStateMixin {

  Challenge? _challenge;
  bool _isLoading = true;
  String? _error;
  
  bool _isStarted = false;
  bool _isCompleting = false;
  bool _isCompleted = false;
  bool _allStepsDone = false;
  int _currentStep = 0;
  Timer? _stepTimer;
  int _secondsLeft = 0;
  bool _timerRunning = false;
  
  final TextEditingController _reflectionController = TextEditingController();
  
  late AnimationController _checkController;
  late Animation<double> _checkScale;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 400)
    );
    _checkScale = CurvedAnimation(parent: _checkController, curve: Curves.elasticOut);
    _loadChallenge();
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _checkController.dispose();
    _reflectionController.dispose();
    super.dispose();
  }

  Future<void> _loadChallenge() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final response = await ApiService().get('/challenges/${widget.challengeId}');
      final challengeData = response['challenge'];
      
      // ✅ CORRECTION: Convertir en Challenge object
      final challenge = Challenge.fromJson(challengeData as Map<String, dynamic>);
      final isCompleted = challengeData['isCompleted'] ?? false;
      
      setState(() {
        _challenge = challenge;
        _isCompleted = isCompleted;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _startChallenge() {
    setState(() { 
      _isStarted = true; 
      _currentStep = 0; 
      _allStepsDone = false; 
    });
    _startStepTimer();
  }

  void _startStepTimer() {
    final stepDuration = _challenge?.completionType.config['stepDuration'] ?? 30;
    _stepTimer?.cancel();
    setState(() {
      _secondsLeft = stepDuration;
      _timerRunning = true;
    });
    _stepTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() { _secondsLeft--; });
      if (_secondsLeft <= 0) {
        t.cancel();
        final instructions = _challenge?.instructions ?? [];
        if (instructions.isNotEmpty && _currentStep >= instructions.length - 1) {
          setState(() { _timerRunning = false; _allStepsDone = true; });
        } else {
          setState(() => _timerRunning = false);
        }
      }
    });
  }

  void _pauseResumeTimer() {
    if (_timerRunning) {
      _stepTimer?.cancel();
      setState(() => _timerRunning = false);
    } else {
      if (_secondsLeft > 0) {
        setState(() => _timerRunning = true);
        _stepTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted) { t.cancel(); return; }
          setState(() { _secondsLeft--; });
          if (_secondsLeft <= 0) {
            t.cancel();
            final instructions = _challenge?.instructions ?? [];
            if (instructions.isNotEmpty && _currentStep >= instructions.length - 1) {
              setState(() { _timerRunning = false; _allStepsDone = true; });
            } else {
              setState(() => _timerRunning = false);
            }
          }
        });
      }
    }
  }

  void _nextStep(int total) {
    _stepTimer?.cancel();
    if (_currentStep < total - 1) {
      setState(() { _currentStep++; });
      _startStepTimer();
    }
  }

  void _resetChallenge() {
    _stepTimer?.cancel();
    setState(() { 
      _isStarted = false; 
      _currentStep = 0; 
      _secondsLeft = 0; 
      _timerRunning = false; 
      _allStepsDone = false; 
    });
  }

  Future<void> _completeChallenge({String? reflection}) async {
  if (_isCompleted || _isCompleting) return;

  _stepTimer?.cancel();
  setState(() => _isCompleting = true);

  try {
  final apiService = ApiService();
  final result = await apiService.completeChallenge(
    widget.challengeId,
    reflection: reflection,
  );

  if (!mounted) return;

  setState(() {
    _isCompleted = true;
    _isCompleting = false;
  });

  _checkController.forward();

  await Future.delayed(const Duration(milliseconds: 600));

  if (!mounted) return;
  _showSuccessSheet(result);

} catch (e) {
  if (!mounted) return;

  setState(() => _isCompleting = false);

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Une erreur est survenue'),
      backgroundColor: AppColors.accent,
    ),
  );
}
}

 

  void _showSuccessSheet(Map<String, dynamic> result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (sheetContext) => _SuccessSheet(
        result: result,
        challenge: _challenge!,
        onDone: () {
          Navigator.of(sheetContext).pop();
          if (context.mounted) {
            context.go('/challenges');
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    
    if (_error != null || _challenge == null) {
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('😕', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(_error ?? 'Défi introuvable', style: AppTextStyles.h3, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () => context.pop(), child: const Text('Retour')),
            ],
          ),
        ),
      );
    }

    final challenge = _challenge!;
    final completionType = challenge.completionType.type;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  color: _getCategoryColor(),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    ScaleTransition(
                      scale: _checkScale,
                      child: Text(
                        _isCompleted ? '✅' : challenge.icon,
                        style: const TextStyle(fontSize: 56),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isCompleted ? 'Défi accompli !' : challenge.title,
                      style: AppTextStyles.h3.copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8, runSpacing: 6,
                    children: [
                      _MetaBadge(label: challenge.category, color: _getCategoryColor()),
                      _MetaBadge(label: '${challenge.durationMinutes} min', color: AppColors.onSurfaceMuted),
                      _MetaBadge(label: '+${challenge.points} pts', color: AppColors.primary),
                      _MetaBadge(
                        label: _getTypeLabel(completionType),
                        color: AppColors.accentOrange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Text(
                    challenge.description,
                    style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted, height: 1.6),
                  ),
                  const SizedBox(height: 24),

                  if (challenge.instructions.isNotEmpty) ...[
                    const Text('Comment faire', style: AppTextStyles.h3),
                    const SizedBox(height: 12),
                    
                    if (completionType == 'timer') 
                      _buildTimerContent(challenge)
                    else if (completionType == 'reflection')
                      _buildReflectionContent(challenge)
                    else
                      _buildSimpleActionContent(challenge),
                  ],

                  if (_isCompleted)
                    _buildCompletedWidget()
                  else if (completionType == 'reflection' && !_isStarted)
                    _buildReflectionButton(challenge)
                  else if (!_isStarted)
                    _buildStartButton()
                  else if (completionType == 'timer')
                    _buildTimerButtons(challenge)
                  else
                    _buildSimpleActionButtons(),

                  SizedBox(height: MediaQuery.of(context).padding.bottom + 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerContent(Challenge challenge) {
    final instructions = challenge.instructions;
    
    if (!_isStarted) {
      return Column(
        children: instructions.asMap().entries.map((e) => _StepTile(
          number: e.key + 1,
          text: e.value,
          isActive: false,
          isDone: false,
          accentColor: _getCategoryColor(),
          stepDuration: challenge.completionType.config['stepDuration'] ?? 30,
        )).toList(),
      );
    }
    
    return Column(
      children: [
        _StepTimerWidget(
          secondsLeft: _secondsLeft,
          totalSeconds: challenge.completionType.config['stepDuration'] ?? 30,
          isRunning: _timerRunning,
          accentColor: _getCategoryColor(),
          onPauseResume: _pauseResumeTimer,
        ),
        const SizedBox(height: 16),
        ...instructions.asMap().entries.map((e) => _StepTile(
          number: e.key + 1,
          text: e.value,
          isActive: e.key == _currentStep,
          isDone: e.key < _currentStep,
          accentColor: _getCategoryColor(),
          stepDuration: challenge.completionType.config['stepDuration'] ?? 30,
          onTap: e.key == _currentStep && !_timerRunning && _secondsLeft == 0
              ? () => _nextStep(instructions.length)
              : null,
        )),
      ],
    );
  }

  Widget _buildReflectionContent(Challenge challenge) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...challenge.instructions.asMap().entries.map((e) => _StepTile(
          number: e.key + 1,
          text: e.value,
          isActive: false,
          isDone: false,
          accentColor: _getCategoryColor(),
          stepDuration: 0,
        )),
        const SizedBox(height: 16),
        TextField(
  controller: _reflectionController,
  maxLines: 6,
  minLines: 4,
  decoration: InputDecoration(
    hintText: challenge.completionType.config['inputPlaceholder'] ?? 
        'Écris ta réflexion ici...',
    border: const OutlineInputBorder(
      borderRadius: AppRadius.md,
      borderSide: BorderSide(color: AppColors.divider),
    ),
    enabledBorder: const OutlineInputBorder(
      borderRadius: AppRadius.md,
      borderSide: BorderSide(color: AppColors.divider),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: AppRadius.md,
      borderSide: BorderSide(color: AppColors.primary),
    ),
  ),
)
      ],
    );
  }

  Widget _buildSimpleActionContent(Challenge challenge) {
    return Column(
      children: challenge.instructions.asMap().entries.map((e) => _StepTile(
        number: e.key + 1,
        text: e.value,
        isActive: false,
        isDone: false,
        accentColor: _getCategoryColor(),
        stepDuration: 0,
      )).toList(),
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _startChallenge,
        icon: const Icon(Icons.play_arrow_rounded, size: 22),
        label: const Text('Commencer le défi'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _getCategoryColor(),
          minimumSize: const Size.fromHeight(54),
        ),
      ),
    );
  }

  Widget _buildReflectionButton(Challenge challenge) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isCompleting
            ? null
            : () => _completeChallenge(reflection: _reflectionController.text.trim()),
        icon: _isCompleting
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.check_circle_rounded, size: 22),
        label: Text(_isCompleting ? 'Enregistrement...' : 'Terminer le défi ✅'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          minimumSize: const Size.fromHeight(54),
        ),
      ),
    );
  }

  Widget _buildTimerButtons(Challenge challenge) {
    final instructions = challenge.instructions;
    
    return Column(
      children: [
        if (instructions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: AppRadius.full,
                    child: LinearProgressIndicator(
                      value: (_currentStep + 1) / instructions.length,
                      color: _getCategoryColor(),
                      backgroundColor: _getCategoryColor().withValues(alpha: 0.15),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${_currentStep + 1}/${instructions.length}',
                  style: AppTextStyles.caption.copyWith(
                    color: _getCategoryColor(), 
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

        if (_currentStep < instructions.length - 1)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_secondsLeft == 0 && !_timerRunning)
                  ? () => _nextStep(instructions.length)
                  : null,
              icon: const Icon(Icons.arrow_forward_rounded, size: 20),
              label: Text(_secondsLeft > 0
                  ? 'Attends la fin du timer...'
                  : 'Étape suivante (${_currentStep + 2}/${instructions.length})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getCategoryColor(),
                minimumSize: const Size.fromHeight(54),
              ),
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_allStepsDone && !_timerRunning && !_isCompleting)
                  ? () => _completeChallenge()
                  : null,
              icon: _isCompleting
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_rounded, size: 22),
              label: Text(
                _isCompleting
                    ? 'Enregistrement...'
                    : !_allStepsDone
                        ? (_secondsLeft > 0 ? 'Attends... (${_secondsLeft}s)' : 'Complète toutes les étapes')
                        : 'Terminer le défi ✅',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                minimumSize: const Size.fromHeight(54),
              ),
            ),
          ),

        const SizedBox(height: 10),
        TextButton(
          onPressed: _resetChallenge,
          child: Text(
            'Recommencer depuis le début',
            style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted),
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleActionButtons() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isCompleting ? null : () => _completeChallenge(),
        icon: _isCompleting
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.check_circle_rounded, size: 22),
        label: Text(_isCompleting ? 'Enregistrement...' : 'Marquer comme terminé ✅'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          minimumSize: const Size.fromHeight(54),
        ),
      ),
    );
  }

  Widget _buildCompletedWidget() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.1),
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
      ),
      child: const Column(
        children: [
          Text('✅', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(
            'Défi accompli aujourd\'hui !',
            style: AppTextStyles.h4,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Reviens demain pour le refaire',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor() {
    final contentState = ref.watch(contentProvider);
    final category = contentState.challengeCategories.firstWhere(
      (c) => c.id == _challenge?.category,
      orElse: () => const ChallengeCategoryDef(
        id: '', label: '', emoji: '', colorHex: '77021D'
      ),
    );
    if (category.colorHex.isNotEmpty) {
      return Color(int.parse('FF${category.colorHex.replaceFirst('#', '')}', radix: 16));
    }
    return AppColors.primary;
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'timer': return '⏱️ Chronométré';
      case 'reflection': return '💭 Réflexion';
      case 'social': return '👥 Social';
      case 'exploration': return '🔍 Découverte';
      default: return '⚡ Action simple';
    }
  }
}

// ─── Step Timer Widget ─────────────────────────────────────────────────────────
class _StepTimerWidget extends StatelessWidget {
  final int secondsLeft;
  final int totalSeconds;
  final bool isRunning;
  final Color accentColor;
  final VoidCallback onPauseResume;

  const _StepTimerWidget({
    required this.secondsLeft,
    required this.totalSeconds,
    required this.isRunning,
    required this.accentColor,
    required this.onPauseResume,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalSeconds > 0 ? secondsLeft / totalSeconds : 0.0;
    final isDone = secondsLeft == 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDone
            ? AppColors.secondary.withValues(alpha: 0.08)
            : accentColor.withValues(alpha: 0.08),
        borderRadius: AppRadius.lg,
        border: Border.all(
          color: isDone
              ? AppColors.secondary.withValues(alpha: 0.4)
              : accentColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56, height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  color: isDone ? AppColors.secondary : accentColor,
                  backgroundColor: accentColor.withValues(alpha: 0.15),
                  strokeWidth: 4,
                ),
                Text(
                  isDone ? '✓' : '$secondsLeft',
                  style: TextStyle(
                    fontSize: isDone ? 20 : 14,
                    fontWeight: FontWeight.w900,
                    color: isDone ? AppColors.secondary : accentColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDone ? 'Étape terminée !' : isRunning ? 'En cours...' : 'En pause',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDone ? AppColors.secondary : accentColor,
                  ),
                ),
                Text(
                  isDone
                      ? 'Passe à l\'étape suivante →'
                      : 'Reste ${secondsLeft}s sur cette étape',
                  style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted),
                ),
              ],
            ),
          ),
          if (!isDone)
            GestureDetector(
              onTap: onPauseResume,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: accentColor,
                  size: 22,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Step Tile ─────────────────────────────────────────────────────────────────
class _StepTile extends StatelessWidget {
  final int number;
  final String text;
  final bool isActive;
  final bool isDone;
  final Color accentColor;
  final int stepDuration;
  final VoidCallback? onTap;

  const _StepTile({
    required this.number,
    required this.text,
    required this.isActive,
    required this.isDone,
    required this.accentColor,
    required this.stepDuration,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDone
              ? AppColors.secondary.withValues(alpha: 0.06)
              : isActive
                  ? accentColor.withValues(alpha: 0.1)
                  : AppColors.surfaceVariant,
          borderRadius: AppRadius.md,
          border: Border.all(
            color: isDone
                ? AppColors.secondary.withValues(alpha: 0.4)
                : isActive ? accentColor : Colors.transparent,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: isDone ? AppColors.secondary : isActive ? accentColor : AppColors.divider,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : Text(
                        '$number',
                        style: AppTextStyles.caption.copyWith(
                          color: isActive ? Colors.white : AppColors.onSurfaceMuted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: AppTextStyles.body.copyWith(
                      color: isDone ? AppColors.onSurfaceMuted : AppColors.onSurface,
                      height: 1.4,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (isActive && stepDuration > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '⏱ ${stepDuration}s pour cette étape',
                      style: AppTextStyles.caption.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Meta badge ───────────────────────────────────────────────────────────────
class _MetaBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _MetaBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: AppRadius.full,
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(
      label,
      style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w800),
    ),
  );
}

// ─── Success sheet ────────────────────────────────────────────────────────────
class _SuccessSheet extends StatelessWidget {
  final Map<String, dynamic> result;
  final Challenge challenge;
  final VoidCallback onDone;

  const _SuccessSheet({
    required this.result,
    required this.challenge,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final newBadges = List<Map<String, dynamic>>.from(result['newBadges'] ?? []);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: AppRadius.full),
            ),
          ),
          const SizedBox(height: 20),
          const Text('🎉', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          const Text('Défi accompli !', style: AppTextStyles.h2, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Tu as terminé "${challenge.title}"',
            style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: AppRadius.full,
            ),
            child: Text(
              '⚡ +${result['pointsEarned'] ?? challenge.points} points gagnés',
              style: AppTextStyles.h4.copyWith(color: Colors.white),
            ),
          ),
          if (newBadges.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...newBadges.map((b) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accentOrange.withValues(alpha: 0.1),
                borderRadius: AppRadius.md,
                border: Border.all(color: AppColors.accentOrange.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(b['icon'] ?? '🏅', style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Text(
                    'Badge "${b['name']}" débloqué !',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.accentOrange,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            )),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(54),
              ),
              child: const Text('Super, continuer ! 🚀'),
            ),
          ),
        ],
      ),
    );
  }
}