import 'dart:ui' show Subtitle, Color, TextStyle, Alignment;

/// Subtitle cue model for parsed subtitles
class SubtitleCue {
  final Duration start;
  final Duration end;
  final String text;
  final SubtitleStyle? style;

  SubtitleCue({
    required this.start,
    required this.end,
    required this.text,
    this.style,
  });
}

/// Subtitle style for ASS/SSA format
class SubtitleStyle {
  final bool bold;
  final bool italic;
  final Color? color;
  final double? fontSize;
  final double? position; // 0-100 percentage from bottom

  SubtitleStyle({
    this.bold = false,
    this.italic = false,
    this.color,
    this.fontSize,
    this.position,
  });
}

/// Subtitle parser - parses SRT, VTT, ASS/SSA formats
class SubtitleParser {
  /// Parse SRT format subtitles
  static List<SubtitleCue> parseSrt(String content) {
    final cues = <SubtitleCue>[];

    if (content.isEmpty) return cues;

    try {
      // Normalize line endings
      final normalized =
          content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

      // Split by double newlines (cues are separated by blank lines)
      final blocks = normalized.split('\n\n');

      for (final block in blocks) {
        final lines = block.trim().split('\n');
        if (lines.length < 2) continue;

        // First line is the cue number
        // Second line is the timestamp
        // Rest is the text
        String? timeLine;
        final textLines = <String>[];

        for (final line in lines) {
          if (line.contains('-->')) {
            timeLine = line;
          } else if (line.trim().isNotEmpty &&
              !RegExp(r'^\d+$').hasMatch(line.trim())) {
            textLines.add(line);
          }
        }

        if (timeLine == null || textLines.isEmpty) continue;

        final timestamps = _parseSrtTimestamp(timeLine);
        if (timestamps == null) continue;

        // Parse HTML tags in text
        final text = _parseSrtText(textLines.join('\n'));

        cues.add(SubtitleCue(
          start: timestamps.$1,
          end: timestamps.$2,
          text: text,
        ));
      }
    } catch (e) {
      // Return empty list on parse error
    }

    return cues;
  }

