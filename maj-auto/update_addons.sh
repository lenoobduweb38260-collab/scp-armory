#!/bin/bash
# ==========================================================================
#  SCP Armory — mise à jour automatique des addons au démarrage (Linux)
#
#  À lancer AVANT srcds (dans start.sh, systemd, Pterodactyl…) :
#      bash update_addons.sh [/chemin/vers/garrysmod]
#
#  - lit addons.txt (même dossier) : un dépôt git par ligne ;
#  - clone les dépôts absents (les dossiers sont créés automatiquement) ;
#  - remet les dépôts présents exactement sur la branche distante :
#    les modifications poussées par Claude sont appliquées ;
#  - installe/actualise l'addon de contrôle scp_autoupdate ;
#  - écrit data/scp_autoupdate/etat.txt (lu par l'addon de contrôle).
#
#  Prérequis : git installé. ATTENTION : toute modification faite à la main
#  dans un dossier synchronisé est écrasée (le dépôt GitHub fait foi).
# ==========================================================================
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFEST="$SCRIPT_DIR/addons.txt"

# --- localisation du dossier garrysmod/ -----------------------------------
GMOD_DIR="${1:-${GMOD_DIR:-}}"
if [ -z "$GMOD_DIR" ]; then
	d="$SCRIPT_DIR"
	while [ "$d" != "/" ]; do
		if [ "$(basename "$d")" = "garrysmod" ] && [ -d "$d/addons" ]; then GMOD_DIR="$d"; break; fi
		if [ -d "$d/garrysmod/addons" ]; then GMOD_DIR="$d/garrysmod"; break; fi
		d="$(dirname "$d")"
	done
fi
if [ -z "$GMOD_DIR" ] || [ ! -d "$GMOD_DIR/addons" ]; then
	echo "[MAJ] ERREUR : dossier garrysmod introuvable. Usage : $0 /chemin/vers/garrysmod" >&2
	exit 1
fi
if ! command -v git >/dev/null 2>&1; then
	echo "[MAJ] ERREUR : git n'est pas installé sur cette machine (apt install git)." >&2
	exit 1
fi
if [ ! -f "$MANIFEST" ]; then
	echo "[MAJ] ERREUR : $MANIFEST introuvable." >&2
	exit 1
fi

echo "[MAJ] Dossier serveur : $GMOD_DIR"
entries=""

# --- synchronisation des dépôts listés ------------------------------------
while read -r url branch folder _; do
	case "$url" in ""|\#*) continue ;; esac
	if [ -z "${branch:-}" ]; then
		echo "[MAJ] Ligne ignorée (branche manquante) : $url"
		continue
	fi
	folder="${folder:-$(basename "$url" .git)}"
	dest="$GMOD_DIR/addons/$folder"

	if [ ! -d "$dest/.git" ]; then
		echo "[MAJ] Installation de « $folder » (branche $branch)…"
		git clone --branch "$branch" --single-branch "$url" "$dest" || { echo "[MAJ] ÉCHEC du clonage de $url"; continue; }
	else
		echo "[MAJ] Mise à jour de « $folder »…"
		git -C "$dest" fetch origin "$branch" || { echo "[MAJ] ÉCHEC du fetch de $folder (réseau ?)"; continue; }
		git -C "$dest" checkout -q "$branch" 2>/dev/null || git -C "$dest" checkout -qb "$branch" "origin/$branch"
		git -C "$dest" reset --hard "origin/$branch" >/dev/null
	fi

	commit="$(git -C "$dest" rev-parse HEAD 2>/dev/null || echo "")"
	repo="$(printf '%s' "$url" | sed -E 's#^(git@github\.com:|https?://github\.com/)##; s#\.git$##; s#/*$##')"
	echo "[MAJ]   → $folder @ ${commit:0:7}"
	entries="$entries${entries:+,}\"$folder\":{\"repo\":\"$repo\",\"branch\":\"$branch\",\"commit\":\"$commit\"}"

	# Addon de contrôle livré dans le dépôt : installé/actualisé automatiquement
	if [ -d "$dest/maj-auto/scp_autoupdate" ]; then
		rm -rf "$GMOD_DIR/addons/scp_autoupdate"
		cp -r "$dest/maj-auto/scp_autoupdate" "$GMOD_DIR/addons/scp_autoupdate"
		echo "[MAJ]   → addon de contrôle scp_autoupdate actualisé"
	fi
done < "$MANIFEST"

# --- état local écrit pour l'addon de contrôle ----------------------------
mkdir -p "$GMOD_DIR/data/scp_autoupdate"
printf '{%s}' "$entries" > "$GMOD_DIR/data/scp_autoupdate/etat.txt"
echo "[MAJ] Terminé."
