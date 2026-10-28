# Glider Game

Obby coopératif à 2 joueurs sur un glider. Projet Rojo basé sur le framework de Clean Old Stuff.

## Démarrer

```bash
rokit install
rojo serve
```

Ouvrir la place dans Studio et se connecter avec le plugin Rojo.

Pour générer une place locale :

```bash
rojo build -o "Glider Game.rbxlx"
```

Pour tester la sauvegarde dans Studio : Game Settings > Security > Enable Studio Access to API Services.

## Structure

| Dossier | Destination |
|---|---|
| `src/first` | `ReplicatedFirst` |
| `src/shared` | `ReplicatedStorage.Shared` |
| `src/server` | `ServerScriptService` |
| `src/client` | `StarterPlayer.StarterPlayerScripts` |

Conventions de code et architecture : [AGENTS.md](AGENTS.md).
