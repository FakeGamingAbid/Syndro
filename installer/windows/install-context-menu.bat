@echo off
:: =====================================================
:: Syndro - Windows Context Menu Installer
:: Installs "Send with Syndro" to Windows Explorer
:: =====================================================

setlocal enabledelayedexpansion

echo.
echo ========================================
echo   Syndro Context Menu Installer
echo ========================================
echo.

:: Check for admin rights (needed for system-wide install)
net session >nul 2>&1
if %errorLevel% == 0 (
    set "ADMIN=true"
    echo [INFO] Running with administrator privileges
) else (
    set "ADMIN=false"
    echo [INFO] Running without administrator privileges
    echo [INFO] Will install for current user only
)

:: Detect Syndro installation
set "SYNDRO_PATH="

:: Check common installation locations
if exist "%LOCALAPPDATA%\Syndro\syndro.exe" (
    set "SYNDRO_PATH=%LOCALAPPDATA%\Syndro\syndro.exe"
) else if exist "%PROGRAMFILES%\Syndro\syndro.exe" (
    set "SYNDRO_PATH=%PROGRAMFILES%\Syndro\syndro.exe"
) else if exist "%PROGRAMFILES(X86)%\Syndro\syndro.exe" (
    set "SYNDRO_PATH=%PROGRAMFILES(X86)%\Syndro\syndro.exe"
) else (
    :: Check PATH
    where syndro.exe >nul 2>&1
    if !errorLevel! == 0 (
        for /f "tokens=*" %%i in ('where syndro.exe') do set "SYNDRO_PATH=%%i"
    )
)

if defined SYNDRO_PATH (
    echo [OK] Found Syndro at: !SYNDRO_PATH!
) else (
    echo [WARNING] Syndro not found in common locations
    echo [INFO] Please specify the path to syndro.exe
    set /p "SYNDRO_PATH=Enter path to syndro.exe: "
)

:: Validate path
if not exist "!SYNDRO_PATH!" (
    echo [ERROR] Invalid path: !SYNDRO_PATH!
    echo Please install Syndro first or provide correct path.
    pause
    exit /b 1
)

:: Get directory for icon
for %%A in ("!SYNDRO_PATH!") do set "SYNDRO_DIR=%%~dpA"
set "SYNDRO_DIR=%SYNDRO_DIR:~0,-1%"

echo.
echo [INFO] Installing context menu...
echo        Path: !SYNDRO_PATH!
echo        Icon: !SYNDRO_DIR!

:: Create registry entries using PowerShell for proper path escaping
:: This handles special characters in paths that batch variable substitution may fail with
set "REG_FILE=%TEMP%\syndro_context_menu.reg"

powershell -Command "$path = '%SYNDRO_PATH%'; $escaped = $path -replace '\\', '\\\\'; @\"
Windows Registry Editor Version 5.00

; Syndro - Right-Click Send with Syndro Context Menu

; Add Send with Syndro to file context menu
[HKEY_CURRENT_USER\Software\Classes\*\shell\SyndroSend]
@=\"Send with Syndro\"
\"Icon\"=\"`\"$escaped`\",0\"

[HKEY_CURRENT_USER\Software\Classes\*\shell\SyndroSend\command]
@=\"`\"$escaped`\" `\"%%1`\"

; Add Send with Syndro to folder context menu
[HKEY_CURRENT_USER\Software\Classes\Directory\shell\SyndroSend]
@=\"Send with Syndro\"
\"Icon\"=\"`\"$escaped`\",0\"

[HKEY_CURRENT_USER\Software\Classes\Directory\shell\SyndroSend\command]
@=\"`\"$escaped`\" `\"%%1`\"

; Add Send with Syndro to directory background (right-click in folder)
[HKEY_CURRENT_USER\Software\Classes\Directory\Background\shell\SyndroSend]
@=\"Send with Syndro\"
\"Icon\"=\"`\"$escaped`\",0\"

[HKEY_CURRENT_USER\Software\Classes\Directory\Background\shell\SyndroSend\command]
@=\"`\"$escaped`\" `\"%%V`\"
\"@ | Set-Content -Path '%REG_FILE%'"

:: Import registry file
reg import "%REG_FILE%" >nul 2>&1
if %errorLevel% == 0 (
    echo [OK] Context menu installed successfully!
) else (
    echo [ERROR] Failed to install context menu
    del "%REG_FILE%"
    pause
    exit /b 1
)

del "%REG_FILE%"

echo.
echo ========================================
echo   Installation Complete!
echo ========================================
echo.
echo You can now right-click on any file or folder
echo and select "Send with Syndro" to share it.
echo.
echo To uninstall, run: uninstall-context-menu.bat
echo.

pause
