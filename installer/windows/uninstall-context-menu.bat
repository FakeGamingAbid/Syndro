@echo off
:: =====================================================
:: Syndro - Windows Context Menu Uninstaller
:: Removes "Send with Syndro" from Windows Explorer
:: =====================================================

echo.
echo ========================================
echo   Syndro Context Menu Uninstaller
echo ========================================
echo.

echo [INFO] Removing context menu entries...

:: Remove registry entries
reg delete "HKCU\Software\Classes\*\shell\SyndroSend" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\shell\SyndroSend" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\Background\shell\SyndroSend" /f >nul 2>&1

echo [OK] Context menu removed successfully!
echo.
echo ========================================
echo   Uninstallation Complete!
echo ========================================
echo.

pause
