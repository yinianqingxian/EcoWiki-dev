@echo off
chcp 65001 >nul
echo [INFO] Stopping EcoWiki services...

REM Kill by port (safe: only targets processes using specific ports)
for /f "tokens=5" %%a in ('netstat -aon 2^>nul ^| findstr /r " :8080 "') do taskkill /f /pid %%a >nul 2>&1
for /f "tokens=5" %%a in ('netstat -aon 2^>nul ^| findstr /r " :5173 "') do taskkill /f /pid %%a >nul 2>&1

REM Clean temp dir
rmdir /s /q "C:\ecowiki_tmp" >nul 2>&1

echo [OK] Done.
timeout /t 2 /nobreak >nul
