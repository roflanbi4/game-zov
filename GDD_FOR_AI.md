# MASTER DESIGN & ARCHITECTURE GUIDE: EAST RIFT ZONE

## 1. PROJECT OVERVIEW
- **Title:** East Rift Zone
- **Genre:** 2D Top-Down Tactical RTS (inspired by *Company of Heroes* & *S.T.A.L.K.E.R.*).
- **Platform:** Web Browser (HTML5 export via Godot 4 Compatibility Renderer).
- **Visual Style:** 2D Top-Down Pixel Art (assets generated via Pixel Art MCP).
- **Setting:** Fictional post-Soviet Eastern European exclusion zone ("The Rift"). Two rival paramilitary factions clash over territory amidst lethal anomalies, artifacts, and mutant hordes.

---

## 2. CORE GAMEPLAY SYSTEMS (COMPONENT-BASED ARCHITECTURE)
To prevent spaghetti code, all units and interactive objects use modular child components (`Node` scripts attached to root `CharacterBody2D` / `Area2D`).

### A. 3-Man Squad System (`SquadController.gd`)
- Infantry units are controlled as a **3-man squad** (a parent `Node2D` Squad Leader marker + 3 `CharacterBody2D` individual soldiers).
- Selecting or issuing a move/attack command to the squad moves all 3 soldiers into formation around the target point.
- Squad dies only when all 3 soldiers reach 0 HP.

### B. Rookies, Veterancy & Morale (`MoraleComponent.gd` & `VeterancyComponent.gd`)
- **Rookie Mechanic:** Newly recruited basic squads start at **Rank 0 (Rookie)**: cheap cost, low accuracy, low HP, and high cowardice (morale drops 2x faster).
- **Veterancy Progression:** Surviving kills/damage grants XP. Leveling up (Rank 1 Veteran -> Rank 2 Elite) significantly boosts accuracy, HP, and morale resilience.
- **Morale System (0.0 to 100.0):**
  - *Drains when:* Under heavy fire, outnumbered nearby, flanked, losing a squadmate, near anomalies, or carrying an Artifact.
  - *Effects:* Below `30.0`, unit enters **Suppressed/Panicked** state (50% slower move speed, -50% accuracy, ignores attack orders and retreats toward nearest friendly point).
  - *Recovers when:* Out of combat, in cover, or near a Medic/Officer.

### C. Squad Specialists (Upgrades)
Players can spend Supply Points to attach **1 Specialist** to an existing infantry squad (replaces or adds a specialized role):
- **Medic:** Passively heals nearby squadmates and boosts Morale recovery.
- **Radio Operator:** Unlocks active ability to call off-map Mortar Strike or Smoke Screen.
- **Sapper / Engineer:** Can disarm anomalies, place mines, and build field defenses (sandbags, auto-turrets).

### D. Cover & Destructible Environment
- **Cover Zones (`CoverZone.gd` - `Area2D`):** Ruins, trenches, and sandbags grant infantry inside `-40% incoming damage` and `+50% morale resistance`.
- **Explosive Props (`ExplosiveProp.gd` - `StaticBody2D`):** Fuel barrels, old transformers, and gas cisterns placed around maps. Taking damage triggers a large AoE explosion damaging nearby units/armor and causing heavy morale shock.

### E. Anomalies & Risk-Reward Artifacts
- **Anomalies (`AnomalyZone.gd` - `Area2D`):** Neutral hazards on the map or spawned dynamically during storms:
  - *Gravitational Vortex:* Pulls units in and crushes armor/infantry.
  - *Thermal Vent:* Periodic fire bursts, destroys projectiles, burns infantry.
  - *EMP Field:* Disables drones and stalls vehicles inside.
- **Artifacts (`ArtifactPickup.gd` - `Area2D`):** Spawn near anomalies or drop from elite mutants. Infantry squads can pick them up for a strong buff (e.g., `+30% speed` or `+30% armor`), **at the cost of continuous Morale drain** due to radiation/paranormal dread.

### F. Day/Night & Vision (`VisionComponent.gd`)
- Maps support a `CanvasModulate` Day/Night toggle.
- **Night Mode:** Infantry vision radius is halved (`50%`). Anomalies glow visibly, gunfire emits bright tracers, and **Thermal/Recon Drones** + **Flare abilities** retain full vision range.

---

## 3. ECONOMY & REINFORCEMENTS (`EconomyManager.gd`)
- **Single Currency:** **Supply Points (SP)**.
- **Income Sources:**
  1. Small passive base trickle (`+2 SP / sec`).
  2. Capturing and holding **Control Points (`ControlPoint.gd`)** on the map (`+5 SP / sec` per point).
  3. Small bounty (`+5 to +20 SP`) for killing enemy units or mutants.
- **Deployment:** Units are called in via UI buttons and spawn at the player's designated entry edge/helipad. Field fortifications (turrets, bunkers) are built by Sapper squads.

---

## 4. FACTIONS & UNIT ROSTER

