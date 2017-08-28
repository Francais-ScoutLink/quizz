#
# Script example Version 1.0
#
# Auteur: CrazyCat <crazycat@mail.invalid.com>
# Date: 01/10/2007
# 
# Ce script est juste un exemple
#
# Utilisation: !exemple en canal
#
 
# CONFIGURATION
# message à afficher

set ns "ScoutLink"
catch ${ns}::uninstall
namespace eval $ns {
    unset ::ns

    variable quizz "\00303Vous pouvez venir tester vos connaisence des scout sur notre canal \00304/join #francais-jeux"
    variable quizz_jeux "\00303Pour démarer le quizz taper \00304!quizz"

    bind pub - "quizz" [namespace current]::respond
    bind pub - "jeux" [namespace current]::respond
    bind raw - INVITE join:invite 
  
    bind msgm - * msg:coucou
    proc msg:coucou { nick uhost handle arg } {
        putserv "PRIVMSG $nick :Désolé je ne suis qu'un bot !"
        putserv "PRIVMSG $nick :Sorry I'm a bot !"
    }
  proc respond {nick uhost hand chan text} {
  
    variable quizz
    variable quizz_jeux
    
    if { "$chan" != "#francais-jeux"} {
        putchan $chan "$quizz"
    } else {
        putchan $chan "$quizz_jeux"
    }
    return 1
  }
 

    proc join:invite {from key arg} { 
        channel add [lindex [split $arg :] 1] 
        return 0 
    }
 
  bind evnt - prerehash [namespace current]::uninstall
  proc uninstall {args} {
    unbind pub - "quizz" [namespace current]::respond
    unbind pub - "quizz_jeux" [namespace current]::respond
    unbind evnt - prerehash [namespace current]::uninstall
    namespace delete [namespace current]
  }
}

putlog "\[Bot-Pixel\] ** Script Gestion quizz chargé - DJBlack **"