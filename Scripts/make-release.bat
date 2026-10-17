@echo off
setlocal
chcp 65001 >nul
call "%~dp0_common.bat"

rem Makes Moded Packed\Release with only what players need: the modded .pck,
rem SHA256.txt with its hash and HOW_TO_INSTALL.txt. The .exe is never copied:
rem it is the unchanged original game exe, players already have it, and a mod
rem must not teach them to run an .exe from a mod.
rem pack-moded.bat calls it as "make-release.bat nopause"; it can also be run alone.
rem WARNING: everything currently in Moded Packed\Release is deleted first.

set "RELEASE=%MODED_PACKED%\Release"
set "TEMPLATE_TXT=%~dp0templates\HOW_TO_INSTALL.txt"

set "MOD_PCK="
for %%F in ("%MODED_PACKED%\*.pck") do if not defined MOD_PCK set "MOD_PCK=%%~fF"
if not defined MOD_PCK (
    echo [ERROR] No .pck file found in "%MODED_PACKED%". Run pack-moded.bat first.
    goto :fail
)
if not exist "%TEMPLATE_TXT%" (
    echo [ERROR] "%TEMPLATE_TXT%" not found.
    goto :fail
)
for %%F in ("%MOD_PCK%") do set "PCK_NAME=%%~nxF"

if exist "%RELEASE%" (
    rd /s /q "%RELEASE%"
    if exist "%RELEASE%" (
        echo [ERROR] Could not clear "%RELEASE%".
        goto :fail
    )
)
mkdir "%RELEASE%"

echo Making release in "%RELEASE%"...
copy /y "%MOD_PCK%" "%RELEASE%\%PCK_NAME%" >nul
if errorlevel 1 (
    echo [ERROR] Could not copy "%MOD_PCK%".
    goto :fail
)
copy /y "%TEMPLATE_TXT%" "%RELEASE%\HOW_TO_INSTALL.txt" >nul
if errorlevel 1 (
    echo [ERROR] Could not copy "%TEMPLATE_TXT%".
    goto :fail
)

rem Same format as sha256sum: "<hash>  <file name>".
set "REL_PCK=%RELEASE%\%PCK_NAME%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p = $env:REL_PCK; $h = (Get-FileHash -Algorithm SHA256 -LiteralPath $p).Hash.ToLower(); [IO.File]::WriteAllText((Join-Path $env:RELEASE 'SHA256.txt'), $h + '  ' + (Split-Path -Leaf $p) + [char]10); Write-Host ('SHA256: ' + $h)"
if errorlevel 1 (
    echo [ERROR] Could not compute the SHA256 hash.
    goto :fail
)

echo Release ready: "%RELEASE%" ^(%PCK_NAME%, SHA256.txt, HOW_TO_INSTALL.txt^).
if /i not "%~1"=="nopause" pause
exit /b 0

:fail
if /i not "%~1"=="nopause" pause
exit /b 1
