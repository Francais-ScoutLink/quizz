# autolog.tcl v1.24 (29 November 2012)
# copyright (c) 2000 by slennox <slennox@egghelp.org>
# slennox's eggdrop page - http://www.egghelp.org/
# Edited by CrazyCat <crazycat@c-p-f.org>
#
# When you want to make your bot keep a logfile for a new channel, you have
# to manually add a new 'logfile' command to the bot's config file. This
# can be a problem if your bot frequently joins new channels and you want
# to keep a log for each. This script automatically enables a logfile for
# each channel the bot joins, so that you don't need to enable it manually.
# The idea for this script came from Zsolt.
#
#
# v1.24 - Corrected some small bugs, essentially "return 0" wich made
#         stop the reinitialisation of logfiles
#         Deleted the send function
#         Added a hook on .-chan command
# v1.23 - Readded trailing backslash in $autolog_path added by myself and
#         removed by Abraham I think, because every good OS don't worrys
#         about multiple slashes in path, so logspath///#channel.log would
#         be the same as logspath//#channel.log or logspath/#channel.log
#         (try it Abraham) *g*
# v1.22 - Removed trailing backslash in $autolog_path added by strolchi.
#         Becouse if user will enter _correctly_ sendfile patch, as in
#         example provided in this script, with backslash at end, then
#         it would give in result incorrectly set path with double backslash.
#         i.e.: Logfile #3: logspath//#channel.log on #channel (log. modes
#         goes here)
# v1.21 - Corrected small omnission related with default values of variables
#         used in that script, it was done in ver. 1.12, but becouse strolchi
#         takes as a base ver. 1.11 - it was done again. (Abraham)
# v1.2  - Added start/continue of autologing after a rehash by strolchi
#       - Added support for missing trailing backslash in $autolog_path
#         by strolchi
# v1.11 - Added support for user defined directory for log-files by Abraham
# v1.1  - Added a trigger for sending log file by hd2000 (winstonlim@visto.com)
#         ScriptCorner - http://scriptcorner.cjb.net 
# v1.0  - Initial release.

# Set the modes for new logfiles. These determine what type of things are
# logged (e.g. 'k' for kicks, bans, and mode changes). These modes are
# explained in the logfile section of eggdrop.conf.dist.
set autolog_modes "sjpk"

# Specify how the logfiles should be named. There are two variables you can
# use here:
#  %chan for the channel name
#  %stripchan for the channel name with leading #+&! character removed
set autolog_file "%stripchan.log"

# The script will create a new logfile for every channel the bot joins for
# which no logfile is already specified. If you have some channels you
# don't want the script to create a log for, specify them here in the
# format "#chan1 #chan2 #etc".
set autolog_exempt ""

# Set the next line as the path where log files should be stored
# and downloaded from
# example : set autolog_path "/home/acratus"
set autolog_path "log_bot"

# Don't edit below unless you know what you're doing.

proc autolog_join {nick uhost hand chan} {
	if {$nick == $::botnick} {
		set stlchan [string tolower $chan]
		if {$::autolog_exempt != "" && [lsearch -exact [string tolower [split $::autolog_exempt]] $stlchan] != -1} {return 0}
		foreach curfile [logfile] {
			if {[string tolower [lindex $curfile 1]] == $stlchan} {return 0}
		}
		regsub -all -- "%chan" $::autolog_file $chan file
		regsub -all -- "%stripchan" $file [string trim $chan "#+&!"] file
		logfile $::autolog_modes $chan "$::autolog_path/$file"
	}
	return 0
}

proc autolog_evnt {type} {
	foreach chan [channels] {
		set stlchan [string tolower $chan]
		if {$::autolog_exempt != "" && [lsearch -exact [string tolower [split $::autolog_exempt]] $stlchan] != -1} {continue}
		foreach curfile [logfile] {
			if {[string tolower [lindex $curfile 1]] == $stlchan} {continue}
			regsub -all -- "%chan" $::autolog_file $chan file
			regsub -all -- "%stripchan" $file [string trim $chan "#+&!"] file
			logfile $::autolog_modes $chan "$::autolog_path/$file"
		}
	}
	return 0
}

proc autolog_remove {handle idx text} {
   set chan [string tolower [lindex [split $text] 0]]
   if {![validchan $chan]} {
      putlog "Sorry, I'm not on $chan"
      return 0
   }
   foreach curfile [logfile] {
      if {[string tolower [lindex $curfile 1]] == $chan} {
         logfile "" "" [lindex $curfile 2]
      }
   }
   channel remove $chan
   return 0
}

bind join - * autolog_join
bind evnt - rehash autolog_evnt
bind dcc - "-chan" autolog_remove
putlog "Loaded autolog.tcl v1.24 by slennox et al"