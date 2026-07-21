import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncless/features/auth/presentation/auth_gate.dart';
import 'package:syncless/features/generation/domain/entities/generation_mode.dart';
import 'package:syncless/features/generation/domain/entities/generation_outcome.dart';
import 'package:syncless/features/generation/domain/entities/generation_quota.dart';
import 'package:syncless/features/generation/domain/entities/generation_request.dart';
import 'package:syncless/features/generation/domain/entities/generation_result.dart';
import 'package:syncless/features/generation/presentation/controllers/generation_controller.dart';
import '../domain/entities/demo_presets.dart';

class WorkspacePage extends ConsumerStatefulWidget {
  const WorkspacePage({super.key});

  @override
  ConsumerState<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends ConsumerState<WorkspacePage> {
  static const _freeCharacterLimit = 12000;
  final TextEditingController _conversationController = TextEditingController();
  GenerationMode _selectedMode = GenerationMode.workSpecification;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    unawaited(_authSubscription.cancel());
    _conversationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final generationState = ref.watch(generationControllerProvider);

    ref.listen<AsyncValue<GenerationOutcome?>>(
      generationControllerProvider,
      (_, next) {
        next.whenOrNull(
          error: (error, _) => _showMessage(error.toString(), isError: true),
          data: (outcome) {
            if (outcome != null && !outcome.quota.allowed) {
              _showMessage(_quotaMessage(outcome), isError: true);
            }
          },
        );
      },
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0A0B0F),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              onNewPressed: () {
                _conversationController.clear();
                ref.read(generationControllerProvider.notifier).clear();
              },
              onCopyPressed: _copyMarkdownOutput,
              onExportPressed: _showExportDialog,
              onUpgradePressed: _showUpgradeDialog,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 900;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1480),
                        child: isCompact
                            ? Column(
                                children: [
                                  SizedBox(
                                    height: 520,
                                    child: _ConversationPanel(
                                      controller: _conversationController,
                                      selectedMode: _selectedMode,
                                      isGenerating: generationState.isLoading,
                                      onModeChanged: (mode) {
                                        setState(() => _selectedMode = mode);
                                      },
                                      onPresetSelected: (preset) {
                                        setState(() {
                                          _conversationController.text = preset.content;
                                        });
                                        _showMessage('Loaded preset: ${preset.title}', isError: false);
                                      },
                                      onUploadFile: _uploadFile,
                                      onGenerate: _generate,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    height: 520,
                                    child: _PreviewPanel(state: generationState),
                                  ),
                                ],
                              )
                            : SizedBox(
                                height: constraints.maxHeight - 40,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      flex: 9,
                                      child: _ConversationPanel(
                                        controller: _conversationController,
                                        selectedMode: _selectedMode,
                                        isGenerating: generationState.isLoading,
                                        onModeChanged: (mode) {
                                          setState(() => _selectedMode = mode);
                                        },
                                        onPresetSelected: (preset) {
                                          setState(() {
                                            _conversationController.text = preset.content;
                                          });
                                          _showMessage('Loaded preset: ${preset.title}', isError: false);
                                        },
                                        onUploadFile: _uploadFile,
                                        onGenerate: _generate,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 11,
                                      child: _PreviewPanel(state: generationState),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: const BoxDecoration(
                color: Color(0xFF0D0E14),
                border: Border(top: BorderSide(color: Color(0xFF1E202C))),
              ),
              alignment: Alignment.center,
              child: const Text(
                '© 2026 Syncless  |  Built By Nisha Najihah',
                style: TextStyle(
                  color: Color(0xFFB5BACB),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'md', 'json', 'log'],
    );
    if (result != null && result.files.single.bytes != null) {
      final content = String.fromCharCodes(result.files.single.bytes!);
      setState(() {
        _conversationController.text = content;
      });
      _showMessage('Uploaded ${result.files.single.name}', isError: false);
    }
  }

  bool _ensureAuthenticated() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) return true;

    unawaited(showDialog<void>(
      context: context,
      builder: (context) => const SignInDialog(),
    ));
    return false;
  }

  Future<void> _generate() async {
    if (!_ensureAuthenticated()) return;

    final sourceText = _conversationController.text;
    if (sourceText.trim().isEmpty) {
      _showMessage('Paste a conversation or notes before generating.', isError: true);
      return;
    }

    await ref.read(generationControllerProvider.notifier).generate(
          GenerationRequest(sourceText: sourceText, mode: _selectedMode),
        );
  }

