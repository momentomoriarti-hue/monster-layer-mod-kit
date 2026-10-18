@echo off
rem Shared paths for the other scripts. Called via: call "%~dp0_common.bat"

for %%I in ("%~dp0..") do set "ROOT=%%~fI"

set "ORIGINAL_PACKED=%ROOT%\Original Packed"
set "ORIGINAL_UNPACKED=%ROOT%\Original Unpacked"
set "MODED_UNPACKED=%ROOT%\Moded Unpacked"
set "MODED_PACKED=%ROOT%\Moded Packed"
set "MODED_SOURCE=%ROOT%\Moded Source"
rem Every mod is a folder in Mods: mod.cfg, mod_settings.cfg, Custom Lays\, Custom Bosses\.
set "MODS=%ROOT%\Mods"

set "GDRE=%ROOT%\Tools\GDRE_tools\gdre_tools.exe"
set "GODOT=%ROOT%\Tools\Godot\Godot_v4.3-stable_win64_console.exe"
rem Original game files: first .pck / .exe found in Original Packed.
set "ORIGINAL_PCK="
set "ORIGINAL_EXE="
for %%F in ("%ORIGINAL_PACKED%\*.pck") do if not defined ORIGINAL_PCK set "ORIGINAL_PCK=%%~fF"
for %%F in ("%ORIGINAL_PACKED%\*.exe") do if not defined ORIGINAL_EXE set "ORIGINAL_EXE=%%~fF"
exit /b 0
