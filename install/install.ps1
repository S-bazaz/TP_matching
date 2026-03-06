Param(
    [string]$EnvName = ".venv",
    [switch]$NoJupyter
)

# Single entry point for TP_matching on Windows: venv, deps, Jupyter kernel, Elasticsearch (local) + index.
# Use -NoJupyter to skip starting Jupyter Lab (e.g. in automation).
# Run from repo root: .\install\install.ps1

$RequirementsPath = Join-Path $PSScriptRoot "requirements.txt"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$EsDataPath = Join-Path $RepoRoot "es_data"
$EsVersion = "8.11.0"
$BaseUrl = "https://artifacts.elastic.co/downloads/elasticsearch"
$EsDir = Join-Path $RepoRoot "elasticsearch_local"
$EsHome = Join-Path $EsDir "elasticsearch-$EsVersion"

if (Get-Command pyenv -ErrorAction SilentlyContinue) {
    $desiredVersion = "3.11.9"
    $versionsRaw = (& pyenv versions --bare 2>$null) | Out-String
    $versions = $versionsRaw -split "`r?`n" | Where-Object { $_ -ne "" }

    if ($versions -contains $desiredVersion) {
        Write-Host "pyenv detected: setting local version to $desiredVersion"
        & pyenv local $desiredVersion
    } else {
        Write-Host "pyenv is detected but Python $desiredVersion is not installed for this project." -ForegroundColor Yellow
        Write-Host "Run the following commands once, then rerun this script:" -ForegroundColor Yellow
        Write-Host "  cd $PWD"
        Write-Host "  pyenv install $desiredVersion"
        Write-Host "  pyenv local $desiredVersion"
        exit 1
    }
}

function Get-PythonCommand {
    if (Get-Command py -ErrorAction SilentlyContinue) {
        return @{ Cmd = "py"; ArgsPrefix = @("-3") }
    }
    elseif (Get-Command python -ErrorAction SilentlyContinue) {
        return @{ Cmd = "python"; ArgsPrefix = @() }
    }
    else {
        throw "No Python executable found (neither 'py' nor 'python')."
    }
}

$pyInfo = Get-PythonCommand
$pyCmd = $pyInfo.Cmd
$pyPrefix = $pyInfo.ArgsPrefix

Write-Host "=== Creating virtual environment ($EnvName) ==="
& $pyCmd @($pyPrefix + @("-m", "venv", $EnvName))

Write-Host "=== Activating virtual environment ==="
$activatePath = Join-Path $EnvName "Scripts\Activate.ps1"
if (Test-Path $activatePath) {
    & $activatePath
} else {
    Write-Warning "Could not find activation script: $activatePath"
}

# Use the Python from the venv for all subsequent operations
$venvPython = Join-Path $EnvName "Scripts\python.exe"
if (-not (Test-Path $venvPython)) {
    Write-Warning "Could not find venv python at $venvPython, falling back to base python."
    $venvPython = $pyCmd
}

Write-Host "=== Upgrading pip ==="
& $venvPython -m pip install --upgrade pip

Write-Host "=== Installing dependencies from install/requirements.txt ==="
& $venvPython -m pip install -r $RequirementsPath

Write-Host "=== Registering Jupyter kernel 'tp_matching_kernel' ==="
& $venvPython -m ipykernel install --user --name tp_matching_kernel --display-name tp_matching_kernel

# --- Elasticsearch (local, no Docker): install, start, create index and bulk ---
if (-not (Test-Path $EsHome)) {
    Write-Host "=== Downloading Elasticsearch $EsVersion (large file, may take a few minutes) ==="
    $zipName = "elasticsearch-$EsVersion-windows-x86_64.zip"
    $zipPath = Join-Path $RepoRoot $zipName
    $downloadUrl = "$BaseUrl/$zipName"
    # Prefer BITS for large files (resumable, more reliable); fallback to Invoke-WebRequest with long timeout
    $bitsOk = $false
    if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
        try {
            Start-BitsTransfer -Source $downloadUrl -Destination $zipPath -Description "Elasticsearch $EsVersion" -DisplayName "Elasticsearch download"
            $bitsOk = $true
        } catch {}
    }
    if (-not $bitsOk) {
        try {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing -TimeoutSec 600
        } catch {
            if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
            Write-Error "Download failed. Check your network or download manually from: $downloadUrl"
            exit 1
        }
    }
    # Expect at least ~250 MB for a valid zip
    $minSize = 250 * 1024 * 1024
    $size = (Get-Item $zipPath -ErrorAction SilentlyContinue).Length
    if (-not $size -or $size -lt $minSize) {
        if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
        Write-Error "Downloaded file is too small or missing ($size bytes). Retry or download manually: $downloadUrl"
        exit 1
    }
    New-Item -ItemType Directory -Path $EsDir -Force | Out-Null
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $EsDir)
    } catch {
        if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
        Write-Error "Zip is corrupted or incomplete (download was interrupted?). Delete '$EsDir' and retry, or download manually: $downloadUrl"
        exit 1
    }
    Remove-Item $zipPath -Force
}
if (-not (Test-Path $EsHome)) {
    Write-Error "Elasticsearch directory not found: $EsHome"
    exit 1
}
$configPath = Join-Path $EsHome "config\elasticsearch.yml"
$configContent = Get-Content $configPath -Raw -ErrorAction SilentlyContinue
if ($configContent -notmatch "xpack\.security\.enabled") {
    Add-Content -Path $configPath -Value "`nxpack.security.enabled: false`ndiscovery.type: single-node"
}
Write-Host "=== Starting Elasticsearch in background ==="
$esBin = Join-Path $EsHome "bin\elasticsearch.bat"
Start-Process -FilePath $esBin -WorkingDirectory $EsHome -WindowStyle Hidden
Write-Host "Waiting for Elasticsearch on http://localhost:9200 ..."
$maxAttempts = 30
$ready = $false
for ($i = 1; $i -le $maxAttempts; $i++) {
    try {
        $r = Invoke-WebRequest -Uri "http://localhost:9200" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
        if ($r.StatusCode -eq 200) { $ready = $true; break }
    } catch {}
    Start-Sleep -Seconds 2
}
if (-not $ready) { Write-Error "Elasticsearch did not become ready in time."; exit 1 }
Write-Host "=== Creating index 'products' and bulk indexing 4 products ==="
$mappingPath = Join-Path $EsDataPath "mapping_products.json"
$bulkPath = Join-Path $EsDataPath "products_bulk.ndjson"
Invoke-RestMethod -Uri "http://localhost:9200/products" -Method Put -ContentType "application/json" -InFile $mappingPath
$bulkBody = [System.IO.File]::ReadAllText($bulkPath, [System.Text.Encoding]::UTF8)
Invoke-RestMethod -Uri "http://localhost:9200/products/_bulk" -Method Post -ContentType "application/x-ndjson" -Body $bulkBody | Out-Null
Write-Host "Elasticsearch is running at http://localhost:9200 with index 'products' (4 products)."
Write-Host ""

Write-Host "Setup finished."
Write-Host "To reuse the environment in a new terminal:"
Write-Host "  .\$EnvName\Scripts\Activate.ps1"
Write-Host ""

if (-not $NoJupyter) {
    Write-Host "Starting Jupyter Lab with kernel 'tp_matching_kernel'..."
    & $venvPython -m jupyter lab
} else {
    Write-Host "Skipping Jupyter Lab (-NoJupyter). Run 'python -m jupyter lab' when needed."
}
