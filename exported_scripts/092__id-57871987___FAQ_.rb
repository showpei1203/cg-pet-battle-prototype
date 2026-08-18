# RMVX_SCRIPT_INDEX: 92
# RMVX_SCRIPT_ID: 57871987
# RMVX_SCRIPT_NAME: <FAQ>
# RMVX_SOURCE_SHA256: 4a231163e676f9b21ed285bec0370189e6a4e42e91237102e0e1dd7840e5917f

#==============================================================================
# ■ FAQ
#------------------------------------------------------------------------------
# Q:  Can I use the ATB script by itself for the default battle system, etc.?
# A:  No.  The ATB script was built specifically for the RPG Tankentai
#     Sideview Battle System.
#
#------------------------------------------------------------------------------
# Q:  Script 'Sideview 2' line 208: NoMethodError occured.
#
#     undefined method `action' for nil:NilClass
# A:  DO NOT INSTALL "Enemy Gauge Addon" with the ATB scripts!  The ATB script
#     already has it built in.  Installing "Enemy Gauge Addon" will result in
#     this error.
#
#------------------------------------------------------------------------------
# Q:  Can you add (insert request here) into the next version?
# A:  No.  I did not create this script, only localized it.  Requests like
#     this are ignored.
#
#------------------------------------------------------------------------------
# Q:  I found (insert bug report here).
# A:  Unfortunately, I am not a scripter so I cannot help with bugs.
#     I can only suggest that you wait until Enu fixes it in a new version.
#
#------------------------------------------------------------------------------
# Q:  Can you make (insert script here) compatible with the Sideview?
# A:  No.  These requests will be ignored.
#
#------------------------------------------------------------------------------
# Q:  Can you make this script "real-time" like in Tales of (insert here)?
# A:  No.  These requests will be ignored.
#
#------------------------------------------------------------------------------
# Q:  I already have a cursor.png in my Characters folder.  Why do I need
#     another one in my System folder?
# A:  The ATB uses a three-framed cursor animation rather than two.  You
#     can delete cursor.png in the Characters folder if you are using ATB.
#
#------------------------------------------------------------------------------
# Q:  How do I make animated enemies like the actors?
# A:  Please read this link: 
#     http://www.rpgrevolution.com/forums/index.php?s=&showtopic=18304&view=findpost&p=212499
#
#     There is also an example if you talk to Ralph in the EXTRA demo
#
#------------------------------------------------------------------------------
# Q:  How do I make my own skill animations?
# A:  This is not an easy question to answer.  I highly recommend reading and
#     examining the default Sideview Configurations script to understand
#     how as that is the best source until someone steps up to create a
#     full guide.
#
#------------------------------------------------------------------------------
# Q:  I got this error, what does this mean: 
#
#     Script 'Sideview1' line 480: NoMethodError occurred
#
#     undefined method '' for nil:NilClass"
# A:  It means that you are loading from an old game save.  Always use 
#     New Game whenever you add something new to your project especially if 
#     it's a script.
#
#------------------------------------------------------------------------------
# Q:  I made a heal skill, but my actor attacks himself with his weapon to heal?
#        OR
#     I made a skill, but my actor attacks multiple times.  Why?
# A:  You have the Dual Attack, Double Attack and Triple Attack Addons installed.  
#     They are meant for the RTP skills provided in IDs 1~3.
#     You can either delete those addons or make your skill on another 
#     skill ID besides 1, 2 or 3.
#
#------------------------------------------------------------------------------
# Q:  Where can I find VX resources?
# A:  Not my responsibility.
#
#------------------------------------------------------------------------------
# Q:  Why are my enemies in the wrong position and lined up in a row like for 
#     the default battle system?  Why aren't they on the left side?
# A:  In your project editor, press F9 to access your Database.  Click the 
#     Troops Tab.  Move the enemy sprites in the little window by dragging
#     them.  By the way, you're a nub.
#
#------------------------------------------------------------------------------