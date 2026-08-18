# RMVX_SCRIPT_INDEX: 91
# RMVX_SCRIPT_ID: 41853801
# RMVX_SCRIPT_NAME: <README/How to Install>
# RMVX_SOURCE_SHA256: ebb64fdeccf556bd6d5a26cf4c3d347d39f28e8900af3c67f803b7b4a27a7f05

#==============================================================================
# ■ Sideview Battle System Version 3.3 (English Translation v2.1)
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
# ● HOW TO INSTALL CORRECTLY
#     Because there are database entries required to be present for the special
#   skill animations, I strongly suggest using the demo as a base to develop a
#   new game.  
#     If you really need to install this script to a game that is
#   already in development, you will need to move the scripts, and copy/paste
#   the following database entries to EXACTLY the same IDs like the demo to 
#   avoid strange errors:
#      - Skills:     084-104        - States: 017-020
#      - Animations: 082
#   Also be sure the following graphic files are present:
#      - Indivdual $charname character sprites for each party member
#      -   .\Graphics\Characters\$cat.png
#          .\Graphics\Characters\cursor.png
#          .\Graphics\Characters\shadow00.png
#          .\Graphics\Characters\shadow01.png
#          .\Graphics\System\Number-.png
#          .\Graphics\System\Number+.png
#   It is highly recommended that you place all SBS scripts above all your
# other custom scripts to avoid compatibility issues.
#------------------------------------------------------------------------------
#  Originally distributed at (http://rmxp.org) - Permission to distribute and
#    use freely in any manner, just give credit where it is due.
#==============================================================================
# Terms and Conditions
#==============================================================================
# (Japanese Text.  Please do not alter if you only see boxes)
# 
# "RPGツクールVXとXPのスクリプト素材。利用規約ナッシング。
# 著作権もサポートも無いものとお考えください。使用は自己責任でお願いします。" - Enu
#
# "RPG Maker XP and VX script materials.  No terms of use.
# No copyright or support what you think please.  Use at your own risk." - Enu
#
# Please do not e-mail Enu on his website for support.  He cannot offer 
# support to English users.

#==============================================================================
# Unsorted Notes
#==============================================================================
# - "OBJ_ANIM_WEIGHT" is a mistranslation and is supposed to be "OBJ_ANIM_WAIT".
#   However, this is arbitrary and considering the amount of time this script
#   has been out, correcting it would cause problems for custom skill makers.
# - The "Position" option in the Animations Tab do not function as they did
#   with the default battle system.  All animations with this script are
#   considered "Center".
# - Several "Scope" options are disabled in the Skills Tab.  They are
#   One Enemy Dual, One Random Enemy, 2 Random Enemies and 3 Random Enemies.
# - "Force Action" in the event commands still has a lot of issues.  Please use
#   it at your own risk.
# - Please do not use "Same as Normal Atk" as the animation for skills.  It will
#   use the last animation ID in your Animations tab.  You can reproduce the
#   same effect in a sequence if you read under Attack Animation Settings.
#==============================================================================

