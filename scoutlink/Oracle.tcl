 ##############################################################################
#
# Oracle
# v2.3 (12/06/2015)   ©2009-2015 MenzAgitat
#
# IRC: irc.epiknet.org  #boulets / #eggdrop
#
# Mes scripts sont téléchargeables sur http://www.eggdrop.fr
# Retrouvez aussi toute l'actualité de mes releases sur
# http://wiki.eggdrop.fr/Utilisateur:MenzAgitat
#
 ##############################################################################
 
#
# Description
#
# Posez votre question à l'oracle, il vous répondra.
# Il détecte plusieurs types de question différents et donne des réponses
# appropriées (la plupart du temps) choisies parmi un total de 615 réponses
# réparties dans 16 catégories.
#
# Si la question a déjà été posée, la réponse restera la même.
#
# Oracle utilise un algorithme phonétique nommé HaploPhone afin de détecter des
# questions identiques même si l'orthographe et la ponctuation varient.
# Oracle utilise également l'algorithme du Rapport de Relation Différentielle
# afin de tolérer des variations et de reconnaître deux questions très
# légèrement différentes ou formulées différemment, comme étant une seule
# et même question.
# 
# Les scripts HaploPhone (HaploPhone.tcl) et Related Differential Report
# (RDR.tcl) sont requis par Oracle pour fonctionner.
# Assurez-vous que vous possédez bien ces deux scripts et que vous les avez
# ajoutés dans le fichier eggdrop.conf AVANT Oracle.tcl :
#			source scripts/HaploPhone.tcl
#			source scripts/RDR.tcl
#			source scripts/Oracle.tcl
#
# Si vous ajoutez de nouvelles réponses, assurez-vous de les placer dans la
# bonne catégorie et de les formuler de la bonne façon (inspirez-vous des
# réponses existantes), sans quoi l'oracle aura l'air d'être à côté de ses
# pompes.
#
 ###############################################################################

#
# Syntaxe
#
# Pour activer l'Oracle sur un chan, vous devez taper ceci en partyline :
# .chanset #NomDuChan +oracle
# et ceci pour le désactiver :
# .chanset #NomDuChan -oracle
#
# Poser une question à l'oracle :
# !oracle <question>
#
# La commande !oracle_db_size permet au propriétaire de l'Eggdrop de compter et
# d'afficher le nombre de réponses dans la base de données.
#
 ###############################################################################

#
#	Changelog
#
# 1.0
#		- 1ère version
# 2.0
#		- Le code a été en grande partie réécrit, ce qui induit la correction de
#			certains bugs potentiels, plus d'évolutivité, plus de rapidité.
#		- Utiliser le script tout seul sur un chan ne provoque plus d'erreur.
#			(merci à panfleto pour l'avoir découvert et à Artix pour la solution
#			élégante)
#		- La détection du type de question est maintenant plus fiable et tolère une
#			orthographe approximative ainsi que de nombreuses variantes.
#		- Ajout d'un grand nombre de nouvelles réponses.
#		- Ajout de plusieurs nouveaux types de réponses.
#		- Ajout de la commande !oracle_db_size qui permet de compter et d'afficher
#			le nombre de réponses dans la base de données (owner seulement).
#		- L'activation/désactivation du script sur chaque chan se fait maintenant
#			au moyen de la commande .chanset #NomDuChan [+/-]oracle (à taper en
#			partyline)
#		- Passage sous licence Creative Commons.
# 2.1
#		- Correction du type de questions "que...." comme dans "que fais-tu ?"
#		- Ajout d'une nouvelle réponse (pour un nouveau total de 563).
#		- Amélioration de la détection des packages.
#		- Quelques optimisations mineures du code.
# 2.2
#		- Amélioration de la détection du type de question : désormais, moins de
#			questions devraient retourner une réponse neutre.
#		- Le nombre de réponses directes oui/non a été légèrement augmenté.
#		- Le script requiert maintenant le package MenzAgitat's Soundex v2.1
#		- En raison de la mise à jour du soundex, les caractères non-alphabétiques
#			n'influent plus sur la phonétique et la détection de questions déjà posées
#			s'en trouve améliorée.
#		- Ajout de 47 nouvelles réponses (pour un nouveau total de 610).
# 2.3
#		- Correction : les question du type "Qu'est" étaient parfois mal détectées.
#		- Modification : Le package Related Differential Report v1.1 est désormais
#			requis : l'Oracle utilise maintenant le Rapport de Relation Différentielle
#			plutôt que la Distance de Levenshtein pour détecter des questions
#			similaires mais écrites ou formulées différemment. (script du même auteur
#			à télécharger séparément).
#		- Modification : le package Levenshtein n'est désormais plus requis.
#		- Modification : Le package HaploPhone v3.0 est désormais requis : l'Oracle
#			utilise maintenant HaploPhone, qui est une version améliorée de l'ancien
#			package MenzAgitats_Soundex.
#		- Modification : Le package MenzAgitats_Soundex n'est désormais plus requis.
#		- Modification : Afin de diminuer la consommation de mémoire, les réponses
#			aux questions déjà posées ne seront plus stockées littéralement, mais sous
#			la forme type/index.
#		- Modification : si une question mémorisée ressemble à une question posée de
#			type différent, elle ne sera désormais plus considérée comme identique.
#		- Ajout de 5 nouvelles réponses (pour un nouveau total de 615).
#		- Nombreuses optimisations du code.
#
 ###############################################################################

#
# LICENCE:
#		Cette création est mise à disposition selon le Contrat
#		Attribution-NonCommercial-ShareAlike 3.0 Unported disponible en ligne
#		http://creativecommons.org/licenses/by-nc-sa/3.0/ ou par courrier postal à
#		Creative Commons, 171 Second Street, Suite 300, San Francisco, California
#		94105, USA.
#		Vous pouvez également consulter la version française ici :
#		http://creativecommons.org/licenses/by-nc-sa/3.0/deed.fr
#
 ###############################################################################

