@echo off
:: Check if running as Administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit
)

powershell -ExecutionPolicy Bypass -File "%~dp0ssl/install.ps1"
pause
