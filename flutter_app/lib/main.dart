import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'marketing_api.dart';
import 'theme.dart';
import 'ui_kit.dart';

void main() => runApp(const MarketingApp());

class MarketingApp extends StatelessWidget {
  const MarketingApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'VoiceMarketing.ai',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const GeneratorPage(),
      );
}

enum Phase { intake, copyReady, voiceLength, generating, playback }

/// The four contract fields, in a fixed display order.
const _fields = ['product_name', 'target_audience', 'tone', 'key_benefit'];

const _fieldLabels = {
  'product_name': 'Product',
  'target_audience': 'Audience',
  'tone': 'Tone',
  'key_benefit': 'Benefit',
};

/// The backend returns `missing_fields` but no assistant text, so the
/// conversational follow-ups are composed client-side from what's still
/// missing — the honest realisation of "ask conversationally" for this API.
const _fieldQuestions = {
  'product_name': "Got it. What's the product or service called?",
  'target_audience': "And who's it for — who should this ad speak to?",
  'tone': "What should the ad feel like — playful, calm, premium?",
  'key_benefit': "Last thing: what's the one benefit worth leading with?",
};

const _lengthTags = {15: 'Punchy', 30: 'Balanced', 60: 'Full story'};

class _ChatMsg {
  const _ChatMsg(this.text, {required this.fromUser});
  final String text;
  final bool fromUser;
}

class GeneratorPage extends StatefulWidget {
  const GeneratorPage({super.key});
  @override
  State<GeneratorPage> createState() => _GeneratorPageState();
}

class _GeneratorPageState extends State<GeneratorPage> {
  final api = MarketingApi();
  final description = TextEditingController();
  final chatInput = TextEditingController();
  final _chatScroll = ScrollController();
  final fields = {for (final key in _fields) key: TextEditingController()};
  final _player = AudioPlayer();

  Phase phase = Phase.intake;
  SessionCredentials? session;
  int duration = 30;
  bool busy = false;
  bool manual = false;
  List<String> missing = [];
  Map<String, String?> extracted = {};
  final List<_ChatMsg> transcript = [];

  String? copy;
  List<String> tips = [];
  List<Map<String, dynamic>> voices = [];
  String? voiceId;
  String? audioPath;

  bool isPlaying = false;
  Duration position = Duration.zero;
  Duration total = Duration.zero;

  bool get complete => session != null && missing.isEmpty && !manual;

