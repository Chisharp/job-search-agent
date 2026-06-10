# Job Search Agent - Chioma Okoye

Automated job search agent that finds cybersecurity leadership roles matching your profile.
Portable — copy this entire folder to any system and run.

## Quick Start

### Windows (PowerShell — no Python needed)
```powershell
cd job_search_agent
.\job_search_agent.ps1
```

### Any OS (Python 3.6+)
```bash
cd job_search_agent
pip install -r requirements.txt
python job_search_agent.py
```

### Linux/Mac shortcut
```bash
chmod +x run_search.sh
./run_search.sh
```

## First Time Setup (optional)
```powershell
.\setup.ps1
```
This verifies your API key and installs dependencies.

## What It Does

- Searches Google Jobs via SerpAPI for 14 different role variations
- Matches jobs against your skills, experience, and preferences
- Scores each job (0-100) based on relevance
- Tracks jobs you've already seen (no duplicate alerts)
- Outputs results as JSON and a readable Markdown summary with apply links

## Your Search Criteria

| Parameter | Value |
|-----------|-------|
| Roles | CISO, Head of Security, Director, VP, Staff/Principal Engineer |
| Location | Global, Remote preferred |
| Salary | $125,000+ |
| Skills Match | AWS, Cloud Security, SOAR, SIEM, PCI, ISO 27001, Incident Response |

## Files in This Folder

| File | Purpose |
|------|---------|
| `job_search_agent.ps1` | PowerShell version (Windows, no Python needed) |
| `job_search_agent.py` | Python version (cross-platform) |
| `requirements.txt` | Python dependencies |
| `run_search.bat` | Windows one-click launcher |
| `run_search.sh` | Linux/Mac launcher |
| `setup.ps1` | First-time setup and verification |
| `setup_schedule.bat` | Schedule daily runs (Windows Task Scheduler) |
| `README.md` | This file |

## Output Files (generated after first run)

| File | Description |
|------|-------------|
| `job_summary.md` | Human-readable summary with apply links |
| `job_results.json` | Full structured data for all matched jobs |
| `seen_jobs.json` | Tracks previously found jobs (for new-job detection) |

## How Scoring Works

| Factor | Points |
|--------|--------|
| Seniority match (CISO/Director/VP/Staff in title) | 30 |
| Skills keyword matches (5 pts each, max 50) | 0-50 |
| Remote mentioned | 10 |
| Salary meets $125k threshold | 10 |

- **Strong match** (70+): Highly aligned with your profile
- **Good match** (50-69): Worth reviewing
- **Moderate match** (40-49): Tangentially related

## Scheduling Daily Runs

### Windows
Right-click `setup_schedule.bat` → Run as Administrator
(Runs daily at 8:00 AM)

### Linux/Mac (cron)
```bash
crontab -e
# Add this line:
0 8 * * * /path/to/job_search_agent/run_search.sh
```

## Updating Your API Key

If your SerpAPI key changes, update it in both:
- `job_search_agent.ps1` (line 18)
- `job_search_agent.py` (line 20)

## Customization

Edit `SEARCH_QUERIES` to add/remove role searches.
Edit `MATCH_KEYWORDS` to adjust what skills increase the match score.
Edit `MIN_SALARY` to change the salary threshold.
