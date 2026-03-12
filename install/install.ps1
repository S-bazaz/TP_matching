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

Write-Host "Setup finished (venv + dépendances + kernel Jupyter)."
Write-Host "To reuse the environment in a new terminal:"
Write-Host "  .\$EnvName\Scripts\Activate.ps1"
Write-Host ""

if (-not $NoJupyter) {
    Write-Host "Starting Jupyter Lab with kernel 'tp_matching_kernel'..."
    & $venvPython -m jupyter lab
} else {
    Write-Host "Skipping Jupyter Lab (-NoJupyter). Run 'python -m jupyter lab' when needed."
}
