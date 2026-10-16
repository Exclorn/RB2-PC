@echo off
rem Double-click this file to set up Raging Blast 2 on Windows. See WINDOWS.md.
title Raging Blast 2 - Windows setup
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\desktop\easy_setup.ps1"
echo.
pause
