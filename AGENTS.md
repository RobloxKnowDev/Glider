# Règles de code du projet

- Ne pas mettre de commentaires dans les scripts.
- Utiliser directement la hiérarchie fournie avec `WaitForChild`.
- Ne pas ajouter de fonctions de recherche génériques ni de vérifications défensives quand l'organisation des objets est connue.
- Préférer un accès simple et lisible, par exemple `local Button = Card:WaitForChild("Button")`.
- Si un nom dans la hiérarchie est incorrect, laisser l'erreur apparaître clairement pour qu'elle puisse être corrigée.
- Ne jamais écrire un ID d'image en dur dans un script : chaque image utilisée par le code est déclarée dans `src/shared/Config/Images.luau`, rangée par système dans la table `Images` (`Trail = { White = "rbxassetid://..." }`), et lue avec `Images.Système.Nom`, par exemple `Images.Trail.White`. Si une image manque, ajouter la clé avec `"rbxassetid://0"` et le signaler pour que l'ID soit rempli.
- `Shared.Config` ne contient que du contenu (listes des gliders et des trails, raretés, images). Les réglages (vitesses, durées, caméra, animations) sont des constantes locales en haut du script qui les utilise.

# Projet

Glider Game : obby sur un glider, en solo ou en duo.

- Les joueurs sont suspendus au `Bar` du glider et s'y déplacent à gauche et à droite en avançant les mains, sans pouvoir se traverser.
- La position moyenne des joueurs sur la barre fait pencher le glider et l'inclinaison le fait tourner. Au centre, il va tout droit.
- Le glider avance en continu et perd de l'altitude. Les zones de vent le font remonter.
- La monnaie (les Studs, affichés en `$`) est sauvegardée et affichée dans `HUD.CoinFrame` et le leaderstats. On la gagne en passant dans les rings.
- Les gliders et les trails s'obtiendront avec des crates (à venir). Il n'y a pas d'achat direct, seulement des inventaires.

# Partie

- `PlayerGui.PlayUi` est construit dans Studio. `PlayButton` ouvre et ferme `MainFrame` avec `UiController`, et `Top.CloseButton` la ferme. `SoloButton` lance un vol seul. `DuoButton` cache `SoloButton` et `DuoButton` et affiche `DuoPage`. Le `CloseButton` de `DuoPage` la cache et réaffiche les deux boutons, comme chaque ouverture ou fermeture de `MainFrame`.
- `DuoPage.ScrollingFrame` a une carte par autre joueur du serveur, clonée depuis `Template` (`Frame.Icon` : avatar, `Frame.Name`, `Frame.InviteButton`). L'`InviteButton` affiche `Invite` avec les couleurs du template. Il passe en gris avec `Sent` pendant `SentTime` secondes après une invitation, `Declined` pendant `DeclinedTime` secondes après un refus, et `Playing` tant que le joueur est en partie.
- L'invité voit `PlayUi.Message` (`Text`, `AcceptButton`, `DeclineButton`), qui disparaît après `InviteTimeout` secondes.
- `DuoService` garde une invitation par joueur invité (remotes `Invite`, `Answer`, `Invited`, `Declined`). Si l'invitation est acceptée à temps et que les deux joueurs ne volent pas, il appelle `GliderService:Launch({ Invitant, Invité })`.
- Lancement : `GliderService:Launch` réserve les joueurs et leur envoie `Launching`. Leurs clients ferment l'UI ouverte, cachent `PlayUi` et `HUD.Left`, et ferment le cercle d'un coup (`TransitionController:Shut`). Après `LaunchDelay`, le serveur crée le glider et envoie `Started`, puis le cercle se rouvre sur le joueur suspendu. Si un joueur est parti ou mort entre-temps, le lancement est annulé avec `Stopped` et le cercle se rouvre.
- L'attribut `Flying` sur chaque Player, posé dès `Launching`, indique aux clients qui est déjà en partie. `PlayUi` et `HUD.Left` réapparaissent à `Stopped`.

# Glider

