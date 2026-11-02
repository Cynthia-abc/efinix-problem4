@echo off
setlocal
cd /d "%~dp0"
python -m pip install --target vendor -r requirements.txt
if errorlevel 1 (
  echo Installation failed. Check your Python and network connection.
) else (
  echo Ready. Double-click start_panel.cmd.
)
pause
