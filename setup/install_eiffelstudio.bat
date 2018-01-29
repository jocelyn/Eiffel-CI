@echo off
setlocal

:: Default values
set ISE_MAJOR_MINOR=17.05
set ISE_BUILD=100416

set ISE_MAJOR_MINOR_NIGHTLY=18.01
set ISE_BUILD_NIGHTLY=101318

REM Overview:
REM
REM This script is meant for quick & easy install via:
REM   $ curl -fsSL https://github.com/jocelyn/Eiffel-CI/raw/master/setup/install_eiffelstudio.bat -o get-es.bat
REM   $ get-es.bat
REM
REM or
REM   $ curl -sSL https://github.com/jocelyn/Eiffel-CI/raw/master/setup/install_eiffelstudio.bat -o %TEMP%\get-es.bat && cmd /c %TEMP%\get-es.bat && del %TEMP%\get-es.bat


:SET_DEFAULTS
set TMP_SAFETY_DELAY=10
set DEFAULT_ISE_CHANNEL_VALUE=latest
goto GET_ARGUMENTS

:GET_ARGUMENTS
if "%1" == "" goto SET_VARIABLES
set ISE_CHANNEL=%1

if "%2" == "" goto SET_VARIABLES
set ISE_PLATFORM=%2

goto SET_VARIABLES


:SET_VARIABLES
echo %ISE_CHANNEL% and %ISE_PLATFORM%

set T_CURRENT_DIR=%CD%

:: This value will automatically get changed for:
::   * latest
::	* specific release, using major.minor.build (such as 17.05.100416)
::   * nightly

if "%ISE_CHANNEL%" == "" set ISE_CHANNEL=%DEFAULT_ISE_CHANNEL_VALUE%


goto DO_INSTALL

:iseverParse
	FOR /f "tokens=1* delims=." %%a IN ("%~1") DO (
		set major=%%a
		FOR /f "tokens=1* delims=." %%a IN ("%%b") DO (
			set minor=%%a
			set build=%%b
		)
	)
goto:eof

:DO_INSTALL
	echo >&2 "Executing eiffelstudio install script ... (%ISE_CHANNEL%)"

	reg Query "HKLM\Hardware\Description\System\CentralProcessor\0" | find /i "x86" > NUL && set architecture=32bits || set architecture=64bits

	if NOT "%ISE_PLATFORM%" == "" goto CHECK_CHANNEL
	echo >&2 Get ISE_PLATFORM from architecture ..
	if "%architecture%" == "32bits" set ISE_PLATFORM=windows
	if "%architecture%" == "64bits" set ISE_PLATFORM=win64

	goto CHECK_CHANNEL

:CHECK_CHANNEL
	echo >&2 Using existing ISE_PLATFORM=%ISE_PLATFORM% on architecture Windows %architecture%

	if "%ISE_CHANNEL%" == "latest" goto CHANNEL_LATEST
	if "%ISE_CHANNEL%" == "nightly" goto CHANNEL_NIGHTLY
	if "%ISE_CHANNEL%" == "" goto FAILURE

			echo >&2 Use custom release %ISE_CHANNEL% if any
			call:iseverParse %ISE_CHANNEL%
			echo >&2 Version=%major%.%minor%.%build%
			set ISE_MAJOR_MINOR=%major%.%minor%
			set ISE_BUILD=%build%
			set ISE_DOWNLOAD_FILE=Eiffel_%ISE_MAJOR_MINOR%_gpl_%ISE_BUILD%-%ISE_PLATFORM%.7z
			set ISE_DOWNLOAD_URL=https://ftp.eiffel.com/pub/download/%ISE_MAJOR_MINOR%/%ISE_DOWNLOAD_FILE%
goto POST_CHANNEL

:CHANNEL_LATEST
			:: Use defaults .. see above.
			echo >&2 Use latest release.
			set ISE_DOWNLOAD_FILE=Eiffel_%ISE_MAJOR_MINOR%_gpl_%ISE_BUILD%-%ISE_PLATFORM%.7z
			set ISE_DOWNLOAD_URL=http://downloads.sourceforge.net/eiffelstudio/%ISE_DOWNLOAD_FILE%
			call:iseverParse %ISE_MAJOR_MINOR%.%ISE_BUILD%
			echo >&2 Version=%major%.%minor%.%build%
			;;
goto POST_CHANNEL

:CHANNEL_NIGHTLY
			echo >&2 Use nighlty release.
			set ISE_MAJOR_MINOR=%ISE_MAJOR_MINOR_NIGHTLY%
			set ISE_BUILD=%ISE_BUILD_NIGHTLY%

			set ISE_DOWNLOAD_FILE=Eiffel_%ISE_MAJOR_MINOR%_gpl_%ISE_BUILD%-%ISE_PLATFORM%.7z
			set ISE_DOWNLOAD_URL=https://ftp.eiffel.com/pub/beta/nightly/%ISE_DOWNLOAD_FILE%
			call:iseverParse %ISE_MAJOR_MINOR%.%ISE_BUILD%
			echo >&2 Version=%major%.%minor%.%build%

	goto POST_CHANNEL

:POST_CHANNEL

	goto CHECK_CONFLICT

:CHECK_COMMAND
	for %%f in (%~1) do (
	   if exist "%%~dp$PATH:f" set %~2=%%~dp$PATH:f%~1
	)
	goto:eof

