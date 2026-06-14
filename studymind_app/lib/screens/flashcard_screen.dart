import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme.dart';

class FlashcardScreen extends StatefulWidget {
  final List<dynamic> flashcards;
  const FlashcardScreen({super.key, required this.flashcards});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  bool _showBack = false;
  late AnimationController _flipCtrl;
  late Animation<double> _flipAnim;

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    super.dispose();
  }

  void _flip() {
    if (_flipCtrl.isCompleted) {
      _flipCtrl.reverse();
      setState(() => _showBack = false);
    } else {
      _flipCtrl.forward();
      setState(() => _showBack = true);
    }
  }

  void _navigate(int newIndex) {
    _flipCtrl.reset();
    setState(() {
      _index = newIndex;
      _showBack = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.flashcards[_index];

    return Scaffold(
      appBar: AppBar(
        title: Text('Flashcards', style: GoogleFonts.spaceGrotesk(
          color: AppColors.textPrimary, fontWeight: FontWeight.w700,
        )),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(child: Text(
              '${_index + 1} / ${widget.flashcards.length}',
              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
            )),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_index + 1) / widget.flashcards.length,
                  backgroundColor: AppColors.divider,
                  color: AppColors.purple,
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _showBack ? 'Tap card to see question' : 'Tap card to reveal answer',
                style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 32),

              // Flip card using AnimationBuilder
              Expanded(
                child: GestureDetector(
                  onTap: _flip,
                  child: AnimatedBuilder(
                    animation: _flipAnim,
                    builder: (context, child) {
                      final angle = _flipAnim.value * pi;
                      final isFront = angle < pi / 2;
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(angle),
                        child: isFront
                            ? _CardFace(
                                text: card['front'] ?? '',
                                label: 'QUESTION',
                                color: AppColors.purple,
                                isBack: false,
                              )
                            : Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()..rotateY(pi),
                                child: _CardFace(
                                  text: card['back'] ?? '',
                                  label: 'ANSWER',
                                  color: AppColors.accent,
                                  isBack: true,
                                ),
                              ),
                      );
                    },
                  ),
                ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),
              ),

              const SizedBox(height: 32),

              // Navigation
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _index > 0 ? () => _navigate(_index - 1) : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.divider),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('← Previous', style: GoogleFonts.inter(fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _index < widget.flashcards.length - 1
                        ? () => _navigate(_index + 1)
                        : () => Navigator.pop(context),
                    child: Text(
                      _index < widget.flashcards.length - 1 ? 'Next →' : 'Done ✓',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ]),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  final String text;
  final String label;
  final Color color;
  final bool isBack;

  const _CardFace({
    required this.text,
    required this.label,
    required this.color,
    required this.isBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 30,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(label, style: GoogleFonts.inter(
              color: color, fontSize: 11, fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            )),
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: isBack ? 15 : 20,
                fontWeight: isBack ? FontWeight.w400 : FontWeight.w600,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
