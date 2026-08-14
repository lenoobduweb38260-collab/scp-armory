# Mise à jour automatique des addons (maj-auto)

Ce dossier fait en sorte qu'**au démarrage ou au redémarrage du serveur**, tous les
addons listés soient installés ou mis à jour automatiquement depuis GitHub :

- les dossiers manquants dans `garrysmod/addons/` sont **créés automatiquement** (clonage) ;
- les dossiers déjà présents sont **remis exactement sur la branche GitHub** — dès que
  Claude pousse une modification, elle est appliquée au redémarrage suivant ;
- un petit addon de contrôle (`scp_autoupdate`) surveille GitHub **pendant que le serveur
  tourne** et prévient (console + superadmins) dès qu'une mise à jour est disponible.

## Pourquoi un script et pas un simple addon ?

Un addon Lua de Garry's Mod est **sandboxé par sécurité** : il ne peut écrire que dans
`garrysmod/data/`, avec quelques extensions autorisées (`.txt`, `.json`…) — jamais de
`.lua`, jamais dans `addons/`, et il ne peut pas exécuter de commande système. C'est
voulu par le jeu : sans cela, n'importe quel addon malveillant pourrait installer du code
sur votre machine. (Des modules binaires « IO » existent pour contourner cette limite,
mais ils ouvrent exactement la faille que la sandbox empêche — à éviter sur un serveur.)

La création/mise à jour des dossiers d'addons doit donc se faire **hors du jeu**, par un
script lancé au démarrage du serveur (il a les droits complets sur le disque). L'addon
`scp_autoupdate`, lui, reste dans la sandbox : il **lit** et **prévient**, c'est tout.

## Installation (Linux)

1. Copiez le dossier `maj-auto/` sur la machine du serveur (n'importe où — le plus simple
   est de le laisser dans `garrysmod/addons/scp-armory/maj-auto/` après un premier clonage).
2. Rendez le script exécutable : `chmod +x update_addons.sh`
3. Lancez-le **avant** srcds à chaque démarrage. Exemples :

   **start.sh classique (avec relance automatique en boucle — recommandé)**
   ```bash
   #!/bin/bash
   while true; do
       bash /chemin/vers/maj-auto/update_addons.sh /chemin/vers/garrysmod
       ./srcds_run -game garrysmod +gamemode darkrp +map rp_site19 ...
       echo "Serveur arrêté — relance dans 5 s (Ctrl+C pour annuler)"
       sleep 5
   done
   ```
   Avec cette boucle, un simple `quit` en console suffit : le serveur se relance à jour.

   **systemd**
   ```ini
   [Service]
   ExecStartPre=/bin/bash /chemin/vers/maj-auto/update_addons.sh /chemin/vers/garrysmod
   ExecStart=/chemin/vers/srcds_run -game garrysmod ...
   Restart=always
   ```

   **Pterodactyl / panels avec commande de démarrage modifiable**
   ```
   bash ./garrysmod/addons/scp-armory/maj-auto/update_addons.sh ./garrysmod && ./srcds_run ...
   ```

## Installation (Windows)

Dans votre `start.bat`, avant srcds :
```bat
call C:\gmodserver\maj-auto\update_addons.bat C:\gmodserver\garrysmod
srcds.exe -console -game garrysmod +map rp_site19 ...
```
(`update_addons.bat` appelle `update_addons.ps1` via PowerShell, présent sur tout Windows.)

## Le premier lancement

Au tout premier passage, le script **clone** chaque dépôt listé : les dossiers d'addons
sont créés tout seuls, rien à copier à la main. Il installe aussi automatiquement l'addon
de contrôle `scp_autoupdate` dans `addons/`. Ensuite, chaque démarrage fait un simple
`fetch` + `reset` (rapide).

## addons.txt — ajouter d'autres addons

Une ligne par dépôt : `URL  branche  dossier`. Exemple :
```
https://github.com/lenoobduweb38260-collab/scp-armory.git claude/ready-or-not-loadout-gbii3v scp-armory
```
Tout dépôt GitHub que Claude gère pour vous peut être ajouté ici : il sera installé et
suivi de la même façon.

⚠️ **Le dépôt fait foi** : toute modification faite à la main directement dans un dossier
synchronisé est écrasée au redémarrage suivant. Pour modifier un addon, passez par le
dépôt (demandez à Claude), pas par FTP.

## L'addon de contrôle scp_autoupdate

Installé/actualisé automatiquement par le script. En jeu et en console :

- au démarrage : liste les addons synchronisés et leur commit ;
- vérifie GitHub 10 s après le lancement puis **toutes les heures** ;
- dès qu'une mise à jour est détectée : message console + alerte aux superadmins
  (à la connexion aussi), avec le titre de la modification de Claude ;
- `!maj` en chat (superadmin) ou `scp_autoupdate_check` en console : vérification immédiate ;
- `scp_autoupdate_autoquit 1` (optionnel, défaut 0) : si une mise à jour est détectée et
  que le serveur est **vide**, il se ferme tout seul — avec le start.sh en boucle
  ci-dessus, il se relance donc à jour automatiquement, sans aucune intervention.

Sécurité : lecture seule, uniquement des requêtes GET vers `api.github.com`, réponses
bornées, aucune écriture de fichier, commande réservée aux superadmins et limitée en cadence.

## Prérequis et limites

- **git** doit être installé sur la machine (`apt install git` / https://git-scm.com).
- Il faut pouvoir modifier la **commande de démarrage** du serveur (SSH, systemd, panel
  type Pterodactyl…). Sur un hébergeur mutualisé qui ne le permet pas : installez quand
  même `scp_autoupdate` (copie du dossier dans `addons/`) — il vous dira quand mettre à
  jour, et la mise à jour se fera par le gestionnaire de fichiers/FTP de l'hébergeur.
