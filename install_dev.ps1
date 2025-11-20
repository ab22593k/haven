# Builds and installs haven from source, for development purposes.

& "$PSScriptRoot/build.ps1"
bin/haven.exe install-haven --log-level=4 --promote
