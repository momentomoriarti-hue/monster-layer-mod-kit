@echo off
setlocal
chcp 65001 >nul
call "%~dp0_common.bat"

rem Copies the unpacked original project into a new folder
rem Moded Unpacked\build_<yyyy-MM-dd_HH-mm-ss-fff>, where mods are made.
rem Existing builds are never touched.

if not exist "%ORIGINAL_UNPACKED%\project.godot" (
    echo [ERROR] "%ORIGINAL_UNPACKED%" is missing or empty. Run unpack-original.bat first.
    goto :fail
)

if not exist "%MODED_UNPACKED%" mkdir "%MODED_UNPACKED%"

rem Locale-independent timestamp; this format also sorts by name in time order.
for /f "delims=" %%T in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss-fff"') do set "STAMP=%%T"
set "BUILD=%MODED_UNPACKED%\build_%STAMP%"

if exist "%BUILD%" (
    echo [ERROR] "%BUILD%" already exists. Try again.
    goto :fail
)
mkdir "%BUILD%"

echo Copying "%ORIGINAL_UNPACKED%" to "%BUILD%"...
robocopy "%ORIGINAL_UNPACKED%" "%BUILD%" /E /NFL /NDL /NJH /NP
rem robocopy exit codes 0-7 mean success, 8+ mean errors.
if %errorlevel% geq 8 (
    echo [ERROR] Copying failed.
    goto :fail
)

echo.
echo Done. Make your changes in "%BUILD%".
if not defined MLMK_NOPAUSE pause
exit /b 0

:fail
if not defined MLMK_NOPAUSE pause
exit /b 1
