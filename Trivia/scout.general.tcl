#########################################
#        _____     _     _              #
#       |_   _|___|_|_ _|_|___          #
#         | | |  _| | | | | .'|         #
#         |_| |_| |_|\_/|_|__,|         #
#                                       #
#  Version : 1.3.4     Patch Level : 1  #
#  Auteur : Souperman  Auteur : TiSmA   #
#                                       #
#########################################

###########
# Sources #
###########

source "[file dirname [info script]]/trivia.conf"
source "[file dirname [info script]]/alltools.tcl"

#############
# Variables #
#############

set tgqdb "[file dirname [info script]]/db/general.questions"
set tgscf "[file dirname [info script]]/db/trivia.scores"
set tgerrfil "[file dirname [info script]]/db/general.errors"
set tgver "1.3.4"
set tgrel "release"
set tgpat "1"

################
# Verification #
################

if {[info tclversion]<8.2} {
	putlog "\002[file tail [info script]]\002 Chargement Impossible : Ce script doit utiliser la librairie tcl 8.2 où supérieure."
	return
}

if {$tgtimeanswer==1&&[info tclversion]<8.3} {
	putlog "\002[file tail [info script]]\002 Chargement Impossible : La synchronisation des réponses doit utiliser la librairie tcl 8.2 où supérieure."
	set tgtimeanswer 0
}

if {![info exists alltools_loaded]||$allt_version<205} {
	putlog "\002[file tail [info script]]\002 Chargement Impossible : Ce script doit utiliser alltools.tcl."
	return
}

if {[utimerexists tghtml]!=""} {killutimer $tghtmlrefreshtimer}

if {$tghtmlrefresh>0} {
	set tghtmlrefreshtimer [utimer $tghtmlrefresh tghtml]
}

if {![file exists $tgqdb]} {
	putlog "\002[file tail [info script]]\002 Chargement Impossible : $tgqdb n'existe pas."
	return
}

if {[llength [split $tgchan]]!=1} {
	putlog "\002[file tail [info script]]\002 Chargement Impossible : Trop de salons spécifiés."
	return
}

if {![info exists tgplaying]} {
	set ctcp-version "${ctcp-version} (Trivia.tcl $tgver-pl$tgpat by Souperman & TiSmA)"
	set tgplaying 0
}

if {![info exists tghintnum]} {set tghintnum 0}

if {![info exists tgmissed]} {set tgmissed 0}

bind pubm $tgflagsstart "$tgchan %$tgcmdstart" tgstart
bind pubm $tgflagsstop "$tgchan %$tgcmdstop" tgstop

proc tgbindhintcmd {} {
	global tgflagshint tgcmdhint
	bind pubm $tgflagshint "$::tgchan %$tgcmdhint" tgforcehint
}

proc tgunbindhintcmd {} {
	global tgflagshint tgcmdhint
	unbind pubm $tgflagshint "$::tgchan %$tgcmdhint" tgforcehint
}

tgbindhintcmd

bind pubm $tgflagsskip "$tgchan %$tgcmdskip" tgskip
bind pubm $tgflagstop10 "$tgchan %$tgcmdtop10" tgshowtop10
bind join -|- "$tgchan *" tgjoinmsg
bind msg - $tgcmdhelp tggivehelp
bind msg - $tgcmdlookup tgscorelookup
bind msg - $tgcmdtarget tgtargetlookup
bind msg - $tgcmderror tgerror
bind msg - $tgcmdrules tgrulesmsg
bind msg $tgflagsreset "$tgcmdreset" tgresetscores
bind kick - "$tgchan $botnick" tgbotgotkicked
bind evnt - disconnect-server tgbotgotdisconnected

proc tgstart {nick host hand chan text} {
	global tgplaying tgstreak tgchan tgerrremindtime tgerrremindtimer tgmissed
	if {[strlwr $tgchan]==[strlwr $chan]} {
		if {$tgplaying==0} {
			tggamemsg "[tgcolstart]Démarrage du QuiZz par $nick"
			tgnextq
			set tgplaying 1
			set tgstreak 0
			set tgmissed 0
			set tgerrremindtimer [timer $tgerrremindtime tgerrremind]
		}
	}
}

proc tgstop {nick host hand chan text} {
	global tghinttimer tgnextqtimer tgplaying tgchan tgcurrentanswer tgstreak tgstreakmin
	global tgerrremindtimer tgrebindhinttimer
	if {[strlwr $tgchan]==[strlwr $chan]} {
		if {$tgplaying==1} {
			tggamemsg "[tgcolstop]Arret du QuiZz par $nick"
			if {$tgstreakmin>0&&[lindex [split $tgstreak ,] 1]>=$tgstreakmin} { tgstreakend }
			set tgstreak 0
			set tgplaying 0
			catch {unbind pubm -|- "$tgchan *" tgcheckanswer}
			if {[utimerexists tghint]!=""} {killutimer $tghinttimer}
			if {[utimerexists tgnextq]!=""} {killutimer $tgnextqtimer}
			if {[timerexists tgerrremind]!=""} {killtimer $tgerrremindtimer}
			if {[utimerexists tgrebindhinttimer]!=""} {killtimer $tgrebindhinttimer}
		}
	}
}

proc tgforcehint {nick host hand chan text} {
	global tghinttimer tgnextqtimer tgplaying tgchan tgcurrentanswer tgstreak tgstreakmin
	global tgtempnohint tgmaxhintcurrent tghintnum tgrebindhinttimer tgtempnohint
	if {[strlwr $tgchan]==[strlwr $chan]} {
		if {$tgplaying==1&&[utimerexists tghint]!=""} {
			killutimer $tghinttimer
			tghint
			tgunbindhintcmd
			if {$tghintnum<$tgmaxhintcurrent} {
				set tgrebindhinttimer [utimer $tgtempnohint tgbindhintcmd]
			}
		}
	}
}

