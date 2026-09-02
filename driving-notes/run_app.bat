@echo off
setlocal

echo ============================================
echo   Driving Notes - build and run on tablet
echo ============================================
echo.

REM Go to the folder this .bat file is sitting in (should be driving_notes)
cd /d "%~dp0"

set FLUTTER=C:\src\flutter\bin\flutter.bat

if not exist "%FLUTTER%" (
    echo Could not find Flutter at %FLUTTER%
    echo If you moved the flutter folder, edit this file and fix the FLUTTER line near the top.
    goto :end
)

echo Make sure your Galaxy Tab S10 is:
echo   - Plugged in with a USB cable
echo   - Set to "File transfer / MTP" (not just "Charging")
echo   - Unlocked, with USB debugging allowed if it asks
echo.
pause

echo.
echo [1/3] Cleaning old build files...
call "%FLUTTER%" clean
if errorlevel 1 goto :error

echo.
echo [2/3] Downloading/updating packages (this can take a minute)...
call "%FLUTTER%" pub get
if errorlevel 1 goto :error

echo.
echo [3/3] Building and installing on the tablet...
echo (First time may take several minutes - please be patient)
call "%FLUTTER%" run -d R52YA02836J
if errorlevel 1 goto :error

echo.
echo Done. If the app opened on the tablet, everything worked.
goto :end

:error
echo.
echo ============================================
echo   Something went wrong (see the red text above).
echo   Copy the FULL error message and send it back
echo   in the chat - do not worry about understanding it.
echo ============================================

:end
echo.
pause
