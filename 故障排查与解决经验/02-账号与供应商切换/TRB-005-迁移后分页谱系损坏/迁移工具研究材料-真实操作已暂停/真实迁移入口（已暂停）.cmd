@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"

where node >nul 2>nul
if errorlevel 1 goto no_node

echo Real-session migration is currently suspended because paginated lineage is not fully verified.
echo The installer will stop before scanning, backing up, or modifying any session file.
node "%~dp0install_bulk_codex_migration.mjs" --apply
set "RESULT=%ERRORLEVEL%"
if "%RESULT%"=="0" set "RESULT=1"
goto failed

:no_node
echo Node.js was not found. No file was changed.
pause
exit /b 1

:failed
echo.
echo Migration was blocked by the safety gate.
echo Keep the complete error text shown in this window.
pause
exit /b %RESULT%
