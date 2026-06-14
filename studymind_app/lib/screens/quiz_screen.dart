import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../theme.dart';
import '../services/api_service.dart';
import '../widgets/glow_button.dart';

class QuizScreen extends StatefulWidget {
  final String sessionId;
  final List<dynamic> questions;
  const QuizScreen({super.key, required this.sessionId, required this.questions});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final Map<int, int> _answers = {};
  bool _submitted = false;
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  Future<void> _submit() async {
    if (_answers.length < widget.questions.length) {
      setState(() => _error = 'Please answer all questions before submitting');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final answerList = List.generate(
        widget.questions.length, (i) => _answers[i] ?? 0,
      );
      final result = await ApiService.submitQuiz(widget.sessionId, answerList);
      setState(() { _result = result; _submitted = true; });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_submitted ? 'Results' : 'Quiz',
          style: GoogleFonts.spaceGrotesk(
            color: AppColors.textPrimary, fontWeight: FontWeight.w700,
          )),
      ),
      body: SafeArea(
        child: _submitted && _result != null
            ? _ResultsView(result: _result!)
            : _QuizView(
                questions: widget.questions,
                answers: _answers,
                loading: _loading,
                error: _error,
                onAnswer: (qi, ai) => setState(() => _answers[qi] = ai),
                onSubmit: _submit,
              ),
      ),
    );
  }
}

class _QuizView extends StatelessWidget {
  final List<dynamic> questions;
  final Map<int, int> answers;
  final bool loading;
  final String? error;
  final void Function(int, int) onAnswer;
  final VoidCallback onSubmit;

  const _QuizView({
    required this.questions, required this.answers,
    required this.loading, required this.error,
    required this.onAnswer, required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${questions.length} Questions',
            style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),

          ...questions.asMap().entries.map((e) {
            final i = e.key;
            final q = e.value;
            final options = List<String>.from(q['options'] ?? []);
            return _QuestionCard(
              index: i,
              question: q['question'] ?? '',
              options: options,
              selected: answers[i],
              onSelect: (ai) => onAnswer(i, ai),
            ).animate().fadeIn(delay: (i * 100).ms);
          }),

          if (error != null)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Text(error!, style: GoogleFonts.inter(
                color: AppColors.error, fontSize: 13,
              )),
            ),

          GlowButton(
            label: loading ? 'Evaluating...' : 'Submit Quiz →',
            loading: loading,
            onTap: loading ? null : onSubmit,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final int index;
  final String question;
  final List<String> options;
  final int? selected;
  final void Function(int) onSelect;

  const _QuestionCard({
    required this.index, required this.question,
    required this.options, required this.selected, required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.purple.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('Q${index + 1}', style: GoogleFonts.inter(
              color: AppColors.purpleLight, fontSize: 11, fontWeight: FontWeight.w700,
            )),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(question, style: GoogleFonts.inter(
            color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600, height: 1.5,
          ))),
        ]),
        const SizedBox(height: 16),
        ...options.asMap().entries.map((e) {
          final isSelected = selected == e.key;
          return GestureDetector(
            onTap: () => onSelect(e.key),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.purple.withOpacity(0.15) : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? AppColors.purple : AppColors.divider,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Text(e.value, style: GoogleFonts.inter(
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 13, height: 1.4,
              )),
            ),
          );
        }),
      ]),
    );
  }
}

class _ResultsView extends StatelessWidget {
  final Map<String, dynamic> result;
  const _ResultsView({required this.result});

  @override
  Widget build(BuildContext context) {
    final pct = (result['percentage'] as num).toDouble();
    final score = result['score'] as int;
    final total = result['total'] as int;
    final weakAreas = List<String>.from(result['weak_areas'] ?? []);
    final feedback = result['feedback'] as String? ?? '';

    final color = pct >= 80
        ? AppColors.success
        : pct >= 60
            ? AppColors.warning
            : AppColors.error;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score circle
          Center(
            child: CircularPercentIndicator(
              radius: 80,
              lineWidth: 10,
              percent: pct / 100,
              center: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('${pct.toStringAsFixed(0)}%',
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w700,
                  )),
                Text('$score / $total', style: GoogleFonts.inter(
                  color: AppColors.textSecondary, fontSize: 13,
                )),
              ]),
              progressColor: color,
              backgroundColor: AppColors.divider,
              circularStrokeCap: CircularStrokeCap.round,
            ).animate().scale(delay: 100.ms),
          ),

          const SizedBox(height: 32),

          // Feedback
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.purple.withOpacity(0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('🤖', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text('Agent Feedback', style: GoogleFonts.spaceGrotesk(
                  color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700,
                )),
              ]),
              const SizedBox(height: 12),
              Text(feedback, style: GoogleFonts.inter(
                color: AppColors.textPrimary, fontSize: 14, height: 1.7,
              )),
            ]),
          ).animate().fadeIn(delay: 200.ms),

          if (weakAreas.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('🎯 Areas to Review', style: GoogleFonts.spaceGrotesk(
              color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700,
            )),
            const SizedBox(height: 12),
            ...weakAreas.map((area) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.error.withOpacity(0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.refresh, color: AppColors.error, size: 16),
                const SizedBox(width: 10),
                Expanded(child: Text(area, style: GoogleFonts.inter(
                  color: AppColors.textPrimary, fontSize: 13,
                ))),
              ]),
            )).toList(),
          ],

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
              child: const Text('Start a New Topic'),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
