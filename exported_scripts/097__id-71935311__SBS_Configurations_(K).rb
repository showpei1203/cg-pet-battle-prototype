# RMVX_SCRIPT_INDEX: 97
# RMVX_SCRIPT_ID: 71935311
# RMVX_SCRIPT_NAME: SBS Configurations (K)
# RMVX_SOURCE_SHA256: 6fd97c50f192d3ef85980a5f0f15a765db46fb63bf65a6cf5b5ca8b0e33bf3cc

#==============================================================================
# ■ Sideview Battle System Configurations (English Translation v2.1)
#   Kaduki Version
#------------------------------------------------------------------------------
#  Original Script by: 
#               Enu (http://rpgex.sakura.ne.jp/home/)
#  Original translation versions by: 
#               Kylock
#  Translation continued by:
#               Mr. Bubble
#  Special thanks:
#               Shu (for translation help)
#               Moonlight (for her passionate bug support for this script)
#               NightWalker (for his community support for this script)
#==============================================================================

#~ Kaduki Version by Night'Walker

#==============================================================================
# ■ module N01
#------------------------------------------------------------------------------
#  Sideview Battle System Config
#==============================================================================
module N01
 #--------------------------------------------------------------------------
 # ● Settings
 #-------------------------------------------------------------------------- 
  # Battle member starting positions
  #                   X   Y     X   Y     X   Y     X   Y
  ACTOR_POSITION = [[410,140],[430,175],[450,215],[470,260]]
  # Maximum party members that can fight at the same time.
  # Remember to add/remove coordinates in ACTOR_POSITION if you adjust
  # the MAX_MEMBER value.
  MAX_MEMBER = 4
  
  # Delay time after a battler completes an action in frames.
  ACTION_WAIT = 12
  # Delay time before enemy collapse (defeat of enemy) animation in frames.
  COLLAPSE_WAIT = 12
  # Delay before victory is processed in frames.
  WIN_WAIT = 70
  
  # BattleFloor display options: FLOOR = [ X-pos, Y-pos, Opacity]
  FLOOR = [0,96,128]
  # Animation ID for any unarmed attack.
  NO_WEAPON = 82
  # Damage modifications when using two weapons.  Values are percentages.
  #               1st Wpn, 2nd Wpn
  TWO_SWORDS_STYLE = [100,50]
  # Auto-Life State, Revivial Animation ID
  RESURRECTION = 41
  
  # Damage POP image file name located in the System folder.  Numbers are
  # arranged 0 to 9.
  DAMAGE_GRAPHICS = "Number+"
  # Image file for recovery numbers.
  RECOVER_GRAPHICS = "Number-"
  # Distance between Damage POP display numbers.
  NUM_INTERBAL = -3
  # Duration (in frames) numbers are displayed.
  NUM_DURATION = 68
  # true: Disable Window graphic behind state names.
  NON_DAMAGE_WINDOW = false
  # POP Window indicator words.  For no word results, use "".
  POP_DAMAGE0 = ""            # Attack results 0 damage
  POP_MISS    = "MISS"        # Attack missed　
  POP_EVA     = "EVADE"       # Attack avoided
  POP_CRI     = "CRITICAL"    # Attack scored a critical hit
  POP_MP_DAM  = "MP DAMAGE"   # Attack caused MP loss
  POP_MP_REC  = "MP RECOVER"  # Attack restored MP
  
  # Set to false to remove shadow under actors
  SHADOW = true  
  # true: Use actor's walking graphic. 
  # false: Don't use actor's walking graphic.
  # If false, battler file with "_1" is required since walking file is not used.
  # "_1" and subsequent files ("_2", "_3", etc.) should be uniform in size.
  WALK_ANIME = true
  # Number of frames in a battler animation file. (horizontal frames)
  ANIME_PATTERN = 3
  # Number of types of battler animation file. (vertical frames)
  ANIME_KIND = 4
  
  # Set true to enable back attacks.
  BACK_ATTACK = true
  # Set true to reverse actors in event of back attack.  Not functional.
  BACK_ATTACK_NON_BACK_MIRROR = true
  # Set equipment and skills to protect against back attacks
  # Equipment must be equipped for effect, skills must be aquired
  # and switches must be ON.
  # For a single weapon: = [1]  or Multiple Weapons: = [1,2]
  # WEAPON IDs
  NON_BACK_ATTACK_WEAPONS = []
  # SHIELD IDs
  NON_BACK_ATTACK_ARMOR1 = []
  # HELMET IDs
  NON_BACK_ATTACK_ARMOR2 = []
  # BODY ARMOR IDs
  NON_BACK_ATTACK_ARMOR3 = []
  # ACCESSORY IDs
  NON_BACK_ATTACK_ARMOR4 = []
  # SKILL IDs
  NON_BACK_ATTACK_SKILLS = []
  # SWITCH Number (takes precedence)  If switch is ON, Back attack ensured.
  BACK_ATTACK_SWITCH = []
 
