@echo off
title Pertin - Web Test Server
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "start_web_test.ps1"
pause
