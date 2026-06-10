"""
Job Search Agent for Chioma Okoye
Searches for cybersecurity leadership roles using SerpAPI Google Jobs API.
Filters by seniority, remote preference, and salary.
Outputs matched jobs to a JSON file and a readable summary.
"""

import json
import os
import time
import hashlib
from datetime import datetime
from pathlib import Path

try:
    import requests
except ImportError:
    print("Installing requests...")
    os.system("pip install requests")
    import requests

# ============================================================
# CONFIGURATION
# ============================================================

SERPAPI_KEY = os.environ.get("SERPAPI_KEY", "50404186c68a7afca77a7f3430e2038a53063237a4b48589159fabf4ef264180")

# Target roles to search for
# Target roles to search for - format: "query|gl|location"
# gl = geo-location code, location = specific city/region for Google Jobs
SEARCH_QUERIES = [
    # ===== IRELAND (location param is required for Irish results) =====
    "cybersecurity|us|Dublin, County Dublin, Ireland",
    "security engineer|us|Dublin, County Dublin, Ireland",
    "cloud security|us|Dublin, County Dublin, Ireland",
    "CISO|us|Dublin, County Dublin, Ireland",
    "Head of Security|us|Dublin, County Dublin, Ireland",
    "Director security|us|Dublin, County Dublin, Ireland",
    "incident response|us|Dublin, County Dublin, Ireland",
    "security architect|us|Dublin, County Dublin, Ireland",
    "DevSecOps|us|Dublin, County Dublin, Ireland",
    "SOC analyst|us|Dublin, County Dublin, Ireland",
    "threat intelligence|us|Dublin, County Dublin, Ireland",
    "information security|us|Dublin, County Dublin, Ireland",
    "security operations|us|Dublin, County Dublin, Ireland",
    "penetration tester|us|Dublin, County Dublin, Ireland",
    "detection engineer|us|Dublin, County Dublin, Ireland",

    # ===== UK (gl=uk) =====
    "cybersecurity remote|uk|",
    "security engineer remote|uk|",
    "CISO|uk|",
    "cloud security|uk|",
    "Head of Security|uk|",
    "Director cybersecurity|uk|",
    "DevSecOps|uk|",
    "threat intelligence|uk|",
    "security architect remote|uk|",
    "SIEM engineer|uk|",
    "SOC manager|uk|",

    # ===== Germany (gl=de) =====
    "cybersecurity remote English|de|",
    "security engineer remote|de|",
    "CISO|de|",
    "cloud security|de|",
    "Head of Security|de|",

    # ===== Netherlands (gl=nl) =====
    "cybersecurity remote|nl|",
    "security engineer|nl|",
    "CISO|nl|",
    "cloud security|nl|",

    # ===== France (gl=fr) =====
    "cybersecurity remote English|fr|",
    "CISO|fr|",
    "security engineer|fr|",

    # ===== Europe general =====
    "cybersecurity remote Europe|us|",
    "CISO Europe remote|us|",
    "security engineer remote Europe|us|",
    "cloud security remote Europe|us|",
    "Head of Security Europe remote|us|",
    "Director cybersecurity Europe remote|us|",
    "DevSecOps Europe remote|us|",
    "security architect Europe remote|us|",

    # ===== Remote Global =====
    "cybersecurity engineer remote|us|",
    "security engineer remote|us|",
    "cloud security engineer remote|us|",
    "detection engineer remote|us|",
    "incident response remote|us|",
    "security architect remote|us|",
    "CISO remote|us|",
    "Head of Security remote|us|",
    "Director cybersecurity remote|us|",
    "SIEM engineer remote|us|",
    "SOAR engineer remote|us|",
    "DevSecOps remote|us|",
    "vulnerability management remote|us|",
    "Staff security engineer remote|us|",
    "Principal security engineer remote|us|",
]

# Minimum salary threshold (USD/EUR equivalent)
MIN_SALARY = 125000

# Keywords that indicate a good match based on resume
MATCH_KEYWORDS = [
    "cloud security", "aws", "azure", "ciso", "head of security",
    "incident response", "threat intelligence", "siem", "soar",
    "pci", "iso 27001", "hipaa", "compliance", "soc",
    "detection", "automation", "terraform", "security engineering",
    "security operations", "vulnerability management", "risk",
    "security architecture", "devsecops", "secure sdlc",
    "team lead", "staff engineer", "principal engineer",
    "director", "vp security", "cloud native", "kubernetes",
    "container security", "zero trust", "xdr",
]

# Seniority keywords to prioritize
SENIORITY_KEYWORDS = [
    "ciso", "chief", "head of", "director", "vp", "vice president",
    "staff", "principal", "senior director", "lead", "manager",
]

# Output paths
OUTPUT_DIR = Path(__file__).parent
RESULTS_FILE = OUTPUT_DIR / "job_results.json"
SUMMARY_FILE = OUTPUT_DIR / "job_summary.md"
SEEN_JOBS_FILE = OUTPUT_DIR / "seen_jobs.json"


