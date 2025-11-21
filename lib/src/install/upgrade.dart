import '../provider.dart';

Future<int> upgradeHaven({
  required Scope scope,
  required String targetVersion,
  required bool? path,
}) async {
  // Removed download for pub-based installation
  throw UnsupportedError('Upgrade not supported for pub installation');
}
