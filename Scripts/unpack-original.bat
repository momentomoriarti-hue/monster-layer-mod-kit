@echo off
setlocal
chcp 65001 >nul
call "%~dp0_common.bat"

rem Unpacks the original game (Original Packed\*.pck) into an editable Godot project
rem in Original Unpacked, using GDRE Tools.

if not exist "%GDRE%" (
    echo [ERROR] GDRE Tools not found. Run setup-tools.bat first.
    goto :fail
)
if not defined ORIGINAL_PCK (
    echo [ERROR] No .pck file found in "%ORIGINAL_PACKED%".
    goto :fail
)

if exist "%ORIGINAL_UNPACKED%" (
    echo Clearing "%ORIGINAL_UNPACKED%"...
    rd /s /q "%ORIGINAL_UNPACKED%"
    if exist "%ORIGINAL_UNPACKED%" (
        echo [ERROR] Could not clear the folder. Close any programs using it and try again.
        goto :fail
    )
)
mkdir "%ORIGINAL_UNPACKED%"

echo Unpacking "%ORIGINAL_PCK%"...
"%GDRE%" --headless "--recover=%ORIGINAL_PCK%" "--output=%ORIGINAL_UNPACKED%"

if not exist "%ORIGINAL_UNPACKED%\project.godot" (
    echo [ERROR] Unpacking failed. See "%ORIGINAL_UNPACKED%\gdre_export.log" if it exists.
    goto :fail
)

echo.
echo Done. The original project is in "%ORIGINAL_UNPACKED%".
pause
exit /b 0

:fail
pause
exit /b 1
