# SCP Armory

Addon **Garry's Mod** : une armurerie de la Fondation SCP qui recrée les écrans **LOADOUT** et
**MODIFY WEAPON** de **Ready or Not** — plein écran sur fond noir, colonne d'équipement à gauche,
opérateur (ou arme) en grand plan, accessoires **ARC9**, poids qui pénalise la mobilité, niveaux
d'accréditation, restrictions par job et objets anormaux.

![Écran LOADOUT](docs/apercu-loadout.png)
![Écran MODIFIER L'ARME](docs/apercu-modify.png)

## Fonctionnalités

- **Écran LOADOUT façon Ready or Not** (Derma, plein écran) :
  - 8 emplacements : arme principale, arme secondaire, tactique ×2, grenade, gilet balistique, casque, objet anormal ;
  - colonne d'équipement à gauche avec silhouettes d'armes de profil, votre playermodel animé en grand plan ;
  - descriptions et statistiques (dégâts, cadence, contrôle, précision) au survol ;
  - résumé du chargement en direct : **poids**, **mobilité**, **armure**, **résistance anormale**, avec classe
    `LÉGER / INTERMÉDIAIRE / LOURD` ; navigation ÉCHAP comme dans le jeu.
- **Écran MODIFIER L'ARME façon Ready or Not** (armes principale et secondaire) :
  - onglets PRINCIPALE / SECONDAIRE, arme en grand plan, panneau récapitulatif des accessoires à droite ;
  - **intégration ARC9** : les emplacements (optique, bouche, sous-canon…) et les accessoires compatibles sont
    récupérés automatiquement depuis le registre ARC9 de l'arme — aucune configuration à écrire ;
  - les accessoires se choisissent **uniquement** ici : le menu de personnalisation ARC9 (touche C) est désactivé
    (`BlockARC9Customize`) ; le serveur valide et pose les accessoires au déploiement.
- **Fonctionnel en jeu** au clic sur **DÉPLOYER** :
  - distribution des armes et munitions (validation côté serveur) ;
  - armure appliquée selon gilet + casque ;
  - vitesse de déplacement recalculée selon le poids total ;
  - effets des objets anormaux : **SCP-500** (soin complet), **SCP-714** (-25 % de dégâts subis, mobilité réduite),
    **Ancre de Réalité Scranton** (-15 % de dégâts subis, 6,5 kg) ;
  - réapplication optionnelle du chargement au respawn.
- **Entité armoire d'armurerie** (`scp_armory_locker`) : une armoire à placer sur la map (menu spawn,
  catégorie *SCP Armory*, modèle configurable via `LockerModel`), avec étiquette 3D2D « ARMURERIE —
  Appuyez sur [E] ». Appuyer sur **E** ouvre le menu. Avec `RequireEntity = true`, s'équiper n'est
  possible **qu'à proximité d'une armoire**, comme dans Ready or Not.
- **Restrictions par job/team** : un objet portant un champ `jobs = { ... }` n'apparaît **que** pour ces
  métiers — les autres joueurs ne le voient même pas dans le menu (validation serveur incluse).
- **Niveaux d'accréditation (1-4)** : les objets verrouillés sont grisés dans le menu et refusés par le
  serveur. Attribuables par groupe (`ClearanceGroups`) ou par job (`ClearanceJobs`).
- **Sauvegarde locale** du dernier loadout (`data/scp_armory/loadout.txt`).

## Installation

Clonez (ou copiez) le dépôt dans le dossier `addons` de Garry's Mod :

```
garrysmod/addons/scp-armory/
├── addon.json
└── lua/
    ├── autorun/scp_armory_init.lua
    └── scp_armory/...
```

## Utilisation

- **Armoire d'armurerie** : spawnez l'entité *Armoire d'armurerie SCP* (catégorie *SCP Armory*) et
  appuyez sur **E** dessus.
- Commande chat : `!armurerie`, `!loadout` ou `!armory`
- Commande console : `scp_armory` (bindable : `bind F7 scp_armory`)
- Choisissez vos objets par emplacement puis cliquez **DÉPLOYER**.

## Configuration

Dans `lua/scp_armory/sh_config.lua` :

| Option | Rôle |
| --- | --- |
| `DefaultClearance` | Accréditation par défaut des joueurs (3 = tout sauf les objets anormaux) |
| `ClearanceGroups` | Accréditation par groupe (`admin`/`superadmin` = 4 par défaut) |
| `ClearanceJobs` | Accréditation par job/team, prioritaire — ex. `["Chef des FGM"] = 4` |
| `RequireEntity` | Si `true`, menu et déploiement uniquement près d'une armoire `scp_armory_locker` |
| `UseDistance` | Portée (en unités) autour de l'armoire quand `RequireEntity = true` |
| `LockerModel` | Modèle 3D de l'armoire d'armurerie |
| `BlockARC9Customize` | Si `true`, désactive le menu de personnalisation ARC9 (touche C) |
| `BaseWalkSpeed` / `BaseRunSpeed` | Vitesses de référence avant malus de poids |
| `MaxArmor` | Plafond d'armure |
| `KeepWeapons` | Outils sandbox redonnés après déploiement (physgun, toolgun…) |

ConVar serveur : `scp_armory_autoapply 1/0` — autorise la réapplication du loadout au respawn.

## Ajouter des armes (M9K, CW 2.0, ArcCW…)

Ajoutez simplement une entrée dans `lua/scp_armory/sh_items.lua`, par exemple :

```lua
{
    id = "m9k_mp5", name = "H&K MP5A5",
    desc = "PM de dotation des FGM.",
    weight = 3.1, clearance = 1,
    class = "m9k_mp5", model = "models/weapons/w_hk_mp5.mdl",
    stats = { degats = 55, cadence = 82, controle = 75, precision = 62 },
},
```

L'addon utilise par défaut les armes HL2 de base afin de fonctionner sans aucune dépendance.

## Accessoires ARC9

Si une arme ajoutée dans `sh_items.lua` est une arme **ARC9** (champ `class` pointant vers une
classe ARC9), l'écran *MODIFIER L'ARME* liste automatiquement ses emplacements de premier niveau
(`SWEP.Attachments`) et les accessoires compatibles du registre `ARC9.Attachments`. Au déploiement,
le serveur valide chaque accessoire (emplacement + compatibilité) puis le pose sur l'arme donnée
(`SWEP:Attach`, avec repli défensif).

- Les joueurs ne passent **jamais** par le menu ARC9 : la touche C est bloquée sur les armes ARC9
  tant que `BlockARC9Customize = true`.
- Recommandé côté serveur : `arc9_free_atts 1` (les accessoires sont fournis par l'armurerie).
- Les emplacements imbriqués (rails ajoutés par un autre accessoire) ne sont pas proposés — seul le
  premier niveau l'est, pour garder une validation serveur simple et sûre.
- Sans ARC9 installé, tout le reste de l'addon fonctionne normalement.

## Réserver des armes à un job (DarkRP)

Ajoutez un champ `jobs` à n'importe quel objet de `sh_items.lua` avec le **nom exact** du job :

```lua
{
    id = "ar2", name = "Fusil à impulsions « Suppression »",
    -- ... le reste de la définition ...
    jobs = { "Opérateur Epsilon-11", "Chef des FGM" },
},
```

Comme dans Ready or Not, les joueurs des autres métiers **ne voient pas du tout** cet objet dans
le menu ; le serveur refuse aussi tout déploiement hors autorisation. Sans champ `jobs`, l'objet
est visible par tout le monde. Combinez avec `ClearanceJobs` pour donner un niveau d'accréditation
à chaque métier.
