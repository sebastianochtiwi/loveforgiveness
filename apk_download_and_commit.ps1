$owner = 'sebastianochtiwi'
$repo = 'loveforgiveness'
# Optional: set RUN_ID env var to poll a specific run. If not provided, script will try to find a release with an APK asset.
$runId = $env:RUN_ID
$runUrl = if ($runId) { "https://api.github.com/repos/$owner/$repo/actions/runs/$runId" } else { $null }
$releasesListUrl = "https://api.github.com/repos/$owner/$repo/releases"
$token = $env:GITHUB_TOKEN
if (-not $token) { $token = $env:CI_DOWNLOAD_TOKEN }
$headers = @{ 'User-Agent' = 'ci-monitor' }
if ($token) { $headers['Authorization'] = "token $token" }

function Get-JsonFromUrl($url) {
    try {
        return Invoke-RestMethod -Uri $url -Headers $headers -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Host "Failed to GET $url : $_"
        return $null
    }
}

Write-Host "Monitoring run $runId ..."
while ($true) {
    $run = Get-JsonFromUrl $runUrl
    if ($null -eq $run) {
        Write-Host "Could not fetch run; retrying in 15s..."
        Start-Sleep -Seconds 15
        continue
    }
    $status = $run.status
    $conclusion = $run.conclusion
    Write-Host "Run status: $status, conclusion: $conclusion"
    if ($status -eq 'completed') { break }
    Start-Sleep -Seconds 15
}

if ($conclusion -ne 'success') {
    Write-Host "Workflow run completed with conclusion: $conclusion. Exiting."
    exit 1
}

Write-Host "Looking for an existing release with an APK asset..."
# First try to find a release that contains an APK asset
$releases = Get-JsonFromUrl $releasesListUrl
if ($null -ne $releases) {
    $release = $releases | Where-Object { $_.assets -ne $null -and ($_.assets | Where-Object { $_.name -match '\.apk$' -or $_.name -match 'debug' }) } | Select-Object -First 1
} else {
    $release = $null
}

# If no release found, optionally poll a specific run (if RUN_ID was supplied)
if ($null -eq $release) {
    if ($runUrl) {
        Write-Host "No release found; monitoring run $runId ..."
        while ($true) {
            $run = Get-JsonFromUrl $runUrl
            if ($null -eq $run) {
                Write-Host "Could not fetch run; retrying in 15s..."
                Start-Sleep -Seconds 15
                continue
            }
            $status = $run.status
            $conclusion = $run.conclusion
            Write-Host "Run status: $status, conclusion: $conclusion"
            if ($status -eq 'completed') { break }
            Start-Sleep -Seconds 15
        }

        if ($conclusion -ne 'success') {
            Write-Host "Workflow run completed with conclusion: $conclusion. Exiting."
            exit 1
        }

        # Try release by tag matching the run id
        $tag = "debug-apk-$runId"
        $releaseUrlByTag = "https://api.github.com/repos/$owner/$repo/releases/tags/$tag"
        $release = Get-JsonFromUrl $releaseUrlByTag
        if ($null -eq $release) {
            Write-Host "Release with tag $tag not found after run completion. Falling back to listing releases..."
            $releases = Get-JsonFromUrl $releasesListUrl
            if ($null -eq $releases) { Write-Host "Failed to list releases"; exit 1 }
            $release = $releases | Where-Object { $_.assets -ne $null -and ($_.assets | Where-Object { $_.name -match '\.apk$' -or $_.name -match 'debug' } ) } | Select-Object -First 1
        }
    } else {
        Write-Host "No release found and no RUN_ID provided. Exiting."
        exit 1
    }
}

