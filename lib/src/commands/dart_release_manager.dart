import '../env/dart.dart';
import '../provider.dart';

class DartReleaseManager {
  DartReleaseManager({required this.scope});

  final Scope scope;

  Future<void> downloadReleases() async {
    final releases = await getDartReleases(scope: scope);

    final allReleases = releases.releases.entries
        .expand(
          (r) => r.value.map(
            (v) => DartRelease(DartOS.current, DartArch.current, r.key, v),
          ),
        )
        .toList();

    // allReleases.removeWhere((e) => e.version.major < 2);

    // This release has no artifacts for some reason
    allReleases.removeWhere(
      (e) => '${e.version}' == '1.24.0' && e.channel == DartChannel.dev,
    );

    for (final release in allReleases) {
      await downloadSharedDartRelease(scope: scope, release: release, check: false);
    }
  }
}
