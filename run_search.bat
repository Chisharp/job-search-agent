@echo off
echo ============================================
echo   Job Search Agent - Chioma Okoye
echo   %date% %time%
echo ============================================
echo.

cd /d "%~dp0"
python job_search_agent.py

echo.
echo Search complete. Check job_summary.md for results.
pause