:CHECK_CONFLICT
	call:CHECK_COMMAND ecb.exe ECB_PATH
	if "%ECB_PATH%" == "" goto CHECK_TOOLS
		echo >&2 Warning: the "ecb" command appears to already exist on this system.
		echo >&2 If you already have EiffelStudio installed, this script can cause trouble, which is
		echo >&2 why we are displaying this warning and provide the opportunity to cancel the installation.
		echo >&2 If you installed the current EiffelStudio package using this script and are using it
		echo >&2 again to update EiffelStudio, you can safely ignore this message.
		echo >&2 You may press Ctrl+C now to abort this script.

		choice /T %TMP_SAFETY_DELAY% /C cyn /N /D y /M "Press [C] to cancel, Press [Y] to continue now, or wait %TMP_SAFETY_DELAY% seconds ..."
		if %ERRORLEVEL% NEQ 2 goto ABORT
		goto CHECK_TOOLS

:CHECK_TOOLS


:CHECK_7z
	call:CHECK_COMMAND 7z.exe S7Z_PATH
	if "%S7Z_PATH%" NEQ "" (
		set extract_cmd="%S7Z_PATH%" x
		goto CHECK_DOWNLOAD
	) else (
		echo >&2 Can not find a 7z extract utility: 7z.exe, ...
		goto FAILURE
	)

:CHECK_DOWNLOAD
	call:CHECK_COMMAND curl.exe CURL_PATH
	if NOT "%CURL_PATH%" == "" (
		echo >&2 Use %CURL_PATH%
		set download_cmd="%CURL_PATH%" -fsSL 
		:: -H 'Cache-Control: no-cache'
		goto GET_DOWNLOAD
	) else (
		call:CHECK_WGET
	)
:CHECK_WGET
	call:CHECK_COMMAND wget.exe WGET_PATH
	if NOT "%WGET_PATH%" == "" (
		set download_cmd="%WGET_PATH%" -qO-
		goto GET_DOWNLOAD
	) else (
		echo >&2 Can not find a download utility: curl, wget, ...
		goto FAILURE
	)

:GET_DOWNLOAD

	set ISE_EIFFEL=%CD%\Eiffel_%ISE_MAJOR_MINOR%

	if EXIST "%ISE_EIFFEL%--REMOVE" (
		echo >&2 Warning: the folder %ISE_EIFFEL% already exists!
		echo >&2 This script will remove it, to install a fresh release, which is
		echo >&2 why we are displaying this warning and provide the opportunity to cancel the installation.
		echo >&2 If you installed the current EiffelStudio package using this script and are using it
		echo >&2 You may press Ctrl+C now to abort this script.
		choice /T %TMP_SAFETY_DELAY% /C cyn /N /D y /M "Press [C] to cancel, Press [Y] to continue now, or wait %TMP_SAFETY_DELAY% seconds ..."
		if %ERRORLEVEL% NEQ 2 goto ABORT
		rd /q/s "%ISE_EIFFEL%"
	)

	echo >&2 Get %ISE_DOWNLOAD_URL%
	if "$ISE_DOWNLOAD_URL" == "" (
		echo >&2 No download url !!!
		exit 1
	)
	
	set TMP_DOWNLOAD_ARCHIVE_7z=tmp_eiffel_archive.7z
	if EXIST %TMP_DOWNLOAD_ARCHIVE_7z% (
		echo >&2 Please remove %TMP_DOWNLOAD_ARCHIVE_7z%.
		goto FAILURE
		)
	%download_cmd% %ISE_DOWNLOAD_URL% > %TMP_DOWNLOAD_ARCHIVE_7z%
	echo >&2 Extract Eiffel archive ...
	if EXIST "%ISE_EIFFEL%" (
		echo >&2 %ISE_EIFFEL% already exists! Remove it first!
		goto FAILURE
		)	
	%extract_cmd% %TMP_DOWNLOAD_ARCHIVE_7z% > NUL
	del %TMP_DOWNLOAD_ARCHIVE_7z%

	set ISE_RC_FILE=eiffel_%ISE_MAJOR_MINOR%_%ISE_BUILD%.bat
	echo REM Setup for EiffelStudio %ISE_MAJOR_MINOR%.%ISE_BUILD%> %ISE_RC_FILE%
	echo set ISE_PLATFORM=%ISE_PLATFORM%>> %ISE_RC_FILE%
	echo set ISE_EIFFEL=%ISE_EIFFEL%>> %ISE_RC_FILE%
	echo set PATH=%PATH%;%%ISE_EIFFEL%%\studio\spec\%%ISE_PLATFORM%%\bin;%%ISE_EIFFEL%%\tools\spec\%%ISE_PLATFORM%%\bin>> %ISE_RC_FILE%
	type %ISE_RC_FILE%

	call %ISE_RC_FILE%

	set ECB_PATH=
	call:CHECK_COMMAND ecb.exe ECB_PATH
	if "%ECB_PATH%" == "" (
			echo >&2 ERROR: Installation failed !!!
			echo >&2 Check inside %ISE_EIFFEL%
			goto FAILURE
		)
	
	echo >&2 EiffelStudio installed in %ISE_EIFFEL%
	%ISE_EIFFEL%\studio\spec\%ISE_PLATFORM%\bin\ecb.exe -version  >&2
	echo >&2 Use the file %cd%\%ISE_RC_FILE% to setup your Eiffel environment.
	if "%ISE_CHANNEL%" == "latest" (
		copy %ISE_RC_FILE% eiffel_latest.bat > NUL
		echo >&2 or the file %cd%\eiffel_latest.bat
	)
	if "%ISE_CHANNEL%" == "nightly" (
		copy %ISE_RC_FILE% eiffel_nightly.bat > NUL
		echo >&2 or the file %cd%\eiffel_nightly.bat
	)
	echo >&2 Happy Eiffeling!

	cd %T_CURRENT_DIR%
	goto END

:FAILURE
echo Failed!
goto END

:ABORT
echo Aborted!
goto END

:END
endlocal