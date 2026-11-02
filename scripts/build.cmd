@echo off
setlocal
cd /d "%~dp0.."
if not defined EFINITY_HOME set "EFINITY_HOME=D:\Efinity\2026.1"
if not exist "%EFINITY_HOME%\bin\efx_run.bat" (
  echo Set EFINITY_HOME to the Efinity 2026.1 installation directory.
  exit /b 1
)
call "%EFINITY_HOME%\bin\setup.bat"
call "%EFINITY_HOME%\bin\efx_run.bat" Ti60_Demo --prj -f compile --family Titanium -d Ti60F225 --output_dir outflow_release --work_dir work_pnr_release --timeout 3600
exit /b %ERRORLEVEL%
