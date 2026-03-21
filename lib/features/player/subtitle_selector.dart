import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/subtitles/opensubtitles_service.dart';
import '../../core/subtitles/subtitle_service.dart';

/// Subtitle selector bottom sheet for player
class SubtitleSelectorSheet extends ConsumerStatefulWidget {
  final SubtitleTrackList trackList;
  final SubtitleTrack? currentTrack;
  final Function(SubtitleTrack?) onTrackSelected;
  final String? imdbId;

  const SubtitleSelectorSheet({
    super.key,
    required this.trackList,
    this.currentTrack,
    required this.onTrackSelected,
    this.imdbId,
  });

  @override
  ConsumerState<SubtitleSelectorSheet> createState() => _SubtitleSelectorSheetState();
}

class _SubtitleSelectorSheetState extends ConsumerState<SubtitleSelectorSheet> {
  bool _isSearching = false;
  String _selectedLanguage = 'en';
  List<SubtitleResult> _searchResults = [];
  bool _isLoadingResults = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A28),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF4A5568),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Subtitles',
                  style: TextStyle(
                    color: Color(0xFFE8EDF2),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (!_isSearching)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isSearching = true;
                      });
                    },
                    icon: const Icon(
                      Icons.search,
                      color: Color(0xFF4A6FA5),
                      size: 20,
                    ),
                    label: const Text(
                      'Search more...',
                      style: TextStyle(
                        color: Color(0xFF4A6FA5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Content
          if (_isSearching)
            _buildSearchContent()
          else
            _buildTrackList(),
          
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildTrackList() {
    final tracks = widget.trackList.tracks;
    
    return Flexible(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Off option
          _buildTrackTile(
            label: 'Off',
            isSelected: widget.currentTrack == null,
            onTap: () {
              widget.onTrackSelected(null);
              Navigator.pop(context);
            },
          ),
          
          // Embedded tracks (if any)
          if (widget.trackList.hasEmbedded)
            _buildSectionHeader('Stream'),
          
          ...tracks
              .where((t) => t.source == SubtitleSource.stream)
              .map((track) => _buildTrackTile(
                    label: track.label,
                    isSelected: widget.currentTrack?.url == track.url,
                    onTap: () {
                      widget.onTrackSelected(track);
                      Navigator.pop(context);
                    },
                  )),
          
          // Provider tracks (if any)
          if (widget.trackList.hasProvider)
            _buildSectionHeader('Provider'),
          
          ...tracks
              .where((t) => t.source == SubtitleSource.provider)
              .map((track) => _buildTrackTile(
                    label: track.label,
                    isSelected: widget.currentTrack?.url == track.url,
                    onTap: () {
                      widget.onTrackSelected(track);
                      Navigator.pop(context);
                    },
                  )),
          
          // OpenSubtitles tracks (if any)
          if (widget.trackList.hasOpenSubtitles)
            _buildSectionHeader('OpenSubtitles'),
          
          ...tracks
              .where((t) => t.source == SubtitleSource.opensubtitles)
              .map((track) => _buildTrackTile(
                    label: track.label,
                    isSelected: widget.currentTrack?.url == track.url,
                    onTap: () {
                      widget.onTrackSelected(track);
                      Navigator.pop(context);
                    },
                  )),
        ],
      ),
    );
  }

  Widget _buildSearchContent() {
    return Flexible(
      child: Column(
        children: [
          // Back button and language selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                      _searchResults = [];
                    });
                  },
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Color(0xFFE8EDF2),
                  ),
                ),
                const Text(
                  'Search OpenSubtitles',
                  style: TextStyle(
                    color: Color(0xFFE8EDF2),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          
          // Language picker
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildLanguagePicker(),
          ),
          
          // Search button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A6FA5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _isLoadingResults ? null : _searchOpenSubtitles,
                child: _isLoadingResults
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFE8EDF2),
                        ),
                      )
                    : const Text('Search'),
              ),
            ),
          ),
          
          // Results list
          if (_searchResults.isNotEmpty)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  return _buildSearchResultTile(result);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLanguagePicker() {
    final languages = [
      ('en', 'English'),
      ('hi', 'Hindi'),
      ('ta', 'Tamil'),
      ('te', 'Telugu'),
      ('ml', 'Malayalam'),
      ('ja', 'Japanese'),
      ('ko', 'Korean'),
      ('es', 'Spanish'),
      ('fr', 'French'),
      ('de', 'German'),
      ('pt', 'Portuguese'),
      ('ru', 'Russian'),
      ('zh', 'Chinese'),
      ('ar', 'Arabic'),
    ];

    return DropdownButtonFormField<String>(
      value: _selectedLanguage,
      dropdownColor: const Color(0xFF2A3A50),
      style: const TextStyle(color: Color(0xFFE8EDF2)),
      decoration: InputDecoration(
        labelText: 'Language',
        labelStyle: const TextStyle(color: Color(0xFF8B9BB0)),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF2A3A50)),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF4A6FA5)),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      items: languages.map((lang) {
        return DropdownMenuItem(
          value: lang.$1,
          child: Text(lang.$2),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedLanguage = value;
          });
        }
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF8B9BB0),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTrackTile({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4A6FA5).withOpacity(0.2) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF4A6FA5) : const Color(0xFFE8EDF2),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check,
                  color: Color(0xFF4A6FA5),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultTile(SubtitleResult result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF12121A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A3A50)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _downloadAndSelect(result),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.language,
                        style: const TextStyle(
                          color: Color(0xFFE8EDF2),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result.fileName,
                        style: const TextStyle(
                          color: Color(0xFF8B9BB0),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${result.downloadCount} downloads',
                        style: const TextStyle(
                          color: Color(0xFF4A5568),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.download,
                  color: Color(0xFF4A6FA5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _searchOpenSubtitles() async {
    if (widget.imdbId == null || widget.imdbId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot search - no IMDB ID available'),
          backgroundColor: Color(0xFFFF6B6B),
        ),
      );
      return;
    }

    setState(() {
      _isLoadingResults = true;
    });

    try {
      final openSubtitles = ref.read(opensubtitlesServiceProvider);
      final results = await openSubtitles.search(widget.imdbId!, _selectedLanguage);
      
      setState(() {
        _searchResults = results;
        _isLoadingResults = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingResults = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching: $e'),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    }
  }

  Future<void> _downloadAndSelect(SubtitleResult result) async {
    try {
      final openSubtitles = ref.read(opensubtitlesServiceProvider);
      
      // Show loading
      setState(() {
        _isLoadingResults = true;
      });
      
      // Get download URL
      final downloadUrl = await openSubtitles.getDownloadUrl(result.fileId);
      if (downloadUrl == null) {
        throw Exception('Could not get download URL');
      }
      
      // Download to cache
      final filename = '${widget.imdbId}_${result.languageCode}_${result.fileId}.srt';
      final localPath = await openSubtitles.downloadToCache(downloadUrl, filename);
      
      // Create track and select it
      final track = SubtitleTrack(
        language: result.language,
        languageCode: result.languageCode,
        url: localPath,
        format: SubtitleFormat.srt,
        source: SubtitleSource.opensubtitles,
        label: '${result.language} (OpenSubtitles)',
        fileId: result.fileId,
      );
      
      widget.onTrackSelected(track);
      
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _isLoadingResults = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading: $e'),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    }
  }
}

/// Show subtitle selector bottom sheet
void showSubtitleSelector(
  BuildContext context, {
  required SubtitleTrackList trackList,
  SubtitleTrack? currentTrack,
  required Function(SubtitleTrack?) onTrackSelected,
  String? imdbId,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) => SubtitleSelectorSheet(
        trackList: trackList,
        currentTrack: currentTrack,
        onTrackSelected: onTrackSelected,
        imdbId: imdbId,
      ),
    ),
  );
}