  @override
  void initState() {
    super.initState();
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => total = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => position = p);
    });
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => isPlaying = s == PlayerState.playing);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          isPlaying = false;
          position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    description.dispose();
    chatInput.dispose();
    _chatScroll.dispose();
    for (final c in fields.values) {
      c.dispose();
    }
    _player.dispose();
    super.dispose();
  }

  // ---- flow -------------------------------------------------------------

  Future<void> run(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.ink800,
    ));
  }

  void _addMsg(String text, {required bool fromUser}) {
    setState(() => transcript.add(_ChatMsg(text, fromUser: fromUser)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(_chatScroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
      }
    });
  }

  void _applyResponse(Map<String, dynamic> r) {
    missing = List<String>.from(r['missing_fields'] ?? []);
    manual = r['requires_manual_entry'] == true;
    final ex = r['extracted'];
    if (ex is Map) {
      extracted = {for (final k in _fields) k: ex[k] as String?};
    }
  }

  void _addFollowup() {
    if (manual) {
      _addMsg("We've talked it through a few times — let's just fill the last "
          'details directly. Quicker this way.', fromUser: false);
    } else if (complete) {
      _addMsg("Perfect — I've got everything I need. Ready to write your script.",
          fromUser: false);
    } else {
      final next = _fields.firstWhere((f) => missing.contains(f),
          orElse: () => missing.first);
      _addMsg(_fieldQuestions[next] ?? 'Tell me a little more?', fromUser: false);
    }
  }

  Future<void> _send(String raw) => run(() async {
        final text = raw.trim();
        if (text.isEmpty) return;
        session ??= await api.createSession(duration);
        _addMsg(text, fromUser: true);
        chatInput.clear();
        final r = await api.message(session!, text);
        _applyResponse(r);
        _addFollowup();
      });

  Future<void> saveManual() => run(() async {
        final r = await api.saveDetails(
            session!, {for (final e in fields.entries) e.key: e.value.text});
        _applyResponse(r);
        if (complete) {
          setState(() {}); // manual body swaps to the generate CTA
        }
      });

  Future<void> makeText() => run(() async {
        final r = await api.generateText(session!);
        final v = await api.voices();
        setState(() {
          copy = r['marketing_text'] as String;
          tips = List<String>.from(r['tips'] ?? []);
          voices = v;
          phase = Phase.copyReady;
        });
      });

  Future<void> generateAd() async {
    setState(() => phase = Phase.generating);
    try {
      await api.generateSpeech(session!, voiceId!);
      final file = await api.downloadAudio(session!);
      await _player.setSource(DeviceFileSource(file.path));
      if (!mounted) return;
      setState(() {
        audioPath = file.path;
        position = Duration.zero;
        phase = Phase.playback;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => phase = Phase.voiceLength);
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void startOver() {
    _player.stop();
    setState(() {
      phase = Phase.intake;
      session = null;
      transcript.clear();
      extracted = {};
      missing = [];
      manual = false;
      copy = null;
      tips = [];
      voices = [];
      voiceId = null;
      audioPath = null;
      isPlaying = false;
      position = Duration.zero;
      total = Duration.zero;
      description.clear();
      chatInput.clear();
      for (final c in fields.values) {
        c.clear();
      }
    });
  }

  void _togglePlay() => isPlaying ? _player.pause() : _player.resume();
  void _seekFraction(double f) {
    if (total > Duration.zero) {
      _player.seek(total * f);
    }
  }

  void _nudge(int seconds) {
    final target = position + Duration(seconds: seconds);
    _player.seek(target < Duration.zero
        ? Duration.zero
        : (total > Duration.zero && target > total ? total : target));
  }

  // ---- build ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final dark = phase == Phase.generating || phase == Phase.playback;
    final reduce = MediaQuery.of(context).disableAnimations;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: AnimatedSwitcher(
          duration: Duration(milliseconds: reduce ? 0 : 450),
          switchInCurve: Curves.easeOut,
          child: KeyedSubtree(
            key: ValueKey('$phase-$manual-$complete'),
            child: _screen(),
          ),
        ),
      ),
    );
  }

  Widget _screen() {
    switch (phase) {
      case Phase.intake:
        if (session == null) return _intakeStart();
        if (manual) return _intakeManual();
        return _intakeChat();
      case Phase.copyReady:
        return _copyReady();
      case Phase.voiceLength:
        return _voiceLength();
      case Phase.generating:
        return _generating();
      case Phase.playback:
        return _playback();
    }
  }

  // paper canvas wrapper
  Widget _canvas({required Widget child}) => Container(
        color: AppColors.paper0,
        child: SafeArea(bottom: false, child: child),
      );

  // ---- A · intake (empty compose) --------------------------------------

  Widget _intakeStart() {
    return _canvas(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
            child: Text('VoiceMarketing',
                style: micro(color: AppColors.teal)),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
              children: [
                Text('Turn your idea\ninto a spoken ad.',
                    style: serif(size: 30, weight: FontWeight.w500, height: 1.05)),
                const SizedBox(height: 8),
                Text(
                    'Describe what you’re selling in a sentence — I’ll ask for '
                    'anything I still need.',
                    style: sans(size: 14, color: AppColors.ink600, height: 1.5)),
                const SizedBox(height: 22),
                Text('HOW LONG SHOULD IT BE?', style: micro()),
                const SizedBox(height: 9),
                _LengthPicker(
                    value: duration,
                    onChanged: busy ? null : (v) => setState(() => duration = v)),
                const SizedBox(height: 22),
                _PaperField(
                  controller: description,
                  hint: 'e.g. A reusable beeswax food wrap that replaces plastic '
                      'wrap, for eco-minded home cooks…',
                  minLines: 4,
                  maxLines: 7,
                ),
              ],
            ),
          ),
          _bottomBar(
            child: PrimaryButton(
              label: 'Start',
              icon: Icons.arrow_forward,
              busy: busy,
              onTap: () => _send(description.text),
            ),
          ),
        ],
      ),
    );
  }

  // ---- A · intake (conversation) ---------------------------------------

  Widget _intakeChat() {
    return _canvas(
      child: Column(
        children: [
          const StepHeader(step: 1),
          _chipsRow(),
          Expanded(
            child: ListView(
              controller: _chatScroll,
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 10),
              children: [
                for (final m in transcript) _bubble(m),
                if (busy && !complete) ...[
                  const SizedBox(height: 4),
                  _thinking(),
                ],
              ],
            ),
          ),
          if (complete)
            _bottomBar(
              child: PrimaryButton(
                label: 'Generate copy',
                icon: Icons.arrow_forward,
                busy: busy,
                onTap: makeText,
              ),
            )
          else
            _chatInputBar(),
        ],
      ),
    );
  }

  Widget _chipsRow() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final f in _fields)
              FieldChip(
                label: _fieldLabels[f]!,
                done: (extracted[f]?.trim().isNotEmpty ?? false),
              ),
          ],
        ),
      );

  Widget _bubble(_ChatMsg m) {
    final me = m.fromUser;
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
        decoration: BoxDecoration(
          color: me ? AppColors.tealSoft : AppColors.paper1,
          border: Border.all(
              color: me ? const Color(0xFFC4DEE0) : AppColors.line),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(me ? 16 : 5),
            bottomRight: Radius.circular(me ? 5 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              me ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(me ? 'YOU' : 'VOICEMARKETING',
                style: micro(color: me ? AppColors.ink400 : AppColors.teal)
                    .copyWith(fontSize: 10, letterSpacing: 1.2)),
            const SizedBox(height: 5),
            Text(m.text,
                style: sans(size: 13.5, color: AppColors.ink800, height: 1.45)),
          ],
        ),
      ),
    );
  }

  Widget _thinking() => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.fromLTRB(15, 12, 16, 12),
          decoration: BoxDecoration(
            color: AppColors.paper1,
            border: Border.all(color: AppColors.line),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(5),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Ribbon(),
              const SizedBox(width: 9),
              Text('listening',
                  style: sans(
                      size: 11, color: AppColors.ink400, weight: FontWeight.w500)),
            ],
          ),
        ),
      );

  Widget _chatInputBar() => Container(
        padding: EdgeInsets.fromLTRB(
            18, 12, 18, 12 + MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(
          color: AppColors.paper0,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: chatInput,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: busy ? null : _send,
                style: sans(size: 13.5, color: AppColors.ink950),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Type your reply…',
                  hintStyle: sans(size: 13, color: AppColors.ink400),
                  filled: true,
                  fillColor: AppColors.paper1,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.azure, width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _SendButton(
                busy: busy, onTap: busy ? null : () => _send(chatInput.text)),
          ],
        ),
      );

  // ---- A′ · intake (form fallback) -------------------------------------

  Widget _intakeManual() {
    final remaining = _fields.where((f) => missing.contains(f)).toList();
    return _canvas(
      child: Column(
        children: [
          StepHeader(step: 1, onBack: startOver),
          _chipsRow(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 20),
              children: [
                Text('Two quick details',
                    style: serif(size: 26, weight: FontWeight.w500)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
                  decoration: BoxDecoration(
                      color: AppColors.yellow,
                      borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: AppColors.ink800),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                            'We’ve talked it through a few times — let’s just '
                            'fill the last fields directly.',
                            style: sans(
                                size: 12,
                                color: AppColors.ink800,
                                weight: FontWeight.w500,
                                height: 1.45)),
                      ),
                    ],
                  ),
                ),
                for (final name in remaining) ...[
                  const SizedBox(height: 16),
                  Row(children: [
                    Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                            color: AppColors.azure, shape: BoxShape.circle)),
                    const SizedBox(width: 7),
                    Text(_fieldLabels[name]!.toUpperCase(),
                        style: micro(color: AppColors.ink600)),
                  ]),
                  const SizedBox(height: 7),
                  _PaperField(
                      controller: fields[name]!,
                      hint: _fieldQuestions[name] ?? '',
                      minLines: 1,
                      maxLines: 2),
                ],
              ],
            ),
          ),
          _bottomBar(
            child: complete
                ? PrimaryButton(
                    label: 'Generate copy',
                    icon: Icons.arrow_forward,
                    busy: busy,
                    onTap: makeText)
                : PrimaryButton(
                    label: 'Save details', busy: busy, onTap: saveManual),
          ),
        ],
      ),
    );
  }

  // ---- B · copy ready ---------------------------------------------------

  Widget _copyReady() {
    final words =
        copy!.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final tone = extracted['tone']?.trim();
    return _canvas(
      child: Column(
        children: [
          StepHeader(step: 2, onBack: () => setState(() => phase = Phase.intake)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 20),
              children: [
                Text('Here’s your script',
                    style: serif(size: 26, weight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text('Read it out loud once — that’s exactly what your listener '
                    'hears.',
                    style: sans(size: 13.5, color: AppColors.ink600, height: 1.5)),
                const SizedBox(height: 20),
                _ScriptCard(copy: copy!),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _metric('Target', '${duration}s'),
                    const SizedBox(width: 20),
                    if (tone != null && tone.isNotEmpty)
                      _metric('Tone', _titleCase(tone)),
                    if (tone != null && tone.isNotEmpty) const SizedBox(width: 20),
                    _metric('Words', '$words'),
                  ],
                ),
                if (tips.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  for (var i = 0; i < tips.length; i++) _tipRow(i + 1, tips[i]),
                ],
              ],
            ),
          ),
          _bottomBar(
            child: Column(
              children: [
                PrimaryButton(
                    label: 'Choose a voice',
                    icon: Icons.arrow_forward,
                    onTap: () => setState(() => phase = Phase.voiceLength)),
                const SizedBox(height: 8),
                GhostButton(label: 'Start over', onTap: startOver),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: micro().copyWith(fontSize: 10)),
          const SizedBox(height: 3),
          Text(value,
              style: sans(size: 15, weight: FontWeight.w600, color: AppColors.ink800)),
        ],
      );

  Widget _tipRow(int n, String tip) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: AppColors.sageSoft,
                  borderRadius: BorderRadius.circular(7)),
              child: Text('$n',
                  style: sans(
                      size: 11, weight: FontWeight.w600, color: AppColors.ink800)),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(tip,
                  style: sans(size: 12.5, color: AppColors.ink600, height: 1.45)),
            ),
          ],
        ),
      );

  // ---- C · voice (+ locked length) -------------------------------------

  Widget _voiceLength() {
    return _canvas(
      child: Column(
        children: [
          StepHeader(
              step: 3, onBack: () => setState(() => phase = Phase.copyReady)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 20),
              children: [
                Text('Pick a voice',
                    style: serif(size: 26, weight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text('Presets tuned for narration — tap to choose.',
                    style: sans(size: 13.5, color: AppColors.ink600, height: 1.5)),
                const SizedBox(height: 16),
                for (var i = 0; i < voices.length; i++)
                  _voiceCard(voices[i], i),
                const SizedBox(height: 18),
                Text('LENGTH', style: micro()),
                const SizedBox(height: 9),
                _lockedLength(),
              ],
            ),
          ),
          _bottomBar(
            child: PrimaryButton(
              label: 'Generate the ad',
              icon: Icons.graphic_eq,
              onTap: voiceId == null ? null : generateAd,
            ),
          ),
        ],
      ),
    );
  }

  Widget _voiceCard(Map<String, dynamic> v, int i) {
    final id = v['id'] as String;
    final label = v['label'] as String;
    final selected = voiceId == id;
    const avatars = [
      AppColors.blush,
      AppColors.azureSoft,
      AppColors.sageSoft,
      AppColors.tealSoft
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Semantics(
        button: true,
        selected: selected,
        label: 'Voice $label',
        child: InkWell(
          onTap: () => setState(() => voiceId = id),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            decoration: BoxDecoration(
              color: selected ? AppColors.azureSoft : AppColors.paper1,
              border: Border.all(
                  color: selected ? AppColors.azure : AppColors.line,
                  width: selected ? 1.5 : 1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: avatars[i % avatars.length],
                      borderRadius: BorderRadius.circular(12)),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(label,
                      style: sans(
                          size: 14,
                          weight: FontWeight.w600,
                          color: AppColors.ink950)),
                ),
                const SizedBox(width: 10),
                MiniWave(
                    color: selected ? AppColors.azure : AppColors.ink400,
                    seed: i + 2),
                const SizedBox(width: 12),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.azure : Colors.transparent,
                    border: selected
                        ? null
                        : Border.all(color: AppColors.ink400, width: 1.5),
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 12, color: AppColors.ink950)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _lockedLength() => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.paper1,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, size: 16, color: AppColors.ink400),
            const SizedBox(width: 10),
            Text('${duration}s',
                style: sans(
                    size: 15, weight: FontWeight.w700, color: AppColors.ink950)),
            const SizedBox(width: 6),
            Text('· ${_lengthTags[duration]}',
                style: sans(size: 13, color: AppColors.ink600)),
            const Spacer(),
            Text('set at the start',
                style: sans(size: 11.5, color: AppColors.ink400)),
          ],
        ),
      );

  // ---- loading · the transition ----------------------------------------

  Widget _generating() {
    final label = _voiceLabel();
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 1.0,
          colors: [AppColors.studio1, AppColors.studio0],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 34),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Ribbon(bars: 7, barWidth: 5, maxHeight: 62, glow: true),
                const SizedBox(height: 28),
                Text('Recording your ad',
                    style: serif(size: 25, color: AppColors.paper0)),
                const SizedBox(height: 9),
                Text('$label · ${duration}s. A few seconds — hold tight.',
                    textAlign: TextAlign.center,
                    style: sans(
                        size: 13.5, color: AppColors.studioText, height: 1.5)),
                const SizedBox(height: 28),
                _genStep('Script locked', done: true),
                _genStep('Synthesizing voice', now: true),
                _genStep('Mixing audio'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _genStep(String label, {bool done = false, bool now = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: SizedBox(
        width: 210,
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? AppColors.sage : Colors.transparent,
                border: done
                    ? null
                    : Border.all(
                        color: now ? AppColors.azure : AppColors.studioLine,
                        width: 1.5),
              ),
              child: done
                  ? const Icon(Icons.check, size: 11, color: AppColors.studio0)
                  : now
                      ? Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                              color: AppColors.azure, shape: BoxShape.circle))
                      : null,
            ),
            const SizedBox(width: 10),
            Text(label,
                style: sans(
                    size: 12.5,
                    weight: FontWeight.w500,
                    color: done
                        ? AppColors.paper0
                        : now
                            ? AppColors.paper0
                            : AppColors.studioMeta)),
          ],
        ),
      ),
    );
  }

  // ---- D · playback -----------------------------------------------------

  Widget _playback() {
    final title = extracted['product_name']?.trim();
    final frac = total > Duration.zero
        ? position.inMilliseconds / total.inMilliseconds
        : 0.0;
    return Container(
      color: AppColors.studio0,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
                children: [
                  Text('YOUR AD IS READY', style: micro(color: AppColors.teal)),
                  const SizedBox(height: 6),
                  Text(title == null || title.isEmpty ? 'Your ad' : title,
                      style: serif(size: 24, color: AppColors.paper0)),
                  const SizedBox(height: 3),
                  Text('${_voiceLabel()} · ${duration}s · MP3',
                      style: sans(size: 12.5, color: AppColors.studioText)),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    decoration: BoxDecoration(
                      color: AppColors.studio1,
                      border: Border.all(color: AppColors.studioLine),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      children: [
                        Waveform(fraction: frac, onSeek: _seekFraction),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_fmt(position),
                                style: sans(
                                    size: 11,
                                    weight: FontWeight.w600,
                                    color: AppColors.azure)),
                            Text(_fmt(total),
                                style: sans(
                                    size: 11,
                                    weight: FontWeight.w600,
                                    color: AppColors.studioMeta)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _transport(),
                  const SizedBox(height: 20),
                  _sourceBox(),
                ],
              ),
            ),
            _playbackActions(),
          ],
        ),
      ),
    );
  }

  Widget _transport() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () => _nudge(-10),
            icon: const Icon(Icons.replay_10),
            color: AppColors.studioText,
            iconSize: 28,
          ),
          const SizedBox(width: 20),
          Semantics(
            button: true,
            label: isPlaying ? 'Pause' : 'Play',
            child: InkWell(
              onTap: _togglePlay,
              customBorder: const CircleBorder(),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.azure,
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.azure.withValues(alpha: 0.4),
                        blurRadius: 28,
                        offset: const Offset(0, 14)),
                  ],
                ),
                child: Icon(isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 34, color: AppColors.ink950),
              ),
            ),
          ),
          const SizedBox(width: 20),
          IconButton(
            onPressed: () => _nudge(10),
            icon: const Icon(Icons.forward_10),
            color: AppColors.studioText,
            iconSize: 28,
          ),
        ],
      );

  Widget _sourceBox() => Container(
        padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
        decoration: BoxDecoration(
          color: AppColors.studio1,
          border: Border.all(color: AppColors.studioLine),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: AppColors.sage, shape: BoxShape.circle)),
              const SizedBox(width: 7),
              Text('SOURCE SCRIPT', style: micro(color: AppColors.studioMeta)),
            ]),
            const SizedBox(height: 8),
            SelectableText(copy ?? '',
                style: sans(size: 12.5, color: AppColors.studioText, height: 1.5)),
          ],
        ),
      );

  Widget _playbackActions() => Container(
        padding: EdgeInsets.fromLTRB(
            22, 12, 22, 14 + MediaQuery.of(context).padding.bottom),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _snack('Saved to $audioPath'),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: AppColors.azure,
                      borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.download, size: 18, color: AppColors.ink950),
                      const SizedBox(width: 8),
                      Text('Download MP3',
                          style: sans(
                              size: 14.5,
                              weight: FontWeight.w600,
                              color: AppColors.ink950)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: startOver,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 56,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.studio1,
                  border: Border.all(color: AppColors.studioLine),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.refresh, color: AppColors.paper0, size: 20),
              ),
            ),
          ],
        ),
      );

  // ---- shared bits ------------------------------------------------------

  Widget _bottomBar({required Widget child}) => Container(
        padding: EdgeInsets.fromLTRB(
            22, 12, 22, 14 + MediaQuery.of(context).padding.bottom),
        color: AppColors.paper0,
        child: child,
      );

  String _voiceLabel() {
    final v = voices.where((v) => v['id'] == voiceId);
    return v.isEmpty ? 'Your voice' : v.first['label'] as String;
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ---- small standalone widgets ------------------------------------------

class _ScriptCard extends StatelessWidget {
  const _ScriptCard({required this.copy});
  final String copy;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 16),
          decoration: BoxDecoration(
            color: AppColors.paper1,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(copy,
                  style: serif(
                      size: 18.5,
                      weight: FontWeight.w400,
                      color: AppColors.ink950,
                      height: 1.5,
                      letterSpacing: 0)),
              const SizedBox(height: 14),
              const MiniWave(color: AppColors.azure, bars: 40, height: 14, seed: 9),
            ],
          ),
        ),
        Positioned(
          top: -11,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
                color: AppColors.ink950,
                borderRadius: BorderRadius.circular(999)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('YOUR ',
                    style: micro(color: AppColors.paper0)
                        .copyWith(fontSize: 10, letterSpacing: 1.6)),
                Text('SCRIPT',
                    style: micro(color: AppColors.yellow)
                        .copyWith(fontSize: 10, letterSpacing: 1.6)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LengthPicker extends StatelessWidget {
  const _LengthPicker({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.paper1,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final s in const [15, 30, 60])
            Expanded(
              child: GestureDetector(
                onTap: onChanged == null ? null : () => onChanged!(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: value == s ? AppColors.ink950 : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Column(
                    children: [
                      Text('${s}s',
                          style: sans(
                              size: 14,
                              weight: FontWeight.w600,
                              color: value == s
                                  ? AppColors.paper0
                                  : AppColors.ink600)),
                      const SizedBox(height: 3),
                      Text(_lengthTags[s]!,
                          style: sans(
                              size: 10,
                              weight: FontWeight.w500,
                              color: value == s
                                  ? AppColors.teal
                                  : AppColors.ink400)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PaperField extends StatelessWidget {
  const _PaperField({
    required this.controller,
    required this.hint,
    this.minLines = 1,
    this.maxLines = 1,
  });
  final TextEditingController controller;
  final String hint;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      style: sans(size: 14, color: AppColors.ink950, height: 1.45),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: sans(size: 13.5, color: AppColors.ink400, height: 1.45),
        filled: true,
        fillColor: AppColors.paper1,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.azure, width: 2),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Send',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.azure,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: AppColors.azure.withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(13),
                  child: CircularProgressIndicator(
                      strokeWidth: 2.2, color: AppColors.ink950),
                )
              : const Icon(Icons.graphic_eq, color: AppColors.ink950, size: 22),
        ),
      ),
    );
  }
}
