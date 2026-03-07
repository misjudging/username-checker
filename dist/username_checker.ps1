param(
    [string]$InputUsernames,
    [string]$InputFile,
    [string]$OutputFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Parse-Usernames {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Raw
    )

    $tokens = $Raw -split "[\s,;]+" | Where-Object { $_ -and $_.Trim().Length -gt 0 }
    $seen = @{}
    $result = New-Object System.Collections.Generic.List[string]

    foreach ($token in $tokens) {
        $clean = $token.Trim().TrimStart("@")
        if ($clean.Length -gt 0 -and -not $seen.ContainsKey($clean)) {
            $seen[$clean] = $true
            $null = $result.Add($clean)
        }
    }

    return $result
}

function Get-Platforms {
    return @(
        @{ Name = "X (Twitter)"; Url = "https://x.com/{0}" },
        @{ Name = "Instagram"; Url = "https://www.instagram.com/{0}/" },
        @{ Name = "Facebook"; Url = "https://www.facebook.com/{0}" },
        @{ Name = "TikTok"; Url = "https://www.tiktok.com/@{0}" },
        @{ Name = "YouTube"; Url = "https://www.youtube.com/@{0}" },
        @{ Name = "Twitch"; Url = "https://www.twitch.tv/{0}" },
        @{ Name = "Kick"; Url = "https://kick.com/{0}" },
        @{ Name = "Reddit"; Url = "https://www.reddit.com/user/{0}/" },
        @{ Name = "LinkedIn"; Url = "https://www.linkedin.com/in/{0}" },
        @{ Name = "Pinterest"; Url = "https://www.pinterest.com/{0}/" },
        @{ Name = "Snapchat"; Url = "https://www.snapchat.com/add/{0}" },
        @{ Name = "GitHub"; Url = "https://github.com/{0}" },
        @{ Name = "GitLab"; Url = "https://gitlab.com/{0}" },
        @{ Name = "Steam"; Url = "https://steamcommunity.com/id/{0}" },
        @{ Name = "Roblox"; Url = "https://www.roblox.com/user.aspx?username={0}" },
        @{ Name = "SoundCloud"; Url = "https://soundcloud.com/{0}" },
        @{ Name = "Spotify"; Url = "https://open.spotify.com/user/{0}" },
        @{ Name = "Vimeo"; Url = "https://vimeo.com/{0}" },
        @{ Name = "Medium"; Url = "https://medium.com/@{0}" },
        @{ Name = "DeviantArt"; Url = "https://www.deviantart.com/{0}" },
        @{ Name = "Threads"; Url = "https://www.threads.net/@{0}" },
        @{ Name = "OnlyFans"; Url = "https://onlyfans.com/{0}" },
        @{ Name = "Patreon"; Url = "https://www.patreon.com/{0}" },
        @{ Name = "Tumblr"; Url = "https://{0}.tumblr.com" }
    )
}

function Get-StatusFromCode {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Code
    )

    if ($Code -eq 200) { return "taken" }
    if ($Code -eq 404) { return "available" }
    if ($Code -in 400, 401, 403, 405, 429) { return "unknown" }
    if ($Code -ge 200 -and $Code -lt 300) { return "taken" }
    return "unknown"
}

function Test-UsernameOnPlatform {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Username,
        [Parameter(Mandatory = $true)]
        [hashtable]$Platform
    )

    $encoded = [System.Uri]::EscapeDataString($Username)
    $url = [string]::Format($Platform.Url, $encoded)

    try {
        $response = Invoke-WebRequest -Uri $url -Method Get -MaximumRedirection 5 -TimeoutSec 8 -UserAgent "UsernameChecker/1.0"
        $status = Get-StatusFromCode -Code ([int]$response.StatusCode)
        return [PSCustomObject]@{
            Platform = $Platform.Name
            Status = $status
            Url = $url
        }
    } catch {
        $httpResponse = $_.Exception.Response
        if ($null -ne $httpResponse) {
            $code = [int]$httpResponse.StatusCode
            $status = Get-StatusFromCode -Code $code
            return [PSCustomObject]@{
                Platform = $Platform.Name
                Status = $status
                Url = $url
            }
        }

        return [PSCustomObject]@{
            Platform = $Platform.Name
            Status = "error"
            Url = $url
        }
    }
}

