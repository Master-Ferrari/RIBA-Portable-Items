@echo off
rem Сборка мода в папку LocalMods игры. Можно просто дважды кликнуть.
rem Все аргументы прокидываются в build.ps1, например:  build.cmd -Clean -Launch
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1" %*
set ERR=%ERRORLEVEL%
if not "%1"=="-NoPause" if %ERR% NEQ 0 pause
exit /b %ERR%
