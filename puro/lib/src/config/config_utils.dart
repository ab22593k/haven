import 'package:file/file.dart';

/// Finds the closest parent directory containing a file with the given name.
Directory? findProjectDir(Directory directory, String fileName) {
  while (directory.existsSync()) {
    if (directory.fileSystem.statSync(directory.childFile(fileName).path).type !=
        FileSystemEntityType.notFound) {
      return directory;
    }
    final parent = directory.parent;
    if (directory.path == parent.path) break;
    directory = parent;
  }
  return null;
}