  Future<void> _copyMarkdownOutput() async {
    if (!_ensureAuthenticated()) return;

    final state = ref.read(generationControllerProvider).value;
    if (state?.result?.markdown != null) {
      await Clipboard.setData(ClipboardData(text: state!.result!.markdown));
      _showMessage('Copied Markdown to clipboard!', isError: false);
    } else {
      _showMessage('No generated content to copy yet.', isError: true);
    }
  }

  Future<void> _showExportDialog() async {
    if (!_ensureAuthenticated()) return;

    final state = ref.read(generationControllerProvider).value;
    if (state?.result == null) {
      _showMessage('Generate a document first before exporting.', isError: true);
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF14161F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Export Document', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.code_rounded, color: Color(0xFF00E5FF)),
              title: const Text('Export as Markdown (.md)', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Standard Markdown format', style: TextStyle(color: Colors.grey)),
              onTap: () async {
                Navigator.pop(context);
                await _copyMarkdownOutput();
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFFF8B8B)),
              title: const Text('Export as PDF (Pro)', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Executive print layout', style: TextStyle(color: Colors.grey)),
              onTap: () async {
                Navigator.pop(context);
                await _showUpgradeDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showUpgradeDialog() async {
    if (!_ensureAuthenticated()) return;

    await showDialog<void>(
      context: context,
      builder: (context) => const _UpgradeDialog(),
    );
  }

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _TopNotification(
        message: message,
        isError: isError,
        onDismiss: () {
          if (entry.mounted) {
            entry.remove();
          }
        },
      ),
    );

    overlay.insert(entry);
  }

  String _quotaMessage(GenerationOutcome outcome) {
    final resetAt = outcome.quota.resetAt;
    if (resetAt == null) return 'Daily quota reached. Please upgrade to continue.';

    final remaining = resetAt.difference(DateTime.now());
    if (remaining.inMinutes <= 0) return 'Your quota is resetting now. Please try again.';

    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    return hours > 0
        ? 'Daily quota reached. Resets in ${hours}h ${minutes}m.'
        : 'Daily quota reached. Resets in ${minutes}m.';
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onNewPressed,
    required this.onCopyPressed,
    required this.onExportPressed,
    required this.onUpgradePressed,
  });

  final VoidCallback onNewPressed;
  final VoidCallback onCopyPressed;
  final VoidCallback onExportPressed;
  final VoidCallback onUpgradePressed;

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Container(
      height: 72,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF20222B))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 720;
          final isVeryNarrow = constraints.maxWidth < 480;

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: isNarrow ? 16 : 24),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E5FF), Color(0xFF0083B0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(Icons.bolt_rounded, size: 19, color: Colors.white),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Syncless',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                if (!isNarrow) ...[
                  const SizedBox(width: 16),
                  const Text(
                    'Turn conversations into execution.',
                    style: TextStyle(color: Color(0xFF8E93A8), fontSize: 15),
                  ),
                ],
                const Spacer(),
                if (!isNarrow)
                  _TopBarAction(label: 'New', icon: Icons.add_rounded, onPressed: onNewPressed)
                else
                  IconButton(
                    onPressed: onNewPressed,
                    icon: const Icon(Icons.add_rounded),
                    tooltip: 'New',
                  ),
                if (!isNarrow) ...[
                  const SizedBox(width: 8),
                  _TopBarAction(
                    label: 'Export',
                    icon: Icons.file_download_outlined,
                    onPressed: onExportPressed,
                  ),
                  const SizedBox(width: 8),
                  _TopBarAction(
                    label: 'Copy',
                    icon: Icons.content_copy_outlined,
                    onPressed: onCopyPressed,
                  ),
                ],
                SizedBox(width: isVeryNarrow ? 4 : 12),
                if (user == null)
                  FilledButton(
                    onPressed: () {
                      unawaited(showDialog<void>(
                        context: context,
                        builder: (context) => const SignInDialog(),
                      ));
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00B4D8),
                      foregroundColor: Colors.white,
                      minimumSize: Size.zero,
                      padding: EdgeInsets.symmetric(horizontal: isVeryNarrow ? 12 : 16, vertical: 14),
                    ),
                    child: const Text('Sign In'),
                  )
                else ...[
                  FilledButton(
                    onPressed: onUpgradePressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00B4D8),
                      foregroundColor: Colors.white,
                      minimumSize: Size.zero,
                      padding: EdgeInsets.symmetric(horizontal: isVeryNarrow ? 12 : 16, vertical: 14),
                    ),
                    child: Text(isVeryNarrow ? 'Pro' : 'Upgrade'),
                  ),
                  const SizedBox(width: 12),
                  PopupMenuButton<String>(
                    color: const Color(0xFF161822),
                    icon: const CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0xFF242733),
                      child: Icon(Icons.person_outline_rounded, size: 18, color: Color(0xFFC9CCDA)),
                    ),
                    onSelected: (value) async {
                      if (value == 'logout') {
                        await Supabase.instance.client.auth.signOut();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        enabled: false,
                        child: Text(
                          user.email ?? 'Authenticated User',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout_rounded, size: 18, color: Colors.redAccent),
                            SizedBox(width: 8),
                            Text('Sign out', style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TopBarAction extends StatelessWidget {
  const _TopBarAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFFBFC3D4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      ),
    );
  }
}

