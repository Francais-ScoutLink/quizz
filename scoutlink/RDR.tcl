 ###############################################################################
#
# Related Differential Report
# v1.21 (17/06/2015)   ©2014-2015 Menz Agitat
#
# IRC: irc.epiknet.org  #boulets / #eggdrop
#
# Mes scripts sont téléchargeables sur http://www.eggdrop.fr
# Retrouvez aussi toute l'actualité de mes releases sur
# http://wiki.eggdrop.fr/Utilisateur:MenzAgitat
#
# Remerciements à Galdinx pour les coups de main sur la partie mathématique.
#
 ###############################################################################

#
# Description
#
# Ce script pourvoit l'eggdrop du package Related_Differential_Report 1.21
#
# Le rapport de relation différentielle est une extrapolation du principe de la
# distance de Levenshtein.
#
# Rappelons que la distance de Levenshtein calcule le nombre de caractères qu'il
# est nécessaire d'ajouter, modifier, déplacer ou supprimer pour passer d'une
# chaîne de caractères à une autre.
#
# Le rapport de relation différentielle (RDR) fait à peu près la même chose, à
# ceci près que la position des caractères n'a aucune importance pour lui.
# Il calcule le taux de différences entre deux chaînes de caractères en se
# focalisant sur le nombre de caractères de chaque type.
# De plus, les caractères conservant la même position entre les deux chaînes de
# caractères (en partant du début ou de la fin) ajoutent un bonus de similarité
# qui sera pris en compte dans le résultat final.
# Enfin, une pénalité est appliquée si la longueur des deux chaînes de
# caractères présente une trop grande différence.
# La valeur retournée est comprise entre 0 et 100, 0 signifiant qu'il n'y a
# aucune différence entre les deux chaînes de caractères, et 100 signifiant
# qu'elles sont très dissemblables.
#
 ###############################################################################

#
# Intérêt
#
# Permet à un correcteur orthographique de faire des suggestions pour tel mot
# mal orthographié, en proposant d'autres mots dont le RDR par rapport au
# premier est faible.
#
# Permet à une pseudo-IA de type chatterbot d'avoir une tolérance
# orthographique : si tel mot comparé à tel autre a un RDR inférieur à une
# tolérance donnée, on peut décider qu'il est équivalent.
#
# Comparé à la méthode de la distance de Levenshtein, RDR est plus souple en ce
# sens qu'il permettra par exemple de détecter deux phrases formulées
# différemment comme étant la même phrase puisque l'ordre des mots importe peu.
#
 ###############################################################################

#
# Syntaxe
#
# ::RDR::RDR [-allchars] <1ère chaîne de caractères> <2ème chaîne de caractères>
#
# Si l'option -allchars est spécifiée, tous les caractères seront pris en
# compte. Si elle ne l'est pas, seuls les caractères alphanumériques et les
# espaces seront traités.
#
# Dans le but d'accroître la rapidité d'exécution, la validité de la syntaxe de
# la commande n'est pas vérifiée. Veillez donc à la respecter scrupuleusement,
# sans quoi le script ne fonctionnera pas comme prévu et vous n'en serez pas
# explicitement averti.
# 
 ###############################################################################

#
# Exemples
#
# ::RDR::RDR "il fait beau aujourd'hui" "aujourd'hui il fait beau"
#	0.0
#
# ::RDR::RDR "il fera beau aujourd'hui" "aujourd'hui il fait beau"
# 8.637461117131487
#
# ::RDR::RDR "il fera beau aujourd'hui" "aujourd'hui il va pleuvoir"
# 20.935906263026013
#
# ::RDR::RDR "il fera beau aujourd'hui" "cette phrase n'a vraiment rien à voir"
# 55.65136373698695
# Notez que dans l'exemple ci-dessus, le score reste éloigné de 100. C'est dû au
# fait que les deux chaînes de caractères comportent un certain nombre de
# caractères communs.
#
# ::RDR::RDR "abcdefghi" "jklmnopqrstuvwxyz"
# 100.0
#
 ###############################################################################

