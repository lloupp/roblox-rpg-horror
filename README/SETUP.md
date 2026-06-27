# 🧟 DARK SURVIVORS — RPG Survival Horror (Roblox)

> Mundo aberto. Sobreviva. Não confie no que você vê.

## 🎮 Sobre o Jogo

**Dark Survivors** é um RPG survival horror mundo aberto para Roblox. O jogador deve gerenciar fome, sede, sanidade e stamina enquanto explora biomas perigosos, crafta itens, combate inimigos e enfrenta eventos de horror dinâmicos.

### Sistemas Principais

| Sistema | Descrição |
|---------|-----------|
| **Sobrevivência** | Fome, sede, sanidade, stamina, vida — todos decaem com o tempo |
| **Combate** | Melee + ranged, armas variadas, bloqueio, críticos, loot de inimigos |
| **Inventário** | 8 slots (16 com backpack), peso, hotbar, drag-drop |
| **Crafting** | 10+ receitas: torch, traps, molotov, shield, etc. |
| **Mundo** | 6 biomas, ciclo dia/noite, clima dinâmico |
| **Horror** | Eventos de sanidade, jump scares, alucinações, atmosfera |
| **Save** | Auto-save a cada 60s, DataStore com versionamento |

---

## 📂 Estrutura do Projeto

```
 roblox-rpg-horror/
 ├── ServerScripts/          ← Scripts de servidor (Script)
 │   ├── SurvivalSystem.server.lua
 │   ├── CombatSystem.server.lua
 │   ├── InventorySystem.server.lua
 │   ├── WorldSystem.server.lua
 │   ├── HorrorSystem.server.lua
 │   └── DataStoreManager.server.lua
 │
 ├── ClientScripts/          ← Scripts de cliente (LocalScript)
 │   ├── HUD.client.lua
 │   └── HorrorEffects.client.lua
 │
 ├── SharedScripts/          ← Scripts compartilhados (ModuleScript)
 │   └── ItemData.module.lua
 │
 ├── Modules/                ← Módulos reutilizáveis
 │   └── EnemyAI.module.lua
 │
 ├── GUI/                    ← Assets de UI (opcional)
 ├── Maps/                   ← Referência de layout do mapa
 ├── Assets/                 ← Models, sounds, textures
 └── README/
     └── SETUP.md            ← Este arquivo
```

---

## 🛠️ Como Montar no Roblox Studio

### Passo 1 — Criar o Place
1. Abra o **Roblox Studio**
2. Crie um novo **Baseplate** ou **Empty Place**
3. Salve como `DarkSurvivors`

### Passo 2 — Criar RemoteEvents
No **ReplicatedStorage**, crie uma Folder chamada `Remotes` com estes RemoteEvents:

```
Remotes/
├── UpdateStats          (Server → Client: sync stats)
├── AttackRequest        (Client → Server: player attacks)
├── AttackResult         (Server → Client: hit feedback)
├── InventoryUpdate      (Server → Client: inventory sync)
├── InventoryAction      (Client → Server: pickup/equip/drop/craft)
├── CraftingResult       (Server → Client: craft success/fail)
├── HorrorEvent          (Server → Client: trigger horror event)
├── SanityEffect         (Server → Client: sanity visual effect)
├── WeatherUpdate        (Server → Client: weather change)
├── TimeUpdate           (Server → Client: day/night cycle)
├── InteractionPrompt    (Server → Client: show E/F prompt)
├── DamageNumber         (Server → Client: floating damage)
└── JumpScare            (Server → Client: jump scare trigger)
```

### Passo 3 — Organizar Scripts
| Script | Tipo | Local no Explorer |
|--------|------|-------------------|
| SurvivalSystem | **Script** | `ServerScriptService` |
| CombatSystem | **Script** | `ServerScriptService` |
| InventorySystem | **Script** | `ServerScriptService` |
| WorldSystem | **Script** | `ServerScriptService` |
| HorrorSystem | **Script** | `ServerScriptService` |
| DataStoreManager | **Script** | `ServerScriptService` |
| HUD | **LocalScript** | `StarterPlayerScripts` |
| HorrorEffects | **LocalScript** | `StarterPlayerScripts` |
| ItemData | **ModuleScript** | `ReplicatedStorage/Shared` |
| EnemyAI | **ModuleScript** | `ServerScriptService/Modules` |

