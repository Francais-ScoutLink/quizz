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

set ns "MyScript"
catch ${ns}::uninstall
namespace eval $ns {
  unset ::ns
 
  variable quizz "Vous pouvez venir tester vos connaisence des scout sur notre canal /join #francais-jeux"

  bind pub - "quizz" [namespace current]::respond
  proc respond {nick uhost hand chan text} {
    variable quizz
    putchan "$quizz"
    return 1
  }
 
  bind evnt - prerehash [namespace current]::uninstall
  proc uninstall {args} {
    unbind pub - "quizz" [namespace current]::respond
    unbind evnt - prerehash [namespace current]::uninstall
    namespace delete [namespace current]
  }
}

putlog "Script Quizz Loader"