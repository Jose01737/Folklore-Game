# FOLKLORE (working title)
A top-down horror survival game where every chapter is a different country and every monster is a real piece of folklore. Read the lore, work out the weakness, survive the night.

Built with **Godot 4.3** (free, open source, Steam-friendly). All content is data-driven: you can change monsters, characters, regions and items without touching code.

## Run it
1. Install Godot 4.3+ from godotengine.org
2. Open this folder in Godot (Import -> `project.godot`) and press F5.

Controls: WASD move, mouse aim, F flashlight, Shift sneak, E interact, 1-8 use item, B build shelter, G ward shelter, J journal, Esc menu.

## How the game works
- Each **region** has one entity, 3 lore notes, 4 items (one is the weakness), 2 save shrines and an exit.
- Notes reveal clues in your **journal**. Pick the correct item and press its number while near the monster to banish it. Wrong item = it goes into a rage for 10 seconds.
- **Light matters**: the flashlight lets monsters see you from farther away. Sneaking and darkness keep you quiet.
- **Sanity** drains near monsters and recovers at save shrines. Low sanity flickers your light.
- **Save points**: shrines (glowing orange) save your inventory, journal, region and position to `user://savegame.json`. Dying returns you to your last shrine.

## Shelters
- Collect **scrap wood** (5 per region). Press **B** to build a shelter for 3 scrap (max 2 per area, needs open ground, no monster nearby).
- Stand inside to **hide**: monsters that have not noticed you lose track of you, and your sanity recovers quickly.
- Monsters that already saw or heard you will come and **scratch it down** (about 12 seconds). Flashlight on makes you easier to notice.
- **E** inside a shelter rests and **saves** (it works as a save point). Shelters persist in the save file.
- **G** wards the shelter: pick the item that matches the monster's folklore weakness and the shelter becomes permanently safe from it. A wrong item is wasted, so the lore matters here too.
- Tuning: `SHELTER_COST` and `MAX_SHELTERS` in `scripts/main.gd`; durability, size and look in `scripts/shelter.gd`; damage per second in `scripts/entity.gd` (`sh.damage(8.0 * delta)`).

## Monster pathfinding
Monsters route around walls using an `AStarGrid2D` built from the level layout (`_build_nav` in `main.gd`, steering in `_dir_to` in `entity.gd`). They walk straight when the line is clear and path around obstacles when it isn't. Hiding behind walls buys you time, not safety.

## Sanity and hallucinations
Below ~45 sanity a pulsing red vignette closes in (faster as it drops), and below that **phantoms** of the region's monster flicker at the edge of your light alongside creepy whispers. They are harmless but look real. Shelters and save points restore sanity. Tune it in `_update_dread` in `main.gd`, and the phantom look in `scripts/phantom.gd`.

## Where to change things
| I want to... | Edit |
|---|---|
| Add or change a monster, its lore clues, weakness, speed | `data/entities.json` |
| Add or change playable characters and perks | `data/characters.json` |
| Add a country/level (colors, intro text, which monster) | `data/regions.json` |
| Add an item | `data/items.json` |
| Add a new monster behavior (AI) | `scripts/entity.gd` (`match behavior:`) |
| Level layout, HUD, game rules | `scripts/main.gd` |
| Shelter behavior | `scripts/shelter.gd` |
| Save format | `scripts/autoload/game_state.gd` |
| Steam features and achievements | `scripts/autoload/steam_manager.gd` |

### Add a creature in 3 steps
1. Add an item in `items.json` if its weakness needs a new one.
2. Add the creature in `entities.json` (copy an existing one). `behavior` can be `stalk`, `gaze`, `charge` or `mimic`.
3. Add a region in `regions.json` pointing to it with `"entity": "your_id"`. Regions play in file order.

Monster behaviors: **stalk** chases once it notices you. **gaze** only moves when you are not looking at it. **charge** winds up, then dashes. **mimic** waits disguised and lures you with sounds, then lunges when you get close.

## Test it
`godot --headless --path . --script tests/playthrough_test.gd` plays through all 8 regions automatically (banish, save, load, death, ending). `tests/shelter_test.gd` covers building, hiding, collapse, warding and save/load of shelters. `tests/features_test.gd` covers monster pathfinding around walls and the low-sanity hallucinations.

## Putting it on Steam
1. Pay the one-time $100 fee at partner.steamgames.com and create your app. You get an App ID.
2. Install the **GodotSteam** plugin (godotsteam.com, use the version that matches your Godot). Put your App ID in `steam_appid.txt` for local testing (480 is Valve's test app).
3. In Godot: Project -> Export, install export templates, add a Windows Desktop preset (and Linux/macOS if you want). Export to `builds/`.
4. Set up achievements in Steamworks. Use the IDs the code already calls, e.g. `ACH_BANISH_ASWANG`, `ACH_SURVIVED_THE_WORLD`.
5. Upload builds with SteamPipe (`steamcmd` + a depot/app build script). Enable Steam Cloud and add `savegame.json` to cloud files.
6. Prepare the store page: capsule art, trailer, screenshots, description, age rating questionnaire. Steam requires the page to be up for a couple of weeks before release, so start early.

## Important: this is a prototype
The art is simple shapes and the levels are generated walls. The systems (data, AI, lore puzzle, saves, journal) are real and tested; swap in your own sprites, 3D, audio and levels when you are ready.

## Cultural respect (please read)
You are drawing on living traditions. For a commercial release:
- Hire **cultural consultants / sensitivity readers** from each tradition. The Wendigo in particular is a serious subject for many Algonquian peoples, and sacred objects (like ofuda) should be treated with respect.
- Credit sources and consultants in-game.
- The weaknesses here are drawn from folklore but adapted for gameplay. Verify and refine them with people from those cultures, and favor local storytellers over film versions.
- ## PSA
- this is not the actual game this is was the first idea of the game concept.
