@echo off
chcp 65001 >nul
echo [INFO] Clearing EcoWiki caches...

REM Vite build cache
if exist "%~dp0..\www\frontend\node_modules\.vite" (
    rmdir /s /q "%~dp0..\www\frontend\node_modules\.vite"
    echo [OK] Vite cache cleared
)

REM Python __pycache__
dir /s /b "%~dp0..\www\backend\__pycache__" 2>nul >nul && (
    for /d /r "%~dp0..\www\backend" %%d in (__pycache__) do @if exist "%%d" rmdir /s /q "%%d" 2>nul
    echo [OK] Python cache cleared
)

REM Browser hint
echo.
echo ============================================
echo  Browser cache: Ctrl+Shift+R (hard refresh)
echo  then restart backend + frontend dev server
echo ============================================
echo.
echo [OK] Done.
pause
