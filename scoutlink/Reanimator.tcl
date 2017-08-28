 ###############################################################################
#
# Reanimator
# v1.2 (27/03/2016)   �2013-2016 Menz Agitat
#
# IRC: irc.epiknet.org  #boulets / #eggdrop
#
# Mes scripts sont t�l�chargeables sur http://www.eggdrop.fr
#
 ###############################################################################

#
# Description
#
# Reanimator permet � votre Eggdrop d'intervenir lorsque personne ne parle
# pendant un certain temps sur un chan. Vous pourrez par exemple lui faire
# raconter des blagues ou s'apitoyer sur sa condition de bot.
#
# Les interventions peuvent afficher une ou plusieurs lignes de texte, envoyer
# des commandes RAW au serveur, ou m�me ex�cuter des commandes tcl. Votre bot
# devient ainsi virtuellement capable de dire ou faire tout ce que vous pourrez
# imaginer afin de redonner vie � votre chan.
# De plus, un certain nombre de variables sp�ciales sont reconnues (d�taill�es
# plus bas dans la section configuration).
#
# Pour plus de r�alisme, le bot simule le temps de frappe des lignes de texte
# et les affiche apr�s un certain d�lai qui varie selon leur longueur.
#
# La commande !reanimator_test permet au propri�taire de l'eggdrop de tester
# en direct l'effet de l'intervention sp�cifi�e.
# Syntaxe : !reanimator_test {{ligne 1}[ {ligne 2}[ {...}]]}
#
# La commande !reanimator_stats permet au propri�taire de l'eggdrop de compter
# et d'afficher le nombre d'interventions dans la base de donn�es, ainsi que
# quelques autres informations concernant les r�glages du script.
#
# Pour activer Reanimator sur un chan, vous devez taper ceci en partyline de
# l'Eggdrop :
# .chanset #NomDuChan +reanimator
# et ceci pour le d�sactiver :
# .chanset #NomDuChan -reanimator
#
 ###############################################################################

#
# Changelog
#
# 1.0
#		- 1�re version
# 1.1
#		- Correction : les caract�res sp�ciaux dans le nom du chan, le nick de
#			l'eggdrop ou le nick d'un utilisateur ne devraient plus poser de probl�me
#			avec les variables %lastnick% %chan% et %botnick%.
#		- Ajout de 2 nouvelles variables : %tcl_randnick% et %tcl_randnick<index>%
#			� utiliser � la place des variables %randnick% et %randnick<index>% dans
#			les interventions de type /tcl. Les caract�res sp�ciaux sont neutralis�s
#			dans les nicks qu'elles retournent (voir documentation incluse dans le
#			script).
# 1.11
#		- Correction : les variables sp�ciales %randnick% %tcl_randnick%
#			%randnick<index>% et %tcl_randnick<index>% ne fonctionnaient pas
#			correctement.
# 1.12
#		- Correction : le fonctionnement des variables %randnick% et %tcl_randnick%
#			ainsi que celui de %randnick<index>% et %tcl_randnick<index>% avaient �t�
#			invers�s, par cons�quent les caract�res sp�ciaux �taient neutralis�s quand
#			ils n'auraient pas d� l'�tre et inversement.
# 1.13
#		- Correction : remplacement des [clock seconds] par [unixtime] dans le code,
#			car pour une raison que j'ignore la fonction clock seconds retourne
#			parfois une heure erron�e.
# 1.14
#		- Correction : les variables sp�ciales %randnick%, %randnick<index>%,
#			%tcl_randnick% et %tcl_randnick<index>% ne fonctionnaient pas correctement
#			avec les nicks contenant des accolades.
#		- Quelques optimisations du code.
# 1.2
#		- Les interventions ne seront d�sormais plus r�p�t�es tant que toutes les
#			autres n'auront pas �t� vues une fois.
#
 ###############################################################################

#
# Licence
#
#		Cette cr�ation est mise � disposition selon le Contrat
#		Attribution-NonCommercial-ShareAlike 3.0 Unported disponible en ligne
#		http://creativecommons.org/licenses/by-nc-sa/3.0/ ou par courrier postal �
#		Creative Commons, 171 Second Street, Suite 300, San Francisco, California
#		94105, USA.
#		Vous pouvez �galement consulter la version fran�aise ici :
#		http://creativecommons.org/licenses/by-nc-sa/3.0/deed.fr
#
 ###############################################################################

if {[::tcl::info::commands ::reanimator::uninstall] eq "::reanimator::uninstall"} { ::reanimator::uninstall }
if { [join [split [::tcl::string::range [lindex $version 0] 0 5] "."] ""] < 1620 } { putloglev o * "\00304\002\[Reanimator - Erreur\]\002\003 La version de votre Eggdrop est \00304\002$version\002\003; Reanimator ne fonctionnera correctement que sur les Eggdrops version 1.6.20 ou sup�rieure." ; return }
if { [info tclversion] < 8.5 } { putloglev o * "\00304\002\[Reanimator - Erreur\]\002\003 Reanimator n�cessite que Tcl 8.5 (ou plus) soit install� pour fonctionner. Votre version actuelle de Tcl est \00304\002$tcl_version\002\003." ; return }
package require Tcl 8.5
namespace eval reanimator {



 ###############################################################################
### Configuration
 ###############################################################################

	### Apr�s combien de temps (en minutes) sans que personne ne parle, le bot
	# interviendra-t-il ?
	variable revive_after 15

	### Intervalle de temps minimum entre deux interventions du bot si personne ne
	# parle (en minutes)
	variable revive_again_after 30