if {[::tcl::info::commands ::Oracle::uninstall] eq "::Oracle::uninstall"} { ::Oracle::uninstall }
# Note pour les programmeurs :
# Dans la version 1.6.19 d'Eggdrop, le numéro de version affiché par .vbottree
# et [numversion] est incorrect; il affiche 1061800 ou 1061801, ce qui
# correspond à la version 1.6.18. On utilise donc une autre technique pour
# vérifier le numéro de version.
if { [regsub -all {\.} [lindex $::version 0] ""] < 1620 } { putloglev o * "\00304\[Oracle - Erreur\]\003 La version de votre Eggdrop est \00304${::version}\003; Oracle ne fonctionnera correctement que sur les Eggdrops version 1.6.20 ou supérieure." ; return }
if { [::tcl::info::tclversion] < 8.5 } { putloglev o * "\00304\[Oracle - Erreur\]\003 Oracle nécessite que Tcl 8.5 (ou plus) soit installé pour fonctionner. Votre version actuelle de Tcl est \00304${::tcl_version}\003." ; return }
package require Tcl 8.5
if { ([lsearch [package names] "HaploPhone"] == -1) || ([package vcompare [package present HaploPhone] 3.0] == -1) } {
	putloglev o * "\00304\[Oracle - Erreur\]\003 Oracle nécessite que le script HaploPhone v3.0 (ou supérieur) soit chargé pour fonctionner."
	return
}
if { ([lsearch [package names] "Related_Differential_Report"] == -1) || ([package vcompare [package present Related_Differential_Report] 1.2] == -1) } {
	putloglev o * "\00304\[Oracle - Erreur\]\003 Oracle nécessite que le script Related Differential Report v1.1 (ou supérieur) soit chargé pour fonctionner."
	return
}
namespace eval ::Oracle {



 ############################################################################
### Configuration
 ############################################################################

	# Commande utilisée pour questionner l'oracle
	variable oracle_cmd "!oracle"

	# autorisations pour la commande
	variable oracleauth "-|-"

	# Activer le contrôle de flood ? (0 = désactivé / 1 = activé)
	variable antiflood 0

	# Seuil de déclenchement de l'antiflood.
	# Exemple : "6:60" = 6 requêtes maximum en 60 secondes.
	variable flood_threshold "6:60"

	# Intervalle de temps minimum (en secondes) entre l'affichage de 2 messages
	# avertissant que l'antiflood a été déclenché (ne réglez pas cette valeur
	# trop bas afin de ne pas être floodé par les messages d'avertissement de
	# l'antiflood...)
	variable antiflood_msg_interval 30

	# Filtrer les codes de styles (couleurs, gras, ...) dans l'affichage des
	# messages du script ? (0 = non / 1 = oui)
	# Remarque : le filtrage s'active automatiquement si le mode +c est mis sur
	# le chan.
	variable monochrome 0

	# Pourcentage de chances de retourner une réponse neutre (neutral_response)
	variable neutral_rate 10

	# Tolérance maximum pour le rapport de relation différentielle (ne touchez pas
	# à cette valeur sans savoir ce que vous faites)
	variable RDR_tolerance 20

	# Nombre maximum de questions mémorisées par l'Eggdrop (si une question
	# mémorisée est posée plusieurs fois par la même personne, elle donnera
	# toujours la même réponse).
	# Afin de ne pas encombrer excessivement la mémoire, on stocke au maximum
	# $max_memory associations nick/question->réponse.
	variable max_memory 50

	# Types de réponse activés, à l'exeption des types "yesno" et "notaquestion"
	# L'ordre est important et détermine la priorité. 
	# Ne touchez pas à cette variable à moins de savoir ce que vous faites.
	variable enabledTypes {howmuchtime howmany howis howare howgoodis howgoodare howto withwhat howshould when why who where neutral}

