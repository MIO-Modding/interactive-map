# General Use

Make sure to have the Map, ArchipelagoClient, PlayerState, and Rando tabs open.
The ArchipelagoClient acts as a normal text client and has the commands that go along with it.

### When Playing
You can open the "Filter by" dropdown to choose visibility for certain things on the map, like limiting locations to not found only (I find this helpful)
The map will show you what is considered intended vs simple skips vs advanced skips through the colors of the rooms/transitions/locations (This also applies to the go mode notice)
To find what a location has before checking it, you can press the 'Scout' button (only applies to a few locs)
To hint, just use the normal `!hint` command in the ArchipelagoClient tab.
When you receive items, they will show up as popups in the bottom right corner. You can toggle them waiting until you close them. You can also toggle on a save entry display for easier use.
To change the wheel's rotation, use the option in the map settings.

# How to use this as a tracker

Enter the server's ip, the port, and your slot name in the ArchipelagoClient tab.
Once you've connected, you can switch back to the Map tab.

# How to use this as a manual client

### Downloads & AP Setup
Firstly, download either the manual or regular apworld.
Secondly, download the [archipelago launcher](https://github.com/ArchipelagoMW/Archipelago/releases/latest).
After this, open the launcher and select "Options Creator".
Use the creator to make a yaml file, and save it to the directed folder.
Back in the launcher, choose "Generate".
This should create a zip file in your Output folder, which you should then upload to [archipelago](https://archipelago.gg/uploads).

### Connecting
Once the room is ready, open the interactive map, choose the "ArchipelagoClient" tab and enter the information (slot name is the name you chose for the yaml file, port is the number shown in your archipelago room)
If using the manual, check the "Manual" checkbox.
Click the connect button.

### Playing
To send locations, you just need to check them off. You can do this by clicking, then checking the "Checked" box (or double click with the "Double Click Checks Locations" option on).
To goal, just mark the "Ati Defeated" event as checked.
Events don't automatically check like archipelago does, so when you complete one, mark it on the map.

### Deathlink
Deathlink is supported, you can send it through the PlayerState tab.