# If no release was found but we have a RUN_ID, try to download artifacts produced by the run
if ($null -eq $release -and $runId) {
    Write-Host "No release found; attempting to fetch artifacts for run $runId"
    $artifactsUrl = "https://api.github.com/repos/$owner/$repo/actions/runs/$runId/artifacts"
    $artifactsResp = Get-JsonFromUrl $artifactsUrl
    if ($null -ne $artifactsResp -and $artifactsResp.artifacts.Count -gt 0) {
        $artifact = $artifactsResp.artifacts | Where-Object { $_.name -match 'app-debug-apk' } | Select-Object -First 1
        if ($null -eq $artifact) { $artifact = $artifactsResp.artifacts[0] }
        $archiveUrl = $artifact.archive_download_url
        $zipPath = Join-Path -Path (Join-Path -Path $env:TEMP -ChildPath "apk_artifacts") -ChildPath ("$($artifact.id).zip")
        if (-not (Test-Path (Split-Path $zipPath -Parent))) { New-Item -ItemType Directory -Path (Split-Path $zipPath -Parent) | Out-Null }
        Write-Host "Downloading artifact archive $archiveUrl to $zipPath"
        try {
            Invoke-WebRequest -Uri $archiveUrl -OutFile $zipPath -UseBasicParsing -Headers $headers -ErrorAction Stop
        } catch {
            Write-Host "Failed to download artifact archive: $_"; exit 1
        }
        $tempExtract = Join-Path -Path (Join-Path -Path $env:TEMP -ChildPath "apk_extract_$($artifact.id)") -ChildPath "content"
        if (Test-Path $tempExtract) { Remove-Item -Recurse -Force $tempExtract }
        New-Item -ItemType Directory -Path $tempExtract | Out-Null
        Write-Host "Extracting $zipPath to $tempExtract"
        try {
            Expand-Archive -Path $zipPath -DestinationPath $tempExtract -Force
        } catch {
            Write-Host "Failed to extract artifact archive: $_"; exit 1
        }
        $apkFound = Get-ChildItem -Path $tempExtract -Recurse -Include *.apk | Select-Object -First 1
        if ($null -ne $apkFound) {
            $downloadUrl = $null
            $filename = $apkFound.Name
            $destDir = Join-Path -Path (Get-Location) -ChildPath 'apkdownload'
            if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir | Out-Null }
            $destPath = Join-Path $destDir $filename
            Copy-Item -Path $apkFound.FullName -Destination $destPath -Force
            Write-Host "Copied APK to $destPath"
            # Commit and push
            git add $destPath
            git commit -m "chore(apk): add debug APK from CI run $runId" -q
            if ($LASTEXITCODE -ne 0) {
                Write-Host "git commit failed or nothing to commit. Exit code $LASTEXITCODE"
            } else {
                git push origin master
                if ($LASTEXITCODE -ne 0) { Write-Host "git push failed with exit code $LASTEXITCODE"; exit 1 }
            }
            Write-Host "APK downloaded and pushed to repository at $destPath"
            exit 0
        } else {
            Write-Host "No APK found inside artifact archive."
        }
    } else {
        Write-Host "No artifacts found for run $runId"
    }
}

$assets = $release.assets
$asset = $assets | Where-Object { $_.name -match '\.apk$' } | Select-Object -First 1
if ($null -eq $asset) {
    $asset = $assets | Select-Object -First 1
}

if ($null -eq $asset) {
    Write-Host "No assets in release; exiting."
    exit 1
}

$downloadUrl = $asset.browser_download_url
$filename = $asset.name

Write-Host "Found asset: $filename; download url: $downloadUrl"

$destDir = Join-Path -Path (Get-Location) -ChildPath 'apkdownload'
if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir | Out-Null }

$destPath = Join-Path $destDir $filename

Write-Host "Downloading to $destPath"
Invoke-WebRequest -Uri $downloadUrl -OutFile $destPath -UseBasicParsing -Headers $headers -ErrorAction Stop

if (-not (Test-Path $destPath)) { Write-Host "Download failed"; exit 1 }

# Commit and push
git add $destPath
git commit -m "chore(apk): add debug APK from CI run $runId" -q
if ($LASTEXITCODE -ne 0) {
    Write-Host "git commit failed or nothing to commit. Exit code $LASTEXITCODE"
} else {
    git push origin master
    if ($LASTEXITCODE -ne 0) { Write-Host "git push failed with exit code $LASTEXITCODE"; exit 1 }
}

Write-Host "APK downloaded and pushed to repository at $destPath"
exit 0
