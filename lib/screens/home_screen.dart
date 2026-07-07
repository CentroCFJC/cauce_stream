import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/category.dart';
import '../models/video_item.dart';
import '../services/google_drive_service.dart';
import '../widgets/category_row.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GoogleDriveService _driveService = GoogleDriveService();
  final FocusNode _heroFocus = FocusNode();
  final FocusNode _playButtonFocus = FocusNode();
  final FocusNode _moreInfoFocus = FocusNode();
  List<Category> _categories = [];
  List<List<FocusNode>> _videoFocusGrid = [];
  List<ScrollController> _hScrollControllers = [];
  final ScrollController _verticalScrollController = ScrollController();
  final List<GlobalKey> _categoryKeys = [];
  bool _loading = true;
  String? _error;
  VideoItem? _selectedVideo;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final categories = await _driveService.fetchCatalog();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _categoryKeys
          ..clear()
          ..addAll(categories.map((_) => GlobalKey()));
        _videoFocusGrid = categories.map((cat) =>
          List.generate(cat.videos.length, (_) => FocusNode())
        ).toList();
        _hScrollControllers = categories.map((_) => ScrollController()).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error al cargar el contenido';
        _loading = false;
      });
    }
  }

  void _selectVideo(VideoItem video) {
    setState(() => _selectedVideo = video);
    Future.microtask(() => _playButtonFocus.requestFocus());
  }

  void _playVideo(VideoItem video) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerScreen(video: video)),
    );
  }

  @override
  void dispose() {
    _heroFocus.dispose();
    _playButtonFocus.dispose();
    _moreInfoFocus.dispose();
    _verticalScrollController.dispose();
    for (final row in _videoFocusGrid) {
      for (final node in row) {
        node.dispose();
      }
    }
    for (final ctrl in _hScrollControllers) {
      ctrl.dispose();
    }
    _driveService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedVideo == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedVideo != null) {
          setState(() => _selectedVideo = null);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1628),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF1565C0)),
            SizedBox(height: 16),
            Text(
              'Cargando contenido...',
              style: TextStyle(color: Colors.white70, fontSize: 22),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFF1565C0), size: 80),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.white, fontSize: 24)),
            const SizedBox(height: 24),
            _RetryButton(onRetry: _loadCatalog),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: Column(
                  children: [
                    if (_selectedVideo != null) _buildHeroBanner(),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _verticalScrollController,
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          children: _categories.asMap().entries.map((e) {
                            final catIndex = e.key;
                            final rowNodes = _videoFocusGrid.length > catIndex
                                ? _videoFocusGrid[catIndex]
                                : <FocusNode>[];
                            final isLast = catIndex == _categories.length - 1;

                            final prevNodes = catIndex > 0
                                ? _videoFocusGrid[catIndex - 1]
                                : null;
                            final nextNodes = !isLast && _videoFocusGrid.length > catIndex + 1
                                ? _videoFocusGrid[catIndex + 1]
                                : null;

                            final List<VoidCallback?> upCbs;
                            if (catIndex == 0) {
                              if (_selectedVideo != null) {
                                upCbs = rowNodes.map((_) => () => _playButtonFocus.requestFocus()).toList();
                              } else {
                                upCbs = rowNodes.map((_) => null).toList();
                              }
                            } else if (prevNodes != null && prevNodes.isNotEmpty) {
                              final targetNode = prevNodes[0];
                              final targetCtrl = _hScrollControllers[catIndex - 1];
                              upCbs = rowNodes.map((_) => () {
                                if (targetCtrl.hasClients) targetCtrl.jumpTo(0);
                                targetNode.requestFocus();
                                _scrollIntoView(targetNode);
                              }).toList();
                            } else {
                              upCbs = rowNodes.map((_) => null).toList();
                            }

                            final List<VoidCallback?> downCbs;
                            if (nextNodes != null && nextNodes.isNotEmpty) {
                              final targetNode = nextNodes[0];
                              final targetCtrl = _hScrollControllers[catIndex + 1];
                              downCbs = rowNodes.map((_) => () {
                                if (targetCtrl.hasClients) targetCtrl.jumpTo(0);
                                targetNode.requestFocus();
                                _scrollIntoView(targetNode);
                              }).toList();
                            } else {
                              downCbs = rowNodes.map((_) => null).toList();
                            }

                            return CategoryRow(
                              key: _categoryKeys[catIndex],
                              category: e.value,
                              onVideoSelected: _selectVideo,
                              initialFocus: catIndex == 0,
                              videoFocusNodes: rowNodes,
                              upCallbacks: upCbs,
                              downCallbacks: downCbs,
                              scrollController: _hScrollControllers[catIndex],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

void _scrollIntoView(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCategoryRow(node);
    });
  }

  void _scrollToCategoryRow(FocusNode node) {
    for (int i = 0; i < _videoFocusGrid.length; i++) {
      if (_videoFocusGrid[i].contains(node) && i < _categoryKeys.length) {
        final key = _categoryKeys[i];
        if (key.currentContext != null) {
          Scrollable.ensureVisible(
            key.currentContext!,
            alignment: 0.0,
            duration: const Duration(milliseconds: 200),
          );
        }
        break;
      }
    }
  }

  Widget _buildTopBar() {
    final sh = MediaQuery.of(context).size.height;
    return Container(
      height: sh * 0.09,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D1D34), Color(0xFF0A1628)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          Image.network(
            'https://res.cloudinary.com/dqgd5r847/image/upload/v1781198321/logo_cauce_blanco_completo_kgcj3s.png',
            height: sh * 0.055,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner() {
    Widget heroContent;
    if (_selectedVideo != null) {
      heroContent = Focus(
        focusNode: _heroFocus,
        skipTraversal: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.escape ||
               event.logicalKey == LogicalKeyboardKey.gameButtonB)) {
            setState(() => _selectedVideo = null);
            return KeyEventResult.handled;
          }
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp) {
            return KeyEventResult.handled;
          }
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowDown) {
            if (_videoFocusGrid.isNotEmpty && _videoFocusGrid[0].isNotEmpty) {
              if (_hScrollControllers.isNotEmpty) {
                _hScrollControllers[0].jumpTo(0);
              }
              _videoFocusGrid[0][0].requestFocus();
              _scrollIntoView(_videoFocusGrid[0][0]);
            }
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: _buildHeroVideo(),
      );
    } else {
      heroContent = _buildHeroDefault();
    }
    final sh = MediaQuery.of(context).size.height;
    return Stack(
      children: [
        heroContent,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: sh * 0.12,
          child: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                    colors: [
                    Color(0xFF0A1628),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroDefault() {
    final sh = MediaQuery.of(context).size.height;
    return Container(
      width: double.infinity,
      height: sh * 0.48,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D1D34), Color(0xFF0A1628)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  Widget _buildHeroVideo() {
    final sh = MediaQuery.of(context).size.height;
    final video = _selectedVideo!;
    return SizedBox(
      height: sh * 0.48,
      child: Stack(
        children: [
          _buildHeroVideoBackground(video, sh),
          Positioned(
            left: 56,
            right: 56,
            bottom: 0,
            top: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: sh * 0.055),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Text(
                          video.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: sh * 0.038,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(height: sh * 0.022),
                      Row(
                        children: [
                          _HeroActionButton(
                            focusNode: _playButtonFocus,
                            autofocus: true,
                            onPressed: () => _playVideo(video),
                            icon: Icons.play_arrow,
                            label: 'Reproducir',
                            primary: true,
                            onRight: () => _moreInfoFocus.requestFocus(),
                            isFirst: true,
                          ),
                          const SizedBox(width: 20),
                          _HeroActionButton(
                            focusNode: _moreInfoFocus,
                            onPressed: () {},
                            icon: Icons.info_outline,
                            label: 'Más información',
                            primary: false,
                            onLeft: () => _playButtonFocus.requestFocus(),
                            isLast: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroVideoBackground(VideoItem video, double sh) {
    final thumb = video.thumbnailUrl;
    if (thumb != null) {
      return CachedNetworkImage(
        imageUrl: thumb,
        width: double.infinity,
      height: sh * 0.48,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _buildHeroFallback(),
      );
    }
    return _buildHeroFallback();
  }

  Widget _buildHeroFallback() {
    final sh = MediaQuery.of(context).size.height;
    return Container(
      width: double.infinity,
      height: sh * 0.48,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D1D34), Color(0xFF0A1628)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }
}

class _HeroActionButton extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final bool primary;
  final FocusNode? focusNode;
  final bool autofocus;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;
  final bool isFirst;
  final bool isLast;

  const _HeroActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.primary,
    this.focusNode,
    this.autofocus = false,
    this.onLeft,
    this.onRight,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  State<_HeroActionButton> createState() => _HeroActionButtonState();
}

class _HeroActionButtonState extends State<_HeroActionButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (widget.onRight == null && event.logicalKey == LogicalKeyboardKey.arrowRight) {
          return KeyEventResult.handled;
        }
        if (widget.onLeft == null && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          return KeyEventResult.handled;
        }
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            widget.onLeft!();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            widget.onRight!();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select) {
            widget.onPressed();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.height * 0.028, vertical: MediaQuery.of(context).size.height * 0.013),
          decoration: BoxDecoration(
            color: _isFocused
                ? (widget.primary
                    ? const Color(0xFF1565C0)
                    : const Color(0xFF0D47A1))
                : (widget.primary
                    ? Colors.white
                    : const Color(0x2AFFFFFF)),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _isFocused ? Colors.white : Colors.transparent,
              width: 3,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: widget.primary
                          ? const Color(0xFF1565C0).withAlpha(120)
                          : const Color(0xFF0D47A1).withAlpha(120),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon,
                  size: MediaQuery.of(context).size.height * 0.025,
                  color: _isFocused ? Colors.white : (widget.primary ? Colors.black : Colors.white)),
              const SizedBox(width: 12),
              Text(widget.label,
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.height * 0.019,
                    fontWeight: FontWeight.w600,
                    color: _isFocused ? Colors.white : (widget.primary ? Colors.black : Colors.white),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  final VoidCallback onRetry;

  const _RetryButton({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onRetry,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1565C0),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      ),
      child: const Text('Reintentar',
          style: TextStyle(color: Colors.white, fontSize: 20)),
    );
  }
}
