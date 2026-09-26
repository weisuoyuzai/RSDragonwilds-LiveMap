@echo off
rem Regenerate LiveMap full-map data (Scripts\world_L_World.lua) and official names (Scripts\names.lua) from the game files.
rem Run this after a game update. It needs a mappings file: in game press Ctrl+Numpad6 once (UE4SS writes *.usmap).
setlocal
set "TOOLS=%~dp0"
set "MOD=%TOOLS%.."
set "UE4SS=%TOOLS%..\..\.."
set "PAKS=%TOOLS%..\..\..\..\..\..\Content\Paks"

set "USMAP="
for /f "delims=" %%F in ('dir /b /o-d "%UE4SS%\*.usmap" 2^>nul') do if not defined USMAP set "USMAP=%UE4SS%\%%F"
if not defined USMAP (
    echo No .usmap found in %UE4SS%
    echo Start the game and press Ctrl+Numpad6 once, then run this again.
    pause
    exit /b 1
)
echo Mappings: %USMAP%

"%TOOLS%WorldExtract.exe" "%PAKS%" "%USMAP%" "%TOOLS%out" "%MOD%\Scripts\config.lua"
if errorlevel 1 (
    echo Extraction failed.
    pause
    exit /b 1
)
copy /y "%TOOLS%out\world_L_World.lua" "%MOD%\Scripts\world_L_World.lua" >nul
"%TOOLS%WorldExtract.exe" loc "%PAKS%" "%USMAP%" "%MOD%\Scripts\names.lua" "%TOOLS%loc_terms.txt"
if errorlevel 1 (
    echo Name extraction failed.
    pause
    exit /b 1
)
echo Done. Restart the game to load the new data.
pause