proc tgskip {nick host hand chan text} {
	global tghinttimer tgnextqtimer tgplaying tgchan tgcurrentanswer tgstreak
	global tgstreakmin tgtimenext tgrebindhinttimer
	if {[strlwr $tgchan]==[strlwr $chan]} {
		if {$tgplaying==1&&[utimerexists tghint]!=""} {
			tggamemsg "[tgcolskip]Prochaine question par [tgcolmisc2]$nick [tgcolskip]"
			if {$tgstreakmin>0&&[lindex [split $tgstreak ,] 1]>=$tgstreakmin&&[strlwr [lindex [split $tgstreak ,] 0]]==[strlwr $nick]} {
				tgstreakend
				set tgstreak 0
			}
			catch {unbind pubm -|- "$tgchan *" tgcheckanswer}
			killutimer $tghinttimer
			if {[utimerexists tgrebindhinttimer]!=""} {killtimer $tgrebindhinttimer}
			set tgnextqtimer [utimer $tgtimenext tgnextq]
		}
	}
}

proc tgerrremind {} {
	global tgerrremindtimer tgerrremindtime botnick tgcmderror
	tggamemsg "[tgcolerr]Rappel: Pour un rapport d'erreur tapez /msg $botnick $tgcmderror <numero de la question> <description>"
	set tgerrremindtimer [timer $tgerrremindtime tgerrremind]
}

proc tgbotgotkicked {nick host hand chan targ text} {
	tgquietstop
}

proc tgbotgotdisconnected {disconnect-server} {
	tgquietstop
}

proc tgquietstop {} {
	global tgplaying tgstreak tgchan tgcurrentanswer tghinttimer tgnextqtimer tgerrremindtimer
	global tgrebindhinttimer
	if {$tgplaying==1} {
		set tgstreak 0
		set tgplaying 0
		catch {unbind pubm -|- "$tgchan *" tgcheckanswer}
		if {[utimerexists tghint]!=""} {killutimer $tghinttimer}
		if {[utimerexists tgnextq]!=""} {killutimer $tgnextqtimer}
		if {[timerexists tgerrremind]!=""} {killtimer $tgerrremindtimer}
		if {[utimerexists tgrebindhinttimer]!=""} {killtimer $tgrebindhinttimer}
	}
}

proc tgreadqdb {} {
	global tgqdb tgquestionstotal tgquestionslist
	set tgquestionstotal 0
	set tgquestionslist ""
	set qfile [open $tgqdb r]
	set tgquestionslist [split [read -nonewline $qfile] "\n"]
	set tgquestionstotal [llength $tgquestionslist]
	close $qfile
}

proc tgnextq {} {
	global tgqdb tgcurrentquestion tgcurrentanswer tgquestionnumber
	global tgquestionstotal tghintnum tgchan tgquestionslist tgqdbsep tgqdbquestionfirst
	global tgcapsquestion tgcapsanswer
	tgreadqdb
	set tgcurrentquestion ""
	set tgcurrentanswer ""
	while {$tgcurrentquestion == ""} {
		set tgquestionnumber [rand [llength $tgquestionslist]]			
		set tgquestionselected [lindex $tgquestionslist $tgquestionnumber]
		set tgcurrentquestion [lindex [split $tgquestionselected $tgqdbsep] [expr $tgqdbquestionfirst^1]]
		if {$tgcapsquestion==1} {
			set tgcurrentquestion [strupr $tgcurrentquestion]
		}
		set tgcurrentanswer [string trim [lindex [split $tgquestionselected $tgqdbsep] $tgqdbquestionfirst]]
		if {$tgcapsanswer==1} {
			set tgcurrentanswer [strupr $tgcurrentanswer]
		}
	}
	unset tghintnum
	tghint
	bind pubm -|- "$tgchan *" tgcheckanswer
	return
}

