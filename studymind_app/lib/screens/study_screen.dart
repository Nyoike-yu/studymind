import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../services/api_service.dart';
import '../widgets/glow_button.dart';
import '../widgets/step_indicator.dart';
import 'flashcard_screen.dart';
import 'quiz_screen.dart';

class StudyScreen extends StatefulWidget {
  final String sessionId;
  const StudyScreen({super.key, required this.sessionId});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  int _step = 0; // 0=idle, 1=analyzed, 2=summarized, 3=generated
  bool _loading = false;
  String _loadingLabel = '';
  String? _error;

  // Data
  Map<String, dynamic>? _plan;
  String? _summary;
  List<dynamic> _flashcards = [];
  List<dynamic> _quiz = [];

  Future<void> _runStep() async {
    try {
      if (_step == 0) {
        setState(() { _loading = true; _error = null; _loadingLabel = 'Analyzing content...'; });
        final res = await ApiService.analyze(widget.sessionId);
        setState(() { _plan = res['study_plan']; _step = 1; });
      } else if (_step == 1) {
        setState(() { _loading = true; _error = null; _loadingLabel = 'Writing summary...'; });
        final res = await ApiService.summarize(widget.sessionId);
        setState(() { _summary = res['summary']; _step = 2; });
      } else if (_step == 2) {
        setState(() { _loading = true; _error = null; _loadingLabel = 'Generating flashcards & quiz...'; });
        final res = await ApiService.generate(widget.sessionId);
        setState(() {
          _flashcards = res['flashcards'] ?? [];
          _quiz = res['quiz'] ?? [];
          _step = 3;
        });
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  String get _nextLabel {
    switch (_step) {
      case 0: return '🔍  Analyze Content';
      case 1: return '📝  Generate Summary';
      case 2: return '🃏  Create Flashcards & Quiz';
      default: return '';
    }
  }

  // StepIndicator expects: 0=Analyze active, 1=Summarize active ...
  // _step 0 means nothing done yet → show step 0 as active
  // _step 1 means analyze done → show step 1 as active
  int get _indicatorStep => _step;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('StudyMind', style: GoogleFonts.spaceGrotesk(
          color: AppColors.textPrimary, fontWeight: FontWeight.w700,
        )),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step progress
              StepIndicator(currentStep: _indicatorStep),
              const SizedBox(height: 32),

              // Loading shimmer
              if (_loading) _LoadingCard(label: _loadingLabel),

              // Error
              if (_error != null && !_loading)
                _ErrorCard(message: _error!),

              // Step 1: Study Plan
              if (_step >= 1 && _plan != null && !_loading) ...[
                _SectionHeader('📋 Study Plan', subtitle: _plan!['topic'] ?? ''),
                const SizedBox(height: 16),
                _ConceptChips(concepts: List<String>.from(_plan!['key_concepts'] ?? [])),
                const SizedBox(height: 16),
                _MilestoneList(milestones: List<String>.from(_plan!['milestones'] ?? [])),
                const SizedBox(height: 24),
              ],

              // Step 2: Summary
              if (_step >= 2 && _summary != null && !_loading) ...[
                _SectionHeader('📝 Summary'),
                const SizedBox(height: 12),
                _SummaryCard(text: _summary!),
                const SizedBox(height: 24),
              ],

              // Step 3: Actions
              if (_step >= 3 && !_loading) ...[
                _SectionHeader('🎯 Ready to Study'),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.style,
                      label: 'Flashcards',
                      count: _flashcards.length,
                      color: AppColors.purple,
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => FlashcardScreen(flashcards: _flashcards),
                      )),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.quiz,
                      label: 'Take Quiz',
                      count: _quiz.length,
                      color: AppColors.accent,
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => QuizScreen(
                          sessionId: widget.sessionId,
                          questions: _quiz,
                        ),
                      )),
                    ),
                  ),
                ]),
                const SizedBox(height: 24),
              ],

              // Next step button
              if (_step < 3 && !_loading)
                GlowButton(
                  label: _nextLabel,
                  onTap: _runStep,
                ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader(this.title, {this.subtitle = ''});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: GoogleFonts.spaceGrotesk(
        color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700,
      )),
      if (subtitle.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(subtitle, style: GoogleFonts.inter(
          color: AppColors.purpleLight, fontSize: 13,
        )),
      ],
    ]).animate().fadeIn().slideX(begin: -0.05);
  }
}

class _ConceptChips extends StatelessWidget {
  final List<String> concepts;
  const _ConceptChips({required this.concepts});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: concepts.map((c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.purpleGlow.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.purple.withOpacity(0.4)),
        ),
        child: Text(c, style: GoogleFonts.inter(
          color: AppColors.purpleLight, fontSize: 12, fontWeight: FontWeight.w500,
        )),
      )).toList(),
    ).animate().fadeIn(delay: 100.ms);
  }
}

class _MilestoneList extends StatelessWidget {
  final List<String> milestones;
  const _MilestoneList({required this.milestones});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: milestones.asMap().entries.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.purple.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.purple.withOpacity(0.5)),
            ),
            child: Center(child: Text('${e.key + 1}', style: GoogleFonts.inter(
              color: AppColors.purpleLight, fontSize: 11, fontWeight: FontWeight.w700,
            ))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(e.value, style: GoogleFonts.inter(
            color: AppColors.textPrimary, fontSize: 14, height: 1.5,
          ))),
        ]),
      )).toList(),
    ).animate().fadeIn(delay: 150.ms);
  }
}

class _SummaryCard extends StatelessWidget {
  final String text;
  const _SummaryCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(text, style: GoogleFonts.inter(
        color: AppColors.textPrimary, fontSize: 14, height: 1.7,
      )),
    ).animate().fadeIn(delay: 100.ms);
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({
    required this.icon, required this.label,
    required this.count, required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(label, style: GoogleFonts.spaceGrotesk(
            color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700,
          )),
          const SizedBox(height: 4),
          Text('$count items', style: GoogleFonts.inter(
            color: AppColors.textSecondary, fontSize: 12,
          )),
        ]),
      ),
    ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.95, 0.95));
  }
}

class _LoadingCard extends StatelessWidget {
  final String label;
  const _LoadingCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.purple.withOpacity(0.3)),
      ),
      child: Row(children: [
        SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.purple,
          ),
        ),
        const SizedBox(width: 16),
        Text(label, style: GoogleFonts.inter(
          color: AppColors.textSecondary, fontSize: 14,
        )),
      ]),
    ).animate().fadeIn();
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: GoogleFonts.inter(
          color: AppColors.error, fontSize: 13,
        ))),
      ]),
    );
  }
}
