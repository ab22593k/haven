$haven_version = dart bin/haven.dart version --no-update-check --plain @args
Write-Output "Version: $haven_version"
dart compile exe bin/haven.dart -o bin/haven.exe --define=haven_version=$haven_version