#
# Changelog
#
# 1.0
#		- 1ère version
# 1.1
#		- Modification de l'algorithme afin de valoriser les caractères qui
#			conservent la même position entre les deux chaînes, en partant du début
#			ou de la fin.
# 1.2
#		- Correction : si les deux chaînes de caractères comparés étaient de
#			longueur différente, le taux de différences retourné différait selon qu'on
#			comparait string1 à string2 ou string2 à string1.
#		- Modification de la fonction servant à calculer le taux de différences afin
#			d'affiner la pertinence des résultats.
#		- Ajout : une pénalité est appliquée au score final les deux chaînes de
#			caractères comparées sont de longueur différentes.
#		- Ajout : une aide à la syntaxe est donnée dans l'erreur retournée par la
#			commande ::RDR::RDR si elle est utilisée sans arguments.
#		- Le code a été commenté afin d'en faciliter la compréhension.
#		- Quelques optimisations.
# 1.21
#		- Correction : comparer deux chaînes de caractères vides provoquait une
#			erreur.
#
 ###############################################################################

#
# Licence
#
#		Cette création est mise à disposition selon le Contrat
#		Attribution-NonCommercial-ShareAlike 3.0 Unported disponible en ligne
#		http://creativecommons.org/licenses/by-nc-sa/3.0/ ou par courrier postal à
#		Creative Commons, 171 Second Street, Suite 300, San Francisco, California
#		94105, USA.
#		Vous pouvez également consulter la version française ici :
#		http://creativecommons.org/licenses/by-nc-sa/3.0/deed.fr
#
 ###############################################################################

if {[::tcl::info::commands ::RDR::uninstall] eq "::RDR::uninstall"} { ::RDR::uninstall }
# Note pour les programmeurs :
# Dans la version 1.6.19 d'Eggdrop, le numéro de version affiché par .vbottree
# et [numversion] est incorrect; il affiche 1061800 ou 1061801, ce qui
# correspond à la version 1.6.18. On utilise donc une autre technique pour
# vérifier le numéro de version.
if { [regsub -all {\.} [lindex $::version 0] ""] < 1620 } { putloglev o * "\00304\[Related Differential Report - erreur\]\003 La version de votre Eggdrop est\00304 ${::version}\003; Related Differential Report ne fonctionnera correctement que sur les Eggdrops version 1.6.20 ou supérieure." ; return }
if { [::tcl::info::tclversion] < 8.5 } { putloglev o * "\00304\[Related Differential Report - erreur\]\003 Related Differential Report nécessite que Tcl 8.5 (ou plus) soit installé pour fonctionner. Votre version actuelle de Tcl est\00304 ${::tcl_version}\003." ; return }
package require Tcl 8.5
namespace eval ::RDR {



 ###############################################################################
### Fin de la configuration
 ###############################################################################



	 #############################################################################
	### Initialisation
	 #############################################################################
	variable scriptname "Related Differential Report"
	variable version "1.21.20150617"
	package provide Related_Differential_Report 1.21
	# Procédure de désinstallation (le script se désinstalle totalement avant
	# chaque rehash ou à chaque relecture au moyen de la commande "source" ou
	# autre)
	proc uninstall {args} {
		putlog "Désallocation des ressources de ${::RDR::scriptname}..."
		foreach binding [lsearch -inline -all -regexp [binds *[set ns [::tcl::string::range [namespace current] 2 end]]*] " \{?(::)?$ns"] {
			unbind [lindex $binding 0] [lindex $binding 1] [lindex $binding 2] [lindex $binding 4]
		}
		package forget Related_Differential_Report
		namespace delete ::RDR
	}
}

 ###############################################################################
### Calcul du rapport de relation différentielle
 ###############################################################################