proc tghint {} {
	global tgmaxhint tghintnum tgcurrentanswer tghinttimer tgchan
	global tgtimehint tghintchar tgquestionnumber tgquestionstotal
	global tgcurrentquestion tghintcharsused tgnextqtimer tgtimenext tgstreak tgstreakmin
	global tgnobodygotit tgtrythenextone tgmissed tgmaxmissed tgcmdstart tgshowanswer
	global tgtimestart tgtimeanswer tgalwaysshowq tgmaxhintcurrent tgtempnohint tgcapshint
	if {![info exists tghintnum]} {
	  set tghintnum 0
	  regsub -all -- "\[^A-Za-z0-9\]" $tgcurrentanswer "" _hintchars
	  set tgmaxhintcurrent [expr [strlen $_hintchars]<=$tgmaxhint?[expr [strlen $_hintchars]-1]:$tgmaxhint]
	  catch {tgunbindhintcmd}
	  if {$tgmaxhintcurrent>0} {
	  set tgrebindhinttimer [utimer $tgtempnohint tgbindhintcmd]
	}
	} else { incr tghintnum } 
	if {$tghintnum >= [expr $tgmaxhintcurrent+1]} {
		incr tgmissed
		set _msg ""
		append _msg "[tgcolmiss][lindex $tgnobodygotit [rand [llength $tgnobodygotit]]]"
		if {$tgshowanswer==1} {
			append _msg " La réponse était [tgcolmisc2]$tgcurrentanswer[tgcolmiss]."
		}
		if {$tgmaxmissed>0&&$tgmissed>=$tgmaxmissed} {
			append _msg " Le jeu est maintenant suspendu. Pour relancer le jeu tapez $tgcmdstart"
			tgquietstop
		} else {
			append _msg " [lindex $tgtrythenextone [rand [llength $tgtrythenextone]]]"
		}
		tggamemsg "[tgcolmiss]$_msg"
		if {$tgstreakmin>0&&[lindex [split $tgstreak ,] 1]>=$tgstreakmin} { tgstreakend }
		set tgstreak 0
		catch {unbind pubm -|- "$tgchan *" tgcheckanswer}
		if {$tgmaxmissed==0||$tgmissed<$tgmaxmissed} {
			set tgnextqtimer [utimer $tgtimenext tgnextq]
		}
		return
	} elseif {$tghintnum == 0} {
		set i 0
		set _hint {}
		set tghintcharsused {}
		foreach word [split $tgcurrentanswer] {
			regsub -all -- "\[A-Za-z0-9\]" $word $tghintchar _current
			lappend _hint $_current
		}
		if {$tgtimeanswer==1} {
			set tgtimestart [clock clicks -milliseconds]
		}
	} elseif {$tghintnum == 1} {
		set i 0
		set _hint {}
		while {$i<[llength [split $tgcurrentanswer]]} {
			set _word [lindex [split $tgcurrentanswer] $i]
			set j 0
			set _newword {}
			while {$j<[strlen $_word]} {
				if {$j==0} {
					append _newword [stridx $_word $j]
					lappend tghintcharsused $i,$j
				} else {
					if {[string is alnum [stridx $_word $j]]} {
						append _newword $tghintchar
					} else {
						append _newword [stridx $_word $j]
						lappend tghintcharsused $i,$j
					}
				}
				incr j
			}
			lappend _hint $_newword
			incr i
		}
		} else {
			set i 0
			set _hint {}
			while {$i<[llength [split $tgcurrentanswer]]} {
				set _word [lindex [split $tgcurrentanswer] $i]
				set j 0
				set _newword {}
				set _selected [rand [strlen $_word]]
				regsub -all -- "\[^A-Za-z0-9\]" $_word "" _wordalnum
				if {[strlen $_wordalnum]>=$tghintnum} {
					while {[lsearch $tghintcharsused $i,$_selected]!=-1||[string is alnum [stridx $_word $_selected]]==0} {
					 set _selected [rand [strlen $_word]]
					}
				}
				lappend tghintcharsused $i,$_selected
				while {$j<[strlen $_word]} {
					if {[lsearch $tghintcharsused $i,$j]!=-1||[string is alnum [stridx $_word $j]]==0} {
						append _newword [stridx $_word $j]
					} else {
						if {[string is alnum [stridx $_word $j]]} {
							append _newword $tghintchar
						}
				}
				incr j
			}
			lappend _hint $_newword
			incr i
		}
	}
	if {$tgcapshint==1} {
		set _hint [strupr $_hint]
	}
	tggamemsg "[tgcolqhead]======== Question [expr $tgquestionnumber+1]/$tgquestionstotal [expr $tghintnum?"(Aide $tghintnum/$tgmaxhintcurrent)":""] ========"
	if {$tgalwaysshowq==1||$tghintnum==0} {
		tggamemsg "[tgcolqbody]$tgcurrentquestion"
	}
	tggamemsg "[tgcolhint]Aide: [join $_hint]"
	set tghinttimer [utimer $tgtimehint tghint]
}

proc tgshowtop10 {nick host hand chan text} {
	global tgscores tgchan tgscorestotal
	if {[strlwr $chan]==[strlwr $tgchan]} {
		tggetscores
		if {$tgscorestotal>0} {
			if {$tgscorestotal>9} {
				set _max 9
			} else {
				set _max [expr $tgscorestotal-1]
			}
			set i 0
			while {$i<=$_max} {
				set _item [lindex $tgscores $i]
				set _nick [join [lindex [split $_item ,] 2]]
				set _score [join [lindex [split $_item ,] 0]]
				if {$i==0} {
					append _scores "[tgcolscr1]$_nick $_score"
				} elseif {$i==1} {
					append _scores ", [tgcolscr2]$_nick $_score"
				} elseif {$i==2} {
					append _scores ", [tgcolscr3]$_nick $_score"
				} else {
					append _scores ", [tgcolmisc1]$_nick $_score"
				}
				incr i
			}
			tggamemsg "[tgcolmisc1]Top 10: $_scores"
		} else {
			tggamemsg "[tgcolmisc1]La Liste des Scores est vide."
		}
	}
}

proc tgcheckanswer {nick host hand chan text} {
	global tgcurrentanswer
	if {[strlwr $tgcurrentanswer] == [tgstripcodes [strlwr [string trim $text]]]} {
		tgcorrectanswer $nick
	}
}