def load_seen_jobs():
    """Load previously seen job IDs to avoid duplicates."""
    if SEEN_JOBS_FILE.exists():
        with open(SEEN_JOBS_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return []


def save_seen_jobs(seen):
    """Save seen job IDs."""
    with open(SEEN_JOBS_FILE, "w", encoding="utf-8") as f:
        json.dump(seen, f)


def generate_job_id(job):
    """Generate a unique hash for a job posting."""
    unique_str = f"{job.get('title', '')}{job.get('company_name', '')}{job.get('location', '')}"
    return hashlib.md5(unique_str.encode()).hexdigest()


def search_jobs(query, gl="us", location=""):
    """Search for jobs using SerpAPI Google Jobs API."""
    url = "https://serpapi.com/search.json"
    params = {
        "engine": "google_jobs",
        "q": query,
        "api_key": SERPAPI_KEY,
        "hl": "en",
        "gl": gl,
        "chips": "date_posted:week",
    }
    if location:
        params["location"] = location

    try:
        response = requests.get(url, params=params, timeout=30)
        response.raise_for_status()
        data = response.json()
        return data.get("jobs_results", [])
    except requests.exceptions.RequestException as e:
        print(f"  [ERROR] Search failed for '{query}' (gl={gl}): {e}")
        return []


def calculate_match_score(job):
    """Calculate how well a job matches Chioma's profile (0-100).
    Primary factor: salary. Secondary: skills match."""
    score = 0
    title = job.get("title", "").lower()
    description = job.get("description", "").lower()
    combined = f"{title} {description}"

    # Salary is the PRIMARY scoring factor (up to 40 points)
    salary_info = extract_salary(job)
    if salary_info:
        if salary_info >= 200000:
            score += 40
        elif salary_info >= 150000:
            score += 35
        elif salary_info >= MIN_SALARY:
            score += 25
        else:
            # Below minimum salary - heavy penalty
            return 0, []
    else:
        # No salary info - give moderate base (might still be good)
        score += 10

    # Skills/keyword match (up to 40 points)
    matched_keywords = []
    for keyword in MATCH_KEYWORDS:
        if keyword in combined:
            matched_keywords.append(keyword)
    keyword_score = min(40, len(matched_keywords) * 4)
    score += keyword_score

    # Remote or hybrid preference (up to 10 points)
    if "remote" in combined or "hybrid" in combined:
        score += 10

    # Ireland location bonus (10 points) or other EU (5 points)
    if "ireland" in combined or "dublin" in combined:
        score += 10
    elif any(loc in combined for loc in ["uk", "united kingdom", "london", "germany", "berlin",
             "netherlands", "amsterdam", "france", "paris", "europe", "spain",
             "sweden", "switzerland", "denmark", "belgium"]):
        score += 5

    return min(100, score), matched_keywords


def extract_salary(job):
    """Try to extract salary from job extensions or description."""
    extensions = job.get("detected_extensions", {})

    # Check salary from extensions
    salary_min = extensions.get("salary_min")
    salary_max = extensions.get("salary_max")

    if salary_max:
        return salary_max
    if salary_min:
        return salary_min

    # Try to find salary in description
    description = job.get("description", "")
    import re
    salary_patterns = [
        r"\$(\d{3},?\d{3})",
        r"(\d{3},?\d{3})\s*(?:USD|EUR|GBP)",
        r"€(\d{3},?\d{3})",
        r"£(\d{3},?\d{3})",
    ]
    for pattern in salary_patterns:
        match = re.search(pattern, description)
        if match:
            salary_str = match.group(1).replace(",", "")
            try:
                return int(salary_str)
            except ValueError:
                pass

    return None


def format_job_summary(jobs, new_only=False):
    """Format jobs into a readable markdown summary."""
    lines = []
    lines.append(f"# Job Search Results - {datetime.now().strftime('%Y-%m-%d %H:%M')}\n")
    lines.append(f"**Profile:** Chioma Okoye | Head of Cybersecurity | Cloud & Enterprise Security")
    lines.append(f"**Preferences:** Remote | Global | CISO/Director/Staff+ | $125k+ minimum\n")
    lines.append(f"**Total Matches Found:** {len(jobs)}\n")

    if new_only:
        lines.append("*Showing new jobs only (not previously seen)*\n")

    lines.append("---\n")

    for i, job in enumerate(jobs, 1):
        score = job.get("match_score", 0)
        score_label = "🟢 Strong" if score >= 70 else "🟡 Good" if score >= 50 else "🔵 Moderate"

        lines.append(f"## {i}. {job['title']}")
        lines.append(f"**Company:** {job.get('company_name', 'N/A')}")
        lines.append(f"**Location:** {job.get('location', 'N/A')}")

        salary = job.get("salary_estimate")
        if salary:
            lines.append(f"**Salary:** ${salary:,}+")
        else:
            lines.append(f"**Salary:** Not disclosed")

        lines.append(f"**Match Score:** {score_label} ({score}/100)")
        lines.append(f"**Matched Skills:** {', '.join(job.get('matched_keywords', []))}")

        # Application links
        apply_links = job.get("apply_options", [])
        if apply_links:
            lines.append(f"**Apply:**")
            for link in apply_links[:3]:
                lines.append(f"  - [{link.get('title', 'Apply')}]({link.get('link', '')})")

        via = job.get("via", "")
        if via:
            lines.append(f"**Source:** {via}")

        lines.append(f"**Posted:** {job.get('detected_extensions', {}).get('posted_at', 'Recently')}")
        lines.append("")

        # Brief description excerpt
        desc = job.get("description", "")
        if desc:
            excerpt = desc[:300].replace("\n", " ")
            lines.append(f"> {excerpt}...")

        lines.append("\n---\n")

    return "\n".join(lines)


def run_search():
    """Main search execution."""
    print("=" * 60)
    print("  JOB SEARCH AGENT - Chioma Okoye")
    print(f"  Running at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60)
    print()

    seen_jobs = load_seen_jobs()
    all_matched_jobs = []
    new_jobs = []

    for i, entry in enumerate(SEARCH_QUERIES, 1):
        parts = entry.split("|")
        query = parts[0]
        gl = parts[1] if len(parts) > 1 and parts[1] else "us"
        location = parts[2] if len(parts) > 2 and parts[2] else ""
        region = location.split(",")[0] if location else {"ie": "Ireland", "uk": "UK", "de": "Germany", "nl": "Netherlands", "fr": "France", "us": "Global"}.get(gl, gl)
        print(f"[{i}/{len(SEARCH_QUERIES)}] Searching: {query} [{region}]")
        jobs = search_jobs(query, gl, location)
        print(f"  Found {len(jobs)} results")

        for job in jobs:
            job_id = generate_job_id(job)

            # Skip duplicates within this run
            if any(j.get("job_id") == job_id for j in all_matched_jobs):
                continue

            # Calculate match score
            score, matched_keywords = calculate_match_score(job)

            # Only include jobs with a reasonable match (score >= 40)
            if score >= 40:
                job_entry = {
                    "job_id": job_id,
                    "title": job.get("title", ""),
                    "company_name": job.get("company_name", ""),
                    "location": job.get("location", ""),
                    "description": job.get("description", "")[:500],
                    "via": job.get("via", ""),
                    "apply_options": job.get("apply_options", []),
                    "detected_extensions": job.get("detected_extensions", {}),
                    "match_score": score,
                    "matched_keywords": matched_keywords,
                    "salary_estimate": extract_salary(job),
                    "found_date": datetime.now().isoformat(),
                    "is_new": job_id not in seen_jobs,
                }
                all_matched_jobs.append(job_entry)

                if job_id not in seen_jobs:
                    new_jobs.append(job_entry)

        # Rate limiting - be respectful to the API
        if i < len(SEARCH_QUERIES):
            time.sleep(2)

    # Sort by match score (highest first)
    all_matched_jobs.sort(key=lambda x: x["match_score"], reverse=True)
    new_jobs.sort(key=lambda x: x["match_score"], reverse=True)

    # Save results
    with open(RESULTS_FILE, "w", encoding="utf-8") as f:
        json.dump(all_matched_jobs, f, indent=2, default=str)

    # Save summary
    summary = format_job_summary(all_matched_jobs)
    with open(SUMMARY_FILE, "w", encoding="utf-8") as f:
        f.write(summary)

    # Update seen jobs
    all_ids = seen_jobs + [j["job_id"] for j in new_jobs]
    save_seen_jobs(list(set(all_ids)))

    # Print results
    print()
    print("=" * 60)
    print(f"  RESULTS SUMMARY")
    print("=" * 60)
    print(f"  Total matched jobs: {len(all_matched_jobs)}")
    print(f"  New jobs (not seen before): {len(new_jobs)}")
    print()

    if new_jobs:
        print("  🆕 NEW MATCHING JOBS:")
        print("  " + "-" * 40)
        for job in new_jobs[:10]:
            score_icon = "🟢" if job["match_score"] >= 70 else "🟡" if job["match_score"] >= 50 else "🔵"
            print(f"  {score_icon} {job['title']}")
            print(f"     {job['company_name']} | {job['location']}")
            print(f"     Score: {job['match_score']}/100")
            if job.get("apply_options"):
                print(f"     Apply: {job['apply_options'][0].get('link', 'N/A')}")
            print()
    else:
        print("  No new jobs found since last run.")

    print(f"\n  📄 Full results: {RESULTS_FILE}")
    print(f"  📋 Summary: {SUMMARY_FILE}")
    print()

    return all_matched_jobs, new_jobs


if __name__ == "__main__":
    run_search()
