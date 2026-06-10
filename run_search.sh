#!/bin/bash
# Job Search Agent - Linux/Mac launcher
echo "============================================"
echo "  Job Search Agent - Chioma Okoye"
echo "  $(date)"
echo "============================================"
echo ""

cd "$(dirname "$0")"
python3 job_search_agent.py

echo ""
echo "Search complete. Check job_summary.md for results."