proc tgcorrectanswer {nick} {
	global tgcurrentanswer tghinttimer tgtimenext tgchan tgnextqtimer tgstreak tgstreakmin
	global tgscoresbyname tgranksbyname tgranksbynum tgcongrats tgscorestotal tgmissed
	global tgtimestart tgshowallscores tgrealnames tgscoresbyrank tgtimeanswer
	tggetscores
	if {![info exists tgranksbyname([strlwr $nick])]} {
		set _oldrank 0
	} else {
		set _oldrank $tgranksbyname([strlwr $nick])
	}
	tgincrscore $nick
	tggetscores
	set _newrank $tgranksbyname([strlwr $nick])
	set _timetoanswer ""
	if {$tgtimeanswer==1} {
		set _timetoanswer [expr [expr [clock clicks -milliseconds]-$tgtimestart]/1000.00]
	}
	set _msg "[tgcolmisc1][lindex $tgcongrats [rand [llength $tgcongrats]]] [tgcolmisc2]$nick[tgcolmisc1] La réponse était [tgcolmisc2]$tgcurrentanswer[tgcolmisc1].[expr $tgtimeanswer==1?" Vous l'avez obtenu en [tgcolmisc2]$_timetoanswer[tgcolmisc1] secondes.":""]"
	if {$_newrank<$_oldrank} {
		if {$_newrank==1} {
			append _msg " Vous êtes en première place !!!"
		} else {
			if {$tgshowallscores==0} {
				append _msg " Vous vous êtes relevé dans le rang !!!"
			} else {
				append _msg " Vous êtes maintenant à la place [tgcolmisc2][ordnumber $tgranksbyname([strlwr $nick])][tgcolmisc1] sur [tgcolmisc2]$tgscorestotal[tgcolmisc1], derrière [tgcolmisc2]$tgrealnames($tgranksbynum([expr $_newrank-1]))[tgcolmisc1] avec [tgcolmisc2]$tgscoresbyrank([expr $_newrank-1])[tgcolmisc1]."
			}
		}
	}
	tggamemsg "$_msg"
	if {$tgstreak!=0} {
		if {[lindex [split $tgstreak ,] 0]==[strlwr $nick]} {
			set tgstreak [strlwr $nick],[expr [lindex [split $tgstreak ,] 1]+1]
			if {$tgstreakmin>0&&[lindex [split $tgstreak ,] 1]>=$tgstreakmin} {
				tggamemsg "[tgcolstrk][tgcolmisc2]$nick[tgcolstrk] a beaucoup de chance [tgcolmisc2][lindex [split $tgstreak ,] 1] [tgcolstrk]"
			}
		} else {
			if {$tgstreakmin>0&&[lindex [split $tgstreak ,] 1]>=$tgstreakmin} { tgstreakend }
			set tgstreak [strlwr $nick],1
		}
	} else {
		set tgstreak [strlwr $nick],1
	}
	set tgmissed 0
	tgshowscores $nick
	catch {unbind pubm -|- "$tgchan *" tgcheckanswer}
	killutimer $tghinttimer
	set tgnextqtimer [utimer $tgtimenext tgnextq]
}

proc tggetscores {} {
	global tgscf tgscorestotal tgscores tgscoresbyname tgranksbyname tgranksbynum
	global tgrealnames tgscoresbyrank
	if {[file exists $tgscf]&&[file size $tgscf]>2} {
		set _sfile [open $tgscf r]
		set tgscores [lsort -dict -decreasing [split [gets $_sfile]]]
		close $_sfile
		set tgscorestotal [llength $tgscores]
	} else {
		set tgscores ""
		set tgscorestotal 0
	}
	if {[info exists tgscoresbyname]} {unset tgscoresbyname}
	if {[info exists tgranksbyname]} {unset tgranksbyname}
	if {[info exists tgrealnames]} {unset tgrealnames}
	if {[info exists tgranksbynum]} {unset tgranksbynum}
	set i 0
	while {$i<[llength $tgscores]} {
		set _item [lindex $tgscores $i]
		set _nick [lindex [split $_item ,] 2]
		set _lwrnick [lindex [split $_item ,] 3]
		set _score [lindex [split $_item ,] 0]
		set tgscoresbyname($_lwrnick) $_score
		set tgrealnames($_lwrnick) $_nick
		set tgranksbyname($_lwrnick) [expr $i+1]
		set tgranksbynum([expr $i+1]) $_lwrnick
		set tgscoresbyrank([expr $i+1]) $_score
		incr i
	}
	return
}

proc tgincrscore {who} {
	global tgscores tgscf tgpointsperanswer tgscorestotal tgscoresbyname
	tggetscores
	if {$tgscorestotal>0} {
		set i 0
		if {![info exists tgscoresbyname([strlwr $who])]} {
			append _newscores "1,[expr 1000000000000.0/[unixtime]],$who,[strlwr $who] "
		}
		while {$i<[llength $tgscores]} {
			set _item [lindex $tgscores $i]
			set _nick [lindex [split $_item ,] 2]
			set _time [lindex [split $_item ,] 1]
			set _score [lindex [split $_item ,] 0]
			if {[strlwr $who]==[strlwr $_nick]} {
				append _newscores "[expr $_score+$tgpointsperanswer],[expr 1000000000000.0/[unixtime]],$who,[strlwr $who][expr [expr [llength $tgscores]-$i]==1?"":"\ "]"
			} else {
				append _newscores "$_score,$_time,$_nick,[strlwr $_nick][expr [expr [llength $tgscores]-$i]==1?"":"\ "]"
			}
			incr i
		}
	} else {
		append _newscores "1,[expr 1000000000000.0/[unixtime]],$who,[strlwr $who]"
	}
	set _sfile [open $tgscf w]
	puts $_sfile "$_newscores"
	close $_sfile
	return
}

