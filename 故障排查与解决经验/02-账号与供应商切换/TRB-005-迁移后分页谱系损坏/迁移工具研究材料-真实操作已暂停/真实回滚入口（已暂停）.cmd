@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"

where node >nul 2>nul
if errorlevel 1 goto no_node

echo Real rollback is currently suspended because old manifest path boundaries are not fully verified.
echo The tool will stop before reading a manifest, backup, or session file.
node "%~dp0install_bulk_codex_migration.mjs" --rollback-latest
set "RESULT=%ERRORLEVEL%"
if not "%RESULT%"=="0" goto failed
echo.
echo Unexpected success: the safety gate did not block rollback.
pause
exit /b 2

:no_node
echo Node.js was not found. No file was changed.
pause
exit /b 1

:failed
echo.
echo Rollback was blocked by the safety gate.
echo Keep the complete error text shown in this window.
pause
exit /b %RESULT%
