# Mise à jour automatique des addons (maj-auto)

> ⚠️ **À lire en premier — qui fait quoi :**
> - c'est le **script** (`update_addons.sh` / `.bat`) qui crée et met à jour les addons,
>   et il ne le fait **que quand il est exécuté** : il doit être branché sur la commande
>   de démarrage du serveur (exemples plus bas). Le lancer une fois à la main permet de
>   tester immédiatement ;
> - l'addon `scp_autoupdate`, lui, ne peut **rien créer** (sandbox du jeu) : il surveille
>   et prévient, c'est tout ;
> - placez le dossier `maj-auto/` **en dehors de `garrysmod/addons/`** (par exemple à la
>   racine du serveur, à côté de `srcds_run`). S'il vit dans le dossier d'un addon
>   synchronisé et que vous supprimez cet addon pour tester, le script disparaît avec !

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

## Test rapide (à faire en premier)

Avant de brancher quoi que ce soit, lancez le script **une fois à la main** et lisez sa
sortie — c'est elle qui dit ce qui se passe :

```bash
bash update_addons.sh /chemin/vers/garrysmod        # Linux
update_addons.bat C:\chemin\vers\garrysmod          # Windows (double-clic possible)
```

Sortie attendue :
```
[MAJ] Dossier serveur : /…/garrysmod
[MAJ] Installation de « scp-armory » (branche claude/ready-or-not-loadout-gbii3v)…
[MAJ]   → scp-armory @ 1a2b3c4
[MAJ]   → addon de contrôle scp_autoupdate actualisé
[MAJ] Terminé : 1 addon(s) synchronisé(s), 0 échec(s).
```

Si l'addon n'apparaît pas dans `addons/`, la réponse est dans cette sortie :
`ÉCHEC du clonage` (réseau, branche, dépôt privé → jeton), `git n'est pas installé`,
`dossier garrysmod introuvable` (passez le chemin en argument), ou le script n'a tout
simplement pas été lancé.

## Installation (Linux)

1. Copiez le dossier `maj-auto/` sur la machine du serveur, **hors de `addons/`**
   (recommandé : à la racine du serveur, à côté de `srcds_run`).
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

## Dépôt privé (jeton facultatif)

Le dépôt de l'armurerie est **public** : rien à configurer. Si un jour vous synchronisez
un dépôt **privé**, créez un jeton GitHub à accès minimal (GitHub → Settings →
Developer settings → *Fine-grained tokens* : accès au seul dépôt concerné, permission
**Contents : Read-only**), puis :

- soit collez-le dans un fichier `github_token.txt` à côté du script ;
- soit exportez la variable d'environnement `GITHUB_TOKEN` avant de le lancer.

Le script l'utilise pour cloner/mettre à jour (sans le conserver dans la config git) et
le transmet à `scp_autoupdate` pour que la surveillance fonctionne aussi. Ne committez
jamais ce fichier (il est ignoré par le dépôt).

## Hébergeur externe sans accès aux commandes : le chargeur cloud

Si votre hébergeur ne permet **ni SSH ni de modifier la commande de démarrage** (mutualisé
classique), le script ci-dessus est inutilisable — utilisez à la place l'addon
**`scp_cloudloader`** fourni dans ce dossier :

1. Déposez **une seule fois** le dossier `scp_cloudloader/` dans `garrysmod/addons/`
   via le gestionnaire de fichiers ou le FTP du panel.
2. **N'installez pas** l'addon `scp-armory` à la main (le chargeur s'en occupe ; s'il
   détecte l'addon sur le disque, il se désactive tout seul et l'addon disque prime).
3. Redémarrez le serveur depuis le panel : c'est tout. **À chaque démarrage**, le
   chargeur télécharge la dernière version du dépôt GitHub et l'exécute — chaque
   modification poussée par Claude est donc appliquée au restart suivant, sans FTP.

Comment ça marche, dans le respect de la sandbox du jeu : le chargeur ne crée aucun
fichier dans `addons/` (interdit). Il télécharge les fichiers lua dans
`data/scp_cloudloader/` (autorisé), les exécute en mémoire, envoie aux joueurs les
fichiers client par le réseau (c'est déjà ainsi qu'un serveur GMod livre son lua aux
clients), et les images de fond du menu arrivent dans `data/scp_armory/`.

À savoir :

- **Panne de GitHub** = démarrage sur la dernière copie en cache : le serveur n'est
  jamais bloqué. Premier démarrage : il faut juste que le serveur ait accès à Internet.
- **Confiance** : le serveur exécute le code du dépôt épinglé dans
  `lua/scp_cloudloader/sv_loader.lua` (constantes `REPO` / `BRANCH`, modifiables).
  C'est la même confiance que déposer l'addon par FTP — même code, même auteur — le
  transport se fait en HTTPS vers GitHub uniquement, tailles et contenus bornés.
- En mode cloud, `scp_autoupdate` est inutile (le serveur repart toujours à jour) :
  ne l'installez pas en même temps.
- Le chargeur sait exécuter des addons composés de `lua/autorun/` + `lua/entities/`
  (le format de l'armurerie). Pour un addon d'une autre structure, demandez à Claude.

### Vérifier que tout fonctionne (et dépanner)

Au démarrage, la console serveur doit afficher, dans cet ordre :

```
[ARMURERIE CLOUD] Chargeur cloud v2 — démarrage dans 5 s.
[ARMURERIE CLOUD] GitHub : armurerie EXÉCUTÉE (15 fichiers, commit abc1234). Serveur prêt.
```

puis, à chaque connexion d'un joueur :

```
[ARMURERIE CLOUD] Manifeste envoyé à Pseudo (STEAM_0:…).
[ARMURERIE CLOUD] Envoi de N fichier(s) à Pseudo…      (première connexion seulement)
[ARMURERIE CLOUD] Pseudo : armurerie chargée chez le joueur.
```

C'est cette **dernière ligne** qui compte pour le « en jeu » : le menu vit chez le
joueur. Tant qu'elle n'apparaît pas pour vous, `!armurerie` ne montrera rien.

Outils de diagnostic :

- `scp_cloud_status` dans la console **serveur** : état, commit, erreurs d'exécution
  détaillées, et l'état de chaque joueur (manifeste envoyé, fichiers envoyés, chargé…) ;
- `scp_cloud_status` dans **votre console** (client, en jeu) : état côté joueur ;
- les superadmins reçoivent l'état du cloud dans le chat ~15 s après leur connexion ;
- `ERREUR : <fichier> — <message>` dans la console = envoyez cette ligne à Claude.

## Prérequis et limites

- **Script `update_addons`** : git installé sur la machine et possibilité de modifier la
  **commande de démarrage** (SSH, systemd, panel type Pterodactyl/WISP — beaucoup de
  panels le permettent, cherchez « Startup command »).
- **Chargeur cloud** : aucun prérequis côté hébergeur, juste l'accès Internet du serveur.
- Dans les deux cas, le dépôt GitHub fait foi : les modifications locales sont écrasées.