proc tgshowscores {nick} {
	global tgscores tgchan tgscorestotal tgshowallscores tgranksbyname tgranksbynum
	global tgscoresbyname tgrealnames tgscoresbyrank
	tggetscores
	set i 0
	if {$tgshowallscores} {
		while {$i<[llength $tgscores]} {
			set _item [lindex $tgscores $i]
			set _nick [lindex [split $_item ,] 2]
			set _score [lindex [split $_item ,] 0]
			if {$i==0} {
				append _scores "[tgcolscr1]$_nick $_score"
			} elseif {$i==1} {
				append _scores ", [tgcolscr2]$_nick $_score"
			} elseif {$i==2} {
				append _scores ", [tgcolscr3]$_nick $_score"
			} elseif {[onchan $_nick $tgchan]} {
				append _scores ", [tgcolmisc1]$_nick $_score"
			}
			incr i
		}
		tggamemsg "[tgcolmisc1]The scores: $_scores"
	} else {
		if {$tgranksbyname([strlwr $nick])==1} {
			set _tgt "."
		} else {
			set _tgt ", derrière [tgcolmisc2]$tgrealnames($tgranksbynum([expr $tgranksbyname([strlwr $nick])-1]))[tgcolmisc1] avec [tgcolmisc2]$tgscoresbyrank([expr $tgranksbyname([strlwr $nick])-1])[tgcolmisc1]."
		}
		tggamemsg "[tgcolmisc2]$nick [tgcolmisc1]a maintenant [tgcolmisc2]$tgscoresbyname([strlwr $nick]) [tgcolmisc1][expr $tgscoresbyname([strlwr $nick])==1?"point":"points"] et est classé [tgcolmisc2][ordnumber $tgranksbyname([strlwr $nick])] [tgcolmisc1]of [tgcolmisc2]$tgscorestotal[tgcolmisc1]$_tgt"
	}
}

proc tgresetscores {nick host hand text} {
	global tgscf tgscorestotal tgscores tgplaying tgresetreqpw
	if {($tgresetreqpw==1 && [passwdok $hand $text]) || $tgresetreqpw==0} {
		if {[file exists $tgscf]&&[file size $tgscf]>2} {
			set _sfile [open $tgscf w]
			puts $_sfile ""
			close $_sfile
			set tgscores ""
			set tgscorestotal 0
		}
		tggamemsg "[tgcolrset]=== Les Scores ont été remis à zero par $nick ==="
	}
}

proc tgstreakend {} {
		global tgstreak tgrealnames
		tggamemsg "[tgcolstend]Dommage pour [tgcolmisc2]$tgrealnames([lindex [split $tgstreak ,] 0])[tgcolstend]."
		return
}

proc tgjoinmsg {nick host hand chan} {
	global botnick tgplaying tgcmdhelp tgcmdstart tgflagsstart tgcmdstop tgflagsstop tgchan
	if {$nick != $botnick} {
		set _msg ""
		append _msg "Status du QuiZz :"
		if {$tgplaying==1} {
			append _msg " \002démarré\002."
		} else {
			append _msg " \002arrêté\002."
		}
		#[tgpriv] $nick "$_msg"
	}
}

proc tgscorelookup {nick host hand text} {
	global tgscoresbyname tgranksbyname tgscorestotal tgrealnames
	if {$text==""} { set text $nick } else { set text [lindex [split $text] 0] }
	tggetscores
	if {![info exists tgscoresbyname([strlwr $text])]} {
		if {[strlwr $text]==[strlwr $nick]} {
			set _who "[tgcolmisc1]Vous êtes"
		} else {
			set _who "[tgcolmisc2]$text [tgcolmisc1]est"
		}
		[tgpriv] $nick "[tgbold]$_who [tgcolmisc1]n'est pas dans la liste des scores."
	} else {
		if {[strlwr $text]==[strlwr $nick]} {
			set _who "[tgcolmisc1]Vous avez"
		} else {
			set _who "[tgcolmisc2]$tgrealnames([strlwr $text]) [tgcolmisc1]a"
		}
		[tgpriv] $nick "[tgbold]$_who [tgcolmisc2]$tgscoresbyname([strlwr $text])[tgcolmisc1] points, Classé [tgcolmisc2][ordnumber $tgranksbyname([strlwr $text])] [tgcolmisc1]sur [tgcolmisc2]$tgscorestotal[tgcolmisc1]."
	}
}

proc tgtargetlookup {nick host hand text} {
	global tgscoresbyname tgranksbyname tgscorestotal tgranksbynum tgrealnames
	tggetscores
	if {![info exists tgscoresbyname([strlwr $nick])]} {
		[tgpriv] $nick "[tgbold][tgcolmisc1]Vous n'êtes pas dans la liste des scores."
	} elseif {$tgranksbyname([strlwr $nick])==1} {
		[tgpriv] $nick "[tgbold][tgcolmisc1]Vous êtes le premier."
	} else {
		[tgpriv] $nick "[tgbold][tgcolmisc1]Vous êtes en ligne [tgcolmisc2]$tgscoresbyname([strlwr $nick])[tgcolmisc1]. Votre prochaine position est [tgcolmisc2]$tgrealnames($tgranksbynum([expr $tgranksbyname([strlwr $nick])-1])) [tgcolmisc1]avec [tgcolmisc2]$tgscoresbyname($tgranksbynum([expr $tgranksbyname([strlwr $nick])-1]))[tgcolmisc1], Classé [tgcolmisc2][ordnumber [expr $tgranksbyname([strlwr $nick])-1]] [tgcolmisc1]sur [tgcolmisc2]$tgscorestotal[tgcolmisc1]."
	}
}

