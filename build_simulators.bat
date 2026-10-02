@echo off
setlocal EnableExtensions

rem ============================================================
rem  Build the two simulators as standalone Windows folders.
rem  Put this file in the project root (next to pubspec.yaml).
rem  Output: build\simulators\board_sim  and  build\simulators\pos_sim
rem          (+ a .zip of each one, ready to copy to another PC)
rem ============================================================

set "ROOT=%~dp0"
set "OUT=%ROOT%build\simulators"
set "APP_EXE=vending_724_panel.exe"

cd /d "%ROOT%"

where flutter >nul 2>nul
if errorlevel 1 (
  echo [ERROR] flutter was not found in PATH. Run this from a terminal where flutter --version works.
  pause
  exit /b 1
)

if not exist "%OUT%" mkdir "%OUT%"

call :build_one board_sim lib/simulators/board_simulator.dart
if errorlevel 1 goto :failed

call :build_one pos_sim lib/simulators/pos_simulator.dart
if errorlevel 1 goto :failed

echo.
echo ============================================================
echo  DONE. Output folder:
echo  %OUT%
echo.
echo    board_sim.zip : copy to the BOARD machine
echo    pos_sim.zip   : copy to the POS machine
echo ============================================================
pause
exit /b 0

:failed
echo.
echo [ERROR] Build failed. See the messages above.
pause
exit /b 1


:build_one
set "NAME=%~1"
set "ENTRY=%~2"
set "REL="
set "DEST=%OUT%\%NAME%"

echo.
echo ============================================================
echo  Building %NAME% from %ENTRY%
echo ============================================================
call flutter build windows --release -t %ENTRY%
if errorlevel 1 exit /b 1

rem Newer Flutter puts the output under x64, older versions do not
if exist "%ROOT%build\windows\x64\runner\Release\%APP_EXE%" set "REL=%ROOT%build\windows\x64\runner\Release"
if not defined REL if exist "%ROOT%build\windows\runner\Release\%APP_EXE%" set "REL=%ROOT%build\windows\runner\Release"
if not defined REL (
  echo [ERROR] Release folder not found after build.
  exit /b 1
)

if exist "%DEST%" rmdir /s /q "%DEST%"
mkdir "%DEST%"
xcopy "%REL%\*" "%DEST%\" /E /I /Y /Q >nul
if errorlevel 1 (
  echo [ERROR] Copy failed.
  exit /b 1
)
ren "%DEST%\%APP_EXE%" "%NAME%.exe"

rem App-local Visual C++ runtime, so a clean Windows does not need an installer
for %%D in (msvcp140.dll msvcp140_1.dll vcruntime140.dll vcruntime140_1.dll) do (
  if exist "%SystemRoot%\System32\%%D" copy /Y "%SystemRoot%\System32\%%D" "%DEST%\" >nul
)

rem Helper to open the firewall for this exe (run as Administrator on the target PC)
>"%DEST%\allow_firewall.bat" echo @echo off
>>"%DEST%\allow_firewall.bat" echo echo Allowing %NAME%.exe through Windows Firewall - run this file as Administrator
>>"%DEST%\allow_firewall.bat" echo netsh advfirewall firewall delete rule name="Vending %NAME%"
>>"%DEST%\allow_firewall.bat" echo netsh advfirewall firewall add rule name="Vending %NAME%" dir=in action=allow program="%%~dp0%NAME%.exe" enable=yes profile=any
>>"%DEST%\allow_firewall.bat" echo pause

if exist "%OUT%\%NAME%.zip" del /q "%OUT%\%NAME%.zip"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Compress-Archive -Path '%DEST%\*' -DestinationPath '%OUT%\%NAME%.zip' -Force"
if errorlevel 1 (
  echo [WARN] Zip failed - copy the folder instead.
)

echo [OK] %NAME% is ready in %DEST%
exit /b 0