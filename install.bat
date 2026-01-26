@echo off
setlocal enabledelayedexpansion

:: Claude Orchestra - Windows Installation Script
:: For users who clone the repo and want to install to their project

:: Colors (Windows 10+)
set "GREEN=[32m"
set "YELLOW=[33m"
set "BLUE=[34m"
set "CYAN=[36m"
set "RED=[31m"
set "NC=[0m"

:: Get script directory
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

:: Show help
if "%1"=="-h" goto :show_help
if "%1"=="--help" goto :show_help

echo.
echo %BLUE%+---------------------------------------------------------------+%NC%
echo %BLUE%^|           Claude Orchestra - Windows Installer                ^|%NC%
echo %BLUE%^|                                                               ^|%NC%
echo %BLUE%^|   For marketplace install, use:                              ^|%NC%
echo %BLUE%^|   /plugin marketplace add picpal/claude-orchestra            ^|%NC%
echo %BLUE%^|   /plugin install claude-orchestra@claude-orchestra          ^|%NC%
echo %BLUE%+---------------------------------------------------------------+%NC%
echo.

:: Verify we're in the right directory
if not exist "%SCRIPT_DIR%\agents" (
    echo %RED%Error: agents directory not found%NC%
    echo Please run this script from the claude-orchestra directory
    exit /b 1
)

:: Parse target directory
set "TARGET_DIR=%~1"

:: Handle -t or --target flag
if "%1"=="-t" set "TARGET_DIR=%~2"
if "%1"=="--target" set "TARGET_DIR=%~2"

:: If no target specified, ask interactively
if "%TARGET_DIR%"=="" (
    echo %CYAN%Enter the target project path:%NC%
    echo %YELLOW%^(where Claude Orchestra will be installed^)%NC%
    echo.
    set /p "TARGET_DIR=> "
    echo.
)

if "%TARGET_DIR%"=="" (
    echo %RED%Error: No target path provided%NC%
    exit /b 1
)

:: Create directory if it doesn't exist
if not exist "%TARGET_DIR%" (
    echo %YELLOW%Directory does not exist: %TARGET_DIR%%NC%
    set /p "CREATE_DIR=Create it? (y/N) "
    if /i "!CREATE_DIR!"=="y" (
        mkdir "%TARGET_DIR%"
    ) else (
        echo Installation cancelled
        exit /b 0
    )
)

:: Convert to absolute path
pushd "%TARGET_DIR%"
set "TARGET_DIR=%CD%"
popd

echo %CYAN%Source:%NC% %SCRIPT_DIR%
echo %CYAN%Target:%NC% %TARGET_DIR%
echo.

:: Check for existing installation
if exist "%TARGET_DIR%\.claude\agents" (
    echo %YELLOW%Warning: Existing Claude Orchestra installation detected%NC%
    set /p "OVERWRITE=Overwrite? (y/N) "
    if /i not "!OVERWRITE!"=="y" (
        echo Installation cancelled
        exit /b 0
    )
)

echo %GREEN%Installing Claude Orchestra...%NC%
echo.

:: Create .claude directory structure
echo Creating directories...
mkdir "%TARGET_DIR%\.claude\agents" 2>nul
mkdir "%TARGET_DIR%\.claude\commands" 2>nul
mkdir "%TARGET_DIR%\.claude\rules" 2>nul
mkdir "%TARGET_DIR%\.claude\contexts" 2>nul
mkdir "%TARGET_DIR%\.claude\hooks\verification" 2>nul
mkdir "%TARGET_DIR%\.claude\hooks\learning\learned-patterns" 2>nul
mkdir "%TARGET_DIR%\.claude\hooks\compact" 2>nul

:: Create .orchestra directory structure
mkdir "%TARGET_DIR%\.orchestra\plans" 2>nul
mkdir "%TARGET_DIR%\.orchestra\journal" 2>nul
mkdir "%TARGET_DIR%\.orchestra\logs" 2>nul
mkdir "%TARGET_DIR%\.orchestra\mcp-configs" 2>nul
mkdir "%TARGET_DIR%\.orchestra\templates" 2>nul

:: Copy agents
echo Installing 12 agents...
xcopy /s /y /q "%SCRIPT_DIR%\agents\*" "%TARGET_DIR%\.claude\agents\" >nul

:: Copy commands
echo Installing 11 commands...
xcopy /s /y /q "%SCRIPT_DIR%\commands\*" "%TARGET_DIR%\.claude\commands\" >nul

:: Copy rules
echo Installing 6 rules...
xcopy /s /y /q "%SCRIPT_DIR%\rules\*" "%TARGET_DIR%\.claude\rules\" >nul

:: Copy contexts
echo Installing 3 contexts...
xcopy /s /y /q "%SCRIPT_DIR%\contexts\*" "%TARGET_DIR%\.claude\contexts\" >nul

:: Copy hooks
echo Installing 15 hooks...
xcopy /s /y /q "%SCRIPT_DIR%\hooks\*" "%TARGET_DIR%\.claude\hooks\" >nul

:: Copy settings.json
echo Installing settings...
copy /y "%SCRIPT_DIR%\.claude\settings.json" "%TARGET_DIR%\.claude\settings.json" >nul

:: Copy orchestra init files
echo Installing orchestra state files...
copy /y "%SCRIPT_DIR%\orchestra-init\config.json" "%TARGET_DIR%\.orchestra\config.json" >nul
copy /y "%SCRIPT_DIR%\orchestra-init\state.json" "%TARGET_DIR%\.orchestra\state.json" >nul

if exist "%SCRIPT_DIR%\orchestra-init\mcp-configs" (
    xcopy /s /y /q "%SCRIPT_DIR%\orchestra-init\mcp-configs\*" "%TARGET_DIR%\.orchestra\mcp-configs\" >nul 2>nul
)

if exist "%SCRIPT_DIR%\orchestra-init\templates" (
    xcopy /s /y /q "%SCRIPT_DIR%\orchestra-init\templates\*" "%TARGET_DIR%\.orchestra\templates\" >nul 2>nul
)

echo.
echo %GREEN%+---------------------------------------------------------------+%NC%
echo %GREEN%^|              Installation Complete!                          ^|%NC%
echo %GREEN%+---------------------------------------------------------------+%NC%
echo.
echo Installed to: %CYAN%%TARGET_DIR%%NC%
echo.
echo %CYAN%.claude\%NC%
echo   +-- agents\      (12 agents)
echo   +-- commands\    (11 commands)
echo   +-- rules\       (6 rules)
echo   +-- contexts\    (3 contexts)
echo   +-- hooks\       (15 hooks)
echo   +-- settings.json
echo.
echo %CYAN%.orchestra\%NC%
echo   +-- config.json
echo   +-- state.json
echo   +-- plans\
echo   +-- logs\
echo.
echo %YELLOW%Quick Start:%NC%
echo   cd %TARGET_DIR%
echo   claude
echo.
echo   /start-work    - Start a work session
echo   /status        - Check current status
echo.

exit /b 0

:show_help
echo.
echo Usage: install.bat [OPTIONS] [TARGET_PATH]
echo.
echo Options:
echo   -h, --help     Show this help message
echo   -t, --target   Specify target directory
echo.
echo Examples:
echo   install.bat                      # Interactive mode
echo   install.bat C:\path\to\project   # Direct path
echo   install.bat -t C:\path\to\project  # With flag
echo.
exit /b 0