proc tgerror {nick host hand text} {
	global tgquestionstotal tgquestionslist tgerrmethod tgerrfil tgerremail tgerrmailtmp
	if {$text==""||![string is int [lindex [split $text] 0]]} {
		[tgpriv] $nick "[tgbold][tgcolmisc1]Vous devez indiquer le numero de la question."
		return
	}
	tgreadqdb
	set _qnum [lindex [split $text] 0]
	if {$_qnum>$tgquestionstotal} {
		[tgpriv] $nick "[tgbold][tgcolmisc1]Aucune question."
		return
	}
	set _qques [lindex [split [lindex $tgquestionslist [expr $_qnum-1]] |] 1]
	set _qans [lindex [split [lindex $tgquestionslist [expr $_qnum-1]] |] 0]
	set _desc [join [lrange [split $text] 1 end]]
	if {$_desc==""} { set _desc "Aucune autre information donnée pour cette erreur." }
	if {$tgerrmethod==1} {
		set _fname $tgerrmailtmp\trivia[rand 100000].tmp
		set _file [open $_fname w]
	} else {
		set _file [open $tgerrfil a]
	}
	puts $_file "------------------------------"
	puts $_file "Erreur généré [strftime %A,\ %d\ %B\ %Y\ @\ %H:%M:%S]"
	puts $_file "Rapporté par:\t$nick!$host"
	puts $_file "Question #:\t$_qnum"
	puts $_file "Question:\t$_qques"
	puts $_file "Réponse:\t\t$_qans"
	puts $_file "Commentaire:\t$_desc"
	puts $_file "------------------------------"
	close $_file
	if {$tgerrmethod==1} {
		exec mail -s "Trivia: Rapport d'erreur de $nick" $tgerremail < $_fname
		file delete $_fname
		[tgpriv] $nick "[tgbold][tgcolmisc1]Merci !!! Votre rapport d'erreur a été envoyé à mon propriétaire."
	} else {
		[tgpriv] $nick "[tgbold][tgcolmisc1]Merci !!! Votre rapport d'erreur a été sera examiné aussitôt que possible."
	}
}

proc tgrulesmsg {nick host hand text} {
	global tgrules
	[tgpriv] $nick "Les règles du salon: $tgrules"
}

proc tggivehelp {nick host hand {text ""}} {
	global botnick tgcmdlookup tgcmdhelp tgcmdstart tgcmdstop tgchan tgflagsstop
	global tgcmdstop tgflagshint tgcmdhint tgflagsskip tgcmdskip tgflagsreset tgcmdreset
	global tgcmdtarget tgcmderror tgcmdrules tgflagsstart
	if {$text==""} {
		[tgpriv] $nick "Vous avez accès aux commandes suivantes:"
		[tgpriv] $nick "Usage : /msg $botnick <commande>"
		[tgpriv] $nick "  \002[strupr $tgcmdrules]\002"
		[tgpriv] $nick "   -- Voir les règles du quizz."
		[tgpriv] $nick "  \002[strupr $tgcmdlookup]\002 pseudo"
		[tgpriv] $nick "   -- Voir le score du pseudo"
		[tgpriv] $nick "  \002[strupr $tgcmdtarget]\002"
		[tgpriv] $nick "   -- Voir votre position."
		[tgpriv] $nick "  \002[strupr $tgcmderror]\002 <numero de la question> <description>"
		[tgpriv] $nick "   -- Envoi un rapport d'erreur"
		if {[matchattr $hand $tgflagsreset $tgchan]} {
			[tgpriv] $nick "  \002[strupr $tgcmdreset]\002"
			[tgpriv] $nick "   -- Remise à zéro des scores."
		}
	}
	if {[strlwr $text]=="pubcmds"} {
		[tgpriv] $nick "Vous avez accès aux commandes suivantes:"
		if {[matchattr $hand $tgflagsstart $tgchan]} {
			[tgpriv] $nick "  \002$tgcmdstart\002 -- Démarrer le QuiZz."
		}
		if {[matchattr $hand $tgflagsstop $tgchan]} {
			[tgpriv] $nick "  \002$tgcmdstop\002 -- Arreter le QuiZz."
		}
		if {[matchattr $hand $tgflagshint $tgchan]} {
			[tgpriv] $nick "  \002$tgcmdhint\002 -- Voir le conseil."
		}
		if {[matchattr $hand $tgflagsskip $tgchan]} {
			[tgpriv] $nick "  \002$tgcmdskip\002 -- Prochaine question."
		}
	}
}

proc tgstripcodes {text} {
	regsub -all -- "\003(\[0-9\]\[0-9\]?(,\[0-9\]\[0-9\]?)?)?" $text "" text
	set text "[string map -nocase [list \002 "" \017 "" \026 "" \037 ""] $text]"
	return $text
}

proc tggamemsg {what} {
	global tgchan
	putquick "PRIVMSG $tgchan :[tgbold]$what"
}

proc tgbold {} {
	global tgusebold
	if {$tgusebold==1} { return "\002" }
}

proc tgcolstart {} {
	global tgcolourstart
	if {$tgcolourstart!=""} { return "\003$tgcolourstart" }
}

proc tgcolstop {} {
	global tgcolourstop
	if {$tgcolourstop!=""} { return "\003$tgcolourstop" }
}

proc tgcolskip {} {
	global tgcolourskip
	if {$tgcolourskip!=""} { return "\003$tgcolourskip" }
}

proc tgcolerr {} {
	global tgcolourerr
	if {$tgcolourerr!=""} { return "\003$tgcolourerr" }
}

proc tgcolmiss {} {
	global tgcolourmiss
	if {$tgcolourmiss!=""} { return "\003$tgcolourmiss" }
}

proc tgcolqhead {} {
	global tgcolourqhead
	if {$tgcolourqhead!=""} { return "\003$tgcolourqhead" }
}

