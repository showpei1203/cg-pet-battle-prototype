# RMVX_SCRIPT_INDEX: 93
# RMVX_SCRIPT_ID: 96928113
# RMVX_SCRIPT_NAME: <Release Notes>
# RMVX_SOURCE_SHA256: c0e365f3d0a87bc0e5b96441390bcd9df659bd505864a6ebcbfeb8449f4573c9

#==============================================================================
# ■ Sideview Release Notes
#     Please note the distinction between the version numbers and the battle
#     system itself.
#------------------------------------------------------------------------------
# 1.0
# ● Original Release of Kylock's translation of 2.4
# 1.1
# ● Corrected some translation issues that caused some special skill animations
#     not to work.  I have changed nearly ALL strong values stored in the script
#     hashes, this version is nearly unrecognizable from the previous version.
# ● Translated the database and changed the distribution method from raw
#     scripts to a demo archive.  This should effectively thwart most of the 
#     simple errors that people are experiencing.
# ● Other minor bugfixes.
# 1.2
# ● Corrected some missing Kanji translations that broke the functionality of
#     some "chained" Skills. (thanks to Eolirin@rmxp.org)  Also added the
#     picture for the 'cut-in' move.
# 1.3
# ● Updated to version 2.6 of the original script.
# 1.4
# ▼ Translation picked up and continued by Mr. Bubble.
# ▼ Updated to version 2.7 of the original script.
# ▼ Corrected certain Kanji translations that broke the functionality of
#     certain Skill Enhancement Extensions.
# 1.5
# ▼ "HPCONSUME" changed to "CONSUMEHP" to prevent a no damage error.
# ▼ Corrected descriptions of "%DAMAGEMAX" and "%DAMAGENOW" extensions.
# ▼ Translated some more portions of the original Japanese script.  I have
#   also added some informational notes in places.
# 1.6
# ▼ PLEASE update your game credits to include the script creator's correct name.
# ▼ Due to a mistranslation by Kylock, the "One Wpn Only" and "Two Wpn Only"
#   Special Modifier names are switched.  Please change any of your custom
#   sequences to reflect this change, though, I doubt anyone knew what they did.
# ▼ Default values for TWO_SWORDS_STYLE changed to [100, 50] to avoid
#   causing less-than-normal damage when using cmpsr2000's Disposable
#   Ammo script. Keep the first value 100 if you are using his script.
#   Remember that you can change TWO_SWORDS_STYLE damage% to whatever you want
#   in the Config script.
# ▼ All State Extensions are now translated into English.
# ▼ All Special Modifiers are, for the most part, translated into English.
# ▼ Corrected other various mistranslations.
# ▼ Overall 95% translated into English.
# 1.7
# ▼ Special thanks to Shu (@rpgrevolution.com) for help on a big chunk of text 
#   I couldn't decipher properly.
# ▼ This will likely be the last translation version I will need to release
#   before any possible version updates.
# ▼ Overall 98% translated into English.
# 1.8
# ▼ Another thanks to Shu for coming through with the very final translation
#   pieces left.  Please remember to credit him as well.
# ▼ 100% English translation. (There are likely things that were lost in
#   translation, though.)
# 1.9
# ▼ Updated to version 2.8 of the original script.
#     - POP words are now fixed to display the correct statement.  This means
#       that a "MISS" or "EVADE" text will display in the correct situation.
#     - Error fixed when character ID 4 is added in the middle of battle.
#     - An error is fixed regarding adding a character in battle and the shadow
#       appears in a strange place. (Mr. Bubble: This seems to be behaving fine.
#       HOWEVER, it looks like this has made a new issue with removing an actor
#       mid-battle.  The removed actor's shadow will appear at the upper-left.)
# ▼ Corrected a description under Slip Damage Settings. (thanks to 
#   mr.?@rpgmakervx.net)
# 1.9 (SBS version update only)
# ▼ Updated to version 2.98 of the original script.
#     - Bug fixed when animated enemies do not invert in surprise attack
#       encounters.
#     - FLOOR in the configuations now correctly adjusts opacity of the
#       BattleFloor rather than Z-axis.
#     - Major bug fixed from 2.8 when adding/removing actors mid-battle.
# 1.9 (SBS version update only)
# ▼ Updated to version 2.98a.  This is an unofficial version release that fixes 
#   incorrect inversion of animated battlers in all cases.  Please note that in 
#   this version Enemy Invert Settings currently only work for animated enemy 
#   battlers and not single image battlers. (thanks to 
#   shadowflare912@rpgrevolution.com)
# 2.0
# ▼ Updated to version 2.99 of the original script.
#     - An official fix to the incorrect inversion of enemy animated battlers.
#       Inverts single image enemies now.
#     - ABSORB_DAMAGE removed from the config script.  Bug fixed with skills
#       that Absorb Damage.
# ▼ Translation version updated to 2.0 to reflect ABSORB_DAMAGE removal in
#   config. (i.e. it's a very minor update.)
# 2.0 (SBS version update only)
# ▼ Updated to version 3.0.
#     - Bug fixed with states set with "Cannot move or evade" restrictions and 
#       start actions.
#     - Action Conditions which check for required skills now works properly.
#     - Stabilized the switching behavior of party members in battle.
#     - Bugs fixed in back attack battles when enemy weapons sprites overlap the 
#       enemy sprite and weapon sprites are not inverted.
#     - Bug fixed with skills used by Force Action?  Hard to understand.
# ▼ KNOWN NEW BUG: Skills that transform an actor's sprite such as 
#   "Transform Cat" does not work properly because of this update.  Please
#   be patient for a fix by the author and use your own judgment on whether you 
#   want to update to this version.
# 2.0 (SBS version update only)
# ▼ Updated to version 3.2.
#     - Sprite transformation bug from previous version now fixed.
#     - Bug fixed when entering back attack battles twice or more in a row?
# 2.0 (SBS version update only)
# ▼ Updated to version 3.3.
#     - Bug fixed where a collapsed enemy's sprite reappears for no reason
#       particularly when used with ATB.
# 2.1
# ▼ English translation updated to 2.1.  The original translation done by
#   Kylock and wolfwoodsama was ok, but I could not tolerate
#   the amount of information that was lost in translation and the
#   amount of errors.
# ▼ Translation overhaul is mainly for first half of the SBS Configuration 
#   script.  No single action names have been changed.  Single action
#   category terms have been changed to ones that make more sense.
# ▼ Comments have been cleaned up and clarified for consistency.  This should 
#   be a lot easier for those who wish to learn how to properly customize this 
#   script.
# ▼ This English translation has been officially approved by Enu, the person
#   who scripted this entire battle system.
# ▼ Stealth update: Changed the sequence names for "LINK_SKILL_91" and
#   "LINK_SKILL_92" because they matched with single-action names.
# ▼ Various other minor changes for clarity.
#==============================================================================
