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
 │   ├── DataStoreManager.server.lua
 │   ├── WorldBootstrap.server.lua      ← gera mundo placeholder + lighting
 │   └── EnemySpawnManager.server.lua   ← spawna inimigos a partir do EnemyAI
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

O projeto usa [Rojo](https://rojo.space/) (`default.project.json`) e é **auto-inicializável**: RemoteEvents, mundo placeholder (chão, 6 zonas de bioma, spawn point, iluminação/atmosfera) e os inimigos já nascem sozinhos quando o servidor inicia. Não é preciso criar nada manualmente no Explorer.

### Passo 1 — Instalar o Rojo
1. Instale a extensão/plugin **Rojo** no Roblox Studio (Plugin Marketplace) e o Rojo CLI (`cargo install rojo` ou via [rojo.space](https://rojo.space/docs/installation/)).
2. Abra o Roblox Studio e crie um **Empty Place** (não precisa ser Baseplate — o `WorldBootstrap` cria o chão).

### Passo 2 — Sincronizar o projeto
1. Na pasta do repositório, rode `rojo serve` (ou `rojo build -o DarkSurvivors.rbxlx` se preferir gerar o arquivo direto).
2. No Studio, abra o plugin Rojo e clique em **Connect**.
3. Isso monta automaticamente a árvore descrita em `default.project.json`:

| Pasta local | Vai para |
|-------------|----------|
| `ServerScripts/` | `ServerScriptService` |
| `Modules/` | `ServerScriptService/Modules` |
| `ClientScripts/` | `StarterPlayer/StarterPlayerScripts` |
| `SharedScripts/` | `ReplicatedStorage/Shared` |

Isso inclui os 8 scripts do servidor: `SurvivalSystem`, `CombatSystem`, `InventorySystem`, `WorldSystem`, `HorrorSystem`, `DataStoreManager`, `WorldBootstrap` e `EnemySpawnManager`.

### Passo 3 — O que acontece automaticamente ao dar Play
- **Remotes**: cada sistema cria seus próprios `RemoteEvent`s em `ReplicatedStorage/Remotes` sob demanda (não precisa criar nenhum à mão).
- **Mundo**: `WorldBootstrap.server.lua` gera um chão, 6 zonas de bioma (`Forest`, `Swamp`, `Ruins`, `Bunker`, `Hospital`, `Caves`) e um `SpawnLocation` — placeholders coloridos e planos, prontos para virar terreno/arte de verdade depois.
- **Iluminação**: `ClockTime`, `Brightness`, `Ambient`, `FogEnd` e um objeto `Atmosphere` (Density 0.3) são configurados pelo mesmo script.
- **Inimigos**: `EnemySpawnManager.server.lua` cria marcadores em `Workspace/EnemySpawns` (prefixo do nome define o tipo, ex. `ZombieSpawn1`) e spawna um `Zombie`, `Shadow` ou `Mutant` em cada um, usando `Modules/EnemyAI.lua` para movimentação/combate e respawn automático após a morte.

Cada uma dessas etapas só roda se a pasta/objeto correspondente ainda não existir — então dá pra substituir qualquer placeholder por arte/level design de verdade sem medo de o script sobrescrever seu trabalho.

### Passo 4 — Testar
1. Pressione **Play** (F5)
2. Verifique o console (View → Output) por erros — cada sistema imprime `Loaded ✓` ao iniciar
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

- [ ] Modelar inimigos no Blender → importar como MeshPart (hoje `EnemySpawnManager` gera rigs R15 procedurais tingidos por tipo como placeholder)
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
