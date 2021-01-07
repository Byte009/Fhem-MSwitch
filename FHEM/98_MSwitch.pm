# 98_MSwitch.pm
#
# copyright Thomas Pause ########################################
#
# 98_MSwitch.pm
#
#################################################################
#
# MSwitchtoggle Suchmuster ab V3 [Befehl 1,Befehl 2,Befehl 3]:[1,2,3]:[reading]
#                                [auszuführender Befehl]:[Inhalt reading]:[Name des readings]
#
#################################################################
#
#
# Todo's:  
#          	CommandSet() statt fhem()
#          	del_repeats mehrfach - in sub auslager
#			event EVENTFULL nur nach aktivierung im frontend auf 1 setzen
#
#################################################################
#
#---------------------------------------------------------------
#
# info sonderreadings
#
# reading '.info' 			wenn definiert -> infotext für device
# reading '.change' 		wenn definiert -> angeforderte deviceänderung
# reading '.change_inf' 	wenn definiert -> info für angeforderte deviceänderung
# reading '.lock' 			sperrt das Interface (1 - alles / 2 alles bis auf trigger)
# reading 'Sys_Extension' 	'on' gibt Systemerweiterung frei
#
#---------------------------------------------------------------
#
# info conffile - austausch eines/mehrerer devices
# I Information zu Devicetausch
# Q dummy1#zu schaltendes geraet#device
# Q dummy2#zu schaltendes geraet2#device
#
#################################################################


package main;
use Time::Local;
use strict;
use warnings;
use POSIX;
use SetExtensions;
use LWP::Simple;
use JSON;
use HttpUtils;
use Color;


my $updateinfo  = "";    # wird mit info zu neuen versionen besetzt
my $generalinfo = "";    # wird mit aktuellen informationen besetzt
my $updateinfolink 	= "https://raw.githubusercontent.com/Byte009/FHEM-MSwitch/master/updateinfo.txt";
my $preconffile 	= "https://raw.githubusercontent.com/Byte009/MSwitch_Addons/master/MSwitch_Preconf.conf";
my $templatefile 	= "https://raw.githubusercontent.com/Byte009/MSwitch_Templates/master/";
my $widgetfile    	= "www/MSwitch/MSwitch_widgets.txt";

my $helpfile    = "www/MSwitch/MSwitch_Help.txt";
my $helpfileeng = "www/MSwitch/MSwitch_Help_eng.txt";
#my $backupfile 	= "backup/MSwitch_Backup.cfg";

my $backupfile 	= "backup/MSwitch/";

my $support = "Support Mail: Byte009\@web.de";
my $autoupdate   = 'off';     				# off/on
my $version      = '5.0';  					# version
my $wizard       = 'on';     				# on/off   - not in use
my $importnotify = 'on';     				# on/off   - not in use
my $importat     = 'on';     				# on/off   - not in use
my $vupdate      = 'V5.0';					# versionsnummer der datenstruktur . änderung der nummer löst MSwitch_VersionUpdate aus .
my $savecount = 50;							# anzahl der zugriff im zeitraum zur auslösung des safemodes. kann durch attribut überschrieben werden .
my $undotime = 60;							# Standarzeit in der ein Undo angeboten wird
my $savemodetime       = 10000000;    		# Zeit für Zugriffe im Safemode
my $rename             = "off";        		# on/off rename in der FW_summary möglich
my $standartstartdelay = 5;					# zeitraum nach fhemstart , in dem alle aktionen geblockt werden. kann durch attribut überschrieben werden .
#my $eventset = '0';
my $deletesavedcmds = 1800; 				# zeitraum nachdem gespeicherte devicecmds gelöscht werden ( beschleunigung des webinterfaces )
my $deletesavedcmdsstandart = "nosave" ; 	# standartverhalten des attributes "MSwitch_DeleteCMDs" <manually,nosave,automatic>
# standartlist ignorierter Devices . kann durch attribut überschrieben werden .
my @doignore = qw(notify allowed at watchdog doif fhem2fhem telnet FileLog readingsGroup FHEMWEB autocreate eventtypes readingsproxy svg cul);
my $startmode   = "Notify";    				# Startmodus des Devices nach Define
my $wizardreset = 3600;       				#Timeout für Wizzard
my $MSwitch_generate_Events ="0";

my $debugging = "0";

$data{MSwitch}{updateinfolink} = $updateinfolink;
$data{MSwitch}{version}       = $version;

$updateinfo = get($updateinfolink);
$updateinfo =~ s/\n/[LINE]/g;

my @uinfos = split( /\[LINE\]/, $updateinfo );

$data{MSwitch}{Version}            = $uinfos[1];
$data{MSwitch}{Updateinformation}  = $uinfos[2];
$data{MSwitch}{Generalinformation} = $uinfos[3];

my $startmessage="";
$startmessage.="     -> Version $version... loading files and system variables\n";

if ($uinfos[1] ne $version)
{
$startmessage.="     -> System: Update avaible: ".$uinfos[1]."\n";
}
else
{
$startmessage.="     -> System: no update avaible\n";	
}

$startmessage.="     -> setting preconfpath... $preconffile\n";
$startmessage.="     -> setting undotime... ".$undotime."sec\n";
$startmessage.="     -> setting rename... $rename\n";
$startmessage.="     -> setting wizard... ".$wizard.", resettime: ".$wizardreset."sec\n";
$startmessage.="     -> setting startdelay... ".$standartstartdelay."sec\n";
$startmessage.="     -> setting startmode... $startmode\n";

## lade widgets
delete $data{MSwitch}{Widget};
# lade widgets
		my $widgetname;
		my $verteiler = "";
		my $pfad = "";
       	if (open( HELP, "<./$widgetfile" )) 
		{ 
		while (<HELP>) 
			{
				next if $_ eq "\n"; 
				if ($_ eq "[MSwitchwidgetName]\n"){$pfad = "Name";next;}
				if ($_ eq "[MSwitchwidgetHtml]\n"){$pfad = "Html";next;}
				if ($_ eq "[MSwitchidgetScript]\n"){$pfad = "Script";next;}
				if ($_ eq "[MSwitchidgetReading]\n"){$pfad = "Reading";next;}
				if ($_ eq "[MSwitchwidgetEND]\n"){$pfad = "";next;}
				if ($_ eq "[MSwitchidgetCode]\n"){$pfad = "Code";next;}
				if ($pfad eq "Name")
				 {
					 $_ =~ s/\n//g;
					 $widgetname = $_;
					 $data{MSwitch}{Widget}{$_}{name} = 	$widgetname; 
				 }
				if ($pfad eq "Html") {$data{MSwitch}{Widget}{$widgetname}{html} .= $_;  } 
				if ($pfad eq "Script"){$data{MSwitch}{Widget}{$widgetname}{script} .= $_; } 
				if ($pfad eq "Reading") {$_ =~ s/\n//g;$data{MSwitch}{Widget}{$widgetname}{reading} .= $_;   } 
				if ($pfad eq "Code") {$_ =~ s/\n//g; $data{MSwitch}{Widget}{$widgetname}{code} .= $_;  } 
			
			}
		close(HELP);
		$startmessage.="     -> widgetfile ($widgetfile) loaded - Widgets on\n";
		$startmessage.="     -> verfuegbare Widgets: ";
		my $inhalt1 = $data{MSwitch}{Widget};
		foreach my $a ( sort keys %{$inhalt1} )
		{
			$startmessage.="[$a],";
		}
		chop($startmessage);
		$startmessage.="\n";
		}
		else
		{
		$startmessage.="!!!  -> no widgetfile ($widgetfile) found - Widgets off\n";
		}
		
#lade helpfiles	
		
		my $germanhelp="";
		my $englischhelp="";
	    my %UMLAUTE = (
            'Ä' => 'Ae',
            'Ö' => 'Oe',
            'Ü' => 'Ue',
            'ä' => 'ae',
            'ö' => 'oe',
            'ü' => 'ue'
        );
		my $UMLKEYS = join( "|", keys(%UMLAUTE) );
		
		if ( open( HELP, "<./$helpfile" ) )
		{
		while (<HELP>) 
			{
            $germanhelp = $germanhelp . $_;
			}
        close(HELP); 
		$germanhelp =~ s/\n/#[LINE]\\\n/g;
        $germanhelp =~ s/"/#[DA]/g;
        $germanhelp =~ s/'/#[A]/g;
		$germanhelp =~ s/($UMLKEYS)/$UMLAUTE{$1}/g;	
		$startmessage.="     -> helpfile ger ($helpfile) loaded - Help on\n";
		}
		else
		{
		$startmessage.="!!!  -> helpfile ger ($helpfile) not found - Help off\n";
		}
        
		if ( open( HELP, "<./$helpfileeng" ) )
		{
		while (<HELP>) 
			{
            $englischhelp = $englischhelp . $_;
			}
        close(HELP); 
		$englischhelp =~ s/\n/#[LINE]\\\n/g;
        $englischhelp =~ s/"/#[DA]/g;
        $englischhelp =~ s/'/#[A]/g;
		$englischhelp =~ s/($UMLKEYS)/$UMLAUTE{$1}/g;	
		$startmessage.="     -> helpfile eng ($helpfileeng) loaded - Help on\n";
		}
		else
		{
		$startmessage.="!!!  -> helpfile eng ($helpfileeng) not found - Help off\n";
		}
			
$startmessage.="     -> autoupdate devices status: $autoupdate \n";		
$startmessage.="     -> $support\n";
$startmessage.="     -> Mswitch initializing ready\n";

Log3("MSwitch",1,"Messages collected while initializing MSwitch-System:\n$startmessage");
$startmessage="";

sub MSwitch_Checkcond_time($$);
sub MSwitch_Checkcond_state($$);
sub MSwitch_Checkcond_day($$$$);
sub MSwitch_Createtimer($);
sub MSwitch_Execute_Timer($);
sub MSwitch_LoadHelper($);
sub MSwitch_debug2($$);
sub MSwitch_ChangeCode($$);
sub MSwitch_Add_Device($$);
sub MSwitch_Del_Device($$);
sub MSwitch_Debug($);
sub MSwitch_Exec_Notif($$$$$);
sub MSwitch_checkcondition($$$);
sub MSwitch_Delete_Delay($$);
sub MSwitch_Check_Event($$);
sub MSwitch_makeAffected($);
sub MSwitch_backup($);
sub MSwitch_backup_this($);
sub MSwitch_backup_all($);
sub MSwitch_restore_all($);
sub MSwitch_restore_this($);
sub MSwitch_backup_done($);
sub MSwitch_checktrigger(@);
sub MSwitch_Cmd(@);
sub MSwitch_toggle($$);
sub MSwitch_Getconfig($$);
sub MSwitch_saveconf($$);
sub MSwitch_replace_delay($$);
sub MSwitch_repeat($);
sub MSwitch_Createrandom($$$);
sub MSwitch_Execute_randomtimer($);
sub MSwitch_Clear_timer($);
sub MSwitch_Createnumber($);
sub MSwitch_Createnumber1($);
sub MSwitch_Savemode($);
sub MSwitch_set_dev($);
sub MSwitch_EventBulk($$$$);
sub MSwitch_priority(@);
sub MSwitch_sort(@);
sub MSwitch_dec($$);
sub MSwitch_makefreecmd($$);
sub MSwitch_makefreecmdonly($$);
sub MSwitch_clearlog($);
sub MSwitch_LOG($$$);
sub MSwitch_Getsupport($);
sub MSwitch_confchange($$);
sub MSwitch_setconfig($$);
sub MSwitch_check_setmagic_i($$);
sub MSwitch_Eventlog($$);
sub MSwitch_Writesequenz($);
sub MSwitch_del_singlelog($$);
sub MSwitch_Checkcond_history($$);
sub MSwitch_fhemwebconf($$$$);
sub MSwitch_setbridge($$);
sub MSwitch_makegroupcmd($$);
sub MSwitch_makegroupcmdout($$);
sub MSwitch_gettemplate($$);
sub MSwitch_Delete_specific_Delay($$$);
sub MSwitch_whitelist($$);
sub MSwitch_PerformHttpRequest($$);
sub MSwitch_savetemplate($$$);

##############################

my $attrdummy ="  disable:0,1"
. "  MSwitch_Language:EN,DE"
. "  MSwitch_Debug:0,1"
. "  disabledForIntervals"
. "  MSwitch_Inforoom"
. "  MSwitch_Mode:Full,Notify,Toggle,Dummy"
. "  MSwitch_Selftrigger_always:0,1"
. "  useSetExtensions:0,1"
. "  setList:textField-long "
. "  readingList:textField-long "
. $readingFnAttributes;


my $attractivedummy = "  disable:0,1"
. "  MSwitch_Language:EN,DE"
. "  MSwitch_Debug:0,1,2,3,4"
. "  disabledForIntervals"
. "  MSwitch_Expert:0,1"
. "  MSwitch_Modul_Mode:0,1"
. "  MSwitch_Readings:textField-long"
. "  MSwitch_EventMap:textField-long"
. "  stateFormat:textField-long"
. "  MSwitch_Eventhistory:0,10"
. "  MSwitch_Delete_Delays:0,1,2,3"
. "  MSwitch_Help:0,1"
. "  MSwitch_Ignore_Types:textField-long "
. "  MSwitch_Extensions:0,1"
. "  MSwitch_Inforoom"
. "  MSwitch_DeleteCMDs:manually,automatic,nosave"
. "  MSwitch_Mode:Full,Notify,Toggle,Dummy"
. "  MSwitch_Selftrigger_always:0,1"
. "  useSetExtensions:0,1"
. "  MSwitch_Snippet:textField-long "
. "  MSwitch_setList:textField-long "
. "  setList:textField-long "
. "  readingList:textField-long "
. "  MSwitch_Device_Groups:textField-long"
. "  MSwitch_ExtraktfromHTTP:textField-long"
. "  MSwitch_ExtraktHTTPMapping:textField-long"
. "  MSwitch_Switching_once:0,1 "
. $readingFnAttributes;
		  
my $attrresetlist =
"  disable:0,1"
. "  disabledForIntervals"
. "  MSwitch_Language:EN,DE"
. "  stateFormat:textField-long"
. "  MSwitch_Comments:0,1"
. "  MSwitch_Read_Log:0,1"
. "  MSwitch_Hidecmds"
. "  MSwitch_Help:0,1"
. "  MSwitch_Readings:textField-long"
. "  MSwitch_EventMap:textField-long"
. "  MSwitch_Debug:0,1,2,3"
. "  MSwitch_Expert:0,1"
. "  MSwitch_Delete_Delays:0,1,2,3,4"
. "  MSwitch_Include_Devicecmds:0,1"
. "  MSwitch_generate_Events:0,1"
. "  MSwitch_Include_Webcmds:0,1"
. "  MSwitch_Include_MSwitchcmds:0,1"
. "  MSwitch_Activate_MSwitchcmds:0,1"
. "  MSwitch_Lock_Quickedit:0,1"
. "  MSwitch_Ignore_Types:textField-long "
. "  MSwitch_Reset_EVT_CMD1_COUNT"
. "  MSwitch_Reset_EVT_CMD2_COUNT"
. "  MSwitch_Extensions:0,1"
. "  MSwitch_Inforoom"
. "  MSwitch_DeleteCMDs:manually,automatic,nosave"
. "  MSwitch_Modul_Mode:0,1"
. "  MSwitch_Mode:Full,Notify,Toggle,Dummy"
. "  MSwitch_Condition_Time:0,1"
. "  MSwitch_Selftrigger_always:0,1"
. "  MSwitch_RandomTime"
. "  MSwitch_RandomNumber"
. "  MSwitch_Safemode:0,1"
. "  MSwitch_Snippet:textField-long "			  
. "  MSwitch_Startdelay:0,10,20,30,60,90,120"
. "  MSwitch_Wait"
. "  MSwitch_Event_Wait:textField-long"
. "  MSwitch_Event_Id_Distributor:textField-long "
. "  MSwitch_Sequenz:textField-long "
. "  MSwitch_Sequenz_time"
. "  MSwitch_setList:textField-long "
. "  setList:textField-long "
. "  readingList:textField-long "
. "  MSwitch_Device_Groups:textField-long"
. "  MSwitch_Func_AVG:textField-long"
. "  MSwitch_Func_TEND:textField-long"
. "  MSwitch_Func_DIFF:textField-long"
. "  MSwitch_ExtraktfromHTTP:textField-long"
. "  MSwitch_ExtraktHTTPMapping:textField-long"
. "  MSwitch_Eventhistory:0,1,2,3,4,5,10,20,30,40,50,60,70,80,90,100,150,200"
. "  MSwitch_Switching_once:0,1"
. "  MSwitch_SysExtension:0,1,2 "
. $readingFnAttributes;				

#################
#newblock
my %sets = (
    "wizard"            => "noArg",
    "on"                => "noArg",
    "reset_device"      => "noArg",
    "off"               => "noArg",
    "reload_timer"      => "noArg",
    "active"            => "noArg",
    "inactive"          => "noArg",
    "devices"           => "noArg",
    "details"           => "noArg",
    "del_trigger"       => "noArg",
    "del_delays"        => "",
    "del_function_data" => "noArg",
    "trigger"           => "noArg",
    "add_device"        => "noArg",
    "del_device"        => "noArg",
    "addevent"          => "noArg",
    "backup_MSwitch"    => "noArg",
    "import_config"     => "noArg",
    "saveconfig"        => "noArg",
    "savesys"           => "noArg",
    "sort_device"       => "noArg",
    "fakeevent"         => "noArg",
    "exec_cmd_1"        => "noArg",
    "exec_cmd_2"        => "noArg",
    "del_repeats"       => "noArg",
	"timer"       		=> "on,off",
    "wait"              => "noArg",
    "VUpdate"           => "noArg",
    "Writesequenz"      => "noArg",
    "confchange"        => "noArg",
    "clearlog"          => "noArg",
	"writelog"          => "",
    "set_trigger"       => "noArg",
    "reset_cmd_count"   => "",
    "delcmds"           => "",
    "deletesinglelog"   => "noArg",
    "loadHTTP"          => "",
	"reset_Switching_once"   => "",
    "change_renamed"    => ""
);

my %gets = (
    "active_timer"         => "noArg",
    "restore_MSwitch_Data" => "noArg",
    "Eventlog"             => "sequenzformated,timeline,clear",
    "deletesinglelog"      => "noArg",
    "config"               => "noArg"
);

####################
sub MSwitch_Initialize($) {

    my ($hash) = @_;
    $hash->{SetFn}             = "MSwitch_Set";
    $hash->{AsyncOutput}       = "MSwitch_AsyncOutput";
    $hash->{RenameFn}          = "MSwitch_Rename";
    $hash->{CopyFn}            = "MSwitch_Copy";
    $hash->{GetFn}             = "MSwitch_Get";
    $hash->{DefFn}             = "MSwitch_Define";
    $hash->{UndefFn}           = "MSwitch_Undef";
    $hash->{DeleteFn}          = "MSwitch_Delete";
    $hash->{ParseFn}           = "MSwitch_Parse";
    $hash->{AttrFn}            = "MSwitch_Attr";
    $hash->{NotifyFn}          = "MSwitch_Notify";
    $hash->{FW_detailFn}       = "MSwitch_fhemwebFn";
    $hash->{ShutdownFn}        = "MSwitch_Shutdown";
    $hash->{FW_deviceOverview} = 1;
	$hash->{FW_addDetailToSummary} = 1;
    $hash->{FW_summaryFn}      = "MSwitch_summary";
    $hash->{NotifyOrderPrefix} = "45-";
	$hash->{AttrList} = $attrresetlist;
	
}
####################
sub MSwitch_defineWidgets($) {
	my ($hash) = @_;
	my $name = $hash->{NAME};
	if ( AttrVal( $name, 'MSwitch_SysExtension', "0" ) eq "0")
		 {
			 return;
		 }
	my $testcode =  ReadingsVal( $name, '.sysconf', 'undef' );
	if ($testcode eq "undef")
		{
			return;
		}
	$testcode =~ s/#\[dp\]/:/g;
	foreach my $a ( keys %{$data{MSwitch}{Widget}} ) 
		{
		if ( $testcode =~ m/\[MSwitch_Widget:$a\]/s ) 
			{	
				$data{MSwitch}{$name}{activeWidgets}{$a} = "on";
							
			}
		}
	return;
}

#####################
sub MSwitch_Rename($) {

    my ( $new_name, $old_name ) = @_;
    my $hash_new = $defs{$new_name};
    my $hashold = $defs{$new_name}{$old_name};
    RemoveInternalTimer($hashold);
    my $inhalt = $hashold->{helper}{repeats};
    foreach my $a ( sort keys %{$inhalt} )
	{
        my $key = $hashold->{helper}{repeats}{$a};
        RemoveInternalTimer($key);
    }
    delete( $hashold->{helper}{repeats} );
    RemoveInternalTimer($hash_new);
    my $inhalt1 = $hash_new->{helper}{repeats};
    foreach my $a ( sort keys %{$inhalt1} )
	{
        my $key = $hash_new->{helper}{repeats}{$a};
        RemoveInternalTimer($key);
    }
    delete( $hash_new->{helper}{repeats} );
    delete( $modules{MSwitch}{defptr}{$old_name} );
    $modules{MSwitch}{defptr}{$new_name} = $hash_new;
    return;
}
#####################################
sub MSwitch_Shutdown($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
	my $showevents = AttrVal( $Name, "MSwitch_generate_Events", 0 );
	if (AttrVal( $Name, 'MSwitch_Debug', '0' ) ne "0" ){$showevents = 1};
    # speichern gesetzter delays
    my $delays = $hash->{helper}{delays};
    my $x      = 1;
    my $seq;
    foreach my $seq ( keys %{$delays} )
	{
        readingsSingleUpdate( $hash, "SaveDelay_$x", $seq, $showevents );
        $x++;
    }
    delete $data{MSwitch}{devicecmds1};
    delete $data{MSwitch}{last_devicecmd_save};
    return "wait";
}
#####################################
sub MSwitch_Copy ($) {
    my ( $old_name, $new_name ) = @_;
    my $hash = $defs{$new_name};
	my $oldhash = $defs{$old_name};
    my $testreading = $oldhash->{READINGS};
    my @areadings   = ( keys %{$testreading} );
	my $cs = "attr $new_name disable 1";
    my $errors = AnalyzeCommandChain( undef, $cs );
    if ( defined($errors) )
	{
        MSwitch_LOG( $new_name, 1, "ERROR $cs" );
    }
    foreach my $key (@areadings)
	{
        my $tmp = ReadingsVal( $old_name, $key, 'undef' );
        fhem( "setreading " . $new_name . " " . $key . " " . $tmp );
    }
    MSwitch_LoadHelper($hash);
    return;
}

#####################
sub MSwitch_summary_info($){
	my ( $hash ) = @_;
	my $Name = $hash->{NAME};
	my $ret ="<br>test $FW_room";
	# $ret .= "<script>
	# \$( \"td[informId|=\'" . $Name . "\']\" ).attr(\"informId\", \'test\');
	# \$(document).ready(function(){
	# \$( \".col3\" ).text( \"\" );
	# \$( \".devType\" ).text( \"MSwitch Inforoom: Anzeige der Deviceinformationen, Änderungen sind nur in den Details möglich.\" );
	# });
	# </script>";
    # $ret =~ s/#dp /:/g;
	return $ret;
}

####################
sub MSwitch_summary($) {
    my ( $wname, $name, $room, $test1 ) = @_;
    my $hash     = $defs{$name};
    my $testroom = AttrVal( $name, 'MSwitch_Inforoom', 'undef' );
    my $mode     = AttrVal( $name, 'MSwitch_Mode', 'Notify' );
    if ( exists $hash->{helper}{mode} && $hash->{helper}{mode} eq "absorb" ) 
	{
        return "Device ist im Konfigurationsmodus.";
    }

    my @areadings = ( keys %{$test1} );
    if (!grep /group/, @areadings)
	{
		$data{MSwitch}{$name}{Ansicht}="detail";
		return;
	}
	
	$data{MSwitch}{$name}{Ansicht}="room";
    return if $testroom ne $room;
    my $info = AttrVal( $name, 'comment', 'No Info saved at ATTR omment' );
    my $image    = ReadingsVal( $name, 'state', 'undef' );
    my $ret      = '';
    my $devtitle = '';
    my $option   = '';
    my $html     = '';
    my $triggerc = 1;
    my $timer    = 1;
    my $trigger  = ReadingsVal( $name, '.Trigger_device', 'undef' );
    my @devaff   = split( / /, MSwitch_makeAffected($hash) );
    $option .= "<option value=\"affected devices\">affected devices</option>";

    foreach (@devaff) {
        $devtitle .= $_ . ", ";
        $option   .= "<option value=\"$_\">" . $_ . "</option>";
    }
    chop($devtitle);
    chop($devtitle);
    my $affected =
        "<select style='width: 12em;' title=\""
      . $devtitle . "\" >"
      . $option
      . "</select>";

    # time
    my $optiontime;
    my $devtitletime = '';
    my $triggertime  = ReadingsVal( $name, '.Trigger_device', 'not defined' );
    my $devtime      = ReadingsVal( $name, '.Trigger_time', '' );
    $devtime =~ s/\[//g;
    $devtime =~ s/\]/ /g;
    my @devtime = split( /~/, $devtime );
    $optiontime .= "<option value=\"Time:\">At: aktiv</option>";
    my $count = @devtime;
    $devtime[0] =~ s/on/on+cmd1: /g        if defined $devtime[0];
    $devtime[1] =~ s/off/off+cmd2: /g      if defined $devtime[1];
    $devtime[2] =~ s/ononly/only cmd1: /g  if defined $devtime[2];
    $devtime[3] =~ s/offonly/only cmd2: /g if defined $devtime[3];

    if ( $mode ne "Notify" ) 
	{
        $optiontime .="<option value=\"$devtime[0]\">" . $devtime[0] . "</option>" if defined $devtime[0];
        $optiontime .= "<option value=\"$devtime[1]\">" . $devtime[1] . "</option>" if defined $devtime[1];
    }

    $optiontime .= "<option value=\"$devtime[2]\">" . $devtime[2] . "</option>" if defined $devtime[2];
    $optiontime .= "<option value=\"$devtime[3]\">" . $devtime[3] . "</option>" if defined $devtime[3];

    my $affectedtime = '';
    if ( $count == 0 )
	{
        $timer = 0;
        $affectedtime =
            "<select style='width: 12em;' title=\""
          . $devtitletime
          . "\" disabled ><option value=\"Time:\">At: inaktiv</option></select>";
    }
    else 
	{
        chop($devtitletime);
        chop($devtitletime);
        $affectedtime =
            "<select style='width: 12em;' title=\""
          . $devtitletime . "\" >"
          . $optiontime
          . "</select>";
    }

    if ( $info eq 'No Info saved at ATTR omment' )
	{
        $ret .= "<input disabled title=\""
          . $info
          . "\" name='info' type='button'  value='Info' onclick =\"FW_okDialog('"
          . $info . "')\">";
    }
    else 
	{
        $ret .= "<input title=\""
          . $info
          . "\" name='info' type='button'  value='Info' onclick =\"FW_okDialog('"
          . $info . "')\">";
    }

    $ret .= " <input disabled name='Text1' size='10' type='text' value='Mode: " . $mode . "'> ";

    if ( $trigger eq 'no_trigger' || $trigger eq 'undef' || $trigger eq '' )
	{
        $triggerc = 0;
        if ( $triggerc != 0 || $timer != 0 )
		{
            $ret .="<select style='width: 18em;' title=\"\" disabled ><option value=\"Trigger:\">Trigger: inaktiv</option></select>";
        }
        else 
		{
            if ( $mode ne "Dummy" )
			{
                $affectedtime = "";
                $ret .= "&nbsp;&nbsp;Multiswitchmode (no trigger / no timer)&nbsp;";
            }
            else
			{
                $affectedtime = "";
                $affected     = "";
                $ret .= "&nbsp;&nbsp;Dummymode&nbsp;";
            }
        }
    }
    else 
	{
        $ret .= "<select style='width: 18em;' title=\"\" >";
        $ret .= "<option value=\"Trigger:\">Trigger: " . $trigger . "</option>";
        $ret .=
            "<option value=\"Trigger:\">on+cmd1: "
          . ReadingsVal( $name, '.Trigger_on', 'not defined' )
          . "</option>";
        $ret .=
            "<option value=\"Trigger:\">off+cmd2: "
          . ReadingsVal( $name, '.Trigger_off', 'not defined' )
          . "</option>";
        $ret .=
            "<option value=\"Trigger:\">only cmd1: "
          . ReadingsVal( $name, '.Trigger_cmd_on', 'not defined' )
          . "</option>";
        $ret .=
            "<option value=\"Trigger:\">only cmd2: "
          . ReadingsVal( $name, '.Trigger_cmd_off', 'not defined' )
          . "</option>";
        $ret .= "</select>";
    }
    $ret .= $affectedtime;
    $ret .= $affected;

    if ( ReadingsVal( $name, '.V_Check', 'not defined' ) ne $vupdate ) {
        $ret .= "
		</td><td informId=\"" . $name . "tmp\">Versionskonflikt ! 
		</td><td informId=\"" . $name . "tmp\">
		<div class=\"dval\" informid=\"" . $name . "-state\"></div>
		</td><td informId=\"" . $name . "tmp\">
		<div informid=\"" . $name . "-state-ts\">(please help)</div>
		 ";
    }
    else 
	{
        if ( AttrVal( $name, 'disable', "0" ) eq '1' ) {
            $ret .= "
		</td><td informId=\"" . $name . "tmp\">State: 
		</td><td informId=\"" . $name . "tmp\">
		<div class=\"dval\" informid=\"" . $name . "-state\"></div>
		</td><td informId=\"" . $name . "tmp\">
		<div informid=\"" . $name . "-state-ts\">disabled</div>";
        }
        else 
		{
            $ret .= "
		</td><td informId=\"" . $name . "tmp\">
		State: </td><td informId=\"" . $name . "tmp\">
		<div class=\"dval\" informid=\""
              . $name
              . "-state\">"
              . ReadingsVal( $name, 'state', '' ) . "</div>
		</td><td informId=\"" . $name . "tmp\">";
            if ( $mode ne "Notify" )
			{
                $ret .=
                    "<div informid=\""
                  . $name
                  . "-state-ts\">"
                  . ReadingsTimestamp( $name, 'state', '' )
                  . "</div>";
            }
            else 
			{
                $ret .=
                    "<div informid=\""
                  . $name
                  . "-state-ts\">"
                  . ReadingsTimestamp( $name, 'state', '' )
                  . "</div>";
            }
        }
    }
    $ret .= "<script>
	 \$( \"td[informId|=\'" . $name . "\']\" ).attr(\"informId\", \'test\');
	 \$(document).ready(function(){
	 \$( \".col3\" ).text( \"\" );
	// \$( \".devType\" ).text( \"MSwitch Inforoom: Anzeige der Deviceinformationen, Änderungen sind nur in den Details möglich.\" );
	});
	 </script>";
    $ret =~ s/#dp /:/g;
    return $ret;
}
#################################
sub MSwitch_check_init($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
    my $oldtrigger = ReadingsVal( $Name, '.Trigger_device', 'undef' );
    if ( $oldtrigger ne 'undef' ) 
	{
        $hash->{NOTIFYDEV} = $oldtrigger;
        readingsSingleUpdate( $hash, ".Trigger_device", $oldtrigger, 0 );
    }
	
	my $bridge = ReadingsVal( $Name, '.Distributor', 'undef' );
    if ( $bridge ne "undef" ) 
	{
        my @test = split( /\n/, $bridge );
        foreach my $testdevices (@test) 
		{
            my ( $key, $val ) = split( /=>/, $testdevices );
            $hash->{helper}{eventtoid}{$key} = $val;
		}
    }
    return;
}

####################
sub MSwitch_LoadHelper($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
    my $oldtrigger = ReadingsVal( $Name, '.Trigger_device', 'undef' );
    my $devhash    = undef;
    my $cdev       = '';
    my $ctrigg     = '';

     if ( $hash->{INIT} eq "def" ) 
	 {
         return;
     }

    if ( defined $hash->{DEF} ) 
	{
        $devhash = $hash->{DEF};
        my @dev = split( /#/, $devhash );
        $devhash = $dev[0];
        ( $cdev, $ctrigg ) = split( / /, $devhash );
        if ( defined $ctrigg ) {
            $ctrigg =~ s/\.//g;
        }
        else 
		{
            $ctrigg = '';
        }
        if ( defined $devhash ) {
            $hash->{NOTIFYDEV} = $cdev; # stand auf global ... änderung auf ...
            if ( defined $cdev && $cdev ne '' ) 
			{
                readingsSingleUpdate( $hash, ".Trigger_device", $cdev, 0 );
            }
        }
        else 
		{
            $hash->{NOTIFYDEV} = 'no_trigger';
            readingsSingleUpdate( $hash, ".Trigger_device", 'no_trigger', 0 );
        }
    }

    if (   !defined $hash->{NOTIFYDEV}|| $hash->{NOTIFYDEV} eq 'undef'|| $hash->{NOTIFYDEV} eq '' )
    {
        $hash->{NOTIFYDEV} = 'no_trigger';
    }

    if ( $oldtrigger ne 'undef' ) 
	{
        $hash->{NOTIFYDEV} = $oldtrigger;
        readingsSingleUpdate( $hash, ".Trigger_device", $oldtrigger, 0 );
    }
################
    MSwitch_set_dev($hash);
################
    if ( AttrVal( $Name, 'MSwitch_Activate_MSwitchcmds', "0" ) eq '1' ) 
	{
        addToAttrList('MSwitchcmd');
    }

    if ( ReadingsVal( $Name, '.First_init', 'undef' ) ne 'done' )
	{
        $hash->{helper}{config} = "no_config";
        readingsBeginUpdate($hash);
        readingsBulkUpdate( $hash, ".V_Check", $vupdate );
        readingsBulkUpdate( $hash, "state",    'active' );
        if ( defined $ctrigg && $ctrigg ne '' ) 
		{
            readingsBulkUpdate( $hash, ".Device_Events", $ctrigg );
            $hash->{DEF} = $cdev;
        }
        else 
		{
            readingsBulkUpdate( $hash, ".Device_Events", 'no_trigger' );
        }
        readingsBulkUpdate( $hash, ".Trigger_on",      'no_trigger' );
        readingsBulkUpdate( $hash, ".Trigger_off",     'no_trigger' );
        readingsBulkUpdate( $hash, ".Trigger_cmd_on",  'no_trigger' );
        readingsBulkUpdate( $hash, ".Trigger_cmd_off", 'no_trigger' );
        readingsBulkUpdate( $hash, ".Trigger_log",      'off' );
        readingsBulkUpdate( $hash, ".Device_Affected", 'no_device' );
		readingsBulkUpdate( $hash, ".Trigger_device", 'no_device' );
        readingsBulkUpdate( $hash, ".First_init",      'done' );
        readingsBulkUpdate( $hash, ".V_Check",         $vupdate );
        readingsEndUpdate( $hash, 0 );
		
		$hash->{NOTIFYDEV} = 'no_trigger';
        # setze ignoreliste
        $attr{$Name}{MSwitch_Ignore_Types} = join( " ", @doignore );

        # setze attr inforoom
        my $testdev = '';
      LOOP22:foreach my $testdevices ( keys %{ $modules{MSwitch}{defptr} } ) 
		{
            if ( $Name eq $testdevices ) { next LOOP22; }
            $testdev = AttrVal( $testdevices, 'MSwitch_Inforoom', '' );
        }
        if ( $testdev ne '' ) 
		{
            $attr{$Name}{MSwitch_Inforoom} = $testdev,;
        }

############################

        setDevAttrList( $Name, $attrresetlist );
		
		# suche nach CONFIGDEVICE
        my @found_devices = devspec2array("TYPE=MSwitch:FILTER=.msconfig=1");

        ##############
        if ( @found_devices > 0 && $defs{ $found_devices[0] }&& ReadingsVal( $found_devices[0], 'status','settings_nicht_anwenden' ) eq 'settings_anwenden')
        {
            my $confighash = $defs{ $found_devices[0] };
            my $configtype = $confighash->{TYPE};
            if ( $configtype eq "MSwitch" ) 
			{
                my $testreading = $confighash->{READINGS};
                my @areadings   = ( keys %{$testreading} );
                foreach my $key (@areadings) 
				{
                    next if ( $key !~ m/(^MSwitch_.*|^disabled.*)/ );
                    next if ReadingsVal( $found_devices[0], $key, 'undef' ) eq "";
                    my $aktset = ReadingsVal( $found_devices[0], $key, 'undef' );
                    $attr{$Name}{$key} = "$aktset";
                }
            }
        }
        else 
		{
            #setze alle attrs
            $attr{$Name}{MSwitch_Eventhistory}        = '0';
            $attr{$Name}{MSwitch_Safemode}            = '1';
            $attr{$Name}{MSwitch_Help}                = '0';
            $attr{$Name}{MSwitch_Debug}               = '0';
            $attr{$Name}{MSwitch_Expert}              = '0';
            $attr{$Name}{MSwitch_Delete_Delays}       = '1';
            $attr{$Name}{MSwitch_Include_Devicecmds}  = '1';
            $attr{$Name}{MSwitch_Include_Webcmds}     = '0';
            $attr{$Name}{MSwitch_Include_MSwitchcmds} = '0';
            $attr{$Name}{MSwitch_Include_MSwitchcmds} = '0';
            $attr{$Name}{MSwitch_Lock_Quickedit}      = '1';
            $attr{$Name}{MSwitch_Extensions}          = '0';
            $attr{$Name}{MSwitch_Mode}                = $startmode;
			$attr{$Name}{MSwitch_generate_Events}     = $MSwitch_generate_Events;
			
            fhem("attr $Name room MSwitch_Devices");
        }
    }

################ erste initialisierung eines devices

#Log3("test",0,"LoadHelper: $Name");
    if ( ReadingsVal( $Name, '.V_Check', 'undef' ) ne $vupdate && $autoupdate eq "on" )
    {
        MSwitch_VersionUpdate($hash);
    }
################

    if ( ReadingsVal( $Name, '.Trigger_on', 'undef' ) eq 'undef' ) 
	{
        readingsBeginUpdate($hash);
        readingsBulkUpdate( $hash, ".Device_Events",   'no_trigger' );
        readingsBulkUpdate( $hash, ".Trigger_on",      'no_trigger' );
        readingsBulkUpdate( $hash, ".Trigger_off",     'no_trigger' );
        readingsBulkUpdate( $hash, ".Trigger_log",      'on' );
        readingsBulkUpdate( $hash, ".Device_Affected", 'no_device' );
        readingsEndUpdate( $hash, 0 );
    }
	
	MSwitch_defineWidgets($hash);    #Neustart aller genutzten widgets
    MSwitch_Createtimer($hash);    #Neustart aller timer
	
    #### savedelays einlesen
    my $counter = 1;
    while ( ReadingsVal( $Name, 'SaveDelay_' . $counter, 'undef' ) ne "undef" )
    {
        my $del = ReadingsVal( $Name, 'SaveDelay_' . $counter, 'undef' );
        my @msgarray = split( /#\[tr\]/, $del );
        my $timecond = $msgarray[4];
        if ( $timecond > time )
		{
            $hash->{helper}{delays}{$del} = $timecond;
            InternalTimer( $timecond, "MSwitch_Restartcmd", $del );
        }
        $counter++;
    }
    fhem("deletereading $Name SaveDelay_.*");

    # eventtoid einlesen
    delete( $hash->{helper}{eventtoid} );
    my $bridge = ReadingsVal( $Name, '.Distributor', 'undef' );
    if ( $bridge ne "undef" ) 
	{
        my @test = split( /\n/, $bridge );
        foreach my $testdevices (@test) 
		{
            my ( $key, $val ) = split( /=>/, $testdevices );
            $hash->{helper}{eventtoid}{$key} = $val;
        }
    }
    return;
}

####################
sub MSwitch_Define($$) {

    my ( $hash, $def ) = @_;
    my $loglevel   = 0;
    my @a          = split( "[ \t][ \t]*", $def );
    my $name       = $a[0];
    my $devpointer = $name;
    my $devhash    = '';

    my $template  = "no";
    my $defstring = '';
    foreach (@a) {
        next if $_ eq $a[0];
        next if $_ eq $a[1];
        $defstring = $defstring . $_ . " ";
    }

    if ( $a[3] ) {
        Log3( $name, 5, "template: $a[3]" );
        $template = $a[3];
    }

    $modules{MSwitch}{defptr}{$devpointer} = $hash;
    $hash->{Version_Modul}                 = $version;
    $hash->{Version_Datenstruktur}         = $vupdate;
    $hash->{Version_autoupdate}            = $autoupdate;
    $hash->{MODEL}                         = $startmode . " " . $version;
    $hash->{Support}                       = $support;

    if ( $version ne $data{MSwitch}{Version} ) 
	{
        $hash->{Update} = "Modulversion " . $data{MSwitch}{Version} . " verfügbar";
    }

    if ( $defstring ne "" and $defstring =~ m/(\(.+?\))/ ) 
	{
        Log3( $name, 1, "ERROR MSwitch define over onelinemode deactivated" );    #LOG
        return "This mode is deactivated";
    }
    else 
	{
        $hash->{INIT} = 'fhem.save';
    }

    if ( $defstring =~ m/wizard.*/ )
    {
        $hash->{helper}{mode}      = 'absorb';
        $hash->{helper}{modesince} = time;
        $hash->{helper}{template}  = $template;
    }
	

    if ( $init_done && !defined( $hash->{OLDDEF} ) )
	{
        my $timecond = gettimeofday() + 5;
        InternalTimer( $timecond, "MSwitch_check_init", $hash );
    }
    else 
	{
    }
    return;
}

####################
sub MSwitch_Make_Undo($) {
	my ( $hash ) = @_;
	my $lastversion = MSwitch_Getconfig($hash,'undo') ;
	$data{MSwitch}{$hash}{undo}=$lastversion;
	$data{MSwitch}{$hash}{undotime}=time;
	return;
}
#######################
sub MSwitch_Get($$@) {
    my ( $hash, $name, $opt, @args ) = @_;
    my $ret;
    if ( ReadingsVal( $name, '.change', '' ) ne '' ) {
        return "Unknown argument, choose one of ";
    }
    return "\"get $name\" needs at least one argument" unless ( defined($opt) );

####################
    my $KLAMMERFEHLER;
    my $CONDTRUE;
    my $CONDTRUE1;
    my $KLARZEITEN;
    my $READINGSTATE;
    my $NOREADING;
    my $INHALT;
    my $INCOMMINGSTRING;
    my $STATEMENTPERL;
    my $SYNTAXERROR;
    my $DELAYDELETE;
    my $NOTIMER;
    my $SYSTEMZEIT;
    my $SCHALTZEIT;
	my $EXECUTEDCMD ;
	my $WARNINGS ;
	my $WARNINGSOUT;

    if (AttrVal($name, 'MSwitch_Language',AttrVal( 'global', 'language', 'EN' )) eq "DE")
    {
        $KLAMMERFEHLER ="Fehler in der Klammersetzung, die Anzahl öffnender und schliessender Klammern stimmt nicht überein.";
        $CONDTRUE     = "Bedingung ist Wahr und wird ausgeführt";
        $CONDTRUE1    = "Bedingung ist nicht Wahr und wird nicht ausgeführt";
        $KLARZEITEN   = "If Anweisung Perl Klarzeiten:";
        $READINGSTATE = "Status der geprüften Readings:";
        $NOREADING    = "Reading nicht vorhanden !";
        $INHALT       = "Inhalt:";
        $INCOMMINGSTRING = "eingehender String:";
        $STATEMENTPERL   = "If Anweisung Perl:";
        $SYNTAXERROR     = "Syntaxfehler:";
        $DELAYDELETE ="INFO: Alle anstehenden Timer wurden neu berechnet, alle Delays wurden gelöscht";
        $NOTIMER    = "Timer werden nicht ausgeführt";
        $SYSTEMZEIT = "Systemzeit:";
        $SCHALTZEIT = "Schaltzeiten (at - kommandos)";
		$EXECUTEDCMD = "ausgeführter Befehl";
		$WARNINGS = "gemeldete Fehler";
		$WARNINGSOUT = "keine";
    }
    else 
	{
        $KLAMMERFEHLER ="Error in brace replacement, number of opening and closing parentheses does not match.";
        $CONDTRUE        = "Condition is true and is executed";
        $CONDTRUE1       = "Condition is not true and will not be executed";
        $KLARZEITEN      = "If statement Perl clears:";
        $READINGSTATE    = "States of the checked readings:";
        $NOREADING       = "Reading not available!";
        $INHALT          = "content:";
        $INCOMMINGSTRING = "Incomming String:";
        $STATEMENTPERL   = "If statement Perl:";
        $SYNTAXERROR     = "Syntaxerror:";
        $DELAYDELETE ="INFO: All pending timers have been recalculated, all delays have been deleted";
        $NOTIMER    = "Timers are not running";
        $SYSTEMZEIT = "system time:";
        $SCHALTZEIT = "Switching times (at - commands)";
		$EXECUTEDCMD = "executed comand";
		$WARNINGS = "errors";
		$WARNINGSOUT = "no errors";
    }



#################################################

  if ( $opt eq 'extcmd' ) 
	{

	  my $typ= $args[0];
	  my $cs = $args[1];
	  my $incommingevent=$args[2];
	  
	  delete( $hash->{helper}{aktevent} );
	  if ($incommingevent ne "no_trigger")
	  {
	  $hash->{helper}{aktevent}=$incommingevent;
	  }

	 if ($typ ne "FreeCmd")
	 {
		  my $cs = $args[1] ;
		  $cs =~ s/#\[sp\]/ /g;
		  $cs = MSwitch_dec( $hash, $cs );
		  my $exec = "set ".$args[0]." ".$cs;
		  #
		  my $errorout="<small>$WARNINGS:<br>";
		  my $errors = AnalyzeCommandChain( undef, $exec );
		  if ( defined($errors) and $errors ne "OK" )
				{
					$errorout.=$errors;
				}
				else
				{
					$errorout.="$WARNINGSOUT";
				}
		  delete( $hash->{helper}{aktevent} );
		  return "<small>$EXECUTEDCMD:</small><br><br>$exec<br><br>$errorout";
	  }
	  else
	  {
		my $cs = $args[1] ;
		$cs =~ s/#\[sp\]/ /g;
		$cs =~ s/#\[se\]/;/g;
		$cs =~ s/#\[nl\]//g;
		$cs = MSwitch_dec( $hash, $cs );
		$cs = MSwitch_makefreecmd( $hash, $cs );
		   
        my $errorout="<small>$WARNINGS:<br>";
		
		
		my $errors = eval($cs);
	
		
		if ( defined($errors) and $errors ne "OK" )
			{
				$errorout.=$errors;
			}
		else
			{
					$errorout.="$WARNINGSOUT";
			}
		delete( $hash->{helper}{aktevent} );
		
		$cs =~ s/;/;<br>/g;
		$cs =~ s/^{/{<br>/g;
		$cs =~ s/}$/}<br>/g;
		return "<small>$EXECUTEDCMD:</small><br><br>$cs<br><br>$errorout";
		return "ok";
		}
	return;
    }
####################
    if ( $opt eq 'MSwitch_preconf' ) 
	{
        MSwitch_setconfig( $hash, $args[0] );
        return "MSwitch_preconfig for $name has loaded.\nPlease refresh device.";
    }
	
	
####################
    if ( $opt eq 'Eventlog' ) {
        $ret = MSwitch_Eventlog( $hash, $args[0] );
        return $ret;
    }
####################
    if ( $opt eq 'restore_MSwitch_Data' && $args[0] eq "this_device" ) {
        $ret = MSwitch_restore_this($hash);
        return $ret;
    }	
################
    if ( $opt eq 'restore_MSwitch_Data' && $args[0] eq "all_devices" ) {
        # open( BACKUPDATEI, "<MSwitch_backup_$vupdate.cfg" )
          # || return "no Backupfile found\n";
        # close(BACKUPDATEI);
        #$hash->{helper}{RESTORE_ANSWER} = $hash->{CL};
        my $ret = MSwitch_restore_all($hash);
        return $ret;
    }
####################
    if ( $opt eq 'checkevent' ) {
        $ret = MSwitch_Check_Event( $hash, $args[0] );
        return $ret;
    }
####################
    if ( $opt eq 'deletesinglelog' ) {
        $ret = MSwitch_delete_singlelog( $hash, $args[0] );
        return $ret;
    }
####################
    if ( $opt eq 'config' ) {
        $ret = MSwitch_Getconfig($hash,'get');
        return $ret;
    }
####################
    if ( $opt eq 'support_info' ) {
        $ret = MSwitch_Getsupport($hash);
        return $ret;
    }
####################
    if ( $opt eq 'sysextension' ) {
        $ret = MSwitch_Sysextension($hash);
        return $ret;
    }
####################
    if ( $opt eq 'checkcondition' ) {
        my ( $condstring, $eventstring ) = split( /\|/, $args[0] );
        $condstring =~ s/#\[dp\]/:/g;
        $condstring =~ s/#\[pt\]/./g;
        $condstring =~ s/#\[ti\]/~/g;
        $condstring =~ s/#\[sp\]/ /g;
        $eventstring =~ s/#\[dp\]/:/g;
        $eventstring =~ s/#\[pt\]/./g;
        $eventstring =~ s/#\[ti\]/~/g;
        $eventstring =~ s/#\[sp\]/ /g;
        $condstring =~ s/\(DAYS\)/|/g;

	    my @eventteile   = split( /:/, $eventstring);
		
		

		
		if (@eventteile ==2)
		{
	if (!defined $eventteile[0]){ $eventteile[0]="";}
	if (!defined $eventteile[1] ){$eventteile[1]="";}
	#if (!defined $eventteile[2]){ $eventteile[2]="";}
		$hash->{helper}{evtparts}{parts}=3;
		$hash->{helper}{evtparts}{device}	=".*";
		$hash->{helper}{evtparts}{evtpart1}	=".*";
		$hash->{helper}{evtparts}{evtpart2}	=$eventteile[0];
		$hash->{helper}{evtparts}{evtpart3}	=$eventteile[1];
		$hash->{helper}{evtparts}{evtfull}	=".*:".$eventstring;
		$hash->{helper}{evtparts}{event}	=$eventteile[0].":".$eventteile[1];	
		$eventstring=$hash->{helper}{evtparts}{evtfull};
		}
		else
		{
			
	if (!defined $eventteile[0]){ $eventteile[0]="";}
	if (!defined $eventteile[1] ){$eventteile[1]="";}
	if (!defined $eventteile[2]){ $eventteile[2]="";}	
			
			
		$hash->{helper}{evtparts}{parts}=3;
		$hash->{helper}{evtparts}{device}	=$eventteile[0];
		$hash->{helper}{evtparts}{evtpart1}	=$eventteile[0];
		$hash->{helper}{evtparts}{evtpart2}	=$eventteile[1];
		$hash->{helper}{evtparts}{evtpart3}	=$eventteile[2];
		$hash->{helper}{evtparts}{evtfull}	=$eventstring;
		$hash->{helper}{evtparts}{event}	=$eventteile[1].":".$eventteile[2];
		}
		
        my $ret1 = MSwitch_checkcondition( $condstring, $name, $eventstring );
        my $condstring1 = $hash->{helper}{conditioncheck};
        my $errorstring = $hash->{helper}{conditionerror};
        if ( !defined $errorstring ) { $errorstring = '' }
        $condstring1 =~ s/</\&lt\;/g;
        $condstring1 =~ s/>/\&gt\;/g;
        $errorstring =~ s/</\&lt\;/g;
        $errorstring =~ s/>/\&gt\;/g;

        if ( $errorstring ne '' && $condstring1 ne 'Klammerfehler' ) {
            $ret1 =
                '<div style="color: #FF0000">'
              . $SYNTAXERROR . '<br>'
              . $errorstring
              . '</div><br>';
        }
        elsif ( $condstring1 eq 'Klammerfehler' ) {
            $ret1 =
                '<div style="color: #FF0000">'
              . $SYNTAXERROR . '<br>'
              . $KLAMMERFEHLER
              . '</div><br>';
        }
        else {
            if ( $ret1 eq 'true' ) {
                $ret1 = $CONDTRUE;
            }
            if ( $ret1 eq 'false' ) {
                $ret1 = $CONDTRUE1;
            }
        }
        $condstring =~ s/~/ /g;
        my $condmarker = $condstring1;
        my $x          = 0;              # exit
        while ( $condmarker =~ m/(.*)(\d{10})(.*)/ ) {
            $x++;                        # exit
            last if $x > 20;             # exit
            my $timestamp = FmtDateTime($2);
            chop $timestamp;
            chop $timestamp;
            chop $timestamp;
            my ( $st1, $st2 ) = split( / /, $timestamp );
            $condmarker = $1 . $st2 . $3;
        }
        $ret =
            $INCOMMINGSTRING
          . "<br>$condstring<br><br>"
          . $STATEMENTPERL
          . "<br>$condstring1<br><br>";
        $ret .= $KLARZEITEN . "<br>$condmarker<br><br>" if $x > 0;
        $ret .= $ret1;
        my $condsplit = $condmarker;
        my $reads     = '<br><br>' . $READINGSTATE . '<br><br>';
        $x = 0;    # exit


        while ( $condsplit =~m/(.*)(ReadingsVal|ReadingsNum|ReadingsAge|AttrVal|InternalVal)(.*?\))(.*)/)
        {
            my $readname      = $2 . $3;
            my $readinginhalt = eval $readname;
            $condsplit = $1 . $4;
            $x++;    # exit
            last if $x > 20;
            $reads .=
              $readname . "     " . $INHALT . " " . $readinginhalt . "<br>";
        }

        $ret .= $reads if $x > 0;
## anzeige funktionserkennung
        if ( defined $hash->{helper}{eventhistory}{DIFFERENCE} ) 
		{
            $ret .= "<br>";
            $ret .= $hash->{helper}{eventhistory}{DIFFERENCE};
            $ret .= "<br>";
            delete( $hash->{helper}{eventhistory}{DIFFERENCE} );
        }

        if ( defined $hash->{helper}{eventhistory}{TENDENCY} ) 
		{
            $ret .= "<br>";
            $ret .= $hash->{helper}{eventhistory}{TENDENCY};
            $ret .= "<br>";
            delete( $hash->{helper}{eventhistory}{TENDENCY} );
        }

        if ( defined $hash->{helper}{eventhistory}{AVERAGE} ) 
		{
            $ret .= "<br>";
            $ret .= $hash->{helper}{eventhistory}{AVERAGE};
            $ret .= "<br>";
            delete( $hash->{helper}{eventhistory}{AVERAGE} );
        }

        if ( defined $hash->{helper}{eventhistory}{INCREASE} ) 
		{
            $ret .= "<br>";
            $ret .= $hash->{helper}{eventhistory}{INCREASE};
            $ret .= "<br>";
            delete( $hash->{helper}{eventhistory}{INCREASE} );
        }

        my $err1;
        my $err2;

        if ( $errorstring ne '' ) {
            ( $err1, $err2 ) = split( /near /, $errorstring );
            chop $err2;
            chop $err2;
            $err2 = substr( $err2, 1 );
            $ret =~ s/$err2/<span style="color: #FF0000">$err2<\/span>/ig;
        }
        $hash->{helper}{conditioncheck} = '';
        $hash->{helper}{conditionerror} = '';
        return "<span style=\"font-size: medium\">" . $ret . "<\/span>";
    }

    #################################################
    if ( $opt eq 'HTTPresponse' ) {

        my $inhalt .= $data{MSwitch}{$name}{HTTPresponse};
        $ret .= "<textarea cols='120' rows='30>$inhalt</textarea>";

        if ( length($inhalt) <1 )    # wenn ein Fehler bei der HTTP Abfrage aufgetreten ist
        {
            $ret = "<html>Keine Daten vorhanden</html>";
        }
        $ret = "<html>" . $ret . "</html>";
        return $ret;
    }

    #################################################
    if ( $opt eq 'active_timer' && $args[0] eq 'delete' )
	{
        MSwitch_Clear_timer($hash);
        MSwitch_Createtimer($hash);
        MSwitch_Delete_Delay( $hash, 'all' );
        $ret .= "<br>" . $DELAYDELETE . "<br>";
        return $ret;
    }
#################################################
    if ( $opt eq 'active_timer' && $args[0] eq 'show' )
	{
        if ( defined $hash->{helper}{wrongtimespec}and $hash->{helper}{wrongtimespec} ne "" )
        {
            $ret = $hash->{helper}{wrongtimespec};
            $ret .= "<br>" . $NOTIMER . "<br>";
            return $ret;
        }
		
	 if ( ReadingsVal( $name, 'Timercontrol', 'on' ) eq "off" )
		{
         $ret .= "<br>Timersteuerung ist deaktiviert<br>";
		 return $ret;
		}
		
        $ret .= "<div nowrap>" . $SYSTEMZEIT . " " . localtime() . "</div><hr>";
        $ret .= "<div nowrap>" . $SCHALTZEIT . "</div><hr>";

        #timer
        my $timehash = $hash->{helper}{timer};

        foreach my $a ( sort keys %{$timehash} ) 
		{
            my @string  = split( /-/,  $hash->{helper}{timer}{$a} );
            my @string1 = split( /ID/, $string[1] );
            my $number  = $string1[0];
            my $id      = $string1[1];
            my $time = FmtDateTime( $string[0] );
            my @timers = split( /,/, $a );
            if ( $number eq '1' ) {
                $ret .=
                    "<div nowrap>"
                  . $time
                  . " switch MSwitch on + execute 'on' cmds</div>";
            }
            if ( $number eq '2' ) {
                $ret .=
                    "<div nowrap>"
                  . $time
                  . " switch MSwitch off + execute 'off' cmds</div>";
            }
            if ( $number eq '3' ) {
                $ret .=
                    "<div nowrap>"
                  . $time
                  . " execute 'cmd1' commands only</div>";
            }
            if ( $number eq '4' ) {
                $ret .=
                    "<div nowrap>"
                  . $time
                  . " execute 'cmd2' commands only</div>";
            }

            if ( $number eq '9' ) {
                $ret .=
                    "<div nowrap>"
                  . $time
                  . " execute 'cmd1+cmd2' commands only</div>";
            }

            if ( $number eq '10' ) {
                $ret .=
                    "<div nowrap>"
                  . $time
                  . " execute 'cmd1+cmd2' commands with ID "
                  . $id
                  . " only</div>";
            }

            if ( $number eq '5' ) {
                $ret .=
                    "<div nowrap>"
                  . $time
                  . " neuberechnung aller Schaltzeiten </div>";
            }

            if ( $number eq '6' ) {
                $ret .=
                    "<div nowrap>"
                  . $time
                  . " execute 'cmd1' commands with ID "
                  . $id
                  . " only</div>";
            }
            if ( $number eq '7' ) {
                $ret .=
                    "<div nowrap>"
                  . $time
                  . " execute 'cmd2' commands from ID "
                  . $id
                  . " only</div>";
            }
        }
		
		if ( ReadingsVal( $name, 'Timercontrol', 'on' ) eq "off" )
		{
          $ret .="<div nowrap><br>Timer sind deaktiviert.</div>";
		}
		
        #delays
        $ret .= "<br>&nbsp;<br><div nowrap>aktive Delays:</div><hr>";
        $timehash = $hash->{helper}{delays};

        foreach my $a ( sort keys %{$timehash} ) 
		{
            my $b      = substr( $hash->{helper}{delays}{$a}, 0, 10 );
            my $time   = FmtDateTime($b);
            my @timers = split( /#\[tr\]/, $a );
            $ret .= "<div nowrap><strong>Ausführungszeitpunkt:</strong> ". $time . "<br>";
            $ret .= "<strong>Indikator: </strong>" . $timers[3] . "<br>";
            $ret .= "<strong>auszuführender Befehl:</strong><br>". $timers[0] . "<br>";
            $ret .= "</div><hr>";
			}
			
        if (  $ret ne "<div nowrap>". $SCHALTZEIT. "</div><hr><div nowrap>aktive Delays:</div><hr>" )
        {
            return $ret;
        }
    return "<span style=\"font-size: medium\">Keine aktiven Delays/Ats gefunden <\/span>";
    }

#######
    my $extension = '';
	if ( AttrVal( $name, 'MSwitch_SysExtension', "0" ) =~ m/(1|2)/s  )
	{
        $extension = 'sysextension:noArg';
    }

### modulmode - no sets
    if ( AttrVal( $name, 'MSwitch_Modul_Mode', "0" ) eq '1' ) 
	{
        return "Unknown argument $opt, choose one of reset_Switching_once:noArg  HTTPresponse:noArg config:noArg support_info:noArg active_timer:show";
    }
#######

    if ( AttrVal( $name, 'MSwitch_Mode', 'Notify' ) eq "Dummy" ) 
	{
        if ( AttrVal( $name, "MSwitch_Selftrigger_always", 0 ) eq "1" ) 
		{
            return "Unknown argument $opt, choose one of reset_Switching_once:noArg HTTPresponse:noArg Eventlog:timeline,clear config:noArg support_info:noArg restore_MSwitch_Data:this_device,all_devices active_timer:show,delete";
        }
        else 
		{
            return "Unknown argument $opt, choose one of support_info:noArg restore_MSwitch_Data:this_device,all_devices";
        }
    }

    if ( ReadingsVal( $name, '.lock', 'undef' ) ne "undef" ) {
        return"Unknown argument $opt, choose one of reset_Switching_once:noArg HTTPresponse:noArg support_info:noArg active_timer:show,delete config:noArg restore_MSwitch_Data:this_device,all_devices ";
    }
    else 
	{
        return "Unknown argument $opt, choose one of reset_Switching_once:noArg HTTPresponse:noArg Eventlog:sequenzformated,timeline,clear support_info:noArg config:noArg active_timer:show,delete restore_MSwitch_Data:this_device,all_devices $extension";
    }
}
####################
sub MSwitch_AsyncOutput ($) {
    my ( $client_hash, $text ) = @_;
    return $text;
}

##################################
##################################
# schreibt log
sub MSwitch_Set_Writelog($@)  
	{
		my ( $hash, $name, $cmd, @args ) = @_;
		my @logs = split( /\|/, $args[0] );
		shift @args;
		MSwitch_LOG($name,$logs[0],"@args");
		return;	
	}

##################################
#timer on/off
sub MSwitch_Set_timer($@)  
	{
		my ( $hash, $name, $cmd, @args ) = @_;
		my $showevents = AttrVal( $name, "MSwitch_generate_Events", 0 );
		if (AttrVal( $name, 'MSwitch_Debug', '0' ) ne "0" ){$showevents = 1};
		readingsSingleUpdate( $hash, "Timercontrol", $args[0], $showevents );
		if ($args[0] eq "on")
		{
			MSwitch_Clear_timer($hash);
			MSwitch_Createtimer($hash);
			MSwitch_LOG( $name, 6, "Timer neu berechnet L:" . __LINE__ );
		}
		if ($args[0] eq "off")
		{
			MSwitch_Clear_timer($hash);
		}
        return;
	}
	
##################################

sub MSwitch_Set_ResetCmdCount($@)  
	{
	my ( $hash, $name, $cmd, @args ) = @_;
	if ( $args[0] eq "1" ) 
			{
				readingsSingleUpdate( $hash, "EVT_CMD1_COUNT", 0, 1 );
			}
			if ( $args[0] eq "2" ) 
			{
				readingsSingleUpdate( $hash, "EVT_CMD2_COUNT", 0, 1 );
			}
			if ( $args[0] eq "all" ) 
			{
				readingsSingleUpdate( $hash, "EVT_CMD1_COUNT", 0, 1 );
				readingsSingleUpdate( $hash, "EVT_CMD2_COUNT", 0, 1 );
			}
			MSwitch_LOG( $name, 6, "Counter resettet L:" . __LINE__ );
			return;
	}

##################################

sub MSwitch_Set_ReloadTimer($@)  
	{
	my ( $hash, $name, $cmd, @args ) = @_;
	MSwitch_Clear_timer($hash);
	MSwitch_Createtimer($hash);
	MSwitch_LOG( $name, 6, "Timer neu berechnet L:" . __LINE__ );
	return;
	}
	
##################################

sub MSwitch_Set_Wizard($@)  
	{
	my ( $hash, $name, $cmd, @args ) = @_;
	$hash->{helper}{mode}      = 'absorb';
	$hash->{helper}{modesince} = time;return;
	}

##################################

sub MSwitch_Set_ChangeRenamed($@)  
	{
	my ( $hash, $name, $cmd, @args ) = @_;	
	my $changestring = $args[0] . "#" . $args[1];
    MSwitch_confchange( $hash, $changestring );
    MSwitch_LOG( $name, 6, "Name geändertt L:" . __LINE__ );
    return;
	}	
	
##################################

sub MSwitch_Set_ExecCmd($@)  
	{
	my ( $hash, $name, $cmd, @args ) = @_;	
	my $comand;	
	my $execids = "0";
	$comand = "on" if $cmd eq 'exec_cmd_1';	
	$comand = "off" if $cmd eq 'exec_cmd_2';
	
	if ( $args[0] eq 'ID' ) 
		{
            $execids = $args[1];
            $args[0] = 'ID';
        }
    if ( $args[0] eq "" ) 
		{
            MSwitch_Exec_Notif( $hash, $comand, 'nocheck', '', 0 );
            return;
        }
    if ( $args[0] ne 'ID' || $args[0] ne '' ) 
		{
            if ( $args[1] !~ m/\d/ ) 
			{
                Log3( $name, 1,"error at id call $args[1]: format must be exec_cmd_1 <ID x,z,y>");
                return;
            }
        }
        # cmd1 abarbeiten
        MSwitch_LOG( $name, 6,"ausführung exec_cmd_1 $args[1] L:" . __LINE__ );
        MSwitch_Exec_Notif( $hash, $comand, 'nocheck', '', $execids );
    return;

	}	
	
##################################

sub MSwitch_Set_AddEvent($@)  
	{
	my ( $hash, $name, $cmd, @args ) = @_;	
	MSwitch_Make_Undo($hash);
    delete( $hash->{helper}{config} );
    # event manuell zufügen
    my $devName = ReadingsVal( $name, '.Trigger_device', '' );
    $args[0] =~ s/\[sp\]/ /g;
    my @newevents = split( /,/, $args[0] );
    if ( ReadingsVal( $name, '.Trigger_device', '' ) eq "all_events" )
		{
            foreach (@newevents) 
			{
                $hash->{helper}{events}{all_events}{$_} = "on";
            }
        }
        else 
		{
            foreach (@newevents) 
			{
                $hash->{helper}{events}{$devName}{$_} = "on";
            }
        }
    my $events    = '';
    my $eventhash = $hash->{helper}{events}{$devName};
    foreach my $name ( keys %{$eventhash} ) 
		{
            $events = $events . $name . '#[tr]';
        }
    chop($events);
    chop($events);
    chop($events);
    chop($events);
    chop($events);
    readingsSingleUpdate( $hash, ".Device_Events", $events, 0 );
    return;
	}		
	

##################################
#timer undo
sub MSwitch_Set_Undo($@)  
	{
		my ( $hash, $name, $cmd, @args ) = @_;
		my %keys;
		foreach my $attrdevice ( keys %{ $attr{$name} } ) 
		{
			delete $attr{$name}{$attrdevice};
		}
		my $testreading = $hash->{READINGS};
		my @areadings   = ( keys %{$testreading} );
		foreach my $key (@areadings)
		{
			fhem("deletereading $name $key ");
		}
		my $Zeilen = $data{MSwitch}{$hash}{undo};  
		$Zeilen =~ s/\\n/#[EOL]/g;
		MSwitch_exec_undo( $hash, $Zeilen );
		delete $data{MSwitch}{$hash}{undotime};
		delete $data{MSwitch}{$hash}{undo};
		return;
	}	
	
##################################
sub MSwitch_Set_DelRepeats($@)  
	{
	my ( $hash, $name, $cmd, @args ) = @_;
	my $inhalt = $hash->{helper}{repeats};
    foreach my $a ( sort keys %{$inhalt} ) 
		{
            my $key = $hash->{helper}{repeats}{$a};
            RemoveInternalTimer($key);
        }
    delete( $hash->{helper}{repeats} );
    MSwitch_LOG( $name, 6, "Repeats gelöscht L:" . __LINE__ );
    return;
	}	

##################################
sub MSwitch_Set_DelDelays($@)  
	{
	my ( $hash, $name, $cmd, @args ) = @_;
    if ( defined $args[0] && $args[0] eq "" ) 
		{
            MSwitch_Delete_Delay( $hash, $name );
        }
        else 
		{
            MSwitch_Delete_specific_Delay( $hash, $name, $args[0] );
        }
        MSwitch_LOG( $name, 6, "Delays gelöscht L:" . __LINE__ );
        return;
	}		
	
##################################
sub MSwitch_Set_switching_once($@)  
	{
	my ( $hash, $name, $cmd, @args ) = @_;
	delete( $hash->{helper}{lastexecute});
	MSwitch_LOG( $name, 6, "Blockierung von gleichen Befehlsketten zurückgesetzt L:" . __LINE__ );
	return;
	}		
################################
#logging web.js
sub MSwitch_Set_loggingwebjs($@)  
	{
	my ( $hash, @args ) = @_;
	if ( defined $args[0] && $args[0] eq "1" ) 
		{
            $hash->{helper}{aktivelog} = "on";
        }
        else
		{
            delete( $hash->{helper}{aktivelog} );
        }
    return;
	}		

################################
sub MSwitch_Set_ResetDevice($@)  
	{
	my ( $hash, $name, $cmd, @args ) = @_;
	        if ( $args[0] eq 'checked' ) 
			{
				$hash->{helper}{config} = "no_config";
				my $testreading = $hash->{READINGS};
				delete $hash->{DEF};
				MSwitch_Delete_Delay( $hash, $name );
				my $inhalt = $hash->{helper}{repeats};
				
				foreach my $a ( sort keys %{$inhalt} ) 
				{
					my $key = $hash->{helper}{repeats}{$a};
					RemoveInternalTimer($key);
				}
				
				delete( $hash->{helper}{repeats} );
				delete $data{MSwitch}{devicecmds1}{$name};
				delete $data{MSwitch}{last_devicecmd_save};
				delete( $hash->{helper}{eventhistory} );
				delete( $hash->{IncommingHandle} );
				delete( $hash->{helper}{eventtoid} );
				delete( $hash->{helper}{savemodeblock} );
				delete( $hash->{helper}{sequenz} );
				delete( $hash->{helper}{history} );
				delete( $hash->{helper}{eventlog} );
				delete( $hash->{helper}{mode} );
				delete( $hash->{helper}{reset} );
				delete( $hash->{READINGS} );

				my %keys;
				my $oldinforoom = AttrVal( $name, 'MSwitch_Inforoom', 'undef' );
				my $oldroom     = AttrVal( $name, 'MSwitch_Inforoom', 'undef' );
				foreach my $attrdevice ( keys %{ $attr{$name} } )    #geht
				{
					fhem "deleteattr $name $attrdevice";
				}

				$hash->{Version_Modul}         = $version;
				$hash->{Version_Datenstruktur} = $vupdate;
				$hash->{Version_autoupdate}    = $autoupdate;
				$hash->{MODEL}                 = $startmode . " " . $version;

				readingsBeginUpdate($hash);
				readingsBulkUpdate( $hash, ".Device_Events",   "no_trigger", 1 );
				readingsBulkUpdate( $hash, ".Trigger_cmd_off", "no_trigger", 1 );
				readingsBulkUpdate( $hash, ".Trigger_cmd_on",  "no_trigger", 1 );
				readingsBulkUpdate( $hash, ".Trigger_off",     "no_trigger", 1 );
				readingsBulkUpdate( $hash, ".Trigger_on",      "no_trigger",  1 );
				readingsBulkUpdate( $hash, ".Trigger_device",   "no_trigger", 1 );
				readingsBulkUpdate( $hash, ".Trigger_log",      "off",        1 );
				readingsBulkUpdate( $hash, "state",            "active",     1 );
				readingsBulkUpdate( $hash, ".V_Check",         $vupdate,     1 );
				readingsBulkUpdate( $hash, ".First_init",      'done' );
				readingsEndUpdate( $hash, 0 );

				setDevAttrList( $name, $attrresetlist );
				$hash->{NOTIFYDEV}                        = 'no_trigger';
				$attr{$name}{MSwitch_Eventhistory}        = '0';
				$attr{$name}{MSwitch_Safemode}            = '1';
				$attr{$name}{MSwitch_Help}                = '0';
				$attr{$name}{MSwitch_Debug}               = '0';
				$attr{$name}{MSwitch_Expert}              = '0';
				$attr{$name}{MSwitch_Delete_Delays}       = '1';
				$attr{$name}{MSwitch_Include_Devicecmds}  = '1';
				$attr{$name}{MSwitch_Include_Webcmds}     = '0';
				$attr{$name}{MSwitch_Include_MSwitchcmds} = '0';
				$attr{$name}{MSwitch_Lock_Quickedit}      = '1';
				$attr{$name}{MSwitch_Extensions}          = '0';
				$attr{$name}{room} = $oldroom if $oldroom ne "undef";
				$attr{$name}{MSwitch_Mode} = $startmode;
				$attr{$name}{MSwitch_Ignore_Types} = join( " ", @doignore );
				fhem("attr $name MSwitch_Inforoom $oldinforoom")if $oldinforoom ne "undef";
				return;
			}
        my $client_hash = $hash->{CL};
        $hash->{helper}{tmp}{reset} = "on";
        return;
	}		
	
################################
sub MSwitch_Set_SetTrigger($@)  
	{
		my ( $hash, $name, $cmd, @args ) = @_;
		MSwitch_Make_Undo($hash);
		MSwitch_Clear_timer($hash);
		delete( $hash->{helper}{config} );
		delete( $hash->{helper}{wrongtimespeccond} );
		my $oldtrigger = ReadingsVal( $name, '.Trigger_device', '' );
		readingsSingleUpdate( $hash, ".Trigger_device",     $args[0], 0 );
		if ( $args[6] eq 'NoCondition' ){$args[6]="";}
		readingsSingleUpdate( $hash, ".Trigger_condition", $args[6], 0 );
		readingsSingleUpdate( $hash, ".Trigger_time_1", '', 0 );
		readingsSingleUpdate( $hash, ".Trigger_time_2", '', 0 );
		readingsSingleUpdate( $hash, ".Trigger_time_3", '', 0 );
		readingsSingleUpdate( $hash, ".Trigger_time_4", '', 0 );
		readingsSingleUpdate( $hash, ".Trigger_time_5", '', 0 );
		
		if ( defined $args[1] && $args[1] ne 'NoTimer' ){readingsSingleUpdate( $hash, ".Trigger_time_1", $args[1], 0 );}
		if ( defined $args[2] && $args[2] ne 'NoTimer' ){readingsSingleUpdate( $hash, ".Trigger_time_2", $args[2], 0 );}
		if ( defined $args[3] && $args[3] ne 'NoTimer' ){readingsSingleUpdate( $hash, ".Trigger_time_3", $args[3], 0 );}
		if ( defined $args[4] && $args[4] ne 'NoTimer' ){readingsSingleUpdate( $hash, ".Trigger_time_4", $args[4], 0 );}
		if ( defined $args[5] && $args[5] ne 'NoTimer' ){readingsSingleUpdate( $hash, ".Trigger_time_5", $args[5], 0 );}
		 
		MSwitch_Createtimer($hash);
		
		if ( !defined $args[7] ) {
            readingsDelete( $hash, '.Trigger_Whitelist' );
        }
        else {
            readingsSingleUpdate( $hash, ".Trigger_Whitelist", $args[7], 0 );
        }

        if ( $oldtrigger ne $args[0] ) {
            MSwitch_Delete_Triggermemory($hash);    # lösche alle events
        }
		
        $hash->{helper}{events}{ $args[0] }{'no_trigger'} = "on";
        if ( $args[0] ne 'no_trigger' ) {
            if ( $args[0] eq "all_events" ) {
                delete( $hash->{NOTIFYDEV} );
                if ( ReadingsVal( $name, '.Trigger_Whitelist', '' ) ne '' ) {
                    $hash->{NOTIFYDEV} =
                      ReadingsVal( $name, '.Trigger_Whitelist', '' );
                }
            }
            else {

                if ( $args[0] ne "MSwitch_Self" ) {
                    $hash->{NOTIFYDEV} = $args[0];
                    my $devices = MSwitch_makeAffected($hash);
                    $hash->{DEF} = $args[0] . ' # ' . $devices;
                }
                else {
                    $hash->{NOTIFYDEV} = $name;
                    my $devices = MSwitch_makeAffected($hash);
                    $hash->{DEF} = $name . ' # ' . $devices;
                }
            }
        }
        else {
            $hash->{NOTIFYDEV} = 'no_trigger';
            delete $hash->{DEF};
        }
        readingsSingleUpdate( $hash, "EVENT", "init", 0 );
	return;
	}	
	
###############################

sub MSwitch_Set_SetTrigger1($@)  
	{
		my ( $hash, $name, $cmd, @args ) = @_;
		MSwitch_Make_Undo($hash);
        delete( $hash->{helper}{config} );
        # setze trigger events
        my $triggeron     = '';
        my $triggeroff    = '';
        my $triggercmdon  = '';
        my $triggercmdoff = '';
        $args[0] =~ s/~/ /g;
        $args[1] =~ s/~/ /g;
        $args[2] =~ s/~/ /g;
        $args[3] =~ s/~/ /g;
        $args[4] =~ s/~/ /g;
        if ( !defined $args[1] ) { $args[1] = "" }
        if ( !defined $args[3] ) { $args[3] = "" }
        $triggeron  = $args[0];
        $triggeroff = $args[1];
        if ( !defined $args[3] ) { $args[3] = "" }
        if ( !defined $args[4] ) { $args[4] = "" }
        $triggercmdon  = $args[3];
        $triggercmdoff = $args[4];
        readingsBeginUpdate($hash);
        readingsBulkUpdate( $hash, ".Trigger_on",      $triggeron );
        readingsBulkUpdate( $hash, ".Trigger_off",     $triggeroff );
        readingsBulkUpdate( $hash, ".Trigger_cmd_on",  $triggercmdon );
        readingsBulkUpdate( $hash, ".Trigger_cmd_off", $triggercmdoff );
        readingsEndUpdate( $hash, 0 );
        return if $hash->{INIT} ne 'define';
        my $definition = $hash->{DEF};
        $definition =~ s/\n/#[nl]/g;
        $definition =~ m/(\(.+?\))(.*)/;
        my $part1      = $1;
        my $part2      = $2;
        my $device     = ReadingsVal( $name, '.Trigger_device', '' );
        my $newtrigger = "([" . $device . ":" . $args[3] . "])" . $part2;
        $newtrigger =~ s/#\[nl\]/\n/g;
        $hash->{DEF} = $newtrigger;
        fhem( "modify $name " . $newtrigger );
        return;
	}
	
################################
sub MSwitch_Set_OnOff($@)  
	{	
	my ( $ic,$showevents,$devicemode,$delaymode,$hash, $name, $cmd, @args ) = @_;
	readingsSingleUpdate( $hash, "state", $cmd, 1 );
	
	
	delete $hash->{helper}{evtparts};
	delete $hash->{helper}{evtparts}{event};
	delete $hash->{helper}{aktevent};
	
	MSwitch_Readings($hash,$name);
    if ( $devicemode eq "Dummy" && AttrVal( $name, "MSwitch_Selftrigger_always", 0 ) eq "0" )
        {
            return;
        }
	MSwitch_Exec_Notif( $hash, $cmd, 'nocheck', '', 0 );
	return;	
	}
	
################################	

sub MSwitch_Set_Devices($@)  
	{	
	my ( $hash, $name, $cmd, @args ) = @_;
		MSwitch_Make_Undo($hash);
        delete( $hash->{helper}{config} );

        # setze devices
        my $devices = $args[0];
        if ( $devices eq 'null' ) {
            readingsSingleUpdate( $hash, ".Device_Affected", 'no_device', 0 );
            return;
        }
        my @olddevices = split( /,/, ReadingsVal( $name, '.Device_Affected', 'no_device' ) );
        my @devices = split( /,/, $args[0] );
        my $addolddevice = '';
        foreach (@devices) 
		{
          my $testdev = $_;
          LOOP6: foreach my $olddev (@olddevices)
			{
                my $oldcmd  = '';
                my $oldname = '';
                ( $oldname, $oldcmd ) = split( /-AbsCmd/, $olddev );
                if ( !defined $oldcmd ) { $oldcmd = '' }
                if ( $oldcmd eq '1' )   { next LOOP6 }
                if ( $oldname eq $testdev ) 
				{
                    $addolddevice = $addolddevice . $olddev . ',';
                }
            }
            $_ = $_ . '-AbsCmd1';
        }
        chop($addolddevice);
        $devices = join( ',', @devices ) . ',' . $addolddevice;
        my @sortdevices = split( /,/, $devices );
        @sortdevices = sort @sortdevices;
        $devices = join( ',', @sortdevices );
        readingsSingleUpdate( $hash, ".Device_Affected", $devices, 0 );
        $devices = MSwitch_makeAffected($hash);

        if ( defined $hash->{DEF} ) {
            my $devhash = $hash->{DEF};
            my @dev = split( /#/, $devhash );
            $hash->{DEF} = $dev[0] . ' # ' . $devices;
        }
        else {
            $hash->{DEF} = ' # ' . $devices;
        }
		MSwitch_Set_DetailsBlanko($hash,$name);
        return;
	}
###############################
sub MSwitch_Set_DetailsBlanko($$)  
	{
	my $blankoinhalt="no_action#[NF]no_action#[NF]#[NF]#[NF]delay1#[NF]delay1#[NF]#[NF]#[NF]#[NF]#[NF]#[NF]#[NF]1#[NF]0#[NF]#[NF]0#[NF]0#[NF]1#[NF]0#[NF]0";	
	my ( $hash, $name) = @_;
	my @devices = split( /,/, ReadingsVal( $name, '.Device_Affected', '' ) );
	my @bestand   = split( /#\[ND\]/, ReadingsVal( $name, '.Device_Affected_Details' ,''));
	my %bestandshash ;
	foreach my $bestandsdevice (@bestand) 
	{
		my @bestandsparts = split( /#\[NF\]/, $bestandsdevice,2 );
		$bestandshash{$bestandsparts[0]} = $bestandsparts[1];
	}
	my $inhalt;
	my @newdevices;
	foreach my $bestandsdevice (@devices) 
	{
		my $newdevice;
		$inhalt =  $bestandshash{$bestandsdevice};
		if(!defined $inhalt || $inhalt eq "")
		{
			$bestandshash{$bestandsdevice} = $blankoinhalt;
			$newdevice = $bestandsdevice."#[NF]".$blankoinhalt;
		}
		else
		{
			$newdevice = $bestandsdevice."#[NF]".$inhalt;
		}
		push(@newdevices,$newdevice);
	}
	my $finalfile = join("#[ND]",@newdevices);
	readingsSingleUpdate( $hash, ".Device_Affected_Details", $finalfile,0 );
	return;
	}
################################
sub MSwitch_Set_Details($@)  
	{
		my ( $hash, $name, $cmd, @args ) = @_;
		MSwitch_Make_Undo($hash);
        delete( $hash->{helper}{config} );
        # setze devices details
        $args[0] = urlDecode( $args[0] );
        $args[0] =~ s/#\[pr\]/%/g;

        #devicehasch
        my %devhash = split( /#\[DN\]/, $args[0] );
        my @devices = split( /,/, ReadingsVal( $name, '.Device_Affected', '' ) );
        my @inputcmds   = split( /#\[ND\]/, $args[0] );
        my $error       = '';
        my $key         = '';
        my $savedetails = '';
        my $devicecmd   = '';
		LOOP10: foreach (@devices) {
            my @devicecmds = split( /#\[NF\]/, $devhash{$_} );
            if ( $_ eq "FreeCmd-AbsCmd1" ) {
                $devicecmd = $devicecmds[2];
            }
            $savedetails = $savedetails . $_ . '#[NF]';
            $savedetails = $savedetails . $devicecmds[0] . '#[NF]';
            $savedetails = $savedetails . $devicecmds[1] . '#[NF]';
            $savedetails = $savedetails . $devicecmds[2] . '#[NF]';
            $savedetails = $savedetails . $devicecmds[3] . '#[NF]';
            $savedetails = $savedetails . $devicecmds[4] . '#[NF]';
            $savedetails = $savedetails . $devicecmds[5] . '#[NF]';
            $savedetails = $savedetails . $devicecmds[7] . '#[NF]';
            $savedetails = $savedetails . $devicecmds[6] . '#[NF]';

            if ( defined $devicecmds[8] ) {
                $savedetails = $savedetails . $devicecmds[8] . '#[NF]';
            }
            else {
                $savedetails = $savedetails . '' . '#[NF]';
            }

            if ( defined $devicecmds[9] ) {
                $savedetails = $savedetails . $devicecmds[9] . '#[NF]';
            }
            else {
                $savedetails = $savedetails . '' . '#[NF]';
            }

            if ( defined $devicecmds[10] ) {
                $savedetails = $savedetails . $devicecmds[10] . '#[NF]';
            }
            else {
                $savedetails = $savedetails . '' . '#[NF]';
            }

            if ( defined $devicecmds[11] ) {
                $savedetails = $savedetails . $devicecmds[11] . '#[NF]';
            }
            else {
                $savedetails = $savedetails . '' . '#[NF]';
            }

            # priority
            if ( defined $devicecmds[12] && $devicecmds[12] ne 'undefined' ) {
                $savedetails = $savedetails . $devicecmds[12] . '#[NF]';
            }
            else {
                $savedetails = $savedetails . '1' . '#[NF]';
            }

            # id
            if ( defined $devicecmds[13] && $devicecmds[13] ne 'undefined' ) {
                $savedetails = $savedetails . $devicecmds[13] . '#[NF]';
            }
            else {
                $savedetails = $savedetails . '0' . '#[NF]';
            }

            # comment
            if ( defined $devicecmds[14] && $devicecmds[14] ne 'undefined' ) {
                $savedetails = $savedetails . $devicecmds[14] . '#[NF]';
            }
            else {
                $savedetails = $savedetails . '' . '#[NF]';
            }

            # exit1
            if ( defined $devicecmds[15] && $devicecmds[15] ne 'undefined' ) {
                $savedetails = $savedetails . $devicecmds[15] . '#[NF]';
            }
            else {
                $savedetails = $savedetails . '0' . '#[NF]';
            }

            # exit2
            if ( defined $devicecmds[16] && $devicecmds[16] ne 'undefined' ) {
                $savedetails = $savedetails . $devicecmds[16] . '#[NF]';
            }
            else {
                $savedetails = $savedetails . '0' . '#[NF]';
            }

            # show
            if ( defined $devicecmds[17] && $devicecmds[17] ne 'undefined' ) {
                $savedetails = $savedetails . $devicecmds[17] . '#[NF]';
            }
            else {
                $savedetails = $savedetails . '1' . '#[NF]';
            }

            # show
            if ( defined $devicecmds[18] && $devicecmds[18] ne 'undefined' ) {
                $savedetails = $savedetails . $devicecmds[18] . '#[NF]';
            }
            else {
                $savedetails = $savedetails . '0' . '#[NF]';
            }


             #repeatcondition
             if ( defined $devicecmds[19] && $devicecmds[19] ne 'undefined' ) {
                 $savedetails = $savedetails . $devicecmds[19] . '#[ND]';
             }
             else {
                 $savedetails = $savedetails . '0' . '#[ND]';
             }


            # $counter++;
        }
        chop($savedetails);
        chop($savedetails);
        chop($savedetails);
        chop($savedetails);
        chop($savedetails);

        # ersetzung sonderzeichen etc mscode
        # auskommentierte wurden bereits dur jscript ersetzt

        $savedetails =~ s/\n/#[nl]/g;
        $savedetails =~ s/\t/    /g;
        $savedetails =~ s/ /#[sp]/g;
        $savedetails =~ s/\\/#[bs]/g;
        $savedetails =~ s/,/#[ko]/g;
        $savedetails =~ s/^#\[/#[eo]/g;
        $savedetails =~ s/^#\]/#[ec]/g;
        $savedetails =~ s/\|/#[wa]/g;
        $savedetails =~ s/\|/#[ti]/g;
        readingsSingleUpdate( $hash, ".Device_Affected_Details", $savedetails,0 );

        return if $hash->{INIT} ne 'define';
        my $definition = $hash->{DEF};
        $definition =~ m/(\(.+?\))(.*)/;
        my $part1 = $1;
        my $part2 = $2;

        $devicecmd =~ s/#\[sp\]/ /g;
        $devicecmd =~ s/#\[nl\]/\\n/g;
        $devicecmd =~ s/#\[se\]/;/g;
        $devicecmd =~ s/#\[dp\]/:/g;
        $devicecmd =~ s/#\[st\]/\\'/g;
        $devicecmd =~ s/#\[dst\]/\"/g;
        $devicecmd =~ s/#\[tab\]/    /g;
        $devicecmd =~ s/#\[ko\]/,/g;
        $devicecmd =~ s/#\[wa\]/|/g;
        $devicecmd =~ s/#\[bs\]/\\\\/g;
        my $newdef = $part1 . " ($devicecmd)";
 
        $hash->{DEF} = $newdef;
        fhem( "modify $name " . $newdef );
        return;
	}		
################################
sub MSwitch_Set($@) {
    my ( $hash, $name, $cmd, @args ) = @_;
    my $dynlist = "";
	my $special = '';
	my $setwidget ="";

	return "" if ( IsDisabled($name) && ( $cmd eq 'on' || $cmd eq 'off' ) );    # Return without any further action if the module is disabled

#################################
if ( $cmd ne "?" && $cmd ne "clearlog" && $cmd ne "writelog") 
	{
		MSwitch_LOG( $name, 6,"\n### SUB_Set ###");
        MSwitch_LOG( $name, 6,"eingehender Setbefehl: $cmd @args ");
    }
	
my $ic = 'leer';
$ic = $hash->{IncommingHandle} if ( $hash->{IncommingHandle} );
	
# on/off übergabe mit parametern

if ((($cmd eq 'on' )||($cmd eq 'off'))&&(defined $args[0] && $args[0] ne '')&&($ic ne 'fromnotify' ))
    {
		readingsSingleUpdate( $hash, "Parameter", $args[0], 1 );
		$args[0] = "$name:".$cmd."_with_Parameter:$args[0]";
    }
	
MSwitch_del_savedcmds($hash);  # prüfen lösche saveddevicecmd

$hash->{eventsave} = 'unsaved';

my $showevents = AttrVal( $name, "MSwitch_generate_Events", 0 );
if (AttrVal( $name, 'MSwitch_Debug', '0' ) ne "0" ){$showevents = 1};

my $devicemode = AttrVal( $name, 'MSwitch_Mode',            'Notify' );
my $delaymode  = AttrVal( $name, 'MSwitch_Delete_Delays',   '0' );

# randomnunner erzeugen wenn attr an
if ( AttrVal( $name, 'MSwitch_RandomNumber', '' ) ne '' ) {MSwitch_Createnumber1($hash);}
######################## TEST-1/$MSTEST1/g

 




#################################
#Systembefehle

if ( $cmd eq 'writelog') 				{MSwitch_Set_Writelog($hash, $name, $cmd, @args);return;}
if ( $cmd eq 'timer' ) 					{MSwitch_Set_timer($hash, $name, $cmd, @args);return;}	
if ( $cmd eq 'showgroup')				{MSwitch_makegroupcmdout( $hash, $args[0]);return;}
if ( $cmd eq 'undo') 					{MSwitch_Set_Undo($hash, $name, $cmd, @args);return;}
if ( $cmd eq 'savetemplate')			{MSwitch_savetemplate( $hash, $args[0], $args[1] );return;}
if ( $cmd eq 'template')				{my $ret = MSwitch_gettemplate( $hash, $args[0] );return $ret;}
if ( $cmd eq 'reset_Switching_once') 	{MSwitch_Set_switching_once( $hash, $args[0], $args[1] );return;}
if ( $cmd eq 'groupreload') 			{my $ret = MSwitch_reloaddevices( $hash, $args[0] );return $ret;}
if ( $cmd eq 'whitelist') 				{my $ret = MSwitch_whitelist( $hash, $args[0] );return $ret;}
if ( $cmd eq 'loadpreconf')				{my $ret = MSwitch_loadpreconf($hash);return $ret;}
if ( $cmd eq 'loadnotify') 				{my $ret = MSwitch_loadnotify( $hash, $args[0] );return $ret;}
if ( $cmd eq 'loadat') 					{my $ret = MSwitch_loadat( $hash, $args[0] );return $ret;}
if ( $cmd eq 'clearlog') 				{MSwitch_clearlog($hash);return;}
if ( $cmd eq 'setbridge') 				{MSwitch_setbridge( $hash, $args[0] );return;}
if ( $cmd eq 'logging' ) 				{MSwitch_Set_loggingwebjs( $hash, $args[0] );return;}
if ( $cmd eq 'reset_device') 			{MSwitch_Set_ResetDevice( $hash, $name, $cmd, @args );return;}
if ( $cmd eq 'loadHTTP')				{MSwitch_PerformHttpRequest( $hash, $args[0] );return;}
if ( $cmd eq 'inactive') 				{readingsSingleUpdate( $hash, "state", 'inactive', 1 );return;}
if ( $cmd eq 'active')					{readingsSingleUpdate( $hash, "state", 'active', 1 );return;}
if ( $cmd eq 'Writesequenz' )			{MSwitch_Writesequenz($hash);return;}
if ( $cmd eq 'VUpdate') 				{MSwitch_VersionUpdate($hash);return;}
if ( $cmd eq 'confchange') 				{MSwitch_confchange( $hash, $args[0] );return;}
if ( $cmd eq 'deletesinglelog') 		{my $ret = MSwitch_delete_singlelog( $hash, $args[0] );return;}
if ( $cmd eq 'wait') 					{readingsSingleUpdate( $hash, "waiting", ( time + $args[0] ),$showevents );return;}
if ( $cmd eq 'sort_device') 			{readingsSingleUpdate( $hash, ".sortby", $args[0], 0 );return;}
if ( $cmd eq 'fakeevent') 				{MSwitch_Check_Event( $hash, $args[0] );return;}
if ( $cmd eq "set_trigger") 			{MSwitch_Set_SetTrigger($hash, $name, $cmd, @args);return;}
if ( $cmd eq "trigger" ) 				{MSwitch_Set_SetTrigger1($hash, $name, $cmd, @args);return;}
if ( $cmd eq "devices" ) 				{MSwitch_Set_Devices($hash, $name, $cmd, @args);return;}
if ( $cmd eq "details" ) 				{MSwitch_Set_Details($hash, $name, $cmd, @args);return;}
if ( $cmd eq "off" || $cmd eq "on" ) 	{MSwitch_Set_OnOff($ic,$showevents,$devicemode,$delaymode,$hash, $name, $cmd, @args);return;}
if ( $cmd eq 'reset_cmd_count' ) 		{MSwitch_Set_ResetCmdCount($hash, $name, $cmd, @args);return;}
if ( $cmd eq 'reload_timer' ) 			{MSwitch_Set_ReloadTimer($hash, $name, $cmd, @args);return;}
if ( $cmd eq 'wizard' ) 				{MSwitch_Set_Wizard($hash, $name, $cmd, @args);return;}
if ( $cmd eq 'change_renamed' ) 		{MSwitch_Set_ChangeRenamed($hash, $name, $cmd, @args);return;}
if ( $cmd eq 'exec_cmd_1' ) 			{MSwitch_Set_ExecCmd($hash, $name, $cmd, @args);return;}
if ( $cmd eq 'exec_cmd_2' ) 			{MSwitch_Set_ExecCmd($hash, $name, $cmd, @args);return;}
if ( $cmd eq 'addevent' ) 				{MSwitch_Set_AddEvent($hash, $name, $cmd, @args);return;}
if ( $cmd eq 'del_repeats' ) 			{MSwitch_Set_DelRepeats($hash, $name, $cmd, @args);return;}
if ( $cmd eq 'del_delays' ) 			{MSwitch_Set_DelDelays($hash, $name, $cmd, @args);return;}



if ( $cmd eq 'backup_MSwitch' ) 
	{
		if ($args[0] eq "this_device"){MSwitch_backup_this($hash);}
		if ($args[0] eq "all_devices"){MSwitch_backup_all($hash);}
		return;
	}


if ( $cmd eq 'saveconfig' ) 
	{
        # configfile speichern
        $args[0] =~ s/\[s\]/ /g;
        MSwitch_saveconf( $hash, $args[0] );
        return;
    }
##
if ( $cmd eq 'savesys' ) 
	{
        # sysfile speichern
        MSwitch_savesys( $hash, $args[0] );
		MSwitch_defineWidgets($hash)	;
        return;
    }
##
if ( $cmd eq "delcmds" ) 
	{
        delete $data{MSwitch}{devicecmds1};
        delete $data{MSwitch}{last_devicecmd_save};
        return;
    }
##
if ( $cmd eq "del_function_data" ) 
	{
        delete( $hash->{helper}{eventhistory} );
        fhem("deletereading $name DIFFERENCE");
        fhem("deletereading $name TENDENCY");
        fhem("deletereading $name AVERAGE");
        return;
    }

##
if ( $cmd eq "add_device" ) 
	{
		MSwitch_Make_Undo($hash);
		delete( $hash->{helper}{config} );
        MSwitch_Add_Device( $hash, $args[0] );
        return;
    }
##
if ( $cmd eq "del_device" )
	{
		MSwitch_Make_Undo($hash);
		MSwitch_Del_Device( $hash, $args[0] );
		return;
    }
##
if ( $cmd eq "del_trigger" )
	{
		MSwitch_Make_Undo($hash);
		MSwitch_Delete_Triggermemory($hash);
		return;
	}
##
# if ( $cmd eq "filter_trigger" )
	# {
		# MSwitch_Make_Undo($hash);
        # MSwitch_Filter_Trigger($hash);
        # return;
    # }

##########################
# einlesen der genutzten Mswitch_widgets
if ( AttrVal( $name, 'MSwitch_SysExtension', "0" ) ne "0")
	{
	foreach my $a ( keys %{$data{MSwitch}{$name}{activeWidgets}} ) 
		{
		my $checkreading = $data{MSwitch}{Widget}{$a}{reading};
		if ($checkreading eq $cmd)
			{
			readingsSingleUpdate( $hash, $cmd, "@args", 1 );
			return;
			}
        }	
	# checkaktiv widgets und erstelle set für reading 	
	foreach my $a ( keys %{$data{MSwitch}{$name}{activeWidgets}} ) 
			{
				$setwidget.=$data{MSwitch}{Widget}{$a}{reading}." ";		
            }
	chop $setwidget;
    }
	
##########################
# einlesen MSwitch dyn setlist
# mswitch dyn setlist
my $mswitchsetlist = AttrVal( $name, 'MSwitch_setList', "undef" );
my @arraydynsetlist;
my @arraydynreadinglist;
my $dynsetlist = "";
if ( $mswitchsetlist ne "undef" ) 
	{
        my @dynsetlist = split( / /, $mswitchsetlist );
        foreach my $test (@dynsetlist) 
		{
            if ( $test =~ m/(.*)\[(.*)\]:?(.*)/ ) 
			{
                my @found_devices = devspec2array($2);
                my $s1            = $1;
                my $s2            = $2;
                my $s3            = $3;
                if ( $s1 ne "" && $1 =~ m/.*:/ ) 
				{
                    my $reading = $s1;
                    chop($reading);
                    push @arraydynsetlist, $reading;
                    $dynlist = join( ',', @found_devices );
                    $dynsetlist = $dynsetlist . $reading . ":" . $dynlist . " ";
                }

                if ( $s3 ne "" ) 
				{
                    my $sets            = $s3;
                    my @test            = split( /,/, $sets );
                    my $namezusatzback  = $sets;
                    my $namezusatzfront = $s1;
                    foreach my $test1 (@found_devices) 
					{
                        if ( $sets eq "Arg" ) 
						{
                            push @arraydynsetlist, $test1;
                        }
                        else 
						{
                            # nothing
                        }
                        push @arraydynsetlist, $test1 . ":" . $sets;
                    }
					@arraydynreadinglist = @found_devices;
                    $dynsetlist = join( ' ', @arraydynsetlist );
                }
            }
            else 
			{
                $dynsetlist = $dynsetlist . $test;
            }
        }

    }
	

my %setlist;
###########################
# nur bei funktionen in setlist !!!!
if ( AttrVal( $name, "MSwitch_Selftrigger_always", 0 ) eq "1" and $cmd ne "?" )
    {
        my $atts = AttrVal( $name, 'setList', "" );
        my @testarray = split( " ", $atts );
        
        foreach (@testarray)
		{
            my ( $arg1, $arg2 ) = split( ":", $_ );
            if ( !defined $arg2 or $arg2 eq "" ) { $arg2 = "noArg" }
            $setlist{$arg1} = $arg2;
        }

        foreach (@arraydynsetlist)
		{
            my ( $arg1, $arg2 ) = split( ":", $_ );
            if ( !defined $arg2 or $arg2 eq "" ) { $arg2 = "noArg" }
            $setlist{$arg1} = $arg2;
        }
		
		if (defined $setlist{$cmd})
		{
			
			if (!defined $args[0] || $args[0] eq "")
			{
				MSwitch_Check_Event( $hash, "MSwitch_Self:state:" . $cmd  );
			}
			else
			{
				MSwitch_Check_Event( $hash, "MSwitch_Self:" . $cmd . ":" . $args[0] );
			}
		}
    }
###########################
# setlist einlesen
if ( !defined $args[0] ) { $args[0] = ''; }
my $setList = AttrVal( $name, "setList", " " );
$setList =~ s/\n/ /g;

if (!exists( $sets{$cmd} ))
	{
        my @cList;
        # Overwrite %sets with setList
        my $atts = AttrVal( $name, 'setList', "" );
        my @testarray = split( " ", $atts );
        foreach (@testarray) 
		{
            my ( $arg1, $arg2 ) = split( ":", $_ );
            if ( !defined $arg2 or $arg2 eq "" ) { $arg2 = "noArg" }
            $setlist{$arg1} = $arg2;
        }
        foreach my $k ( sort keys %sets ) 
		{
            my $opts = undef;
            $opts = $sets{$k};
            $opts = $setlist{$k} if ( exists( $setlist{$k} ) );
            if ( defined($opts) ) 
			{
                push( @cList, $k . ':' . $opts );
            }
            else 
			{
                push( @cList, $k );
            }
        }    # end foreach
# unbekannt
        if ( ReadingsVal( $name, '.change', '' ) ne '' )
		{
            return "Unknown argument $cmd, choose one of " if ( $name eq "test" );
        }

# bearbeite setlist und readinglist
##############################
		if ( $cmd ne "?" ) 
			{
			my @sl       = split( " ", AttrVal( $name, "setList", "" ) );
			my $re       = qr/$cmd/;
			my @gefischt = grep( /$re/, @sl );
			if ( @sl && grep /$re/, @sl ) 
				{
					my @rl = split( " ", AttrVal( $name, "readingList", "" ) );
					if ( @rl && grep /$re/, @rl ) 
						{
							readingsSingleUpdate( $hash, $cmd, "@args", 1 );
						}
					else 
						{
							readingsSingleUpdate( $hash, "state", $cmd . " @args", 1 );
						}
					return;
					}
			@gefischt = grep( /$re/, @arraydynsetlist );
			if ( @arraydynsetlist && grep /$re/, @arraydynsetlist ) 
				{
					readingsSingleUpdate( $hash, $cmd, "@args", 1 );
					return;
				}

##############################
# dummy state setzen und exit
			if ( $devicemode eq "Dummy" ) 
				{
					if ( $cmd eq "on" || $cmd eq "off" ) 
						{
							readingsSingleUpdate( $hash, "state", $cmd . " @args", 1 );
							return;
						}
						else 
						{
							if ( AttrVal( $name, 'useSetExtensions', "0" ) eq '1' ) 
							{
								return SetExtensions( $hash, $setList, $name, $cmd, @args );
							}
							else 
							{
								return;
							}
						}
					}

#AUFRUF DEBUGFUNKTIONEN
			if ( AttrVal( $name, 'MSwitch_Debug', "0" ) eq '4' ) { MSwitch_Debug($hash);}
			delete( $hash->{IncommingHandle} );
			}

		#############################################
		if ( exists $hash->{helper}{config}&& $hash->{helper}{config} eq "no_config" )
		{
		# rückgabe für leeres/neues device
			return "Unknown argument $cmd, choose one of wizard:noArg";
		}
		
		if ( AttrVal( $name, 'MSwitch_Modul_Mode', "0" ) eq '1' )
		{
		# rückgabe modulmode - no sets
			return "Unknown argument $cmd, choose one of $dynsetlist $setList $setwidget";
		}

		if ( $devicemode eq "Notify" ) 
			{
			# rückgabe für Notifymode	
				return"Unknown argument $cmd, choose one of timer:on,off $dynsetlist writelog reset_Switching_once:noArg loadHTTP reset_device:noArg active:noArg inactive:noArg del_function_data:noArg del_delays backup_MSwitch:this_device,all_devices fakeevent exec_cmd_1 exec_cmd_2 wait reload_timer:noArg del_repeats:noArg change_renamed reset_cmd_count:1,2,all $setList $setwidget ";
			}
			elsif ( $devicemode eq "Toggle" )
			{
			# rückgabe für Togglemodemode	
				return "Unknown argument $cmd, choose one of timer:on,off $dynsetlist writelog reset_Switching_once:noArg reset_device:noArg active:noArg del_function_data:noArg inactive:noArg on off del_delays:noArg backup_MSwitch:this_device,all_devices fakeevent wait reload_timer:noArg del_repeats:noArg change_renamed $setList $setwidget ";
			}
		elsif ( $devicemode eq "Dummy" )
			{
			# rückgabe für Togglemodemode	
				if ( AttrVal( $name, 'useSetExtensions', "0" ) eq '1' )
				{
						return SetExtensions( $hash, $setList, $name, $cmd, @args );
				}
				else 
				{
					if ( AttrVal( $name, "MSwitch_Selftrigger_always", 0 ) eq "1" )
					{
						return "Unknown argument $cmd, choose one of timer:on,off $dynsetlist writelog reset_Switching_once:noArg loadHTTP del_repeats:noArg del_delays exec_cmd_1 exec_cmd_2 reset_device:noArg wait backup_MSwitch:this_device,all_devices $setList $special $setwidget";
					}
						else 
					{
						return "Unknown argument $cmd, choose one of $dynsetlist reset_device:noArg backup_MSwitch:this_device,all_devices $setList $special $setwidget";
					}
				}
			}
			else 
			{
			# rückgabe für Fullmode
					return "Unknown argument $cmd, choose one of timer:on,off $dynsetlist writelog reset_Switching_once:noArg loadHTTP del_repeats:noArg reset_device:noArg active:noArg del_function_data:noArg inactive:noArg on off  del_delays backup_MSwitch:this_device,all_devices fakeevent exec_cmd_1 exec_cmd_2 wait del_repeats:noArg reload_timer:noArg change_renamed reset_cmd_count:1,2,all $setList $special $setwidget";
			}
	}
	
### ende der sets prüfung	
##############################
return;
}

###################################

sub MSwitch_Cmd(@) {

    my ( $hash, @cmdpool ) = @_;
    my $Name = $hash->{NAME};
	my @timers=split/ /,$hash->{helper}{delaytimers};
	delete( $hash->{helper}{delaytimers}); 		  
    my $fullstring = join( '[|]', @cmdpool );
    if ( AttrVal( $Name, 'MSwitch_Switching_once', 0 ) == 1 && $fullstring eq $hash->{helper}{lastexecute} )
    {
        MSwitch_LOG( $Name, 6,"Ausführung Befehlsstapel abgebrochen, Stapel wurde bereits ausgeführt L:" . __LINE__ );
        MSwitch_LOG( $Name, 6, "(attr MSwitch_Switching_once gesetzt) L:" . __LINE__ );
        return;
    }

    my $lastdevice;
    my $showevents = AttrVal( $Name, "MSwitch_generate_Events", 0 );
	if (AttrVal( $Name, 'MSwitch_Debug', '0' ) ne "0" ){$showevents = 1};
    my %devicedetails = MSwitch_makeCmdHash($Name);

    foreach my $cmds (@cmdpool) 
	{
        MSwitch_LOG( $Name, 6, "cmds: $cmds L:" . __LINE__ );
		if ( $cmds =~ m/\[TIMER\].*/ )
		{
                MSwitch_LOG( $Name, 6, "Timerhandling: $cmds" . __LINE__ );
                $cmds =~ m/\[NUMBER(.*?)](.*)/;
                my $number = $1;
                my $string = $2;
				$string =~ s/#\[MSNL\]/\n/g;
                MSwitch_LOG( $Name, 5,"extrahierte Nummer: $number L:" . __LINE__ );
                MSwitch_LOG( $Name, 5, "extrahierte String: $string L:" . __LINE__ );
                my $timecondition = $timers[$number];
                MSwitch_LOG( $Name, 5,"extrahierte Timecondition: $timecondition L:" . __LINE__ );
                $string =~ s/TIMECOND/$timecondition/g;
                MSwitch_LOG( $Name, 6, "setze Timer: $string L:" . __LINE__ );      
                $hash->{helper}{delays}{$string} = $timecondition;
                InternalTimer( $timecondition, "MSwitch_Restartcmd", $string );
                next;
            }

        my @cut = split( /\|/, $cmds );
        $cmds = $cut[0];

        #ersetze platzhakter vor ausführung
        my $device = $cut[1];
		my $zweig= $cut[2];
		
        $lastdevice = $device;
        my $toggle = '';
        if ( $cmds =~ m/set (.*)(MSwitchtoggle)(.*)/ ) {
            $toggle = $cmds;
            $cmds = MSwitch_toggle( $hash, $cmds );
        }

        if ( AttrVal( $Name, 'MSwitch_Expert', "0" ) eq '1' && $devicedetails{ $device . '_repeatcount' } ne '' )
        {
            my $x = 0;
            while ( $devicedetails{ $device . '_repeatcount' } =~ m/\[(.*)\:(.*)\]/ )
            {
                $x++;    # exit
                last if $x > 20;    # exitg
                my $setmagic = ReadingsVal( $1, $2, 0 );
                $devicedetails{ $device . '_repeatcount' } = $setmagic;
            }
        }

        if ( AttrVal( $Name, 'MSwitch_Expert', "0" ) eq '1'&& $devicedetails{ $device . '_repeattime' } ne '' )
        {
            my $x = 0;
            while ( $devicedetails{ $device . '_repeattime' } =~ m/\[(.*)\:(.*)\]/ )
            {
                $x++;    # exit
                last if $x > 20;    # exitg
                my $setmagic = ReadingsVal( $1, $2, 0 );
                $devicedetails{ $device . '_repeattime' } = $setmagic;
            }
        }

        if (   AttrVal( $Name, 'MSwitch_Expert', "0" ) eq '1'&& $devicedetails{ $device . '_repeatcount' } > 0 && $devicedetails{ $device . '_repeattime' } > 0 )
        {
            my $i;
            for ($i = 1 ;$i <= $devicedetails{ $device . '_repeatcount' } ;$i++)
            {
                my $msg = $cmds . "|" . $Name;
                if ( $toggle ne '' ) 
				{ 
				$msg = $toggle . "|" . $Name;
                }
                my $timecond = gettimeofday() +( ( $i + 1 ) * $devicedetails{ $device . '_repeattime' } );
				$msg = $msg . "|" . $timecond. "|" .$device. "|" .$zweig;
                $hash->{helper}{repeats}{$timecond} = "$msg";
                MSwitch_LOG( $Name, 6, "setze Wiederholungen L:" . __LINE__ );
                InternalTimer( $timecond, "MSwitch_repeat", $msg );
            }
        }

        my $todec = $cmds;
        $cmds = MSwitch_dec( $hash, $todec );

############################
        # debug2 mode , kein execute
        if ( AttrVal( $Name, 'MSwitch_Debug', "0" ) eq '2' )
		{
            MSwitch_LOG( $Name, 6,"ausgeführter Befehl:\n $cmds \nL:" . __LINE__ );
        }
        else 
		{
            if ( $cmds =~ m/(\{)(.*)(\})/ )
			{

                $cmds =~ s/\[SR\]/\|/g;
                MSwitch_LOG( $Name, 6,"ausgeführter Befehl auf Perlebene:\n $cmds L:" . __LINE__ );
               my $out;
				{
				no warnings;
				$out = eval($cmds);
                if ($@) 
				{
                    MSwitch_LOG( $Name, 0,"MSwitch_Set: ERROR $cmds: $@ " . __LINE__ );
					
					
                }
				}
				
            }
            else 
			{
                MSwitch_LOG( $Name, 6,"ausgeführter Befehl auf Fhemebene:\n $cmds \nL:". __LINE__ );
                my $errors = AnalyzeCommandChain( undef, $cmds );
                if ( defined($errors) and $errors ne "OK" )
				{
                    MSwitch_LOG( $Name, 1,"MSwitch_Set: ERROR $cmds: $errors " . __LINE__ );
                }
            }
			
			
        }
#############################
    }
    my $showpool = join( ',', @cmdpool );

    if ( length($showpool) > 100 ) {
        $showpool = substr( $showpool, 0, 100 ) . '....';
    }
    readingsSingleUpdate( $hash, "last_exec_cmd", $showpool, $showevents ) if $showpool ne '';
    if ( AttrVal( $Name, 'MSwitch_Expert', '0' ) eq "1" ) 
	{
        readingsSingleUpdate( $hash, "last_cmd",
        $hash->{helper}{priorityids}{$lastdevice}, 0 ) if defined $lastdevice;
    }

    $hash->{helper}{lastexecute} = $fullstring;
    return;
}
####################
sub MSwitch_toggle($$) {

    my @cmds;
    my $anzcmds;
    my @muster;
    my $anzmuster;
    my $reading = 'state';
    my ( $hash, $cmds ) = @_;
    my $Name = $hash->{NAME};
	my $showevents = AttrVal( $Name, "MSwitch_generate_Events", 0 );
	if (AttrVal( $Name, 'MSwitch_Debug', '0' ) ne "0" ){$showevents = 1};
    MSwitch_LOG( $Name, 6, "ausführung Toggle L:" . __LINE__ );

	$cmds=~ s/#\[SR\]/|/g;
    $cmds =~ m/(set) (.*)( )MSwitchtoggle (.*)/;
	
	my $devicename = $2;
    my $newcomand = $1 . " " . $2 . " ";
	
	MSwitch_LOG( $Name, 6, "1 $1 L:" . __LINE__ );
	MSwitch_LOG( $Name, 6, "cmds $cmds L:" . __LINE__ );
	
	if ($2 eq "MSwitch_Self")
	{
	$newcomand = $1 . " " . $Name . " ";
	$devicename = $Name;
	}
	
    my @togglepart = split( /:/, $4 );
	MSwitch_LOG( $Name, 6, "Toggleparts @togglepart!!! L:" . __LINE__ );
	my $trenner=",";
	
	if ($togglepart[0] =~ m/^\[(.)\]/)
	{
		if ($togglepart[0] =~ m/^\[\|\]/){
		$togglepart[0]="\\|";	
		}
		$trenner = $togglepart[0];
		$trenner =~ s/\[//g;
		$trenner =~ s/\]//g;
		MSwitch_LOG( $Name, 6, "Trennercheck $togglepart[0]!!! L:" . __LINE__ );
		shift @togglepart;
	}
	
    if ( $togglepart[0] ) {
        $togglepart[0] =~ s/\[//g;
        $togglepart[0] =~ s/\]//g;
        @cmds = split( /$trenner/, $togglepart[0] );
        $anzcmds = @cmds;
    }

    if ( $togglepart[1] ) {
        $togglepart[1] =~ s/\[//g;
        $togglepart[1] =~ s/\]//g;
        @muster = split( /$trenner/, $togglepart[1] );
		MSwitch_LOG( $Name, 6, "cmds @cmds!!! L:" . __LINE__ );		
        $anzmuster = @cmds;
    }
    else 
	{
        @muster    = @cmds;
        $anzmuster = $anzcmds;
    }
    if ( $togglepart[2] ) {
        $togglepart[2] =~ s/\[//g;
        $togglepart[2] =~ s/\]//g;
        $reading = $togglepart[2];
    }
	my $aktstate;

	if ($reading eq "MSwitch_Self")
	{
		$aktstate = ReadingsVal( $Name, 'last_toggle_state', 'undef' );	
	} else {
		$aktstate = ReadingsVal( $devicename, $reading, 'undef' );	
	}

    my $foundmuster;
    for ( my $i = 0 ; $i < $anzmuster ; $i++ ) {
        if ( $muster[$i] eq $aktstate ) {
            $foundmuster = $i;
            last;
        }
    }

    my $nextpos = 0;
    if ( defined $cmds[ $foundmuster + 1 ] ) {
        $nextpos = $foundmuster + 1;
    }

    my $nextcmd = $cmds[$nextpos];
    $newcomand = $newcomand . $nextcmd;
	readingsSingleUpdate( $hash, "last_toggle_state", $nextcmd, $showevents );
    MSwitch_LOG( $Name, 6, "Toggle Rückgabe:\n $newcomand \nL:" . __LINE__ );
    return $newcomand;
}

######################################

sub MSwitch_Log_Event(@) {
    my ( $hash, $msg, $me ) = @_;
    my $Name          = $hash->{NAME};
    my $triggerdevice = ReadingsVal( $Name, '.Trigger_device', 'no_trigger' );
    my $re            = qr/$triggerdevice/;
    if ( $triggerdevice eq 'no_trigger' ) {
        delete( $hash->{helper}{writelog} );
        return;
    }

    if (   $triggerdevice ne 'Logfile'
        && $triggerdevice ne 'all_events'
        && ( $hash->{helper}{writelog} !~ /$re/ ) )
    {
        delete( $hash->{helper}{writelog} );
        return;
    }

    MSwitch_Check_Event( $hash, $hash );
    delete( $hash->{helper}{writelog} );
    return;
}

##############################

sub MSwitch_Attr(@) {
    my ( $cmd, $name, $aName, $aVal ) = @_;
    my $hash = $defs{$name};


### Debug
if (defined $aVal && $aVal ne "" && $aName eq 'MSwitch_Debug')
{
    if (( $aVal == 0 || $aVal == 1 || $aVal == 2 || $aVal == 3 ) )
    {
        delete( $hash->{READINGS}{Bulkfrom} );
        delete( $hash->{READINGS}{Device_Affected} );
        delete( $hash->{READINGS}{Device_Affected_Details} );
        delete( $hash->{READINGS}{Device_Events} );
    }
}

## RandomTime
    if ( $aName eq 'MSwitch_RandomTime' && $aVal ne '' ) {
        if ( $aVal !~
            m/([0-9]{2}:[0-9]{2}:[0-9]{2}-[0-9]{2}:[0-9]{2}:[0-9]{2})/ )
        {
            return 'wrong syntax !<br>the syntax must be: HH:MM:SS-HH:MM:SS';
        }
        else {
            $aVal =~ s/\://g;
            my @test = split( /-/, $aVal );
            if ( $test[0] >= $test[1] ) {
                return
                    'fist '
                  . $test[0]
                  . ' parameter must be lower than second parameter '
                  . $test[1];
            }
        }
        return;
    }


## ReadLog
    if ( $cmd eq "set" && $aName eq "MSwitch_Read_Log" ) {
        if ( defined($aVal) && $aVal eq "1" ) {
            $logInform{$name} = sub($$) {
                my ( $me, $msg ) = @_;
                return if ( defined( $hash->{helper}{writelog} ) );
                $hash->{helper}{writelog} = $msg;
                MSwitch_Log_Event( $hash, $msg, $me );
              }
        }
        else {
            delete( $hash->{helper}{writelog} );
            delete $logInform{$name};
        }
    }

## DeviceGroups
    if ( $cmd eq 'set' && $aName eq 'MSwitch_Device_Groups' ) 
	{
        delete $data{MSwitch}{$name}{groups};
        my @gset = split( /\n/, $aVal );

        foreach my $line (@gset) {
            my @lineset = split( /->/, $line );
            $data{MSwitch}{$name}{groups}{ $lineset[0] } = $lineset[1];
            #my @areadings = ( keys %{ $data{MSwitch}{$name}{groups} } );
        }
        return;
    }

    if ( $cmd eq 'del' && $aName eq 'MSwitch_Device_Groups' ) {
        delete $data{MSwitch}{$name}{groups};
        return;
    }


## Readings

	if ( $cmd eq 'set' && $aName eq 'MSwitch_Readings' ) 
	{
		delete $data{MSwitch}{$name}{Readings};
		my $readings = $aVal.",";
		$readings =~ s/\n//g;
		my $x          = 0; # exit
        while ( $readings =~ m/(.*?\})(,)(.*)/ )
		{
            $x++; 
			last if $x > 10;
			my $first = $1;
			$readings = $3;
			chop $first;
			my ($key,$inhalt)=split(/{/,$first);
			$key=~ s/ //g;
		#Log3("test",0,"key: $key");
		
			$data{MSwitch}{$name}{Readings}{$key}=$inhalt;

		}
		return;
	}
	
################################	
	
	if ( $cmd eq 'set' && $aName eq 'MSwitch_EventMap' ) 
	{
		delete $data{MSwitch}{$name}{Eventmap};
		my $evantmaps = $aVal;
		my $trenner =" ";
		# suche trennzeichen
		if ( $evantmaps =~ m/^([^a-zA_Z])(.*)/ )
		{
			$trenner = $1;
			$evantmaps = $2;
		}
		my @mappaare = split(/$trenner/,$evantmaps);
		for my $paar (@mappaare) 
		{
			my ($key,$inhalt)=split(/:/,$paar);
			$data{MSwitch}{$name}{Eventmap}{$key}=$inhalt;
		}
		return;
	}
	
###################################
	
## EventWait
    if ( $cmd eq 'set' && $aName eq 'MSwitch_Event_Wait' ) {

        delete $data{MSwitch}{$name}{eventwait};
        my @gset = split( /\n/, $aVal );
        foreach my $line (@gset)
		{
            my @lineset = split( /->/, $line );
            $data{MSwitch}{$name}{eventwait}{ $lineset[0] } = $lineset[1];
        }
        return;
    }

    if ( $cmd eq 'del' && $aName eq 'MSwitch_Event_Wait' ) {
        delete $data{MSwitch}{$name}{eventwait};
        return;
    }

## SysExtension
 if ( $cmd eq 'set' && $aName eq 'MSwitch_SysExtension' ) 
 {
	if ($aVal == 0 )
	{
		 delete $data{MSwitch}{$name}{activeWidgets};
	}
	if ($aVal == 1 || $aVal == 2 )
	{
		MSwitch_defineWidgets($hash);
	}
 }

## DeleteCMDs
    if ( $cmd eq 'set' && $aName eq 'MSwitch_DeleteCMDs' ) 
	{
        delete $data{MSwitch}{devicecmds1};
        delete $data{MSwitch}{last_devicecmd_save};
    }
	
## Snippet
	if ( $cmd eq 'set' && $aName eq 'MSwitch_Snippet' )
	{
		delete $data{MSwitch}{$name}{snippet};
		my @snips = split( /\n/, $aVal );
		my $aktsnippetnumber;
		my $aktsnippet ="";
		foreach my $line (@snips) 
		{
			if ( $line =~ m/^\[Snippet:([\d]{1,3})\]$/ ) 
				{
					$aktsnippet ="";
					$aktsnippetnumber =$1;
					MSwitch_LOG( $name, 6, "FOUND Snipnumber: $aktsnippetnumber " . __LINE__ );
					next;
				}
			MSwitch_LOG( $name, 6, "snipline: $line " . __LINE__ );
            $data{MSwitch}{$name}{snippet}{$aktsnippetnumber} .= $line."\n";
        }
		MSwitch_LOG( $name, 6, $data{MSwitch}{$name}{snippet}{1});
		MSwitch_LOG( $name, 6, $data{MSwitch}{$name}{snippet}{2});
		return;
    }
	
## Event Counter	
    if ( $cmd eq 'set' && $aName eq 'MSwitch_Reset_EVT_CMD1_COUNT' )
	{
        readingsSingleUpdate( $hash, "EVT_CMD1_COUNT", 0, 1 );
    }
    if ( $cmd eq 'set' && $aName eq 'MSwitch_Reset_EVT_CMD2_COUNT' )
	{
        readingsSingleUpdate( $hash, "EVT_CMD2_COUNT", 0, 1 );
    }

## disable
    if ( $cmd eq 'set' && $aName eq 'disable' && $aVal == 1 ) {
        $hash->{NOTIFYDEV} = 'no_trigger';
        MSwitch_Delete_Delay( $hash, 'all' );
        MSwitch_Clear_timer($hash);
    }

    if ( $cmd eq 'set' && $aName eq 'disable' && $aVal == 0 )
	{
        delete( $hash->{helper}{savemodeblock} );
        delete( $hash->{READINGS}{Safemode} );
        MSwitch_Createtimer($hash);

        if ( ReadingsVal( $name, '.Trigger_device', 'no_trigger' ) ne 'no_trigger'
            and ReadingsVal( $name, '.Trigger_device', 'no_trigger' ) ne
            "MSwitch_Self" )
        {
            $hash->{NOTIFYDEV} =
              ReadingsVal( $name, '.Trigger_device', 'no_trigger' );
        }

        if ( $init_done == 1
            and ReadingsVal( $name, '.Trigger_device', 'no_trigger' ) eq
            "MSwitch_Self" )
        {
            $hash->{NOTIFYDEV} = $name;
        }
    }

## Mswitch CMDs

    if ( $aName eq 'MSwitch_Activate_MSwitchcmds' && $aVal == 1 )
	{
        addToAttrList('MSwitchcmd');
    }

## Debug
    if ( defined $aVal && $aName eq 'MSwitch_Debug' && $aVal eq '0' )
	{
        unlink("./log/MSwitch_debug_$name.log");
    }


    if ( defined $aVal && ( $aName eq 'MSwitch_Debug' && ( $aVal eq '2' || $aVal eq '3' )))
    {
        MSwitch_clearlog($hash);
    }

## Inforoom
    if ( $cmd eq 'set' && $aName eq 'MSwitch_Inforoom' )
	{
        my $testarg = $aVal;
        foreach my $testdevices ( keys %{ $modules{MSwitch}{defptr} })
		{
            $attr{$testdevices}{MSwitch_Inforoom} = $testarg;
        }
    }

############ FULL / TOGGLE

    if ( $aName eq 'MSwitch_Mode' && ( $aVal eq 'Full' || $aVal eq 'Toggle' ) )
    {
        delete( $hash->{helper}{config} );
        my $cs = "setstate $name ???";
        my $errors = AnalyzeCommandChain( undef, $cs );
        $hash->{MODEL} = 'Full' . " " . $version   if $aVal eq 'Full';
        $hash->{MODEL} = 'Toggle' . " " . $version if $aVal eq 'Toggle';
        setDevAttrList( $name, $attrresetlist );
		if ($init_done) 
		{
		if (ReadingsVal( $name, '.Trigger_device', '' ) ne '' ){
				$hash->{NOTIFYDEV} = ReadingsVal( $name, '.Trigger_device', '' );
			}
			else{
				$hash->{NOTIFYDEV} = 'no_trigger';
			}
		}
    }

############ DUMMY ohne  Selftrigger

	if ($init_done &&  $aName eq 'MSwitch_Selftrigger_always' &&  AttrVal( $name, 'MSwitch_Mode', '' ) eq "Dummy" )
	{
		if ( $aVal eq '1' )
		{
			setDevAttrList( $name, $attractivedummy );
		}
		
		if ( $aVal eq '0' )
		{
		fhem( "deleteattr $name MSwitch_Include_Webcmds");
        fhem( "deleteattr $name MSwitch_Include_MSwitchcmds");
        fhem( "deleteattr $name MSwitch_Include_Devicecmds");
        fhem( "deleteattr $name MSwitch_Safemode");
        fhem( "deleteattr $name MSwitch_Extensions");
        fhem( "deleteattr $name MSwitch_Lock_Quickedit");
        fhem( "deleteattr $name MSwitch_Delete_Delays");
		fhem( "deleteattr $name MSwitch_Debug");
		fhem( "deleteattr $name MSwitch_Eventhistory");
		fhem( "deleteattr $name MSwitch_Expert");
		fhem( "deleteattr $name MSwitch_Ignore_Types");
		fhem( "deleteattr $name MSwitch_generate_Events");
		fhem( "deleteattr $name MSwitch_Help");
		
		delete( $hash->{eventsave} );
        delete( $hash->{NOTIFYDEV} );
        delete( $hash->{NTFY_ORDER} );
		
		my $delete =".Trigger_device";
        delete( $hash->{READINGS}{$delete} );
        delete( $hash->{IncommingHandle} );
        delete( $hash->{READINGS}{EVENT} );
        delete( $hash->{READINGS}{EVTFULL} );
        delete( $hash->{READINGS}{EVTPART1} );
        delete( $hash->{READINGS}{EVTPART2} );
        delete( $hash->{READINGS}{EVTPART3} );
     #   delete( $hash->{READINGS}{last_activation_by} );
        delete( $hash->{READINGS}{last_event} );
        delete( $hash->{READINGS}{last_exec_cmd} );
		delete( $hash->{READINGS}{last_cmd} );
		delete( $hash->{READINGS}{MSwitch_generate_Events} );
		setDevAttrList( $name, $attrdummy );
		}
	}

############ DUMMY ohne  Selftrigger
    if ( $aName eq 'MSwitch_Mode' && ( $aVal eq 'Dummy' ) )
	{
        delete( $hash->{helper}{config} );
        MSwitch_Delete_Delay( $hash, 'all' );
        MSwitch_Clear_timer($hash);
        #$hash->{NOTIFYDEV} 	= 'no_trigger';
        $hash->{MODEL}     	= 'Dummy' . " " . $version;
		$hash->{DEF}     	= $name;

		if ($init_done) 
		{
			fhem( "deleteattr $name MSwitch_Include_Webcmds");
			fhem( "deleteattr $name MSwitch_Include_MSwitchcmds");
			fhem( "deleteattr $name MSwitch_Include_Devicecmds");
			fhem( "deleteattr $name MSwitch_Safemode");
			fhem( "deleteattr $name MSwitch_Extensions");
			fhem( "deleteattr $name MSwitch_Lock_Quickedit");
			fhem( "deleteattr $name MSwitch_Delete_Delays");
			fhem( "deleteattr $name MSwitch_Debug");
			fhem( "deleteattr $name MSwitch_Eventhistory");
			fhem( "deleteattr $name MSwitch_Expert");
			fhem( "deleteattr $name MSwitch_Ignore_Types");
			fhem( "deleteattr $name MSwitch_generate_Events");
			fhem( "deleteattr $name MSwitch_Help");

			delete( $hash->{eventsave} );
			delete( $hash->{NOTIFYDEV} );
			delete( $hash->{NTFY_ORDER} );
			my $delete =".Trigger_device";
			delete( $hash->{READINGS}{$delete} );
			delete( $hash->{IncommingHandle} );
			delete( $hash->{READINGS}{EVENT} );
			delete( $hash->{READINGS}{EVTFULL} );
			delete( $hash->{READINGS}{EVTPART1} );
			delete( $hash->{READINGS}{EVTPART2} );
			delete( $hash->{READINGS}{EVTPART3} );
		#	delete( $hash->{READINGS}{last_activation_by} );
			delete( $hash->{READINGS}{last_event} );
			delete( $hash->{READINGS}{last_exec_cmd} );
			delete( $hash->{READINGS}{last_cmd} );
			delete( $hash->{READINGS}{MSwitch_generate_Events} );
			
			if ( AttrVal( $name, 'MSwitch_Selftrigger_always', '' ) eq "1" )
			{
				setDevAttrList( $name, $attractivedummy );
			}
			else
			{
				setDevAttrList( $name, $attrdummy );
			}
		}
	}
	
############### Notify
if ( $aName eq 'MSwitch_Mode' && $aVal eq 'Notify' ) 
		{
			$hash->{MODEL} = 'Notify' . " " . $version;
			my $cs = "setstate $name active";
			my $errors = AnalyzeCommandChain( undef, $cs );
			if ( defined($errors) ) {MSwitch_LOG( $name, 1,"$name MSwitch_Notify: Fehler bei Befehlsausführung $errors -> Comand: $_ ". __LINE__ );}
			setDevAttrList( $name, $attrresetlist );
			readingsSingleUpdate( $hash, "state", "active", 1 );
			$hash->{MODEL}     = 'Notify' . " " . $version;
			setDevAttrList( $name, $attrresetlist );
			if ($init_done) 
			{	
				if (ReadingsVal( $name, '.Trigger_device', '' ) ne '' )
				{
					$hash->{NOTIFYDEV} = ReadingsVal( $name, '.Trigger_device', '' );
				}
				else
				{
					$hash->{NOTIFYDEV} = 'no_trigger';
				}
			}
		}
		
		
## ATTR DELETE FUNKTOIONEN

	if ( $cmd eq 'del' ) 
	{
	my $testarg = $aName;
			if ( $testarg eq 'MSwitch_Readings' )
			{
				my $keyhash = $data{MSwitch}{$name}{Readings};
				foreach my $reading ( keys %{$keyhash} )
				{
					delete( $hash->{READINGS}{$reading} );
				}
				delete $data{MSwitch}{$name}{Readings};
			return;
			}
			
			
		
        if ( $testarg eq 'MSwitch_Inforoom' )
		{
          LOOP21:foreach my $testdevices ( keys %{ $modules{MSwitch}{defptr} } )
			{
                if ( $testdevices eq $name ) { next LOOP21; }
                delete( $attr{$testdevices}{MSwitch_Inforoom} );
            }
		return;
        }

        if ( $testarg eq 'disable' )
		{
            MSwitch_Delete_Delay( $hash, "all" );
            MSwitch_Clear_timer($hash);
            delete( $hash->{helper}{savemodeblock} );
            delete( $hash->{READINGS}{Safemode} );
			return;
        }

		if ( $testarg eq 'MSwitch_SysExtension' )
		{
            delete $data{MSwitch}{$name}{activeWidgets};
			return;
        }

        if ( $testarg eq 'MSwitch_Reset_EVT_CMD1_COUNT' )
		{
            delete( $hash->{READINGS}{EVT_CMD1_COUNT} );
			return;
        }

        if ( $testarg eq 'MSwitch_Reset_EVT_CMD2_COUNT' )
		{
            delete( $hash->{READINGS}{EVT_CMD2_COUNT} );
			return;
        }

        if ( $testarg eq 'MSwitch_DeleteCMDs' )
		{
            delete $data{MSwitch}{devicecmds1};
            delete $data{MSwitch}{last_devicecmd_save};
			return;
        }
    }

    return;
}

####################
sub MSwitch_Delete($$) {
    my ( $hash, $name ) = @_;
	MSwitch_Delete_Delay( $hash, $name );
	my $inhalt = $hash->{helper}{repeats};
        foreach my $a ( sort keys %{$inhalt} ) 
		{
            my $key = $hash->{helper}{repeats}{$a};
            RemoveInternalTimer($key);
        }
        delete( $hash->{helper}{repeats} );

    RemoveInternalTimer($hash);
	MSwitch_Clear_timer($hash);
    RemoveInternalTimer($hash);
    delete( $modules{MSwitch}{defptr}{$name} );
    return;
}
####################
sub MSwitch_Undef($$) {
	my ( $hash, $name ) = @_;
	MSwitch_Delete_Delay( $hash, $name );
	my $inhalt = $hash->{helper}{repeats};
        foreach my $a ( sort keys %{$inhalt} )
		{
            my $key = $hash->{helper}{repeats}{$a};
            RemoveInternalTimer($key);
        }
    delete( $hash->{helper}{repeats} );
	MSwitch_Clear_timer($hash);
    RemoveInternalTimer($hash);
    delete( $modules{MSwitch}{defptr}{$name} );
    return;
}
####################
sub MSwitch_Check_AVG($@)  
	{	
	my ( $hash, $name ) = @_;
	my @avg = split(/,/,AttrVal( $name, "MSwitch_Func_AVG", 'undef'));
	my $showevents = AttrVal( $name, "MSwitch_generate_Events", 0 );
	if (AttrVal( $name, 'MSwitch_Debug', '0' ) ne "0" ){$showevents = 1};
	AVG: foreach my $aktavg (@avg)
	{
		my ($aktname,$aktwert,$reading)=split(/->/,$aktavg);
		my $aktevent = $hash->{helper}{evtparts}{evtpart2};
		next AVG if $aktname ne $aktevent;
		my $history = $hash->{helper}{eventhistory}{$aktname};
		my @checkwert = split(/ /,$history);
		my $sum=0;
		for ( my $i = 0 ; $i < $aktwert ; $i++ )
		{
			if (!defined $checkwert[$i]){$checkwert[$i] = 0;}
			$sum=$sum+$checkwert[$i]
		}
		my $mittelwert = $sum/$aktwert;
		readingsSingleUpdate( $hash, $reading, $mittelwert, $showevents );
	}
	return;	
	}
#################################
sub MSwitch_Check_TEND($@)  
	{	
	my ( $hash, $name ) = @_;
	my @tend = split(/,/,AttrVal( $name, "MSwitch_Func_TEND", 'undef'));
	my $showevents = AttrVal( $name, "MSwitch_generate_Events", 0 );
	if (AttrVal( $name, 'MSwitch_Debug', '0' ) ne "0" ){$showevents = 1};
	TEND: foreach my $akttend (@tend)
	{
		my ($aktname,$aktwert,$alert,$reading,$maxcheck)=split(/->/,$akttend);
		if (!defined $maxcheck){$maxcheck = 0;}
		my $lastreading = ReadingsVal( $name, $reading.'_change', 'no_change' );
		my $aktevent = $hash->{helper}{evtparts}{evtpart2};
		next TEND if $aktname ne $aktevent;
		my $anzahl = $aktwert;    # anzahl der getesteten events aus historia
        my $anzahl1 = $aktwert * 2; # anzahl der getesteten events aus historia
		my $history = $hash->{helper}{eventhistory}{$aktname};
		my @checkwert = split(/ /,$history);
		next TEND if @checkwert < $anzahl1;
		my $wert1 = 0;
        my $wert2 = 0;
        my $count = 0;

        foreach (@checkwert)
			{
                last if $count >= $anzahl1;
                $wert1 = $wert1 + $_ if $count < $anzahl;
                $wert2 = $wert2 + $_ if $count >= $anzahl;
                $count++;
            }
			
		$wert1 = $wert1 / $anzahl;
		$wert2 = $wert2 / $anzahl;			
		my $tendenzwert = $wert1-$wert2;
		my $tendenzwertabsolut = abs( $tendenzwert);
		my $direction ="no_change";
		if ($tendenzwert < 0)
		{
			$direction ="down";
		}
		if ($tendenzwert > 0)
		{
			$direction ="up";
		}
		
		#############################################################
		#prüfe einzelwert
		if ( $tendenzwertabsolut >= $alert && $direction ne $lastreading)
		{
			# änderung erkannt
			readingsSingleUpdate( $hash, $reading.'_change', 'changed', $showevents ) ;
			readingsSingleUpdate( $hash, $reading.'_direction_tendenz', $direction, $showevents ) ;
			readingsSingleUpdate( $hash, $reading.'_direction_real', $direction, $showevents ) ;	
			readingsSingleUpdate( $hash, $reading.'_direction_value', $tendenzwert, $showevents ) ;
			# setze max/min wert auf aktuellen wert wenn geschaltet
			readingsSingleUpdate( $hash, ".".$reading.'_max', $wert1, 0 ) ;
			readingsSingleUpdate( $hash, ".".$reading.'_min', $wert1, 0 ) ;
			next TEND;
		}
		
			######################	
	# prüfe maximalwert 	
		if ($maxcheck > 0)
		{
			my $max =  ReadingsVal( $name, ".".$reading.'_max', 'undef' );
			my $min =  ReadingsVal( $name, ".".$reading.'_min', 'undef' );
			#init readings für max/min
			readingsSingleUpdate( $hash, ".".$reading.'_max', $wert1, 0 ) if $max eq "undef";
			readingsSingleUpdate( $hash, ".".$reading.'_min', $wert1, 0 ) if $min eq "undef";
			$max = $wert1  if $max eq "undef";
			$min = $wert1  if $min eq "undef";
			###
			if ($wert1 > $max){readingsSingleUpdate( $hash, ".".$reading.'_max', $wert1, 0 );}
			if ($wert1 < $min){readingsSingleUpdate( $hash, ".".$reading.'_min', $wert1, 0 );}
			
			# real fallend setze vergleichswert auf grössten realwert
			# real steigend setze vergleichswert auf kleinsten realwert
			# wenn überhaupt definiert
			# wert2 muss angepasst werden wenn .....
			
			if ($direction eq "down" )
			{
				$wert2 = $max if $max > $wert2;
			}
			if ($direction eq "up" )
			{
				$wert2 = $min if $min < $wert2;
			}
			$tendenzwert = $wert1-$wert2;
			$tendenzwertabsolut = abs( $tendenzwert);
			$direction ="no_change";
			if ($tendenzwert < 0)
				{
					$direction ="down";
				}
			if ($tendenzwert > 0)
				{
					$direction ="up";
				}
		
			if ( $tendenzwertabsolut >= $alert && $direction ne $lastreading)
			{
				# änderung erkannt
				readingsSingleUpdate( $hash, $reading.'_change', 'changed', $showevents ) ;
				readingsSingleUpdate( $hash, $reading.'_direction_tendenz', $direction, $showevents ) ;
				readingsSingleUpdate( $hash, $reading.'_direction_real', $direction, $showevents ) ;	
				readingsSingleUpdate( $hash, $reading.'_direction_value', $tendenzwert, $showevents ) ;
				# setze max/min wert auf aktuellen wert wenn geschaltet
				readingsSingleUpdate( $hash, ".".$reading.'_max', $wert1, 0 ) ;
				readingsSingleUpdate( $hash, ".".$reading.'_min', $wert1, 0 ) ;
				next TEND;
			}
		}
		
	########################	
		if ( $tendenzwertabsolut < $alert)
		{
			# keine änderung / kein alarm 
			readingsSingleUpdate( $hash, $reading.'_change', 'no_change', $showevents ) ;
			readingsSingleUpdate( $hash, $reading.'_direction_real', $direction, $showevents ) ;	
			readingsSingleUpdate( $hash, $reading.'_direction_value', $tendenzwert, $showevents ); 
		}
	}
	return;	
	}
###############################
sub MSwitch_Check_DIFF($@)  
	{	
	my ( $hash, $name ) = @_;
	my @diff = split(/,/,AttrVal( $name, "MSwitch_Func_DIFF", 'undef'));
	my $showevents = AttrVal( $name, "MSwitch_generate_Events", 0 );
	if (AttrVal( $name, 'MSwitch_Debug', '0' ) ne "0" ){$showevents = 1};
	DIFF: foreach my $aktavg (@diff)
	{
		my ($aktname,$aktwert,$reading)=split(/->/,$aktavg);
		my $aktevent = $hash->{helper}{evtparts}{evtpart2};
		next DIFF if $aktname ne $aktevent;
		my $vergloperand = $aktwert;
		my $history = $hash->{helper}{eventhistory}{$aktname};
		my @checkwert = split(/ /,$history);
        my $index   = $vergloperand ;
		next if !defined $checkwert[$index];
		my $diff =( $checkwert[0] - $checkwert[$index] );		
		readingsSingleUpdate( $hash, $reading, $diff, $showevents ) ;
	}
	return;	
	}
	
###############################









sub MSwitch_Initcheck() {
	
	# prüfe debug
	my $startmessage="";	
	my @debugging_devices = devspec2array("TYPE=MSwitch:FILTER=MSwitch_Debug=2||3");
	my @restore_devices = devspec2array("TYPE=MSwitch");
	
	$startmessage.="     -> Es sind ".@restore_devices." Mswitchdefinitionen vorhanden, teste Definitionen... \n";		
	#$startmessage.="     -> teste Definitionen ...\n";	
	
	
	if 	(@debugging_devices >0)
		{
			$startmessage.="!!!  -> Erhoehte Systembelastung festgestellt, folgende Geraete befinden sich im Debugmode 2 oder 3: \n";	
			for my $name (@debugging_devices) 
				{
					$startmessage.="     ->    $name \n";
				}
				$startmessage.="     -> Die empfohlene Einstellung im Normalbetrieb lautet MSwitch_Debug 0 oder 1  \n";	
			}
	$data{MSwitch}{warning}{debug}	="Debug_Warning";
	
	
	# prüfe backups
	
	my $nobackups=0;
	my $nobackupnames="";
	for my $restore (@restore_devices) 
	{
		
		my $pfad="./".$backupfile.$restore.".".$vupdate.".conf" ;
		my $devhash = $defs{$restore};
		if(-e $pfad)
		{
			#Log3("test",0,"-> vorhanden");
			# datei vorhanden
			$devhash->{Backup_avaible}            = $pfad;
		}
		else
		{
			$nobackups++;
			$nobackupnames.= "     ->    $restore\n";
			$devhash->{Backup_avaible}            = "not_avaible";
		}
	}
	if ($nobackups >0)
	{
	$startmessage.="!!!  -> fehlende Backupdateien fuer $nobackups Mswitchdefinitionen gefunden \n";		
	$startmessage.="     -> bei Deffekt oder Verlust der 'fhem.save' sind diese nicht wieder herzustellen \n";	
	$startmessage.="     -> eine Liste betroffener Geraete kann mit 'list TYPE=MSwitch:FILTER=Backup_avaible=not_avaible' angezeigt werden \n";	

	#$startmessage.=	$nobackupnames;
	}
	
	$startmessage.="     -> initializing MSwitch-Devices ready \n";	
	Log3("MSwitch",1,"Messages collected while initializing MSwitch-Devices:\n$startmessage");
	
	
	
	return;
}

################################	

sub MSwitch_Notify($$) {
    my $testtoggle = '';
    my ( $own_hash, $dev_hash ) = @_;
    my $ownName = $own_hash->{NAME};    # own name / hash
    my $devName;
    $devName = $dev_hash->{NAME};
    my $events = deviceEvents( $dev_hash, 1 );
	
	# prüfe debugmodes 	
	if (!exists $data{MSwitch}{warning}{debug})
	{
	MSwitch_Initcheck();
	}
	
### checke auf aktive wizard	
    if ( exists $own_hash->{helper}{mode} and $own_hash->{helper}{mode} eq "absorb" )
    {
        if ( time > $own_hash->{helper}{modesince} + $wizardreset )    # time bis wizardreset
        {
            delete( $own_hash->{helper}{mode} );
            delete( $own_hash->{helper}{modesince} );
            delete( $own_hash->{NOTIFYDEV} );
            delete( $own_hash->{READINGS} );
            readingsBeginUpdate($own_hash);
            readingsBulkUpdate( $own_hash, ".Device_Events", "no_trigger", 1 );
            readingsBulkUpdate( $own_hash, ".Trigger_cmd_off", "no_trigger", 1 );
            readingsBulkUpdate( $own_hash, ".Trigger_cmd_on", "no_trigger", 1 );
            readingsBulkUpdate( $own_hash, ".Trigger_off",    "no_trigger", 1 );
            readingsBulkUpdate( $own_hash, ".Trigger_on",     "no_trigger", 1 );
            readingsBulkUpdate( $own_hash, ".Trigger_device",  "no_trigger", 1 );
            readingsBulkUpdate( $own_hash, ".Trigger_log",     "off",        1 );
            readingsBulkUpdate( $own_hash, "state",           "active",     1 );
            readingsBulkUpdate( $own_hash, ".V_Check",        $vupdate,     1 );
            readingsBulkUpdate( $own_hash, ".First_init",     'done' );
            readingsEndUpdate( $own_hash, 0 );
            return;
        }
		
		return if $devName eq $ownName;
        my @eventscopy = ( @{$events} );
        foreach my $event (@eventscopy) 
		{
            readingsSingleUpdate( $own_hash, "EVENTCONF",$devName . ": " . $event, 1 );
        }
        return;
    }
# ende wenn wizard aktiv

# jede aktion für eigenes debug abbrechen
    if ( $devName eq $ownName && grep( m/.*Debug|clearlog.*/, @{$events} ) )
    {
        return;
    }

# events blocken wenn datensatz unvollständig
    if ( ReadingsVal( $ownName, '.First_init', 'undef' ) ne 'done' )
	{
        return;
    }

# lösche saveddevicecmd #
    MSwitch_del_savedcmds($own_hash);

# setze devicename auf Logfile, wenn LogNotify aktiv
    if ($own_hash->{helper}{testevent_device}&& $own_hash->{helper}{testevent_device} eq 'Logfile' )
    {
        $devName = 'Logfile';
    }

    my $trigevent = '';
    my $execids        = "0";
    my $foundcmd1      = 0;
    my $foundcmd2      = 0;
    my $foundcmdbridge = 0;
	my $activecount = 0;
    my $anzahl;
	my $mswait			= AttrVal( $ownName, "MSwitch_Wait", 0 );
    my $showevents     	= AttrVal( $ownName, "MSwitch_generate_Events", 0 );
	if (AttrVal( $ownName, 'MSwitch_Debug', '0' ) ne "0" ){$showevents = 1};
	
    my $evhistory      	= AttrVal( $ownName, "MSwitch_Eventhistory", 10 );
    my $resetcmd1      	= AttrVal( $ownName, "MSwitch_Reset_EVT_CMD1_COUNT", 0 );
    my $resetcmd2      	= AttrVal( $ownName, "MSwitch_Reset_EVT_CMD2_COUNT", 0 );
	my $devicemode  	= AttrVal( $ownName, 'MSwitch_Mode',           'Notify' );
    my $debugmode    	= AttrVal( $ownName, 'MSwitch_Debug',          "0" );
    my $startdelay 		= AttrVal( $ownName, 'MSwitch_Startdelay', $standartstartdelay );
    my $attrrandomnumber= AttrVal( $ownName, 'MSwitch_RandomNumber', '' );
	my $incommingdevice = '';
	my $triggerdevice =ReadingsVal( $ownName, '.Trigger_device', '' );    # Triggerdevice
    my @cmdarray;
    my @cmdarray1;    # enthält auszuführende befehle nach conditiontest
	my $sequenztime = AttrVal( $ownName, 'MSwitch_Sequenz_time', 5 );
	my $triggerlog = ReadingsVal( $ownName, '.Trigger_log', 'off' );
    my $triggeron     = ReadingsVal( $ownName, '.Trigger_on',      '' );
    my $triggeroff    = ReadingsVal( $ownName, '.Trigger_off',     '' );
    my $triggercmdon  = ReadingsVal( $ownName, '.Trigger_cmd_on',  '' );
    my $triggercmdoff = ReadingsVal( $ownName, '.Trigger_cmd_off', '' );
	my $triggercondition = ReadingsVal( $ownName, '.Trigger_condition', '' );
	
	my $set       = "noset";
    my $eventcopy = "";
	my @eventscopy;
	

# nur abfragen für eigenes Notify
    if (   $init_done && $devName eq "global"&& grep( m/^MODIFIED $ownName$/, @{$events} ) )
    {
        # reaktion auf eigenes notify start / define / modify
        my $timecond = gettimeofday() + 5;
        InternalTimer( $timecond, "MSwitch_LoadHelper", $own_hash );
    }

    if (   $init_done && $devName eq "global" && grep( m/^DEFINED $ownName$/, @{$events} ) )
    {
        # reaktion auf eigenes notify start / define / modify
        my $timecond = gettimeofday() + 5;
        InternalTimer( $timecond, "MSwitch_LoadHelper", $own_hash );
    }

    if ( $devName eq "global" && grep( m/^INITIALIZED|REREADCFG$/, @{$events} ) )
    {
        # reaktion auf eigenes notify start / define / modify
		
		#Log3("test",0,"found init 1");
			
	# versionscheck
    if ( ReadingsVal( $ownName, '.V_Check', $vupdate ) ne $vupdate ) 
	{
        my $ver = ReadingsVal( $ownName, '.V_Check', '' );
        MSwitch_LOG( $ownName, 1,"$ownName-> Event blockiert, NOTIFYDEV deaktiviert - Versionskonflikt L:" . __LINE__ );
		$own_hash->{NOTIFYDEV} = 'no_trigger';
       #delete $own_hash->{NOTIFYDEV};
    }
	
		
        MSwitch_LoadHelper($own_hash);
    }
# nur abfragen für eigenes Notify ENDE
    
#Log3("test",0,"nach init 1");
# Return without any further action if the module is disabled
	return "" if ( IsDisabled($ownName) );
	
	
# lösche cmd counter
    if ( $resetcmd1 > 0 && ReadingsVal( $ownName, 'EVT_CMD1_COUNT', '0' ) >= $resetcmd1 )
    {
        readingsSingleUpdate( $own_hash, "EVT_CMD1_COUNT", 0, $showevents );
    }

    if ( $resetcmd2 > 0 && ReadingsVal( $ownName, 'EVT_CMD2_COUNT', '0' ) >= $resetcmd1 )
    {
        readingsSingleUpdate( $own_hash, "EVT_CMD2_COUNT", 0, $showevents );
    }
	
# abbruch wenn selbsttrigger nicht aktiv 
    if ( AttrVal( $ownName, "MSwitch_Selftrigger_always", 0 ) ne "1" ) 
	{
        return if ( ReadingsVal( $ownName, ".Trigger_device", "no_trigger" ) eq 'no_trigger' );
        return if ( !$own_hash->{NOTIFYDEV} && ReadingsVal( $ownName, '.Trigger_device', 'no_trigger' ) ne "all_events" );
    }

#Log3("test",0,"nach init 1a");
# startverzögerung abwarten
    my $diff = int(time) - $fhem_started;
	
	#Log3("test",0,int(time)." - ".$fhem_started);
	
	#Log3("test",0,"startdelay: $startdelay");
	#Log3("test",0,"diff: $diff");
	
	
	
    if ( $diff < $startdelay && $startdelay > 0 )
	{
        MSwitch_LOG( $ownName, 6,"Event blockiert - Startverzögerung $diff " );
        return;
    }
#Log3("test",0,"nach init 1b");


# test wait attribut
    if ( ReadingsVal( $ownName, "waiting", '0' ) > time ) 
	{
        MSwitch_LOG( $ownName, 6, "Event blockiert - Wait gesetzt " . ReadingsVal( $ownName, "waiting", '0' ) . " " );
        # teste auf attr waiting verlesse wenn gesetzt
        return "";
    }
    else 
	{
        # reading löschen
        delete( $own_hash->{READINGS}{waiting} );
    }

# setze incomming device  

    if ( defined( $own_hash->{helper}{testevent_device} )&& $own_hash->{helper}{testevent_device} eq $ownName )
    {
		# setze name als mswitch self wenn von mswitch selber ausgelöst ( selftrigger always)
        $incommingdevice = "MSwitch_Self";
        $events          = 'x';
    }
    elsif (defined( $own_hash->{helper}{testevent_device})) 
	{
        # unklar
        $events          = 'x';
        $incommingdevice = ( $own_hash->{helper}{testevent_device} );
    }
    else 
	{
		# setze devicenam wenn nicht durch mswitch_self ausgelöst
        $incommingdevice = $dev_hash->{NAME};    # aufrufendes device
    }

# abbruch wenn nicht logfile
    if ( !$events && $own_hash->{helper}{testevent_device} ne 'Logfile' ) 
	{
        return;
    }

################# ggf umsetzen - nach akzeptierten events
    if ( $attrrandomnumber ne '' ) 
	{
        # create randomnumber wenn attr an
        MSwitch_Createnumber1($own_hash);
    }
	
   # readingsSingleUpdate( $own_hash, 'last_activation_by','event',0 );
	
#######################################
	
    if ( $devicemode eq "Notify" ) 
	{
        # passt triggerfelder an attr an
        $triggeron  = 'no_trigger';
        $triggeroff = 'no_trigger';
    }

    if ( $devicemode eq "Toggle" ) 
	{
        # passt triggerfelder an attr an
        $triggeroff    = 'no_trigger';
        $triggercmdon  = 'no_trigger';
        $triggercmdoff = 'no_trigger';
    }

# notify für eigenes device

    if ( defined( $own_hash->{helper}{testevent_event}))
	{
        @eventscopy = "$own_hash->{helper}{testevent_event}";
		
        $devName = $own_hash->{helper}{testevent_device};
		$incommingdevice = $own_hash->{helper}{testevent_device};
		$triggerdevice = $own_hash->{helper}{testevent_device};
    }
    elsif ($devName eq $ownName && $triggerdevice eq "MSwitch_Self")
	{
		$devName = "MSwitch_Self";
		$incommingdevice = "MSwitch_Self";
		$triggerdevice = "MSwitch_Self";
		 @eventscopy = ( @{$events} ) if $events ne "x";
		
	}
	else
	{
        @eventscopy = ( @{$events} ) if $events ne "x";
    }

    $own_hash->{helper}{eventfrom} = $devName;
#Log3("test",0,"nach init 2");
	return if ($incommingdevice ne $triggerdevice
				&& $triggerdevice ne "all_events"
				&& $triggerdevice ne "MSwitch_Self"
				&& $incommingdevice ne "MSwitch_Self" );	

	
#Log3("test",0,"nach init 3");
#### alte sequenzen löschen
	my $sequenzarrayfull = AttrVal( $ownName, 'MSwitch_Sequenz', 'undef' );
	my @sequenzall = split( /\//, $sequenzarrayfull );
	my @sequenzarrayfull = split( / /, $sequenzarrayfull );
	$sequenzarrayfull =~ s/\// /g;
	my @sequenzarray;

	if ($sequenzarrayfull  ne "undef")
		{
			my @sequenzarray;
			my $sequenz;
			my $x = 0;
		
		foreach my $sequenz (@sequenzall)
			{
				$x++;
				if ( $sequenz ne "undef" ) {
					@sequenzarray = split( / /, $sequenz );
					my $sequenzanzahl = @sequenzarray;
					my $deletezeit    = time;
					my $seqhash       = $own_hash->{helper}{sequenz}{$x};
					foreach my $seq ( keys %{$seqhash} ) 
					{
						if ( time > ( $seq + $sequenztime ) ) 
						{
							delete( $own_hash->{helper}{sequenz}{$x}{$seq} );
						}
					}
				}
			}
		}	
#### alte sequenzen löschen			
## EVENTMAINLOOP	
##########################

#Log3("test",0,"for loop $events");


#Log3("test",0,"nach init 4");
      EVENT: foreach my $event (@eventscopy)
		{
		MSwitch_LOG( $ownName, 6, "bearbeitetes Event -> $event  " );
		
		
		#Log3("test",0,"aktuelles event: $event  ");
		
		
# ausstieg bei jason
        if ( $event =~ m/^.*:.\{.*\}?/ )
		{
                MSwitch_LOG( $ownName, 2, "$ownName:    found jason -> $event  " );
                next EVENT;
        }

        if ( $event =~ m/(.*)(\{.*\})(.*)/ )
		{
                my $p1   = $1;
                my $json = $2;
                my $p3   = $3;
                $json =~ s/:/[dp]/g;
                $json =~ s/\"/[dst]/g;
                $event = $p1 . $json . $p3;
        }
#
        $own_hash->{eventsave} = 'unsaved';
        $event = "" if ( !defined($event) );
        $eventcopy = $event;
        $eventcopy =~ s/: /:/s;    # BUG  !!!!!!!!!!!!!!!!!!!!!!!!
        $event =~ s/: /:/s;

####################################

		$eventcopy = "$devName:$eventcopy";

##################################################################
# eventcopy  enthätl die arbeitskopie von event : immer 3 teilg ##
##################################################################

# teste auf mswitch-eventmap  -> vor triggercondition				
	$eventcopy = MSwitch_Eventmap($own_hash,$ownName,$eventcopy);	

		# temporär
		# setze eingehendes Event :
		 
		delete $own_hash->{helper}{evtparts};
		delete $own_hash->{helper}{evtparts}{event};
		delete $own_hash->{helper}{aktevent};
		
		#Log3("test",0,"eventcopy ".$eventcopy);
		
		my @eventteile   = split( /:/, $eventcopy );
			
			
		next EVENT if @eventteile > 3;	# keine 4 stelligen events zulassen
		#hier kann optiona eine zusammenfassung eingebaut werde ( zusammenfassung nach der 3 stelle
		
		
#Log3("test",0,"parts ".@eventteile);		
		
		
		 if (@eventteile == 2 && $eventteile[0] eq "global")
		 {
			 unshift (@eventteile,"global");
			 $eventcopy = join(":",@eventteile);
		 }
		
		if (!defined $eventteile[0]){ $eventteile[0]="";}
		if (!defined $eventteile[1] ){$eventteile[1]="";}
		if (!defined $eventteile[2]){ $eventteile[2]="";}
	
		$own_hash->{helper}{evtparts}{parts}=3;
		$own_hash->{helper}{evtparts}{device}	=$incommingdevice;
		$own_hash->{helper}{evtparts}{evtpart1}	=$eventteile[0];
		$own_hash->{helper}{evtparts}{evtpart2}	=$eventteile[1];
		$own_hash->{helper}{evtparts}{evtpart3}	=$eventteile[2];
		$own_hash->{helper}{evtparts}{evtfull}	=$eventcopy;
		$own_hash->{helper}{evtparts}{event}	=$eventteile[1].":".$eventteile[2];
		$own_hash->{helper}{aktevent}=$eventcopy;
		
# teste auf mswitch-reading - evtl umsetzen -> nach triggercondition				
	MSwitch_Readings($own_hash,$ownName);	
# Teste auf einhaltung Triggercondition für ausführung zweig 1 und zweig 2
# kann ggf an den anfang der routine gesetzt werden ? test erforderlich
        
        $triggercondition =~ s/#\[dp\]/:/g;
		$triggercondition =~ s/#\[pt\]/./g;
		$triggercondition =~ s/#\[ti\]/~/g;
		$triggercondition =~ s/#\[sp\]/ /g;
		
		if ( $triggercondition ne '' ) 
			{
			my $ret = MSwitch_checkcondition( $triggercondition, $ownName,$eventcopy );
            if ( $ret eq 'false' )
				{
                    next EVENT;
                }
            }
### ab hier ist das event durch condition akzeptiert		

delete( $own_hash->{helper}{history} ) ; # lösche historyberechnung verschieben auf nach abarbeitung conditions

# update der readings
			if ( $event ne '' ) 
			{
                    MSwitch_EventBulk( $own_hash, $eventcopy, '0','MSwitch_Notify' );
			}

######################################

#### checke eventwait:
# nur wenn attribut gesetzt

		my $eventsollwait =$data{MSwitch}{$ownName}{eventwait}{ $eventcopy};
		if (defined $eventsollwait && $eventsollwait ne "")
		{ 
			my $lastincomming = $data{MSwitch}{$ownName}{inputeventwait}{$eventcopy};
			if ($lastincomming eq "")
			{
				$lastincomming = 0 ;
			}

			my $newdiff =  $lastincomming+$eventsollwait-time;
			if ($newdiff > 0)
			{
				my $lasttime= time+$eventsollwait - $lastincomming ;
				MSwitch_LOG($ownName,6,"Event $eventcopy wird noch $newdiff sekunden blockiert");
				next EVENT;
			}
			else
			{
				$data{MSwitch}{$ownName}{inputeventwait}{$eventcopy} = time;
			}
		}

######################################
# sequenz
        my $x    = 0;
        my $zeit = time;

        SEQ: foreach my $sequenz (@sequenzall)
		{
            $x++;
            if ( $sequenz ne "undef" )
			{
                foreach my $test (@sequenzarrayfull)
				{
                    if ( $eventcopy =~ /$test/ )
					{
                        $own_hash->{helper}{sequenz}{$x}{$zeit} = $eventcopy;
                    }
                }

                my $seqhash    = $own_hash->{helper}{sequenz}{$x};
				my $aktsequenz = "";
                foreach my $seq ( sort keys %{$seqhash} )
				{
                    $aktsequenz .=$own_hash->{helper}{sequenz}{$x}{$seq} . " ";
                }

                if ( $aktsequenz =~ /$sequenz/ )
				{
                    delete( $own_hash->{helper}{sequenz}{$x} );
                    MSwitch_LOG( $ownName, 6, "Sequenz $x gefunden " );
                    readingsSingleUpdate( $own_hash, "SEQUENCE", 'match',$showevents );
                    readingsSingleUpdate( $own_hash, "SEQUENCE_Number", $x, $showevents );
                    last SEQ;
                }
                else 
				{
                    if ( ReadingsVal( $ownName, "SEQUENCE", 'undef' ) eq "match" )
                        {
                            readingsSingleUpdate( $own_hash, "SEQUENCE",'no_match', $showevents );
                        }
                    if ( ReadingsVal( $ownName, "SEQUENCE_Number", 'undef' )ne "0" )
                        {
                            readingsSingleUpdate( $own_hash, "SEQUENCE_Number", '0', $showevents );
                        }
                }
            }
        }
######################################
# Triggerlog/Eventlog

        if ( $triggerlog eq 'on' )
		{
            my $zeit = time;
            if ( $incommingdevice ne "MSwitch_Self" )
			{
                    if ( $triggerdevice eq "all_events" )
					{
                        $own_hash->{helper}{events}{'all_events'}{$eventcopy} = "on";
                    }
                    else
					{
                       $own_hash->{helper}{events}{$devName}{$eventcopy} ="on";
                    }
            }
            else 
			{
                $own_hash->{helper}{events}{MSwitch_Self}{$eventcopy} ="on";
            }

        }


        if ( $evhistory > 0 )
		{
            my $zeit = time;
            $own_hash->{helper}{eventlog}{$zeit} ="MSitch_Self:" . $eventcopy;
            my $log = $own_hash->{helper}{eventlog};
            my $x   = 0;
            my $seq;
            foreach $seq ( sort { $b <=> $a } keys %{$log} )
			{
                delete( $own_hash->{helper}{eventlog}{$seq} )if $x > $evhistory;
                $x++;
            }
        }

################ alle events für weitere funktionen speichern
#############################################################      
            if ( $event ne '' ) 
			{
                ### pruefe Bridge
                my ( $chbridge, $zweig, $bridge ) =MSwitch_checkbridge( $own_hash, $ownName, $eventcopy, );
                next EVENT if $chbridge eq "found bridge";
            }

############################################################################################################

            my $testvar      = '';
			my $check = 0;
            #test auf zweige cmd1/2 and switch MSwitch on/off
            if ( $triggeron ne 'no_trigger' )
			{
            $testvar = MSwitch_checktrigger_new( $own_hash,$triggeron, 'on' );
                if (defined $testvar && $testvar ne 'undef' )
				{
                    $set       = $testvar;
                    $check     = 1;
                    $foundcmd1 = 1;
                    $trigevent = $eventcopy;
                }
            }

            if ( $triggeroff ne 'no_trigger' )
			{
            $testvar =MSwitch_checktrigger_new( $own_hash,$triggeroff,'off');
                if (defined $testvar && $testvar ne 'undef')
				{
                    $set       = $testvar;
                    $check     = 1;
                    $foundcmd2 = 1;
                    $trigevent = $eventcopy;
                }
            }

            #test auf zweige cmd1/2 and switch MSwitch on/off ENDE
            #test auf zweige cmd1/2 only
            #ergebnisse werden in  @cmdarray geschrieben

            if ( $triggercmdoff ne 'no_trigger' )
			{
                $testvar = MSwitch_checktrigger_new( $own_hash, $triggercmdoff, 'offonly' );
                if ( defined $testvar && $testvar ne 'undef' )
				{
                    MSwitch_LOG( $ownName, 6, "Befehl eingefuegt (cmdoff)");
                    push @cmdarray, $own_hash . ',off,check,' . $eventcopy;
                    $check     = 1;
                    $foundcmd2 = 1;
                }
            }

            if ( $triggercmdon ne 'no_trigger' )
			{
                $testvar = MSwitch_checktrigger_new( $own_hash,$triggercmdon,'ononly');
                if ( defined $testvar && $testvar ne 'undef' )
				{
                    MSwitch_LOG( $ownName, 6,"Befehl eingefuegt (cmdon)");
                    push @cmdarray, $own_hash . ',on,check,' . $eventcopy;
                    $check     = 1;
                    $foundcmd1 = 1;
                }
            }

#### prüfen
            # speichert 20 events ab zur weiterne funktion ( funktionen )
            # ändern auf bedarfschaltung   ,$own_hash->{helper}{evtparts}
			# wenn der wert nur zahlen enthätl

            if (    $check == '1'
                and defined( ( split( /:/, $eventcopy ) )[2] )
                and ( ( split( /:/, $eventcopy ) )[2] =~ /^[-]?[0-9,.E]+$/ ) )
            {
				
				my $evde    = ( split( /:/,$eventcopy   ))[0]; #ACHTUNG
				my $evwert    = ( split( /:/,$eventcopy   ))[2]; #ACHTUNG
                my $evreading = ( split( /:/,$eventcopy  ))[1];  #ACHTUNG

                my @eventfunction;
				@eventfunction = split( / /, $own_hash->{helper}{eventhistory}{$evreading} ) if exists $own_hash->{helper}{eventhistory}{$evreading};
                unshift( @eventfunction, $evwert );
                while ( @eventfunction > $evhistory ) 
				{
                    pop(@eventfunction);
                }
                my $neweventfunction = join( ' ', @eventfunction );
                $own_hash->{helper}{eventhistory}{$evreading} =$neweventfunction;
            }
			
#Newfunction	
		#Function AVG	
			
			if (AttrVal( $ownName, "MSwitch_Func_AVG", 'undef') ne 'undef')
			{
				MSwitch_Check_AVG($own_hash,$ownName) ;
			}
			
		#Function DIFF	
			
			if (AttrVal( $ownName, "MSwitch_Func_DIFF", 'undef') ne 'undef')
			{
				MSwitch_Check_DIFF($own_hash,$ownName) ;
			}	
				
		#Function TEND	
			
			if (AttrVal( $ownName, "MSwitch_Func_TEND", 'undef') ne 'undef')
			{
				MSwitch_Check_TEND($own_hash,$ownName) ;
			}	
				
######################################
#test auf zweige cmd1/2 only ENDE

            $anzahl = @cmdarray;
            $own_hash->{IncommingHandle} = 'fromnotify' if $devicemode ne "Dummy";
 #          $event =~ s/~/ /g;    #?
 
 
            if ( $devicemode eq "Notify" and $activecount == 0 )
			{
                # reading activity aktualisieren
                readingsSingleUpdate( $own_hash, "state",'active', $showevents )if ReadingsVal( $ownName, 'state', '0' ) eq "active";
                $activecount = 1;
            }
		
            if ( $devicemode eq "Toggle" && $set eq 'on' )
			{
                # umschalten des devices nur im togglemode
                my $cmd = '';
                my $statetest = ReadingsVal( $ownName, 'state', 'on' );
                $cmd = "set $ownName off" if $statetest eq 'on';
                $cmd = "set $ownName on"  if $statetest eq 'off';

                if ( $debugmode ne '2' )
				{
                    my $errors = AnalyzeCommandChain( undef, $cmd );
                    if ( defined($errors) )
					{
                        MSwitch_LOG( $ownName, 1,"$ownName MSwitch_Notify: Fehler bei Befehlsausführung $errors -> Comand: $_ ". __LINE__ );
                    }
                }
                return;
            }
        
		}

#################################################
# abfrage und setzten von blocking
# schalte blocking an , wenn anzahl grösser 0 und MSwitch_Wait gesetzt
        if (($foundcmd1 eq "1"  || $foundcmd2 eq "1") && $mswait > 0 )
			{
                readingsSingleUpdate( $own_hash, "waiting", ( time + $mswait ),0 );
            }
# abfrage und setzten von blocking ENDE
#################################################
# CMD Counter setzen
        if ( $foundcmd1 eq "1" && AttrVal( $ownName, "MSwitch_Reset_EVT_CMD1_COUNT", 'undef' ) ne 'undef' )
        {
            my $inhalt = ReadingsVal( $ownName, 'EVT_CMD1_COUNT', '0' );
            if ( $resetcmd1 == 0 )
			{
                $inhalt++;
                readingsSingleUpdate( $own_hash, "EVT_CMD1_COUNT",$inhalt, $showevents );
            }
            elsif ( $resetcmd1 > 0 && $inhalt < $resetcmd1 )
			{
                $inhalt++;
                readingsSingleUpdate( $own_hash, "EVT_CMD1_COUNT",$inhalt, $showevents );
            }
        }

        if ( $foundcmd2 eq "1" && AttrVal( $ownName, "MSwitch_Reset_EVT_CMD2_COUNT", 'undef' ) ne'undef' )
        {
            my $inhalt = ReadingsVal( $ownName, 'EVT_CMD2_COUNT', '0' );
            if ( $resetcmd2 == 0 )
			{
                $inhalt++;
                readingsSingleUpdate( $own_hash, "EVT_CMD2_COUNT",$inhalt, $showevents );
            }
            elsif ( $resetcmd2 > 0 && $inhalt < $resetcmd2 )
			{
                $inhalt++;
                readingsSingleUpdate( $own_hash, "EVT_CMD2_COUNT", $inhalt, $showevents );
            }
        }
# CMD Counter setzen ENDE	
#################################################	
		

     #ausführen aller cmds in @cmdarray nach triggertest aber vor conditiontest
     #my @cmdarray1;	#enthält auszuführende befehle nach conditiontest
     #schaltet zweig 3 und 4

        # ACHTUNG
        if ( $anzahl && $anzahl != 0 )
		{

            MSwitch_LOG( $ownName, 6, "auszuführende Befehle gefunden: $anzahl");
            MSwitch_LOG( $ownName, 6, "Befehlsarray: @cmdarray ");
            #aberabeite aller befehlssätze in cmdarray
            MSwitch_Safemode($own_hash);

        LOOP31: foreach (@cmdarray)
			{
                my $test = $_;
                if ( $_ eq 'undef' ) { next LOOP31; }
                my ( $ar1, $ar2, $ar3, $ar4 ) = split( /,/, $test );
                if ( !defined $ar2 ) { $ar2 = ''; }
                if ( $ar2 eq '' )
				{
                    next LOOP31;
                }
                my $returncmd = 'undef';
				
				MSwitch_LOG( $ownName, 6, "aufruf sub_execnotif:\n$ar2, $ar3, $ar4, $execids" );
                $returncmd = MSwitch_Exec_Notif( $own_hash, $ar2, $ar3, $ar4, $execids );
               
				if ( defined $returncmd && $returncmd ne 'undef' )
				{
                    # datensatz nur in cmdarray1 übernehme wenn
                    chop $returncmd;    #CHANGE

                    push( @cmdarray1, $returncmd );
                }
			}

            my $befehlssatz = join( ',', @cmdarray1 );
            foreach ( split( /,/, $befehlssatz ) )
			{
                my $ecec = $_;
                if ( !$ecec =~ m/set (.*)(MSwitchtoggle)(.*)/ )
				{
                    if ( $attrrandomnumber ne '' )
					{
                        MSwitch_Createnumber($own_hash);
                    }

                    if ( $debugmode ne '2' )
					{
                        MSwitch_LOG( $ownName, 6,"Befehlsausführung:\n$_ ");
                        my $errors = AnalyzeCommandChain( undef, $_ );
                        if ( defined($errors) )
						{
                            MSwitch_LOG( $ownName, 1,"$ownName MSwitch_Notify: Fehler bei Befehlsausführung $errors -> Comand: $_ " . __LINE__ );
                        }
                    }

                    if ( length($ecec) > 100 )
					{
                        $ecec = substr( $ecec, 0, 100 ) . '....';
                    }
                    readingsSingleUpdate( $own_hash, "last_exec_cmd", $ecec, $showevents ) if $ecec ne '';
                }
                else
				{
                    # nothing
                }
            }
        }

        # ende loopeinzeleventtest
        # schreibe gruppe mit events
        my $selftrigger = "";
        $events      = '';
        my $eventhash   = $own_hash->{helper}{events}{$devName};
        if ( AttrVal( $ownName, "MSwitch_Selftrigger_always", 0 ) eq "1" )
		{
            $eventhash = $own_hash->{helper}{events}{MSwitch_Self};
            foreach my $name ( keys %{$eventhash} )
			{
                $events = $events . 'MSwitch_Self:' . $name . '#[tr]';
            }
        }

        if ( $triggerdevice eq "all_events" )
		{
            $eventhash = $own_hash->{helper}{events}{all_events};
        }
        else 
		{
            $eventhash = $own_hash->{helper}{events}{$devName};
        }

        foreach my $name ( keys %{$eventhash} )
		{
            $events = $events . $name . '#[tr]';
        }
        chop($events);
        chop($events);
        chop($events);
        chop($events);
        chop($events);
        if ( $events ne "" )
		{
            readingsSingleUpdate( $own_hash, ".Device_Events", $events, $showevents );
        }

        # schreiben ende
        # schalte modul an/aus bei entsprechendem notify
        # teste auf condition
        return if $set eq 'noset';   # keine MSwitch on/off incl cmd1/2 gefunden

######################
# schaltet zweig 1 und 2 , wenn $set befehl enthält , es wird nur MSwitch geschaltet, Devices werden dann 'mitgerissen'
        my $cs;

        if ( $triggerdevice eq "all_events" )
		{
            $cs = "set $ownName $set $devName:$trigevent";
        }
        else
		{
            $cs = "set $ownName $set $trigevent";
        }

        if ( $attrrandomnumber ne '' )
		{
            MSwitch_Createnumber($own_hash);
        }

        if ( $debugmode ne '2' )
		{
            MSwitch_LOG( $ownName, 6, "Befehlsausführung:\n$cs" );
            my $errors = AnalyzeCommandChain( undef, $cs );
        }
        return;
 #  }
}

#########################

sub	MSwitch_Eventmap(@){	
	my ( $hash, $name ,$eventcopy) = @_;
	return if !exists $data{MSwitch}{$name}{Eventmap};
	readingsSingleUpdate( $hash, 'EVENT_ORG',$eventcopy,0 );
	my $maphash = $data{MSwitch}{$name}{Eventmap};
    foreach my $key ( keys %{$maphash} )
	{
	my $inhalt = $data{MSwitch}{$name}{Eventmap}{$key};
	$eventcopy =~ s/$key/$inhalt/g;
	}
return $eventcopy;
}

#########################


sub MSwitch_Readings(@)
{
	
	my ( $hash, $name ) = @_;
	return if !exists $data{MSwitch}{$name}{Readings};
	my $keyhash = $data{MSwitch}{$name}{Readings};
    foreach my $reading ( keys %{$keyhash} )
	{
	my $cs = "{".$data{MSwitch}{$name}{Readings}{$reading}."}";
	$cs = MSwitch_dec( $hash, $cs );
	$cs = MSwitch_makefreecmd( $hash, $cs );
	my $result = eval($cs);
	readingsSingleUpdate( $hash, $reading, $result, 1 );
	}
return;
}


###############################
sub MSwitch_checkbridge($$$) {
    my ( $hash, $name, $event ) = @_;
    MSwitch_LOG( $name, 6, "SUB BRIDGE EVENT: $event L:" . __LINE__ );
    my $bridgemode = ReadingsVal( $name, '.Distributor', '0' );
    my $expertmode = AttrVal( $name, 'MSwitch_Expert', '0' );

	my @bridge;
	my $zweig;
	my $eventpart;
	my $eventbedingung;
	my $foundcond;	
	my $orgkey;
	my $etikeys  = $hash->{helper}{eventtoid};
	my $foundkey = "undef";	
		
    return "no_bridge" if $expertmode eq "0";
    return "no_bridge" if $bridgemode eq "0";

    foreach my $a ( sort keys %{$etikeys} ) 
	{
		@bridge=();
		$foundkey = "undef";
		$orgkey = $a;
		$foundcond ="0";
		$eventbedingung="";
        MSwitch_LOG( $name, 6, "SUB BRIDGE KEY: -$a- L:" . __LINE__ );
		
		if ($a =~ m/(.*)\[(.*)\]/ )
		{
		
			$foundcond ="1";
			$eventpart =$1;
			$eventbedingung = $2;
			MSwitch_LOG( $name, 6,"Zsatzbedingung gefunden: $a  L:" . __LINE__ );
			MSwitch_LOG( $name, 6,"eventpart $eventpart  L:" . __LINE__ );
			MSwitch_LOG( $name, 6,"eventbedingung $eventbedingung  L:" . __LINE__ );
			$a =$eventpart;
		}
		
        my $re = qr/$a/;
		MSwitch_LOG( $name, 6, "$re - $event L:" . __LINE__ );
        $foundkey = $a if ( $event =~ /$re/ );

		MSwitch_LOG( $name, 6, "SUB BRIDGE foundkey: -$foundkey- L:" . __LINE__ );
		MSwitch_LOG( $name, 6, "SUB BRIDGE EVENT: $event L:" . __LINE__ );
		MSwitch_LOG( $name, 6, "SUB BRIDGE EVENT vergleich mit a: $a L:" . __LINE__ );
		
		next if $foundkey eq "undef";
		if ($foundkey ne "undef" ){$foundkey = $orgkey;}
		
	##########################	
	#	ausführen des gefundenen keys
	#	
		@bridge = split( / /, $hash->{helper}{eventtoid}{$foundkey} ) if exists $hash->{helper}{eventtoid}{$foundkey};
		#$zweig;
		MSwitch_LOG( $name, 6, "SUB BRIDGE : @bridge L:" . __LINE__ );
		next if @bridge < 1;
		$zweig = "on"  if $bridge[0] eq "cmd1";
		$zweig = "off" if $bridge[0] eq "cmd2";
		MSwitch_LOG( $name, 6,"ID Bridge gefunden: zweig: $bridge[0] , ID:$bridge[2]  L:" . __LINE__ );
		
		if ($foundcond eq "1")
		{
			MSwitch_LOG( $name, 6, "Teste gefundene Zusatzbedingung $eventbedingung L:" . __LINE__ );
			MSwitch_LOG( $name, 6, "Eventtest fuer Zusatzbedingung $eventpart L:" . __LINE__ );
			MSwitch_LOG( $name, 6, "Eventeingang fuer Zusatzbedingung $event L:" . __LINE__ );
		
			my $eventparts = $hash->{helper}{evtparts};
			my @eventteile= split( /:/, $eventpart ,$eventparts )	;
		
			my $position ;	
			for ( my $i = 0 ; $i < $eventparts ; $i++ ) 
				{	
					MSwitch_LOG( $name, 6,"eventparts($i) $eventteile[$i]  L:" . __LINE__ );
					if ($eventteile[$i] eq ".*")
					{
						$position = $i;
					}
				}	
		
			MSwitch_LOG( $name, 6,"starposition $position  L:" . __LINE__ );
	
			my @eventsplit =split(/:/,	$event);
			my $staris =$eventsplit[$position];
			MSwitch_LOG( $name, 6,"staris $staris  L:" . __LINE__ );
		
			my $newcondition = $eventbedingung;
		
			MSwitch_LOG( $name, 6,"oldcondition  $newcondition  L:" . __LINE__ );
		
			if ($staris =~ m/^-?\d+(?:[\.,]\d+)?$/)
			{
				MSwitch_LOG( $name, 6,"STARIS =  Zahl L:" . __LINE__ );
				$newcondition =~ s/\*/$staris/g;
			}
			else
			{
				MSwitch_LOG( $name, 6,"STARIS =  String  L:" . __LINE__ );
				$newcondition =~ s/\*/"$staris"/g;
				# teste auf string/zahl vergleich
				my $testccondition = $newcondition;
				$testccondition =~ s/ //g;
				MSwitch_LOG( $name, 6,"Testcondition $testccondition  L:" . __LINE__ );
				if ($testccondition =~ m/(".*"(>|<)\d+)/)
				{
					MSwitch_LOG( $name, 6,"ABBRUCH STRING ZAHL Vergleich gefunden  L:" . __LINE__ );
					return 'undef';
				}
			}
			MSwitch_LOG( $name, 6,"newcondition  $newcondition  L:" . __LINE__ );
			my $ret = MSwitch_checkcondition($newcondition,$name,$event);
			MSwitch_LOG( $name, 6,"bedingungsprüfung  $ret  L:" . __LINE__ );
			next if $ret ne "true";;
		}
		MSwitch_Exec_Notif( $hash, $zweig, 'nocheck', $event, $bridge[2] );
    }

    if ( !defined $hash->{helper}{eventtoid}{$foundkey} )
	{
        return "NO BRIDGE FOUND !";
    }
    return ( "bridge found", $zweig, $bridge[2] );
}

############################
sub MSwitch_fhemwebconf($$$$) {

    my ( $FW_wname, $d, $room, $pageHash ) = @_;    # pageHash is set for summaryFn.
    my $hash = $defs{$d};
    my $Name = $hash->{NAME};
    my @found_devices;
	
    delete( $hash->{NOTIFYDEV} );
    readingsSingleUpdate( $hash, "EVENTCONF", "start", 1 );

    my $preconf1 = '';
    my $preconf  = '';
    my $devstring;
    my $cmds;
    $cmds .="' reset_Switching_once loadHTTP timer:on,off del_repeats reset_device active del_function_data inactive on off del_delays backup_MSwitch fakeevent exec_cmd_1 exec_cmd_2 wait del_repeats reload_timer change_renamed reset_cmd_count ',";
    $devstring .= "'MSwitch_Self',";
    @found_devices = devspec2array("TYPE=.*");

    for (@found_devices)
	{
        my $test = getAllSets($_);
		if ( $test =~m/.*'.*/ )
		{
			Log3($Name,1,"der Fhembefehl 'getAllSets' verursacht eine ungültige Rückgabe des Devices $_ , bitte den Modulautor informieren . Hierfür bitte den Devicetypen des Devices $_ angeben. ");
			$test=~ s/'//g;
		}	
        $cmds      .= "'" . $test . "',";
        $devstring .= "'" . $_ . "',";
    }

    chop $devstring;
    chop $cmds;
    $cmds =~ s/\n//g;
    $cmds =~ s/\r//g;
    $devstring = "[" . $devstring . "]";
    $cmds      = "[" . $cmds . "]";
    my $fileend = "x" . rand(1000);
    my $devicehash;
    my $at="";
    my $atdef;
    my $athash;
    my $insert;
    my $comand;
    my $timespec;
    my $flag;
    my $trigtime;

    # suche at
    @found_devices = devspec2array("TYPE=at");
    for (@found_devices)
	{
        $athash = $defs{$_};
        $insert = $athash->{DEF};
        $flag   = substr( $insert, 0, 1 );

        if ( $flag ne "+" )
		{
            next if $athash->{PERIODIC} eq 'no';
            next if $athash->{RELATIVE} eq 'yes';
        }
        $at .= "'" . $_ . "',";
    }
    chop $at if length($at) > 0;

    $at = "[" . $at . "]";
    # suche notify
    my $nothash;
    my $notinsert;
    my $notify="";
    my $notifydef="";

    @found_devices = devspec2array("TYPE=notify");
    for (@found_devices)
	{
        $nothash   = $defs{$_};
        $notinsert = $nothash->{DEF};
        $notify .= "'" . $_ . "',";
    }
    chop $notifydef if length($at) > 0;
    chop $notify if length($at) > 0;
    $notify = "[" . $notify . "]";

    my $return = "<div id='mode'>Konfigurationsmodus:&nbsp;";
    $return .="<input name=\"conf\" id=\"config\" type=\"button\" value=\"import MSwitch_Config\" onclick=\"javascript: conf('importCONFIG',id)\"\">&nbsp;
	<input name=\"conf\" id=\"importat\" type=\"button\" value=\"import AT\" onclick=\"javascript: conf('importAT',id)\"\">&nbsp;
	<input name=\"conf\" id=\"importnotify\" type=\"button\" value=\"import NOTIFY\" onclick=\"javascript: conf('importNOTIFY',id)\"\">
	<input name=\"conf\" id=\"importpreconf\" type=\"button\" value=\"import PRECONF\" onclick=\"javascript: conf('importPRECONF',id)\"\">
	";

    my $templateinhalt = '';
    my $template       = "";
    my $adress         = $templatefile . "01_inhalt.txt";

    $templateinhalt = get($adress);

    my @templates = split( /\n/, $templateinhalt );

    foreach my $testdevices (@templates)
	{
        my ( $key, $val ) = split( /\|/, $testdevices );
        my $plainkey = ( split( /\./, $key ) )[0];
        $template .= "<option value=\"$plainkey\">$plainkey</option>";
    }

    my @files = <./FHEM/MSwitch/*.txt>;

    foreach my $testdevices (@files)
	{
        my @string = split( /\//, $testdevices );
        $string[3] =~ s/\.txt//g;
        $template .= "<option value=\"local/$string[3]\">local / $string[3]</option>";
    }

    $return .="<input name=\"template\" id=\"importTEMPLATE\" type=\"button\" value=\"import Template\" onclick=\"javascript: loadtemplate()\"\">";
    $return .="<select id =\"templatefile\"  name=\"\"  >"
      . "<option value=\"empty_template\">empty_template</option>"
      . $template
      . "</select>";

    $return .= "
	</div>
	<br><br>
	<div id='speicherbank' style='display: none;'>
	<hr>Hilfselder ( werden unsichtbar )<br>
	Speicherbank1 bank 1-4: 
	<input id='bank1' type='text' value=''>
	<input id='bank2' type='text' value=''>
	<input id='bank3' type='text' value=''>
	<input id='bank4' type='text' value=''>
	</div>

	<div id='speicherbank1' style='display: none;'>
	Speicherbank2 bank 5-8: 
	<textarea id='bank5'></textarea>
	<textarea id='bank6'></textarea>
	<textarea id='bank7'></textarea>
	<textarea id='bank8'></textarea>
	<br>&nbsp;<hr>
	</div>

	<table border='0'>
	<tr>
	<td id='help'>Hilfetext</td>
	<td id='help1'></td>
	</tr>
	</table>";

    $return .="<input type=\"button\" id = \"showtemplate\" value=\"zeige Template\" onclick=\"javascript: toggletemplate()\" style=\"display:none\">";
    $return .= "<br>&nbsp;<br>";
    $return .= "<div id='empty' style=\"display:none\">";
    $return .= "Template: ";
    $return .="<input type=\"text\" id = \"templatename\" value=\"\"  style=\"background-color:transparent\">";
    $return .="&nbsp;<input type=\"button\" id = \"savetemplata\" value=\"Template lokal speichern\"  style=\"\" onclick=\"javascript: savetemplate()\">";
    $return .="&nbsp;<input type=\"button\" id = \"\" value=\"FreeCmd kodieren\"  style=\"\" onclick=\"javascript: showkode()\">";
    $return .= "<br>&nbsp;<br>";
	$return .= "<div id='decode' style=\"display:none\">";
    $return .="<textarea id='decode1' style='width: 100%; height: 100px'>### insert code ###</textarea>";
    $return .="<br><input type=\"button\" id = \"\" value=\"kodieren\"  style=\"\" onclick=\"javascript: decode()\">";
    $return .="&nbsp;<input type=\"button\" id = \"\" value=\"dekodieren\"  style=\"\" onclick=\"javascript: encode()\">";
    $return .= "<br>&nbsp;</div>";
    $return .="<textarea id='emptyarea' style='width: 100%; height: 300px'>### insert template ###</textarea><br>
	 <input type=\"button\" id = \"execbutton\" value=\"Template ausführen\" onclick=\"javascript: execempty()\">
	 <br>&nbsp;<br>
	 </div>";
    $return .= "<div id='importWIZARD' style=\"display:none\">
	<table border = ''>
	<tr>
	<td id='monitor' style=\"text-align: center; vertical-align: middle;\">
	<br><select disabled=\"disabled\" style=\"width: 50em;\" size=\"15\" id =\"eventcontrol\" multiple=\"multiple\"></select>
	<br>&nbsp;<br>
	</td>
	</tr>
	<tr>
	<td style=\"text-align: center; vertical-align: middle;\">
	<br>&nbsp;<br>
	<input name=\"saveconf\" id=\"saveconf\" type=\"button\" disabled=\"disabled\" value=\"save new config\" onclick=\"javascript: saveconfig('rawconfig','wizard')\"\">
	</td>
	</tr>
	<tr>
	<td style=\"display:none; text-align: center; vertical-align: middle;\">	
	<textarea disabled id='rawconfig' style='width: 600px; height: 400px'></textarea>
	</td>
	</tr>
	</table>
	</div>";
    $return .= "
	<div id='importAT'>@found_devices</div>
	<div id='importNOTIFY'>import notify</div>
	<div id='importCONFIG'>import config</div>
	<div id='importPRECONF'>import preconf</div>
	<div id='importTemplate'>importTemplate</div>
	";

    my $ownattr = getAllAttr($Name);
    my @owna = split( / /, $ownattr );
    my $j1 = "
	<script type=\"text/javascript\">
	//preconf
	//var preconf ='" . $preconf . "';
	var preconf ='';
	";
    $j1 .= "// VARS
	const ownattr = [];
	const INQ = [];
	const templateinfo= [];
	";
    foreach my $akt (@owna)
	{
        next if $akt eq "";
        my @test = split( /:/, $akt );
        $j1 .= "ownattr['$test[0]']  = '$test[1]';\n";
    }

	my $vupdatedigit = substr($vupdate,1,length($vupdate)-1) ;
    $j1 .= "// firstconfig
	var logging ='off';
	var devices = " . $devstring . ";
	//var triggertime = " . $trigtime . ";
	var cmds = " . $cmds . ";
	var i;
	var len = devices.length;
	var o = new Object();
	var devicename= '" . $Name . "';
	var mVersion= '" . $version . "';
	var MSDATAVERSION = '" . $vupdate . "';
	var MSDATAVERSIONDIGIT = " . $vupdatedigit . ";
	var notify = " . $notify . ";
	var at = " . $at . ";
	var templatesel ='" . $hash->{helper}{template} . "';
	\$(document).ready(function() {
    \$(window).load(function() {
	name = '$Name';
	// loadScript(\"pgm2/MSwitch_Preconf.js?v=" . $fileend . "\");
    loadScript(\"pgm2/MSwitch_Wizard.js?v=" . $fileend
      . "\", function(){start1(name)});";

    if ( defined $hash->{helper}{template} ne "no" && $hash->{helper}{template} ne "no" )
	{
        $hash->{helper}{template} = 'no';
    }

    $j1 .= "return;
	}); 
	});
	</script>";

    # at vorübergehend deaktiviert
    # var at = " . $at . ";
    # var atdef = " . $atdef . ";
    # var atcmd = " . $comand . ";
    # var atspec = " . $timespec . ";
    # var notify = " . $notify . ";
    # var notifydef = " . $notifydef . ";"<br>&nbsp;<br>" .

    $return .= $j1;
    return $return;
}
############################
############################
sub MSwitch_fhemwebFn($$$$) {

    my ( $FW_wname, $d, $room, $pageHash ) =@_;    # pageHash is set for summaryFn.
    my $hash       = $defs{$d};
    my $Name       = $hash->{NAME};
    my $jsvarset   = '';
    my $j1         = '';
    my $border     = 0;
    my $ver        = ReadingsVal( $Name, '.V_Check', '' );
    my $expertmode = AttrVal( $Name, 'MSwitch_Expert', '0' );
	my $debugmode    	= AttrVal( $Name, 'MSwitch_Debug',0 );
    my $noshow     = 0;
    my @hidecmds = split( /,/, AttrVal( $Name, 'MSwitch_Hidecmds', 'undef' ) );
	my $debughtml="";
    my $testgroups = $data{MSwitch}{$Name}{groups};
    my @msgruppen  = ( keys %{$testgroups} );
    my $info       = '';
	my $system="";

 # if ( $debugmode > 1 )
    # {
		
	# $debughtml="<table style=\"display:none\" border='0' class='block wide' id='MSwitchWebTR' nm='$hash->{NAME}' cellpadding='4' style='border-spacing:0px;'>				
	# <tr class=\"even\"><td><div class=\"dname\" data-name=\"$Name\">Debug</div></td>
	# <td><div class=\"dval\" changeID =\"$Name-Debug\" informid=\"\">05:49:36: -&gt; LOCK gelöscht</div></td>
	# </tr>
	# </table><br>";	
	# $debughtml .= "<script>
	# \$(document).ready(function(){
    # \$( \"div[informId|=\'" . $Name . "-Debug-ts\']\" ).attr(\"informId\", \'1offline\');
	# \$( \"div[informId|=\'" . $Name . "-Debug\']\" ).text('aktiv'); 
	# \$( \"div[informId|=\'" . $Name . "-Debug\']\" ).attr(\"informId\", \'2offline\');
	# \$( \"div[changeID |=\'" . $Name . "-Debug\']\" ).attr(\"informId\", \'" . $Name . "-Debug\');
	# });
	# </script>";			
	# }
		
	if ( AttrVal( $Name, 'MSwitch_SysExtension', "0" ) =~ m/(0|1)/s  && $data{MSwitch}{$Name}{Ansicht} eq "room")
	{
        return;
    }
	
	my @affecteddevices = split( /,/, ReadingsVal( $Name, '.Device_Affected', 'no_device' ) );
	
	my $affectednames =  ReadingsVal( $Name, '.Device_Affected', 'no_device' );
	$affectednames =~ s/-AbsCmd[1-9]{1,3}//g;
	$affectednames =~ s/MSwitch_Self/$Name/g;
	my @affectedklartext = split( /,/,$affectednames );

    if ( AttrVal( $Name, 'MSwitch_SysExtension', "0" ) =~ m/(1|2)/s  )
	{
		$system = ReadingsVal( $Name, '.sysconf', '' );
		## platzhalter für benötigte readings (informid)
		#$system="<div id=\"\$Nameweekdayreading\" style=\"display: none;\"></div><span id='\$Nameinnersystem'></span>".$system;
		
        $system =
            "<script type=\"text/javascript\">var nameself ='"
          . $Name
          . "';</script>"
          . $system;
		  
        $system =~ s/#\[tr\]/[tr]/g;
        $system =~ s/#\[wa\]/|/g;
        $system =~ s/#\[sp\]/ /g;
        #$system =~ s/#\[nl\]/\n/g;
        $system =~ s/#\[se\]/;/g;
        $system =~ s/#\[bs\]/\\/g;
        $system =~ s/#\[dp\]/:/g;
        $system =~ s/#\[st\]/'/g;
        $system =~ s/#\[dst\]/\"/g;
        $system =~ s/#\[tab\]/    /g;
        $system =~ s/#\[ko\]/,/g;
        $system =~ s/\[tr\]/#[tr]/g;
		
		########################
		# teste auf widgetersetzungen
        #foreach my $a ( keys %{$data{MSwitch}{Widget}} ) 
			
			foreach my $a ( keys %{$data{MSwitch}{$Name}{activeWidgets}} ) 
			{
				if ( $system =~ m/\[MSwitch_Widget:$a\]/s ) 
					{

						$system =~ s/\[MSwitch_Widget:$a\]/$data{MSwitch}{Widget}{$a}{script}/g;
						$system.=$data{MSwitch}{Widget}{$a}{html};
					}
            }
		
		###########################
		
		$system =~ s/\$Name/$Name/g;
		$system =~ s/\$Callfrom/$data{MSwitch}{$Name}{Ansicht}/g;
		$system =~ s/#\[nl\]/\n/g;
		
	## ersetze benötigte readings für widgets 
	my $x = 0;
    while ( $system =~ m/(.*)\[ReadingVal\:(.*)\:(.*)\](.*)/ ) {
        $x++;    # notausstieg notausstieg
        my $setmagic = ReadingsVal( $2, $3, 0 );
		$system =~ s/\[ReadingVal:$2:$3\]/$setmagic/g;
		last if $x > 20;    # notausstieg notausstieg
    }
		

    }

########## korrigiere version
    # if ( ReadingsVal( $Name, '.V_Check', 'undef' ) ne $vupdate
        # && $autoupdate eq "on" )
    # {
		# Log3($Name,0,".V_Check: ".ReadingsVal( $Name, '.V_Check', 'undef' ));
		# Log3($Name,0,"Aufruf der versionsprüfung". __LINE__);
        # MSwitch_VersionUpdate($hash);
    # }

###########################
##### konfigmode

    if ( exists $hash->{helper}{mode} && $hash->{helper}{mode} eq "absorb" ) {
        $rename = "off";
        my $ret = MSwitch_fhemwebconf( $FW_wname, $d, $room, $pageHash );
        return $ret;

    }

####################  TEXTSPRACHE
    my $LOOPTEXT;
    my $ATERROR;
    my $PROTOKOLL2;
    my $PROTOKOLL3;
    my $CLEARLOG;
    my $WRONGSPEC1;
    my $WRONGSPEC2;
    my $HELPNEEDED;
    my $WRONGCONFIG;
    my $VERSIONCONFLICT;
    my $INACTIVE;
    my $OFFLINE;
    my $NOCONDITION;
    my $MSDISTRIBUTORTEXT;
    my $MSDISTRIBUTOREVENT;
    my $NOSPACE;
    my $MSTEST1 = "";
    my $MSTEST2 = "";
    my $EXECCMD;
    my $DUMMYMODE;
    my $RELOADBUTTON;
    my $RENAMEBUTTON;
    my $EDITEVENT;
    my $CLEARWINDOW;
    my $STOPLOG;

    if (
        AttrVal(
            $Name, 'MSwitch_Language',
            AttrVal( 'global', 'language', 'EN' )
        ) eq "DE"
      )
    {
        $DUMMYMODE =
"Device befindet sich im passiven Dummymode, für den aktiven Dummymode muss dass Attribut 'MSwitch_Selftrigger_always' auf '1' gesetzt werden. ";
        $MSDISTRIBUTORTEXT  = "Zuordnung Event/ID";
        $MSDISTRIBUTOREVENT = "eingehendes Event";
        $LOOPTEXT =
"ACHTUNG: Der Safemodus hat eine Endlosschleife erkannt, welche zum Fhemabsturz führen könnte.<br>Dieses Device wurde automatisch deaktiviert ( ATTR 'disable') !<br>&nbsp;";
        $ATERROR = "AT-Kommandos können nicht ausgeführt werden !";
        $PROTOKOLL2 =
"Das Device befindet sich im Debug 2 Mode. Es werden keine Befehle ausgeführt, sondern nur protokolliert.";
        $PROTOKOLL3 =
"Das Device befindet sich im Debug 3 Mode. Alle Aktionen werden protokolliert.";
        $CLEARLOG    = "lösche Log";
        $CLEARWINDOW = "lösche Fenster";
        $STOPLOG     = "Liveansicht";
        $WRONGSPEC1 =
"Format HH:MM<br>HH muss kleiner 24 sein<br>MM muss < 60 sein<br>Timer werden nicht ausgeführt";
        $WRONGSPEC2 =
"Format HH:MM<br>HH muss < 24 sein<br>MM muss < 60 sein<br>Bedingung gilt immer als FALSCH";
        $HELPNEEDED = "Eingriff erforderlich !";
        $WRONGCONFIG =
"Einspielen des Configfiles nicht möglich !<br>falsche Versionsnummer:";
        $VERSIONCONFLICT =
"Versionskonflikt erkannt!<br>Das Device führt derzeit keine Aktionen aus. Bitte ein Update des Devices vornehmen.<br>Erwartete Strukturversionsnummer: $vupdate<br>Vorhandene Strukturversionsnummer: $ver ";
        $INACTIVE = "Device ist nicht aktiv";
        $OFFLINE  = "Device ist abgeschaltet, Konfiguration ist möglich";
        $NOCONDITION =
"Es ist keine Bedingung definiert, das Kommando wird immer ausgeführt";
        $NOSPACE =
"Befehl kann nicht getestet werden. Das letzte Zeichen darf kein Leerzeichen sein.";
        $EXECCMD      = "augeführter Befehl:";
        $RELOADBUTTON = "Aktualisieren";
        $RENAMEBUTTON = "Name ändern";
        $EDITEVENT    = "Event bearbeiten";
    }
    else {
        $DUMMYMODE =
"Device is in passive dummy mode, for the active dummy mode the attribute 'MSwitch_Selftrigger_always' must be set to '1'.";
        $MSDISTRIBUTORTEXT  = "Event to ID distributor";
        $MSDISTRIBUTOREVENT = "incommming Event:";
        $LOOPTEXT =
"ATTENTION: The safe mode has detected an endless loop, which could lead to a crash.<br> This device has been deactivated automatically ( ATTR 'disable') !<br>&nbsp;";
        $ATERROR = "AT commands can not be executed!";
        $PROTOKOLL2 =
"The device is in Debug 2 mode, no commands are executed, only logged.";
        $PROTOKOLL3  = "The device is in debug 3 mode. All actions are logged.";
        $CLEARLOG    = "clear log";
        $CLEARWINDOW = "clear window";
        $STOPLOG     = "Live";
        $WRONGSPEC1 =
"Format HH: MM <br> HH must be less than 24 <br> MM must be <60 <br> Timers are not executed";
        $WRONGSPEC2 =
"Format HH: MM <br> HH must be <24 <br> MM must be <60 <br> Condition is always considered FALSE";
        $HELPNEEDED = "Intervention required !";
        $WRONGCONFIG =
          "Importing the Configfile not possible! <br> wrong version number:";
        $VERSIONCONFLICT =
"Version conflict detected! <br> The device is currently not executing any actions. Please update the device. <br> Expected Structure Version Number: $vupdate <br> Existing Structure Version Number: $ver";
        $INACTIVE = "Device is inactive";
        $OFFLINE  = "Device is disabled, configuration avaible";
        $NOCONDITION =
          "No condition is defined, the command is always executed";
        $NOSPACE =
          "Command can not be tested. The last character can not be a space.";
        $EXECCMD      = "executed command:";
        $RELOADBUTTON = "reload";
        $RENAMEBUTTON = "rename";
        $EDITEVENT    = "edit selected event";
    }
####################
    # lösche saveddevicecmd #
    if ( ReadingsVal( $Name, '.First_init', 'undef' ) ne 'done' ) {
        MSwitch_LoadHelper($hash);
    }

    my $cmdfrombase = "0";
    MSwitch_del_savedcmds($hash);

    if ( AttrVal( $Name, 'MSwitch_Debug', "0" ) eq '4' ) {
        $border = 1;
    }

    #versetzen nach ATTR
    if ( AttrVal( $Name, 'MSwitch_RandomNumber', '' ) eq '' ) {
        delete( $hash->{READINGS}{RandomNr} );
        delete( $hash->{READINGS}{RandomNr1} );
    }
####################
### teste auf new defined device
    my $hidden = '';
    if ( AttrVal( $Name, 'MSwitch_Debug', "0" ) eq '4' ) {
        $hidden = '';
    }
    else {
        $hidden = 'hidden';
    }

    my $triggerdevices = '';
    my $events         = ReadingsVal( $Name, '.Device_Events', '' );
    my @eventsall      = split( /#\[tr\]/, $events );
    my $Triggerdevice  = ReadingsVal( $Name, '.Trigger_device', '' );
    my $triggeron      = ReadingsVal( $Name, '.Trigger_on', '' );
    if ( !defined $triggeron ) { $triggeron = "" }
    my $triggeroff = ReadingsVal( $Name, '.Trigger_off', '' );
    if ( !defined $triggeroff ) { $triggeroff = "" }
    my $triggercmdon = ReadingsVal( $Name, '.Trigger_cmd_on', '' );
    if ( !defined $triggercmdon ) { $triggercmdon = "" }
    my $triggercmdoff = ReadingsVal( $Name, '.Trigger_cmd_off', '' );
    if ( !defined $triggercmdoff ) { $triggercmdoff = "" }
    my $disable = "";

    my %korrekt;
    foreach (@eventsall) {
        $korrekt{$_} = 'ok';
    }
    $korrekt{$triggeron}     = 'ok';
    $korrekt{$triggeroff}    = 'ok';
    $korrekt{$triggercmdon}  = 'ok';
    $korrekt{$triggercmdoff} = 'ok';

    my @eventsallnew;
    for my $name ( sort keys %korrekt ) {
        push( @eventsallnew, $name );
    }
    @eventsall = @eventsallnew;
    if ( AttrVal( $Name, 'MSwitch_Mode', 'Notify' ) eq "Notify" ) {
        $triggeroff = "";
        $triggeron  = "";
    }

    if ( AttrVal( $Name, 'MSwitch_Mode', 'Notify' ) eq "Dummy" ) {

        $triggeroff = "";
        $triggeron  = "";
    }

    if ( AttrVal( $Name, 'MSwitch_Mode', 'Notify' ) eq "Toggle" ) {
        $triggeroff    = "";
        $triggercmdoff = "";
        $triggercmdon  = "";
    }

    #eigene trigger festlegen
    my $optionon       = '';
    my $optiongeneral  = '';
    my $optioncmdon    = '';
    my $alltriggers    = '';
    my $scripttriggers = '';
    my $to             = '';
    my $toc            = '';
  LOOP12: foreach (@eventsall) {
        $alltriggers .= "<option value=\"$_\">" . $_ . "</option>";
        $scripttriggers .= "\"$_\": 1 ,";


	#MSwitch_LOG( $Name, 0,"fhemweb  $_  L:" . __LINE__ );




        if ( $_ eq 'no_trigger' ) {
            next LOOP12;
        }

        if ( $triggeron eq $_ ) {
            $optionon =
                $optionon
              . "<option selected=\"selected\" value=\'$_\'>"
              . $_
              . "</option>";
            $to = '1';
        }
        else {
            $optionon .= "<option value=\'$_\'>" . $_ . "</option>";
        }

        if ( $triggercmdon eq $_ ) {
            $optioncmdon =
                $optioncmdon
              . "<option selected=\"selected\" value=\'$_\'>"
              . $_
              . "</option>";
            $toc = '1';
        }
        else {
            $optioncmdon .= "<option value=\'$_\'>" . $_ . "</option>";
        }
####################  nur bei entsprechender regex
        # my $test = $_;

        # if ( $test =~ m/(.*)\((.*)\)(.*)/ ) 
		# {

            # #nothing
        # }
        # else
		# {
       
        # }

#####################
    }

    # selectfield aller verfügbaren events erstellen
    my @alloptions = @eventsall;
    push @alloptions, $triggeron, $triggeroff, $triggercmdoff, $triggercmdon;
    my %seen;
    @alloptions = grep { !$seen{$_}++ } @alloptions;

    #$optiongeneral ="";
    foreach my $op (@alloptions) {

        $op =~ s/\s+$//;
        $optiongeneral .= "<option value=\'$op\'>" . $op . "</option>";

    }

    chop($scripttriggers);

    if ( $to eq '1' ) {
        $optionon =
          "<option value=\"no_trigger\">no_trigger</option>" . $optionon;
    }
    else {
        $optionon =
"<option selected=\"selected\" value=\"no_trigger\">no_trigger</option>"
          . $optionon;
    }

    if ( $toc eq '1' ) {
        $optioncmdon =
          "<option value=\"no_trigger\">no_trigger</option>" . $optioncmdon;
    }
    else {
        $optioncmdon =
"<option selected=\"selected\" value=\"no_trigger\">no_trigger</option>"
          . $optioncmdon;
    }

    my $optioncmdoff = '';
    my $optionoff    = '';
    $to  = '';
    $toc = '';

  LOOP14: foreach (@eventsall) {
        if ( $_ eq 'no_trigger' ) { next LOOP14 }
        if ( $triggeroff eq $_ ) {
            $optionoff = $optionoff
              . "<option selected=\"selected\" value=\'$_\'>$_</option>";
            $to = '1';
        }
        else {
            $optionoff = $optionoff . "<option value=\'$_\'>$_</option>";
        }

        if ( $triggercmdoff eq $_ ) {
            $optioncmdoff = $optioncmdoff
              . "<option selected=\"selected\" value=\'$_\'>$_</option>";
            $toc = '1';
        }
        else {
            $optioncmdoff = $optioncmdoff . "<option value=\'$_\'>$_</option>";
        }
    }

    if ( $to eq '1' ) {
        $optionoff =
          "<option value=\"no_trigger\">no_trigger</option>" . $optionoff;
    }
    else {
        $optionoff =
"<option selected=\"selected\" value=\"no_trigger\">no_trigger</option>"
          . $optionoff;
    }

    if ( $toc eq '1' ) {
        $optioncmdoff =
          "<option value=\"no_trigger\">no_trigger</option>" . $optioncmdoff;
    }
    else {
        $optioncmdoff =
"<option selected=\"selected\" value=\"no_trigger\">no_trigger</option>"
          . $optioncmdoff;
    }

    $optionon =~ s/\[bs\]/|/g;
    $optionoff =~ s/\[bs\]/|/g;
    $optioncmdon =~ s/\[bs\]/|/g;
    $optioncmdoff =~ s/\[bs\]/|/g;
    $optiongeneral =~ s/\[bs\]/|/g;

####################
    # mögliche affected devices und mögliche triggerdevices
    my $devicesets;
    my $deviceoption = "";
    my $selected     = "";
    my $errors       = "";
    my $javaform     = "";    # erhält javacode für übergabe devicedetail
    my $cs           = "";
    my %cmdsatz;              # ablage desbefehlssatzes jedes devices
    my $globalon  = 'off';
    my $globalon1 = 'off';

    if ( ReadingsVal( $Name, '.Trigger_device', 'no_trigger' ) eq 'no_trigger' )
    {
        $triggerdevices =
"<option selected=\"selected\" value=\"no_trigger\">no_trigger</option>";
    }
    else {
        $triggerdevices = "<option  value=\"no_trigger\">no_trigger</option>";
    }

    if ( $expertmode eq '1' ) {

        if ( ReadingsVal( $Name, '.Trigger_device', 'no_trigger' ) eq
            'all_events' )
        {
            $triggerdevices .=
"<option selected=\"selected\" value=\"all_events\">GLOBAL</option>";
            $globalon = 'on';
        }
        else {
            $triggerdevices .= "<option  value=\"all_events\">GLOBAL</option>";
        }
    }

    if ( AttrVal( $Name, 'MSwitch_Read_Log', "0" ) eq '1' ) {
        if ( ReadingsVal( $Name, '.Trigger_device', 'no_trigger' ) eq 'Logfile' )
        {
            $triggerdevices .=
"<option selected=\"selected\" value=\"Logfile\">LOGFILE</option>";

            #$globalon = 'on';
        }
        else {
            $triggerdevices .= "<option  value=\"Logfile\">LOGFILE</option>";
        }
    }

    if (
        ReadingsVal( $Name, '.Trigger_device', 'no_trigger' ) eq 'MSwitch_Self' )
    {
        $triggerdevices .=
"<option selected=\"selected\" value=\"MSwitch_Self\">MSwitch_Self ($Name)</option>";
    }
    else {
        $triggerdevices .=
          "<option  value=\"MSwitch_Self\">MSwitch_Self ($Name)</option>";
    }


################# achtung doppelsplit


   my $affecteddevices = ReadingsVal( $Name, '.Device_Affected', 'no_device' );

   # affected devices to hash
   my %usedevices;
   my @deftoarray = split( /,/, $affecteddevices );
	
	#my @deftoarray = @affecteddevices;
	
	
    my $anzahl     = @deftoarray;
    my $anzahl1    = @deftoarray;
    my $anzahl3    = @deftoarray;
    my @testidsdev = split( /#\[ND\]/,
        ReadingsVal( $Name, '.Device_Affected_Details', 'no_device' ) );

    #PRIORITY
    # teste auf grössere PRIORITY als anzahl devices
    foreach (@testidsdev) {

        last if $_ eq "no_device";

        my @testid = split( /#\[NF\]/, $_ );
        my $x = 0;

        my $id = $testid[13];

        $anzahl = $id if $id > $anzahl;
    }

    my $reihenfolgehtml = "";
    if ( $expertmode eq '1' ) {
        $reihenfolgehtml = "<select name = 'reihe' id=''>";
        for ( my $i = 1 ; $i < $anzahl + 1 ; $i++ ) {
            $reihenfolgehtml .= "<option value='$i'>$i</option>";
        }
        $reihenfolgehtml .= "</select>";
    }

### display
    my $hidehtml = "";
    $hidehtml = "<select name = 'hidecmd' id=''>";
    $hidehtml .= "<option value='0'>0</option>";
    $hidehtml .= "<option value='1'>1</option>";
    $hidehtml .= "</select>";
#########################################
    # SHOW
    # teste auf grössere PRIORITY als anzahl devices
    foreach (@testidsdev) {

        my @testid = split( /#\[NF\]/, $_ );
        my $x = 0;

        my $id = $testid[18];
        if ( defined $id ) {

            $anzahl1 = $id if $id > $anzahl;
        }
    }

#################################
    my $showfolgehtml = "";
    $showfolgehtml = "<select name = 'showreihe' id=''>";
    for ( my $i = 1 ; $i < $anzahl1 + 1 ; $i++ ) {
        $showfolgehtml .= "<option value='$i'>$i</option>";
    }
    $showfolgehtml .= "</select>";
######################################
    #ID
    my $idfolgehtml = "";
    if ( $expertmode eq '1' ) {
        $idfolgehtml = "<select name = 'idreihe' id=''>";
        for ( my $i = -1 ; $i < $anzahl3 + 1 ; $i++ ) {
            $idfolgehtml .= "<option value='$i'>$i</option>" if $i > 0;
            $idfolgehtml .= "<option value='$i'>-</option>"  if $i == 0;
        }
        $idfolgehtml .= "</select>";
    }

    foreach (@deftoarray) {
        my ( $a, $b ) = split( /-/, $_ );
        $usedevices{$a} = 'on';
    }

    my $notype = AttrVal( $Name, 'MSwitch_Ignore_Types', "" );

    if (   AttrVal( $Name, 'MSwitch_Mode', 'Notify' ) eq "Dummy"
        && AttrVal( $Name, "MSwitch_Selftrigger_always", 0 ) eq "0" )
    {
        $notype = ".*";
    }

    my @found_devices;
    my $setpattern  = "";
    my $setpattern1 = "";

    ###### ersetzung ATTR oder READING
    if ( $notype =~ /(.*)\[(ATTR|READING):(.*):(.*)\](.*)/ ) {
        my $devname   = $3;
        my $firstpart = $1;
        my $lastpart  = $5;
        my $readname  = $4;
        my $type      = $2;
        $devname =~ s/\$SELF/$Name/;
        my $magic = ".*";
        $magic = AttrVal( $devname, $readname, ".*" ) if $type eq "ATTR";
        $magic = ReadingsVal( $devname, $readname, '.*' ) if $type eq "READING";
        $notype = $firstpart . $magic . $lastpart;
    }

    if ( $notype =~ /(")(.*)(")/ ) {
        my $reg = $2;
        if ( $reg =~ /(.*?)(s)(!=|=)([a-zA-Z]{1,10})(:?)(.*)/ ) {
            $reg         = $1 . $5 . $6;
            $setpattern1 = $4;
            $setpattern  = "=~" if ( $3 eq "=" );
            $setpattern  = "!=" if ( $3 eq "!=" );
            chop $reg if $6 eq "";
            $reg =~ s/::/:/g;
        }
        @found_devices = devspec2array("$reg");
    }
    else {
        $notype =~ s/ /|/g;
        @found_devices = devspec2array("TYPE!=$notype");
    }

    if ( $setpattern eq "=~" ) {
        my @found_devices_new;
        my $re = qr/$setpattern1/;
        for my $name (@found_devices) {
            my $cs = "set $name ?";
            my $errors = AnalyzeCommandChain( undef, $cs );
            if ( $errors =~ /$re/ ) {
                push @found_devices_new, $name;
            }
        }
        @found_devices = @found_devices_new;
    }

    if ( $setpattern eq "!=" ) {
        my @found_devices_new;
        my $re = qr/$setpattern1/;
        for my $name (@found_devices) {
            my $cs = "set $name ?";
            my $errors = AnalyzeCommandChain( undef, $cs );
            if ( $errors !~ /$re/ ) {
                push @found_devices_new, $name;
            }
        }
        @found_devices = @found_devices_new;
    }

    if ( !grep { $_ eq $Name } @found_devices ) {

        push @found_devices, $Name;
    }

    my $includewebcmd = AttrVal( $Name, 'MSwitch_Include_Webcmds', "1" );
    my $extensions    = AttrVal( $Name, 'MSwitch_Extensions',      "0" );
    my $MSwitchIncludeMSwitchcmds =
      AttrVal( $Name, 'MSwitch_Include_MSwitchcmds', "1" );
    my $MSwitchIncludeDevicecmds =
      AttrVal( $Name, 'MSwitch_Include_Devicecmds', "1" );
    my $Triggerdevicetmp = ReadingsVal( $Name, '.Trigger_device', '' );
    my $savecmds = AttrVal( $Name, 'MSwitch_DeleteCMDs', $deletesavedcmdsstandart );

  LOOP9: for my $name ( sort @found_devices ) {
	  
	 my @gefischt = grep( /$name/, @affectedklartext  ); 
	 # next LOOP9 if @gefischt <1;
	  
	  
	  
        my $selectedtrigger = '';
        my $devicealias = AttrVal( $name, 'alias', "" );
        my $devicewebcmd =
          AttrVal( $name, 'webCmd', "noArg" );    # webcmd des devices
        my $devicehash = $defs{$name};            #devicehash
        my $deviceTYPE = $devicehash->{TYPE};

        # triggerfile erzeugen

        if ( $Triggerdevicetmp eq $name ) {
            $selectedtrigger = 'selected=\"selected\"';
            if ( $name eq 'all_events' ) { $globalon = 'on' }
        }
        $triggerdevices .=
"<option $selectedtrigger value=\"$name\">$name (a:$devicealias t:$deviceTYPE)</option>";

        # filter auf argumente on oder off ;
        if ( $name eq '' ) { next LOOP9; }

        # abfrage und auswertung befehlssatz
        if ( $MSwitchIncludeDevicecmds eq '1' and $hash->{INIT} ne "define"  and  @gefischt > 0) {
            if ( exists $data{MSwitch}{devicecmds1}{$name}
                && $savecmds ne "nosave" )

            {
                $cmdfrombase = "1";
                $errors = $data{MSwitch}{devicecmds1}{$name};

            }
            else {
                $errors = getAllSets($name);
                if ( $savecmds ne "nosave" ) {
                    $data{MSwitch}{devicecmds1}{$name} = $errors;
                    $data{MSwitch}{last_devicecmd_save} = time;

                }
            }
        }
        else {
            $errors = '';
        }

        if ( !defined $errors ) {
            $errors = '';
        }

        $errors = '|' . $errors;
        $errors =~ s/\| //g;
        $errors =~ s/\|//g;

        if (    $includewebcmd eq '1'
            and $devicewebcmd ne "noArg"
            and $hash->{INIT} ne "define" )
        {
            my $device = '';
            my @webcmd = split( /:/, $devicewebcmd );
            foreach (@webcmd) {
                $_ =~ tr/ /:/;
                my @parts = split( /:/, $_ );
                if ( !defined $parts[1] || $parts[1] eq '' ) {
                    $device .= $parts[0] . ':noArg ';
                }
                else {
                    $device .= $parts[0] . ':' . $parts[1] . ' ';
                }
            }
            chop $device;
            $devicewebcmd = $device;
            $errors .= ' ' . $devicewebcmd;
        }

        if ( $MSwitchIncludeMSwitchcmds eq '1' and $hash->{INIT} ne "define" ) {
            my $usercmds = AttrVal( $name, 'MSwitchcmd', '' );
            if ( $usercmds ne '' ) {
                $usercmds =~ tr/:/ /;
                $errors .= ' ' . $usercmds;
            }
        }

        if ( $extensions eq '1' ) {
            $errors .= ' ' . 'MSwitchtoggle';
        }

        $errors .= ' ' . '[FREECMD]:textfieldLong';

        if ( $errors ne '' ) {
            $selected = "";
            if ( exists $usedevices{$name} && $usedevices{$name} eq 'on' ) {
                $selected = "selected=\"selected\" ";
            }
            $deviceoption =
                $deviceoption
              . "<option "
              . $selected
              . "value=\""
              . $name . "\">"
              . $name . " (a:"
              . $devicealias
              . ")</option>";

            # befehlssatz für device in scalar speichern
            $cmdsatz{$name} = $errors;
        }
        else {
            #nothing
        }
    }

    my $select = index( $affecteddevices, 'FreeCmd', 0 );
    $selected = "";
    if ( $select > -1 ) { $selected = "selected=\"selected\" " }
    $deviceoption =
        "<option "
      . "value=\"FreeCmd\" "
      . $selected
      . ">Free Cmd (nicht an ein Device gebunden)</option>"
      . $deviceoption;

    $select = index( $affecteddevices, 'MSwitch_Self', 0 );
    $selected = "";
    if ( $select > -1 ) { $selected = "selected=\"selected\" " }
    $deviceoption =
        "<option "
      . "value=\"MSwitch_Self\" "
      . $selected
      . ">MSwitch_Self ("
      . $Name
      . ")</option>"
      . $deviceoption;

    my @areadings = ( keys %{ $data{MSwitch}{$Name}{groups} } );

    foreach my $key (@areadings) {
        my $fullname = $key;
        my $re       = qr/$fullname/;
        my @test     = grep ( /$re/, @deftoarray );

        $selected = "";
        if ( @test > 0 ) {
            $selected = "selected=\"selected\" ";
        }

        $deviceoption =
            $deviceoption
          . "<option "
          . $selected
          . "value=\""
          . $key . "\">"
          . $key . " (a:"
          . "MSwitch Gruppe"
          . ")</option>";
    }

####################
    # #devices details
    # steuerdatei
    my $controlhtml;
    $controlhtml = "
<!-- folgende HTML-Kommentare dürfen nicht gelöscht werden -->
<!-- 
info: festlegung einer zellenhöhe
MS-cellhigh=30;
-->
<!-- 
start:textersetzung:ger
Set->Schaltbefehl
Hidden command branches are available->Ausgeblendete Befehlszweige vorhanden
condition:->Schaltbedingung
show hidden cmds->ausgeblendete Befehlszweige anzeigen
show IDs->zeige Befehlszweige mit der ID
execute and exit if applies->Abbruch nach Ausführung
Repeats:->Befehlswiederholungen:
Repeatdelay in sec:->Wiederholungsverzögerung in Sekunden:
delay with Cond-check immediately and delayed:->Verzögerung mit Bedingungsprüfung sofort und vor Ausführung:
delay with Cond-check immediately only:->Verzögerung mit Bedingungsprüfung sofort:
delay with Cond-check delayed only:->Verzögerung mit Bedingungsprüfung vor Ausführung:
at with Cond-check immediately and delayed:->Ausführungszeit mit Bedingungsprüfung sofort und vor Ausführung:
at with Cond-check immediately only:->Ausführungszeit mit Bedingungsprüfung sofort:
at with Cond-check delayed only->Ausführungszeit mit Bedingungsprüfung vor Ausführung:
with Cond-check->Schaltbedingung vor jeder Ausführung prüfen
check condition->Bedingung testen
with->mit
modify Actions->Befehle speichern
device actions sortby:->Sortierung:
add action for->zusätzliche Aktion für
delete this action for->lösche diese Aktion für
priority:->Priorität:
displaysequence:->Anzeigereihenfolge:
hide display->Anzeige verbergen
test comand->Befehl testen
end:textersetzung:ger
-->
<!-- 
start:textersetzung:eng
end:textersetzung:eng
-->
<!--
MS-cellhighstandart
MS-cellhighexpert
MS-cellhighdebug
MS-IDSATZ
MS-NAMESATZMS-ACTIONSATZ
MS-SET1
MS-SET2
MS-COND1
MS-COND2
MS-EXEC1
MS-EXEC2
MS-DELAYset1
MS-DELAYset2
MS-REPEATset
MS-COMMENTset
MS-HELPpriority
MS-HELPonoff
MS-HELPcondition
MS-HELPexit
MS-HELPtimer
MS-HELPrepeats
MS-HELPexeccmd
MS-HELPdelay
--> 



<!-- start htmlcode -->
<!--start devices -->


<table border='0' class='block wide' id='MSwitchWebTR' nm='test1' cellpadding='4' style='border-spacing:0px;'>
	<tr>
		<td style='height: MS-cellhighstandart;width: 100%;' colspan='3'>
		<table style='width: 100%'>
			<tr>
				<td>MS-NAMESATZ</td>
				<td align=right>MS-HELPpriority&nbsp;MS-IDSATZ</td>
			</tr>
		</table>
		</td>
	</tr>
	<tr>
		<td colspan='3'>MS-COMMENTset</td>
	</tr>
	<tr>
		<td rowspan='6'>CMD&nbsp;1&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>
		<td colspan='2'></td>
	</tr>
	<tr>
		<td>MS-HELPonoff</td>
		<td style='height: MS-cellhighstandart;width: 100%;'>MS-SET1</td>
	</tr>
	<tr>
		<td>MS-HELPcondition</td>
		<td style='height: MS-cellhighstandart;width: 100%'>MS-COND1</td>
	</tr>
	<tr>
		<td></td>
		<td style='height: MS-cellhighdebug;width: 100%'>MS-TEST-1MS-CONDCHECK1</td>
	</tr>
	<tr>
		<td>MS-HELPexeccmd</td>
		<td style='height: MS-cellhighexpert;width: 100%'>MS-EXEC1</td>
	</tr>
	<tr>
		<td>MS-HELPdelay</td>
		<td style='height: MS-cellhighexpert;width: 100%'>MS-DELAYset1</td>
	</tr>
	<tr>
		<td rowspan='7'>CMD&nbsp;2&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>
		<td colspan='2'><hr noshade='noshade' style='height: 1px'></td>
	</tr>
	<tr>
		<td>MS-HELPonoff</td>
		<td style='height: MS-cellhighstandart;width: 100%'>MS-SET2</td>
	</tr>
	<tr>
		<td>MS-HELPcondition</td>
		<td style='height: MS-cellhighstandart;width: 100%'>MS-COND2</td>
	</tr>
	<tr>
		<td></td>
		<td style='height: MS-cellhighdebug;width: 100%'>MS-TEST-2MS-CONDCHECK2</td>
	</tr>
	<tr>
		<td>MS-HELPexeccmd</td>
		<td style='height: MS-cellhighexpert;width: 100%'>MS-EXEC2</td>
	</tr>
	<tr>
		<td>MS-HELPdelay</td>
		<td style='height: MS-cellhighexpert;width: 100%;'>MS-DELAYset2</td>
	</tr>
	<tr>
		<td colspan='2'></td>
	</tr>
	<tr>
		<td style='height: MS-cellhighexpert;'colspan='3'>MS-HELPrepeats&nbsp;MS-REPEATset</td>
	</tr>
	<tr>
		<td style='height: MS-cellhighstandart;'colspan='3'>&nbsp;MS-ACTIONSATZ</td>
	</tr>
</table>
<br>
<!-- end devices-->

";


    $controlhtml = AttrVal( $Name, 'MSwitch_Develop_Affected', $controlhtml );
	
    #### extrakt ersetzung
    my $extrakt = $controlhtml;
    $extrakt =~ s/\n/#/g;
    my $extrakthtml = $extrakt;

    # umstellen auf globales attribut !!!!!!
    if (
        AttrVal(
            $Name, 'MSwitch_Language',
            AttrVal( 'global', 'language', 'EN' )
        ) eq "DE"
      )
    {
        $extrakt =~ m/start:textersetzung:ger(.*)end:textersetzung:ger/;
        $extrakt = $1;
    }
    else {
        $extrakt =~ m/start:textersetzung:eng(.*)end:textersetzung:eng/;
        $extrakt = $1;
    }

    my @translate;
    if ( defined $extrakt ) {
        $extrakt =~ s/^.//;
        $extrakt =~ s/.$//;
        @translate = split( /#/, $extrakt );
    }


    $controlhtml =~ m/MS-cellhigh=(.*);/;
    my $cellhight       = $1 . "px";
    my $cellhightexpert = $1 . "px";
    my $cellhightdebug  = $1 . "px";

    $extrakthtml =~ m/<!-- start htmlcode -->(.*)/;
    $controlhtml = $1;
    $controlhtml =~ s/#/\n/g;

    # detailsatz in scalar laden
    my %savedetails = MSwitch_makeCmdHash($Name);
    my $detailhtml  = "";
	
    #my @affecteddevices = split( /,/, ReadingsVal( $Name, '.Device_Affected', 'no_device' ) );
#####################################

    if ( $expertmode eq '1'
        && ReadingsVal( $Name, '.sortby', 'none' ) eq 'priority' )
    {
        #sortieren
        my $typ = "_priority";
        @affecteddevices = MSwitch_sort( $hash, $typ, @affecteddevices );
    }

    if ( ReadingsVal( $Name, '.sortby', 'none' ) eq 'show' ) {

        #sortieren
        my $typ = "_showreihe";
        @affecteddevices = MSwitch_sort( $hash, $typ, @affecteddevices );
    }

######################################class='block wide'
    if (   AttrVal( $Name, 'MSwitch_Mode', 'Notify' ) eq "Dummy"
        && AttrVal( $Name, "MSwitch_Selftrigger_always", 0 ) eq "0" )
    {
        $affecteddevices[0] = 'no_device';
    }
    my $sortierung = "";
    my $modify     = "";
    my $IDsatz     = "";
    my $NAMEsatz   = "";
    my $ACTIONsatz = "";
    my $SET1       = "";
    my $SET2       = "";
    my $COND1set1  = "";
    my $COND1check1 = "";
    my $COND2check2 = "";
    my $COND1set2  = "";
    my $EXECset1   = "";
    my $EXECset2   = "";
    my $DELAYset1  = "";
    my $DELAYset2  = "";
    my $REPEATset  = "";
    my $COMMENTset = "";
    my $HELPpriority  = "";
    my $HELPonoff     = "";
    my $HELPcondition = "";
    my $HELPexit      = "";
    my $HELPtimer     = "";
    my $HELPrepeats   = "";
    my $HELPexeccmd   = "";
    my $HELPdelay     = "";

    if ( AttrVal( $Name, 'MSwitch_Help', "0" ) eq '1' ) {
        $HELPpriority =
"<input name='info' type='button' value='?' onclick=\"hilfe('priority')\">";
        $HELPonoff =
"<input name='info' type='button' value='?' onclick=\"hilfe('onoff')\">";
        $HELPcondition =
"<input name='info' type='button' value='?' onclick=\"hilfe('condition')\">";
        $HELPexit =
"<input name='info' type='button' value='?' onclick=\"hilfe('exit')\">";
        $HELPtimer =
"<input name='info' type='button' value='?' onclick=\"hilfe('timer')\">";
        $HELPrepeats =
"<input name='info' type='button' value='?' onclick=\"hilfe('repeats')\">";
        $HELPexeccmd =
"<input name='info' type='button' value='?' onclick=\"hilfe('execcmd')\">";
        $HELPdelay =
"<input name='info' type='button' value='?' onclick=\"hilfe('timer')\">";
    }

    if ( $affecteddevices[0] ne 'no_device' ) {
        #######################   sortierungsblock
        $sortierung = "";
        if ( $hash->{INIT} ne 'define' ) {
            $sortierung .= "
			device actions sortby:
			<input type='hidden' id='affected' name='affected' size='40'  value ='"
              . ReadingsVal( $Name, '.Device_Affected', 'no_device' ) . "'>";

            my $select = ReadingsVal( $Name, '.sortby', 'none' );

            if ( $expertmode ne '1' && $select eq 'priority' ) {
                $select = 'none';
                readingsSingleUpdate( $hash, ".sortby", $select, 0 );
            }

            my $nonef     = "";
            my $priorityf = "";
            my $showf     = "";
            $nonef     = 'selected="selected"' if $select eq 'none';
            $priorityf = 'selected="selected"' if $select eq 'priority';
            $showf     = 'selected="selected"' if $select eq 'show';

            $sortierung .=
'<select name="sort" id="sort" onchange="changesort()" ><option value="none" '
              . $nonef
              . '>None</option>';

            if ( $expertmode eq '1' ) {
                $sortierung .= '
                <option value="priority" '
                  . $priorityf . '>Field Priority</option>';
            }
            $sortierung .=
              '<option value="show" ' . $showf . '>Field Show</option>';
        }
#################################

        $modify =
"<table width = '100%' border='0' class='block wide' id='MSwitchDetails' cellpadding='4' style='border-spacing:0px;' nm='MSwitch'>
			<tr class='even'><td>
			<input type='button' id='aw_det' value='modify Actions' >&nbsp;$sortierung
			</td></tr></table>
			";

##########################
        # $detailhtml .= $sortierung;
##########################

        my $alert;
        foreach (@affecteddevices) {
            $IDsatz     = "";
            $ACTIONsatz = "";
            $COND1set1  = "";
            $COND1set2  = "";
            $EXECset1   = "";
            $EXECset2   = "";
            $COMMENTset = "";

            my $nopoint = $_;
            $nopoint =~ s/\./point/g;
            $alert = '';
            my @devicesplit = split( /-AbsCmd/, $_ );
            my $devicenamet = $devicesplit[0];

            my $re = qr/$devicenamet/;

            my @test = grep ( /$re/, @deftoarray );

            # prüfe auf nicht vorhandenes device
            if (
                   $devicenamet ne "FreeCmd"
                && $devicenamet ne "MSwitch_Self"
                && !defined $cmdsatz{$devicenamet}
                && !
                grep ( /$re/, @deftoarray )

              )
            {
                $alert =
'<div style="color: #FF0000">Achtung: Dieses Device ist nicht vorhanden , bitte mit "set changed_renamed" korrigieren !</div>';
                $cmdsatz{$devicenamet} = $savedetails{ $_ . '_on' } . " "
                  . $savedetails{ $_ . '_off' };
            }
            my $zusatz = "";
            my $add    = $devicenamet;
            if ( $devicenamet eq "MSwitch_Self" ) {
                $devicenamet = $Name;
                $zusatz      = "MSwitch_Self -> ";
                $add         = "MSwitch_Self";
            }

            if ( grep( /$re/, @msgruppen ) > 0 ) {

                my $gruppencmd = MSwitch_makegroupcmd( $hash, $devicenamet );
                $cmdsatz{$devicenamet} =
                  $gruppencmd . ' [FREECMD]:textfieldLong';
            }

            my $devicenumber = $devicesplit[1];
            my @befehlssatz  = '';
            if ( $devicenamet eq "FreeCmd" ) {
                $cmdsatz{$devicenamet} = '';
            }

            @befehlssatz = split( / /, $cmdsatz{$devicenamet} ) if exists $cmdsatz{$devicenamet};
            my $aktdevice = $_;
            ## optionen erzeugen
            my $option1html  = '';
            my $option2html  = '';
            my $selectedhtml = "";


			

            foreach (@befehlssatz)    #befehlssatz einfügen
            {
                my @aktcmdset =
                  split( /:/, $_ );    # befehl von noarg etc. trennen
                $selectedhtml = "";
                next if !defined $aktcmdset[0];    #changed 19.06
                if ( $aktcmdset[0] eq $savedetails{ $aktdevice . '_on' } ) {
                    $selectedhtml = "selected=\"selected\"";
                }
                $option1html .="<option $selectedhtml value=\"$aktcmdset[0]\">$aktcmdset[0]</option>";
                $selectedhtml = "";
                if ( $aktcmdset[0] eq $savedetails{ $aktdevice . '_off' } ) {
                    $selectedhtml = "selected=\"selected\"";
                }
                $option2html .="<option $selectedhtml value=\"$aktcmdset[0]\">$aktcmdset[0]</option>";
            }



            $savedetails{ $aktdevice . '_onarg' } =~ s/#\[ti\]/~/g;
            $savedetails{ $aktdevice . '_offarg' } =~ s/#\[ti\]/~/g;
            $savedetails{ $aktdevice . '_onarg' } =~ s/#\[wa\]/|/g;     #neu
            $savedetails{ $aktdevice . '_offarg' } =~ s/#\[wa\]/|/g;    #neu

            $savedetails{ $aktdevice . '_onarg' } =~ s/#\[SR\]/|/g;
            $savedetails{ $aktdevice . '_offarg' } =~ s/#\[SR\]/|/g;
            $savedetails{ $aktdevice . '_onarg' } =~ s/#\[SR\]/|/g;     #neu
            $savedetails{ $aktdevice . '_offarg' } =~ s/#\[SR\]/|/g;    #neu

            my $dalias = '';
            if ( $devicenamet ne "FreeCmd" ) {
                $dalias = "(a: " . AttrVal( $devicenamet, 'alias', "no" ) . ")"
                  if AttrVal( $devicenamet, 'alias', "no" ) ne "no";
            }

            my $realname = '';
            if ( AttrVal( $Name, 'MSwitch_Debug', "0" ) eq '4' ) {
                $realname =
                    "<input id='' name='devicename"
                  . $nopoint
                  . "' size='20'  value ='"
                  . $_ . "'>";
            }
            else {
                $realname =
                    "<input type='$hidden' id='' name='devicename"
                  . $nopoint
                  . "' size='20'  value ='"
                  . $_ . "'>";
            }

            my $groupbutton = "";

            if ( grep( /$re/, @msgruppen ) > 0 ) {
                $groupbutton =
"<input type='button' id='' value='showdevices' onclick=\"javascript:showgroup('"
                  . $devicenamet
                  . "')\";>";

            }

            if ( $expertmode eq '1' ) {
                $NAMEsatz =
"$zusatz $devicenamet $realname&nbsp;&nbsp;$groupbutton&nbsp;&nbsp;$dalias $alert";

###################### priority

                my $aktfolge = $reihenfolgehtml;
                my $newname  = "reihe" . $nopoint;
                my $tochange =
"<option value='$savedetails{ $aktdevice . '_priority' }'>$savedetails{ $aktdevice . '_priority' }</option>";
                my $change =
"<option selected value='$savedetails{ $aktdevice . '_priority' }'>$savedetails{ $aktdevice . '_priority' }</option>";
                $aktfolge =~ s/reihe/$newname/g;
                $aktfolge =~ s/$tochange/$change/g;
                $IDsatz = "priority: " . $aktfolge . "&nbsp;";

                # ende
                # show
                # showfolgehtml

                $aktfolge = $showfolgehtml;
                $newname  = "showreihe" . $nopoint;
                $tochange =
"<option value='$savedetails{ $aktdevice . '_showreihe' }'>$savedetails{ $aktdevice . '_showreihe' }</option>";
                $change =
"<option selected value='$savedetails{ $aktdevice . '_showreihe' }'>$savedetails{ $aktdevice . '_showreihe' }</option>";
                $aktfolge =~ s/showreihe/$newname/g;
                $aktfolge =~ s/$tochange/$change/g;
                $IDsatz .= "displaysequence: " . $aktfolge . "&nbsp;"
                  if ( $hash->{INIT} ne 'define' );
####
                # ID
                $aktfolge = $idfolgehtml;
                $newname  = "idreihe" . $nopoint;
                $tochange =
"<option value='$savedetails{ $aktdevice . '_id' }'>$savedetails{ $aktdevice . '_id' }</option>";
                $change =
"<option selected value='$savedetails{ $aktdevice . '_id' }'>$savedetails{ $aktdevice . '_id' }</option>";
                $aktfolge =~ s/idreihe/$newname/g;
                $aktfolge =~ s/$tochange/$change/g;
                $IDsatz .= "ID: " . $aktfolge;

                $aktfolge = $hidehtml;
                $newname  = "hidecmd" . $nopoint;
                $tochange =
                  "<option value='$savedetails{ $aktdevice . '_hidecmd' }'>";
                $change =
"<option selected value='$savedetails{ $aktdevice . '_hidecmd' }'>";
                $aktfolge =~ s/hidecmd/$newname/g;
                $aktfolge =~ s/$tochange/$change/g;
                $IDsatz .= "hide display: " . $aktfolge . "&nbsp;"
                  if ( $hash->{INIT} ne 'define' );

                # ende
            }
            else {

                $NAMEsatz =
"$zusatz $devicenamet $realname&nbsp;&nbsp;$groupbutton&nbsp;&nbsp;$dalias $alert";
                my $aktfolge = $showfolgehtml;
                my $newname  = "showreihe" . $nopoint;
                my $tochange =
"<option value='$savedetails{ $aktdevice . '_showreihe' }'>$savedetails{ $aktdevice . '_showreihe' }</option>";
                my $change =
"<option selected value='$savedetails{ $aktdevice . '_showreihe' }'>$savedetails{ $aktdevice . '_showreihe' }</option>";
                $aktfolge =~ s/showreihe/$newname/g;
                $aktfolge =~ s/$tochange/$change/g;
                $IDsatz .= "displaysequence: " . $aktfolge . "&nbsp;"
                  if ( $hash->{INIT} ne 'define' );

                $aktfolge = $hidehtml;
                $newname  = "hidecmd" . $nopoint;
                $tochange =
                  "<option value='$savedetails{ $aktdevice . '_hidecmd' }'>";
                $change =
"<option selected value='$savedetails{ $aktdevice . '_hidecmd' }'>";
                $aktfolge =~ s/hidecmd/$newname/g;
                $aktfolge =~ s/$tochange/$change/g;
                $IDsatz .= "hide display: " . $aktfolge . "&nbsp;"
                  if ( $hash->{INIT} ne 'define' );

            }

##### bis hier ok hier ist nach überschrift
##### kommentare
            my $noschow = "style=\"display:none\"";
            if ( AttrVal( $Name, 'MSwitch_Comments', "0" ) eq '1' ) {
                $noschow = '';
            }

            #kommentar
            if ( AttrVal( $Name, 'MSwitch_Comments', "0" ) eq '1' ) {
                my @a = split( /\n/, $savedetails{ $aktdevice . '_comment' } );
                my $lines = @a;
                $lines = 1 if $lines == 0;

                $COMMENTset =
"<textarea rows=\"$lines\" style=\"width:97%;\"  id='cmdcomment"
                  . $_
                  . "1' name='cmdcomment"
                  . $nopoint . "'>"
                  . $savedetails{ $aktdevice . '_comment' }
                  . "</textarea>";
            }

            if ( $devicenamet ne 'FreeCmd' ) {

                # nicht freecmd
                $SET1 = "<table border ='0'><tr><td>
			Set <select class=\"devdetails2\" id='"
                  . $_
                  . "_on' name='cmdon"
                  . $nopoint
                  . "' onchange=\"javascript: activate(document.getElementById('"
                  . $_
                  . "_on').value,'"
                  . $_
                  . "_on_sel','"
                  . $cmdsatz{$devicenamet}
                  . "','cmdonopt"
                  . $_
                  . "1')\" >
					<option value='no_action'>no_action</option>" . $option1html . "</select>
					</td>
					<td><input type='$hidden' id='cmdseton"
                  . $_
                  . "' name='cmdseton"
                  . $nopoint
                  . "' size='30'  value ='"
                  . $cmdsatz{$devicenamet} . "'>
					<input type='$hidden' id='cmdonopt"
                  . $_
                  . "1' name='cmdonopt"
                  . $nopoint
                  . "' size='10'  value ='"
                  . $savedetails{ $aktdevice . '_onarg' } . "'>
					  </td><td nowrap id='" . $_ . "_on_sel'>
					  </td></tr></table>
					  ";
            }
            else {
                # freecmd
                $savedetails{ $aktdevice . '_onarg' } =~ s/'/&#039/g;
                $SET1 =
"<textarea onclick=\"javascript: checklines(id+'$_')\" rows='10' id='cmdonopt' style=\"width:97%;\" "
                  . $_
                  . "1' name='cmdonopt"
                  . $nopoint . "'
				>" . $savedetails{ $aktdevice . '_onarg' } . "</textarea>";
                "<input type='$hidden' id='"
                  . $_
                  . "_on' name='cmdon"
                  . $nopoint
                  . "' size='20'  value ='cmd'>
				<input type='$hidden' id='cmdseton"
                  . $_
                  . "' name='cmdseton"
                  . $nopoint
                  . "' size='20'  value ='cmd'>
				<span  style='text-align: left;' class='col2' nowrap id='" . $_
                  . "_on_sel'>	</span>			  ";
            }

########################
## block off #$devicename

            if ( $devicenamet ne 'FreeCmd' )
			{
                $SET2 = "<table border ='0'><tr><td>
						Set <select class=\"devdetails2\" id='"
                  . $_
                  . "_off' name='cmdoff"
                  . $nopoint
                  . "' onchange=\"javascript: activate(document.getElementById('"
                  . $_
                  . "_off').value,'"
                  . $_
                  . "_off_sel','"
                  . $cmdsatz{$devicenamet}
                  . "','cmdoffopt"
                  . $_
                  . "1')\" >
						<option value='no_action'>no_action</option>" . $option2html . "</select>
						</td><td>
						<input type='$hidden' id='cmdsetoff"
                  . $_
                  . "' name='cmdsetoff"
                  . $nopoint
                  . "' size='10'  value ='"
                  . $cmdsatz{$devicenamet} . "'>
						<input type='$hidden'   id='cmdoffopt"
                  . $_
                  . "1' name='cmdoffopt"
                  . $nopoint
                  . "' size='10' value ='"
                  . $savedetails{ $aktdevice . '_offarg' } . "'>
                      </td><td nowrap id='" . $_ . "_off_sel' >
					  </td></tr></table>
					  ";

                if (   $debugmode  eq '1'|| $debugmode  eq '3' )
                {
                     # $MSTEST1 =
                         # "<input name='info' name='TestCMD"
                       # . $_
                       # . "' id='TestCMD"
                       # . $_
                       # . "'type='button' value='test comand' onclick=\"javascript: testcmd('cmdon$nopoint','$devicenamet','cmdonopt$nopoint','teston')\">";


$MSTEST1 = "<input name='info' name='TestCMD". $_. "' id='TestCMD". $_
            . "'type='button' value='test comand' onclick=\"javascript: testcmd('cmdon$nopoint','$devicenamet','cmdonopt$nopoint',document.querySelector('#checkon".$_. "').value )\">";
				
				
				
				
				
                     # $MSTEST2 =
                         # "<input name='info' name='TestCMD"
                       # . $_
                       # . "' id='TestCMD"
                       # . $_
                       # . "'type='button' value='test comand' onclick=\"javascript: testcmd('cmdoff$nopoint','$devicenamet','cmdoffopt$nopoint','testoff')\">";
               


$MSTEST2 = "<input name='info' name='TestCMD". $_. "' id='TestCMD". $_
            . "'type='button' value='test comand' onclick=\"javascript: testcmd('cmdoff$nopoint','$devicenamet','cmdoffopt$nopoint',document.querySelector('#checkoff".$_. "').value )\">";
				
			
					





			   }

            }
            else 
			{
                $savedetails{ $aktdevice . '_offarg' } =~ s/'/&#039/g;

                $SET2 =
"<textarea onclick=\"javascript: checklines(id+'$_')\" rows='10' id='cmdoffopt' style=\"width:97%;\""
                  . $_
                  . "1' name='cmdoffopt"
                  . $_ . "'
							>" . $savedetails{ $aktdevice . '_offarg' } . "</textarea>
							<span style='text-align: left;' class='col2' nowrap id='" . $_
                  . "_off_sel' ></span>
							<input type='$hidden' id='"
                  . $_
                  . "_off' name='cmdoff"
                  . $_
                  . "' size='20'  value ='cmd'></td>
							<td  class='col2' nowrap>
							<input type='$hidden' id='cmdsetoff"
                  . $_
                  . "' name='cmdsetoff"
                  . $_
                  . "' size='20'  value ='cmd'>";

                if (  $debugmode  eq '1' || $debugmode  eq '3' )
                {
                    # $MSTEST1 =
                        # "<input name='info' name='TestCMD"
                      # . $_
                      # . "' id='TestCMD"
                      # . $_
                      # . "'type='button' value='test comand' onclick=\"javascript: testcmd('cmdonopt$nopoint','$devicenamet','cmdonopt$nopoint',document.querySelector('#checkon".$_. "').value )\">";




$MSTEST1 = "<input name='info' name='TestCMD". $_. "' id='TestCMD". $_
            . "'type='button' value='test comand' onclick=\"javascript: testcmd('cmdonopt$nopoint','$devicenamet','cmdonopt$nopoint',document.querySelector('#checkon".$_. "').value )\">";
				
				
			





                    # $MSTEST2 =
                        # "<input name='info' name='TestCMD"
                      # . $_
                      # . "' id='TestCMD"
                      # . $_
                      # . "'type='button' value='test comand' onclick=\"javascript: testcmd('cmdoffopt$nopoint','$devicenamet','tesofffree')\">";


$MSTEST1 = "<input name='info' name='TestCMD". $_. "' id='TestCMD". $_
            . "'type='button' value='test comand' onclick=\"javascript: testcmd('cmdonopt$nopoint','$devicenamet','not_in_use',document.querySelector('#checkon".$_. "').value )\">";
				
		

$MSTEST2 = "<input name='info' name='TestCMD". $_. "' id='TestCMD". $_
            . "'type='button' value='test comand' onclick=\"javascript: testcmd('cmdoffopt$nopoint','$devicenamet','not_in_use',document.querySelector('#checkoff".$_. "').value )\">";
				
				
			              
				
									   
				}
            }

            $COND1set1 =
"condition: <input class=\"devdetails\" type='text' id='conditionon"
              . $_
              . "' name='conditionon"
              . $nopoint
              . "' size='55' value ='"
              . $savedetails{ $aktdevice . '_conditionon' }
              . "' onClick=\"javascript:bigwindow(this.id);\">";

            my $exit1 = '';
            $exit1 = 'checked'
              if ( defined $savedetails{ $aktdevice . '_exit1' }
                && $savedetails{ $aktdevice . '_exit1' } eq '1' );

            if ( $expertmode eq '1' ) {
                $EXECset1 =
                    "<input type=\"checkbox\" $exit1 name='exit1"
                  . $nopoint
                  . "' /> execute and exit if applies";
            }
            else {
                $EXECset1 .=
                  "<input hidden type=\"checkbox\" $exit1 name='exit1"
                  . $nopoint . "' /> ";
            }

            if (   AttrVal( $Name, 'MSwitch_Debug', "0" ) eq '1'
                || AttrVal( $Name, 'MSwitch_Debug', "0" ) eq '3' )
            {
                $COND1check1 =
"<input name='info' type='button' value='check condition' onclick=\"javascript: checkcondition('conditionon"
                  . $_
                  . "',document.querySelector('#checkon"
                  . $_
                  . "').value)\"> with \$EVENT=<select id = \"checkon"
                  . $_
                  . "\" name=\"checkon"
                  . $_ . "\">"
                  . $optiongeneral
                  . "</select>";

            }

            #$aktdevicename
            #alltriggers

            $COND1set2 .=
"condition: <input class=\"devdetails\" type='text' id='conditionoff"
              . $_
              . "' name='conditionoff"
              . $nopoint
              . "' size='55' value ='"
              . $savedetails{ $aktdevice . '_conditionoff' }
              . "' onClick=\"javascript:bigwindow(this.id);\">";

            my $exit2 = '';
            $exit2 = 'checked'
              if ( defined $savedetails{ $aktdevice . '_exit2' }
                && $savedetails{ $aktdevice . '_exit2' } eq '1' );
            if ( $expertmode eq '1' ) {
                $EXECset2 =
                    "<input type=\"checkbox\" $exit2 name='exit2"
                  . $nopoint
                  . "' /> execute and exit if applies";
            }
            else {
                $EXECset2 .=
                  "<input hidden type=\"checkbox\" $exit2 name='exit1"
                  . $nopoint . "' /> ";
            }

            if (   AttrVal( $Name, 'MSwitch_Debug', "0" ) eq '1'
                || AttrVal( $Name, 'MSwitch_Debug', "0" ) eq '3' )
            {
                $COND2check2 =
"<input name='info' type='button' value='check condition' onclick=\"javascript: checkcondition('conditionoff"
                  . $_
                  . "',document.querySelector('#checkoff"
                  . $_
                  . "').value)\"> with \$EVENT=<select id = \"checkoff"
                  . $_
                  . "\" name=\"checkoff"
                  . $_ . "\">"
                  . $optiongeneral
                  . "</select>";
            }

            #### zeitrechner    ABSATZ UAF NOTWENDIGKEIT PRÜF
            my $delaym = 0;
            my $delays = 0;
            my $delayh = 0;
            my $timestroff;
            my $testtimestroff = $savedetails{ $aktdevice . '_timeoff' };
            $timestroff = $savedetails{ $aktdevice . '_timeoff' };
            my $timestron;
            my $testtimestron = $savedetails{ $aktdevice . '_timeon' };
            $timestron = $savedetails{ $aktdevice . '_timeon' };
            #########################################

            $DELAYset1 = "<select id = '' name='onatdelay" . $nopoint . "'>";

            my $se11    = '';
            my $sel2    = '';
            my $sel3    = '';
            my $sel4    = '';
            my $sel5    = '';
            my $sel6    = '';
            my $testkey = $aktdevice . '_delaylaton';

            $se11 = 'selected'
              if ( $savedetails{ $aktdevice . '_delayaton' } eq "delay1" );
            $sel2 = 'selected'
              if ( $savedetails{ $aktdevice . '_delayaton' } eq "delay0" );
            $sel5 = 'selected'
              if ( $savedetails{ $aktdevice . '_delayaton' } eq "delay2" );
            $sel4 = 'selected'
              if ( $savedetails{ $aktdevice . '_delayaton' } eq "at0" );
            $sel3 = 'selected'
              if ( $savedetails{ $aktdevice . '_delayaton' } eq "at1" );
            $sel6 = 'selected'
              if ( $savedetails{ $aktdevice . '_delayaton' } eq "at2" );

            $DELAYset1 .=
"<option $se11 value='delay1'>delay with Cond-check immediately and delayed:</option>";
            $DELAYset1 .=
"<option $sel2 value='delay0'>delay with Cond-check immediately only:</option>";
            $DELAYset1 .=
"<option $sel5 value='delay2'>delay with Cond-check delayed only:</option>";
            $DELAYset1 .=
"<option $sel4 value='at0'>at with Cond-check immediately and delayed:</option>";
            $DELAYset1 .=
"<option $sel3 value='at1'>at with Cond-check immediately only:</option>";
            $DELAYset1 .=
"<option $sel6 value='at0'>at with Cond-check delayed only:</option>";
            $DELAYset1 .=
              "	</select><input type='text' class=\"devdetails\" id='timeseton"
              . $_
              . "' name='timeseton"
              . $nopoint
              . "' size='15' value ='"
              . $timestron . "'>";

            $DELAYset2 = "<select id = '' name='offatdelay" . $nopoint . "'>";

            $se11    = '';
            $sel2    = '';
            $sel3    = '';
            $sel4    = '';
            $sel5    = '';
            $sel6    = '';
            $testkey = $aktdevice . '_delaylatoff';

            $se11 = 'selected'
              if ( $savedetails{ $aktdevice . '_delayatoff' } eq "delay1" );
            $sel2 = 'selected'
              if ( $savedetails{ $aktdevice . '_delayatoff' } eq "delay0" );
            $sel5 = 'selected'
              if ( $savedetails{ $aktdevice . '_delayatoff' } eq "delay2" );
            $sel4 = 'selected'
              if ( $savedetails{ $aktdevice . '_delayatoff' } eq "at0" );
            $sel3 = 'selected'
              if ( $savedetails{ $aktdevice . '_delayatoff' } eq "at1" );
            $sel6 = 'selected'
              if ( $savedetails{ $aktdevice . '_delayatoff' } eq "at2" );

            $DELAYset2 .=
"<option $se11 value='delay1'>delay with Cond-check immediately and delayed:</option>";
            $DELAYset2 .=
"<option $sel2 value='delay0'>delay with Cond-check immediately only:</option>";
            $DELAYset2 .=
"<option $sel5 value='delay2'>delay with Cond-check delayed only:</option>";
            $DELAYset2 .=
"<option $sel4 value='at0'>at with Cond-check immediately and delayed:</option>";
            $DELAYset2 .=
"<option $sel3 value='at1'>at with Cond-check immediately only:</option>";
            $DELAYset2 .=
"<option $sel6 value='at0'>at with Cond-check delayed only:</option>";
            $DELAYset2 .=
              "</select><input type='text' class=\"devdetails\" id='timesetoff"
              . $nopoint
              . "' name='timesetoff"
              . $nopoint
              . "' size='15' value ='"
              . $timestroff . "'>";

            if ( $expertmode eq '1' ) {
                $REPEATset =
"<hr noshade='noshade' style='height: 1px'>
Repeats: <input type='text' id='repeatcount' name='repeatcount"
                  . $nopoint
                  . "' size='10' value ='"
                  . $savedetails{ $aktdevice . '_repeatcount' } . "'>
						&nbsp;&nbsp
						Repeatdelay in sec:
						<input type='text' id='repeattime' name='repeattime"
                  . $nopoint
                  . "' size='10' value ='"
                  . $savedetails{ $aktdevice . '_repeattime' } . "'> ";
				  
				  
				  
				  
			my $recon = '';
            $recon = 'checked' if ( defined $savedetails{ $aktdevice . '_repeatcondition' } && $savedetails{ $aktdevice . '_repeatcondition' } eq '1' );
           
            $REPEATset .="<input type=\"checkbox\" $recon name='repeatcond". $nopoint. "' />&nbsp;with Cond-check";
				  
				  
	
			
				  
            }

            #if ( $devicenumber == 1 ) {
                $ACTIONsatz =
                  "<input name='info' class=\"randomidclass\" id=\"add_action1_"
                  . rand(1000000)
                  . "\" type='button' value='add action for $add' onclick=\"javascript: addevice('$add')\">";
           # }

            $ACTIONsatz .=
                "&nbsp;<input name='info' id=\"del_action1_"
              . rand(1000000)
              . "\" class=\"randomidclass\" type='button' value='delete this action for $add' onclick=\"javascript: deletedevice('$_')\">";

######################################## neu ##############################################
            my $controlhtmldevice = $controlhtml;

            # ersetzung in steuerdatei
            # MS-IDSATZ ... $IDsatz
            $controlhtmldevice =~ s/MS-IDSATZ/$IDsatz/g;

            # MS-NAMESATZ ... $NAMEsatz
            $controlhtmldevice =~ s/MS-NAMESATZ/$NAMEsatz/g;

            # MS-ACTIONSATZ ... $ACTIONsatz
            $controlhtmldevice =~ s/MS-ACTIONSATZ/$ACTIONsatz/g;

            # MS-SET1 ... $SET1
            $controlhtmldevice =~ s/MS-SET1/$SET1/g;
            $controlhtmldevice =~ s/MS-SET2/$SET2/g;

            # MS-COND ... $COND1set
            $controlhtmldevice =~ s/MS-COND1/$COND1set1/g;
            $controlhtmldevice =~ s/MS-COND2/$COND1set2/g;

            # MS-EXEC ... $EXECset1
            $controlhtmldevice =~ s/MS-EXEC1/$EXECset1/g;
            $controlhtmldevice =~ s/MS-EXEC2/$EXECset2/g;

            # MS-DELAY1 ... $DELAYset1
            $controlhtmldevice =~ s/MS-DELAYset1/$DELAYset1/g;
            $controlhtmldevice =~ s/MS-DELAYset2/$DELAYset2/g;

            # MS-REPEATset  $REPEATset
            $controlhtmldevice =~ s/MS-REPEATset/$REPEATset/g;

            #$COMMENTsatz	$MSComment
            $controlhtmldevice =~ s/MS-COMMENTset/$COMMENTset/g;
            $controlhtmldevice =~ s/MS-CONDCHECK1/$COND1check1/g;
            $controlhtmldevice =~ s/MS-CONDCHECK2/$COND2check2/g;
            $controlhtmldevice =~ s/MS-TEST-1/$MSTEST1/g;
            $controlhtmldevice =~ s/MS-TEST-2/$MSTEST2/g;
            #####
            #zellenhöhe

            if ( $expertmode eq '0' ) {
                $cellhightexpert = "0px";
            }
            if ( AttrVal( $Name, 'MSwitch_Debug', "0" ) ne '1' ) {
                $cellhightdebug = "0px";
            }

            $controlhtmldevice =~ s/MS-cellhighstandart/$cellhight/g;
            $controlhtmldevice =~ s/MS-cellhighexpert/$cellhightexpert/g;
            $controlhtmldevice =~ s/MS-cellhighdebug/$cellhightdebug/g;

            #$controlhtmldevice =~ s/MS-CONDCHECK2/$COND2check2/g;
            #MS-cellhigh
            #MS-cellhighexpert
            #MS-cellhighdebug
            #HELPcondition
            if ( $expertmode ne '1' ) {
                $HELPexit    = "";
                $HELPrepeats = "";
                $HELPexeccmd = "";
            }
            $controlhtmldevice =~ s/MS-HELPpriority/$HELPpriority/g;
            $controlhtmldevice =~ s/MS-HELPonoff/$HELPonoff/g;
            $controlhtmldevice =~ s/MS-HELPcondition/$HELPcondition/g;
            $controlhtmldevice =~ s/MS-HELPexit/$HELPexit/g;
            $controlhtmldevice =~ s/MS-HELPtimer/$HELPtimer/g;
            $controlhtmldevice =~ s/MS-HELPrepeats/$HELPrepeats/g;
            $controlhtmldevice =~ s/MS-HELPexeccmd/$HELPexeccmd/g;
            $controlhtmldevice =~ s/MS-HELPdelay/$HELPdelay/g;















            # textersetzung
            # foreach (@translate) {
                # my ( $wert1, $wert2 ) = split( /->/, $_ );
                # $controlhtmldevice =~ s/$wert1/$wert2/g;
            # }

















            my $aktpriority = $savedetails{ $aktdevice . '_showreihe' };
			my $aktid = $savedetails{ $aktdevice . '_id' };
			
			
			
			
			
			
            if ( grep { $_ eq $aktpriority } @hidecmds ) {
                $noshow++;
                $detailhtml .=
"<div t='1' id='MSwitchWebTR' nm='$hash->{NAME}' idnumber='$aktid' name ='noshow' cellpadding='0' style='display: none;border-spacing:0px;'>"
                  . $controlhtmldevice
                  . "</div>";
            }
            else {

                if ( $savedetails{ $aktdevice . '_hidecmd' } eq "1" ) {
                    $noshow++;
                    $detailhtml .=
"<div t='1' id='MSwitchWebTR' nm='$hash->{NAME}' idnumber='$aktid' name ='noshow' cellpadding='0' style='display: none;border-spacing:0px;'>"
                      . $controlhtmldevice
                      . "</div>";
                }
                else {
                    $detailhtml .=
"<div t='1' id='MSwitchWebTR' nm='$hash->{NAME}' name ='noshow' idnumber='$aktid' cellpadding='0' style='display: block;border-spacing:0px;'>"
                      . $controlhtmldevice
                      . "</div>";
                }
            }

            # javazeile für übergabe erzeugen
            $javaform = $javaform . "
			devices += \$(\"[name=devicename$nopoint]\").val();
			devices += '#[DN]'; 
			devices += \$(\"[name=cmdon$nopoint]\").val()+'#[NF]';
			devices += \$(\"[name=cmdoff$nopoint]\").val()+'#[NF]';
			change = \$(\"[name=cmdonopt$nopoint]\").val();
			devices += change+'#[NF]';;
			change = \$(\"[name=cmdoffopt$nopoint]\").val();
			devices += change+'#[NF]';;
			devices = devices.replace(/\\|/g,'#[SR]');
			
			//alert(devices);
			
			devices += \$(\"[name=onatdelay$nopoint]\").val();
			devices += '#[NF]';
			devices += \$(\"[name=offatdelay$nopoint]\").val();
			devices += '#[NF]';
			delay1 = \$(\"[name=timesetoff$nopoint]\").val();
			devices += delay1+'#[NF]';
			delay2 = \$(\"[name=timeseton$nopoint]\").val();
			devices += delay2+'#[NF]';
			devices1 = \$(\"[name=conditionon$nopoint]\").val();
			devices1 = devices1.replace(/\\|/g,'(DAYS)');
			devices2 = \$(\"[name=conditionoff$nopoint]\").val();
			if(typeof(devices2)==\"undefined\"){devices2=\"\"}
			devices2 = devices2.replace(/\\|/g,'(DAYS)');
			devices += devices1+'#[NF]';
			devices += devices2;
			devices += '#[NF]';
			devices3 = \$(\"[name=repeatcount$nopoint]\").val();
			devices += devices3;
			devices += '#[NF]';
			devices += \$(\"[name=repeattime$nopoint]\").val();
			devices += '#[NF]';
			devices += \$(\"[name=reihe$nopoint]\").val();
			devices += '#[NF]';
			devices += \$(\"[name=idreihe$nopoint]\").val();
			devices += '#[NF]';
			devices += \$(\"[name=cmdcomment$nopoint]\").val();
			devices += '#[NF]';
			devices += \$(\"[name=exit1$nopoint]\").prop(\"checked\") ? \"1\":\"0\";
			devices += '#[NF]';
			devices += \$(\"[name=exit2$nopoint]\").prop(\"checked\") ? \"1\":\"0\";
			devices += '#[NF]';
			devices += \$(\"[name=showreihe$nopoint]\").val();
			devices += '#[NF]';
			devices += \$(\"[name=hidecmd$nopoint]\").val();
			
			devices += '#[NF]';
			testfeld = \$(\"[name=repeatcond$nopoint]\").prop(\"checked\") ? \"1\":\"0\";
			//alert(testfeld);
			devices += testfeld;;
			
			devices += '#[DN]';
			
			//return;
			";
        }



		# showid









        # textersetzung modify


        #if ( $noshow > 0 ) {
            $modify =
			"<table width = '100%' border='0' class='block wide' name ='noshowtask' id='MSwitchDetails' cellpadding='4' style='border-spacing:0px;' nm='MSwitch'>
			<tr class='even' ><td><br>
			Hidden command branches are available (<span id='anzid'>$noshow</span>)
			<input type='button' id='aw_show' value='show hidden cmds' >
			
			&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
			<input type='button' id='aw_showid' value='show IDs' >
			<input type='text' id='aw_showid1' size=\"20\" value='' >
			
			
			<br>&nbsp;
			</td></tr></table><br>
			" . $modify;
       # }

      #   foreach (@translate) {
      #       my ( $wert1, $wert2 ) = split( /->/, $_ );
       #     $modify =~ s/$wert1/$wert2/g;
       #  }


        $detailhtml .= $modify;
    }

   #textersetzung
   
   
   
   
   
   
   
   
   
   
   
   
    #MSwitch_LOG( $Name, 0,"STARTE TEXTERSETZUNG " .time); 
               foreach (@translate) {
                   my ( $wert1, $wert2 ) = split( /->/, $_ );
                   $detailhtml=~ s/$wert1/$wert2/g;
               }

# MSwitch_LOG( $Name, 0,"BEENDE TEXTERSETZUNG " .time); 

















    # ende kommandofelder
####################
    my $triggercondition = ReadingsVal( $Name, '.Trigger_condition', '' );
    $triggercondition =~ s/~/ /g;

    $triggercondition =~ s/#\[dp\]/:/g;
    $triggercondition =~ s/#\[pt\]/./g;
    $triggercondition =~ s/#\[ti\]/~/g;
    $triggercondition =~ s/#\[sp\]/ /g;



	my $timeon        = ReadingsVal( $Name, '.Trigger_time_1', '' );
	$timeon =~ s/#\[dp\]/:/g;
	$timeon =~ s/\[NEXTTIMER\]/&\#9252;/g;
	
	
	
	my $timeoff       = ReadingsVal( $Name, '.Trigger_time_2', '' );
	$timeoff =~ s/#\[dp\]/:/g;
	$timeoff =~ s/\[NEXTTIMER\]/&\#9252;/g;
	
	my $timeononly    = ReadingsVal( $Name, '.Trigger_time_3', '' );
	$timeononly =~ s/#\[dp\]/:/g;
	$timeononly =~ s/\[NEXTTIMER\]/&\#9252;/g;
	my $timeoffonly   = ReadingsVal( $Name, '.Trigger_time_4', '' );
	$timeoffonly =~ s/#\[dp\]/:/g;
	$timeoffonly =~ s/\[NEXTTIMER\]/&\#9252;/g;
	my $timeonoffonly = ReadingsVal( $Name, '.Trigger_time_5', '' );
	$timeonoffonly =~ s/#\[dp\]/:/g;
	$timeonoffonly =~ s/\[NEXTTIMER\]/&\#9252;/g;



    my $ret = '';

########################
    my $blocking = '';
    $blocking = $hash->{helper}{savemodeblock}{blocking}
      if ( defined $hash->{helper}{savemodeblock}{blocking} );

    # endlosschleife
    if ( $blocking eq 'on' ) {
        $ret .= "<table border='$border' class='block wide' id=''>
		<tr class='even'>
		<td><center>&nbsp;<br>$LOOPTEXT";
        $ret .= "</td></tr></table><br>
		";
    }
######################
    # AT fehler
    my $errortest = "";
    $errortest = $hash->{helper}{error} if ( defined $hash->{helper}{error} );
    if ( $errortest ne "" ) {
        $ret .= "<table border='$border' class='block wide' id=''>
		 <tr class='even'>
		 <td><center>&nbsp;<br>$ATERROR<br>"
          . $errortest . "<br>&nbsp;
		 </td></tr></table><br>&nbsp;<br>
		 ";
    }
    # debugmode
    if (   AttrVal( $Name, 'MSwitch_Debug', "0" ) eq '2'
        || AttrVal( $Name, 'MSwitch_Debug', "0" ) eq '3' )
    {
        my $Zeilen = ("");
        open( BACKUPDATEI, "./log/MSwitch_debug_$Name.log" );
        while (<BACKUPDATEI>) {
            $Zeilen = $Zeilen . $_;
        }
        close(BACKUPDATEI);
        my $text = "";
        $text = $PROTOKOLL2 if AttrVal( $Name, 'MSwitch_Debug', "0" ) eq '2';
        $text = $PROTOKOLL3 if AttrVal( $Name, 'MSwitch_Debug', "0" ) eq '3';

        my $activelog = '';
        if ( defined $hash->{helper}{aktivelog} && $hash->{helper}{aktivelog} eq 'on' ) {
            $activelog = 'checked';
        }

        $ret .= "<table border='$border' class='block wide' id=''>
			 <tr class='even'>
			 <td><center>&nbsp;<br>
			 $text<br>&nbsp;<br>";
		# $ret .= " <textarea name=\"log\" id=\"log\" rows=\"5\" cols=\"160\" STYLE=\"font-family:Arial;font-size:9pt;\">"
        #. $Zeilen . "</textarea>";
		$ret .= " <textarea name=\"log\" id=\"log\" rows=\"5\" cols=\"160\" STYLE=\"font-family:Arial;font-size:9pt;\">"
          . "$Zeilen" . "</textarea>";
		$ret .= "<br>&nbsp;<br>
			<input type=\"button\" id=\"\"
			value=\"$CLEARLOG\" onClick=\"clearlog();\"> 
			<input type=\"button\" id=\"\"
			value=\"$CLEARWINDOW\" onClick=\"clearlogwindow();\"> 
			<input id =\"autoscroll\" name=\"autoscroll\" type=\"checkbox\" checked> autoscroll
			<input id =\"activelog\" name=\"activelogging\" type=\"checkbox\" $activelog > $STOPLOG
			<br>&nbsp;<br>
			</td></tr></table><br>
			<br>
			";
    }

    # einblendung wrong timespec
    if ( defined $hash->{helper}{wrongtimespec}
        and $hash->{helper}{wrongtimespec} ne "" )
    {
        $ret .= "
		<table border='$border' class='block wide' id=''>
		<tr class='even'>
		<td colspan ='3'><center><br>&nbsp;";
        $ret .= $hash->{helper}{wrongtimespec};
        $ret .= "<br>$WRONGSPEC1<br>";
        $ret .= "<br>&nbsp;</td></tr></table><br>";
		#$ret .= "<script type=\"text/javascript\">{alert(\"test\")}</script>;
		
		# ";
    }
    if ( defined $hash->{helper}{wrongtimespeccond}
        and $hash->{helper}{wrongtimespeccond} ne "" )
    {
        $ret .= "
		<table border='$border' class='block wide' id=''>
		<tr class='even'>
		<td colspan ='3'><center><br>&nbsp;";
        $ret .= $hash->{helper}{wrongtimespeccond};
        $ret .= "<br>$WRONGSPEC2<br>";
        $ret .= "<br>&nbsp;</td></tr></table><br>
		 ";
    }

    # einblendung system

   	 if ( AttrVal( $Name, 'MSwitch_SysExtension', "0" ) =~ m/(1|2)/s  )
	 {
        $ret .= $system;
     }

    if ( ReadingsVal( $Name, '.info', 'undef' ) ne "undef" ) {
        $info .= "
		<table border='$border' class='block wide' id=''>
		<tr class='even'>
		<td colspan ='3'><center><br>&nbsp;";
        $info .= ReadingsVal( $Name, '.info', '' );
        $info .= "<br>&nbsp;</td></tr></table><br>
		
		 ";
        $ret .= $info;
    }

    # anpassung durch configeinspielung
    if ( ReadingsVal( $Name, '.change', 'undef' ) ne "undef" ) {

        # geräteliste
        my $dev;
        for my $name ( sort keys %defs ) {
            my $devicealias  = AttrVal( $name, 'alias',  "" );
            my $devicewebcmd = AttrVal( $name, 'webCmd', "noArg" );
            my $devicehash   = $defs{$name};
            my $deviceTYPE   = $devicehash->{TYPE};
            $dev .=
                "<option selected=\"\" value=\"$name\">"
              . $name . " (a: "
              . $devicealias
              . ")</option>";
        }

        my $sel = "<select id = \"CID\" name=\"trigon\">" . $dev . "</select>";

        my @change = split( "\\|", ReadingsVal( $Name, '.change', 'undef' ) );
        my $out    = '';
        my $count  = 0;
        foreach my $changes (@change) {
            my @set = split( "#", $changes );
            $out .= $set[1];
            $out .=
                "<input type='' id='cdorg"
              . $count
              . "' name=''  value ='$set[0]' disabled> ersetzen durch:";

            if ( $set[2] eq "device" ) {
                my $newstring = $sel;
                my $newname   = "cdnew" . $count;
                $newstring =~ s/CID/$newname/g;
                $out .= $newstring;
            }
            else {
                $out .=
                    "&nbsp;<input type='' id='cdnew"
                  . $count
                  . "' name='' size='20'  value =''>";
            }
            $count++;
        }
#################################################
        $ret .= "
		<table border='0' class='block wide' id=''>
		<tr class='even'>
		<td>
		<center>
		<br>$HELPNEEDED<br>
		</td></tr>
		<tr class='even'>
		<td>";
        $ret .= ReadingsVal( $Name, '.change_info', '' );
        $ret .= "</td></tr>
		<tr class='even'>
		<td><center>"
          . $out . "</td></tr>
		<tr class='even'>
		<td><center>&nbsp;<br>
		<input type=\"button\" id=\"\"
		value=\"save changes\" onClick=\"changedevices();\"> 
		<br>&nbsp;<br>
		</td></tr></table><br>
		 ";
###################################################
        $j1 = "<script type=\"text/javascript\">{";
        $j1 .=
"var t=\$(\"#MSwitchWebTR\"), ip=\$(t).attr(\"ip\"), ts=\$(t).attr(\"ts\");
	FW_replaceWidget(\"[name=aw_ts]\", \"aw_ts\", [\"time\"], \"12:00\");
	\$(\"[name=aw_ts] input[type=text]\").attr(\"id\", \"aw_ts\");";

        $j1 .= "function changedevices(){
    var count = $count;
	var string = '';
	for (i=0; i<count; i++)
		{
		var field1 = 'cdorg'+i;
		var field2 = 'cdnew'+i;
		string +=  document.getElementById(field1).value + '#' + document.getElementById(field2).value + '|';
		}
	var strneu = string.substr(0, string.length-1);
	strneu = strneu.replace(/ /g,'#[sp]');
	var  def = \"" . $Name . "\"+\" confchange \"+encodeURIComponent(strneu);
	location = location.pathname+\"?detail=" . $Name . "&cmd=set \"+addcsrf(def);
	}";
        $j1 .= "}</script>";
        return "$ret" . "$j1";
    }

###########################################
    if ( ReadingsVal( $Name, '.wrong_version', 'undef' ) ne "undef" ) {
        $ret .= "<table border='$border' class='block wide' id=''>
		 <tr class='even'>
		 <td><center>&nbsp;<br>$WRONGCONFIG"
          . ReadingsVal( $Name, '.wrong_version', '' )
          . "<br>geforderte Versionsnummer $vupdate<br>&nbsp;
		</td></tr></table><br>
		
		 ";
        fhem("deletereading $Name .wrong_version");

    }
#############################################

    if ( ReadingsVal( $Name, '.V_Check', $vupdate ) ne $vupdate ) {

        $ret .= "<table border='$border' class='block wide' id=''>
		 <tr class='even'>
		 <td><center>&nbsp;<br>$VERSIONCONFLICT<br>&nbsp;<br>
		<input type=\"button\" id=\"\"
		value=\"try update to $vupdate\" onClick=\"vupdate();\"> 
		<br>&nbsp;<br>
		</td></tr></table><br>
		<br>
		 ";
        $j1 = "<script type=\"text/javascript\">{";
        $j1 .=
"var t=\$(\"#MSwitchWebTR\"), ip=\$(t).attr(\"ip\"), ts=\$(t).attr(\"ts\");
	FW_replaceWidget(\"[name=aw_ts]\", \"aw_ts\", [\"time\"], \"12:00\");
	\$(\"[name=aw_ts] input[type=text]\").attr(\"id\", \"aw_ts\");";
        $j1 .= "function vupdate(){
    conf='';
	var  def = \"" . $Name . "\"+\" VUpdate \"+encodeURIComponent(conf);
	//alert(def);
	location = location.pathname+\"?detail=" . $Name . "&cmd=set \"+addcsrf(def);
	}";
        $j1 .= "}</script>";
        return "$ret" . "$j1";
    }

#########################################

    if ( ReadingsVal( $Name, 'state', 'undef' ) eq "inactive" ) {
        $ret .= "<table border='$border' class='block wide' id=''>
		 <tr class='even'>
		 <td><center>&nbsp;<br>$INACTIVE<br>&nbsp;<br>
		 </td></tr></table><br>";
    }
    elsif ( IsDisabled($Name) ) {
        $ret .= "<table border='$border' class='block wide' id=''>
		 <tr class='even'>
		 <td><center>&nbsp;<br>$OFFLINE<br>&nbsp;<br>
		 </td></tr></table><br>";
    }
####################

    # trigger start

    my $triggerhtml = "
<!--start Ausloesendes Gerät -->
<!-- folgende HTML-Kommentare dürfen nicht gelöscht werden -->
<!-- 
info: festlegung einer zelleknöhe
MS-cellhigh=30;
-->
<!--
start:textersetzung:ger
trigger device/time->Auslösendes Gerät und/oder Zeit
trigger device->Auslösendes Gerät
trigger time->Auslösezeit
modify Trigger Device->Trigger speichern
switch MSwitch on and execute CMD1 at->MSwitch an und CMD1 ausführen
switch MSwitch off and execute CMD2 at->MSwitch aus und CMD2 ausführen
execute CMD1 only->Schaltkanal 1 ausführen
execute CMD2 only->Schaltkanal 2 ausführen
execute CMD1 and CMD2 only->Schaltkanal 1 und 2 ausführen
Trigger Device Global Whitelist->Beschränkung GLOBAL Auslöser
Trigger condition->Auslösebedingung
time&events->für Events und Zeit
events only->nur für Events
check condition->prüfe Bedingung
end:textersetzung:ger
-->
<!--
start:textersetzung:eng
end:textersetzung:eng
-->
<!--
MS-HIDEDUMMY
MS-TRIGGER
MS-WHITELIST
MS-ONAND1
MS-ONAND2
MS-EXEC1
MS-EXEC2
MS-EXECALL
MS-CONDITION
MS-HELPtime
MS-HELPdevice
MS-HELPtime
MS-HELPdevice
MS-HELPwhitelist
MS-HELPexecdmd
MS-HELPcond
--> 
<table MS-HIDEDUMMY border='0' cellpadding='4' class='block wide' style='border-spacing:0px;'>
	<tr class='even'>
		<td colspan='4'>trigger device/time</td>
	</tr>
	<tr class='even'>
		<td>MS-HELPdevice</td>
		<td>trigger device</td>
		<td>&nbsp;</td>
		<td>MS-TRIGGER</td>
	</tr>
	<tr MS-HIDEWHITELIST class='even'>
		<td>MS-HELPwhitelist</td>
		<td>Trigger Device Global Whitelist</td>
		<td>&nbsp;</td>
		<td>MS-WHITELIST</td>
	</tr>
	<tr MS-HIDEFULL class='even'>
		<td>MS-HELPtime</td>
		<td></td>
		<td>switch MSwitch on and execute CMD1 at</td>
		<td>MS-ONAND1</td>
	</tr>
	<tr MS-HIDEFULL class='even'>
		<td>MS-HELPexecdmd</td>
		<td>&nbsp;</td>
		<td>switch MSwitch off and execute CMD2 at</td>
		<td>MS-ONAND2</td>
	</tr>
	<tr class='even'>
		<td>&nbsp;</td>
		<td>trigger time</td>
		<td>execute CMD1 only</td>
		<td>MS-EXEC1</td>
	</tr>
	<tr class='even'>
		<td>&nbsp;</td>
		<td>&nbsp;</td>
		<td>execute CMD2 only</td>
		<td>MS-EXEC2</td>
	</tr>
	<tr class='even'>
		<td>&nbsp;</td>
		<td>&nbsp;</td>
		<td>execute CMD1 and CMD2 only</td>
		<td>MS-EXECALL</td>
	</tr>
	<tr class='even'>
		<td>MS-HELPcond</td>
		<td>MS-CONDTEXT</td>
		<td>&nbsp;</td>
		<td>MS-CONDITION MS-CHECKCONDITION</td>
	</tr>


	<tr class='even'>
		<td colspan ='4'>MS-modify</td>
	</tr>
</table><br>
<!--end Auslösendes Gerät -->
";

    $triggerhtml = AttrVal( $Name, 'MSwitch_Develop_Trigger', $triggerhtml );

    my $extrakt1 = $triggerhtml;
    $extrakt1 =~ s/\n/#/g;

    if (
        AttrVal(
            $Name, 'MSwitch_Language',
            AttrVal( 'global', 'language', 'EN' )
        ) eq "DE"
      )
    {
        $extrakt1 =~ m/start:textersetzung:ger(.*)end:textersetzung:ger/;
        $extrakt1 = $1;
    }
    else {
        $extrakt1 =~ m/start:textersetzung:eng(.*)end:textersetzung:eng/;
        $extrakt1 = $1;
    }

    @translate = "";
    if ( defined $extrakt1 ) {
        $extrakt1 =~ s/^.//;
        $extrakt1 =~ s/.$//;
        @translate = split( /#/, $extrakt1 );
    }

    my $MSHELPexeccmd    = "";
    my $MSHEPLtrigger    = "";
    my $MSHEPLwhitelist  = "";
    my $MSHEPtime        = "";
    my $MSHELPcond       = "";
    my $MStrigger        = "";
    my $MSwhitelist      = "";
    my $MSmodify         = "";
    my $MScondition      = "";
    my $MSonand1         = "";
    my $MSonand2         = "";
    my $MSexec1          = "";
    my $MSexec2          = "";
    my $MSexec12         = "";
    my $MSconditiontext  = "";
    my $MShidefull       = "";
    my $MSHidedummy      = "";
    my $MSHidewhitelist  = "id='triggerwhitelist'";
    my $MScheckcondition = "";

    my $inhalt5     = "switch $Name on and execute cmd1";
    my $displaynot  = '';
    my $displayntog = '';
    my $help        = "";
    my $visible     = 'visible';

    if ( AttrVal( $Name, 'MSwitch_Mode', 'Notify' ) eq "Notify" ) {
        $MShidefull = "style='display:none;'";
        $displaynot = "style='display:none;'";

    }

    if ( AttrVal( $Name, 'MSwitch_Mode', 'Notify' ) eq "Toggle" ) {
        $displayntog = "style='display:none;'";
        $inhalt5     = "toggle $Name and execute cmd1/cmd2";
    }

    if ( AttrVal( $Name, 'MSwitch_Mode', 'Notify' ) ne "Dummy" ) {
        $MSHidedummy = "";
    }
    else {
        $MSHidedummy = "style ='visibility: collapse'";
        $MShidefull = "style='display:none;'";
        $displaynot = "style='display:none;'";
    }

    $MStrigger =
        "<select id =\"trigdev\" name=\"trigdev\">"
      . $triggerdevices
      . "</select>";

    if ( $globalon ne 'on' ) {
        $MSHidewhitelist =
          "id='triggerwhitelist' style ='visibility: collapse'";
    }

    $MSwhitelist =
"<input type='text' id ='triggerwhite' name='triggerwhitelist' size='35' value ='"
      . ReadingsVal( $Name, '.Trigger_Whitelist', '' )
      . "' onClick=\"javascript:bigwindow(this.id);\" >";

    $MSonand1 =
      "<input type='text' id='timeon' name='timeon' size='35'  value ='"
      . $timeon . "' onClick=\"javascript:bigwindow(this.id,'web');\">";
    $MSonand2 =
      "<input type='text' id='timeoff' name='timeoff' size='35'  value ='"
      . $timeoff . "' onClick=\"javascript:bigwindow(this.id,'web');\">";
    $MSexec1 =
      "<input type='text' id='timeononly' name='timeononly' size='35'  value ='"
      . $timeononly . "' onClick=\"javascript:bigwindow(this.id,'web');\">";

    if ( $hash->{INIT} ne 'define' ) {
        $MSexec2 =
"<input type='text' id='timeoffonly' name='timeoffonly' size='35'  value ='"
          . $timeoffonly . "'onClick=\"javascript:bigwindow(this.id,'web');\">";

        $MSexec12 =
"<input type='text' id='timeonoffonly' name='timeonoffonly' size='35'  value ='"
          . $timeonoffonly . "' onClick=\"javascript:bigwindow(this.id,'web');\">";
    }

    $MSconditiontext = "Trigger condition (events only)";

    if ( AttrVal( $Name, 'MSwitch_Condition_Time', "0" ) eq '1' ) {
        $MSconditiontext = "Trigger condition (time&events)";
    }

    if (   AttrVal( $Name, 'MSwitch_Debug', "0" ) eq '1'
        || AttrVal( $Name, 'MSwitch_Debug', "0" ) eq '3' )
    {
        $MScheckcondition =
" <input name='info' type='button' value='check condition' onclick=\"javascript: checkcondition('triggercondition','$Name:trigger:conditiontest')\">";
    }

    $MScondition =
"<input type='text' id='triggercondition' name='triggercondition' size='35' value ='"
      . $triggercondition
      . "' onClick=\"javascript:bigwindow(this.id);\" >";

    if ( AttrVal( $Name, 'MSwitch_Help', "0" ) eq '1' ) {
        $MSHEPLtrigger =
"<input name='info' type='button' value='?' onclick=\"hilfe('trigger')\">";
        $MSHEPLwhitelist =
"<input name='info' type='button' value='?' onclick=\"hilfe('whitelist')\">";
        $MSHEPLtrigger =
"<input name='info' type='button' value='?' onclick=\"hilfe('trigger')\">";
        $help =
"<input name='info' type='button' value='?' onclick=\"hilfe('execcmd')\">&nbsp;";
        $MSHELPcond =
"<input name='info' type='button' value='?' onclick=\"hilfe('triggercondition')\">";
    }

    $MSmodify =
"<input type=\"button\" id=\"aw_trig\" value=\"modify Trigger Device\"$disable>";

    $triggerhtml =~ s/MS-HELPexecdmd/$MSHELPexeccmd/g;
    $triggerhtml =~ s/MS-HELPdevice/$MSHEPLtrigger/g;
    $triggerhtml =~ s/MS-HELPwhitelist/$MSHEPLwhitelist/g;
    $triggerhtml =~ s/MS-HELPtime/$MSHEPLtrigger/g;
    $triggerhtml =~ s/MS-HELPcond/$MSHELPcond/g;
    $triggerhtml =~ s/MS-modify/$MSmodify/g;
    $triggerhtml =~ s/MS-TRIGGER/$MStrigger/g;
    $triggerhtml =~ s/MS-WHITELIST/$MSwhitelist/g;
    $triggerhtml =~ s/MS-CONDITION/$MScondition/g;
    $triggerhtml =~ s/MS-ONAND1/$MSonand1/g;
    $triggerhtml =~ s/MS-ONAND2/$MSonand2/g;
    $triggerhtml =~ s/MS-EXEC1/$MSexec1/g;
    $triggerhtml =~ s/MS-EXEC2/$MSexec2/g;
    $triggerhtml =~ s/MS-EXECALL/$MSexec12/g;
    $triggerhtml =~ s/MS-CONDTEXT/$MSconditiontext/g;
    $triggerhtml =~ s/MS-HIDEFULL/$MShidefull/g;
    $triggerhtml =~ s/MS-HIDEDUMMY/$MSHidedummy/g;
    $triggerhtml =~ s/MS-HIDEWHITELIST/$MSHidewhitelist/g;
    $triggerhtml =~ s/MS-CHECKCONDITION/$MScheckcondition/g;

    foreach (@translate) {
        my ( $wert1, $wert2 ) = split( /->/, $_ );
        $triggerhtml =~ s/$wert1/$wert2/g;
    }

    $ret .=
"<div id='MSwitchWebTR' nm='$hash->{NAME}' cellpadding='0' style='border-spacing:0px;'>"
      . $triggerhtml
      . "</div>";
################### eventsteuerung

    my $MSTRIGGER;
    my $MSCMDONTRIGGER  = "";
    my $MSCMDOFFTRIGGER = "";
    my $MSCMD1TRIGGER   = "";
    my $MSCMD2TRIGGER   = "";
    my $MSSAVEEVENT     = "";
    my $MSADDEVENT      = "";
    my $MSMODLINE       = "";
    my $MSTESTEVENT     = "";
    my $MSHELP5         = "";
    my $MSHELP6         = "";
    my $MSHELP7         = "";
    my $MSHELP8  = "";
    my $MSHELP9  = "";
    my $MSHELP10 = "";
    my $MSHELP11 = "";
    my $eventhtml = "
<!-- folgende HTML-Kommentare dürfen nicht gelöscht werden -->
<!-- 
info: festlegung einer zellenhöhe
MS-cellhigh=30;
-->
<!-- 
start:textersetzung:ger
Save incomming events permanently->eingehende Events permanent speichern
Add event manually->Event manuell eintragen
event details:->Eventdetails
test event->Event testen
add event->Event einfügen
clear saved events->Eventliste löschen
event monitor->Eventmonitor
end:textersetzung:ger
-->
<!-- 
start:textersetzung:eng
end:textersetzung:eng
-->
<!-- start htmlcode -->
<!-- start Event Details-->
<table border='0' cellpadding='2' class='block wide' style='border-spacing:0px;'>
		<tr>
		<td colspan='4'>event details:</td>
	</tr>

	<tr>
		<td>MS-HELP5</td>
		<td>Save incomming events permanently</td>
		<td>MS-SAVEEVENT</td>
		<td>&nbsp;</td>
	</tr>
		<tr>
		<td>MS-HELP7</td>
		<td>event monitor</td>
		<td><input id =\"eventmonitor\" name=\"eventmonitor\" type=\"checkbox\"></td>
		<td>&nbsp;</td>
	</tr>
	<tr>
		<td>MS-HELP6</td>
		<td>Add event manually</td>
		<td nowrap>MS-ADDEVENT</td>
		<td>&nbsp;</td>
	</tr>
	
	<tr>
		<td id='log' colspan='1'></td>
		<td id='log1' colspan='1'></td>
		<td id='log2' colspan='1'></td>
		<td id='log3' colspan='1'></td>
	</tr>
	<tr>
		<td></td>
		<td colspan='3'>MS-TESTEVENT MS-MODLINE</td>	
	</tr>
</table>
<br>
<!-- end Event Details-->
";

    my $extrakt7 = $eventhtml;
    $extrakt7 =~ s/\n/#/g;

    if (
        AttrVal(
            $Name, 'MSwitch_Language',
            AttrVal( 'global', 'language', 'EN' )
        ) eq "DE"
      )
    {
        $extrakt7 =~ m/start:textersetzung:ger(.*)end:textersetzung:ger/;
        $extrakt7 = $1;
    }
    else {
        $extrakt7 =~ m/start:textersetzung:eng(.*)end:textersetzung:eng/;
        $extrakt7 = $1;
    }

    @translate = "";
    if ( defined $extrakt7 ) {
        $extrakt7 =~ s/^.//;
        $extrakt7 =~ s/.$//;
        @translate = split( /#/, $extrakt7 );
    }

    my $selectedcheck3 = "";
    my $SELF           = $Name;
    my $testlog        = ReadingsVal( $Name, '.Trigger_log', 'on' );
    if ( $testlog eq 'on' ) {
        $selectedcheck3 = "checked=\"checked\"";
    }

    $MSSAVEEVENT =
"<input id ='eventsave'  $selectedcheck3 name=\"aw_save\" type=\"checkbox\" $disable>";

    if ( AttrVal( $Name, 'MSwitch_Help', "0" ) eq '1' ) {
        $MSHELP5 =
"<input name='info' type='button' value='?' onclick=\"hilfe('saveevent')\">&nbsp;";
        $MSHELP6 =
"<input name='info' type='button' value='?' onclick=\"hilfe('addevent')\">&nbsp;";
        $MSHELP7 =
"<input name='info' type='button' value='?' onclick=\"hilfe('eventmonitor')\">&nbsp;";
    }

    $MSADDEVENT =
      "<input type='text' id='add_event' name='add_event' size='40'  value =''>
		<input type=\"button\" id=\"aw_addevent\" value=\"add event\"$disable>";

    # $MSMODLINE =
# "<input type=\"button\" id=\"aw_md1\" value=\"apply filter to saved events\" $disable>
		# <input type=\"button\" id=\"aw_md20\" value=\"clear saved events\" $disable>";
		
		    $MSMODLINE ="<input type=\"button\" id=\"aw_md20\" value=\"clear saved events\" $disable>";
		
		

    if (
        (
               AttrVal( $Name, 'MSwitch_Debug', "0" ) eq '1'
            || AttrVal( $Name, 'MSwitch_Debug', "0" ) eq '3'
        )
        && $optiongeneral ne ''
      )
    {
        $MSTESTEVENT =
            "<select id = \"eventtest\" name=\"eventtest\">"
          . $optiongeneral
          . "</select><input type=\"button\" id=\"aw_md2\" value=\"test event\"$disable onclick=\"javascript: checkevent(document.querySelector('#eventtest').value)\">";

    }

    $eventhtml =~ s/MS-SAVEEVENT/$MSSAVEEVENT/g;
    $eventhtml =~ s/MS-ADDEVENT/$MSADDEVENT/g;
    $eventhtml =~ s/MS-MODLINE/$MSMODLINE/g;
    $eventhtml =~ s/MS-TESTEVENT/$MSTESTEVENT/g;
    $eventhtml =~ s/MS-HELP5/$MSHELP5/g;
    $eventhtml =~ s/MS-HELP6/$MSHELP6/g;
    $eventhtml =~ s/MS-HELP7/$MSHELP7/g;

    foreach (@translate) {
        my ( $wert1, $wert2 ) = split( /->/, $_ );
        $eventhtml =~ s/$wert1/$wert2/g;
    }

    if (   ReadingsVal( $Name, '.Trigger_device', 'no_trigger' ) ne 'no_trigger'
        || AttrVal( $Name, "MSwitch_Selftrigger_always", 0 ) eq "1" )
    {
        $ret .=
"<div id='MSwitchWebTR' nm='$hash->{NAME}' cellpadding='0' style='border-spacing:0px;'>"
          . $eventhtml
          . "</div>";
    }
###########################################################
###########################################################
    # id event bridge neu
###########################################################
###########################################################
    my $distributline = 0;

    my $dist = '';

    if (
        $expertmode eq "1"
        && (
            ReadingsVal( $Name, '.Trigger_device', 'no_trigger' ) ne 'no_trigger'
            || AttrVal( $Name, "MSwitch_Selftrigger_always", 0 ) eq "1" )
      )
    {

        my $MSDELETE     = 'delete';
        my $MSADDDISTRI  = 'add distributor';
        my $MSSAVEDISTRI = 'modify distributor';
        if (
            AttrVal(
                $Name, 'MSwitch_Language',
                AttrVal( 'global', 'language', 'EN' )
            ) eq "DE"
          )
        {
            $MSDELETE     = 'löschen';
            $MSADDDISTRI  = 'neuer Verteiler';
            $MSSAVEDISTRI = 'Verteiler speichern';
        }

        $dist = "<div id='Distributor'>
			<table border='0'  class='block wide' nm='$hash->{NAME}'>
			<tr class=\"even\"><td colspan='2'nowrap>";

        if ( AttrVal( $Name, 'MSwitch_Help', "0" ) eq '1' ) {
            $dist .=
"<input name='info' type='button' value='?' onclick=\"hilfe('eventdistributor')\">&nbsp;";
        }

        $dist .= "$MSDISTRIBUTORTEXT&nbsp;
			<input id ='aw_dist1' name='' type='button' value='$MSADDDISTRI' onclick='adddistributor()'>
			</td></tr>
			<tr class=\"even\"><td>&nbsp;</td><td></td></tr>";

        my $toid = $hash->{helper}{eventtoid};
        foreach my $a ( keys %{$toid} ) {

            my $sel1 = "";
            my $sel2 = "";
            my @toid = split( / /, $hash->{helper}{eventtoid}{$a} );
            if ( $toid[0] eq "cmd1" ) { $sel1 = "selected"; }
            if ( $toid[0] eq "cmd2" ) { $sel2 = "selected"; }

            my $finaloptionid = '';
            for ( my $i = 1 ; $i < $anzahl + 1 ; $i++ ) {

                my $idsel = "";
                if ( $toid[2] eq $i ) { $idsel = "selected"; }
                $finaloptionid .=
                  "<option $idsel value='" . $i . "'>" . $i . "</option>";
            }

            $dist .= "<tr class=\"even\">
				<td id='line1-" . $distributline . "'nowrap>
				$MSDISTRIBUTOREVENT
				<select id = 'ideventNR"
              . $distributline . "' name='' onchange='checkdistricode()'>
				<option selected='selected' value='$a'>$a</option>
				$optiongeneral
				</select>
				</td>";

            $dist .= "<td id='line2-" . $distributline . "' width='100%'>";

            $dist .= "execute ID
				<select id = 'ideventID"
              . $distributline . "' name='' onchange='checkdistricode()'>
				 $finaloptionid
				</select>
				&nbsp;";

            $dist .= "CMD
				<select id = 'ideventCMD"
              . $distributline . "' name='' onchange='checkdistricode()'>
				<option $sel1 value='1'>1</option>
				<option $sel2 value='2'>2</option>
				</select>
				&nbsp;
				<input id ='aw_dist_del$distributline' name='' type='button' value='$MSDELETE' onclick='deletedistributor("
              . $distributline . ")'>";

            $dist .= "</td></tr>";

            $distributline++;
        }

        $dist .= "<!--newline-->";

        $dist .= "
				<tr class=\"even\"><td colspan='2'>
				&nbsp;
				</td></tr>
			<tr class=\"even\"><td colspan='2'>
			<input id ='aw_dist' name='' type='button' value='$MSSAVEDISTRI' onclick='savedistributor()'>
			</td>
			</tr>
			</table>
			</div>";

        my $finaloptionid = '';
        for ( my $i = 1 ; $i < $anzahl + 1 ; $i++ ) {

            my $idsel = "";
            $finaloptionid .= "<option value='" . $i . "'>" . $i . "</option>";
        }

        $dist .= "<table style='display:none;' id ='rawcode'>
			<tr class=\"even\">
			<td id='line1-' nowrap>
				$MSDISTRIBUTOREVENT:
				<select id = 'ideventNR' name='' onchange='checkdistricode()'>
				<option selected='selected' value='undefined'>no_trigger</option>
				$optiongeneral
				</select>
				</td>
				
				<td id='line2-' width='100%'>
				
				execute
				
				ID
				<select id = 'ideventID' name='' onchange='checkdistricode()'>
				 $finaloptionid
				</select>
				
				&nbsp;
				CMD
				<select id = 'ideventCMD' name='' onchange='checkdistricode()'>
				<option value='1'>1</option>
				<option value='2'>2</option>
				</select>
				
				
				&nbsp;
				
				<input id ='aw_dist2' name='' type='button' value='$MSDELETE' onclick='deletedistributor(LINENUMBER)'>
				</td></tr>
			</table>
			<br>
			";
    }

    $ret .= $dist;

    #  $optiongeneral
###################################################################

    # trigger ende

####################

    my $triggerdetailhtml = "
<!-- folgende HTML-Kommentare dürfen nicht gelöscht werden -->
<!-- 
info: festlegung einer zelleknöhe
MS-cellhigh=30;
-->
<!-- 
start:textersetzung:ger
execute only cmd1->nur CMD1 ausführen
execute only cmd2->nur CMD2 ausführen
switch $Name on and execute cmd1->$Name anschalten und CMD1 ausführen
switch $Name off and execute cmd2->$Name ausschalten und CMD2 ausführen
trigger details:->Trigger Details
modify Trigger->Triggerdetails speichern
end:textersetzung:ger
-->
<!-- 
start:textersetzung:eng
end:textersetzung:eng
-->
<!-- start htmlcode -->
<!-- start Trigger Details-->
<table border='0' cellpadding='2' class='block wide' style='border-spacing:0px;'>
		<tr>
		<td colspan='4'>trigger details:</td>
	</tr>
	<tr MS-HIDE>
		<td>MS-HELP9</td>
		<td>MS-CHANGETEXT</td>
		<td>MS-TRIGGER</td>
		<td>MS-ONCMD1TRIGGER</td>
	</tr>
	<tr MS-HIDE MS-HIDE1>
		<td>MS-HELP8</td>
		<td>switch $Name off and execute cmd2</td>
		<td>MS-TRIGGER</td>
		<td>MS-OFFCMD2TRIGGER</td>
	</tr>
	<tr>
		<td>&nbsp;</td>
		<td>&nbsp;</td>
		<td>&nbsp;</td>
		<td>&nbsp;</td>
	</tr>
	<tr MS-HIDE1>
		<td>MS-HELP10</td>
		<td>execute only cmd1</td>
		<td>MS-TRIGGER</td>
		<td>MS-CMD1TRIGGER</td>
	</tr>
	<tr MS-HIDE1>
		<td>MS-HELP11</td>
		<td>execute only cmd2</td>
		<td>MS-TRIGGER</td>
		<td nowrap>MS-CMD2TRIGGER</td>
	</tr>
	<tr>
		<td colspan='4'>MS-MODLINE</td>
		
	</tr>
</table>
<br>
<!-- end Trigger Details-->

";

    my $extrakt2 = $triggerdetailhtml;
    $extrakt2 =~ s/\n/#/g;

    $extrakthtml = $extrakt2;

    # umstellen auf globales attribut !!!!!!
    if (
        AttrVal(
            $Name, 'MSwitch_Language',
            AttrVal( 'global', 'language', 'EN' )
        ) eq "DE"
      )
    {
        $extrakt2 =~ m/start:textersetzung:ger(.*)end:textersetzung:ger/;
        $extrakt2 = $1;
    }
    else {
        $extrakt2 =~ m/start:textersetzung:eng(.*)end:textersetzung:eng/;
        $extrakt2 = $1;
    }

    @translate = "";
    if ( defined $extrakt2 ) {
        $extrakt2 =~ s/^.//;
        $extrakt2 =~ s/.$//;
        @translate = split( /#/, $extrakt2 );
    }

    $extrakthtml =~ m/<!-- start htmlcode -->(.*)/;
    $triggerdetailhtml = $1;
    $triggerdetailhtml =~ s/#/\n/g;

    my $selftrigger       = "";
    my $showtriggerdevice = $Triggerdevice;
    if (   AttrVal( $Name, "MSwitch_Selftrigger_always", 0 ) eq "1"
        && ReadingsVal( $Name, '.Trigger_device', 'no_trigger' ) ne
        'no_trigger' )
    {
        $selftrigger       = "1";
        $showtriggerdevice = $showtriggerdevice . " (or MSwitch_Self)";
    }
    elsif (AttrVal( $Name, "MSwitch_Selftrigger_always", 0 ) eq "1"
        && ReadingsVal( $Name, '.Trigger_device', 'no_trigger' ) eq
        'no_trigger' )
    {
        $selftrigger       = "1";
        $showtriggerdevice = "MSwitch_Self:";
    }
    if ( ReadingsVal( $Name, '.Trigger_device', 'no_trigger' ) ne 'no_trigger'
        || $selftrigger ne "" )
    {
        $MSTRIGGER = "Trigger " . $showtriggerdevice . "";
        $MSCMDONTRIGGER =
          "<select id = \"trigon\" name=\"trigon\">" . $optionon . "</select>";
##############
        my $fieldon = "";
        if ( $triggeron =~ m/{(.*)}/ ) {
            my $exec = "\$fieldon = " . $1;
			{
			no warnings;
            eval($exec);
			}
            $MSCMDONTRIGGER .=
"<input style='background-color:#e5e5e5;' name='info' readonly value='value = "
              . $fieldon . "'>";
        }
        #####################

        $MSCMDOFFTRIGGER =
            "<select id = \"trigoff\" name=\"trigoff\">"
          . $optionoff
          . "</select>";

        ##############
        my $fieldoff = "";
        if ( $triggeroff =~ m/{(.*)}/ ) {
            my $exec = "\$fieldoff = " . $1;
			{
			no warnings;
            eval($exec);
			}
            $MSCMDOFFTRIGGER .=
"<input style='background-color:#e5e5e5;' name='info' readonly value='value = "
              . $fieldoff . "'>";
        }
        #####################

        $MSCMD1TRIGGER =
            "<select id = \"trigcmdon\" name=\"trigcmdon\">"
          . $optioncmdon
          . "</select>";

        ##############
        my $fieldcmdon = "";
        if ( $triggercmdon =~ m/{(.*)}/ ) {
            my $exec = "\$fieldcmdon = " . $1;
			{
			no warnings;
            eval($exec);
			}
            $MSCMD1TRIGGER .=
"<input style='background-color:#e5e5e5;' name='info' readonly value='value = "
              . $fieldcmdon . "'>";
        }

        if ( $hash->{INIT} ne 'define' ) {
            $MSCMD2TRIGGER =
                "<select id = \"trigcmdoff\" name=\"trigcmdoff\">"
              . $optioncmdoff
              . "</select>";

            ##############
            my $fieldcmdoff = "";
            if ( $triggercmdoff =~ m/{(.*)}/ ) {
                my $exec = "\$fieldcmdoff = " . $1;
				{
				no warnings;
                eval($exec);
				}
                $MSCMD2TRIGGER .=
"<input style='background-color:#e5e5e5;' name='info' readonly value='value = "
                  . $fieldcmdoff . "'>";
            }
            #####################
        }

        $MSSAVEEVENT =
          "<input $selectedcheck3 name=\"aw_save\" type=\"checkbox\" $disable>";

        if ( AttrVal( $Name, 'MSwitch_Help', "0" ) eq '1' ) {
            $MSHELP8 =
"<input name='info' type='button' value='?' onclick=\"hilfe('cmd2off')\">&nbsp;";
            $MSHELP9 =
"<input name='info' type='button' value='?' onclick=\"hilfe('cmd2on')\">&nbsp;";

            $MSHELP10 =
"<input name='info' type='button' value='?' onclick=\"hilfe('cmd2ononly')\">&nbsp;";
            $MSHELP11 =
"<input name='info' type='button' value='?' onclick=\"hilfe('cmd2offonly')\">&nbsp;";

        }

        $MSMODLINE =
"<input type=\"button\" id=\"aw_md\" value=\"modify Trigger\" $disable>";

    }
    else {
        $triggerdetailhtml =
"<div style='display:none;border-spacing:0px;'><p id=\"MSwitchWebTRDT\">no show</p></div>";
    }

##############################################################

    #MS-HIDEWHITELIST
    $triggerdetailhtml =~ s/MS-OFFCMD2TRIGGER/$MSCMDOFFTRIGGER/g;
    $triggerdetailhtml =~ s/MS-ONCMD1TRIGGER/$MSCMDONTRIGGER/g;
    $triggerdetailhtml =~ s/MS-CMD2TRIGGER/$MSCMD2TRIGGER/g;
    $triggerdetailhtml =~ s/MS-CMD1TRIGGER/$MSCMD1TRIGGER/g;
    $triggerdetailhtml =~ s/MS-TRIGGER/$MSTRIGGER/g;
    $triggerdetailhtml =~ s/MS-MODLINE/$MSMODLINE/g;
    $triggerdetailhtml =~ s/MS-CHANGETEXT/$inhalt5/g;
    $triggerdetailhtml =~ s/MS-HIDE1/$displayntog/g;
    $triggerdetailhtml =~ s/MS-HIDE/$displaynot/g;
    $triggerdetailhtml =~ s/MS-HELP5/$MSHELP5/g;
    $triggerdetailhtml =~ s/MS-HELP6/$MSHELP6/g;
    $triggerdetailhtml =~ s/MS-HELP7/$MSHELP7/g;
    $triggerdetailhtml =~ s/MS-HELP8/$MSHELP8/g;
    $triggerdetailhtml =~ s/MS-HELP9/$MSHELP9/g;
    $triggerdetailhtml =~ s/MS-HELP10/$MSHELP10/g;
    $triggerdetailhtml =~ s/MS-HELP11/$MSHELP11/g;

    foreach (@translate) {
        my ( $wert1, $wert2 ) = split( /->/, $_ );
        $triggerdetailhtml =~ s/$wert1/$wert2/g;
    }

    $ret .=
"<div id='MSwitchWebTRDT' nm='$hash->{NAME}' cellpadding='0' style='border-spacing:0px;'>"
      . $triggerdetailhtml
      . "</div>";

    #auswfirst  MSwitch_Selftrigger_always
    my $style = "";
	
	
	
	
	
	
    if (   AttrVal( $Name, 'MSwitch_Mode', 'Notify' ) eq "Dummy"
        && AttrVal( $Name, 'MSwitch_Selftrigger_always', '0' ) ne "1" )
    {
        $style = " style ='visibility: collapse' ";

        #$style = "";
		
		# anzeige passiver Dummymode
        # $ret .=
# "<table border='$border' class='block wide' id='MSwitchWebAF' nm='$hash->{NAME}'>
	# <tr class=\"even\">
	# <td><center><br>$DUMMYMODE<br>&nbsp;<br></td></tr></table>
	# ";
    }







    my $MSSAVED            = "";
    my $MSSELECT           = "";
    my $MSHELP             = "";
    my $MSEDIT             = "";
    my $MSLOCK             = "";
    my $MSMOD              = "";
    my $selectaffectedhtml = "
<!--start zu schaltende Geräte -->
<!-- folgende HTML-Kommentare dürfen nicht gelöscht werden -->
<!-- 
start:textersetzung:ger
quickedit locked->Auswahlfeld gesperrt
edit list->Liste editieren
multiple selection with ctrl and mousebutton->mehrfachauswahl mit CTRL und Maustaste
all devicecomands saved->alle Devicekommandos gespeichert
modify Devices->Devices speichern
show greater list->grosses Auswahlfeld
reload->neu laden
affected devices->zu schaltende Geräte
end:textersetzung:ger
-->
<!-- 
start:textersetzung:eng
end:textersetzung:eng
-->
<!-- start htmlcode -->
<table width='100%' border='$border' class='block wide' $style >
	<tr>
		<td>affected devices<br>MS-SAVED</td>
		<td>&nbsp;</td>
		<td></td>
	</tr>
	<tr>
		<td>MS-HELP&nbsp;multiple selection with ctrl and mousebutton</td>
		<td>MS-SELECT</td>
		<td><center>MS-EDIT<br>MS-LOCK</td>
	</tr>
	<tr>
		<td>MS-MOD</td>
		<td>&nbsp;</td>
		<td>&nbsp;</td>
	</tr>
</table>
<!--end zu schaltende Geräte -->";
    my $extrakt3 = $selectaffectedhtml;

    $extrakt3 =~ s/\n/#/g;
    if (
        AttrVal(
            $Name, 'MSwitch_Language',
            AttrVal( 'global', 'language', 'EN' )
        ) eq "DE"
      )
    {
        $extrakt3 =~ m/start:textersetzung:ger(.*)end:textersetzung:ger/;
        $extrakt3 = $1;
    }
    else {
        $extrakt3 =~ m/start:textersetzung:eng(.*)end:textersetzung:eng/;
        $extrakt3 = $1;
    }

    @translate = "";
    if ( defined $extrakt3 ) {
        $extrakt3 =~ s/^.//;
        $extrakt3 =~ s/.$//;
        @translate = split( /#/, $extrakt3 );
    }

    if ( $hash->{INIT} ne 'define' ) {

        # affected devices   class='block wide' style ='visibility: collapse'
        if ( $savecmds ne "nosave" && $cmdfrombase eq "1" ) {
            $MSSAVED =
"all devicecomands saved <input type=\"button\" id=\"del_savecmd\" value=\"reload\">";
        }
        if ( AttrVal( $Name, 'MSwitch_Help', "0" ) eq '1' ) {
            $MSHELP =
"<input name='info' type='button' value='?' onclick=\"hilfe('affected')\">";
        }

        $MSSELECT =
"<select id =\"devices\" multiple=\"multiple\" name=\"affected_devices\" size=\"6\" disabled >"
          . $deviceoption
          . "</select>";
        $MSEDIT =
"<input type=\"button\" id=\"aw_great\" value=\"edit list\" onClick=\"javascript:deviceselect();\">";
        $MSLOCK =
"<input onChange=\"javascript:switchlock();\" checked=\"checked\" id=\"lockedit\" name=\"lockedit\" type=\"checkbox\" value=\"lockedit\" /> quickedit locked";
        $MSMOD =
"<input type=\"button\" id=\"aw_dev\" value=\"modify Devices\"$disable>";
    }

    $selectaffectedhtml =~ s/MS-SAVED/$MSSAVED/g;
    $selectaffectedhtml =~ s/MS-SELECT/$MSSELECT/g;
    $selectaffectedhtml =~ s/MS-HELP/$MSHELP/g;
    $selectaffectedhtml =~ s/MS-EDIT/$MSEDIT/g;
    $selectaffectedhtml =~ s/MS-LOCK/$MSLOCK/g;
    $selectaffectedhtml =~ s/MS-MOD/$MSMOD/g;

    foreach (@translate) {
        my ( $wert1, $wert2 ) = split( /->/, $_ );
        $selectaffectedhtml =~ s/$wert1/$wert2/g;
    }
    $selectaffectedhtml =~ s/#/\n/g;
    $ret .=
"<div t='2' id='MSwitchWebAF' nm='$hash->{NAME}' cellpadding='0' style='border-spacing:0px;'>"
      . $selectaffectedhtml
      . "</div>";

####################
    #javascript$jsvarset
    my $triggerdevicehtml = $Triggerdevice;
    $triggerdevicehtml =~ s/\(//g;
    $triggerdevicehtml =~ s/\)//g;

    my $fileend = "x" . rand(1000);
    my $language =AttrVal( $Name, 'MSwitch_Language',AttrVal( 'global', 'language', 'EN' ) );
    my $quickedit = AttrVal( $Name, 'MSwitch_Lock_Quickedit', "1" );
    my $exec1     = 0;
    my $devicetyp = AttrVal( $Name, 'MSwitch_Mode', 'Notify' );
  
    my $Helpmode = AttrVal( $Name, 'MSwitch_Help', '0' );
    my $Help = '';

    if ( $Helpmode eq '1' ) 
	{
		if ( $language eq "EN" ) {$Help = $englischhelp;}
		else {$Help = $germanhelp;}
	}	

    if ( $affecteddevices[0] ne 'no_device' and $hash->{INIT} ne 'define' )
	{
        $exec1 = "1";
    }

    my $javachange = $javaform;
    $javachange =~ s/\n//g;
    $javachange =~ s/\t//g;
    $javachange =~ s/'/\\'/g;

    $j1 = "<script type=\"text/javascript\">{";
    $j1 .= "
	
	var HELP = '" . $Help . "';
	var HELPMODE = '" . $Helpmode . "';
	var devicename = '" . $Name . "';
	var mswitchname = '" . $Name . "';
	var editevent = '" . $EDITEVENT . "';
	var NOCONDITION = '" . $NOCONDITION . "';
	var CSRF = '" . $FW_CSRF . "';
	var RENAMEBUTTON = '" . $RENAMEBUTTON . "';
	var RELOADBUTTON = '" . $RELOADBUTTON . "';
	var LANGUAGE = '" . $language . "';
	var EXECCMD = '" . $EXECCMD . "';
	var QUICKEDIT = '" . $quickedit . "';
	var EXEC1 = '" . $exec1 . "';
	var SCRIPTTRIGGERS = '" . $scripttriggers . "';
	var DEVICETYP = '" . $devicetyp . "';
	var TRIGGERDEVICEHTML = '" . $triggerdevicehtml . "';
	var JAVAFORM='" . $javachange . "';
	var HASHINIT = '" . $hash->{INIT} . "';
	var UNLOCK ='" . ReadingsVal( $Name, '.lock', 'undef' ) . "';
	var RENAME = '" . $rename . "';
	var DEBUGMODE = '" . $debugmode . "';
	var DISTRIBUTLINES = " . $distributline . ";

	\$(document).ready(function() {
    \$(window).load(function() {
    loadScript(\"pgm2/MSwitch_Web.js?v=" . $fileend
      . "\", function(){teststart()});
	return;
	}); 
	});
	";

## reset und timeline muss noch in javaweb übernommen werden aber nicht wichtig !!
    if ( defined $hash->{helper}{tmp}{deleted}
        && $hash->{helper}{tmp}{deleted} eq "on" )
    {
        my $text = MSwitch_Eventlog( $hash, 'timeline' );
        delete( $hash->{helper}{tmp}{deleted} );
        $j1 .=
"FW_cmd(FW_root+'?cmd=get $Name Eventlog timeline&XHR=1', function(data){FW_okDialog(data)});";
    }

    if ( defined $hash->{helper}{tmp}{reset}
        && $hash->{helper}{tmp}{reset} eq "on" )
    {
        delete( $hash->{helper}{tmp}{reset} );
        my $txt =
"Durch Bestätigung mit \"Reset\" wird das Device komplett zurückgesetzt (incl. Readings und Attributen) und alle Daten werden gelöscht !";
        $txt .=
"<br>&nbsp;<br><center><input type=\"button\" style=\"BACKGROUND-COLOR: red;\" value=\" Reset \" onclick=\" javascript: reset() \">";
        $j1 .= "FW_okDialog('$txt');";
    }
## ende reset und timeline muss noch in javaweb übernommen werden aber nicht wichtig !!

    $j1 .= "
	\$(\"#aw_det\").click(function(){
	var nm = \$(t).attr(\"nm\");
	devices = '';
	$javaform
	//eval(JAVAFORM);
	//return;
	devices = devices.replace(/\t/g, '    ');
	devices = devices.replace(/:/g,'#[dp]');
	devices = devices.replace(/;/g,'#[se]');
	devices = devices.replace(/ /g,'#[sp]');
	devices = devices.replace(/%/g,'#[pr]');
	devices =  encodeURIComponent(devices);
	//alert(devices);
	var  def = nm+\" details \"+devices+\" \";
	location = location.pathname+\"?detail=" . $Name . "&cmd=set \"+addcsrf(def);
	});
	";
    $j1 .= "}</script>";

    my $helpfile = "";

    if ( AttrVal( $Name, 'MSwitch_Help', "0" ) eq '1' ) {
        $helpfile =
"<br><table width = '100%' border='0' class='block wide' id='MSwitchDetails' cellpadding='4' style='border-spacing:0px;' nm='MSwitch'>
			<tr class='even'><td>
			<input type='button' id='' value='Help set' onclick=\"hilfe('set')\">
			<input type='button' id='' value='Help get' onclick=\"hilfe('get')\">
			<input type='button' id='' value='Help attr'onclick=\"hilfe('attr')\" >
			</td></tr></table>
			";
    }

    my $hidecode = "";
    my $inhalt   = "";

    if ( AttrVal( $Name, 'MSwitch_Modul_Mode', "0" ) eq '1' ) {

        my @arraydynsetlist;
        my @arraydynreadinglist = ();
###

        if ( AttrVal( $Name, 'MSwitch_Modul_Mode', "0" ) eq '1' ) {

            my $mswitchsetlist = AttrVal( $Name, 'MSwitch_setList', "undef" );
            if ( $mswitchsetlist ne "undef" ) {
                my @dynsetlist = split( / /, $mswitchsetlist );

                foreach my $test (@dynsetlist) {
                    if ( $test =~ m/(.*)\[(.*)\]:?(.*)/ )

                    {

                        my @found_devices = devspec2array($2);
                        my $s1            = $1;
                        my $s2            = $2;
                        my $s3            = $3;

                        if ( $s3 ne "" ) {
                            @arraydynreadinglist = @found_devices;
                        }
                    }
                }
            }
        }

###

        my $oddeven = "odd";
        my @readlist = split( / /, AttrVal( $Name, 'readingList', "" ) );
        @readlist = ( @readlist, @arraydynreadinglist );

        for (@readlist) {

            my $setinhalt = ReadingsVal( $Name, $_, '' );
            my $settimstamp = ReadingsTimestamp( $Name, $_, '' );

            $inhalt .=
                "<tr class=\""
              . $oddeven
              . "\"><td><div class=\"dname\" data-name=\""
              . $Name . "\">"
              . $_
              . "</div></td>\\
<td><div class=\"dval\" informid=\""
              . $Name . "-" . $_ . "\">" . $setinhalt . "</div></td>\\
<td><div informid=\""
              . $Name . "-" . $_ . "-ts\">" . $settimstamp . "</div></td>\\
</tr>";

            if ( $oddeven eq "odd" ) {
                $oddeven = "even";
                next;
            }
            else {
                $oddeven = "odd";
                next;

            }

        }

        my $testname = "EVENT";
        $hidecode = "<script type=\"text/javascript\">{";
        $hidecode .= "
	\$( document ).ready(function() {
    hideall();
	});
	
	function hideall(){
// \$( \"div:contains(\'" . $testname . "\')\" ).css('display','none');
// \$( \"table[data-name|=\'" . $testname . "\']\" ).css('display','none');
// \$(\".makeTable.wide.readings\").css('display','none');

	 \$(\".block.wide.readings\").html('" . $inhalt . "');
	 var internals = \$(\".makeTable.wide.internals\").html();
	 var readings  = \$(\".makeTable.wide.readings\").html();
	 \$(\".makeTable.wide.readings\").html(internals);
	 \$(\".makeTable.wide.internals\").html(readings);
	return;
 }
	";
        $hidecode .= "}</script>";
    }
	
	if ( AttrVal( $Name, 'MSwitch_SysExtension', "0" ) =~ m/(2)/s  && $data{MSwitch}{$Name}{Ansicht} eq "room")
	{
        #return "$info$system$hidecode<br>";
		return "$info$system<br>";
    }
	
    if ( AttrVal( $Name, 'MSwitch_Modul_Mode', "0" ) eq '1' ) {
        return "$info$system$hidecode<br>";
    }
	
	my $undo="";

	if (exists $data{MSwitch}{$hash}{undo})
		{
			
			if ($data{MSwitch}{$hash}{undotime} > (time-$undotime)){
			
			if ( $language eq "EN" ) 
			{
			$undo="<table border='0' class='block wide' id='MSwitchWebTR' nm='$hash->{NAME}' cellpadding='4' style='border-spacing:0px;'>
				<tr>
				<td style='height: MS-cellhighstandart;width: 100%;' colspan='3'>
				<center><input id=\"undo\" style='BACKGROUND-COLOR: red;' name='undo last change' type='button' value='undo last change'>
				</td>
				</tr>
			</table><br>";
			}
			else
			{
			$undo="<table border='0' class='block wide' id='MSwitchWebTR' nm='$hash->{NAME}' cellpadding='4' style='border-spacing:0px;'>
				<tr>
				<td style='height: MS-cellhighstandart;width: 100%;' colspan='3'>
				<center><input id=\"undo\" style='BACKGROUND-COLOR: red;' name='undo last change' type='button' value='letzte Änderung rückgängig machen'>
				</td>
				</tr>
			</table><br>";
				
			}
			}	

		}
		
    return "$debughtml$undo$ret<br>$detailhtml$helpfile<br>$j1$hidecode";
}

####################

sub MSwitch_makeCmdHash($) {
    my $loglevel = 5;
    my ($Name) = @_;

    # detailsatz in scalar laden
    my @devicedatails;
    @devicedatails =split( /#\[ND\]/, ReadingsVal( $Name, '.Device_Affected_Details', '' ) );
    my %savedetails;

    foreach (@devicedatails) 
	{
        #	ersetzung
        $_ =~ s/#\[sp\]/ /g;
        $_ =~ s/#\[nl\]/\n/g;
        $_ =~ s/#\[se\]/;/g;
        $_ =~ s/#\[dp\]/:/g;
        $_ =~ s/\(DAYS\)/|/g;
        $_ =~ s/#\[ko\]/,/g;     #neu
        $_ =~ s/#\[bs\]/\\/g;    #neu

		### achtung on/off vertauscht
		############### off

        my @detailarray = split( /#\[NF\]/, $_ );    #enthält daten 0-5 0 - name 1-5 daten 7 und9 sind zeitangaben
        my $key = '';
		
        $key = $detailarray[0] . "_delayatonorg";
        $savedetails{$key} = $detailarray[7];
        my $testtimestron = $detailarray[8];
        $key = $detailarray[0] . "_delayatofforg";
        $savedetails{$key} = $detailarray[8];
        $detailarray[8]    = $testtimestron;
        $key               = $detailarray[0] . "_on";
        $savedetails{$key} = $detailarray[1];
        $key               = $detailarray[0] . "_off";
        $savedetails{$key} = $detailarray[2];
        $key               = $detailarray[0] . "_onarg";
		if ( defined $detailarray[3] && $detailarray[3] ne "" )
		{	
        $savedetails{$key} = $detailarray[3];
		}
		else{
		$savedetails{$key} = "";
		}
        $key               = $detailarray[0] . "_offarg";
        $savedetails{$key} = $detailarray[4];
        $key               = $detailarray[0] . "_delayaton";
        $savedetails{$key} = $detailarray[5];
        $key               = $detailarray[0] . "_delayatoff";
        $savedetails{$key} = $detailarray[6];
        $key               = $detailarray[0] . "_timeon";
        $savedetails{$key} = $detailarray[7];
        $key               = $detailarray[0] . "_timeoff";
        $savedetails{$key} = $detailarray[8];
        $key               = $detailarray[0] . "_repeatcount";

        if ( defined $detailarray[11] && $detailarray[11] ne "" ) {
            $savedetails{$key} = $detailarray[11];
        }
        else {
            $savedetails{$key} = 0;
        }

        $key = $detailarray[0] . "_repeattime";
        if ( defined $detailarray[12] && $detailarray[12] ne "" ) {
            $savedetails{$key} = $detailarray[12];
        }
        else {
            $savedetails{$key} = 0;
        }

        $key = $detailarray[0] . "_priority";
        if ( defined $detailarray[13] ) {
            $savedetails{$key} = $detailarray[13];
        }
        else {
            $savedetails{$key} = 1;
        }

        $key = $detailarray[0] . "_id";
        if ( defined $detailarray[14] ) {
            $savedetails{$key} = $detailarray[14];
        }
        else {
            $savedetails{$key} = 0;
        }

        $key = $detailarray[0] . "_exit1";
        if ( defined $detailarray[16] ) {
            $savedetails{$key} = $detailarray[16];
        }
        else {
            $savedetails{$key} = 0;
        }

        $key = $detailarray[0] . "_exit2";
        if ( defined $detailarray[17] ) {
            $savedetails{$key} = $detailarray[17];
        }
        else {
            $savedetails{$key} = 0;
        }

        $key = $detailarray[0] . "_showreihe";
        if ( defined $detailarray[18] ) {
            $savedetails{$key} = $detailarray[18];
        }
        else {
            $savedetails{$key} = 0;
        }
        ###

        $key = $detailarray[0] . "_hidecmd";
        if ( defined $detailarray[19] ) {
            $savedetails{$key} = $detailarray[19];
        }
        else {
            $savedetails{$key} = 0;
        }
        ###

        $key = $detailarray[0] . "_comment";
        if ( defined $detailarray[15] ) {
            $savedetails{$key} = $detailarray[15];
        }
        else {
            $savedetails{$key} = '';
        }

        $key = $detailarray[0] . "_conditionon";

        if ( defined $detailarray[9] ) {

            $savedetails{$key} = $detailarray[9];
        }
        else {
            $savedetails{$key} = '';
        }
        $key = $detailarray[0] . "_conditionoff";

        if ( defined $detailarray[10] ) {

            $savedetails{$key} = $detailarray[10];
        }
        else {
            $savedetails{$key} = '';
        }
		

		 $key = $detailarray[0] . "_repeatcondition";
		  if ( defined $detailarray[20] ) {

             $savedetails{$key} = $detailarray[20];
         }
         else {
             $savedetails{$key} = '';
         }
    }

   my @pass = %savedetails;
   return @pass;
}
########################################

sub MSwitch_Delete_Triggermemory($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
	my $showevents = AttrVal( $Name, "MSwitch_generate_Events", 0 );
	if (AttrVal( $Name, 'MSwitch_Debug', '0' ) ne "0" ){$showevents = 1};
    my $events        = ReadingsVal( $Name, '.Device_Events', '' );
    my $triggeron     = ReadingsVal( $Name, '.Trigger_on', 'no_trigger' );
    if ( !defined $triggeron ) { $triggeron = "" }
    my $triggeroff = ReadingsVal( $Name, '.Trigger_off', 'no_trigger' );
    if ( !defined $triggeroff ) { $triggeroff = "" }
    my $triggercmdon = ReadingsVal( $Name, '.Trigger_cmd_on', 'no_trigger' );
    if ( !defined $triggercmdon ) { $triggercmdon = "" }
    my $triggercmdoff = ReadingsVal( $Name, '.Trigger_cmd_off', 'no_trigger' );
    if ( !defined $triggercmdoff ) { $triggercmdoff = "" }
    my $triggerdevice = ReadingsVal( $Name, '.Trigger_device', '' );
    delete( $hash->{helper}{events} );

    $hash->{helper}{events}{$triggerdevice}{'no_trigger'}   = "on";
    $hash->{helper}{events}{$triggerdevice}{$triggeron}     = "on";
    $hash->{helper}{events}{$triggerdevice}{$triggeroff}    = "on";
    $hash->{helper}{events}{$triggerdevice}{$triggercmdon}  = "on";
    $hash->{helper}{events}{$triggerdevice}{$triggercmdoff} = "on";
    readingsSingleUpdate( $hash, ".Device_Events", 'no_trigger', $showevents );
    my $eventhash = $hash->{helper}{events}{$triggerdevice};
    $events = "";

    foreach my $name ( keys %{$eventhash} )
	{
        $name =~ s/#\[tr//ig;
        $events = $events . $name . '#[tr]';
    }
    chop($events);
    chop($events);
    chop($events);
    chop($events);
    chop($events);
    readingsSingleUpdate( $hash, ".Device_Events", $events, 0 );
    return;
}
###########################################################################
sub MSwitch_Exec_Notif($$$$$) {
    #Inhalt Übergabe ->  push @cmdarray, $own_hash . ',on,check,' . $eventcopy1
	
	
    my ( $hash, $comand, $check, $event, $execids ) = @_;
    my $name      = $hash->{NAME};
	
	#Log3("test",0," $comand -- $check -- $event -- $execids ");
	MSwitch_LOG( $name, 6,"### SUB_Exec_Notif ###");
	
    my $protokoll = '';
    my $satz;

    if ( !$execids ) { $execids = "0" }
    my $showevents     = AttrVal( $name, "MSwitch_generate_Events", 0 );
	if (AttrVal( $name, 'MSwitch_Debug', '0' ) ne "0" ){$showevents = 1};
	
    my $debugmode      = AttrVal( $name, 'MSwitch_Debug',           "0" );
    my $expertmode     = AttrVal( $name, 'MSwitch_Expert',          "0" );
    my $delaymode      = AttrVal( $name, 'MSwitch_Delete_Delays',   '0' );
    my $attrrandomtime = AttrVal( $name, 'MSwitch_RandomTime',      '' );
    my $exittest       = '';
    $exittest = "1" if $comand eq "on";
    $exittest = "2" if $comand eq "off";
    my $ekey = '';
    my $out  = '0';
    return "" if ( IsDisabled($name) ); 

    if ( $delaymode eq '2' ) 
	{
        MSwitch_Delete_specific_Delay( $hash, $name, $event );
    }
	
	if ( $delaymode eq '3' ) 
	{
        MSwitch_Delete_Delay( $hash, $name );
    }
	
    my %devicedetails = MSwitch_makeCmdHash($name);

    # betroffene geräte suchen
    my @devices =split( /,/, ReadingsVal( $name, '.Device_Affected', 'no_device' ) );
    my $update     = '';
    my $testtoggle = '';
	 
	#MSwitch_LOG( $name, 6, "devices id:$execids @devices L:" . __LINE__ );
    # liste nach priorität ändern , falls expert
    @devices = MSwitch_priority( $hash, $execids, @devices );
	#MSwitch_LOG( $name, 6, "devices nach priority @devices L:" . __LINE__ );
	
    my $lastdevice;
    my @execute;
    my @timers;
    my $timercounter = 0;
    my $eventcount=0;

	LOOP45: foreach my $device (@devices)
	{

        MSwitch_LOG( $name, 6, "ausfuehrung fuer: $device ");

        $out = '0';
        if ( $expertmode eq '1' ) {
            $ekey = $device . "_exit" . $exittest;
            $out  = $devicedetails{$ekey};
        }

        if ( $delaymode eq '1' )
		{
            MSwitch_Delete_Delay( $hash, $device );
        }

        my @devicesplit = split( /-AbsCmd/, $device );
        my $devicenamet = $devicesplit[0];

        # teste auf on kommando
        my $key      = $device . "_" . $comand;
        my $timerkey = $device . "_time" . $comand;

        if ( $devicedetails{$timerkey} =~ m/{.*}/ )
		{
			{
			no warnings;
            $devicedetails{$timerkey} = eval $devicedetails{$timerkey};
			}
        }

        if ( $devicedetails{$timerkey} =~ m/\[.*:.*\]/ )
		{
			$hash->{helper}{aktevent}=$event;
			{
			no warnings;
            $devicedetails{$timerkey} = eval MSwitch_Checkcond_state( $devicedetails{$timerkey}, $name );
			}
			delete( $hash->{helper}{aktevent} );
        }

        if ( $devicedetails{$timerkey} =~ m/[\d]{2}:[\d]{2}:[\d]{2}/ )
		{

            my $hdel = ( substr( $devicedetails{$timerkey}, 0, 2 ) ) * 3600;
            my $mdel = ( substr( $devicedetails{$timerkey}, 3, 2 ) ) * 60;
            my $sdel = ( substr( $devicedetails{$timerkey}, 6, 2 ) ) * 1;
            $devicedetails{$timerkey} = $hdel + $mdel + $sdel;
        }
        elsif ( $devicedetails{$timerkey} =~ m/^\d*\.?\d*$/ )
		{
            $devicedetails{$timerkey} = $devicedetails{$timerkey};
        }
        else
		{
            $devicedetails{$timerkey} = 0;
        }

        # teste auf condition
        # antwort $execute 1 oder 0 ;

        my $conditionkey = $device . "_condition" . $comand;
        if ( $devicedetails{$key} ne "" && $devicedetails{$key} ne "no_action" )
        {
            my $cs = '';
            if ( $devicenamet eq 'FreeCmd' )
			{
                $cs = "  $devicedetails{$device.'_'.$comand.'arg'}";
				#MSwitch_LOG( $name, 6, "AUFRUF FREECMD $event L:" . __LINE__ );
				$hash->{helper}{aktevent}=$event;
                $cs = MSwitch_makefreecmd( $hash, $cs );
				delete( $hash->{helper}{aktevent} );
                #variableersetzung erfolgt in freecmd
            }
            else 
			{
                $cs ="$devicedetails{$device.'_'.$comand} $devicedetails{$device.'_'.$comand.'arg'}";
                my $pos = index( $cs, "[FREECMD]" );
                if ( $pos >= 0 ) 
				{
					$hash->{helper}{aktevent}=$event;
                    $cs = MSwitch_makefreecmdonly( $hash, $cs );
					delete( $hash->{helper}{aktevent} );
                }
                else 
				{
                    $cs = "set $devicenamet " . $cs;
                }
            }

            #Variabelersetzung

            if (   $devicedetails{$timerkey} eq "0" || $devicedetails{$timerkey} eq "" )
            {
                # teste auf condition
                # antwort $execute 1 oder 0 ;
                $conditionkey = $device . "_condition" . $comand;
                my $execute =MSwitch_checkcondition( $devicedetails{$conditionkey}, $name, $event );
                $testtoggle = 'undef';
                if ( $execute eq 'true' ) 
				{
                    $lastdevice = $device;
                    $testtoggle = $cs;
                    #############
                    my $toggle = '';
                    if ( $cs =~ m/set (.*)(MSwitchtoggle)(.*)/ )
					{
                        $toggle = $cs;
                        $cs = MSwitch_toggle( $hash, $cs );
                    }

                    # neu
                    $devicedetails{ $device . '_repeatcount' } = 0 if !defined $devicedetails{ $device . '_repeatcount' };
                    $devicedetails{ $device . '_repeattime' } = 0 if !defined $devicedetails{ $device . '_repeattime' };

                    my $x = 0;
                    while ( $devicedetails{ $device . '_repeatcount' } =~  m/\[(.*)\:(.*)\]/ )
                    {
                        $x++;    # exit
                        last if $x > 20;    # exit
                        my $setmagic = ReadingsVal( $1, $2, 0 );
                        $devicedetails{ $device . '_repeatcount' } = $setmagic;
                    }

                    $x = 0;
                    while ( $devicedetails{ $device . '_repeattime' } =~ m/\[(.*)\:(.*)\]/ )
                    {
                        $x++;               # exit
                        last if $x > 20;    # exit
                        my $setmagic = ReadingsVal( $1, $2, 0 );
                        $devicedetails{ $device . '_repeattime' } = $setmagic;
                    }

                    if ( $devicedetails{ $device . '_repeatcount' } ne "undefined"
                        && $devicedetails{ $device . '_repeattime' } ne "undefined" )
                    {

                        if ( $devicedetails{ $device . '_repeatcount' } eq "" )
                        {
                            $devicedetails{ $device . '_repeatcount' } = 0;
                        }
                        if ( $devicedetails{ $device . '_repeattime' } eq "" )
						{
                            $devicedetails{ $device . '_repeattime' } = 0;
                        }

                        if (   $expertmode eq '1'
                            && $devicedetails{ $device . '_repeatcount' } > 0
                            && $devicedetails{ $device . '_repeattime' } > 0 )
                        {
                            my $i;
                            for ($i = 1 ; $i <=$devicedetails{ $device . '_repeatcount' } ; $i++)
                            {
								$cs =~ s/\n/#[MSNL]/g;
                                my $msg2 = $cs . "|" . $name;
                                if ( $toggle ne '' )
								{
                                    $msg2 = $toggle . "|" . $name;
                                }
                                my $timecond = gettimeofday() +( ( $i + 1 ) *$devicedetails{ $device . '_repeattime' });
                                $msg2 = $msg2 . "|[TIMECOND]|$device|$comand";
                                MSwitch_LOG( $name, 6,"Befehlswiederholungen gesetzt: $timecond");
                                my $timerset = "[REPEATER][NUMBER$timercounter]$msg2";
                                $timers[$timercounter] = $timecond;
                                push( @execute, $timerset );
                                $timercounter++;

                                if ( $out eq '1' )
								{
                                    $lastdevice = $device;
                                    last LOOP45;
                                }

                            }
                        }
                    }
                    my $todec = $cs;
					$hash->{helper}{aktevent}=$event;
                    $cs = MSwitch_dec( $hash, $cs );
					delete( $hash->{helper}{aktevent} );
					
					if ( $cs =~ m/(^set.*)(\{.*\})/ )
					{
						my $exec = $2;
						{
						no warnings;
						$exec = eval $exec;
						}
						$cs = $1.$exec;
					}
                    ############################
                    if ( $cs =~ m/{.*}/ )
					{
                        $cs =~ s/\[SR\]/\|/g;
                        MSwitch_LOG( $name, 6,"finaler Befehl auf Ausführungsstapel geschoben:\n \n$cs\n\n:");
                        push( @execute, $cs );
                        if ( $out eq '1' )
						{
                            MSwitch_LOG( $name, 6, "Abbruchbefehl ehalten von: ". $device . " " );
                            $lastdevice = $device;
                            last LOOP45;
                        }

                    }
                    else 
					{
                        MSwitch_LOG( $name, 6,"finaler Befehl auf Ausführungsstapel geschoben:\n \n$cs\n \n");
						push( @execute, $cs );
                        if ( $out eq '1' )
						{
                            MSwitch_LOG( $name, 6,"Abbruchbefehl erhalten von ". $device . " ");
                            $lastdevice = $device;
                            last LOOP45;
                        }
                    }
                }
            }
            else 
			{
                if ($attrrandomtime ne ''&& $devicedetails{$timerkey} eq '[random]')
                {
                    MSwitch_LOG( $name, 6, "setze zufälligen Timer");
                    $devicedetails{$timerkey} =MSwitch_Execute_randomtimer($hash);
                    # ersetzt $devicedetails{$timerkey} gegen randomtimer
                }
                elsif ($attrrandomtime eq ''&& $devicedetails{$timerkey} eq '[random]' )
                {

                    MSwitch_LOG( $name, 6, "setze zufälligen Timer 0 - Attr nicht definiert " );
                    $devicedetails{$timerkey} = 0;
                }

                ###################################################################################

                my $timecond     = gettimeofday() + $devicedetails{$timerkey};
                my $delaykey     = $device . "_delayat" . $comand;
                my $delayinhalt  = $devicedetails{$delaykey};
                my $delaykey1    = $device . "_delayat" . $comand . "org";
                my $teststateorg = $devicedetails{$delaykey1};

                $conditionkey = $device . "_condition" . $comand;
                my $execute = "true";

                if ( $delayinhalt ne "delay2" && $delayinhalt ne "at02" )
				{
                    $execute = MSwitch_checkcondition( $devicedetails{$conditionkey},$name, $event );
                }

                if ( $execute eq "true" )
				{
                    if ( $delayinhalt eq 'at0' || $delayinhalt eq 'at1' )
					{
                        $timecond = MSwitch_replace_delay( $hash, $teststateorg );
                    }

                    if ( $delayinhalt eq 'at1' || $delayinhalt eq 'delay0' )
					{
                        $conditionkey = "nocheck";
                    }

                    $cs =~ s/,/##/g;
					$cs =~ s/\n/#[MSNL]/g;
                    my $msg2 =
                        $cs . "#[tr]"
                      . $name . "#[tr]"
                      . $conditionkey . "#[tr]"
                      . $event . "#[tr]"
                      . "TIMECOND#[tr]"
                      . $device."#[tr]"
					  . $comand;

                    $testtoggle = 'undef';
                    MSwitch_LOG( $name, 6,  "setze Verzögerung $timecond" );
                    my $timerset = "[TIMER][NUMBER$timercounter]$msg2";
                    $timers[$timercounter] = $timecond;
                    push( @execute, $timerset );
                    $timercounter++;

                    if ( $expertmode eq "1" && $device )
					{
                        readingsSingleUpdate( $hash, "last_cmd",$hash->{helper}{priorityids}{$device},0 );
                    }

                    if ( $out eq '1' )
					{
                        #abbruchbefehl erhalten von $device
                        MSwitch_LOG( $name, 6, "Abbruchbefehl erhalten von ". $device . " ");
                        $lastdevice = $device;
                        last LOOP45;
                    }

                }
            }
        }
        if ( $testtoggle ne '' && $testtoggle ne 'undef' )
		{
            $satz .= $testtoggle . ',';
        }
    }

    if ( $expertmode eq "1" && $lastdevice ) 
	{
        readingsSingleUpdate( $hash, "last_cmd",$hash->{helper}{priorityids}{$lastdevice}, 0 );
    }

    my $fullstring = join( '[|]', @execute );
    my $msg;
    MSwitch_LOG( $name, 6, "Ausführung Befehlsstapel " );
	
    if ( AttrVal( $name, 'MSwitch_Switching_once', 0 ) == 1
        && $fullstring eq $hash->{helper}{lastexecute} )
    {
        MSwitch_LOG( $name, 6,"Ausfuehrung Befehlsstapel abgebrochen - Stapel wurde bereits ausgeführt ");
        MSwitch_LOG( $name, 6, "attr MSwitch_Switching_once gesetzt");
    }
    else  
	{
		MSwitch_LOG( $name, 6,"anzahl vorhandener Befehle : ".@execute );	
        foreach my $device (@execute)
		{
			MSwitch_LOG( $name, 6,"Ausgefuehrter Befehl: -$device-");	
            next if $device eq "";
            next if $device eq " ";
            next if $device eq "  ";

            if ( $debugmode eq '2' )
			{
                MSwitch_LOG( $name, 6, "nicht Ausgefuehrter (Debug2) Befehl: $device" );
                next;
            }

            if ( $device =~ m/\[REPEATER\].*/ )
			{
			
                MSwitch_LOG( $name, 6, "Repeaterhandling: $device");
                $device =~ m/\[NUMBER(.*?)](.*)/;
                my $number = $1;
                my $string = $2;
				$string =~ s/#\[MSNL\]/\n/g;
               # MSwitch_LOG( $name, 6,"extrahierte Nummer: $number L:" . __LINE__ );
               # MSwitch_LOG( $name, 6, "extrahierte String: $string L:" . __LINE__ );
                my $timecondition = $timers[$number];
               # MSwitch_LOG( $name, 6,"extrahierte Timecondition: $timecondition L:" . __LINE__ );
                $string =~ s/\[TIMECOND\]/$timecondition/g;
                MSwitch_LOG( $name, 6, "setze Repeat: $string L:");
                $hash->{helper}{repeats}{$timecondition} = "$string";
                InternalTimer( $timecondition, "MSwitch_repeat", $string );
                next;
            }

            if ( $device =~ m/\[TIMER\].*/ )
			{
				
				
				
                MSwitch_LOG( $name, 6, "Timerhandling: $device" . __LINE__ );
                $device =~ m/\[NUMBER(.*?)](.*)/;
                my $number = $1;
                my $string = $2;
				$string =~ s/#\[MSNL\]/\n/g;
               # MSwitch_LOG( $name, 6, "extrahierte Nummer: $number L:" . __LINE__ );."|$comand";
               # MSwitch_LOG( $name, 6, "extrahierte String: $string L:" . __LINE__ );
                my $timecondition = $timers[$number];
               # MSwitch_LOG( $name, 6,"extrahierte Timecondition: $timecondition L:" . __LINE__ );
                $string =~ s/TIMECOND/$timecondition/g;
				
				Log3( $name, 6, "Timerhandling: $string" . __LINE__ );
				
                MSwitch_LOG( $name, 6, "setze Timer: $string ");
                $hash->{helper}{delays}{$string} = $timecondition;
                InternalTimer( $timecondition, "MSwitch_Restartcmd", $string );
                next;
            }

			$msg.=$device.";";

            if ( $device =~ m/{.*}/ )
			{
                MSwitch_LOG( $name, 6, "Device - $device" );
				{
				no warnings;
                eval($device);
				}
                if ( $@ and $@ ne "OK" )
				{
                    MSwitch_LOG( $name, 1,
					"$name MSwitch_Set: ERROR $device: $@ " . __LINE__ );
                }
            }
            else 
			{
                MSwitch_LOG( $name, 6, "Device - $device" );
                my $errors = AnalyzeCommandChain( undef, $device );
                if ( defined($errors) and $errors ne "OK" )
				{
                    MSwitch_LOG( $name, 1,"MSwitch_Exec_Notif $comand: ERROR $device: $errors -> Comand: $device". " ". __LINE__ );
                }
            }
        }

        if ( defined $msg && length($msg) > 100 ) { $msg = substr( $msg, 0, 100 ) . '....'; }
        readingsSingleUpdate( $hash, "last_exec_cmd", $msg, $showevents ) if defined $msg ;
	
		if (@execute > 0)
		{
			$hash->{helper}{lastexecute} = $fullstring;
			MSwitch_LOG( $name, 6, "Eventlock gelöscht" );
		}
		else
		{
			MSwitch_LOG( $name, 6, "Eventlock nicht gelöscht" );
		}
    }
return $satz;
}
####################



sub MSwitch_checkcondition($$$) {
	my ( $condition, $name, $event ) = @_;
    my ( $sec, $min, $hour, $mday, $month, $year, $wday, $yday, $isdst ) =localtime( gettimeofday() );
    $month++;
    $year += 1900;
    
	MSwitch_LOG( $name, 6,"### SUB_checkcondition ###");
	#MSwitch_LOG( $name, 6, "Device: $name ");
    MSwitch_LOG( $name, 6, "Bedingungsprüfung Bedingung: $condition ");
    MSwitch_LOG( $name, 6, "Bedingungsprüfung Event: $event ");

    my $hash = $modules{MSwitch}{defptr}{$name};
    $event =~ s/"/\\"/g;    # keine " im event zulassen ERROR
    my $attrrandomnumber = AttrVal( $name, 'MSwitch_RandomNumber', '' );
    my $debugmode        = AttrVal( $name, 'MSwitch_Debug',        "0" );

	my $aktsnippet ="";
	my $aktsnippetnumber ="";
	if ( $condition =~ m/(.*)\[Snippet:([\d]{1,3})\](.*)/ ) 
	{					
		my $firstpart = $1;
		my $snipppetnumber = $2;
		my $lastpart =$3;	
		MSwitch_LOG( $name, 6, "Snippet gefunden: $aktsnippetnumber " );
		my $snippet =	 $data{MSwitch}{$name}{snippet}{$snipppetnumber};
		$snippet =~ s/\n//g;
		$condition = $firstpart . $snippet . $lastpart;
		MSwitch_LOG( $name, 6, "Bedingung mit Snippetersetzung: $condition ");
	}
	
	$condition =~ s/\"\$EVENT\"/\$EVENT/g;
    $condition =~ s/\"\$EVTFULL\"/\$EVTFULL"/g;
    $condition =~ s/\"\$EVTPART1\"/\$EVTPART1/g;
    $condition =~ s/\"\$EVTPART2\"/\$EVTPART2/g;
    $condition =~ s/\"\$EVTPART3\"/\$EVTPART3/g;
	
	$condition =~ s/\[\$EVENT\]/\$EVENT/g;
    $condition =~ s/\[\$EVTFULL\]/\$EVTFULL/g;
    $condition =~ s/\[\$EVTPART1\]/\$EVTPART1/g;
    $condition =~ s/\[\$EVTPART2\]/\$EVTPART2/g;
    $condition =~ s/\[\$EVTPART3\]/\$EVTPART3/g;
    $condition =~ s/\[\$EVT_CMD1_COUNT\]/"\$EVT_CMD1_COUNT"/g;
    $condition =~ s/\[\$EVT_CMD2_COUNT\]/"\$EVT_CMD2_COUNT"/g;
    #### evt anpassung wenn alleinstehend
    $condition =~ s/(?<!")\$EVENT(?!")|\[EVENT]/\$EVENT/g;
    $condition =~ s/(?<!")\$EVTFULL(?!")|\[EVTFULL]/\$EVTFULL/g;
    $condition =~ s/(?<!")\$EVTPART1(?!")|\[EVTPART1]/\$EVTPART1/g;
    $condition =~ s/(?<!")\$EVTPART2(?!")|\[EVTPART2]/\$EVTPART2/g;
    $condition =~ s/(?<!")\$EVTPART3(?!")|\[EVTPART3]/\$EVTPART3/g;
	
    $condition =~ s/\[EVT_CMD1_COUNT\]/[$name:EVT_CMD1_COUNT]/g;
    $condition =~ s/\[EVT_CMD2_COUNT\]/[$name:EVT_CMD2_COUNT]/g;
    $condition =~ s/\[DIFFDIRECTION\]/[$name:DIFFDIRECTION]/g;
    $condition =~ s/\[DIFFERENCE\]/[$name:DIFFERENCE]/g;
    $condition =~ s/\[TENDENCY\]/[$name:TENDENCY]/g;
    $condition =~ s/\[INCREASE\]/[$name:INCREASE]/g;
    $condition =~ s/\[AVERAGE\]/[$name:AVERAGE]/g;
    $condition =~ s/\[SEQUENCE_Number\]/[$name:SEQUENCE_Number]/g;
    $condition =~ s/\[SEQUENCE\]/[$name:SEQUENCE]/g;
    $condition =~ s/\$year/[YEAR]/g;
    $condition =~ s/\$month/[MONTH]/g;
    $condition =~ s/\$day/[DAY]/g;
    $condition =~ s/\$min/[MIN]/g;
    $condition =~ s/\$hour/[HOUR]/g;
    $condition =~ s/\$hms/[HMS]/g;
    
    if ( !defined($condition) ) { return 'true'; }
    if ( $condition eq '' )     { return 'true'; }

#################################
    # readingsfunction
############# ersetze funktionsstring durch readingsstring

    my $funktionsstringdiff;
    my $funktionsstringtend;
    my $funktionstring = "";
    my $funktionsstringavg;
    my $funktionsstringinc;
    my $hms = AnalyzeCommand( 0, '{return $hms}' );

    if ( $condition =~ m/YEAR|MONTH|DAY|MIN|HOUR|HMS/ ) 
	{
        while ( $condition =~ m/(.*)\[YEAR\](.*)([\d]{4})(.*)/ )
		{
            $condition = $1 . "$year$2$3" . $4;
        }
        while ( $condition =~ m/(.*)\[MONTH\](.*)([\d]{1,2})(.*)/ )
		{

            $condition = $1 . "$month$2$3" . $4;
        }
        while ( $condition =~ m/(.*)\[DAY\](.*)([\d]{1,2})(.*)/ )
		{
            $condition = $1 . "$mday$2$3" . $4;
        }

        while ( $condition =~ m/(.*)\[MIN\](.*)([\d]{1,2})(.*)/ )
		{
            $condition = $1 . "$min$2$3" . $4;
        }
        while ( $condition =~ m/(.*)\[HOUR\](.*)([\d]{1,2})(.*)/ )
		{
            $condition = $1 . "$hour$2$3" . $4;
        }
        while ( $condition =~ m/(.*)\[HMS\](.*)/ )
		{
            $condition = $1 . "\"$hms\"" . $2;
        }
    }

##############
    # $condition
    # perlersetzung
##############
    my $x     = 0;
    my $field = "";
    my $SELF  = $name;

    while ( $condition =~m/(.*?)\[(ReadingsVal|ReadingsNum|ReadingsAge|AttrVal|InternalVal):(.*?):(.*?):(.*?)\](.*)/)
    {
        my $firstpart       = $1;
        my $readingtyp      = $2;
        my $readingdevice   = $3;
        my $readingname     = $4;
        my $readingstandart = $5;
        my $lastpart        = $6;
        $readingdevice =~ s/\$SELF/$name/;
        my $code = "("
          . $readingtyp . "('"
          . $readingdevice . "', '"
          . $readingname . "', '"
          . $readingstandart . "'))";

        $condition = $firstpart . $code . $lastpart;
        $x++;
        last if $x > 10;    #notausstieg
    }


    $x = 0;
    while ( $condition =~ m/(.*)\{(.+)\}(.*)/ )    #z.b $WE
    {
        my $firstpart  = $1;
        my $secondpart = $2;
        my $lastpart   = $3;
        my $exec       = "\$field = " . $2;
        if ( $secondpart =~ m/(!\$.*|\$.*)/ )
		{
            $field = $secondpart;
        }
        else 
		{
			{
			no warnings;
            eval($exec);
			}
        }

        if ( $field =~ m/([0-9]{2}):([0-9]{2}):([0-9]{2})/ ) 
		{
            my $hh = $1;
            if ( $hh > 23 ) { $hh = $hh - 24 }
            $field = $hh . ":" . $2;
        }

        $condition = $firstpart . $field . $lastpart;
        $x++;
        last if $x > 10;    #notausstieg
    }

    if ( $attrrandomnumber ne '' )
	{
        MSwitch_Createnumber($hash);
    }
    my $anzahlk1 = $condition =~ tr/{//;
    my $anzahlk2 = $condition =~ tr/}//;

    if ( $anzahlk1 ne $anzahlk2 )
	{
        $hash->{helper}{conditioncheck} = "Klammerfehler";
        return "false";
    }

    $anzahlk1 = $condition =~ tr/(//;
    $anzahlk2 = $condition =~ tr/)//;

    if ( $anzahlk1 ne $anzahlk2 )
	{
        $hash->{helper}{conditioncheck} = "Klammerfehler";
        return "false";
    }

    $anzahlk1 = $condition =~ tr/[//;
    $anzahlk2 = $condition =~ tr/]//;

    if ( $anzahlk1 ne $anzahlk2 )
	{
        $hash->{helper}{conditioncheck} = "Klammerfehler";
        return "false";
    }

    my $arraycount = '0';
    my $finalstring;
    my $answer;
    my $i;
    my $pos;
    my $pos1;
    my $part;
    my $part1;
    my $part2;
    my $part3;
    my $lenght;

    # wildcardcheck

    my $we = AnalyzeCommand( 0, '{return $we}' );
    my @perlarray;
    ### perlteile trennen

    #######################
    my @evtparts;
    if ($event || $event ne "")
	{
        @evtparts = split( /:/, $event );
    }
    else 
	{
        $event       = "";
        $evtparts[0] = "";
        $evtparts[1] = "";
        $evtparts[2] = "";
    }
	
	if (!defined $evtparts[0]){ $evtparts[0]="";}
	if (!defined $evtparts[1] ){$evtparts[1]="";}
	if (!defined $evtparts[2]){ $evtparts[2]="";}
	
    my $evtsanzahl = $hash->{helper}{evtparts}{parts};
	my $evtfull = $event;
    $event = $evtparts[1].":".$evtparts[2];
	
    my $evtcmd1 = ReadingsVal( $name, 'EVT_CMD1_COUNT', '0' );
    my $evtcmd2 = ReadingsVal( $name, 'EVT_CMD2_COUNT', '0' );
	
	$condition =~ s/\:\$EVENT/:$event/ig;
    $condition =~ s/\:\$EVTFULL/:$evtfull/ig;
    $condition =~ s/\:\$EVTPART1/:$evtparts[0]/ig;
    $condition =~ s/\:\$EVTPART2/:$evtparts[1]/ig;
	$condition =~ s/\:\$EVTPART3/:$evtparts[2]/ig;

    $condition =~ s/\$EVENT/"$event"/ig;
    $condition =~ s/\$EVTFULL/"$evtfull"/ig;
    $condition =~ s/\$EVTPART1/"$evtparts[0]"/ig;
    $condition =~ s/\$EVTPART2/"$evtparts[1]"/ig;
    $condition =~ s/\$EVTPART3/"$evtparts[2]"/ig;

    $condition =~ s/\$EVT_CMD1_COUNT/$evtcmd1/ig;
    $condition =~ s/\$EVT_CMD2_COUNT/$evtcmd2/ig;
    
    $condition =~ s/{!\$we}/ !\$we /ig;
    $condition =~ s/{\$we}/ \$we /ig;
    $condition =~ s/{sunset\(\)}/{ sunset\(\) }/ig;
    $condition =~ s/{sunrise\(\)}/{ sunrise\(\) }/ig;

    $x = 0;
    while ( $condition =~ m/(.*?)(\$NAME)(.*)?/ )
	{
        my $firstpart  = $1;
        my $secondpart = $2;
        my $lastpart   = $3;
        $condition = $firstpart . $name . $lastpart;
        $x++;
        last if $x > 10;    #notausstieg
    }

    $x = 0;
    while ( $condition =~ m/(.*?)(\$SELF)(.*)?/ )
	{
        my $firstpart  = $1;
        my $secondpart = $2;
        my $lastpart   = $3;
        $condition = $firstpart . $name . $lastpart;
        $x++;
        last if $x > 10;    #notausstieg
    }

    my $searchstring;
    $x = 0;
    while ( $condition =~m/(.*?)(\[\[[a-zA-Z][a-zA-Z0-9_]{0,30}:[a-zA-Z0-9_]{0,30}\]-\[[a-zA-Z][a-zA-Z0-9_]{0,30}:[a-zA-Z0-9_]{0,30}\]\])(.*)?/)
    {
        my $firstpart = $1;
        $searchstring = $2;
        my $lastpart = $3;
        $x++;
        last if $x > 10;    #notausstieg
        my $x = 0;
        # Searchstring -> [[t1:state]-[t2:state]]
        while ( $searchstring =~ m/(.*?)(\[[a-zA-Z][a-zA-Z0-9_]{0,30}:[a-zA-Z0-9_]{0,30}\])(.*)?/ )
        {
            my $read1           = '';
            my $firstpart       = $1;
            my $secsearchstring = $2;
            my $lastpart        = $3;
            if ( $secsearchstring =~ m/\[(.*):(.*)\]/ )
			{
                $read1 = ReadingsVal( $1, $2, 'undef' );
            }
            $searchstring = $firstpart . $read1 . $lastpart;
            $x++;
            last if $x > 10;    #notausstieg
        }
        $condition = $firstpart . $searchstring . $lastpart;
    }

    $x = 0;
    while ( $condition =~ m/(.*)(\{ )(.*)(\$we)( \})(.*)/ )
	{
        last if $x > 20;        # notausstieg
        $condition = $1 . " " . $3 . $4 . " " . $6;
    }

    ###################################################
    # ersetzte sunset sunrise
    $x = 0;    # notausstieg
    while (  $condition =~ m/(.*)(\{ )(sunset\([^}]*\)|sunrise\([^}]*\))( \})(.*)/ )
    {
        $x++;    # notausstieg
        last if $x > 20;    # notausstieg
        if ( defined $2 ) {

			my $part2;
			{
			no warnings;
            $part2 = eval $3;
			
			}
            chop($part2);
            chop($part2);
            chop($part2);
            my ( $testhour, $testmin ) = split( /:/, $part2 );
            if ( $testhour > 23 ) {
                $testhour = $testhour - 24;
                $testhour = '0' . $testhour if $testhour < 10;
                $part2    = $testhour . ':' . $testmin;
            }
            $condition = $part2;
            $condition = $1 . $condition if ( defined $1 );
            $condition = $condition . $5 if ( defined $5 );
        }
    }
    my $conditioncopy = $condition;
    my @argarray;
    $arraycount = '0';
    $pos        = '';
    $pos1       = '';
    $part       = '';
    $part1      = '';
    $part2      = '';
    $part3      = '';
    $lenght     = '';


	
    ## verursacht fehlerkennung bei angabe von regex [a-zA-Z]
	ARGUMENT: for ( $i = 0 ; $i <= 10 ; $i++ )
	{
        $pos = index( $condition, "[", 0 );
        my $x = $pos;
        if ( $x == '-1' ) { last ARGUMENT; }
        $pos1 = index( $condition, "]", 0 );
        $argarray[$arraycount] =substr( $condition, $pos, ( $pos1 + 1 - $pos ) );
        $lenght = length($condition);
        $part1  = substr( $condition, 0, $pos );
        $part2  = 'ARG' . $arraycount;
        $part3 = substr( $condition, ( $pos1 + 1 ), ( $lenght - ( $pos1 + 1 ) ) );
        $condition = $part1 . $part2 . $part3;
        $arraycount++;
    }

    $condition =~ s/ AND / && /ig;
    $condition =~ s/ OR / || /ig;
    $condition =~ s/ = / == /ig;

	MSwitch_LOG( $name, 6, "Bedingung nach Ersetzungen: $condition" );

	END:
 
    # teste auf typ
    my $count = 0;
    my $testarg;
    my @newargarray;
    foreach my $args (@argarray)
	{
        $testarg = $args;
        if ( $testarg =~ '.*:h\d{1,3}' )
		{
            # historyformatierung erkannt - auswerten über sub
            # in der regex evtl auf zeilenende definieren
            $newargarray[$count] = MSwitch_Checkcond_history( $args, $name );
            $count++;
            next;
        } 
        $testarg =~ s/[0-9]+//gs;
        if ( $testarg eq '[:-:|]' || $testarg eq '[:-:]' )
		{
            # timerformatierung erkannt - auswerten über sub
            # my $param = $argarray[$count];
            $newargarray[$count] = MSwitch_Checkcond_time( $args, $name );
        }
        elsif ( $testarg =~ '[.*:.*]' )
		{
            # stateformatierung erkannt - auswerten über sub
            $newargarray[$count] = MSwitch_Checkcond_state( $args, $name );
        }
        else 
		{
            $newargarray[$count] = $args;
        }
        $count++;
    }

    $count = 0;
    my $tmp;
    foreach my $args (@newargarray)
	{
        $tmp = 'ARG' . $count;
        $condition =~ s/$tmp/$args/ig;
        $count++;
    }
	
    $finalstring ="if (" . $condition . "){\$answer = 'true';} else {\$answer = 'false';} ";
    MSwitch_LOG( $name, 6, "Bedingungsprüfung2 (final): $finalstring ");

	my $ret;
	{
		no warnings;
		$ret = eval $finalstring;
	}


	if ($@)
		{
			MSwitch_LOG( $name, 1, "############# " . __LINE__ );
			MSwitch_LOG( $name, 1, "$name EERROR: $@ ");
			MSwitch_LOG( $name, 1, "Finalstring: $finalstring");
			MSwitch_LOG( $name, 1, "Event: $event");
			MSwitch_LOG( $name, 1, "Eventfull: $evtfull");
			MSwitch_LOG( $name, 1, "############# \n" );
			$hash->{helper}{conditionerror} = $@;
			return 'false';
		}

    MSwitch_LOG( $name, 6,"Ergebniss Bedingungsprüfung : $ret " );
    if ( $ret ne "true" )
	{
        MSwitch_LOG( $name, 6, "Befehlsabbruch - Bedingung nicht erfüllt " );
    }
    $hash->{helper}{conditioncheck} = $finalstring;
    return $ret;
}
####################
####################
sub MSwitch_Checkcond_state($$) {
    my ( $condition, $name ) = @_;
	my $hash       = $modules{MSwitch}{defptr}{$name};
	my $event =$hash->{helper}{aktevent};
	if ($event)
	{
		my @evtparts = split( /:/, $event,$hash->{helper}{evtparts}{parts} );
		$condition =~ s/\$EVENT/$event/ig;
		$condition =~ s/\$EVTFULL/$event/ig;
		$condition =~ s/\$EVTPART1/$evtparts[0]/ig;
		$condition =~ s/\$EVTPART2/$evtparts[1]/ig;
		$condition =~ s/\$EVTPART3/$evtparts[2]/ig;
	}

    my $x = 0;
    while ( $condition =~ m/(.*?)(\$SELF)(.*)?/ )
	{
        my $firstpart  = $1;
        my $secondpart = $2;
        my $lastpart   = $3;
        $condition = $firstpart . $name . $lastpart;
        $x++;
        last if $x > 10;    #notausstieg
    }
	
    $condition =~ s/\[//;
    $condition =~ s/\]//;

    my @reading = split( /:/, $condition );
    my $return;
    my $test;

    if ( defined $reading[2] and $reading[2] eq "d" ) 
	{
        $test = ReadingsNum( $reading[0], $reading[1], 'undef' );
        $return ="ReadingsNum('$reading[0]', '$reading[1]', 'undef')";    #00:00:00
    }
    else 
	{
        $test = ReadingsVal( $reading[0], $reading[1], 'undef' );
        $return = "ReadingsVal('$reading[0]', '$reading[1]', 'undef')";    #00:00:00
    }
    return $return;
}
####################
sub MSwitch_Checkcond_time($$) {
    my ( $condition, $name ) = @_;
    MSwitch_LOG( $name, 6, "zeitbezogene Bedingung gefunden: $condition L:" . __LINE__ );
    $condition =~ s/\[//;
    $condition =~ s/\]//;
    my $hash         = $defs{$name};
    my $adday        = 0;
    my $days         = '';
    my $daycondition = '';
    ( $condition, $days ) = split( /\|/, $condition )if index( $condition, "|", 0 ) > -1;
    my ( $tformat1, $tformat2 ) = split( /-/, $condition );
    my ( $t11,      $t12 )      = split( /:/, $tformat1 );
    my ( $t21,      $t22 )      = split( /:/, $tformat2 );
    my $hour1 = sprintf( "%02d", $t11 );
    my $min1  = sprintf( "%02d", $t12 );
    my $hour2 = sprintf( "%02d", $t21 );
    my $min2  = sprintf( "%02d", $t22 );
    if ( $hour1 eq "24" )    # test auf 24 zeitangabe
    {
        $hour1 = "00";
    }
    if ( $hour2 eq "24" )
	{
        $hour2 = "00";
    }
    my $time = localtime;
    $time =~ s/\s+/ /g;
    my ( $day, $month, $date, $n, $time1 ) = split( / /, $time );
    my ( $akthour, $aktmin, $aktsec ) = split( /:/, $n );
    ############ timecondition 1
    my $timecondtest;
    my $timecond1;
    my $timecond2;
    my ( $tday, $tmonth, $tdate, $tn );
    $timecondtest = localtime;
    $timecondtest =~ s/\s+/ /g;
    ( $tday, $tmonth, $tdate, $tn, $time1 ) = split( / /, $timecondtest );
    delete( $hash->{helper}{wrongtimespeccond} );
    if ( $hour1 > 23 || $min1 > 59 || $hour2 > 23 || $min2 > 59 )
	{
        $hash->{helper}{wrongtimespeccond} ="ERROR: wrong timespec in condition. $condition";
        my $return = "(0 < 0 && 0 > 0)";
        MSwitch_LOG( $name, 1,"$name:  ERROR wrong format in Condition $condition Format must be HH:MM." );
        return $return;
    }
    $timecond1 = timelocal( '00', $min1, $hour1, $tdate, $tmonth, $time1 );
    $timecond2 = timelocal( '00', $min2, $hour2, $tdate, $tmonth, $time1 );
    my $timeaktuell = timelocal( '00', $aktmin, $akthour, $date, $month, $time1 );

    if ( $timeaktuell < $timecond2 && $timecond2 < $timecond1 )
	{
        use constant SECONDS_PER_DAY => 60 * 60 * 24;
        $timecond1 = $timecond1 - SECONDS_PER_DAY;
        $adday     = 1;
    }
    if ( $timeaktuell > $timecond1 && $timecond2 < $timecond1 )
	{
        use constant SECONDS_PER_DAY => 60 * 60 * 24;
        $timecond2 = $timecond2 + SECONDS_PER_DAY;
        $adday     = 1;
    }
    my $return = "($timecond1 <= $timeaktuell && $timeaktuell <= $timecond2)";
    if ( $days ne '' )
	{
        $daycondition = MSwitch_Checkcond_day( $days, $name, $adday, $day );
        $return = "($return $daycondition)";
    }
    MSwitch_LOG( $name, 6,"Ergebniss zeitbezogene Bedingung: $return L:" . __LINE__ );
    return $return;
}
####################
sub MSwitch_Checkcond_history($$) {
    my ( $condition, $name ) = @_;
    $condition =~ s/\[//;
    $condition =~ s/\]//;
    my $hash = $defs{$name};
    MSwitch_LOG( $name, 6,"historybezogene Bedingung gefunden: $condition L:" . __LINE__ );

    my $return;
    my $seq;
    my $x   = 0;
    my $log = $hash->{helper}{eventlog};
    if ( $hash->{helper}{history}{eventberechnung} ne "berechnet" )    # teste auf vorhandene berechnung
    {
        foreach $seq ( sort { $b <=> $a } keys %{$log} )
		{
            my @historyevent = split( /:/, $hash->{helper}{eventlog}{$seq} );
            $hash->{helper}{history}{event}{$x}{EVENT} =$historyevent[1] . ":" . $historyevent[2];
            $hash->{helper}{history}{event}{$x}{EVTFULL} =$hash->{helper}{eventlog}{$seq};
            $hash->{helper}{history}{event}{$x}{EVTPART1} = $historyevent[0];
            $hash->{helper}{history}{event}{$x}{EVTPART2} = $historyevent[1];
            $hash->{helper}{history}{event}{$x}{EVTPART3} = $historyevent[2];
            $x++;
        }
    $hash->{helper}{history}{eventberechnung} = "berechnet";
    }

    my @historysplit = split( /\:/, $condition );
    my $historynumber;
    $historynumber = $historysplit[1];
    $historynumber =~ s/[a-z]+//gs;
    # den letzten inhalt ernittel ( anzahl im array )
    my $inhalt =$hash->{helper}{history}{event}{$historynumber}{ $historysplit[0] }; #????
    $return = "'" . $inhalt . "'";
    MSwitch_LOG( $name, 6, "Ergebniss historybezogene Bedingung: $condition L:" . __LINE__ );
    return $return;
}
####################
sub MSwitch_Checkcond_day($$$$) {
    my ( $days, $name, $adday, $day ) = @_;
    MSwitch_LOG( $name, 6,"tagesbezogene Bedingung gefunden: $days L:" . __LINE__ );
    my %daysforcondition = (
        "Mon" => 1,
        "Tue" => 2,
        "Wed" => 3,
        "Thu" => 4,
        "Fri" => 5,
        "Sat" => 6,
        "Sun" => 7
    );
    $day = $daysforcondition{$day};
    my @daycond = split //, $days;
    my $daycond = '';
    foreach my $args (@daycond)
	{
        if ( $adday == 1 ) { $args++; }
        if ( $args == 8 ) { $args = 1 }
        $daycond = $daycond . "($day == $args) || ";
    }
    chop $daycond;
    chop $daycond;
    chop $daycond;
    chop $daycond;
    $daycond = "&& ($daycond)";
    MSwitch_LOG( $name, 6,"Ergebniss tagesbezogene Bedingung: $daycond L:" . __LINE__ );
    return $daycond;
}

###################################
sub MSwitch_Clear_timer($) {
    my ( $hash, $device ) = @_;
    my $name     = $hash->{NAME};
    my $timehash = $hash->{helper}{timer};
    foreach my $a ( keys %{$timehash} )
	{
        my $inhalt = $hash->{helper}{timer}{$a};
        RemoveInternalTimer($inhalt);
        $inhalt = $hash->{helper}{timer}{$a};
        $inhalt =~ s/-/ /g;
        $inhalt = $name . ' ' . $inhalt;
        RemoveInternalTimer($inhalt);
    }
	RemoveInternalTimer($hash);
    delete( $hash->{helper}{timer} );
}


####################
# newtimerstring
#[REPEAT=00:02*04:10-06:30|RANDOM=20:00-21:00|TIME=17:00|DAYS=1,2,3|MONTH=1,2,3,12|CW=1,2,3]
sub MSwitch_Createtimer($) 
{

	my ($hash) = @_;
    my $Name = $hash->{NAME};
	my $we = AnalyzeCommand( 0, '{return $we}' );
	my $aktuellezeit = gettimeofday();
	my $timerexist = 0;
	MSwitch_Clear_timer($hash);
	delete( $hash->{helper}{wrongtimespec} );
	#### aktuelle daten setzen
	my $akttimestamp = TimeNow();
    my ( $aktdate, $akttime ) = split / /, $akttimestamp;
    my ( $aktyear, $aktmonth, $aktmday ) = split /-/, $aktdate;
	my $showdate = $aktmday.".".$aktmonth.".".$aktyear;
	my $showmonth = $aktmonth;
    $aktmonth = $aktmonth - 1;
    my $time = localtime;
    $time =~ s/\s+/ /g;
    my ( $day, $month, $date, $n, $time1 )=split( / /, $time );    # day enthält aktuellen tag als wochentag
    my $aktday           = $day;
    my %daysforcondition = (
        "Mon" => 1,
        "Tue" => 2,
        "Wed" => 3,
        "Thu" => 4,
        "Fri" => 5,
        "Sat" => 6,
        "Sun" => 7
    );
    my $wday = $daysforcondition{$day};    # enthält aktuellen tag
	my $weekNumber = POSIX::strftime("%V", localtime time);
	# timeranpassung an Bertriebsmode
	my $timercount =5;
	if ( AttrVal( $Name, 'MSwitch_Mode', 'Notify' ) eq "Notify" )
	{
		$timercount =2;
	}
	if ( AttrVal( $Name, 'MSwitch_Mode', 'Notify' ) eq "Toggle" ) 
	{
        $timercount =1;
    }
	for (my $i=1; $i <= 5; $i++)
	{
	my $timer = ReadingsVal( $Name, '.Trigger_time_'.$i, '' );
	$timer =~ s/#\[dp\]/:/g;
	$timer =~ s/\$name/$Name/g;
	next if $timer eq "";	
	$timerexist =1;
	## timer in felder teilen 
	my @alltimers = split (/\[NEXTTIMER\]/,$timer);
	EACHTIMER: foreach my $einzeltimer (@alltimers)
	{
######################## ersetzungen	
		#ersetze Snippetz
		my $x =0;	
		while ( $einzeltimer =~ m/(.*)\[Snippet:([\d]{1,3})\](.*)/ )
		{
			$x++;    # notausstieg notausstieg
			last if $x > 20;    # notausstieg notausstieg
			my $firstpart = $1;
			my $snipppetnumber = $2;
			my $lastpart =$3;
			my $ret=$data{MSwitch}{$Name}{snippet}{$snipppetnumber};
			$ret =~ s/\n/#[nl]/g;
			$einzeltimer = $firstpart .$ret . $lastpart;
		}	
	#ersetze Perl	
	$x=0;
    while ( $einzeltimer =~ m/(.*)\{(.*)\}(.*)/ ) 
	{
        $x++;    # notausstieg
        last if $x > 20;    # notausstieg
        if ( defined $2 ) 
		{
            my $part1 = $1;
			my $part2 =$2;
            my $part3 = $3;
			my $exec=    "my \$name='".$Name."';my \$SELF='".$Name."';my \$return = ".$part2.";return \$return;";
			$exec  =~ s/#\[nl\]/\n/g;
			{
			no warnings;
			$part2 = eval $exec;
			}
			my $part2hh = substr( $part2, 0, 2 );
			my $part2mm = substr( $part2, 3, 2 );
			if ($part2hh >23 ) {$part2hh = $part2hh -24}
			$part2 = $part2hh.":".$part2mm;
            $einzeltimer = $part1 . $part2 . $part3;
        }
    }	
		
	# suche nach setmagic	
	$x = 0;
    while ( $einzeltimer =~ m/(.*)\[([0-9]?[a-zA-Z\$]{1}.*\:.*?)\](.*)/ )
	{
        $x++;    # notausstieg
        last if $x > 20;    # notausstieg
		my $firstpart = $1;
		my $devname = $2;
		my $lastpart =$3;
		$devname =~ s/\$SELF/$Name/g;
		my ($device,$reading)= split (/:/,$devname);
        my $setmagic = ReadingsVal( $device, $reading, 'wrongformat' );
        $einzeltimer = $firstpart  . $setmagic  . $lastpart;
    }	
#############
	my @timerfile = split(/\|/,$einzeltimer);
	my %timertable;
	$timertable{TIME}="";
	$timertable{REPEAT}="";
	$timertable{RANDOM}="";
	$timertable{WDAY}="";
	$timertable{YEAR}="";
	$timertable{CW}="";
	$timertable{DATE}="";
	$timertable{CDAY}="";
	$timertable{CMONTH}="";
	$timertable{ID}="";
	$timertable{WEEK}=""; #weekNumber
	$timertable{WEEKEND}="";
	my $id="";
	foreach my $fullpart (@timerfile)
	{
		my ($part1,$part2)= split (/=/,$fullpart);
		$timertable{$part1}=$part2;
	}

	## prüfe auf nur ein vorkommen einer zeitangabe TIME/RANDOM/REPEAT
	my $control = 0;
	$control++ if $timertable{TIME} ne "";
	$control++ if $timertable{REPEAT} ne "";
	$control++ if $timertable{RANDOM} ne "";
	next  if $control > 1;
	
######### prüfe alle bedingungen , next wenn bedingung nicht erfüllt
# wenn bedingung nicht erfüllt next eachtimer
# [REPEAT=00:02*04:10-06:30|RANDOM=20:00-21:00|TIME=17:00||CW=1,2,3]
# prüfe Kalenderwoche / weekNumber ################################ weekNumber

	if ($timertable{WEEKEND} ne "")
	{
		my $foundweekend = 0;
		if ($we eq  $timertable{WEEKEND})
		{
			$foundweekend =1;
		}
	next EACHTIMER if $foundweekend == 0;
	}

	if ($timertable{WEEK} ne "")
	{
		my @week  = (split(/,/,$timertable{WEEK}));
		my $foundweek = 0;
		foreach my $aktweek (@week){
		$foundweek++ if $aktweek == $weekNumber;	
		}
	next EACHTIMER if $foundweek == 0;
	}

# prüfe day / WDAY ################################
	if ($timertable{WDAY} ne "")
	{
		my @weekkdays  = (split(/,/,$timertable{WDAY}));
		my $foundday = 0;
		foreach my $aktweekday (@weekkdays){
		$foundday++ if $wday == $aktweekday;	
		}
	next EACHTIMER if $foundday == 0;
	}

# prüfe monat / MONTH ##############################
	if ($timertable{CMONTH} ne "")
	{
		my @month  = (split(/,/,$timertable{CMONTH}));
		my $foundmonth = 0;
		foreach my $testmonth (@month){
		$foundmonth++ if $testmonth == $showmonth;
		}
	next EACHTIMER if $foundmonth == 0;
	}

# prüfe kalendertag / CDAY ################################ aktmday
	if ($timertable{CDAY} ne "")
	{
		my @cdays  = (split(/,/,$timertable{CDAY}));
		my $foundcday = 0;
		foreach my $aktcday (@cdays){
		$foundcday++ if $aktmday == $aktcday;	
		}
	next EACHTIMER if $foundcday == 0;
	}

# prüfe datum / CDAY ################################ showdate
	if ($timertable{DATE} ne "")
	{
		my @datum  = (split(/,/,$timertable{DATE}));
		my $founddate = 0;
		foreach my $aktdate (@datum){	
		my @splitdate = (split(/\./,$aktdate));
		$splitdate[0] =~ s/\*/$aktmday/g;
		$splitdate[1] =~ s/\*/$showmonth/g;
		$splitdate[2] =~ s/\*/$aktyear/g;
		$aktdate=$splitdate[0].".".$splitdate[1].".".$splitdate[2];
		$founddate++ if $aktdate eq $showdate;	
		}
	next EACHTIMER if $founddate == 0;
	}

###### setze timer RANDOM
	if ($timertable{RANDOM} ne "")
		{
			my $startrnd = substr( $timertable{RANDOM}, 0, 2 );
			my $endrnd =substr( $timertable{RANDOM}, 3, 2 ) ;
			my $newtimer = MSwitch_Createrandom( $hash,$startrnd ,$endrnd );
			$timertable{TIME}=$newtimer ;
		}
###### setze timer TIMER
	if ($timertable{TIME} ne "")
			{
				my $id="ID".$timertable{ID};
				$id="" if $id eq "ID";
				my $timetoexecute = $timertable{TIME}.":00";
				if ( substr( $timetoexecute, 0, 2 ) > 23 || substr( $timetoexecute, 3, 2 ) > 59 )
				{
					$hash->{helper}{wrongtimespec} ="ERROR: wrong timespec. $timetoexecute";
					$hash->{helper}{wrongtimespec}{typ} = $i;
					return;
				}

				my $timetoexecuteunix = timelocal(
					substr( $timetoexecute, 6, 2 ),
					substr( $timetoexecute, 3, 2 ),
					substr( $timetoexecute, 0, 2 ),
					$date, $aktmonth, $aktyear);

				my $number = $i;
				if ( $id ne "" && ( $i == 3 || $i == 4 ) )
				{
					$number = $number + 3;
				}
				if ( $i == 5 ) { $number = 9; }
				if ( $id ne "" && $number == 9 ) { $number = 10; }

				my $sectowait = $timetoexecuteunix - $aktuellezeit;
				next EACHTIMER if $sectowait <= 0;   # abbruch wenn timer abgelaufen 
				my $inhalt = $timetoexecuteunix . "-" . $number . $id;
				$hash->{helper}{timer}{$inhalt} = "$inhalt";
				my $msg = $Name . " " . $timetoexecuteunix . " " . $number . $id;
				InternalTimer( $timetoexecuteunix, "MSwitch_Execute_Timer", $msg );
			}
			
	
	if ($timertable{REPEAT}	ne "")
		{ 		
			my @repeats = (split(/\*/,$timertable{REPEAT}));
			my $sectoadd     = substr( $repeats[0], 0, 2 ) * 3600 + substr( $repeats[0], 3, 2 ) * 60;
			my $starttime = (split(/-/,$repeats[1]))[0];
			my $endtime = (split(/-/,$repeats[1]))[1];
			my $timecondtest = localtime;
            $timecondtest =~ s/\s+/ /g;
            my ( $tday, $tmonth, $tdate, $tn, $time1 ) = split( / /, $timecondtest );
			if ( substr( $starttime, 0, 2 ) > 23 || substr( $starttime, 3, 2 ) > 59 )
			{
                $hash->{helper}{wrongtimespec} = "ERROR: wrong timespec. $starttime";
                return;
			}
			if ( substr( $endtime, 0, 2 ) > 23 || substr( $endtime, 3, 2 ) > 59 )
			{
                $hash->{helper}{wrongtimespec} = "ERROR: wrong timespec. $endtime";
                return;
			}
			my $timecond1 = timelocal(
                '00',
                substr( $starttime, 3, 2 ),
                substr( $starttime, 0, 2 ),
                $tdate, $tmonth, $time1
            );
			
			my $timecond2 = timelocal(
                '00',
                substr( $endtime, 3, 2 ),
                substr( $endtime, 0, 2 ),
                $tdate, $tmonth, $time1
            );
			
			my $id="ID".$timertable{ID};
			$id="" if $id eq "ID";	

			my $number = $i;
			if ( $id ne "" && ( $i == 3 || $i == 4 ) )
				{
					$number = $number + 3;
				}
			if ( $i == 5 ) { $number = 9; }
			if ( $id ne "" && $number == 9 ) { $number = 10; }

			EACHREPEAT: while ( $timecond1 < $timecond2 ) 
			{
				my $timestamp = substr( FmtDateTime($timecond1), 11, 5 );
				if ( substr( $timestamp, 0, 2 ) > 23 || substr( $timestamp, 3, 2 ) > 59 ) 
				{
					$hash->{helper}{wrongtimespec} = "ERROR: wrong timespec. $timestamp";
					$hash->{helper}{wrongtimespec}{typ} = $i;  # vorgesehen für zukünftige markierung fehlerhafter felder
					return;
				}
					
				my $timetoexecute = $timestamp.":00";			
				my $timetoexecuteunix = timelocal(
					substr( $timetoexecute, 6, 2 ),
					substr( $timetoexecute, 3, 2 ),
					substr( $timetoexecute, 0, 2 ),
					$date, $aktmonth, $aktyear);
				my $sectowait = $timetoexecuteunix - $aktuellezeit;
				$timecond1 = $timecond1 + $sectoadd;
				next EACHREPEAT if $sectowait <= 0;   # abbruch wenn timer abgelaufen   
				my $inhalt = $timetoexecuteunix . "-" . $number . $id;
				$hash->{helper}{timer}{$inhalt} = "$inhalt";
				my $msg = $Name . " " . $timetoexecuteunix . " " . $number . $id;
				InternalTimer( $timetoexecuteunix, "MSwitch_Execute_Timer", $msg );
			}
		}
	} # ENDE EACHTIMER
	}

	return if $timerexist == 0;
    # berechne zeit bis 23,59 und setze timer auf create timer
	# nur ausführen wenn timer belegt 
    my $newask = timelocal( '59', '59', '23', $date, $aktmonth, $aktyear );
    $newask = $newask + 2;
    my $newassktest = FmtDateTime($newask);
    my $msg         = $Name . " " . $newask . " " . 5;
    my $inhalt      = $newask . "-" . 5;
    $hash->{helper}{timer}{$newask} = "$inhalt";
    InternalTimer( $newask, "MSwitch_Execute_Timer", $msg );
	return;
}
##############################
sub MSwitch_Createrandom($$$) {
    my ( $hash, $t1, $t2 ) = @_;
    my $Name       = $hash->{NAME};
    my $testrandom = $t1 . "-" . $t2;
    my $testt1     = $t1;
    my $testt2     = $t2;
    $testt1 =~ s/\://g;
    $testt2 =~ s/\://g;
    my $timecondtest = localtime;
    $timecondtest =~ s/\s+/ /g;
    my ( $tday, $tmonth, $tdate, $tn, $time1 ) = split( / /, $timecondtest );
    my $timecond1 = timelocal(
        '00',
        substr( $t1, 3, 2 ),
        substr( $t1, 0, 2 ),
        $tdate, $tmonth, $time1
    );
    my $timecond2 = timelocal(
        '00',
        substr( $t2, 3, 2 ),
        substr( $t2, 0, 2 ),
        $tdate, $tmonth, $time1
    );
    if ( $testt2 < $testt1 ) { $timecond2 = $timecond2 + 86400 }
    my $newtime    = int( rand( $timecond2 - $timecond1 ) ) + $timecond1;
    my $timestamp  = FmtDateTime($newtime);
    my $timestamp1 = substr( $timestamp, 11, 5 );
    return $timestamp1;
}
###########################
sub MSwitch_Execute_Timer($) {
    my ($input) = @_;
    my ( $Name, $timecond, $param ) = split( / /, $input );
    my $showevents = AttrVal( $Name, "MSwitch_generate_Events", 0 );
	if (AttrVal( $Name, 'MSwitch_Debug', '0' ) ne "0" ){$showevents = 1};
    my $hash = $defs{$Name};
    return "" if ( IsDisabled($Name) );



   if ( ReadingsVal( $Name, '.V_Check', $vupdate ) ne $vupdate ) 
	{
        my $ver = ReadingsVal( $Name, '.V_Check', '' );
        MSwitch_LOG( $Name, 1,"$Name-> Timer blockiert, NOTIFYDEV deaktiviert - Versionskonflikt L:" . __LINE__ );
		$hash->{NOTIFYDEV} = 'no_trigger';
		MSwitch_Clear_timer($hash);
        #delete $own_hash->{NOTIFYDEV};
		
		
        return;
    }




	if ( ReadingsVal( $Name, 'Timercontrol', 'on' ) eq "off" )
	{
		MSwitch_LOG( $Name, 6,
        "ausführung Timer abgebrochen ( deaktiviert ) L:" . __LINE__ );
		return;
	}

	if (!defined $hash || !defined $Name || $hash eq "" || $Name eq "")
	{
		MSwitch_LOG( "MSwitch_Error", 0,"##################################"  );
		MSwitch_LOG( "MSwitch_Error", 0,"MSwitch_Error in exec_timer " );
		MSwitch_LOG( "MSwitch_Error", 0,"eingehende daten: $input " );
		MSwitch_LOG( "MSwitch_Error", 0,"eingehender Hash: $hash " );
		MSwitch_LOG( "MSwitch_Error", 0,"eingehender Name: $Name ");
		MSwitch_LOG( "MSwitch_Error", 0,"Routine abgebrochen");
		MSwitch_LOG( "MSwitch_Error", 0,"##################################"  );
		return;
	}

    MSwitch_LOG( $Name, 6,"ausführung Timer $timecond, $param L:" . __LINE__ );

    if ( defined $hash->{helper}{wrongtimespec}and $hash->{helper}{wrongtimespec} ne "" )
    {
        my $ret = $hash->{helper}{wrongtimespec};
        $ret .= " - Timer werden nicht ausgefuehrt ";
        return;
    }
    my @string = split( /ID/, $param );

    $param = $string[0];
    my $execid = 0;
    $execid = $string[1] if ( $string[1] );

    $hash->{eventsave} = 'unsaved';
    if ( ReadingsVal( $Name, '.V_Check', $vupdate ) ne $vupdate )
	{
        my $ver = ReadingsVal( $Name, '.V_Check', '' );
        MSwitch_LOG( $Name, 1,
                $Name
              . ' Versionskonflikt, aktion abgebrochen !  erwartet:'
              . $vupdate
              . ' vorhanden:'
              . $ver );
        return;
    }
    $hash->{IncommingHandle} = 'fromtimer'if AttrVal( $Name, 'MSwitch_Mode', 'Notify' ) ne "Dummy";
   # readingsSingleUpdate( $hash, "last_activation_by", 'timer', 0 );
    if ( AttrVal( $Name, 'MSwitch_RandomNumber', '' ) ne '' )
	{
        MSwitch_Createnumber1($hash);
    }
    if ( $param eq '5' )
	{
        MSwitch_Createtimer($hash);
        return;
    }
    if ( AttrVal( $Name, 'MSwitch_Condition_Time', "0" ) eq '1' )
	{
        my $triggercondition = ReadingsVal( $Name, '.Trigger_condition', '' );
        $triggercondition =~ s/#\[dp\]/:/g;
        $triggercondition =~ s/#\[pt\]/./g;
        $triggercondition =~ s/#\[ti\]/~/g;
        $triggercondition =~ s/#\[sp\]/ /g;
        if ( $triggercondition ne '' )
		{
            my $ret = MSwitch_checkcondition( $triggercondition, $Name, '' );
            if ( $ret eq 'false' )
			{
                return;
            }
        }
    }
    my $extime = POSIX::strftime( "%H:%M", localtime );
    readingsBeginUpdate($hash);
    readingsBulkUpdate( $hash, "EVENT",$Name . ":execute_timer_P" . $param . ":" . $extime ,$showevents);
    readingsBulkUpdate( $hash, "EVTFULL", $Name . ":execute_timer_P" . $param . ":" . $extime ,$showevents);
    readingsBulkUpdate( $hash, "EVTPART1", $Name ,$showevents);
    readingsBulkUpdate( $hash, "EVTPART2", "execute_timer_P" . $param ,$showevents);
    readingsBulkUpdate( $hash, "EVTPART3", $extime ,$showevents );
    readingsEndUpdate( $hash, $showevents );

    if ( $param eq '1' )
	{
        my $cs = "set $Name on";
        MSwitch_LOG( $Name, 6,"finale Befehlsausführung auf Fhemebene:\n$cs\n L:" . __LINE__ );
        my $errors = AnalyzeCommandChain( undef, $cs );
        if ( defined($errors) ) 
		{
            MSwitch_LOG( $Name, 1,"$Name MSwitch_Execute_Timer: Fehler bei Befehlsausfuehrung ERROR $Name: $errors " . __LINE__ );
        }
    return;
    }
    if ( $param eq '2' )
	{
        my $cs = "set $Name off";
        MSwitch_LOG( $Name, 6, "finale Befehlsausführung auf Fhemebene:\n$cs\n L:" . __LINE__ );

        my $errors = AnalyzeCommandChain( undef, $cs );
        if ( defined($errors) )
		{
            MSwitch_LOG( $Name, 1,"$Name MSwitch_Execute_Timer: Fehler bei Befehlsausfuehrung ERROR $Name: $errors "  . __LINE__ );
        }
    return;
    }
    if ( $param eq '3' )
	{
        MSwitch_Exec_Notif( $hash, 'on', 'nocheck', '', 0 );
        return;
    }
    if ( $param eq '4' )
	{
        MSwitch_Exec_Notif( $hash, 'off', 'nocheck', '', 0 );
        return;
    }
    if ( $param eq '6' )
	{

        MSwitch_Exec_Notif( $hash, 'on', 'nocheck', '', $execid );
        return;
    }
    if ( $param eq '7' )
	{
        MSwitch_Exec_Notif( $hash, 'off', 'nocheck', '', $execid );
        return;
    }
    if ( $param eq '9' )
	{
        MSwitch_Exec_Notif( $hash, 'on',  'nocheck', '', 0 );
        MSwitch_Exec_Notif( $hash, 'off', 'nocheck', '', 0 );
        return;
    }
    if ( $param eq '10' )
	{
        MSwitch_Exec_Notif( $hash, 'on',  'nocheck', '', $execid );
        MSwitch_Exec_Notif( $hash, 'off', 'nocheck', '', $execid );
        return;
    }
    return;
}
####################
sub MSwitch_ChangeCode($$) {
    my ( $hash, $option ) = @_;
    my $Name = $hash->{NAME};
    my $x    = 0;               # exit secure
    while ( $option =~ m/(.*)\{(sunset|sunrise)(.*)\}(.*)/ ) 
	{
        $x++;                   # exit secure
        last if $x > 20;        # exit secure
        if ( defined $2 )
		{
			my $part2;
			{
			no warnings;
            $part2 = eval $2 . $3;
			}
			
			
            chop($part2);
            chop($part2);
            chop($part2);
            $option = $part2;
            $option = $1 . $option if ( defined $1 );
            $option = $option . $4 if ( defined $4 );
        }
    }
    return $option;
}
####################
sub MSwitch_Add_Device($$) {
    my ( $hash, $device ) = @_;
    my $Name       = $hash->{NAME};
	my $showevents = AttrVal( $Name, "MSwitch_generate_Events", 0 );
	if (AttrVal( $Name, 'MSwitch_Debug', '0' ) ne "0" ){$showevents = 1};
    my @olddevices = split( /,/, ReadingsVal( $Name, '.Device_Affected', '' ) );
    my $count      = 1;
	LOOP7: foreach (@olddevices)
	{
        my ( $devicename, $devicecmd ) = split( /-AbsCmd/, $_ );
        if ( $device eq $devicename ) { $count++; }
    }
    my $newdevices .= ',' . $device . '-AbsCmd' . $count;
    my $newset = ReadingsVal( $Name, '.Device_Affected', '' ) . $newdevices;
    $newdevices = join( ',', @olddevices ) . ',' . $newdevices;
    my @sortdevices = split( /,/, $newdevices );
    @sortdevices = sort @sortdevices;
    $newdevices  = join( ',', @sortdevices );
    $newdevices  = substr( $newdevices, 1 );
    readingsSingleUpdate( $hash, ".Device_Affected", $newdevices, $showevents );
    return;
}
###################################
sub MSwitch_Del_Device($$) {
    my ( $hash, $device ) = @_;
    my $Name = $hash->{NAME};
    my @olddevices = split( /,/, ReadingsVal( $Name, '.Device_Affected', '' ) );
    my @olddevicesset =
      split( /#\[ND\]/, ReadingsVal( $Name, '.Device_Affected_Details', '' ) );
    my @newdevice;
    my @newdevicesset;
    my $count = 0;
	LOOP8: foreach (@olddevices)
	{
        if ( $device eq $_ )
		{
            $count++;
            next LOOP8;
        }
        push( @newdevice,     $olddevices[$count] );
        push( @newdevicesset, $olddevicesset[$count] );
        $count++;
    }
    my ( $devicemaster, $devicedeleted ) = split( /-AbsCmd/, $device );
    $count = 1;
    my @newdevice1;
	LOOP9: foreach (@newdevice)
	{
        my ( $devicename, $devicecmd ) = split( /-AbsCmd/, $_ );
        if ( $devicemaster eq $devicename )
		{
            my $newname = $devicename . '-AbsCmd' . $count;
            $count++;
            push( @newdevice1, $newname );
            next LOOP9;
        }
     push( @newdevice1, $_ );
    }
    $count = 1;
    my @newdevicesset1;
	LOOP10: foreach (@newdevicesset)
	{
        my ( $name,       @comands )   = split( /#\[NF\]/, $_ );
        my ( $devicename, $devicecmd ) = split( /-AbsCmd/, $name );
        if ( $devicemaster eq $devicename )
		{
            my $newname =
                $devicename
              . '-AbsCmd'
              . $count . '#[NF]'
              . join( '#[NF]', @comands );
            push( @newdevicesset1, $newname );
            $count++;
            next LOOP10;
        }
    push( @newdevicesset1, $_ );
    }
    my $newaffected = join( ',', @newdevice1 );
    if ( $newaffected eq '' ) { $newaffected = 'no_device' }
    my $newaffecteddet = join( '#[ND]', @newdevicesset1 );
    readingsBeginUpdate($hash);
    readingsBulkUpdate( $hash, ".Device_Affected",         $newaffected );
    readingsBulkUpdate( $hash, ".Device_Affected_Details", $newaffecteddet );
    readingsEndUpdate( $hash, 0 );
    my $devices = MSwitch_makeAffected($hash);
    my $devhash = $hash->{DEF};
    my @dev     = split( /#/, $devhash );
    $hash->{DEF} = $dev[0] . ' # ' . $devices;
	return;
}
###################################
sub MSwitch_Debug($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
    my $debug1 = ReadingsVal( $Name, '.Device_Affected',         0 );
    my $debug2 = ReadingsVal( $Name, '.Device_Affected_Details', 0 );
    my $debug3 = ReadingsVal( $Name, '.Device_Events',           0 );
    $debug2 =~ s/:/ /ig;
    $debug3 =~ s/,/, /ig;
    readingsBeginUpdate($hash);
    readingsBulkUpdate( $hash, "Device_Affected",         $debug1 );
    readingsBulkUpdate( $hash, "Device_Affected_Details", $debug2 );
    readingsBulkUpdate( $hash, "Device_Events",           $debug3 );
    readingsEndUpdate( $hash, 0 );
}
###################################
sub MSwitch_Delete_Delay($$) {
    my ( $hash, $device ) = @_;
    my $Name     = $hash->{NAME};
    my $timehash = $hash->{helper}{delays};
    if ( $device eq 'all' )
	{
        foreach my $a ( keys %{$timehash} )
		{
            my $inhalt = $hash->{helper}{delays}{$a};
            RemoveInternalTimer($a);
            RemoveInternalTimer($inhalt);
            delete( $hash->{helper}{delays}{$a} );
        }
    }
    else 
	{
        foreach my $a ( keys %{$timehash} )
		{
            my $pos = index( $a, "$device", 0 );
            if ( $pos != -1 )
			{
                RemoveInternalTimer($a);
                my $inhalt = $hash->{helper}{delays}{$a};
                RemoveInternalTimer($a);
                RemoveInternalTimer($inhalt);
                delete( $hash->{helper}{delays}{$a} );
            }
        }
    }
    return;
}

###################################
sub MSwitch_Delete_specific_Delay($$$) {
    my ( $hash, $name, $indikator ) = @_;
    my $timehash = $hash->{helper}{delays};
    foreach my $a ( sort keys %{$timehash} )
	{
        my @timers = split( /#\[tr\]/, $a );
        if ( index( $timers[3], $indikator ) > -1 )
		{
            my $inhalt = $hash->{helper}{delays}{$a};
            RemoveInternalTimer($a);
            RemoveInternalTimer($inhalt);
            delete( $hash->{helper}{delays}{$a} );
        }

    }
    return;
}
##################################
# Eventsimulation
sub MSwitch_Check_Event($$) {
    my ( $hash, $eventin ) = @_;
    my $Name = $hash->{NAME};
    $eventin =~ s/~/ /g;
    my $dev_hash = "";
	
	
	
    if ( $eventin ne $hash ) 
	{
        if ( ReadingsVal( $Name, '.Trigger_device', '' ) eq "all_events" ) 
		{
            my @eventin = split( /:/, $eventin );
            $dev_hash = $defs{ $eventin[0] };

            if ( $eventin[0] eq "MSwitch_Self" ) 
			{
                $hash->{helper}{testevent_device} = $eventin[0];
                $hash->{helper}{testevent_event} = $eventin[1] . ":" . $eventin[2];
            }
            else 
			{
                $hash->{helper}{testevent_device} = $eventin[0];
                $hash->{helper}{testevent_event} =$eventin[1] . ":" . $eventin[2];
            }
        }
        else 
		{
            my @eventin = split( /:/, $eventin );
            if ( $eventin[0] ne "MSwitch_Self" )
			{
                $dev_hash = $defs{ ReadingsVal( $Name, '.Trigger_device', '' ) };
                $hash->{helper}{testevent_device} = ReadingsVal( $Name, '.Trigger_device', '' );
                $hash->{helper}{testevent_event} = $eventin[0] . ":" . $eventin[1];
            }
            else
			{
                $dev_hash = $hash;
				$hash->{helper}{testevent_device} = "MSwitch_Self";
                $hash->{helper}{testevent_event} = $eventin[1] . ":" . $eventin[2];
            }
        }
    }
	
	
    if ( $eventin eq $hash )
	{
        my $logout = $hash->{helper}{writelog};
        $logout =~ s/:/[#dp]/g;
        my $triggerdevice =ReadingsVal( $Name, '.Trigger_device', 'no_trigger' );
        if ( ReadingsVal( $Name, '.Trigger_device', '' ) eq "all_events" )
		{
            $dev_hash                         = $hash;
            $hash->{helper}{testevent_device} = 'Logfile';
            $hash->{helper}{testevent_event}  = "writelog:" . $logout;
        }
        elsif ( ReadingsVal( $Name, '.Trigger_device', '' ) eq "Logfile" )
		{
            $dev_hash                         = $hash;
            $hash->{helper}{testevent_device} = 'Logfile';
            $hash->{helper}{testevent_event}  = "writelog:" . $logout;
        }
        else
		{
            $dev_hash = $defs{ ReadingsVal( $Name, '.Trigger_device', '' ) };
            $hash->{helper}{testevent_device} = ReadingsVal( $Name, '.Trigger_device', '' );
            $hash->{helper}{testevent_event} = "writelog:" . $logout;
        }
    }
    my $we = AnalyzeCommand( 0, '{return $we}' );
    MSwitch_Notify( $hash, $dev_hash );

    delete( $hash->{helper}{testevent_device} );
    delete( $hash->{helper}{testevent_event} );
    return;
}

#########################################
sub MSwitch_makeAffected($) {
    my ($hash)  = @_;
    my $Name    = $hash->{NAME};
    my $devices = '';
    my %saveaffected;
    my @affname;
    my $affected = ReadingsVal( $Name, '.Device_Affected', 'nodevices' );
    my @affected = split( /,/, $affected );
	LOOP30: foreach (@affected)
	{
        @affname = split( /-/, $_ );
        $saveaffected{ $affname[0] } = 'on';
    }
    foreach my $a ( keys %saveaffected )
	{
        $devices = $devices . $a . ' ';
    }
    chop($devices);
    return $devices;
}




#############################
sub MSwitch_checktrigger_new(@) {
    my ( $own_hash, $triggerfield, $zweig ) = @_;
    #my ( $own_hash, $ownName, , $triggerfield,  $zweig,  $eventcopy, @eventsplit ) = @_;

	my $device			=$own_hash->{helper}{evtparts}{device};
	my $eventstellen	=$own_hash->{helper}{evtparts}{parts};
	my $ownName			=$own_hash->{NAME};
	my $eventcopy		=$own_hash->{helper}{evtparts}{evtfull};
	
	
	
	#Log3("test",0,"eventcopy: $eventcopy ".__LINE__);
	#Log3("test",0,"triggerfield: $triggerfield ".__LINE__);
	
	
	
	return if !defined $eventcopy;
	my @eventsplit   	= split( /:/, $eventcopy ,$own_hash->{helper}{evtparts}{parts});
	
#		$own_hash->{helper}{evtparts}{parts}=3;
#		$own_hash->{helper}{evtparts}{device}	=$incommingdevice;
#		$own_hash->{helper}{evtparts}{evtpart1}	=$eventteile[0];
#		$own_hash->{helper}{evtparts}{evtpart2}	=$eventteile[1];
#		$own_hash->{helper}{evtparts}{evtpart3}	=$eventteile[2];
#		$own_hash->{helper}{evtparts}{evtfull}	=$eventcopy;
			
	

   MSwitch_LOG( $ownName, 6, "prüfe trigger $triggerfield und Event $eventcopy L:" . __LINE__ );
   
   
   

 my @triggerarray =split (/:/,$triggerfield);

#global:INITIALIZED


 if (@triggerarray == 1 && ($triggerarray[0] eq "INITIALIZED" || $triggerarray[0] eq "SHUTDOWN" || $triggerarray[0] eq "ATTR")){
	unshift(@triggerarray,"global");
	unshift(@triggerarray,"global");
	$triggerfield = join ":",@triggerarray;
 }



 if (@triggerarray == 2)
 {
	# Systemumstellung Trigger 2stellig auf trigger 3stellig
	#Log3($ownName,0,"$ownName - $triggerfield");
	unshift(@triggerarray,$own_hash->{helper}{evtparts}{device});
	$triggerfield = join ":",@triggerarray;
	#Log3($ownName,0,"altes Triggerformat gefunden - automatische Umstellung , bitte anpassen");
 }
   
   
   
   	#Log3("test",0,"eventcopy: $eventcopy ".__LINE__);
	#Log3("test",0,"triggerfield: $triggerfield ".__LINE__);
	
	
	
	
   
    my $triggeron     = ReadingsVal( $ownName, '.Trigger_on',      '' );
    my $triggeroff    = ReadingsVal( $ownName, '.Trigger_off',     '' );
    my $triggercmdon  = ReadingsVal( $ownName, '.Trigger_cmd_on',  '' );
    my $triggercmdoff = ReadingsVal( $ownName, '.Trigger_cmd_off', '' );
	
	################ versiosnpassung
	
	
	
	
	################################
	
    my $answer        = "";
	
	########## teste zusatzbedingung #################
	#pct:.*[*>10]
	MSwitch_LOG( $ownName, 6,"start triggerfeld: $triggerfield  L:" . __LINE__ );


# trigger enthält bedingung
	if ( $triggerfield =~ m/(.*)\[(.*)\]/ )
	{
		MSwitch_LOG( $ownName, 6,"Zsatzbedingung gefunden: $triggerfield  L:" . __LINE__ );
		my $eventpart =$1;
		my $eventbedingung = $2;
		my $eventparts = $own_hash->{helper}{evtparts}{parts};
		$triggerfield =$eventpart;
		MSwitch_LOG( $ownName, 6,"eventpart $eventpart  L:" . __LINE__ );
		MSwitch_LOG( $ownName, 6,"eventbedingung $eventbedingung  L:" . __LINE__ );
		MSwitch_LOG( $ownName, 6,"eventparts $eventparts  L:" . __LINE__ );
		#my @eventteile= split( /:/, $eventpart ,$eventparts )	;
		MSwitch_LOG( $ownName, 6,"eventparts $eventparts  L:" . __LINE__ );
		my $position ;	
		for ( my $i = 0 ; $i < $eventparts ; $i++ ) 
		{	
			MSwitch_LOG( $ownName, 6,"eventparts($i) $eventsplit[$i]  L:" . __LINE__ );
			if ($eventsplit[$i] eq ".*")
			{
				$position = $i;
			}
		 }	
		MSwitch_LOG( $ownName, 6,"starposition $position  L:" . __LINE__ );
		my $staris =$eventsplit[$position];
		MSwitch_LOG( $ownName, 6,"staris $staris  L:" . __LINE__ );
		my $newcondition = $eventbedingung;
		MSwitch_LOG( $ownName, 6,"oldcondition  $newcondition  L:" . __LINE__ );
	
		if ($staris =~ m/^-?\d+(?:[\.,]\d+)?$/)
		{
			MSwitch_LOG( $ownName, 6,"STARIS =  Zahl L:" . __LINE__ );
			$newcondition =~ s/\*/$staris/g;
		}
		else
		{
			MSwitch_LOG( $ownName, 6,"STARIS =  String  L:" . __LINE__ );
			$newcondition =~ s/\*/"$staris"/g;
			# teste auf string/zahl vergleich
			my $testccondition = $newcondition;
			$testccondition =~ s/ //g;
			MSwitch_LOG( $ownName, 6,"Testcondition $testccondition  L:" . __LINE__ );
			if ($testccondition =~ m/(".*"(>|<)\d+)/)
			{
				MSwitch_LOG( $ownName, 6,"ABBRUCH STRING ZAHL Vergleich gefunden  L:" . __LINE__ );
				return 'undef';
			}
		}
	
		MSwitch_LOG( $ownName, 6,"newcondition  $newcondition  L:" . __LINE__ );
		my $ret = MSwitch_checkcondition($newcondition,$ownName,$eventcopy);
		MSwitch_LOG( $ownName, 6,"bedingungsprüfung  $ret  L:" . __LINE__ );
		return 'undef' if $ret ne "true";;
	}

	# trigger enthält perl
    if ( $triggerfield =~ m/(.*?)\{(.*)\}/ )
	{
        my $SELF = $ownName;
        my $exec = "\$triggerfield = " . $2;
		{
		no warnings;
        eval($exec);
		}
		$triggerfield = $1.$triggerfield.$3;
		MSwitch_LOG( $ownName, 6,"new triggerfield $triggerfield  L:" . __LINE__ );
    }
	
	if ( $triggerfield eq "*" )
     {
         $triggerfield = ".*:.*:.*";
     }
	
################
    if ( $eventcopy =~ m/^$triggerfield/ )
	{
        $answer = "wahr";
    }


    if (   $zweig eq 'on'
        && $answer eq 'wahr'
        && $eventcopy ne $triggercmdoff
        && $eventcopy ne $triggercmdon
        && $eventcopy ne $triggeroff )
    {
        MSwitch_LOG( $ownName, 6, "rückgabe trigger: ON and CMD1 L:" . __LINE__ );
        return 'on';
    }

    if (   $zweig eq 'off'
        && $answer eq 'wahr'
        && $eventcopy ne $triggercmdoff
        && $eventcopy ne $triggercmdon
        && $eventcopy ne $triggeron )
    {
        MSwitch_LOG( $ownName, 6, "rückgabe trigger: OFF and CMD1 L:" . __LINE__ );
        return 'off';
    }

    if ( $zweig eq 'offonly' && $answer eq 'wahr' )
	{
        MSwitch_LOG( $ownName, 6, "rückgabe trigger: CMD2 L:" . __LINE__ );
        return 'offonly';
    }

    if ( $zweig eq 'ononly' && $answer eq 'wahr' )
	{
        MSwitch_LOG( $ownName, 6, "rückgabe trigger: CMD1 L:" . __LINE__ );
        return 'ononly';
    }

    MSwitch_LOG( $ownName, 6,  "rückgabe trigger: kein treffer - es wird kein Zweig ausgeführt L:". __LINE__ );
    return 'undef';
}
###############################
sub MSwitch_VersionUpdate($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
	#Log3($Name,0,"   ");
	my $message="";
	$message.="MSwitch-Strukturupdate -> Autoupdate fuer MSwitch_Device $Name \n";
	$message.="     -> Backup wird angelegt \n";
	mkdir($backupfile,0777);
	$backupfile 	= "backup/MSwitch/Versionsupdate/";
	mkdir($backupfile,0777);
	
	
	
	my $oldversion=ReadingsVal( $Name, '.V_Check', 'V0.0' );
    my $testreading = $hash->{READINGS};
    my @areadings   = ( keys %{$testreading} );
	
	open( BACKUPDATEI, ">".$backupfile.$Name.".".$oldversion.".conf" ); 
        print BACKUPDATEI "#N -> $Name\n";
        foreach my $key (@areadings) {
            next if $key eq "last_exec_cmd";

            my $tmp = ReadingsVal( $Name, $key, 'undef' );
            print BACKUPDATEI "#S $key -> $tmp\n";
        }
        #my %keys;
        foreach my $attrdevice ( keys %{ $attr{$Name} } ) 
        {
            my $inhalt = "#A $attrdevice -> " . AttrVal( $Name, $attrdevice, '' );
            $inhalt =~ s/\n/#[nla]/g;
            print BACKUPDATEI $inhalt . "\n";
        }
		close(BACKUPDATEI);
		#$hash->{Backup_avaible}            = "./".$backupfile.$Name.".".$oldversion.".conf";

	

	
	
	# update eventsteuerung
	# my @triggeron     = split(/:/,ReadingsVal( $Name, '.Trigger_on','' ));
    # my @triggeroff    = split(/:/,ReadingsVal( $Name, '.Trigger_off','' ));
    # my @triggercmdon  = split(/:/,ReadingsVal( $Name, '.Trigger_cmd_on','' ));
    # my @triggercmdoff = split(/:/,ReadingsVal( $Name, '.Trigger_cmd_off','' ));
	# if (@triggeron == 2)
		# {
			# readingsSingleUpdate( $hash, ".Trigger_on", ".*:".ReadingsVal( $Name, '.Trigger_on','' ), 0 ) ;
			# Log3($Name,0,"MSwitch-Strukturupdate -> Reading .Trigger_on update -> ".ReadingsVal( $Name, '.Trigger_on','' ));
		# }
	
	# if (@triggeroff == 2)
		# {
			# readingsSingleUpdate( $hash, ".Trigger_off", ".*:".ReadingsVal( $Name, '.Trigger_off','' ), 0 ) ;
			# Log3($Name,0,"MSwitch-Strukturupdate -> Reading .Trigger_off update -> ".ReadingsVal( $Name, '.Trigger_off','' ));
		# }
		
	# if (@triggercmdon == 2)
		# {
			# readingsSingleUpdate( $hash, ".Trigger_cmd_on", ".*:".ReadingsVal( $Name, '.Trigger_cmd_on','' ), 0 ) ;
			# Log3($Name,0,"MSwitch-Strukturupdate -> Reading .Trigger_cmd_on update -> ".ReadingsVal( $Name, '.Trigger_cmd_on','' ));
		# }
		
	# if (@triggercmdoff == 2)
		# {
			# readingsSingleUpdate( $hash, ".Trigger_cmd_off", ".*:".ReadingsVal( $Name, '.Trigger_cmd_off','' ), 0 ) ;
			# Log3($Name,0,"MSwitch-Strukturupdate -> Reading .Trigger_cmd_off update -> ".ReadingsVal( $Name, '.Trigger_cmd_off','' ));
		# }
	
	####
	
	
	my $triggerchange=ReadingsVal( $Name, 'Trigger_device', 'changed' );
	if ($triggerchange ne "changed")
	{
    readingsSingleUpdate( $hash, ".Trigger_device", $triggerchange, 0 ) ;
	$message.="     -> Readingaenderung Trigger_device-> .Trigger_device -> Trigger: $triggerchange \n";
	$message.="     -> Reading -> Trigger_device bleibt erhalten (Downgrade moeglich) \n";
	}
	
	my $oldtimer = ReadingsVal( $Name, '.Trigger_time', 'undef' );

	if ( $oldtimer ne "undef" )
	{
		$oldtimer =~ s/^\s+//;
		$oldtimer =~ s/#\[dp\]/:/g;	
		$oldtimer =~ s/~offonly/~/ig;
		$oldtimer =~ s/~ononly/~/ig;
		$oldtimer =~ s/~off/~/ig;
		$oldtimer =~ s/^on//ig;
		$oldtimer =~ s/~onoffonly/~/ig;

		# aufteilung in einzeltimer	
		################################################	
		$oldtimer =~ s/\$SELF/$Name/g;
		my @timer = split /~/, $oldtimer;
		$timer[0] = '' if ( !defined $timer[0] );    #on
		$timer[0] = '' if ( $timer[0] eq "on");    #on
		$timer[1] = '' if ( !defined $timer[1] );    #off
		$timer[2] = '' if ( !defined $timer[2] );    #cmd1
		$timer[3] = '' if ( !defined $timer[3] );    #cmd2
		$timer[4] = '' if ( !defined $timer[4] );    #cmd1+2
			
		my $count=0;	
		my $write =0;
		NEXTTIMER: foreach my $option (@timer) 
		{
		$count++;
		next NEXTTIMER if $option eq "";

		my $key = '\]\[';
		$option =~ s/$key/ /ig;
		$key = '\[';
		$option =~ s/$key//ig;
		$key = '\]';
		$option =~ s/$key//ig;

		my @einzeltimer = (split(" ",$option));
		
		my $final="";
		foreach my $einzelt (@einzeltimer) #starte timerline
		{
			$einzelt =~ s/ //ig;
			next if $einzelt eq "";
			next if length($einzelt) < 5;
			my @einzelparts =  split /\|/,$einzelt;
			my $partnumber = 0;
			my $newfirst="";
			my $newdays="";
			my $weekend="";
			my $newid="";
			foreach my $part (@einzelparts)  #starte einzeltimer
				{
					$partnumber++;
					if ($partnumber ==1) #eigentliche timerangabe
					{
						if ( $part =~m/\?(.*)(-)([0-9]{2}:[0-9]{2})(\|[0-9]{0,7})?(.*)?/ )
						{
							$newfirst="RANDOM=".$part;	
							$newfirst =~ s/\?//ig;	
							# suche naxh random
						}
						elsif ($part =~m/(.*?)([0-9]{2}):([0-9]{2})\*([0-9]{2}:[0-9]{2})-([0-9]{2}:[0-9]{2})/)
						{
							# suche naxh repeat
							#00:05*04:30-05:30
							$newfirst = "REPEAT=$part";
						}
						else
							{
								# firstpart = TIMER	
								$newfirst = "TIME=$part";
							}
						next;
					}  
						
					if ( $part =~m/ID.*$/ )
						{
							# found ID
							my @id=split //,$part;
							shift (@id);
							shift (@id);
							$newid = join ",",@id;
							$newid = "ID=".$newid;
						}
						
					if ( $part =~m/^[1-7]{1,7}$/ )
						{
							# found days 
							my @days=split //,$part;
							$newdays = join ",",@days;
							$newdays = "WDAY=".$newdays;
						}
						
					if ( $part =~m/^!\$we/ )
						{
							# found weekend
							$weekend = "WEEKEND=0";
						}
						
					if ( $part =~m/^\$we/ )
						{
							# found weekend
							$weekend = "WEEKEND=1";
						}	
				} # ende einzelparts
			
			$final.= join("|",$newfirst,$newdays,$weekend,$newid);
			$final =~ s/\|\|\|/|/ig; 
			$final =~ s/\|\|/|/ig; 
			$final =~ s/\|.\|/|/ig; 
			$final =~ s/\|$//ig; 
			$final.="[NEXTTIMER]";
			} # ende timerline

			$final = substr( $final,0,(length($final)-11));
			next if length($final) <5;
			$write++;
			readingsSingleUpdate( $hash, ".Trigger_time_$count", $final, 0 );
			$message.="     -> NewtimerReading ($count): $final \n";
		}		
	
		readingsSingleUpdate( $hash, ".V_Check", $vupdate, 0 );
		MSwitch_Createtimer($hash);

		if ($write >0)
		{
		$message.="     -> Oldtimer: $oldtimer \n";
		$message.="     -> Timerdaten des Devices $Name wurden an Strukturversion $vupdate anepasst. \n";
		$message.="     -> Reading -> .Trigger_time bleibt erhalten (Downgrade moeglich)\n";
		}
		else
		{
		$message.="     -> Fehler in Formatierung gefunden (evt. ueberfluessige Leerzeichen): [$oldtimer] \n";
		$message.="     -> keine Timer-Anpassung notwendig, ein Formatierungsfehler behoben\n";
		$message.="     -> Reading -> .Trigger_time bleibt erhalten (Downgrade moeglich)\n";
		}
	}	 
	else
	{
		$message.="     -> keine Timer-Anpassung notwendig\n";
		readingsSingleUpdate( $hash, ".V_Check", $vupdate, 0 );
	}

$message.="     -> nicht benoetigte Readings werden geloescht \n";
    fhem("deletereading $Name Trigger_device");
    fhem("deletereading $Name .Trigger_time");

$message.="     -> Device $Name wird neu gestartet\n";
Log3( $Name, 0, "$message");
MSwitch_LoadHelper($hash);		
return;

}


################################
sub MSwitch_backup_this($) {
    my ($hash)      = @_;
    my $Name        = $hash->{NAME};
    my $testreading = $hash->{READINGS};
    my @areadings   = ( keys %{$testreading} );
	mkdir($backupfile,0777);
	open( BACKUPDATEI, ">".$backupfile.$Name.".".$vupdate.".conf" ); 
        print BACKUPDATEI "#N -> $Name\n";
        foreach my $key (@areadings) {
            next if $key eq "last_exec_cmd";

            my $tmp = ReadingsVal( $Name, $key, 'undef' );
            print BACKUPDATEI "#S $key -> $tmp\n";
        }
        #my %keys;
        foreach my $attrdevice ( keys %{ $attr{$Name} } ) 
        {
            my $inhalt = "#A $attrdevice -> " . AttrVal( $Name, $attrdevice, '' );
            $inhalt =~ s/\n/#[nla]/g;
            print BACKUPDATEI $inhalt . "\n";
        }
		close(BACKUPDATEI);
		$hash->{Backup_avaible}            = "./".$backupfile.$Name.".".$vupdate.".conf";
}

################################
sub MSwitch_backup_all($) {
    my ($hash)      = @_;
    my $Name        = $hash->{NAME};
    my $testreading = $hash->{READINGS};
    my @areadings   = ( keys %{$testreading} );
    my %keys;
	mkdir($backupfile,0777);
    foreach my $testdevice ( keys %{ $modules{MSwitch}{defptr} } )    #
    {
		my $devhash = $defs{$testdevice};
	open( BACKUPDATEI, ">".$backupfile.$testdevice.".".$vupdate.".conf" ); 
        print BACKUPDATEI "#N -> $testdevice\n";
        foreach my $key (@areadings) {
            next if $key eq "last_exec_cmd";

            my $tmp = ReadingsVal( $testdevice, $key, 'undef' );
            print BACKUPDATEI "#S $key -> $tmp\n";
        }
        #my %keys;
        foreach my $attrdevice ( keys %{ $attr{$testdevice} } ) 
        {
            my $inhalt = "#A $attrdevice -> " . AttrVal( $testdevice, $attrdevice, '' );
            $inhalt =~ s/\n/#[nla]/g;
            print BACKUPDATEI $inhalt . "\n";
        }
		$devhash->{Backup_avaible}            = "./".$backupfile.$testdevice.".".$vupdate.".conf";
		close(BACKUPDATEI);
    }
}
################################

################################
sub MSwitch_restore_all($) {
    my ($hash) = @_;
    my $Name   = $hash->{NAME};
    my $answer = '';
	Log3("TEST2",0,"starte restore");
	my @restore_devices = devspec2array("TYPE=MSwitch");	
	for my $restore (@restore_devices) 
	{
		my $Zeilen = ("");
		my $devhash = $defs{$restore};
		
		
		
		if (open( BACKUPDATEI, "<./".$backupfile.$restore.".".$vupdate.".conf" ))
		{
			while (<BACKUPDATEI>) 
			{
				$Zeilen = $Zeilen . $_;
			}
		}
		else
		{
			$answer = $answer . "!  -> no backup found for $restore\n";
			next;
		}
		
		
		close(BACKUPDATEI);
		$Zeilen =~ s/\n/[NL]/g;
		my @found = split( /\[NL\]/, $Zeilen );
		foreach (@found) 
		{
			if ( $_ =~ m/#S (.*) -> (.*)/ )    # setreading
			{
				next if $1 eq "last_exec_cmd";
				if ( $2 eq 'undef' || $2 eq '' || $2 eq ' ' )
				{
				}
				else 
				{
					$Zeilen = $2;
					readingsSingleUpdate( $devhash, "$1", $Zeilen, 0 );
				}
			}
			if ( $_ =~ m/#A (.*) -> (.*)/ )    # setattr
			{
				my $inhalt  = $2;
				my $aktattr = $1;
				$inhalt =~ s/#\[nla\]/\n/g;
				$inhalt =~ s/;/;;/g;
				my $cs = "attr $restore $aktattr $inhalt";
				my $errors = AnalyzeCommandChain( undef, $cs );
				if ( defined($errors) )
				{
					MSwitch_LOG( $Name, 1, "ERROR $cs" );
				}
			}
		}
		$answer = $answer . "   -> MSwitch $restore restored.\n";
	}
    return $answer;
}
################################
sub MSwitch_restore_this($) {
    my ($hash)  = @_;
    my $Name    = $hash->{NAME};
    my $Zeilen  = ("");
    my $Zeilen1 = "";
    open( BACKUPDATEI, "<./".$backupfile.$Name.".".$vupdate.".conf" ) || return "no Backupfile found!\n";
    while (<BACKUPDATEI>) 
	{
        $Zeilen = $Zeilen . $_;
    }
    close(BACKUPDATEI);
    $Zeilen =~ s/\n/[NL]/g;
	
    my @found = split( /\[NL\]/, $Zeilen );
    foreach (@found) {
        if ( $_ =~ m/#S (.*) -> (.*)/ )    # setreading
        {
            next if $1 eq "last_exec_cmd";
            if ( $2 eq 'undef' || $2 eq '' || $2 eq ' ' )
			{
            }
            else 
			{
                $Zeilen1 = $2;
                readingsSingleUpdate( $hash, "$1", $Zeilen1, 0 );
            }
        }
        if ( $_ =~ m/#A (.*) -> (.*)/ )    # setattr
        {
            my $inhalt  = $2;
            my $aktattr = $1;
            $inhalt =~ s/#\[nla\]/\n/g;
            $inhalt =~ s/;/;;/g;
            my $cs = "attr $Name $aktattr $inhalt";
            my $errors = AnalyzeCommandChain( undef, $cs );
            if ( defined($errors) )
			{
                MSwitch_LOG( $Name, 1, "ERROR $cs" );
            }
        }
    }
    MSwitch_LoadHelper($hash);
    return "MSwitch $Name restored.\nPlease refresh device.";
}

#################################
sub MSwitch_Getsupport($) {
    my ($hash) = @_;
    my $Name   = $hash->{NAME};
    my $out    = '';
    $out .= "Modulversion: $version\\n";
    $out .= "Datenstruktur: $vupdate\\n";
    $out .= "\\n----- Devicename -----\\n";
    $out .= "$Name\\n";
    $out .= "\\n----- Attribute -----\\n";
    my %keys;

    foreach my $attrdevice ( keys %{ $attr{$Name} } )    #geht
    {
        my $tmp = AttrVal( $Name, $attrdevice, '' );
        $tmp =~ s/</\\</g;
        $tmp =~ s/>/\\>/g;
        $tmp =~ s/'/\\'/g;
        $tmp =~ s/\n/#[nl]/g;
        $out .= "Attribut $attrdevice: " . $tmp . "\\n";
    }
    $out .= "\\n----- Trigger -----\\n";
    $out .= "Trigger device:  ";
    my $tmp = ReadingsVal( $Name, '.Trigger_device', 'undef' );
    $out .= "$tmp\\n";
    $out .= "Trigger time: ";
    $tmp = ReadingsVal( $Name, '.Trigger_time', 'undef' );
    $tmp =~ s/~/ /g;
    $out .= "$tmp\\n";
    $out .= "Trigger condition: ";
    $tmp = ReadingsVal( $Name, '.Trigger_condition', 'undef' );
    $out .= "$tmp\\n";
    $out .= "Trigger Device Global Whitelist: ";
    $tmp = ReadingsVal( $Name, '.Trigger_Whitelist', 'undef' );
    $out .= "$tmp\\n";
    $out .= "\\n----- Trigger Details -----\\n";
    $out .= "Trigger cmd1: ";
    $tmp = ReadingsVal( $Name, '.Trigger_on', 'undef' );
    $out .= "$tmp\\n";
    $out .= "Trigger cmd2: ";
    $tmp = ReadingsVal( $Name, '.Trigger_off', 'undef' );
    $out .= "$tmp\\n";
    $out .= "Trigger cmd3: ";
    $tmp = ReadingsVal( $Name, '.Trigger_cmd_on', 'undef' );
    $out .= "$tmp\\n";
    $out .= "Trigger cmd4: ";
    $tmp = ReadingsVal( $Name, '.Trigger_cmd_off', 'undef' );
    $out .= "$tmp\\n";
    $out .= "\\n----- Bridge Details -----\\n";
    my $tmp1 = ReadingsVal( $Name, '.Distributor', 'undef' );
    $tmp1 =~ s/\n/#[nl]/g;

    $out .= "$tmp1\\n";

    my %savedetails = MSwitch_makeCmdHash($hash);
    $out .= "\\n----- Device Actions -----\\n";
    my @affecteddevices = split( /#\[ND\]/,
        ReadingsVal( $Name, '.Device_Affected_Details', 'no_device' ) );

    foreach (@affecteddevices) {
        my @devicesplit = split( /#\[NF\]/, $_ );
        $devicesplit[4] =~ s/'/\\'/g;
        $devicesplit[5] =~ s/'/\\'/g;
        $devicesplit[1] =~ s/'/\\'/g;
        $devicesplit[3] =~ s/'/\\'/g;
        $out .= "\\nDevice: " . $devicesplit[0] . "\\n";
        $out .= "cmd1: " . $devicesplit[1] . " " . $devicesplit[3] . "\\n";
        $out .= "cmd2: " . $devicesplit[2] . " " . $devicesplit[4] . "\\n";
        $out .= "cmd1 condition: " . $devicesplit[9] . "\\n";
        $out .= "cmd2 condition: " . $devicesplit[10] . "\\n";
        $out .= "cmd1 delay: " . $devicesplit[7] . "\\n";
        $out .= "cmd2 delay: " . $devicesplit[8] . "\\n";
        $out .= "repeats: " . $devicesplit[11] . "\\n";
        $out .= "repeats delay: " . $devicesplit[12] . "\\n";
        $out .= "priority: " . $devicesplit[13] . "\\n";
        $out .= "id: " . $devicesplit[14] . "\\n";
        $out .= "comment: " . $devicesplit[15] . "\\n";
        $out .= "cmd1 exit: " . $devicesplit[16] . "\\n";
        $out .= "cmd2 exit: " . $devicesplit[17] . "\\n";
    }
    $out =~ s/#\[dp\]/:/g;
    $out =~ s/#\[pt\]/./g;
    $out =~ s/#\[ti\]/~/g;
    $out =~ s/#\[sp\]/ /g;
    $out =~ s/#\[nl\]/\\n/g;
    $out =~ s/#\[se\]/;/g;
    $out =~ s/#\[dp\]/:/g;
    $out =~ s/\(DAYS\)/|/g;
    $out =~ s/#\[ko\]/,/g;     #neu
    $out =~ s/#\[bs\]/\\/g;    #neu
    asyncOutput( $hash->{CL},
"<html><center>Bei Supportanfragen bitte untenstehene Datei anhängen, das erleichtert Anfragen erheblich.<br>&nbsp;<br><textarea name=\"edit1\" id=\"edit1\" rows=\""
          . "40\" cols=\"180\" STYLE=\"font-family:Arial;font-size:9pt;\">"
          . $out
          . "</textarea><br></html>" );

    return;
}
##################
sub MSwitch_Getconfig($$) {
    my ($hash,$aktion)      = @_;
    my $Name        = $hash->{NAME};
    my $testreading = $hash->{READINGS};
    my @areadings   = ( keys %{$testreading} );
    my $count       = 0;
    my $out         = "#V $version\\n";
    $out .= "#VS $vupdate\\n";
    my $testdevice = $Name;

    foreach my $key (@areadings) {
        next if $key eq "last_exec_cmd";
        my $tmp = ReadingsVal( $testdevice, $key, 'undef' );
        if ( $key eq ".Device_Affected_Details" ) {
            $tmp =~ s/#\[nl\]/;;/g;
            $tmp =~ s/#\[sp\]/ /g;
            $tmp =~ s/#\[nl\]/\\n/g;
            $tmp =~ s/#\[se\]/;/g;
            $tmp =~ s/#\[dp\]/:/g;
            $tmp =~ s/\(DAYS\)/|/g;
            $tmp =~ s/#\[ko\]/,/g;    #neu
            $tmp =~ s/#\[wa\]/|/g;
            $tmp =~ s/#\[st\]/\\'/g;
            $tmp =~ s/'/\\'/g;
            $tmp =~ s/#\[bs\]/\\\\/g;
        }

        if ( $key eq ".Distributor" ) {
            $tmp =~ s/\n/#[nl]/g;
        }

        $tmp =~ s/#\[tr\]/ /g;
        if (
               $key eq ".Device_Events"
            || $key eq ".info"
            || $key eq ".Trigger_cmd_on"
            || $key eq ".Trigger_cmd_off"
            || $key eq ".Trigger_on"
            || $key eq ".Trigger_off"

          )
        {
            $tmp =~ s/'/\\'/g;
        }

        if ( $key eq ".sysconf" ) {

            $tmp =~ s/</&lt;/g;
            $tmp =~ s/>/&gt;/g;

        }

        if ( $key eq ".Device_Events" ) {
            $tmp =~ s/#\[tr\]/ /g;
        }
        $out .= "#S $key -> $tmp\\n";
        $count++;
    }

	if ($aktion ne 'undo')
	{
    foreach my $attrdevice ( keys %{ $attr{$testdevice} } )    #geht
    {
        my $tmp = AttrVal( $testdevice, $attrdevice, '' );
        $tmp =~ s/</\\</g;
        $tmp =~ s/>/\\>/g;
        $tmp =~ s/'/\\'/g;
        $tmp =~ s/"/\\"/g;

        #CHaNGE einspielen noch ungeprüft
        $tmp =~ s/\n/#[nl]/g;
        $tmp =~ s/\t//g;
        $out .= "#A $attrdevice -> " . $tmp . "\\n";
        $count++;
    }
	}
	else
	{
	
		return $out;
	}
	
	$count++;
    $count++;

    my $client_hash = $hash->{CL};
    my $ret         = asyncOutput( $hash->{CL},
"<html>Änderungen sollten hier nur von erfahrenen Usern durchgeführt werden.<br><textarea name=\"edit1\" id=\"edit1\" rows=\""
          . $count
          . "\" cols=\"160\" STYLE=\"font-family:Arial;font-size:9pt;\">"
          . $out
          . "</textarea><br>"
          . "<input name\"edit\" type=\"button\" value=\"save changes\" onclick=\" javascript: saveconfig(document.querySelector(\\\'#edit1\\\').value) \">"
          . "</html>" );
    return;
}
#######################################################
sub MSwitch_Sysextension($) {
    my ($hash) = @_;
    my $Name   = $hash->{NAME};
    my $count  = 30;
    my $out = ReadingsVal( $Name, '.sysconf', '' );
    $out =~ s/#\[sp\]/ /g;
    $out =~ s/#\[nl\]/\\n/g;
    $out =~ s/#\[se\]/;/g;
    $out =~ s/#\[dp\]/:/g;
    $out =~ s/#\[st\]/\\'/g;
    $out =~ s/#\[dst\]/\"/g;
    $out =~ s/#\[tab\]/    /g;
    $out =~ s/#\[ko\]/,/g;
    $out =~ s/#\[wa\]/|/g;
    $out =~ s/#\[bs\]/\\\\/g;
    $out =~ s/</&lt;/g;
    $out =~ s/>/&gt;/g;
    $out =~ s/#\[bs\]/\\\\/g;

    my $client_hash = $hash->{CL};
    asyncOutput( $hash->{CL},
"<html><center>Code (Html/Javascript) wird unmittelbar unter DeviceOverview eingebettet<br><textarea name=\"sys\" id=\"sys\" rows=\""
          . $count
          . "\" cols=\"160\" STYLE=\"font-family:Arial;font-size:9pt;\">"
          . $out
          . "</textarea><br><input type=\"button\" value=\"save changes\" onclick=\" javascript: savesys(document.querySelector(\\\'#sys\\\').value) \"></html>"
    );
    return;
}
################################
sub MSwitch_resetore_all($) {
    my ($hash) = @_;
    my $Name   = $hash->{NAME};
    my $answer = '';
    my $Zeilen = ("");
    open( BACKUPDATEI, "<./$backupfile" )
      || return "$Name|no Backupfile MSwitch_backup_$vupdate.cfg found\n";
    while (<BACKUPDATEI>) {
        $Zeilen = $Zeilen . $_;
    }
    close(BACKUPDATEI);
    foreach my $testdevice ( keys %{ $modules{MSwitch}{defptr} } )    #
    {
        my $devhash = $defs{$testdevice};
        $Zeilen =~ s/\n/[NL]/g;
        if ( $Zeilen !~ m/#N -> $testdevice\[NL\](.*)#E -> $testdevice\[NL\]/ )
        {
            $answer = $answer . "no Backupfile found for $testdevice\n";
        }
        my @found = split( /\[NL\]/, $1 );
        foreach (@found) {
            if ( $_ =~ m/#S (.*) -> (.*)/ )    # setreading
            {
                if ( $2 eq 'undef' || $2 eq '' || $2 eq ' ' ) {
                }
                else {
                    readingsSingleUpdate( $devhash, "$1", $2, 0 );
                }
            }
            if ( $_ =~ m/#A (.*) -> (.*)/ )    # setattr
            {
                my $inhalt  = $2;
                my $aktattr = $1;

                $inhalt =~ s/#\[nla\]/\n/g;
                $inhalt =~ s/;/;;/g;
                my $cs = "attr $Name $aktattr $inhalt";
                my $errors = AnalyzeCommandChain( undef, $cs );
                if ( defined($errors) ) {
                    MSwitch_LOG( $testdevice, 1, "ERROR $cs" );

                }
            }
        }
        my $cs = "attr  $testdevice verbose 0";
        my $errors = AnalyzeCommandChain( undef, $cs );
        if ( defined($errors) ) {
            MSwitch_LOG( $testdevice, 1, "ERROR $cs" );

        }
        MSwitch_LoadHelper($devhash);
        $answer = $answer . "MSwitch $testdevice restored.\n";
    }
    return $answer;
}
################################################
sub MSwitch_savesys($$) {
    my ( $hash, $cont ) = @_;
    my $name = $hash->{NAME};
    $cont = urlDecode($cont);
    $cont =~ s/\n/#[nl]/g;
    $cont =~ s/\t/    /g;
    $cont =~ s/ /#[sp]/g;
    $cont =~ s/\\/#[bs]/g;
    $cont =~ s/,/#[ko]/g;
    $cont =~ s/^#\[/#[eo]/g;
    $cont =~ s/^#\]/#[ec]/g;
    $cont =~ s/\|/#[wa]/g;
    if ( !defined $cont ) { $cont = ""; }

    if ( $cont ne '' ) {
        readingsSingleUpdate( $hash, ".sysconf", $cont, 0 );
    }
    else {
        fhem("deletereading $name .sysconf");
    }
    return;
}
################################################
sub MSwitch_saveconf($$) {
    my ( $hash, $cont ) = @_;
    my $name     = $hash->{NAME};
    my $contcopy = $cont;

    delete $data{MSwitch}{devicecmds1};
    delete $data{MSwitch}{last_devicecmd_save};

    delete( $hash->{READINGS} );
    $cont =~ s/#c\[sp\]/ /g;
    $cont =~ s/#c\[se\]/;/g;
    $cont =~ s/#c\[dp\]/:/g;
    my @changes;
    my $info = "";
    my @found = split( /#\[EOL\]/, $cont );

    foreach (@found) {

        if ( $_ =~ m/#Q (.*)/ )    # setattr
        {
            push( @changes, $1 );
        }
        if ( $_ =~ m/#I (.*)/ )    # setattr
        {
            $info = $1;
        }
        if ( $_ =~ m/#VS (.*)/ )    # setattr
        {
            if ( $1 ne $vupdate ) {
                readingsSingleUpdate( $hash, ".wrong_version", $1, 0 );
                return;
            }
        }
        if ( $_ =~ m/#S (.*) -> (.*)/ )    # setreading
        {
            if ( $2 eq 'undef' || $2 eq '' || $2 eq ' ' ) {

                delete( $hash->{READINGS}{$1} );
            }
            else {
                my $newstring = $2;
                if ( $1 eq ".Device_Affected_Details" ) {
                    $newstring =~ s/;/#[se]/g;
                    $newstring =~ s/:/#[dp]/g;
                    $newstring =~ s/\t/    /g;
                    $newstring =~ s/ /#[sp]/g;
                    $newstring =~ s/\\/#[bs]/g;
                    $newstring =~ s/,/#[ko]/g;
                    $newstring =~ s/^#\[/#[eo]/g;
                    $newstring =~ s/^#\]/#[ec]/g;
                    $newstring =~ s/\|/#[wa]/g;
                    $newstring =~ s/#\[se\]#\[se\]#\[se\]/#[se]#[nl]/g;
                    $newstring =~ s/#\[se\]#\[se\]/#[nl]/g;
                }
                if ( $1 eq ".sysconf" ) { }

                if ( $1 eq ".Device_Events" ) {
                    $newstring =~ s/ /#[tr]/g;
                }

                if ( $1 eq ".Distributor" ) {
                    $newstring =~ s/#\[nl\]/\n/g;
                }
                readingsSingleUpdate( $hash, "$1", $newstring, 0 );
            }
        }
        if ( $_ =~ m/#A (.*) -> (.*)/ )    # setattr
        {
# für usserattribute zweiten durchgang starten , dafür alle befehle in ein array und nochmals einlesen userattr

            my $na = $1;
            my $ih = $2;
            $ih =~ s/#\[nl\]/\n/g;

            if ( $na eq "userattr" ) {
                fhem("attr $name $na $ih");
            }
            else {

                $hash->{helper}{safeconf}{$na} = $ih;
            }
        }
    }
    my $testreading = $hash->{helper}{safeconf};
    my @areadings   = ( keys %{$testreading} );
    foreach my $key (@areadings) {
        if ( $key eq "devStateIcon" ) {
            $attr{$name}{$key} = $hash->{helper}{safeconf}{$key};
        }
        else {
            fhem( "attr $name $key " . $hash->{helper}{safeconf}{$key} );
        }
    }
    ################# helperkeys abarbeiten #######

    readingsSingleUpdate( $hash, ".V_Check", $vupdate, 0 );

    delete( $hash->{helper}{safeconf} );
    delete( $hash->{helper}{mode} );
    ##############################################
    MSwitch_set_dev($hash);
    if ( @changes > 0 ) {
        my $save = join( '|', @changes );
        readingsSingleUpdate( $hash, ".change", $save, 0 );
    }
    if ( $info ne "" ) {
        readingsSingleUpdate( $hash, ".change_info", $info, 0 );
    }
    delete( $hash->{helper}{config} );
    fhem("deletereading $name EVENTCONF");

    # timrer berechnen
    MSwitch_Createtimer($hash);

    # eventtoid einlesen
    delete( $hash->{helper}{eventtoid} );
    my $bridge = ReadingsVal( $name, '.Distributor', 'undef' );
    if ( $bridge ne "undef" ) {
        my @test = split( /\n/, $bridge );
        foreach my $testdevices (@test) {
            my ( $key, $val ) = split( /=>/, $testdevices );
            $hash->{helper}{eventtoid}{$key} = $val;
        }
    }

    return;
}
################################################
sub MSwitch_exec_undo($$) {
    my ( $hash, $cont ) = @_;
    my $name     = $hash->{NAME};
    my $contcopy = $cont;

    delete $data{MSwitch}{devicecmds1};
    delete $data{MSwitch}{last_devicecmd_save};

    delete( $hash->{READINGS} );
    $cont =~ s/#c\[sp\]/ /g;
    $cont =~ s/#c\[se\]/;/g;
    $cont =~ s/#c\[dp\]/:/g;
    my @changes;
    my $info = "";
    my @found = split( /#\[EOL\]/, $cont );

    foreach (@found) {

        if ( $_ =~ m/#Q (.*)/ )    # setattr
        {
            push( @changes, $1 );
        }
        if ( $_ =~ m/#I (.*)/ )    # setattr
        {
            $info = $1;
        }
        if ( $_ =~ m/#VS (.*)/ )    # setattr
        {
            if ( $1 ne $vupdate ) {
                readingsSingleUpdate( $hash, ".wrong_version", $1, 0 );
                return;
            }
        }
        if ( $_ =~ m/#S (.*) -> (.*)/ )    # setreading
        {
            if ( $2 eq 'undef' || $2 eq '' || $2 eq ' ' ) {

                delete( $hash->{READINGS}{$1} );
            }
            else {
                my $newstring = $2;
                if ( $1 eq ".Device_Affected_Details" ) {
                    $newstring =~ s/;/#[se]/g;
                    $newstring =~ s/:/#[dp]/g;
                    $newstring =~ s/\t/    /g;
                    $newstring =~ s/ /#[sp]/g;
                    $newstring =~ s/\\/#[bs]/g;
                    $newstring =~ s/,/#[ko]/g;
                    $newstring =~ s/^#\[/#[eo]/g;
                    $newstring =~ s/^#\]/#[ec]/g;
                    $newstring =~ s/\|/#[wa]/g;
                    $newstring =~ s/#\[se\]#\[se\]#\[se\]/#[se]#[nl]/g;
                    $newstring =~ s/#\[se\]#\[se\]/#[nl]/g;
                }
                if ( $1 eq ".sysconf" ) { }

                if ( $1 eq ".Device_Events" ) {
                    $newstring =~ s/ /#[tr]/g;
                }

                if ( $1 eq ".Distributor" ) {
                    $newstring =~ s/#\[nl\]/\n/g;
                }
                readingsSingleUpdate( $hash, "$1", $newstring, 0 );
            }
        }
        if ( $_ =~ m/#A (.*) -> (.*)/ )    # setattr
        {
        # nothing
        }
    }

    ################# helperkeys abarbeiten #######

    readingsSingleUpdate( $hash, ".V_Check", $vupdate, 0 );

    delete( $hash->{helper}{safeconf} );
    delete( $hash->{helper}{mode} );
    ##############################################
    MSwitch_set_dev($hash);
    if ( @changes > 0 ) {
        my $save = join( '|', @changes );
        readingsSingleUpdate( $hash, ".change", $save, 0 );
    }
    if ( $info ne "" ) {
        readingsSingleUpdate( $hash, ".change_info", $info, 0 );
    }
    delete( $hash->{helper}{config} );
    fhem("deletereading $name EVENTCONF");

    # timrer berechnen
    MSwitch_Createtimer($hash);

    # eventtoid einlesen
    delete( $hash->{helper}{eventtoid} );
    my $bridge = ReadingsVal( $name, '.Distributor', 'undef' );
    if ( $bridge ne "undef" ) {
        my @test = split( /\n/, $bridge );
        foreach my $testdevices (@test) {
            my ( $key, $val ) = split( /=>/, $testdevices );
            $hash->{helper}{eventtoid}{$key} = $val;
        }

    }

    return;
}
#################################

sub MSwitch_Execute_randomtimer($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
	my $showevents = AttrVal( $Name, "MSwitch_generate_Events", 0 );
	if (AttrVal( $Name, 'MSwitch_Debug', '0' ) ne "0" ){$showevents = 1};
    my $param = AttrVal( $Name, 'MSwitch_RandomTime', '0' );
    my $min = substr( $param, 0, 2 ) * 3600;
    $min = $min + substr( $param, 3, 2 ) * 60;
    $min = $min + substr( $param, 6, 2 );
    my $max = substr( $param, 9, 2 ) * 3600;
    $max = $max + substr( $param, 12, 2 ) * 60;
    $max = $max + substr( $param, 15, 2 );
    my $sekmax = $max - $min;
    my $ret    = $min + int( rand $sekmax );
	readingsSingleUpdate( $hash, "Randomtimer", $ret,$showevents );
    return $ret;
}
############################################
sub MSwitch_replace_delay($$) {
    my ( $hash, $timerkey ) = @_;
    my $name  = $hash->{NAME};
    my $time  = time;
    my $ltime = TimeNow();

    my ( $aktdate, $akttime ) = split / /, $ltime;
    my $hh = ( substr( $timerkey, 0, 2 ) );
    my $mm = ( substr( $timerkey, 2, 2 ) );
    my $ss = ( substr( $timerkey, 4, 2 ) );
    my $referenz = time_str2num("$aktdate $hh:$mm:$ss");

    if ( $referenz < $time ) {
        $referenz = $referenz + 86400;
    }
    if ( $referenz >= $time ) {
    }
    $referenz = $referenz - $time;
    my $timestampGMT = FmtDateTimeRFC1123($referenz);
    return $referenz;
}
############################################################
sub MSwitch_repeat($) {

    my ( $msg, $name ) = @_;
	
	
	# 4 - on / off

	my $incomming = $msg;
    my @msgarray = split( /\|/, $incomming );
    $name = $msgarray[1];
	
	
	#Log3("test",0,"incomming: $incomming".__LINE__);
	
	
	
	# Return without any further action if the module is disabled
	return "" if ( IsDisabled($name) );
	
	
	if (!exists $defs{$name} )
		{
			
			Log3("test",0,"Fehler, hash existiert nicht ".__LINE__);
			Log3("test",0,"name: $name");
			Log3("test",0,"msg: $msg");
			return;
		}
	
	
	
	
	my $hash = $defs{$name};
    my $time = $msgarray[2];
    my $cs   = $msgarray[0];
    my $device = $msgarray[3];
	
	
		if (!defined $device )
		{
			
			Log3("test",0,"Fehler, device existiert nicht ".__LINE__);
			
			Log3("test",0,"msgarray3: $msgarray[3] ".__LINE__);
			Log3("test",0,"name: $name");
			Log3("test",0,"msg: $msg");
			return;
		}
	
	
	
	my $cmd = $msgarray[4];
	
	my %devicedetails = MSwitch_makeCmdHash($name);
	MSwitch_LOG( $name, 6,"repeat aufgerufen incomming: $incomming  L:" . __LINE__ );
	MSwitch_LOG( $name, 6,"repeat aufgerufen msg: $msg L:" . __LINE__ );
	my $conditionkey = $device . "_condition" . $cmd;
	my $repconkey= $device . "_repeatcondition";
	my $docheck = $devicedetails{$repconkey};
	#
	if ($docheck eq "1")
	{
	MSwitch_LOG( $name, 6,"repeat conditionkey:  $devicedetails{$conditionkey} L:" . __LINE__ );
	my $execute = "true";
    $execute = MSwitch_checkcondition( $devicedetails{$conditionkey}, $name, "" ) if $devicedetails{$conditionkey} ne '';
	if ($execute ne "true" )
	{
	MSwitch_LOG( $name, 6,"Repeat abgebrochen , Bedingung nicht erfüllt L:" . __LINE__ );
	return;
	}
	}
    $cs =~ s/\n//g;
	$cs =~ s/MSwitch_Self/$name/g;
    if ( $cs =~ m/set (.*)(MSwitchtoggle)(.*)/ ) 
		{
			$cs = MSwitch_toggle( $hash, $cs );
		}

    if ( AttrVal( $name, 'MSwitch_Debug', "0" ) ne '2' ) 
	{
        MSwitch_LOG( $name, 6,"Befehlswiederholungen ausgeführt: $cs  L:" . __LINE__ );
        if ( $cs =~ m/{.*}/ ) 
		{
            $cs =~ s/\[SR\]/\|/g;
			{
			no warnings;
            eval($cs);
			}
            if ($@) 
			{
                MSwitch_LOG( $name, 1, "$name MSwitch_repeat: ERROR $cs: $@ " . __LINE__ );
            }
        }
        else 
		{
            my $errors = AnalyzeCommandChain( undef, $cs );
            if ( defined($errors) ) 
			{
                MSwitch_LOG( $name, 1,"$name Absent_repeat $cs: ERROR : $errors -> Comand: $cs" );
            }
        }
    }

    else {
        MSwitch_LOG( $name, 6,
            "nicht ausgeführte Befehlswiederholungen (Debug2): $cs  L:"
              . __LINE__ );

    } 
    delete( $hash->{helper}{repeats}{$time} );
	return;
}


####################
sub MSwitch_Restartcmd($) {
    my $incomming  = $_[0];
    my @msgarray   = split( /#\[tr\]/, $incomming );
    my $name       = $msgarray[1];
    my $hash       = $modules{MSwitch}{defptr}{$name};
    my $showevents = AttrVal( $name, "MSwitch_generate_Events", 0 );
	if (AttrVal( $name, 'MSwitch_Debug', '0' ) ne "0" ){$showevents = 1};
    return "" if ( IsDisabled($name) );
	
	#Log3("test",0,"inc: $incomming");
	
	
	MSwitch_LOG( $name, 6,"### SUB_Restartcmd ###");
	MSwitch_LOG( $name, 6,  "verzögerte Befehlswiederholungen ausgeführt:\n$incomming");
    $hash->{eventsave} = 'unsaved';
    # checke versionskonflikt der datenstruktur
    if ( ReadingsVal( $name, '.V_Check', $vupdate ) ne $vupdate )
	{
        my $ver = ReadingsVal( $name, '.V_Check', '' );
        MSwitch_LOG( $name, 1, "$name: Versionskonflikt - aktion abgebrochen" );
        return;	
    }
    my $cs = $msgarray[0];
    $cs =~ s/##/,/g;
    my $conditionkey = $msgarray[2];
    my $event        = $msgarray[3];
    my $device       = $msgarray[5];
	my $cmdzweig      = $msgarray[6];
    my %devicedetails = MSwitch_makeCmdHash($name);
    if ( AttrVal( $name, 'MSwitch_RandomNumber', '' ) ne '' )
	{
        MSwitch_Createnumber1($hash);
    }
    ### teste auf condition
    my $execute = "true";
    $devicedetails{$conditionkey} = "nocheck" if $conditionkey eq "nocheck";
    if ( $msgarray[2] ne 'nocheck' )
	{
        $execute = MSwitch_checkcondition( $devicedetails{$conditionkey}, $name,$event );
        MSwitch_LOG( $name, 6, "Ergebnissrgebniss Bedingungsprüfung: $execute");
    }

    my $toggle = '';
    if ( $execute eq 'true' )
	{

        if ( $cs =~ m/set (.*)(MSwitchtoggle)(.*)/ )
		{
            $toggle = $cs;
            $cs = MSwitch_toggle( $hash, $cs );
        }

        my $x = 0;
        while ($devicedetails{ $device . '_repeatcount' } =~ m/\[(.*)\:(.*)\]/ )
        {
            $x++;    # notausstieg notausstieg
            last if $x > 20;    # notausstieg notausstieg
            my $setmagic = ReadingsVal( $1, $2, 0 );
            $devicedetails{ $device . '_repeatcount' } = $setmagic;
        }

        $x = 0;
        while ( $devicedetails{ $device . '_repeattime' } =~ m/\[(.*)\:(.*)\]/ )
        {
            $x++;               # notausstieg notausstieg
            last if $x > 20;    # notausstieg notausstieg
            my $setmagic = ReadingsVal( $1, $2, 0 );
            $devicedetails{ $device . '_repeattime' } = $setmagic;
        }


		if (  $devicedetails{ $device . '_repeatcount' } eq "undefined"){$devicedetails{ $device . '_repeatcount' } =0};
		if (  $devicedetails{ $device . '_repeattime' } eq "undefined"){$devicedetails{ $device . '_repeattime' } =0};

        ######################################
        if (  defined $devicedetails{ $device . '_repeatcount' } && defined $devicedetails{ $device . '_repeattime' } && AttrVal( $name, 'MSwitch_Expert', "0" ) eq '1'
            && $devicedetails{ $device . '_repeatcount' } > 0
            && $devicedetails{ $device . '_repeattime' } > 0 )
        {
            my $i;
            for ($i = 1 ; $i <= $devicedetails{ $device . '_repeatcount' } ;$i++ )
            {
                my $msg = $cs . "|" . $name;
                if ( $toggle ne '' )
				{
                    $msg = $toggle . "|" . $name;
                }
                my $timecond = gettimeofday() +( ( $i + 1 ) * $devicedetails{ $device . '_repeattime' } );
                $msg = $msg . "|" . $timecond."|$device|$cmdzweig"; #on/off
                $hash->{helper}{repeats}{$timecond} = "$msg";
                MSwitch_LOG( $name, 6,"Setze Befehlswiederholung $timecond" );
                InternalTimer( $timecond, "MSwitch_repeat", $msg );
            }
        }

        my $todec = $cs;
        $cs = MSwitch_dec( $hash, $todec );
        ############################

        if ( AttrVal( $name, 'MSwitch_Debug', "0" ) eq '2' ) 
		{
            MSwitch_LOG( $name, 6, "Befehlsausführung -> " . $cs );
        }
        else 
		{
            if ( $cs =~ m/{.*}/ )
			{
                $cs =~ s/\[SR\]/\|/g;
                MSwitch_LOG( $name, 6, "finale verzögerte Befehlsausführung auf Perlebene:\n\n$cs\n\n");
				{
				no warnings;
                eval($cs);
				}
                if ($@) 
				{
                    MSwitch_LOG( $name, 1,"$name MSwitch_Set: ERROR $cs: $@ " . __LINE__ );
                }
            }
            else 
			{
                MSwitch_LOG( $name, 6, "finale verzögerte Befehlsausführung auf Fhemebene:\n\n$cs\n\n");
                my $errors = AnalyzeCommandChain( undef, $cs );
                if ( defined($errors) and $errors ne "OK" ) 
				{
                    MSwitch_LOG( $name, 1,"$name MSwitch_Restartcmd :Fehler bei Befehlsausfuehrung  ERROR $errors " . __LINE__ );
                }
            }
        }

        if ( length($cs) > 100 && AttrVal( $name, 'MSwitch_Debug', "0" ) ne '4' )
        {
            $cs = substr( $cs, 0, 100 ) . '....';
        }
        readingsSingleUpdate( $hash, "last_exec_cmd", $cs, $showevents ) if $cs ne '';
    }
    RemoveInternalTimer($incomming);
    delete( $hash->{helper}{delays}{$incomming} );
    return;
}

###############################
sub MSwitch_Safemode($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
	my $showevents = AttrVal( $Name, "MSwitch_generate_Events", 0 );
	
	if (AttrVal( $Name, 'MSwitch_Debug', '0' ) ne "0" ){$showevents = 1};
    if ( AttrVal( $Name, 'MSwitch_Safemode', '0' ) == 0 ) { return; }
    my $time = gettimeofday();
    $time =~ s/\.//g;
    my $time1    = int($time);
    my $count    = 0;
    my $timehash = $hash->{helper}{savemode};

    foreach my $a ( keys %{$timehash} ) {
        $count++;
        if ( $a < $time1 - $savemodetime )    # für 10 sekunden
        {
            delete( $hash->{helper}{savemode}{$a} );
            $count = $count - 1;
        }
    }
    $hash->{helper}{savemode}{$time1} = $time1;
    if ( $count > $savecount ) {
        MSwitch_LOG( $Name, 1,
                "Das Device "
              . $Name
              . " wurde automatisch deaktiviert ( Safemode )" );
        $hash->{helper}{savemodeblock}{blocking} = 'on';
        readingsSingleUpdate( $hash, "Safemode", 'on', $showevents );
        foreach my $a ( keys %{$timehash} ) {
            delete( $hash->{helper}{savemode}{$a} );
        }
        $attr{$Name}{disable} = '1';
    }
    return;
}


####################


sub MSwitch_Createnumber($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
	my $showevents = AttrVal( $Name, "MSwitch_generate_Events", 0 );
	if (AttrVal( $Name, 'MSwitch_Debug', '0' ) ne "0" ){$showevents = 1};
    my $number = AttrVal( $Name, 'MSwitch_RandomNumber', '' ) + 1;
    my $number1 = int( rand($number) );
    readingsSingleUpdate( $hash, "RandomNr", $number1, $showevents );
    return;
}
################################
sub MSwitch_Createnumber1($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
	my $showevents = AttrVal( $Name, "MSwitch_generate_Events", 0 );
	if (AttrVal( $Name, 'MSwitch_Debug', '0' ) ne "0" ){$showevents = 1};
    my $number = AttrVal( $Name, 'MSwitch_RandomNumber', '' ) + 1;
    my $number1 = int( rand($number) );
    readingsSingleUpdate( $hash, "RandomNr1", $number1, $showevents );
    return;
}

#########################
sub MSwitch_EventBulk($$$$) {
    my ( $hash, $event, $update, $from ) = @_;
	# übergabe event ist altbestand / löschen
    my $name = $hash->{NAME};
	if (AttrVal( $name, 'MSwitch_Debug', '0' ) ne "0" ){$update=1;};
	if (AttrVal( $name, 'MSwitch_generate_Events', '0' ) ne "0" ){$update=1;};

    return if !defined $event;
    return if !defined $hash;
    if ( $hash eq "" ) { return; }
    MSwitch_LOG( $name, 6, "+++ +++ aktualisiere Eventreadings L:" . __LINE__ );
	$event=$hash->{helper}{evtparts}{event};
	my $evtfull=$hash->{helper}{evtparts}{evtfull};
	my @evtparts = split( /:/,$hash->{helper}{evtparts}{evtfull},3);
	
	if (!defined $evtparts[0]){ $evtparts[0]="";}
	if (!defined $evtparts[1] ){$evtparts[1]="";}
	if (!defined $evtparts[2]){ $evtparts[2]="";}

    $event =~ s/\[dp\]/:/g;
    $evtfull =~ s/\[dp\]/:/g;
    $evtparts[1] =~ s/\[dp\]/:/g if $evtparts[1];
    $evtparts[2] =~ s/\[dp\]/:/g if $evtparts[2];
    $event =~ s/\[dst\]/"/g;
    $evtfull =~ s/\[dst\]/"/g;
    $evtparts[1] =~ s/\[dst\]/"/g if $evtparts[1];
    $evtparts[2] =~ s/\[dst\]/"/g if $evtparts[2];
    $event =~ s/\[#dp\]/:/g;
    $evtfull =~ s/\[#dp\]/:/g;
    $evtparts[1] =~ s/\[#dp\]/:/g if $evtparts[1];
    $evtparts[2] =~ s/\[#dp\]/:/g if $evtparts[2];

    if (   $event ne ''
        && $event ne "last_activation_by:event"
        && $hash->{eventsave} ne 'saved' )

    {
        MSwitch_LOG( $name, 6, "ausführung aktualisiere Eventreadings: $event  L:" . __LINE__ );
		
        $hash->{eventsave} = "saved";
        readingsBeginUpdate($hash);
        readingsBulkUpdate( $hash, "EVENT", $event ,$update)
          if $event ne '';
        readingsBulkUpdate( $hash, "EVTFULL", $evtfull,1 )
          if $evtfull ne '';
        readingsBulkUpdate( $hash, "EVTPART1", $evtparts[0],$update )
          if $evtparts[0] ne '';
        readingsBulkUpdate( $hash, "EVTPART2", $evtparts[1],$update )
          if $evtparts[1] ne '';
        readingsBulkUpdate( $hash, "EVTPART3", $evtparts[2],$update)
          if $evtparts[2] ne '';
        #readingsBulkUpdate( $hash, "last_event", $evtfull,0) if $event ne '';
        readingsEndUpdate( $hash, 1 );
    }
    return;
}
##########################################################
# setzt reihenfolge und testet ID
sub MSwitch_priority(@) {
    my ( $hash, $execids, @devices ) = @_;
    my $name = $hash->{NAME};
    my @execids = split( /,/, $execids );

    if ( AttrVal( $name, 'MSwitch_Expert', "0" ) ne '1' ) {
        return @devices;
    }
    my %devicedetails = MSwitch_makeCmdHash($name);
    my %new;
    foreach my $device (@devices) 
	{
        # $execids beinhaltet auszuführende ids gesetzt bei init
        my $key1 = $device . "_id";
        if ( !grep { $_ eq $devicedetails{$key1} } @execids ) {
            next;
        }
        my $key  = $device . "_priority";
        my $prio = $devicedetails{$key};
        $new{$device} = $prio;
        $hash->{helper}{priorityids}{$device} = $prio;
    }
    my @new = %new;
    my @newlist;
    for my $key ( sort { $new{$a} <=> $new{$b} } keys %new ) {
        if ( $key ne "" && $key ne " " ) {
            push( @newlist, $key );
            my $key = $key . "_priority";

        }
    }
    my $anzahl = @newlist;

    @devices = @newlist if $anzahl > 0;
    @devices = ()       if $anzahl == 0;
    return @devices;
}
##########################################################
# setzt reihenfolge und testet ID
sub MSwitch_sort(@) {
    my ( $hash, $typ, @devices ) = @_;
    my $name = $hash->{NAME};

    my %devicedetails = MSwitch_makeCmdHash($name);
    my %new;
    foreach my $device (@devices) {

        my $key  = $device . $typ;
        my $prio = $devicedetails{$key};
        $new{$device} = $prio;
    }
    my @new = %new;
    my @newlist;
    for my $key ( sort { $new{$a} <=> $new{$b} } keys %new ) {
        if ( $key ne "" && $key ne " " ) {
            push( @newlist, $key );
        }
    }
    my $anzahl = @newlist;

    @devices = @newlist if $anzahl > 0;
    return @devices;
}
##########################################################
sub MSwitch_set_dev($) {

    #PROTO
    # setzt NOTIFYDEF
    my ($hash) = @_;
    my $name = $hash->{NAME};
    my $not = ReadingsVal( $name, '.Trigger_device', '' );

    if ( $not ne 'no_trigger' ) {
        if ( $not eq "all_events" ) {
            delete( $hash->{NOTIFYDEV} );
            if ( ReadingsVal( $name, '.Trigger_Whitelist', '' ) ne '' ) {
                $hash->{NOTIFYDEV} =
                  ReadingsVal( $name, '.Trigger_Whitelist', '' );
            }
        }
        elsif ( $not eq "MSwitch_Self" ) {
            $hash->{NOTIFYDEV} = $name;

        }
        else {
            $hash->{NOTIFYDEV} = $not;
            my $devices = MSwitch_makeAffected($hash);
            $hash->{DEF} = $not . ' # ' . $devices;
        }
    }
    else {
        $hash->{NOTIFYDEV} = 'no_trigger';
        delete $hash->{DEF};
    }
}
################################################################
sub MSwitch_clearlog($) {
    my ( $hash, $cs ) = @_;
    my $name = $hash->{NAME};
    open( BACKUPDATEI, ">./log/MSwitch_debug_$name.log" );
    print BACKUPDATEI "Starte Log\n";    #
    close(BACKUPDATEI);
    return;
}
################################################################

sub MSwitch_setbridge($$) {
    my ( $hash, $bridge ) = @_;
    my $name = $hash->{NAME};
    $bridge =~ s/\[NL\]/\n/g;
    $bridge =~ s/\[SP\]/ /g;
    MSwitch_LOG( $name, 6, "SAVE BRIDGE : $bridge L:" . __LINE__ );

    delete( $hash->{helper}{eventtoid} );

    if ( $bridge eq "" ) {
        fhem("deletereading $name .Distributor");
    }

    readingsSingleUpdate( $hash, ".Distributor", $bridge, 0 );

    my @test = split( /\n/, $bridge );

    foreach my $testdevices (@test) {
        my ( $key, $val ) = split( /=>/, $testdevices );
        $hash->{helper}{eventtoid}{$key} = $val;
    }
    return;
}
################################################################

sub MSwitch_debug2($$) {
    my ( $hash, $cs ) = @_;
    my $name = $hash->{NAME};
    return if $cs eq '';
	
    open( my $fh, ">>", "./log/MSwitch_debug_$name.log" );
    #print $fh localtime() . ": -> $cs\n";
	print $fh " -> $cs\n";
    close $fh;

    #my $hms = AnalyzeCommand( 0, '{return $hms}' );

    #my $write = $hms . ": -> " . $cs;
	
	my $write = " -> " . $cs;
	
    if ( exists $hash->{helper}{aktivelog} && $hash->{helper}{aktivelog} eq 'on' )
    {
		my  $encoded = urlEncode($write);
		FW_directNotify( "FILTER=$name","#FHEMWEB:WEB", "writedebug('$encoded')", "");
        #readingsSingleUpdate( $hash, "Debug", $write, 1 );
    }
    return;
}
##################################
sub MSwitch_LOG($$$) {
    my ( $name, $level, $cs ) = @_;
    my $hash = $defs{$name};

    if 
	((AttrVal( $name, 'MSwitch_Debug', "0" ) eq '2'|| AttrVal( $name, 'MSwitch_Debug', "0" ) eq '3'
        ) && ( $level eq "6" ))
    {
        MSwitch_debug2( $hash, $cs );
       # $cs = "[$name] " . $cs;
		
		
		return if $level eq "6";
    }
	
    $level = 5 if $level eq "6";
    my %UMLAUTE = (
        'Ä' => 'Ae',
        'Ö' => 'Oe',
        'Ü' => 'Ue',
        'ä' => 'ae',
        'ö' => 'oe',
        'ü' => 'ue'
    );
    my $UMLKEYS = join( "|", keys(%UMLAUTE) );
    $cs =~ s/($UMLKEYS)/$UMLAUTE{$1}/g;
    Log3( $name, $level, $cs );
    return;
}
#########################
sub MSwitch_confchange($$) {

    # change wenn folgende einträge vorhanden
    #I testinfo
    #Q dummy1#zu schaltendes geraet#device
    my ( $hash, $cs ) = @_;
    my $name = $hash->{NAME};
    MSwitch_clearlog($hash);
    $cs = urlDecode($cs);
    $cs =~ s/#\[sp\]/ /g;
    my @changes = split( /\|/, $cs );
    foreach my $change (@changes) {
        my @names = split( /#/, $change );

        # afected devices
        my $tochange1 = ReadingsVal( $name, ".Device_Affected", "" );
        my $oldname   = $names[0] . "-";
        my $newname   = $names[1] . "-";
        my @devices   = split( /,/, $tochange1 );
        my $x         = 0;
        foreach (@devices) {
            $_ =~ s/$oldname/$newname/g;
            $devices[$x] = $_;
            $x++;
        }
        my $newdevices = join( ',', @devices );
        readingsSingleUpdate( $hash, ".Device_Affected", $newdevices, 0 );

        #details
        my $tochange2 = ReadingsVal( $name, ".Device_Affected_Details", "" );
        my @devicesdetails = split( /#\[ND\]/, $tochange2 );
        $x = 0;
        foreach (@devicesdetails) {
            $_ =~ s/$oldname/$newname/g;
            $devicesdetails[$x] = $_;
            $x++;
        }
        $tochange2 = join( '#[ND]', @devicesdetails );
        $x = 0;
        while ( $tochange2 =~ m/(.*?)($names[0])(.*)?/ ) {
            my $firstpart  = $1;
            my $secondpart = $2;
            my $lastpart   = $3;
            $tochange2 = $firstpart . $names[1] . $lastpart;
            $x++;
            last if $x > 10;    #notausstieg
        }
        readingsSingleUpdate( $hash, ".Device_Affected_Details", $tochange2, 0 );
    }
    fhem("deletereading $name .change");
    fhem("deletereading $name .change_info");
    return;
}

##############################################################
sub MSwitch_dec($$) {

    my ( $hash, $todec ) = @_;
    my $name = $hash->{NAME};
	my @evtparts;
	my $event;
	
	
	#Log3("test",0,"aktevent: ".$hash->{helper}{aktevent});
	
	
    if ($hash->{helper}{aktevent})
	{
        @evtparts = split( /:/, $hash->{helper}{aktevent},$hash->{helper}{evtparts} );
		$event=$hash->{helper}{aktevent};
    }
    else 
	{
        $event       = "";
        $evtparts[0] = "";
        $evtparts[1] = "";
        $evtparts[2] = "";
    }
	
    my $evtsanzahl = @evtparts;
    if ( $evtsanzahl < 3 )
	{
        my $eventfrom = $hash->{helper}{eventfrom};
        unshift( @evtparts, $eventfrom );
        $evtsanzahl = @evtparts;
    }
    my $evtfull = join( ':', @evtparts );
    $evtparts[2] = '' if !defined $evtparts[2];
	$event       = "undef" if $event eq "";
    $evtparts[0] = "undef" if $evtparts[0] eq "";
    $evtparts[1] = "undef" if $evtparts[1] eq "";
    $evtparts[2] = "undef" if $evtparts[2] eq "";
	$evtfull   = "undef" if $evtfull eq "::";

    # ersetzungen direkt vor befehlsausführung
    # gilt für fhemcode, freecmdperl freecmd fhem

    if ( $todec =~ m/(\{)(.*)(\})/s )
	{
        # ersetzung für perlcode
        $todec =~ s/\n//g;
        $todec =~ s/\[\$SELF:/[$name:/g;
		$todec =~ s/MSwitch_Self/$name/g;

    }
    else
	{
        # ersetzung für fhemcode
        $todec =~ s/\$NAME/$hash->{helper}{eventfrom}/g;
        $todec =~ s/\$SELF/$name/g;
        $todec =~ s/\n//g;
        $todec =~ s/#\[wa\]/|/g;
        $todec =~ s/#\[SR\]/|/g;
        $todec =~ s/MSwitch_Self/$name/g;
        my $ersetzung;
		$todec =~ s/\$EVTFULL/$evtfull/g;
		
        $todec =~ s/\$EVTPART3/$evtparts[2]/g;
        $todec =~ s/\$EVTPART2/$evtparts[1]/g;
        $todec =~ s/\$EVTPART1/$evtparts[0]/g;
        $todec =~ s/\$EVENT/$event/g;
   }

    # ersetzung für beide codes
    # setmagic ersetzung
    my $x = 0;
    while ( $todec =~
        m/(.*)\[([a-zA-Z0-9._\$]{1,50})\:([a-zA-Z0-9._]{1,50})\](.*)/ )
    {
        $x++;    # notausstieg notausstieg
        last if $x > 20;    # notausstieg notausstieg
        my $firstpart   = $1;
        my $lastpart    = $4;
        my $readingname = $3;
        my $devname     = $2;
        $devname =~ s/\$SELF/$name/;
        my $setmagic = ReadingsVal( $devname, $readingname, 0 );
        $todec = $firstpart . $setmagic . $lastpart;
    }

    $todec =~ s/\[FREECMD\]//g;

    ###########################################################################
    ## ersetze gruppenname durch devicenamen
    ## test - nur wenn attribut gesetzt noch einfügen

    if ( AttrVal( $name, 'MSwitch_Device_Groups', 'undef' ) ne "undef" ) {
        my $testgroups = $data{MSwitch}{$name}{groups};
        my @msgruppen  = ( keys %{$testgroups} );

        foreach my $testgoup (@msgruppen) 
		{
            my $x = 0;
            while ( $todec =~ m/(.*)(.$testgoup.)(.*)/ ) {
                $x++;
                last if $x > 10;
                $todec =
                    $1 . " "
                  . $data{MSwitch}{$name}{groups}{$testgoup} . " "
                  . $3;
            }
        }
    }
    return $todec;
}

################################################################

sub MSwitch_makefreecmdonly($$) {

    #ersetzungen und variablen für freecmd
    # nur für freecmdperl

    my ( $hash, $cs ) = @_;
    my $name = $hash->{NAME};
    if ( $cs =~ m/(.*)(\{)(.*)(\})/s ) {
		
	my @evtparts;
	my $event;
    if ($hash->{helper}{aktevent}) {

        @evtparts = split( /:/, $hash->{helper}{aktevent},$hash->{helper}{evtparts} );
    }
    else {
        $event       = "";
        $evtparts[0] = "";
        $evtparts[1] = "";
        $evtparts[2] = "";

    }
	
    my $evtsanzahl = @evtparts;
    if ( $evtsanzahl < 3 ) {
        my $eventfrom = $hash->{helper}{eventfrom};
        unshift( @evtparts, $eventfrom );
        $evtsanzahl = @evtparts;
    }
    my $evtfull = join( ':', @evtparts );
    $evtparts[2] = '' if !defined $evtparts[2];
	#$event       = "undef" if $event eq "";
        $evtparts[0] = "undef" if $evtparts[0] eq "";
        $evtparts[1] = "undef" if $evtparts[1] eq "";
        $evtparts[2] = "undef" if $evtparts[2] eq "";
		$evtfull   = "undef" if $evtfull eq "::";

        my $firstpart = $1;
        ## variablendeklaration für perlcode / wird anfangs eingefügt

        my $newcode = "";

        if ( exists $hash->{helper}{eventfrom} ) {
            $newcode .= "my \$NAME = \"" . $hash->{helper}{eventfrom} . "\";";
        }
        else {
            $newcode .= "my \$NAME = \"\";";
        }

        $newcode .= "my \$SELF = \"" . $name . "\";\n";
		$newcode .="my \$EVTPART1 = \"" . $evtparts[0] . "\";\n";
        $newcode .="my \$EVTPART2 = \"" . $evtparts[1] . "\";\n";
        $newcode .= "my \$EVTPART3 = \"" .$evtparts[2] . "\";\n";
        $newcode .= "my \$EVTFULL = \"" . $evtfull . "\";\n";
        $newcode .= $3;
        $cs = "{\n$newcode}";

        # entferne kommntarzeilen
        $cs =~ s/#\[SR\]/|/g;

        my $newcs = "";
        my @lines = split( /\n/, $cs );
        foreach my $lin (@lines) {
            $lin =~ s/^\s+//;
            $lin =~ s/(#)([^;]*)($)//g;
            $lin =~ s/^#.*//g;
            $newcs .= $lin . "\n";
        }
        $cs = $newcs;
		{
		no warnings;
        $cs = $firstpart . "" . eval($cs);
		}
        return $cs;
    }
    return $cs;
}

################################################################
sub MSwitch_makefreecmd($$) {

    #ersetzungen und variablen für freecmd
    # nur für freecmdperl

    my ( $hash, $cs ) = @_;
    my $name = $hash->{NAME};
    if ( $cs =~ m/(\{)(.*)(\})/s )
	{
		my $oldpart = $2;
		my $newcode = "";
		my @evtparts;
		my $event;
		if ($hash->{helper}{aktevent})
		{

			@evtparts = split( /:/, $hash->{helper}{aktevent},$hash->{helper}{evtparts} );
		}
		else 
		{
			$event       = "";
			$evtparts[0] = "";
			$evtparts[1] = "";
			$evtparts[2] = "";
		}
		
		my $evtsanzahl = @evtparts;
		if ( $evtsanzahl < 3 )
		{
			my $eventfrom = $hash->{helper}{eventfrom};
			unshift( @evtparts, $eventfrom );
			$evtsanzahl = @evtparts;
		}
		my $evtfull = join( ':', @evtparts );
		$evtparts[2] = '' if !defined $evtparts[2];
        $evtparts[0] = "undef" if $evtparts[0] eq "";
        $evtparts[1] = "undef" if $evtparts[1] eq "";
        $evtparts[2] = "undef" if $evtparts[2] eq "";
		$evtfull   = "undef" if $evtfull eq "::";

        ## variablendeklaration für perlcode / wird anfangs eingefügt
        if ( exists $hash->{helper}{eventfrom} )
		{
            $newcode .= "my \$NAME = \"" . $hash->{helper}{eventfrom} . "\";\n";
        }
        else
		{
            $newcode .= "my \$NAME = \"\";\n";
        }

        $newcode .= "my \$SELF = \"" . $name . "\";\n";
		$newcode .="my \$EVTPART1 = \"" . $evtparts[0] . "\";\n";
        $newcode .= "my \$EVTPART2 = \"" . $evtparts[1] . "\";\n";
        $newcode .= "my \$EVTPART3 = \"" .$evtparts[2] . "\";\n";
        $newcode .="my \$EVTFULL = \"" . $evtfull . "\";\n";
        $newcode .= $oldpart;
        $cs = "{\n$newcode}";

        # entferne kommntarzeilen
        $cs =~ s/#\[SR\]/[SR]/g;

        my $newcs = "";
        my @lines = split( /\n/, $cs );
        foreach my $lin (@lines)
		{
            $lin =~ s/^\s+//;
            $lin =~ s/(#)([^;]*)($)//g;
            $lin =~ s/^#.*//g;
            $newcs .= $lin . "\n";
        }
        $cs = $newcs;
    }
    return $cs;

}
#################################
sub MSwitch_check_setmagic_i($$) {
    my ( $hash, $msg ) = @_;
    my $name = $hash->{NAME};

    # setmagic ersetzung

    my $x = 0;
    while ( $msg =~ m/(.*)\[(.*)\:(.*)\:i\](.*)/ ) {
        $x++;    # notausstieg notausstieg
        last if $x > 20;    # notausstieg notausstieg
        my $setmagic = ReadingsVal( $2, $3, 0 );
        $msg = $1 . $setmagic . $4;
    }
    $x = 0;
    while ( $msg =~ m/(.*)\[(.*)\:(.*)\:d\:i\](.*)/ ) {
        $x++;               # notausstieg notausstieg
        last if $x > 20;    # notausstieg notausstieg
        my $setmagic = ReadingsNum( $2, $3, 0 );
        $msg = $1 . $setmagic . $4;
    }
    return $msg;
}

#################################
sub MSwitch_setconfig($$) {
    my ( $hash, $aVal ) = @_;
    my $name = $hash->{NAME};

    my %keys;
    foreach my $attrdevice ( keys %{ $attr{$name} } )    #geht
    {
        delete $attr{$name}{$attrdevice};
    }
    my $testreading = $hash->{READINGS};
    my @areadings   = ( keys %{$testreading} );
    #
    foreach my $key (@areadings) {
        fhem("deletereading $name $key ");
    }
    my $Zeilen = '';
    open( BACKUPDATEI, "<./FHEM/MSwitch/$aVal" )
      || return "$name|no Backupfile ./MSwitch_Extensions/$aVal found\n";
    while (<BACKUPDATEI>) {
        $Zeilen = $Zeilen . $_;
    }
    close(BACKUPDATEI);
    $Zeilen =~ s/\n/#[EOL]/g;
    MSwitch_saveconf( $hash, $Zeilen );
    return;
}
#####################################
sub MSwitch_del_savedcmds($) {
    my ($hash) = @_;
    my $name = $hash->{NAME};
    my $savecmds = AttrVal( $name, 'MSwitch_DeleteCMDs', $deletesavedcmdsstandart );
    if (   exists $hash->{helper}{last_devicecmd_save}
        && $hash->{helper}{last_devicecmd_save} < ( time - $deletesavedcmds )
        && $savecmds ne "manually" )
    {
        delete $data{MSwitch}{devicecmds1};
        delete $data{MSwitch}{last_devicecmd_save};
    }
    return;
}
##################################
# Eventlog
sub MSwitch_Eventlog($$) {
    my ( $hash, $typ ) = @_;
    my $Name = $hash->{NAME};
    my $out1;
    my $seq;
    my $x   = 1;
    my $log = $hash->{helper}{eventlog};
    if ( $typ eq "clear" ) {
        delete( $hash->{helper}{eventlog} );
        delete( $hash->{helper}{tmp} );
        delete( $hash->{helper}{history} )
          ; # lösche historyberechnung verschieben auf nach abarbeitung conditions
            # sequenz
        return "ok, alle Daten gelöscht !";
    }

    if ( $typ eq "timeline" ) {
        $out1 =
"Eventlog - Timeline<br>---------------------------------------------------------------------------------------------------<br>";
        my $y = ( keys %{$log} ) - 1;
        foreach my $seq ( sort keys %{$log} ) {
            my $timestamp = FmtDateTime($seq);
            $out1 .=
"<input id =\"Checkbox-$x\"  name=\"Checkbox-$x\" type=\"checkbox\" value=\"test\" />";
            $out1 .=
                $timestamp . " "
              . $hash->{helper}{eventlog}{$seq}
              . " [EVENT/EVTPART1,2,3/EVTFULL:h$y]<br>";
            $hash->{helper}{tmp}{keys}{$x} = $seq;
            $x++;
            $y--;
        }
        $out1 .=
"<br><input type=\"button\" value=\"delete selected\" onclick=\" javascript: deletelog() \">";
        $out1 .=
          "<input type='hidden' id='dellog' name='dellog' size='5'  value ='"
          . $x . "'>";
    }

    if ( $typ eq "sequenzformated" ) {
        my $lastkey;
        my $firstkey;
        my $tmpseq;
        $out1 =
"Eventlog - sequenzeformated<br>---------------------------------------------------------------------------------------------------<br>";
        foreach $seq ( sort keys %{$log} ) {
            $firstkey = $seq if $x == 1;
            $lastkey = $seq;
            $out1   .= $hash->{helper}{eventlog}{$seq} . " ";
            $tmpseq .= $hash->{helper}{eventlog}{$seq} . " ";
            $x++;
        }
        chop($tmpseq);
        chop($out1);
        $out1 .=
"<br>---------------------------------------------------------------------------------------------------<br>";
        my $timeneed = int( $lastkey - $firstkey ) + 1;
        $out1 .= "Time needed for Sequenz = $timeneed Sekunden<br>&nbsp;<br>";
        $out1 .=
"<input name='edit' type='button' value='write sequenze to ATTR' onclick=' javascript: writeattr() '>";
        $out1 .=
"<br>&nbsp;<br>Folgende Attribute werden gesetzt und evtl. vorhandene Inhalte überschrieben:<br>MSwitch_Sequenz<br>MSwitch_Sequenz_time<br>Die Condition-Abfrage auf Match lautet:<br>[\$SELF:SEQUENCE_Number] eq '1'";
        $hash->{helper}{tmp}{sequenz}     = $tmpseq;
        $hash->{helper}{tmp}{sequenztime} = $timeneed;
    }
    $out1 = "Keine Daten vorhanden " if $x eq "1";
    return $out1;
}
#####################################
sub MSwitch_Writesequenz($) {
    my ($hash)   = @_;
    my $name     = $hash->{NAME};
    my $tmpseq   = $hash->{helper}{tmp}{sequenz};
    my $timeneed = $hash->{helper}{tmp}{sequenztime};
    delete( $hash->{helper}{tmp} );
    $attr{$name}{MSwitch_Sequenz}      = $tmpseq;
    $attr{$name}{MSwitch_Sequenz_time} = $timeneed;
    return;
}
#####################################
sub MSwitch_delete_singlelog($$) {
    my ( $hash, $arg ) = @_;
    my $Name = $hash->{NAME};
    $hash->{helper}{tmp}{deleted} = "on";
    chop($arg);
    my @args = split( /,/, $arg );
    foreach my $logs (@args) {
        my $todelete = $hash->{helper}{tmp}{keys}{$logs};
        delete( $hash->{helper}{eventlog}{$todelete} );
    }
    return $arg;
}
################################# MSwitch_Check_Event

sub MSwitch_makegroupcmd($$) {
    my ( $hash, $gruppe ) = @_;
    my $Name = $hash->{NAME};
    delete $data{MSwitch}{gruppentest};
    my @inhalt = split( /,/, $data{MSwitch}{$Name}{groups}{$gruppe} );

    # suche alle geräte
    my @alldevices    = ();
    my $anzahldevices = 0;    # anzahl der geräte
    foreach my $dev (@inhalt) {
        my @tmpdevices = devspec2array($dev);
        push( @alldevices, @tmpdevices );
    }

    my @unfilter = ();
    foreach my $aktdevice (@alldevices) {
        my $test = getAllSets($aktdevice);
        $anzahldevices++;
        my @cmdsatz = split( / /, $test );

        foreach my $aktsatz (@cmdsatz) {

            $data{MSwitch}{gruppentest}{$aktsatz} = 'ok';
            push( @unfilter, $aktsatz );
        }
    }

    my @testout = ( keys %{ $data{MSwitch}{gruppentest} } );
    my @exitcmd = ();
    foreach my $allkeys (@testout) {
        next if $allkeys eq "";
        next if $allkeys eq " ";
        my $re       = qr/^$allkeys$/;
        my @gefischt = grep( /$re/, @unfilter );
        my $tmpanz   = @gefischt;
        if ( $tmpanz == $anzahldevices ) {
            push( @exitcmd, $allkeys );

        }
    }
    return join( ' ', @exitcmd );
}

#################################

sub MSwitch_makegroupcmdout($$) {
    my ( $hash, $gruppe ) = @_;
    my $Name = $hash->{NAME};
    my @inhalt = split( /,/, $data{MSwitch}{$Name}{groups}{$gruppe} );

    # suche alle geräte
    my @alldevices = ();
    foreach my $dev (@inhalt) {
        my @tmpdevices = devspec2array($dev);
        push( @alldevices, @tmpdevices );
    }
    my $outfile = join( '\n', @alldevices );
    asyncOutput( $hash->{CL},
            "<html><center><br><textarea name=\"edit1\" id=\"edit1\"  rows=\""
          . "20\" cols=\"100\" STYLE=\"font-family:Arial;font-size:9pt;\">"
          . $outfile
          . "</textarea><br></html>" );
    return;
}


#################################

sub MSwitch_gettemplate($$) {
    my ( $hash, $template ) = @_;
    my $Name    = $hash->{NAME};
    my $tZeilen = "";
    my ( $err, $data );
    my $adress      = $templatefile . $template;
    my $localadress = "./FHEM/MSwitch/";
    if ( $template =~ m/\.*\/(.*)/s ) {
        $adress = $localadress . $1;
        open( BACKUPDATEI, "<$adress" )
          || Log3( "test", 0, "ERROR " . $adress );
        while (<BACKUPDATEI>) {
            $data = $data . $_;
        }
        close(BACKUPDATEI);
    }
    else {
        my $param = {
            url     => "$adress",
            timeout => 5,
            hash    => $hash
            , # Muss gesetzt werden, damit die Callback funktion wieder $hash hat
            method => "GET",    # Lesen von Inhalten
            header => "User-Agent: None\r\nAccept: application/json"
            ,                   # Den Header gemäß abzufragender Daten ändern
            callback =>
              \&X_ParseHttpResponse # Diese Funktion soll das Ergebnis dieser HTTP Anfrage bearbeiten
        };
        ( $err, $data ) = HttpUtils_BlockingGet($param);
    }

    return "$data";
}

##########################################
sub MSwitch_loadpreconf($) {
    my ($hash)  = @_;
    my $Name    = $hash->{NAME};
    my $preconf = '';
    $preconf = get($preconffile);
    $preconf =~ s/\n/#[NEWL]/g;
    $preconf =~ s/\r//g;
    return $preconf;
}
##########################################

sub MSwitch_loadnotify($$) {
    my ( $hash, $notify ) = @_;
    my $Name      = $hash->{NAME};
    my $nothash   = $defs{$notify};
    my $notinsert = $nothash->{DEF};
    $notinsert =~ s/\r//g;
    $notinsert =~ s/\t/    /g;
    return $notinsert;
}
##########################################
sub MSwitch_loadat($$) {
    my ( $hash, $at ) = @_;
    my $Name = $hash->{NAME};
    my $athash   = $defs{$at};
    my $atdef    = $athash->{DEF};
    my $atcomand = $athash->{COMMAND};

    $atcomand =~ s/\r//g;
    $atcomand =~ s/\t/    /g;

    my $attimespec = $athash->{TIMESPEC};
    my $attrigtime = $athash->{TRIGGERTIME};

    my $string =
        $atdef
      . "[TRENNER]"
      . $atcomand
      . "[TRENNER]"
      . $attimespec
      . "[TRENNER]"
      . $attrigtime;

    return $string;
}
##########################################
sub MSwitch_reloaddevices($$) {
    my ( $hash, $arg1 ) = @_;
    my $Name = $hash->{NAME};
    my $string = '';
    my @devs;
    my @devscmd;
    my $aVal = $arg1;
    my @gset = split( /\[nl\]/, $aVal );
    foreach my $line (@gset)
	{
        my @lineset = split( /->/, $line );
        $lineset[0] =~ s/ //g;
        next if $lineset[0] eq "";
        push( @devs, $lineset[0] );
        $data{MSwitch}{$Name}{groups}{ $lineset[0] } = $lineset[1];
        $string = MSwitch_makegroupcmd( $hash, $lineset[0] );
        push( @devscmd, $string );

    }

	my $newnames = join( "[|]", @devs );
	my $newsets = join( "[|]", @devscmd );
	$string = "$newnames" . "[TRENNER]" . "$newsets";
    return $string;
}

###############################################

sub MSwitch_whitelist($$) {
    my ( $hash, $arg1 ) = @_;
    my $Name = $hash->{NAME};
    $hash->{NOTIFYDEV} = $arg1;
    %ntfyHash = ();
    return;
}

###############################################

sub MSwitch_savetemplate($$$) {
    my ( $hash, $arg1, $arg2 ) = @_;
    my $Name = $hash->{NAME};
    $hash->{NOTIFYDEV} = $arg1;
    if ( -d "FHEM/MSwitch" ) {

    }
    else {
        mkdir( "FHEM/MSwitch", 0777 );
    }

    $arg2 =~ s/\[EOL\]/\n/g;
    $arg2 =~ s/\[SP\]/ /g;
    $arg2 =~ s/\[RA\]/#/g;
    $arg2 =~ s/\[PL\]/+/g;
    $arg2 =~ s/\[AN\]/"/g;
    $arg2 =~ s/\[SE\]/;/g;
	$arg2 =~ s/\[AND\]/&/g;

    open( BACKUPDATEI, ">FHEM/MSwitch/$arg1.txt" )
      ;    # Datei zum Schreiben öffnen
    print BACKUPDATEI "$arg2\n";
    close(BACKUPDATEI);

    asyncOutput( $hash->{CL},
"<html><center><br>Das Template wurde unter \"./FHEM/MSwitch/$arg1.txt gespeichert\"<br></html>"
    );

    return;
}

##############################################
sub MSwitch_PerformHttpRequest($$) {
    my ( $hash, $def ) = @_;
    my $name = $hash->{NAME};
	my $showevents = AttrVal( $name, "MSwitch_generate_Events", 0 );
	if (AttrVal( $name, 'MSwitch_Debug', '0' ) ne "0" ){$showevents = 1};
    my $data;
    my $err = "";
    fhem("deletereading $name FullHTTPResponse");

    my $param = {
        url     => "$def",
        timeout => 5,
        hash    => $hash
        ,    # Muss gesetzt werden, damit die Callback funktion wieder $hash hat
        method => "GET",    # Lesen von Inhalten
        header => "User-Agent: None\r\nAccept: application/json"
        ,                   # Den Header gemäß abzufragender Daten ändern
        callback =>
          \&X_ParseHttpResponse # Diese Funktion soll das Ergebnis dieser HTTP Anfrage bearbeiten
    };

#HttpUtils_NonblockingGet($param);  	# Starten der HTTP Abfrage. Es gibt keinen Return-Code.

    ( $err, $data ) = HttpUtils_BlockingGet($param);
    if (length($err) > 1 )    # wenn ein Fehler bei der HTTP Abfrage aufgetreten ist
    {
        Log3 $name, 1, "$err";
        readingsSingleUpdate( $hash, "FullHTTPResponse", $err, $showevents );
        return;

    }
    $data{MSwitch}{$name}{HTTPresponse} = $data;

    my $mapss = AttrVal( $name, "MSwitch_ExtraktHTTPMapping", "no_mapping" );
    my @maps;
    @maps = split( /\n/, $mapss );
    my $regex =
      AttrVal( $name, "MSwitch_ExtraktfromHTTP", "FullHTTPResponse->(.*)" );
    my @gset = split( /\n/, $regex );
    foreach my $line (@gset)
	{
        my @lineset    = split( /->/, $line );
        my $reading    = $lineset[0];
        my $reg        = $lineset[1];
        my $regex      = qr/$reg/;
        my $regexblank = $reg;

        fhem( "deletereading $name $reading" . "_.*" );

        if ( my @matches = $data =~ /$regex/sg )
		{
            my $arg = join( "#[trenner]", @matches );
            # mapping
            if ( $mapss ne "no_mapping" )
			{
                foreach my $mapping (@maps)
				{
                    my @mapset = split( /->/, $mapping );
                    my $org    = $mapset[0];
                    my $ers    = $mapset[1];
                    $arg =~ s/$org/$ers/g;
                }
            }

            my @newmatch = split( /#\[trenner\]/, $arg );
            $arg = join( ",", @newmatch );
            my $x = 0;
            if ( @newmatch > 1 && $reading ne "FullHTTPResponse" )
            {
                foreach my $match (@newmatch)
				{
                    readingsSingleUpdate( $hash, $reading . "_" . $x,  $match, $showevents );
                    $x++;
                }
            }

            if ( $reading eq "FullHTTPResponse" )
			{
                $arg =
                    "for more details \"get $name HTTPresponse\"    ..... "
                  . substr( $arg, 0, 150 ) . " .....";
            }
            readingsSingleUpdate( $hash, $reading, $arg, $showevents );
        }
        else 
		{
            Log3 $name, 1, "no match found for regex $reg";
            readingsSingleUpdate( $hash, $reading, "no match", $showevents );
        }
    }
    return;
}
###########################################################

sub X_ParseHttpResponse($) {
    my ( $param, $err, $data ) = @_;
    my $hash = $param->{hash};
    my $name = $hash->{NAME};

    if ( $err ne "" )    # wenn ein Fehler bei der HTTP Abfrage aufgetreten ist
    {
        Log3 $name, 1,
            "error while requesting "
          . $param->{url}
          . " - $err";    # Eintrag fürs Log
        readingsSingleUpdate( $hash, "fullResponse", "ERROR", 0 );               # Readings erzeugen
    }
    elsif ( $data ne "" ) # wenn die Abfrage erfolgreich war ($data enthält die Ergebnisdaten des HTTP Aufrufes)
    {
        Log3 $name, 0,
          "url " . $param->{url} . " returned: $data";    # Eintrag fürs Log

        # An dieser Stelle die Antwort parsen / verarbeiten mit $data

        readingsSingleUpdate( $hash, "fullResponse", $data, 0 )
          ;                                               # Readings erzeugen
    }

}

1;

