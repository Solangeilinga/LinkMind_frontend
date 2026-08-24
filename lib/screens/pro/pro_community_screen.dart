import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/theme.dart';
import '../../services/pro_api.service.dart';

class ProCommunityScreen extends StatefulWidget {
  const ProCommunityScreen({super.key});

  @override
  State<ProCommunityScreen> createState() => _ProCommunityScreenState();
}

class _ProCommunityScreenState extends State<ProCommunityScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _posts = [];
  final _composeController = TextEditingController();
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _composeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!await ProApiService().isLoggedIn()) {
      if (mounted) context.go('/pro/login');
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    try {
      final posts = await ProApiService().getCommunityFeed();
      setState(() { _posts = posts; _isLoading = false; });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _publish() async {
    final content = _composeController.text.trim();
    if (content.isEmpty) return;
    setState(() => _isPosting = true);
    try {
      await ProApiService().createCommunityPost(content, postType: 'tip');
      _composeController.clear();
      FocusScope.of(context).unfocus();
      await _load();
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Communauté', style: AppTextStyles.h3),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Bandeau d'identification (rappel : jamais anonyme ici) ─────
            Container(
              margin: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: AppRadius.md,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.badge_outlined, color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tes publications ici sont identifiées avec ton nom et ton badge professionnel — jamais anonymes.',
                      style: AppTextStyles.caption.copyWith(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),

            // ── Zone de composition ─────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.lg,
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextField(
                    controller: _composeController,
                    maxLines: 3,
                    maxLength: 1500,
                    decoration: const InputDecoration(
                      hintText: 'Partage un conseil ou un mot de soutien avec la communauté...',
                      border: InputBorder.none,
                      counterText: '',
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _isPosting ? null : _publish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.full),
                    ),
                    child: _isPosting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Publier'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Fil ──────────────────────────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _error != null
                        ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
                        : _posts.isEmpty
                            ? ListView(
                                children: [
                                  const SizedBox(height: 60),
                                  Center(
                                    child: Text(
                                      'Aucun post pour l\'instant.',
                                      style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                                itemCount: _posts.length,
                                itemBuilder: (context, index) => _PostCard(post: _posts[index] as Map<String, dynamic>),
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final author = post['author'] as Map<String, dynamic>?;
    final isProfessional = author?['isProfessional'] == true;
    final displayName = isProfessional
        ? (author?['name'] as String? ?? 'Professionnel partenaire')
        : (author?['anonymousAlias'] as String? ?? 'Anonyme');
    final content = post['content'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(
          color: isProfessional ? AppColors.primary.withValues(alpha: 0.3) : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(displayName, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
              if (isProfessional) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: AppRadius.full,
                  ),
                  child: const Text(
                    'Professionnel',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(content, style: AppTextStyles.body),
        ],
      ),
    );
  }
}
