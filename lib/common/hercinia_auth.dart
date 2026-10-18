import 'dart:convert';

import 'package:fl_clash/common/hercinia.dart';
import 'package:fl_clash/common/request.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 激活结果，成功时带上到期时间用于展示。
class HerciniaActivation {
  final bool success;
  final String message;
  final String? expireAt;

  const HerciniaActivation({
    required this.success,
    required this.message,
    this.expireAt,
  });
}

/// 与站点 `/api/sync` 通讯，校验授权码并返回账号状态。
///
/// 只读取云端数据，绝不回写：站点接口没有鉴权，写入等于把后台交给每个用户。
class HerciniaAuthClient {
  const HerciniaAuthClient();

  Future<Map<String, dynamic>> _fetchSync() async {
    final uri = Uri.parse('$herciniaApiBase/sync').replace(
      queryParameters: {'_t': '${DateTime.now().millisecondsSinceEpoch}'},
    );
    final response = await request.getTextResponseForUrl(uri.toString());
    final body = jsonDecode(response.data ?? '{}');
    if (body is! Map<String, dynamic> || body['success'] != true) {
      throw Exception('接口返回异常');
    }
    return (body['data'] as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// 用邮箱 + 授权码激活。已在有效期内的账号，凭邮箱即可放行。
  Future<HerciniaActivation> activate({
    required String email,
    String code = '',
  }) async {
    final trimmedEmail = email.trim();
    final trimmedCode = code.trim();
    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      return const HerciniaActivation(success: false, message: '请输入有效邮箱');
    }
    final Map<String, dynamic> data;
    try {
      data = await _fetchSync();
    } catch (e) {
      return const HerciniaActivation(
        success: false,
        message: '无法连接授权服务器，请检查网络后重试',
      );
    }
    final users = (data['users'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    final codes = (data['codes'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();

    final account = users.firstWhere(
      (u) => (u['account'] as String? ?? '').toLowerCase() ==
          trimmedEmail.toLowerCase(),
      orElse: () => const {},
    );

    if (trimmedCode.isEmpty) {
      if (account.isEmpty) {
        return const HerciniaActivation(
          success: false,
          message: '该邮箱未激活，请输入授权码',
        );
      }
      final expireAt = account['auth_expire_time'] as String?;
      if (_isExpired(expireAt)) {
        return HerciniaActivation(
          success: false,
          message: '账号已于 $expireAt 到期，请输入新的授权码',
        );
      }
      return HerciniaActivation(
        success: true,
        message: '授权有效',
        expireAt: expireAt,
      );
    }

    final codeObj = codes.firstWhere(
      (c) => (c['code'] as String? ?? '').trim().toLowerCase() ==
          trimmedCode.toLowerCase(),
      orElse: () => const {},
    );
    if (codeObj.isEmpty) {
      return const HerciniaActivation(success: false, message: '授权码无效，请核对');
    }
    final status = codeObj['status'];
    if (status == 1) {
      return const HerciniaActivation(success: false, message: '授权码已被使用');
    }
    if (status == 2) {
      return const HerciniaActivation(success: false, message: '授权码已失效');
    }
    if (status == 3 || _isExpired(codeObj['code_expire_time'] as String?)) {
      return const HerciniaActivation(success: false, message: '授权码已失效');
    }
    final days = (codeObj['package_days'] as num?)?.toInt() ?? 0;
    if (days <= 0) {
      return const HerciniaActivation(success: false, message: '授权码套餐异常');
    }
    // 激活动作发生在网页端；App 端只放行，避免无鉴权接口被改写。
    final base = DateTime.now();
    final expire = base.add(Duration(days: days));
    return HerciniaActivation(
      success: true,
      message: '授权通过',
      expireAt: _formatDate(expire),
    );
  }

  static bool _isExpired(String? value) {
    if (value == null || value.isEmpty) return false;
    if (value.startsWith('2099')) return false;
    final parsed = DateTime.tryParse(value.replaceAll('/', '-'));
    if (parsed == null) return false;
    return DateTime.now().isAfter(parsed);
  }

  static String _formatDate(DateTime time) =>
      '${time.year}-${_two(time.month)}-${_two(time.day)} '
      '${_two(time.hour)}:${_two(time.minute)}:${_two(time.second)}';

  static String _two(int value) => value.toString().padLeft(2, '0');
}

/// 授权码输入页；通过后导入订阅并关闭。
class HerciniaActivationPage extends ConsumerStatefulWidget {
  const HerciniaActivationPage({super.key});

  @override
  ConsumerState<HerciniaActivationPage> createState() =>
      _HerciniaActivationPageState();
}

class _HerciniaActivationPageState
    extends ConsumerState<HerciniaActivationPage> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _expireAt;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await const HerciniaAuthClient().activate(
      email: _emailController.text,
      code: _codeController.text,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _expireAt = result.success ? result.expireAt : null;
      _error = result.success ? null : result.message;
    });
    if (!result.success) return;
    await ref
        .read(profilesActionProvider.notifier)
        .addProfileFromLink(
          herciniaSubscriptionUrl,
          label: 'Hercinia Network',
        );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Hercinia 授权激活'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '输入账号与授权码',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '授权码可在官网或 Telegram 群获取',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: '邮箱账号',
                    prefixIcon: Icon(Icons.alternate_email),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: '授权码（已激活账号可留空）',
                    prefixIcon: Icon(Icons.vpn_key_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (_expireAt != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    '有效期至 $_expireAt',
                    style: TextStyle(color: theme.colorScheme.primary),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('激活并导入订阅'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 弹出授权页；返回 true 表示已激活并写入订阅。
Future<bool> requestHerciniaActivation() async {
  final context = globalState.navigatorKey.currentContext;
  if (context == null || !context.mounted) return false;
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const HerciniaActivationPage(),
    ),
  );
  return result == true;
}