### Passo 4 — Configurar o Mapa

#### Biomas (coloque Parts/Folders com estes nomes em `Workspace/Biomes`):
- **Forest** — Árvores, grama, caminhos
- **Swamp** — Água rasa, névoa verde, debuff de veneno
- **Ruins** — Prédios destruídos, loot, inimigos
- **Bunker** — Interiors, safe zone, crafting stations
- **Hospital** — Corredores, salas, alto horror, loot médico
- **Caves** — Túneis escuros, recursos raros

#### Enemy Spawns (coloque Parts em `Workspace/EnemySpawns`):
- Nomeie cada spawn: `ZombieSpawn1`, `ShadowSpawn3`, etc.
- Tipo de inimigo é determinado pelo prefixo do nome

#### Loot Spawns (Parts em `Workspace/LootSpawns`):
- Itens spawnam aleatoriamente nestes pontos

### Passo 5 — Configurar Lighting
No serviço **Lighting**, set:
- `ClockTime = 14` (iniciar de dia)
- `Brightness = 2`
- `Ambient = Color3.fromRGB(128,128,128)`
- `FogEnd = 10000`
- `Atmosphere` object: Density 0.3

### Passo 6 — Testar
1. Pressione **Play** (F5)
2. Verifique o console (View → Output) por erros
3. Teste cada sistema individualmente
4. Para multiplayer: Publish → Test → Start Server + Players

---

## 🎯 Inimigos

| Tipo | HP | Speed | Attack | Comportamento |
|------|----|-------|--------|---------------|
| **Zombie** | 100 | 8 | Melee 15 | Lento, persegue, tanky |
| **Shadow** | 40 | 22 | Melee 25 | Rápido, teleporta quando perde LOS |
| **Mutant** | 60 | 10 | Ranged 20 | Cuspe ácido a distância, foge quando low HP |

---

## 🍳 Crafting

| Receita | Ingredientes | Resultado |
|---------|-------------|-----------|
| Tocha | Wood + Cloth + DuctTape | Iluminação portátil |
| Spike Trap | Wood + Metal + Rope | Armadilha de dano |
| Molotov | Cloth + Chemical | Arma incendiária |
| Shield | Metal + Metal + DuctTape | Bloqueio +def |
| Poison Bomb | Chemical×2 + Glass | Dano venenoso em área |
| Electric Trap | Wood + Wire + DuctTape | Armadilha stun |
| Backpack | Cloth×2 + Rope | +8 slots inventário |
| Lockpick | Metal + DuctTape + Wire | Abrir portas/baús |
| Cooked Meat | RawMeat + Lighter | Comida segura |
| Flash Bomb | Glass + Chemical + DuctTape | Stun em área |

---

## 🌦️ Clima

| Clima | Efeito |
|-------|--------|
| Clear | Normal |
| Rain | Speed -10%, som de chuva |
| Storm | Lightning (dano), thunder, visibilidade reduzida |
| Fog | FogEnd reduzido, visibilidade mínima |
| Blood Rain | Chuva vermelha, sanity -2/sec quando fora |

---

## 💀 Sistema de Sanidade

| Sanidade | Efeitos |
|----------|---------|
| 70-100 | Normal |
| 50-69 | Sussurros, sombras distantes |
| 30-49 | Tela treme, inimigos falsos, portas abrem sozinhas |
| 15-29 | Distorção pesada, jumpscares fake, texto nas paredes |
| 0-14 | UI mente (stats falsos), inimigos parecem NPCs |

---

## 🚀 Próximos Passos (Pós-Chassis)

- [ ] Modelar inimigos no Blender → importar como MeshPart
- [ ] Adicionar sons próprios (criaturas, ambiente, jump scares)
- [ ] Criar animações de ataque (Moon Animator)
- [ ] Balancear stats/dano/tempo
- [ ] Sistema de missões/lore
- [ ] Multi-team (PvPvE)
- [ ] Leaderboard/stats globais
- [ ] Passes de game (Game Passes no Roblox)
- [ ] Monetização: game passes, developer products

---

**Desenvolvido com 💀 por Eduardo + Hermes Agent**
