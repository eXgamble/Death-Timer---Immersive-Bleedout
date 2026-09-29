@echo off
rem Configure + build Death Timer SKSE from a VS 2026 developer environment.
call "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\Common7\Tools\VsDevCmd.bat" -arch=amd64 -host_arch=amd64 >nul || exit /b 1
cd /d "%~dp0"
cmake --preset release || exit /b 2
cmake --build --preset release || exit /b 3
echo BUILD OK