- Modèles : `ReplicatedStorage.Assets.Glider.<Nom>` (`Classic` est le glider de base), chacun avec une Part `Bar` à laquelle les joueurs sont suspendus. La longueur du `Bar` donne l'axe gauche/droite.
- `Shared.Utils.GliderFrame` donne le repère d'un glider depuis son `Bar` : droite le long du `Bar`, haut vertical, avant perpendiculaire. Il sert au vol et aux viewports de l'inventaire.
- `GliderService:Launch(Team)` (1 ou 2 joueurs) clone le glider équipé du premier joueur au centre de `Workspace.SpawnPart`, tourné vers la face avant du `SpawnPart` (celle que montre l'orientation indicator de Studio), dans `Workspace.Gliders` (nommé par le UserId du premier joueur). Le `SpawnPart` est un repère : le serveur le rend invisible et sans collision.
- Trails : le `Bar` de chaque modèle contient deux attachments, un à chaque bout d'aile. Au lancement, `TrailService:Attach` prend chaque `Attachment` du `Bar`, quel que soit son nom, et crée au-dessus de lui un `TrailAttachment`, à `TrailWidth` vers le haut du glider, et un `Trail` entre les deux, de la couleur du trail équipé par le premier joueur. L'écart entre les deux attachments donne la largeur du trail. Il doit rester perpendiculaire au vol pour que `FaceCamera` tourne toujours le trail vers la caméra. Le trail s'élargit juste après le bout d'aile, puis s'affine en pointe et s'efface vers la queue. Si le trail a des `Sparkles`, un `ParticleEmitter` avec la texture d'étincelle par défaut de Roblox est ajouté sur chaque attachment d'aile. Ses particules restent dans le monde et scintillent le long du trail. Les réglages sont en haut de `TrailService`.
- Chaque joueur est soudé sous le `Bar` par un `Weld` rangé dans `Riders` (nommé par UserId, attributs `Offset` et `Height`). En duo, ils partent de part et d'autre du centre. `Height` est calculé depuis les articulations R15 pour que les mains bras levés arrivent sur la barre.
- Le premier joueur est le pilote (attribut `Pilot` du glider) et reçoit la propriété réseau. Son `GliderController` simule le vol (inclinaison, virage, descente, vent) et détecte les crashs. Le passager suit le `Bar` répliqué pour sa caméra.
- `GliderController` déplace son joueur le long de la barre, le donne à `RiderController:Steer` et l'envoie au serveur avec `Move`. Gauche et droite sont lus par rapport à la caméra, pour rester les mêmes quand on la tourne. Le serveur réplique la position dans le `Weld` et son attribut `Offset`.
- Collision entre joueurs : chaque client garde au moins `RiderGap` entre lui et son partenaire et se fait pousser s'il est trop près.
- Caméra : on la tourne en maintenant le clic droit, en glissant le doigt ou avec le stick droit. Après `ReturnDelay` secondes sans y toucher, elle revient derrière le glider.
- `RiderController` (toujours actif) suit tous les gliders de `Workspace.Gliders`. Pour chaque joueur, il lisse l'attribut `Offset` et réécrit le `Weld` localement. Seul le joueur local suit directement `Steer`, sans lissage.
- Il écrit aussi la pose suspendue (`Motor6D.Transform` des épaules et des hanches, rig R15) dans `PreSimulation`. `Transform` n'étant pas répliqué, chaque client anime ainsi tous les joueurs depuis `Offset`, et tout le monde voit les animations de tout le monde.
- Crash : dès que le glider ou un joueur touche une Part qui a `CanCollide`, le pilote envoie `Crash`. Les autres gliders, les personnages, les rings et les zones de vent sont ignorés.
- Le serveur détache alors tous les joueurs du glider et les met en ragdoll sans les tuer (`Utils.Ragdoll` remplace les `Motor6D` par des `BallSocketConstraint`, sauf `Root` et `Neck`), puis envoie `Crashed`. Après `RespawnTime`, il remet les articulations, téléporte les joueurs côte à côte sur `Workspace.SpawnLocation` et termine le vol (`Stopped`).
- Si un joueur quitte le jeu ou réapparaît pendant un vol, il sort du vol et les autres joueurs crashent.
- Les réglages de vol et de caméra sont en haut de `GliderController`, ceux de la pose et du lissage en haut de `RiderController`. `LaunchDelay`, `RespawnTime`, `RiderGap` et les marges sont en haut de `GliderService`.

# Parcours

- `Workspace.RingsFolder` : chaque `Ring` est un Model avec deux Parts `Ring`, un Model `Text` et un attribut `Reward`. `GliderService` détecte côté serveur quand le `Bar` traverse un ring et donne `Reward` Studs à chaque joueur du glider, une fois par ring et par vol. Il leur envoie aussi `Ring` avec le modèle.
- `RingController` joue alors l'animation chez ces joueurs : un double du ring, sans son `Text`, grandit et s'efface, et le ring flashe en blanc (`Highlight`). Le `GliderController` du pilote ajoute `RingBoost` à la vitesse, un bonus qui retombe avec `BoostResponse`.
- Le plan d'un ring est l'axe le plus fin de sa boîte englobante, et son rayon la moitié de la plus petite des deux autres dimensions. Les rings sont mesurés une seule fois au démarrage du serveur.
- `Workspace.Windzones` : tant que le `Bar` est dans une `WindPart`, le glider monte à `WindLiftSpeed` au lieu de descendre (`LiftResponse` règle la vitesse à laquelle la montée s'installe). En sortant, il garde son élan et continue de monter un moment avant de redescendre (`SinkResponse`).

# Transition

- `TransitionController:Close(Character)` resserre un cercle noir sur la tête en deux temps : il rétrécit, marque une pause, puis ferme l'écran. `Open` rouvre le cercle d'un seul mouvement depuis la tête.
- `Shut(Character)` ferme le cercle d'un seul mouvement, sans pause, au lancement d'une partie. `ShutTime` doit rester plus court que `LaunchDelay` (en haut de `GliderService`).
- `Play(Character, Ready)` enchaîne les deux et attend `Ready`, qui rend le personnage à montrer. `GliderController` la lance à un crash, jusqu'à la fin du vol. `TransitionController` la lance aussi à chaque vraie mort, jusqu'à la réapparition Roblox au `SpawnLocation`.
- Au chargement, `LoadingController` appelle `Blackout` puis `Reveal(Character)` : l'écran passe du noir à l'ouverture du cercle.
- `RespawnTime` (en haut de `GliderService`) est le délai avant la téléportation après un crash et la valeur de `Players.RespawnTime`. La fermeture doit rester plus courte que `RespawnTime`.
- Le cercle est un Frame rond transparent dont le `UIStroke` très épais couvre le reste de l'écran, sans image.

# Monnaie

- `StudsService` : solde de Studs (`leaderstats.Studs`, section de sauvegarde `Studs`), avec `Add` et `Spend`. Remotes `GetStuds` et `Updated` (solde, montant gagné). Le montant de départ est `Startingstuds`.
- `StudsController` : affiche l'argent dans `HUD.CoinFrame.Text` au format `1,000,000$`. À chaque gain, un `+montant$` apparaît au centre de l'écran. Une gerbe de `$` éclate puis file en courbe jusqu'au compteur, qui monte à chaque arrivée, flashe en vert et rebondit.
- `CoinFrame.BuyButton` n'a pour l'instant que son animation : il ouvrira la fenêtre d'achat de coins en Robux.

# Inventaire

- Deux catégories, `Gliders` et `Trails`. `Shared.Config.Gliders` et `Shared.Config.Trails` : `List` donne les objets dans l'ordre d'affichage, avec leur `Rarity`. Pour un glider, `Name` est le nom du modèle dans `Assets.Glider`. Un trail a aussi sa `Color` (`ColorSequence` de la tête vers la queue), son icône `Images.Trail.<Name>`, et parfois des `Sparkles` (`ColorSequence` des étincelles). `Default` est l'objet de base de la catégorie, toujours possédé et rééquipé à chaque `UnEquip`.
- `Shared.Config.Rarities` : les raretés `Common`, `Rare`, `Epic`, `Legendary` et `Mythic`. Chacune a un `Gradient` (couleurs reprises du projet Clean Old Stuff) et une couleur `Stroke` foncée. Le texte `Rarity` d'une carte passe en blanc avec un `UIGradient` de sa rareté (`UiGradient.Ensure`), et son `UIStroke` prend la couleur `Stroke`.
- Tests : en Studio, les catégories de `StudioUnlocked` (en haut de `InventoryService`, pour l'instant `Trails`) sont entièrement débloquées pour tout le monde. Elles ne sont alors pas sauvegardées, pour ne pas fausser les vraies données.
- `InventoryService` : objets possédés et objet équipé par catégorie, chacune dans sa section de sauvegarde du même nom. Remotes `GetState`, `Equip`, `Unequip` (repasse sur `Default`) et `Updated`. `Give(Player, Catégorie, Nom)` ajoute un objet, pour les crates. `GetEquipped(Player, Catégorie)` donne le glider que `GliderService` fait voler et le trail que `TrailService` lui met.
- `InventoryController` : `HUD.Left.GliderButton` ouvre `GliderUi.Frame` et `HUD.Left.TrailButton` ouvre `TrailUi.Frame`. `Top.CloseButton` les ferme. Chaque carte est clonée depuis `Scrolling.Template` : les deux `Name`, `Rarity`, et le modèle du glider dans le `ViewportFrame` ou l'icône du trail dans `Icon`. Tous les objets de la config sont affichés. Sur ceux que le joueur n'a pas, un Frame noir `Lock` (transparence `LockTransparency`) grise la carte, et le `BuyButton` gris affiche `Locked`.
- Le glider d'une carte tourne sur lui-même tant que la souris est dessus, puis revient droit. Le `BuyButton` affiche `Equip` (vert) ou `UnEquip` (rouge).

# Architecture

- `src/server/Services` : services serveur chargés automatiquement par `Server.server.luau`. Chaque module retourne une table avec `Name`, `Priority`, et optionnellement `Remotes`, `Init`, `Start`.
- `src/client/Controllers` : controllers client chargés automatiquement par `Client.client.luau`, même format sans `Remotes`.
- `Core` (`ReplicatedStorage.Shared.Packages.Core`) appelle tous les `Init` puis tous les `Start` par `Priority` croissante. Accès entre modules avec `Core:GetService("Name")` et `Core:GetController("Name")`.
- `RemoteManager` crée les remotes déclarés dans `Remotes = { Nom = "Event" | "Function" }` sous `ReplicatedStorage.Remotes`, nommés `Service_Nom`. Serveur : `OnServerEvent`, `OnServerInvoke`, `FireClient`, `FireAllClients`. Client : `FireServer`, `InvokeServer`, `OnClientEvent`.
- Sauvegarde : un service enregistre sa section dans son `Init` avec `Core:GetService("DataService"):Register("Nom", { Load, Save, Clear })`. Le nom doit aussi être ajouté à `Sectionorder` dans `DataService.luau`.
- Textes affichés : passer par `Shared.Utils.Translation` (`Set`, `Format`, `Raw`).
- `src/first/LoadingScreen.client.luau` retire l'écran de chargement Roblox et garde l'écran noir jusqu'à ce que `LoadingController` mette l'attribut `Ready` sur `LoadingUi`, ou au plus 25 s. `LoadingController` précharge pendant ce temps les images du `PlayerGui` et toutes celles de `Config.Images`, puis lance l'ouverture en cercle.
- `UiController` : toute UI s'ouvre avec `Open` ou `Toggle` et se ferme avec `Close`. Une seule est ouverte à la fois, avec un flou derrière et la FOV légèrement zoomée.
- `UiFade.BindButton` anime le survol et le clic d'un bouton avec un `UIScale`. Les boutons de `HUD.Left` sont rangés par un `UIListLayout` avec `Wraps`, où l'`UIScale` n'a pas d'effet : ils utilisent `UiFade.BindButtonSize`, qui anime directement leur `Size`.
- L'UI et la map sont construites dans Studio (`$ignoreUnknownInstances`), seuls les scripts sont dans `src`, sauf `TransitionUi`, construit en code. Les ScreenGui de Studio doivent avoir `ResetOnSpawn` décoché, car les controllers ne s'y branchent qu'une fois.
