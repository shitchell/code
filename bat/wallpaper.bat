@echo off

:: check if an image path was specified.
if not [%1]==[] goto main
:: --------------------------
echo usage: %0 %%image_path

:: --------------------------
exit /B 1

:main
:: --------------------------
reg add "HKEY_CURRENT_USER\control panel\desktop" /v wallpaper /t REG_SZ /d "" /f
reg add "HKEY_CURRENT_USER\control panel\desktop" /v wallpaper /t REG_SZ /d %1 /f
reg add "HKEY_CURRENT_USER\control panel\desktop" /v WallpaperStyle /t REG_SZ /d 2 /f
RUNDLL32.EXE user32.dll,UpdatePerUserSystemParameters
pause
exit