#==============================================================================
# ■ Single Action Engine
#------------------------------------------------------------------------------
# These are utilized by sequenced actions and have no utility alone.
#==============================================================================
 # A single-action cannot be used by itself unless it is used as part of a
 # sequence.
  ANIME = {
 #--------------------------------------------------------------------------
 # ● Battler Animations
 #--------------------------------------------------------------------------
  # No.    - Battler graphic file used.
  #             0: Normal Battler Graphic.  In the case of Actors, 0 refers to
  #                 default walking graphic.
  #             n: "Character Name + _n", where n refers to the file number
  #                 extension.  An example file would be "$Ralph_1".  These 
  #                 files are placed in the Characters folder.
  #                 Use "1" for non-standard battler, like Minkoff's.
  #
  # Row    - Vertical position (row) of cells in battler graphic file. (0~3)
  # Speed  - Refresh rate of animation. Lower numbers are faster.
  # Loop   - [0: "Round-Trip" Loop]    Example: 1 2 3 2 1 2 3 2 ...
  #          [1: "One-Way" Loop]       Example: 1 2 3 1 2 3 1 2 ...
  #          [2: One Loop, no repeat]  Example: 1 2 3 .
  # Wait   - Time, in frames, before animation loops again.
  #          Does not apply if Loop=2
  # Fixed  - Defines loop behavior or specific fixed cell display.
  #          -2: Reverse Loop Animation
  #          -1: Normal Loop Animation
  #           0: No Loop Animation
  #         1~3: Refers to cell on character sprite sheet starting
  #                where 1 = left-most cell.
  # Z      - Set battler's Z priority.
  # Shadow - Set true to display battler shadow during animation; false to hide.
  # Weapon - Weapon animation to play with battler animation.  For no weapon
  #          animation, use "".
  
  # Action Name        No. Row Speed Loop Wait Fixed  Z Shadow  Weapon
  "WAIT"            => [  1,  0,  15,  0,   0,  -1,   0, true,  "" ],
  "WAIT(FIXED)"     => [  1,  0,  10,  2,   0,   1,   0, true,  "" ],
  "RIGHT(FIXED)"    => [  0,  2,  10,  1,   2,   1,   0, true,  "" ],
  "DAMAGE"          => [  1,  1,   5,  2,  24,  -1,   0, true,  "" ],
  "ATTACK_FAIL"     => [  2,  3,  10,  1,   8,   0,   0, true,  "" ],
  "MOVE_TO"         => [  1,  3,  11,  2,   0,  -1,   0, true,  "" ],
  "MOVE_AWAY"       => [  1,  3,  11,  2,   0,  -1,   0, true,  "" ],
  "ABOVE_DISPLAY"   => [  0,  1,   2,  1,   0,  -1, 600, true,  "" ],
  "WPN_SWING_V"     => [  3,  0,   4,  2,   0,  -1,   0, true,"VERT_SWING"],
  "WPN_SWING_VL"    => [  3,  0,   4,  2,   0,  -1,   2, true,"VERT_SWINGL"],
  "WPN_SWING_VS"    => [  3,  0,   8,  2,   0,  -1,   2, true,"VERT_SWING"],
  "WPN_SWING_UNDER" => [  3,  1,   2,  2,   0,  -1,   2, false,"UNDER_SWING"],
  "WPN_SWING_OVER"  => [  0,  1,   2,  2,   0,  -1,   2, false,"OVER_SWING"],
  "WPN_RAISED"      => [  3,  1,   2,  2,  28,  -1,   2, true,"RAISED"],
  "WAIT_CRITICAL"   => [  1,  2,  15,  0,   0,  -1,   0, true,  "" ],
  "SKILL_POSE"      => [  3,  3,   6,  0,   0,  -1,   0, true,  "" ],
  "VICTORY_POSE"    => [  2,  0,  29,  2,   0,  -1,   0, true,  "" ],
  "DEATH_POSE"      => [  2,  3,  10,  1,   0,  -1,   0, false, "" ],
  "EVADING_POSE"    => [  2,  1,   5,  2,   0,  -1,   0, true,  "" ],
  "ATTACK_MOVE"     => [  1,  3,   5,  0,   0,  -1,   0, true, "NO_SWING" ],
  "JUMP_ATTACK"     => [  3,  0,   5,  2,   0,   0,   0, true,  "" ],
  
 #--------------------------------------------------------------------------
 # ● Weapon Animations
 #--------------------------------------------------------------------------
  # Weapon Animations can only be used with Battler Animations as seen 
  # and defined above.
  #
  # Xa - Distance weapon sprite is moved on the X-axis.
  # Ya - Distance weapon sprite is moved on the Y-axis.  Please note that
  #      the Y-axis is inverted. This means negative values move up, positive 
  #      values move down.
  # Za - If true, weapon sprite is displayed over battler sprite.
  #      If false, weapon sprite is displayed behind battler sprite.
  # A1 - Starting angle of weapon sprite rotation.  Negative numbers will 
  #      result in counter-clockwise rotation.
  # A2 - Ending angle of weapon sprite rotation.  Rotation will stop here.
  # Or - Rotation Origin - [0: Center] [1: Upper Left] [2: Upper Right]
  #                        [3:Bottom Left] [4:Bottom Right]
  # Inv - Invert - If true, horizontally inverts weapon sprite.
  # Xs - X scale - Stretches weapon sprite horizontally by a factor of X.
  #                Values may be decimals. (0.6, 0.9, etc.)
  # Ys - Y scale - Stretches weapon sprite vertically by a factor of Y.
  #                Values may be decimals. (0.6, 0.9, etc.)
  # Xp - X pitch - For adjusting the X axis. This number changes the initial 
  #                X coordinate.
  # Yp - Y pitch - For adjusting the Y axis. This number changes the initial 
  #                Y coordinate.
  # Weapon2 - If set to true, Two Weapon Style's Weapon 2 sprite will be used
  #           instead.
  
  # Action Name        Xa   Ya  Za    A1   A2  Or  Inv    Xs  Ys   Xp Yp Weapon2
  "NO_SWING"     => [  0,  0, false, 260, 260,  4, false,  1,  1,  0,  0,false],
  "VERT_SWING"   => [  0,  0, false,-135,  45,  4, false,  1,  1,  0,  0,false],
  "VERT_SWINGL"  => [  0,  0, false,-135,  45,  4, false,  1,  1,  0,  0, true],
  "UNDER_SWING"  => [  6,  8, false, 270,  45,  4, false,  1,  1, -4, -6,false],
  "OVER_SWING"   => [  6,  8, false,  45,-100,  4, false,  1,  1, -4, -6,false],
  "RAISED"       => [  6, -4, false,  90, -45,  4, false,  1,  1, -4, -6,false],

 #--------------------------------------------------------------------------
 # ● Battler Movements
 #--------------------------------------------------------------------------
  # Origin - Defines the origin of movement based on an (x,y) coordinate plane.
  #          1 unit = 1 pixel
  #             [0: Battler's Current Position] 
  #             [1: Battler's Selected Target] 
  #             [2: Screen; (0,0) is at upper-left of screen] 
  #             [3: Battle Start Position]
  # X - X-axis pixels from origin.
  # Y - Y-axis pixels from origin.  Please note that the Y-axis is 
  #     inverted. This means negative values move up, positive values move down.
  # Time - Travel time.  Larger numbers are slower.  The distance is 
  #        divided by one frame of movement.
  # Accel - Positive values accelerates frames.  Negative values decelerates.
  # Jump - Negative values produce a jumping arc.  Positive values produce
  #        a reverse arc.  [0: No jump] 
  # Animation - Battler Animation utilized during moving.
 
  #                           Origin   X   Y  Time  Accel Jump Animation
  "NO_MOVE"                 => [  0,   0,   0,  1,   0,   0,  "WAIT(FIXED)"],
  "START_POSITION"          => [  0,  54,   0,  1,   0,   0,  "MOVE_TO"],
  "BEFORE_MOVE"             => [  3, -32,   0, 18,  -1,   0,  "MOVE_TO"],
  "AFTER_MOVE"              => [  0,  32,   0,  8,  -1,   0,  "MOVE_TO"],
  "4_MAN_ATTACK_1"          => [  2, 444,  96, 18,  -1,   0,  "MOVE_TO"],
  "4_MAN_ATTACK_2"          => [  2, 444, 212, 18,  -1,   0,  "MOVE_TO"],
  "4_MAN_ATTACK_3"          => [  2, 384,  64, 18,  -1,   0,  "MOVE_TO"],
  "4_MAN_ATTACK_4"          => [  2, 384, 244, 18,  -1,   0,  "MOVE_TO"],
  "DEAL_DAMAGE"             => [  0,  32,   0,  4,  -1,   0,  "DAMAGE"],
  "EXTRUDE"                 => [  0,  12,   0,  1,   1,   0,  "DAMAGE"],
  "FLEE_SUCCESS"            => [  0, 300,   0,300,   1,   0,  "MOVE_AWAY"],
  "FLEE_FAIL"               => [  0,  48,   0, 16,   1,   0,  "MOVE_AWAY"],
  "VICTORY_JUMP"            => [  0,   0,   0, 20,   0,  -2,  "VICTORY_POSE"],
  "MOVING_TARGET"           => [  1,   0,   0, 18,  -1,   0,  "MOVE_TO"],
  "MOVING_TARGET_FAST"      => [  1,   0, -12,  8,   0,  -2,  "MOVE_TO"],
  "PREV_MOVING_TARGET"      => [  1,  24,   0, 35,   0,   0,  "ATTACK_MOVE"],
  "PREV_MOVING_TARGET_FAST" => [  1,  24,   0,  1,   0,   0,  "MOVE_TO"],
  "MOVING_TARGET_RIGHT"     => [  1,  96,  32, 16,  -1,   0,  "MOVE_TO"],
  "MOVING_TARGET_LEFT"      => [  1,  96, -32, 16,  -1,   0,  "MOVE_TO"],
  "JUMP_TO"                 => [  0, -32,   0,  8,  -1,  -4,  "MOVE_TO"],
  "JUMP_AWAY"               => [  0,  32,   0,  8,  -1,  -4,  "MOVE_AWAY"],
  "JUMP_TO_TARGET"          => [  1,  12, -12, 12,  -1,  -6,  "MOVE_TO"],
  "THROW_ALLY"              => [  0, -24,   0, 16,   0,  -2,  "MOVE_TO"],
  "TRAMPLE"                 => [  1,  12, -32, 12,  -1,  -6,  "ABOVE_DISPLAY"],
  "PREV_JUMP_ATTACK"        => [  0, -32,   0, 12,  -1,  -2,  "WPN_SWING_V"],
  "PREV_STEP_ATTACK"        => [  1,  12,   0, 12,  -1,  -5,  "WPN_SWING_VS"],
  "REAR_SWEEP_ATTACK"       => [  1,  12,   0, 16,   0,  -3,  "WPN_SWING_V"],
  "JUMP_FIELD_ATTACK"       => [  1,   0,   0, 16,   0,  -5,  "WPN_SWING_V"],
  "DASH_ATTACK"             => [  1, -96,   0, 16,   2,   0,  "WPN_SWING_V"],
  "RIGHT_DASH_ATTACK"       => [  1, -96,  32, 16,   2,   0,  "WPN_SWING_V"],
  "LEFT_DASH_ATTACK"        => [  1, -96, -32, 16,   2,   0,  "WPN_SWING_V"],
  "RIGHT_DASH_ATTACK2"      => [  1,-128,  48, 16,   2,   0,  "WPN_SWING_V"],
  "LEFT_DASH_ATTACK2"       => [  1,-128, -48, 16,   2,   0,  "WPN_SWING_V"],
  "JUMP_BACK"               => [  0, 32,   0,  16,  0,  -4,  "EVADING_POSE"],
  "FRONT_JUMP"              => [  0, -32,   0,  16,  0,  -3,  "JUMP_ATTACK"],
  
 #--------------------------------------------------------------------------
 # ● Battler Float Animations
 #--------------------------------------------------------------------------
  # These types of single-actions defines the movement of battlers from their
  # own shadows.
  #
  # Type - Always "float".
  # A - Starting float height. Negative values move up.
  #                            Positive values move down.
  # B - Ending float height.  This height is maintained until another action.
  # Time - Duration of movement from point A to point B
  # Animation - Specifies the Battler Animation to be used.
  
  #                  　Type     A    B  Time  Animation
  "FLOAT_"      => ["float", -22, -20,  2, "WAIT(FIXED)"],
  "FLOAT_2"     => ["float", -20, -18,  2, "WAIT(FIXED)"],
  "FLOAT_3"     => ["float", -18, -20,  2, "WAIT(FIXED)"],
  "FLOAT_4"     => ["float", -20, -22,  2, "WAIT(FIXED)"],
  "JUMP_STOP"   => ["float",   0, -80,  4, "WAIT(FIXED)"],
  "JUMP_LAND"   => ["float", -80,   0,  4, "WAIT(FIXED)"],
  "LIFT"        => ["float",   0, -30,  4, "WAIT(FIXED)"],
  
 #--------------------------------------------------------------------------
 # ● Battler Position Reset
 #-------------------------------------------------------------------------- 
  # These types of single-actions define when a battler's turn is over and
  # will reset the battler back to its starting coordinates.  This type of
  # single-action is required in all sequences.  
  # 
  # Please note that after a sequence has used this type of single-action, 
  # no more damage can be done by the battler since its turn is over.
  #
  # Type - Always "reset"
  # Time - Time it takes to return to starting coordinates.  Movement speed
  #        fluctuates depending on distance from start coordinates.
  # Accel - Positive values accelerate.  Negative values decelerate.
  # Jump - Negative values produce a jumping arc.  Positive values produce
  #        a reverse arc.  [0: No jump] 
  # Animation - Specifies the Battler Animation to be used.
 
  #                   Type   Time Accel Jump Animation
  "COORD_RESET"   => ["reset", 16,  0,   0,  "MOVE_TO"],
  "FLEE_RESET"    => ["reset", 16,  0,   0,  "MOVE_AWAY"],
  "JUMP_RESET"    => ["reset", 16,  0,  -2,  "MOVE_TO"],
  
 #--------------------------------------------------------------------------
 # ● Forced Battler Actions
 #--------------------------------------------------------------------------
  # These types of single-actions allow forced control of other battlers
  # that you define.
  #
  # Type - Specifies action type.  "SINGLE" or "SEQUENCE"
  #
  # Object -    The battler that will execute the action defined under Action 
  #          Name. 0 is for selected target, and any other number is a State 
  #          number (1~999), and affects all battlers with the State on them.  
  #             By adding a - (minus sign) followed by a Skill ID number (1~999),
  #          it will target the actors that know the specified skill, besides 
  #          the original actor.
  #             If you want to designate an actor by their index ID number, 
  #          add 1000 to their index ID number. If the system cannot designate 
  #          the index number(such as if actor is dead or ran away), it will 
  #          select the nearest one starting from 0.  If a response fails, 
  #          the action will be canceled. (Example: Ylva's actor ID is 4.  A
  #          value of 1004 would define Ylva as the Object.)
  #
  # Reset Type - Specifies method of returning the battler to its original
  #                 location.
  # Action Name - Specifies action used.  If Type is SINGLE, then Action Name
  #               must be a single-action function.  If Type is SEQUENCE, 
  #               the Action Name must an action sequence name.

  #                         Type   Object   Reset Type      Action Name
  "LIGHT_BLOWBACK"    => ["SINGLE",     0,  "COORD_RESET",  "EXTRUDE"],
  "RIGHT_TURN"        => ["SINGLE",     0,  "COORD_RESET",  "CLOCKWISE_TURN"],
  "DROP_DOWN"         => ["SINGLE",     0,  "COORD_RESET",  "Y_SHRINK"],
  "IMPACT_1"          => ["SINGLE",     0,  "COORD_RESET",  "OBJ_TO_SELF"],
  "LIFT_ALLY"         => ["SINGLE",     0,             "",  "LIFT"],
  "ULRIKA_ATTACK"     => ["SEQUENCE",   18, "COORD_RESET",  "ULRIKA_ATTACK_1"],
  "4_MAN_ATK_1"       => ["SEQUENCE", -101, "COORD_RESET",  "4_MAN_ATTACK_1"],
  "4_MAN_ATK_2"       => ["SEQUENCE", -102, "COORD_RESET",  "4_MAN_ATTACK_2"],
  "4_MAN_ATK_3"       => ["SEQUENCE", -103, "COORD_RESET",  "4_MAN_ATTACK_3"],
  "ALLY_FLING"        => ["SEQUENCE", 1000, "COORD_RESET",  "THROW"],
 
 #--------------------------------------------------------------------------
 # ● Target Modification
 #--------------------------------------------------------------------------
  # Changes battler's target in battle.  Original target will still be stored.  
  # Current battler is the only battler capable of causing damage.
  #
  # Type - Always "target"
  #
  # Object -    The battler that will have its target modified.  0 is selected 
  #          target, any other number is a State ID number (1~999), and 
  #          changes all battlers with that state on them to target the new 
  #          designated target.
  #             If you want to designate an actor by their index ID number, 
  #          add 1000 to their index ID number. If the system cannot designate 
  #          the index number(such as if actor is dead or ran away), it will 
  #          select the nearest one starting from 0.  If a response fails, 
  #          the action will be canceled. (Example: Ylva's actor ID is 4.  A
  #          value of 1004 would define Ylva as the Object.)
  #
  # Target - New Target. [0=Self]  [1=Self's Target]
  #                      [2=Self's Target After Modification]
  #                      [3=Reset to Previous Target (if 2 was used)]
  
  # Target Mod name            Type   Object  Target
  "REAL_TARGET"           => ["target",    0,  0],
  "TWO_UNIFIED_TARGETS"   => ["target",   18,  1],
  "FOUR_UNIFIED_TARGETS"  => ["target",   19,  1],
  "ALLY_TO_THROW"         => ["target", 1000,  2],
  "THROW_TARGET"          => ["target", 1000,  3],
  
 #--------------------------------------------------------------------------
 # ● Skill Linking
 #--------------------------------------------------------------------------
  # Linking to the next skill will stop any current action.  Linking to the 
  # next skill will also require and consume MP/HP cost of that skill.
  #
  # Type - Always "der"
  # Chance - Chance, in percent, to link to the defined skill ID. (0~100)
  # Link - true: actor does not require Skill ID learned to link.
  #        false: actor requires Skill ID learned.
  # Skill ID - ID of the skill that will be linked to.
  
  # Action Name           Type  Chance Link Skill ID
  "LINK_SKILL_91"     => ["der", 100, true,  91],
  "LINK_SKILL_92"     => ["der", 100, true,  92],

 #--------------------------------------------------------------------------
 # ● Action Conditions
 #--------------------------------------------------------------------------
  # If the condition is not met, all current actions are canceled.
  #
  # A: Type - always "nece"
  # B: Object - Object that Condition refers to. [0=Self] [1=Target] 
  #                                           [2=All Enemies] [3=All Allies]
  # C: Content - [0=State] [1=Parameter] [2=Switch] [3=Variable] [4=Skill]
  # 
  # D: Condition - This value is determined by the value you set for Content.
  # [0] State: State ID
  # [1] Parameter: [0=HP] [1=MP] [2=Atk Pwr] [3=Def Pwr] [4=Spirit] [5=Agility]
  # [2] Switch: Game Switch Number
  # [3] Variable: Game Variable Number
  # [4] Skill: Skill ID
  #
  # E: Supplement - Supplement for the Condition as defined above.
  # [0] State: Amount required.  If number is positive, the condition is how 
  #            many have the state, while a negative number are those who 
  #            don't have the state.
  # [1] Parameter: If Object is more than one battler, average is used.
  #                Success if Parameter is greater than value.  If Value
  #                is negative, then success if lower.
  # [2] Switch: [true: Switch ON succeeds] [false: Switch OFF succeeds]
  # [3] Variable: Game variable value used to determine if condition is met.  If
  #               supplement value is positive, Game Variable must have more
  #               than the defined amount to succeed.  If supplement value has a
  #               minus symbol (-) attached, Game Variable must have less than
  #               the defined amount to succeed.  (Ex: -250 means the Game
  #               Variable must have a value less than 250 to succeed.)
  # [4] Skill: Required amount of battlers that have the specified skill 
  #            ID learned.
  
  #                       Type  Obj  Cont  Cond   Supplement
  #                         A     B   C    D    E
  "2_MAN_ATK_COND"  => ["nece",   3,  0,  18,   1],
  "4_MAN_ATK_COND"  => ["nece",   3,  0,  19,   3],
  "FLOAT_STATE"     => ["nece",   0,  0,  17,   1],
  "CAT_STATE"       => ["nece",   0,  0,  20,   1],
  
 #--------------------------------------------------------------------------
 # ● Battler Rotation
 #--------------------------------------------------------------------------
  # Rotates battler image.  Weapon Animations are not automatically adjusted
  # for Battler Rotation like with Invert settings.
  #
  # Type - always "angle"
  # Time - Duration duration of rotation animation in frames.
  # Start - Starting angle. 0-360 degrees.  Negative values = counter clockwise.
  # End - Ending Angle. 0-360 degress.  Negative values = counter clockwise.
  # Return - true: End of rotation is the same as end of duration.
  #          false: Rotation animation as defined.
 
  #                           Type   Time Start  End  Return
  "FALLEN"                => ["angle",  1, -90, -90,false],
  "CLOCKWISE_TURN"        => ["angle", 48,   0,-360,false],
  "COUNTERCLOCKWISE_TURN" => ["angle",  6,   0, 360,false],

 #--------------------------------------------------------------------------
 # ● Battler Zoom
 #--------------------------------------------------------------------------
  # Stretch and shrink battler sprites with these single-actions.
  #
  # Type - always "zoom"
  # Time - Duration of zoom animation in frames.
  # X - X scale - Stretches battler sprite horizontally by a factor of X.
  #               1.0 is normal size, 0.5 is half size.
  # Y - Y scale - Stretches battler sprite vertically by a factor of Y.
  #               1.0 would be normal size, 0.5 would be half size.
  # Return - true: End of rotation is the same as end of duration.
  #          false: Zoom animation as defined.
  #          Battler zoom is still temporary.
 
  #             　     Type  Time   X    Y   Return
  "X_SHRINK"         => ["zoom", 16, 0.5, 1.0, true],
  "Y_SHRINK"         => ["zoom", 16, 1.0, 0.5, true],
  
 #--------------------------------------------------------------------------
 # ● Damage and Database-Assigned Animations
 #--------------------------------------------------------------------------
  # These single-actions deal with animations, particularly with those assigned 
  # in the Database for Weapons, Skills and Items.  These are what causes
  # any damage/healing/state/etc. application from Weapons, Skills and Items. 
  #
  # A difference between "anime" and "m_a" single-actions is that 
  # "anime" triggered animations will move with the Object on the screen.  The
  # Z-axis of animations will always be over battler sprites.  If "OBJ_ANIM" 
  # is added at the beginning of the name, it will be both damage and defined
  # animation.
  #
  # Type - always "anime"
  # ID - (-1): Uses assigned animation from game Database.
  #      (-2): Uses equipped Weapon animation as assigned in the Database.
  #   (1~999): Database Animation ID.
  # Object - [0=Self] [1=Target] 
  # Invert - If set to true, the animation is inverted horizontally.
  # Wait - true: Sequence will not continue until animation is completed.
  #        false: Sequence will continue regardless of animation length.
  # Weapon2 - true: If wielding two weapons, damage and animation will be
  #                 based off Weapon 2.
  
  #                         Type   ID  Object Invert  Wait  Weapon2
  "OBJ_ANIM"          => ["anime",  -1,  1,   false,  false, false],
  "OBJ_ANIM_WEIGHT"   => ["anime",  -1,  1,   false,   true, false],
  "OBJ_ANIM_WEAPON"   => ["anime",  -2,  1,   false,  false, false],
  "OBJ_ANIM_L"        => ["anime",  -1,  1,   false,  false,  true],
  "HIT_ANIM"          => ["anime",   1,  1,   false,  false, false],
  "KILL_HIT_ANIM"     => ["anime",  11,  1,   false,  false, false],
   
 #--------------------------------------------------------------------------
 # ● Movement and Display of Animations
 #--------------------------------------------------------------------------
  # These single-actions provide motion options for animations used for 
  # effects such as long-ranged attacks and projectiles.  Weapon sprites
  # may also substitute animations.
  #
  # A difference between "m_a" and "anime" single-actions is that "m_a"
  # animations will stay where the Object was even if the Object moved.
  #
  # Type - always "m_a"
  # ID - 1~999: Database Animation ID
  #          0: No animation displayed.
  # Object - Animation's target. [0=Target] [1=Enemy's Area] 
  #                              [2=Party's Area] [4=Self]
  # Pass -  [0: Animation stops when it reaches the Object.] 
  #         [1: Animation passes through the Object and continues.] 
  # Time - Duration of animation travel time and display.  Larger values
  #        decrease travel speed.  Increase this value if the animation
  #        being played is cut short.
  # Arc - Trajectory - Positive values produce a low arc. 
  #                    Negative values produce a high arc.
  #                    [0: No Arc]
  # Xp - X Pitch - This value adjusts the initial X coordinate of the 
  #                animation. Enemy calculation will be automatically inverted.
  # Yp - Y Pitch - This value adjusts the initial X coordinate of the 
  #                animation.
  # Start - Defines origin of animation movement.
  #              [0=Self] [1=Target] [2=No Movement] 
  # Z-axis - true: Animation will be over the battler sprite.
  #          false: Animation will be behind battler sprite.
  # Weapon - Insert only "Throwing Weapon Rotation" and
  #          "Throwing Skill Rotation" actions.  If ID is not 0, use "".
  
  #                        Type   ID Object Pass Time Arc  Xp Yp Start Z Weapon
  "START_MAGIC_ANIM"  => ["m_a", 86,   4,  0,  50,   0,  0,  0, 0,false,""],
  "OBJ_TO_SELF"         => ["m_a",  4,   0,  0,  24,   0,  0,  0,  1,false,""],
  "START_WEAPON_THROW"  => ["m_a",  0,   0,  0,  18, -24,  0,  0,  0,false,"WPN_ROTATION"],
  "END_WEAPON_THROW"    => ["m_a",  0,   0,  0,  18,  24,  0,  0,  1,false,"WPN_ROTATION"],
  "STAND_CAST"          => ["m_a", 80,   1,  0,  64,   0,  0,  0,  2, true,""],
  
 #--------------------------------------------------------------------------
 # ● Throwing Weapon Rotation
 #--------------------------------------------------------------------------
  # These are used to rotate weapon sprites that are "thrown" with Movement of
  # Animation single-actions.  These must be used while the sprite is in flight.
  # You may assign a different weapon graphic to be thrown in this 
  # configuration script under Throwing Weapon Graphic Settings.
  #
  # Start - Starting angle in degrees (0-360)
  # End - Ending angle in degrees. (0-360)
  # Time - Duration, in frames, of a single rotation.  Rotation will continue
  #        until the animation is complete.
  
  #                     Start  Angle  Time
  "WPN_ROTATION"     => [   0, 360,  8],
  
 #--------------------------------------------------------------------------
 # ● Throwing Skill Rotation
 #--------------------------------------------------------------------------
  # Different from Throwing Weapon Rotation. These single-actions are used to 
  # rotate weapon sprites that are "thrown" with Movement of Animation single 
  # actions. These are specifically used with skills.  These must be used while 
  # the sprite is in flight. You may assign a different weapon graphic to be 
  # thrown in this configuration script under Throwing Weapon Graphic Settings.  
  #
  # Start - Starting angle in degrees (0-360)
  # End - Ending angle in degrees. (0-360)
  # Time - Duration, in frames, of a single rotation.  Rotation will continue
  #        until the animation is complete.
  # Type - Always "skill".
  
  # Weapon Action Name　　   Start  End Time  Type
  "WPN_THROW"           => [   0, 360,  8, "skill"],
  
 #--------------------------------------------------------------------------
 # ● Status Balloon Animation
 #--------------------------------------------------------------------------
  # Uses Balloon.png in the System folder.
  #
  # Type - Always "balloon"
  # Row - Determines row from the Balloon.png (0~9)
  # Loop - Balloon loop behavior.  Balloon disappears when loop is
  #        complete. [0="One-Way" Loop] [1="Round-Trip" Loop]
  
  # Emote Name　　       Type        Row  Loop
  "STATUS-NORMAL"   => ["balloon",   6,  1],
  "STATUS-CRITICAL" => ["balloon",   5,  1],
  "STATUS-SLEEP"    => ["balloon",   9,  1],
  
 #--------------------------------------------------------------------------
 # ● Sound Effect Actions
 #--------------------------------------------------------------------------
  # Type - always "sound"
  # Type - ["se","bgm","bgs"]
  # Pitch - Value between 50 and 150.
  # Vol - Volume - Value between 0 and 100.
  # Filename - Name of the sound to be played.
  
  #                    Type   Type  Pitch Vol   Filename
  "absorb1"       => ["sound", "se",  80, 100, "absorb1"],
  
 #--------------------------------------------------------------------------
 # ● Game Speed Modifier
 #--------------------------------------------------------------------------
  # Type - always "fps"
  # Speed - Speed in Frames Per Second.  60 is normal frame rate.
  # Use with care as this function modifies FPS directly and will conversly
  #    affect any active timers or time systems.
  
  #                Type  Speed
  "FPS_SLOW"    => ["fps",  20],
  "FPS_NORMAL"  => ["fps",  60],
  
 #--------------------------------------------------------------------------
 # ● State Granting Effects
 #--------------------------------------------------------------------------
  # Type - always "sta+"
  # Object - [0=Self] [1=Target] [2=All Enemies] [3=All Allies] 
  #          [4=All Allies (excluding user)]
  # State ID - State ID to be granted.
  
  #                      Type  Object  State ID
  "2_MAN_TECH_GRANT" => ["sta+",  0,  18],
  "4_MAN_TECH_GRANT" => ["sta+",  0,  19],
  "CATFORM_GRANT"    => ["sta+",  0,  20],
  
 #--------------------------------------------------------------------------
 # ● State Removal Effects
 #--------------------------------------------------------------------------
  # Type - always "sta-"
  # Object - [0=Self] [1=Target] [2=All Enemies] [3=All Allies] 
  #          [4=All Allies (excluding user)]
  # State ID - State ID to be removed.
  
  #                    Type  Object  State ID
  "2_MAN_TECH_REVOKE" => ["sta-",  3,  18],
  "4_MAN_TECH_REVOKE" => ["sta-",  3,  19],

 #--------------------------------------------------------------------------
 # ● Battler Transformation Effects
 #--------------------------------------------------------------------------
  # Type - always "change"
  # Reset - true: Battler sprite reverts back to default file after battle.
  #         false: Transformation is permanent after battle.
  # Filename - Battler graphics file that will be transformed to.
  
  #                         Type   Reset  Filename
  "TRANSFORM_CAT"     => ["change", true,"$cat"],
  "TRANSFORM_CANCEL"  => ["change", true,"$ylva"],
  
 #--------------------------------------------------------------------------
 # ● Cut-In Image Effects
 #--------------------------------------------------------------------------
  # Only one image can be displayed at a time.
  #
  # X1 - Image's starting X-coordinate.
  # Y1 - Starting Y-coordinate.
  # X2 - Ending X-coordinate.
  # Y2 - Ending Y-coordinate.
  # Time - Length of time from start to end. Higher value is slower.
  # Z-axis - true: Image appears over BattleStatus Window.
  #          false: Image appears behind BattleStatus Window.
  # Filename - Filename from .Graphics\Pictures folder.
 
  #                    Type    X1   Y1   X2   Y2 Time Z-axis  Filename
  "CUT_IN_START"   => ["pic", -280, 48,   0,  64, 14, false, "Actor2-3"],
  "CUT_IN_END"     => ["pic",   0,  48, 550,  64, 12, false, "Actor2-3"],
  
 #--------------------------------------------------------------------------
 # ● Game Switch Settings 
 #--------------------------------------------------------------------------
  # Type - Always "switch"
  # Switch - Switch number from the game database.
  # ON/OFF - [true:Switch ON] [false:Switch OFF]
  # 
  #                         Type    Switch  ON/OFF
  "GAME_SWITCH_1_ON"    => ["switch",   1,  true],
  
 #--------------------------------------------------------------------------
 # ● Game Variable Settings 
 #--------------------------------------------------------------------------
  # Type - Always "variable"
  # Var - Variable Number from the game database.
  # Oper - [0=Set] [1=Add] [2=Sub] [3=Mul] [4=Div] [5=Mod] 
  # X - value of the operation.
  # 
  #           　　            Type       Var   Oper   X
  "GAME_VAR_1_+1"       => ["variable",   1,   1,    1],
  
 #--------------------------------------------------------------------------
 # ● Script Operation Settings
 #--------------------------------------------------------------------------
  # Type - Always "script"
  # 
  # Inserts a simple script code into the action sequence. In the sample, 
  # where it says p=1 can be replaced with any script. Character strings 
  # and anything beyond functions will not work. (?) 
  # 　              　　  Type    
  "TEST_SCRIPT"   => ["script", " 
  
  p = 1 
  
  "],
  
 #--------------------------------------------------------------------------
 # ● Special Modifiers - DO NOT CHANGE THESE NAMES
 #--------------------------------------------------------------------------
  # Clear image - Clears images such as Cut-in graphics.
  # Afterimage ON - Activates Afterimage of battler.
  # Afterimage OFF - Deactivates Afterimage.
  # Invert - Invert animation. Use Invert again in a sequence to cancel
  #          because "COORD_RESET" does not reset Invert.
  # Don't Wait - Any actions after Don't Wait is applied are done instantly.  
  #              Apply "Don't Wait" again in a sequence to trigger off.
  # Can Collapse - Triggers collapse of battler when HP is 0.
  #                Required in every damage sequence.
  # Two Wpn Only - The Single Action following Two Wpn Only will only execute
  #                if the actor is wielding two weapons.  If the actor is not,
  #                the Single Action will be skipped and will move on to the next.
  # One Wpn Only - The Single Action following One Wpn Only will only execute
  #                if the actor is wielding one weapon.  If the actor is not,
  #                the Single Action will be skipped and will move on to the next.
  # Process Skill - The Return marker for individual processing of a skill.
  # Process Skill End - The End marker for individual processing of a skill.
  # Start Pos Change - Changes the Start Position to wherever the battler
  #                    currently is on screen.
  # Start Pos Return - Returns battler to original Start Position.
  # Cancel Action - Trigger the "end" of battler's turn which will cause the
  #                 the next battler's turn to execute.
  #                 This includes the function of Can Collapse, and no 
  #                 additional damage can be dealt by the battler after this.
  # End - This is used when no action is automatically recognized.
  #
  # Note: If you wish to understand how Process Skill and Process Skill End 
  #       functions, please examine the "SKILL_ALL" sequence in this Config
  #       and use the Float All skill provided in the demo to see how it works.
  
  "Clear image"    => ["Clear image"],
  "Afterimage ON"          => ["Afterimage ON"],
  "Afterimage OFF"         => ["Afterimage OFF"],
  "Invert"            => ["Invert"],
  "Don't Wait"=> ["Don't Wait"],
  "Can Collapse"    => ["Can Collapse"],
  "Two Wpn Only"        => ["Two Wpn Only"],
  "One Wpn Only"      => ["One Wpn Only"],
  "Process Skill"    => ["Process Skill"],
  "Process Skill End"    => ["Process Skill End"],
  "Start Pos Change"    => ["Start Pos Change"],
  "Start Pos Return"=> ["Start Pos Return"],
  "Cancel Action"  => ["Cancel Action"],
  "End"            => ["End"]
  
 #--------------------------------------------------------------------------
 # ● About Wait
 #--------------------------------------------------------------------------
  # When there is only a numerical value as a single-action name, it will be 
  # considered a delay, in frames, before the Action Sequence continues. 
  # (i.e. "10", "42")  Because of this, single-action function names for the
  # effects defined above cannot be entirely numerical.  Any Battler Animations 
  # that have been prompted will persist when Waiting.
  }
#==============================================================================
# ■ Action Sequence
#------------------------------------------------------------------------------
# Action sequences are made of the single-action functions defined above.
#==============================================================================
  # Action Sequences defined here can be used for Actor/Enemy actions below.
  # Sequences are processed left to right in order.
  ACTION = {
#------------------------------- Basic Actions --------------------------------
  
  "BATTLE_START"          => ["START_POSITION","COORD_RESET"],
                          
  "WAIT"              => ["WAIT"],
                          
  "WAIT-CRITICAL" => ["WAIT_CRITICAL"],
                          
  "WAIT-NORMAL"      => ["NO_MOVE","WAIT(FIXED)","STATUS-NORMAL","22"],
                          
  "WAIT-SLEEP"          => ["NO_MOVE","WAIT(FIXED)","STATUS-SLEEP","22"],
                          
  "WAIT-FLOAT"          => ["WAIT(FIXED)","6","FLOAT_","4",
                          "FLOAT_2","4","FLOAT_3","4",
                          "FLOAT_4","4"],
                          
  "DEAD"              => ["DEATH_POSE"],
                          
  "DAMAGE"          => ["DEAL_DAMAGE","COORD_RESET"],
                          
  "FLEE"              => ["FLEE_SUCCESS"],
                          
  "ENEMY_FLEE"      => ["FLEE_SUCCESS","COORD_RESET"],
                          
  "FLEE_FAIL"          => ["FLEE_FAIL","WAIT(FIXED)","8","COORD_RESET"],
                          
  "COMMAND_INPUT"      => ["BEFORE_MOVE"],
                          
  "COMMAND_SELECT"    => ["COORD_RESET"],
                          
  "GUARD_ATTACK"              => ["WAIT(FIXED)","4","FLOAT_STATE","FLOAT_",
                          "2","FLOAT_2","2","FLOAT_3","2",
                          "FLOAT_4","2"],
                          
  "EVADE_ATTACK"              => ["JUMP_BACK","15","JUMP_RESET"],
                          
  "ENEMY_EVADE_ATTACK"      => ["JUMP_BACK","15","JUMP_RESET"],
                          
  "VICTORY" => ["VICTORY_JUMP",
  "Don't Wait","CAT_STATE",
  "START_MAGIC_ANIM","TRANSFORM_CANCEL","WAIT(FIXED)","Don't Wait",],
                          
  "RESET_POSITION"          => ["COORD_RESET"],
                          
#------------------------- "Forced Action" Sequences -----------------------------
                          
  "ULRIKA_ATTACK_1" => ["2","MOVING_TARGET_LEFT","WAIT(FIXED)",
                          "START_MAGIC_ANIM","WPN_SWING_UNDER","WPN_RAISED",
                          "48","RIGHT_DASH_ATTACK","64","FLEE_RESET"], 
                          
  "4_MAN_ATTACK_1"     => ["2","4_MAN_ATTACK_2","WAIT(FIXED)","START_MAGIC_ANIM",
                          "WPN_SWING_UNDER","WPN_RAISED","90",
                          "LEFT_DASH_ATTACK","96","FLEE_RESET"],
                          
  "4_MAN_ATTACK_2"     => ["2","4_MAN_ATTACK_3","WAIT(FIXED)","START_MAGIC_ANIM",
                          "WPN_SWING_UNDER","WPN_RAISED","60","RIGHT_DASH_ATTACK2","RIGHT_TURN",
                          "OBJ_ANIM","128","FLEE_RESET"],
                          
  "4_MAN_ATTACK_3"     => ["2","4_MAN_ATTACK_4","WAIT(FIXED)","START_MAGIC_ANIM",
                          "WPN_SWING_UNDER","WPN_RAISED","34","LEFT_DASH_ATTACK2","RIGHT_TURN",
                          "OBJ_ANIM","144","FLEE_RESET"],
                          
  "THROW"    => ["CLOCKWISE_TURN","4","MOVING_TARGET_FAST","JUMP_AWAY","4",
                          "WAIT(FIXED)","JUMP_AWAY","WAIT(FIXED)","32"],
                          
#---------------------- Basic Action Oriented ------------------------------
  
  "NORMAL_ATTACK"          => ["PREV_MOVING_TARGET","WPN_SWING_V","OBJ_ANIM_WEIGHT",
                          "12","WPN_SWING_VL","OBJ_ANIM_L","One Wpn Only","16",
                          "Can Collapse","FLEE_RESET"],
                          
  "ENEMY_UNARMED_ATK"    => ["PREV_MOVING_TARGET","WPN_SWING_V","OBJ_ANIM_WEIGHT",
                          "Can Collapse","FLEE_RESET"],
                          

  "SKILL_USE"    => ["BEFORE_MOVE","SKILL_POSE","24","START_MAGIC_ANIM",
                      "OBJ_ANIM_WEIGHT","Can Collapse","24","COORD_RESET"],
                      
  "SKILL_ALL"=> ["BEFORE_MOVE","START_MAGIC_ANIM","WPN_SWING_UNDER","WPN_RAISED",
                          "Process Skill","WPN_SWING_V","OBJ_ANIM","24",
                          "Process Skill End","Can Collapse","COORD_RESET"],
                          
  "ITEM_USE"      => ["PREV_MOVING_TARGET","WAIT(FIXED)","24","OBJ_ANIM_WEIGHT",
                  "Can Collapse","COORD_RESET"],
#------------------------------ Skill Sequences -------------------------------
  
  "MULTI_ATTACK"          => ["Afterimage ON","PREV_STEP_ATTACK","WPN_SWING_VL","OBJ_ANIM_WEAPON",
                          "WAIT(FIXED)","16","OBJ_ANIM_WEAPON","WPN_SWING_UNDER",
                          "WPN_SWING_OVER","4","JUMP_FIELD_ATTACK","WPN_SWING_VL",
                          "OBJ_ANIM_WEAPON","WAIT(FIXED)","16","OBJ_ANIM_WEAPON",
                          "Invert","WPN_SWING_V","WPN_SWING_VL","12","Invert",
                          "JUMP_FIELD_ATTACK","WPN_SWING_VL","OBJ_ANIM_WEAPON",
                          "JUMP_AWAY","JUMP_AWAY","WAIT(FIXED)",
                          "OBJ_ANIM_WEAPON","DASH_ATTACK","WPN_SWING_VL","Can Collapse",
                          "Afterimage OFF","16","FLEE_RESET"],
                          
  "MULTI_ATTACK_RAND"=> ["PREV_STEP_ATTACK","WPN_SWING_VL","OBJ_ANIM_WEAPON","WAIT(FIXED)","16",
                          "PREV_STEP_ATTACK","WPN_SWING_VL","OBJ_ANIM_WEAPON","WAIT(FIXED)","16",
                          "PREV_STEP_ATTACK","WPN_SWING_VL","OBJ_ANIM_WEAPON","WAIT(FIXED)","16",
                          "PREV_STEP_ATTACK","WPN_SWING_VL","OBJ_ANIM_WEAPON","Can Collapse","COORD_RESET"],
                          
  "RAPID_MULTI_ATTACK"      => ["PREV_MOVING_TARGET","WPN_SWING_V","LIGHT_BLOWBACK","OBJ_ANIM_WEAPON",
                          "PREV_MOVING_TARGET_FAST","WPN_SWING_V","LIGHT_BLOWBACK","WPN_SWING_VL","OBJ_ANIM_WEAPON",
                          "PREV_MOVING_TARGET_FAST","WPN_SWING_V","LIGHT_BLOWBACK","WPN_SWING_VL","OBJ_ANIM_WEAPON",
                          "PREV_MOVING_TARGET_FAST","WPN_SWING_V","LIGHT_BLOWBACK","WPN_SWING_VL","OBJ_ANIM_WEAPON",
                          "PREV_MOVING_TARGET_FAST","WPN_SWING_V","LIGHT_BLOWBACK","WPN_SWING_VL","OBJ_ANIM_WEAPON",
                          "PREV_MOVING_TARGET_FAST","WPN_SWING_V","LIGHT_BLOWBACK","WPN_SWING_VL","OBJ_ANIM_WEAPON",
                          "Can Collapse","12","COORD_RESET"],
                          
  "2-MAN_ATTACK"      => ["2_MAN_ATK_COND","TWO_UNIFIED_TARGETS","ULRIKA_ATTACK",
                          "MOVING_TARGET_RIGHT","WAIT(FIXED)","START_MAGIC_ANIM","WPN_SWING_UNDER",
                          "WPN_RAISED","48","KILL_HIT_ANIM","LEFT_DASH_ATTACK","64","OBJ_ANIM",
                          "Can Collapse","FLEE_RESET","2_MAN_TECH_REVOKE"],
                          
  "2-MAN_ATTACK_ASSIST"  => ["2_MAN_TECH_GRANT"],  
                          
  "4-MAN_ATTACK"      => ["4_MAN_ATK_COND","FOUR_UNIFIED_TARGETS","4_MAN_ATK_1",
                          "4_MAN_ATK_2","4_MAN_ATK_3","4_MAN_ATTACK_1","WAIT(FIXED)",
                          "START_MAGIC_ANIM","WPN_SWING_UNDER","WPN_RAISED","90",
                          "KILL_HIT_ANIM","RIGHT_DASH_ATTACK","64","OBJ_ANIM_WEIGHT",
                          "Can Collapse","FLEE_RESET","合体攻撃解除"],
                          
  "4-MAN_ATTACK_ASSIST"  => ["4_MAN_TECH_GRANT"],
                          
  "THROW_WEAPON"          => ["BEFORE_MOVE","WPN_SWING_V","absorb1","WAIT(FIXED)",
                          "START_WEAPON_THROW","12","OBJ_ANIM_WEAPON","Can Collapse",
                          "END_WEAPON_THROW","COORD_RESET"],
                          
  "MULTI_SHOCK"=> ["JUMP_TO","JUMP_STOP","Process Skill",
                          "REAL_TARGET","WPN_SWING_V","IMPACT_1","8",
                          "OBJ_ANIM_WEAPON","Process Skill End","Can Collapse",
                          "JUMP_LAND","COORD_RESET"],
                          
  "SHOCK_WAVE"    => ["REAL_TARGET","WPN_SWING_V","IMPACT_1","20",
                          "OBJ_ANIM_WEIGHT","Can Collapse"],
                         
  "SKILL_90_SEQUENCE"      => ["PREV_MOVING_TARGET","OBJ_ANIM","WPN_SWING_V",
                          "16","LINK_SKILL_91","COORD_RESET"],
                          
  "SKILL_91_SEQUENCE"        => ["FLEE_FAIL","START_MAGIC_ANIM","WPN_SWING_UNDER","WPN_RAISED",
                          "8","OBJ_ANIM","LINK_SKILL_92","COORD_RESET"],
                          
  "CUT_IN"        => ["WAIT(FIXED)","START_MAGIC_ANIM","CUT_IN_START",
                          "75","CUT_IN_END","8","PREV_MOVING_TARGET",
                          "WPN_SWING_V","OBJ_ANIM_WEIGHT","Can Collapse",
                          "Clear image","FLEE_RESET"],
                          
  "STOMP"          => ["JUMP_TO_TARGET","HIT_ANIM","DROP_DOWN","JUMP_AWAY",
                          "TRAMPLE","HIT_ANIM","DROP_DOWN","JUMP_AWAY",
                          "TRAMPLE","OBJ_ANIM","DROP_DOWN","JUMP_AWAY",
                          "JUMP_AWAY","Can Collapse","WAIT(FIXED)","8","FLEE_RESET"],
                          
  "ALL_ATTACK_1"         => ["BEFORE_MOVE","WAIT(FIXED)","START_MAGIC_ANIM","WPN_SWING_UNDER",
                          "WPN_RAISED","STAND_CAST","WPN_SWING_V","48",
                          "OBJ_ANIM_WEIGHT","Can Collapse","COORD_RESET"],
                          
  "TRANSFORM_CAT"        => ["JUMP_TO","WAIT(FIXED)","START_MAGIC_ANIM","32",
                          "TRANSFORM_CAT","WAIT(FIXED)","CATFORM_GRANT","32","JUMP_AWAY"],                     
                          
  "THROW_FRIEND"      => ["ALLY_TO_THROW","MOVING_TARGET","LIFT_ALLY","4",
                          "absorb1","THROW_TARGET","ALLY_FLING",
                          "THROW_ALLY","WAIT(FIXED)","OBJ_ANIM","COORD_RESET",
                          "WAIT(FIXED)","32"],                          
                          
                          
#------------------------------------------------------------------------------- 
  "End"              => ["End"]}
end
#==============================================================================
# ■ Game_Actor
#------------------------------------------------------------------------------
# 　Actor Basic Action Settings
#==============================================================================
class Game_Actor < Game_Battler
  #--------------------------------------------------------------------------
  # ● Actor Unarmed Attack Animation Sequence
  #-------------------------------------------------------------------------- 
  # when 1 <- Actor ID number
  #   return "NORMAL_ATTACK" <- Corresponding action sequence name.
  def non_weapon
    case cg_database_actor_id
    when 1 # Actor ID
      return "NORMAL_ATTACK"
    end
    # Default action for all unassigned Actor IDs.
    return "NORMAL_ATTACK"
  end
  #--------------------------------------------------------------------------
  # ● Actor Wait/Idle Animation
  #-------------------------------------------------------------------------- 
  def normal
    case cg_database_actor_id
    when 1
      return "WAIT"
    end
    # Default action for all unassigned Actor IDs.
    return "WAIT"
  end
  #--------------------------------------------------------------------------
  # ● Actor Critical (1/4th HP) Animation
  #-------------------------------------------------------------------------- 
  def pinch
    case cg_database_actor_id
    when 1
      return "WAIT-CRITICAL"
    end
    # Default action for all unassigned Actor IDs.
    return "WAIT-CRITICAL"
  end
  #--------------------------------------------------------------------------
  # ● Actor Guarding Animation
  #-------------------------------------------------------------------------- 
  def defence
    case cg_database_actor_id
    when 1
      return "GUARD_ATTACK"
    end
    # Default action for all unassigned Actor IDs.
    return "GUARD_ATTACK"
  end
  #--------------------------------------------------------------------------
  # ● Actor Damage Taken Animation
  #-------------------------------------------------------------------------- 
  def damage_hit
    case cg_database_actor_id
    when 1
      return "DAMAGE"
    end
    # Default action for all unassigned Actor IDs.
    return "DAMAGE"
  end  
  #--------------------------------------------------------------------------
  # ● Actor Evasion Animation
  #-------------------------------------------------------------------------- 
  def evasion
    case cg_database_actor_id
    when 1
      return "EVADE_ATTACK"
    end
    # Default action for all unassigned Actor IDs.
    return "EVADE_ATTACK"
  end  
  #--------------------------------------------------------------------------
  # ● Actor Command Input Animation
  #-------------------------------------------------------------------------- 
  def command_b
    case cg_database_actor_id
    when 1
      return "COMMAND_INPUT"
    end
    # Default action for all unassigned Actor IDs.
    return "COMMAND_INPUT"
  end
  #--------------------------------------------------------------------------
  # ● Actor Command Selected Animation
  #-------------------------------------------------------------------------- 
  def command_a
    case cg_database_actor_id
    when 1
      return "COMMAND_SELECT"
    end
    # Default action for all unassigned Actor IDs.
    return "COMMAND_SELECT"
  end
  #--------------------------------------------------------------------------
  # ● Actor Flee Success Animation
  #-------------------------------------------------------------------------- 
  def run_success
    case cg_database_actor_id
    when 1
      return "FLEE"
    end
    # Default action for all unassigned Actor IDs.
    return "FLEE"
  end
  #--------------------------------------------------------------------------
  # ● Actor Flee Failure Animation
  #-------------------------------------------------------------------------- 
  def run_ng
    case cg_database_actor_id
    when 1
      return "FLEE_FAIL"
    end
    # Default action for all unassigned Actor IDs.
    return "FLEE_FAIL"
  end
  #--------------------------------------------------------------------------
  # ● Actor Victory Animation
  #-------------------------------------------------------------------------- 
  def win
    case cg_database_actor_id
    when 1
      return "VICTORY"
    end
    # Default action for all unassigned Actor IDs.
    return "VICTORY"
  end
  #--------------------------------------------------------------------------
  # ● Actor Battle Start Animation
  #--------------------------------------------------------------------------  
  def first_action
    case cg_database_actor_id
    when 1
      return "BATTLE_START"
    end
    # Default action for all unassigned Actor IDs.
    return "BATTLE_START"
  end
  #--------------------------------------------------------------------------
  # ● Actor Return Action when actions are interuptted/canceled
  #--------------------------------------------------------------------------  
  def recover_action
    case cg_database_actor_id
    when 1
      return "RESET_POSITION"
    end
   # Default action for all unassigned Actor IDs.
    return "RESET_POSITION"
  end
  #--------------------------------------------------------------------------
  # ● Actor Shadow
  #-------------------------------------------------------------------------- 
  # return "shadow01" <- Image file name in .Graphics\Characters
  # return "" <- No shadow used.
  def shadow
    case cg_database_actor_id
    when 1
      return "shadow00"
    end
    # Default shadow for all unassigned Actor IDs.
    return "shadow00"
  end 
  #--------------------------------------------------------------------------
  # ● Actor Shadow Adjustment
  #-------------------------------------------------------------------------- 
  # return [ X-Coordinate, Y-Coordinate] 
  def shadow_plus
    case cg_database_actor_id
    when 1
      return [ 0, 4]
    end
    # Default shadow positioning for all unassigned Actor IDs.
    return [ 0, 4]
  end
end
#==============================================================================
# ■ Game_Enemy
#------------------------------------------------------------------------------
# 　Enemy Basic Action Settings
#==============================================================================
class Game_Enemy < Game_Battler
  #--------------------------------------------------------------------------
  # ● Enemy Unarmed Attack Animation Sequence
  #--------------------------------------------------------------------------
  # when 1 <- enemyID#
  #   return "ENEMY_UNARMED_ATK" <- Corresponding action SEQUENCE name.
  def base_action
    case @enemy_id
    when 1
      return "ENEMY_UNARMED_ATK"
    end
    # Default action for all unassigned Enemy IDs.
    return "ENEMY_UNARMED_ATK"
  end 
  #--------------------------------------------------------------------------
  # ● Enemy Wait/Idle Animation
  #-------------------------------------------------------------------------- 
  def normal
    case @enemy_id
    when 1
      return "WAIT"
    end
    # Default action for all unassigned Enemy IDs.
    return "WAIT"
  end
  #--------------------------------------------------------------------------
  # ● Enemy Critical (1/4th HP) Animation
  #-------------------------------------------------------------------------- 
  def pinch
    case @enemy_id
    when 1
      return "WAIT"
    end
    # Default action for all unassigned Enemy IDs.
    return "WAIT"
  end
  #--------------------------------------------------------------------------
  # ● Enemy Guarding Animation
  #--------------------------------------------------------------------------  
  def defence
    case @enemy_id
    when 1
      return "GUARD_ATTACK"
    end
    # Default action for all unassigned Enemy IDs.
    return "GUARD_ATTACK"
  end
  #--------------------------------------------------------------------------
  # ● Enemy Damage　Taken Animation
  #-------------------------------------------------------------------------- 
  def damage_hit
    case @enemy_id
    when 1
      return "DAMAGE"
    end
    # Default action for all unassigned Enemy IDs.
    return "DAMAGE"
  end
  #--------------------------------------------------------------------------
  # ● Enemy Evasion Animation
  #-------------------------------------------------------------------------- 
  def evasion
    case @enemy_id
    when 1
      return "ENEMY_EVADE_ATTACK"
    end
    # Default action for all unassigned Enemy IDs.
    return "ENEMY_EVADE_ATTACK"
  end
  #--------------------------------------------------------------------------
  # ● Enemy Flee Animation
  #-------------------------------------------------------------------------- 
  def run_success
    case @enemy_id
    when 1
      return "ENEMY_FLEE"
    end
    # Default action for all unassigned Enemy IDs.
    return "ENEMY_FLEE"
  end
  #--------------------------------------------------------------------------
  # ● Enemy Battle Start Animation
  #--------------------------------------------------------------------------  
  def first_action
    case @enemy_id
    when 1
      return "BATTLE_START"
    end
    # Default action for all unassigned Enemy IDs.
    return "BATTLE_START"
  end
  #--------------------------------------------------------------------------
  # ● Enemy Return Action when action is interuptted/discontinued
  #--------------------------------------------------------------------------  
  def recover_action
    case @enemy_id
    when 1
      return "RESET_POSITION"
    end
    # Default action for all unassigned Enemy IDs.
    return "RESET_POSITION"
  end
  #--------------------------------------------------------------------------
  # ● Enemy Shadow
  #-------------------------------------------------------------------------- 
  # return "shadow01" <- Image file name in .Graphics\Characters
  # return "" <- No shadow used.
  def shadow
    case @enemy_id
    when 1
      return "shadow00"
    when 30
      return ""
    end
    # Default shadow for all unassigned Enemy IDs.
    return "shadow00"
  end 
  #--------------------------------------------------------------------------
  # ● Enemy Shadow Adjustment
  #-------------------------------------------------------------------------- 
  # return [ X-Coordinate, Y-Coordinate] 
  def shadow_plus
    case @enemy_id
    when 1
      return [ 0, 4]
    end
    # Default shadow positioning for all unassigned Enemy IDs.
    return [ 0, 4]
  end 
  #--------------------------------------------------------------------------
  # ● Enemy Equipped Weapon
  #-------------------------------------------------------------------------- 
  # return 0  (Unarmed/No weapon equipped.)
  # return 1  (Weapon ID number. (1~999))
  def weapon
    case @enemy_id
    when 1 # Enemy ID
      return 0 # Weapon ID
    end
    # Default weapon for all unassigned Enemy IDs.
    return 0
  end 
  #--------------------------------------------------------------------------
  # ● Enemy Screen Positioning Adjustment
  #-------------------------------------------------------------------------- 
  # return [ 0, 0]  <- [X-coordinate、Y-coordinate]
  def position_plus
    case @enemy_id
    when 1
      return [0, 0]
    end
    # Default positioning for all unassigned Enemy IDs.
    return [ 0, 0]
  end
  #--------------------------------------------------------------------------
  # ● Enemy Collapse Animation Settings
  #--------------------------------------------------------------------------
  # return 1  (Enemy sprite stays on screen after death.)
  # return 2  (Enemy disappears from the battle like normal.)
  # return 3  (Special collapse animation.) <- Good for bosses.
  def collapse_type
    case @enemy_id
    when 1
      return 2
    when 30
      return 3
    end
    # Default collapse for all unassigned Enemy IDs.
    return 2
  end
  #--------------------------------------------------------------------------
  # ● Enemy Multiple Action Settings
  #--------------------------------------------------------------------------
  # Maximum Actions, Probability, Rapidity Adjustment
  # return [ 2, 100, 100]
  #
  # Maximum Actions - Maximum number of actions enemy may execute in a turn.
  # Probability - % value. Chance for a successive action.
  # Rapidity Adjustment - % value that decreases enemy's rapidity after
  #                       each successive action.  [Note: Literal Japanese
  #                       translation.]
  def action_time
    case @enemy_id
    when 1
      return [ 1, 100, 100]
    end
    # Default action for all unassigned Enemy IDs.
    return [ 1, 100, 100]
  end
  #--------------------------------------------------------------------------
  # ● Enemy Animated Battler Settings
  #--------------------------------------------------------------------------
  # return true - Enemy battler uses same animation frames as actors.
  # return false - Default enemy battler.
  # [Settings]
  # 1.Enemy animated battler file must be in .Graphics\Characters folder.
  # 2.Enemy battler file names must match between .Graphics\Characters and
  #   .Graphics/Battlers folders.
  def anime_on
    case @enemy_id
    when 1
      return false
    end
    # Default action for all unassigned Enemy IDs.
    return false
  end
  #--------------------------------------------------------------------------
  # ● Enemy Invert Settings
  #--------------------------------------------------------------------------
  # return false  <- Normal
  # return true   <- Inverts enemy image
  def action_mirror
    case @enemy_id
    when 1
      return false
    end
    # Default action for all unassigned Enemy IDs.
    return false
  end
end
module RPG
#==============================================================================
# ■ module RPG
#------------------------------------------------------------------------------
# 　State Action Settings
#==============================================================================
class State
 #--------------------------------------------------------------------------
 # ● State Affliction Wait Animation Settings
 #-------------------------------------------------------------------------- 
 # when 1  <- State ID number
 #   return "DEAD"  <- SEQUENCE Animation when afflicted by specified state.
  def base_action
    case @id
    when 1  # Incapacitated(HP0). Has the highest priority.
      return "DEAD"
    when 2,3,4,5,7  
      return "WAIT-NORMAL"
    when 6  
      return "WAIT-SLEEP"
    when 17  
      return "WAIT-FLOAT"
    end
    # Default SEQUENCE for all unassigned State IDs.
    return "WAIT"
  end
 #--------------------------------------------------------------------------
 # ● State Enhancement Extension Settings
 #--------------------------------------------------------------------------
 # Note about REFLECT and NULL states:
 #      An item/skill is considered physical if "Physical Attack" is 
 #      checked under "Options" in your Database.  Otherwise, it is magical.
 #
 # "AUTOLIFE/50"      - Automatically revives when Incapacitated.
 #                      Value after "/" is % of MAXHP restored when revived.
 # "MAGREFLECT/39"    - Reflects magical skills to the original caster.
 #                      Value after "/" is Animation ID when triggered.
 # "MAGNULL/39"       - Nullify magical skills and effects.
 #                      Value after "/" is Animation ID when triggered.
 # "PHYREFLECT/39"    - Reflects physical skills to the original caster.
 #                      Value after "/" is Animation ID when triggered.
 # "PHYNULL/39"       - Nullify physical skills and effects.
 #                      Value after "/" is Animation ID when triggered.
 # "COSTABSORB"       - Absorbs the MP (or HP) cost of an incoming skill when
 #                      affected.  This will not appear as POP Damage.  This 
 #                      function is similar to Celes' "Runic" from FF6.
 # "ZEROTURNLIFT"     - State is lifted at the end of turn regardless.
 # "EXCEPTENEMY"      - Enemies will not use animation sequence assigned 
 #                      under State Affliction Wait Animation Settings when
 #                      afflicted. (Actors still will.)
 # "NOPOP"            - State name will not appear as POP Damage.
 # "HIDEICON"         - State icon will not appear in the BattleStatus Window.
 # "NOSTATEANIME"     - State's caster and enemies will not use animation 
 #                      sequence assigned under State Affliction Wait Animation 
 #                      Settings when afflicted.
 # "SLIPDAMAGE"       - Apply slip damage.  Assign values under Slip Damage Settings.
 # "NONE"             - No extension. Used as a default.
  def extension
    case @id
    when 1  # Incapacitated State.  Has highest priority.
      return ["NOPOP","EXCEPTENEMY"]
    when 2  # Poison
      return ["SLIPDAMAGE"]
    when 18 # 2-Man Tech
      return ["ZEROTURNLIFT","HIDEICON"]
    when 19 # 4-Man Tech
      return ["ZEROTURNLIFT","HIDEICON"]
    when 20 # Cat Transformation
      return ["HIDEICON","NOSTATEANIME"]
    end
    # Default extension that applies if state is not assigned above.
    return ["NONE"]
  end
 #--------------------------------------------------------------------------
 # ● Slip Damage Settings
 #--------------------------------------------------------------------------
 # Also includes regeneration options.
 #
 # when 1 <- State ID. Slip Damage only applies if "SLIPDAMAGE" is assigned above.
 # 　　　　 Multiple settings may be applied. Ex)[["hp",0,5,true],["mp",0,5,true]]
 #                           
 #  　     Type, Constant, %, POP?, Allow Death
 # return [["hp",    0,  10, true,  true]]
 #
 # Type       – "hp" or "mp".
 # Constant   – Set a constant value to apply each turn. 
 #              Positive values are damage.  Negative values are recovery. 
 # %          - Set a percentage value to apply each turn based on MAX HP/MP. 
 #              Positive values are damage. Negative values are recovery.
 # POP?       - Determines whether or not you want slip damage value to 
 #              appear as POP Damage.
 # Allow Death - true: Slip damage can kill.
 #               false: Slip damage will not kill. (Battler will be left at 1 HP)
  def slip_extension
    case @id
    when 2  # Poison
      return [["hp", 0, 10, true, true]]
    end
    return []
  end
end 
#==============================================================================
# ■ module RPG
#------------------------------------------------------------------------------
# 　Weapon Action Settings
#==============================================================================
class Weapon
 #--------------------------------------------------------------------------
 # ● Weapon Animation Sequence Settings
 #-------------------------------------------------------------------------- 
 # Assigns a specific animation sequence when using a weapon.
 #
 # when 1 <- Weapon ID number
 # return "NORMAL_ATTACK" <- SEQUENCE Animation for assigned weaponID
  def base_action
    case @id
    when 1
      return "NORMAL_ATTACK"
    end
    # Default SEQUENCE for unassigned WeaponIDs.
    return "NORMAL_ATTACK"
  end
 #--------------------------------------------------------------------------
 # ● Weapon Graphic Assignment Settings
 #--------------------------------------------------------------------------
 # Allows use of a seperate weapon graphic besides the one assigned 
 # from Iconset.png
 #
 # return "001-Weapon01" <- Weapon image file name.  If "", none is used. 
 #                          File must be in the .Graphics\Characters folder 
 #                          of your project.
  def graphic
    case @id
    when 1
      return ""
    end
    # Default weapon graphic for unassigned WeaponIDs.
    return ""
  end
 #--------------------------------------------------------------------------
 # ● Throwing Weapon Graphic Settings
 #--------------------------------------------------------------------------
 # Allows use of a seperate throwing weapon graphic besides the one assigned
 # from Iconset.png.  This is useful for arrows when you don't want the bow
 # to be thrown.
 #
 # return "001-Weapon01" <- Weapon image file name.  If "", none is used. 
 #                          File must be in the .Graphics\Characters folder 
 #                          of your project.
  def flying_graphic
    case @id
    when 1
      return ""
    end
    # Default throwing weapon graphic for unassigned WeaponIDs.
    return ""
  end
end  
#==============================================================================
# ■ module RPG
#------------------------------------------------------------------------------
# 　Skill Action Settings
#==============================================================================
class Skill
 #--------------------------------------------------------------------------
 # ● Skill ID Sequence Assignments
 #--------------------------------------------------------------------------  
  def base_action
    case @id
    when 84
      return "THROW_WEAPON"
    when 85
      return "MULTI_ATTACK"
    when 86
      return "RAPID_MULTI_ATTACK"  
    when 87
      return "MULTI_SHOCK"  
    when 88
      return "SHOCK_WAVE" 
    when 89
      return "MULTI_ATTACK_RAND"  
    when 90
      return "SKILL_90_SEQUENCE"  
    when 91
      return "SKILL_91_SEQUENCE"  
    when 92
      return "NORMAL_ATTACK"  
    when 93
      return "CUT_IN"  
    when 94
      return "STOMP"
    when 95
      return "ALL_ATTACK_1"
    when 96
      return "SKILL_ALL"
    when 97 
      return "TRANSFORM_CAT"
    when 98
      return "2-MAN_ATTACK"
    when 99
      return "2-MAN_ATTACK_ASSIST"
    when 100
      return "4-MAN_ATTACK"
    when 101
      return "4-MAN_ATTACK_ASSIST"
    when 102
      return "4-MAN_ATTACK_ASSIST"
    when 103
      return "4-MAN_ATTACK_ASSIST"
    when 104
      return "THROW_FRIEND"
    end
    # Default SEQUENCE for unassigned skills.
    return "SKILL_USE"
  end
 #--------------------------------------------------------------------------
 # ● Skill Enhancement Extension Settings
 #--------------------------------------------------------------------------
 # Multiple extensions may be applied to a skill ID.
 # If "CONSUMEHP" is applied along with any other extensions that deal with
 # MP in a forumla, it will be HP instead. 
 # This script WILL have compatibility issues with KGC_MPCostAlter.
 #
 # "NOEVADE"          -Cannot be evaded regardless.
 # "CONSUMEHP"        -Consumes HP instead of MP.
 # "%COSTMAX"         -Consumes % of MAXMP.  Example: Actor MAXMP500, 
 #                     10 set in Database, MP50 cost.
 # "%COSTNOW"         -Consumes % of current MP.
 # "IGNOREREFLECT"    -Ignores damage reflection states.
 # "%DAMAGEMAX/30"    -Changes damage formula of skill to:
 #                     damage = ENEMY MAX HP * [Integer] / 100
 #                     [Integer] is the number you apply after "/".
 # "%DAMAGENOW/30"    -Changes damage formula of skill to:
 #                     damage = ENEMY CURRENT HP * [Integer] / 100
 #                     [Integer] is the number you apply after "/".
 # "COSTPOWER"        -Changes damage formula of skill to:
 #                     damage = base damage * cost / MAX MP
 #                     The more the skill costs, the more damage it will do.
 # "HPNOWPOWER"       -Changes damage formula of skill to:
 #                     damage = base damage * CURRENT HP / MAX HP
 #                     The less current HP you have, the less damage.
 # "MPNOWPOWER"       -Changes damage formula of skill to:
 #                     damage = base damage * CURRENT MP / MAX MP
 #                     The less current MP you have, the less damage.
 # "NOHALFMPCOST"     -"Half MP Cost" from armor options will not apply.
 # "HELPHIDE"         -Help window when casting will not appear.
 # "TARGETALL"        -Will affect all enemies and allies simultaneously.
 # "RANDOMTARGET"     -Target is chosen at random.
 # "OTHERS"           -Skill will not affect caster.
 # "NOOVERKILL"       -Damage will not be applied after the target reaches zero HP.
 # "NOFLASH"          -Battler will not flash when taking action.
 # "NONE"             -No extension. Used as a default.
  def extension
    case @id
    when 86
      return ["NOOVERKILL"]
    when 89
      return ["RANDOMTARGET"]
    when 94
      return ["NOOVERKILL"]
    when 96
      return ["TARGETALL"]
    when 98
      return ["NOOVERKILL"]
    when 99
      return ["HELPHIDE","NOFLASH"]
    when 100
      return ["NOOVERKILL"]
    when 101
      return ["HELPHIDE","NOFLASH"]
    when 102
      return ["HELPHIDE","NOFLASH"]
    when 103
      return ["HELPHIDE","NOFLASH"]
    end
    # Default extensions for unassigned skills.
    return ["NONE"]
  end
 #--------------------------------------------------------------------------
 # ● Skill Throwing Weapon Graphic Settings
 #--------------------------------------------------------------------------
 # - Allows use of a seperate throwing weapon graphic besides the one assigned
 #   from Iconset.png.  This section is specifically for skills.
 #
 # return "001-Weapon01" <- Weapon image file name.  If "", none is used. 
 #                          File must be in the .Graphics\Characters folder 
 #                          of your project.
  def flying_graphic
    case @id
    when 1
      return ""
    end
    # Default throwing skill graphic for unassigned WeaponIDs.
    return ""
  end
end  
#==============================================================================
# ■ module RPG 
#------------------------------------------------------------------------------
# 　Item Action Settings
#==============================================================================
class Item
 #--------------------------------------------------------------------------
 # ● Item ID Sequence Assignment
 #--------------------------------------------------------------------------  
  def base_action
    case @id
    when 1
      return "ITEM_USE"
    end
    # Default SEQUENCE for unassigned ItemIDs.
    return "ITEM_USE"
  end
 #--------------------------------------------------------------------------
 # ● Item Enhancement Extension Settings
 #-------------------------------------------------------------------------- 
 # "NOEVADE"          -Cannot be evaded regardless.
 # "IGNOREREFLECT"    -Ignores damage reflection states.
 # "HELPHIDE"         -Help window when casting will not appear.
 # "TARGETALL"        -Will affect all enemies and allies simultaneously.
 # "RANDOMTARGET"     -Target is chosen at random.
 # "OTHERS"           -Item will not affect caster.
 # "NOOVERKILL"       -Damage will not be applied after the target reaches zero HP.
 # "NOFLASH"          -Battler will not flash when taking action.
 # "NONE"             -No extension. Used as a default.
  def extension
    case @id
    when 1
      return ["NONE"]
    end
    # Default extension for unassigned ItemIDs.
    return ["NONE"]
  end
end
end