proc tgcolqbody {} {
	global tgcolourqbody
	if {$tgcolourqbody!=""} { return "\003$tgcolourqbody" }
}

proc tgcolhint {} {
	global tgcolourhint
	if {$tgcolourhint!=""} { return "\003$tgcolourhint" }
}

proc tgcolstrk {} {
	global tgcolourstrk
	if {$tgcolourstrk!=""} { return "\003$tgcolourstrk" }
}

proc tgcolscr1 {} {
	global tgcolourscr1
	if {$tgcolourscr1!=""} { return "\003$tgcolourscr1" }
}

proc tgcolscr2 {} {
	global tgcolourscr2
	if {$tgcolourscr2!=""} { return "\003$tgcolourscr2" }
}

proc tgcolscr3 {} {
	global tgcolourscr3
	if {$tgcolourscr3!=""} { return "\003$tgcolourscr3" }
}

proc tgcolrset {} {
	global tgcolourrset
	if {$tgcolourrset!=""} { return "\003$tgcolourrset" }
}

proc tgcolstend {} {
	global tgcolourstend
	if {$tgcolourstend!=""} { return "\003$tgcolourstend" }
}

proc tgcolmisc1 {} {
	global tgcolourmisc1
	if {$tgcolourmisc1!=""} { return "\003$tgcolourmisc1" }
}

proc tgcolmisc2 {} {
	global tgcolourmisc2
	if {$tgcolourmisc2!=""} { return "\003$tgcolourmisc2" }
}

proc tgpriv {} {
	global tgpriv2msg
	if {$tgpriv2msg==1} { return "putmsg" } else { return "putnotc" }
}

