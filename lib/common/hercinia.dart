import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Hercinia Network 专属订阅地址。
const herciniaSubscriptionUrl = 'https://pool.hercinia.kdns.fr/clash.yaml';

/// 官网与社群入口。
const herciniaPortalUrl = 'https://pool.hercinia.kdns.fr/';
const herciniaTelegramUrl = 'https://t.me/HerciniaNetwork';

/// 首次启动时把 Hercinia 专属订阅写进配置。
///
/// 返回 true 表示本次真的导入了订阅；已有订阅或用户取消时返回 false，
/// 调用方据此决定是否继续走普通启动流程。
Future<bool> ensureHerciniaProfile(ProviderContainer container) async {
  final profiles = container.read(profilesProvider);
  final hasHercinia = profiles.any(
    (profile) => profile.url == herciniaSubscriptionUrl,
  );
  if (hasHercinia) {
    return false;
  }
  if (profiles.isNotEmpty) {
    return false;
  }
  final context = globalState.navigatorKey.currentContext;
  if (context == null || !context.mounted) {
    return false;
  }
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _HerciniaWelcomeDialog(),
  );
  if (accepted != true) {
    return false;
  }
  await container
      .read(profilesActionProvider.notifier)
      .addProfileFromLink(
        herciniaSubscriptionUrl,
        label: 'Hercinia Network',
      );
  return true;
}

class _HerciniaWelcomeDialog extends StatelessWidget {
  const _HerciniaWelcomeDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('欢迎使用 Hercinia Network'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '将为你自动导入 Hercinia 专属节点池订阅，'
            '包含经真机测速筛选的高速节点。',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            herciniaSubscriptionUrl,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('稍后'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('立即导入'),
        ),
      ],
    );
  }
}
