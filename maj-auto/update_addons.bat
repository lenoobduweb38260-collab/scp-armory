@echo off
rem SCP Armory — mise à jour automatique des addons (Windows)
rem Usage : update_addons.bat [C:\chemin\vers\garrysmod]
rem À appeler dans votre start.bat AVANT le lancement de srcds.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update_addons.ps1" %1
rem Lancé par double-clic : on laisse la fenêtre ouverte pour lire le résultat
echo %cmdcmdline% | find /i "%~f0" >nul && pause
