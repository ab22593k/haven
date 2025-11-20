haven_version="$(dart bin/haven.dart version --no-update-check --plain "$@")"
echo "version: $haven_version"
dart compile exe bin/haven.dart -o bin/haven "--define=haven_version=$haven_version"
