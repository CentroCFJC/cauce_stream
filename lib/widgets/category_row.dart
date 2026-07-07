import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/category.dart';
import '../models/video_item.dart';
import 'video_card.dart';

class CategoryRow extends StatefulWidget {
  final Category category;
  final ValueChanged<VideoItem> onVideoSelected;
  final bool initialFocus;
  final List<FocusNode>? videoFocusNodes;
  final List<VoidCallback?>? upCallbacks;
  final List<VoidCallback?>? downCallbacks;
  final ScrollController? scrollController;

  const CategoryRow({
    super.key,
    required this.category,
    required this.onVideoSelected,
    this.initialFocus = false,
    this.videoFocusNodes,
    this.upCallbacks,
    this.downCallbacks,
    this.scrollController,
  });

  @override
  State<CategoryRow> createState() => _CategoryRowState();
}

class _CategoryRowState extends State<CategoryRow> {

  double _cardWidth(BuildContext context) {
    return MediaQuery.of(context).size.width * 0.22;
  }

  void _scrollToCenter(int index, ScrollController controller, BuildContext context) {
    if (!controller.hasClients || !controller.position.hasContentDimensions) return;
    final double itemWidth = _cardWidth(context) + 20; // 20 is exactly the total horizontal margin in VideoCard (10 left + 10 right)
    final double paddingStart = MediaQuery.of(context).size.width * 0.015;
    final double viewportWidth = controller.position.viewportDimension;
    if (viewportWidth <= 0) return;
    
    final double itemCenter = paddingStart + (index * itemWidth) + (itemWidth / 2);
    final double targetOffset = itemCenter - (viewportWidth / 2);
    
    final double clampedOffset = targetOffset.clamp(
      0.0,
      controller.position.maxScrollExtent,
    );
    
    if ((clampedOffset - controller.offset).abs() < 1.0) return;
    
    controller.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutQuad,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.scrollController;
    final sh = MediaQuery.of(context).size.height;
    final cardH = _cardWidth(context) * (260 / 420) + 30;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(sh * 0.025, sh * 0.012, 0, sh * 0.008),
          child: Text(
            widget.category.name,
            style: TextStyle(
              color: Colors.white,
              fontSize: sh * 0.035,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: cardH,
          child: Stack(
            children: [
              ListView(
                controller: ctrl,
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.hardEdge,
                padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.015),
                children: widget.category.videos.asMap().entries.map((e) {
                  final video = e.value;
                  final index = e.key;

                  VoidCallback? onLeft;
                  if (index > 0 && widget.videoFocusNodes != null && index < widget.videoFocusNodes!.length) {
                    final prevNode = widget.videoFocusNodes![index - 1];
                    onLeft = () {
                      prevNode.requestFocus();
                    };
                  }

                  VoidCallback? onRight;
                  if (index < widget.category.videos.length - 1 && widget.videoFocusNodes != null && index + 1 < widget.videoFocusNodes!.length) {
                    final nextNode = widget.videoFocusNodes![index + 1];
                    onRight = () {
                      nextNode.requestFocus();
                    };
                  }

                  return _FocusableVideoCard(
                    key: ValueKey('${widget.category.id}_$index'),
                    video: video,
                    onSelected: () => widget.onVideoSelected(video),
                    autofocus: widget.initialFocus && index == 0,
                    focusNode: widget.videoFocusNodes != null && index < widget.videoFocusNodes!.length
                        ? widget.videoFocusNodes![index]
                        : null,
                    onFocus: () {
                      if (ctrl != null) {
                        _scrollToCenter(index, ctrl, context);
                      }
                    },
                    onUp: widget.upCallbacks != null && index < widget.upCallbacks!.length
                        ? widget.upCallbacks![index]
                        : null,
                    onDown: widget.downCallbacks != null && index < widget.downCallbacks!.length
                        ? widget.downCallbacks![index]
                        : null,
                    onLeft: onLeft,
                    onRight: onRight,
                    isFirst: index == 0,
                    isLast: index == widget.category.videos.length - 1,
                  );
                }).toList(),
              ),
              if (ctrl != null) ...[
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: MediaQuery.of(context).size.width * 0.04,
                  child: IgnorePointer(
                    child: ListenableBuilder(
                      listenable: ctrl,
                      builder: (context, _) {
                        final show = ctrl.hasClients && ctrl.position.hasContentDimensions && ctrl.offset > 0;
                        return AnimatedOpacity(
                          opacity: show ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  const Color(0xFF0A1628).withAlpha(230),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: MediaQuery.of(context).size.width * 0.04,
                  child: IgnorePointer(
                    child: ListenableBuilder(
                      listenable: ctrl,
                      builder: (context, _) {
                        final show = ctrl.hasClients && ctrl.position.hasContentDimensions && ctrl.offset < ctrl.position.maxScrollExtent;
                        return AnimatedOpacity(
                          opacity: show ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerRight,
                                end: Alignment.centerLeft,
                                colors: [
                                  const Color(0xFF0A1628).withAlpha(230),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: MediaQuery.of(context).size.height * 0.015),
      ],
    );
  }
}

class _FocusableVideoCard extends StatefulWidget {
  final VideoItem video;
  final VoidCallback onSelected;
  final bool autofocus;
  final FocusNode? focusNode;
  final VoidCallback? onFocus;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;
  final bool isFirst;
  final bool isLast;

  const _FocusableVideoCard({
    super.key,
    required this.video,
    required this.onSelected,
    this.autofocus = false,
    this.focusNode,
    this.onFocus,
    this.onUp,
    this.onDown,
    this.onLeft,
    this.onRight,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  State<_FocusableVideoCard> createState() => _FocusableVideoCardState();
}

class _FocusableVideoCardState extends State<_FocusableVideoCard> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _isFocused = widget.focusNode?.hasFocus ?? false;
  }

  @override
  void didUpdateWidget(_FocusableVideoCard old) {
    super.didUpdateWidget(old);
    if (widget.focusNode != old.focusNode) {
      _isFocused = widget.focusNode?.hasFocus ?? false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (focused) {
        if (mounted) setState(() => _isFocused = focused);
        if (focused && widget.onFocus != null) {
          widget.onFocus!();
        }
      },
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
            widget.onSelected();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp && widget.onUp != null) {
            widget.onUp!();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown && widget.onDown != null) {
            widget.onDown!();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onSelected,
        child: VideoCard(
          video: widget.video,
          isFocused: _isFocused,
        ),
      ),
    );
  }
}
