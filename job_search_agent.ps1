<#
.SYNOPSIS
    Job Search Agent for Chioma Okoye
    Searches for cybersecurity leadership roles using SerpAPI Google Jobs API.
    
.DESCRIPTION
    - Searches multiple role variations across Google Jobs
    - Scores matches based on skills, seniority, and preferences
    - Outputs results to JSON and Markdown summary
    - Tracks previously seen jobs to highlight new findings

.USAGE
    .\job_search_agent.ps1
#>

# ============================================================
# CONFIGURATION
# ============================================================

$SERPAPI_KEY = if ($env:SERPAPI_KEY) { $env:SERPAPI_KEY } else { "50404186c68a7afca77a7f3430e2038a53063237a4b48589159fabf4ef264180" }

$SEARCH_QUERIES = @(
    # Broad cybersecurity roles - remote & global
    "cybersecurity engineer remote"
    "cyber security remote"
    "security engineer remote"
    "cloud security engineer remote"
    "detection engineer remote"
    "incident response remote"
    "security architect remote"
    "security operations remote"
    "threat intelligence remote"
    "SIEM engineer remote"
    "SOAR engineer remote"
    "DevSecOps remote"
    "application security remote"
    "penetration tester remote"
    "vulnerability management remote"
    "CISO remote"
    "Head of Security remote"
    "Director cybersecurity remote"
    "VP security remote"
    # Ireland & hybrid specific
    "cybersecurity Ireland"
    "security engineer Ireland hybrid"
    "cloud security Ireland"
    "CISO Ireland"
    "Head of Security Ireland"
    "Director security Ireland"
    "cyber detection engineer Ireland"
    "incident response Ireland"
    "security architect Ireland hybrid"
    "DevSecOps Ireland"
)

$MIN_SALARY = 125000

$MATCH_KEYWORDS = @(
    "cloud security", "aws", "azure", "ciso", "head of security",
    "incident response", "threat intelligence", "siem", "soar",
    "pci", "iso 27001", "hipaa", "compliance", "soc",
    "detection", "automation", "terraform", "security engineering",
    "security operations", "vulnerability management", "risk",
    "security architecture", "devsecops", "secure sdlc",
    "team lead", "staff engineer", "principal engineer",
    "director", "vp security", "cloud native", "kubernetes",
    "container security", "zero trust", "xdr"
)

