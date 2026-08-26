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

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage.clamp(0, widget.pageCount - 1);
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
  void dispose() {
    _animation.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void jumpToPage(int page) {
    final target = page.clamp(0, widget.pageCount - 1);
    if (widget.mode == 'curl') {
      setState(() => _page = target);
      widget.onPageChanged(target);
    } else if (_pageController.hasClients) {
      _pageController.jumpToPage(target);
    }
  }

  void _animateTo(double target, {bool commit = false}) {
    _turn = Tween<double>(
      begin: _dragProgress,
      end: target,
    ).animate(CurvedAnimation(parent: _animation, curve: Curves.easeOutCubic));
    _animation.forward(from: 0).whenComplete(() {
      if (!mounted) return;
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
    if (_animation.isAnimating) return;
    final next = (_dragProgress - details.delta.dx / _dragWidth).clamp(
      -1.0,
      1.0,
    );
    if ((next > 0 && _page == widget.pageCount - 1) ||
        (next < 0 && _page == 0)) {
      setState(() => _dragProgress = next * .16);
      return;
    }
    setState(() => _dragProgress = next);
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dragProgress.abs() > .18 && _dragProgress.sign != 0) {
      _animateTo(_dragProgress.sign, commit: true);
    } else {
      _animateTo(0);
    }
  }

  Widget _buildPageAt(int index) =>
      Positioned.fill(child: widget.pageBuilder(index));

  Widget _curlPage(double progress) {
    final direction = progress.sign;
    final amount = progress.abs().clamp(0.0, 1.0);
    final target = (_page + direction.toInt()).clamp(0, widget.pageCount - 1);
    final forward = direction > 0;
    final rotation = forward ? -amount * 1.570796 : amount * 1.570796;
    final transform = Matrix4.identity()
      ..setEntry(3, 2, 0.0016)
      ..rotateY(rotation);
    return LayoutBuilder(
      builder: (context, constraints) {
        _dragWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : 1;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildPageAt(target),
                if (amount < .999)
                  Transform(
                    alignment: forward
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    transform: transform,
                    transformHitTests: false,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.34 * amount),
                            blurRadius: 22 * amount,
                            spreadRadius: 1.5,
                            offset: Offset(forward ? -10 : 10, 0),
                          ),
                        ],
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          widget.pageBuilder(_page),
                          Align(
                            alignment: forward
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            child: FractionallySizedBox(
                              widthFactor: .24 * amount,
                              child: DecoratedBox(
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
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                if (amount > .02)
                  Align(
                    alignment: forward
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: .018,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.48 * amount),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(.3 * amount),
                              blurRadius: 9,
                            ),
                          ],
                        ),
                      ),
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
