@echo off
chcp 65001 >nul
title EcoWiki Stopper
echo [INFO] Stopping EcoWiki services...

REM Kill by window title
taskkill /fi "WINDOWTITLE eq EcoWiki*" /f >nul 2>&1

REM Kill by port
for /f "tokens=5" %%a in ('netstat -aon 2^>nul ^| findstr /r " :8080 "') do taskkill /f /pid %%a >nul 2>&1
for /f "tokens=5" %%a in ('netstat -aon 2^>nul ^| findstr /r " :5173 "') do taskkill /f /pid %%a >nul 2>&1

REM Clean temp dir
rmdir /s /q "C:\ecowiki_tmp" >nul 2>&1

echo [OK] Done.
timeout /t 2 /nobreak >nul