$SENIORITY_KEYWORDS = @(
    "ciso", "chief", "head of", "director", "vp", "vice president",
    "staff", "principal", "senior director", "lead", "manager"
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RESULTS_FILE = Join-Path $ScriptDir "job_results.json"
$SUMMARY_FILE = Join-Path $ScriptDir "job_summary.md"
$SEEN_JOBS_FILE = Join-Path $ScriptDir "seen_jobs.json"

# ============================================================
# FUNCTIONS
# ============================================================

function Get-SeenJobs {
    if (Test-Path $SEEN_JOBS_FILE) {
        return Get-Content $SEEN_JOBS_FILE -Raw | ConvertFrom-Json
    }
    return @()
}

function Save-SeenJobs($seen) {
    $seen | ConvertTo-Json | Set-Content $SEEN_JOBS_FILE -Encoding UTF8
}

function Get-JobId($job) {
    $str = "$($job.title)$($job.company_name)$($job.location)"
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($str)
    $hash = $md5.ComputeHash($bytes)
    return [BitConverter]::ToString($hash).Replace("-", "").ToLower()
}

function Search-Jobs($query) {
    $uri = "https://serpapi.com/search.json"
    $params = "engine=google_jobs&q=$([System.Uri]::EscapeDataString($query))&api_key=$SERPAPI_KEY&hl=en&chips=date_posted:week"
    $fullUri = "$uri`?$params"

    try {
        $response = Invoke-RestMethod -Uri $fullUri -Method Get -TimeoutSec 30
        if ($response.jobs_results) {
            return $response.jobs_results
        }
        return @()
    }
    catch {
        Write-Host "  [ERROR] Search failed for '$query': $_" -ForegroundColor Red
        return @()
    }
}

function Get-MatchScore($job) {
    $score = 0
    $title = $job.title.ToLower()
    $description = if ($job.description) { $job.description.ToLower() } else { "" }
    $combined = "$title $description"
    $matchedKeywords = @()

    # Salary is PRIMARY factor (up to 40 points)
    $salary = Get-SalaryEstimate $job
    if ($salary) {
        if ($salary -ge 200000) { $score += 40 }
        elseif ($salary -ge 150000) { $score += 35 }
        elseif ($salary -ge $MIN_SALARY) { $score += 25 }
        else {
            # Below minimum - reject
            return @{ Score = 0; Keywords = @() }
        }
    } else {
        # No salary info - moderate base
        $score += 10
    }

    # Skills match (up to 40 points)
    foreach ($kw in $MATCH_KEYWORDS) {
        if ($combined -match [regex]::Escape($kw)) {
            $matchedKeywords += $kw
        }
    }
    $keywordScore = [Math]::Min(40, $matchedKeywords.Count * 4)
    $score += $keywordScore

    # Remote or hybrid (10 points)
    if ($combined -match "remote" -or $combined -match "hybrid") {
        $score += 10
    }

    # Ireland bonus (10 points)
    if ($combined -match "ireland" -or $combined -match "dublin") {
        $score += 10
    }

    return @{
        Score = [Math]::Min(100, $score)
        Keywords = $matchedKeywords
    }
}

function Get-SalaryEstimate($job) {
    # Check extensions
    if ($job.detected_extensions) {
        if ($job.detected_extensions.salary_max) { return $job.detected_extensions.salary_max }
        if ($job.detected_extensions.salary_min) { return $job.detected_extensions.salary_min }
    }

    # Try regex on description
    if ($job.description) {
        if ($job.description -match '\$(\d{3},?\d{3})') {
            $salaryStr = $matches[1] -replace ","
            try { return [int]$salaryStr } catch { }
        }
    }
    return $null
}

function Format-Summary($jobs) {
    $now = Get-Date -Format "yyyy-MM-dd HH:mm"
    $lines = @()
    $lines += "# Job Search Results - $now`n"
    $lines += "**Profile:** Chioma Okoye | Head of Cybersecurity | Cloud & Enterprise Security"
    $lines += "**Preferences:** Remote | Global | CISO/Director/Staff+ | `$125k+ minimum`n"
    $lines += "**Total Matches Found:** $($jobs.Count)`n"
    $lines += "---`n"

    $i = 0
    foreach ($job in $jobs) {
        $i++
        $scoreLabel = if ($job.match_score -ge 70) { "Strong Match" } 
                      elseif ($job.match_score -ge 50) { "Good Match" } 
                      else { "Moderate Match" }

        $lines += "## $i. $($job.title)"
        $lines += "**Company:** $($job.company_name)"
        $lines += "**Location:** $($job.location)"
        
        if ($job.salary_estimate) {
            $lines += "**Salary:** `$$($job.salary_estimate.ToString('N0'))+"
        } else {
            $lines += "**Salary:** Not disclosed"
        }
        
        $lines += "**Match Score:** $scoreLabel ($($job.match_score)/100)"
        $lines += "**Matched Skills:** $($job.matched_keywords -join ', ')"

        if ($job.apply_options -and $job.apply_options.Count -gt 0) {
            $lines += "**Apply:**"
            foreach ($link in ($job.apply_options | Select-Object -First 3)) {
                $lines += "  - [$($link.title)]($($link.link))"
            }
        }

        if ($job.via) { $lines += "**Source:** $($job.via)" }
        
        $posted = if ($job.detected_extensions -and $job.detected_extensions.posted_at) { 
            $job.detected_extensions.posted_at 
        } else { "Recently" }
        $lines += "**Posted:** $posted"
        $lines += ""

        if ($job.description) {
            $excerpt = $job.description.Substring(0, [Math]::Min(300, $job.description.Length)) -replace "`n", " "
            $lines += "> $excerpt..."
        }
        $lines += "`n---`n"
    }

    return $lines -join "`n"
}

# ============================================================
# MAIN EXECUTION
# ============================================================

Write-Host "=" * 60
Write-Host "  JOB SEARCH AGENT - Chioma Okoye" -ForegroundColor Cyan
Write-Host "  Running at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "=" * 60
Write-Host ""

$seenJobs = @(Get-SeenJobs)
$allMatchedJobs = @()
$newJobs = @()

$queryCount = $SEARCH_QUERIES.Count
for ($i = 0; $i -lt $queryCount; $i++) {
    $query = $SEARCH_QUERIES[$i]
    Write-Host "[$($i+1)/$queryCount] Searching: $query" -ForegroundColor Yellow
    
    $jobs = @(Search-Jobs $query)
    Write-Host "  Found $($jobs.Count) results"

    foreach ($job in $jobs) {
        $jobId = Get-JobId $job

        # Skip duplicates
        if ($allMatchedJobs | Where-Object { $_.job_id -eq $jobId }) { continue }

        # Calculate score
        $result = Get-MatchScore $job
        $score = $result.Score
        $keywords = $result.Keywords

        # Only include jobs scoring 40+
        if ($score -ge 40) {
            $entry = [PSCustomObject]@{
                job_id            = $jobId
                title             = $job.title
                company_name      = $job.company_name
                location          = $job.location
                description       = if ($job.description) { $job.description.Substring(0, [Math]::Min(500, $job.description.Length)) } else { "" }
                via               = $job.via
                apply_options     = $job.apply_options
                detected_extensions = $job.detected_extensions
                match_score       = $score
                matched_keywords  = $keywords
                salary_estimate   = Get-SalaryEstimate $job
                found_date        = (Get-Date).ToString("o")
                is_new            = ($seenJobs -notcontains $jobId)
            }
            $allMatchedJobs += $entry

            if ($seenJobs -notcontains $jobId) {
                $newJobs += $entry
            }
        }
    }

    # Rate limiting
    if ($i -lt ($queryCount - 1)) {
        Start-Sleep -Seconds 2
    }
}

# Sort by score
$allMatchedJobs = $allMatchedJobs | Sort-Object -Property match_score -Descending
$newJobs = $newJobs | Sort-Object -Property match_score -Descending

# Save JSON results
$allMatchedJobs | ConvertTo-Json -Depth 5 | Set-Content $RESULTS_FILE -Encoding UTF8

# Save markdown summary
$summary = Format-Summary $allMatchedJobs
$summary | Set-Content $SUMMARY_FILE -Encoding UTF8

# Update seen jobs
$allIds = @($seenJobs) + @($newJobs | ForEach-Object { $_.job_id })
$allIds | Select-Object -Unique | ConvertTo-Json | Set-Content $SEEN_JOBS_FILE -Encoding UTF8

# Print results
Write-Host ""
Write-Host "=" * 60
Write-Host "  RESULTS SUMMARY" -ForegroundColor Green
Write-Host "=" * 60
Write-Host "  Total matched jobs: $($allMatchedJobs.Count)"
Write-Host "  New jobs (not seen before): $($newJobs.Count)"
Write-Host ""

if ($newJobs.Count -gt 0) {
    Write-Host "  NEW MATCHING JOBS:" -ForegroundColor Green
    Write-Host "  $('-' * 40)"
    
    foreach ($job in ($newJobs | Select-Object -First 10)) {
        $icon = if ($job.match_score -ge 70) { "[STRONG]" } 
                elseif ($job.match_score -ge 50) { "[GOOD]" } 
                else { "[OK]" }
        
        Write-Host "  $icon $($job.title)" -ForegroundColor White
        Write-Host "     $($job.company_name) | $($job.location)" -ForegroundColor Gray
        Write-Host "     Score: $($job.match_score)/100"
        
        if ($job.apply_options -and $job.apply_options.Count -gt 0) {
            Write-Host "     Apply: $($job.apply_options[0].link)" -ForegroundColor Cyan
        }
        Write-Host ""
    }
} else {
    Write-Host "  No new jobs found since last run." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  Full results: $RESULTS_FILE" -ForegroundColor Gray
Write-Host "  Summary: $SUMMARY_FILE" -ForegroundColor Gray
Write-Host ""
