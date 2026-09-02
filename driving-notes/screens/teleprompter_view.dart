import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../services/bible_text_service.dart';
import '../services/emphasis_service.dart';

/// The full-screen scrolling teleprompter, self-contained: it owns its own
/// scroll position, pacing, font size, countdown and pause state, and knows
/// nothing about recording beyond what it's told. RecordReadingScreen just
/// hands it a passage and a stop callback.
///
/// Pulled out of record_reading_screen.dart once that file had grown past
/// 1,200 lines doing four unrelated jobs. Everything teleprompter-shaped
/// lives here now; the recorder screen keeps only the passage that's loaded
/// and the recording lifecycle.
class TeleprompterView extends StatefulWidget {
  /// The text to scroll, already broken into numbered chunks (real verses
  /// for scripture, or paragraph-sized pieces of your own pasted text).
  final List<BibleVerse> verses;

  /// Shown in the app bar - e.g. "John 3" or "Week 3 - Romans Overview".
  final String label;

  /// Optional AI emphasis/pause suggestions from EmphasisService. Purely
  /// additive styling; null or empty just renders the plain text.
  final List<EmphasisMark>? emphasisMarks;

  /// True when this is a rehearsal with nothing being recorded.
  final bool isPractice;

  /// Recording clock, owned by the parent (which is what's actually doing
  /// the recording) and passed down purely for the header readout.
  final int elapsedSeconds;
  final bool blinkOn;

  /// Tapped "Stop & Save" (or "Done Practicing").
  final VoidCallback onStop;

  const TeleprompterView({
    super.key,
    required this.verses,
    required this.label,
    required this.isPractice,
    required this.elapsedSeconds,
    required this.blinkOn,
    required this.onStop,
    this.emphasisMarks,
  });

  @override
  State<TeleprompterView> createState() => _TeleprompterViewState();
}

/// One sentence-sized piece of a chunk, plus how long a breath belongs
/// after it. Splitting at punctuation (rather than rendering a whole verse
/// as one block) is what makes the micro-pauses possible - the gap after a
/// full stop is real vertical space the scroll has to travel through, which
/// at a constant pace becomes real time to breathe.
class _Line {
  final String text;
  final int chunkIndex;

  /// Where this line starts inside its chunk's original text - needed to
  /// map whole-chunk emphasis marks onto the right line.
  final int startOffset;

  /// 0 = run straight on, 0.5 = half beat (";" ":" dash), 1 = full stop.
  final double pauseBeats;

  /// Only the first line of a chunk shows the verse/chunk number.
  final bool isChunkStart;
  final int number;

  _Line({
    required this.text,
    required this.chunkIndex,
    required this.startOffset,
    required this.pauseBeats,
    required this.isChunkStart,
    required this.number,
  });
}

/// Where one emphasis/pause mark falls inside a line's text, resolved at
/// build time from EmphasisMark.phrase - purely a rendering helper, never
/// persisted.
class _PositionedMark {
  final int start;
  final int end;
  final String type;

  _PositionedMark({required this.start, required this.end, required this.type});
}

