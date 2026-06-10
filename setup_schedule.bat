@echo off
echo ============================================
echo   Setting up daily job search schedule
echo ============================================
echo.
echo This will create a Windows Task Scheduler entry to run
echo the job search agent every day at 8:00 AM.
echo.

:: Create scheduled task to run daily at 8 AM
schtasks /create /tn "JobSearchAgent_ChiomaOkoye" /tr "\"%~dp0run_search.bat\"" /sc daily /st 08:00 /f

if %errorlevel% equ 0 (
    echo.
    echo SUCCESS: Scheduled task created!
    echo The job search will run daily at 8:00 AM.
    echo.
    echo To modify: Open Task Scheduler and find "JobSearchAgent_ChiomaOkoye"
    echo To remove: schtasks /delete /tn "JobSearchAgent_ChiomaOkoye" /f
) else (
    echo.
    echo ERROR: Could not create scheduled task.
    echo Try running this script as Administrator.
)

echo.
pause