class _ConversationPanel extends StatelessWidget {
  const _ConversationPanel({
    required this.controller,
    required this.selectedMode,
    required this.isGenerating,
    required this.onModeChanged,
    required this.onPresetSelected,
    required this.onUploadFile,
    required this.onGenerate,
  });

  final TextEditingController controller;
  final GenerationMode selectedMode;
  final bool isGenerating;
  final ValueChanged<GenerationMode> onModeChanged;
  final ValueChanged<DemoPreset> onPresetSelected;
  final VoidCallback onUploadFile;
  final Future<void> Function() onGenerate;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Conversation Input',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Paste a conversation, transcript, or unstructured notes below to generate structured documents.',
              style: TextStyle(color: Color(0xFF9297AB), fontSize: 17),
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF2A2D38), height: 1),
            const SizedBox(height: 16),

            const Text(
              'Example Presets',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF00E5FF)),
            ),
            const SizedBox(height: 10),
            _PresetBar(onPresetSelected: onPresetSelected),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF2A2D38), height: 1),
            const SizedBox(height: 16),
            const Text(
              'Select Output Format',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF00E5FF)),
            ),
            const SizedBox(height: 10),
            _ModeSelector(selectedMode: selectedMode, onChanged: onModeChanged),
            const SizedBox(height: 12),
            _ModeDescription(mode: selectedMode),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF2A2D38), height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Conversation Context',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF00E5FF)),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.fullscreen_rounded, color: Color(0xFF00E5FF), size: 22),
                  tooltip: 'Expand to Fullscreen Editor',
                  onPressed: () {
                    unawaited(showDialog<void>(
                      context: context,
                      builder: (context) => _ExpandedEditorDialog(controller: controller),
                    ));
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Stack(
                children: [
                  TextField(
                    controller: controller,
                    maxLength: _WorkspacePageState._freeCharacterLimit,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(fontSize: 18, height: 1.6),
                    decoration: InputDecoration(
                      hintText: 'Paste your conversation here…',
                      hintStyle: const TextStyle(color: Color(0xFF686D80)),
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xFF101218),
                      contentPadding: const EdgeInsets.all(18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF2A2D38)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF2A2D38)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF00B4D8), width: 1.5),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 14,
                    bottom: 12,
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (context, value, _) => Text(
                        '${value.text.length} / ${_WorkspacePageState._freeCharacterLimit}',
                        style: const TextStyle(color: Color(0xFF74798C), fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onUploadFile,
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('Upload file'),
                ),
                const Spacer(),
                const Text(
                  '3 free generations daily',
                  style: TextStyle(color: Color(0xFF8D92A5), fontSize: 14),
                ),
                const SizedBox(width: 14),
                FilledButton.icon(
                  onPressed: isGenerating ? null : onGenerate,
                  icon: isGenerating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: Text(isGenerating ? 'Generating' : 'Generate'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00B4D8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetBar extends StatelessWidget {
  const _PresetBar({required this.onPresetSelected});

  final ValueChanged<DemoPreset> onPresetSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6, right: 4),
          child: Text(
            'Try Example:',
            style: TextStyle(color: Color(0xFF7E8497), fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        ...DemoPreset.presets.map(
          (preset) => ActionChip(
            avatar: const Icon(Icons.chat_bubble_outline_rounded, size: 15, color: Color(0xFF00E5FF)),
            label: Text(preset.title),
            onPressed: () => onPresetSelected(preset),
            backgroundColor: const Color(0xFF161822),
            side: const BorderSide(color: Color(0xFF282B38)),
            labelStyle: const TextStyle(color: Color(0xFFC7CBD9), fontSize: 16),
          ),
        ),
      ],
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.selectedMode, required this.onChanged});

  final GenerationMode selectedMode;
  final ValueChanged<GenerationMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: GenerationMode.values.map((mode) {
        final selected = mode == selectedMode;
        return ChoiceChip(
          label: Text(mode.label),
          selected: selected,
          onSelected: (_) => onChanged(mode),
          selectedColor: const Color(0xFF004B57),
          backgroundColor: const Color(0xFF161820),
          side: BorderSide(color: selected ? const Color(0xFF00E5FF) : const Color(0xFF2A2D38)),
          labelStyle: TextStyle(
            color: selected ? const Color(0xFFE0FCFF) : const Color(0xFFA5AABB),
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 16,
          ),
        );
      }).toList(),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({required this.state});

  final AsyncValue<GenerationOutcome?> state;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Work Specification',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161820),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF2B2E39)),
                  ),
                  child: const Text(
                    'GPT-5.6 Powered',
                    style: TextStyle(color: Color(0xFF969BAD), fontSize: 13),
                  ),
                ),
              ],
            ),
            Expanded(
              child: state.when(
                loading: () => const _ProcessingPreview(),
                error: (_, __) => const _PreviewEmptyState(
                  title: 'System at high capacity',
                  subtitle: 'Our AI engine is currently experiencing high demand or undergoing routine maintenance. Please try again in a few hours.',
                  icon: Icons.speed_rounded,
                ),
                data: (outcome) {
                  if (outcome == null) return const _PreviewEmptyState();
                  if (!outcome.isSuccessful) return _QuotaPreview(outcome: outcome);
                  return _GeneratedPreview(result: outcome.result!, quota: outcome.quota);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewEmptyState extends StatelessWidget {
  const _PreviewEmptyState({
    this.title = 'Your Work Specification will appear here.',
    this.subtitle = 'Turn scattered context into an actionable, structured plan in seconds.',
    this.icon = Icons.description_outlined,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _EmptyStateIcon(icon: icon),
          const SizedBox(height: 20),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SizedBox(
            width: 320,
            child: Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF8D92A5), fontSize: 15, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class _ProcessingPreview extends StatelessWidget {
  const _ProcessingPreview();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 2.5)),
          SizedBox(height: 18),
          Text('Turning context into clarity…', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
          SizedBox(height: 6),
          Text('Synthesizing decisions, scope, and next steps with GPT-5.6.', style: TextStyle(color: Color(0xFF8D92A5), fontSize: 15)),
        ],
      ),
    );
  }
}

class _QuotaPreview extends StatelessWidget {
  const _QuotaPreview({required this.outcome});

  final GenerationOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final resetAt = outcome.quota.resetAt;
    final plan = outcome.quota.plan;
    final isProFormatLock = !plan.isPro && outcome.quota.remaining == null && resetAt == null;

    if (isProFormatLock) {
      return const _PreviewEmptyState(
        title: 'Syncless Pro Format Required',
        subtitle: 'Sprint Plan and Executive Brief formats are exclusive to Pro subscribers. Upgrade to Pro to generate these formats.',
        icon: Icons.lock_outline_rounded,
      );
    }

    return _PreviewEmptyState(
      title: 'Daily quota reached.',
      subtitle: resetAt == null
          ? 'Upgrade to Pro for a higher generation allowance.'
          : 'Your free generation allowance will reset soon.',
      icon: Icons.timer_outlined,
    );
  }
}