  /// Parse WebVTT format subtitles
  static List<SubtitleCue> parseVtt(String content) {
    final cues = <SubtitleCue>[];

    if (content.isEmpty) return cues;

    try {
      // Normalize line endings
      final normalized =
          content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

      // Remove WEBVTT header and metadata
      var lines = normalized.split('\n');

      // Skip header
      int startIndex = 0;
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].trim().startsWith('WEBVTT')) {
          startIndex = i + 1;
          break;
        }
      }

      // Skip NOTE blocks and STYLE blocks
      final blocks = <String>[];
      var currentBlock = StringBuffer();

      for (int i = startIndex; i < lines.length; i++) {
        final line = lines[i].trim();

        if (line.startsWith('NOTE') || line.startsWith('STYLE')) {
          // Skip note and style blocks
          while (i < lines.length && lines[i].trim().isNotEmpty) {
            i++;
          }
          continue;
        }

        if (line.isEmpty) {
          if (currentBlock.isNotEmpty) {
            blocks.add(currentBlock.toString());
            currentBlock = StringBuffer();
          }
        } else {
          currentBlock.writeln(line);
        }
      }

      // Add last block
      if (currentBlock.isNotEmpty) {
        blocks.add(currentBlock.toString());
      }

      for (final block in blocks) {
        final blockLines = block.trim().split('\n');
        String? timeLine;
        final textLines = <String>[];

        for (final line in blockLines) {
          if (line.contains('-->')) {
            timeLine = line;
          } else if (line.trim().isNotEmpty) {
            textLines.add(line);
          }
        }

        if (timeLine == null || textLines.isEmpty) continue;

        final timestamps = _parseVttTimestamp(timeLine);
        if (timestamps == null) continue;

        final text = textLines.join('\n');

        cues.add(SubtitleCue(
          start: timestamps.$1,
          end: timestamps.$2,
          text: text,
        ));
      }
    } catch (e) {
      // Return empty list on parse error
    }

    return cues;
  }

  /// Parse ASS/SSA format subtitles
  static List<SubtitleCue> parseAss(String content) {
    final cues = <SubtitleCue>[];

    if (content.isEmpty) return cues;

    try {
      // Normalize line endings
      final normalized =
          content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      final lines = normalized.split('\n');

      // Parse events section
      bool inEvents = false;
      final dialogueLines = <String>[];

      for (final line in lines) {
        if (line.trim().toLowerCase() == '[events]') {
          inEvents = true;
          continue;
        }

        if (inEvents && line.trim().toLowerCase() == '[events]') {
          break;
        }

        if (inEvents && line.toLowerCase().startsWith('dialogue:')) {
          dialogueLines.add(line);
        }
      }

      for (final dialogue in dialogueLines) {
        final cue = _parseAssDialogue(dialogue);
        if (cue != null) {
          cues.add(cue);
        }
      }

      // Sort by start time
      cues.sort((a, b) => a.start.compareTo(b.start));
    } catch (e) {
      // Return empty list on parse error
    }

    return cues;
  }

  /// Parse ASS Dialogue line
  static SubtitleCue? _parseAssDialogue(String line) {
    try {
      // Remove "Dialogue:" prefix
      final content = line.substring(9).trim();

      // Split by comma (ASS uses comma as delimiter)
      final parts = content.split(',');

      if (parts.length < 10) return null;

      // Parse timestamps (parts 1 and 2)
      final startTime = _parseAssTimestamp(parts[1].trim());
      final endTime = _parseAssTimestamp(parts[2].trim());

      if (startTime == null || endTime == null) return null;

      // Parts 3-9 are style info, part 10+ is text
      final text = parts.sublist(9).join(',').trim();

      // Parse style for bold/italic
      final style = parts[2].trim(); // Style name
      SubtitleStyle? subtitleStyle;

      // Check for override tags in text
      final hasBold = text.contains('\\b1') || text.contains('\\btrue');
      final hasItalic = text.contains('\\i1') || text.contains('\\itrue');

      if (hasBold || hasItalic) {
        subtitleStyle = SubtitleStyle(
          bold: hasBold,
          italic: hasItalic,
        );
      }

      // Strip ASS tags from text for display
      final cleanText = _stripAssTags(text);

      return SubtitleCue(
        start: startTime,
        end: endTime,
        text: cleanText,
        style: subtitleStyle,
      );
    } catch (e) {
      return null;
    }
  }

  /// Strip ASS override tags from text
  static String _stripAssTags(String text) {
    // Remove {\...} blocks
    var result = text.replaceAll(RegExp(r'\{[^}]*\}'), '');
    // Remove \N and \n (line breaks)
    result = result.replaceAll('\\N', '\n').replaceAll(r'\n', '\n');
    return result.trim();
  }

  /// Parse SRT timestamp (00:00:00,000)
  static (Duration, Duration)? _parseSrtTimestamp(String line) {
    try {
      final parts = line.split('-->');
      if (parts.length != 2) return null;

      final start = _parseSrtTime(parts[0].trim());
      final end = _parseSrtTime(parts[1].trim());

      if (start == null || end == null) return null;
      return (start, end);
    } catch (e) {
      return null;
    }
  }

  /// Parse SRT time string
  static Duration? _parseSrtTime(String time) {
    try {
      // Format: 00:00:00,000
      final parts = time.split(':');
      if (parts.length != 3) return null;

      final hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);
      final secondsParts = parts[2].split(',');
      final seconds = int.parse(secondsParts[0]);
      final milliseconds = int.parse(secondsParts[1]);

      return Duration(
        hours: hours,
        minutes: minutes,
        seconds: seconds,
        milliseconds: milliseconds,
      );
    } catch (e) {
      return null;
    }
  }

  /// Parse VTT timestamp (00:00:00.000)
  static (Duration, Duration)? _parseVttTimestamp(String line) {
    try {
      final parts = line.split('-->');
      if (parts.length != 2) return null;

      var startStr = parts[0].trim();
      var endStr = parts[1].trim();

      // Remove cue settings (position, line, etc.)
      if (endStr.contains(' ')) {
        endStr = endStr.split(' ')[0];
      }

      final start = _parseVttTime(startStr);
      final end = _parseVttTime(endStr);

      if (start == null || end == null) return null;
      return (start, end);
    } catch (e) {
      return null;
    }
  }

  /// Parse VTT time string
  static Duration? _parseVttTime(String time) {
    try {
      // Format: 00:00:00.000 or 00:00.000
      final parts = time.split(':');

      int hours = 0;
      int minutes;
      String secondsPart;

      if (parts.length == 3) {
        hours = int.parse(parts[0]);
        minutes = int.parse(parts[1]);
        secondsPart = parts[2];
      } else if (parts.length == 2) {
        minutes = int.parse(parts[0]);
        secondsPart = parts[1];
      } else {
        return null;
      }

      final secondsParts = secondsPart.split('.');
      final seconds = int.parse(secondsParts[0]);
      final milliseconds = secondsParts.length > 1
          ? int.parse(secondsParts[1].padRight(3, '0').substring(0, 3))
          : 0;

      return Duration(
        hours: hours,
        minutes: minutes,
        seconds: seconds,
        milliseconds: milliseconds,
      );
    } catch (e) {
      return null;
    }
  }

  /// Parse ASS timestamp (H:MM:SS.cc)
  static Duration? _parseAssTimestamp(String time) {
    try {
      // Format: H:MM:SS.cc (centiseconds)
      final parts = time.split(':');
      if (parts.length != 3) return null;

      final hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);
      final secondsParts = parts[2].split('.');
      final seconds = int.parse(secondsParts[0]);
      final centiseconds = int.parse(secondsParts[1]);
      final milliseconds = centiseconds * 10;

      return Duration(
        hours: hours,
        minutes: minutes,
        seconds: seconds,
        milliseconds: milliseconds,
      );
    } catch (e) {
      return null;
    }
  }

  /// Parse HTML tags in SRT text
  static String _parseSrtText(String text) {
    // Remove HTML tags
    var result = text.replaceAll(RegExp(r'<[^>]*>'), '');
    // Convert common HTML entities
    result = result
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    return result.trim();
  }
}
