import 'package:material_ui/material_ui.dart';

/// 全站背景图路径，随包分发。
const herciniaBackgroundAsset = 'assets/images/hercinia_bg.jpg';

/// 给整棵 UI 铺一层 Hercinia 背景。
///
/// 背景固定在底层，[child] 之上的页面保持原有半透明材质，
/// 这样既能看到背景，也不会牺牲文字对比度。
class HerciniaBackdrop extends StatelessWidget {
  final Widget child;
  final double dim;

  const HerciniaBackdrop({
    super.key,
    required this.child,
    this.dim = 0.35,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          herciniaBackgroundAsset,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black),
        ),
        ColoredBox(
          color: isDark
              ? Colors.black.withValues(alpha: dim)
              : Colors.white.withValues(alpha: dim * 0.6),
        ),
        child,
      ],
    );
  }
}
