##################### Advance Channel Greet v1.0 ######################
#
#
# Author : MeS - MeS@Hells.Ca - http://www.Hells.Ca
# Source DownLoad : http://www.mesloopy.net/ACG.zip
#
# Support Channels :  #EdenTech @Undernet.Org
#                     #Hells    @Hells.Ca
#                   
#                     
#
# *Description : Ce script permet de sender une notice informative et
# une notice de bienvenue. Au personnes qui joignent votre channel.
# Il recevrons une notice leur donnant l'url du channel et une autre 
# leur souhaitant la bienvenue.
# Ce script envoi aussi un query priver piocher au hazard dans une list
# lorsque une personne quit le channel.
# Il permet aussi d'utiliser la commande !Info pour avoir des
# informations complétent sur le channel.
#
# *Ce Script Est valabre pour 1 channel.
#
#
#######################################################################
#               La Configuration du script commence ici               #
#######################################################################

# Channel 1 ou le script doit agirs.
set channel "#francais01 #francais02 #francais03 #francais04"

# Adresse web de votre channel.
set url "http://francais.scoutlink.net/"


# Formule de bienvenu au channel
set info {
    "Merci de respecter le fait que ce canal parle uniquement Français | Thank you to respect the fact that this channel only speaks French | Vous pouvez venir tester vos connaisence des scout sur notre canal /join #francais-jeux"
}

# Le query que recoivent les gens en quittant.
set partmsg {
    "Revenez nous Vite !!"
    "Enrevoir. Et à la prochaine."
}

# Les informations qui suivent seront transmis par la commande !info.

# Seter ici une description de votre channel.
set description "http://francais.scoutlink.net/les-regles/"

# Seter ici Le nick/nom du propriétaire du channel.
set owner "Rigoh,Patate,DJBlack"

# Seter ici le propriétaire de l'eggdrop en question.
set owner2 "DJBlack"

# Seter ici la notice on join que recevrons les users pour les 
# prevenirs que la commande !info Existe et leurs est disponible. Si 
# vous ne souhaiter pas qu'une notice soit communiquer laisser vide.

set infonotice ""

#######################################################################
# NE TOUCHEZ PAS LES LIGNES QUI SUIVENT OU CELA POURAIT ENDOMAGER LE  #                        
# SCRIPT                                                              #
#######################################################################

set ACG(ver) "v1.0"

set siteinfo "0"
bind join - "$channel %" msg_jmsg
bind part - "$channel %" msg_pmsg

proc msg_pmsg {nick uhost hand channel args} {
    global partmsg siteinfo url
      if {$siteinfo == "0"} {
       putserv "PRIVMSG $nick :[do_part $args]"
    return 0
 }
      if {$siteinfo == "1"} {
       putserv "PRIVMSG $nick :Notre Siteweb: $url" 
       putserv "PRIVMSG $nick :[do_part $args]"
    return 0
 }
}

proc do_part {nick} {
   global partmsg
   set partoutput [lindex $partmsg [rand [llength $partmsg]]]
   return "$partoutput" 

}

proc msg_jmsg {nick uhost hand channel args} {
    global url 
       putserv "NOTICE $nick :Notre Siteweb: $url" 
       putserv "NOTICE $nick :[do_random $args]" 
    return 0
}

proc do_random {nick} {
   global info
   set output [lindex $info [rand [llength $info]]]
   return "$output" 

}

bind pub - !info pub_info

bind join - * join_tous
proc join_tous {nick host hand chan} {
global channel infonotice
if {$chan == "$channel"} {
puthelp "NOTICE $nick :$infonotice"
  }
}

proc pub_info {nick host hand chan args} {
global channel description url owner owner2
if {$chan == "$channel"} {
puthelp "NOTICE $nick :Description: $description"
puthelp "NOTICE $nick :URL du chan: $url"
puthelp "NOTICE $nick :Owner du Chan: $owner"
puthelp "NOTICE $nick :Owner de l'egg: $owner2"
  }
}

############### CopyRight 2003 : Hells.ca ###############

putlog "Advance Channel Greet. TCL by MeS - http://www.Hells.Ca loaded!"
