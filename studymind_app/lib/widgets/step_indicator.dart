import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

class StepIndicator extends StatelessWidget {
  final int currentStep; // 0=nothing done, 1=analyzed, 2=summarized, 3=generated, 4=evaluated

  const StepIndicator({super.key, required this.currentStep});

  static const _steps = ['Analyze', 'Summarize', 'Generate', 'Evaluate'];
  static const _icons = ['🔍', '📝', '🃏', '🎯'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _steps.asMap().entries.map((e) {
        final i = e.key;
        // step index i is "done" when currentStep > i, "active" when currentStep == i
        final done = currentStep > i;
        final active = currentStep == i;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: done
                          ? AppColors.purple
                          : active
                              ? AppColors.purpleGlow
                              : AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: done || active ? AppColors.purple : AppColors.divider,
                        width: active ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: done
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : Text(_icons[i], style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _steps[i],
                    style: GoogleFonts.inter(
                      color: done || active
                          ? AppColors.purpleLight
                          : AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ]),
              ),
              if (i < _steps.length - 1)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 2,
                      color: done ? AppColors.purple : AppColors.divider,
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
