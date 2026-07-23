# 🗺️ Dark Survivors — Roadmap & Análise

> Snapshot do estado do projeto em 2026-07-22 (branch `fix/bindtoclose-typo`).
> 16 arquivos, ~2.4k LOC. Skeleton jogável, mas com bugs críticos de integração.

---

## 🔴 Bugs críticos que quebram a gameplay atual

| # | Onde | O que acontece |
|---|------|----------------|
| 1 | `SurvivalSystem:181-199` | Heartbeat executa `humanoid.Health = s.Health` todo frame. Dano de inimigos (via `Humanoid:TakeDamage`) é **desfeito no próximo tick** porque `s.Health` não é atualizado quando o dano vem de fora. Não existe `Humanoid.HealthChanged` ouvindo dano externo → jogador não morre de verdade. |
| 2 | `HorrorSystem:51-62` vs `SurvivalSystem` | Existem **duas fontes de sanidade**: `playerStats[player].Sanity` (SurvivalSystem, mostrada no HUD) e `playerSanity[player]` (HorrorSystem, usada pra disparar eventos). Elas **nunca sincronizam** — o bloco `UpdateStatsRemote` no HorrorSystem está vazio (`-- Server tracks sanity internally`). Resultado: eventos de horror rodam em cima de sanidade sempre 100, nunca disparam. |
| 3 | `DataStoreManager` ↔ `SurvivalSystem` | `initPlayer()` (SurvivalSystem) sempre cria 100/100/100/100/100, **ignorando `pd.stats` carregado**. Stats não restauram ao relogar. O remote `DataStatsUpdate` existe mas ninguém dispara pra ele. |
| 4 | `HorrorEffects.client.lua:12` | `local camera = Workspace.CurrentCamera` — `Workspace` (capitalizado) não é declarado no script. Roblox moderna usa `workspace` (minúsculo). Provável erro de runtime no cliente. |
| 5 | `CombatSystem` ↔ `InventorySystem` | Ambos registram `EquipRemote.OnServerEvent`. Funciona, mas o `combatState.equippedWeapon` nunca é sincronizado com `inv.equipped.weapon` — atacar usa `weaponName` enviado pelo cliente, sem checar o que realmente tem equipado. Cliente pode atacar com Shotgun mesmo sem a ter. |

---

## 🟡 Sistemas "no papel" — declarados em ItemData mas sem código que os executa

- **Armadilhas** (`SpikeTrap`, `ElectricTrap`): têm `isTrap = true`, `trapDamage`, `stunDuration`, mas **nenhuma lógica de posicionamento/ativação**.
- **Área/throwable** (`Molotov`, `PoisonBomb`, `FlashBomb`): tem `areaDamage`, `poisons`, `blinding`, `isThrowable`, **mas nada explode, stunneia ou envenena**.
- **Ferramentas funcionais** (`Flashlight`, `Torch`, `Lighter`): têm `providesLight`/`lightRadius`/`providesFire` mas **nenhuma luz é criada** ao usar/equipar.
- **`Antidote`** (`curesPoison`), **`Adrenaline`** (`speedBoost`, `boostDuration`): são `Medical`, mas o handler `use` só lê `healthRestore` — eles são consumidos sem nenhum efeito.
- **`Lockpick`** (`opensLocks`), **`Map`** (`revealsMap`), **`Radio`** (`canCallRescue`), **`Compass`**: definidos mas nada no jogo consome essas propriedades. Portas/baús não existem.
- **`MysteryBox`** (`randomLoot`): sem lógica de abertura.
- **`Journal`** (`containsLore`): sistema de lore não existe.

---

## 🟡 Itens do design document que não têm implementação

- **Uso de hotbar**: o HUD mapeia slot→índice mas teclas `1-4` só mudam o highlight visual — ninguém chama `use` no item mapeado.
- **Combo de teclas de combate**: `AttackRequest`, `ToggleBlock` não têm cliente disparando (só servidor ouve).
- **Bloqueio**: Não há input no cliente para iniciar/parar block.
- **Correr/sprint**: `ToggleRun` remote existe, mas nenhum cliente dispara.
- **Pausa/morte/respawn** com tela de transição: nada implementado — só respawn nativo do Roblox.
- **Sons**: zero `Sound` instanciado. Sussurros, jump scares, ambiente, ataque, passos — tudo só visual.
- **Animações**: NPCs são rigs de Part pré-fabricados; sem `AnimationTrack`.
- **Equip visível**: equipar arma/armadura não coloca nada no avatar.

---

## 🟢 Conteúdo que precisa ser criado (não é código)