proc ::RDR::RDR {args} {
	if { [set args [::tcl::string::tolower $args]] eq "" } {
		error "wrong # args: should be \"[::tcl::info::level 0] ?-allchars? string1 string2\""
	} else {
		# Le paramètre -allchars a été spécifié, on traite tous les caractères.
		if { [regexp -- {^-allchars\s} $args] } {
			lassign $args {} string1 string2
		# Le paramètre -allchars n'a pas été spécifié, on ne traite que les
		# caractères alphanumériques et les espaces.
		} else {
			lassign $args string1 string2
			regsub -all {[^\s[:alnum:]]} $string1 "" string1
			regsub -all {[^\s[:alnum:]]} $string2 "" string2
		}
		# Gestion du cas où les deux chaînes de caractères sont vides.
		if {
			($string1 eq "")
			&& ($string2 eq "")
		} then {
			return 0.0
		}
		# Initialisation des variables.
		set similarity_bonus 0
		set string1_charlist [split $string1 ""]
		set string2_charlist [split $string2 ""]
		set string1_length [::tcl::string::length $string1]
		set string2_length [::tcl::string::length $string2]
		# On parcourt $string1 lettre par lettre.
		set index 0
		foreach char $string1_charlist {
			# Construction d'une table contenant un exemplaire de chaque caractère
			# utilisé dans $string1, auquel est associé une valeur. La valeur est
			# incrémentée pour chaque occurrence de ce caractère dans $string1.
			::tcl::dict::incr worklist $char 1
			# Si le caractère en cours de traitement conserve la même position dans
			# $string2 en partant du début OU de la fin, on incrémente un bonus de
			# similarité qui influera sur le score final.
			# Par exemple, si $string1 est "ARBRES", "E" est la 5ème lettre en partant
			# du début, ou la 2ème en partant de la fin; un bonus de similarité sera
			# accordé si dans $string2 on retrouve un "E" en 5ème ou avant-dernière
			# position.
			if { $char eq [lindex $string2_charlist $index] } {
				incr similarity_bonus 1
			} elseif { $char eq [lindex $string2_charlist end-[expr {$string1_length - $index - 1}]] } {
				incr similarity_bonus 1
			}
			incr index
		}
		# On parcourt $string2 lettre par lettre.
		set index 0
		foreach char $string2_charlist {
			# Décrémentation de la valeur associée à chaque caractère de la table
			# $worklist, pour chaque occurrence dans $string2.
			# Si un caractère n'existe pas encore dans la table, il y est ajouté et
			# décrémenté.
			::tcl::dict::incr worklist $char -1
		}
		# Gestion du cas particulier où $string2_length est impair et où l'on
		# retrouve son caractère central dans $string1 en même position à la fois en
		# partant du début ET de la fin du mot (comme le A dans HAMAC et FAT).
		# On compense donc pour éviter que le A ne soit compté 2 fois dans un sens,
		# et une seule fois dans l'autre.
		if { [expr {($string2_length / 2) * 2}] != $string2_length } {
			set string2_center_index [expr {round($string2_length / 2.0) - 1}]
			set string2_center_char [lindex $string2_charlist $string2_center_index]
			if {
				($string2_center_char eq [lindex $string1_charlist $string2_center_index])
				&& ($string2_center_char eq [lindex $string1_charlist end-$string2_center_index])
			} then {
				incr similarity_bonus -1
			}
		}
		# Calcul du score.
		set length_mismatch_penalty [expr {1 / (0.1 + (3.797 * 1.09**-((abs($string1_length-$string2_length) * 1.0) / max($string1_length,$string2_length) * 100))) - 3.797 + 3.5404}]
		if { !$similarity_bonus } {
			# On compense le fait qu'une fonction asymptotique empêche d'atteindre la
			# valeur maximum (soit 100).
			set score [expr {((abs([expr [regsub -all -- {-} [join [::tcl::dict::values $worklist] "+"] ""]]) * 100.0) / ($string1_length + $string2_length)) + $length_mismatch_penalty}]
		} else {
			set score [expr {(1 / (1 + exp(((10 * $similarity_bonus) / max($string1_length,$string2_length)) - 5))) * ((abs([expr [regsub -all -- {-} [join [::tcl::dict::values $worklist] "+"] ""]]) * 100.0) / ($string1_length + $string2_length)) + $length_mismatch_penalty}]
		}
		# On arrondit le score aux deux extrémités.
		if { $score >= 100 } {
			set score 100.0
		} elseif { $score <= 1.0e-5 } {
			set score 0.0
		}
		return $score
	}
}

 ###############################################################################
### Binds
 ###############################################################################
bind evnt - prerehash ::RDR::uninstall


putlog "$::RDR::scriptname v$::RDR::version (©2014-2015 Menz Agitat) a été chargé."
