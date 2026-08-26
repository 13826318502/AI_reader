part of '../main.dart';

class _ReadingPageContent extends StatelessWidget {
  final List<Widget> children;
  const _ReadingPageContent({required this.children});
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      ReadingPreferencesStore.horizontalPadding,
      16,
      ReadingPreferencesStore.horizontalPadding,
      24,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

class _ReaderTool extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ReaderTool({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Column(
      children: [
        Icon(icon, size: 20),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    ),
  );
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  const _InfoLine(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.black54, fontSize: 11),
        ),
        Text(
          value,
          style: const TextStyle(color: Colors.black54, fontSize: 11),
        ),
      ],
    ),
  );
}

class _PageRevealClipper extends CustomClipper<Path> {
  final double visibleFraction;
  final bool revealFromRight;

  const _PageRevealClipper({
    required this.visibleFraction,
    required this.revealFromRight,
  });

  @override
  Path getClip(Size size) {
    final width = size.width * visibleFraction.clamp(0.0, 1.0);
    final left = revealFromRight ? 0.0 : size.width - width;
    return Path()..addRect(Rect.fromLTWH(left, 0, width, size.height));
  }

  @override
  bool shouldReclip(covariant _PageRevealClipper oldClipper) =>
      oldClipper.visibleFraction != visibleFraction ||
      oldClipper.revealFromRight != revealFromRight;
}

class _PaperTexturePainter extends CustomPainter {
  const _PaperTexturePainter();

  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(covariant _PaperTexturePainter oldDelegate) => false;
}

class _BookReaderViewport extends StatefulWidget {
  final int pageCount;
  final int initialPage;
  final String mode;
  final Widget Function(int page) pageBuilder;
  final ValueChanged<int> onPageChanged;

  const _BookReaderViewport({
    super.key,
    required this.pageCount,
    required this.initialPage,
    required this.mode,
    required this.pageBuilder,
    required this.onPageChanged,
  });

  @override
  State<_BookReaderViewport> createState() => _BookReaderViewportState();
}

