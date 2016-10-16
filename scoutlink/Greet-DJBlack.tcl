#  Greet.tcl by Nils Ostbjerg <shorty@business.auc.dk>
#  (C) Copyright (2000)
#
#  This script greets uses and asks them to interduce or ident them  if 
#  it dont know them. 
#
#  This version of the Greet script is useable (read tested) with Eggdrop
#  version 1.4.0 or higher.
#
#  Please report any bugs to me at shorty@business.auc.dk.
#  Idea and suggestion to new features are also welcome.
#
#                                 - Nils Ostbjerg <shorty@business.auc.dk>
#
#  Version 1.4.0 - 16 Apr 2000  First Version, should work ok.
#                                 - Nils Ostbjerg <shorty@business.auc.dk>
# 
##### GENERAL SETTINGS ####
# EDIT the channel names or REMOVE one or two depending on which channel you intend the bot the advertise
set channel "#francais01 #francais02 #francais03 #francais04"

# Edit the time cycle which is in minutes format depending on the time intervals you want the bot to flow out the advertisment
set time 15

# EDIT the text or REMOVE or ADD lines including inverted commas at the starting and ending at each line 
set text {
    "\00303venez vous défié à notre super quizz sur notre canal /join #francais-jeux | Merci de respecter le fait que ce canal parle uniquement Français | Thank you to respect the fact that this channel only speaks French"
}


##########################################################################
# Bind                                                                   #
##########################################################################

bind join - * join:greet
bind part - * msg_pmsg

##########################################################################
# join:greet start                                                       #
##########################################################################

proc join:greet {nick host hand chan} {
    global botnick
    if { "$nick" != "$botnick" } {
        putnotc $nick "Bienvenue sur le canal $chan, $nick."
        putnotc $nick "Bonjour et bienvenue $nick!  Je suis $botnick, le robot du quizz de #francais-jeux."
        if { "$chan" != "#francais-jeux" } {
            putnotc $nick "Merci de respecter le fait que ce canal parle uniquement Français | Thank you to respect the fact that this channel only speaks French | Vous pouvez venir tester vos connaisence des scout sur notre canal /join #francais-jeux"
        }
    }
}

proc msg_pmsg {nick uhost hand chan args} {
    global botnick
    if { "$nick" != "$botnick" } {
        if { "$chan" == "#francais-jeux" } {
                putmsg $nick "Revenez nous Vite jouer avec nous !!"
            } else {
                putmsg $nick "Revenez nous Vite !!"
                putmsg $nick "Enrevoir. Et à la prochaine."
            }
    }
}
putlog "\002 Script DJBlack chargement réusis\002"
if {[string compare [string index $time 0] "!"] == 0} { set timer [string range $time 1 end] } { set timer [expr $time * 60] }
if {[lsearch -glob [utimers] "* go *"] == -1} { utimer $timer go }

proc go {} {
    global channel time text timer
    foreach chan $channel {
    foreach line $text { putserv "PRIVMSG $chan :$line" }
}
if {[lsearch -glob [utimers] "* go *"] == -1} { utimer $timer go }
}

putlog "\002Loaded Auto-ADV script by JingYou @ Galaxynet #JingYou (v.4 13nov03)\002"

##########################################################################
# join:greet end                                                         #
##########################################################################


##########################################################################
# putlog                                                                 #
##########################################################################

putlog "Loaded Greet (DLF)"

##########################################################################
# auto adv                                                               #
##########################################################################
############################
#### ADV on Timer v.4  #####
# Whats new on v0.4 ?  ############
# -Added on multiple text message!#
# Whats new on v0.3 ?             #######################################
# -Added on multiple channel advertisment				#
#########################################################################
# Credits:								#
# Mainly to Egghelp.Org helpers on behalf helping solving out errors    #
# Errors/comments/suggestions do please email me: boojingyou@hotmail.com#             
# Do visit my personnal webby @ http://singnet.per.sg                   #
# For users who wanna chat with me, do loginto irc.GalaxyNet.Org        #
# #JingYou . My Nickname would be JingYou.       --Have fun--           #
################################################################################
# COLORS / BOLD								       #
# To make a text bold do this: \002TEXT-BOLD\002			       #
# To make a text with colors do this: \00304TEXT-RED\003 (04 = red, e.g.)      #
# To make a text with colors and bold do this: \002\00304TEXT-RED-BOLD\003\002 #
# Alternative, hit ctrl+k in IRC and copy paste in to dialog box. (RECOMMENDED)#
################################################################################

##### DO NOT EDIT ANYTHING BELOW THIS LINE UNLESS YOU KNOW WHAT YOU ARE DOING #####



