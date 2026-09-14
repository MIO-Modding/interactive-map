class_name LogicLevel extends Resource


## The levels of logic used
enum LogicLevels {
	NONE, ## Out of logic (ool)
	INTENDED_LOGIC, ## The player is intended in the game to be able to reach this room/location.
	SIMPLE_SKIPS, ## The player can preform simple skips to be able to reach this room/location.
	ADVANCED_SKIPS, ## The player can preform advanced skips to be able to reach this room/location.
}

## The associated colors for [enum LogicLevels]
const LEVEL_COLORS: Dictionary[LogicLevels, Color] = {
	LogicLevels.NONE: Color.WHITE,
	LogicLevels.INTENDED_LOGIC: Color.GREEN,
	LogicLevels.SIMPLE_SKIPS: Color.YELLOW,
	LogicLevels.ADVANCED_SKIPS: Color(1.0, 0.5, 0.0),
}


var level