class _GeneratedPreview extends StatelessWidget {
  const _GeneratedPreview({required this.result, required this.quota});

  final GenerationResult result;
  final GenerationQuota quota;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(result.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
          if (quota.remaining != null) ...[
            const SizedBox(height: 6),
            Text(
              '${quota.remaining} ${quota.plan.isPro ? 'generations' : 'free generations'} remaining',
              style: const TextStyle(color: Color(0xFF8D92A5), fontSize: 14),
            ),
          ],
          const SizedBox(height: 16),
          MarkdownBody(
            data: result.markdown,
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: const TextStyle(color: Color(0xFFD7DAE5), fontSize: 18, height: 1.65),
              h1: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
              h2: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 24),
          _InsightSection(title: 'AI confidence', items: ['${(result.confidence * 100).round()}% confidence']),
          _InsightSection(title: 'Missing information', items: result.missingInformation),
          _InsightSection(title: 'Potential risks', items: result.potentialRisks),
          _InsightSection(title: 'Suggested follow-up questions', items: result.followUpQuestions),
        ],
      ),
    );
  }
}

class _InsightSection extends StatelessWidget {
  const _InsightSection({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF80F3FF), fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text('• $item', style: const TextStyle(color: Color(0xFFBEC2D1), fontSize: 15, height: 1.4)),
              )),
        ],
      ),
    );
  }
}