### Faction 1: "Корпус" (The Corps — Regular Militarized Forces)
*Theme:* Heavy armor, artillery support, disciplined defense.
1. **Conscripts (3-man Rookie Squad):** Cheap cannon fodder, high cowardice, becomes lethal if leveled to Veteran.
2. **Heavy Shock Squad (3-man Elite):** Armored infantry with anti-tank launchers and high base morale.
3. **Recon Drone (UAV):** Fast flying unit, immune to ground obstacles, reveals fog/night vision, marks targets (+accuracy for allies).
4. **APC (BTR):** Armored troop transport (carries 1 squad) with light autocannon.
5. **Main Battle Tank:** Heavy frontal armor, slow turn rate, high-explosive main gun.
6. **Field Artillery / Mortar:** Long-range indirect fire with suppression splash.

### Faction 2: "Синдикат" (The Rift Syndicate — Mercenaries & Zone Stalkers)
*Theme:* Speed, ambushes, FPV drone swarms, anomaly-infused weapons.
1. **Scavengers (3-man Rookie Squad):** Cheap, fast-moving raiders with SMGs, low morale.
2. **Rift Stalkers (3-man Anomaly Squad):** Equipped with experimental arc/anomaly rifles (ignores vehicle armor, causes heavy morale damage).
3. **FPV Kamikaze Drone:** Cheap, high-speed disposable drone that detonates on target impact (hard counter to tanks and clustered infantry).
4. **Gun-Truck (Technical):** Fast unarmored jeep with heavy machine gun (hit-and-run).
5. **Assault Rail-IFV:** Medium agile vehicle firing high-velocity bursts.
6. **MLRS Rocket Truck:** Fires rapid volley of unguided rockets over an area.

### Faction 3: "Мутанты" (Zone Mutants — Neutral AI Hazard)
- **Swarmers (Blind Hounds / Ghouls):** Fast melee units attacking in packs.
- **Brutes / Jugger-Mutants:** High-HP bullet sponges that charge directly into cover and break morale.

---

## 5. SINGLE-PLAYER CAMPAIGN (4 SCRIPTED MISSIONS)
1. **Mission 1 [The Corps] — "Периметр" (Border Sweep):**
   - *Daytime.* Capture 3 Control Points and survive 2 waves of Swarmers. Teaches squad movement, cover, and leveling Rookie Conscripts.
2. **Mission 2 [The Corps] — "Конвой в тумане" (Convoy Ambush):**
   - *Dusk/Anomalies.* Escort 2 supply trucks through an anomaly canyon while fending off Syndicate Gun-Trucks and FPV drones. Features explosive fuel barrels.
3. **Mission 3 [The Syndicate] — "Ночной налет" (Night Raid):**
   - *Night Mode.* Use Recon/Thermal Drones and Scavenger flanks to destroy a heavily fortified Corps artillery base.
4. **Mission 4 [The Syndicate] — "Сердце Разлома" (Heart of the Rift):**
   - *Dynamic Anomaly Storm.* Hold the central artifact reactor against simultaneous waves of Mutants and a full-scale Corps armored counter-attack.

---

## 6. PROJECT DIRECTORY STRUCTURE
```text
res://
├── scenes/
│   ├── units/          # Squads, Soldiers, Vehicles, Drones, Mutants
│   ├── buildings/      # ControlPoints, Turrets, Bunkers
│   ├── environment/    # Anomalies, CoverZones, ExplosiveProps, Artifacts
│   ├── ui/             # HUD, SelectionBox, CallInPanel, SquadCard
│   └── levels/         # Mission_01.tscn to Mission_04.tscn
├── scripts/
│   ├── core/           # GameManager.gd, EconomyManager.gd, RTSCamera.gd, SelectionManager.gd
│   ├── components/     # HealthComponent.gd, MoraleComponent.gd, VeterancyComponent.gd, WeaponComponent.gd
│   └── ai/             # SkirmishAI.gd, MutantWaveSpawner.gd
└── assets/
    ├── sprites/        # Pixel art textures (Filter: Nearest)
    └── audio/
```

---

## 7. STEP-BY-STEP DEVELOPMENT ROADMAP (EXECUTE SEQUENTIALLY)
- **Step 1 (Controls & Camera):** `RTSCamera.gd` (WASD/edge pan + mouse wheel zoom) and `SelectionManager.gd` (left-click drag selection box + right-click move command).
- **Step 2 (Squad & Pathfinding):** `SquadController.gd` + 3 `Soldier.gd` units using `NavigationAgent2D` to move in formation.
- **Step 3 (Combat & Cover):** `HealthComponent.gd`, `WeaponComponent.gd` (auto-acquire targets in `Area2D`), projectiles, `CoverZone.gd`, and `ExplosiveProp.gd`.
- **Step 4 (Morale, Veterancy & Specialists):** `MoraleComponent.gd` (suppression/retreat state), `VeterancyComponent.gd` (Rookie -> Veteran promotion), and Squad Specialist upgrades.
- **Step 5 (Vehicles, Drones & Anomalies):** Vehicle base class, flying `DroneUnit.gd` (Recon & FPV Kamikaze), `AnomalyZone.gd`, and `ArtifactPickup.gd`.
- **Step 6 (Economy, UI & Night Mode):** `EconomyManager.gd`, `ControlPoint.gd`, HUD reinforcement call-in buttons, and `CanvasModulate` night vision toggle.
- **Step 7 (AI & 4 Campaign Missions):** `SkirmishAI.gd`, `MutantWaveSpawner.gd`, and assembling `Mission_01` through `Mission_04`.
