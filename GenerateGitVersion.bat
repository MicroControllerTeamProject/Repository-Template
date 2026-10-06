@echo off
setlocal EnableExtensions

set "PROJECT_DIR=%~dp0"
set "BUILD_PATH=%~1"
set "OUT=%PROJECT_DIR%GitVersion.h"
set "TMP=%PROJECT_DIR%GitVersion.tmp"
set "GITTMP=%TEMP%\FirmwareGitVersion.txt"
set "FAIL_DEFINE=INVALID_GIT_BUILD"

if "%BUILD_PATH%"=="" (
	echo ERROR: Build path not provided.
	exit /b 1
)

git -C "%PROJECT_DIR%" rev-parse --show-toplevel > "%GITTMP%" 2>nul
if errorlevel 1 (
	call :fail "Git repository not found."
	exit /b 1
)
set /p REPO=<"%GITTMP%"

git -C "%REPO%" rev-parse --abbrev-ref HEAD > "%GITTMP%"
set /p BRANCH=<"%GITTMP%"

echo Git branch: %BRANCH%

rem ------------------------------------------------------------
rem Non-release branches: development build marker
rem ------------------------------------------------------------

if /I not "%BRANCH:~0,8%"=="release/" goto generate_development_version

rem ------------------------------------------------------------
rem Strict validation only for release/* branches
rem ------------------------------------------------------------

set "FAIL_DEFINE=INVALID_RELEASE_BUILD"

git -C "%REPO%" status --porcelain > "%GITTMP%"
for %%A in ("%GITTMP%") do set SIZE=%%~zA

if not "%SIZE%"=="0" (
	call :fail "Working tree is not clean."
	exit /b 1
)

git -C "%REPO%" fetch origin "%BRANCH%" --quiet
if errorlevel 1 (
	call :fail "Cannot fetch origin/%BRANCH%."
	exit /b 1
)

git -C "%REPO%" rev-parse HEAD > "%GITTMP%"
set /p LOCAL_HASH=<"%GITTMP%"

git -C "%REPO%" rev-parse FETCH_HEAD > "%GITTMP%"
set /p REMOTE_HASH=<"%GITTMP%"

if /I not "%LOCAL_HASH%"=="%REMOTE_HASH%" (
	call :fail "Local release branch is not aligned with origin."
	echo Branch: %BRANCH%
	echo Local : %LOCAL_HASH%
	echo Origin: %REMOTE_HASH%
	exit /b 1
)

rem ------------------------------------------------------------
rem Generate real Git hash for release/*
rem ------------------------------------------------------------

git -C "%REPO%" rev-parse --short=7 HEAD > "%GITTMP%"
if errorlevel 1 (
	call :fail "Cannot determine Git version."
	exit /b 1
)

set /p GIT_HASH=<"%GITTMP%"

> "%TMP%" echo #pragma once
>> "%TMP%" echo #define GIT_VERSION "%GIT_HASH%"

move /y "%TMP%" "%OUT%" >nul
del "%GITTMP%" >nul 2>&1

echo Git version: %GIT_HASH%
exit /b 0

rem ------------------------------------------------------------
rem Development version
rem ------------------------------------------------------------

:generate_development_version

> "%TMP%" echo #pragma once
>> "%TMP%" echo #define GIT_VERSION "XXXXXXX"

move /y "%TMP%" "%OUT%" >nul
del "%GITTMP%" >nul 2>&1

echo Git version: XXXXXXX
exit /b 0

:fail
> "%OUT%" echo #pragma once
>> "%OUT%" echo #error %FAIL_DEFINE%
del "%GITTMP%" >nul 2>&1
echo ERROR: %~1
exit /b 0
