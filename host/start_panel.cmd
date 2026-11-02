@echo off
setlocal
cd /d "%~dp0"
where python >nul 2>nul
if errorlevel 1 (
  echo Python is not available. Install Python 3 with Tcl/Tk and add it to PATH.
  pause
  exit /b 1
)
python mode_panel.py
if errorlevel 1 pause
