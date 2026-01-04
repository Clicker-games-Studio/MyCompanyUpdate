@echo off
echo Boot to Update Install
echo.
echo =-=-=-=-=-=-=-=-=-=-=-=-=
echo Waiting for elevation...
echo =-=-=-=-=-=-=-=-=-=-=-=-=

:init
setlocal DisableDelayedExpansion
set "batchPath=%~0"
for %%k in (%0) do set batchName=%%~nk
set "vbsGetPrivileges=%temp%\OEgetPriv_%batchName%.vbs"
setlocal EnableDelayedExpansion

:checkPrivileges
NET FILE 1>NUL 2>NUL
if '%errorlevel%' == '0' ( goto gotPrivileges ) else ( goto getPrivileges )

:getPrivileges
if '%1'=='ELEV' (echo ELEV & shift /1 & goto gotPrivileges)
echo Set UAC = CreateObject^("Shell.Application"^) > "%vbsGetPrivileges%"
echo args = "ELEV " >> "%vbsGetPrivileges%"
echo For Each strArg in WScript.Arguments >> "%vbsGetPrivileges%"
echo args = args ^& strArg ^& " "  >> "%vbsGetPrivileges%"
echo Next >> "%vbsGetPrivileges%"
echo UAC.ShellExecute "!batchPath!", args, "", "runas", 1 >> "%vbsGetPrivileges%"
"%SystemRoot%\System32\WScript.exe" "%vbsGetPrivileges%" %*
exit /B

:gotPrivileges
setlocal & pushd .
cd /d %~dp0
if '%1'=='ELEV' (del "%vbsGetPrivileges%" 1>nul 2>nul  &  shift /1)

REM ~-~-~-~-~-~-~-~ Batch file starts here
echo.
echo Starting the file... 
ping localhost -n 2 > nul
echo Entering MS-DOS (recovery) mode...
echo.
echo Tweaking the registry...
reg add HKLM\System\Setup /v CmdLine /t REG_SZ /d "cmd.exe /k C:\dosexec.bat" /f
reg add HKLM\System\Setup /v SystemSetupInProgress /t REG_DWORD /d 1 /f > nul
reg add HKLM\System\Setup /v SetupType /t REG_DWORD /d 2 /f > nul
reg add HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System /v EnableCursorSuppression /t REG_DWORD /d 0 /f > nul
reg add HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System /v EnableLUA /t REG_DWORD /d 0 /f > nul
reg add HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System /v VerboseStatus /t REG_DWORD /d 1 /f > nul
echo.


if not exist "%SystemDrive%\dosexec.bat" (
    echo Dosexec not present, creating a default file.

    (
        echo @echo off
        echo echo This is a default dosexec file, you can add commands here to run on the next recovery startup.
        echo reg add HKLM\System\Setup /v SystemSetupInProgress /t REG_DWORD /d 0 /f
        echo net start
        echo start explorer
        echo ping localhost -n 3
        echo cls
        echo echo The system runs in the recovery /so-called MS-DOS/ mode, type ^"win^" to get back to Windows.
        echo powershell -ExecutionPolicy Bypass -File C:\start.ps1
        echo powershell -ExecutionPolicy Bypass -File C:\updateinstall.ps1
	start C:\windows\system32\win.bat
    ) > "%SystemDrive%\dosexec.bat"

    echo.
    echo =-=-=-=-=-= DOSEXEC.BAT =-=-=-=-=-=
    type "%SystemDrive%\dosexec.bat"
    echo =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    pause
)

echo.
echo Done, rebooting.
ping localhost -n 3 > nul
shutdown -r -t 0