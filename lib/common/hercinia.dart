import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/hercinia_auth.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Hercinia Network 专属订阅地址。
const herciniaSubscriptionUrl = 'https://pool.hercinia.kdns.fr/clash.yaml';

/// 官网与社群入口。
const herciniaPortalUrl = 'https://pool.hercinia.kdns.fr/';
const herciniaTelegramUrl = 'https://t.me/HerciniaNetwork';

/// 站点 API 根路径。
const herciniaApiBase = 'https://pool.hercinia.kdns.fr/api';

/// 首次启动引导：校验授权后导入 Hercinia 专属订阅。
///
/// 已有订阅的用户直接放行，不再打扰；返回 true 表示本次导入了订阅。
Future<bool> ensureHerciniaProfile(ProviderContainer container) async {
  final profiles = container.read(profilesProvider);
  if (profiles.any((profile) => profile.url == herciniaSubscriptionUrl)) {
    return false;
  }
  if (profiles.isNotEmpty) {
    return false;
  }
  final activated = await requestHerciniaActivation();
  if (!activated) {
    return false;
  }
  return true;
}

/// 官网入口按钮，设置页与引导页共用。
class HerciniaPortalLinks extends StatelessWidget {
  const HerciniaPortalLinks({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: () => _open(context, herciniaPortalUrl),
          icon: const Icon(Icons.public, size: 18),
          label: Text(
            '访问官网',
            style: theme.textTheme.bodySmall,
          ),
        ),
        TextButton.icon(
          onPressed: () => _open(context, herciniaTelegramUrl),
          icon: const Icon(Icons.send, size: 18),
          label: Text(
            'Telegram 交流群',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  void _open(BuildContext context, String url) {
    dialogs.openUrl(url);
  }
}
