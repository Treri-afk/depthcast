# Jouer en co-op par Steam

Le jeu se développe et se teste **en réseau local**, sans Steam ([D15](DECISIONS.md#d15--le-réseau-local-dabord-steam-en-dernier)).
Ce document ne concerne que le jour où l'on veut jouer avec quelqu'un qui n'est
pas sur le même réseau — ou vérifier les invitations avant de publier.

**Rien de ce qui suit n'est nécessaire pour ouvrir le projet, lancer le jeu, ni
jouer à deux sur la même machine.** Sans GodotSteam, les boutons Steam du menu
restent visibles, grisés, et disent pourquoi.

---

## 1. Installer GodotSteam (GDExtension)

Décidé en [D9](DECISIONS.md#d9--intégration-steam--godotsteam-en-gdextension) :
la **GDExtension**, jamais le module compilé — celui-ci imposerait un binaire
Godot custom à tout le monde, y compris à quelqu'un qui ne vient que dessiner.

0. **Vérifie ta version de Godot d'abord.** Le projet est en **4.7.2**, et
   GodotSteam est publié par version : une archive prévue pour 4.6 s'installe
   sans broncher, crée bien le dossier `addons/`, et ne se charge jamais. C'est
   le mode d'échec le plus fréquent, et il ne ressemble pas à un problème de
   version — il ressemble à une extension absente.
1. Dans l'éditeur : **AssetLib** → chercher `GodotSteam GDExtension` → installer.
   (Ou télécharger l'archive sur <https://godotsteam.com> et la décompresser à la
   racine du projet.)
2. Le dossier `addons/godotsteam/` apparaît. **Il n'est pas versionné** — c'est
   un binaire tiers de plusieurs dizaines de Mo par plateforme, et le dépôt
   n'a qu'1 Go de LFS par mois ([D18](DECISIONS.md#d18--steam-est-branché-godotsteam-nest-pas-versionné)).
   Chacun l'installe de son côté.
3. **Fermer et rouvrir Godot.** Une GDExtension ne se charge qu'au démarrage.

Pour vérifier : lancer le jeu, ouvrir le menu. Si la ligne orange sous les
boutons Steam a disparu, l'extension est chargée.

**Si elle dit que GodotSteam est présent mais ne s'est pas chargé**, c'est le cas
le plus fréquent et il n'a rien à voir avec l'installation : GodotSteam est
publié **par version de Godot**, et une archive prévue pour une autre échoue au
chargement sans message clair. Reprends l'archive correspondant exactement à ta
version de Godot (le menu l'affiche), et redémarre l'éditeur.

Sous Windows, vérifie aussi que `steam_api64.dll` accompagne bien l'extension :
il est dans l'archive, et une décompression partielle le laisse derrière.

## 2. Lancer le client Steam

Il doit tourner **et être connecté**. Le jeu démarre sur l'App ID public de
Valve — 480, *Spacewar* — qui donne accès aux lobbies, aux invitations et au P2P
sans payer Steam Direct ([D8](DECISIONS.md#d8--développement-steam-sur-lapp-id-public-480-transport-interchangeable)).

L'App ID est transmis par variable d'environnement au démarrage : rien à créer
à la main. Si Steam refuse quand même de s'initialiser, poser un fichier
`steam_appid.txt` contenant `480` à la racine du projet (il est ignoré par Git).

Le vrai App ID prendra la place du 480 au moment de publier — une constante,
`SteamApi.APP_ID_DEV`, et c'est tout.

## 3. Jouer

Dans le menu :

| Bouton | Ce qu'il fait |
|---|---|
| **Héberger sur Steam** | Ouvre la session et crée un lobby « amis uniquement ». |
| **Rejoindre le lobby** | Entre dans un lobby par son identifiant, puis se connecte à son hôte. |
| **Rejoindre l'hôte** | Se connecte directement au SteamID64 de l'hôte, sans lobby. |

Dans le salon, l'hôte dispose d'**Inviter des amis** : l'overlay Steam s'ouvre
sur la liste d'amis. Une invitation acceptée ramène l'autre joueur au menu, qui
suit la connexion tout seul — y compris si Steam a dû lancer le jeu pour ça
(`+connect_lobby`).

---

## Ce qui ne marche pas depuis l'éditeur

**L'overlay Steam ne s'affiche que dans un export** ([D9](DECISIONS.md#d9--intégration-steam--godotsteam-en-gdextension)).
Toute vérification d'invitation demande donc un build. Exporter avec les
**templates Godot standards**, surtout pas ceux de GodotSteam.

Le bouton **Rejoindre l'hôte** existe pour ça : il se contente d'un SteamID64
collé à la main, et n'a besoin ni d'overlay ni de lobby.

## Ce qu'on ne peut pas tester seul

Steam refuse deux clients connectés au même compte sur une même machine. Une
partie à deux par Steam demande donc **deux comptes et deux machines** — c'est
exactement la raison pour laquelle le réseau local existe et reste au menu
([D8](DECISIONS.md#d8--développement-steam-sur-lapp-id-public-480-transport-interchangeable),
[R9](ARCHITECTURE.md#r9--le-transport-réseau-est-interchangeable)).

Pour vérifier le co-op sans rien de tout ça, deux terminaux suffisent :

```
Godot --headless --path . res://tools/sonde.tscn -- host
Godot --headless --path . res://tools/sonde.tscn
```

---

## Où vit le code

| Fichier | Rôle |
|---|---|
| `scripts/net/steam_api.gd` | Le seul fichier qui parle à l'API Steam. Appels dynamiques : sans extension, il répond `false`. |
| `scripts/net/steam_transport.gd` | Le tuyau, entre deux SteamID. Interchangeable avec ENet ([R9](ARCHITECTURE.md#r9--le-transport-réseau-est-interchangeable)). |
| `scripts/net/steam_lobby.gd` | Lobbies, invitations, overlay. Autoload `SteamNet`. |

Le reste du jeu ne sait pas que Steam existe, et ne doit jamais l'apprendre.
