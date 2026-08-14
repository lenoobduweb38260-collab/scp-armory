# ==========================================================================
#  SCP Armory — mise à jour automatique des addons au démarrage (Windows)
#  Lancé par update_addons.bat avant le démarrage du serveur.
#  Même logique que update_addons.sh : voir LISEZMOI.md.
# ==========================================================================
param([string]$GmodDir = "")

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Manifest = Join-Path $ScriptDir "addons.txt"

# --- localisation du dossier garrysmod/ -----------------------------------
if (-not $GmodDir) {
    $d = $ScriptDir
    while ($d -and ($d -ne [IO.Path]::GetPathRoot($d))) {
        if ((Split-Path -Leaf $d) -eq "garrysmod" -and (Test-Path (Join-Path $d "addons"))) { $GmodDir = $d; break }
        if (Test-Path (Join-Path $d "garrysmod\addons")) { $GmodDir = Join-Path $d "garrysmod"; break }
        $d = Split-Path -Parent $d
    }
}
if (-not $GmodDir -or -not (Test-Path (Join-Path $GmodDir "addons"))) {
    Write-Host "[MAJ] ERREUR : dossier garrysmod introuvable. Usage : update_addons.bat C:\chemin\vers\garrysmod"
    exit 1
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "[MAJ] ERREUR : git n'est pas installé (https://git-scm.com)."
    exit 1
}
if (-not (Test-Path $Manifest)) {
    Write-Host "[MAJ] ERREUR : $Manifest introuvable."
    exit 1
}

Write-Host "[MAJ] Dossier serveur : $GmodDir"
$state = @{}

# --- synchronisation des dépôts listés ------------------------------------
Get-Content $Manifest | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith("#")) { return }
    $parts = $line -split "\s+"
    $url = $parts[0]
    $branch = if ($parts.Count -ge 2) { $parts[1] } else { "" }
    $folder = if ($parts.Count -ge 3) { $parts[2] } else { [IO.Path]::GetFileNameWithoutExtension($url) }
    if (-not $branch) { Write-Host "[MAJ] Ligne ignorée (branche manquante) : $url"; return }
    $dest = Join-Path $GmodDir "addons\$folder"

    if (-not (Test-Path (Join-Path $dest ".git"))) {
        Write-Host "[MAJ] Installation de « $folder » (branche $branch)…"
        git clone --branch $branch --single-branch $url $dest
        if ($LASTEXITCODE -ne 0) { Write-Host "[MAJ] ÉCHEC du clonage de $url"; return }
    } else {
        Write-Host "[MAJ] Mise à jour de « $folder »…"
        git -C $dest fetch origin $branch
        if ($LASTEXITCODE -ne 0) { Write-Host "[MAJ] ÉCHEC du fetch de $folder (réseau ?)"; return }
        git -C $dest checkout -q $branch 2>$null
        if ($LASTEXITCODE -ne 0) { git -C $dest checkout -qb $branch "origin/$branch" }
        git -C $dest reset --hard "origin/$branch" | Out-Null
    }

    $commit = (git -C $dest rev-parse HEAD).Trim()
    $repo = $url -replace '^(git@github\.com:|https?://github\.com/)', '' -replace '\.git$', ''
    Write-Host "[MAJ]   → $folder @ $($commit.Substring(0, [Math]::Min(7, $commit.Length)))"
    $state[$folder] = @{ repo = $repo; branch = $branch; commit = $commit }

    # Addon de contrôle livré dans le dépôt : installé/actualisé automatiquement
    $checker = Join-Path $dest "maj-auto\scp_autoupdate"
    if (Test-Path $checker) {
        $target = Join-Path $GmodDir "addons\scp_autoupdate"
        if (Test-Path $target) { Remove-Item -Recurse -Force $target }
        Copy-Item -Recurse $checker $target
        Write-Host "[MAJ]   → addon de contrôle scp_autoupdate actualisé"
    }
}

# --- état local écrit pour l'addon de contrôle ----------------------------
$dataDir = Join-Path $GmodDir "data\scp_autoupdate"
New-Item -ItemType Directory -Force -Path $dataDir | Out-Null
($state | ConvertTo-Json -Compress -Depth 4) | Set-Content -Encoding ASCII (Join-Path $dataDir "etat.txt")
Write-Host "[MAJ] Terminé."
