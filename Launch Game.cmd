@echo off
setlocal
set "godotExecutable=%LOCALAPPDATA%\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64.exe"
if not exist "%godotExecutable%" (
    echo Godot 4.7.2 was not found at "%godotExecutable%".
    echo Open project.godot with your installed Godot editor and press F5.
    pause
    exit /b 1
)
start "" "%godotExecutable%" --path "%~dp0."