class _UpgradeDialog extends StatelessWidget {
  const _UpgradeDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF10121A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF282B3C))),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6D5DF5).withAlpha(40),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.bolt_rounded, color: Color(0xFF00E5FF)),
          ),
          const SizedBox(width: 12),
          const Text('Upgrade to Syncless Pro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Unlock high-capacity AI generations, multi-document modes, and export features.',
              style: TextStyle(color: Color(0xFF9FA4B7), fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 20),
            _buildFeatureRow('500 AI generations per month'),
            _buildFeatureRow('Up to 100,000 characters per prompt'),
            _buildFeatureRow('Sprint Plan & Executive Brief modes'),
            _buildFeatureRow('PDF & DOCX Export'),
            _buildFeatureRow('Priority GPT-5.6 inference speed'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Stripe Checkout session initialized! (Stripe Test Mode)'),
                      backgroundColor: Color(0xFF4338CA),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6D5DF5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Upgrade for \$19/month', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildFeatureRow(String feature) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF00B4D8), size: 18),
          const SizedBox(width: 10),
          Text(feature, style: const TextStyle(color: Color(0xFFE2E4EC), fontSize: 15)),
        ],
      ),
    );
  }
}

class _EmptyStateIcon extends StatelessWidget {
  const _EmptyStateIcon({this.icon = Icons.description_outlined});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0xFF17182B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF35305F)),
      ),
      child: Icon(icon, color: const Color(0xFFA89FFF), size: 27),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF101116),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF242631)),
      ),
      child: child,
    );
  }
}

class _ModeDescription extends StatelessWidget {
  const _ModeDescription({required this.mode});

  final GenerationMode mode;

  @override
  Widget build(BuildContext context) {
    String description;
    String title;
    IconData icon;

    switch (mode) {
      case GenerationMode.workSpecification:
        title = 'Work Specification';
        description = 'Generates product scope, key technical decisions, user flows, and acceptance criteria.';
        icon = Icons.description_outlined;
        break;
      case GenerationMode.sprintPlan:
        title = 'Sprint Plan';
        description = 'Generates developer ticket breakdowns (title, description, story points) ready for Jira/Linear.';
        icon = Icons.view_week_outlined;
        break;
      case GenerationMode.executiveBrief:
        title = 'Executive Brief';
        description = 'Generates a high-level executive summary, business impact, and milestone estimates for leadership.';
        icon = Icons.insights_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161822),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF282B38)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF00E5FF)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF8E93A8), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopNotification extends StatefulWidget {
  const _TopNotification({
    required this.message,
    required this.isError,
    required this.onDismiss,
  });

  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  @override
  State<_TopNotification> createState() => _TopNotificationState();
}

class _TopNotificationState extends State<_TopNotification> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    unawaited(_controller.forward());

    // Auto dismiss after 3 seconds
    unawaited(Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        unawaited(_controller.reverse().then((_) {
          widget.onDismiss();
        }));
      }
    }));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 24, left: 16, right: 16),
          child: SlideTransition(
            position: _offsetAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 450),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: widget.isError ? const Color(0xFFDC2626) : const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(80),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandedEditorDialog extends StatelessWidget {
  const _ExpandedEditorDialog({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF10121A),
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF282B3C)),
      ),
      child: Container(
        width: 850,
        height: 650,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.edit_note_rounded, color: Color(0xFF00E5FF), size: 26),
                const SizedBox(width: 10),
                const Text(
                  'Conversation Context Editor',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF73788B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontSize: 18, height: 1.6, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Paste or edit your transcript here...',
                  hintStyle: const TextStyle(color: Color(0xFF686D80)),
                  filled: true,
                  fillColor: const Color(0xFF161822),
                  contentPadding: const EdgeInsets.all(20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF282B38)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00B4D8),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                child: const Text('Done Editing', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