	### Nicks/handles que Reanimator doit ignorer (si vous poss�dez par exemple un
	# autre bot susceptible de parler de temps � autres, et que vous ne voulez pas
	# que cela soit consid�r� comme une preuve d'activit� par Reanimator, ajoutez
	# son nick ou son handle)
	variable ignores {}

	### Nicks/handles que Reanimator ne doit jamais utiliser en choisissant un
	# nick al�atoirement pour les variables %randnick% ou %randnick<index>%
	variable randnick_exclusion_list {}

	### Vitesse � laquelle le bot �crit (pour simuler le temps de frappe)
	# reply_speed_coeff = coefficient de rapidit�, multiplie/divise la rapidit�
	# (0.5 divise par 2 la vitesse de r�f�rence, etc)
	# reply_speed_offset = ajoute ou enl�ve des secondes au d�lai (pour l'affinage)
	variable reply_speed_coeff 1
	variable reply_speed_offset 1

	### Mode monochrome : filtre les codes de couleur/gras/... dans tout ce qui
	# est affich� par Reanimator sur un chan. (0 = d�sactiv� ; 1 = activ�)
	# Remarque : le mode monochrome s'active automatiquement sur les chans o�
	# le mode +c est mis.
	variable monochrome 0

	### Base de donn�es des interventions possibles pour ranimer un chan.
	# Chaque intervention d'une seule ligne doit se pr�senter sous cette forme :
	# 	{{intervention}}.
	# Les interventions sur plusieurs lignes sont possibles de cette fa�on :
	# 	{{1�re ligne} {2�me ligne} {...}}.
	# Vous pouvez utiliser des codes couleurs/gras/... selon la syntaxe habituelle
	#	d'un Eggdrop.
	# Vous pouvez utiliser un certain nombre de variables sp�ciales dans les
	# interventions.
	# Certaines d'entre-elles existent en deux versions dont l'une est pr�fix�e
	# par tcl_; celle-ci doit �tre utilis�e dans les interventions de type /tcl
	# (voir plus bas) car les caract�res sp�ciaux y sont neutralis�s.
	#		%botnick%
	#			Sera remplac� par le nick actuel de l'Eggdrop.
	#		%chan%
	#			Sera remplac� par le nom du chan.
	#		%hour%
	#			Sera remplac� par l'heure qu'il est (seulement l'heure).
	#		%hour_short%
	#			Sera remplac� par l'heure qu'il est (seulement l'heure et sans le 0 au
	#			d�but).
	#		%minutes%
	#			Sera remplac� par l'heure qu'il est (seulement les minutes).
	#		%minutes_short%
	#			Sera remplac� par l'heure qu'il est (seulement les minutes et sans le 0
	#			au d�but).
	#		%seconds%
	#			Sera remplac� par l'heure qu'il est (seulement les secondes).
	#		%seconds_short%
	#			Sera remplac� par l'heure qu'il est (seulement les secondes et sans le 0
	#			au d�but).
	#		%day_num%
	#			Sera remplac� par le jour num�rique.
	#		%day%
	#			Sera remplac� par le jour de la semaine en toutes lettres.
	#		%month_num%
	#			Sera remplac� par le mois num�rique.
	#		%month%
	#			Sera remplac� par le mois en toutes lettres.
	#		%year%
	#			Sera remplac� par l'ann�e.
	#		%idle_time%
	#			Sera remplac� par le temps �coul� depuis que personne n'a parl�.
	#			Si personne n'a jamais parl� sur ce chan et qu'une intervention
	#			contient %idle_time%, elle sera ignor�e et une autre intervention
	#			sera choisie al�atoirement.
	#		%lastnick%
	#			Sera remplac� par le nick de la derni�re personne ayant parl� sur ce
	#			chan. Si personne n'a jamais parl� sur ce chan ou si la derni�re
	#			personne ayant parl� n'est plus sur le chan et qu'une intervention
	#			contient %lastnick%, elle sera ignor�e et une autre intervention
	#			sera choisie al�atoirement.
	#			Les changements de nick de la derni�re personne ayant parl� sont
	#			surveill�s et %lastnick% est tenu � jour automatiquement.
	#		%randnick% / %tcl_randnick%
	#			Sera remplac� par un nick choisi al�atoirement parmi les utilisateurs
	#			pr�sents, � l'exception de l'Eggdrop.
	#			Si vous utilisez 3 fois la variable %randnick% dans une m�me
	#			intervention, elle sera remplac�e par 3 nicks diff�rents.
	# 	%randnick<index>% / %tcl_randnick<index>%
	#			Sera remplac� par un nick pris al�atoirement sur le chan.
	#			Si vous utilisez 3 fois la variable %randnick<index>% dans une m�me
	#			r�ponse, elle sera remplac�e par 3 fois le m�me nick si l'index est
	#			identique. L'index est une valeur num�rique arbitraire.
	#			Voici un exemple qui vous permettra de mieux comprendre :
	#			{{%randnick1% tu es l� ?} {%randnick1% ?} {%randnick2% n'est pas l� non plus je suppose ?}}
	#			donnera sur 3 lignes diff�rentes : Pierre tu es l� ? | Pierre ? | Jean n'est pas l� non plus je suppose ?
	# Certaines commandes sont reconnues dans les interventions :
	#		/me	<texte>
	#			Fait faire un CTCP ACTION au bot
	#		/putserv <commande RAW � envoyer au serveur>
	#			Permet d'envoyer des commandes au serveur IRC.
	#			Exemple : {/putserv kick #monchan Machin raison du kick}
	#			Pour plus d'informations, consultez http://www.faqs.org/rfcs/rfc1459.html
	#		/tcl <commande(s)>
	#			Permet d'ex�cuter une ou plusieurs commandes tcl. Vous pouvez par
	#			exemple appeler une proc d'un autre script.
	#			Exemple : {/tcl putquick "PRIVMSG #testchan :test [regsub -all {\W} "a-b-c $::botnick" "|"]"}
	# Veuillez noter que si vous souhaitez utiliser les caract�res } et { dans les
	# messages standards, les /me et les /putserv, vous devrez les neutraliser
	# comme ceci : \} et \{.
	# Par contre, vous ne devez pas neutraliser les { et } lorsque vous utilisez
	# /tcl, vous devez juste veiller � ce qu'ils soient �quilibr�s.
	#
	# Astuce : vous pouvez inclure des lignes vides dans une intervention afin
	# d'ajouter un d�lai suppl�mentaire entre deux lignes d'une m�me intervention.
	# Pour cela, vous devez r�gler reply_speed_offset � 1 (ou plus) et ajouter
	# autant de {} que vous souhaitez de secondes suppl�mentaires de d�lai.
	#		Exemple : {{/me baille} {} {} {} {} {} {/me s'ennuie}}
	# Dans cet exemple, nous avons ajout� 5 secondes de d�lai suppl�mentaire entre
	# l'affichage de /me baille et de /me s'ennuie. Notez que les lignes vides
	# ainsi ajout�es ne seront pas affich�es.
	#		
	variable database {
		{{/me baille}}
		{{/me baille} {} {} {} {} {} {/me s'ennuie}}
		{{/me tousse}}
		{{/me sifflote}}
		{{/me s'ennuie}}
		{{/me s'ennuie} {} {} {} {} {} {/me baille}}
		{{/me somnole}}
		{{/me s'�tire}}
		{{/me se demande pourquoi personne ne parle}}
		{{/me soupire}}
		{{c'est calme ici...}}
		{{personne ne parle ?}}
		{{et � part �a ?}}
		{{bon} {qu'est-ce qu'on fait maintenant ?}}
		{{euh} {y'a encore quelqu'un ?}}
		{{je suis tout seul ?}}
		{{me laissez pas tout seul :(}}
		{{il fait chaud ici} {/me va ouvrir la fen�tre}}
		{{il fait froid ici} {/me va fermer la fen�tre}}
		{{j'ai une id�e !} {} {} {} {} {} {} {} {} {ah non}}
		{{les ordinateurs ne sont pas intelligents} {ils pensent seulement qu'ils le sont}}
		{{en tant que bot, je trouve votre foi en la technologie plut�t amusante} {} {} {:)}}
		{{je vous dirais bien � quoi je pense en ce moment, mais votre cerveau exploserait.} {remarque �a pourrait �tre marrant}}
		{{demander si les machines peuvent penser est comme demander si les sous-marins savent nager.}}
		{{%randnick% ?}}
		{{t'es l� %randnick1% ?} {} {} {} {%randnick1% ?} {} {} {} {} {:/} {%randnick2% ?} {} {} {} {} {} {pff}}
		{{personne n'a parl� depuis %idle_time% ou je ne suis plus connect� ?}}
		{{t'as dit un truc y'a %idle_time% %lastnick%} {} {} {} {} {} {c'est pas un genre de vent �a ?}}
		{{et donc %lastnick%, tu disais ?}}
		{{qui �a ? %lastnick% ?} {oups} {mauvaise fen�tre}}
		{{d�j� %hour_short%h%minutes% :/}}
		{{bizarre} {d'habitude c'est moins mort vers %hour_short%h}}
		{{\037Oo\037'} {} {} {} {\037xO\037''} {} {} {} {} {:o} {} {} {} {} {} {} {/me s'ennuie}}
        {{Joue avec moi} {} {} {quoi il � personne pour joue avec moi} {/me :(}}
	}

	### Voici quelques exemples d'interventions utilisant /putserv ou /tcl afin
	### d'en illustrer les possibilit�s :
	# Le bot tape !randquote pour afficher une citation al�atoire (n�cessite le
	# script Public Quotes System) :
	#		{{!randquote} {/tcl ::pubqsys::randquote - - - %chan% ""}}
	# Le bot tape !vdm pour afficher une VDM al�atoire (n�cessite le script VDM) :
	#		{{!vdm} {/tcl ::vdm::vdm_command - - - %chan% ""}}
	# Le bot tape !dtc pour afficher une citation al�atoire de www.danstonchat.com
	# (n�cessite le script DansTonChat) :
	#		{{!dtc} {/tcl ::dtc::command - - - %chan% ""}}
	# Le bot invoque quelque chose pour ranimer le chan (n�cessite le script The
	# Summoner) :
	#		{{!invoque pour ranimer le chan} {/tcl ::summoner::main %botnick% - - %chan% "pour ranimer le chan"}}
	# Le bot construit un sc�nario entre deux nicks al�atoires (n�cessite le
	# script IRC Story) :
	#		{{!story %randnick1% %randnick2%} {/tcl ::IRCSTORY::pub_disp_story %botnick% - - %chan% "%tcl_randnick1% %tcl_randnick2%"}}
	# Le bot demande � l'Oracle s'il est bien le bot le plus intelligent du chan,
	# et l'Oracle lui r�pond (n�cessite le script Oracle) :
	#		{{!oracle suis-je le bot le plus intelligent du chan ?} {/tcl ::Oracle::ask_oracle %botnick% - - %chan% "suis-je le bot le plus intelligent du chan ?"} {omg qui a parl� ? oO}}
	# Le bot se voice (s'il poss�de un acc�s suffisant sur le chan) :
	#		{{/putserv MODE %chan% +v %botnick%}}
	# Autre exemple d'utilisation de /tcl :
	#		{{/tcl puthelp "PRIVMSG %chan% :test [regsub -all {\W} "a-b-c $::botnick" "|"]"}}

 ###############################################################################
### Fin de la configuration
 ###############################################################################



	 #############################################################################
	### Initialisation
	 #############################################################################
  variable scriptname "Reanimator"
  variable version "1.2.20160327"
	setudef flag reanimator
	# DEBUGMODE peut valoir 0 (d�sactiv�), 1 (pas d'avertissement pour chaque
	# activit� d�tect�e) ou 2 (tout)
	variable DEBUGMODE 0
	variable delayed_talk_running 0
	variable random_indexes {}
	variable revive_after [expr {$revive_after * 60}]
	variable revive_again_after [expr {$revive_again_after * 60}]
	array set ::reanimator::memory {}
	# Proc�dure de d�sinstallation (le script se d�sinstalle totalement avant chaque rehash ou � chaque relecture au moyen de la commande "source" ou autre)
	proc uninstall {args} {
		putlog "D�sallocation des ressources de \002[set ::reanimator::scriptname]\002..."
		foreach binding [lsearch -inline -all -regexp [binds *[set ns [::tcl::string::range [namespace current] 2 end]]*] " \{?(::)?$ns"] {
			unbind [lindex $binding 0] [lindex $binding 1] [lindex $binding 2] [lindex $binding 4]
		}
		namespace delete ::reanimator
	}
}

 ##############################################################################
### R�animation d'un chan
 ##############################################################################
proc ::reanimator::defibrillator {chan} {
	set counter 1
	set text "!misfit!"
	if {
		(![::tcl::dict::exists $::reanimator::random_indexes $chan])
		|| ([::tcl::dict::get $::reanimator::random_indexes $chan] eq {})
	} then {
		::reanimator::build_random_indexes $chan
	}
	# On s�lectionne l'intervention.
	while { [set text [::reanimator::substitute_special_vars_1st_pass $chan $text]] eq "!misfit!" } {
		set text [lindex $::reanimator::database [lindex [::tcl::dict::get $::reanimator::random_indexes $chan] 0]]
		::tcl::dict::set ::reanimator::random_indexes $chan [lreplace [::tcl::dict::get $::reanimator::random_indexes $chan] 0 0]
		incr counter
		# La ligne suivante sert � prot�ger contre un infinite loop dans le cas o�
		# la base de donn�es ne contient que des interventions comportant des
		# variables n�cessitant qu'une personne ait d�j� parl� sur le chan, et que
		# ce n'est pas le cas.
		if { $counter > 1000 } {
			putloglev o * [::reanimator::filter_styles_if_req - "\00304\[$::reanimator::scriptname - avertissement\]\003 La base de donn�es ne contient aucune intervention utilisable sur $chan pour le moment. L'intervention est annul�e."]
			return
		}
	}
	foreach line $text {
		regexp {^([^\s]+)\s} $line {} first_word
		# hormis pour la commande /tcl, on neutralise les caract�res qui choquent
		# Tcl, � l'exception des codes de couleur/gras/...
		if { (![::tcl::info::exists first_word]) || ($first_word ne "/tcl") } {
			regsub -all {\\\\([\}\{])} [regsub -all {(?!\\002|\\003|\\022|\\037|\\026|\\017)[\$[\[\]"\\]} $line {\\&}] {\1} line ; # "
		}
		# Filtrage des codes couleur/gras/... si le mode monochrome est activ� ou
		# si le flag +c est d�tect� sur le chan.
		# Remarque : stripcodes ne fonctionne pas du fait que les \ ont �t�
		# neutralis�s
		if { ($::reanimator::monochrome) || ([::tcl::string::match *c* [lindex [split [getchanmode $chan]] 0]]) } {
			 regsub -all {\\003[0-9]{0,2}(,[0-9]{0,2})?|\\017|\\037|\\002|\\026|\\006|\\007} $line "" line
		}
		lappend ::reanimator::talk_queue [list $chan $line]
	}
	if { !$::reanimator::delayed_talk_running } { ::reanimator::delayed_talk }
}

 ##############################################################################
### Substitution des variables sp�ciales devant l'�tre en une seule fois
### sur toutes les lignes d'une intervention (%randnick% et %randnick<index>%)
### $text est une liste d'une ou plusieurs r�ponses
 ##############################################################################
proc ::reanimator::substitute_special_vars_1st_pass {chan text} {
	if { $text eq "!misfit!" } { return $text }
	# Si %idle_time% ou %lastnick% sont utilis�s dans l'intervention et que
	# personne n'a encore parl� sur ce chan, ou si %lastnick% a quitt� le chan,
	# on arr�te et on retourne un code d'erreur pour indiquer que cette
	# intervention est inappropri�e.
	if { (([regsub -all {%(tcl_)?idle_time%} $text {&} text] != 0)
		&& ([::reanimator::idle_time $chan] eq "no activity"))
		|| (([regsub -all {%(tcl_)?lastnick%} $text {&} text] != 0)
		&& (([set last_activity [lindex $::reanimator::memory([md5 $chan]) 2]] eq "-")
		|| (($last_activity ne "-")
		&& (![onchan [lindex $::reanimator::memory([md5 $chan]) 1] $chan]))))
	} then {
		return "!misfit!"
	}
	# Liste de nicks des users pr�sents sur le chan, sauf le nick de l'Eggdrop
	set static_nicklist [lreplace [set nicklist [chanlist $chan]] [set index [lsearch -exact $nicklist $::nick]] $index] 
	# On exclut de la liste les users pr�sents dans $randnick_exclusion_list
	foreach excluded_user $::reanimator::randnick_exclusion_list {
		set static_nicklist [lreplace $static_nicklist [set index [lsearch -nocase $static_nicklist $excluded_user]] $index]
		if { [set user [hand2nick $excluded_user]] ne "" } {
			set static_nicklist [lreplace $static_nicklist [set index [lsearch -nocase $static_nicklist $user]] $index]
		}
	}
	# Remplacement des variables %randnick% et %tcl_randnick% par un nick
	# al�atoire chaque fois diff�rent
	set num_thisvar [regsub -all {%(tcl_)?randnick%} $text {&} text]
	if { $num_thisvar != 0 } {
		# S'il ne reste personne dans la liste apr�s avoir retir� le nick du bot et
		# les nicks/handles de ceux qu'on exclut des %randnick%, alors on interromp
		# la substitution et on retourne un code d'erreur
		if { $static_nicklist eq "" } { return "!misfit!" }
		set nicklist $static_nicklist
		set num_users [llength $nicklist]
		# Si on n'a pas plus de %randnick% � remplacer qu'il n'y a d'users
		# sur le chan, on s'assure qu'un m�me nick ne sera pas utilis� plus
		# d'une fois.
		if { $num_thisvar <= $num_users } {
			for { set counter 1 } { $counter <= $num_thisvar } { incr counter } {
				set num_remaining_users [llength $nicklist]
				set random_index [rand $num_remaining_users]
				if { ![regsub {%randnick%} $text [regsub -all {[\}\{]} [set chosen_randnick [lindex $nicklist $random_index]] {\\&}] text] } {
					regsub {%tcl_randnick%} $text [regsub -all {\W} $chosen_randnick {\\\\&}] text
				}
				set nicklist [lreplace $nicklist $random_index $random_index]
			}
		# Si on a plus de %randnick% � remplacer qu'il n'y a d'users sur le
		# chan, on s'autorise � utiliser plusieurs fois le m�me nick,
		# al�atoirement.
		} else {
			for { set counter 1 } { $counter <= $num_thisvar } { incr counter } {
				set random_index [rand $num_users]
				if { ![regsub {%randnick%} $text [regsub -all {[\}\{]} [set chosen_randnick [lindex $nicklist $random_index]] {\\&}] text] } {
					regsub {%tcl_randnick%} $text [regsub -all {\W} $chosen_randnick {\\\\&}] text
				}
			}
		}						
	}
	# Remplacement des variables %randnick<index>% et %tcl_randnick<index>% par un
	# nick al�atoire statique selon l'index.
	# Combien de %randnick<index>% diff�rents devra-t-on remplacer ?
	set num_thisvar [llength [set replacement_list [lsort -unique [regexp -inline -all {%(?:tcl_)?randnick\d+%} $text]]]]
	if { $num_thisvar != 0 } {
		if { $static_nicklist eq "" } { return "!misfit!" }
		set nicklist [::reanimator::randomize_list $static_nicklist]
		set num_users [llength $nicklist]
		# Si on n'a pas plus de %randnick<index>% diff�rents � remplacer
		# qu'il n'y a d'users sur le chan, on s'assure qu'un m�me nick ne
		# sera pas utilis� plus d'une fois.
		if { $num_thisvar <= $num_users } {
			foreach randnick $replacement_list {
				set num_remaining_users [llength $nicklist]
				regexp {\d+} $randnick seed
				set seeded_index [expr {$seed % $num_remaining_users}]
				regsub -all "%tcl_randnick[set seed]%" $text [regsub -all {\W} [set chosen_randnick [lindex $nicklist $seeded_index]] {\\\\&}] text
				regsub -all "%randnick[set seed]%" $text [regsub -all {[\}\{]} $chosen_randnick {\\&}] text
				set nicklist [lreplace $nicklist $seeded_index $seeded_index]
			}
		# Si on a plus de %randnick<index>% � remplacer qu'il n'y a d'users sur le
		# chan, on s'autorise � utiliser plusieurs fois le m�me nick,
		# al�atoirement.
		} else {
			foreach randnick $replacement_list {
				regexp {\d+} $randnick seed
				set seeded_index [expr {$seed % $num_users}]
				regsub -all "%tcl_randnick[set seed]%" $text [regsub -all {\W} [set chosen_randnick [lindex $nicklist $seeded_index]] {\\\\&}] text
				regsub -all "%randnick[set seed]%" $text [regsub -all {[\}\{]} $chosen_randnick {\\&}] text
			}
		}
	}
	return $text
}

 ##############################################################################
### Substitution des autres variables sp�ciales au moment de l'affichage.
### $text est une string
 ##############################################################################
proc ::reanimator::substitute_special_vars_2nd_pass {chan text} {
	if { $text eq "!misfit!" } { return $text }
	regsub -all %idle_time% $text [::reanimator::idle_time $chan] text
	regsub -all %lastnick% $text [regsub -all {\W} [lindex $::reanimator::memory([md5 $chan]) 1] {\\&}] text
	regsub -all %chan% $text [regsub -all {[\[\]\{\}\$\"\\]} $chan {\\&}] text ; # "
	regsub -all %botnick% $text [regsub -all {\W} $::nick {\\&}] text
	regsub -all %hour% $text [set hour [strftime %H [unixtime]]] text
	regsub -all %hour_short% $text [if { $hour != 00 } { set dummy [::tcl::string::trimleft $hour 0] } { set dummy 0 }] text
	regsub -all %minutes% $text [set minutes [strftime %M [unixtime]]] text
	regsub -all %minutes_short% $text [if { $minutes != 00 } { set dummy [::tcl::string::trimleft $minutes 0] } { set dummy 0 }] text
	regsub -all %seconds% $text [set seconds [strftime %S [unixtime]]] text
	regsub -all %seconds_short% $text [if { $seconds != 00 } { set dummy [::tcl::string::trimleft $seconds 0] } { set dummy 0 }] text
	regsub -all %day_num% $text [strftime %d [unixtime]] text
	regsub -all %day% $text [::tcl::string::map -nocase {Mon lundi Tue mardi Wed mercredi Thu jeudi Fri vendredi Sat samedi Sun dimanche} [strftime "%a" [unixtime]]] text
	regsub -all %month_num% $text [strftime %m [unixtime]] text
	regsub -all %month% $text [::tcl::string::map {Jan janvier Feb f�vrier Mar mars Apr avril May mai Jun juin Jul juillet Aou ao�t Sep septembre Oct octobre Nov novembre Dec d�cembre} [strftime %b [unixtime]]] text
	regsub -all %year% $text [strftime %Y [unixtime]] text
	return $text
}

 ##############################################################################
### Surveillance des changements de nick de la derni�re personne ayant parl�
### afin de tenir %lastnick% � jour
 ##############################################################################
proc ::reanimator::survey_lastnick_change {nick host hand chan newnick} {
	if { ![channel get $chan reanimator] } { return }
	if { $nick eq [lindex $::reanimator::memory([set hash [md5 [::tcl::string::tolower $chan]]]) 1] } {
		set ::reanimator::memory($hash) [list [lindex $::reanimator::memory($hash) 0] $newnick [lindex $::reanimator::memory($hash) 2] [lindex $::reanimator::memory($hash) 3]]
		if { $::reanimator::DEBUGMODE >= 1 } {
			putlog [::reanimator::filter_styles_if_req - "\00304\[$::reanimator::scriptname - debug\]\003 $nick est la derni�re personne ayant parl� sur $chan (%lastnick%) et vient juste de changer de nick pour $newnick. Modification de l'enregistrement \00314\$::reanimator::memory($hash) \{[set ::reanimator::memory($hash)]\}"]
		}
	}
}

 ##############################################################################
### Retourne le temps d'idle d'un chan en secondes OU en minutes OU en heures
### car selon le temps �coul�, le besoin de pr�cision varie
 ##############################################################################
proc ::reanimator::idle_time {chan} {
	set hash [md5 $chan]
	set last_activity [lindex $::reanimator::memory($hash) 2]
	if { $last_activity eq "-" } { return "no activity" }
	set idle_time [expr {[unixtime] - $last_activity}]
	if { $idle_time < 60 } {
		return "$idle_time [::reanimator::plural $idle_time "seconde" "secondes"]"
	} elseif { $idle_time < 3600 } {
		set value [expr {abs($idle_time / 60)}]
		return "$value [::reanimator::plural $value "minute" "minutes"]"
	} else {
		set value [expr {abs($idle_time / 3600)}]
		return "$value [::reanimator::plural $value "heure" "heures"]"
	}
}

 ##############################################################################
### Traitement de la file d'attente de parole
 ##############################################################################
proc ::reanimator::delayed_talk {} {
	# si la file d'attente de r�ponses est vide, on arr�te
	if { ![llength $::reanimator::talk_queue] } {
		variable delayed_talk_running 0
		return
	} else {
		variable delayed_talk_running 1
	}
	set raw_text [lindex $::reanimator::talk_queue 0 1]
	set chan [lindex $::reanimator::talk_queue 0 0]
	set first_word ""
	regexp {^([^\s]+)\s(.*)} $raw_text {} first_word leftovers
	switch -exact -- [::tcl::string::tolower $first_word] {
		"/putserv" {
			# le 1er argument est le type (0=/putserv 1=normal 2=/me 3=/tcl)
			# le 2�me argument signifie "ajouter au log ?" (0=non 1=oui)
			::reanimator::display_response 0 $chan $leftovers
		}
		"/me" {
			set delay [expr {round(($::reanimator::reply_speed_coeff * sqrt([::tcl::string::length $leftovers])) + $::reanimator::reply_speed_offset) * 1000}]
			after $delay [list ::reanimator::display_response 1 $chan $leftovers]
			if { $::reanimator::DEBUGMODE >= 1 } { putlog [::reanimator::filter_styles_if_req - "\00304\[$::reanimator::scriptname - debug\]\003 after [expr {$delay / 1000}] \00314--$chan-->\003 $leftovers"] }
		}
		"/tcl" {
			::reanimator::display_response 2 $chan $leftovers
		}
		default {
			set delay [expr {round(($::reanimator::reply_speed_coeff * sqrt([::tcl::string::length $raw_text])) + $::reanimator::reply_speed_offset) * 1000}]
			after $delay [list ::reanimator::display_response 3 $chan $raw_text]
			if { $::reanimator::DEBUGMODE >= 1 } { putlog [::reanimator::filter_styles_if_req - "\00304\[$::reanimator::scriptname - debug\]\003 after [expr {$delay / 1000}] \00314--$chan-->\003 $raw_text"] }
		}
	}
 	return
}

 ##############################################################################
### Affichage d'une r�ponse sur un chan
### type : 0 = /putserv   1 = /me   2 = /tcl   3 = normal
 ##############################################################################
proc ::reanimator::display_response {type chan text} {
	switch -exact -- $type {
		0 {
			set output "putserv \"[::reanimator::substitute_special_vars_2nd_pass $chan $text]\""
		}
		1 {
			set output "puthelp \"PRIVMSG [regsub -all {\W} $chan {\\&}] :\\001ACTION [::reanimator::substitute_special_vars_2nd_pass $chan $text]\\001\""
			putloglev p $chan "* $::nick $text"
		}
		2 {
			set output [::reanimator::substitute_special_vars_2nd_pass $chan $text]
		}
		3 {
			set output "puthelp \"PRIVMSG [regsub -all {\W} $chan {\\&}] :[::reanimator::substitute_special_vars_2nd_pass $chan $text]\""
			putloglev p $chan "<$::nick> $text"
		}
	}
	if { [catch {uplevel 1 $output}] } {
		putloglev o * [::reanimator::filter_styles_if_req - "\00304\[$::reanimator::scriptname - erreur\]\003 L'intervention suivante provoque une erreur et a �t� ignor�e :\00314 $output"]
		putloglev o * [::reanimator::filter_styles_if_req - "\00304\[$::reanimator::scriptname - erreur\]\003 Probl�me rencontr� :\00314 [lindex [split $::errorInfo "\n"] 0]"]
	}
	# on �limine la 1�re r�ponse de la file d'attente car elle a �t� trait�e
	set ::reanimator::talk_queue [lreplace $::reanimator::talk_queue 0 0]
	::reanimator::delayed_talk
	return
}

 ##############################################################################
### Accord au singulier ou au pluriel
 ##############################################################################
proc ::reanimator::plural {value singular plural} {
	if { ($value >= 2) || ($value <= -2) } { return $plural } { return $singular }
}

 ##############################################################################
### M�lange al�atoire des �l�ments d'une liste
### Cette proc�dure provient de http://wiki.tcl.tk/941 (shuffle6)
 ##############################################################################
proc ::reanimator::randomize_list {data} {
	set n [llength $data]
	for { set i 1 } { $i < $n } { incr i } {
		set j [expr {int(rand() * $n)}]
		set temp [lindex $data $i]
		lset data $i [lindex $data $j]
		lset data $j $temp
	}
	return $data
}

 ##############################################################################
### V�rifie si un chan n�cessite d'�tre r�anim�
### Structure de l'array memory($chan_hash) :
### <timestamp> <dernier nick ayant parl�> <timestamp derni�re fois que qq'un a parl�> <init/activity/revived>
 ##############################################################################
proc ::reanimator::check_pulse {min hour day month year} {
	foreach chan [channels] {
		if { [channel get $chan reanimator] } {
			set hash [md5 [set lowerchan [::tcl::string::tolower $chan]]]
			# aucun enregistrement n'est m�moris� pour $chan, on en cr�e un
			if { ![::tcl::info::exists ::reanimator::memory($hash)] } {
				set ::reanimator::memory($hash) [list [unixtime] - - init]
				if { $::reanimator::DEBUGMODE >= 1 } { putlog [::reanimator::filter_styles_if_req - "\00304\[$::reanimator::scriptname - debug\]\003 Cr�ation de l'enregistrement \00314\$::reanimator::memory($hash) \{[set ::reanimator::memory($hash)]\}"] }
			# un enregistrement existe d�j� pour $chan;
			# si le chan n'a pas d�j� �t� r�anim� et que $revive_after minutes se
			# sont �coul�es, ou si le chan a d�j� �t� r�anim� et que
			# $revive_again_after minutes se sont �coul�es, on le r�anime
			} elseif {
				(([lindex $::reanimator::memory($hash) 3] ne "revived")
				 && ([lindex $::reanimator::memory($hash) 0] + $::reanimator::revive_after <= [unixtime]))
				|| (([lindex $::reanimator::memory($hash) 3] eq "revived")
				 && ([lindex $::reanimator::memory($hash) 0] + $::reanimator::revive_again_after <= [unixtime]))
			} then {
				if { $::reanimator::DEBUGMODE >= 1 } {
					if { ([lindex $::reanimator::memory($hash) 3] ne "revived") && ([lindex $::reanimator::memory($hash) 0] + $::reanimator::revive_after <= [unixtime]) } {
						putlog "\00304\[$::reanimator::scriptname - DEBUG\]\003 R�animation de $chan - 1�re intervention."
					} elseif { ([lindex $::reanimator::memory($hash) 3] eq "revived") && ([lindex $::reanimator::memory($hash) 0] + $::reanimator::revive_again_after <= [unixtime]) } {
						putlog "\00304\[$::reanimator::scriptname - DEBUG\]\003 R�animation de $chan - nouvelle tentative."
					}
				}
				::reanimator::defibrillator $lowerchan
				set ::reanimator::memory($hash) [list [unixtime] [lindex $::reanimator::memory($hash) 1] [lindex $::reanimator::memory($hash) 2] revived]
				if { $::reanimator::DEBUGMODE >= 1 } { putlog [::reanimator::filter_styles_if_req - "\00304\[$::reanimator::scriptname - debug\]\003 Modification de l'enregistrement \00314\$::reanimator::memory($hash) \{[set ::reanimator::memory($hash)]\}"] }
			}
		}
	}
}

 ##############################################################################
### De l'activit� a �t� d�tect�e sur un chan
 ##############################################################################
proc ::reanimator::pub_life_sign_detected {nick host hand chan text} {
	::reanimator::life_sign_detected $nick $host $hand $chan $text
}
proc ::reanimator::ctcp_life_sign_detected {nick host hand target ctcp_type text} {
	if { [validchan $target] } {
		::reanimator::life_sign_detected $nick $host $hand $target $text
	}
}
proc ::reanimator::life_sign_detected {nick host hand chan text} {
	if { ([channel get $chan reanimator])
		&& ([lsearch -nocase $::reanimator::ignores $nick] == -1)
		&& ([lsearch -nocase -exact $::reanimator::ignores $hand] == -1)
	} then {
		set ::reanimator::memory([md5 [::tcl::string::tolower $chan]]) [list [unixtime] $nick [unixtime] activity]
		if { $::reanimator::DEBUGMODE == 2 } { putlog [::reanimator::filter_styles_if_req - "\00304\[$::reanimator::scriptname - debug\]\003 Activit� d�tect�e de la part de $nick sur $chan. Modification de l'enregistrement \00314\$::reanimator::memory([set hash [md5 [::tcl::string::tolower $chan]]]) \{[set ::reanimator::memory($hash)]\}"] }
	}
}

 ##############################################################################
### Gestion des couleurs; filtrage des codes de couleur/gras/soulignement si le
### mode +c est d�tect� sur le chan, ou si la couleur est d�sactiv�e
### manuellement
 ##############################################################################
proc ::reanimator::filter_styles_if_req {chan text} {
	if { ($::reanimator::monochrome) || (($chan ne "-") && ([::tcl::string::match *c* [lindex [split [getchanmode $chan]] 0]])) } {
		return [regsub -all {\017} [stripcodes abcgru $text] ""]
	} else {
		return $text
	}
}

 ###############################################################################
### Construction des listes d'index al�atoires servant � �viter la r�p�tition
### d'une intervention tant que tous les autres n'ont pas �t� utilis�es.
 ###############################################################################
proc ::reanimator::build_random_indexes {chan} {
	::tcl::dict::set ::reanimator::random_indexes $chan [::reanimator::randomize_list [lsearch -all $::reanimator::database "*"]]
}

 ##############################################################################
### Commande !reanimator_test_output permettant d'ex�cuter l'intervention
### pass�e en argument
 ##############################################################################
proc ::reanimator::test_output {nick host hand chan text} {
	if { [catch {set textlistlength [llength $text]}] } {
		puthelp [::reanimator::filter_styles_if_req $chan "PRIVMSG $chan :\00304\[$::reanimator::scriptname - erreur\]\003 les \{ et \} ne sont pas �quilibr�s."]
		return
	}
	if { ($text eq "") || ($textlistlength > 1) } {
		puthelp [::reanimator::filter_styles_if_req $chan "PRIVMSG $chan :\037Syntaxe\037 : \002!reanimator_test\002 \{\{ligne 1\}\00314\[\003 \{ligne 2\}\00314\[\003 \{...\}\00314\]\]\003\} \00307|\003 Permet de tester en direct l'intervention sp�cifi�e."]
		return
	}
	# Si aucun enregistrement n'existe pour $chan, on en cr�e un
	if { ![::tcl::info::exists ::reanimator::memory([set hash [md5 [set lowerchan [::tcl::string::tolower $chan]]]])] } {
		set ::reanimator::memory($hash) [list [unixtime] - - init]
		if { $::reanimator::DEBUGMODE >= 1 } { putlog [::reanimator::filter_styles_if_req - "\00304\[$::reanimator::scriptname - debug\]\003 Cr�ation de l'enregistrement \00314\$::reanimator::memory($hash) \{[set ::reanimator::memory($hash)]\}"] }
	}
	foreach line {*}[::reanimator::substitute_special_vars_1st_pass $lowerchan $text] {
		regexp {^([^\s]+)\s} $line {} first_word
		# hormis pour la commande /tcl, on neutralise les caract�res qui choquent
		# Tcl, � l'exception des codes de couleur/gras/...
		if { (![::tcl::info::exists first_word]) || ($first_word ne "/tcl") } {
			regsub -all {\\\\([\}\{])} [regsub -all {(?!\\002|\\003|\\022|\\037|\\026|\\017)[\$[\[\]"\\]} $line {\\&}] {\1} line ; # "
		}
		# Filtrage des codes couleur/gras/... si le mode monochrome est activ� ou
		# si le flag +c est d�tect� sur le chan.
		# Remarque : stripcodes ne fonctionne pas du fait que les \ ont �t�
		# neutralis�s
		if { ($::reanimator::monochrome) || ([::tcl::string::match *c* [lindex [split [getchanmode $chan]] 0]]) } {
			 regsub -all {\\003[0-9]{0,2}(,[0-9]{0,2})?|\\017|\\037|\\002|\\026|\\006|\\007} $line "" line
		}
		lappend ::reanimator::talk_queue [list $lowerchan $line]
	}
	if { !$::reanimator::delayed_talk_running } { ::reanimator::delayed_talk }
}

 ##############################################################################
### commande !reanimator_stats : affiche le nombre d'interventions dans la base
### de donn�es, ainsi que quelques autres informations sur les r�glages du
### script
 ##############################################################################
proc ::reanimator::stats {nick host hand chan arg} {
	puthelp [::reanimator::filter_styles_if_req $chan "PRIVMSG $chan :J'interviendrai si personne ne parle pendant \002[expr {$::reanimator::revive_after / 60}]\002 minutes, puis � nouveau toutes les \002[expr {$::reanimator::revive_again_after / 60}]\002 minutes. Ma base de donn�es contient actuellement \002[set num_interventions [llength $::reanimator::database]]\002 [::reanimator::plural $num_interventions "intervention" "interventions"]."]
}

 ##############################################################################
### Post-initialisation
 ##############################################################################
::reanimator::check_pulse  - - - - -

 ##############################################################################
### Binds
 ##############################################################################
bind evnt - prerehash ::reanimator::uninstall
bind time - "* * * * *" ::reanimator::check_pulse
bind nick - * ::reanimator::survey_lastnick_change
bind pubm - * ::reanimator::pub_life_sign_detected
bind ctcp - ACTION ::reanimator::ctcp_life_sign_detected
bind pub n !reanimator_test ::reanimator::test_output
bind pub n !reanimator_stats ::reanimator::stats


putlog "$::reanimator::scriptname v$::reanimator::version (�2013-2016 Menz Agitat) a �t� charg�."