	# Expressions régulières utilisées pour la détection du type de la question.
	# N'y touchez pas si vous n'êtes pas familier avec ça.
	array set ::Oracle::regexpTypes {
		howmuchtime {(^|[^[:alpha:]]+)(co[mn]bien|cb(ien)?)\s+de\s+temps?[^[:alpha:]]}
		howmany {(^|[^[:alpha:]]+)co[mn]bien|cb(ien)?[^[:alpha:]]}
		howis {(^|[^[:alpha:]]+)((com+[ea]nt?\s+([eé](st|[st])(ait?)?|suis?|sera(i[ts]?)?))|(([eé](st|[st])(ait?)?|suis?|sera(i[ts]?)?)\s+com+[ea]nt?))[^[:alpha:]]}
		howare {(^|[^[:alpha:]]+)((com+[ea]nt?\s+(s(er)?ont|seraient|[ée]taient))|((s(er)?ont?|seraient|[ée]taient)\s+com+[ea]nt?))[^[:alpha:]]}
		howgoodis {(^|[^[:alpha:]]+)com+[ea]nt?\s+va[ts]?[^[:alpha:]]}
		howgoodare {(^|[^[:alpha:]]+)com+[ea]nt?\s+vont?[^[:alpha:]]}
		howto {com+[ea]nt?\s+([êe]tre?|f(ai|e|è)r+e?|pour+(a|e|io|on)[[:alpha:]]|peut?|puis?j?e?|doi[st]?|on)[^[:alpha:]]}
		withwhat {(^|[^[:alpha:]]+)(par|ave[ck])\s+(qu?|k)oi[^[:alpha:]]}
		howshould {(^|[^[:alpha:]]+)(com+[ea]nt?|de\s+(qu?|k)el+e?s?\s+(fa([çc]|s+)on|mani[èe]r+e?))[^[:alpha:]]}
		when {(^|[^[:alpha:]]+)(qu?|k)and?[^[:alpha:]]}
		why {(^|[^[:alpha:]]+)(pour(\s+)?(qu?|k)oi|pk(oi)?)[^[:alpha:]]}
		who {(^|(^([aà]|[eé](st|[st])(ait?)?|avec|par|pour|sur|sous|de|en)[^[:alpha:]])|([^[:alpha:]](est?|[eé]t(ai[st]?|é)?|avec|par|pour|sur|sous|de|en)[^[:alpha:]]))(qu?|k)i[^[:alpha:]]}
		where {((^|[^[:alpha:]]+)(où|(qu?|k)el+e?s?\s+([ea]ndroit?|coin|lieu|place|zon+e)|(dans?|vers?)\s+(qu?|k)el+e?)|^ou)[^[:alpha:]]}
		neutral {(^|[^[:alpha:]]+)((qu?|k)[e'](l+e?s?)?\s+([eé](st|[st])(ait?)?|s(er)?(ont?|a(i[ts]?|ient)?))|^(qu?|k)e|(qu?|k)el+e?s?|qu'est?(-?ce)?|(qu?|k)es(qu?|k)e?|(qu?|k)oi)[^[:alpha:]]}
	}
	# Pour ceux qui ne savent pas lire les expressions régulières, voici en clair
	# la liste des modèles pris en charge classés par type.
	# Remarque : cette liste n'est pas exhaustive car elle ne comprend pas les
	# variantes orthographiques que permet l'utilisation des expressions
	# régulières.
	#		TYPE				MODELE DE QUESTION
	#		howmuchtime	combien de temps
	#		howmany			combien
	#		howis				comment est/était/suis/sera/serait | est/était/suis/sera/serait comment
	#		howare			comment sont/seront/seraient/étaient | sont/seront/seraient/étaient comment
	#		howgoodis		comment va
	#		howgoodare	comment vont
	#		howto				comment être/faire/pourrais/pourrions/pourrons/peut/puis/doit/on
	#		withwhat		par/avec quoi
	#		howshould		comment | de quelle façon/manière
	#		when				quand
	#		why					pourquoi
	#		who					à/est/était/avec/par/pour/sur/sous/de/en qui
	#		where				où | quel endroit/coin/lieu/place/zone | dans/vers quel
	#		neutral			quel est/était/sera/serait/sont/seront | qu'est-ce | quoi


	###  BIBLIOTHEQUE DE REPONSES

	# Vous pouvez utiliser des variables dans les réponses, elles seront
	# substituées par leur valeur au moment de l'affichage. Exemples :
	#		$nick = nick de la personne qui a posé la question
	#		$chan = chan sur lequel la question a été posée
	#		$question = la question qui a été posée
	#		$randnick =	nick d'une personne choisie aléatoirement sur le chan
	#								(ne peut pas être le nom de l'Eggdrop ni le nick de
	#								la personne qui a posé la question)
	# Vous pouvez aussi utiliser des couleurs (selon la syntaxe habituelle),
	# du gras, du soulignement, ...

	# Réponses si la question n'en est pas une
	set ::Oracle::replyTypes(notaquestion) {
		{si tu le dis...}
		{ok, c'est noté}
		{très intéressant, mais tu n'avais pas une question à poser ?}
		{ok, mais tu n'avais pas une question ?}
		{c'est bien, mais tu n'avais pas une question à poser ?}
		{c'est cool, mais tu n'avais pas une question à poser ?}
		{tant mieux, mais tu n'avais pas une question à poser ?}
		{chouette alors}
		{quelle bonne nouvelle !}
		{waw, c'est super intéressant ce que tu nous racontes là}
		{c'est fou}
		{waw ! mais tu n'avais pas une question à poser ?}
		{mon boulot est de répondre aux questions, pas d'écouter tes certitudes}
		{et la question est ... ?}
		{et à part ça, t'avais pas une question à me poser ?}
		{rappelle-moi quelle était la question déjà ?}
		{c'est pas moi qui te dirai le contraire}
		{c'est une affirmation ?}
		{c'est une question ça ?}
		{mais où est la question ?}
		{où est la question dans tout ça ?}
		{super, raconte-moi ta vie...}
		{c'est comme tu le sens}
		{ça ressemble à une affirmation}
		{tu sembles bien sûr de toi}
		{tu es sûr ?}
		{ah bon ?}
	}
	# Réponses aux questions de type "combien de temps"
	set ::Oracle::replyTypes(howmuchtime) {
		{quelques secondes}
		{quelques secondes, tout au plus}
		{une minute}
		{quelques minutes}
		{3 minutes}
		{5 minutes}
		{10 minutes}
		{une dizaine de minutes}
		{20 minutes}
		{1 heure}
		{quelques heures}
		{5 heures}
		{10 heures}
		{une journée entière}
		{2 jours}
		{2 ou 3 jours}
		{quelques jours}
		{une semaine}
		{2 semaines}
		{2 ou 3 semaines}
		{quelques semaines}
		{un mois}
		{2 mois}
		{2 ou 3 mois}
		{quelques mois}
		{6 mois}
		{1 an}
		{2 ans}
		{5 ans}
		{10 ans}
		{50 ans}
		{un siècle}
		{un million d'années}
		{quelques millions d'années à 10mn près}
		{ça dépend de toi}
	}
	# Réponses aux questions de type "combien"
	set ::Oracle::replyTypes(howmany) {
		{aucun}
		{pas un seul}
		{un seul}
		{juste un}
		{environ 2 ou 3}
		{7 ou 8}
		{une bonne dizaine}
		{je dirais 10 au moins}
		{13 à mon avis}
		{pas plus de 15}
		{environ 20}
		{à peu près 25}
		{presque 30}
		{une quarantaine}
		{42}
		{pas loin de 50}
		{une bonne centaine à vue de nez}
		{plus de 1000 !}
		{des tonnes}
		{une quantité non négligeable}
		{beaucoup}
		{peu}
		{très peu}
		{une quantité négligeable}
		{un chouia}
		{énormément}
		{pas beaucoup}
		{un certain nombre}
		{quelques uns}
		{un bon paquet}
	}
	# Réponses aux questions de type "comment est"
	set ::Oracle::replyTypes(howis) {
		{très joli}
		{de la bonne taille}
		{adorable}
		{cuit à point}
		{vert à pois jaunes}
		{grand avec une moustache}
		{petit et trappu}
		{trop court}
		{trop long}
		{énorme}
		{minuscule}
		{tout bleu}
		{étrange}
		{mémorable}
		{magnifique}
		{superbe}
		{horrible}
		{imprononçable}
		{peu recommandable}
		{trop petit}
		{trop gros}
		{pas assez gros}
		{pas assez long}
		{pas assez petit}
		{velu}
		{poilu}
		{malodorant}
		{mignon}
		{exquis}
		{ridicule}
		{rigolo}
		{intéressant}
		{inintéressant}
		{effrayant}
		{rassurant}
	}
	# # Réponses aux questions de type "comment sont"
	set ::Oracle::replyTypes(howare) {
		{très jolis}
		{de la bonne taille}
		{adorables}
		{cuits à point}
		{verts à pois jaunes}
		{grands avec une moustache}
		{petits et trappus}
		{trop courts}
		{trop longs}
		{énormes}
		{minuscules}
		{tout bleus}
		{étranges}
		{mémorables}
		{magnifiques}
		{superbes}
		{horribles}
		{imprononçables}
		{peu recommandables}
		{trop petits}
		{trop gros}
		{pas assez gros}
		{pas assez longs}
		{pas assez petits}
		{velus}
		{poilus}
		{malodorants}
		{mignons}
		{exquis}
		{ridicules}
		{rigolos}
		{intéressants}
		{inintéressants}
		{effrayants}
		{rassurants}
	}
	# Réponses aux questions de type "comment va"
	set ::Oracle::replyTypes(howgoodis) {
		{très bien}
		{pas trop bien}
		{je ne sais pas}
		{aucune idée}
		{ne demande pas}
		{demande-lui}
		{bien}
		{mal}
		{couci-couça}
		{demande à $randnick}
	}
	# Réponses aux questions de type "comment vont"
	set ::Oracle::replyTypes(howgoodare) {
		{très bien}
		{pas trop bien}
		{je ne sais pas}
		{aucune idée}
		{ne demande pas}
		{demande-leur}
		{bien}
		{mal}
		{couci-couça}
		{demande à $randnick}
	}
	# Réponses aux questions de type "comment faire"
	set ::Oracle::replyTypes(howto) {
		{en y passant plus de temps}
		{en changeant de main de temps en temps}
		{en travaillant dur}
		{en demandant de l'aide à un ami}
		{en y mettant les doigts}
		{avec les doigts}
		{en te sortant les doigts du nez}
		{en arrêtant de croire qu'un bot détient la vérité}
		{en mangeant des quenelles}
		{en arrêtant d'être un boulet}
		{en y pensant très fort}
		{en y croyant très fort}
		{en chatouillant $randnick}
		{en demandant à $randnick}
		{en sautillant sur place}
		{en se roulant par terre}
		{en n'y allant pas par quatre chemins}
		{en prenant un air décidé}
		{en prenant beaucoup de précautions}
		{en prenant son temps}
		{tout seul}
		{aussi rapidement que possible}
		{lentement et consciencieusement}
		{en utilisant un trombone et un chewing-gum}
		{avec beaucoup de courage}
		{à mains nues}
		{en appelant des renforts}
		{librement, sans se poser de questions}
		{avec l'aide de $randnick}
		{avec beaucoup d'enthousiasme}
		{sans beaucoup de conviction}
		{en évitant les obstacles}
		{avec l'aide d'un super-héros}
		{en se tapant la tête contre un mur}
		{en s'organisant}
		{en arrêtant de faire n'importe quoi}
		{en se munissant d'une boîte à outils}
		{en utilisant assez d'explosif pour raser tout le quartier}
		{en utilisant de la colle extra-forte}
		{avec l'aide d'un truc en mousse}
		{en faisant de ton mieux}
		{en y allant doucement}
		{avec les outils adaptés}
		{en allumant un cierge}
		{en criant et en tapant du pied}
	}
	# Réponses aux questions de type "avec quoi"
	set ::Oracle::replyTypes(withwhat) {
		{un pot de cornichons}
		{une petite cuiller}
		{un caillou}
		{une péniche}
		{une crotte de bantha}
		{un tuyau percé}
		{de la crème pour les pieds}
		{du viagra}
		{du talc}
		{de la vaseline}
		{une fourchette}
		{un démonte-pneu}
		{une grue de chantier}
		{une pelle à neige}
		{des bretelles}
		{une roue de vélo}
		{du cirage noir}
		{un chausse-pied}
		{une batte de baseball}
		{un tournevis}
		{un couteau}
		{du fard à paupières}
		{de la sauce pimentée}
		{un moule à gauffres}
		{une tartine beurrée}
		{un balai à chiottes}
		{un air innocent}
		{une pelleteuse}
		{un parachute}
		{les doigts}
		{une pince à épiler}
		{un objet inconnu}
		{une chaussette}
		{de bonnes intentions}
		{de l'humour}
		{une boîte à outils}
		{assez d'explosif pour raser tout le quartier}
		{de la colle extra-forte}
		{un truc en mousse}
		{une déclaration d'amour}
		{une bonne dose d'humour}
		{du papier recyclé}
		{un pied de biche}
	}
	# Réponses aux questions de type "comment"
	set ::Oracle::replyTypes(howshould) {
		{en mettant tous tes doigts dans ton nez en même temps}
		{en prenant beaucoup de précautions}
		{en prenant ton temps}
		{en évitant les obstacles}
		{tout seul}
		{un ouvre-boîte}
		{un taille-crayon}
		{aussi rapidement que possible}
		{lentement et consciencieusement}
		{avec un ami}
		{avec quelqu'un que tu aimes bien}
		{ne le fais pas, c'est mieux}
		{fais-le simplement}
		{pas tout seul}
		{avec de l'aide}
		{en utilisant un trombone et un chewing-gum}
		{en y pensant très fort}
		{avec beaucoup de courage}
		{sans beaucoup de conviction}
		{à mains nues}
		{je ne sais pas comment faire ça}
		{en appelant des renforts}
		{avec l'aide de tes parents}
		{librement, sans te poser de questions}
		{avec l'aide de $randnick}
		{avec un solide sens de l'humour}
		{avec beaucoup d'enthousiasme}
		{en tapant tout ce qui bouge}
		{en prenant un marteau plus gros}
		{avec de la délicatesse}
		{vite et bien}
		{avec des gants}
		{avec du tact}
		{avec de la subtilité}
	}
	# Réponses aux questions de type "quand"
	set ::Oracle::replyTypes(when) {
		{ça s'est déjà produit dans le passé, tu n'avais qu'à être là}
		{tu l'as manqué, c'était il y a 1 heure}
		{maintenant ! ah trop tard}
		{pourquoi pas maintenant ?}
		{maintenant}
		{aujourd'hui}
		{dans 1 minute}
		{dans 3 minutes}
		{dans 5 minutes}
		{dans 5mn, si $randnick ne nous retarde pas...}
		{dans 10 minutes}
		{dans 15 minutes}
		{dans 20 minutes}
		{dans 30 minutes}
		{dans une heure}
		{dans moins de 2 heures}
		{dans 2 heures}
		{cette nuit}
		{demain}
		{demain matin à 6h}
		{demain après-midi}
		{dans 2 jours}
		{dans 3 jours}
		{dans 4 jours}
		{dans 5 jours}
		{dans 6 jours}
		{dans 1 semaine}
		{la semaine prochaine}
		{le mois prochain}
		{dans 2 mois}
		{dans 3 mois}
		{dans 6 mois}
		{dans 1 an}
		{dans le courant de l'année prochaine}
		{dans 2 ans}
		{dans 3 ans}
		{dans 5 ans}
		{dans 10 ans}
		{dans 20 ans}
		{dans 50 ans}
		{dans quelques années}
		{dans 1 siècle}
		{dans 1000 ans}
		{dans 1 million d'années}
		{dans quelques millions d'années à 10mn près}
		{en janvier}
		{en février}
		{en mars}
		{en avril}
		{en mai}
		{en juin}
		{en juillet}
		{en août}
		{en septembre}
		{en octobre}
		{en novembre}
		{en décembre}
		{cet été}
		{cet hiver}
		{au printemps}
		{en automne}
		{trois jours avant la 2ème pleine lune après ton prochain anniversaire}
		{le jour de ton anniversaire}
		{dès qu'il se mettra à pleuvoir}
		{dès qu'il se mettra à neiger}
		{quand les poules auront des dents}
		{à la saint Glinglin}
		{après le déluge}
		{à la prochaine pleine lune}
		{ça n'arrivera pas à moins que tu ne quittes dès maintenant ton écran pour agir}
		{jamais}
		{jamais}
		{jamais}
		{jamais}
		{jamais}
	}
	# Réponses aux questions de type "pourquoi"
	set ::Oracle::replyTypes(why) {
		{pourquoi pas ?}
		{parce que c'est comme ça et puis c'est tout}
		{parce que c'est comme ça}
		{pour te donner l'air intelligent}
		{pour te ridiculiser}
		{parce que c'est beaucoup plus marrant comme ça}
		{parce qu'on lui a demandé de le faire}
		{pour te faire parler}
		{parce que tu le vaux bien}
		{parce que t'es un boulet}
		{parce que t'es un marrant}
		{parce que t'es un winner}
		{parce que sinon, ça ne serait pas drôle}
		{parce que :)}
		{parce que $randnick l'a dit}
		{parce que $randnick l'a prédit}
		{parce que $randnick a insisté pour ça}
		{à l'origine, c'était pour faire plaisir à $randnick}
		{parce que Nostradamus l'a prédit}
		{parce que le monde est injuste}
		{parce que c'est ainsi que vont les choses}
		{pour te faire plaisir}
		{pour t'emmerder}
		{pour te faire taper "!oracle $question"}
		{parce que l'équilibre de l'univers en dépend}
		{parce que t'as pas de chance}
		{parce que le hasard en a décidé ainsi}
		{je t'en pose des questions ?}
	}
	# Réponses aux questions de type "qui"
	set ::Oracle::replyTypes(who) {
		{quelqu'un de bien}
		{quelqu'un qui pose moins de questions que toi}
		{un mutant avec des tentacules}
		{un homme déguisé en femme}
		{le plus gros boulet connu}
		{un illustre inconnu}
		{ta soeur}
		{un malade mental}
		{$randnick}
		{$randnick}
		{$randnick}
		{ton père}
		{ta mère}
		{un pote de ta soeur}
		{une amie de ta mère}
		{un voisin}
		{un ami qui te veut du bien}
		{ton meilleur ami}
		{Dédé le Cochon}
		{un fuyard recherché par la police}
		{un emmerdeur de première}
		{quelqu'un qui ne veut pas être reconnu}
		{un animal de compagnie}
		{un psychopathe}
		{personne d'autre que toi}
		{toi-même}
		{toi}
		{moi}
		{c'est pas moi}
	}
	# Réponses aux questions de type "où"
	set ::Oracle::replyTypes(where) {
		{dans la forêt}
		{dans la cuisine}
		{dans un lit}
		{dans ton lit}
		{sous le lit}
		{dehors}
		{à l'intérieur}
		{en Italie}
		{au Vénézuela}
		{en Suisse}
		{en Australie}
		{près de ton meilleur ami}
		{près de ton pire ennemi}
		{chez toi}
		{sur ton lieu de travail}
		{dans le placard}
		{dans la rue}
		{dans la cave}
		{dans une voiture}
		{sur le tapis}
		{sous le tapis}
		{accroché au mur}
		{dans un couloir}
		{devant ton ordinateur}
		{sur une chaise}
		{dans le réfrigérateur}
		{attaché à un monument}
		{dans la maison d'un ami}
		{dans la main de quelqu'un que tu aimes bien}
		{au fond de l'océan}
		{à DisneyLand}
		{au McDo}
		{dans les toilettes}
		{dans une baignoire}
		{dans l'herbe d'un pré}
		{derrière des portes fermées}
		{dans la 4ème dimension}
		{à côté de toi}
		{sur la lune}
		{quelque part dans la galaxie}
		{quelque part où tu ne peux pas le voir}
		{par là -->}
		{ici}
		{tu as regardé sur www.perdu.com ?}
		{sur ce chan}
		{chez $randnick}
		{dans le frigo de $randnick}
		{sur les genoux de $randnick}
		{sur une autre planète}
		{DTC}
		{DTC}
		{DTC}
		{DTC}
	}
	# Réponses neutres. Attention à ce que vous mettez dans cette catégorie, ça
	# doit être le plus neutre possible afin de convenir à tous les types de
	# questions.
	set ::Oracle::replyTypes(neutral) {
		{oh regarde là bas ! une diversion !}
		{ne parlons pas des choses qui fâchent}
		{mieux vaut changer de sujet}
		{la réponse est : 42}
		{il faudrait être vraiment dérangé pour répondre à ça}
		{c'est une question que tu devrais te poser à toi-même}
		{je ne sais pas}
		{si tu savais...}
		{tu as de ces questions...}
		{*Joker*}
		{je ne peux pas avoir réponse à tout}
		{demande à quelqu'un d'autre}
		{tu n'as pas besoin de le savoir}
		{TUUUT TUUUT TUUUT TUUUT}
		{il y a des questions qu'il vaut mieux ne pas poser}
		{je ne sais pas \00313*rougit*\003}
		{...}
		{je ne répondrai pas à ça}
		{il y a des choses qu'il vaut mieux ne pas savoir}
		{c'est quoi ces questions ?  \037oO\037'}
		{on t'a payé pour m'emmerder ?}
		{va savoir...}
		{je pourrais te répondre mais après cela je serais obligé de te tuer}
		{comment suis-je sensé savoir ça ? je suis une fonction aléatoire dans un bot, tu sais ?}
		{tu es trop intelligent pour demander ça}
		{donne moi de l'argent et je verrai ce que je peux faire}
		{plus de données sont requises pour répondre précisément à cette question}
		{merci de reformuler votre question}
		{erreur de syntaxe}
		{Cette fonction sonne occupé. Merci de réessayer dans quelques minutes...}
		{désolé, je n'écoutais pas}
		{il est totalement impossible de répondre objectivement à cette question}
		{je ferais mieux de ne pas te répondre maintenant}
		{et toi tu en penses quoi ?}
		{oublie ça}
		{qui s'en soucie ?}
		{on s'en fout}
		{osef}
		{je m'en fous un peu en fait}
		{question stupide, au suivant}
		{crois-moi, tu ne veux pas vraiment le savoir}
		{tu n'aimerais pas connaître la réponse}
		{la réponse ne va pas te plaire}
		{demande donc à $randnick}
		{$randnick pourrait t'en parler...}
		{je suis vraiment obligé de répondre à toutes les questions idiotes ?}
		{tu connais déjà la réponse}
	}
	# Réponses de type oui/non
	set ::Oracle::replyTypes(yesno) {
		{oui}
		{oui}
		{oui}
		{oui}
		{oui}
		{oui}
		{oui}
		{oui}
		{non}
		{non}
		{non}
		{non}
		{non}
		{non}
		{non}
		{non}
		{pas forcément}
		{peut-être dans un futur proche}
		{peut-être}
		{je ne parierais pas là dessus}
		{oui, absolument}
		{pas nécessairement}
		{oh que oui !}
		{oui, peut-être}
		{ça se pourrait}
		{les rumeurs disent que oui}
		{évidemment pas, cesse de poser des questions stupides}
		{oui : 78 | non : 93 | votes blancs : 4 | abstention : 15}
		{ça va pas non ?}
		{bien sûr}
		{il y a des chances}
		{il y a peu de chances}
		{ne dis pas n'importe quoi}
		{sois-en sûr}
		{pas du tout}
		{t'as qu'à compter là dessus}
		{très certainement, oui}
		{absolument pas}
		{évidemment, quelle question !}
		{qui t'a raconté ça ?!}
		{ouais et y'a ptet des pingouins sur Mars aussi...}
		{oui mais non}
		{c'est possible en effet}
		{la probabilité est de 1/9702831101}
		{bien sûr, ça a même été prédit par l'Institut des Risques Majeurs}
		{ben oui, tu es bien le seul à en douter encore}
		{et pas qu'un peu !}
		{non, pas du tout... ah... on me dit que si dans mon oreillette...}
		{si je te dis que non, tu vas pas aller te suicider ou un autre truc dingue ?}
		{ah non pas du tout}
		{si ça te fait plaisir d'y croire, alors oui}
		{ouais}
		{seulement si tu y crois très fort}
		{mmh je dirais que oui}
		{désolé, rien n'est moins sûr}
		{La réponse m'apparaît un peu floue mais on dirait que c'est oui}
		{La réponse est non seulement si Saturne est alignée avec Pluton et Neptune}
		{nop :(}
		{yep :)}
		{il semblerait que non mais c'est peut-être un bug}
		{si mes sources sont fiables, oui}
		{c'est certain}
		{j'en doute}
		{tel que je le vois, ma réponse est oui}
		{ouais, et moi je suis le Pape}
		{c'est ridicule !}
		{tu aimerais, hein ?}
		{ouep ^^}
		{sûr !}
		{j'espère que tu plaisantes...}
		{même pas en rêve}
		{seulement dans ton imagination}
		{on dirait bien que oui}
		{je crois que oui}
		{grave !}
		{bah, c'est n'importe quoi}
		{c'est incroyable le nombre de rumeurs qui peuvent circuler sur ce chan...}
		{$randnick ne pourra pas dire le contraire}
		{ou pas}
	}

 ############################################################################
### Fin de la configuration
 ############################################################################




 ##############################################################################
### initialisation
 ##############################################################################
	variable scriptname "Oracle"
	variable version "2.3.20150612"
	variable DEBUGMODE 0
	setudef flag oracle
	scan $flood_threshold "%d:%d" ::Oracle::antiflood_max_instances ::Oracle::antiflood_instance_length
	array set ::Oracle::instance {}
	array set ::Oracle::antiflood_msg {}
	array set ::Oracle::phonetics_table {}
	# Procédure de désinstallation (le script se désinstalle totalement avant
	# chaque rehash ou à chaque relecture au moyen de la commande "source" ou
	# autre)
	proc uninstall {args} {
		putlog "Désallocation des ressources de ${::Oracle::scriptname}..."
		foreach binding [lsearch -inline -all -regexp [binds *[set ns [::tcl::string::range [namespace current] 2 end]]*] " \{?(::)?$ns"] {
			unbind [lindex $binding 0] [lindex $binding 1] [lindex $binding 2] [lindex $binding 4]
		}
		foreach running_utimer [utimers] {
			if { [::tcl::string::match "*[namespace current]::*" [lindex $running_utimer 1]] } { killutimer [lindex $running_utimer 2] }
		}
		namespace delete ::Oracle
	}
}

 ##############################################################################
### procédure principale
 ##############################################################################
proc ::Oracle::ask_oracle {nick host handle chan question} {
	if {
		!([channel get $chan oracle])
		|| (($::Oracle::antiflood)
		&& ([::Oracle::antiflood $chan]))
	} then {
		return
	} elseif { [set question [::tcl::string::trim $question]] eq "" } {
		puthelp "PRIVMSG $chan :!$nick"
		return
	} elseif { $question eq "?" } {
		puthelp "PRIVMSG $chan :!$nick ?"
		return
	} else {
		# Si la question posée... n'est pas une question.
		if { ![::tcl::string::match "*\\?*" $question] } {
			set detected_question_type "notaquestion"
			set answer [::Oracle::process_answer $nick $chan [lindex $::Oracle::replyTypes($detected_question_type) [set answer_index [rand [llength $::Oracle::replyTypes($detected_question_type)]]]]]
		} else {
			set nick_hash [md5 $nick]
			set phonetics [::HaploPhone::process [::tcl::string::map {"‹" "<" "›" ">" "“" "\"" "”" "\"" "…" "..."} $question]]
			set known_question 0
			# On définit le type de question par défaut si aucun type n'est reconnu.
			set detected_question_type "yesno"
			# On tente de reconnaitre le type de question.
			foreach currentType $::Oracle::enabledTypes {
				if { [regexp -nocase $::Oracle::regexpTypes($currentType) $question] } {
					set detected_question_type $currentType
					break
				}
			}
			# On définit que, par défaut, le type de réponse sera lié au type de
			# question détecté.
			set applied_question_type $detected_question_type
			# Si la question a déjà été posée, on retrouve la réponse qui a été donnée.
			if { [set array_entry [::Oracle::compare_RDR $nick_hash $detected_question_type $phonetics]] != -1 } {
				set known_question 1
				lassign [split $::Oracle::phonetics_table($array_entry) "¤"] applied_question_type answer_index
			# Aléatoirement, on obtient une réponse neutre quelle que soit la
			# question.
			} elseif { [expr ([clock clicks -milliseconds] % 100) + 1] <= $::Oracle::neutral_rate } {
				set applied_question_type "neutral"
			}
			# On choisit une réponse au hasard.
			if { ![::tcl::info::exists answer_index] } { 
				set answer_index [rand [llength $::Oracle::replyTypes($applied_question_type)]]
			}
			set answer [::Oracle::process_answer $nick $chan [lindex $::Oracle::replyTypes($applied_question_type) $answer_index]]
			# Si cette question n'a jamais été posée auparavant, on la mémorise.
			if { !$known_question } {
				# Si le nombre de questions stockées en mémoire atteint la limite
				# autorisée ($max_memory), on supprime la plus ancienne.
				if { [array size ::Oracle::phonetics_table] >= $::Oracle::max_memory } {
					unset ::Oracle::phonetics_table([lindex [lsort [array names ::Oracle::phonetics_table]] 0])
				}
				# On stocke la valeur phonétique de la question, ainsi que la réponse
				# associée.
				set ::Oracle::phonetics_table([unixtime]¤${nick_hash}¤${phonetics}¤$detected_question_type) "${applied_question_type}¤$answer_index"
			}
		}
		if { $::Oracle::DEBUGMODE } { ::Oracle::output_message $chan quick "\00314\[Oracle - debug\]\003 [if {[::tcl::info::exists known_question]} {set dummy "known question : $known_question \00314|\003 "} {set dummy ""}][if {[::tcl::info::exists phonetics]} {set dummy "phonetics : $phonetics \00314|\003 "} {set dummy ""}]detected type : $detected_question_type \00314|\003 [if {[::tcl::info::exists applied_question_type]} {set dummy "applied type : $applied_question_type \00314|\003 "} {set dummy ""}]answer_index : $answer_index" }
		::Oracle::output_message $chan help "$nick > $answer"
		# On ajoute manuellement aux logs puisque le logger interne ne le fait pas
		# avec les commandes et les réponses de l'Eggdrop.
		putloglev p $chan "<$nick> $::Oracle::oracle_cmd $question"
		putloglev p $chan "<$::botnick> $nick > $answer"
	}
}

 ##############################################################################
### Neutralisation des antislashes (sauf codes de contrôle \002 \003 \022
### \037 \026 \017) et substitution des variables dans les réponses.
 ##############################################################################
proc ::Oracle::process_answer {nick chan answer} {
	set randnick [::Oracle::randnick $nick $chan]
	return [subst -nocommands [regsub -all {(?!\\002|\\003|\\022|\\037|\\026|\\017)(\\)} $answer {\\\\}]]
}

 ##############################################################################
### Recherche de correspondances ayant un rapport de relation différentielle
### inférieur à la tolérance définie dans la table phonétique.
 ##############################################################################
proc ::Oracle::compare_RDR {nick_hash detected_question_type phonetics} {
	if { [::tcl::info::exists ::Oracle::phonetics_table] } {
		foreach array_entry [array names ::Oracle::phonetics_table] {
			lassign [split $array_entry "¤"] {} stored_nick_hash stored_phonetics stored_question_type
			if {
				($nick_hash eq $stored_nick_hash)
				&& ($detected_question_type eq $stored_question_type)
				&& ([::RDR::RDR $stored_phonetics $phonetics] <= $::Oracle::RDR_tolerance)
			} then {
				return $array_entry
			}
		}
		return -1
	}
}

 ##############################################################################
### Retourne un nick aléatoire parmi les users présents sur le chan (sauf
### l'Eggdrop, sauf les autres Eggdrops du botnet, sauf l'user qui a posé la
### question).
 ##############################################################################
proc ::Oracle::randnick {nick chan} {
	set users_list [lreplace [set users [chanlist $chan -b|]] [set index [lsearch $users $nick]] $index]
	set users_list [lreplace $users_list [set index [lsearch $users_list $::botnick]] $index]
	if {![llength $users_list]} {
		return "quelqu'un"
	}
	return [lindex $users_list [rand [llength $users_list]]]
}

 ##############################################################################
### Accord au singulier ou au pluriel.
 ##############################################################################
proc ::Oracle::plural {value singular plural} {
	if {
		($value >= 2)
		|| ($value <= -2)
	} then {
		return $plural
	} else {
		return $singular
	}
}

 ###############################################################################
### Affichage d'un message.
 ###############################################################################
proc ::Oracle::output_message {chan queue data} {
	# Filtrage des styles si nécessaire
	if { ($::Oracle::monochrome == 1)
		|| ([::tcl::string::match *c* [lindex [split [getchanmode $chan]] 0]])
	} then {
		put$queue "PRIVMSG $chan :[regsub -all "\017" [stripcodes abcgru $data] ""]"
	} else {
		put$queue "PRIVMSG $chan :$data"
	}
	return
}

 ###############################################################################
### Test de l'existence d'un utimer, renvoi de son ID
 ###############################################################################
proc ::Oracle::utimerexists {command} {
	foreach utimer_ [utimers] {
		if { ![::tcl::string::compare $command [lindex $utimer_ 1]] } then {
			return [lindex $utimer_ 2]
		}
	}
	return
}

 ##############################################################################
### Commande !oracle_db_size : affiche le nombre de réponses dans la base
### de données.
 ##############################################################################
proc ::Oracle::show_db_size {nick host handle chan arg} {
	set total 0
	foreach currentType $::Oracle::enabledTypes {
		if { [::tcl::info::exists output] } {
			append output " \00307|\003 "
		}
		append output "$currentType :\00314 [set num_answers [llength $::Oracle::replyTypes($currentType)]]\003"
		incr total $num_answers
	}
	append output " \00307|\003 notaquestion :\00314 [set num_answers1 [llength $::Oracle::replyTypes(notaquestion)]]\003 \00307|\003 yesno :\00314 [set num_answers2 [llength $::Oracle::replyTypes(yesno)]]\003"
	set total [expr $total + $num_answers1 + $num_answers2]
	append output " \00304|\003 nombre total de réponses dans la base de données :\00314 $total\003"
	::Oracle::output_message $chan help "$output"	
}

 ###############################################################################
### Contrôle du flood
 ###############################################################################
proc ::Oracle::antiflood {chan} {
	set chan_hash [md5 $chan]
	# l'antiflood est dans un statut neutre, on l'initialise
	if { ![::tcl::info::exists ::Oracle::instance($chan_hash)] } {
		set ::Oracle::instance($chan_hash) 0
		set ::Oracle::antiflood_msg($chan_hash) 0
	}
	if { $::Oracle::instance($chan_hash) >= $::Oracle::antiflood_max_instances } {
		if { !$::Oracle::antiflood_msg($chan_hash) } {
			set ::Oracle::antiflood_msg($chan_hash) 2
			::Oracle::output_message $chan quick "\00304:::\003 \00314Contrôle de flood activé pour la commande \002$::Oracle::oracle_cmd\002 : pas plus de $::Oracle::antiflood_max_instances [::Oracle::plural $::Oracle::antiflood_max_instances "requête" "requêtes"] en $::Oracle::antiflood_instance_length [::Oracle::plural $::Oracle::antiflood_instance_length "seconde" "secondes"].\003"
			if { [set msgresettimer [::Oracle::utimerexists "::Oracle::antiflood_msg_reset $chan_hash"]] ne ""} {
				killutimer $msgresettimer
			}
			utimer $::Oracle::antiflood_msg_interval [list ::Oracle::antiflood_msg_reset $chan_hash]
		} elseif { $::Oracle::antiflood_msg($chan_hash) == 1 } {
			set ::Oracle::antiflood_msg($chan_hash) 2
			::Oracle::output_message $chan help "\00304:::\003 \00314Le contrôle de flood est toujours actif, merci de patienter.\003"
			if { [set msgresettimer [::Oracle::utimerexists "::Oracle::antiflood_msg_reset $chan_hash"]] ne ""} {
				killutimer $msgresettimer
			}
			utimer $::Oracle::antiflood_msg_interval [list ::Oracle::antiflood_msg_reset $chan_hash]
		}
		return 1
	} else {
		incr ::Oracle::instance($chan_hash)
		utimer $::Oracle::antiflood_instance_length [list ::Oracle::antiflood_close_instance $chan_hash]
		return 0
	}
}
proc ::Oracle::antiflood_close_instance {chan_hash} {
	incr ::Oracle::instance($chan_hash) -1
	if { $::Oracle::instance($chan_hash) == 0 } {
		unset ::Oracle::instance($chan_hash)
		unset ::Oracle::antiflood_msg($chan_hash)
	} else {
		set ::Oracle::antiflood_msg($chan_hash) 0
		if { [set msgresettimer [::Oracle::utimerexists "::Oracle::antiflood_msg_reset [set chan_hash]"]] ne "" } {
			killutimer $msgresettimer
		}
	}
	return
}
proc ::Oracle::antiflood_msg_reset {chan_hash} {
	set ::Oracle::antiflood_msg($chan_hash) 1
	return
}

 ##############################################################################
### Binds
 ##############################################################################
bind pub $::Oracle::oracleauth $::Oracle::oracle_cmd ::Oracle::ask_oracle
bind pub n !oracle_db_size ::Oracle::show_db_size
bind evnt - prerehash ::Oracle::uninstall


putlog "$::Oracle::scriptname v$::Oracle::version (©2009-2015 MenzAgitat) a été chargé."
