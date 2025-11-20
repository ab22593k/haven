$haven_version = ..\..\haven\bin\haven.exe version --plain
Write-Output "Version: $haven_version"
&"C:\Program Files (x86)\Inno Setup 6\iscc" "/dAppVersion=${haven_version}" install.iss
if(!$?) { Exit $LASTEXITCODE }