proc tghtml {} {
	global tgchan botnick tghtmlfile tghtmlrefresh server tgscoresbyname tgranksbyname
	global tgscorestotal tgranksbyname tgrealnames tgscoresbyrank tgranksbynum tgplaying
	global tgquestionstotal tghtmlrefreshtimer tghtmlfont tgver tgpat
	tggetscores
	tgreadqdb
	set _file [open $tghtmlfile~new w]
	puts $_file "<!DOCTYPE HTML PUBLIC \"-/W3C/DTD HTML 4.01 Transitional/EN\">"
	puts $_file "<html>"
	puts $_file "<head>"
	puts $_file "<title>Statistiques du QuiZz ([lindex [split $server :] 0] - $tgchan)</title>"
	puts $_file "<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; CHARSET=iso-8859-1\">"
	puts $_file "<META HTTP-EQUIV=\"CONTENT-LANGAGE\" CONTENT=\"fr_FR\">"
	puts $_file "<META HTTP-EQUIV=\"refresh\" CONTENT=\"$tghtmlrefresh\">"
	puts $_file "<META NAME=\"TITLE\" CONTENT=\"Trivia.tcl $tgver-pl$tgpat\">"
	puts $_file "<META NAME=\"AUTHOR\" CONTENT=\"Souperman & TiSmA\">"
	puts $_file "<style type=\"text/css\">"
	puts $_file "a {text-decoration: none;}"
	puts $_file "a:link {color: #0b407a;}"
	puts $_file "a:visited {color: #0b407a;}"
	puts $_file "a:hover {text-decoration: underline; color: #0b407a;}"
	puts $_file "a.background {text-decoration: none;}"
	puts $_file "a.background:link {color: #0b407a;}"
	puts $_file "a.background:visited {color: #0b407a;}"
	puts $_file "a.background:hover {text-decoration: underline; color: #0b407a;}"
	puts $_file "body {background-color: #dedeee; font-family: $tghtmlfont; font-size: 13px; color: #000000;}"
	puts $_file "td {font-family: $tghtmlfont; font-size: 13px; color: #000000;}"
	puts $_file ".title {font-family: $tghtmlfont; font-size: 15px; font-weight: bold;}"
	puts $_file ".headtext {color: #ffffff; font-weight: bold; text-align: center; background-color: #666699;}"
	puts $_file ".headlinebg {background-color: #000000;}"
	puts $_file ".tdtop {background-color: #C8C8DD;}"
	puts $_file ".hicell {background-color: #BABADD;}"
	puts $_file ".hicell10 {background-color: #BABADD; font-size: 10px;}"
	puts $_file ".rankc {background-color: #CCCCCC;}"
	puts $_file ".hirankc {background-color: #AAAAAA; font-weight: bold;}"
	puts $_file ".rankc10 {background-color: #CCCCCC; font-size: 10px;}"
	puts $_file ".rankc10center {background-color: #CCCCCC; font-size: 10px; text-align: center;}"
	puts $_file ".hirankc10center {background-color: #AAAAAA; font-weight: bold; font-size: 10px; text-align: center;}"
	puts $_file ".small {font-family: $tghtmlfont; font-size: 10px;}"
	puts $_file ".asmall {font-family: $tghtmlfont; font-size: 10px; color: #000000; text-align: center;}"
	puts $_file "</style>"
	puts $_file "</head>"
	puts $_file "<body bgcolor=\"#ffffff\">"
	puts $_file "<div align=\"center\">"
	if {![onchan $botnick $tgchan]} {
		puts $_file "<br><p><b>Service momentan&eacute;ment indisponible... Essayer plus tard.</b></p>"
	} else {
		puts $_file "<br><table width=\"730\" cellpadding=\"1\" cellspacing=\"0\" border=\"0\">"
		puts $_file "<tr>"
		puts $_file "<td class=\"headlinebg\">"
		puts $_file "<table width=\"100%\" cellpadding=\"2\" cellspacing=\"0\" border=\"0\">"
		puts $_file "<tr>"
		puts $_file "<td class=\"headtext\">Statistiques du QuiZz ([lindex [split $server :] 0] - $tgchan)</td>"
		puts $_file "</tr>"
		puts $_file "</table>"
		puts $_file "</td>"
		puts $_file "</tr>"
		puts $_file "</table>"
		puts $_file "<table width=\"734\"><tr>"
		puts $_file "<td class=\"hicell\"><table width=\"100%\"><tr><td>&nbsp;</td><td>"
		puts $_file "<span>Le QuiZz est actuellement <b>[expr $tgplaying==1?"online":"offline"]</b>. Il y a <b>$tgquestionstotal</b> questions dans notre database.<br>Statistiques &eacute;dit&eacute;s le [strftime %A,\ %d\ %B\ %Y\ a\ %H:%M:%S] par <b>$botnick</b>.<br>Cette page est updat&eacute;e toutes les <b>[expr $tghtmlrefresh==1?"</b>seconde":"$tghtmlrefresh </b>secondes"].</span>"
		puts $_file "</td><td>&nbsp;</td></tr></table></td>"
		puts $_file "</tr></table><br><br><br>"
		puts $_file "<table width=\"730\" cellpadding=\"1\" cellspacing=\"0\" border=\"0\">"
		puts $_file "<tr>"
		puts $_file "<td class=\"headlinebg\">"
		puts $_file "<table width=\"100%\" cellpadding=\"2\" cellspacing=\"0\" border=\"0\">"
		puts $_file "<tr>"
		puts $_file "<td class=\"headtext\">Liste des Joueurs</td>"
		puts $_file "</tr>"
		puts $_file "</table>"
		puts $_file "</td>"
		puts $_file "</tr>"
		puts $_file "</table>"
		puts $_file "<table width=\"734\"><tr>"
		puts $_file "<td class=\"hicell\"><table width=\"100%\"><tr><td>&nbsp;</td><td align=\"center\">"
		puts $_file "<table width=\"95%\" border=\"0\" cellspacing=\"0\" cellpadding=\"0\">"
		puts $_file "<tr>"
		puts $_file "<td width=\"30%\" align=\"center\"><b>Pseudo</b></td>"
		puts $_file "<td width=\"25%\" align=\"center\"><b>Score</b></td>"
		puts $_file "<td width=\"25%\" align=\"center\"><b>Place</b></td>"
		puts $_file "<td width=\"20%\" align=\"center\"><b>Idle</b></td>"
		puts $_file "</tr>"
		foreach nick [lsort [chanlist $tgchan]] {
			puts $_file "<tr>"
			puts $_file "<td width=\"30%\" align=\"center\">[expr [isop $nick $tgchan]?"@":""][expr [isvoice $nick $tgchan]?"+":""]$nick[expr [string match $nick $botnick]?" (Robot du QuiZz)":""]</td>"
			if {[info exists tgscoresbyname([strlwr $nick])]} {
				puts $_file "<td width=\"25%\" align=\"center\">$tgscoresbyname([strlwr $nick])</td>"
			} else {
				puts $_file "<td width=\"25%\" align=\"center\">-</td>"
			}
			if {[info exists tgranksbyname([strlwr $nick])]} {
				puts $_file "<td width=\"25%\" align=\"center\">$tgranksbyname([strlwr $nick])</td>"
			} else {
				puts $_file "<td width=\"25%\" align=\"center\">-</td>"
			}
			puts $_file "<td width=\"20%\" align=\"center\">[expr [getchanidle $nick $tgchan]>10?"[getchanidle $nick $tgchan]m":"-"]</td>"
			puts $_file "</tr>"
		}
		puts $_file "</table>"
		puts $_file "</td><td>&nbsp;</td></tr></table></td>"
		puts $_file "</tr>"
		puts $_file "</table><br><br><br>"
	}
	puts $_file "<table width=\"730\" cellpadding=\"1\" cellspacing=\"0\" border=\"0\">"
	puts $_file "<tr>"
	puts $_file "<td class=\"headlinebg\">"
	puts $_file "<table width=\"100%\" cellpadding=\"2\" cellspacing=\"0\" border=\"0\">"
	puts $_file "<tr>"
	puts $_file "<td class=\"headtext\">Liste des Scores</td>"
	puts $_file "</tr>"
	puts $_file "</table>"
	puts $_file "</td>"
	puts $_file "</tr>"
	puts $_file "</table>"
	puts $_file "<table width=\"734\">"
	puts $_file "<tr>"
	puts $_file "<td class=\"hicell\"><table width=\"100%\"><tr><td>&nbsp;</td><td><span>"
	if {$tgscorestotal>0} {
		set _rank 1
		while {$_rank<=$tgscorestotal} {
			puts $_file "<b>$_rank</b>. $tgrealnames($tgranksbynum($_rank)) : $tgscoresbyrank($_rank)<br>"
			incr _rank
		}
	} else {
		puts $_file "&nbsp;&nbsp;Aucun pseudo dans la Liste des Scores<br>"
	}
	puts $_file "</span></td><td>&nbsp;</td></tr></table></td>"
	puts $_file "</tr>"
	puts $_file "</table>"
	puts $_file "</body>"
	puts $_file "</html>"
	close $_file
	file rename -force $tghtmlfile~new $tghtmlfile
	set tghtmlrefreshtimer [utimer $tghtmlrefresh tghtml]
}

putlog "-------------------------------"
putlog "Trivia $tgver by Souperman "
putlog "Patch Level $tgpat by TiSmA"
putlog "-------------------------------"
