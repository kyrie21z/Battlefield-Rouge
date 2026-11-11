@echo off
setlocal EnableExtensions DisableDelayedExpansion
for %%I in ("%~dp0..") do set "PROJECT_DIR=%%~fI"
if not defined GODOT_EXE set "GODOT_EXE=%~d0\godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT_EXE%" (
  echo Godot 4.7.2 was not found: "%GODOT_EXE%"
  echo Set GODOT_EXE to your Godot 4.7.2 executable and try again.
  goto :failed
)
if not exist "%PROJECT_DIR%\project.godot" (
  echo project.godot was not found in "%PROJECT_DIR%".
  goto :failed
)
set "GODOT_IMPORT_EXE=%GODOT_EXE%"
if exist "%GODOT_EXE:~0,-4%_console.exe" set "GODOT_IMPORT_EXE=%GODOT_EXE:~0,-4%_console.exe"
set "RUNTIME_DIR=%PROJECT_DIR%\.runtime"
if not exist "%RUNTIME_DIR%" mkdir "%RUNTIME_DIR%"
if not exist "%RUNTIME_DIR%" goto :failed

echo [1/2] Preparing game resources. The first launch after an update may take a moment...
"%GODOT_IMPORT_EXE%" --headless --editor --path "%PROJECT_DIR%" --import --log-file "%RUNTIME_DIR%\startup-import.log" >"%RUNTIME_DIR%\startup-prepare.log" 2>&1
if errorlevel 1 goto :import_failed
rem Godot can return zero even after a script or resource import error.
findstr /C:"SCRIPT ERROR:" /C:"Failed loading resource:" /C:"Failed to load script" /C:"Error importing" /C:"Failed to instantiate an autoload" "%RUNTIME_DIR%\startup-prepare.log" >nul
if not errorlevel 1 goto :import_failed
if not exist "%PROJECT_DIR%\.godot\global_script_class_cache.cfg" goto :import_failed

echo [2/2] Opening Mind Freak...
rem FINDSTR returns one for a clean log; START does not clear that value.
cmd /d /c exit 0
start "" /D "%PROJECT_DIR%" "%GODOT_EXE%" --path "%PROJECT_DIR%" --log-file "%RUNTIME_DIR%\game.log" %*
if errorlevel 1 goto :failed
exit /b 0

:import_failed
echo Resource preparation failed. The game was not started.
echo Details: "%RUNTIME_DIR%\startup-prepare.log"
:failed
pause
exit /b 1
