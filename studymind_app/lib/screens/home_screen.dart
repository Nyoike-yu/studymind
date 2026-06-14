import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../services/api_service.dart';
import '../widgets/glow_button.dart';
import '../widgets/input_tab.dart';
import 'study_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _topicCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  // PDF state held here so _start() can access it
  String? _pdfFilename;
  Uint8List? _pdfBytes;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _topicCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() { _loading = true; _error = null; });
    try {
      String sessionId;
      switch (_tab.index) {
        case 0:
          if (_topicCtrl.text.trim().isEmpty) throw Exception('Enter a topic');
          sessionId = await ApiService.ingestTopic(_topicCtrl.text.trim());
          break;
        case 1:
          if (_urlCtrl.text.trim().isEmpty) throw Exception('Enter a URL');
          sessionId = await ApiService.ingestUrl(_urlCtrl.text.trim());
          break;
        case 2:
          if (_pdfBytes == null || _pdfFilename == null) {
            throw Exception('Please select a PDF file first');
          }
          sessionId = await ApiService.ingestPdf(_pdfBytes!, _pdfFilename!);
          break;
        default:
          throw Exception('Unknown tab');
      }
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => StudyScreen(sessionId: sessionId),
      ));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // Logo + title
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.purple, AppColors.accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Text('StudyMind',
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  )),
              ]).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),

              const SizedBox(height: 8),
              Text('Your AI study agent',
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                )).animate().fadeIn(delay: 100.ms),

              const SizedBox(height: 40),

              // Agent steps preview
              _AgentStepsRow(),

              const SizedBox(height: 36),

              // Input card
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: [
                    // Tabs
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppColors.divider)),
                      ),
                      child: TabBar(
                        controller: _tab,
                        indicatorColor: AppColors.purple,
                        indicatorWeight: 2,
                        labelColor: AppColors.purple,
                        unselectedLabelColor: AppColors.textSecondary,
                        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                        tabs: const [
                          Tab(text: 'Topic'),
                          Tab(text: 'URL'),
                          Tab(text: 'PDF'),
                        ],
                      ),
                    ),

                    // Input card tabs content
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        height: 140,
                        child: TabBarView(
                          controller: _tab,
                          children: [
                            InputTab(
                              controller: _topicCtrl,
                              hint: 'e.g. Photosynthesis, Thermodynamics, Machine Learning...',
                              icon: Icons.lightbulb_outline,
                              maxLines: 4,
                            ),
                            InputTab(
                              controller: _urlCtrl,
                              hint: 'https://en.wikipedia.org/wiki/...',
                              icon: Icons.link,
                              maxLines: 1,
                            ),
                            _PdfPicker(
                              filename: _pdfFilename,
                              onPicked: (bytes, name) => setState(() {
                                _pdfBytes = bytes;
                                _pdfFilename = name;
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_error!, style: GoogleFonts.inter(
                      color: AppColors.error, fontSize: 13,
                    ))),
                  ]),
                ),
              ],

              const SizedBox(height: 24),

              GlowButton(
                label: _loading ? 'Starting agent...' : 'Start Studying →',
                loading: _loading,
                onTap: _loading ? null : _start,
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentStepsRow extends StatelessWidget {
  final steps = const [
    ('🔍', 'Analyze'),
    ('📝', 'Summarize'),
    ('🃏', 'Generate'),
    ('🎯', 'Evaluate'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: steps.asMap().entries.map((e) {
        final i = e.key;
        final s = e.value;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Center(child: Text(s.$1, style: const TextStyle(fontSize: 18))),
                  ),
                  const SizedBox(height: 6),
                  Text(s.$2, style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  )),
                ]),
              ),
              if (i < steps.length - 1)
                const Icon(Icons.chevron_right, color: AppColors.divider, size: 18),
            ],
          ),
        );
      }).toList(),
    ).animate().fadeIn(delay: 150.ms);
  }
}

class _PdfPicker extends StatelessWidget {
  final String? filename;
  final void Function(Uint8List bytes, String name) onPicked;

  const _PdfPicker({required this.filename, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          withData: true,
        );
        if (result != null && result.files.first.bytes != null) {
          onPicked(result.files.first.bytes!, result.files.first.name);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: filename != null ? AppColors.purple : AppColors.divider,
            width: filename != null ? 2 : 1,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                filename != null ? Icons.check_circle : Icons.upload_file,
                color: filename != null ? AppColors.purple : AppColors.textSecondary,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                filename ?? 'Tap to upload PDF',
                style: GoogleFonts.inter(
                  color: filename != null ? AppColors.textPrimary : AppColors.textSecondary,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
