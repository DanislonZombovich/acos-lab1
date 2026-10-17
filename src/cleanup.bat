@echo off
setlocal enabledelayedexpansion
set "LOG_DIR=%~1"
if "%LOG_DIR%"=="" set "LOG_DIR=log"
set "THRESHOLD=%~2"
if "%THRESHOLD%"=="" set "THRESHOLD=70"
set "BACKUP_DIR=%~3"
if "%BACKUP_DIR%"=="" set "BACKUP_DIR=backup"

if not exist "%LOG_DIR%" (
    echo Ошибка: папка "%LOG_DIR%" не найдена.
    exit /b 1
)

REM --- Определяем букву диска из пути LOG_DIR ---
set "DRIVE=%~d1"
if "%DRIVE%"=="" set "DRIVE=%~d0"

REM --- Получаем общий размер диска в байтах через wmic ---
set "TOTAL_BYTES="
for /f "tokens=2 delims==" %%B in ('wmic logicaldisk where "DeviceID='!DRIVE!'" get Size /value 2^>nul ^| find "="') do (
    set "TOTAL_BYTES=%%B"
)

if "!TOTAL_BYTES!"=="" (
    echo Ошибка: не удалось определить размер диска !DRIVE!
    exit /b 1
)

set /a TOTAL_MB=!TOTAL_BYTES! / 1048576

set /a TOTAL_KB=TOTAL_MB * 1024
set /a CURRENT_KB=0

for %%F in ("%LOG_DIR%\*") do (
    set /a FSIZE_KB=%%~zF / 1024
    set /a CURRENT_KB+=!FSIZE_KB!
)

set /a PERCENT=(CURRENT_KB * 100) / TOTAL_KB

echo Папка логов: %LOG_DIR%
echo Диск: %DRIVE% (объем: %TOTAL_MB% MB)
echo Текущий объем: %CURRENT_KB% KB из %TOTAL_KB% KB (%PERCENT%%)
echo Установленный порог: %THRESHOLD%%%

if %PERCENT% leq %THRESHOLD% (
    echo Порог не превышен. Архивация не требуется.
    exit /b 0
)

set /a TARGET_KB=(TOTAL_KB * THRESHOLD) / 100
set /a NEED_TO_FREE_KB=CURRENT_KB - TARGET_KB
echo Порог превышен! Требуется освободить минимум: %NEED_TO_FREE_KB% KB

set /a FREED_KB=0
set "FILES_COUNT=0"

for /f "delims=" %%F in ('dir /b /a-d /od "%LOG_DIR%"') do (
    set "FILE_NAME=%%F"
    set "FILE_PATH=%LOG_DIR%\%%F"
    for %%A in ("!FILE_PATH!") do set /a FSIZE_KB=%%~zA / 1024
    set /a FILES_COUNT+=1
    set "FILE_!FILES_COUNT!=%%F"
    set /a FREED_KB+=!FSIZE_KB!
    if !FREED_KB! geq %NEED_TO_FREE_KB% goto :stop_collecting
)
:stop_collecting

if %FILES_COUNT% equ 0 (
    echo Нет доступных файлов для архивации.
    exit /b 0
)

if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

for /f "tokens=1-4 delims=/:. " %%a in ("%time%") do set "T=%%a%%b%%c"
set "TIMESTAMP=%date:~-4%%date:~3,2%%date:~0,2%_%T: =0%"

if "%LAB1_MAX_COMPRESSION%"=="1" (
    set "ARCHIVE_NAME=backup_%TIMESTAMP%.tar.lzma"
) else (
    set "ARCHIVE_NAME=backup_%TIMESTAMP%.tar.gz"
)

set "FILE_LIST="
for /l %%i in (1,1,%FILES_COUNT%) do (
    set "FILE_LIST=!FILE_LIST! "!FILE_%%i!""
)

pushd "%LOG_DIR%"
if "%LAB1_MAX_COMPRESSION%"=="1" (
    tar --lzma -cf "..\%BACKUP_DIR%\%ARCHIVE_NAME%" !FILE_LIST!
) else (
    tar -czf "..\%BACKUP_DIR%\%ARCHIVE_NAME%" !FILE_LIST!
)
popd

if %ERRORLEVEL% neq 0 (
    echo Ошибка при создании архива.
    exit /b 1
)

for /l %%i in (1,1,%FILES_COUNT%) do (
    del /f /q "%LOG_DIR%\!FILE_%%i!"
)

set /a NEW_KB=0
for %%F in ("%LOG_DIR%\*") do (
    set /a FSIZE_KB=%%~zF / 1024
    set /a NEW_KB+=!FSIZE_KB!
)
set /a NEW_PERCENT=(NEW_KB * 100) / TOTAL_KB

echo Архив успешно создан: %BACKUP_DIR%\%ARCHIVE_NAME%
echo Удалено файлов: %FILES_COUNT%
echo Освобождено памяти: %FREED_KB% KB
echo Текущий объем после очистки: %NEW_KB% KB из %TOTAL_KB% KB (%NEW_PERCENT%%)
exit /b 0
