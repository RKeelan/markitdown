param (
    [string]$UpstreamRemote = "upstream",
    [string]$Branch = "no-magika",
    [string]$TagPrefix = "pyodide-"
)

# Ensure working tree is clean
git diff-index --quiet HEAD
if ($LASTEXITCODE -ne 0) {
    Write-Error "Working tree is dirty"
    exit 1
}


# Fetch and rebase
git fetch $UpstreamRemote
git checkout $Branch
git rebase "$UpstreamRemote/main"

# Extract version from pyproject.toml
$VersionLine = Get-Content packages\markitdown\src\markitdown\__about__.py | Where-Object { $_ -match '^__version__ = "(.*?)"' }
if (-not ($VersionLine -match '"([^"]+)"')) {
    Write-Error "Could not extract version from __about__.py"
    exit 1
}
$Version = $matches[1]
$Tag = "$TagPrefix$Version"

# Build the wheel
Push-Location packages/markitdown
Remove-Item -Recurse -Force dist -ErrorAction Ignore
python -m build --wheel
Pop-Location

$Wheel = Get-Item packages/markitdown/dist/*.whl
if (-not $Wheel) {
    throw "No wheel found"
}

# Commit and tag
git add -u
git commit -m "Release $Version (Pyodide fork)"
git tag -f $Tag
git push origin $Branch --follow-tags
git push origin $Tag --force

# Create or update GitHub release
# If it already exists, this is a no-op
gh release create $Tag `
  $Wheel.FullName `
  --title "MarkItDown for Pyodide v$Version" `
  --notes "Built for Pyodide from branch $Branch" `
  --repo $(git remote get-url origin)
