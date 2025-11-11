import '../ast/binary.dart';
import '../config/config.dart';
import '../env/dart.dart';
import '../provider.dart';

class SnapshotReader {
  SnapshotReader({
    required this.scope,
  });

  final Scope scope;
  late final config = PuroConfig.of(scope);

  Future<void> readSnapshots(Map<int, BinFormat> formats) async {
    final releases = await getDartReleases(scope: scope);

    final allReleases = releases.releases.entries
        .expand((r) => r.value.map((v) => DartRelease(
              DartOS.current,
              DartArch.current,
              r.key,
              v,
            )))
        .toList();

    for (final release in allReleases) {
      if (release.version.major < 2) continue;
      final snapshotFile = config
          .getDartRelease(release)
          .binDir
          .childDirectory('snapshots')
          .childFile('kernel-service.dart.snapshot');
      if (!snapshotFile.existsSync()) {
        continue;
      }
      final bytes = snapshotFile.readAsBytesSync();
      if (bytes.buffer.asByteData().getUint32(0) != 0x90ABCDEF) {
        continue;
      }
      final reader = BinReader(formats, bytes);
      reader.read();
    }
  }
}