class _TeleprompterViewState extends State<TeleprompterView>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  Ticker? _scrollTicker;
  int _lastTickMs = 0;

  bool _scrollPaused = false;
  double _fontSize = 36;

  // Pacing is words per minute, NOT pixels per second, and the pixel rate
  // is derived from the passage's real rendered height every frame (see
  // _pixelsPerSecond). That keeps font size and reading pace independent -
  // 120 wpm is 120 wpm whether the text is small or huge.
  double _wpm = 130;
  static const Map<String, double> _speedPresets = {
    'Slower': 95,
    'Slow': 110,
    'Normal': 130,
    'Fast': 155,
  };

  /// A full-stop breath is worth roughly this many words of time. At 130
  /// wpm that's about two thirds of a second - long enough to land a
  /// sentence, short enough not to feel like a stall.
  static const double _wordsPerBeat = 1.5;

  int _countdown = 0;
  Timer? _countdownTimer;

  List<_Line> _lines = [];
  int _realWords = 0;
  double _totalBeats = 0;

  /// Word count plus the time-cost of every breath, so a passage full of
  /// short sentences doesn't secretly race to make up for its own pauses.
  /// Without this the extra gaps would just inflate the content height, the
  /// derived pixel rate would rise to match, and the pauses would steal
  /// their time back out of the words.
  double get _effectiveWords => _realWords + _totalBeats * _wordsPerBeat;

  /// Extra vertical gap one full beat is worth, scaled to the text so a
  /// breath stays proportionate at any size.
  double get _beatPixels => _fontSize * 1.15;

  @override
  void initState() {
    super.initState();
    _rebuildLines();
    _beginCountdownThenScroll();
  }

  @override
  void didUpdateWidget(TeleprompterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.verses != widget.verses || oldWidget.emphasisMarks != widget.emphasisMarks) {
      _rebuildLines();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _scrollTicker?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ---------- Building lines + pauses ----------

  /// Splits every chunk at sentence-ending punctuation, recording where each
  /// piece started so emphasis marks still land in the right place, and how
  /// much of a breath its punctuation earns.
  ///
  /// Deliberately ignores commas - they're frequent enough that pausing at
  /// every one would read as stuttering rather than phrasing.
  void _rebuildLines() {
    final lines = <_Line>[];
    var words = 0;
    var beats = 0.0;

    // A sentence end, plus any closing quote/bracket that belongs with it.
    final strong = RegExp(r'''[.!?…]+["'”’)\]]*(\s+|$)''');
    final medium = RegExp(r'''[;:—–]["'”’)\]]*(\s+|$)''');

    for (var chunkIndex = 0; chunkIndex < widget.verses.length; chunkIndex++) {
      final chunk = widget.verses[chunkIndex];
      final text = chunk.text;
      words += text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

      // Collect every break point in this chunk, with its weight.
      final breaks = <int, double>{}; // end index (exclusive) -> beats
      for (final m in strong.allMatches(text)) {
        breaks[m.end] = 1.0;
      }
      for (final m in medium.allMatches(text)) {
        // Never downgrade a full stop that landed at the same spot.
        breaks[m.end] = breaks[m.end] ?? 0.5;
      }
      final cutPoints = breaks.keys.toList()..sort();

      var start = 0;
      var first = true;
      for (final cut in cutPoints) {
        if (cut <= start) continue;
        final piece = text.substring(start, cut);
        if (piece.trim().isEmpty) {
          start = cut;
          continue;
        }
        final weight = breaks[cut]!;
        lines.add(_Line(
          text: piece,
          chunkIndex: chunkIndex,
          startOffset: start,
          pauseBeats: weight,
          isChunkStart: first,
          number: chunk.verse,
        ));
        beats += weight;
        first = false;
        start = cut;
      }

      // Whatever's left after the last punctuation mark (or the whole chunk
      // if it had none) - always gets at least a chunk-boundary breath.
      if (start < text.length && text.substring(start).trim().isNotEmpty) {
        lines.add(_Line(
          text: text.substring(start),
          chunkIndex: chunkIndex,
          startOffset: start,
          pauseBeats: 1.0,
          isChunkStart: first,
          number: chunk.verse,
        ));
        beats += 1.0;
      } else if (lines.isNotEmpty && !first) {
        // Chunk ended exactly on punctuation - make sure the last line of it
        // still carries a full chunk-boundary breath.
        final last = lines.removeLast();
        lines.add(_Line(
          text: last.text,
          chunkIndex: last.chunkIndex,
          startOffset: last.startOffset,
          pauseBeats: last.pauseBeats < 1.0 ? 1.0 : last.pauseBeats,
          isChunkStart: last.isChunkStart,
          number: last.number,
        ));
        beats += last.pauseBeats < 1.0 ? (1.0 - last.pauseBeats) : 0.0;
      }
    }

    setState(() {
      _lines = lines;
      _realWords = words;
      _totalBeats = beats;
    });
  }

  // ---------- Pacing ----------

  /// Turns the chosen words-per-minute into an actual scroll rate using how
  /// tall this passage really rendered at the current font size. Measured
  /// rather than assumed, so changing text size (or loading a wordier
  /// passage) automatically adjusts the pixel speed to hold the same spoken
  /// pace - the number that actually matters when reading aloud.
  double _pixelsPerSecond(ScrollPosition position) {
    final words = _effectiveWords;
    if (words <= 0) return 0;
    final contentHeight = position.maxScrollExtent + position.viewportDimension;
    if (contentHeight <= 0) return 0;
    final pixelsPerWord = contentHeight / words;
    return pixelsPerWord * (_wpm / 60.0);
  }

  void _startScroll() {
    _scrollTicker?.dispose();
    _lastTickMs = 0;
    _scrollTicker = createTicker(_onScrollTick)..start();
  }

  /// Runs once per display frame, advancing by however much real time
  /// actually elapsed - so a dropped frame doesn't quietly slow the read
  /// down, and a speed change takes effect on the very next frame with
  /// nothing to restart.
  void _onScrollTick(Duration elapsed) {
    final ms = elapsed.inMilliseconds;
    final dtMs = _lastTickMs == 0 ? 0 : ms - _lastTickMs;
    _lastTickMs = ms;
    if (dtMs <= 0) return;
    if (_scrollPaused || _countdown > 0) return;
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;
    final pps = _pixelsPerSecond(position);
    if (pps <= 0) return;
    final next = _scrollController.offset + pps * (dtMs / 1000.0);
    if (next >= position.maxScrollExtent) {
      _scrollController.jumpTo(position.maxScrollExtent);
    } else {
      _scrollController.jumpTo(next);
    }
  }

  void _beginCountdownThenScroll() {
    _countdownTimer?.cancel();
    _countdown = 3;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) timer.cancel();
    });
    _startScroll();
  }

  /// Pauses/resumes the auto-scroll only - a recording in progress keeps
  /// running either way. Lets you freeze the text if you fall behind or want
  /// to linger without losing your place.
  void _togglePause() => setState(() => _scrollPaused = !_scrollPaused);

  void _nudge(double delta) {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + delta)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(target,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _biggerText() => setState(() => _fontSize = (_fontSize + 2).clamp(18, 64));
  void _smallerText() => setState(() => _fontSize = (_fontSize - 2).clamp(18, 64));

  String _formatElapsed(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // ---------- Emphasis rendering ----------

  /// Turns one line's plain text plus any AI emphasis/pause marks that fall
  /// inside it into styled TextSpans - accented and bold for an emphasis
  /// phrase, a small muted "·" after a suggested pause phrase.
  ///
  /// The original text is only ever sliced and reassembled here, never
  /// replaced or retyped, so nothing about the actual wording can change
  /// even if a mark came back oddly from the AI. EmphasisService already
  /// verified each phrase is a verbatim substring; this never trusts that
  /// twice, and silently skips anything it can't locate.
  List<TextSpan> _buildLineSpans(_Line line, TextStyle baseStyle) {
    final all = widget.emphasisMarks;
    if (all == null || all.isEmpty) {
      return [TextSpan(text: line.text, style: baseStyle)];
    }

    final chunkText = widget.verses[line.chunkIndex].text;
    final lineStart = line.startOffset;
    final lineEnd = lineStart + line.text.length;

    final positioned = <_PositionedMark>[];
    for (final m in all.where((m) => m.chunkIndex == line.chunkIndex)) {
      final idx = chunkText.indexOf(m.phrase);
      if (idx == -1) continue;
      final end = idx + m.phrase.length;
      // Only marks fully inside this line - one that straddles a sentence
      // break is dropped rather than rendered half-styled.
      if (idx < lineStart || end > lineEnd) continue;
      positioned.add(_PositionedMark(
        start: idx - lineStart,
        end: end - lineStart,
        type: m.type,
      ));
    }
    if (positioned.isEmpty) {
      return [TextSpan(text: line.text, style: baseStyle)];
    }
    positioned.sort((a, b) => a.start.compareTo(b.start));

    final spans = <TextSpan>[];
    var cursor = 0;
    for (final m in positioned) {
      if (m.start < cursor) continue; // overlaps an earlier mark - keep the first
      if (m.start > cursor) {
        spans.add(TextSpan(text: line.text.substring(cursor, m.start), style: baseStyle));
      }
      final phraseText = line.text.substring(m.start, m.end);
      if (m.type == 'emphasis') {
        spans.add(TextSpan(
          text: phraseText,
          style: baseStyle.copyWith(color: const Color(0xFFFFC94D), fontWeight: FontWeight.w900),
        ));
      } else {
        spans.add(TextSpan(text: phraseText, style: baseStyle));
        spans.add(TextSpan(
          text: '  ·  ',
          style: baseStyle.copyWith(color: Colors.white38, fontWeight: FontWeight.w400),
        ));
      }
      cursor = m.end;
    }
    if (cursor < line.text.length) {
      spans.add(TextSpan(text: line.text.substring(cursor), style: baseStyle));
    }
    return spans;
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.label),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStatusRow(),
            _buildSpeedRow(),
            _buildFineTrimRow(),
            Expanded(child: _buildTextArea()),
            _buildBottomControls(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          if (widget.isPractice) ...[
            const Icon(Icons.play_circle_outline, color: Colors.lightBlueAccent, size: 20),
            const SizedBox(width: 8),
            const Text(
              'PRACTICE - not recording',
              style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.w800),
            ),
          ] else ...[
            AnimatedOpacity(
              opacity: widget.blinkOn ? 1.0 : 0.3,
              duration: const Duration(milliseconds: 400),
              child: const Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 20),
            ),
            const SizedBox(width: 8),
            Text(
              'RECORDING - ${_formatElapsed(widget.elapsedSeconds)}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ],
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.text_decrease, color: Colors.white70),
            tooltip: 'Smaller text',
            onPressed: _smallerText,
          ),
          IconButton(
            icon: const Icon(Icons.text_increase, color: Colors.white70),
            tooltip: 'Bigger text',
            onPressed: _biggerText,
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        children: [
          const Icon(Icons.speed, color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          // Scrollable so the chips can never overflow on a narrower screen -
          // the pause button stays fixed and visible either way.
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final entry in _speedPresets.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('${entry.key}  ${entry.value.round()}'),
                        selected: _wpm == entry.value,
                        onSelected: (_) => setState(() => _wpm = entry.value),
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(_scrollPaused ? Icons.play_arrow : Icons.pause, color: Colors.white),
            tooltip: _scrollPaused
                ? 'Resume auto-scroll'
                : widget.isPractice
                    ? 'Pause auto-scroll'
                    : 'Pause auto-scroll (recording keeps going)',
            onPressed: _togglePause,
          ),
        ],
      ),
    );
  }

  Widget _buildFineTrimRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(
        children: [
          const Text('wpm', style: TextStyle(color: Colors.white38, fontSize: 12)),
          Expanded(
            child: Slider(
              value: _wpm,
              min: 70,
              max: 190,
              divisions: 24,
              label: '${_wpm.round()} wpm',
              onChanged: (v) => setState(() => _wpm = v),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(
              '${_wpm.round()}',
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextArea() {
    return GestureDetector(
      onTap: _togglePause,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // Fades the text toward the top and bottom edges so the brightest,
          // sharpest line sits at a fixed spot on screen - the eye can rest
          // there instead of chasing a moving line, which is the single
          // biggest thing broadcast teleprompters do differently from plain
          // scrolling text.
          ShaderMask(
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(0.10),
                Colors.white.withOpacity(0.45),
                Colors.white,
                Colors.white,
                Colors.white.withOpacity(0.35),
                Colors.white.withOpacity(0.08),
              ],
              stops: const [0.0, 0.14, 0.30, 0.52, 0.78, 1.0],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Center(
                child: ConstrainedBox(
                  // A narrower column is markedly easier to read aloud than
                  // full-width lines - the eye travels less between line
                  // breaks and loses its place far less often.
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: ListView.builder(
                    controller: _scrollController,
                    // Only the ticker/nudge buttons move this - disabling drag
                    // avoids any tug-of-war with the auto-scroll.
                    physics: const NeverScrollableScrollPhysics(),
                    // Blank space at both ends so the first line can start at
                    // the reading band rather than jammed against the top, and
                    // the last line can reach it rather than stopping short.
                    padding: const EdgeInsets.symmetric(vertical: 140),
                    itemCount: _lines.length,
                    itemBuilder: (context, index) => _buildLine(_lines[index]),
                  ),
                ),
              ),
            ),
          ),
          // Small edge markers pointing at the reading band - enough to anchor
          // the eye without a line running across the words themselves.
          Positioned.fill(
            child: IgnorePointer(
              child: FractionallySizedBox(
                alignment: Alignment.topCenter,
                heightFactor: 0.40,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(Icons.play_arrow, size: 16, color: Colors.white.withOpacity(0.28)),
                      Icon(Icons.play_arrow, size: 16, color: Colors.white.withOpacity(0.28)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_countdown > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black54,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_countdown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 120,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        widget.isPractice ? 'Get ready…' : 'Recording - text starts moving in…',
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_scrollPaused && _countdown == 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Scroll paused - tap to resume',
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLine(_Line line) {
    final baseStyle = TextStyle(
      fontSize: _fontSize,
      color: Colors.white,
      height: 1.5,
      fontWeight: FontWeight.w600,
    );
    // The gap below a line IS the pause - at a constant pace, extra space
    // with no words in it is time to breathe. A tiny base gap keeps lines
    // that run straight on from touching.
    final gap = 4 + line.pauseBeats * _beatPixels;
    return Padding(
      padding: EdgeInsets.only(bottom: gap),
      child: RichText(
        text: TextSpan(
          children: [
            if (line.isChunkStart)
              TextSpan(
                text: '${line.number}  ',
                style: TextStyle(
                  fontSize: _fontSize * 0.55,
                  color: Colors.white38,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ..._buildLineSpans(line, baseStyle),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 32),
                tooltip: 'Back up a bit',
                onPressed: () => _nudge(-140),
              ),
              const SizedBox(width: 32),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 32),
                tooltip: 'Skip ahead a bit',
                onPressed: () => _nudge(140),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onStop,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 72),
                backgroundColor:
                    widget.isPractice ? theme.colorScheme.primary : theme.colorScheme.error,
                foregroundColor:
                    widget.isPractice ? theme.colorScheme.onPrimary : theme.colorScheme.onError,
              ),
              icon: Icon(widget.isPractice ? Icons.check : Icons.stop, size: 30),
              label: Text(widget.isPractice ? 'Done Practicing' : 'Stop & Save'),
            ),
          ),
        ],
      ),
    );
  }
}
