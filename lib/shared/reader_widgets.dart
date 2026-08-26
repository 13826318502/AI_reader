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

class _BookTurnPage extends StatelessWidget {
  final PageController controller;
  final int index;
  final Widget child;

  const _BookTurnPage({
    required this.controller,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final page = controller.hasClients && controller.page != null
            ? controller.page!
            : index.toDouble();
        final delta = (page - index).clamp(-1.0, 1.0);
        final progress = delta.abs();
        // PageView 会预构建相邻页；静止态不对相邻页做 3D 变换，
        // 避免变换后的边缘从页面缝隙中露出斜线。
        if (progress < .01 || progress > .98) return child!;

        final forward = delta > 0;
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateY(forward ? -progress * .28 : progress * .28);
        return ClipRect(
          child: Transform(
            alignment: forward ? Alignment.centerLeft : Alignment.centerRight,
            transform: transform,
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.22 * progress),
                    blurRadius: 18 * progress,
                    offset: Offset(forward ? -8 : 8, 0),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  child!,
                  Align(
                    alignment: forward
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: .16 * progress,
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
                              Colors.black.withOpacity(.20 * progress),
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
          ),
        );
      },
    );
  }
}