function Get-UsernamesFromInput {
    param(
        [string]$InputUsernamesArg,
        [string]$InputFileArg
    )

    if (-not [string]::IsNullOrWhiteSpace($InputFileArg)) {
        if (-not (Test-Path -LiteralPath $InputFileArg -PathType Leaf)) {
            throw "Input file not found: $InputFileArg"
        }
        $fileContent = Get-Content -LiteralPath $InputFileArg -Raw
        return Parse-Usernames -Raw $fileContent
    }

    if (-not [string]::IsNullOrWhiteSpace($InputUsernamesArg)) {
        return Parse-Usernames -Raw $InputUsernamesArg
    }

    Write-Host "Enter username(s) separated by comma/space/newline."
    Write-Host "Or enter a file path (example: usernames.txt) to load usernames from file."
    $raw = Read-Host "> "

    if ([string]::IsNullOrWhiteSpace($raw)) {
        return @()
    }

    if (Test-Path -LiteralPath $raw -PathType Leaf) {
        $content = Get-Content -LiteralPath $raw -Raw
        return Parse-Usernames -Raw $content
    }

    return Parse-Usernames -Raw $raw
}

function Show-Results {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Username,
        [Parameter(Mandatory = $true)]
        [System.Collections.IEnumerable]$Results
    )

    Write-Host ""
    Write-Host "Username: $Username"
    Write-Host ("-" * 79)
    $Results | Sort-Object Platform | Format-Table -AutoSize Platform, Status, Url

    $taken = @($Results | Where-Object { $_.Status -eq "taken" }).Count
    $available = @($Results | Where-Object { $_.Status -eq "available" }).Count
    $unknown = @($Results | Where-Object { $_.Status -eq "unknown" }).Count
    $error = @($Results | Where-Object { $_.Status -eq "error" }).Count

    Write-Host "Summary: taken=$taken, available=$available, unknown=$unknown, error=$error"
}

function Write-ReportFile {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IEnumerable]$AllResults,
        [string]$OutputFileArg
    )

    $targetPath = $OutputFileArg
    if ([string]::IsNullOrWhiteSpace($targetPath)) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $targetPath = "username_report_$timestamp.txt"
    }

    $available = @($AllResults | Where-Object { $_.Status -eq "available" } | Sort-Object Username, Platform)
    $taken = @($AllResults | Where-Object { $_.Status -eq "taken" } | Sort-Object Username, Platform)
    $unknown = @($AllResults | Where-Object { $_.Status -eq "unknown" } | Sort-Object Username, Platform)
    $error = @($AllResults | Where-Object { $_.Status -eq "error" } | Sort-Object Username, Platform)

    $lines = New-Object System.Collections.Generic.List[string]
    $null = $lines.Add("Username Checker Report")
    $null = $lines.Add("Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")")
    $null = $lines.Add("")

    foreach ($section in @(
        @{ Name = "AVAILABLE"; Items = $available },
        @{ Name = "TAKEN"; Items = $taken },
        @{ Name = "UNKNOWN"; Items = $unknown },
        @{ Name = "ERROR"; Items = $error }
    )) {
        $null = $lines.Add("=== $($section.Name) ===")
        if ($section.Items.Count -eq 0) {
            $null = $lines.Add("(none)")
        } else {
            foreach ($item in $section.Items) {
                $null = $lines.Add(("{0} | {1} | {2}" -f $item.Username, $item.Platform, $item.Url))
            }
        }
        $null = $lines.Add("")
    }

    Set-Content -LiteralPath $targetPath -Value $lines -Encoding UTF8
    return (Resolve-Path -LiteralPath $targetPath).Path
}

Write-Host "Username Checker - social + streaming platforms"
$usernames = @(Get-UsernamesFromInput -InputUsernamesArg $InputUsernames -InputFileArg $InputFile)

if ($usernames.Count -eq 0) {
    Write-Host "No usernames provided."
    exit 0
}

$platforms = Get-Platforms
Write-Host ""
Write-Host ("Checking {0} username(s) on {1} platforms..." -f $usernames.Count, $platforms.Count)
$allResults = New-Object System.Collections.Generic.List[object]

foreach ($username in $usernames) {
    $results = foreach ($platform in $platforms) {
        Test-UsernameOnPlatform -Username $username -Platform $platform
    }
    Show-Results -Username $username -Results $results

    foreach ($row in $results) {
        $null = $allResults.Add([PSCustomObject]@{
            Username = $username
            Platform = $row.Platform
            Status = $row.Status
            Url = $row.Url
        })
    }
}

$reportPath = Write-ReportFile -AllResults $allResults -OutputFileArg $OutputFile
Write-Host ""
Write-Host "Report written to: $reportPath"