| O quê | Estado |
|-------|--------|
| **Mapa** | Pastas `Biomes` vazias; sem terreno, props, prédios, ou iluminação de cena |
| **Spawn markers** (`Workspace/EnemySpawns`) | EnemySpawner cria a pasta vazia e avisa; sem markers = **zero inimigos no mundo** |
| **LootSpawns** (`Workspace/LootSpawns`) | sem configs específicas — hoje loot spawnado pega posição aleatória de Parts filhas de Ruins/Hospital |
| **Modelos/Meshes** | NPCs são blocos coloridos |
| **Lighting config** | SETUP.md orienta, mas o `.rbxl` não vem pré-configurado |
| **Game loop / progressão** | Só "sobreviva até morrer"; sem objetivos, missões, facções, win-state |
| **Monetização** | Gamepasses/DevProducts — no roadmap do SETUP |

---

## 📋 O que está 100% funcional hoje

Sobrevivência (fome/sede/stamina/stamina-regen), combate melee/ranged com crit+block, inventário + crafting (10 receitas), dia/noite + clima, drops de loot no mundo, save DataStore, IA dos 3 inimigos, efeitos visuais de horror (vignette/grain/jumpscare/fake-entity). **É um skeleton jogável** — mas com os bugs críticos (1, 2 e 3), sanidade é decorativa e o jogador é essencialmente imortal.

---

## 🎯 Ordem de prioridade sugerida

### Fase 1 — Correções críticas (bugs que quebram o jogo)
1. **Bug #1** — listener de `Humanoid.HealthChanged` em `SurvivalSystem` atualizando `s.Health` (e remover o `humanoid.Health = s.Health` do loop forçado).
2. **Bug #2** — HorrorSystem ler a sanidade da SurvivalSystem via `_G.GetStats(player)` em vez de manter a propria tabela.
3. **Bug #3** — SurvivalSystem partir de `pd.stats` (do DataStore) em vez de DEFAULTS.
4. **Bug #4** — trocar `Workspace` por `workspace` no `HorrorEffects`.
5. **Bug #5** — sincronizar `combatState.equippedWeapon` com `inv.equipped.weapon` e validar weapon no `AttackRequest`.

### Fase 2 — Sistemas que liberam jogabilidade
6. Implementar **ferramentas de luz** (Flashlight/Torch/Lighter) — sem isso o jogo não é jogável à noite/caves.
7. Implementar **uso de hotbar** e input de **ataque/bloqueio/correr** no cliente.
8. Implementar **armadilhas e throwables** (SpikeTrap/Molotov/PoisonBomb/FlashBomb/ElectricTrap).
9. Implementar efeitos dos **consumíveis especiais** (Antidote/Adrenaline).
10. Validar equip no servidor (Bug #5 acima).

### Fase 3 — Conteúdo e polimento
11. Adicionar alguns **EnemySpawn markers** (mesmo que poucos) pra testar o loop de combate → respawn → loot.
12. Adicionar árvores/props/casa num bioma Forest + Spawn pra validar o resto.
13. Adicionar **sons** (ambiente, ataque, jump scare).
14. Balancear stats/dano/tempo.
15. Sistema de missões/lore.

### Fase 4 — Publicação
16. Modelos/Meshes (Blender → MeshPart).
17. Animações de ataque (Moon Animator).
18. Game loop / progressão (objetivos, win-state).
19. Monetização: Game Passes / Developer Products.
20. Leaderboard/stats globais.

---

## 📊 Status consolidado

| Sistema | Estado | % pronto (estimado) |
|---------|--------|---------------------|
| Survival (stats decay) | ✅ funciona | 90% |
| Combat (melee/ranged) | ⚠️ funciona, bug #5 | 85% |
| Inventory + Crafting | ✅ funciona | 85% |
| WorldSystem (dia/noite/clima) | ✅ funciona | 90% |
| DataStore (save/load) | ⚠️ bug #3 | 75% |
| HorrorSanity | ⚠️ bug #2, eventos não disparam | 40% |
| EnemyAI + Spawner | ✅ funciona, sem markers no mundo | 70% |
| HUD (UI) | ⚠️ falta input/use hotbar | 60% |
| HorrorEffects (client) | ⚠️ bug #4 | 80% |
| Ferramentas/Armadilhas/Throwables | ❌ não existe | 10% |
| Sons | ❌ não existe | 0% |
| Animações | ❌ não existe | 0% |
| Mapa / Biomas | ❌ pastas vazias | 5% |
| Missões/Lore | ❌ não existe | 0% |
| Monetização | ❌ não existe | 0% |
| **TOTAL geral** | | **~58%** |

---

*Análise gerada em 22/jul/2026 por Hermes Agent com Eduardo.*