class _BookReaderViewportState extends State<_BookReaderViewport>
    with SingleTickerProviderStateMixin {
  late int _page;
  double _dragProgress = 0;
  double _dragWidth = 1;
  late final AnimationController _animation;
  late final PageController _pageController;
  Animation<double>? _turn;
  int _animationGeneration = 0;

  @override
  void initState() {
    super.initState();
    _page = widget.pageCount == 0
        ? 0
        : widget.initialPage.clamp(0, widget.pageCount - 1);
    _pageController = PageController(initialPage: _page);
    _animation =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 560),
        )..addListener(() {
          if (_turn != null) setState(() => _dragProgress = _turn!.value);
        });
  }

  @override
  void didUpdateWidget(covariant _BookReaderViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pageCount == 0) return;
    final target = widget.initialPage.clamp(0, widget.pageCount - 1);
    if (target == _page && oldWidget.mode == widget.mode) return;
    _animationGeneration++;
    _animation.stop();
    _turn = null;
    _dragProgress = 0;
    _page = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients)
        _pageController.jumpToPage(_page);
    });
  }

  @override
  void dispose() {
    _animation.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void jumpToPage(int page) {
    if (widget.pageCount == 0) return;
    final target = page.clamp(0, widget.pageCount - 1);
    if (widget.mode == 'curl') {
      setState(() => _page = target);
      widget.onPageChanged(target);
    } else if (_pageController.hasClients) {
      _pageController.jumpToPage(target);
    }
  }

  void _animateTo(double target, {bool commit = false}) {
    final generation = ++_animationGeneration;
    _turn = Tween<double>(
      begin: _dragProgress,
      end: target,
    ).animate(CurvedAnimation(parent: _animation, curve: Curves.easeOutCubic));
    _animation.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      if (generation != _animationGeneration) return;
      if (commit) {
        final direction = target.sign.toInt();
        _page = (_page + direction).clamp(0, widget.pageCount - 1);
        widget.onPageChanged(_page);
      }
      setState(() {
        _dragProgress = 0;
        _turn = null;
      });
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_animation.isAnimating) {
      // Let a new gesture take over an unfinished turn. This keeps the page
      // physically draggable at half-turn instead of forcing a full snap.
      _animationGeneration++;
      _animation.stop(canceled: false);
      _turn = null;
    }
    final next = (_dragProgress - details.delta.dx / _dragWidth).clamp(
      -1.0,
      1.0,
    );
    if ((next > 0 && _page == widget.pageCount - 1) ||
        (next < 0 && _page == 0)) {
      setState(() => _dragProgress = next * .16);
      return;
    }
    if (next.abs() >= .999) {
      final direction = next.sign.toInt();
      _page = (_page + direction).clamp(0, widget.pageCount - 1);
      widget.onPageChanged(_page);
      setState(() => _dragProgress = 0);
      return;
    }
    setState(() => _dragProgress = next);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocityProgress = details.primaryVelocity == null
        ? 0.0
        : (-details.primaryVelocity! / (_dragWidth * 5.2));
    final intended = (_dragProgress + velocityProgress).clamp(-1.0, 1.0);
    if (intended.abs() > .18 && intended.sign != 0) {
      _animateTo(intended.sign, commit: true);
    } else {
      _animateTo(0);
    }
  }

  Widget _curlPage(double progress) {
    final direction = progress.sign;
    final amount = progress.abs().clamp(0.0, 1.0);
    final target = (_page + direction.toInt()).clamp(0, widget.pageCount - 1);
    final forward = direction > 0;
    Widget paperPage(int index) => RepaintBoundary(
      key: ValueKey('reader-page-$index'),
      child: CustomPaint(
        painter: const _PaperTexturePainter(),
        child: widget.pageBuilder(index),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        _dragWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : 1;
        final visibleFraction = 1 - amount;
        final foldWidth = (constraints.maxWidth * .11).clamp(28.0, 76.0);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: ClipPath(
                    // During a forward turn, only the right side of the
                    // target page is revealed. The backward turn mirrors it
                    // on the left, preventing both pages from overlapping.
                    clipper: _PageRevealClipper(
                      visibleFraction: amount,
                      revealFromRight: !forward,
                    ),
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFF7EFE2),
                            Color(0xFFF1E4D1),
                            Color(0xFFF8EEDD),
                          ],
                        ),
                      ),
                      child: paperPage(target),
                    ),
                  ),
                ),
                if (amount < .999)
                  Positioned.fill(
                    child: ClipPath(
                      clipper: _PageRevealClipper(
                        visibleFraction: visibleFraction,
                        revealFromRight: forward,
                      ),
                      child: paperPage(_page),
                    ),
                  ),
                if (amount > .02)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: forward
                        ? constraints.maxWidth * visibleFraction - foldWidth / 2
                        : null,
                    right: forward
                        ? null
                        : constraints.maxWidth * visibleFraction -
                              foldWidth / 2,
                    width: foldWidth,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Transform.translate(
                          offset: Offset(forward ? 3 : -3, 0),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFFC8B7A1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(.30 * amount),
                                  blurRadius: 9 * amount,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: forward
                                  ? Alignment.centerLeft
                                  : Alignment.centerRight,
                              end: forward
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              colors: [
                                Colors.black.withOpacity(.32 * amount),
                                const Color(0xFFEBD9C1),
                                const Color(0xFFF9F0E3),
                                Colors.white.withOpacity(.66 * amount),
                              ],
                            ),
                            border: Border(
                              left: forward
                                  ? BorderSide(
                                      color: Colors.black.withOpacity(
                                        .22 * amount,
                                      ),
                                      width: 1,
                                    )
                                  : BorderSide.none,
                              right: forward
                                  ? BorderSide.none
                                  : BorderSide(
                                      color: Colors.black.withOpacity(
                                        .22 * amount,
                                      ),
                                      width: 1,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pageCount <= 0) return const SizedBox.shrink();
    if (widget.mode == 'curl') return _curlPage(_dragProgress);
    return PageView.builder(
      controller: _pageController,
      pageSnapping: widget.mode != 'none',
      physics: widget.mode == 'none'
          ? const NeverScrollableScrollPhysics()
          : const PageScrollPhysics(),
      itemCount: widget.pageCount,
      onPageChanged: (value) {
        _page = value;
        widget.onPageChanged(value);
      },
      itemBuilder: (_, index) => widget.pageBuilder(index),
    );
  }
}
