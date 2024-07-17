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
# bv
#l
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


my @msw;
my $codelenght    = 100; # abbruch der ansicht ( schnellansicht ) nach x zeichen
my $anzahlmswitch = 0;
my $shutdowned    = 0;
my $foundcfgs     = 0;
my $err           = "";
my $updateinfo    = "";  # wird mit info zu neuen versionen besetzt
my $generalinfo   = "";  # wird mit aktuellen informationen besetzt
my $updateinfolink =
"https://raw.githubusercontent.com/Byte009/FHEM-MSwitch/master/updatenfo.txt";
my $preconffile =
"https://raw.githubusercontent.com/Byte009/MSwitch_Addons/master/MSwitch_Preconf.conf";
my $templatefile =
  "https://raw.githubusercontent.com/Byte009/MSwitch_Templates/master/";
my $widgetfile   = "www/MSwitch/MSwitch_widgets.txt";
my $helpfile     = "www/MSwitch/MSwitch_Help.txt";
my $helpfileeng  = "www/MSwitch/MSwitch_Help_eng.txt";
my $conffile     = "www/MSwitch/MSwitch_Conf.txt";
 
my $backupfile= "restoreDir/MSwitch/";
my $restoredir   = "restoreDir/MSwitch/";
my $cmdprocessing = "block";  #cmd standart block oder lineverarbeitung
my $backupfilen= "restoreDir";
my $restoredirn= "restoreDir"; 

my $support      = "Support Mail: Byte009\@web.de";
my $autoupdate   = 'on';                                 # off/on
my $version      = '7.70';                               # version
my $wizard       = 'on';                                 # on/off   - not in use
my $importnotify = 'on';                                 # on/off   - not in use
my $importat     = 'on';                                 # on/off   - not in use
my $vupdate      = 'V6.3'
  ; # versionsnummer der datenstruktur . änderung der nummer löst MSwitch_VersionUpdate aus .
my $undotime      = 3000;    # Standarzeit in der ein Undo angeboten wird
my $startsafemode = 1;
my $savecount     = 60
  ; # anzahl der zugriff im zeitraum zur auslösung des safemodes. kann durch attribut überschrieben werden .
my $savemodetime   = 3;      # Zeit für Zugriffe im Safemode ( 100000 = 1 sec )
my $savemode2block = 60;
my $rename         = "off";  # on/off rename in der FW_summary möglich
my $showcom        = "off";
my $webwidget      = 0;      # standartverhalten webwidgets
my $standartstartdelay = 30
  ; # zeitraum nach fhemstart , in dem alle aktionen geblockt werden. kann durch attribut überschrieben werden .
my $deletesavedcmds = 1800
  ; # zeitraum nachdem gespeicherte devicecmds gelöscht werden ( beschleunigung des webinterfaces )
my $deletesavedcmdsstandart = "nosave"
  ; # standartverhalten des attributes "MSwitch_DeleteCMDs" <manually,nosave,automatic>

# standartlist ignorierter Devices . kann durch attribut überschrieben werden .
my @doignore =
  qw(notify allowed at watchdog doif fhem2fhem telnet FileLog readingsGroup FHEMWEB autocreate eventtypes readingsproxy SVG cul);
my $startmode               = "Notify";    # Startmodus des Devices nach Define
my $wizardreset             = 3600;        #Timeout für Wizzard
my $MSwitch_generate_Events = "1";
my $statistic;
my $debugging    = "0";
my $configdevice = "";
$data{MSwitch}{updateinfolink} = $updateinfolink;
$data{MSwitch}{version}        = $version;
$data{MSwitch}{Log}            = "all";

if ( 1 == 1 ) {
    my $param = {
        url     => "$updateinfolink",
        timeout => 5,
        hash    => ''
        ,    # Muss gesetzt werden, damit die Callback funktion wieder $hash hat
        method => "GET",    # Lesen von Inhalten
        header => "User-Agent: None\r\nAccept: application/json"
        ,                   # Den Header gemäß abzufragender Daten ändern
        callback =>
          \&X_ParseHttpResponse # Diese Funktion soll das Ergebnis dieser HTTP Anfrage bearbeiten
    };

#HttpUtils_NonblockingGet($param);  	# Starten der HTTP Abfrage. Es gibt keinen Return-Code.
    ( $err, $updateinfo ) = HttpUtils_BlockingGet($param);
    if (
        length($err) >
        1 )    # wenn ein Fehler bei der HTTP Abfrage aufgetreten ist
    {
        Log3( "MSwitch", 5, "$err" );
    }
}

$updateinfo =~ s/\n/[LINE]/g;
my @uinfos = split( /\[LINE\]/, $updateinfo );
$data{MSwitch}{Version}            = $uinfos[1];
$data{MSwitch}{Updateinformation}  = $uinfos[2];
$data{MSwitch}{Generalinformation} = $uinfos[3];

my $startmessage = "";
$startmessage .=
  "     -> Version $version... loading files and system variables\n";

if ( $uinfos[1] ne $version ) {
    $startmessage .= "     -> System: Update avaible: " . $uinfos[1] . "\n";
}
else {
    $startmessage .= "     -> System: no update avaible\n";
}

$startmessage .= "     -> setting preconfpath... $preconffile\n";
$startmessage .= "     -> setting undotime... " . $undotime . "sec\n";
$startmessage .= "     -> setting rename... $rename\n";
$startmessage .=
    "     -> setting wizard... "
  . $wizard
  . ", resettime: "
  . $wizardreset . "sec\n";
$startmessage .=
  "     -> setting startdelay... " . $standartstartdelay . "sec\n";
$startmessage .= "     -> setting startmode... $startmode\n";

## lade widgets
delete $data{MSwitch}{Widget};

# lade widgets
my $widgetname;
my $verteiler = "";
my $pfad      = "";
if ( open( HELP, "<./$widgetfile" ) ) {
    while (<HELP>) {
        next if $_ eq "\n";

        if ( $_ eq "[MSwitchwidgetName]\n" )   { $pfad = "Name";    next; }
        if ( $_ eq "[MSwitchwidgetHtml]\n" )   { $pfad = "Html";    next; }
        if ( $_ eq "[MSwitchidgetScript]\n" )  { $pfad = "Script";  next; }
        if ( $_ eq "[MSwitchidgetReading]\n" ) { $pfad = "Reading"; next; }
        if ( $_ eq "[MSwitchwidgetEND]\n" )    { $pfad = "";        next; }
        if ( $_ eq "[MSwitchidgetCode]\n" )    { $pfad = "Code";    next; }
        if ( $_ eq "[MSwitchSystem]\n" )       { $pfad = "System";  next; }
        if ( $pfad eq "Name" ) {
            $_ =~ s/\n//g;
            $widgetname = $_;
            $data{MSwitch}{Widget}{$_}{name} = $widgetname;
        }
        if ( $pfad eq "Html" ) {
            $data{MSwitch}{Widget}{$widgetname}{html} .= $_;
        }
        if ( $pfad eq "Script" ) {
            $data{MSwitch}{Widget}{$widgetname}{script} .= $_;
        }
        if ( $pfad eq "Reading" ) {
            $_ =~ s/\n//g;
            $data{MSwitch}{Widget}{$widgetname}{reading} .= $_;
        }
        if ( $pfad eq "Code" ) {
            $_ =~ s/\n//g;
            $data{MSwitch}{Widget}{$widgetname}{code} .= $_;
        }
        if ( $pfad eq "System" ) {
            $_ =~ s/\n//g;
            $data{MSwitch}{Widget}{$widgetname}{system} .= $_;
        }
    }
    close(HELP);
    $startmessage .= "     -> widgetfile ($widgetfile) loaded - Widgets on\n";
    $startmessage .= "     -> verfuegbare Widgets: ";
    my $inhalt1 = $data{MSwitch}{Widget};
    foreach my $a ( sort keys %{$inhalt1} ) {
        $startmessage .= "[$a],";
    }
    chop($startmessage);
    $startmessage .= "\n";
}
else {
    $startmessage .=
      "!!!  -> no widgetfile ($widgetfile) found - Widgets off\n";
}

#lade helpfiles
my $germanhelp   = "";
my $englischhelp = "";
my %UMLAUTE      = (
    'Ä' => 'Ae',
    'Ö' => 'Oe',
    'Ü' => 'Ue',
    'ä' => 'ae',
    'ö' => 'oe',
    'ü' => 'ue'
);
my $UMLKEYS = join( "|", keys(%UMLAUTE) );

if ( open( HELP, "<./$helpfile" ) ) {
    while (<HELP>) {
        $germanhelp = $germanhelp . $_;
    }
    close(HELP);
    $germanhelp =~ s/\n/#[LINE]\\\n/g;
    $germanhelp =~ s/"/#[DA]/g;
    $germanhelp =~ s/'/#[A]/g;
    $germanhelp =~ s/($UMLKEYS)/$UMLAUTE{$1}/g;
    $startmessage .= "     -> helpfile ger ($helpfile) loaded - Help on\n";
}
else {
    $startmessage .= "!!!  -> helpfile ger ($helpfile) not found - Help off\n";
}

if ( open( HELP, "<./$helpfileeng" ) ) {
    while (<HELP>) {
        $englischhelp = $englischhelp . $_;
    }
    close(HELP);
    $englischhelp =~ s/\n/#[LINE]\\\n/g;
    $englischhelp =~ s/"/#[DA]/g;
    $englischhelp =~ s/'/#[A]/g;
    $englischhelp =~ s/($UMLKEYS)/$UMLAUTE{$1}/g;
    $startmessage .= "     -> helpfile eng ($helpfileeng) loaded - Help on\n";
}
else {
    $startmessage .=
      "!!!  -> helpfile eng ($helpfileeng) not found - Help off\n";
}

$startmessage .= "     -> autoupdate devices status: $autoupdate \n";
$startmessage .= "     -> $support\n";
$startmessage .= "     -> Mswitch initializing ready\n";
Log3( "MSwitch", 5,
    "Messages collected while initializing MSwitch-System:\n$startmessage" );
$data{MSwitch}{startmessage} = $startmessage;
$startmessage = "";
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
sub MSwitch_backup_this($$);
sub MSwitch_backup_all($);
sub MSwitch_restore_all($);
sub MSwitch_restore_this($$);
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
sub MSwitch_CreateStatusReset(@);
sub MSwitch_Get_Backup_inhalt(@);
sub MSwitch_Asc($);

##############################

my $FLevel="7.67,7.68";
my $attrdummy =
    "  disable:0,1"
  . "  MSwitch_CMD_processing:block,line"
  . "  MSwitch_Language:EN,DE"
  . "  MSwitch_Format_Lastdelay"
  . "  MSwitch_Delay_Count:0,1,5,10,30,60"
  . "  MSwitch_INIT:save,cfg"
  . "  MSwitch_Debug:0,1"
  . "  MSwitch_State_Counter:off,24_Hours,manuell,after_switch"
  . "  MSwitch_use_WebWidgets:0,1"
  . "  MSwitch_Expert:0,1"
  . "  MSwitch_Help:0,1"
  . "  disabledForIntervals"
  . "  MSwitch_Futurelevel:".$FLevel
  . "  MSwitch_Safemode:0,1,2"
  . "  MSwitch_Readings:textField-long"
  . "  MSwitch_Mode:Full,Notify,Toggle,Dummy"
  . "  MSwitch_Selftrigger_always:0,1,2"
  . "  MSwitch_Statistic:0,1"
  . "  MSwitch_generate_Events:0,1"
  . "  MSwitch_generate_Events_selected:textField-long"
  . "  useSetExtensions:0,1"
  . "  setList:textField-long "
  . "  MSwitch_Comment_to_Room:0,1"
  . "  readingList:textField-long "
  . "  MSwitch_SysExtension:0,1,2 "
  . "  MSwitch_lastState:textField-long"
  . "  useSetExtensions:0,1";

my $attractivedummy =
    "  disable:0,1"
  . "  MSwitch_CMD_processing:block,line"
  . "  MSwitch_Format_Lastdelay"
  . "  MSwitch_Delay_Count:0,1,5,10,30,60"
  . "  MSwitch_Language:EN,DE"
  . "  MSwitch_INIT:save,cfg"
  . "  MSwitch_State_Counter:off,24_Hours,manuell,after_switch"
  . "  MSwitch_Debug:0,1,2,3,4"
  . "  disabledForIntervals"
  . "  MSwitch_Expert:0,1"
  . "  MSwitch_Modul_Mode:0,1"
  . "  MSwitch_generate_Events:0,1"
  . "  MSwitch_generate_Events_selected:textField-long"
  . "  MSwitch_Readings:textField-long"
  . "  MSwitch_use_WebWidgets:0,1"
  . "  MSwitch_EventMap:textField-long"
  . "  stateFormat:textField-long"
  . "  MSwitch_Eventhistory:0,1,2,3,4,5,10,20,30,40,50,60,70,80,90,100,150,200"
  . "  MSwitch_Eventhistory_to_Reading:0,1"
  . "  MSwitch_Eventhistory_timestamp_to_Reading:0,1"
  . "  MSwitch_Eventhistory_realtime_to_Reading:0,1"
  . "  MSwitch_Delete_Delays:0,1,2,3"
  . "  MSwitch_Help:0,1"
  . "  MSwitch_Comment_to_Room:0,1"
  . "  MSwitch_Futurelevel:".$FLevel
  . "  MSwitch_Ignore_Types:textField-long "
  . "  MSwitch_Extensions:0,1"
  . "  MSwitch_Safemode:0,1,2"
  . "  MSwitch_Statistic:0,1"
  . "  MSwitch_DeleteCMDs:manually,automatic,nosave"
  . "  MSwitch_Mode:Full,Notify,Toggle,Dummy"
  . "  MSwitch_Selftrigger_always:0,1,2"
  . "  useSetExtensions:0,1"
  . "  MSwitch_Snippet:textField-long "
  . "  MSwitch_setList:textField-long "
  . "  setList:textField-long "
  . "  readingList:textField-long "
  . "  MSwitch_Device_Groups:textField-long"
  . "  MSwitch_ExtraktfromHTTP:textField-long"
  . "  MSwitch_ExtraktHTTPMapping:textField-long"
  . "  MSwitch_ExtraktHTTP_max"
  . "  MSwitch_Switching_once:0,1 "
  . "  MSwitch_SysExtension:0,1,2 "
  . "  MSwitch_lastState:textField-long"
  . "  useSetExtensions:0,1"
  . $readingFnAttributes;

my $attrresetlist =
    "  MSwitch_CMD_processing:block,line"
  . "  disable:0,1"
  . "  disabledForIntervals"
  . "  MSwitch_Format_Lastdelay"
  . "  MSwitch_Delay_Count:0,1,5,10,30,60"
  . "  MSwitch_use_WebWidgets:0,1"
  . "  MSwitch_State_Counter:off,24_Hours,manuell,after_switch"
  . "  MSwitch_Language:EN,DE"
  . "  MSwitch_INIT:save,cfg"
  . "  stateFormat:textField-long"
  . "  MSwitch_Comments:0,1"
  . "  MSwitch_Read_Log:0,1"
  . "  MSwitch_Statistic:0,1"
  . "  MSwitch_Hidecmds"
  . "  MSwitch_Help:0,1"
  . "  MSwitch_Readings:textField-long"
  . "  MSwitch_EventMap:textField-long"
  . "  MSwitch_Debug:0,1,2,3"
  . "  MSwitch_Expert:0,1"
  . "  MSwitch_Delete_Delays:0,1,2,3,4"
  . "  MSwitch_Include_Devicecmds:0,1"
  . "  MSwitch_Comment_to_Room:0,1"
  . "  MSwitch_generate_Events:0,1"
  . "  MSwitch_generate_Events_selected:textField-long"
  . "  MSwitch_Include_Webcmds:0,1"
  . "  MSwitch_Include_MSwitchcmds:0,1"
  . "  MSwitch_Activate_MSwitchcmds:0,1"
  . "  MSwitch_Ignore_Types:textField-long "
  . "  MSwitch_Reset_EVT_CMD1_COUNT"
  . "  MSwitch_Reset_EVT_CMD2_COUNT"
  . "  MSwitch_Extensions:0,1"
  . "  MSwitch_DeleteCMDs:manually,automatic,nosave"
  . "  MSwitch_Modul_Mode:0,1"
  . "  MSwitch_Mode:Full,Notify,Toggle,Dummy"
  . "  MSwitch_Condition_Time:0,1"
  . "  MSwitch_Selftrigger_always:0,1,2"
  . "  MSwitch_Futurelevel:".$FLevel
  . "  MSwitch_RandomTime"
  . "  MSwitch_RandomNumber"
  . "  MSwitch_Safemode:0,1,2"
  . "  MSwitch_Snippet:textField-long "
  . "  MSwitch_Startdelay:0,10,20,30,60,90,120"
  . "  MSwitch_Wait"
  . "  MSwitch_Event_Wait:textField-long"
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
  . "  MSwitch_ExtraktHTTP_max"
  . "  MSwitch_Eventhistory:0,1,2,3,4,5,10,20,30,40,50,60,70,80,90,100,150,200"
  . "  MSwitch_Eventhistory_to_Reading:0,1"
  . "  MSwitch_Eventhistory_timestamp_to_Reading:0,1"
  . "  MSwitch_Eventhistory_realtime_to_Reading:0,1"
  . "  MSwitch_Switching_once:0,1"
  . "  MSwitch_SysExtension:0,1,2 "
  . "  MSwitch_lastState:textField-long"
  . "  useSetExtensions:0,1"
  . $readingFnAttributes;
 
#################
my %sets;
my %setsnotify = (
    "timer"                => "on,off",
    "writelog"             => "",
    "reset_Switching_once" => "",
    "loadHTTP"             => "",
    "reset_device"         => "noArg",
    "active"               => "noArg",
    "inactive"             => "noArg",
    "del_function_data"    => "noArg",
    "del_history_data"     => "noArg",
    "del_delays"           => "",
    "backup_MSwitch"       => "noArg",
    "fakeevent"            => "noArg",
    "exec_cmd_1"           => "",
    "exec_cmd_2"           => "",
    "wait"                 => "",
    "reload_timer"         => "noArg",
    "del_repeats"          => "noArg",
    "change_renamed"       => "",
    "reset_cmd_count"      => "",
	"reload_Assoziations"      => "noArg",
    "reset_status_counter" => "noArg"
);


my %setstoggle = (
    "timer"                => "on,off",
    "writelog"             => "",
    "reset_Switching_once" => "",
    "reset_device"         => "noArg",
    "active"               => "noArg",
    "inactive"             => "noArg",
    "del_function_data"    => "noArg",
    "del_delays"           => "",
    "backup_MSwitch"       => "noArg",
    "fakeevent"            => "noArg",
    "wait"                 => "",
    "reload_timer"         => "noArg",
    "del_repeats"          => "noArg",
    "change_renamed"       => "",
    "on"                   => "noArg",
    "off"                  => "noArg",
	"reload_Assoziations"      => "noArg",
    "reset_status_counter" => "noArg"
);

my %setsfull = (
    "timer"                => "on,off",
    "writelog"             => "",
    "reset_Switching_once" => "",
    "reset_device"         => "noArg",
    "active"               => "noArg",
    "inactive"             => "noArg",
    "del_function_data"    => "noArg",
    "del_delays"           => "",
    "backup_MSwitch"       => "noArg",
    "fakeevent"            => "noArg",
    "wait"                 => "",
    "reload_timer"         => "noArg",
    "del_repeats"          => "noArg",
    "change_renamed"       => "",
    "on"                   => "noArg",
    "off"                  => "noArg",
	"toggle"               => "noArg",
    "reset_status_counter" => "noArg",
    "loadHTTP"             => "",
    "del_history_data"     => "noArg",
    "exec_cmd_1"           => "",
    "exec_cmd_2"           => "",
	"reload_Assoziations"      => "noArg",
    "reset_cmd_count"      => ""
);

my %setsdummywithst = (
    "timer"                => "on,off",
    "writelog"             => "",
    "reset_Switching_once" => "",
    "reset_device"         => "noArg",
    "del_delays"           => "",
    "backup_MSwitch"       => "noArg",
    "wait"                 => "",
    "del_repeats"          => "noArg",
    "reset_status_counter" => "noArg",
    "loadHTTP"             => "",
    "exec_cmd_1"           => "",
	"reload_Assoziations"      => "noArg",
    "exec_cmd_2"           => ""
);

my %setsdummywithoutst = (
    "reset_device"         => "noArg",
    "backup_MSwitch"       => "noArg",
    "reset_status_counter" => "noArg",
	"reload_Assoziations"      => "",
	"wait"                 => "",
);

my %gets = (
    "active_timer"         => "noArg",
    "restore_MSwitch_Data" => "noArg",
    "Eventlog"             => "sequenzformated,timeline,clear",
    "deletesinglelog"      => "noArg",
	"reload_Assoziations"      => "noArg",
    "config"               => "noArg"
);


####################

sub MSwitch_Initialize($) {
    my ($hash) = @_;
    $hash->{SetFn}                   = "MSwitch_Set";
    $hash->{AsyncOutputFn}           = "MSwitch_AsyncOutput";
    $hash->{RenameFn}                = "MSwitch_Rename";
    $hash->{CopyFn}                  = "MSwitch_Copy";
    $hash->{GetFn}                   = "MSwitch_Get";
    $hash->{DefFn}                   = "MSwitch_Define";
    $hash->{UndefFn}                 = "MSwitch_Undef";
    $hash->{DeleteFn}                = "MSwitch_Delete";
    $hash->{ParseFn}                 = "MSwitch_Parse";
    $hash->{AttrFn}                  = "MSwitch_Attr";
    $hash->{NotifyFn}                = "MSwitch_Notify";
    $hash->{FW_detailFn}             = "MSwitch_fhemwebFn";
    $hash->{ShutdownFn}              = "MSwitch_Shutdown";
    $hash->{FW_deviceOverview}       = 1;
    $hash->{FW_addDetailToSummary}   = 1;
    $hash->{FW_summaryFn}            = "MSwitch_summary";
    $hash->{NotifyOrderPrefix}       = "50-";
    $hash->{DelayedShutdownFn}       = "MSwitch_delayed_Shutdown";
    $hash->{AttrList}                = $attrresetlist;
    $hash->{helper}{countdownstatus} = "inactive";
}
####################

sub MSwitch_defineWidgets($) {
    my ($hash) = @_;
    my $name = $hash->{NAME};
    delete $data{MSwitch}{$name}{activeWidgets};
    if ( AttrVal( $name, 'MSwitch_SysExtension', "0" ) eq "0" ) {
        return;
    }
   
   
  # my $testcode = ReadingsVal( $name, '.sysconf', 'undef' );
  
  
  my $val = ReadingsVal( $name, '.sysconf', '' );
  
  my $testcode = MSwitch_Asc($val);

  if ( $testcode eq "undef" ) {
        return;
    }
    $testcode =~ s/#\[dp\]/:/g;
    foreach my $a ( keys %{ $data{MSwitch}{Widget} } ) {
        $data{MSwitch}{$name}{activeWidgets}{$a} = "on";
    }
    return;
}

#####################
sub MSwitch_Rename($) {

    my ( $new_name, $old_name ) = @_;
    my $hash_new = $defs{$new_name};
    my $hashold  = $defs{$new_name}{$old_name};
    RemoveInternalTimer($hashold);
    my $inhalt = $hashold->{helper}{repeats};
    foreach my $a ( sort keys %{$inhalt} ) {
        my $key = $hashold->{helper}{repeats}{$a};
        RemoveInternalTimer($key);
    }
    delete( $hashold->{helper}{repeats} );
    RemoveInternalTimer($hash_new);
    my $inhalt1 = $hash_new->{helper}{repeats};
    foreach my $a ( sort keys %{$inhalt1} ) {
        my $key = $hash_new->{helper}{repeats}{$a};
        RemoveInternalTimer($key);
    }
    delete( $hash_new->{helper}{repeats} );
    delete( $modules{MSwitch}{defptr}{$old_name} );
    $modules{MSwitch}{defptr}{$new_name} = $hash_new;
    return;
}

#####################################
sub MSwitch_delayed_Shutdown($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
    my $timecond;
    my $typ = ReadingsVal( $Name, '.msconfig', '0' );
    if ( $typ eq "0" ) {
        return;
    }
    if ( $typ eq "1" ) {
        $timecond = gettimeofday() + 3;
        InternalTimer( $timecond, "MSwitch_FullBackup_save", $hash );
        return 10;
    }
    return;
}

#####################################

sub MSwitch_Shutdown_HEX($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
    my $hex = MSwitch_backup_this( $hash, 'cleanup' );
    $hash->{DEF} = 'HEX ' . $hex;
    MSwitch_LOG( $Name, 1, "final Cleanup for $Name" );
    if ( AttrVal( 'global', 'autosave', '1' ) eq "1" ) {
        delete( $hash->{READINGS} );
    }
    else {
        $hash->{MSwitch_Init} = 'fhem.save';
        MSwitch_LOG( $Name, 1, "Autosave off, device $Name hold Data to fhem.save" );
    }
    return;
}

#####################################
sub MSwitch_Shutdown_end($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
    CancelDelayedShutdown($Name);
    return;
}

#####################################
sub MSwitch_Shutdown($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};

    if ( $anzahlmswitch == 0 ) {
        @msw           = devspec2array("TYPE=MSwitch");
        $anzahlmswitch = @msw;
    }
    $shutdowned++;

    my $showevents = AttrVal( $Name, "MSwitch_generate_Events", 0 );
    if ( AttrVal( $Name, 'MSwitch_Debug', '0' ) ne "0" ) { $showevents = 1 }

    # speichern gesetzter delays
    my $delays = $hash->{helper}{delays};
    my $x      = 1;
    my $seq;
    foreach my $seq ( keys %{$delays} ) {
		
		my $showevents = MSwitch_checkselectedevent( $hash, "SaveDelay_$x" );
        readingsSingleUpdate( $hash, "SaveDelay_$x", $seq, $showevents );
        $x++;
    }
    delete $data{MSwitch}{devicecmds1};
    delete $data{MSwitch}{last_devicecmd_save};

    if ( $hash->{MSwitch_Init} eq 'fhem.cfg' ) {
        MSwitch_Shutdown_HEX($hash);
        $foundcfgs++;
    }

    if ( $shutdowned == $anzahlmswitch && $foundcfgs > 0 ) {
        if ( AttrVal( 'global', 'autosave', '1' ) eq "1" ) {
            fhem("save");
        }
    }
    return "wait";
}
#####################################
sub MSwitch_Copy ($) {
    my ( $old_name, $new_name ) = @_;
    my $hash        = $defs{$new_name};
    my $oldhash     = $defs{$old_name};
    my $testreading = $oldhash->{READINGS};
    my @areadings   = ( keys %{$testreading} );
    my $cs          = "attr $new_name disable 1";
    my $errors      = AnalyzeCommandChain( undef, $cs );
    if ( defined($errors) ) {
         MSwitch_LOG( $new_name, 0, "ERROR $cs" );
    }
    foreach my $key (@areadings) {
        my $tmp = ReadingsVal( $old_name, $key, 'undef' );
		MSwitch_LOG( $new_name, 3, "Copy-cmd setreading " . $new_name . " " . $key . " " . $tmp );
        fhem( "setreading " . $new_name . " " . $key . " " . $tmp );
    }
    MSwitch_LoadHelper($hash);
    return;
}

#####################
sub MSwitch_summary_info($) {
    my ($hash) = @_;
    my $Name   = $hash->{NAME};
    my $ret    = "<br>test $FW_room";
    return $ret;
}

####################
sub MSwitch_summary($) {
    my ( $wname, $name, $room, $test1 ) = @_;
    my $hash     = $defs{$name};
    my $testroom = "undef";
    if ( $configdevice ne "" && $configdevice ne "undef" ) {
        $testroom = ReadingsVal( $configdevice, 'MSwitch_inforoom', 'undef' );
    }
    else {
        my @found_devices = devspec2array("TYPE=MSwitch:FILTER=.msconfig=1");
        if ( @found_devices > 0 ) {
            $testroom =
              ReadingsVal( $found_devices[0], 'MSwitch_inforoom', 'undef' );
        }
        else {
            $configdevice = "undef";
        }
    }

    my $mode = AttrVal( $name, 'MSwitch_Mode', 'Notify' );
    if ( exists $hash->{helper}{mode} && $hash->{helper}{mode} eq "absorb" ) {
        return "Device ist im Konfigurationsmodus.";
    }

    my @areadings = ( keys %{$test1} );
    if ( !grep /group/, @areadings ) {
        $data{MSwitch}{$name}{Ansicht} = "detail";
        return;
    }

    $data{MSwitch}{$name}{Ansicht} = "room";
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
    my $devtime1     = ReadingsVal( $name, '.Trigger_time_1', '' );
    my $devtime2     = ReadingsVal( $name, '.Trigger_time_2', '' );
    my $devtime3     = ReadingsVal( $name, '.Trigger_time_3', '' );
    my $devtime4     = ReadingsVal( $name, '.Trigger_time_4', '' );
    $optiontime .= "<option value=\"Time:\">At: aktiv</option>";

    if ( $mode ne "Notify" ) {
        $optiontime .= "<option value=\"$devtime1\">" . $devtime1 . "</option>"
          if $devtime1 ne 'undef' and $devtime1 ne "";
        $optiontime .= "<option value=\"$devtime2\">" . $devtime2 . "</option>"
          if $devtime2 ne 'undef' and $devtime2 ne "";
    }

    $optiontime .= "<option value=\"$devtime3\">" . $devtime3 . "</option>"
      if $devtime3 ne 'undef' and $devtime3 ne "";
    $optiontime .= "<option value=\"$devtime4\">" . $devtime4 . "</option>"
      if $devtime4 ne 'undef' and $devtime4 ne "";

    my $affectedtime = '';
    if (    $devtime4 eq ''
        and $devtime3 eq ''
        and $devtime2 eq ''
        and $devtime1 eq '' )
    {
        $timer = 0;
        $affectedtime =
            "<select style='width: 12em;' title=\""
          . $devtitletime
          . "\" disabled ><option value=\"Time:\">At: inaktiv</option></select>";
    }
    else {
        chop($devtitletime);
        chop($devtitletime);
        $affectedtime =
            "<select style='width: 12em;' title=\""
          . $devtitletime . "\" >"
          . $optiontime
          . "</select>";
    }

    if ( $info eq 'No Info saved at ATTR omment' ) {
        $ret .=
            "<input disabled title=\""
          . $info
          . "\" name='info' type='button'  value='Info' onclick =\"FW_okDialog('"
          . $info . "')\">";
    }
    else {
        $ret .=
            "<input title=\""
          . $info
          . "\" name='info' type='button'  value='Info' onclick =\"FW_okDialog('"
          . $info . "')\">";
    }

    $ret .= " <input disabled name='Text1' size='10' type='text' value='Mode: "
      . $mode . "'> ";

    if ( $trigger eq 'no_trigger' || $trigger eq 'undef' || $trigger eq '' ) {
        $triggerc = 0;
        if ( $triggerc != 0 || $timer != 0 ) {
            $ret .=
"<select style='width: 18em;' title=\"\" disabled ><option value=\"Trigger:\">Trigger: inaktiv</option></select>";
        }
        else {
            if ( $mode ne "Dummy" ) {
                $affectedtime = "";
                $ret .=
                  "&nbsp;&nbsp;Multiswitchmode (no trigger / no timer)&nbsp;";
            }
            else {
                $affectedtime = "";
                $affected     = "";
                $ret .= "&nbsp;&nbsp;Dummymode&nbsp;";
            }
        }
    }
    else {
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
    else {
        if ( AttrVal( $name, 'disable', "0" ) eq '1' ) {
            $ret .= "
		</td><td informId=\"" . $name . "tmp\">State: 
		</td><td informId=\"" . $name . "tmp\">
		<div class=\"dval\" informid=\"" . $name . "-state\"></div>
		</td><td informId=\"" . $name . "tmp\">
		<div informid=\"" . $name . "-state-ts\">disabled</div>";
        }
        else {
            $ret .= "
		</td><td informId=\"" . $name . "tmp\">
		State: </td><td informId=\"" . $name . "tmp\">
		<div class=\"dval\" informid=\""
              . $name
              . "-state\">"
              . ReadingsVal( $name, 'state', '' ) . "</div>
		</td><td informId=\"" . $name . "tmp\">";
            if ( $mode ne "Notify" ) {
                $ret .=
                    "<div informid=\""
                  . $name
                  . "-state-ts\">"
                  . ReadingsTimestamp( $name, 'state', '' )
                  . "</div>";
            }
            else {
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

    if ( exists $data{MSwitch}{runningbackup}
        && $data{MSwitch}{runningbackup} eq "ja" )
    {
        return;
    }

    my $oldtrigger = ReadingsVal( $Name, '.Trigger_device', 'undef' );
    MSwitch_LOG( $Name, 6,"->$Name OLDTRIGGER - $oldtrigger " . __LINE__ );	
    if ( $oldtrigger ne 'undef' ) {
        $hash->{NOTIFYDEV} = $oldtrigger;
        readingsSingleUpdate( $hash, ".Trigger_device", $oldtrigger, 0 );
    }

    my $bridge = ReadingsVal( $Name, '.Distributor', 'undef' );
    if ( $bridge ne "undef" ) {
        my @test = split( /\n/, $bridge );
        foreach my $testdevices (@test) {
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

    if ( exists $data{MSwitch}{runningbackup}
        && $data{MSwitch}{runningbackup} eq "ja" )
    {
        return;
    }

    my $oldtrigger = ReadingsVal( $Name, '.Trigger_device', 'undef' );
    my $devhash    = undef;
    my $cdev       = '';
    my $ctrigg     = '';

    if ( $hash->{MSwitch_Init} eq "def" ) {
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
        else {
            $ctrigg = '';
        }
        if ( defined $devhash ) {
            $hash->{NOTIFYDEV} = $cdev; # stand auf global ... änderung auf ...
            if ( defined $cdev && $cdev ne '' ) {
                readingsSingleUpdate( $hash, ".Trigger_device", $cdev, 0 );
            }
        }
        else {
            $hash->{NOTIFYDEV} = 'no_trigger';
            readingsSingleUpdate( $hash, ".Trigger_device", 'no_trigger', 0 );
        }
    }


    if (   !defined $hash->{NOTIFYDEV}
        || $hash->{NOTIFYDEV} eq 'undef'
        || $hash->{NOTIFYDEV} eq '' )
    {
        $hash->{NOTIFYDEV} = 'no_trigger';
    }

    if ( $oldtrigger ne 'undef' ) {

        MSwitch_LOG( $Name, 6,"->$Name oldtrigger $oldtrigger  " . __LINE__ );	

        $hash->{NOTIFYDEV} = $oldtrigger;
        readingsSingleUpdate( $hash, ".Trigger_device", $oldtrigger, 0 );
    }
################
    MSwitch_set_dev($hash);
################
    if ( AttrVal( $Name, 'MSwitch_Activate_MSwitchcmds', "0" ) eq '1' ) {
        addToAttrList('MSwitchcmd');
    }

    if ( ReadingsVal( $Name, '.First_init', 'undef' ) ne 'done' ) {
        $hash->{helper}{config} = "no_config";
        readingsBeginUpdate($hash);
        readingsBulkUpdate( $hash, ".V_Check", $vupdate );
        if ( defined $ctrigg && $ctrigg ne '' ) {	
            readingsBulkUpdate( $hash, ".Device_Events", $ctrigg );
            $hash->{DEF} = $cdev;
        }
        else {
            readingsBulkUpdate( $hash, ".Device_Events", 'no_trigger' );
        }
        readingsBulkUpdate( $hash, ".Trigger_on",      'no_trigger' );
        readingsBulkUpdate( $hash, ".Trigger_off",     'no_trigger' );
        readingsBulkUpdate( $hash, ".Trigger_cmd_on",  'no_trigger' );
        readingsBulkUpdate( $hash, ".Trigger_cmd_off", 'no_trigger' );
        readingsBulkUpdate( $hash, ".Trigger_log",     'off' );
        readingsBulkUpdate( $hash, ".Device_Affected", 'no_device' );
        readingsBulkUpdate( $hash, ".Trigger_device",  'no_device' );
        readingsBulkUpdate( $hash, ".First_init",      'done' );
        readingsBulkUpdate( $hash, ".V_Check",         $vupdate );
        readingsEndUpdate( $hash, 0 );
        $hash->{NOTIFYDEV} = 'no_trigger';

        # setze ignoreliste
        $attr{$Name}{MSwitch_Ignore_Types} = join( " ", @doignore );
        setDevAttrList( $Name, $attrresetlist );
    }

################ erste initialisierung eines devices

    if ( ReadingsVal( $Name, '.V_Check', 'undef' ) ne $vupdate
        && $autoupdate eq "on" )
    {
        MSwitch_VersionUpdate($hash);
    }
################

    if ( ReadingsVal( $Name, '.Trigger_on', 'undef' ) eq 'undef' ) {
        readingsBeginUpdate($hash);
        readingsBulkUpdate( $hash, ".Device_Events",   'no_trigger' );
        readingsBulkUpdate( $hash, ".Trigger_on",      'no_trigger' );
        readingsBulkUpdate( $hash, ".Trigger_off",     'no_trigger' );
        readingsBulkUpdate( $hash, ".Trigger_log",     'on' );
        readingsBulkUpdate( $hash, ".Device_Affected", 'no_device' );
        readingsEndUpdate( $hash, 0 );
    }

    MSwitch_defineWidgets($hash);    #Neustart aller genutzten widgets
    MSwitch_Createtimer($hash);      #Neustart aller timer

    #### savedelays einlesen
    my $counter = 1;
    while ( ReadingsVal( $Name, 'SaveDelay_' . $counter, 'undef' ) ne "undef" )
    {
        my $del = ReadingsVal( $Name, 'SaveDelay_' . $counter, 'undef' );
        my @msgarray = split( /#\[tr\]/, $del );
        my $timecond = $msgarray[4];
        if ( $timecond > time ) {
            $hash->{helper}{delays}{$del} = $timecond;
            InternalTimer( $timecond, "MSwitch_Restartcmd", $del );
        }
        $counter++;
    }
    fhem("deletereading $Name SaveDelay_.*");

    # eventtoid einlesen
    delete( $hash->{helper}{eventtoid} );
    my $bridge = ReadingsVal( $Name, '.Distributor', 'undef' );

    if ( $bridge ne "undef" ) {
        my @test = split( /\n/, $bridge );
        foreach my $testdevices (@test) {
            my ( $key, $val ) = split( /=>/, $testdevices );
            $hash->{helper}{eventtoid}{$key} = $val;
        }
    }

    my $testnot = $hash->{NOTIFYDEV};
    if ( defined $testnot && length $testnot < 1 ) {
        $hash->{NOTIFYDEV} = 'no_trigger';
    }

    if ( ReadingsVal( $Name, '.Trigger_devic', 'undef' ) eq "all_events" ) {
        delete( $hash->{NOTIFYDEV} );
    }

    if ( AttrVal( $Name, 'MSwitch_Mode', "" ) eq 'Dummy' ) {
        $hash->{NOTIFYDEV} = 'no_trigger';
    }
	
	my @found_devices = devspec2array("TYPE=MSwitch:FILTER=.msconfig=1");
       
        if ( @found_devices > 0)
		{
		$hash->{MSwitch_Configdevice} = 'installed';
		
		
		
		if ( ReadingsVal( $found_devices[0], 'MSwitch_Experimental', 'off' ) eq "on" )
		{
		
		$hash->{MSwitch_Experimental_mode} = 'on';
		}
		else{
			$hash->{MSwitch_Experimental_mode} = 'off';
		}
		
		
		
		}
	 else
		{
			 $hash->{MSwitch_Configdevice} = 'not installed';
			 $hash->{MSwitch_Experimental_mode} = 'off';
		}
    return;
}

####################

sub MSwitch_DefineHEX($$$) {

    my ( $hash, $arg, $name ) = @_;
    $data{MSwitch}{$name}{backupdatei} = $arg;
    MSwitch_restore_this( $hash, 'configfile' );
    #$hash->{DEF} = '# no_device';
    MSwitch_check_init($hash);
    readingsDelete( $hash, '.Trigger_log' );
	my $showevents = MSwitch_checkselectedevent( $hash, "waiting" );
    readingsSingleUpdate( $hash, "waiting", ( time + 10 ), $showevents );
    MSwitch_defineWidgets($hash);    #Neustart aller genutzten widgets
    MSwitch_Createtimer($hash);      #Neustart aller timer
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
    my $template   = "no";
    my $defstring  = '';
    foreach (@a) {
        next if $_ eq $a[0];
        next if $_ eq $a[1];
        $defstring = $defstring . $_ . " ";
    }

    if ( $a[3] ) {
        $template = $a[3];
    }

    $modules{MSwitch}{defptr}{$devpointer} = $hash;
	$hash->{MSwitch_Modulversion}         = $version;
    $hash->{MSwitch_Datenstruktur} = $vupdate;
    $hash->{MSwitch_Autoupdate}    = $autoupdate;
    $hash->{MODEL}                         = $startmode . " " . $version;
    $hash->{MSwitch_Init}                          = 'fhem.save';
	
    if ( $defstring =~ m/HEX.*/ ) {
        $hash->{MSwitch_Init} = 'fhem.cfg';
        MSwitch_DefineHEX( $hash, $template, $name );
        $attr{$name}{MSwitch_INIT} = 'cfg';
        return;
    }

    if ( $defstring =~ m/wizard.*/ ) {
        $hash->{helper}{mode}      = 'absorb';
        $hash->{helper}{modesince} = time;
        $hash->{helper}{template}  = $template;
    }

    if ( $init_done && !defined( $hash->{OLDDEF} ) ) {
        my @found_devices = devspec2array("TYPE=MSwitch:FILTER=.msconfig=1");
        ##############
        if (
               @found_devices > 0
            && $defs{ $found_devices[0] }
            && ReadingsVal( $found_devices[0], 'status',
                'settings_nicht_anwenden' ) eq 'settings_anwenden'
          )
        {
            my $confighash = $defs{ $found_devices[0] };
            my $configtype = $confighash->{TYPE};
            if ( $configtype eq "MSwitch" ) {
                my $testreading = $confighash->{READINGS};
                my @areadings   = ( keys %{$testreading} );
                foreach my $key (@areadings) {
                    next
                      if ( $key !~m/(^MSwitch_.*|stateFormat|devStateIcon|icon|room|disable)/);
                    next
                      if ReadingsVal( $found_devices[0], $key, 'undef' ) eq "";
                    my $aktset =
                      ReadingsVal( $found_devices[0], $key, 'undef' );

                    $aktset =~ s/\\\{/{/;
                    $aktset =~ s/\\\}/}/;
                    $attr{$name}{$key} = "$aktset";
                }
            }
        }
        else {
            #setze alle attrs
            $attr{$name}{MSwitch_INIT}                = 'save';
            $attr{$name}{MSwitch_Eventhistory}        = '0';
            $attr{$name}{MSwitch_Safemode}            = $startsafemode;
            $attr{$name}{MSwitch_Help}                = '0';
            $attr{$name}{MSwitch_Debug}               = '0';
            $attr{$name}{MSwitch_Expert}              = '0';
            $attr{$name}{MSwitch_Delete_Delays}       = '1';
            $attr{$name}{MSwitch_Include_Devicecmds}  = '1';
            $attr{$name}{MSwitch_Include_Webcmds}     = '0';
            $attr{$name}{MSwitch_Include_MSwitchcmds} = '0';
            $attr{$name}{MSwitch_Include_MSwitchcmds} = '0';
            $attr{$name}{MSwitch_Extensions}          = '0';
            $attr{$name}{MSwitch_Mode}                = $startmode;
            $attr{$name}{MSwitch_generate_Events} = $MSwitch_generate_Events;
            fhem("attr $name room MSwitch_Devices");
        }
        my $timecond = gettimeofday() + 5;
        InternalTimer( $timecond, "MSwitch_check_init", $hash );
    }
    else {
    }
    return;
}

####################
sub MSwitch_Make_Undo($) {
    my ($hash) = @_;
    my @found_devices = devspec2array("TYPE=MSwitch:FILTER=.msconfig=1");
    if ( @found_devices > 0 ) {
        return
          if (
            ReadingsVal( $found_devices[0], 'MSwitch_Undo', 'off' ) eq "off" );
    }
    else {
        return;
    }

    my $lastversion = MSwitch_backup_this( $hash, 'undo' );
    $data{MSwitch}{$hash}{undo}     = $lastversion;
    $data{MSwitch}{$hash}{undotime} = time;
    return;
}




####################
sub MSwitch_Make_Experimental($) {
    my ($hash) = @_;
	
	my @found_devices = devspec2array("TYPE=MSwitch:FILTER=.msconfig=1");
    if ( @found_devices > 0 ) 
	{
        return if ( ReadingsVal( $found_devices[0], 'MSwitch_Experimental', 'off' ) eq "off" );
    }
    else 
	{
        return;
    }
	
	MSwitch_backup_this( $hash, 'experimental' );
	
	
	
    return;
}


#####################################
sub MSwitch_Get($$@) {
    my ( $hash, $name, $opt, @args ) = @_;
    my $ret;
    if ( ReadingsVal( $name, '.change', '' ) ne '' ) {
        return "Unknown argument, choose one of ";
    }
    return "\"get $name\" needs at least one argument" unless ( defined($opt) );

#####################################
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
    my $EXECUTEDCMD;
    my $WARNINGS;
    my $WARNINGSOUT;

    if (
        AttrVal(
            $name, 'MSwitch_Language',
            AttrVal( 'global', 'language', 'EN' )
        ) eq "DE"
      )
    {
        $KLAMMERFEHLER =
"Fehler in der Klammersetzung, die Anzahl öffnender und schliessender Klammern stimmt nicht überein.";
        $CONDTRUE     = "Bedingung ist Wahr und wird ausgeführt";
        $CONDTRUE1    = "Bedingung ist nicht Wahr und wird nicht ausgeführt";
        $KLARZEITEN   = "If Anweisung Perl Klarzeiten:";
        $READINGSTATE = "Status der geprüften Readings:";
        $NOREADING    = "Reading nicht vorhanden !";
        $INHALT       = "Inhalt:";
        $INCOMMINGSTRING = "eingehender String:";
        $STATEMENTPERL   = "If Anweisung Perl:";
        $SYNTAXERROR     = "Syntaxfehler:";
        $DELAYDELETE =
"INFO: Alle anstehenden Timer wurden neu berechnet, alle Delays wurden gelöscht";
        $NOTIMER     = "Timer werden nicht ausgeführt";
        $SYSTEMZEIT  = "Systemzeit:";
        $SCHALTZEIT  = "Schaltzeiten (at - kommandos)";
        $EXECUTEDCMD = "ausgeführter Befehl";
        $WARNINGS    = "gemeldete Fehler";
        $WARNINGSOUT = "keine";
    }
    else {
        $KLAMMERFEHLER =
"Error in brace replacement, number of opening and closing parentheses does not match.";
        $CONDTRUE        = "Condition is true and is executed</green>";
        $CONDTRUE1       = "Condition is not true and will not be executed";
        $KLARZEITEN      = "If statement Perl clears:";
        $READINGSTATE    = "States of the checked readings:";
        $NOREADING       = "Reading not available!";
        $INHALT          = "content:";
        $INCOMMINGSTRING = "Incomming String:";
        $STATEMENTPERL   = "If statement Perl:";
        $SYNTAXERROR     = "Syntaxerror:";
        $DELAYDELETE =
"INFO: All pending timers have been recalculated, all delays have been deleted";
        $NOTIMER     = "Timers are not running";
        $SYSTEMZEIT  = "system time:";
        $SCHALTZEIT  = "Switching times (at - commands)";
        $EXECUTEDCMD = "executed comand";
        $WARNINGS    = "errors";
        $WARNINGSOUT = "no errors";
    }

#################################################

    if ( $opt eq 'extcmd' ) 
	{
        my $typ            = $args[0];
        my $cs             = $args[1];
        my $incommingevent = $args[2];
        delete( $hash->{helper}{aktevent} );
        if ( $incommingevent ne "no_trigger" ) 
		{
            $hash->{helper}{aktevent} = $incommingevent;
        }

		my $typcmd;

        if ( $typ ne "FreeCmd" ) 
		{
            my $cs = $args[1];
            $cs =~ s/#\[sp\]/ /g;
            my $exec = "set " . $args[0] . " " . $cs;
            $exec = MSwitch_dec( $hash, $exec );
            my $errorout = "<small>$WARNINGS:<br>";
            my $errors = AnalyzeCommandChain( undef, $exec );
            if ( defined($errors) and $errors ne "OK" ) 
			{
                $errorout .= $errors;
            }
            else 
			{
                $errorout .= "$WARNINGSOUT";
            }
            delete( $hash->{helper}{aktevent} );
            return "<small>$EXECUTEDCMD:</small><br><br>$exec<br><br>$errorout";
        }
		
        else 
		{
            my $cs = $args[1];
	MSwitch_LOG( $name, 6,"----- CS> $cs " . __LINE__ );		

            if ( $cs =~ m/^(\{)(.*)(\})/s )
			{


	MSwitch_LOG( $name, 6,"PERLMODE" . __LINE__ );
                #perlmod
                $cs =~ s/#\[sp\]/ /g;
                $cs =~ s/#\[se\]/;/g;
                $cs =~ s/#\[nl\]//g;
				$cs =~ s/#\[pr\]/%/g;
                $cs = MSwitch_dec( $hash, $cs );
                $cs = MSwitch_makefreecmd( $hash, $cs );

                my $errorout = "<small>$WARNINGS:<br>";
                my $errors   = eval($cs);
                if ( defined($errors) and $errors ne "OK" ) {
                    $errorout .= $errors;
                }
                else {
                    $errorout .= "$WARNINGSOUT";
                }
                delete( $hash->{helper}{aktevent} );
                $cs =~ s/;/;<br>/g;
                $cs =~ s/^{/{<br>/g;
                $cs =~ s/}$/}<br>/g;
                return
                  "<small>$EXECUTEDCMD (Perlmode):</small><br><br>$cs<br><br>$errorout";
                return "ok";
            }
            else 
			{
                #fhemmode
				MSwitch_LOG( $name, 6,"FHEMMODE" . __LINE__ );
                $cs =~ s/#\[sp\]/ /g;
                $cs =~ s/#\[se\]/;/g;
                $cs =~ s/#\[nl\]//g;
				$cs =~ s/#\[pr\]/%/g;
                my $exec     = $cs;
                my $errorout = "<small>$WARNINGS:<br>";
				my $errors;
				my $newexec;	
					
			if ( AttrVal( $name, 'MSwitch_CMD_processing', $cmdprocessing ) eq "block" )
			{
				$typcmd= "MSwitch_CMD_processing -> block";
				$exec = MSwitch_dec( $hash, $cs );
                $errors = AnalyzeCommandChain( undef, $exec );
				$newexec.=$exec;
			}

				if ( AttrVal( $name, 'MSwitch_CMD_processing', $cmdprocessing ) eq "line" )
							{
								$typcmd= "MSwitch_CMD_processing -> line";
								my @lines = split( /;/, $exec );	
								 foreach my $einzelline (@lines) 
								 {
									$einzelline = MSwitch_dec( $hash, $einzelline );
									$errors.= AnalyzeCommandChain( undef, $einzelline );
									$newexec.=$einzelline.";";
								 }
							}

                if ( defined($errors) and $errors ne "OK" ) 
				{
                    $errorout .= $errors;
                }
                else {
                    $errorout .= "$WARNINGSOUT";
                }
                 delete( $hash->{helper}{aktevent} );
                $newexec =~ s/;/;<br>/g;
                $newexec =~ s/^{/{<br>/g;
                $newexec =~ s/}$/}<br>/g;
                return "<small>$EXECUTEDCMD (Fhemmode):<br>$typcmd</small><br><br>$newexec<br><br>$errorout";
            }
        }
        return;
    }
####################
    if ( $opt eq 'statistics' ) {
        my $return = MSwitch_Get_Statistik($hash);
        return $return;
    }

####################
    if ( $opt eq 'MSwitch_preconf' ) {
        MSwitch_setconfig( $hash, $args[0] );
        return
          "MSwitch_preconfig for $name has loaded.\nPlease refresh device.";
    }

####################
    if ( $opt eq 'Eventlog' ) {
        $ret = MSwitch_Eventlog( $hash, $args[0] );
        return $ret;
    }
####################

    if ( $opt eq 'restore_MSwitch_Data' ) {
        $ret = MSwitch_restore_this( $hash, "backupfile" );
        return $ret;
    }

####################



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
        $ret = MSwitch_Getconfig( $hash, $args[0] );
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

		$args[0]=MSwitch_Asc($args[0]);

        my ( $condstring, $eventstring ) = split( /\|/, $args[0] );

		$eventstring =~ s/#\[sp\]/ /g;
		$condstring =~ s/#\[sp\]/ /g;
		$condstring =~ s/\(DAYS\)/|/g;

        my @eventteile = split( /:/, $eventstring );

        if ( @eventteile == 2 ) {
            if ( !defined $eventteile[0] ) { $eventteile[0] = ""; }
            if ( !defined $eventteile[1] ) { $eventteile[1] = ""; }
            $hash->{helper}{evtparts}{parts}    = 3;
            $hash->{helper}{evtparts}{device}   = ".*";
            $hash->{helper}{evtparts}{evtpart1} = ".*";
            $hash->{helper}{evtparts}{evtpart2} = $eventteile[0];
            $hash->{helper}{evtparts}{evtpart3} = $eventteile[1];
            $hash->{helper}{evtparts}{evtfull}  = ".*:" . $eventstring;
            $hash->{helper}{evtparts}{event} =
              $eventteile[0] . ":" . $eventteile[1];
            $eventstring = $hash->{helper}{evtparts}{evtfull};
        }
        else {

            if ( !defined $eventteile[0] ) { $eventteile[0] = ""; }
            if ( !defined $eventteile[1] ) { $eventteile[1] = ""; }
            if ( !defined $eventteile[2] ) { $eventteile[2] = ""; }

            $hash->{helper}{evtparts}{parts}    = 3;
            $hash->{helper}{evtparts}{device}   = $eventteile[0];
            $hash->{helper}{evtparts}{evtpart1} = $eventteile[0];
            $hash->{helper}{evtparts}{evtpart2} = $eventteile[1];
            $hash->{helper}{evtparts}{evtpart3} = $eventteile[2];
            $hash->{helper}{evtparts}{evtfull}  = $eventstring;
            $hash->{helper}{evtparts}{event} =
              $eventteile[1] . ":" . $eventteile[2];
        }

        my $ret1 = MSwitch_checkcondition( $condstring, $name, $eventstring );
        my $condstring1 = $hash->{helper}{conditioncheck};
        my $condstring2 = $hash->{helper}{conditioncheck1};
        my $errorstring = $hash->{helper}{conditionerror};
        if ( !defined $errorstring ) { $errorstring = '' }

        $condstring1 =~ s/</\&lt\;/g;
        $condstring1 =~ s/>/\&gt\;/g;
        $condstring2 =~ s/</\&lt\;/g;
        $condstring2 =~ s/>/\&gt\;/g;
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
                $ret1 = "<div style=\"color: #2cc703\">" . $CONDTRUE . "</div>";
            }
            if ( $ret1 eq 'false' ) {
                $ret1 =
                  "<div style=\"color: #FF0000\">" . $CONDTRUE1 . "</div>";
            }
        }
        $condstring =~ s/~/ /g;
        my $condmarker = $condstring1;
        my $x          = 0;              # exit
        while ( $condmarker =~ m/(.*)(\d{10})(.*)/ ) {
            $x++;                        # exit
            last if $x > 20;             # exit
            my $timestamp = FmtDateTime($2);
            my ( $st1, $st2 ) = split( / /, $timestamp );
            $condmarker = $1 . $st2 . $3;
        }

        my $test  = $condstring1;
        my $test1 = $condstring2;
        $test =~ s/ //g;
        $test1 =~ s/ //g;

        $ret =
            $INCOMMINGSTRING
          . "<br><small>$condstring</small><br><br>"
          . $STATEMENTPERL
          . "<br><small>$condstring2";
        $ret .= "<br>$condstring1</small><br>" if $test ne $test1;
        $ret .= "</small><br>" if $test eq $test1;

        $ret .= "<br>";

        $ret .= $KLARZEITEN . "<br><small>$condmarker</small><br><br>"
          if $x > 0;
        $ret .= "<u>" . $ret1 . "</u>";
        my $condsplit = $condmarker;
        my $reads     = '<br><br>' . $READINGSTATE . '<br>';
        $x = 0;    # exit

### old

        while ( $condsplit =~
m/(.*)(ReadingsVal|ReadingsNum|ReadingsAge|AttrVal|InternalVal)(.*?\))(.*)/
          )
        {
            my $readname      = $2 . $3;
            my $readinginhalt = eval $readname;
            $condsplit = $1 . $4;
            $x++;    # exit
            last if $x > 20;
            $reads .=
                "<small>- "
              . $readname . " -> "
              . $readinginhalt
              . "</small><br>";
        }
        foreach my $key ( keys %{ $data{MSwitch}{$hash}{condition} } ) {
            $reads .=
              "<small>- $data{MSwitch}{$hash}{condition}{$key}</small><br>";
            $x++;
        }
        delete $data{MSwitch}{$hash}{condition};
        $ret .= $reads if $x > 0;

## anzeige funktionserkennung
        if ( defined $hash->{helper}{eventhistory}{DIFFERENCE} ) {
            $ret .= "<br>";
            $ret .= $hash->{helper}{eventhistory}{DIFFERENCE};
            $ret .= "<br>";
            delete( $hash->{helper}{eventhistory}{DIFFERENCE} );
        }

        if ( defined $hash->{helper}{eventhistory}{TENDENCY} ) {
            $ret .= "<br>";
            $ret .= $hash->{helper}{eventhistory}{TENDENCY};
            $ret .= "<br>";
            delete( $hash->{helper}{eventhistory}{TENDENCY} );
        }

        if ( defined $hash->{helper}{eventhistory}{AVERAGE} ) {
            $ret .= "<br>";
            $ret .= $hash->{helper}{eventhistory}{AVERAGE};
            $ret .= "<br>";
            delete( $hash->{helper}{eventhistory}{AVERAGE} );
        }

        if ( defined $hash->{helper}{eventhistory}{INCREASE} ) {
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
        my $inhalt = $data{MSwitch}{$name}{HTTPresponse};
        my $window =
            "<textarea cols='120' rows='30'>"
          . $data{MSwitch}{$name}{HTTPresponse}
          . "</textarea>";

        if (
            length($inhalt) < 1 )    # wenn ein Fehler bei der HTTP Abfrage aufgetreten ist
        {
            return "<html>Keine Daten vorhanden</html>";
        }
        return "<html><span style=\"font-size: medium\">" . $window
          . "<\/span></html>";
    }

    #################################################

    if ( $opt eq 'active_timer' && $args[0] eq 'delete' ) {
        MSwitch_Clear_timer($hash);
        MSwitch_Createtimer($hash);
        MSwitch_Delete_Delay( $hash, 'all' );
        $ret .= "<br>" . $DELAYDELETE . "<br>";
        return $ret;
    }

#################################################

    if ( $opt eq 'active_timer' && $args[0] eq 'show' ) {
        if ( defined $hash->{helper}{wrongtimespec}
            and $hash->{helper}{wrongtimespec} ne "" )
        {
            $ret = $hash->{helper}{wrongtimespec};
            $ret .= "<br>" . $NOTIMER . "<br>";
            return $ret;
        }

        if ( ReadingsVal( $name, 'timer', 'on' ) eq "off" ) {
            $ret .= "<br>Timersteuerung ist deaktiviert<br>";
            return $ret;
        }
        $ret .= "<div nowrap>" . $SYSTEMZEIT . " " . localtime() . "</div><hr>";
        $ret .= "<div nowrap>" . $SCHALTZEIT . "</div><hr>";

        #timer
        my $timehash = $hash->{helper}{timer};

        foreach my $a ( sort keys %{$timehash} ) {
            my @string  = split( /-/,  $hash->{helper}{timer}{$a} );
            my @string1 = split( /ID/, $string[1] );
            my $number  = $string1[0];
            my $id      = $string1[1];
            my $arg     = "noArg";

            if ( defined $string[2] ) {
                $arg = $string[2];
            }

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

            if ( $number eq '51' ) {
                $ret .=
                    "<div nowrap>"
                  . $time
                  . " nachberechnung der Schaltzeiten (holiday-einbindung)</div>";
            }

            if ( $number eq '52' ) {
                $ret .= "<div nowrap>" . $time . " Reset State Counter</div>";
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

            $ret .=
"<div nowrap>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Argument: $arg </div>";

        }

        if ( ReadingsVal( $name, 'timer', 'on' ) eq "off" ) {
            $ret .= "<div nowrap><br>Timer sind deaktiviert.</div>";
        }

        #delays
        $ret .= "<br>&nbsp;<br><div nowrap>aktive Delays:</div><hr>";
        $timehash = $hash->{helper}{delaydetails};

        foreach my $a ( sort keys %{$timehash} ) {
            my $time = FmtDateTime($a);
            my @timers = split( /#\[tr\]/, $a );
            $ret .= "<div nowrap><strong>Ausführungszeitpunkt:</strong> "
              . $time . "<br>";
            $ret .= "<strong>Indikator: </strong>"
              . $hash->{helper}{delaydetails}{$a}{Indikator} . "<br>";
            $ret .= "<strong>Name: </strong>"
              . $hash->{helper}{delaydetails}{$a}{name} . "<br>";
            $ret .= "<strong>auszuführender Befehl:</strong><br>"
              . $hash->{helper}{delaydetails}{$a}{cmd} . "<br>";
            $ret .= "</div><hr>";
        }

        if (  $ret ne "<div nowrap>"
            . $SCHALTZEIT
            . "</div><hr><div nowrap>aktive Delays:</div><hr>" )
        {
            return $ret;
        }
        return
"<span style=\"font-size: medium\">Keine aktiven Delays/Ats gefunden <\/span>";
    }

####
    my $statistic = "";
    my $typ = ReadingsVal( $name, '.msconfig', '0' );

    if ( AttrVal( $name, 'MSwitch_Statistic', "0" ) == 1 ) {
        $statistic = "statistics:noArg";
    }
#######
    my $extension = '';
    if ( AttrVal( $name, 'MSwitch_SysExtension', "0" ) =~ m/(1|2)/s ) {
        $extension = 'sysextension:noArg';
    }

### modulmode - no sets

    if ( AttrVal( $name, 'MSwitch_Modul_Mode', "0" ) eq '1' ) {
        return "Unknown argument $opt, choose one of config:noArg support_info:noArg active_timer:show sysextension:noArg $statistic";
    }

#######

    if ( AttrVal( $name, 'MSwitch_Mode', 'Notify' ) eq "Dummy" ) {
        if ( AttrVal( $name, "MSwitch_Selftrigger_always", 0 ) > 0 ) {
            return
"Unknown argument $opt, choose one of HTTPresponse:noArg Eventlog:timeline,clear config:noArg support_info:noArg restore_MSwitch_Data:noArg active_timer:show,delete $extension $statistic";
        }
        else {
            return
"Unknown argument $opt, choose one of support_info:noArg restore_MSwitch_Data:noArg $extension $statistic";
        }
    }

    if ( ReadingsVal( $name, '.lock', 'undef' ) ne "undef" ) {
        return
"Unknown argument $opt, choose one of HTTPresponse:noArg support_info:noArg active_timer:show,delete config:noArg restore_MSwitch_Data:noArg $statistic ";
    }
    else {
        return
"Unknown argument $opt, choose one of HTTPresponse:noArg Eventlog:sequenzformated,timeline,clear support_info:noArg config:noArg active_timer:show,delete restore_MSwitch_Data:noArg $extension $statistic";
    }
}

###########################################################

sub MSwitch_Get_Statistik($) {
    my ($hash) = @_;
    my $re = "";
    if ( !exists $hash->{helper}{statistics}{starttime} ) {
        return "noch keine Daten aufgezeichnet!";
    }

    if ( !exists $hash->{helper}{statistics} ) {
        return "noch keine Daten aufgezeichnet!";
    }

    my $starttime = $hash->{helper}{statistics}{starttime};
    my $akttime   = time;
    my $readtime  = $akttime - $starttime;
    my ( $Stunden, $Minuten, $Sekunden ) = (
        int( $readtime / 3600 ),
        int( ( $readtime % 3600 ) / 60 ),
        $readtime % 60
    );

    $Stunden  = sprintf( "%02d", $Stunden );
    $Minuten  = sprintf( "%02d", $Minuten );
    $Sekunden = sprintf( "%02d", $Sekunden );

    my $typeoption = "";
    my $inhalt     = $hash->{helper}{statistics}{notifyloop_incomming_types};
    my %sort;
    foreach my $a ( keys %{$inhalt} )

    {
        $sort{$a} = $hash->{helper}{statistics}{notifyloop_incomming_types}{$a};
    }
    foreach my $key ( reverse sort { $sort{$a} <=> $sort{$b} } keys %sort ) {
        $typeoption .=
            "<option value=\"\">"
          . $key
          . " - Zugriffe: "
          . $sort{$key}
          . "</option>";
    }

    my $typenames = "";
    $inhalt = $hash->{helper}{statistics}{notifyloop_incomming_names};
    my %sort1;
    foreach my $a ( keys %{$inhalt} )

    {
        $sort1{$a} =
          $hash->{helper}{statistics}{notifyloop_incomming_names}{$a};
    }
    foreach my $key ( reverse sort { $sort1{$a} <=> $sort1{$b} } keys %sort1 ) {
        $typenames .=
            "<option value=\"\">"
          . $key
          . " - Zugriffe: "
          . $sort1{$key}
          . "</option>";
    }

    my $unused = "";
    $inhalt = $hash->{helper}{statistics}{eventloop}{unused};
    my %sort2;
    foreach my $a ( keys %{$inhalt} )

    {
        $sort2{$a} = $hash->{helper}{statistics}{eventloop}{unused}{$a};
    }
    foreach my $key ( reverse sort { $sort2{$a} <=> $sort2{$b} } keys %sort2 ) {
        $unused .=
            "<option value=\"\">"
          . $key
          . " - Zugriffe: "
          . $sort2{$key}
          . "</option>";
    }

    $re .= "<table>";

    $re .= "<tr>";
    $re .=
        "<td colspan = \"3\">Aufzeichnungsbeginn: "
      . FmtDateTime($starttime)
      . "<\/td>";
    $re .= "<\/tr>";

    $re .= "<tr>";
    $re .= "<td colspan = \"3\">Messzeit: $Stunden:$Minuten:$Sekunden<\/td>";
    $re .= "<\/tr>";

    $re .= "<tr>";
    $re .= "<td colspan = \"3\"><hr><\/td>";
    $re .= "<\/tr>";

    $re .= "<tr>";
    $re .= "<td>{Notify_FN} gesamtanzahll eingehender Eventpakete:<\/td>";
    $re .= "<td>&nbsp;&nbsp;&nbsp;<\/td>";
    $re .=
      "<td> " . $hash->{helper}{statistics}{notifyloop_incomming} . "<\/td>";
    $re .= "</tr>";

    $re .= "<tr>";
    $re .= "<td>{Notify_FN} Systemprüfung - passiert:<\/td>";
    $re .= "<td>&nbsp;&nbsp;&nbsp;<\/td>";
    $re .= "<td> "
      . $hash->{helper}{statistics}{notifyloop_firsttest_passed}
      . "<\/td>";
    $re .= "<\/tr>";

    $re .= "<tr>";
    $re .= "<td>{Notify_FN} von Startdelay blockiert: <\/td>";
    $re .= "<td>&nbsp;&nbsp;&nbsp;<\/td>";
    $re .= "<td> "
      . $hash->{helper}{statistics}{notifyloop_startdelay_blocked}
      . "<\/td>";
    $re .= "</tr>";

    $re .= "<tr>";
    $re .= "<td>{Notify_FN} erste Minute nach Systemstart: <\/td>";
    $re .= "<td>&nbsp;&nbsp;&nbsp;<\/td>";
    $re .= "<td> "
      . $hash->{helper}{statistics}{notifyloop_incomming_firstminute}
      . "<\/td>";
    $re .= "</tr>";

    $re .= "<tr>";
    $re .= "<td>{Notify_FN} Safemode 2 aktiviert:<\/td>";
    $re .= "<td>&nbsp;&nbsp;&nbsp;<\/td>";
    $re .=
      "<td> " . $hash->{helper}{statistics}{safemode_2_blocking_on} . "<\/td>";
    $re .= "<\/tr>";

    $re .= "<tr>";
    $re .= "<td>{Notify_FN} von Wait blockiert:<\/td>";
    $re .= "<td>&nbsp;&nbsp;&nbsp;<\/td>";
    $re .=
      "<td> " . $hash->{helper}{statistics}{notifyloop_wait_blocked} . "<\/td>";
    $re .= "<\/tr>";

    $re .= "<tr>";
    $re .= "<td>{Notify_FN} eingehende Events TYPES :<\/td>";
    $re .= "<td>&nbsp;&nbsp;&nbsp;<\/td>";
    $re .=
      "<td><select style=\"disabled\" >" . $typeoption . "\/<select><\/td>";
    $re .= "<\/tr>";

    $re .= "<tr>";
    $re .= "<td>{Notify_FN} eingehende Events NAMES :<\/td>";
    $re .= "<td>&nbsp;&nbsp;&nbsp;<\/td>";
    $re .= "<td><select style=\"disabled\" >" . $typenames . "\/<select><\/td>";
    $re .= "<\/tr>";

    $re .= "<tr>";
    $re .= "<td>{Notify_FN} von GREP blockierte Eventpakete :<\/td>";
    $re .= "<td>&nbsp;&nbsp;&nbsp;<\/td>";
    $re .= "<td> "
      . $hash->{helper}{statistics}{notifyloop_blocked_from_grep}
      . "<\/td>";
    $re .= "<\/tr>";

    $re .= "<tr>";
    $re .=
      "<td>{Notify_FN} von GREP gefilterte Einzelvents aus Paketen :<\/td>";
    $re .= "<td>&nbsp;&nbsp;&nbsp;<\/td>";
    $re .= "<td> " . $hash->{helper}{statistics}{sortout_from_grep} . "<\/td>";
    $re .= "<\/tr>";

    $re .= "<tr>";
    $re .= "<td colspan = \"3\"><hr><\/td>";
    $re .= "<\/tr>";

    $re .= "<tr>";
    $re .= "<td>{Event_LOOP} ankommend: <\/td>";
    $re .= "<td>&nbsp;&nbsp;&nbsp;<\/td>";
    $re .=
      "<td> " . $hash->{helper}{statistics}{eventloop_incomming} . "<\/td>";
    $re .= "<\/tr>";

    $re .= "<tr>";
    $re .= "<td>{Event_LOOP} JasonFormat - blocked: <\/td>";
    $re .= "<td>&nbsp;&nbsp;&nbsp;<\/td>";
    $re .=
      "<td> " . $hash->{helper}{statistics}{eventloop_jason_blocked} . "<\/td>";
    $re .= "<\/tr>";

    $re .= "<tr>";
    $re .= "<td>{Event_LOOP} Auslösebedingung - passed: <\/td>";
    $re .= "<td>&nbsp;&nbsp;&nbsp;<\/td>";
    $re .= "<td> "
      . $hash->{helper}{statistics}{eventloop_firstcondition_passed}
      . "<\/td>";
    $re .= "<\/tr>";

    $re .= "<tr>";
    $re .= "<td>{Event_LOOP} Verteilt auf CMD1: <\/td>";
    $re .= "<td>&nbsp;&nbsp;&nbsp;<\/td>";
    $re .= "<td> " . $hash->{helper}{statistics}{eventloop_cmd1} . "<\/td>";
    $re .= "<\/tr>";

    $re .= "<tr>";
    $re .= "<td>{Event_LOOP} Verteilt auf CMD2: <\/td>";
    $re .= "<td>&nbsp;&nbsp;&nbsp;<\/td>";
    $re .= "<td> " . $hash->{helper}{statistics}{eventloop_cmd2} . "<\/td>";
    $re .= "<\/tr>";

    $re .= "<tr>";
    $re .= "<td>{Event_LOOP} Verteilt auf CMD3: <\/td>";
    $re .= "<td>&nbsp;&nbsp;&nbsp;<\/td>";
    $re .= "<td> " . $hash->{helper}{statistics}{eventloop_cmd3} . "<\/td>";
    $re .= "<\/tr>";

    $re .= "<tr>";
    $re .= "<td>{Event_LOOP} Verteilt auf CMD4: <\/td>";
    $re .= "<td>&nbsp;&nbsp;&nbsp;<\/td>";
    $re .= "<td> " . $hash->{helper}{statistics}{eventloop_cmd4} . "<\/td>";
    $re .= "<\/tr>";

    $re .= "<tr>";
    $re .= "<td>{Event_LOOP} Verteilt auf Bridge: <\/td>";
    $re .= "<td>&nbsp;&nbsp;&nbsp;<\/td>";
    $re .= "<td> " . $hash->{helper}{statistics}{eventloop_bridge} . "<\/td>";
    $re .= "<\/tr>";

    $re .= "<tr>";
    $re .= "<td>{Event_LOOP} nicht genutzt : <\/td>";
    $re .= "<td>&nbsp;&nbsp;&nbsp;<\/td>";
    $re .= "<td> " . $hash->{helper}{statistics}{eventignored} . "<\/td>";
    $re .= "<\/tr>";

    $re .= "<tr>";
    $re .= "<td>{Event_LOOP} ungenutzte Events :<\/td>";
    $re .= "<td>&nbsp;&nbsp;&nbsp;<\/td>";
    $re .= "<td><select style=\"disabled\" >" . $unused . "\/<select><\/td>";
    $re .= "<\/tr>";
    $re .= "<\/table>";
    return "<span style=\"font-size: medium\">" . $re . "<\/span>";
}

####################
sub MSwitch_AsyncOutput(@) {
    my ( $client_hash, $text ) = @_;
    asyncOutput( $client_hash, $text );
    return $text;
}

##################################
# schreibt log
sub MSwitch_Set_Writelog($@) {
    my ( $hash, $name, $cmd, @args ) = @_;
    my @logs = split( /\|/, $args[0] );
    shift @args;
    MSwitch_LOG($name,$logs[0],"@args");
    return;
}

# setze wizarddaten
sub MSwitch_Set_wizard($@) {
    my ( $hash, $name, $cmd, @args ) = @_;
    Log3( "test2", 5, "args: @args - " . @args );
    FW_directNotify( "FILTER=$name", "#FHEMWEB:WEB", "setargument('$args[0]')",
        "" );
    return;
}

sub MSwitch_Set_alert($@) {
    my ( $hash, $name, $cmd, @args ) = @_;
    my $client_hash = $hash->{CL};
    my $ret = asyncOutput( $hash->{CL}, "test " . $hash->{CL} . " test" );
    return;
}

# setze wizarddaten
sub MSwitch_Set_wizard1($@) {
    my ( $hash, $name, $cmd, @args ) = @_;
    FW_directNotify(
        "FILTER=$name",                        "#FHEMWEB:WEB",
        "setargument('$args[0]', '$args[1]')", ""
    );
    return;
}

##################################
#timer on/off
sub MSwitch_Set_timer($@) {
    my ( $hash, $name, $cmd, @args ) = @_;
	my $showevents = MSwitch_checkselectedevent( $hash, "timer" );
    readingsSingleUpdate( $hash, "timer", $args[0], $showevents );
    if ( $args[0] eq "on" ) {
        MSwitch_Clear_timer($hash);
        MSwitch_Createtimer($hash);
    }
    if ( $args[0] eq "off" ) {
        MSwitch_Clear_timer($hash);
    }
    return;
}

##################################

sub MSwitch_Set_ResetCmdCount($@) {
    my ( $hash, $name, $cmd, @args ) = @_;
	my $showevents;
    if ( $args[0] eq "1" ) {
		$showevents = MSwitch_checkselectedevent( $hash, "EVT_CMD1_COUNT" );
        readingsSingleUpdate( $hash, "EVT_CMD1_COUNT", 0, $showevents );
    }
    if ( $args[0] eq "2" ) {
		$showevents = MSwitch_checkselectedevent( $hash, "EVT_CMD2_COUNT" );
        readingsSingleUpdate( $hash, "EVT_CMD2_COUNT", 0, $showevents );
    }
    if ( $args[0] eq "all" ) {
		$showevents = MSwitch_checkselectedevent( $hash, "EVT_CMD1_COUNT" );
        readingsSingleUpdate( $hash, "EVT_CMD1_COUNT", 0, $showevents );
		$showevents = MSwitch_checkselectedevent( $hash, "EVT_CMD2_COUNT" );
        readingsSingleUpdate( $hash, "EVT_CMD2_COUNT", 0, $showevents );
    }
    return;
}

##################################

sub MSwitch_Set_ReloadTimer($@) {
    my ( $hash, $name, $cmd, @args ) = @_;
    MSwitch_Clear_timer($hash);
    MSwitch_Createtimer($hash);
    return;
}

##################################

sub MSwitch_Set_Wizard($@) {
    my ( $hash, $name, $cmd, @args ) = @_;
    $hash->{helper}{mode}      = 'absorb';
    $hash->{helper}{modesince} = time;
    return;
}

##################################

sub MSwitch_Set_Freesearch($@) {
    my ( $hash, $name, $cmd, @args ) = @_;
   
    my $searchstring      = $args[0];
	my $orgsearch = $args[0];
my @found_devices = devspec2array("TYPE=MSwitch:FILTER=.msconfig=1");

($searchstring) =~ s/(.|\n)/sprintf("%02lx ", ord $1)/eg;
$searchstring =~ s/ //g;

my $oldconf = MSwitch_backup_this( $hash, 'rename' );
my $result = "nothing found";
my $raw ="";
if ( $oldconf =~ m/$searchstring/ ) {

FW_directNotify(
					"FILTER=$found_devices[0]",
					"#FHEMWEB:WEB",
					"searchinformation('$name')",
					""
				);		
				
				
			 FW_directNotify(
            "FILTER=$found_devices[0]",
            "#FHEMWEB:WEB",
            "information('Suchtext gefunden im Device: $name ')",
            ""
        );		
				
	$raw = MSwitch_Asc($oldconf);
	my $backupdatei = $raw;
    my @found = split( /\n/, $backupdatei );
	
	foreach (@found) 
	{
		$raw= $_;
			
		if ( $raw =~ m/$orgsearch/ )
		{
			
			
				if ( $raw =~ m/#N -> (.*)/ )   
				{	
				$result = "found";
				#    #N -> Aussenlicht_manuell_1
				 FW_directNotify(
					"FILTER=$found_devices[0]",
					"#FHEMWEB:WEB",
					"information('   -> Suchtext im Namen gefunden: $1 ')",
					""
				);	
				next;
				}
						
				if ( $raw =~ m/#S .Trigger_device -> (.*)/ )   
				{	
				$result = "found";
				 FW_directNotify(
					"FILTER=$found_devices[0]",
					"#FHEMWEB:WEB",
					"information('   -> Suchtext im Trigger gefunden: $name ')",
					""
				);	
				next;
				}
				
				if ( $raw =~ m/#S .Device_Affected -> (.*)/ )   
				{	
				$result = "found";
				 FW_directNotify(
					"FILTER=$found_devices[0]",
					"#FHEMWEB:WEB",
					"information('   -> Suchtext in den CMDs gefunden ( Befehlsausführung ) ')",
					""
				);	
				next;
				}
				
				
				if ( $raw =~ m/#S .Device_Affected_Details_new -> (.*)/ )   
				{	
				$raw =~ s/$orgsearch-AbsCmd//g;
				
				if ( $raw =~ m/$orgsearch/ )
				{
					 $result = "found";
						  FW_directNotify(
							 "FILTER=$found_devices[0]",
							 "#FHEMWEB:WEB",
							 "information('   -> Suchtext in den Conditions gefunden ( Bedingungen ) ')",
							 ""
						 );	
						 next;
				}
	
				}
				

				if ( $raw =~ m/#A MSwitch_Device_Groups -> (.*)/ )   
				{	
				$result = "found";
				 FW_directNotify(
					"FILTER=$found_devices[0]",
					"#FHEMWEB:WEB",
					"information('   -> Suchtext in einer Gruppendefinition gefunden ')",
					""
				);	
				next;
				}
				
		next;
		}
	}
	
}

  if (( @found_devices > 0 ) && ($result eq "found" )){
         FW_directNotify(
             "FILTER=$found_devices[0]",
             "#FHEMWEB:WEB",
             "information('____________________________________________\\n')",
             ""
         );
     }

return ;

}


sub MSwitch_Set_ChangeRenamed($@) {
    my ( $hash, $name, $cmd, @args ) = @_;
    my $changestring = $args[0] . "#" . $args[1];
    my $oldname      = $args[0];
    my $newname      = $args[1];
	
	my @found_devices = devspec2array("TYPE=MSwitch:FILTER=.msconfig=1");
	
	return if $found_devices[0] eq $name;
	
    ($oldname) =~ s/(.|\n)/sprintf("%02lx ", ord $1)/eg;
    $oldname =~ s/ //g;
	
	
    ($newname) =~ s/(.|\n)/sprintf("%02lx ", ord $1)/eg;
    $newname =~ s/ //g;
	
    my $oldconf = MSwitch_backup_this( $hash, 'rename' );
    $oldconf =~ s/$oldname/$newname/g;
    $data{MSwitch}{$name}{backupdatei} = $oldconf;

    MSwitch_restore_this( $hash, 'configfile' );
	
   if ( @found_devices > 0 ) {
        FW_directNotify(
            "FILTER=$found_devices[0]",
            "#FHEMWEB:WEB",
            "information('Device $name angepasst')",
            ""
        );
    }
    return;
}

##################################

sub MSwitch_Set_ExecCmd($@) {
    my ( $hash, $name, $cmd, @args ) = @_;
    my $comand;
    my $execids = "0";
    $comand = "on"  if $cmd eq 'exec_cmd_1';
    $comand = "off" if $cmd eq 'exec_cmd_2';

    $data{MSwitch}{$name}{setdata}{last_cmd}    = "cmd_1" if $comand eq "on";
    $data{MSwitch}{$name}{setdata}{last_cmd}    = "cmd_2" if $comand eq "off";

    if ( !defined $args[0] ) { $args[0] = ""; }

    if ( $args[0] eq 'ID' ) {
        $execids = $args[1];
        $args[0] = 'ID';
    }
    if ( $args[0] eq "" ) {
         MSwitch_LOG( $name, 6,"### Aufruf SUB_Exec_Notif mit event : --- ". __LINE__ );
        MSwitch_Exec_Notif( $hash, $comand, 'nocheck', '', 0 );
        return;
    }
    if ( $args[0] ne 'ID' || $args[0] ne '' ) {
        if ( $args[1] !~ m/\d/ ) {
            return;
        }
    }

    # cmd1 abarbeiten
    MSwitch_LOG( $name, 6,"ausführung exec_cmd_1 $args[1] L:" . __LINE__ );
    MSwitch_LOG( $name, 6,"### Aufruf SUB_Exec_Notif mit event :---t ". __LINE__ );
    MSwitch_Exec_Notif( $hash, $comand, 'nocheck', '', $execids );
    return;
}

##################################

sub MSwitch_Set_AddEvent($@) {
    my ( $hash, $name, $cmd, @args ) = @_;
    MSwitch_Make_Undo($hash);
	MSwitch_Make_Experimental($hash);
    delete( $hash->{helper}{config} );

    # event manuell zufügen
    my $devName = ReadingsVal( $name, '.Trigger_device', '' );
    $args[0] =~ s/\[sp\]/ /g;
    my @newevents = split( /,/, $args[0] );
    if ( ReadingsVal( $name, '.Trigger_device', '' ) eq "all_events" ) {
        foreach (@newevents) {
            $hash->{helper}{events}{all_events}{$_} = "on";
        }
    }
    else {
        foreach (@newevents) {
            $hash->{helper}{events}{$devName}{$_} = "on";
        }
    }
    my $events    = '';
    my $eventhash = $hash->{helper}{events}{$devName};
    foreach my $name ( keys %{$eventhash} ) {
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
sub MSwitch_Set_DelRepeats($@) {
    my ( $hash, $name, $cmd, @args ) = @_;
    my $inhalt = $hash->{helper}{repeats};
    foreach my $a ( sort keys %{$inhalt} ) {
        my $key = $hash->{helper}{repeats}{$a};
        RemoveInternalTimer($key);
    }
    delete( $hash->{helper}{repeats} );
    return;
}

##################################
sub MSwitch_Set_DelDelays($@) {
    my ( $hash, $name, $cmd, @args ) = @_;
    if ( !defined $args[0] || $args[0] eq "" ) {
        MSwitch_Delete_Delay( $hash, $name );
    }
    else {
        MSwitch_Delete_specific_Delay( $hash, $name, $args[0] );
    }
    return;
}

##################################
sub MSwitch_Set_DelHistory($@) {
    my ( $hash, $name, $cmd, @args ) = @_;
    fhem("deletereading $name .*_h.*");
    delete( $hash->{helper}{eventhistory} );
    delete( $hash->{helper}{eventhistory} );
    return;
}

##################################
sub MSwitch_Set_switching_once($@) {
    my ( $hash, $name, $cmd, @args ) = @_;
    delete( $hash->{helper}{lastexecute} );
    return;
}
################################
#logging web.js
sub MSwitch_Set_loggingwebjs($@) {
    my ( $hash, @args ) = @_;
    if ( defined $args[0] && $args[0] eq "1" ) {
        $hash->{helper}{aktivelog} = "on";
    }
    else {
        delete( $hash->{helper}{aktivelog} );
    }
    return;
}

################################
sub MSwitch_Set_ResetDevice($@) {
    my ( $hash, $name, $cmd, @args ) = @_;
    if ( $args[0] eq 'checked' )
	{
        $hash->{helper}{config} = "no_config";
        my $testreading = $hash->{READINGS};
        delete $hash->{DEF};
		
        MSwitch_Delete_Delay( $hash, $name );
        my $inhalt = $hash->{helper}{repeats};

        foreach my $a ( sort keys %{$inhalt} ) {
            my $key = $hash->{helper}{repeats}{$a};
            RemoveInternalTimer($key);
        }

        delete( $hash->{helper}{repeats} );
        delete $data{MSwitch}{devicecmds1}{$name};
        delete $data{MSwitch}{last_devicecmd_save};
        delete( $hash->{helper}{eventhistory} );
       # delete( $hash->{MSwitch_IncommingHandle} );
        delete( $hash->{helper}{eventtoid} );
        delete( $hash->{helper}{savemodeblock} );
        delete( $hash->{helper}{sequenz} );
        delete( $hash->{helper}{history} );
        delete( $hash->{helper}{eventlog} );
        delete( $hash->{helper}{mode} );
        delete( $hash->{helper}{reset} );
        delete( $hash->{READINGS} );

        my %keys;
        foreach my $attrdevice ( keys %{ $attr{$name} } )    #geht
        {
            fhem "deleteattr $name $attrdevice";
        }

		$hash->{MSwitch_Modulversion}         = $version;
        $hash->{MSwitch_Datenstruktur} = $vupdate;
        $hash->{MSwitch_Autoupdate}    = $autoupdate;
        $hash->{MODEL}                 = $startmode . " " . $version;
		

        readingsBeginUpdate($hash);
        readingsBulkUpdate( $hash, ".Device_Events",   "no_trigger", 0 );
        readingsBulkUpdate( $hash, ".Trigger_cmd_off", "no_trigger", 0 );
        readingsBulkUpdate( $hash, ".Trigger_cmd_on",  "no_trigger", 0 );
        readingsBulkUpdate( $hash, ".Trigger_off",     "no_trigger", 0 );
        readingsBulkUpdate( $hash, ".Trigger_on",      "no_trigger", 0 );
        readingsBulkUpdate( $hash, ".Trigger_device",  "no_trigger", 0 );
        readingsBulkUpdate( $hash, ".Trigger_log",     "off",        0 );
        readingsBulkUpdate( $hash, "state",            "active",    0 );
        readingsBulkUpdate( $hash, ".V_Check",         $vupdate,     0 );
        readingsBulkUpdate( $hash, ".First_init",      'done' );
        readingsEndUpdate( $hash, 0 );

        setDevAttrList( $name, $attrresetlist );
        $hash->{NOTIFYDEV}                        = 'no_trigger';
        $attr{$name}{MSwitch_Eventhistory}        = '0';
        $attr{$name}{MSwitch_Safemode}            = $startsafemode;
        $attr{$name}{MSwitch_Help}                = '0';
        $attr{$name}{MSwitch_Debug}               = '0';
        $attr{$name}{MSwitch_Expert}              = '0';
        $attr{$name}{MSwitch_Delete_Delays}       = '1';
        $attr{$name}{MSwitch_Include_Devicecmds}  = '1';
        $attr{$name}{MSwitch_Include_Webcmds}     = '0';
        $attr{$name}{MSwitch_Include_MSwitchcmds} = '0';
        $attr{$name}{MSwitch_Lock_Quickedit}      = '1';
        $attr{$name}{MSwitch_Extensions}          = '0';
        $attr{$name}{MSwitch_Mode}                = $startmode;
        $attr{$name}{MSwitch_Ignore_Types} = join( " ", @doignore );
        return;
    }
    my $client_hash = $hash->{CL};
    $hash->{helper}{tmp}{reset} = "on";
	MSwitch_assoziation($hash);
    return;
}

################################
sub MSwitch_Set_SetTrigger($@) {
    my ( $hash, $name, $cmd, $trig ) = @_;
	my @args = split (/ /,MSwitch_Asc($trig));
	if ( $args[6] eq 'NoCondition' ) { $args[6] = ""; }
	$args[6]=MSwitch_Hex($args[6]);

    MSwitch_Make_Undo($hash);
	MSwitch_Make_Experimental($hash);
    MSwitch_Clear_timer($hash);
    delete( $hash->{helper}{config} );
    delete( $hash->{helper}{wrongtimespeccond} );
	
	readingsSingleUpdate( $hash, ".Trigger_device", $args[0], 0 );
    my $oldtrigger = ReadingsVal( $name, '.Trigger_device', '' );

    MSwitch_LOG( $name, 6,"settrigger".__LINE__);
	readingsBeginUpdate($hash);
    readingsBulkUpdate( $hash, ".Trigger_condition", $args[6], 0 );
    readingsBulkUpdate( $hash, ".Trigger_time_1",    '',       0 );
    readingsBulkUpdate( $hash, ".Trigger_time_2",    '',       0 );
    readingsBulkUpdate( $hash, ".Trigger_time_3",    '',       0 );
    readingsBulkUpdate( $hash, ".Trigger_time_4",    '',       0 );
    readingsBulkUpdate( $hash, ".Trigger_time_5",    '',       0 );
	readingsEndUpdate( $hash, 0 );
	
	readingsBeginUpdate($hash);
    if ( defined $args[1] && $args[1] ne 'NoTimer' ) {
        readingsBulkUpdate( $hash, ".Trigger_time_1", $args[1], 0 );
    }
    if ( defined $args[2] && $args[2] ne 'NoTimer' ) {
        readingsBulkUpdate( $hash, ".Trigger_time_2", $args[2], 0 );
    }
    if ( defined $args[3] && $args[3] ne 'NoTimer' ) {
        readingsBulkUpdate( $hash, ".Trigger_time_3", $args[3], 0 );
    }
    if ( defined $args[4] && $args[4] ne 'NoTimer' ) {
        readingsBulkUpdate( $hash, ".Trigger_time_4", $args[4], 0 );
    }
    if ( defined $args[5] && $args[5] ne 'NoTimer' ) {
        readingsBulkUpdate( $hash, ".Trigger_time_5", $args[5], 0 );
    }

	readingsEndUpdate( $hash, 0 );
    MSwitch_Createtimer($hash);

    if ( !defined $args[7] ) {
        readingsDelete( $hash, '.Trigger_Whitelist' );
    }
    else {

        MSwitch_LOG( $name, 6,"Whitelist :   $args[7]".__LINE__);
        readingsSingleUpdate( $hash, ".Trigger_Whitelist", $args[7], 0 );
    }

    if ( $oldtrigger ne $args[0] ) {
        MSwitch_Delete_Triggermemory($hash);    # lösche alle events
    }

    $hash->{helper}{events}{ $args[0] }{'no_trigger'} = "on";
    if ( $args[0] ne 'no_trigger' ) 
	{
        if ( $args[0] eq "all_events" ) 
		{
            delete( $hash->{NOTIFYDEV} );
            if ( ReadingsVal( $name, '.Trigger_Whitelist', '' ) ne '' ) {
                my $argument = ReadingsVal( $name, '.Trigger_Whitelist', '' );
				my $resc=0;
				$argument =~ s/\$SELF/$name/g;
               while ( $argument =~ m/\[(.*)\:(.*)\]/ ) {
				   $resc++;
				   last if $resc > 10;
                    MSwitch_LOG( $name, 6," -- $resc -- Whitelist :   found setmagic".__LINE__);
                    $argument = MSwitch_check_setmagic_i( $hash, $argument );
                    MSwitch_LOG( $name, 6,"Whitelist :   new -> $argument".__LINE__);
                }

                $hash->{NOTIFYDEV} = $argument;
            }
        }
        else 
		{

            if ( $args[0] ne "MSwitch_Self" ) 
			{
                $hash->{NOTIFYDEV} = $args[0];
            }
            else 
			{
                $hash->{NOTIFYDEV} = $name;
            }
        }
    }
    else 
	{
        $hash->{NOTIFYDEV} = 'no_trigger';
    }
	my $showevents = MSwitch_checkselectedevent( $hash, "EVENT" );
	
	MSwitch_assoziation($hash);
    readingsSingleUpdate( $hash, "EVENT", "init", $showevents );
	delete $data{MSwitch}{$name}{TCond};
    return;
}

###############################

sub MSwitch_Set_SetTrigger1($@) {
    my ( $hash, $name, $cmd, @args ) = @_;
    MSwitch_Make_Undo($hash);
	MSwitch_Make_Experimental($hash);
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
    readingsBulkUpdate( $hash, ".Trigger_on",      $triggeron ,0);
    readingsBulkUpdate( $hash, ".Trigger_off",     $triggeroff ,0);
    readingsBulkUpdate( $hash, ".Trigger_cmd_on",  $triggercmdon,0 );
    readingsBulkUpdate( $hash, ".Trigger_cmd_off", $triggercmdoff,0 );
    readingsEndUpdate( $hash, 0 );
	delete $data{MSwitch}{$name}{TCond};
    return if $hash->{MSwitch_Init} ne 'define';
	fhem( "modify $name " );
	MSwitch_assoziation($hash);
    return;
}




################################
sub MSwitch_Set_OnOff($@) {
    my ( $ic, $showevents, $devicemode, $delaymode, $hash, $name, $cmd, @args )
      = @_;
    my $oldstate = ReadingsVal( $name, "state", 'undef' );

    my $event = $hash->{helper}{aktevent};
	$showevents = AttrVal( $name, "MSwitch_generate_Events", 0 );

    # test wait attribut
    if ( ReadingsVal( $name, "waiting", '0' ) > time ) {
        # teste auf attr waiting verlesse wenn gesetzt
        return "";
    }
    else {
        # reading löschen
        delete( $hash->{READINGS}{waiting} );
        $data{MSwitch}{$name}{setdata}{last_ID}     = "match";
        $data{MSwitch}{$name}{setdata}{last_cmd}    = "cmd_1" if $cmd eq "on";
        $data{MSwitch}{$name}{setdata}{last_cmd}    = "cmd_2" if $cmd eq "off";
        $data{MSwitch}{$name}{setdata}{last_switch} = "on" if $cmd eq "on";
        $data{MSwitch}{$name}{setdata}{last_switch} = "off" if $cmd eq "off";
    }
	$showevents = MSwitch_checkselectedevent( $hash, "state" );
    readingsSingleUpdate( $hash, "state", $cmd, $showevents );

############################

    MSwitch_Safemode($hash);

    delete $hash->{helper}{evtparts};
    delete $hash->{helper}{evtparts}{event};
    delete $hash->{helper}{aktevent};

    MSwitch_Readings( $hash, $name );
    if ( $devicemode eq "Dummy"
        && AttrVal( $name, "MSwitch_Selftrigger_always", 0 ) == 0 )
    {
		delete $hash->{helper}{deepsave};
        MSwitch_setdata( $hash, $name );
        return;
    }

    #deeprecsave
    $hash->{helper}{deepsave} = $cmd;
	MSwitch_Set_Statecounter( $name, $oldstate, $cmd );
    MSwitch_Exec_Notif( $hash, $cmd, 'nocheck', $event, 0 );

    delete $hash->{helper}{deepsave};
    MSwitch_setdata( $hash, $name );
    
	if (($cmd eq "on" && $oldstate eq "off" )||( $cmd eq "off" && $oldstate eq "off"))
    {
	if (AttrVal( $name, "MSwitch_Mode", "Notify" ) ne "Notify" && AttrVal( $name, "MSwitch_State_Counter", "off" ) eq "after_switch"){

	$showevents=1;
	$showevents = MSwitch_checkselectedevent( $hash, "off_time" );
    readingsSingleUpdate( $hash, "off_time", 0, $showevents );
	$showevents = MSwitch_checkselectedevent( $hash, "on_time" );
	readingsSingleUpdate( $hash, "on_time", 0, $showevents );
	}
	}
    return;
}

##############################

sub MSwitch_Set_Statecounter($@) {
    my ( $name, $oldstate, $cmd ) = @_;
    my $hash = $defs{$name};

    if (   AttrVal( $name, "MSwitch_State_Counter", "off" ) eq "off"
        || AttrVal( $name, "MSwitch_Mode", "Notify" ) eq "Notify" )
    {
        return;
    }
    my $showevents = AttrVal( $name, "MSwitch_generate_Events", 0 );

    # MSwitch_Mode

    if (   ( $cmd eq "on" && $oldstate eq "off" )
        || ( $cmd eq "off" && $oldstate eq "off" ) )
    {

        my $oldofftime = ReadingsVal( $name, "off_time",           0 );
        my $lastswitch = ReadingsVal( $name, "last_ON_OFF_switch", time );
        my $newofftime = $oldofftime + ( time - $lastswitch );
		$showevents = MSwitch_checkselectedevent( $hash, "off_time" );
        readingsSingleUpdate( $hash, "off_time", int $newofftime, $showevents );
    }

    if ( $cmd eq "on" ) {
        my $oncount = ReadingsVal( $name, "on_count", 0 );
        $oncount++;
		$showevents = MSwitch_checkselectedevent( $hash, "on_count" );
        readingsSingleUpdate( $hash, "on_count", $oncount, $showevents );

    }

    if ( $cmd eq "off" ) {
        my $offcount = ReadingsVal( $name, "off_count", 0 );
        $offcount++;
		$showevents = MSwitch_checkselectedevent( $hash, "off_count" );
        readingsSingleUpdate( $hash, "off_count", $offcount, $showevents );
    }

    if (   ( $cmd eq "off" && $oldstate eq "on" )
        || ( $cmd eq "on" && $oldstate eq "on" ) )
    {

        my $oldontime  = ReadingsVal( $name, "on_time",            0 );
        my $lastswitch = ReadingsVal( $name, "last_ON_OFF_switch", time );
        my $newontime = $oldontime + ( time - $lastswitch );
		$showevents = MSwitch_checkselectedevent( $hash, "on_time" );
        readingsSingleUpdate( $hash, "on_time", int $newontime, $showevents );
    }
	$showevents = MSwitch_checkselectedevent( $hash, "last_ON_OFF_switch" );
    readingsSingleUpdate( $hash, "last_ON_OFF_switch", int time, $showevents );
    return;
}

################################

sub MSwitch_Set_Devices($@) {
    my ( $hash, $name, $cmd, @args ) = @_;
    MSwitch_Make_Undo($hash);
	MSwitch_Make_Experimental($hash);
    delete( $hash->{helper}{config} );

    # setze devices
    my $devices = $args[0];
    if ( $devices eq 'null' ) {
        readingsSingleUpdate( $hash, ".Device_Affected", 'no_device', 0 );
        return;
    }
    my @olddevices =
      split( /,/, ReadingsVal( $name, '.Device_Affected', 'no_device' ) );
    my @devices = split( /,/, $args[0] );
    my $addolddevice = '';
    foreach (@devices) {
        my $testdev = $_;
      LOOP6: foreach my $olddev (@olddevices) {
            my $oldcmd  = '';
            my $oldname = '';
            ( $oldname, $oldcmd ) = split( /-AbsCmd/, $olddev );
            if ( !defined $oldcmd ) { $oldcmd = '' }
            if ( $oldcmd eq '1' )   { next LOOP6 }
            if ( $oldname eq $testdev ) {
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
    MSwitch_Set_DetailsBlanko( $hash, $name );
	MSwitch_assoziation($hash);
    return;
}
###############################
sub MSwitch_Set_DetailsBlanko($$) {
    my $blankoinhalt =
"no_action#[NF]no_action#[NF]#[NF]#[NF]delay0#[NF]delay0#[NF]#[NF]#[NF]#[NF]#[NF]#[NF]#[NF]1#[NF]0#[NF]#[NF]0#[NF]0#[NF]1#[NF]0#[NF]0";
    my ( $hash, $name ) = @_;
    my @devices = split( /,/, ReadingsVal( $name, '.Device_Affected', '' ) );
	
	my @bestand = MSwitch_Load_Details($hash);
	
	my %bestandshash;
    foreach my $bestandsdevice (@bestand) {
        my @bestandsparts = split( /#\[NF\]/, $bestandsdevice, 2 );
        $bestandshash{ $bestandsparts[0] } = $bestandsparts[1];
    }
    my $inhalt;
    my @newdevices;
    foreach my $bestandsdevice (@devices) {
        my $newdevice;
        $inhalt = $bestandshash{$bestandsdevice};
        if ( !defined $inhalt || $inhalt eq "" ) {
            $bestandshash{$bestandsdevice} = $blankoinhalt;
            $newdevice = $bestandsdevice . "#[NF]" . $blankoinhalt;
        }
        else {
            $newdevice = $bestandsdevice . "#[NF]" . $inhalt;
        }
        push( @newdevices, $newdevice );
    }
    my $finalfile = join( "#[ND]", @newdevices );
	
	delete $data{MSwitch}{$name}{Device_Affected_Details};
	delete $data{MSwitch}{$name}{TCond};
	MSwitch_Save_Details($hash,$finalfile);

    return;
}
################################

sub MSwitch_Set_Detailsraw($@) {
    my ( $hash, $name, $cmd, @args ) = @_;
	
	
	MSwitch_LOG( "test", 0,"startraw 1" );
	
	$args[0] = urlDecode($args[0]);
	$args[0] = MSwitch_Hex($args[0]);
	MSwitch_Set_Details( $hash, $name, $cmd, @args );
	MSwitch_LOG( "test", 0,"rawende 1" );
	return;
}

################################

sub MSwitch_Set_Details($@) {
    my ( $hash, $name, $cmd, @args ) = @_;
    MSwitch_Make_Undo($hash);
	MSwitch_Make_Experimental($hash);
    delete( $hash->{helper}{config} );

    # setze devices details
	$args[0] = MSwitch_Asc($args[0]);

    #deviceasch
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
            $savedetails = $savedetails . $devicecmds[19] . '#[NF]';
        }
        else {
            $savedetails = $savedetails . '0' . '#[NF]';
        }

        ### identifier
        if ( defined $devicecmds[20] && $devicecmds[20] ne '' ) {
            $savedetails = $savedetails . $devicecmds[20] . '#[NF]';
        }
        else {
            $savedetails = $savedetails . '' . '#[NF]';
        }

        if ( defined $devicecmds[21] && $devicecmds[21] ne '' ) {
            $savedetails = $savedetails . $devicecmds[21] . '#[ND]';
        }
        else {
            $savedetails = $savedetails . '' . '#[ND]';
        }

    }
    chop($savedetails);
    chop($savedetails);
    chop($savedetails);
    chop($savedetails);
    chop($savedetails);

    # ersetzung sonderzeichen etc mscode
    # auskommentierte wurden bereits dur jscript ersetzt

    $savedetails =~ s/\n/#[nl]/g;

	delete $data{MSwitch}{$name}{Device_Affected_Details};
	delete $data{MSwitch}{$name}{TCond};
	MSwitch_Save_Details($hash,$savedetails);
	
	MSwitch_assoziation($hash);

    return if $hash->{MSwitch_Init} ne 'define';
    my $definition = $hash->{DEF};
	fhem( "modify $name " );
	MSwitch_assoziation($hash);
    return;
}

################################

sub MSwitch_CreateSet($$$) {

    my ( $hash, $name, $typ ) = @_;

    my %select;
    my @selectline;
    if ( $typ eq "Notify" ) {
        %select = %setsnotify;
    }

    if ( $typ eq "Toggle" ) {
        %select = %setstoggle;
    }

    if ( $typ eq "Full" ) {
        %select = %setsfull;
    }

    if ( $typ eq "Dummy" ) {
        if ( AttrVal( $name, "MSwitch_Selftrigger_always", 0 ) > 0 ) {
            %select = %setsdummywithst;
        }
        else {
            %select = %setsdummywithoutst;
        }
    }

    foreach my $key ( sort keys %select ) {

        my $opts = undef;
        $opts = $select{$key} if ( exists( $select{$key} ) );
        push( @selectline, $key . ':' . $opts );
    }

    return ( "@selectline", %select );
}

################################
sub MSwitch_Set($@) {
    my ( $hash, $name, $cmd, @args ) = @_;
    my $dynlist   = "";
    my $special   = '';
    my $setwidget = "";

    return ""
    if ( IsDisabled($name) && ( $cmd eq 'on' || $cmd eq 'off' ) );    # Return without any further action if the module is disabled

    if ( $cmd ne "?" && $cmd ne "clearlog" && $cmd ne "writelog" ) {
        MSwitch_LOG( $name, 6,"\n ".localtime."\n---------- Moduleinstieg > SUB SET ----------\n- eingehender Setbefehl: $cmd \n- eingehende Argumente: @args   ");
    }

   my $ic = 'leer';

$ic = $hash->{helper}{trigwrite};


    # on/off übergabe mit parametern
my $showevents = MSwitch_checkselectedevent( $hash, "Parameter" );

		  if (   ( ( $cmd eq 'on' ) || ( $cmd eq 'off' ) )
        && ( defined $args[0] && $args[0] ne '' )
        && ( $ic ne 'notify' ) )
    {
		
        readingsSingleUpdate( $hash, "Parameter", $args[0], $showevents );
        $args[0] = "$name:" . $cmd . "_with_Parameter:$args[0]";
    }


 if ((( $cmd eq 'on' ) || ( $cmd eq 'off'  )) && $hash->{helper}{trigwrite} ne "noset"){


#from
 readingsSingleUpdate( $hash, "last_device_trigger", "OnOff" , $showevents ) ;
 }

    MSwitch_del_savedcmds($hash);    # prüfen lösche saveddevicecmd

    $hash->{MSwitch_Eventsave} = 'unsaved';

    my $showevents = AttrVal( $name, "MSwitch_generate_Events", 0 );
    if ( AttrVal( $name, 'MSwitch_Debug', '0' ) ne "0" ) { $showevents = 1 }

    my $devicemode = AttrVal( $name, 'MSwitch_Mode',          'Notify' );
    my $delaymode  = AttrVal( $name, 'MSwitch_Delete_Delays', '0' );

    # randomnunner erzeugen wenn attr an
    if ( AttrVal( $name, 'MSwitch_RandomNumber', '' ) ne '' ) {
        MSwitch_Createnumber1($hash);
    }

#################################
    #Systembefehle
    ( my $setline, %sets ) = MSwitch_CreateSet( $hash, $name, $devicemode );

	if ( $cmd eq 'extractbackup' ) {
       my $ret = MSwitch_Set_extractbackup( $hash, $name, $cmd, @args );
        return $ret;
    }
	
	if ( $cmd eq 'deletefiles' ) {
       my $ret = MSwitch_Set_deletefiles( $hash, $name, $cmd, @args );
        return $ret;
    }
	
	if ( $cmd eq 'createconf' ) {
       my $ret = MSwitch_restore_this( $hash,"configdevice" );
        return $ret;
    }
	
	if ( $cmd eq 'extractbackup1' ) {
       my $ret = MSwitch_Set_extractbackup1( $hash, $name, $cmd, @args );
        return $ret;
    }

    if ( $cmd eq 'wizardcont' ) {
        MSwitch_Set_wizard( $hash, $name, $cmd, @args );
        return;
    }
    if ( $cmd eq 'alert' ) {
        MSwitch_Set_alert( $hash, $name, $cmd, @args );
        return;
    }
    if ( $cmd eq 'wizardcont1' ) {
        MSwitch_Set_wizard1( $hash, $name, $cmd, @args );
        return;
    }
    if ( $cmd eq 'writelog' ) {
        MSwitch_Set_Writelog( $hash, $name, $cmd, @args );
        return;
    }
    if ( $cmd eq 'timer' ) {
        MSwitch_Set_timer( $hash, $name, $cmd, @args );
        return;
    }
    if ( $cmd eq 'showgroup' ) {
        MSwitch_makegroupcmdout( $hash, $args[0] );
        return;
    }
   if ( $cmd eq 'undo' ) {
	   MSwitch_restore_this( $hash, "undo" ); 
	   return; 
	   }

	if ( $cmd eq 'restore_exp' ) {
		   MSwitch_restore_this( $hash, "experimental" ); 
	   return; 
	   }

    if ( $cmd eq 'savetemplate' ) {
        MSwitch_savetemplate( $hash, $args[0], $args[1] );
        return;
    }
    if ( $cmd eq 'loadreadings' ) {
        my $ret = MSwitch_reloadreadings( $hash, $args[0] );
        return $ret;
    }
    if ( $cmd eq 'template' ) {
        my $ret = MSwitch_gettemplate( $hash, $args[0] );
        return $ret;
    }
    if ( $cmd eq 'reset_Switching_once' ) {
        MSwitch_Set_switching_once( $hash, $args[0], $args[1] );
        return;
    }
    if ( $cmd eq 'groupreload' ) {
        my $ret = MSwitch_reloaddevices( $hash, $args[0] );
        return $ret;
    }
    if ( $cmd eq 'notifyset' ) {
        my $ret = MSwitch_notifyset( $hash, $args[0] );
        return $ret;
    }
    if ( $cmd eq 'fullrestore' ) {
        my $ret = MSwitch_fullrestore( $hash, $args[0],$args[1] );
        return $ret;
    }
    if ( $cmd eq 'fullrestorelocal' ) {
        my $ret = MSwitch_fullrestorelocal( $hash, $args[0] );
        return $ret;
    }
	
	   if ( $cmd eq 'uploadlocal' ) {
        my $ret = MSwitch_uploadlocal( $hash, @args);
        return $ret;
	   }
	
    if ( $cmd eq 'getbackup' ) {
        my $ret = MSwitch_Get_Backup($hash);
        return $ret;
    }
    if ( $cmd eq 'fullbackup' ) {
        my $ret = MSwitch_FullBackup( $hash, $args[0] );
        return $ret;
    }
    if ( $cmd eq 'getbackupfile' ) {
        my $ret = MSwitch_Get_Backup_inhalt( $hash, $args[0] );
        return $ret;
    }
    if ( $cmd eq 'getdevices' ) {
        my $ret = MSwitch_Get_Devices($hash);
        return $ret;
    }
    if ( $cmd eq 'getraw' ) { my $ret = MSwitch_Getraw($hash); return $ret; }
    if ( $cmd eq 'whitelist' ) {
        my $ret = MSwitch_whitelist( $hash, $args[0] );
        return $ret;
    }
    if ( $cmd eq 'loadpreconf' ) {
        my $ret = MSwitch_loadpreconf($hash);
        return $ret;
    }
    if ( $cmd eq 'loadnotify' ) {
        my $ret = MSwitch_loadnotify( $hash, $args[0] );
        return $ret;
    }

	if ( $cmd eq 'reload_Assoziations' ) {
        my $ret = MSwitch_assoziation( $hash );
        return $ret;
    }
	
    if ( $cmd eq 'loadat' ) {
        my $ret = MSwitch_loadat( $hash, $args[0] );
        return $ret;
    }
    if ( $cmd eq 'clearlog' ) { MSwitch_clearlog($hash); return; }
    if ( $cmd eq 'setbridge' ) { MSwitch_setbridge( $hash, $args[0] ); return; }
    if ( $cmd eq 'logging' ) {
        MSwitch_Set_loggingwebjs( $hash, $args[0] );
        return;
    }
    if ( $cmd eq 'reset_device' ) {
        MSwitch_Set_ResetDevice( $hash, $name, $cmd, @args );
        return;
    }
    if ( $cmd eq 'loadHTTP' ) {
        MSwitch_PerformHttpRequest( $hash, $args[0] );
        return;
    }

    if ( $cmd eq 'Writesequenz' ) { MSwitch_Writesequenz($hash);  return; }
    if ( $cmd eq 'VUpdate' )      { MSwitch_VersionUpdate($hash); return; }

    if ( $cmd eq 'deletesinglelog' ) {
        my $ret = MSwitch_delete_singlelog( $hash, $args[0] );
        return;
    }
    if ( $cmd eq 'wait' ) {
		$showevents = MSwitch_checkselectedevent( $hash, "waiting" );
        readingsSingleUpdate( $hash, "waiting", ( time + $args[0] ),
            $showevents );
        return;
    }
    if ( $cmd eq 'sort_device' ) {
        readingsSingleUpdate( $hash, ".sortby", $args[0], 0 );
        return;
    }
    if ( $cmd eq 'fakeevent' ) {
        MSwitch_Check_Event( $hash, $args[0] );
        return;
    }
    if ( $cmd eq "set_trigger" ) {
        MSwitch_Set_SetTrigger( $hash, $name, $cmd, @args );
        return;
    }
    if ( $cmd eq "trigger" ) {
        MSwitch_Set_SetTrigger1( $hash, $name, $cmd, @args );
        return;
    }
    if ( $cmd eq "devices" ) {
        MSwitch_Set_Devices( $hash, $name, $cmd, @args );
        return;
    }
    if ( $cmd eq "details" ) {
        MSwitch_Set_Details( $hash, $name, $cmd, @args );
        return;
    }
	
	
	 if ( $cmd eq "detailsraw" ) {
        MSwitch_Set_Detailsraw( $hash, $name, $cmd, @args );
        return;
    }
	

if ( $cmd eq "toggle" && ReadingsVal( $name, "state", 'undef' ) eq "on" ) {$cmd = "off"}
if ( $cmd eq "toggle" && ReadingsVal( $name, "state", 'undef' ) eq "off" ) {$cmd = "on"}


    if ( $cmd eq "off" || $cmd eq "on" ) {
        MSwitch_Set_OnOff( $ic, $showevents, $devicemode, $delaymode, $hash,
            $name, $cmd, @args );	
        return;
    }

    if ( $cmd eq 'reset_cmd_count' ) {
        MSwitch_Set_ResetCmdCount( $hash, $name, $cmd, @args );
        return;
    }
    if ( $cmd eq 'reset_status_counter' ) {
        MSwitch_DeleteStatusReset($hash);
        return;
    }

    if ( $cmd eq 'reload_timer' ) {
        MSwitch_Set_ReloadTimer( $hash, $name, $cmd, @args );
        return;
    }
    if ( $cmd eq 'wizard' ) {
        MSwitch_Set_Wizard( $hash, $name, $cmd, @args );
        return;
    }
    if ( $cmd eq 'change_renamed' ) {
        MSwitch_Set_ChangeRenamed( $hash, $name, $cmd, @args );
        return;
		
	}

	if ( $cmd eq 'search_free' ) {
        
		MSwitch_Set_Freesearch( $hash, $name, $cmd, @args );
        return;
	
    }
    if ( $cmd eq 'exec_cmd_1' ) {
		
		
		MSwitch_LOG( $name, 6,"-> execute cmd1");

        MSwitch_Set_ExecCmd( $hash, $name, $cmd, @args );
        return;
    }
    if ( $cmd eq 'exec_cmd_2' ) {
		MSwitch_LOG( $name, 6,"-> execute cmd2");
        MSwitch_Set_ExecCmd( $hash, $name, $cmd, @args );
        return;
    }
    if ( $cmd eq 'addevent' ) {
        MSwitch_Set_AddEvent( $hash, $name, $cmd, @args );
        return;
    }
    if ( $cmd eq 'del_repeats' ) {
        MSwitch_Set_DelRepeats( $hash, $name, $cmd, @args );
        return;
    }
    if ( $cmd eq 'del_delays' ) {
        MSwitch_Set_DelDelays( $hash, $name, $cmd, @args );
        return;
    }
    if ( $cmd eq 'del_history_data' ) {
        MSwitch_Set_DelHistory( $hash, $name, $cmd, @args );
        return;
    }
    if ( $cmd eq 'backup_MSwitch' ) {
        MSwitch_backup_this( $hash, "" );
        return;
    }

    if ( $cmd eq 'inactive' ) {
		$showevents = MSwitch_checkselectedevent( $hash, "state" );
        readingsSingleUpdate( $hash, "state", 'inactive', 1 );
        MSwitch_Clear_timer($hash);
        MSwitch_LOG( $name, 6, "-> Timer gelöscht L:" . __LINE__ );
        return;
    }

    if ( $cmd eq 'active' ) {
		$showevents = MSwitch_checkselectedevent( $hash, "state" );
        readingsSingleUpdate( $hash, "state", 'active', $showevents );
        MSwitch_Clear_timer($hash);
        MSwitch_Createtimer($hash);
        MSwitch_LOG( $name, 6, "-> Timer neu berechnet L:" . __LINE__ );
        return;
    }

    if ( $cmd eq 'saveconfig' ) {

        # configfile speichern
        $args[0] =~ s/\[s\]/ /g;
        MSwitch_saveconf( $hash, $args[0] );
        return;
    }
##
    if ( $cmd eq 'savesys' ) {

        # sysfile speichern
        MSwitch_savesys( $hash, $args[0] );
        MSwitch_defineWidgets($hash);
        return;
    }
##
    if ( $cmd eq "delcmds" ) {
        delete $data{MSwitch}{devicecmds1};
        delete $data{MSwitch}{last_devicecmd_save};
        return;
    }
##
    if ( $cmd eq "del_function_data" ) {
        delete( $hash->{helper}{eventhistory} );
        fhem("deletereading $name DIFFERENCE");
        fhem("deletereading $name TENDENCY");
        fhem("deletereading $name AVERAGE");
        return;
    }

##
    if ( $cmd eq "add_device" ) {
        MSwitch_Make_Undo($hash);
	MSwitch_Make_Experimental($hash);
        delete( $hash->{helper}{config} );
        MSwitch_Add_Device( $hash, $args[0] );
        return;
    }
##
    if ( $cmd eq "del_device" ) {
        MSwitch_Make_Undo($hash);
		MSwitch_Make_Experimental($hash);
        MSwitch_Del_Device( $hash, $args[0] );
        return;
    }
##
    if ( $cmd eq "del_trigger" ) {
        MSwitch_Make_Undo($hash);
		MSwitch_Make_Experimental($hash);
        MSwitch_Delete_Triggermemory($hash);
        return;
    }

##

    if ( $cmd eq "Dynsetlist" || $cmd eq "Dynsetlist_clear" ) {
        my @lastsetlist = split( / /, ReadingsVal( $name, 'Dynsetlist', '' ) );
        my @setter = split( / /, @lastsetlist );
        foreach my $test (@lastsetlist) {
            my @gefischt = grep( /$test/, @setter );
            fhem("deletereading $name $test") if @gefischt < 1;
        }
		$showevents = MSwitch_checkselectedevent( $hash, $cmd );
		
        readingsSingleUpdate( $hash, $cmd, "@args", $showevents )
          if ( $cmd eq "Dynsetlist" );
        fhem("deletereading $name Dynsetlist")
          if ( $cmd eq "Dynsetlist_clear" );
		  
		MSwitch_triggerkorrektur($hash, $cmd);  
        return;
    }

##

    if ( $cmd eq "Dynsetlist_add" ) {
        my @lastsetlist = split( / /, ReadingsVal( $name, 'Dynsetlist', '' ) );
        my %newlist;
        foreach my $test (@lastsetlist) {
            $newlist{$test} = ReadingsVal( $name, $test, '' );
        }
        $newlist{ $args[0] } = '';
        my @artest = ( keys %newlist );
		$showevents = MSwitch_checkselectedevent( $hash, "Dynsetlist" );
        readingsSingleUpdate( $hash, 'Dynsetlist', "@artest", $showevents);
		
		MSwitch_triggerkorrektur($hash, $cmd);
        return;
    }

##

    if ( $cmd eq "Dynsetlist_delete" ) {
        my @lastsetlist = split( / /, ReadingsVal( $name, 'Dynsetlist', '' ) );
        my %newlist;
        foreach my $test (@lastsetlist) {
            $newlist{$test} = ReadingsVal( $name, $test, '' )
              if ( $test ne $args[0] );
        }
        my @artest = ( keys %newlist );
		
        readingsSingleUpdate( $hash, 'Dynsetlist', "@artest", 1 );
        fhem("deletereading $name $args[0]");
		MSwitch_triggerkorrektur($hash, $cmd);
		
        return;
    }
	
##	
	
	if ( $cmd eq "restore_lastStates" ) 
	{

		my $pfad ="";
		if ($args[0] eq "cmd1"){$pfad ="on";}
		if ($args[0] eq "cmd2"){$pfad ="off";}
		my $statearg = "deviceslaststate".$pfad;
		my @laststates = split (" ",$data{MSwitch}{$name}{lastStates}{$statearg});

		foreach my $devval (@laststates) {
			my  @DevState = split ("\:",$devval);
			my $inhalt  = $data{MSwitch}{$name}{lastStates}{$pfad}{$DevState[0]}{$DevState[1]};
			my $readingrear = "lastState_".$DevState[0]."_".$DevState[1];
			my $readingrearval =  ReadingsVal( $name, $readingrear, 'undef' );
			if ($inhalt eq "noDyn")
			{
			next if $readingrearval eq "";
			my $setting = "set $DevState[0] $DevState[1] $readingrearval";
			$setting =~ s/state //g;
			my $errors = AnalyzeCommandChain( undef, $setting );
				if ( defined($errors)) 
				{
					MSwitch_LOG( $name, 6,"LastState-ERROR : $errors -> Comand: $setting" );
				}	
				
			}
			else{
				my @Pairs = split ("/",$inhalt);
				my @mapping = split ("/",$inhalt);
				my %map ;
				foreach my $maptmp (@mapping){
					next if $maptmp eq "";
					my @maptmp1 = split ("->",$maptmp);
					$map{$maptmp1[0]}=$maptmp1[1];
				}
				
					my $setter =  $map{$readingrearval};
					my $setting = "set $DevState[0] $setter";
					my $errors = AnalyzeCommandChain( undef, $setting );
					if ( defined($errors)) 
					{
						MSwitch_LOG( $name, 6,"LastState-ERROR : $errors -> Comand: $setting" );
					}
			}
		}
        return;
    }
	
## restore_lastStates:saved_from_cmd_1,saved_from_cmd_2

##########################
    # einlesen der genutzten Mswitch_widgets
    if ( AttrVal( $name, 'MSwitch_SysExtension', "0" ) ne "0" ) {
        foreach my $a ( keys %{ $data{MSwitch}{$name}{activeWidgets} } ) {
            my $checkreading = $data{MSwitch}{Widget}{$a}{reading};
            if ( $checkreading eq $cmd ) {
				$showevents = MSwitch_checkselectedevent( $hash, $cmd );
                readingsSingleUpdate( $hash, $cmd, "@args", $showevents );
				MSwitch_triggerkorrektur($hash, $cmd);
                return;
            }
        }

        # checkaktiv widgets und erstelle set für reading
        foreach my $a ( keys %{ $data{MSwitch}{$name}{activeWidgets} } ) {
            $setwidget .= $data{MSwitch}{Widget}{$a}{reading} . " ";
        }
        chop $setwidget;
    }

########################
    # einlesen MSwitch dyn setlist
    # mswitch dyn setlist
    my $mswitchsetlist = AttrVal( $name, 'MSwitch_setList', "undef" );
    my @arraydynsetlist;
    my @arraydynreadinglist;
    my $dynsetlist = "";
    if ( $mswitchsetlist ne "undef" ) {
        my @dynsetlist = split( / /, $mswitchsetlist );
        foreach my $test (@dynsetlist) {
            if ( $test =~ m/(.*)\[(.*)\]:?(.*)/ ) {
                my @found_devices = devspec2array($2);
                my $s1            = $1;
                my $s2            = $2;
                my $s3            = $3;
                if ( $s1 ne "" && $1 =~ m/.*:/ ) {
                    my $reading = $s1;
                    chop($reading);
                    push @arraydynsetlist, $reading;
                    $dynlist = join( ',', @found_devices );
                    $dynsetlist = $dynsetlist . $reading . ":" . $dynlist . " ";
                }

                if ( $s3 ne "" ) {
                    my $sets            = $s3;
                    my @test            = split( /,/, $sets );
                    my $namezusatzback  = $sets;
                    my $namezusatzfront = $s1;
                    foreach my $test1 (@found_devices) {
                        if ( $sets eq "Arg" ) {
                            push @arraydynsetlist, $test1;
                        }
                        else {
                            # nothing
                        }
                        push @arraydynsetlist, $test1 . ":" . $sets;
                    }
                    @arraydynreadinglist = @found_devices;
                    $dynsetlist = join( ' ', @arraydynsetlist );
                }
            }
            else {
                $dynsetlist = $dynsetlist . $test;
            }
        }

    }
	
############## einsetzen des restore lastStates	

my $lastStates ="";
if ( AttrVal( $name, 'MSwitch_lastState', 'undef' ) ne "undef" ) { 
$lastStates="restore_lastStates:cmd1,cmd2"; 
}

###########################

    #dynsetlist enlesen
    # setlist einlesen

    my $returnblank = "";
    if ( !defined $args[0] ) { $args[0] = ''; }
    my $setList = AttrVal( $name, "setList", " " );
    $setList =~ s/\n/ /g;
    my $dynsetlist1 = "";
    my $dynsetentry = "";

    # funktion nicht aktiv
    if ( AttrVal( $name, 'MSwitch_Expert', "0" ) eq '1' ) {
        $dynsetentry =
"Dynsetlist:textField-long Dynsetlist_clear:noArg Dynsetlist_add Dynsetlist_delete ";
        $dynsetlist1 = ReadingsVal( $name, 'Dynsetlist', '' );
        $dynsetlist1 =~ s/\n/ /g;
############################

        if ( $dynsetlist1 ne "" ) {
            my @dynsetlisttest = split( / /, $dynsetlist1 );
            if ( $cmd ne "?" ) {
                my @testarray = ( grep( /$cmd/, @dynsetlisttest ) );
                if ( @testarray > 0 ) {
				$showevents = MSwitch_checkselectedevent( $hash, $cmd );
				
                    readingsSingleUpdate( $hash, $cmd, "@args", $showevents );
					
					MSwitch_triggerkorrektur($hash, $cmd);
                    $returnblank = "return";
                }
            }
            $setList = $setList . " " . $dynsetlist1;
        }
    }

###############
    my %setlist;

    # nur bei funktionen in setlist !!!!
    if ( AttrVal( $name, "MSwitch_Selftrigger_always", 0 ) > 0 and $cmd ne "?" )
    {
        my $atts = $setList;
        my @testarray = split( " ", $atts );
        foreach (@testarray) {
            my ( $arg1, $arg2 ) = split( ":", $_, 2 );
            if ( !defined $arg2 or $arg2 eq "" ) { $arg2 = "noArg" }
            $setlist{$arg1} = $arg2;
        }

        foreach (@arraydynsetlist) {
            my ( $arg1, $arg2 ) = split( ":", $_, 2 );
            if ( !defined $arg2 or $arg2 eq "" ) { $arg2 = "noArg" }
            $setlist{$arg1} = $arg2;
        }

        if ( defined $setlist{$cmd} ) {
            if ( defined $args[0] || $args[0] ne "" ) {
                $hash->{helper}{restartseltrigger} =
                  "MSwitch_Self:" . $cmd . ":" . "@args";
                MSwitch_Restartselftrigger($hash);

                $returnblank = "return";
            }
        }
    }

#########################

    if ( !exists( $sets{$cmd} ) ) {
        my @cList;
        # Overwrite %sets with setList
        my $atts = $setList;

        my @testarray = split( " ", $atts );
        foreach (@testarray) {
            my ( $arg1, $arg2 ) = split( ":", $_, 2 );
            if ( !defined $arg2 or $arg2 eq "" ) { $arg2 = "noArg" }
            $setlist{$arg1} = $arg2;
        }
        foreach my $k ( sort keys %sets ) {
            my $opts = undef;
            $opts = $sets{$k};
            $opts = $setlist{$k} if ( exists( $setlist{$k} ) );
            if ( defined($opts) ) {
                push( @cList, $k . ':' . $opts );
            }
            else {
                push( @cList, $k );
            }
        }    # end foreach

        # unbekannt
        if ( ReadingsVal( $name, '.change', '' ) ne '' ) {
            return "Unknown argument $cmd, choose one of "
              if ( $name eq "test" );
        }

        # bearbeite setlist und readinglist
##############################
        if ( $cmd ne "?" ) {
            my @sl       = split( " ", AttrVal( $name, "setList", "" ) );
            my $re       = qr/$cmd/;
            my @gefischt = grep( /$re/, @sl );
            if ( @sl && grep /$re/, @sl ) {
                my @rl = split( " ", AttrVal( $name, "readingList", "" ) );
                if ( @rl && grep /$re/, @rl ) {
					$showevents = MSwitch_checkselectedevent( $hash, $cmd );
					
                    readingsSingleUpdate( $hash, $cmd, "@args", $showevents );
					MSwitch_triggerkorrektur($hash, $cmd);
                }
                else {
					$showevents = MSwitch_checkselectedevent( $hash, "state" );
					
                    readingsSingleUpdate( $hash, "state", $cmd . " @args", $showevents );
					MSwitch_triggerkorrektur($hash, $cmd);
                }
				
                return;
            }
            @gefischt = grep( /$re/, @arraydynsetlist );
            if ( @arraydynsetlist && grep /$re/, @arraydynsetlist ) {
				$showevents = MSwitch_checkselectedevent( $hash, $cmd );
				
                readingsSingleUpdate( $hash, $cmd, "@args",$showevents );
				MSwitch_triggerkorrektur($hash, $cmd);
                return;
            }

##############################
            # dummy state setzen und exit
            if ( $devicemode eq "Dummy" ) {
                if ( $cmd eq "on" || $cmd eq "off" ) {
					$showevents = MSwitch_checkselectedevent( $hash, $cmd );
                    readingsSingleUpdate( $hash, "state", $cmd . " @args", $showevents );
					MSwitch_triggerkorrektur($hash, $cmd);
                    return;
                }
                else {
                    if ( AttrVal( $name, 'useSetExtensions', "0" ) eq '1' ) {
                        return SetExtensions( $hash, $setList, $name, $cmd,
                            @args );
                    }
                    else {
                        return;
                    }
                }
            }

         }

        if ( $returnblank eq "return" ) { return; }

        my $statistic = "";
        my $alert     = "";
        my $zusatz ="$dynsetlist1 $dynsetentry $alert $dynsetlist $setList $setwidget $statistic";
        if ( exists $hash->{helper}{config}
            && $hash->{helper}{config} eq "no_config" )
        {
            # rückgabe für leeres/neues device
            return "Unknown argument $cmd, choose one of wizard:noArg";
        }

        if ( AttrVal( $name, 'MSwitch_Modul_Mode', "0" ) eq '1' ) {
            # rückgabe modulmode - no sets
            return "Unknown argument $cmd, choose one of $zusatz";
        }

        if ( $devicemode eq "Full" ) {
            $zusatz .= " " . $special;
        }

        if (   $devicemode eq "Notify"
            || $devicemode eq "Toggle"
            || $devicemode eq "Full" )
        {
            return "Unknown argument $cmd, choose one of $setline $zusatz $lastStates";
        }

####################################

        if ( $devicemode eq "Dummy" ) {
            $zusatz .= " " . $special;
            if ( AttrVal( $name, 'useSetExtensions', "0" ) eq '1' ) 
			{
                return SetExtensions( $hash, $setList, $name, $cmd, @args );
            }
            else 
			{
			MSwitch_LOG( $name, 6, "$setline " . $setList. " $zusatz");
			return "Unknown argument $cmd, choose one of $setline" . " " . " $zusatz";
            }
        }
        return;
    }

### ende der sets prüfung
##############################
    return;
}

###################################

sub MSwitch_triggerkorrektur($$) {
my ( $hash, $cmd ) = @_;
    my $name = $hash->{NAME};
    # teste auf dynamischen trigger und änderung
    my $argument = ReadingsVal( $name, '.Trigger_Whitelist', '' );
	MSwitch_LOG( $name, 6,"-> check dynamic trigger : $argument");
	MSwitch_LOG( $name, 6,"-> cmd : $cmd");
    if ( $argument =~ m/\[(.*)\:(.*)\]/ ) {
        $argument =~ s/\$SELF/$name/g;
        my $test1 = "[$name:$cmd]";
        if ( $test1 eq $argument ) {
            $argument = MSwitch_check_setmagic_i( $hash, $argument );
			MSwitch_LOG( $name, 6,"-> return from setmagic: $argument");
            $hash->{NOTIFYDEV} = $argument;
        }
    }
}

##################################

sub MSwitch_Cmd(@) {

    my ( $hash, @cmdpool ) = @_;
    my $Name = $hash->{NAME};
    my @timers = split / /, $hash->{helper}{delaytimers};
    delete( $hash->{helper}{delaytimers} );
    my $fullstring = join( '[|]', @cmdpool );
    if ( AttrVal( $Name, 'MSwitch_Switching_once', 0 ) == 1
        && $fullstring eq $hash->{helper}{lastexecute} )
    {
        MSwitch_LOG( $Name, 6,"-> Ausführung Befehlsstapel abgebrochen, Stapel wurde bereits ausgeführt\n(attr MSwitch_Switching_once gesetzt) L:" . __LINE__ );
        return;
    }

    my $lastdevice;
    my $showevents = AttrVal( $Name, "MSwitch_generate_Events", 0 );
    if ( AttrVal( $Name, 'MSwitch_Debug', '0' ) ne "0" ) { $showevents = 1 }
    my %devicedetails = MSwitch_makeCmdHash($Name);

    foreach my $cmds (@cmdpool) {
        if ( $cmds =~ m/\[TIMER\].*/ ) {
            $cmds =~ m/\[NUMBER(.*?)](.*)/;
            my $number = $1;
            my $string = $2;
            $string =~ s/#\[MSNL\]/\n/g;
            my $timecondition = $timers[$number];
            $string =~ s/TIMECOND/$timecondition/g;
            MSwitch_LOG( $Name, 6, "-> setze Timer: $string L:" . __LINE__ );
            $hash->{helper}{delays}{$string} = $timecondition;
            InternalTimer( $timecondition, "MSwitch_Restartcmd", $string );
            next;
        }

        my @cut = split( /\|/, $cmds );
        $cmds = $cut[0];

        #ersetze platzhakter vor ausführung
        my $device = $cut[1];
        my $zweig  = $cut[2];

        $lastdevice = $device;
        my $toggle = '';
        if ( $cmds =~ m/set (.*)(MSwitchtoggle)(.*)/ ) {
            $toggle = $cmds;
            $cmds = MSwitch_toggle( $hash, $cmds );
        }

        if ( AttrVal( $Name, 'MSwitch_Expert', "0" ) eq '1'
            && $devicedetails{ $device . '_repeatcount' } ne '' )
        {
            my $x = 0;
            while ( $devicedetails{ $device . '_repeatcount' } =~
                m/\[(.*)\:(.*)\]/ )
            {
                $x++;    # exit
                last if $x > 20;    # exitg
                my $setmagic = ReadingsVal( $1, $2, 0 );
                $devicedetails{ $device . '_repeatcount' } = $setmagic;
            }
        }

        if ( AttrVal( $Name, 'MSwitch_Expert', "0" ) eq '1'
            && $devicedetails{ $device . '_repeattime' } ne '' )
        {
            my $x = 0;
            while (
                $devicedetails{ $device . '_repeattime' } =~ m/\[(.*)\:(.*)\]/ )
            {
                $x++;    # exit
                last if $x > 20;    # exitg
                my $setmagic = ReadingsVal( $1, $2, 0 );
                $devicedetails{ $device . '_repeattime' } = $setmagic;
            }
        }

        if (   AttrVal( $Name, 'MSwitch_Expert', "0" ) eq '1'
            && $devicedetails{ $device . '_repeatcount' } > 0
            && $devicedetails{ $device . '_repeattime' } > 0 )
        {
            my $i;
            for (
                $i = 1 ;
                $i <= $devicedetails{ $device . '_repeatcount' } ;
                $i++
              )
            {
                my $msg = $cmds . "|" . $Name;
                if ( $toggle ne '' ) {
                    $msg = $toggle . "|" . $Name;
                }
                my $timecond = gettimeofday() +
                  ( ( $i + 1 ) * $devicedetails{ $device . '_repeattime' } );
                $msg = $msg . "|" . $timecond . "|" . $device . "|" . $zweig;
                $hash->{helper}{repeats}{$timecond} = "$msg";
                MSwitch_LOG( $Name, 6, "-> setze Wiederholungen L:" . __LINE__ );
                InternalTimer( $timecond, "MSwitch_repeat", $msg );
            }
        }

        my $todec = $cmds;
        $cmds = MSwitch_dec( $hash, $todec );

############################
        # debug2 mode , kein execute
        if ( AttrVal( $Name, 'MSwitch_Debug', "0" ) eq '2' ) {
            MSwitch_LOG( $Name, 6,"-> ausgeführter Befehl:\n-> $cmds \nL:" . __LINE__ );
        }
        else {
            if ( $cmds =~ m/(\{)(.*)(\})/ ) {
                $cmds =~ s/\[SR\]/\|/g;
                MSwitch_LOG( $Name, 6,"-> ausgeführter Befehl auf Perlebene:\n-> $cmds L:" . __LINE__ );
                my $out;
                {
                    no warnings;
                    $out = eval($cmds);
                    if ($@) {
                        MSwitch_LOG( $Name, 1,"MSwitch_Set: ERROR $cmds: $@ " . __LINE__ );
                    }
                }
            }
            else {
                MSwitch_LOG( $Name, 6,"-> ausgeführter Befehl auf Fhemebene:\n-> $cmds \nL:". __LINE__ );
                my $errors = AnalyzeCommandChain( undef, $cmds );
                if ( defined($errors) and $errors ne "OK" ) {
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
	$showevents = MSwitch_checkselectedevent( $hash, "last_exec_cmd" );
    readingsSingleUpdate( $hash, "last_exec_cmd", $showpool, $showevents )
      if $showpool ne '';

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
    if ( AttrVal( $Name, 'MSwitch_Debug', '0' ) ne "0" ) { $showevents = 1 }

	MSwitch_LOG( $Name, 6,"\n---------- SUB TOGGLE ----------\n- ausführung Toggle");
	MSwitch_LOG( $Name, 6,"-> cmds $cmds ");

    $cmds =~ s/#\[SR\]/|/g;
    $cmds =~ m/(set) (.*)( )MSwitchtoggle (.*)/;

    my $devicename = $2;
    my $newcomand  = $1 . " " . $2 . " ";
	MSwitch_LOG( $Name, 6,"-> cmds $cmds ");
	MSwitch_LOG( $Name, 6,"-> devicename $devicename ");
	MSwitch_LOG( $Name, 6,"-> s4 $4 ");

    if ( $2 eq "MSwitch_Self" ) {
        $newcomand  = $1 . " " . $Name . " ";
        $devicename = $Name;
    }

	MSwitch_LOG( $Name, 6,"-> newcomand $newcomand ");


    my @togglepart = split( /:/, $4 );
    my $trenner = ",";

	MSwitch_LOG( $Name, 6,"-> trenner $trenner ");
	MSwitch_LOG( $Name, 6,"-> togglepart @togglepart ");

    if ( $togglepart[0] =~ m/^\[(.)\]/ ) 
	{
		MSwitch_LOG( $Name, 6,"-> Option 1 ");
        if ( $togglepart[0] =~ m/^\[\|\]/ ) 
		{
            $togglepart[0] = "\\|";
        }
        $trenner = $togglepart[0];
        $trenner =~ s/\[//g;
        $trenner =~ s/\]//g;
        shift @togglepart;
    }

    if ( $togglepart[0] ) 
	{
		MSwitch_LOG( $Name, 6,"-> Option 2 ");
        $togglepart[0] =~ s/\[//g;
        $togglepart[0] =~ s/\]//g;
        @cmds = split( /$trenner/, $togglepart[0] );
        $anzcmds = @cmds;
    }

    if ( $togglepart[1] )
	{
		MSwitch_LOG( $Name, 6,"-> Option 3 ");

        $togglepart[1] =~ s/\[//g;
        $togglepart[1] =~ s/\]//g;
        @muster = split( /$trenner/, $togglepart[1] );
        $anzmuster = @cmds;
    }
    else 
	{
	MSwitch_LOG( $Name, 6,"-> Option 4 ");

        @muster    = @cmds;
        $anzmuster = $anzcmds;
    }
	
	
    if ( $togglepart[2] ) {
			MSwitch_LOG( $Name, 6,"-> Option 5 ");
	
        $togglepart[2] =~ s/\[//g;
        $togglepart[2] =~ s/\]//g;
        $reading = $togglepart[2];
    }

    my $aktstate;
    if ( $reading eq "MSwitch_Self" or $reading eq "MSwitch_self" ) 
	{
       $aktstate = ReadingsVal( $Name, 'last_toggle_state', 'undef' );
       MSwitch_LOG( $Name, 6, "-> aktueller state des devices: $aktstate L:" . __LINE__ );
    }
    else {
       $aktstate = ReadingsVal( $devicename, $reading, 'undef' );
		MSwitch_LOG( $Name, 6, "-> reading $reading L:" . __LINE__ );
		MSwitch_LOG( $Name, 6, "-> devicename $devicename L:" . __LINE__ );
		MSwitch_LOG( $Name, 6, "-> aktueller state des devices: $aktstate L:" . __LINE__ );
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
	$showevents = MSwitch_checkselectedevent( $hash, "last_toggle_state" );
    readingsSingleUpdate( $hash, "last_toggle_state", $nextcmd, $showevents );
    MSwitch_LOG( $Name, 6, "-> Toggle Rückgabe:\n-> $newcomand \nL:" . __LINE__ );
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

    if ( !defined $aVal ) { $aVal = ""; }

### Debug
    if ( defined $aVal && $aVal ne "" && $aName eq 'MSwitch_Debug' ) {
        if ( ( $aVal == 0 || $aVal == 1 || $aVal == 2 || $aVal == 3 ) ) {
            delete( $hash->{READINGS}{Bulkfrom} );
            delete( $hash->{READINGS}{Device_Affected} );
            delete( $hash->{READINGS}{Device_Affected_Details} );
			delete $data{MSwitch}{$name}{TCond};
            delete( $hash->{READINGS}{Device_Events} );
        }
    }
## statusCounter

    if ( $init_done && $aName eq 'MSwitch_State_Counter' ) {
        readingsDelete( $hash, "last_ON_OFF_switch" );
        readingsDelete( $hash, "off_time" );
        readingsDelete( $hash, "on_time" );
        readingsDelete( $hash, "off_count" );
        readingsDelete( $hash, "on_count" );
        my $timecond = gettimeofday() + 2;
        InternalTimer( $timecond, "MSwitch_Createtimer", $hash );
        return;
    }

## INIT
    if ( $aName eq 'MSwitch_INIT' ) {
        if ( $aVal eq 'save' ) {
            $hash->{MSwitch_Init} = 'fhem.save';
        }

        if ( $aVal eq 'cfg' ) {
            $hash->{MSwitch_Init} = 'fhem.cfg';
        }
        return;
    }

## statistik
    if ( $aName eq 'MSwitch_Statistic' && $aVal eq '1' ) {

        delete( $hash->{helper}{statistics} );
        delete( $hash->{helper}{statistics}{notifyloop_incomming_names} );
        $hash->{helper}{statistics}{sortout_from_grep} = 0;
    }

    if ( $aName eq 'MSwitch_Statistic' && $aVal eq '0' ) {
        delete( $hash->{helper}{statistics} );
        delete( $hash->{helper}{statistics}{notifyloop_incomming_names} );
    }

    # random

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
    if ( $cmd eq 'set' && $aName eq 'MSwitch_Device_Groups' ) {
        delete $data{MSwitch}{$name}{groups};
        fhem("deletereading $name MSGroup_.*");
        my @gset = split( /\n/, $aVal );
        foreach my $line (@gset) {
            my @lineset = split( /->/, $line );
            $data{MSwitch}{$name}{groups}{ $lineset[0] } = $lineset[1];
            my $gruppenname = "MSGroup_$lineset[0]";
            readingsSingleUpdate( $hash, $gruppenname, $lineset[1], 0 );
        }
        return;
    }

## LastState
    if ( $cmd eq 'set' && $aName eq 'MSwitch_lastState' ) {
		my $showevents=0;
		delete $data{MSwitch}{$name}{lastStates};
		fhem("deletereading $name lastState_.*");
		my @Deviceslaststateon;
		my @Deviceslaststateoff;
		my @gset = split( /,/, $aVal );	
        foreach my $line (@gset) {
			my @lineset = split( /:/, $line );
			
			if ( !defined $lineset[3] ){$lineset[3] = "noDyn"};
			if ( $lineset[3] eq "" ){$lineset[3] = "noDyn"};
			if ($lineset[0] == 1){
			$data{MSwitch}{$name}{lastStates}{on}{$lineset[1]}{$lineset[2]}=$lineset[3];
			readingsSingleUpdate( $hash, "lastState_".$lineset[1]."_".$lineset[2], 'undef', $showevents );
			push( @Deviceslaststateon, $lineset[1].":".$lineset[2]  );
			}
			
			if ($lineset[0] == 2){
			$data{MSwitch}{$name}{lastStates}{off}{$lineset[1]}{$lineset[2]}=$lineset[3];
			readingsSingleUpdate( $hash, "lastState_".$lineset[1]."_".$lineset[2], 'undef', $showevents );
			push( @Deviceslaststateoff, $lineset[1].":".$lineset[2]  );
			}
		}
		$data{MSwitch}{$name}{lastStates}{deviceslaststateon}="@Deviceslaststateon";
		$data{MSwitch}{$name}{lastStates}{deviceslaststateoff}="@Deviceslaststateoff";
		return;
	}

## Readings

    if ( $cmd eq 'set' && $aName eq 'MSwitch_Readings' ) {
        delete $data{MSwitch}{$name}{Readings};
        my $readings = $aVal . ",";
        $readings =~ s/\n//g;
        my $x = 0;    # exit
        while ( $readings =~ m/(.*?\})(,)(.*)/ ) {
            $x++;
            last if $x > 10;
            my $first = $1;
            $readings = $3;
            chop $first;
            my ( $key, $inhalt ) = split( /{/, $first );
            $key =~ s/ //g;
            $data{MSwitch}{$name}{Readings}{$key} = $inhalt;
        }
        return;
    }

################################

    if ( $cmd eq 'set' && $aName eq 'MSwitch_EventMap' ) {
        delete $data{MSwitch}{$name}{Eventmap};
        my $evantmaps = $aVal;
        my $trenner   = " ";
        # suche trennzeichen
        if ( $evantmaps =~ m/^([^a-zA_Z])(.*)/ ) {
            $trenner   = $1;
            $evantmaps = $2;
        }
        my @mappaare = split( /$trenner/, $evantmaps );
        for my $paar (@mappaare) {
            $paar =~ s/\\:/[#dp]/g;
            my ( $key, $inhalt ) = split( /:/, $paar, 2 );
            $data{MSwitch}{$name}{Eventmap}{$key} = $inhalt;
        }
        return;
    }

###################################

## EventWait
    if ( $cmd eq 'set' && $aName eq 'MSwitch_Event_Wait' ) {
        delete $data{MSwitch}{$name}{eventwait};
        my @gset = split( /\n/, $aVal );
        foreach my $line (@gset) {
            my @lineset = split( /->/, $line );
            my @testwild = split( /:/, $lineset[0] );
            if ( $testwild[2] =~ m/^\.\*..*/s ) {
                # teile lineset
                my @linesetparts = split( /:/, $lineset[0] );
                my $linepart = $linesetparts[0] . ":" . $linesetparts[1];
                $testwild[2] =~ s/\.\*//g;
                $testwild[2] =~ s/\[//g;
                $testwild[2] =~ s/]//g;
                $data{MSwitch}{$name}{eventwaitwild}{$linepart}{ $testwild[2] }
                  = $lineset[1];
                next;
            }
            $data{MSwitch}{$name}{eventwait}{ $lineset[0] } = $lineset[1];
        }
        return;
    }

    if ( $cmd eq 'del' && $aName eq 'MSwitch_Event_Wait' ) {
        delete $data{MSwitch}{$name}{eventwait};
        return;
    }

## SysExtension
    if ( $cmd eq 'set' && $aName eq 'MSwitch_SysExtension' ) {
        if ( $aVal == 0 ) {
            delete $data{MSwitch}{$name}{activeWidgets};
        }
        if ( $aVal == 1 || $aVal == 2 ) {
            MSwitch_defineWidgets($hash);
        }
    }

## DeleteCMDs
    if ( $cmd eq 'set' && $aName eq 'MSwitch_DeleteCMDs' ) {
        delete $data{MSwitch}{devicecmds1};
        delete $data{MSwitch}{last_devicecmd_save};
    }

## Snippet
    if ( $cmd eq 'set' && $aName eq 'MSwitch_Snippet' ) {
        delete $data{MSwitch}{$name}{snippet};
        my @snips = split( /\n/, $aVal );
        my $aktsnippetnumber;
        my $aktsnippet = "";
        foreach my $line (@snips) {
			
            #if ( $line =~ m/^\[Snippet:([\d]{1,3})\]$/ ) 
			
			if ( $line =~ m/^\[Snippet:(.*?)\]$/ ) 
			{
                $aktsnippet       = "";
                $aktsnippetnumber = $1;
                next;
            }
            $data{MSwitch}{$name}{snippet}{$aktsnippetnumber} .= $line . "\n";
        }
        return;
    }
	
### selected events
   if ( $cmd eq 'set' && $aName eq 'MSwitch_generate_Events_selected' ) {

	delete( $hash->{helper}{selectedevents} );
	my @evlist = split( /,/, $aVal );
	foreach my $line (@evlist) {
		$hash->{helper}{selectedevents}{$line}=1;
	}	
   }
	

## Event Counter
    if ( $cmd eq 'set' && $aName eq 'MSwitch_Reset_EVT_CMD1_COUNT' ) {
		
		
		
		my $showevents = MSwitch_checkselectedevent( $hash, "EVT_CMD1_COUNT" );
        readingsSingleUpdate( $hash, "EVT_CMD1_COUNT", 0, $showevents );
    }
    if ( $cmd eq 'set' && $aName eq 'MSwitch_Reset_EVT_CMD2_COUNT' ) {
		my $showevents = MSwitch_checkselectedevent( $hash, "EVT_CMD2_COUNT" );
        readingsSingleUpdate( $hash, "EVT_CMD2_COUNT", 0, $showevents );
    }

## disable
    if ( $cmd eq 'set' && $aName eq 'disable' && $aVal == 1 ) {
        $hash->{NOTIFYDEV} = 'no_trigger';
        MSwitch_Delete_Delay( $hash, 'all' );
        MSwitch_Clear_timer($hash);
    }

    if ( $cmd eq 'set' && $aName eq 'disable' && $aVal == 0 ) {
        delete( $hash->{helper}{savemodeblock} );
        delete( $hash->{READINGS}{Safemode} );
        MSwitch_Createtimer($hash);

        if ( ReadingsVal( $name, '.Trigger_device', 'no_trigger' ) ne
            'no_trigger'
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
        return;
    }

## Mswitch CMDs

    if ( $aName eq 'MSwitch_Activate_MSwitchcmds' && $aVal == 1 ) {
        addToAttrList('MSwitchcmd');
    }

## Debug
    if ( defined $aVal && $aName eq 'MSwitch_Debug' && $aVal eq '0' ) {
		 my $pfad =  AttrVal( 'global', 'logdir', './log/' ) ;
			unlink($pfad."/MSwitch_debug_$name.log");

    }

    if ( defined $aVal
        && ( $aName eq 'MSwitch_Debug' && ( $aVal eq '2' || $aVal eq '3' ) ) )
    {
        MSwitch_clearlog($hash);
    }

############ FULL / TOGGLE

    if ( $init_done && $aName eq 'MSwitch_Mode' ) {
        readingsDelete( $hash, "last_ON_OFF_switch" );
        readingsDelete( $hash, "off_time" );
        readingsDelete( $hash, "on_time" );
        readingsDelete( $hash, "off_count" );
        readingsDelete( $hash, "on_count" );
    }

    if ( $aName eq 'MSwitch_Mode' && ( $aVal eq 'Full' || $aVal eq 'Toggle' ) )
    {
        delete( $hash->{helper}{config} );
        my $cs = "setstate $name ???";
        my $errors = AnalyzeCommandChain( undef, $cs );
        $hash->{MODEL} = 'Full' . " " . $version   if $aVal eq 'Full';
        $hash->{MODEL} = 'Toggle' . " " . $version if $aVal eq 'Toggle';
        setDevAttrList( $name, $attrresetlist );
        if ($init_done) {
            if ( ReadingsVal( $name, '.Trigger_device', '' ) ne '' ) {
                $hash->{NOTIFYDEV} =
                  ReadingsVal( $name, '.Trigger_device', '' );
            }
            else {
                $hash->{NOTIFYDEV} = 'no_trigger';
            }
        }
        else {
            $hash->{NOTIFYDEV} = 'global';
        }
    }

############ DUMMY ohne  Selftrigger

    if (   $init_done
        && $aName eq 'MSwitch_Selftrigger_always'
        && AttrVal( $name, 'MSwitch_Mode', '' ) eq "Dummy" )
    {
        if ( $aVal eq '1' ) {
            setDevAttrList( $name, $attractivedummy );
        }

        if ( $aVal eq '0' ) {
            fhem("deleteattr $name MSwitch_Include_Webcmds");
            fhem("deleteattr $name MSwitch_Include_MSwitchcmds");
            fhem("deleteattr $name MSwitch_Include_Devicecmds");
            fhem("deleteattr $name MSwitch_Safemode");
            fhem("deleteattr $name MSwitch_Extensions");
            fhem("deleteattr $name MSwitch_Lock_Quickedit");
            fhem("deleteattr $name MSwitch_Delete_Delays");
            fhem("deleteattr $name MSwitch_Debug");
            fhem("deleteattr $name MSwitch_Eventhistory");
            fhem("deleteattr $name MSwitch_Ignore_Types");

            delete( $hash->{MSwitch_Eventsave} );
            delete( $hash->{NOTIFYDEV} );
            delete( $hash->{NTFY_ORDER} );

            my $delete = ".Trigger_device";
			
            delete( $hash->{READINGS}{$delete} );
           # delete( $hash->{MSwitch_IncommingHandle} );
            delete( $hash->{READINGS}{EVENT} );
            delete( $hash->{READINGS}{EVTFULL} );
            delete( $hash->{READINGS}{EVTPART1} );
            delete( $hash->{READINGS}{EVTPART2} );
            delete( $hash->{READINGS}{EVTPART3} );
            delete( $hash->{READINGS}{last_event} );
            delete( $hash->{READINGS}{last_exec_cmd} );
            delete( $hash->{READINGS}{last_cmd} );
            delete( $hash->{READINGS}{MSwitch_generate_Events} );
            setDevAttrList( $name, $attrdummy );
        }

        if ($init_done) {
            $hash->{NOTIFYDEV} = 'no_trigger';
        }
        else {
            $hash->{NOTIFYDEV} = 'global';
        }
        return;
    }

############ DUMMY ohne  Selftrigger
    if ( $aName eq 'MSwitch_Mode' && ( $aVal eq 'Dummy' ) ) {
        delete( $hash->{helper}{config} );
        MSwitch_Delete_Delay( $hash, 'all' );
        MSwitch_Clear_timer($hash);
        $hash->{MODEL} = 'Dummy' . " " . $version;
        $hash->{DEF}   = $name;

        my $delete = ".Trigger_device";
        delete( $hash->{READINGS}{$delete} );
        if ($init_done) {
            fhem("deleteattr $name MSwitch_Include_Webcmds");
            fhem("deleteattr $name MSwitch_Include_MSwitchcmds");
            fhem("deleteattr $name MSwitch_Include_Devicecmds");
            fhem("deleteattr $name MSwitch_Safemode");
            fhem("deleteattr $name MSwitch_Extensions");
            fhem("deleteattr $name MSwitch_Lock_Quickedit");
            fhem("deleteattr $name MSwitch_Delete_Delays");
            fhem("deleteattr $name MSwitch_Debug");
            fhem("deleteattr $name MSwitch_Eventhistory");
            fhem("deleteattr $name MSwitch_Ignore_Types");

            delete( $hash->{MSwitch_Eventsave} );
            delete( $hash->{NTFY_ORDER} );
           # delete( $hash->{MSwitch_IncommingHandle} );
            delete( $hash->{READINGS}{EVENT} );
            delete( $hash->{READINGS}{EVTFULL} );
            delete( $hash->{READINGS}{EVTPART1} );
            delete( $hash->{READINGS}{EVTPART2} );
            delete( $hash->{READINGS}{EVTPART3} );
            delete( $hash->{READINGS}{last_event} );
            delete( $hash->{READINGS}{last_exec_cmd} );
            delete( $hash->{READINGS}{last_cmd} );
            delete( $hash->{READINGS}{MSwitch_generate_Events} );

            if ( AttrVal( $name, 'MSwitch_Selftrigger_always', 0 ) > 0 ) {
                setDevAttrList( $name, $attractivedummy );
            }
            else {
                setDevAttrList( $name, $attrdummy );
            }

            if ($init_done) {
                $hash->{NOTIFYDEV} = 'no_trigger';
            }
            else {
                $hash->{NOTIFYDEV} = 'global';
            }
        }
        return;
    }

############### Notify
    if ( $aName eq 'MSwitch_Mode' && $aVal eq 'Notify' ) {
        $hash->{MODEL} = 'Notify' . " " . $version;
        my $cs = "setstate $name active";
        my $errors = AnalyzeCommandChain( undef, $cs );
        if ( defined($errors) ) {
            MSwitch_LOG( $name, 1,"$name MSwitch_Notify: Fehler bei Befehlsausführung $errors -> Comand: $_ ". __LINE__ );
        }
        setDevAttrList( $name, $attrresetlist );
        $hash->{MODEL} = 'Notify' . " " . $version;
        setDevAttrList( $name, $attrresetlist );
        if ($init_done) {
            if ( ReadingsVal( $name, '.Trigger_device', '' ) ne '' ) {
                $hash->{NOTIFYDEV} =
                  ReadingsVal( $name, '.Trigger_device', '' );
            }
            else {
                $hash->{NOTIFYDEV} = 'no_trigger';
            }
        }
        else {
            $hash->{NOTIFYDEV} = 'global';
        }
    }

## ATTR DELETE FUNKTOIONEN

    if ( $cmd eq 'del' ) {
		
		my $testarg = $aName;	
		if ( $testarg eq 'MSwitch_lastState' ) {
			
		delete $data{MSwitch}{$name}{lastStates};
		fhem("deletereading $name lastState_.*");
	}
	
	
		if ( $testarg eq 'MSwitch_generate_Events_selected' ) {
		delete( $hash->{helper}{selectedevents} );
		}

        if ( $testarg eq 'MSwitch_Device_Groups' ){
            delete $data{MSwitch}{$name}{groups};
            fhem("deletereading $name MSGroup_.*");
            return;
        }

        if ( $testarg eq 'MSwitch_Statistic' ) {
            delete( $hash->{helper}{statistics} );
            delete( $hash->{helper}{statistics}{notifyloop_incomming_names} );
        }

        if ( $testarg eq 'MSwitch_Readings' ) {
            my $keyhash = $data{MSwitch}{$name}{Readings};
            foreach my $reading ( keys %{$keyhash} ) {
                my ( $delete, $notused ) = split( /\:/, $reading );
                delete $data{MSwitch}{$name}{Readings}{$delete};
                delete( $hash->{READINGS}{$reading} );
            }
            return;
        }

        if ( $testarg eq 'MSwitch_EventMap' ) {
            delete( $hash->{READINGS}{EVENT_ORG} );
            delete $data{MSwitch}{$name}{Eventmap};
            return;
        }

        if ( $testarg eq 'disable' ) {
            MSwitch_Delete_Delay( $hash, "all" );
            MSwitch_Clear_timer($hash);
            delete( $hash->{helper}{savemodeblock} );
            delete( $hash->{READINGS}{Safemode} );
            MSwitch_Createtimer($hash);
            if ( ReadingsVal( $name, '.Trigger_device', 'no_trigger' ) ne
                'no_trigger'
                and ReadingsVal( $name, '.Trigger_device', 'no_trigger' ) ne
                "MSwitch_Self" ){
                $hash->{NOTIFYDEV} =
                  ReadingsVal( $name, '.Trigger_device', 'no_trigger' );
            }

            if ( $init_done == 1
                and ReadingsVal( $name, '.Trigger_device', 'no_trigger' ) eq
                "MSwitch_Self" ){
                $hash->{NOTIFYDEV} = $name;
            }
            return;
        }

        if ( $testarg eq 'MSwitch_SysExtension' ) {
            delete $data{MSwitch}{$name}{activeWidgets};
            return;
        }

        if ( $testarg eq 'MSwitch_Reset_EVT_CMD1_COUNT' ) {
            delete( $hash->{READINGS}{EVT_CMD1_COUNT} );
            return;
        }

        if ( $testarg eq 'MSwitch_Reset_EVT_CMD2_COUNT' ) {
            delete( $hash->{READINGS}{EVT_CMD2_COUNT} );
            return;
        }

        if ( $testarg eq 'MSwitch_DeleteCMDs' ) {
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
    foreach my $a ( sort keys %{$inhalt} ) {
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
    foreach my $a ( sort keys %{$inhalt} ) {
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
sub MSwitch_Check_AVG($@) {
    my ( $hash, $name ) = @_;
    my @avg = split( /,/, AttrVal( $name, "MSwitch_Func_AVG", 'undef' ) );
    my $showevents = AttrVal( $name, "MSwitch_generate_Events", 0 );
    if ( AttrVal( $name, 'MSwitch_Debug', '0' ) ne "0" ) { $showevents = 1 }
	AVG: foreach my $aktavg (@avg) {
        my ( $aktname, $aktwert, $reading ) = split( /->/, $aktavg );
        my $aktevent = $hash->{helper}{evtparts}{evtpart2};
        next AVG if $aktname ne $aktevent;
        my $history   = $hash->{helper}{eventhistory}{$aktname};
        my @checkwert = split( / /, $history );
        my $sum       = 0;
        for ( my $i = 0 ; $i < $aktwert ; $i++ ) {
            if ( !defined $checkwert[$i] ) { $checkwert[$i] = 0; }
            $sum = $sum + $checkwert[$i];
        }
        my $mittelwert = $sum / $aktwert;
		
		MSwitch_checkselectedevent( $hash, $mittelwert );
		$showevents = MSwitch_checkselectedevent( $hash, $reading );

        readingsSingleUpdate( $hash, $reading, $mittelwert, $showevents );
    }
    return;
}
#################################
sub MSwitch_Check_TEND($@) {
    my ( $hash, $name ) = @_;
    my @tend = split( /,/, AttrVal( $name, "MSwitch_Func_TEND", 'undef' ) );
    my $showevents = AttrVal( $name, "MSwitch_generate_Events", 0 );
    if ( AttrVal( $name, 'MSwitch_Debug', '0' ) ne "0" ) { $showevents = 1 }
  TEND: foreach my $akttend (@tend) {
        my ( $aktname, $aktwert, $alert, $reading, $maxcheck ) =
          split( /->/, $akttend );
        if ( !defined $maxcheck ) { $maxcheck = 0; }
        my $lastreading =
          ReadingsVal( $name, $reading . '_change', 'no_change' );
        my $aktevent = $hash->{helper}{evtparts}{evtpart2};
        next TEND if $aktname ne $aktevent;
        my $anzahl  = $aktwert;      # anzahl der getesteten events aus historia
        my $anzahl1 = $aktwert * 2;  # anzahl der getesteten events aus historia
        my $history = $hash->{helper}{eventhistory}{$aktname};
        my @checkwert = split( / /, $history );
        next TEND if @checkwert < $anzahl1;
        my $wert1 = 0;
        my $wert2 = 0;
        my $count = 0;

        foreach (@checkwert) {
            last if $count >= $anzahl1;
            $wert1 = $wert1 + $_ if $count < $anzahl;
            $wert2 = $wert2 + $_ if $count >= $anzahl;
            $count++;
        }

        $wert1 = $wert1 / $anzahl;
        $wert2 = $wert2 / $anzahl;
        my $tendenzwert        = $wert1 - $wert2;
        my $tendenzwertabsolut = abs($tendenzwert);
        my $direction          = "no_change";
        if ( $tendenzwert < 0 ) {
            $direction = "down";
        }
        if ( $tendenzwert > 0 ) {
            $direction = "up";
        }

        #############################################################
        #prüfe einzelwert
        if ( $tendenzwertabsolut >= $alert && $direction ne $lastreading ) {

            # änderung erkannt
			
			$showevents = MSwitch_checkselectedevent( $hash, $reading . "_change" );
            readingsSingleUpdate( $hash, $reading . '_change',
                'changed', $showevents );
			$showevents = MSwitch_checkselectedevent( $hash, $reading . "_direction_tendenz" );	
            readingsSingleUpdate( $hash, $reading . '_direction_tendenz',
                $direction, $showevents );
			$showevents = MSwitch_checkselectedevent( $hash, $reading . "_direction_real" );		
            readingsSingleUpdate( $hash, $reading . '_direction_real',
                $direction, $showevents );
			$showevents = MSwitch_checkselectedevent( $hash, $reading . "_direction_value" );		
	
            readingsSingleUpdate( $hash, $reading . '_direction_value',
                $tendenzwert, $showevents );

            # setze max/min wert auf aktuellen wert wenn geschaltet
			
			$showevents = MSwitch_checkselectedevent( $hash, $reading . "_max" );		
            readingsSingleUpdate( $hash, "." . $reading . '_max', $wert1, $showevents );
			$showevents = MSwitch_checkselectedevent( $hash, $reading . "_min" );		
            readingsSingleUpdate( $hash, "." . $reading . '_min', $wert1, $showevents );
            next TEND;
        }

        ######################
        # prüfe maximalwert
        if ( $maxcheck > 0 ) {
            my $max = ReadingsVal( $name, "." . $reading . '_max', 'undef' );
            my $min = ReadingsVal( $name, "." . $reading . '_min', 'undef' );

            #init readings für max/min
				
			$showevents = MSwitch_checkselectedevent( $hash, $reading . "_max" );
            readingsSingleUpdate( $hash, "." . $reading . '_max', $wert1, $showevents )
              if $max eq "undef";
			  $showevents = MSwitch_checkselectedevent( $hash, $reading . "_min" );
            readingsSingleUpdate( $hash, "." . $reading . '_min', $wert1, $showevents )
              if $min eq "undef";
			  
            $max = $wert1 if $max eq "undef";
            $min = $wert1 if $min eq "undef";
            ###
            if ( $wert1 > $max ) {
				$showevents = MSwitch_checkselectedevent( $hash, $reading . "_max" );
                readingsSingleUpdate( $hash, "." . $reading . '_max',
                    $wert1, $showevents );
            }
            if ( $wert1 < $min ) {
				$showevents = MSwitch_checkselectedevent( $hash, $reading . "_min" );
                readingsSingleUpdate( $hash, "." . $reading . '_min',
                    $wert1, $showevents );
            }

            # real fallend setze vergleichswert auf grössten realwert
            # real steigend setze vergleichswert auf kleinsten realwert
            # wenn überhaupt definiert
            # wert2 muss angepasst werden wenn .....

            if ( $direction eq "down" ) {
                $wert2 = $max if $max > $wert2;
            }
            if ( $direction eq "up" ) {
                $wert2 = $min if $min < $wert2;
            }
            $tendenzwert        = $wert1 - $wert2;
            $tendenzwertabsolut = abs($tendenzwert);
            $direction          = "no_change";
            if ( $tendenzwert < 0 ) {
                $direction = "down";
            }
            if ( $tendenzwert > 0 ) {
                $direction = "up";
            }

            if ( $tendenzwertabsolut >= $alert && $direction ne $lastreading ) {

                # änderung erkannt
				
				$showevents = MSwitch_checkselectedevent( $hash, $reading . '_change');
                readingsSingleUpdate( $hash, $reading . '_change', 'changed', $showevents );
				$showevents = MSwitch_checkselectedevent( $hash, $reading . '_direction_tendenz');
                readingsSingleUpdate( $hash, $reading . '_direction_tendenz', $direction, $showevents );
				$showevents = MSwitch_checkselectedevent( $hash, $reading . '_direction_real');
                readingsSingleUpdate( $hash, $reading . '_direction_real',$direction, $showevents );
				$showevents = MSwitch_checkselectedevent( $hash, $reading . '_direction_value');
                readingsSingleUpdate( $hash, $reading . '_direction_value', $tendenzwert, $showevents );
                # setze max/min wert auf aktuellen wert wenn geschaltet
                readingsSingleUpdate( $hash, "." . $reading . '_max',$wert1, 0 );
                readingsSingleUpdate( $hash, "." . $reading . '_min', $wert1, 0 );
                next TEND;
            }
        }

        ########################
        if ( $tendenzwertabsolut < $alert ) {

            # keine änderung / kein alarm
			$showevents = MSwitch_checkselectedevent( $hash, $reading . '_direction_change');

            readingsSingleUpdate( $hash, $reading . '_change',
                'no_change', $showevents );
				
			$showevents = MSwitch_checkselectedevent( $hash, $reading . '_direction_real');
	
            readingsSingleUpdate( $hash, $reading . '_direction_real',
                $direction, $showevents );
				
			$showevents = MSwitch_checkselectedevent( $hash, $reading . '_direction_value');

            readingsSingleUpdate( $hash, $reading . '_direction_value',
                $tendenzwert, $showevents );
        }
    }
    return;
}
###############################
sub MSwitch_Check_DIFF($@) {
    my ( $hash, $name ) = @_;
    my @diff = split( /,/, AttrVal( $name, "MSwitch_Func_DIFF", 'undef' ) );
    my $showevents = AttrVal( $name, "MSwitch_generate_Events", 0 );
    if ( AttrVal( $name, 'MSwitch_Debug', '0' ) ne "0" ) { $showevents = 1 }
  DIFF: foreach my $aktavg (@diff) {
        my ( $aktname, $aktwert, $reading ) = split( /->/, $aktavg );
        my $aktevent = $hash->{helper}{evtparts}{evtpart2};
        next DIFF if $aktname ne $aktevent;
        my $vergloperand = $aktwert;
        my $history      = $hash->{helper}{eventhistory}{$aktname};
        my @checkwert = split( / /, $history );
        my $index = $vergloperand;
        next if !defined $checkwert[$index];
        my $diff = ( $checkwert[0] - $checkwert[$index] );
		
		$showevents = MSwitch_checkselectedevent( $hash, $reading );
        readingsSingleUpdate( $hash, $reading, $diff, $showevents );
    }
    return;
}

###############################

sub MSwitch_Initcheck() {

    # prüfe debug
    my $startmessage = "";
    my @debugging_devices =
      devspec2array("TYPE=MSwitch:FILTER=MSwitch_Debug=2||3");
    my @restore_devices = devspec2array("TYPE=MSwitch");

    $startmessage .=
        "     -> Es sind "
      . @restore_devices
      . " Mswitchdefinitionen vorhanden, teste Definitionen... \n";

    if ( @debugging_devices > 0 ) {
        $startmessage .=
"!!!  -> Erhoehte Systembelastung festgestellt, folgende Geraete befinden sich im Debugmode 2 oder 3: \n";
        for my $name (@debugging_devices) {
            $startmessage .= "     ->    $name \n";
        }
        $startmessage .=
"     -> Die empfohlene Einstellung im Normalbetrieb lautet MSwitch_Debug 0 oder 1  \n";
    }
    $data{MSwitch}{warning}{debug} = "Debug_Warning";
    $startmessage .= "     -> initializing MSwitch-Devices ready \n";
    MSwitch_LOG( "MSwitch", 5,"Messages collected while initializing MSwitch-Devices:\n$startmessage"
    );
    $data{MSwitch}{startmessage} .= $startmessage;
    return;
}

################################

sub MSwitch_setdata(@) {

    my ( $hash, $name ) = @_;
    my $setdatahash = $data{MSwitch}{$name}{setdata};
    my $showevents = AttrVal( $name, "MSwitch_generate_Events", 0 );
	
	
	
	# updateänderung
	
    readingsBeginUpdate($hash);
    foreach my $key ( keys %{$setdatahash} ) {
		$showevents = MSwitch_checkselectedevent( $hash, $key, );
		readingsBulkUpdate( $hash, $key, $data{MSwitch}{$name}{setdata}{$key} ,$showevents);
    }
	
	readingsEndUpdate( $hash, 1 );
    delete $data{MSwitch}{$name}{setdata};
    return;
}

################################

sub MSwitch_Notify($$) {
    my $testtoggle = '';
    my ( $own_hash, $dev_hash ) = @_;
    my $ownName = $own_hash->{NAME};    # own name / hash
    my $devName;
    $devName = $dev_hash->{NAME};
    my $devType   = $dev_hash->{TYPE};
    my $events    = deviceEvents( $dev_hash, 1 );
    my $statistic = 0;

    return if !$devName;

    delete $data{MSwitch}{$ownName}{setdata};

    if ( exists $data{MSwitch}{runningbackup}
        && $data{MSwitch}{runningbackup} eq "ja" )
    {
        return;
    }

    if ( AttrVal( $ownName, 'MSwitch_Statistic', "0" ) == 1 ) { $statistic = 1 }

    if ( grep( m/EVENT|EVTFULL|writelog|last_exec_cmd|EVTPART.*/, @{$events} ) )
    {
        MSwitch_LOG( $ownName, 5, "hard exit ..." );
        MSwitch_LOG( $ownName, 5, "$ownName - $devName " );
        MSwitch_LOG( $ownName, 5, " - @{$events}" );
        return;
    }

### checke auf aktive wizard
    if ( exists $own_hash->{helper}{mode}
        and $own_hash->{helper}{mode} eq "absorb" )
    {
        if (
            time > $own_hash->{helper}{modesince} +
            $wizardreset )    # time bis wizardreset
        {
            delete( $own_hash->{helper}{mode} );
            delete( $own_hash->{helper}{modesince} );
            delete( $own_hash->{NOTIFYDEV} );
            delete( $own_hash->{READINGS} );
            readingsBeginUpdate($own_hash);
            readingsBulkUpdate( $own_hash, ".Device_Events", "no_trigger", 0 );
            readingsBulkUpdate( $own_hash, ".Trigger_cmd_off", "no_trigger",0 );
            readingsBulkUpdate( $own_hash, ".Trigger_cmd_on", "no_trigger", 0 );
            readingsBulkUpdate( $own_hash, ".Trigger_off",    "no_trigger", 0 );
            readingsBulkUpdate( $own_hash, ".Trigger_on",     "no_trigger", 0 );
            readingsBulkUpdate( $own_hash, ".Trigger_device", "no_trigger", 0 );
            readingsBulkUpdate( $own_hash, ".Trigger_log",    "off",        0 );
            readingsBulkUpdate( $own_hash, ".V_Check",        $vupdate,     0 );
            readingsBulkUpdate( $own_hash, ".First_init",     'done' );
            readingsEndUpdate( $own_hash, 0 );
            return;
        }

        my @eventscopy = ( @{$events} );
        my @newarray;

        foreach my $event (@eventscopy) {
            $event =~ s/ //g;
            $event = $devName . ":" . $event;
            push( @newarray, $event );
        }
        my $eventcopy = join( " ", @newarray );
		my $showevents = MSwitch_checkselectedevent( $own_hash, "EVENTCONF" );		
        readingsSingleUpdate( $own_hash, "EVENTCONF", "$eventcopy", $showevents );
        return;
    }

    # ende wenn wizard aktiv
###############################
    # prüfe debugmodes 	meldungen absetzen
    if ( !exists $data{MSwitch}{warning}{debug} ) {
        MSwitch_Initcheck();
    }
###############################

    # jede aktion für eigenes debug abbrechen
    if ( $devName eq $ownName && grep( m/.*Debug|clearlog.*/, @{$events} ) ) {
        return;
    }

    # events blocken wenn datensatz unvollständig
    if ( ReadingsVal( $ownName, '.First_init', 'undef' ) ne 'done' ) {
        return;
    }

    # setze devicename auf Logfile, wenn LogNotify aktiv
    if (   $own_hash->{helper}{testevent_device}
        && $own_hash->{helper}{testevent_device} eq 'Logfile' )
    {
        $devName = 'Logfile';
    }

    my $trigevent      = '';
    my $execids        = "0";
    my $foundcmd1      = 0;
    my $foundcmd2      = 0;
    my $foundcmdbridge = 0;
    my $activecount    = 0;
    my $anzahl;
    my $mswait = AttrVal( $ownName, "MSwitch_Wait", 0 );

	if ( $mswait =~ m/\[(.*)\:(.*)\]/ ) 
	{
		$mswait = MSwitch_check_setmagic_i( $own_hash, $mswait );
	}
    my $showevents = AttrVal( $ownName, "MSwitch_generate_Events", 0 );
    if ( AttrVal( $ownName, 'MSwitch_Debug', '0' ) ne "0" ) { $showevents = 1 }

    my $evhistory = AttrVal( $ownName, "MSwitch_Eventhistory",         10 );
    my $resetcmd1 = AttrVal( $ownName, "MSwitch_Reset_EVT_CMD1_COUNT", 0 );
    my $resetcmd2 = AttrVal( $ownName, "MSwitch_Reset_EVT_CMD2_COUNT", 0 );
    my $devicemode = AttrVal( $ownName, 'MSwitch_Mode',  'Notify' );
    my $debugmode  = AttrVal( $ownName, 'MSwitch_Debug', "0" );
    my $startdelay = AttrVal( $ownName, 'MSwitch_Startdelay', $standartstartdelay );
    my $attrrandomnumber = AttrVal( $ownName, 'MSwitch_RandomNumber', '' );
    my $incommingdevice = '';
    my $triggerdevice = ReadingsVal( $ownName, '.Trigger_device', '' );    # Triggerdevice
    my @cmdarray;
    my @cmdarray1;    # enthält auszuführende befehle nach conditiontest
    my $sequenztime = AttrVal( $ownName, 'MSwitch_Sequenz_time', 5 );
    my $triggerlog       = ReadingsVal( $ownName, '.Trigger_log',       'off' );
    my $triggeron        = ReadingsVal( $ownName, '.Trigger_on',        '' );
    my $triggeroff       = ReadingsVal( $ownName, '.Trigger_off',       '' );
    my $triggercmdon     = ReadingsVal( $ownName, '.Trigger_cmd_on',    '' );
    my $triggercmdoff    = ReadingsVal( $ownName, '.Trigger_cmd_off',   '' );	
	my $triggercondition = MSwitch_Load_Tcond($own_hash);
    my $set       = "noset";
    my $eventcopy = "";
    my @eventscopy;
    MSwitch_del_savedcmds($own_hash);

    # aktualisiere statecounter

    if ( $devicemode ne "Notify" ) {
        my $oldstate = ReadingsVal( $ownName, "state", 'undef' );
        my $virtcmd = $oldstate;
        MSwitch_Set_Statecounter( $ownName, $oldstate, $virtcmd );
    }

    # nur abfragen für eigenes Notify

    if (   $init_done
        && $devName eq "global"
        && grep( m/^MODIFIED $ownName$/, @{$events} ) )
    {
        # reaktion auf eigenes notify start / define / modify
        my $timecond = gettimeofday() + 1;
        InternalTimer( $timecond, "MSwitch_LoadHelper", $own_hash );

    }

    if (   $init_done
        && $devName eq "global"
        && grep( m/^DEFINED $ownName$/, @{$events} ) )
    {
        # reaktion auf eigenes notify start / define / modify
        my $timecond = gettimeofday() + 1;
        InternalTimer( $timecond, "MSwitch_LoadHelper", $own_hash );
    }
############################################
    if ( $devName eq "global"
        && grep( m/^INITIALIZED|REREADCFG$/, @{$events} ) )
    {
        # reaktion auf eigenes notify start / define / modify
        # setze globale einstellungen
        if ( ReadingsVal( $ownName, '.msconfig', 0 ) eq "1" ) {
            $configdevice = $ownName;
        }

        # versionscheck
        if ( ReadingsVal( $ownName, '.V_Check', $vupdate ) ne $vupdate ) {
            my $ver = ReadingsVal( $ownName, '.V_Check', '' );
            MSwitch_LOG( $ownName, 1,"$ownName -> Event blockiert, NOTIFYDEV deaktiviert - Versionskonflikt L:" . __LINE__ );
            $own_hash->{NOTIFYDEV} = 'no_trigger';
        }
        MSwitch_LoadHelper($own_hash);
    }

# nur abfragen für eigenes Notify ENDE
#########################################
# Return without any further action if the module is disabled

    return "" if ( IsDisabled($ownName) );
    if ( $init_done != 1 ) {
        return;
    }
    $own_hash->{helper}{statistics}{starttime} = time
    if !exists $own_hash->{helper}{statistics}{starttime};

    # abbruch wenn selbsttrigger nicht aktiv
    if ( AttrVal( $ownName, "MSwitch_Selftrigger_always", 0 ) == 0 ) {
        #abbruch wenn kein trigger angegeben
        return
          if ( ReadingsVal( $ownName, ".Trigger_device", "no_trigger" ) eq
            'no_trigger' );
        return
          if ( !$own_hash->{NOTIFYDEV}
            && ReadingsVal( $ownName, '.Trigger_device', 'no_trigger' ) ne
            "all_events" );

        #abbruch wenn GLOBAL und eigenes device
        return
          if ( ReadingsVal( $ownName, ".Trigger_device", "no_trigger" ) eq
            "all_events" and $ownName eq $devName );
    }
######################################

    # startverzögerung abwarten
    my $diff = int(time) - $fhem_started;
    if ( $diff < $startdelay && $startdelay > 0 ) {
        $own_hash->{helper}{statistics}{notifyloop_startdelay_blocked}++
          if $statistic == 1;    #statistik

        MSwitch_LOG( $ownName, 6,"-> Event blockiert - Startverzögerung $diff " );
        return;
    }
	
	
############################

    if ( $statistic == 1 ) {
        $own_hash->{helper}{statistics}{notifyloop_incomming}++;
        $own_hash->{helper}{statistics}{notifyloop_incomming_names}{$devName}++;
        $own_hash->{helper}{statistics}{notifyloop_incomming_types}{$devType}++;
        my $starttime = $own_hash->{helper}{statistics}{starttime};
        my $akttime   = time;

        if ( $akttime - ( $starttime + 60 ) < 0 ) {
            $own_hash->{helper}{statistics}{notifyloop_incomming_firstminute}++;
        }
    }

#############################
    # test wait attribut
    if ( ReadingsVal( $ownName, "waiting", '0' ) > time ) {
        MSwitch_LOG( $ownName, 6, "-> Event blockiert - Wait gesetzt " . ReadingsVal( $ownName, "waiting", '0' ) . " " );
        # teste auf attr waiting verlesse wenn gesetzt
        $own_hash->{helper}{statistics}{notifyloop_wait_blocked}++
          if $statistic == 1;    #statistik
        return "";
    }
    else {
        delete( $own_hash->{READINGS}{waiting} );
    }
############################  notifyloop_firsttest_passed

    MSwitch_Safemode($own_hash);
    # abbruch wenn nicht logfile
    if ( !$events && $own_hash->{helper}{testevent_device} ne 'Logfile' ) {
        return;
    }

################# ggf umsetzen - nach akzeptierten events
    if ( $attrrandomnumber ne '' ) {
        # create randomnumber wenn attr an
        MSwitch_Createnumber1($own_hash);
    }

#######################################

    if ( $devicemode eq "Notify" ) {
        # passt triggerfelder an attr an
        $triggeron  = 'no_trigger';
        $triggeroff = 'no_trigger';
    }

    if ( $devicemode eq "Toggle" ) {
        # passt triggerfelder an attr an
        $triggeroff    = 'no_trigger';
        $triggercmdon  = 'no_trigger';
        $triggercmdoff = 'no_trigger';
    }

## notify für eigenes device
## übernahme event und device aus der testeventfunktion

    if ( defined( $own_hash->{helper}{testevent_event} ) ) {
        @eventscopy = "$own_hash->{helper}{testevent_event}";
    }
    else {
        @eventscopy = ( @{$events} );
    }
	
###################################
### lösche cmd counter

    if ( $resetcmd1 > 0
        && ReadingsVal( $ownName, 'EVT_CMD1_COUNT', '0' ) >= $resetcmd1 )
    {
		
		$showevents = MSwitch_checkselectedevent( $own_hash, "EVT_CMD1_COUNT" );		
        readingsSingleUpdate( $own_hash, "EVT_CMD1_COUNT", 0, $showevents );
    }
    if ( $resetcmd2 > 0
        && ReadingsVal( $ownName, 'EVT_CMD2_COUNT', '0' ) >= $resetcmd1 )
    {
		$showevents = MSwitch_checkselectedevent( $own_hash, "EVT_CMD2_COUNT" );		
        readingsSingleUpdate( $own_hash, "EVT_CMD2_COUNT", 0, $showevents );
    }
	
#####################
#### alte sequenzen löschen

    my $sequenzarrayfull = AttrVal( $ownName, 'MSwitch_Sequenz', 'undef' );
    my @sequenzall = split( /\//, $sequenzarrayfull );
    my @sequenzarrayfull = split( / /, $sequenzarrayfull );
    $sequenzarrayfull =~ s/\// /g;
    my @sequenzarray;

    if ( $sequenzarrayfull ne "undef" ) {
        my @sequenzarray;
        my $sequenz;
        my $x = 0;

        foreach my $sequenz (@sequenzall) {
            $x++;
            if ( $sequenz ne "undef" ) {
                @sequenzarray = split( / /, $sequenz );
                my $sequenzanzahl = @sequenzarray;
                my $deletezeit    = time;
                my $seqhash       = $own_hash->{helper}{sequenz}{$x};
                foreach my $seq ( keys %{$seqhash} ) {
                    if ( time > ( $seq + $sequenztime ) ) {
                        delete( $own_hash->{helper}{sequenz}{$x}{$seq} );
                    }
                }
            }
        }
    }

##########################
# notifyloop_incomming
# EVENTMAINLOOP
##########################
# aktuelle zeit in sekunden errechnen

    my $aktsectime = localtime;
    $aktsectime =~ s/\s+/ /g;
    my ( $tday, $tmonth, $tdate, $tn, $time1 ) = split( / /, $aktsectime );
    my ( $HH, $MM, $SS ) = split( /:/, $tn );
    $aktsectime = timelocal( $SS, $MM, $HH, $tdate, $tmonth, $time1 );
	$showevents = MSwitch_checkselectedevent( $own_hash, "last_ID" );	


	readingsBeginUpdate($own_hash);
    readingsBulkUpdate( $own_hash, "last_ID","ID_0",$showevents );
    readingsEndUpdate( $own_hash, $showevents);
	
	
	
	
	
	
    $own_hash->{helper}{statistics}{notifyloop_firsttest_passed}++
      if $statistic == 1;    #statistik

  EVENT: foreach my $event (@eventscopy) {
        $own_hash->{helper}{statistics}{eventloop_incomming}++
        if $statistic == 1;    #statistik

        # ausstieg bei jason
        if ( $event =~ m/^.*:.\{.*\}?/ ) {
            $own_hash->{helper}{statistics}{eventloop_jason_blocked}++
              if $statistic == 1;    #statistik
            MSwitch_LOG( $ownName, 4, "$ownName:    found jason -> $event  " );
			MSwitch_LOG( $ownName, 6, "-> jsonformatierung gefunden\n-> ignoriere event -> $event  " );
            next EVENT;
        }

        if ( $event =~ m/(.*)(\{.*\})(.*)/ ) {
            my $p1   = $1;
            my $json = $2;
            my $p3   = $3;
            $json =~ s/:/[dp]/g;
            $json =~ s/\"/[dst]/g;
            $event = $p1 . $json . $p3;
        }

        $own_hash->{MSwitch_Eventsave} = 'unsaved';
        $event = "" if ( !defined($event) );
        $eventcopy = $event;
        $eventcopy =~ s/: /:/s;    # BUG  !!!!!!!!!!!!!!!!!!!!!!!!
        $event =~ s/: /:/s;

####################################

        if ( exists $own_hash->{helper}{testevent_device} ) {
            $devName = $own_hash->{helper}{testevent_device};
            delete( $own_hash->{helper}{testevent_device} );
            delete( $own_hash->{helper}{testevent_event} );
        }

        # ersetze bei global eingang ggf fehlende eeventteile
        if ( $devName eq "global" ) {
            my @eventcopytmp = split( / /, $eventcopy, 2 );
            if ( @eventcopytmp == 1 ) {
                unshift @eventcopytmp, 'global';
            }
            $eventcopy = join( ":", @eventcopytmp );
        }
        $eventcopy = "$devName:$eventcopy";

##################################################################
# eventcopy  enthätl die arbeitskopie von event : immer 3 teilg ##
##################################################################
# doppelte eigentriggerung vermeiden

        if ( AttrVal( $ownName, "MSwitch_Selftrigger_always", 0 ) > 0 ) {
            my $testevent = $eventcopy;
            my @eventtestteile = split( /:/, $testevent );

            if ( !defined $eventtestteile[2] ) { $eventtestteile[2] = ""; }
            if ( $eventtestteile[2] eq "MSwitch_Self" ) {
                next EVENT;
            }

            if ( $eventtestteile[2] eq "MSwitch_Self" ) {
                next EVENT;
            }

            if ( $eventtestteile[0] eq $ownName ) {
                next EVENT;
            }
        }
        ################################

        delete( $own_hash->{helper}{history} )
          ; # lösche historyberechnung verschieben auf nach abarbeitung conditions

# teste auf mswitch-eventmap  -> vor triggercondition
        $eventcopy = MSwitch_Eventmap( $own_hash, $ownName, $eventcopy );
        $eventcopy =~ s/\"/\\"/g;
# temporär
# setze eingehendes Event :
        delete $own_hash->{helper}{evtparts};
        delete $own_hash->{helper}{evtparts}{event};
        delete $own_hash->{helper}{aktevent};
        my @eventteile = split( /:/, $eventcopy, 3 );

#hier kann optiona eine zusammenfassung eingebaut werde ( zusammenfassung nach der 3 stelle

        if ( !defined $eventteile[0] ) { $eventteile[0] = ""; }
        if ( !defined $eventteile[1] ) { $eventteile[1] = ""; }
        if ( !defined $eventteile[2] ) { $eventteile[2] = ""; }

        $own_hash->{helper}{evtparts}{parts}    = 3;
        $own_hash->{helper}{evtparts}{device}   = $devName;
        $own_hash->{helper}{evtparts}{evtpart1} = $eventteile[0];
        $own_hash->{helper}{evtparts}{evtpart2} = $eventteile[1];
        $own_hash->{helper}{evtparts}{evtpart3} = $eventteile[2];
        $own_hash->{helper}{evtparts}{evtfull}  = $eventcopy;
        $own_hash->{helper}{evtparts}{event} =
        $eventteile[1] . ":" . $eventteile[2];
        $own_hash->{helper}{aktevent} = $eventcopy;
        $eventcopy =
        $eventteile[0] . ":" . $eventteile[1] . ":" . $eventteile[2];

# Teste auf einhaltung Triggercondition für ausführung zweig 1 und zweig 2
# kann ggf an den anfang der routine gesetzt werden ? test erforderlich
# ignoriere condition wenn seftrigger und modus == 2

# from
readingsSingleUpdate( $own_hash, "last_device_trigger", "event" , $showevents ) if AttrVal( $ownName, 'MSwitch_Mode', 'Notify' ) ne "Dummy";

$own_hash->{helper}{trigwrite}="noset";

        my $ignore = "docondition";

        if ( exists $own_hash->{helper}{selftriggermode}
            && $own_hash->{helper}{selftriggermode} == 2 )
        {
            $ignore = "ignorecondition";
        }

        if ( $triggercondition ne '' && $triggercondition ne 'no_device' && $ignore eq "docondition" ) 
		{
            $triggercondition =~ s/#\[sp\]/ /g;
	
            my $ret = MSwitch_checkcondition( $triggercondition, $ownName, $eventcopy );
            if ( $ret eq 'false' ) {
                next EVENT;
            }
        }

MSwitch_LOG( $ownName, 6, "\n-> eingehendes Event:\n$eventcopy:" );
MSwitch_LOG( $ownName, 6, "\n");


        $own_hash->{helper}{statistics}{eventloop_firstcondition_passed}++
          if $statistic == 1;    #statistik

### ab hier ist das event durch condition akzeptiert


        MSwitch_EventBulk( $own_hash, $eventcopy, '0', 'MSwitch_Notify' );
        # teste auf mswitch-reading - evtl umsetzen -> nach triggercondition
        MSwitch_Readings( $own_hash, $ownName, $eventteile[1] );

######################################
# checke eventwait:
# nur wenn attribut gesetzt
#################
#check last eventpart

        my $lastincomming = "";
        foreach my $line ( keys %{ $data{MSwitch}{$ownName}{eventwait} } ) {
        }
        ##################################################

        my $checklast = $eventteile[0] . ":" . $eventteile[1] . ":.*";
        my $eventsollwaitwild = $data{MSwitch}{$ownName}{eventwait}{$checklast};

        if ( defined $eventsollwaitwild && $eventsollwaitwild ne "" ) {
            $lastincomming =
              $data{MSwitch}{$ownName}{inputeventwait}{$checklast};
            if ( $lastincomming eq "" ) {
                $lastincomming = 0;
            }

            my $newdiff = $lastincomming + $eventsollwaitwild - time;
            if ( $newdiff > 0 ) {
                my $lasttime = time + $eventsollwaitwild - $lastincomming;
                next EVENT;
            }
            else {
                $data{MSwitch}{$ownName}{inputeventwait}{$checklast} = time;
            }
        }

##########################
#	check last eventpart mit bedingung

        $checklast = $eventteile[0] . ":" . $eventteile[1];

        foreach my $line (
            keys %{ $data{MSwitch}{$ownName}{eventwaitwild}{$checklast} } )
        {
            my $eventsollwaitwildcond =
              $data{MSwitch}{$ownName}{eventwaitwild}{$checklast}{$line};
            my $condition = $line;
            $condition =~ s/\*/$eventteile[2]/g;
            my $result = eval($condition);

            if ($result) {
                MSwitch_LOG($ownName,6,"-> CONDITION $result erfüllt ");
                ### bedingung erfüllt
                my $ersatzevent = $checklast . ":" . $line;
                $lastincomming =
                  $data{MSwitch}{$ownName}{inputeventwaitwild}{$ersatzevent};
                if ( $lastincomming eq "" ) {
                    $lastincomming = 0;
                }
                my $newdiff = $lastincomming + $eventsollwaitwildcond - time;

                if ( $newdiff > 0 ) {
                    my $lasttime =
                      time + $eventsollwaitwildcond - $lastincomming;
                    MSwitch_LOG($ownName,6,"-> Event $eventcopy wird noch $newdiff sekunden blockiert");
                    next EVENT;
                }
                else {
                    $data{MSwitch}{$ownName}{inputeventwaitwild}{$ersatzevent}
                      = time;
                }
                ### bedingung erfüllt ende
            }
        }

        ################
        # check full event
        my $eventsollwait = $data{MSwitch}{$ownName}{eventwait}{$eventcopy};
        if ( defined $eventsollwait && $eventsollwait ne "" ) {
            $lastincomming =
              $data{MSwitch}{$ownName}{inputeventwait}{$eventcopy};
            if ( $lastincomming eq "" ) {
                $lastincomming = 0;
            }

            my $newdiff = $lastincomming + $eventsollwait - time;
            if ( $newdiff > 0 ) {
                my $lasttime = time + $eventsollwait - $lastincomming;
                MSwitch_LOG($ownName,6,"-> Event $eventcopy wird noch $newdiff sekunden blockiert");
                next EVENT;
            }
            else {
                $data{MSwitch}{$ownName}{inputeventwait}{$eventcopy} = time;
            }
        }

######################################
        # sequenz
        my $x    = 0;
        my $zeit = time;

      SEQ: foreach my $sequenz (@sequenzall) {
            $x++;
            if ( $sequenz ne "undef" ) 
			{
                foreach my $test (@sequenzarrayfull) 
				{
					
					MSwitch_LOG($ownName,6,"test -> $test");
					
                    if ( $eventcopy =~ /$test/ ) 
					{
                        $own_hash->{helper}{sequenz}{$x}{$zeit} = $eventcopy;
                    }
                }
                my $seqhash    = $own_hash->{helper}{sequenz}{$x};
                my $aktsequenz = "";
                foreach my $seq ( sort keys %{$seqhash} )
				{
					MSwitch_LOG($ownName,6,"seq -> $seq");
                    $aktsequenz .= $own_hash->{helper}{sequenz}{$x}{$seq} . " ";
					MSwitch_LOG($ownName,6,"aktsequenz -> $aktsequenz");

                }
					MSwitch_LOG($ownName,6,"aktsequenzready -> $aktsequenz");

                if ( $aktsequenz =~ /$sequenz/ ) 
				{
					MSwitch_LOG($ownName,6,"FOUND SEQUENZ -> $aktsequenz - $sequenz");
					MSwitch_LOG($ownName,6,"----------------------------------------\n");
					
                    delete( $own_hash->{helper}{sequenz}{$x} );
					$showevents = MSwitch_checkselectedevent( $own_hash, "SEQUENCE" );
                    readingsSingleUpdate( $own_hash, "SEQUENCE", 'match', $showevents );
					$showevents = MSwitch_checkselectedevent( $own_hash, "SEQUENCE_Number" );
                    readingsSingleUpdate( $own_hash, "SEQUENCE_Number", $x, $showevents );
                    last SEQ;
                }
                else 
				{
                    if ( ReadingsVal( $ownName, "SEQUENCE", 'undef' ) eq
                        "match" )
                    {
						$showevents = MSwitch_checkselectedevent( $own_hash, "SEQUENCE" );
                        readingsSingleUpdate( $own_hash, "SEQUENCE", 'no_match', $showevents );
                    }
                    if ( ReadingsVal( $ownName, "SEQUENCE_Number", 'undef' ) ne
                        "0" )
                    {
						$showevents = MSwitch_checkselectedevent( $own_hash, "SEQUENCE_Number" );
                        readingsSingleUpdate( $own_hash, "SEQUENCE_Number", '0', $showevents );
                    }
                }
            }
        }
######################################
        # Triggerlog/Eventlog

        if ( $triggerlog eq 'on' ) {
            my $zeit = time;
            if ( $devName ne "MSwitch_Self" ) {
                if ( $triggerdevice eq "all_events" ) {
                    $own_hash->{helper}{events}{'all_events'}{$eventcopy} =
                      "on";
                }
                else {
                    $own_hash->{helper}{events}{$devName}{$eventcopy} = "on";
                }
            }
            else {
                $own_hash->{helper}{events}{MSwitch_Self}{$eventcopy} = "on";
            }
        }
        if ( $evhistory > 0 ) {
            my $zeit = time;
            $own_hash->{helper}{eventlog}{$zeit} = $eventcopy;
            my $log = $own_hash->{helper}{eventlog};
            my $x   = 0;
            my $seq;
            foreach $seq ( sort { $b <=> $a } keys %{$log} ) {
                delete( $own_hash->{helper}{eventlog}{$seq} )
                  if $x > $evhistory;
                $x++;
            }
        }

################ alle events für weitere funktionen speichern
#############################################################

        if ( $event ne '' ) {
            ### pruefe Bridge
            my ( $chbridge, $zweig, $bridge ) =
              MSwitch_checkbridge( $own_hash, $ownName, $eventcopy, );

            $own_hash->{helper}{statistics}{eventloop_bridge}++
              if $statistic == 1 && $chbridge eq "found bridge";
            if ( $chbridge eq "bridge found" ) {
                MSwitch_history(
                    $own_hash,   $ownName,   $showevents, $devName,
                    $aktsectime, $evhistory, $eventcopy
                );
                next EVENT;
            }
        }
############################################################################################################

        my $testvar = '';
        my $check   = 0;

        #test auf zweige cmd1/2 and switch MSwitch on/off
        if ( $triggeron ne 'no_trigger' ) {
            $testvar = MSwitch_checktrigger_new( $own_hash, $triggeron, 'on' );
            if ( defined $testvar && $testvar ne 'undef' ) {
                $own_hash->{helper}{statistics}{eventloop_cmd1}++
                  if $statistic == 1;    #statistik
                $set       = $testvar;
                $check     = 1;
                $foundcmd1 = 1;
                $trigevent = $eventcopy;
            }
        }

        if ( $triggeroff ne 'no_trigger' ) {
            $testvar =
              MSwitch_checktrigger_new( $own_hash, $triggeroff, 'off' );
            if ( defined $testvar && $testvar ne 'undef' ) {

                $own_hash->{helper}{statistics}{eventloop_cmd2}++
                  if $statistic == 1;    #statistik
                $set       = $testvar;
                $check     = 1;
                $foundcmd2 = 1;
                $trigevent = $eventcopy;
            }
        }

        #test auf zweige cmd1/2 and switch MSwitch on/off ENDE
        #test auf zweige cmd1/2 only
        #ergebnisse werden in  @cmdarray geschrieben

        if ( $triggercmdoff ne 'no_trigger' ) {
            $testvar =
              MSwitch_checktrigger_new( $own_hash, $triggercmdoff, 'offonly' );
            if ( defined $testvar && $testvar ne 'undef' ) {
                $data{MSwitch}{$ownName}{setdata}{last_cmd}    = "cmd_2";
                $data{MSwitch}{$ownName}{setdata}{last_switch} = "no switch";
                $own_hash->{helper}{statistics}{eventloop_cmd4}++
                  if $statistic == 1;    #statistik

                push @cmdarray, $own_hash . ',off,check,' . $eventcopy;
                $check     = 1;
                $foundcmd2 = 1;
            }
        }

        if ( $triggercmdon ne 'no_trigger' ) {
            $testvar =
              MSwitch_checktrigger_new( $own_hash, $triggercmdon, 'ononly' );
            if ( defined $testvar && $testvar ne 'undef' ) {
                $data{MSwitch}{$ownName}{setdata}{last_cmd}    = "cmd_1";
                $data{MSwitch}{$ownName}{setdata}{last_switch} = "no switch";
                $own_hash->{helper}{statistics}{eventloop_cmd3}++
                  if $statistic == 1;    
                push @cmdarray, $own_hash . ',on,check,' . $eventcopy;
                $check     = 1;
                $foundcmd1 = 1;
            }
        }

        $own_hash->{helper}{statistics}{eventignored}++
          if $statistic == 1 && $check != 1;    #statistik
        my $statevent = $eventteile[0] . ":" . $eventteile[1];
        $own_hash->{helper}{statistics}{eventloop}{unused}{$statevent}++
          if $statistic == 1 && $check != 1;    #statistik
		  
        my $timestampreading =
          AttrVal( $ownName, 'MSwitch_Eventhistory_timestamp_to_Reading', "0" );

#notifyloop_incomming_names:
### prüfen
# speichert 20 events ab zur weiterne funktion ( funktionen )
# ändern auf bedarfschaltung   ,$own_hash->{helper}{evtparts}
# wenn der wert nur zahlen enthätl

        if ( $check == '1' ) {
            MSwitch_history(
                $own_hash,   $ownName,   $showevents, $devName,
                $aktsectime, $evhistory, $eventcopy
            );
        }

############################################################################

        #Newfunction
        #Function AVG
        if ( AttrVal( $ownName, "MSwitch_Func_AVG", 'undef' ) ne 'undef' ) {
            MSwitch_Check_AVG( $own_hash, $ownName );
        }

        #Function DIFF
        if ( AttrVal( $ownName, "MSwitch_Func_DIFF", 'undef' ) ne 'undef' ) {
            MSwitch_Check_DIFF( $own_hash, $ownName );
        }

        #Function TEND
        if ( AttrVal( $ownName, "MSwitch_Func_TEND", 'undef' ) ne 'undef' ) {
            MSwitch_Check_TEND( $own_hash, $ownName );
        }

######################################
        #test auf zweige cmd1/2 only ENDE

        $anzahl = @cmdarray;
       # $own_hash->{MSwitch_IncommingHandle} = 'fromnotify' if $devicemode ne "Dummy";

        if ( $devicemode eq "Notify" and $activecount == 0 ) {
            # reading activity aktualisieren
            $activecount = 1;
        }

        if ( $devicemode eq "Toggle" && $set eq 'on' ) {
            # umschalten des devices nur im togglemode
            my $cmd = '';
            my $statetest = ReadingsVal( $ownName, 'state', 'on' );
            $cmd = "set $ownName off" if $statetest eq 'on';
            $cmd = "set $ownName on"  if $statetest eq 'off';

            if ( $debugmode ne '2' ) {
                my $errors = AnalyzeCommandChain( undef, $cmd );
                if ( defined($errors) ) {
                    MSwitch_LOG( $ownName, 1,
"$ownName MSwitch_Notify: Fehler bei Befehlsausführung $errors -> Comand: $_ "
                          . __LINE__ );
						  
					MSwitch_LOG( $ownName, 6,
"-> Fehler bei Befehlsausführung $errors -> Comand: $_ "
                          . __LINE__ );	  
						  
                }
            }
            MSwitch_setdata( $own_hash, $ownName );
			$own_hash->{helper}{trigwrite}="set";
            return;
        }

    }

#################################################
    # abfrage und setzten von blocking
    # schalte blocking an , wenn anzahl grösser 0 und MSwitch_Wait gesetzt

    if ( ( $foundcmd1 eq "1" || $foundcmd2 eq "1" ) && $mswait > 0 ) {
        MSwitch_LOG( $ownName, 6, "-> Wait auf $mswait gesetzt");
        $data{MSwitch}{$ownName}{setdata}{waiting} = ( time + $mswait );
    }

    # abfrage und setzten von blocking ENDE
#################################################
    # CMD Counter setzen

    if ( $foundcmd1 eq "1"
        && AttrVal( $ownName, "MSwitch_Reset_EVT_CMD1_COUNT", 'undef' ) ne
        'undef' )
    {
        my $inhalt = ReadingsVal( $ownName, 'EVT_CMD1_COUNT', '0' );
        if ( $resetcmd1 == 0 ) {
            $inhalt++;
            $data{MSwitch}{$ownName}{setdata}{EVT_CMD1_COUNT} = $inhalt;

        }
        elsif ( $resetcmd1 > 0 && $inhalt < $resetcmd1 ) {
            $inhalt++;
			$showevents = MSwitch_checkselectedevent( $own_hash, "EVT_CMD1_COUNT" );
            readingsSingleUpdate( $own_hash, "EVT_CMD1_COUNT", $inhalt,$showevents );
            $data{MSwitch}{$ownName}{setdata}{EVT_CMD1_COUNT} = $inhalt;
        }
    }

    if ( $foundcmd2 eq "1"
        && AttrVal( $ownName, "MSwitch_Reset_EVT_CMD2_COUNT", 'undef' ) ne
        'undef' )
    {
        my $inhalt = ReadingsVal( $ownName, 'EVT_CMD2_COUNT', '0' );
        if ( $resetcmd2 == 0 ) {
            $inhalt++;
            $data{MSwitch}{$ownName}{setdata}{EVT_CMD2_COUNT} = $inhalt;
        }
        elsif ( $resetcmd2 > 0 && $inhalt < $resetcmd2 ) {
            $inhalt++;
			$showevents = MSwitch_checkselectedevent( $own_hash, "EVT_CMD2_COUNT" );
            readingsSingleUpdate( $own_hash, "EVT_CMD2_COUNT", $inhalt,$showevents );
            $data{MSwitch}{$ownName}{setdata}{EVT_CMD2_COUNT} = $inhalt;
        }
    }

# CMD Counter setzen ENDE
#################################################
#ausführen aller cmds in @cmdarray nach triggertest aber vor conditiontest
#my @cmdarray1;	#enthält auszuführende befehle nach conditiontest
#schaltet zweig 3 und 4

    # ACHTUNG
    if ( $anzahl && $anzahl != 0 ) {

        MSwitch_LOG( $ownName, 6, "-> $anzahl auszuführende Befehle gefunden");
        #aberabeite aller befehlssätze in cmdarray

      LOOP31: foreach (@cmdarray) {
            my $test = $_;
		    MSwitch_LOG( $ownName, 6, "    - $test");
            if ( $_ eq 'undef' ) { next LOOP31; }
            my ( $ar1, $ar2, $ar3, $ar4 ) = split( /,/, $test );
            if ( !defined $ar2 ) { $ar2 = ''; }
            if ( $ar2 eq '' ) {
                next LOOP31;
            }
            my $returncmd = 'undef';
			$returncmd = MSwitch_Exec_Notif( $own_hash, $ar2, $ar3, $ar4, $execids );

            if ( defined $returncmd && $returncmd ne 'undef' ) {
                # datensatz nur in cmdarray1 übernehme wenn
                chop $returncmd;    #CHANGE
                push( @cmdarray1, $returncmd );
            }
        }

        my $befehlssatz = join( ',', @cmdarray1 );
        foreach ( split( /,/, $befehlssatz ) ) {
            my $ecec = $_;
            if ( !$ecec =~ m/set (.*)(MSwitchtoggle)(.*)/ ) {
                if ( $attrrandomnumber ne '' ) {
                    MSwitch_Createnumber($own_hash);
                }

                if ( $debugmode ne '2' ) {
                     MSwitch_LOG( $ownName, 6,"Befehlsausführung:\n$_ ");
                    my $errors = AnalyzeCommandChain( undef, $_ );
                    if ( defined($errors) ) {
                         MSwitch_LOG( $ownName, 1,"$ownName MSwitch_Notify: Fehler bei Befehlsausführung $errors -> Comand: $_ " . __LINE__ );
                         MSwitch_LOG( $ownName, 6,"-> Fehler bei Befehlsausführung $errors -> Comand: $_ ");

				   }
                }

                if ( length($ecec) > 100 ) {
                    $ecec = substr( $ecec, 0, 100 ) . '....';
                }

                $data{MSwitch}{$ownName}{setdata}{last_exec_cmd} = $ecec
                  if $ecec ne '';
            }
            else {
                # nothing
            }
        }
    }

    # ende loopeinzeleventtest
    # schreibe gruppe mit events
    my $selftrigger = "";
    $events = '';
    my $eventhash = $own_hash->{helper}{events}{$devName};
    if ( AttrVal( $ownName, "MSwitch_Selftrigger_always", 0 ) > 0 ) {
        $eventhash = $own_hash->{helper}{events}{MSwitch_Self};
        foreach my $name ( keys %{$eventhash} ) {
            $events = $events . $name . '#[tr]';
        }
    }

    if ( $triggerdevice eq "all_events" ) {
        $eventhash = $own_hash->{helper}{events}{all_events};
    }
    else {
        $eventhash = $own_hash->{helper}{events}{$devName};
    }

    foreach my $name ( keys %{$eventhash} ) {
        $events = $events . $name . '#[tr]';
    }
    chop($events);
    chop($events);
    chop($events);
    chop($events);
    chop($events);
    if ( $events ne "" ) {
        my $inh = ".Device_Events";
        $data{MSwitch}{$ownName}{setdata}{$inh} = $events;
    }

    # schreiben ende
    # schalte modul an/aus bei entsprechendem notify
    # teste auf condition
    if ( $set eq 'noset' ) {

        # keine MSwitch on/off incl cmd1/2 gefunden
        MSwitch_setdata( $own_hash, $ownName );
		$own_hash->{helper}{trigwrite}="set";
        return;
    }

######################
# schaltet zweig 1 und 2 , wenn $set befehl enthält , es wird nur MSwitch geschaltet, Devices werden dann 'mitgerissen'
    my $cs;
    $own_hash->{helper}{aktevent} = $eventcopy;
    if ( $triggerdevice eq "all_events" ) {
        $cs = "set $ownName $set $trigevent";
    }
    else {
        $cs = "set $ownName $set $trigevent";
    }

    if ( $attrrandomnumber ne '' ) {
        MSwitch_Createnumber($own_hash);
    }

    if ( $debugmode ne '2' ) {
        MSwitch_LOG( $ownName, 6, "-> Befehlsausführung ON/OFF mit Event $eventcopy:\n$cs" );
        my $errors = AnalyzeCommandChain( undef, $cs );
    }
    MSwitch_setdata( $own_hash, $ownName );
	$own_hash->{helper}{trigwrite}="set";
    return;
}

#########################

sub MSwitch_Eventmap(@) {
    my ( $hash, $name, $eventcopy ) = @_;
    return $eventcopy if !exists $data{MSwitch}{$name}{Eventmap};
    my $showevents = AttrVal( $name, "MSwitch_generate_Events", 0 );
	
	
	$showevents = MSwitch_checkselectedevent( $hash, "EVENT_ORG" );
    readingsSingleUpdate( $hash, 'EVENT_ORG', $eventcopy, $showevents );

    my @ecopy = split( /:/, $eventcopy, 3 );
    my $maphash = $data{MSwitch}{$name}{Eventmap};
    foreach my $key ( keys %{$maphash} ) {

        my $inhalt;
        my $change;
        my $part;
        my $muster;
        $inhalt = $data{MSwitch}{$name}{Eventmap}{$key};

        my @ihalt = split( /:/, $inhalt, 2 );
        $change = $ihalt[0];
        $part   = $ihalt[1];

        $key =~ s/\[#dp\]/\\:/g;
        $change =~ s/\[#dp\]/:/g;

        $muster = qr{$key};

        if ( !defined $part || $part eq "EVENT" ) {
            $ecopy[0] =~ s/$muster/$change/g;
            $ecopy[1] =~ s/$muster/$change/g;
            $ecopy[2] =~ s/$muster/$change/g;
        }

        if ( $part eq "EVTPART1" ) {
            $ecopy[0] =~ s/$muster/$change/g;
        }

        if ( $part eq "EVTPART2" ) {
            $ecopy[1] =~ s/$muster/$change/g;
        }

        if ( $part eq "EVTPART3" ) {
            $ecopy[2] =~ s/$muster/$change/g;
        }

        if ( !defined $part || $part eq "EVENTFULL" ) {
            $eventcopy =~ s/$muster/$change/g;
            return $eventcopy;
        }
        if ( !defined $ecopy[0] or $ecopy[0] eq "" ) { $ecopy[0] = "undef"; }
        if ( !defined $ecopy[1] or $ecopy[1] eq "" ) { $ecopy[1] = "undef"; }
        if ( !defined $ecopy[2] or $ecopy[2] eq "" ) { $ecopy[2] = "undef"; }
        $eventcopy = join ":", @ecopy;
    }
    return $eventcopy;
}

#########################

sub MSwitch_Readings(@) {

    my ( $hash, $name, $trigger ) = @_;
    return if !exists $data{MSwitch}{$name}{Readings};
    my $keyhash = $data{MSwitch}{$name}{Readings};
    foreach my $readingraw ( keys %{$keyhash} ) {
        my ( $reading, $totrigger ) = split( /:/, $readingraw, 2 );

        if ( !defined $totrigger || $totrigger eq "" ) {
            $totrigger = ".*";
        }

        if ( $trigger =~ m/$totrigger/ ) {
        }
        else {
            next;
        }
        my $cs = "{" . $data{MSwitch}{$name}{Readings}{$readingraw} . "}";
        $cs = MSwitch_dec( $hash, $cs );
        $cs = MSwitch_makefreecmd( $hash, $cs );
        my $result = eval($cs);

        $data{MSwitch}{$name}{setdata}{$reading} = $result;
    }
    return;
}

###############################
sub MSwitch_history(@) {
    my (
        $own_hash,   $ownName,   $showevents, $devName,
        $aktsectime, $evhistory, $eventcopy
    ) = @_;

    my $evde      = ( split( /:/, $eventcopy ) )[0];    #ACHTUNG
    my $evwert    = ( split( /:/, $eventcopy ) )[2];    #ACHTUNG
    my $evreading = ( split( /:/, $eventcopy ) )[1];    #ACHTUNG

    my @eventfunction;
    my @eventfunctiontime;

    if ( ReadingsVal( $ownName, ".Trigger_device", "no_trigger" ) eq
        'all_events' )
    {
        @eventfunction =
          split( / /, $own_hash->{helper}{eventhistory}{$evde}{$evreading} )
          if exists $own_hash->{helper}{eventhistory}{$evde}{$evreading};
        @eventfunctiontime =
          split( / /,
            $own_hash->{helper}{eventhistory}{timer}{$evde}{$evreading} )
          if exists $own_hash->{helper}{eventhistory}{timer}{$evde}{$evreading};
    }
    else {
        @eventfunction =
          split( / /, $own_hash->{helper}{eventhistory}{$evreading} )
          if exists $own_hash->{helper}{eventhistory}{$evreading};
        @eventfunctiontime =
          split( / /, $own_hash->{helper}{eventhistory}{timer}{$evreading} )
          if exists $own_hash->{helper}{eventhistory}{timer}{$evreading};
    }

    unshift( @eventfunction,     $evwert );
    unshift( @eventfunctiontime, $aktsectime );

    while ( @eventfunction > $evhistory ) {
        pop(@eventfunction);
    }

    while ( @eventfunctiontime > $evhistory ) {
        pop(@eventfunctiontime);
    }

    my $neweventfunction     = join( ' ', @eventfunction );
    my $neweventfunctiontime = join( ' ', @eventfunctiontime );

    if ( ReadingsVal( $ownName, ".Trigger_device", "no_trigger" ) eq
        'all_events' )
    {
        $own_hash->{helper}{eventhistory}{$evde}{$evreading} =
          $neweventfunction;
        $own_hash->{helper}{eventhistory}{timer}{$evde}{$evreading} =
          $neweventfunctiontime;
    }
    else {
        $own_hash->{helper}{eventhistory}{$evreading} = $neweventfunction;
        $own_hash->{helper}{eventhistory}{timer}{$evreading} =
          $neweventfunctiontime;
    }

    my $timestampreading =
      AttrVal( $ownName, 'MSwitch_Eventhistory_timestamp_to_Reading', "0" );
    my $realtimerreading =
      AttrVal( $ownName, 'MSwitch_Eventhistory_realtime_to_Reading', "0" );

    if ( AttrVal( $ownName, 'MSwitch_Eventhistory_to_Reading', "0" ) == 1 ) {
        my $count = 0;
        readingsBeginUpdate($own_hash);
        foreach my $testdevices (@eventfunction) {
            my $readname         = $evreading . "_h" . $count;
            my $readnametime     = $evreading . "_h" . $count . "_time";
            my $readnamerealtime = $evreading . "_h" . $count . "_realtime";

            my $realtime;
            $realtime = FmtDateTime( $eventfunctiontime[$count] )
              if $realtimerreading == 1;
            if ( ReadingsVal( $ownName, ".Trigger_device", "no_trigger" ) eq
                'all_events' )
            {
                readingsBulkUpdate( $own_hash, $devName . "_" . $readname, $testdevices,1 );
                readingsBulkUpdate( $own_hash,$devName . "_" . $readnametime,$eventfunctiontime[$count],1) if $timestampreading == 1;
                readingsBulkUpdate( $own_hash,$devName . "_" . $readnamerealtime, $realtime,1 ) if $realtimerreading == 1;

            }
            else {
                readingsBulkUpdate( $own_hash, $readname, $testdevices,1 );
                readingsBulkUpdate( $own_hash, $readnametime,$eventfunctiontime[$count],1 ) if $timestampreading == 1;
                readingsBulkUpdate( $own_hash, $readnamerealtime, $realtime,1 ) if $realtimerreading == 1;

            }

            $count++;
        }
        readingsEndUpdate( $own_hash, $showevents );
        return;
    }
}

###############################
sub MSwitch_checkbridge($$$) {
    my ( $hash, $name, $event ) = @_;
    my $bridgemode = ReadingsVal( $name, '.Distributor', '0' );
    my $expertmode = AttrVal( $name, 'MSwitch_Expert',          '0' );
    my $showevents = AttrVal( $name, 'MSwitch_generate_Events', '0' );
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
		
	MSwitch_LOG( $name, 6,"->> teste Eventhandler(Bridge): $a " );	
        @bridge         = ();
        $foundkey       = "undef";
        $orgkey         = $a;
        $foundcond      = "0";
        $eventbedingung = "";

		$a =~ s/\$SELF/$name/g;
		$a = MSwitch_check_setmagic_i( $hash, $a );

        if ( $a =~ m/(.*)\[(.*)\]/ ) {

            $foundcond      = "1";
            $eventpart      = $1;
            $eventbedingung = $2;
            MSwitch_LOG( $name, 6,"-> Zusatzbedingung gefunden: $a " );
            $a = $eventpart;
        }

        my $re = qr/$a/;
        $foundkey = $a if ( $event =~ /$re/ );
        next if $foundkey eq "undef";

		my $oldkey;
        if ( $foundkey ne "undef" ) { 
		$oldkey = $foundkey;
		$foundkey = $orgkey; 
		}
		
		MSwitch_LOG( $name, 6, "\n-> SUB BRIDGE foundkey " );
		MSwitch_LOG( $name, 6, "ORGKEY: $orgkey "  );
		MSwitch_LOG( $name, 6, "KEY: $oldkey "  );
		MSwitch_LOG( $name, 6, "VERGL 1: $re"  );
		MSwitch_LOG( $name, 6, "VERGL 2: $event"  );
		
        ##########################
        #	ausführen des gefundenen keys
        #
        @bridge = split( / /, $hash->{helper}{eventtoid}{$foundkey} )
          if exists $hash->{helper}{eventtoid}{$foundkey};

        #$zweig;
        next if @bridge < 1;
        $zweig = "on"  if $bridge[0] eq "cmd1";
        $zweig = "off" if $bridge[0] eq "cmd2";

        MSwitch_LOG( $name, 6,"\n->> ID Bridge gefunden: zweig: $bridge[0] , ID:$bridge[2] ");
		MSwitch_LOG( $name, 6, "      - BEDINGUNG: $re\n      - EVENT: $event");
		
		$showevents = MSwitch_checkselectedevent( $hash, "last_ID" );
		
		
		
		 MSwitch_LOG( $name, 6,"Showevents ID Update-> : ".$showevents);
       # readingsSingleUpdate( $hash, "last_ID", "ID_" . $bridge[2], $showevents );



	readingsBeginUpdate($hash);
    readingsBulkUpdate( $hash, "last_ID", "ID_" . $bridge[2], $showevents );
    readingsEndUpdate( $hash, $showevents);
	
	
	
        if ( $foundcond eq "1" ) {
          
            my $eventparts = $hash->{helper}{evtparts};
            my @eventteile = split( /:/, $eventpart, $eventparts );

            my $position;
            for ( my $i = 0 ; $i < $eventparts ; $i++ ) {
                if ( $eventteile[$i] =~ m/^.*$/ ) {
                    $position = $i;
                }
            }

            my @eventsplit = split( /:/, $event );
            my $staris = $eventsplit[$position];
            my $newcondition = $eventbedingung;
            if ( $staris =~ m/^-?\d+(?:[\.,]\d+)?$/ ) {
                $newcondition =~ s/\*/$staris/g;
            }
            else {
                $newcondition =~ s/\*/"$staris"/g;

                # teste auf string/zahl vergleich
                my $testccondition = $newcondition;
                $testccondition =~ s/ //g;
                if ( $testccondition =~ m/(".*"(>|<)\d+)/ ) {
                    return 'undef';
                }
            }
  
            my $ret = MSwitch_checkcondition( $newcondition, $name, $event );
            next if $ret ne "true";
        }
        MSwitch_Exec_Notif( $hash, $zweig, 'nocheck', $event, $bridge[2] );
    }

    if ( !defined $hash->{helper}{eventtoid}{$foundkey} ) {
        return "NO BRIDGE FOUND !";
    }
    return ( "bridge found", $zweig, $bridge[2] );
}

############################
sub MSwitch_fhemwebconf($$$$) {

    my ( $FW_wname, $d, $room, $pageHash ) =
      @_;    # pageHash is set for summaryFn.
    my $hash = $defs{$d};
    my $Name = $hash->{NAME};
    my @found_devices;
    $hash->{NOTIFYDEV} = 'no_trigger';
	my $showevents;
	$showevents = MSwitch_checkselectedevent( $hash, "EVENTCONF" );
    readingsSingleUpdate( $hash, "EVENTCONF", "start", $showevents );

    my $preconf1 = '';
    my $preconf  = '';
    my $devstring;
    my $cmds;
    $cmds .=
"' reset_Switching_once loadHTTP timer:on,off del_repeats reset_device active del_function_data del_history_data:noArg inactive on off del_delays backup_MSwitch fakeevent exec_cmd_1 exec_cmd_2 wait del_repeats reload_timer change_renamed reset_status_counter:noArg reset_cmd_count ',";
    $devstring .= "'MSwitch_Self',";
    @found_devices = devspec2array("TYPE=.*");

    for (@found_devices) {
        my $test = getAllSets($_);
        if ( $test =~ m/.*'.*/ ) {
            MSwitch_LOG( $Name, 1,
"der Fhembefehl 'getAllSets' verursacht eine ungültige Rückgabe des Devices $_ , bitte den Modulautor informieren . Hierfür bitte den Devicetypen des Devices $_ angeben. "
            );
            $test =~ s/'//g;
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
    my $at = "";
    my $atdef;
    my $athash;
    my $insert;
    my $comand;
    my $timespec;
    my $flag;
    my $trigtime;

    # suche at
    @found_devices = devspec2array("TYPE=at");
    for (@found_devices) {
        $athash = $defs{$_};
        $insert = $athash->{DEF};
        $flag   = substr( $insert, 0, 1 );

        if ( $flag ne "+" ) {
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
    my $notify    = "";
    my $notifydef = "";

    @found_devices = devspec2array("TYPE=notify");
    for (@found_devices) {
        $nothash   = $defs{$_};
        $notinsert = $nothash->{DEF};
        $notify .= "'" . $_ . "',";
    }
    chop $notifydef if length($at) > 0;
    chop $notify    if length($at) > 0;
    $notify = "[" . $notify . "]";

    my $return = "<div id='mode'>Konfigurationsmodus:&nbsp;";
    $return .=
"<input name=\"conf\" id=\"config\" type=\"button\" value=\"import MSwitch_Config\" onclick=\"javascript: conf('importCONFIG',id)\"\">&nbsp;
	<input name=\"conf\" id=\"importat\" type=\"button\" value=\"import AT\" onclick=\"javascript: conf('importAT',id)\"\">&nbsp;
	<input name=\"conf\" id=\"importnotify\" type=\"button\" value=\"import NOTIFY\" onclick=\"javascript: conf('importNOTIFY',id)\"\">
	<input name=\"conf\" id=\"importpreconf\" type=\"button\" value=\"import PRECONF\" onclick=\"javascript: conf('importPRECONF',id)\"\">
	";

    my $template = "";
    my $adress   = $templatefile . "01_inhalt.txt";
    my $def      = $adress;

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

    my ( $err, $templateinhalt ) = HttpUtils_BlockingGet($param);
    if (
        length($err) >
        1 )    # wenn ein Fehler bei der HTTP Abfrage aufgetreten ist
    {
        return;
    }

    my @templates = split( /\n/, $templateinhalt );

    foreach my $testdevices (@templates) {
        my ( $key, $val ) = split( /\|/, $testdevices );
        my $plainkey = ( split( /\./, $key ) )[0];
        $template .= "<option value=\"$plainkey\">$plainkey</option>";
    }

    my @files = <./FHEM/MSwitch/*.txt>;

    foreach my $testdevices (@files) {
        my @string = split( /\//, $testdevices );
        $string[3] =~ s/\.txt//g;
        $template .=
          "<option value=\"local/$string[3]\">local / $string[3]</option>";
    }

    $return .=
"<input name=\"template\" id=\"importTEMPLATE\" type=\"button\" value=\"import Template\" onclick=\"javascript: loadtemplate()\"\">";
    $return .=
        "<select id =\"templatefile\"  name=\"\"  >"
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
	</div>
	<div id='speicherbank2' style='display: none;'>
	Speicherbank2 bank 9-12: 
	<textarea id='bank9'></textarea>
	<textarea id='bank10'></textarea>
	<textarea id='bank11'></textarea>
	<textarea id='bank12'></textarea>
	<br>&nbsp;<hr>
	</div>
	<table border='0'>
	<tr>
	<td id='help'>Hilfetext</td>
	<td id='help1'></td>
	</tr>
	</table>";

    $return .=
"<input type=\"button\" id = \"showtemplate\" value=\"zeige Template\" onclick=\"javascript: toggletemplate()\" style=\"display:none\">";
    $return .= "<br>&nbsp;<br>";
    $return .= "<div id='empty' style=\"display:none\">";
    $return .= "Template: ";
    $return .=
"<input type=\"text\" id = \"templatename\" value=\"\"  style=\"background-color:transparent\">";
    $return .=
"&nbsp;<input type=\"button\" id = \"savetemplata\" value=\"Template lokal speichern\"  style=\"\" onclick=\"javascript: savetemplate()\">";
    $return .=
"&nbsp;<input type=\"button\" id = \"\" value=\"FreeCmd kodieren\"  style=\"\" onclick=\"javascript: showkode()\">";

    $return .=
"&nbsp;<input type=\"button\" id = \"\" value=\"Hilfe\"  style=\"\" onclick=\"javascript: alert(\'Verfügbar ab V5.31\')\">";

    $return .= "<br>&nbsp;<br>";
    $return .= "<div id='decode' style=\"display:none\">";
    $return .=
"<textarea id='decode1' style='width: 100%; height: 100px'>### insert code ###</textarea>";
    $return .=
"<br><input type=\"button\" id = \"\" value=\"kodieren\"  style=\"\" onclick=\"javascript: decode()\">";
    $return .=
"&nbsp;<input type=\"button\" id = \"\" value=\"dekodieren\"  style=\"\" onclick=\"javascript: encode()\">";
    $return .= "<br>&nbsp;</div>";
    $return .=
"<textarea id='emptyarea' style='width: 100%; height: 300px'>### insert template ###</textarea><br>
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
    my @owna    = split( / /, $ownattr );
    my $j1      = "
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
    foreach my $akt (@owna) {

        next if !defined $akt;
        next if $akt eq "";
        my @test = split( /:/, $akt );

        if ( !defined $test[1] ) { next; }
        $j1 .= "ownattr['$test[0]']  = '$test[1]';\n";
    }

    my $vupdatedigit = substr( $vupdate, 1, length($vupdate) - 1 );
    $j1 .= "// firstconfig
	var logging ='off';
	var devices = " . $devstring . ";
	var cmds = " . $cmds . ";
	var i;
	var templatefile='" . $templatefile . "';
	var preconffile ='" . $preconffile . "';
	var len = devices.length;
	var o = new Object();
	var devicename= '" . $Name . "';
	var mVersion= '" . $version . "';
	var MSDATAVERSION = '" . $vupdate . "';
	var MSDATAVERSIONDIGIT = " . $vupdatedigit . ";
	var notify = " . $notify . ";
	var at = " . $at . ";";

    if ( exists $hash->{helper}{template} ) {
        $j1 .= "var templatesel ='" . $hash->{helper}{template} . "';";
    }
    else {
        $j1 .= "var templatesel ='';";
    }

    $j1 .= "\$(document).ready(function() {
    \$(window).load(function() {
	name = '$Name';
	// loadScript(\"pgm2/MSwitch_Preconf.js?v=" . $fileend . "\");
    loadScript(\"pgm2/MSwitch_Wizard.js?v=" . $fileend
      . "\", function(){start1(name)});";

    if ( defined $hash->{helper}{template} ne "no"
        && $hash->{helper}{template} ne "no" )
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

    my ( $FW_wname, $d, $room, $pageHash ) =
      @_;    # pageHash is set for summaryFn.
    my $hash          = $defs{$d};
    my $Name          = $hash->{NAME};
    my $jsvarset      = '';
    my $j1            = '';
    my $border        = 0;
    my $ver           = ReadingsVal( $Name, '.V_Check', '' );
    my $expertmode    = AttrVal( $Name, 'MSwitch_Expert', '0' );
    my $debugmode     = AttrVal( $Name, 'MSwitch_Debug', 0 );
    my $selftrigger   = AttrVal( $Name, "MSwitch_Selftrigger_always", 0 );
    my $devicemode    = AttrVal( $Name, 'MSwitch_Mode', $startmode );
    my $triggerdevice = ReadingsVal( $Name, '.Trigger_device', 'no_trigger' );
    my $noshow        = 0;
    my @hidecmds  = split( /,/, AttrVal( $Name, 'MSwitch_Hidecmds', 'undef' ) );
    my $debughtml = "";
    my $testgroups = $data{MSwitch}{$Name}{groups};
    my @msgruppen  = ( keys %{$testgroups} );
    my $info       = '';
    my $system     = "";

    my $futurelevel = AttrVal( $Name, 'MSwitch_Futurelevel', '0' );
    my $comsystem   = "";
    my $confdevice  = "";
    my $offlinemsg  = "";
	my $undomode="off";
	my $experimentalmode="off";
	
	
    my @found_devices = devspec2array("TYPE=MSwitch:FILTER=.msconfig=1");
    if ( @found_devices > 0 ) {
        $rename  = ReadingsVal( $found_devices[0], 'MSwitch_rename',  'off' );
        $showcom = ReadingsVal( $found_devices[0], 'MSwitch_Komment', 'off' );
		
		$undomode = ReadingsVal( $found_devices[0], 'MSwitch_Undo', 'off' );
		
		$experimentalmode = ReadingsVal( $found_devices[0], 'MSwitch_Experimental', 'off' );
		
        $confdevice = $found_devices[0];
		$hash->{MSwitch_Configdevice}                          = 'installed';
		
		
		#if ( ReadingsVal( $found_devices[0], 'MSwitch_Experimental', 'off' ) eq "on" )
		
		
		
		if ( $undomode eq "on" )
		{
			$hash->{MSwitch_Undo_mode} = 'on';
			
		
			
		}
		else{
			delete $hash->{MSwitch_Undo_mode};
		}

		if ( $experimentalmode eq "on" )
		{
		$hash->{MSwitch_Experimental_mode} = 'on';
		# on backup exists
		my $pfad =  AttrVal( 'global', 'backupdir', $restoredirn ) ;
		$pfad.="/MSwitch/";
		my $dateiname=$pfad."MSwitch_Experimental_".$Name.".txt";
		if (-e $dateiname)
		{
			$hash->{MSwitch_Experimental_mode} = 'on backup exists';
			}
		}
		else{
			$hash->{MSwitch_Experimental_mode} = 'off';
			delete $hash->{MSwitch_Experimental_mode};
		}
	
    }
    else {
        $rename  = "off";
        $showcom = "off";
		$hash->{MSwitch_Configdevice}                          = 'not installed';
		$hash->{MSwitch_Experimental_mode} = 'off';
    }

    if ( exists $data{MSwitch}{runningbackup}
        && $data{MSwitch}{runningbackup} eq "ja" )
    {

        $offlinemsg =
"<table border='0' class='block wide' id='MSwitchWebTR' nm='$hash->{NAME}' cellpadding='4' style='border-spacing:0px;'>
						<tr>
						<td style='height: MS-cellhighstandart;width: 100%;' colspan='3'>
						<center>MSwitch-System ist Offline ( Restoremodus ). Fhemneustart erforderlich.
						</td>
						</tr>
					</table><br>";
    }

    MSwitch_defineWidgets($hash);

    if ( AttrVal( $Name, 'MSwitch_Comment_to_Room', '0' ) eq "1"
        || $showcom eq "on" )
    {
        my $current = AttrVal( $Name, "comment", "" );
        if ( $current ne "" ) {
            $comsystem =
              "<table border='0'  cellpadding='4' style='border-spacing:0px;'>
				<tr>
				<td>&nbsp;</td>
				<td style='height: MS-cellhighstandart;width: 100%;' >
				$current
				</td>
				<td>&nbsp;</td>
				</tr>
			</table>";
        }
    }

    if (   AttrVal( $Name, 'MSwitch_SysExtension', "0" ) =~ m/(0|1)/s
        && exists $data{MSwitch}{$Name}{Ansicht}
        && $data{MSwitch}{$Name}{Ansicht} eq "room" )
    {
        if ( $comsystem ne "" ) { return $comsystem }
        return;
    }

    my @affecteddevices =
      split( /,/, ReadingsVal( $Name, '.Device_Affected', 'no_device' ) );
    my $affectednames = ReadingsVal( $Name, '.Device_Affected', 'no_device' );
    $affectednames =~ s/-AbsCmd[1-9]{1,3}//g;
    $affectednames =~ s/MSwitch_Self/$Name/g;
    my @affectedklartext = split( /,/, $affectednames );

    if (   AttrVal( $Name, 'MSwitch_SysExtension', "0" ) =~ m/(1|2)/s
        && ReadingsVal( $Name, '.sysconf', '' ) ne "" )
    {
  
		$system = MSwitch_Asc(ReadingsVal( $Name, '.sysconf', '' ));
        ## platzhalter fuer benoetigte readings (informid)
		#$system="<div id=\"\$Nameweekdayreading\" style=\"display: none;\"></div><span id='\$Nameinnersystem'></span>".$system;
        $system =
            "<script type=\"text/javascript\">var nameself ='"
          . $Name
          . "';</script>"
          . $system;

        ###############################

        if ( $system =~ m/\[Reading:(.*?)\]/s ) {
            my $count = 0;
            while ( $system =~ m/\[Reading:(.*?)\]/s ) {
                $count++;
                last if $count > 100;
                my $argumente;
                my $orgwidget = $1;
                my @args = ( split /:/, $1 );
                if ( @args == 1 ) {
                    my $reading = $args[0];
                    my $current = ReadingsVal( $Name, $reading, 'undef' );
                    my $widget  = "";
                    $widget ="<span class=\"dval\" informid=\"$Name-$reading\">$current</span>";
                    $system =~ s/\[Reading:$orgwidget\]/$widget/g;
                }
            }
        }

################

	my $tmswitchsetlist = AttrVal( $Name, 'MSwitch_setList', "undef" );
	if ($tmswitchsetlist ne "undef"){
            my @testdynsetlist = split( / /, $tmswitchsetlist );

            foreach my $test (@testdynsetlist) {
					# Anwenden_auf:[TYPE=MSwitch]
					if ( $test =~ m/(.*):\[(.*)\](.*)/ ) {
                    my @tfound_devices = devspec2array($2);
					
					my $testreadingarg = join( ',', @tfound_devices );
                    my $tsetreading            = $1;
					$data{MSwitch}{mssetlist}{$tsetreading} = $testreadingarg;
                }
			}      
		}
        

##############
        if ( $system =~ m/\[RAW:(.*?)\]/s ) {
            my $count = 0;
            while ( $system =~ m/\[RAW:(.*?)\]/s ) {
                $count++;
                last if $count > 100;
                my $argumente;
                my $orgwidget = $1;

                my @args = ( split /:/, $1 );
                if ( @args == 1 ) {
                    my $reading = $args[0];
                    my $current = ReadingsVal( $Name, $reading, 'undef' );
                    my $widget  = "$current";
                    $system =~ s/\[RAW:$orgwidget\]/$widget/g;
                }
            }
        }

        if ( $system =~ m/\[Widget:(.*?)\]/s ) {
            my $setlist = AttrVal( $Name, 'setList', "" );
            $setlist =~ s/\n/ /g;
            my @slist = split / /, $setlist;
            foreach (@slist) {
                my ( $sname, $sargs ) = split( /:/, $_, 2 );
                next if ( !defined $sname );
                $data{MSwitch}{$Name}{setlist}{$sname} = $sargs;
            }
            my $count = 0;
            while ( $system =~ m/\[Widget:(.*?)\]/s ) {
                $count++;
                last if $count > 100;
                my $argumente;
                my $orgwidget = $1;
                my @args      = ( split /:/, $1, 2 );
                my $reading   = $args[0];
                my $current   = ReadingsVal( $Name, $reading, 'undef' );
                if ( defined $args[1] ) {
                    $argumente = $args[1];
				}
                else {
                    $argumente = $data{MSwitch}{$Name}{setlist}{$reading};
                }
				
				if (exists $data{MSwitch}{mssetlist}{$reading}) 
				{
				$argumente=	$data{MSwitch}{mssetlist}{$reading};
				}
                my $widget =
                    "<div class='fhemWidget' cmd='"
                  . $reading
                  . "' reading='"
                  . $reading
                  . "' dev='"
                  . $Name
                  . "' arg='"
                  . $argumente
                  . "' current='"
                  . $current
                  . "'></div>";
                $system =~ s/\[Widget:$orgwidget\]/$widget/g;
            }
        }
	delete $data{MSwitch}{mssetlist};


        #################################

        if ( $system =~ m/\[MSwitch_Widget:(.*?)\]/s ) {
            foreach my $a ( keys %{ $data{MSwitch}{$Name}{activeWidgets} } ) {
                my $lastpart = "";
                while ( $system =~ m/\[MSwitch_Widget:$a(.*?)\]/s ) {
                    my $html    = $data{MSwitch}{Widget}{$a}{html};
                    my $reading = "";
                    if ( defined $1 ) {
                        $lastpart = $1;
                        my @args = split( /:/, $1, 2 );
                        if ( defined $args[1] ) {
                            my @string = split( /,/, $args[1] );
                            my @stringcompl = split( /,/, $args[1], 2 );
                            $html =~ s/READING/$string[0]/g;
                            my $current =
                              ReadingsVal( $Name, $string[0], 'undef' );
                            $html =~ s/CURRENT/$current/g;
                            $html =~ s/MIN/$string[1]/g  if defined $string[1];
                            $html =~ s/MAX/$string[3]/g  if defined $string[3];
                            $html =~ s/STEP/$string[2]/g if defined $string[2];
                            $html =~ s/ARGS/$stringcompl[1]/g
                              if defined $stringcompl[1];
                        }
                    }
                    $system =~
s/\[MSwitch_Widget:$a$lastpart\]/$data{MSwitch}{Widget}{$a}{script}$html/g;
                }
            }
        }

        $system =~ s/\$Name/$Name/g;
        $system =~ s/\$Callfrom/$data{MSwitch}{$Name}{Ansicht}/g;
        $system =~ s/#\[nl\]/\n/g;

        ## ersetze benoetigte readings fuer widgets
        my $x = 0;
        while ( $system =~ m/(.*)\[ReadingVal\:(.*)\:(.*)\](.*)/ ) {
            $x++;    # notausstieg notausstieg
            my $setmagic = ReadingsVal( $2, $3, 0 );
            $system =~ s/\[ReadingVal:$2:$3\]/$setmagic/g;
            last if $x > 20;    # notausstieg notausstieg
        }
    }

########## korrigiere version
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
"Device befindet sich im passiven Dummymode, fuer den aktiven Dummymode muss dass Attribut 'MSwitch_Selftrigger_always' auf '1' gesetzt werden. ";
        $MSDISTRIBUTORTEXT  = "Zuordnung Event/ID";
        $MSDISTRIBUTOREVENT = "eingehendes Event";
        $LOOPTEXT =
"ACHTUNG: Der Safemodus hat eine Endlosschleife erkannt, welche zum Fhemabsturz fuehren koennte.<br>Dieses Device wurde automatisch deaktiviert ( ATTR 'disable') !<br>&nbsp;";
        $ATERROR = "AT-Kommandos koennen nicht ausgefuehrt werden !";
        $PROTOKOLL2 =
"Das Device befindet sich im Debug 2 Mode. Es werden keine Befehle ausgefuehrt, sondern nur protokolliert.";
        $PROTOKOLL3 =
"Das Device befindet sich im Debug 3 Mode. Alle Aktionen werden protokolliert.";
        $CLEARLOG    = "loesche Log";
        $CLEARWINDOW = "loesche Fenster";
        $STOPLOG     = "Liveansicht";
        $WRONGSPEC1 =
"Format HH:MM<br>HH muss kleiner 24 sein<br>MM muss < 60 sein<br>Timer werden nicht ausgefuehrt";
        $WRONGSPEC2 =
"Format HH:MM<br>HH muss < 24 sein<br>MM muss < 60 sein<br>Bedingung gilt immer als FALSCH";
        $HELPNEEDED = "Eingriff erforderlich !";
        $WRONGCONFIG =
"Einspielen des Configfiles nicht moeglich !<br>falsche Versionsnummer:";
        $VERSIONCONFLICT =
"Versionskonflikt erkannt!<br>Das Device fuehrt derzeit keine Aktionen aus. Bitte ein Update des Devices vornehmen.<br>Erwartete Strukturversionsnummer: $vupdate<br>Vorhandene Strukturversionsnummer: $ver ";
        $INACTIVE = "Device ist nicht aktiv";
        $OFFLINE  = "Device ist abgeschaltet, Konfiguration ist moeglich";
        $NOCONDITION =
"Es ist keine Bedingung definiert, das Kommando wird immer ausgefuehrt";
        $NOSPACE =
"Befehl kann nicht getestet werden. Das letzte Zeichen darf kein Leerzeichen sein.";
        $EXECCMD      = "augefuehrter Befehl:";
        $RELOADBUTTON = "Aktualisieren";
        $RENAMEBUTTON = "Name aendern";
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
    # loesche saveddevicecmd #
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

    #$hidden = '';

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
        push( @eventsallnew, $name ) if ( $name ne "match_sequenz" );
    }

    if ( AttrVal( $Name, 'MSwitch_Sequenz', '0' ) ne "0" )

    {
        push @eventsallnew, 'match_sequenz';

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

        if ( $_ eq 'no_trigger' ) { next LOOP12; }

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

    }

    # selectfield aller verfuegbaren events erstellen

    my @alloptions = @eventsall;

    push @alloptions, $triggeron, $triggeroff, $triggercmdoff, $triggercmdon;

    my %seen;
    @alloptions = grep { !$seen{$_}++ } @alloptions;

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

#############################################

    my $optioncmdoff = '';
    my $optionoff    = '';
    $to  = '';
    $toc = '';
    my $seqmatchoff    = '';
    my $seqmatchcmdoff = '';

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

    # moegliche affected devices und moegliche triggerdevices
    my $devicesets;
    my $deviceoption = "";
    my $selected     = "";
    my $errors       = "";
    my $javaform     = "";    # erhaelt javacode fuer uebergabe devicedetail
    my $cs           = "";
    my %cmdsatz;              # ablage desbefehlssatzes jedes devices
    my $globalon  = 'off';
    my $globalon1 = 'off';
    my @devicestotrigger;
    my @devicestotriggerzusatz;
    my $devicetotriggerselect = "no_trigger";

    push( @devicestotrigger,       "no_trigger" );
    push( @devicestotriggerzusatz, "no_trigger" );

    if ( ReadingsVal( $Name, '.Trigger_device', 'no_trigger' ) eq 'no_device' )
    {
        $devicetotriggerselect = "no_trigger";
    }

    if ( ReadingsVal( $Name, '.Trigger_device', 'no_trigger' ) eq 'no_trigger' )
    {
        $devicetotriggerselect = "no_trigger";
    }

    if ( $expertmode eq '1' ) {
        push( @devicestotrigger,       "all_events" );
        push( @devicestotriggerzusatz, "GLOBAL" );
        if ( ReadingsVal( $Name, '.Trigger_device', 'no_trigger' ) eq
            'all_events' )
        {
            $globalon              = 'on';
            $devicetotriggerselect = "all_events";
        }
    }

    if ( AttrVal( $Name, 'MSwitch_Read_Log', "0" ) eq '1' ) {
        push( @devicestotrigger,       "Logfile" );
        push( @devicestotriggerzusatz, "LOGFILE" );
        if (
            ReadingsVal( $Name, '.Trigger_device', 'no_trigger' ) eq 'Logfile' )
        {
            $devicetotriggerselect = "Logfile";
        }
    }

    push( @devicestotrigger,       "MSwitch_Self" );
    push( @devicestotriggerzusatz, "MSwitch_Self ($Name)" );
    if ( ReadingsVal( $Name, '.Trigger_device', 'no_trigger' ) eq
        'MSwitch_Self' )
    {
        $devicetotriggerselect = "MSwitch_Self";
    }

    if ( !defined $devicetotriggerselect ) {

        MSwitch_LOG( $Name, 5,
            "$Name:undefined devicetotriggerselect - setze no_trigger" );
        $devicetotriggerselect = "no_trigger";
    }

################# achtung doppelsplit

    my $affecteddevices = ReadingsVal( $Name, '.Device_Affected', 'no_device' );

    # affected devices to hash
    my %usedevices;
    my @deftoarray = split( /,/, $affecteddevices );

    my $anzahl     = @deftoarray;
    my $anzahl1    = @deftoarray;
    my $anzahl3    = @deftoarray;

    my @testidsdev1 = MSwitch_Load_Details($hash);
	my @testidsdev= @testidsdev1;

    #PRIORITY
    # teste auf groessere PRIORITY als anzahl devices
    foreach (@testidsdev) {
        last if $_ eq "no_device";
        my @testid = split( /#\[NF\]/, $_ );
        my $x      = 0;
        my $id     = $testid[13];

        if ( defined $id ) {
            $anzahl = $id if $id > $anzahl;
        }
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
    # teste auf groessere PRIORITY als anzahl devices
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
        && AttrVal( $Name, "MSwitch_Selftrigger_always", 0 ) == 0 )
    {
        $notype = ".*";
    }

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

    my $includewebcmd = AttrVal( $Name, 'MSwitch_Include_Webcmds', "0" );
	
	
    my $extensions    = AttrVal( $Name, 'MSwitch_Extensions',      "0" );
    my $MSwitchIncludeMSwitchcmds =
      AttrVal( $Name, 'MSwitch_Include_MSwitchcmds', "1" );
    my $MSwitchIncludeDevicecmds =
      AttrVal( $Name, 'MSwitch_Include_Devicecmds', "1" );
    my $Triggerdevicetmp = ReadingsVal( $Name, '.Trigger_device', '' );
    my $savecmds =
      AttrVal( $Name, 'MSwitch_DeleteCMDs', $deletesavedcmdsstandart );

    my @alldevices;
    my @alldevicesalias;
    my @selecteddevices;
    my @alldevicestype;
    my @alldevicesselected;

    my @nondevices;
    my $alert1 = "";

    if (   $triggerdevice ne "no_device"
        && $triggerdevice ne ""
        && $triggerdevice ne "MSwitch_Self"
        && $triggerdevice ne "all_events"
        && $triggerdevice ne "no_trigger" )
    {

        my $found1 = grep( /^$triggerdevice$/, @found_devices );
        my $found2 = grep( /^$triggerdevice$/, @msgruppen );
        if ( $found1 == 0 && $found2 == 0 ) {
            push( @nondevices,    $triggerdevice );
            push( @found_devices, $triggerdevice );

            $alert1 =
'<span style="display:inline-block; padding: 4px; border:1px solid black; background: red;">Dieses Device ist nicht vorhanden, Namenskorrektur noetig: ';
            $alert1 .=
                "<input style='display:none;' disabled name='' id ='ren1_"
              . $triggerdevice
              . "' type='text' value='$triggerdevice'>";
            $alert1 .= "";
            $alert1 .=
                "<input name='' id ='ren2_"
              . $triggerdevice
              . "' type='text' value=''>";
            $alert1 .=
"&nbsp;<input name='' type='button' value='umbenennen' onclick=\"rename('"
              . $triggerdevice . "')\">";
            $alert1 .= "</span>";
        }
    }

    for my $testname (@affectedklartext) {
        next if $testname eq "FreeCmd";
        my $found = grep( /^$testname$/, @found_devices );
        if ( $found == 0 ) {
            push( @nondevices,    $testname );
            push( @found_devices, $testname );
        }
    }


  LOOP9: for my $name ( sort @found_devices ) {
        next if ( $name eq "no_device" );
        my @gefischt = grep( /$name/, @affectedklartext );

        my $selectedtrigger = '';
        my $devicealias = AttrVal( $name, 'alias', "" );
        my $devicewebcmd = AttrVal( $name, 'webCmd', "noArg" );    # webcmd des devices
        my $devicehash = $defs{$name};            #devicehash
		my $deviceTYPE = "";
        $deviceTYPE = $devicehash->{TYPE} if exists $devicehash->{TYPE};

        # triggerfile erzeugen
        if ( $Triggerdevicetmp eq $name ) {
            $selectedtrigger = 'selected=\"selected\"';
            if ( $name eq 'all_events' ) { $globalon = 'on' }
            $devicetotriggerselect = "$name";
        }
        push( @devicestotrigger, "$name" );
        my $inhalt = "$name (a:$devicealias t:$deviceTYPE)";

        $inhalt =~ s/\'//g;
        push( @devicestotriggerzusatz, $inhalt );

        # filter auf argumente on oder off ;
        if ( $name eq '' ) { next LOOP9; }

        # abfrage und auswertung befehlssatz
        if (    $MSwitchIncludeDevicecmds eq '1' and $hash->{MSwitch_Init} ne "define" and @gefischt > 0 )
        {
            if ( exists $data{MSwitch}{devicecmds1}{$name}&& $savecmds ne "nosave" )
            {
                $cmdfrombase = "1";
                $errors      = $data{MSwitch}{devicecmds1}{$name};
            }
            else 
			{
                $errors = getAllSets($name);
                if ( $savecmds ne "nosave" ) 
				{
                    $data{MSwitch}{devicecmds1}{$name} = $errors;
                    $data{MSwitch}{last_devicecmd_save} = time;
                }
            }
        }
        else 
		{
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
            and $hash->{MSwitch_Init} ne "define" )
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

        if ( $MSwitchIncludeMSwitchcmds eq '1' and $hash->{MSwitch_Init} ne "define" ) {
            my $usercmds = AttrVal( $name, 'MSwitchcmd', '' );
            if ( $usercmds ne '' ) {
                $usercmds =~ tr/:/ /;
                $errors .= ' ' . $usercmds;
            }
        }

        if ( $extensions eq '1' ) {
            $errors .= ' ' . 'MSwitchtoggle:textfieldLong';
        }

        $errors .= ' ' . '[FREECMD]:textfieldLong';

        if ( $errors ne '' ) {
            if ( exists $usedevices{$name} && $usedevices{$name} eq 'on' ) {
                push( @alldevicesselected, $name );
            }

            # befehlssatz fuer device in scalar speichern
            $cmdsatz{$name} = $errors;
            $devicealias =~ s/\'//g;
            push( @alldevicesalias, $devicealias );
            push( @alldevices,      $name );
            push( @alldevicestype,  InternalVal( $name, 'TYPE', '' ) );

        }
        else {
            #nothing
        }
    }

    # FREECMD zufuegen
    my $select = index( $affecteddevices, 'FreeCmd', 0 );
    if ( $select > -1 ) {
        push( @alldevicesselected, 'FreeCmd' );
    }

    # MSWITCH SELF zufuegen

    $select = index( $affecteddevices, 'MSwitch_Self', 0 );
    if ( $select > -1 ) {
        push( @alldevicesselected, 'MSwitch_Self' );
    }

    # GRUPPENSUCHEN
    my @areadings = ( keys %{ $data{MSwitch}{$Name}{groups} } );
    foreach my $key (@areadings) {

        my $fullname = $key;
        my $re       = qr/$fullname/;
        my @test     = grep ( /$re/, @deftoarray );
        if ( @test > 0 ) {

            if ( grep( /$key/, @alldevicesselected ) == 0 ) {

                push( @alldevicesselected, $key );
            }

        }
        push( @alldevicesalias, "" );
        push( @alldevices,      $key );
        push( @alldevicestype,  InternalVal( $key, 'TYPE', '' ) );
    }

####

    unshift @alldevices, "MSwitch_Self";
    unshift( @alldevicesalias, "" );
    unshift( @alldevicestype,  "MSwitch" );
    unshift @alldevices, "FreeCmd";
    unshift( @alldevicestype, "MSwitch" );

####################
    # #devices details
    # steuerdatei
    my $controlhtml;
    $controlhtml = "
<!-- folgende HTML-Kommentare duerfen nicht geloescht werden -->
<!-- 
info: festlegung einer zellenhoehe
MS-cellhigh=30;
-->
<!-- 
start:textersetzung:ger
long code - press info for more details->lange Codezeile - Info für mehr Details
action unsaved - save all actions->Aktion nicht gespeichert - Alle Aktionen speichern
info->Info
edit action->bearbeiten
close action->minimieren
Set->Schaltbefehl&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
Hidden command branches are available->Ausgeblendete Befehlszweige vorhanden
condition:->Schaltbedingung
show hidden cmds->ausgeblendete Befehlszweige anzeigen
show IDs->zeige Befehlszweige mit der ID
execute and exit if applies->Abbruch nach Ausfuehrung
Repeats:->Befehlswiederholungen:
Repeatdelay in sec:->Wiederholungsverzoegerung in Sekunden:
delay with Cond-check immediately and delayed:->Verzoegerung mit Bedingungspruefung sofort und vor Ausfuehrung:
delay with Cond-check immediately only:->Verzoegerung mit Bedingungspruefung sofort:
delay with Cond-check delayed only:->Verzoegerung mit Bedingungspruefung vor Ausfuehrung:
readingname(ident)->readingname(ident)
at with Cond-check immediately and delayed:->Ausfuehrungszeit mit Bedingungspruefung sofort und vor Ausfuehrung:
at with Cond-check immediately only:->Ausfuehrungszeit mit Bedingungspruefung sofort:
at with Cond-check delayed only->Ausfuehrungszeit mit Bedingungspruefung vor Ausfuehrung:
with Cond-check->Schaltbedingung vor jeder Ausfuehrung pruefen
check condition->Bedingung testen
with->mit
modify Actions->Befehle speichern
device actions sortby:->Sortierung:
add action->zusaetzliche Aktion
delete action->loesche Aktion
edit all->alle bearbeiten
close all->alle minimieren
priority:->Prioritaet:
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
MS-DEVICEID
--> 
<!--MS-AKTDEVICE-EDIT  name='MS-AKTDEVICE-EDIT' id='MS-AKTDEVICE-EDIT'  -->
<!-- start htmlcode -->
<!--start devices -->
	<table border='0' class='block wide' name='' id='' nm='test1' cellpadding='0' style='border-spacing:0px;'>
	<tr>
	<td width='100%' nowrap><strong>
MS-NAMESATZ
</td>
	<td align='right' nowrap>
	<!--
		<input type='button' value='test' onclick='javascript: testfeld(\"MS-AKTDEVICE\") '>
	--> 
	<input id='MS-AKTDEVICE-BUTTON' text1='close action' text2='edit action' name='MS-AKTDEVICE-BUTTON' type='button' value='edit action' onclick='javascript: showedit(\"MS-AKTDEVICE\") '>
	<input id='' name='' type='button' value='Info' onclick='javascript: Fullinf(\"MS-AKTDEVICE\") '>

	MS-ACTIONSATZ&nbsp;&nbsp;&nbsp;
	</td>
	
	<td align='right' nowrap>
	MS-IDSATZ&nbsp;MS-HELPpriority
	</td>
	</tr>
	
	<tr name='MS-AKTDEVICE-PLAIN'>
	<td colspan='3' nowrap>&nbsp;</td>
	</tr>
	
	<tr name='MS-AKTDEVICE-PLAIN'>
	<td width='100%' colspan='2' nowrap >MS-SET1PLAIN</td>
	
	<td align='right'>
	</td>
    </tr>

	<tr>
	<td colspan='3'>MS-COMMENTset</td>
	</tr>

<!-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXx -->

<tr style='display: none;'>
	<td colspan='3'><input type='text' size ='100'  id='MS-AKTDEVICE-SAVE' value='empty'></td>
	</tr>

<tr style='display: none;' id='MS-AKTDEVICE-SAVE-BUTTON'  >
	<td colspan='3'>&nbsp;<br><input onclick='setTimeout(function() {
            formsubmit();}, 100);' style=' BACKGROUND-COLOR: red;' type='Button' value='action unsaved - save all actions'></td>
	</tr>
	
<!-- xxx -->	
<tr name='MS-AKTDEVICE-EDIT' style='display:none;'>	<td colspan='3'><hr>
	</td>
	</tr>
	
<tr name='MS-AKTDEVICE-EDIT' style='display:none;'>	<td colspan='3'>

	<table border='0'>
	
	<tr>
	<td rowspan='6'>CMD&nbsp;1&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>
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
		
	</table>
		</td>
	</tr>
	
<!-- xxx -->	
		
<tr name='MS-AKTDEVICE-EDIT' style='display:none;'>	<td colspan='3'><hr>
	</td>
	</tr>

<tr name='MS-AKTDEVICE-EDIT' style='display:none;'>	<td colspan='3'>
	<table border='0'>
	<tr>
		<td rowspan='6'>CMD&nbsp;2&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>
	</tr>
		
		<tr>
		<td>MS-HELPonoff</td>
		<td style='height: MS-cellhighstandart;width: 100%;'>MS-SET2</td>
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
		<td style='height: MS-cellhighexpert;width: 100%'>MS-DELAYset2</td>
	</tr>
		
		</table>
		
		</td>
	</tr>
<!-- xxx -->	

<tr name='MS-AKTDEVICE-EDIT' style='display:none;'>	<td colspan='3'><hr>
	</td>
	</tr>
	<tr name='MS-AKTDEVICE-EDIT' style='display:none;'>
		<td style='height: MS-cellhighexpert;'colspan='3' nowrap>MS-HELPrepeats&nbsp;MS-REPEATset</td>
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

    my $detailhtml = "";

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
    if ( $devicemode eq "Dummy" && $selftrigger == 0 ) {
        $affecteddevices[0] = 'no_device';
    }
    my $sortierung = "";
    my $modify     = "";
    my $saveline   = "";
    my $IDsatz     = "";
    my $NAMEsatz   = "";
    my $PNAMEsatz  = "";
    my $ACTIONsatz = "";

    my $SET1PLAIN = "";
    my $SET1      = "";
    my $SET2      = "";

    my $AKTDEVICE     = "";
    my $COND1set1     = "";
    my $COND1check1   = "";
    my $COND2check2   = "";
    my $COND1set2     = "";
    my $EXECset1      = "";
    my $EXECset2      = "";
    my $DELAYset1     = "";
    my $DELAYset2     = "";
    my $REPEATset     = "";
    my $COMMENTset    = "";
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
        if ( $hash->{MSwitch_Init} ne 'define' ) {
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

        $saveline =
"<table width = '100%' border='0' class='block wide' id='MSwitchDetails' cellpadding='4' style='border-spacing:0px;' nm='MSwitch'>
			<tr class='even'><td>
			<input type='button'
			onclick='setTimeout(function() {
            formsubmit();}, 100);'
			value='modify Actions' >&nbsp;$sortierung
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



#$_ =~ s/\./\\./g;


            my $aktdevice = $_;
			#$aktdevice =~ s/\./point/g;
			
			
            my $nopoint   = $_;
           # 
			 my $nopointx   = $_;
			#$nopointx =~ s/\./\\./g;
            $alert = '';
            my @devicesplit = split( /-AbsCmd/, $_ );
            my $devicenamet = $devicesplit[0];
            my $re          = qr/$devicenamet/;

            # test auf nicht vorhandenes geraet

            my $found2 = grep( /^$devicenamet$/, @msgruppen );
            if ( $devicenamet ne "FreeCmd" && $found2 == 0 ) {
                my $foundnondev = grep( /^$devicenamet$/, @nondevices );

                if ( $foundnondev > 0 ) {
                    $alert =
'<span style="display:inline-block; padding: 4px; border:1px solid black; background: red;"> Dieses Device ist nicht vorhanden, Namenskorrektur noetig: ';
                    $alert .=
                      "<input style='display:none;' disabled name='' id ='ren1_"
                      . $aktdevice
                      . "' type='text' value='$devicenamet'>";
                    $alert .= "";
                    $alert .=
                        "<input name='' id ='ren2_"
                      . $aktdevice
                      . "' type='text' value=''>";
                    $alert .=
"&nbsp;<input name='' type='button' value='umbenennen' onclick=\"rename('"
                      . $aktdevice . "')\">";
                    $alert .= "</span>";
                    $cmdsatz{$devicenamet} =
                        $savedetails{ $aktdevice . '_on' } . " "
                      . $savedetails{ $aktdevice . '_off' };
                }

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

            @befehlssatz = split( / /, $cmdsatz{$devicenamet} )if exists $cmdsatz{$devicenamet};

            ## optionen erzeugen
            my $option1html  = '';
            my $option2html  = '';
            my $selectedhtml = "";

            foreach (@befehlssatz)    #befehlssatz einfuegen
            {
                my @aktcmdset =
                  split( /:/, $_ );    # befehl von noarg etc. trennen
                $selectedhtml = "";
                next if !defined $aktcmdset[0];    #changed 19.06
                if ( $aktcmdset[0] eq $savedetails{ $aktdevice . '_on' } ) {
                    $selectedhtml = "selected=\"selected\"";
                }
                $option1html .=
"<option $selectedhtml value=\"$aktcmdset[0]\">$aktcmdset[0]</option>";
                $selectedhtml = "";
                if ( $aktcmdset[0] eq $savedetails{ $aktdevice . '_off' } ) {
                    $selectedhtml = "selected=\"selected\"";
                }
                $option2html .=
"<option $selectedhtml value=\"$aktcmdset[0]\">$aktcmdset[0]</option>";
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
"$zusatz $devicenamet $alert $realname&nbsp;&nbsp;$groupbutton&nbsp;&nbsp;$dalias";

                #   $NAMEsatz ="$realname";

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
                  if ( $hash->{MSwitch_Init} ne 'define' );
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
                  if ( $hash->{MSwitch_Init} ne 'define' );

                # ende
            }
            else {    #$devicenamet
                $NAMEsatz =
"$zusatz $devicenamet $alert $realname&nbsp;&nbsp;$groupbutton&nbsp;&nbsp;$dalias";

                #$PNAMEsatz ="$devicenamet";

                my $aktfolge = $showfolgehtml;
                my $newname  = "showreihe" . $nopoint;
                my $tochange =
"<option value='$savedetails{ $aktdevice . '_showreihe' }'>$savedetails{ $aktdevice . '_showreihe' }</option>";
                my $change =
"<option selected value='$savedetails{ $aktdevice . '_showreihe' }'>$savedetails{ $aktdevice . '_showreihe' }</option>";
                $aktfolge =~ s/showreihe/$newname/g;
                $aktfolge =~ s/$tochange/$change/g;
                $IDsatz .= "displaysequence: " . $aktfolge . "&nbsp;"
                  if ( $hash->{MSwitch_Init} ne 'define' );

                $aktfolge = $hidehtml;
                $newname  = "hidecmd" . $nopoint;
                $tochange =
                  "<option value='$savedetails{ $aktdevice . '_hidecmd' }'>";
                $change =
"<option selected value='$savedetails{ $aktdevice . '_hidecmd' }'>";
                $aktfolge =~ s/hidecmd/$newname/g;
                $aktfolge =~ s/$tochange/$change/g;
                $IDsatz .= "hide display: " . $aktfolge . "&nbsp;"
                  if ( $hash->{MSwitch_Init} ne 'define' );

            }

##### bis hier ok hier ist nach ueberschrift
##### kommentare
            my $noschow = "style=\"display:none\"";
            if ( AttrVal( $Name, 'MSwitch_Comments', "0" ) eq '1' ) {
                $noschow = '';
            }

            #kommentar
            if ( AttrVal( $Name, 'MSwitch_Comments', "0" ) eq '1' ) {
                my @a = split( /\n/, $savedetails{ $aktdevice . '_comment' } );
                my $lines = @a;
                $lines = 3 if $lines == 0;

                $COMMENTset =
"<br><table><tr><td>&nbsp;</td><td width=100%><center><textarea rows=\"$lines\" style=\"width:97%;\"  id='cmdcomment"
                  . $_
                  . "1' name='cmdcomment"
                  . $nopoint . "'>"
                  . $savedetails{ $aktdevice . '_comment' }
                  . "</textarea></td><td>&nbsp</td></tr></table><br>";
            }

            if ( $devicenamet ne 'FreeCmd' ) {

                $SET1PLAIN = "<table border=0>";
                $SET1PLAIN .=
                    "<tr><td id='"
                  . $_
                  . "_plain1'>CMD1: "
                  . $savedetails{ $aktdevice . '_on' } . " "
                  . $savedetails{ $aktdevice . '_onarg' }
                  . "</td></tr>";
                $SET1PLAIN .=
                    "<tr><td id='"
                  . $_
                  . "_plain2'>CMD2: "
                  . $savedetails{ $aktdevice . '_off' } . " "
                  . $savedetails{ $aktdevice . '_offarg' }
                  . "</td></tr>";
                $SET1PLAIN .= "</table>";

                # nicht freecmd
                $SET1 = "<table width='100%' border ='0'><tr>
					<td nowrap>&nbsp;Set<select class=\"devdetails2\" id='"
                  . $_
                  . "_on' name='cmdon"
                  . $nopoint
                  . "' onchange=\"javascript:
				  activate(document.getElementById('"
                  . $_
                  . "_on').value, '"
                  . $_
                  . "_on_sel', '"
                  . $cmdsatz{$devicenamet}
                  . "', 'cmdonopt"
                  . $_ . "1')
				  \" >
					<option value='no_action'>no_action</option>" . $option1html . "</select>
					</td>";

                $SET1 .=
                    "<td><input type='$hidden' id='cmdseton"
                  . $_
                  . "' name='cmdseton"
                  . $nopoint
                  . "' size='30'  value ='"
                  . $cmdsatz{$devicenamet} . "'>
					<input type='$hidden' id='cmdonopt"
                  . $_
                  . "1' name='cmdonopt"
                  . $nopoint
                  . "' size='30'  value ='"
                  . $savedetails{ $aktdevice . '_onarg' } . "'>
					  </td>
					  <td nowrap id='" . $_ . "_on_sel'></td>
					  <td nowrap id='" . $_ . "_on_sel_widget'></td>
					  
					  ";

                if ( AttrVal( $Name, 'MSwitch_use_WebWidgets', $webwidget ) ==
                    1 )
                {
                    $SET1 .=
                        "<td  align='right' width='100%'><input id='"
                      . $_
                      . "_on_sel_but' type='button' value='Widget/Text' onclick='javascript: changeinput(\""
                      . $_
                      . "_on_sel\",\"cmdonopt"
                      . $_
                      . "1\",\""
                      . $cmdsatz{$devicenamet} . "\",\""
                      . $_
                      . "_on\")''>&nbsp;</td>";
                }
                else {
                    $SET1 .= "<td width='100%'></td>";
                }

                $SET1 .= " </tr></table>
					  ";
            }
            else {
                # freecmd
                $SET1PLAIN = "<table border=0>";
                my $onlenght  = length $savedetails{ $aktdevice . '_onarg' };
                my $offlenght = length $savedetails{ $aktdevice . '_offarg' };
                if ( $onlenght > $codelenght ) {
                    $SET1PLAIN .=
                        "<tr><td cut ='"
                      . $codelenght
                      . "' text='CMD1: long code - press info for more details' id='"
                      . $_
                      . "_plain1'>CMD1: long code - press info for more details</td></tr>";
                }
                else {
                    $SET1PLAIN .=
                        "<tr><td cut ='"
                      . $codelenght
                      . "' text='CMD1: long code - press info for more details' id='"
                      . $_
                      . "_plain1'>CMD1: "
                      . $savedetails{ $aktdevice . '_on' } . " "
                      . $savedetails{ $aktdevice . '_onarg' }
                      . "</td></tr>";
                }
                if ( $offlenght > $codelenght ) {
                    $SET1PLAIN .=
                        "<tr><td cut ='"
                      . $codelenght
                      . "' text='CMD1: long code - press info for more details' id='"
                      . $_
                      . "_plain1'>CMD2: long code - press info for more details</td></tr>";
                }
                else {
                    $SET1PLAIN .=
                        "<tr><td cut ='"
                      . $codelenght
                      . "' text='CMD1: long code - press info for more details' id='"
                      . $_
                      . "_plain2'>CMD2: "
                      . $savedetails{ $aktdevice . '_off' } . " "
                      . $savedetails{ $aktdevice . '_offarg' }
                      . "</td></tr>";
                }
                $SET1PLAIN .= "</table>";

                $savedetails{ $aktdevice . '_onarg' } =~ s/'/&#039/g;
                $SET1 =
"<textarea onclick=\"javascript: checklines(id+'$_')\" rows='10' id='cmdonopt' style=\"width:97%;\" "
                  . $_
                  . "1' name='cmdonopt"
                  . $nopoint . "'>"
                  . $savedetails{ $aktdevice . '_onarg' }
                  . "</textarea>";

                $SET1 .=
                    "<input type='$hidden' id='"
                  . $_
                  . "_on' name='cmdon"
                  . $nopoint
                  . "' size='20'  value ='cmd'>";
                $SET1 .=
                    "<input type='$hidden' id='cmdseton"
                  . $_
                  . "' name='cmdseton"
                  . $nopoint
                  . "' size='20'  value ='cmd'>";
                $SET1 .=
                    "<span  style='text-align: left;' class='col2' nowrap id='"
                  . $_
                  . "_on_sel'>	</span>			  ";
            }

########################
## block off #$devicename

            if ( $devicenamet ne 'FreeCmd' ) {
                $SET2 = "<table width='100%' border ='0'><tr><td nowrap>
						&nbsp;Set <select class=\"devdetails2\" id='"
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
						</td>";

                $SET2 .= "	<td>
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
                      </td>
					  <td valign='middle' nowrap id='" . $_ . "_off_sel' ></td>
					  <td nowrap id='" . $_ . "_off_sel_widget'></td>
					  ";

                if ( AttrVal( $Name, 'MSwitch_use_WebWidgets', $webwidget ) ==
                    1 )
                {
                    $SET2 .=
                        "<td  align='right' width='100%'><input id='"
                      . $_
                      . "_off_sel_but' type='button' value='Widget/Text' onclick='javascript: changeinput(\""
                      . $_
                      . "_off_sel\",\"cmdoffopt"
                      . $_
                      . "1\",\""
                      . $cmdsatz{$devicenamet} . "\",\""
                      . $_
                      . "_off\")''>&nbsp;</td>";
                }
                else {
                    $SET2 .= "	<td width='100%'></td>";
                }

                $SET2 .= "</tr> </table>
					  ";

                if ( $debugmode eq '1' || $debugmode eq '3' ) {

                    $MSTEST1 =
                        "<input name='info' name='TestCMD"
                      . $_
                      . "' id='TestCMD"
                      . $_
                      . "'type='button' value='test comand' onclick=\"javascript: testcmd('cmdon$nopoint','$devicenamet','cmdonopt$nopoint',document.querySelector('#checkon"
                      . $_
                      . "').value )\">";

                    $MSTEST2 =
                        "<input name='info' name='TestCMD"
                      . $_
                      . "' id='TestCMD"
                      . $_
                      . "'type='button' value='test comand' onclick=\"javascript: testcmd('cmdoff$nopoint','$devicenamet','cmdoffopt$nopoint',document.querySelector('#checkoff"
                      . $_
                      . "').value )\">";

                }
            }
            else {
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

                if ( $debugmode eq '1' || $debugmode eq '3' ) {

                    $MSTEST1 =
                        "<input name='info' name='TestCMD"
                      . $_
                      . "' id='TestCMD"
                      . $_
                      . "'type='button' value='test comand' onclick=\"javascript: testcmd('cmdonopt$nopoint','$devicenamet','not_in_use',document.querySelector('#checkon"
                      . $_
                      . "').value )\">";

                    $MSTEST2 =
                        "<input name='info' name='TestCMD"
                      . $_
                      . "' id='TestCMD"
                      . $_
                      . "'type='button' value='test comand' onclick=\"javascript: testcmd('cmdoffopt$nopoint','$devicenamet','not_in_use',document.querySelector('#checkoff"
                      . $_
                      . "').value )\">";

                }
            }

            $COND1set1 =
"&nbsp;condition: <input class=\"devdetails\" type='text' id='conditionon"
              . $_
              . "' name='conditionon"
              . $nopoint
              . "' size='55' value ='"
              . $savedetails{ $aktdevice . '_conditionon' }
              . "' onClick=\"javascript:bigwindow(this.id,'',1);\">";

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
"&nbsp;condition: <input class=\"devdetails\" type='text' id='conditionoff"
              . $_
              . "' name='conditionoff"
              . $nopoint
              . "' size='55' value ='"
              . $savedetails{ $aktdevice . '_conditionoff' }
              . "' onClick=\"javascript:bigwindow(this.id,'',1);\">";

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

            #### zeitrechner    ABSATZ UAF NOTWENDIGKEIT PRUeF
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

            if ( $expertmode eq '1' ) {
                $savedetails{ $aktdevice . '_countdownon' } =~ s/undefined//g;
                $DELAYset1 .=
"&nbsp;&nbsp;readingname(ident): <input type='text' class=\"devdetails\" id='countdownon"
                  . $nopoint
                  . "' name='countdownon"
                  . $nopoint
                  . "' size='15' value ='"
                  . $savedetails{ $aktdevice . '_countdownon' } . "'>";
            }

            $DELAYset2 = "<select id = '' name='offatdelay" . $nopoint . "'>";
            $se11      = '';
            $sel2      = '';
            $sel3      = '';
            $sel4      = '';
            $sel5      = '';
            $sel6      = '';
            $testkey   = $aktdevice . '_delaylatoff';

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
                $savedetails{ $aktdevice . '_countdownoff' } =~ s/undefined//g;
                $DELAYset2 .=
"&nbsp;&nbsp;readingname(ident): <input type='text' class=\"devdetails\" id='countdownoff"
                  . $nopoint
                  . "' name='countdownoff"
                  . $nopoint
                  . "' size='15' value ='"
                  . $savedetails{ $aktdevice . '_countdownoff' } . "'>";
            }

            if ( $expertmode eq '1' ) {
                $REPEATset =
"Repeats: <input type='text' id='repeatcount' name='repeatcount"
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
                $recon = 'checked'
                  if ( defined $savedetails{ $aktdevice . '_repeatcondition' }
                    && $savedetails{ $aktdevice . '_repeatcondition' } eq '1' );

                $REPEATset .=
                    "<input type=\"checkbox\" $recon name='repeatcond"
                  . $nopoint
                  . "' />&nbsp;with Cond-check";

            }

            $ACTIONsatz =
                "<input name='info' class=\"randomidclass\" id=\"add_action1_"
              . rand(1000000)
              . "\" type='button' value='add action' onclick=\"javascript: addevice('$add')\">";

            $ACTIONsatz .=
                "&nbsp;<input name='info' id=\"del_action1_"
              . rand(1000000)
              . "\" class=\"randomidclass\" type='button' value='delete action' onclick=\"javascript: deletedevice('$_')\">";

######################################## neu ##############################################
            my $controlhtmldevice = $controlhtml;

            # ersetzung in steuerdatei

            $controlhtmldevice =~ s/MS-AKTDEVICE/$aktdevice/g;

            # MS-IDSATZ ... $IDsatz
            $controlhtmldevice =~ s/MS-IDSATZ/$IDsatz/g;

            # MS-NAMESATZ ... $NAMEsatz

            #$NAMEsatz =~ s/&nbsp;/ /g;

            $controlhtmldevice =~ s/MS-NAMESATZ/$NAMEsatz/g;

            #$controlhtmldevice =~ s/MS-PNAMESATZ/$PNAMEsatz/g;

            # MS-ACTIONSATZ ... $ACTIONsatz
            $controlhtmldevice =~ s/MS-ACTIONSATZ/$ACTIONsatz/g;

            # MS-ACTIONSATZ ... $ACTIONsatz

            # MS-SET1PLAIN ... $SET1
            $controlhtmldevice =~ s/MS-SET1PLAIN/$SET1PLAIN/g;

            #$controlhtmldevice =~ s/MS-SET2/$SET2/g;

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
            #zellenhoehe

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

            my $aktpriority = $savedetails{ $aktdevice . '_showreihe' };
            my $aktid       = $savedetails{ $aktdevice . '_id' };

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

            # javazeile fuer uebergabe erzeugen
            $javaform = $javaform . "
			
			
			akd = '$nopoint';
			akd = akd.replace(/\\./,'\\\\.');
			
			devices += \$(\"[name=devicename\"+akd+\"]\").val();
			devices += '#[DN]'; 

			change = \$(\"[name=cmdon\"+akd+\"]\").val();
			devices += change+'#[NF]';

			change= \$(\"[name=cmdoff\"+akd+\"]\").val();
			devices += change+'#[NF]';
			change = \$(\"[name=cmdonopt\"+akd+\"]\").val();

			devices += change+'#[NF]';
			
			change = \$(\"[name=cmdoffopt\"+akd+\"]\").val();
			devices += change+'#[NF]';

			devices = devices.replace(/\\|/g,'#[SR]');
			devices += \$(\"[name=onatdelay\"+akd+\"]\").val();
			devices += '#[NF]';
			devices += \$(\"[name=offatdelay\"+akd+\"]\").val();
			devices += '#[NF]';

			delay1 = \$(\"[name=timesetoff\"+akd+\"]\").val();
			devices += delay1+'#[NF]';
			delay2 = \$(\"[name=timeseton\"+akd+\"]\").val();
			devices += delay2+'#[NF]';
			
			change = \$(\"[name=conditionon\"+akd+\"]\").val();
			change = change.replace(/\\|/g,'(DAYS)');
			devices1 = change;
			
			change = \$(\"[name=conditionoff\"+akd+\"]\").val();
			change = change.replace(/\\|/g,'(DAYS)');
			devices2 = change;

			if(typeof(devices2)==\"undefined\"){devices2=\"\"}
			
			devices += devices1+'#[NF]';
			devices += devices2;
			devices += '#[NF]';
			devices3 = \$(\"[name=repeatcount\"+akd+\"]\").val();
			devices += devices3;
			devices += '#[NF]';
			devices += \$(\"[name=repeattime\"+akd+\"]\").val();
			devices += '#[NF]';
			devices += \$(\"[name=reihe\"+akd+\"]\").val();
			devices += '#[NF]';
			devices += \$(\"[name=idreihe\"+akd+\"]\").val();
			devices += '#[NF]';
			devices += \$(\"[name=cmdcomment\"+akd+\"]\").val();
			devices += '#[NF]';
			devices += \$(\"[name=exit1\"+akd+\"]\").prop(\"checked\") ? \"1\":\"0\";
			devices += '#[NF]';
			devices += \$(\"[name=exit2\"+akd+\"]\").prop(\"checked\") ? \"1\":\"0\";
			devices += '#[NF]';
			devices += \$(\"[name=showreihe\"+akd+\"]\").val();
			devices += '#[NF]';
			devices += \$(\"[name=hidecmd\"+akd+\"]\").val();
			devices += '#[NF]';
			testfeld = \$(\"[name=repeatcond\"+akd+\"]\").prop(\"checked\") ? \"1\":\"0\";
			devices += testfeld;
			testfeld1=\$(\"[name=countdownon\"+akd+\"]\").val();
			devices += '#[NF]';
			devices += testfeld1;
			testfeld2=\$(\"[name=countdownoff\"+akd+\"]\").val();
			devices += '#[NF]';
			devices += testfeld2;
			devices += '#[DN]';
	
			";
        }

        $modify =
"<table width = '100%' border='0' class='block wide' name ='noshowtask' id='MSwitchDetails' cellpadding='4' style='border-spacing:0px;' nm='MSwitch'>
			<tr class='even' ><td><br>
			<input type='button' value='edit all' onclick='javascript: editall() '>
			&nbsp;
			<input type='button' value='close all' onclick='javascript: closeall() '>
			&nbsp;
		
			<input type='button' id='aw_show' value='show hidden cmds ($noshow)' >
			&nbsp;
			<input type='button' id='aw_showid' value='show IDs' >
			&nbsp;
			<input type='text' id='aw_showid1' size=\"8\" value='' >
			
			<br>&nbsp;
			</td></tr>
			</table><br>
			";

        $detailhtml = $modify . $detailhtml . $saveline;
    }

    #textersetzung
    foreach (@translate) {
        my ( $wert1, $wert2 ) = split( /->/, $_ );
        $detailhtml =~ s/$wert1/$wert2/g;
    }

    # ende kommandofelder
	
####################

	my $triggercondition = MSwitch_Load_Tcond($hash);
	
	# optimieren für html darstellung
	
	$triggercondition =~ s/#\[sp\]/ /g;
	$triggercondition =~ s/\(DAYS\)/|/g;
    $triggercondition =~ s/~/&#126/g;
	$triggercondition =~ s/\\/&#92;/g;
	$triggercondition =~ s/'/&#39;/g;
	$triggercondition =~ s/"/&#34;/g;
	$triggercondition =~ s/\//&#47/g;
    $triggercondition =~ s/&#160/&#38;nbsp;/g;
	
    my $timeon = ReadingsVal( $Name, '.Trigger_time_1', '' );
    $timeon =~ s/#\[dp\]/:/g;
    $timeon =~ s/\[NEXTTIMER\]/&\#9252;/g;

    my $timeoff = ReadingsVal( $Name, '.Trigger_time_2', '' );
    $timeoff =~ s/#\[dp\]/:/g;
    $timeoff =~ s/\[NEXTTIMER\]/&\#9252;/g;

    my $timeononly = ReadingsVal( $Name, '.Trigger_time_3', '' );
    $timeononly =~ s/#\[dp\]/:/g;
    $timeononly =~ s/\[NEXTTIMER\]/&\#9252;/g;
    my $timeoffonly = ReadingsVal( $Name, '.Trigger_time_4', '' );
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
    if ( $debugmode eq '2' || $debugmode eq '3' ) {
        my $Zeilen = ("");
		my $pfad =  AttrVal( 'global', 'logdir', './log/' ) ;

		
		open( BACKUPDATEI,  $pfad."/MSwitch_debug_$Name.log" );
        while (<BACKUPDATEI>) {
            $Zeilen = $Zeilen . $_;
        }
        close(BACKUPDATEI);
        my $text = "";
        $text = $PROTOKOLL2 if AttrVal( $Name, 'MSwitch_Debug', "0" ) eq '2';
        $text = $PROTOKOLL3 if AttrVal( $Name, 'MSwitch_Debug', "0" ) eq '3';

        my $activelog = '';
        if ( defined $hash->{helper}{aktivelog}
            && $hash->{helper}{aktivelog} eq 'on' )
        {
            $activelog = 'checked';
        }

        $ret .= "<table border='$border' class='block wide' id=''>
			 <tr class='even'>
			 <td><center>&nbsp;<br>
			 $text<br>&nbsp;<br>";

        $ret .=
" <textarea name=\"log\" id=\"log\" rows=\"5\" cols=\"160\" STYLE=\"font-family:Arial;font-size:9pt;\">"
          . "$Zeilen"
          . "</textarea>";
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

        # geraeteliste
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

        my $sel = "<select  id = \"CID\" name=\"trigon\">" . $dev . "</select>";

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
<!--start Ausloesendes Geraet -->
<!-- folgende HTML-Kommentare duerfen nicht geloescht werden -->
<!-- 
info: festlegung einer zelleknoehe
MS-cellhigh=30;
-->
<!--
start:textersetzung:ger
search devices->Geraet suchen
trigger device/time->Ausloesendes Geraet und/oder Zeit
trigger device->Ausloesendes Geraet
trigger time->Ausloesezeit
modify Trigger Device->Trigger speichern
switch MSwitch on and execute CMD1 at->MSwitch an und CMD1 ausfuehren
switch MSwitch off and execute CMD2 at->MSwitch aus und CMD2 ausfuehren
execute CMD1 only->Schaltkanal 1 ausfuehren
execute CMD2 only->Schaltkanal 2 ausfuehren
execute CMD1 and CMD2 only->Schaltkanal 1 und 2 ausfuehren
Trigger Device Global Whitelist->Beschraenkung GLOBAL Ausloeser
Trigger condition->Ausloesebedingung
time&events->fuer Events und Zeit
events only->nur fuer Events
check condition->pruefe Bedingung
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
MS-Alert
--> 
<table MS-HIDEDUMMY border='0' cellpadding='4' informid='hidedummy' class='block wide' style='border-spacing:0px;'>
	<tr class='even'>
		<td colspan='4'>trigger device/time</td>
	</tr>
	<tr class='even'>
		<td>MS-HELPdevice</td>
		<td>trigger device </td>
		<td colspan='2' >MS-TRIGGER</td>
	</tr>
	<tr class='even'>
		<td></td>
		<td></td>
		<td colspan = '2'>MS-Alert</td>
	</tr>
		<tr class='even'>
		<td></td>
		<td></td>
		
		<td colspan='2'>
		&nbsp;<br>search devices: <input id='searchstringtrigger' name='info' type='text' value='' onkeyup=\"searchtriggerdevice()\">&nbsp;
		&nbsp;
		</td>
	</tr>
	<tr class='even'>
		<td colspan='4'>&nbsp;</td>
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
<!--end Ausloesendes Geraet -->
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

    if ( $devicemode eq "Notify" ) {
        $MShidefull = "style='display:none;'";
        $displaynot = "style='display:none;'";

    }

    if ( $devicemode eq "Toggle" ) {
        $displayntog = "style='display:none;'";
        $inhalt5     = "toggle $Name and execute cmd1/cmd2";
    }

    if ( $devicemode ne "Dummy" ) {
        $MSHidedummy = "";
    }
    else {
        $MSHidedummy = "style ='visibility: collapse'";
        $MShidefull  = "style='display:none;'";
        $displaynot  = "style='display:none;'";
    }

    $MStrigger =
"<br><select style=\"width:700px;\" size='1' id =\"trigdevnew\" name=\"trigdevnew\">"
      . "</select>";

    if ( $globalon ne 'on' ) {
        $MSHidewhitelist =
          "id='triggerwhitelist' style ='visibility: collapse'";
    }

    $MSwhitelist =
"<input type='text' id ='triggerwhite' name='triggerwhitelist' size='35' value ='"
      . ReadingsVal( $Name, '.Trigger_Whitelist', '' )
      . "' onClick=\"javascript:bigwindow(this.id,'',2);\" >";

    $MSonand1 =
        "<input type='text' id='timeon' name='timeon' size='35'  value ='"
      . $timeon
      . "' onClick=\"javascript:bigwindow(this.id,'web',3);\">";
    $MSonand2 =
        "<input type='text' id='timeoff' name='timeoff' size='35'  value ='"
      . $timeoff
      . "' onClick=\"javascript:bigwindow(this.id,'web',3);\">";
    $MSexec1 =
      "<input type='text' id='timeononly' name='timeononly' size='35'  value ='"
      . $timeononly
      . "' onClick=\"javascript:bigwindow(this.id,'web',3);\">";

    if ( $hash->{MSwitch_Init} ne 'define' ) {
        $MSexec2 =
"<input type='text' id='timeoffonly' name='timeoffonly' size='35'  value ='"
          . $timeoffonly
          . "'onClick=\"javascript:bigwindow(this.id,'web',3);\">";

        $MSexec12 =
"<input type='text' id='timeonoffonly' name='timeonoffonly' size='35'  value ='"
          . $timeonoffonly
          . "' onClick=\"javascript:bigwindow(this.id,'web',3);\">";
    }

    $MSconditiontext = "Trigger condition (events only)";

    if ( AttrVal( $Name, 'MSwitch_Condition_Time', "0" ) eq '1' ) {
        $MSconditiontext = "Trigger condition (time&events)";
    }

    if ( $debugmode eq '1' || $debugmode eq '3' ) {
        $MScheckcondition =
" <input name='info' type='button' value='check condition' onclick=\"javascript: checkcondition('triggercondition','$Name:trigger:conditiontest')\">";
    }

    $MScondition =
"<input type='text' id='triggercondition' name='triggercondition' size='35' value ='"
      . $triggercondition
      . "' onClick=\"javascript:bigwindow(this.id,'',1);\" >";

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
    $triggerhtml =~ s/MS-Alert/$alert1/g;

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
    my $MSHELP8         = "";
    my $MSHELP9         = "";
    my $MSHELP10        = "";
    my $MSHELP11        = "";
    my $eventhtml       = "
<!-- folgende HTML-Kommentare duerfen nicht geloescht werden -->
<!-- 
info: festlegung einer zellenhoehe
MS-cellhigh=30;
-->
<!-- 
start:textersetzung:ger
Save incomming events permanently->eingehende Events permanent speichern
Add event manually->Event manuell eintragen
event details:->Eventdetails
test event->Event testen
add event->Event einfuegen
clear saved events->Eventliste loeschen
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
		<td colspan='4'>&nbsp;</td>
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
		<td colspan='4'>MS-TESTEVENT MS-MODLINE</td>	
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

    $MSSAVEEVENT ="<input id ='eventsave'  $selectedcheck3 name=\"aw_save\" type=\"checkbox\" $disable>";
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

    $MSMODLINE =
"<input type=\"button\" id=\"aw_md20\" value=\"clear saved events\" $disable>";

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

    if (   $triggerdevice ne 'no_trigger'
        || $selftrigger > 0
        || ( $selftrigger > 0 && $devicemode eq "Dummy" ) )
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
        && (   $triggerdevice ne 'no_trigger'
            || $selftrigger > 0
            || ( $selftrigger > 0 && $devicemode eq "Dummy" ) )
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
            $MSDELETE     = 'loeschen';
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
<!-- folgende HTML-Kommentare duerfen nicht geloescht werden -->
<!-- 
info: festlegung einer zelleknoehe
MS-cellhigh=30;
-->
<!-- 
start:textersetzung:ger
execute only cmd1->nur CMD1 ausfuehren
execute only cmd2->nur CMD2 ausfuehren
switch $Name on and execute cmd1->$Name anschalten und CMD1 ausfuehren
switch $Name off and execute cmd2->$Name ausschalten und CMD2 ausfuehren
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

#####################

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

    #my $selftrigger       = "";
    my $showtriggerdevice = $Triggerdevice;
    if (   AttrVal( $Name, "MSwitch_Selftrigger_always", 0 ) > 0
        && ReadingsVal( $Name, '.Trigger_device', 'no_trigger' ) ne
        'no_trigger' )
    {
        $selftrigger       = 1;
        $showtriggerdevice = $showtriggerdevice . " (or MSwitch_Self)";
    }
    elsif (AttrVal( $Name, "MSwitch_Selftrigger_always", 0 ) > 0
        && ReadingsVal( $Name, '.Trigger_device', 'no_trigger' ) eq
        'no_trigger' )
    {
        $selftrigger       = 1;
        $showtriggerdevice = "MSwitch_Self:";
    }

    if (   ( $triggerdevice ne 'no_trigger' )
        || ( $devicemode eq 'Dummy' && $selftrigger > 0 ) )
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

        if ( $hash->{MSwitch_Init} ne 'define' ) {
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
        && AttrVal( $Name, 'MSwitch_Selftrigger_always', 0 ) == 0 )
    {
        $style = " style ='visibility: collapse' ";
    }

    my $MSSAVED        = "";
    my $MSSELECT       = "";
    my $MSSECONDSELECT = "";
    my $MSTHIRDSELECT  = "";
    my $MSHELP         = "";
    my $MSEDIT         = "";
    my $MSLOCK         = "";
    my $MSMOD          = "";
    my $MSMODNEW       = "";

    # <td>MS-SECONDSELECT</td>
    my $selectaffectedhtml = "
<!--start zu schaltende Geraete -->
<!-- folgende HTML-Kommentare duerfen nicht geloescht werden -->
<!-- 
start:textersetzung:ger
selected devices->gewaehlte Geraete
available devices->verfuegbare Geraete
search devices->Geraet suchen
edit list->Liste editieren
filter->Filter
all devicecomands saved->alle Devicekommandos gespeichert
modify Devices->Devices speichern
reload->neu laden
affected devices->zu schaltende Geraete
end:textersetzung:ger
-->
<!-- 
start:textersetzung:eng
end:textersetzung:eng
-->
";

    $selectaffectedhtml .= "
<table width='100%' border='$border' class='block wide' $style >
	<tr>
		<td nowrap colspan='5'>affected devices<br>MS-SAVED</td>
	</tr>
	<tr>
		<td>&nbsp;</td>
		<td nowrap><center>available devices</td>
		<td>&nbsp;</td>
		<td nowrap><center>selected devices</td>
		<td width='100%'>&nbsp;</td>
	</tr>
	<tr>
		<td nowrap>MS-HELP</td>
		<td>MS-SECONDSELECT</td>
		<td nowrap>
		&nbsp;&nbsp;&nbsp;
		<input name='info' type='button' value='>>' onclick=\"selectdevices('') \">
		<input name='info' type='button' value='<<' onclick=\"deletedevices('') \">
		&nbsp;&nbsp;&nbsp;</td>
		<td>MS-THIRDSELECT</td>
		<td>&nbsp;</td>
	</tr>
	<tr>
		<td>&nbsp;</td>
		<td>&nbsp;</td>
		<td>&nbsp;</td>
		<td>&nbsp;</td>
		<td width='100%'>&nbsp;</td>
	</tr>
	<tr>
		<td>&nbsp;</td>
		<td nowrap colspan='4'>
		&nbsp;search devices: <input id='searchstring' name='info' type='text' value='' onkeyup=\"searchdevice()\">&nbsp;
		&nbsp;filter (TYPE):
		<select name='' id='modtype' size='1' onchange=\"searchdevice()\">
		<option selected>.*</option>
		</select></td>
	</tr>

	<tr>
		<td nowrap colspan='5'>&nbsp;</td>
	</tr>
	
	<tr>
		<td nowrap colspan='5'>MS-MOD-NEW</td>
	</tr>
</table>
<!--end zu schaltende Geraete -->";

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

    if ( $hash->{MSwitch_Init} ne 'define' ) {

        # affected devices   class='block wide' style ='visibility: collapse'
        if ( $savecmds ne "nosave" && $cmdfrombase eq "1" ) {
            $MSSAVED =
"all devicecomands saved <input type=\"button\" id=\"del_savecmd\" value=\"reload\">";
        }
        if ( AttrVal( $Name, 'MSwitch_Help', "0" ) eq '1' ) {
            $MSHELP =
"<input name='info' type='button' value='?' onclick=\"hilfe('affected')\">";
        }

        $MSSECONDSELECT =
"<select style=\"width:700px;\" ondblclick=\"selectdevices('')\" id =\"affected_second_devices\" multiple=\"multiple\" name=\"affected_second_devices\" size=\"6\" >"
          . ""
          . "</select>";

        $MSTHIRDSELECT =
"<select ondblclick=\"deletedevices('')\" id =\"affected_third_devices\" multiple=\"multiple\" name=\"affected_third_devices\" size=\"6\" >"
          . ""
          . "</select>";

        $MSEDIT =
"<input type=\"button\" id=\"aw_great\" value=\"edit list\" onClick=\"javascript:deviceselect();\">";
        $MSLOCK =
"<input onChange=\"javascript:switchlock();\" checked=\"checked\" id=\"lockedit\" name=\"lockedit\" type=\"checkbox\" value=\"lockedit\" /> quickedit locked";

        $MSMOD =
"<input type=\"button\" id=\"aw_dev\" value=\"modify Devices\" $disable>";

        $MSMODNEW =
"<input type=\"button\" id=\"aw_new_dev\" value=\"modify Devices\" $disable>";

    }

    $selectaffectedhtml =~ s/MS-SAVED/$MSSAVED/g;
    $selectaffectedhtml =~ s/MS-SECONDSELECT/$MSSECONDSELECT/g;
    $selectaffectedhtml =~ s/MS-THIRDSELECT/$MSTHIRDSELECT/g;
    $selectaffectedhtml =~ s/MS-HELP/$MSHELP/g;
    $selectaffectedhtml =~ s/MS-EDIT/$MSEDIT/g;
    $selectaffectedhtml =~ s/MS-LOCK/$MSLOCK/g;

    $selectaffectedhtml =~ s/MS-MOD-NEW/$MSMODNEW/g;
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
    my $language =
      AttrVal( $Name, 'MSwitch_Language',
        AttrVal( 'global', 'language', 'EN' ) );
    my $quickedit = AttrVal( $Name, 'MSwitch_Lock_Quickedit', "1" );
    my $exec1     = 0;
    my $devicetyp = AttrVal( $Name, 'MSwitch_Mode', 'Notify' );

    my $Helpmode = AttrVal( $Name, 'MSwitch_Help', '0' );
    my $Help = '';

    if ( $Helpmode eq '1' || $confdevice eq $Name ) {
        if   ( $language eq "EN" ) { $Help = $englischhelp; }
        else                       { $Help = $germanhelp; }
    }

    if ( $affecteddevices[0] ne 'no_device' and $hash->{MSwitch_Init} ne 'define' ) {
        $exec1 = "1";
    }

    my $javachange = $javaform;
	
	
#	Log3( $Name, 0,  $javachange );
    $javachange =~ s/\n//g;
    $javachange =~ s/\t//g;
    $javachange =~ s/'/\\'/g;



# Log3( $Name, 0,  $javachange );


    my $alldevices                = join( '\',\'', @alldevices );
    my $alldevicesalias           = join( '\',\'', @alldevicesalias );
    my $alldevicestype            = join( '\',\'', @alldevicestype );
    my $alldevicesselected        = join( '\',\'', @alldevicesselected );
    my $alldevicestotrigger       = join( '\',\'', @devicestotrigger );
    my $alldevicestotriggerzusatz = join( '\',\'', @devicestotriggerzusatz );

    $j1 = "<script type=\"text/javascript\">{";
    $j1 .= "
	var ALLDEVICESTOTRIGGER=['" . "$alldevicestotrigger" . "'];
	var ALLDEVICESTOTRIGGERZUSATZ=['" . "$alldevicestotriggerzusatz" . "'];
	var DEVICETOTRIGGERSELECT='$devicetotriggerselect';
	var ALLDEVICES=['" . "$alldevices" . "'];
	var ALLDEVICESALIAS=['" . "$alldevicesalias" . "'];
	var ALLDEVICESTYPE=['" . "$alldevicestype" . "'];
	var ALLDEVICESSELECTED=['" . "$alldevicesselected" . "'];
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
	var HASHINIT = '" . $hash->{MSwitch_Init} . "';
	var UNLOCK ='" . ReadingsVal( $Name, '.lock', 'undef' ) . "';
	var RENAME = '" . $rename . "';
	var DEBUGMODE = '" . $debugmode . "';
	var DISTRIBUTLINES = " . $distributline . ";
	var FUTURELEVEL = " . $futurelevel . ";
	var CONFIGD = '" . $confdevice . "';

	var webwidget= '"
      . AttrVal( $Name, 'MSwitch_use_WebWidgets', $webwidget ) . "';
	
	\$(document).ready(function() {
    \$(window).load(function() {
    loadScript(\"pgm2/MSwitch_Web.js?v=" . $fileend
      . "\", function(){teststart()});
	return;
	}); 
	});
	";

## reset und timeline muss noch in javaweb uebernommen werden aber nicht wichtig !!
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
"Durch Bestaetigung mit \"Reset\" wird das Device komplett zurueckgesetzt (incl. Readings und Attributen) und alle Daten werden geloescht !";
        $txt .=
"<br>&nbsp;<br><center><input type=\"button\" style=\"BACKGROUND-COLOR: red;\" value=\" Reset \" onclick=\" javascript: reset() \">";
        $j1 .= "FW_okDialog('$txt');";
    }

    $j1 .= "
	function formsubmit(){	
	var nm = \$(t).attr(\"nm\");
	devices = '';
	$javaform
	devices = devices.replace(/\\(/g,'#[EK1]');
	devices = devices.replace(/\\)/g,'#[EK2]');
	devices = devices.replace(/ /g,'#[sp]');
	devices = devices.replace(/;/g,'#[se]');
	devices = devices.replace(/:/g,'#[dp]');
	devices = devices.replace(/%/g,'#[pr]');
	
	devices = devices.replace(/\t/g,'#[sp]#[sp]#[sp]#[sp]');
	
	devices =  encodeURIComponent(devices);
	var  def = nm+\" detailsraw \"+devices+\" \";
	location = location.pathname+\"?detail=" . $Name . "&cmd=set \"+addcsrf(def);
	}
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

        my $mswitchsetlist = AttrVal( $Name, 'MSwitch_setList', "undef" );
        if ( $mswitchsetlist ne "undef" ) {
            my @dynsetlist = split( / /, $mswitchsetlist );
            foreach my $test (@dynsetlist) {
                if ( $test =~ m/(.*)\[(.*)\]:?(.*)/ ) {

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

        my $oddeven    = "odd";
        my @readlist   = split( / /, AttrVal( $Name, 'readingList', "" ) );
        my @dynsetlist = split( / /, ReadingsVal( $Name, "Dynsetlist", '' ) );
        @readlist = ( @readlist, @arraydynreadinglist, @dynsetlist );
        for (@readlist) {
            my $setinhalt = ReadingsVal( $Name, $_, '' );

            next if $setinhalt eq "";

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

        #display:none
        $hidecode =
          "<div class='makeTable Radingcontainer' style='display:none'></div>";
        $hidecode .= "<script type=\"text/javascript\">{";
        $hidecode .= "
	\$( document ).ready(function() {
    hideall();
	});
	
	function hideall(){
	//	return;
//            \$( \"div:contains(\'"
          . $testname
          . "\')\" ).css('display','none');
//            \$( \"table[data-name|=\'"
          . $testname
          . "\']\" ).css('display','none');
//            \$(\".makeTable.wide.readings\").css('display','none');

var readings  = \$(\".makeTable.wide.readings\").html();
var newreadings = readings.replace(\/[\\r\\n]+\/g, 'TEST');
var myRegEx = new RegExp('<tbody>.*');  
treffer = newreadings.match(myRegEx);
treffer='<table>'+treffer+'</table>';

\$(\".makeTable.Radingcontainer\").html(treffer);
\$(\".block.wide.readings\").html('" . $inhalt . "');

//dreht readings und internals 
//	 var internals = \$(\".makeTable.wide.internals\").html();
//	 var readings  = \$(\".makeTable.wide.readings\").html();
//	 \$(\".makeTable.wide.readings\").html(internals);
//	 \$(\".makeTable.wide.internals\").html(readings);
// -----
	return;
 }
	";
        $hidecode .= "}</script>";
    }

    my @tareadings = ( keys %{ $data{MSwitch}{$Name}{groups} } );
    if ( AttrVal( $Name, 'MSwitch_SysExtension', "0" ) =~ m/(2)/s
        && $data{MSwitch}{$Name}{Ansicht} eq "room" )
    {
        # readingtabelle erstellen
        my $testreading = $hash->{READINGS};
        my $oddeven     = "even";
        my $inhalt      = "";
        my @readlist    = ( keys %{$testreading} );

        for (@readlist) {
            my $setinhalt = ReadingsVal( $Name, $_, '' );
            my $settimstamp = ReadingsTimestamp( $Name, $_, '' );
            if ( $_ =~ m/^\..*/s ) { next; }
            $inhalt .=
                "<tr class=\""
              . $oddeven
              . "\"><td><div class=\"dname\" data-name=\""
              . $Name . "\">"
              . $_
              . "</div></td><td><div class=\"dval\" informid=\""
              . $Name . "-"
              . $_ . "\">"
              . $setinhalt
              . "</div></td>"
              . "</tr>";
            if ( $oddeven eq "odd" ) {
                $oddeven = "even";
                next;
            }
            else {
                $oddeven = "odd";
                next;

            }
        }
        my $table = "";
        if ( $system ne "" ) {
            $table =
"<br><div class='makeTable Radingcontainer' style='display:none'><table>$inhalt</table></div>";
        }
        return "$info$comsystem$offlinemsg$system$table";
    }
















   # my $undo = "";

    if ( exists $data{MSwitch}{$hash}{undo} ) {
        if ( $data{MSwitch}{$hash}{undotime} > ( time - $undotime ) ) {
			
			
			
			$hash->{MSwitch_Undo_mode} = 'on backup exists';
			
			
            # if ( $language eq "EN" ) {
                # $undo =
# "<table border='0' class='block wide' id='MSwitchWebTR' nm='$hash->{NAME}' cellpadding='4' style='border-spacing:0px;'>
					# <tr>
					# <td style='height: MS-cellhighstandart;width: 100%;' colspan='3'>
					# <center><input id=\"undo\" style='BACKGROUND-COLOR: red;' name='undo last change' type='button' value='undo last change'>
					# </td>
					# </tr>
				# </table><br>";
            # }
            # else {
                # $undo =
# "<table border='0' class='block wide' id='MSwitchWebTR' nm='$hash->{NAME}' cellpadding='4' style='border-spacing:0px;'>
					# <tr>
					# <td style='height: MS-cellhighstandart;width: 100%;' colspan='3'>
					# <center><input id=\"undo\" style='BACKGROUND-COLOR: red;' name='undo last change' type='button' value='letzte Aenderung rueckgaengig machen'>
					# </td>
					# </tr>
				# </table><br>";

            # }
        }
    }
	
	#$undo = "";
	

    # aktualisiere statecounter
    if ( $devicemode ne "Notify" ) {
        my $oldstate = ReadingsVal( $Name, "state", 'undef' );
        my $virtcmd = $oldstate;
        MSwitch_Set_Statecounter( $Name, $oldstate, $virtcmd );
    }

    my $modmode = "";
    if ( AttrVal( $Name, 'MSwitch_Modul_Mode', "0" ) eq '1' ) {

        $modmode = "<table style='display:none'><tr><td>";

        $modmode .= "$ret<br>$detailhtml";
        $modmode .= "</td></tr></table>";
    }
    else {
        $modmode .= "$ret<br>$detailhtml";
    }
    return "$debughtml$offlinemsg$system$modmode$helpfile<br>$j1$hidecode";
}

####################

sub MSwitch_makeCmdHash($) {
    my $loglevel = 5;
    my ($Name) = @_;
my $hash         = $modules{MSwitch}{defptr}{$Name};
    # detailsatz in scalar laden
    my @devicedatails;   
	@devicedatails = MSwitch_Load_Details($hash);
	my %savedetails;
    foreach (@devicedatails) {

        #	ersetzung
		$_ =~ s/#\[sp\]/ /g;
		$_ =~ s/#\[nl\]/\n/g;
        $_ =~ s/\(DAYS\)/|/g;

        ### achtung on/off vertauscht
        ############### off

        my @detailarray = split( /#\[NF\]/, $_ );    #enthält daten 0-5 0 - name 1-5 daten 7 und9 sind zeitangaben

        my $key = '';
        $key = $detailarray[0] . "_delayatonorg";
        $savedetails{$key} = $detailarray[7];
        my $testtimestron = $detailarray[8];
        $savedetails{$key} = $detailarray[8];
        $detailarray[8]    = $testtimestron;
        $key               = $detailarray[0] . "_on";
        $savedetails{$key} = $detailarray[1];
        $key               = $detailarray[0] . "_off";
        $savedetails{$key} = $detailarray[2];
        $key               = $detailarray[0] . "_onarg";
		
		

		
		
		
		#FreeCmd-AbsCmd1_delayatonarg
		
        if ( defined $detailarray[3] && $detailarray[3] ne "" ) {
            $savedetails{$key} = $detailarray[3];
        }
        else {
            $savedetails{$key} = "";
        }
		
        $key               = $detailarray[0] . "_offarg";
        $savedetails{$key} = $detailarray[4];
        $key               = $detailarray[0] . "_delayaton";
        $savedetails{$key} = $detailarray[5];
        $key               = $detailarray[0] . "_delayatoff";
        $savedetails{$key} = $detailarray[6];
		
		
		$key               = $detailarray[0] . "_delayatonarg";
		$savedetails{$key} = $detailarray[7];
		
		#MSwitch_LOG( $Name,6,"abgelgter key > ".$key." ".__LINE__);
		#MSwitch_LOG( $Name,6,"abgelgter key inhalt> ".$detailarray[7]." ".__LINE__);
		
        $key               = $detailarray[0] . "_delayatoffarg";
        $savedetails{$key} = $detailarray[8];
		
		
		
		
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

        $key = $detailarray[0] . "_countdownon";
        if ( defined $detailarray[21] ) {

            $savedetails{$key} = $detailarray[21];
        }
        else {
            $savedetails{$key} = '';
        }

        $key = $detailarray[0] . "_countdownoff";
        if ( defined $detailarray[22] ) {

            $savedetails{$key} = $detailarray[22];
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
    if ( AttrVal( $Name, 'MSwitch_Debug', '0' ) ne "0" ) { $showevents = 1 }
    my $events    = ReadingsVal( $Name, '.Device_Events', '' );
    my $triggeron = ReadingsVal( $Name, '.Trigger_on',    'no_trigger' );
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

    foreach my $name ( keys %{$eventhash} ) {
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

sub MSwitch_change_snippet($$) {
    my ( $hash, $cs ) = @_;
    my $name             = $hash->{NAME};
    my $aktsnippet       = "";
    my $aktsnippetnumber = "";

	my $stop =0;
	while  ( $cs =~ m/(.*)\[Snippet:(.*?)\](.*)/s ) 
	 
	{
        my $firstpart      = $1;
        my $snipppetnumber = $2;
        my $lastpart       = $3;
		$stop++;
		last if $stop > 20;

		if (exists $data{MSwitch}{$name}{snippet}{$snipppetnumber})
			{

				my $snippet = $data{MSwitch}{$name}{snippet}{$snipppetnumber};
				$snippet =~ s/\n//g;
				$cs = $firstpart . $snippet . $lastpart;
			}
	
		else 
		{
		my $snippet="[undefSnippet:$snipppetnumber]";
		$cs = $firstpart . $snippet . $lastpart;
		}
    }
	
	$cs =~ s/undefSnippet/Snippet/g;
    return $cs;
}

###########################################################################
sub MSwitch_Exec_Notif($$$$$) {

    #Inhalt Übergabe ->  push @cmdarray, $own_hash . ',on,check,' . $eventcopy1
    my ( $hash, $comand, $check, $event, $execids ) = @_;
    my $name = $hash->{NAME};
    my $field = "";
    return "" if ( IsDisabled($name) );
	
	#ACHTUNG
	if (!defined $event ) { $event = "";}
	MSwitch_LOG( $name, 6,"\n----------  SUB Exec_Notif ----------\n->  event: $event\n-> comand: $comand");

    my $protokoll = '';
    my $satz;

    if ( !$execids ) { $execids = "0" }
    my $showevents = AttrVal( $name, "MSwitch_generate_Events", 0 );
    if ( AttrVal( $name, 'MSwitch_Debug', '0' ) ne "0" ) { $showevents = 1 }

    my $debugmode      = AttrVal( $name, 'MSwitch_Debug',         "0" );
    my $expertmode     = AttrVal( $name, 'MSwitch_Expert',        "0" );
    my $delaymode      = AttrVal( $name, 'MSwitch_Delete_Delays', '0' );
    my $attrrandomtime = AttrVal( $name, 'MSwitch_RandomTime',    '' );
    my $exittest       = '';
	
	my $errors ="";
	
	if ($comand eq "on")
	{
		$exittest = "1";
	}
	
	if ($comand eq "off")
	{
		$exittest = "2";
	}

###########

	if ( AttrVal( $name, 'MSwitch_lastState', 'undef' ) ne "undef" ) { 
	my $statearg = "deviceslaststate".$comand;
	
	#### check laststate 
		my @laststates = split (" ",$data{MSwitch}{$name}{lastStates}{$statearg});
		foreach (@laststates) {
		my @devargs = split ("\:",$_);
		my $val =ReadingsVal( $devargs[0], $devargs[1], 'undef' );
		readingsSingleUpdate( $hash, "lastState_".$devargs[0]."_".$devargs[1], $val, $showevents );
		readingsSingleUpdate( $hash, "lastState_cmd".$exittest."_time", int(time), $showevents );
		}
	}
	
#########################	
	
    my $ekey = '';
    my $out  = '0';
	
    my $format = AttrVal( $name, 'MSwitch_Format_Lastdelay', "HH:MM:SS" );
    my $jump   = AttrVal( $name, "MSwitch_Delay_Count",      10 );

    if ( $delaymode eq '2' ) {
        MSwitch_Delete_specific_Delay( $hash, $name, $event );
    }

    if ( $delaymode eq '3' ) {
        MSwitch_Delete_Delay( $hash, $name );
    }

    my %devicedetails = MSwitch_makeCmdHash($name);
    return if ReadingsVal( $name, '.Device_Affected', 'no_device' ) eq 'no_device';

    # betroffene geräte suchen
    my @devices =
      split( /,/, ReadingsVal( $name, '.Device_Affected', 'no_device' ) );

    my $update     = '';
    my $testtoggle = '';

    # liste nach priorität ändern , falls expert

    @devices = MSwitch_priority( $hash, $execids, @devices );

    my $lastdevice;
    my @execute;
    my @timers;
    my $timercounter = 0;
    my $eventcount   = 0;

  LOOP45: foreach my $device (@devices) {
        $out = '0';
        if ( $expertmode eq '1' ) {
            $ekey = $device . "_exit" . $exittest;
            $out  = $devicedetails{$ekey};
        }

        if ( $delaymode eq '1' ) {
            MSwitch_Delete_Delay( $hash, $device );
        }

        my @devicesplit = split( /-AbsCmd/, $device );
        my $devicenamet = $devicesplit[0];

        # teste auf on kommando
        my $key      = $device . "_" . $comand;
        my $timerkey = $device . "_time" . $comand;

        my ( $evtparts1, $evtparts2, $evtparts3 ) = split( /:/, $event, 3 );
        my $evtfull = $event;

        if ( !defined $devicedetails{$timerkey} ) {
            $devicedetails{$timerkey} = 0;
        }

        $devicedetails{$timerkey} =~ s/\$SELF/$name/ig;
        $devicedetails{$timerkey} =~ s/\$EVENT/$event/ig;
        $devicedetails{$timerkey} =~ s/\$EVTFULL/$evtfull/ig;
        $devicedetails{$timerkey} =~ s/\$EVTPART1/$evtparts1/ig;
        $devicedetails{$timerkey} =~ s/\$EVTPART2/$evtparts2/ig;
        $devicedetails{$timerkey} =~ s/\$EVTPART3/$evtparts3/ig;

        # setmagic ersetzung

        my $x = 0;
        while ( $devicedetails{$timerkey} =~
            m/(.*)\[([a-zA-Z0-9._\$]{1,50})\:([a-zA-Z0-9._\$]{1,50})\](.*)/ )
        {
            $x++;    # notausstieg notausstieg
            last if $x > 20;    # notausstieg notausstieg
            my $firstpart   = $1;
            my $lastpart    = $4;
            my $readingname = $3;
            my $devname     = $2;
            my $setmagic    = ReadingsVal( $devname, $readingname, 0 );
            $devicedetails{$timerkey} = $firstpart . $setmagic . $lastpart;
        }

MSwitch_LOG( $name,6,"firsttimerkeyorg > ".$devicedetails{$timerkey}.__LINE__);

#my $orgtimer =$devicedetails{$timerkey};


        $devicedetails{$timerkey} =
          timetoseconds( $name, $devicedetails{$timerkey} );
		  
		
		  
		  
		  
		  
		  
		  
		  
		  
		  
        if ( !defined $devicedetails{$timerkey} ) {
            $devicedetails{$timerkey} = 0;
        }
        if ( $devicedetails{$timerkey} =~ m/{.*}/ ) {
            {
                no warnings;
                $devicedetails{$timerkey} = eval $devicedetails{$timerkey};
            }
            $devicedetails{$timerkey} =
              timetoseconds( $name, $devicedetails{$timerkey} );
        }

        elsif ( $devicedetails{$timerkey} =~ /^-?\d+(?!\.\d+)?$/ ) {

        }
        else {
            $devicedetails{$timerkey} = 0;
        }

        # teste auf condition
        # antwort $execute 1 oder 0 ;

        my $conditionkey = $device . "_condition" . $comand;
		
		
		if ( $devicedetails{$key} eq "no_action" )
			{
				$conditionkey = $device . "_condition" . $comand;
                my $execute =MSwitch_checkcondition( $devicedetails{$conditionkey},$name, $event );
                if ( $execute eq 'true' ){
				if ( $out eq '1' ) {
                        #abbruchbefehl erhalten von $device
                        MSwitch_LOG( $name, 6, "-> Abbruchbefehl erhalten von ". $device . " ");
                        $lastdevice = $device;
                        last LOOP45;
                    }
				}
			}
		
		
        if ( $devicedetails{$key} ne "" && $devicedetails{$key} ne "no_action" )
        {
            my $cs = '';
            if ( $devicenamet eq 'FreeCmd' ) {
                $cs = "$devicedetails{$device.'_'.$comand.'arg'}";
                $cs = MSwitch_change_snippet( $hash, $cs );
                $hash->{helper}{aktevent} = $event;
				
				
	##### ACHTUNG ######			
				#MSwitch_LOG( $name,6,"aufruf freecmd: > ".__LINE__);
                $cs = MSwitch_makefreecmd( $hash, $cs );
                delete( $hash->{helper}{aktevent} );
                #variableersetzung erfolgt in freecmd
            }
            else {
                $cs =
"$devicedetails{$device.'_'.$comand} $devicedetails{$device.'_'.$comand.'arg'}";

                $cs = MSwitch_change_snippet( $hash, $cs );
                my $pos = index( $cs, "[FREECMD]" );
                if ( $pos >= 0 ) {
                    $hash->{helper}{aktevent} = $event;
				MSwitch_LOG( $name, 6,"aufruf freecmdonly: > ".__LINE__);

                    $cs = MSwitch_makefreecmdonly( $hash, $cs );
                    delete( $hash->{helper}{aktevent} );
                }
                else {
                    $cs = "set $devicenamet " . $cs;
                }
            }


            #Variabelersetzung
            if (   $devicedetails{$timerkey} eq "0" || $devicedetails{$timerkey} eq "" )
            {
				
				
				
				
				
                # teste auf condition
                # antwort $execute 1 oder 0 ;
                $conditionkey = $device . "_condition" . $comand;
                my $execute =
                  MSwitch_checkcondition( $devicedetails{$conditionkey},
                    $name, $event );
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
                    $devicedetails{ $device . '_repeatcount' } = 0
                      if !defined $devicedetails{ $device . '_repeatcount' };
                    $devicedetails{ $device . '_repeattime' } = 0
                      if !defined $devicedetails{ $device . '_repeattime' };

                    my $x = 0;
                    while ( $devicedetails{ $device . '_repeatcount' } =~ m/\[(.*)\:(.*)\]/ )
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

                    if ( $devicedetails{ $device . '_repeatcount' } ne "undefined" && $devicedetails{ $device . '_repeattime' } ne"undefined" )
                    {

						if ( $devicedetails{ $device . '_repeatcount' } =~ m/[a-zA-Z]/s )
							{
								
								MSwitch_LOG( $name, 0,"Device $name -> Fehler in der Repeatangabe ".$devicedetails{ $device . '_repeatcount' } );
								
								$devicedetails{ $device . '_repeatcount' } = 0;
							}

                        if ( $devicedetails{ $device . '_repeatcount' } eq "" )
							{
								$devicedetails{ $device . '_repeatcount' } = 0;
							}
                        if ( $devicedetails{ $device . '_repeattime' } eq "" ) 
							{
								$devicedetails{ $device . '_repeattime' } = 0;
							}   

                        if (   $expertmode eq '1' && $devicedetails{ $device . '_repeatcount' } > 0)
							{
								my $i;
								for ($i = 1 ;$i <= $devicedetails{ $device . '_repeatcount' } ;$i++ )
								{
									$cs =~ s/\n/#[MSNL]/g;
									my $msg2 = $cs . "|" . $name;
									if ( $toggle ne '' ) 
										{
											$msg2 = $toggle . "|" . $name;
										}
									my $timecond =
									  gettimeofday() +
									  ( ( $i + 1 ) *
										  $devicedetails{ $device . '_repeattime' }
									  );
									$msg2 = $msg2 . "|[TIMECOND]|$device|$comand";
									MSwitch_LOG( $name, 6,"-> Befehlswiederholungen gesetzt: $timecond");
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

                        $cs =~ s/#\[MSNL\]/\n/g;

                    }
                    my $todec = $cs;
									
					if ( AttrVal( $name, 'MSwitch_CMD_processing', $cmdprocessing ) eq "block" ) {						
						$hash->{helper}{aktevent} = $event;
						$cs = MSwitch_dec( $hash, $cs );
						delete( $hash->{helper}{aktevent} );
					}             
					
                    if ( $cs =~ m/(^set.*)(\{.*\}$)/ ) {
                        my $exec = $2;
                        {
                            no warnings;
                            $exec = eval $exec;
								if ($exec eq "")
								{
								$exec = $2;
								}
                        }
                        $cs = $1 . $exec;
                    }

                    ############################
                    if ( $cs =~ m/{.*}/ ) 
					{
                        $cs =~ s/\[SR\]/\|/g;
                        push( @execute, $cs );
                        if ( $out eq '1' ) 
						{
                            MSwitch_LOG( $name, 6, "-> Abbruchbefehl ehalten von: ". $device . " \n" );
                            $lastdevice = $device;
                            last LOOP45;
                        }

                    }
                    else 
					{
                        MSwitch_LOG( $name, 6,"-> finaler Befehl auf Ausführungsstapel geschoben:\n$cs");
                        push( @execute, $cs );
                        if ( $out eq '1' ) 
						{
                            MSwitch_LOG( $name, 6, "-> Abbruchbefehl ehalten von: ". $device . " \n" );
                            $lastdevice = $device;
                            last LOOP45;
                        }
                    }
                }
            }
            else {
				
				
				#MSwitch_LOG( $name, 6,  "-> STARTKEY1: ".$devicedetails{$timerkey} );
				
				
                if (   $attrrandomtime ne ''
                    && $devicedetails{$timerkey} eq '[random]' )
                {
                    MSwitch_LOG( $name, 6, "-> setze zufälligen Timer");
                    $devicedetails{$timerkey} =
                      MSwitch_Execute_randomtimer($hash);
                }
                elsif ($attrrandomtime eq ''
                    && $devicedetails{$timerkey} eq '[random]' )
                {

                    MSwitch_LOG( $name, 6, "-> setze zufälligen Timer 0 - Attr nicht definiert " );
                    $devicedetails{$timerkey} = 0;
                }

                ###################################################################################

                my $timecond     = gettimeofday() + $devicedetails{$timerkey};
                my $delaykey     = $device . "_delayat" . $comand;
                my $delayinhalt  = $devicedetails{$delaykey};
                my $delaykey1    = $device . "_delayat" . $comand . "arg";
				
				
#MSwitch_LOG( $name, 6,  "->gesuchter key delaykey1: ".$delaykey1 );
#MSwitch_LOG( $name, 6,  "-> Inhalt: ".$devicedetails{$delaykey1});

				
                my $teststateorg = $devicedetails{$delaykey1};


#MSwitch_LOG( $name, 6,  "-> teststateorg: ".$teststateorg );
#MSwitch_LOG( $name, 6,  "-> delayinhalt: ".$delayinhalt );
#MSwitch_LOG( $name, 6,  "-> delaykey1: ".$delaykey1 );


                $conditionkey = $device . "_condition" . $comand;
                my $execute = "true";

                if ( $delayinhalt ne "delay2" && $delayinhalt ne "at02" ) {
                    $execute =
                      MSwitch_checkcondition( $devicedetails{$conditionkey},
                        $name, $event );
                }

#MSwitch_LOG( $name, 6,  "-> STARTKEY2: ".$devicedetails{$timerkey} );

                if ( $execute eq "true" ) 
				{
				#MSwitch_LOG( $name, 6,  "" );	
				#MSwitch_LOG( $name, 6,  "-> delayinhalt: ".$delayinhalt );
				#MSwitch_LOG( $name, 6,  "-> STARTKEY3: ".$devicedetails{$timerkey} );	
					
					
                    if ( $delayinhalt eq 'at0' || $delayinhalt eq 'at1' ) 
					{

                         MSwitch_LOG( $name, 6,  "-> setze Verzögerung1 $teststateorg" );

						# teststateorg muss time im zeitformat xx:xx:xx enzhalten !
					
                        $timecond =MSwitch_replace_delay( $hash, $teststateorg );
                        $devicedetails{$timerkey} = $timecond;
                        $timecond = gettimeofday() + $timecond;
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
                      . $device . "#[tr]"
                      . $comand;

                    $testtoggle = 'undef';
                    MSwitch_LOG( $name, 6,  "-> setze Verzögerung2 $timecond" );
					
					MSwitch_LOG( $name, 6,  "-> KEY2: ".$devicedetails{$timerkey} );
					
					
					
					
					

#################################################################

                    my $savename = "not_defined";

                    if ( $expertmode eq '1' ) {
                        my $sek      = $devicedetails{$timerkey};
                        my $h        = int( $sek / 3600 );
                        my $rest     = $sek % 3600;
                        my $min      = int( $rest / 60 );
                        my $sekunden = $rest % 60;

                        $h        = sprintf( "%2.2d", $h );
                        $min      = sprintf( "%2.2d", $min );
                        $sekunden = sprintf( "%2.2d", $sekunden );
                        $format =~ s/HH/$h/g;
                        $format =~ s/MM/$min/g;
                        $format =~ s/SS/$sekunden/g;
                        $format =~ s/ss/$sek/g;






                        if ( exists $data{MSwitch}{$name}{setdata}{last_cmd}
                            && $data{MSwitch}{$name}{setdata}{last_cmd} eq
                            "cmd_1" )
                        {
                            $field = "_countdownon";
                        }
                        if ( exists $data{MSwitch}{$name}{setdata}{last_cmd}
                            && $data{MSwitch}{$name}{setdata}{last_cmd} eq
                            "cmd_2" )
                        {
                            $field = "_countdownoff";
                        }




# MSwitch_LOG( $name, 6,"jump1: $jump");
# MSwitch_LOG( $name, 6,"devicedetails: $devicedetails{ $device . $field }");
# MSwitch_LOG( $name, 6,"device: $device");
# MSwitch_LOG( $name, 6,"field: $field");
# MSwitch_LOG( $name, 6,"jump1: $jump");
# MSwitch_LOG( $name, 6,"data: $data{MSwitch}{$name}{setdata}{last_cmd}");
# MSwitch_LOG( $name, 6,"jump1: $jump");




                        if ( defined $devicedetails{ $device . $field }
                            && $devicedetails{ $device . $field } ne "" )
                        {

                            my $counternumber = 0;
                            $savename = $devicedetails{ $device . $field } . "_"
                              . $counternumber;

                            ## prüde timername auf bereits laufend
                            while ( exists $hash->{helper}{countdown}{$savename}
                                && $hash->{helper}{countdown}{$savename} != 0 )
                            {
                                $counternumber++;
                                $savename =
                                    $devicedetails{ $device . $field } . "_"
                                  . $counternumber;
                                last if $counternumber > 20;    # notausstieg
                            }

							$showevents = MSwitch_checkselectedevent( $hash, "lastsetting_delay_ident" );
							readingsSingleUpdate( $hash, "lastsetting_delay_ident", $savename,$showevents );

							$showevents = MSwitch_checkselectedevent( $hash, "lastsetting_delay_cmd" );
                            readingsSingleUpdate( $hash, "lastsetting_delay_cmd",$data{MSwitch}{$name}{setdata}{last_cmd},$showevents );
							$showevents = MSwitch_checkselectedevent( $hash, "lastsetting_delay_time" );
                            readingsSingleUpdate( $hash, "lastsetting_delay_time", $format,$showevents );

						#}


#	MSwitch_LOG( $name, 6,"jump2: $jump");





                            if ( $jump > 0 ) {
                                $hash->{helper}{countdown}{$savename} = $sek;
								
								$showevents = MSwitch_checkselectedevent( $hash, $savename );
                                readingsSingleUpdate( $hash, $savename, $format,$showevents );

                                if ( !exists $hash->{helper}{countdownstatus} )
                                {
                                    $hash->{helper}{countdownstatus} =
                                      "inaktiv";
                                }

                                if ( $hash->{helper}{countdownstatus} eq
                                    "aktiv" )
                                {
                                    # hole zeit der nächsten ausführung
                                    my $nexttime =
                                      $hash->{helper}{countdownnexttime};
                                    my $akttime  = gettimeofday();
                                    my $nextjump = int( $nexttime - $akttime );
                                    my $diff     = $jump - $nextjump;

                                    my $ctime = $sek + $diff;
                                    $hash->{helper}{countdown}{$savename} =
                                      $ctime;

                                }

                                if ( $hash->{helper}{countdownstatus} ne
                                    "aktiv" )
                                {
                                    #aktiviere countdown;
                                    $hash->{helper}{countdownstatus} = "aktiv";
                                    my $timecond = gettimeofday() + $jump;
                                    my $msg      = "$name|$timecond";
                                    $hash->{helper}{countdownnexttime} =
                                      $timecond;
                                    InternalTimer( $timecond,
                                        "MSwitch_Countdown_new", $msg );
                                }
                            }
                        }
						
						
						
						
						
						
						
						
						
						
						
						
						
						

                    }

                    # savename festlegen !
                    my $timerset =
                      "[TIMER][NAME_$savename][NUMBER_$timercounter]$msg2";
                    $timers[$timercounter] = $timecond;
                    push( @execute, $timerset );
                    $timercounter++;

                    if ( $out eq '1' ) {

                        #abbruchbefehl erhalten von $device
                        MSwitch_LOG( $name, 6, "-> Abbruchbefehl erhalten von ". $device . " ");
                        $lastdevice = $device;
                        last LOOP45;
                    }
                }
            }
        }
        if ( $testtoggle ne '' && $testtoggle ne 'undef' ) {
            $satz .= $testtoggle . ',';
        }
    }

    my $fullstring = join( '[|]', @execute );
    my $msg;

    MSwitch_LOG( $name, 6, "-> Ausführung Befehlsstapel " );

    if (   defined $fullstring
        && exists $hash->{helper}{lastexecute}
        && AttrVal( $name, 'MSwitch_Switching_once', 0 ) == 1
        && $fullstring eq $hash->{helper}{lastexecute} )
    {
        MSwitch_LOG( $name, 6,"-> Ausfuehrung Befehlsstapel abgebrochen - Stapel wurde bereits ausgeführt (MSwitch_Switching_onc)");
    }
    else 
	{
         MSwitch_LOG( $name, 6,"-> anzahl vorhandener Befehle : ".@execute );
        foreach my $device (@execute) {

            next if $device eq "";
            next if $device eq " ";
            next if $device eq "  ";

            if ( $debugmode eq '2' ) {
                MSwitch_LOG( $name, 6, "-> nicht Ausgefuehrter (Debug2) Befehl: $device" );
                next;
            }
            else {
            }

            if ( $device =~ m/\[REPEATER\].*/ ) {
                MSwitch_LOG( $name, 6, "-> Repeaterhandling: $device");
                $device =~ m/\[NUMBER(.*?)](.*)/;
                my $number = $1;
                my $string = $2;
                $string =~ s/#\[MSNL\]/\n/g;
                my $timecondition = $timers[$number];
                $string =~ s/\[TIMECOND\]/$timecondition/g;
                MSwitch_LOG( $name, 6, "-> setze Repeat: $string L:");
                $hash->{helper}{repeats}{$timecondition} = "$string";
                InternalTimer( $timecondition, "MSwitch_repeat", $string );
                next;
            }

            if ( $device =~ m/\[TIMER\].*/ ) {
                $device =~ m/\[NAME_(.*?)\]/;
                my $identifier = $1;
                $device =~ m/\[NUMBER_(.*?)](.*)/;
                my $number = $1;
                my $string = $2;
                $string =~ s/#\[MSNL\]/\n/g;

                my $timecondition = $timers[$number];
                $string =~ s/TIMECOND/$timecondition/g;
                #################### new#

                my @delaydetails = split( /#\[tr\]/, $string );

                $hash->{helper}{delaydetails}{$timecondition}{name} =
                  $identifier;
                $hash->{helper}{delaydetails}{$timecondition}{cmd} =
                  $delaydetails[0];
                $hash->{helper}{delaydetails}{$timecondition}{device} =
                  $delaydetails[1];
                $hash->{helper}{delaydetails}{$timecondition}{number} = $number;
                $hash->{helper}{delaydetails}{$timecondition}{check} =
                  $delaydetails[2];
                $hash->{helper}{delaydetails}{$timecondition}{Indikator} =
                  $delaydetails[3];
                $hash->{helper}{delaydetails}{$timecondition}{cmdzweig} =
                  $delaydetails[5];
                $hash->{helper}{delaydetails}{$timecondition}{state} =
                  $delaydetails[6];

                ####################
                InternalTimer( $timecondition, "MSwitch_Restartcmdnew",
                    $timecondition . "-" . $delaydetails[1] );
                next;
            }

            $msg .= $device . ";";

##############################################################
############### achtung evtll ungewollte aktionen 
##############################################################

	 # perlcodiert
	# my $errors ="";	
           if ( $device =~ m/^\{/ ) 
		{
			   
			   $device = MSwitch_dec( $hash, $device );
			   MSwitch_LOG( $name, 6,"aufruf freecmd: > ".__LINE__);

               $device = MSwitch_makefreecmd( $hash, $device );
				
			MSwitch_LOG( $name, 6,"Perlcodierung erkannt " . __LINE__ );		
			MSwitch_LOG( $name, 6,"---$device----" . __LINE__ ); 	   
			   
                {
                    no warnings;
                    eval($device);
                }
                if ( $@ and $@ ne "OK" ) 
				{
                    MSwitch_LOG( $name, 1,"$name MSwitch_Set: ERROR $device: $@ " . __LINE__ );
					MSwitch_LOG( $name, 6,"!!!!!!!!!!!!!!!!\nERROR $name $device: $@ " . __LINE__ ."\n!!!!!!!!!!!!!!!!");		
                }
            }
            else 
			{
                my $deepsafe = "undef";
                $deepsafe = "set $name " . $hash->{helper}{deepsave} if exists $hash->{helper}{deepsave};

                if (
                    (
                           $deepsafe eq "set $name off"
                        || $deepsafe eq "set $name on"
                    )
                    && (   $device eq "set $name off "
                        || $device eq "set $name on " )
                  )
                {

                    fhem("$device");
                    MSwitch_LOG( $name, 6,
"!!! bevorstehende DEEPRECURSION erkannt.\n   LOOP wird unterbrochen.\n   Die Einhaltung der Befehlsreihenfolge kann nicht Gewährleistet werden.\n   Befehl:$device wird neu gestaret."
                    );
                    next;
                }
                else 
				{
					
		# fhemcodiert

			
			if ( AttrVal( $name, 'MSwitch_CMD_processing', $cmdprocessing ) eq "block" )
			{			
					MSwitch_LOG( $name, 6,"execute command BLOCKMODE-> $device " . __LINE__ ."\n");	
                    $errors = AnalyzeCommandChain( undef, $device );
			}	
					
			if ( AttrVal( $name, 'MSwitch_CMD_processing', $cmdprocessing ) eq "line" )
			{		
			
			$msg ="";
			$hash->{helper}{aktevent} = $event;
				MSwitch_LOG( $name, 6,"$name -> execute command LINEMODE-> $device " . __LINE__ );		
				my @lines = split( /;/, $device );	
				MSwitch_LOG( $name, 6,"$name -> LINES-> \n\n@lines\n\n" . __LINE__ );	

				
				 foreach my $einzelline (@lines) 
				 {
		
					$einzelline =~ s/\n//g;
					if ($einzelline eq "" )
					{
					MSwitch_LOG( $name, 6,"$name -> leerzeile übersprungen -> $einzelline " . __LINE__ );	
					next;
					}
					
					MSwitch_LOG( $name,6,"$name -> LINE -> $einzelline " . __LINE__ );		
					
					$einzelline = MSwitch_dec( $hash, $einzelline );
				
					MSwitch_LOG( $name, 6,"$name -$errors- -> LINEfromDEC -> $einzelline " . __LINE__ );	
					
					my $ret = AnalyzeCommandChain( undef,$einzelline );
	
					if (defined $ret)
					{
					$errors.= $ret;
					}
					
					$msg.=$einzelline.";";
				 }
				 
			delete( $hash->{helper}{aktevent} );	  
			}		
	
			if ( defined($errors) and $errors ne "OK" and $errors ne "" )
				{
                        if ( $device =~ m/^get.*/ ) 
						{
                            MSwitch_PerformGetRequest( $hash, $errors );
                        }
                        else 
						{
						MSwitch_LOG( $name, 6,"\n! CommandAnswer $name $device $errors " . __LINE__ ."\n");	
						if ($errors eq "Executing the update the background.")
							{
							asyncOutput( $hash->{CL},"<html><center><br>Update laeuft im Hintergrund<br>Modul wird in 10 Sekunden neu geladen,Fhemneustart wird empfohlen.</html>");
							}
						}
                 }	
		
                }
            }
        }

        if ( defined $msg && length($msg) > 100 ) {
            $msg = substr( $msg, 0, 100 ) . '....';
        }
		$showevents = MSwitch_checkselectedevent( $hash, "last_exec_cmd" );
        readingsSingleUpdate( $hash, "last_exec_cmd", $msg, $showevents )
          if defined $msg;

        if ( @execute > 0 ) {
            $hash->{helper}{lastexecute} = $fullstring;
        }
        else {
        }
    }
    return $satz;
}
####################

sub MSwitch_checkcondition($$$) {

    my ( $condition, $name, $event ) = @_;
    my $conditionorg = $condition;
    my $hash         = $modules{MSwitch}{defptr}{$name};
    my $futurelevel  = AttrVal( $name, 'MSwitch_Futurelevel', '0' );
    my $answer;

    # abbruch bei leerer condition
    if ( !defined($condition) ) { return 'true'; }
    if ( $condition eq '' )     { return 'true'; }
	MSwitch_LOG( $name, 6,"\n----------  SUB MSwitch_checkcondition ----------");
	
	
	
	MSwitch_LOG( $name, 6,"condition: $condition ");
	
	
	$condition =~ s/#\[dp\]/:/g;
	$condition =~ s/#\[sp\]/ /g;

    ############# prüfe klammerfehler

    my $anzahlk1 = $condition =~ tr/{//;
    my $anzahlk2 = $condition =~ tr/}//;

    if ( $anzahlk1 ne $anzahlk2 ) {
        $hash->{helper}{conditioncheck} = "Klammerfehler";
        return "false";
    }

    $anzahlk1 = $condition =~ tr/(//;
    $anzahlk2 = $condition =~ tr/)//;

    if ( $anzahlk1 ne $anzahlk2 ) {
        $hash->{helper}{conditioncheck} = "Klammerfehler";
        return "false";
    }

    $anzahlk1 = $condition =~ tr/[//;
    $anzahlk2 = $condition =~ tr/]//;

    if ( $anzahlk1 ne $anzahlk2 ) {
        $hash->{helper}{conditioncheck} = "Klammerfehler";
        return "false";
    }

    my $we = AnalyzeCommand( 0, '{return $we}' );
    my $time = int(time);

    my $timecondtest = localtime;
    my $timestamp    = $timecondtest;

    $timestamp =~ s/\s+/ /g;

    my ( $tday, $tmonth, $tdate, $tn, $time1 ) = split( / /, $timestamp );
    my ( $HH, $MM, $SS ) = split( /:/, $tn );

    $timestamp = timelocal( $SS, $MM, $HH, $tdate, $tmonth, $time1 );

    ##############################

    my ( $sec, $min, $hour, $mday, $month, $year, $wday, $yday, $isdst ) =
      localtime( gettimeofday() );
    $month++;
    $year += 1900;
    $wday = 7 if $wday == 0;
    my $hms = AnalyzeCommand( 0, '{return $hms}' );
    my $attrrandomnumber = AttrVal( $name, 'MSwitch_RandomNumber', '' );
    if ( $attrrandomnumber ne '' ) {
        MSwitch_Createnumber($hash);
    }
    my $debugmode = AttrVal( $name, 'MSwitch_Debug', "0" );

    my $finalstring  = "";
    my $finalstring1 = "";
    my $finalstring2 = "";
    my $field        = "";
    my $SELF         = $name;
    my $searchstring;

    ###########################
    my ( $evtparts1, $evtparts2, $evtparts3 ) = split( /:/, $event, 3 );
    my $evtfull = $event;
    ###############################

    # ersetzung snippet
	
	$condition = MSwitch_change_snippet($hash,$condition);

    # ersetzungen

    $condition =~ s/ AND / && /ig;
    $condition =~ s/ OR / || /ig;
    $condition =~ s/ = / == /ig;
    $condition =~ s/\$year|\[YEAR\]/$year/g;
    $condition =~ s/\$month|\[MONTH\]/$month/g;
    $condition =~ s/\$day|\[DAY\]/$mday/g;
    $condition =~ s/\$yday|\[YDAY\]/$yday/g;
    $condition =~ s/\$wday|\[WDAY\]/$wday/g;
    $condition =~ s/\$min|\[MIN\]/$min/g;
    $condition =~ s/\$hour|\[HOUR\]/$hour/g;
    $condition =~ s/\$hms|\[HMS\]/$hms/g;
    $condition =~ s/\$timestamp/$timestamp/g;
    $condition =~ s/\$time/$time/g;
    $condition =~ s/\$NAME/$name/ig;
    $condition =~ s/\$SELF/$name/ig;
	
	
	
	
    $condition =~ s/\:\$EVENT/:$event/ig;
    $condition =~ s/\:\$EVTFULL/:$evtfull/ig;
    $condition =~ s/\:\$EVTPART1/:$evtparts1/ig;
    $condition =~ s/\:\$EVTPART2/:$evtparts2/ig;
    $condition =~ s/\:\$EVTPART3/:$evtparts3/ig;
	
	
	
	#if ($futurelevel ne "6.78")
	#{
     $condition =~ s/\$EVENT/"$event"/ig;
     $condition =~ s/\$EVTFULL/"$evtfull"/ig;
     $condition =~ s/\$EVTPART1/"$evtparts1"/ig;
     $condition =~ s/\$EVTPART2/"$evtparts2"/ig;
     $condition =~ s/\$EVTPART3/"$evtparts3"/ig;
	#}
	
	
	
	
    $condition =~ s/\$ARG/$hash->{helper}{timerarag}/g;

    if ( defined $evtparts3 ) {
        if ( $evtparts3 =~ '^[\d\.]+$' ) {
            $condition =~ s/\$EVTPART3/$evtparts3/ig;
        }
        else {
            $condition =~ s/\$EVTPART3/"$evtparts3"/ig;
        }
    }


	MSwitch_LOG( $name, 6,"condition3: $condition ");



## ersetze multicondition Format [NAME:READING_h0::10]

    my $x = 0;
    $condition = "START " . $condition . " END";

    while ( $condition =~
m/(.*[START|AND|OR|\&\&|\|\|\s|\(|\)]?)(\[.*::\d{1,}\])(.*?[\d|"|\]])(\s[END|AND|OR|\&\&|\|\|].*)/
      )    #z.b $WE
    {
        my $part1 = $1;
        my $part2 = $2;
        my $part3 = $3;
        my $part4 = $4;

        $x++;
        last if $x > 20;
        my $multicondition = $part2 . $part3;
        ###########
        my $middlepart = "";
        my @treffer    = $multicondition =~ m/\[(.*):(.*)(\d+)::(\d+)\](.*)/gs;

        while ( $treffer[2] <= $treffer[3] ) {
            $middlepart =
                $middlepart . " ["
              . $treffer[0] . ":"
              . $treffer[1]
              . $treffer[2] . "] "
              . $treffer[4] . " && ";
            $treffer[2]++;
        }
        chop $middlepart;
        chop $middlepart;
        chop $middlepart;
        ###########
        my $newcondition = $part1 . "(" . $middlepart . ") " . $part4;
        $condition = $newcondition;
    }

    while ( $condition =~
m/(.*[START|AND|OR|\&\&|\|\|\s|\(|\)]?)(\[.*::\d{1,}_time\])(.*?[\d|"|\]])(\s[END|AND|OR|\&\&|\|\|].*)/
      )    #z.b $WE
    {
        my $part1 = $1;
        my $part2 = $2;
        my $part3 = $3;
        my $part4 = $4;

        $x++;
        last if $x > 20;
        my $multicondition = $part2 . $part3;
        ###########
        my $middlepart = "";
        my @treffer =
          $multicondition =~ m/\[(.*):(.*)(\d+)::(\d+)(_time)\](.*)/gs;

        while ( $treffer[2] <= $treffer[3] ) {
            $middlepart =
                $middlepart . " ["
              . $treffer[0] . ":"
              . $treffer[1]
              . $treffer[2]
              . $treffer[4] . "] "
              . $treffer[5] . " && ";
            $treffer[2]++;
        }
        chop $middlepart;
        chop $middlepart;
        chop $middlepart;
        
        my $newcondition = $part1 . "(" . $middlepart . ") " . $part4;
        $condition = $newcondition;
    }

    $condition =~ s/START //ig;
    $condition =~ s/ END//ig;

#################

    $x = 0;
    my $change = $condition;



MSwitch_LOG( $name, 6,"condition: $condition ");
MSwitch_LOG( $name, 6,"change: $change ");

    # perlersetzung
    while ( $change =~ m/\{(.*?)\}/ )    #z.b $WE
    {
        my $orgstring = $1;
        my $tochange  = "\$field = " . $1;
        eval($tochange);
        # ersetze alle metazeichen
        $orgstring =~ s/(\\|\||\(|\)|\[|\]|\^|\$|\*|\+|\?|\.|\<|\>)/\\$1/ig;
        $change =~ s/\{$orgstring\}/$field/ig;
        $x++;
        last if $x > 100;
        #notausstieg
    }

MSwitch_LOG( $name, 6,"change1: $change ");




my %setmarray;

		MSwitch_LOG( $name, 6,"futurelevel: $futurelevel ");






#    [ECHO_SZ:musicwecker_01]

if ($futurelevel eq "7.68")
	{
		
		MSwitch_LOG( $name, 6,"SCHLEIFE Futurelevel");
			
		$x = 0;
	    #while ( $change =~ m/(\[["a-zA-Z0-9:\.\|_-]+\])/ ) 
		#while ( $change =~ m/(\[["a-zA-Z0-9:\.\|_-]+\]:\[["a-zA-Z0-9:\.\|_-]+\])/ ) 
		 
		  while ( $change =~ m/(\[["a-zA-Z0-9:\.\|_-]+:["a-zA-Z0-9:\.\|_-]+\])/ ) 
		 
		
		 
			{
				my $treffer = $1;
				my $aktarg  = "SETMAGIC_" . $x;
				$setmarray{$aktarg} = $treffer;
				my $convertreffer = $treffer;
				$convertreffer =~ s/(\\|\||\(|\)|\[|\]|\^|\$|\*|\+|\?|\.|\<|\>)/\\$1/ig;
				MSwitch_LOG( $name, 6,"FUTaktarg: $aktarg ");
				MSwitch_LOG( $name, 6,"FUTconvertreffer: $convertreffer ");
				$change =~ s/$convertreffer/ $aktarg /ig;
				$x++;    # notausstieg notausstieg
				last if $x > 100;    # notausstieg notausstieg
			}
	}


	
	if ($futurelevel ne "7.68")
	{
    $x = 0;
		while ( $change =~ m/(\[["a-zA-Z0-9:\.\|_-]+\])/ ) 
			{
				my $treffer = $1;
				my $aktarg  = "SETMAGIC_" . $x;
				$setmarray{$aktarg} = $treffer;
				my $convertreffer = $treffer;
				$convertreffer =~ s/(\\|\||\(|\)|\[|\]|\^|\$|\*|\+|\?|\.|\<|\>)/\\$1/ig;
				MSwitch_LOG( $name, 6,"aktarg: $aktarg ");
				MSwitch_LOG( $name, 6,"convertreffer: $convertreffer ");
				
				
				$change =~ s/$convertreffer/ $aktarg /ig;
				$x++;    # notausstieg notausstieg
				last if $x > 100;    # notausstieg notausstieg
			}
	}
	
	

MSwitch_LOG( $name, 6,"change2: $change ");
#############

    my %setnewmarray;
    my %setnewminhaltarray;

    foreach my $key ( ( keys %setmarray ) ) {
        my $arg     = $setmarray{$key};
        my $testarg = $setmarray{$key};

        $testarg =~ s/[0-9]+//gs;


MSwitch_LOG( $name, 6,"testarg: $testarg ");



        ##########
        if ( $arg =~
'\[(ReadingsVal|ReadingsNum|ReadingsAge|AttrVal|InternalVal):(.*?):(.*?):(.*?)\]'
          )
        {
			
		MSwitch_LOG( $name, 6,"auslöser: 1 ");	
			
            my $evalstring = "$1('$2','$3','$4')";
            my $inhalt     = eval($evalstring);
            $setnewmarray{$key}       = $evalstring;
            $setnewminhaltarray{$key} = $inhalt;
            next;
        }





        ###########
        if ( $testarg =~ '\[.*?:h\]' )    #history
        {
			
			
			MSwitch_LOG( $name, 6,"auslöser: 2 ");	
			
			
            $setnewmarray{$key} = MSwitch_Checkcond_history( $arg, $name );
            if ( $setnewmarray{$key} eq "''" ) {
                $setnewmarray{$key}       = "undef";
                $setnewminhaltarray{$key} = $setnewmarray{$key};
            }
            else {
                $setnewminhaltarray{$key} = $setnewmarray{$key};
                $setnewminhaltarray{$key} = $setnewmarray{$key};
            }
            next;
        }
		
		
		
		
		

        if ( $testarg =~ '\[.*[a-zA-Z0-9_]{1}.:.*\]' )    #reading
        {
			
			
			
			MSwitch_LOG( $name, 6,"auslöser: 3 ");	
			
			
			
            $arg =~ s/"//gs;
            $arg =~ s/'//gs;
            $setnewmarray{$key} = MSwitch_Checkcond_state( $arg, $name );
            $setnewminhaltarray{$key} = eval( $setnewmarray{$key} );
            next;
        }
        $setnewmarray{$key}       = $setmarray{$key};
        $setnewminhaltarray{$key} = $setmarray{$key};
    }






    my $change1 = $change;

MSwitch_LOG( $name, 6,"changeX: $change ");


    foreach my $key ( ( keys %setmarray ) ) {
        my $log =
"$setmarray{$key} -> $setnewmarray{$key} -> $setnewminhaltarray{$key}";

        $data{MSwitch}{$hash}{condition}{$key} = $log;
        my $aktkey = $key;

        if ( $setnewminhaltarray{$key} =~ '^[\d\.]+$' ) {
						MSwitch_LOG( $name, 6,"auslöser: 4 ");	

            $change =~ s/ $key /$setnewminhaltarray{$key}/g;
            $change1 =~ s/ $key /$setnewminhaltarray{$key}/g;
        }
        elsif ( $setnewminhaltarray{$key} =~ '\d\d:\d\d' ) {
						MSwitch_LOG( $name, 6,"auslöser: 5 ");	

            $change =~ s/ $key /$setnewminhaltarray{$key}/g;
            $change1 =~ s/ $key /$setnewminhaltarray{$key}/g;
        }
        else {
			
			
MSwitch_LOG( $name, 6,"auslöser: 6 ");	
MSwitch_LOG( $name, 6,"auslöser: 6 -> key $key");
MSwitch_LOG( $name, 6,"auslöser: 6 ->".$setnewminhaltarray{$key}."-");

# auslöser: 6 ->[test]-


		if ( $setnewminhaltarray{$key} =~ '[test]' ) 
			{
				
				MSwitch_LOG( $name, 6,"OPTION: 1 ");
				
			$change =~ s/ $key /"$setnewminhaltarray{$key}"/g;
            $change1 =~ s/ $key /$setnewmarray{$key}/g;
			}
			else
			{
				
				MSwitch_LOG( $name, 6,"OPTION: 2 ");
				
			$change =~ s/ $key /"$setnewminhaltarray{$key}"/g;
            $change1 =~ s/ $key /$setnewmarray{$key}/g;
			}
			
			





            
        }
    }


MSwitch_LOG( $name, 6,"changeX: $change ");




    ##### timererkennung
    $x = 0;
    while ( $change =~
m/(\[!?\d{2}:\d{2}-\d{2}:\d{2}\|[!0-7]+?\]|\[!?\d{2}:\d{2}-\d{2}:\d{2}\])/
      )
    {
        my $akttimer = $1;
        my $orgtimer = $1;

        #convertreffer
        $akttimer =~ s/(\\|\||\(|\)|\[|\]|\^|\$|\*|\+|\?|\.|\<|\>)/\\$1/ig;
        my $newtimer = MSwitch_Checkcond_time( $orgtimer, $name );
        $change =~ s/$akttimer/$newtimer/g;
        $x++;    # notausstieg notausstieg
        last if $x > 20;    # notausstieg notausstieg
    }






    # zeiterkennung
    $x = 0;
    while (
        $change =~ m/(^\d\d:\d\d\s|\s\d\d:\d\d\s|\s\d\d:\d\d$|^\d\d:\d\d$)/ )
    {
        my $foundtimeorg = $1;
        my $foundtime    = $1 . ":00";
        my ( $HH, $MM, $SS ) = split( /:/, $foundtime );
        $timecondtest =~ s/\s+/ /g;
        my ( $tday, $tmonth, $tdate, $tn, $time1 ) =
          split( / /, $timecondtest );
        my $newsecond = timelocal( '00', $MM, $HH, $tdate, $tmonth, $time1 );
        $change =~ s/$foundtimeorg/ $newsecond /g;
        $x++;    # notausstieg notausstieg
        last if $x > 20;    # notausstieg notausstieg
    }






    $x = 0;
    while ( $change =~
m/(^\d\d:\d\d:\d\d\s|\s\d\d:\d\d:\d\d\s|\s\d\d:\d\d:\d\d$|^\d\d:\d\d:\d\d$)/
      )
    {

        my $foundtimeorg = $1;
        my $foundtime    = $1;
        my ( $HH, $MM, $SS ) = split( /:/, $foundtime );
        $timecondtest =~ s/\s+/ /g;
        my ( $tday, $tmonth, $tdate, $tn, $time1 ) =
          split( / /, $timecondtest );
        my $newsecond = timelocal( $SS, $MM, $HH, $tdate, $tmonth, $time1 );

        $change =~ s/$foundtimeorg/ $newsecond /g;
        $x++;    # notausstieg notausstieg
        last if $x > 20;    # notausstieg notausstieg
    }



MSwitch_LOG( $name, 6,"condition8: $condition ");
MSwitch_LOG( $name, 6,"change: $change ");




# if ($futurelevel eq "6.78")
	# {
     # $condition =~ s/\$EVENT/"$event"/ig;
     # $condition =~ s/\$EVTFULL/"$evtfull"/ig;
     # $condition =~ s/\$EVTPART1/"$evtparts1"/ig;
     # $condition =~ s/\$EVTPART2/"$evtparts2"/ig;
     # $condition =~ s/\$EVTPART3/"$evtparts3"/ig;
	# }





$change =~ s/@/\\@/g;
$change =~ s/$//g;


    $finalstring =
      "if (" . $change . "){\$answer = 'true';} else {\$answer = 'false';} ";
    $finalstring2 = "if (" . $change . ")";
    $finalstring1 = "if (" . $change1 . ") ";
	
	
	
	# MSwitch_LOG( $name, 6, "\n-> Bedingungsprüfung (final):\n$finalstring !");
	
	MSwitch_LOG( $name, 6,"condition9: $condition ");
	
    MSwitch_LOG( $name, 6, "\n-> Bedingungsprüfung (final):\n$finalstring !");

    my $ret;
    {
        no warnings;
        $ret = eval $finalstring;
    }

    if ($@) {
        MSwitch_LOG( $name, 1, "aufruf condcheck ############# " . __LINE__ );
        MSwitch_LOG( $name, 1, "$name EERROR: $@ " );
        MSwitch_LOG( $name, 1, "Finalstring: $finalstring" );
        MSwitch_LOG( $name, 1, "Event: $event" );
        MSwitch_LOG( $name, 1, "Eventfull: $evtfull" );
        MSwitch_LOG( $name, 1, "############# \n" );
        MSwitch_LOG( $name, 6, "############# " . __LINE__ );
        MSwitch_LOG( $name, 6, "$name EERROR: $@ " );
        MSwitch_LOG( $name, 6, "Finalstring: $finalstring" );
        MSwitch_LOG( $name, 6, "Event: $event" );
        MSwitch_LOG( $name, 6, "Eventfull: $evtfull" );
        MSwitch_LOG( $name, 6, "############# \n" );

        $hash->{helper}{conditionerror} = $@;
        return 'false';
    }

    if ( $ret ne "true" ) {
        MSwitch_LOG( $name, 6, "-> Befehlsabbruch - Bedingung nicht erfüllt " );
    }
	else{
		MSwitch_LOG( $name, 6, "-> Bedingung erfüllt " );
	}
    $hash->{helper}{conditioncheck}  = $finalstring2;
    $hash->{helper}{conditioncheck1} = $finalstring1;
    return $ret;
}

####################
sub MSwitch_Checkcond_state($$) {
    my ( $condition, $name ) = @_;
    my $hash = $modules{MSwitch}{defptr}{$name};

    my $evtfull   = $hash->{helper}{evtparts}{evtfull};
    my $event     = $hash->{helper}{evtparts}{event};
    my $evtparts1 = $hash->{helper}{evtparts}{evtpart1};
    my $evtparts2 = $hash->{helper}{evtparts}{evtpart2};
    my $evtparts3 = $hash->{helper}{evtparts}{evtpart3};

    $condition =~ s/\$EVENT/$event/ig;
    $condition =~ s/\$EVTFULL/$evtfull/ig;
    $condition =~ s/\$EVTPART1/$evtparts1/ig;
    $condition =~ s/\$EVTPART2/$evtparts2/ig;
    $condition =~ s/\$EVTPART3/$evtparts3/ig;

    my $x = 0;
    while ( $condition =~ m/(.*?)(\$SELF)(.*)?/ ) {
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

    if ( defined $reading[2] and $reading[2] eq "d" ) {
        $test = ReadingsNum( $reading[0], $reading[1], 'undef' );
        $return =
          "ReadingsNum('$reading[0]', '$reading[1]', 'undef')";    #00:00:00
    }
    else {
        $test = ReadingsVal( $reading[0], $reading[1], 'undef' );
        $return =
          "ReadingsVal('$reading[0]', '$reading[1]', 'undef')";    #00:00:00
    }
    return $return;
}
####################
sub MSwitch_Checkcond_time($$) {
    my ( $condition, $name ) = @_;
    my $conditionorg = $condition;

    $condition =~ s/!//;
    $condition =~ s/\[//;
    $condition =~ s/\]//;

    my $hash         = $defs{$name};
    my $adday        = 0;
    my $days         = '';
    my $daycondition = '';
    ( $condition, $days ) = split( /\|/, $condition )
      if index( $condition, "|", 0 ) > -1;
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
    if ( $hour2 eq "24" ) {
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

    if ( $hour1 > 23 || $min1 > 59 || $hour2 > 23 || $min2 > 59 ) {
        $hash->{helper}{wrongtimespeccond} =
          "ERROR: wrong timespec in condition. $condition";
        my $return = "(0 < 0 && 0 > 0)";
        MSwitch_LOG( $name, 1,
"$name:  ERROR wrong format in Condition $condition Format must be HH:MM."
        );
        return $return;
    }
    $timecond1 = timelocal( '00', $min1, $hour1, $tdate, $tmonth, $time1 );
    $timecond2 = timelocal( '00', $min2, $hour2, $tdate, $tmonth, $time1 );
    my $timeaktuell =
      timelocal( '00', $aktmin, $akthour, $date, $month, $time1 );

    if ( $timeaktuell < $timecond2 && $timecond2 < $timecond1 ) {
        use constant SECONDS_PER_DAY => 60 * 60 * 24;
        $timecond1 = $timecond1 - SECONDS_PER_DAY;
        $adday     = 1;
    }
    if ( $timeaktuell > $timecond1 && $timecond2 < $timecond1 ) {
        use constant SECONDS_PER_DAY => 60 * 60 * 24;
        $timecond2 = $timecond2 + SECONDS_PER_DAY;
        $adday     = 1;
    }

    my $return;

    if ( $conditionorg =~ '\[!' ) {
        $condition =~ s/!//;
        $return = "($timeaktuell < $timecond1 || $timeaktuell > $timecond2)";
    }
    else {
        $return = "($timecond1 <= $timeaktuell && $timeaktuell <= $timecond2)";
    }

    if ( $days ne '' ) {
        $daycondition = MSwitch_Checkcond_day( $days, $name, $adday, $day );
        $return = "($return $daycondition)";
    }
    return $return;
}
####################
sub MSwitch_Checkcond_history($$) {
    my ( $condition, $name ) = @_;
    $condition =~ s/\[//;
    $condition =~ s/\]//;
    my $hash = $defs{$name};
    my $return;
    my $seq;
    my $x   = 0;
    my $log = $hash->{helper}{eventlog};
    if ( $hash->{helper}{history}{eventberechnung} ne
        "berechnet" )    # teste auf vorhandene berechnung
    {
        foreach $seq ( sort { $b <=> $a } keys %{$log} ) {
            my @historyevent = split( /:/, $hash->{helper}{eventlog}{$seq} );
            $hash->{helper}{history}{event}{$x}{EVENT} =
              $hash->{helper}{eventlog}{$seq};
            $hash->{helper}{history}{event}{$x}{EVTFULL} =
              $hash->{helper}{eventlog}{$seq};
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
    my $inhalt =
      $hash->{helper}{history}{event}{$historynumber}{ $historysplit[0] }; #????
    $return = "'" . $inhalt . "'";
    return $return;
}
####################
sub MSwitch_Checkcond_day($$$$) {
    my ( $days, $name, $adday, $day ) = @_;
    my $rzeichen = "==";
    my $logik    = "||";
    if ( $days =~ '^!' ) {
        $days =~ s/!//;
        $rzeichen = "!=";
        $logik    = "&&";
    }

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
    foreach my $args (@daycond) {
        if ( $adday == 1 ) { $args++; }
        if ( $args == 8 ) { $args = 1 }
        $daycond = $daycond . "($day $rzeichen $args) $logik  ";
    }
    chop $daycond;
    chop $daycond;
    chop $daycond;
    chop $daycond;
    $daycond = "&& ($daycond)";
    return $daycond;
}

###################################
sub MSwitch_Clear_timer($) {
    my ( $hash, $device ) = @_;
    my $name     = $hash->{NAME};
    my $timehash = $hash->{helper}{timer};
    foreach my $a ( keys %{$timehash} ) {
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
#[REPEAT=00:02*04:10-06:30|RANDOM=20:00-21:00|TIME=17:00|DAYS=1,2,3|MONTH=1,2,3,12|CW=1,2,3|ARG=12]
sub MSwitch_Createtimer($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
    my $we           = AnalyzeCommand( 0, '{return $we}' );
    my $aktuellezeit = gettimeofday();
    my $timerexist   = 0;
	my $showevents  = AttrVal( $Name, "MSwitch_generate_Events", 0 );
    my @nexttimer;
    MSwitch_Clear_timer($hash);
    delete( $hash->{helper}{wrongtimespec} );
    #### aktuelle daten setzen
    my $akttimestamp = TimeNow();
    my ( $aktdate, $akttime ) = split / /, $akttimestamp;
    my ( $aktyear, $aktmonth, $aktmday ) = split /-/, $aktdate;
    my $showdate  = $aktmday . "." . $aktmonth . "." . $aktyear;
    my $showmonth = $aktmonth;
    $aktmonth = $aktmonth - 1;
    my $time = localtime;
    $time =~ s/\s+/ /g;
    my ( $day, $month, $date, $n, $time1 ) =
      split( / /, $time );    # day enthält aktuellen tag als wochentag
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

    my $weekNumber = POSIX::strftime( "%V", localtime time );

    my ( $secx, $minx, $hourx, $mday, $monthx, $yearx, $wday, $ydayx, $isdstx )
      = localtime( gettimeofday() );

    $wday = 7 if $wday == 0;

    # timeranpassung an Bertriebsmode
    my $timercount = 5;
    if ( AttrVal( $Name, 'MSwitch_Mode', 'Notify' ) eq "Notify" ) 
	{
        $timercount = 2;
    }
    if ( AttrVal( $Name, 'MSwitch_Mode', 'Notify' ) eq "Toggle" ) 
	{
        $timercount = 1;
    }

    for ( my $i = 1 ; $i <= 5 ; $i++ ) {
        my $timer = ReadingsVal( $Name, '.Trigger_time_' . $i, '' );
        $timer =~ s/#\[dp\]/:/g;
        $timer =~ s/\$name/$Name/g;
        next if $timer eq "";

        $timerexist = 1;
        ## timer in felder teilen
        my @alltimers = split( /\[NEXTTIMER\]/, $timer );
		EACHTIMER: foreach my $einzeltimer (@alltimers) {
######################## ersetzungen
            #ersetze Snippetz
			
			$einzeltimer = MSwitch_change_snippet($hash,$einzeltimer);
			#! Achtung ggf muss die rückgabe so sein:
			# $ret =~ s/\n/#[nl]/g;

            # suche nach setmagic
            my $x = 0;
            while (
                $einzeltimer =~ m/(.*)\[([0-9]?[a-zA-Z\$]{1}.*\:.*?)\](.*)/ )
            {
                $x++;    # notausstieg
                last if $x > 20;    # notausstieg
                my $firstpart = $1;
                my $devname   = $2;
                my $lastpart  = $3;
                $devname =~ s/\$SELF/$Name/g;
                my ( $device, $reading ) = split( /:/, $devname );
                my $setmagic = ReadingsVal( $device, $reading, 'wrongformat' );
                $einzeltimer = $firstpart . $setmagic . $lastpart;
            }

            #ersetze Perl
            $x = 0;
            while ( $einzeltimer =~ m/(.*)\{(.*)\}(.*)/ ) 
			{
                $x++;    # notausstieg
                last if $x > 20;    # notausstieg
                if ( defined $2 ) 
				{
                    my $part1 = $1;
                    my $part2 = $2;
                    my $part3 = $3;
                    my $exec =
                        "my \$name='"
                      . $Name
                      . "';my \$SELF='"
                      . $Name
                      . "';my \$return = "
                      . $part2
                      . ";return \$return;";
                    $exec =~ s/#\[nl\]/\n/g;
                    {
                        no warnings;
                        $part2 = eval $exec;
                    }
					
					 if (!defined $part2 || $part2 eq "")
					 {
						 MSwitch_LOG($Name, 0, "Error bei Timer des Devices $Name \n -> einzeltimer nach perl -> $einzeltimer" );
						 
						 MSwitch_Clear_timer($hash);
						 return;
					 }
                    my $part2hh = substr( $part2, 0, 2 );
                    my $part2mm = substr( $part2, 3, 2 );
                    if ( $part2hh > 23 ) { $part2hh = $part2hh - 24 }
                    $part2       = $part2hh . ":" . $part2mm;
                    $einzeltimer = $part1 . $part2 . $part3;
                }
            }

#############
            my @timerfile = split( /\|/, $einzeltimer );
            my %timertable;
            $timertable{TIME}    = "";
            $timertable{REPEAT}  = "";
            $timertable{RANDOM}  = "";
            $timertable{WDAY}    = "";
            $timertable{YEAR}    = "";
            $timertable{CW}      = "";
            $timertable{DATE}    = "";
            $timertable{CDAY}    = "";
            $timertable{CMONTH}  = "";
            $timertable{ID}      = "";
            $timertable{WEEK}    = "";    #weekNumber
            $timertable{WEEKEND} = "";
            $timertable{MDAY}    = "";
            $timertable{ARG}     = "";

            my $id = "";
            foreach my $fullpart (@timerfile) {
                my ( $part1, $part2 ) = split( /=/, $fullpart );
                $timertable{$part1} = $part2 if defined $part1;
            }

            if ( $timertable{TIME} =~ m/^\d\:\d\d$/ ) {

                $timertable{TIME} = "0" . $timertable{TIME};

            }

            ## prüfe auf nur ein vorkommen einer zeitangabe TIME/RANDOM/REPEAT
            my $control = 0;
            $control++ if $timertable{TIME} ne "";
            $control++ if $timertable{REPEAT} ne "";
            $control++ if $timertable{RANDOM} ne "";
            next       if $control > 1;

######### prüfe alle bedingungen , next wenn bedingung nicht erfüllt
 # wenn bedingung nicht erfüllt next eachtimer
 # [REPEAT=00:02*04:10-06:30|RANDOM=20:00-21:00|TIME=17:00||CW=1,2,3]
 # prüfe Kalenderwoche / weekNumber ################################ weekNumber

            if ( $timertable{WEEKEND} ne "" ) {
                my $foundweekend = 0;
                if ( $we eq $timertable{WEEKEND} ) {
                    $foundweekend = 1;
                }
                next EACHTIMER if $foundweekend == 0;
            }

            if ( $timertable{WEEK} ne "" ) {
                my $even      = 0;
                my $odd       = 0;
                my $testweek  = $weekNumber / 2;
                my $testweek1 = int( $weekNumber / 2 );

                if ( $testweek == $testweek1 ) {
                    $timertable{WEEK} =~ s/even/$weekNumber/g;
                    $timertable{WEEK} =~ s/odd//g;
                }
                else {
                    $timertable{WEEK} =~ s/even//g;
                    $timertable{WEEK} =~ s/odd/$weekNumber/g;
                }

                $timertable{WEEK} =~ s/even//g;
                $timertable{WEEK} =~ s/,,/,/g;
                $timertable{WEEK} =~ s/,$//g;

                my @week = ( split( /,/, $timertable{WEEK} ) );
                my $foundweek = 0;
                foreach my $aktweek (@week) {
                    $foundweek++ if $aktweek == $weekNumber;
                }
                next EACHTIMER if $foundweek == 0;
            }

            # prüfe day / WDAY ################################
            if ( $timertable{WDAY} ne "" ) {
                my @weekkdays = ( split( /,/, $timertable{WDAY} ) );
                my $foundday = 0;
                foreach my $aktweekday (@weekkdays) {

                    $foundday++ if $wday == $aktweekday;
                }
                next EACHTIMER if $foundday == 0;
            }

            # prüfe monat / MONTH ##############################
            if ( $timertable{CMONTH} ne "" ) {
                my @month = ( split( /,/, $timertable{CMONTH} ) );
                my $foundmonth = 0;
                foreach my $testmonth (@month) {
                    $foundmonth++ if $testmonth == $showmonth;
                }
                next EACHTIMER if $foundmonth == 0;
            }

            # prüfe kalendertag / CDAY ################################ aktmday

            if ( $timertable{CDAY} ne "" ) {

                $aktmday =~ s/^0*(\d+)$/$1/;
                my $tomorrow = strftime( "%d", localtime time + 86400 );
                $tomorrow =~ s/^0*(\d+)$/$1/;
                if ( $tomorrow == 1 ) {
                    $timertable{CDAY} =~ s/lastday/$aktmday/g;
                }
                else {
                    $timertable{CDAY} =~ s/lastday//g;
                    $timertable{CDAY} =~ s/,,/,/g;
                    $timertable{CDAY} =~ s/,$//g;
                }

                my $even = 0;
                my $odd  = 0;

                my $testday  = $aktmday / 2;
                my $testday1 = int( $aktmday / 2 );

                if ( $testday == $testday1 ) {

                    $timertable{CDAY} =~ s/even/$aktmday/g;
                    $timertable{CDAY} =~ s/odd//g;
                }
                else {
                    $timertable{CDAY} =~ s/even//g;
                    $timertable{CDAY} =~ s/odd/$aktmday/g;

                }

                $timertable{CDAY} =~ s/even//g;
                $timertable{CDAY} =~ s/,,/,/g;
                $timertable{CDAY} =~ s/,$//g;

                my @cdays = ( split( /,/, $timertable{CDAY} ) );
                my $foundcday = 0;
                foreach my $aktcday (@cdays) {
                    $aktcday =~ s/^0*(\d+)$/$1/;
                    $foundcday++ if $aktmday == $aktcday;
                }

                next EACHTIMER if $foundcday == 0;
            }

            # prüfe datum / CDAY ################################ showdate
            if ( $timertable{DATE} ne "" ) {
                my @datum = ( split( /,/, $timertable{DATE} ) );
                my $founddate = 0;
                foreach my $aktdate (@datum) {
                    my @splitdate = ( split( /\./, $aktdate ) );
                    $splitdate[0] =~ s/\*/$aktmday/g;
                    $splitdate[1] =~ s/\*/$showmonth/g;
                    $splitdate[2] =~ s/\*/$aktyear/g;
                    $aktdate =
                      $splitdate[0] . "." . $splitdate[1] . "." . $splitdate[2];
                    $founddate++ if $aktdate eq $showdate;
                }
                next EACHTIMER if $founddate == 0;
            }

###### setze timer RANDOM
            if ( $timertable{RANDOM} ne "" ) {
                my $startrnd = substr( $timertable{RANDOM}, 0, 5 );
                my $endrnd   = substr( $timertable{RANDOM}, 6, 5 );
                my $newtimer =
                  MSwitch_Createrandom( $hash, $startrnd, $endrnd );
                $timertable{TIME} = $newtimer;
            }
###### setze timer TIMER
            if ( $timertable{TIME} ne "" ) {
                my $id = "ID" . $timertable{ID};
                $id = "" if $id eq "ID";
                my $timetoexecute = $timertable{TIME} . ":00";

                if (   substr( $timetoexecute, 0, 2 ) > 23
                    || substr( $timetoexecute, 3, 2 ) > 59 )
                {
                    $hash->{helper}{wrongtimespec} =
                      "ERROR: wrong timespec. $timetoexecute";
                    $hash->{helper}{wrongtimespec}{typ} = $i;
                    return;
                }

                my $timetoexecuteunix = timelocal(
                    substr( $timetoexecute, 6, 2 ),
                    substr( $timetoexecute, 3, 2 ),
                    substr( $timetoexecute, 0, 2 ),
                    $date,
                    $aktmonth,
                    $aktyear
                );

                my $number = $i;
                if ( $id ne "" && ( $i == 3 || $i == 4 ) ) {
                    $number = $number + 3;
                }
                if ( $i == 5 ) { $number = 9; }
                if ( $id ne "" && $number == 9 ) { $number = 10; }

                my $sectowait = $timetoexecuteunix - $aktuellezeit;
                next EACHTIMER
                  if $sectowait <= 0;    # abbruch wenn timer abgelaufen
                my $inhalt = $timetoexecuteunix . "-" . $number . $id;

                if ( $timertable{ARG} ne "" ) {

                    $hash->{helper}{timer}{$inhalt} =
                      "$inhalt" . "-" . $timertable{ARG};
                }
                else {

                    $hash->{helper}{timer}{$inhalt} = "$inhalt";
                }

                my $msg =
                  $Name . " " . $timetoexecuteunix . " " . $number . $id;
                push @nexttimer, $timetoexecuteunix;
                InternalTimer( $timetoexecuteunix, "MSwitch_Execute_Timer",
                    $msg );
            }

            if ( $timertable{REPEAT} ne "" ) {
                my @repeats = ( split( /\*/, $timertable{REPEAT} ) );
                my $sectoadd =
                  substr( $repeats[0], 0, 2 ) * 3600 +
                  substr( $repeats[0], 3, 2 ) * 60;
                my $starttime = ( split( /-/, $repeats[1] ) )[0];
                my $endtime   = ( split( /-/, $repeats[1] ) )[1];
                my $timecondtest = localtime;
                $timecondtest =~ s/\s+/ /g;
                my ( $tday, $tmonth, $tdate, $tn, $time1 ) =
                  split( / /, $timecondtest );
                if (   substr( $starttime, 0, 2 ) > 23
                    || substr( $starttime, 3, 2 ) > 59 )
                {
                    $hash->{helper}{wrongtimespec} =
                      "ERROR: wrong timespec. $starttime";
                    return;
                }
                if (   substr( $endtime, 0, 2 ) > 23
                    || substr( $endtime, 3, 2 ) > 59 )
                {
                    $hash->{helper}{wrongtimespec} =
                      "ERROR: wrong timespec. $endtime";
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

                my $id = "ID" . $timertable{ID};
                $id = "" if $id eq "ID";

                my $number = $i;
                if ( $id ne "" && ( $i == 3 || $i == 4 ) ) {
                    $number = $number + 3;
                }
                if ( $i == 5 ) { $number = 9; }
                if ( $id ne "" && $number == 9 ) { $number = 10; }

              EACHREPEAT: while ( $timecond1 < $timecond2 ) {
                    my $timestamp = substr( FmtDateTime($timecond1), 11, 5 );
                    if (   substr( $timestamp, 0, 2 ) > 23
                        || substr( $timestamp, 3, 2 ) > 59 )
                    {
                        $hash->{helper}{wrongtimespec} =
                          "ERROR: wrong timespec. $timestamp";
                        $hash->{helper}{wrongtimespec}{typ} = $i
                          ; # vorgesehen für zukünftige markierung fehlerhafter felder
                        return;
                    }

                    my $timetoexecute     = $timestamp . ":00";
                    my $timetoexecuteunix = timelocal(
                        substr( $timetoexecute, 6, 2 ),
                        substr( $timetoexecute, 3, 2 ),
                        substr( $timetoexecute, 0, 2 ),
                        $date,
                        $aktmonth,
                        $aktyear
                    );
                    my $sectowait = $timetoexecuteunix - $aktuellezeit;
                    $timecond1 = $timecond1 + $sectoadd;
                    next EACHREPEAT
                      if $sectowait <= 0;    # abbruch wenn timer abgelaufen
                    my $inhalt = $timetoexecuteunix . "-" . $number . $id;
                    if ( $timertable{ARG} ne "" ) {

                        $hash->{helper}{timer}{$inhalt} =
                          "$inhalt" . "-" . $timertable{ARG};
                    }
                    else {

                        $hash->{helper}{timer}{$inhalt} = "$inhalt";
                    }

                    my $msg =
                      $Name . " " . $timetoexecuteunix . " " . $number . $id;
                    push @nexttimer, $timetoexecuteunix;
                    InternalTimer( $timetoexecuteunix, "MSwitch_Execute_Timer",
                        $msg );
                }
            }
        }    # ENDE EACHTIMER
    }

    if ( $timerexist == 0 ) {

        MSwitch_CreateStatusReset( $Name, $hash, $date, $aktmonth, $aktyear );
		$showevents = MSwitch_checkselectedevent( $hash, "Next_Timer" );
        readingsSingleUpdate( $hash, "Next_Timer", "no_timer", $showevents  );
        return;
    }

    @nexttimer = sort @nexttimer;

    if ( defined $nexttimer[0] ) {
        my $nexttime = FmtDateTime( $nexttimer[0] );
        my @nt = split / /, $nexttime;
		$showevents = MSwitch_checkselectedevent( $hash, "Next_Timer" );
        readingsSingleUpdate( $hash, "Next_Timer", "no_timer_today", $showevents  ) if scalar(@nexttimer) == 0;
		$showevents = MSwitch_checkselectedevent( $hash, "Next_Timer" );
        readingsSingleUpdate( $hash, "Next_Timer", $nt[1], $showevents  ) if scalar(@nexttimer) > 0;

        my $timehash = $hash->{helper}{timer};
        my $timername = ( my @timerkeys = ( sort keys %{$timehash} ) )[0];

        my @arg = split( /-/, $hash->{helper}{timer}{$timername} );
		$showevents = MSwitch_checkselectedevent( $hash, "Next_Timer_ARG" );
        readingsSingleUpdate( $hash, "Next_Timer_ARG", $arg[2], $showevents  )
          if scalar(@nexttimer) > 0;

    }
    else {
		$showevents = MSwitch_checkselectedevent( $hash, "Next_Timer" );
        readingsSingleUpdate( $hash, "Next_Timer", "no_timer_today", $showevents  );
    }

    # berechne zeit bis 23,59 und setze timer auf create timer
    # nur ausführen wenn timer belegt
    my $newask = timelocal( '59', '59', '23', $date, $aktmonth, $aktyear );

    $newask = $newask + 2;
    my $newassktest = FmtDateTime($newask);
    my $msg         = $Name . " " . $newask . " " . 5;
    my $inhalt      = $newask . "-" . 5;
    $hash->{helper}{timer}{$newask} = "$inhalt";
    InternalTimer( $newask, "MSwitch_Execute_Timer", $msg );
    my @found_devices = devspec2array("TYPE=holiday");
    if ( @found_devices > 0 ) {
        $newask = $newask + 59;
        my $newassktest = FmtDateTime($newask);
        my $msg         = $Name . " " . $newask . " " . 51;
        my $inhalt      = $newask . "-" . 51;
        $hash->{helper}{timer}{$newask} = "$inhalt";
        InternalTimer( $newask, "MSwitch_Execute_Timer", $msg );
    }
    MSwitch_CreateStatusReset( $Name, $hash, $date, $aktmonth, $aktyear );
    return;
}

##############################

sub MSwitch_CreateStatusReset(@) {

    my ( $Name, $hash, $date, $aktmonth, $aktyear ) = @_;

    if (   AttrVal( $Name, "MSwitch_State_Counter", "off" ) eq "24_Hours"
        && AttrVal( $Name, "MSwitch_Mode", "Notify" ) ne "Notify" )
    {
        my $newask = timelocal( '59', '59', '23', $date, $aktmonth, $aktyear );
        $newask = $newask + 4;
        my $newassktest = FmtDateTime($newask);
        my $inhalt      = $newask . "-" . 52;
        $hash->{helper}{timer}{$newask} = "$inhalt";
        InternalTimer( $newask, "MSwitch_DeleteStatusReset", $hash );
    }
    return;
}
#############################
sub MSwitch_DeleteStatusReset($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
    my $showevents = AttrVal( $Name, "MSwitch_generate_Events", 0 );
	
	$showevents = MSwitch_checkselectedevent( $hash, "off_time" );
    readingsSingleUpdate( $hash, "off_time",           0,        $showevents );
	$showevents = MSwitch_checkselectedevent( $hash, "on_time" );
    readingsSingleUpdate( $hash, "on_time",            0,        $showevents );
	$showevents = MSwitch_checkselectedevent( $hash, "last_ON_OFF_switch" );
    readingsSingleUpdate( $hash, "last_ON_OFF_switch", int time, $showevents );
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
    if ( AttrVal( $Name, 'MSwitch_Debug', '0' ) ne "0" ) { $showevents = 1 }
    my $hash = $defs{$Name};
    return "" if ( IsDisabled($Name) );

    MSwitch_LOG( $Name, 6,"\n ".localtime."\n---------- Moduleinstieg > MSwitch_Execute_Time ----------\n- timecondition: $timecond \n- parameter: $param   ");

    if ( ReadingsVal( $Name, '.V_Check', $vupdate ) ne $vupdate ) {
        my $ver = ReadingsVal( $Name, '.V_Check', '' );
        MSwitch_LOG( $Name, 1,
"$Name-> Timer blockiert, NOTIFYDEV deaktiviert - Versionskonflikt L:"
              . __LINE__ );
        $hash->{NOTIFYDEV} = 'no_trigger';
        MSwitch_Clear_timer($hash);
        return;
    }

    if ( !defined $hash || !defined $Name || $hash eq "" || $Name eq "" ) {

       MSwitch_LOG( "MSwitch_Error", 5,"##################################"  );
       MSwitch_LOG( "MSwitch_Error", 5,"MSwitch_Error in exec_timer " );
       MSwitch_LOG( "MSwitch_Error", 5,"eingehende daten: $input " );
       MSwitch_LOG( "MSwitch_Error", 5,"eingehender Hash: $hash " );
       MSwitch_LOG( "MSwitch_Error", 5,"eingehender Name: $Name ");
       MSwitch_LOG( "MSwitch_Error", 5,"Routine abgebrochen");
       MSwitch_LOG( "MSwitch_Error", 5,"##################################"  );
	 
	   MSwitch_LOG( "MSwitch_Error", 6,"##################################"  );
       MSwitch_LOG( "MSwitch_Error", 6,"MSwitch_Error in exec_timer " );
       MSwitch_LOG( "MSwitch_Error", 6,"eingehende daten: $input " );
       MSwitch_LOG( "MSwitch_Error", 6,"eingehender Hash: $hash " );
       MSwitch_LOG( "MSwitch_Error", 6,"eingehender Name: $Name ");
       MSwitch_LOG( "MSwitch_Error", 6,"Routine abgebrochen");
       MSwitch_LOG( "MSwitch_Error", 6,"##################################"  );
       return;
    }

    MSwitch_LOG( $Name, 6,"---- ausführung Timer $timecond, $param L:" . __LINE__ );

	my @arg ;

		if (!defined $hash->{helper}{timer}{ $timecond . "-" . $param })
		{
			
		#MSwitch_LOG( $Name, 0,"$Name -> evtl error in exec timer" . __LINE__ );	
		}
		else
		{
			@arg = split( /-/, $hash->{helper}{timer}{ $timecond . "-" . $param } );
		}

    MSwitch_LOG( $Name, 6,"-> ausführung Timer arg $arg[2] L:" . __LINE__ ) if (defined $arg[2]);
    $hash->{helper}{timerarag} = $arg[2];

    if ( defined $hash->{helper}{wrongtimespec}
        and $hash->{helper}{wrongtimespec} ne "" )
    {
        my $ret = $hash->{helper}{wrongtimespec};
        $ret .= " - Timer werden nicht ausgefuehrt ";
        return;
    }
    my @string = split( /ID/, $param );

    $param = $string[0];
    my $execid = 0;
    $execid = $string[1] if ( $string[1] );

    $hash->{MSwitch_Eventsave} = 'unsaved';
    if ( ReadingsVal( $Name, '.V_Check', $vupdate ) ne $vupdate ) {
        my $ver = ReadingsVal( $Name, '.V_Check', '' );
        MSwitch_LOG( $Name, 1,
                $Name
              . ' Versionskonflikt, aktion abgebrochen !  erwartet:'
              . $vupdate
              . ' vorhanden:'
              . $ver );
        return;
    }
	
	
	
	
	
#$hash->{MSwitch_IncommingHandle} = 'fromtimer' if AttrVal( $Name, 'MSwitch_Mode', 'Notify' ) ne "Dummy";
# from
readingsSingleUpdate( $hash, "last_device_trigger", "timer" , $showevents ) if AttrVal( $Name, 'MSwitch_Mode', 'Notify' ) ne "Dummy";






    if ( $param eq '5' ) {
        MSwitch_Createtimer($hash);
        return;
    }

    if ( ReadingsVal( $Name, 'timer', 'on' ) eq "off" ) {
        MSwitch_LOG( $Name, 6,
            "ausführung Timer abgebrochen ( deaktiviert ) L:" . __LINE__ );
        return;
    }







    if ( AttrVal( $Name, 'MSwitch_RandomNumber', '' ) ne '' ) {
        MSwitch_Createnumber1($hash);
    }

    my $extime = POSIX::strftime( "%H:%M", localtime );

	$showevents = MSwitch_checkselectedevent( $hash, "EVENT" );
	readingsSingleUpdate( $hash, "EVENT",$Name . ":execute_timer_P" . $param . ":" . $extime, $showevents );

	$showevents = MSwitch_checkselectedevent( $hash, "EVTFULL" );
	readingsSingleUpdate( $hash, "EVTFULL",$Name . ":execute_timer_P" . $param . ":" . $extime, $showevents );

	$showevents = MSwitch_checkselectedevent( $hash, "EVTPART1" );
	readingsSingleUpdate( $hash, "EVTPART1", $Name, $showevents );

	$showevents = MSwitch_checkselectedevent( $hash, "EVTPART2" );
	readingsSingleUpdate( $hash, "EVTPART2", "execute_timer_P" . $param, $showevents );

	$showevents = MSwitch_checkselectedevent( $hash, "EVTPART3" );
	readingsSingleUpdate( $hash, "EVTPART3", $extime, $showevents );

    $hash->{helper}{evtparts}{evtfull} =
      $Name . ":execute_timer_P" . $param . ":" . $extime;
    $hash->{helper}{evtparts}{event} =
      $Name . ":execute_timer_P" . $param . ":" . $extime;
    $hash->{helper}{evtparts}{evtpart1} = $Name;
    $hash->{helper}{evtparts}{evtpart2} = "execute_timer_P" . $param;
    $hash->{helper}{evtparts}{evtpart3} = $extime;
	
	
    if ( AttrVal( $Name, 'MSwitch_Condition_Time', "0" ) eq '1' )
	{
		my $triggercondition = MSwitch_Load_Tcond($hash);
        if ( $triggercondition ne '' ) {

            my $ret = MSwitch_checkcondition( $triggercondition, $Name,
                $hash->{helper}{evtparts}{evtfull} );
            if ( $ret eq 'false' ) {
                return;
            }
        }
    }

    # ############ timerhash anpassen , nächstes timerevent melden
    my $settime  = int(time);
    my $timehash = $hash->{helper}{timer};
    my @nexttimer;

    foreach my $a ( sort keys %{$timehash} ) {
        my @string  = split( /-/,  $hash->{helper}{timer}{$a} );
        my @string1 = split( /ID/, $string[1] );
        my $number  = $string1[0];
        my $id      = $string1[1];

        if ( $string[0] <= $settime ) {

            delete( $hash->{helper}{timer}{$a} );
        }
        else {
            push @nexttimer, $hash->{helper}{timer}{$a};
        }

    }
    @nexttimer = sort @nexttimer;
	my @nt;
	

	
    if ( exists $nexttimer[0] ) {
	MSwitch_LOG( $Name, 6,"-> next timer  : $nexttimer[0]\n L:" . __LINE__ );
        my @aktset   = split( /-/, $nexttimer[0] );

		if ($aktset[1] eq "5" )
		{
		$showevents = MSwitch_checkselectedevent( $hash, "Next_Timer" );
        readingsSingleUpdate( $hash, "Next_Timer", "no_timer_today", $showevents );	
		}
		else
		{
        my $nexttime = FmtDateTime( $aktset[0] );
        @nt       = split / /, $nexttime;
		$showevents = MSwitch_checkselectedevent( $hash, "Next_Timer" );
        readingsSingleUpdate( $hash, "Next_Timer", $nt[1], $showevents );
		}
    }
    else {
		$showevents = MSwitch_checkselectedevent( $hash, "Next_Timer" );
        readingsSingleUpdate( $hash, "Next_Timer", "no_timer_today", $showevents );
    }
    ##############################################################


$hash->{helper}{trigwrite}="noset";






    if ( $param eq '1' ) {
        my $cs = "set $Name on";
        MSwitch_LOG( $Name, 6,"-> finale Befehlsausführung auf Fhemebene:\n$cs\n L:" . __LINE__ );
        my $errors = AnalyzeCommandChain( undef, $cs );
        if ( defined($errors) ) {
            MSwitch_LOG( $Name, 1,
"$Name MSwitch_Execute_Timer: Fehler bei Befehlsausfuehrung ERROR $Name: $errors "
                  . __LINE__ );
        }
        #return;
    }
    if ( $param eq '2' ) {
        my $cs = "set $Name off";
        MSwitch_LOG( $Name, 6,
            "-> finale Befehlsausführung auf Fhemebene:\n$cs\n L:" . __LINE__ );




		
        my $errors = AnalyzeCommandChain( undef, $cs );
        if ( defined($errors) ) {
            MSwitch_LOG( $Name, 1,
"$Name MSwitch_Execute_Timer: Fehler bei Befehlsausfuehrung ERROR $Name: $errors "
                  . __LINE__ );
        }
        #return;
    }
	
	$showevents = MSwitch_checkselectedevent( $hash, "last_cmd" );
	#MSwitch_LOG( $Name, 6,"-> load next nt : $nt[2]\n L:" . __LINE__ );

    if ( $param eq '3' ) {
        readingsSingleUpdate( $hash, "last_cmd", "cmd_1", $showevents );
        MSwitch_Exec_Notif( $hash, 'on', 'nocheck', '', 0 );

    }
    if ( $param eq '4' ) {
        readingsSingleUpdate( $hash, "last_cmd", "cmd_2", $showevents );
        MSwitch_Exec_Notif( $hash, 'off', 'nocheck', '', 0 );
		
    }
    if ( $param eq '6' ) {
        readingsSingleUpdate( $hash, "last_cmd", "cmd_1", $showevents );
        MSwitch_Exec_Notif( $hash, 'on', 'nocheck', '', $execid );

    }
    if ( $param eq '7' ) {
        readingsSingleUpdate( $hash, "last_cmd", "cmd_2 ", $showevents );
        MSwitch_Exec_Notif( $hash, 'off', 'nocheck', '', $execid );

    }
	
    if ( $param eq '9' ) {
        MSwitch_Exec_Notif( $hash, 'on',  'nocheck', '', 0 );
        MSwitch_Exec_Notif( $hash, 'off', 'nocheck', '', 0 );
		
    }
    if ( $param eq '10' ) {
        MSwitch_Exec_Notif( $hash, 'on',  'nocheck', '', $execid );
        MSwitch_Exec_Notif( $hash, 'off', 'nocheck', '', $execid );
		
    }
	
	
	readingsSingleUpdate( $hash, "Next_Timer_ARG", "noArg", $showevents );
	$showevents = MSwitch_checkselectedevent( $hash, "Next_Timer_ARG" );
	if ( exists $nexttimer[0] ) 
	{
		
		my @aktset   = split( /-/, $nexttimer[0] );
		my $select = $aktset[0]."-".$aktset[1];

my @arg;


		if (!defined $hash->{helper}{timer}{ $select } )
		{
			
		#MSwitch_LOG( $Name, 0,"$Name -> evtl error in exec timer" . __LINE__ );	
		}
		else{
			
			@arg = split( /-/, $hash->{helper}{timer}{ $select } );
		}

			
			
			
			if (!defined $arg[2])
			{
				$arg[2] = "noArg";
			}
			
			
			if ( $arg[2] eq "")
			{
				$arg[2] = "noArg";
			}
			
			readingsSingleUpdate( $hash, "Next_Timer_ARG", $arg[2], $showevents  );
			
			
	}
	 else 
	{
        readingsSingleUpdate( $hash, "Next_Timer_ARG", "noArg", $showevents );
    }
	
	
	
    return;$hash->{helper}{trigwrite}="set";
}
####################
sub MSwitch_ChangeCode($$) {
    my ( $hash, $option ) = @_;
    my $Name = $hash->{NAME};
    my $x    = 0;               # exit secure
    while ( $option =~ m/(.*)\{(sunset|sunrise)(.*)\}(.*)/ ) {
        $x++;                   # exit secure
        last if $x > 20;        # exit secure
        if ( defined $2 ) {
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
    my $Name = $hash->{NAME};
    my $showevents = AttrVal( $Name, "MSwitch_generate_Events", 0 );
    if ( AttrVal( $Name, 'MSwitch_Debug', '0' ) ne "0" ) { $showevents = 1 }
    my @olddevices = split( /,/, ReadingsVal( $Name, '.Device_Affected', '' ) );
    my $count = 1;
  LOOP7: foreach (@olddevices) {
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
	my @olddevicesset = MSwitch_Load_Details($hash);
	my @newdevice;
    my @newdevicesset;
    my $count = 0;
  LOOP8: foreach (@olddevices) {

        if ( $device eq $_ ) {
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
  LOOP9: foreach (@newdevice) {
        my ( $devicename, $devicecmd ) = split( /-AbsCmd/, $_ );
        if ( $devicemaster eq $devicename ) {
            my $newname = $devicename . '-AbsCmd' . $count;
            $count++;
            push( @newdevice1, $newname );
            next LOOP9;
        }
        push( @newdevice1, $_ );
    }
    $count = 1;
    my @newdevicesset1;
  LOOP10: foreach (@newdevicesset) {
        my ( $name,       @comands )   = split( /#\[NF\]/, $_ );
        my ( $devicename, $devicecmd ) = split( /-AbsCmd/, $name );
        if ( $devicemaster eq $devicename ) {
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
	
	delete $data{MSwitch}{$Name}{Device_Affected_Details};
	delete $data{MSwitch}{$Name}{TCond};
	MSwitch_Save_Details($hash,$newaffecteddet);
	
    readingsBeginUpdate($hash);
    readingsBulkUpdate( $hash, ".Device_Affected",         $newaffected );
    readingsEndUpdate( $hash, 0 );
	MSwitch_assoziation($hash);
    return;
}
###################################
sub MSwitch_Debug($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
    my $debug1 = ReadingsVal( $Name, '.Device_Affected',         0 );
	my $debug2=MSwitch_Load_Details($hash);
    my $debug3 = ReadingsVal( $Name, '.Device_Events',           0 );
    $debug2 =~ s/:/ /ig;
    $debug3 =~ s/,/, /ig;
   return;
}
###################################
sub MSwitch_Delete_Delay($$) {
    my ( $hash, $device ) = @_;
    my $Name     = $hash->{NAME};
    my $timehash = $hash->{helper}{delays};
    if ( $device eq 'all' ) {
        foreach my $a ( keys %{$timehash} ) {
            my $inhalt = $hash->{helper}{delays}{$a};
            RemoveInternalTimer($a);
            RemoveInternalTimer($inhalt);
            delete( $hash->{helper}{delays}{$a} );
        }
    }
    else {
        foreach my $a ( keys %{$timehash} ) {
            my $pos = index( $a, "$device", 0 );
            if ( $pos != -1 ) {
                RemoveInternalTimer($a);
                my $inhalt = $hash->{helper}{delays}{$a};
                RemoveInternalTimer($a);
                RemoveInternalTimer($inhalt);
                delete( $hash->{helper}{delays}{$a} );
            }
        }

        foreach my $countdown ( keys %{ $hash->{helper}{countdown} } ) {
            delete( $hash->{helper}{countdown}{$countdown} );
            my $format =
              AttrVal( $Name, 'MSwitch_Format_Lastdelay', "HH:MM:SS" );
            $format =~ s/HH/00/g;
            $format =~ s/MM/00/g;
            $format =~ s/SS/00/g;
            $format =~ s/ss/0/g;
			
			my $showevents = MSwitch_checkselectedevent( $hash, $countdown );
            readingsSingleUpdate( $hash, $countdown, $format, $showevents );

        }
        delete( $hash->{helper}{delaydetails} );
    }
    return;
}

###################################
sub MSwitch_Delete_specific_Delay($$$) {
    my ( $hash, $name, $indikator ) = @_;
    my $timehash = $hash->{helper}{delays};
    my $expertmode = AttrVal( $name, 'MSwitch_Expert', "0" );
	my $showevents;
    if ( $indikator =~ m/.*:.*:.*/ ) {
        my $delaydindikatorhash = $hash->{helper}{delaydetails};
        foreach my $a ( sort keys %{$delaydindikatorhash} ) {
            my $checkname    = $hash->{helper}{delaydetails}{$a}{Indikator};
            my $checkcounter = $hash->{helper}{delaydetails}{$a}{name};
            if ( $checkname eq $indikator ) {
                my $delete = $a . "-" . $name;
                RemoveInternalTimer($delete);
                delete( $hash->{helper}{delaydetails}{$a} );

                if ( $expertmode eq '1' ) {
                    $hash->{helper}{countdown}{$checkcounter} = 0;
                    my $format =
                      AttrVal( $name, 'MSwitch_Format_Lastdelay', "HH:MM:SS" );
                    $format =~ s/HH/00/g;
                    $format =~ s/MM/00/g;
                    $format =~ s/SS/00/g;
                    $format =~ s/ss/0/g;
					
					$showevents = MSwitch_checkselectedevent( $hash, $checkcounter );
                    readingsSingleUpdate( $hash, $checkcounter, $format, $showevents );
                }
            }
        }
    }
    else {

        my $delaydindikatorhash = $hash->{helper}{delaydetails};
        foreach my $a ( sort keys %{$delaydindikatorhash} ) {
            my $checkname = $hash->{helper}{delaydetails}{$a}{name};
            if ( $checkname eq $indikator ) {
                my $delete = $a . "-" . $name;
                RemoveInternalTimer($delete);
                delete( $hash->{helper}{delaydetails}{$a} );

                if ( $expertmode eq '1' ) {
                    $hash->{helper}{countdown}{$indikator} = 0;
                    my $format =
                      AttrVal( $name, 'MSwitch_Format_Lastdelay', "HH:MM:SS" );
                    $format =~ s/HH/00/g;
                    $format =~ s/MM/00/g;
                    $format =~ s/SS/00/g;
                    $format =~ s/ss/0/g;
					
					$showevents = MSwitch_checkselectedevent( $hash, $indikator );
                    readingsSingleUpdate( $hash, $indikator, $format, $showevents );
                }
            }
        }
    }

    return;
}
##################################
# Eventsimulation
sub MSwitch_Check_Event($$) {
    my ( $hash, $eventin ) = @_;
    my $Name = $hash->{NAME};

    if ( !defined $eventin ) { $eventin = ""; }

    $eventin =~ s/~/ /g;
    my $dev_hash = "";

    if ( $eventin ne $hash ) {
        if ( ReadingsVal( $Name, '.Trigger_device', '' ) eq "all_events" ) {
            my @eventin = split( /:/, $eventin, 3 );
            if ( !defined $eventin[0] ) { $eventin[0] = ""; }
            if ( !defined $eventin[1] ) { $eventin[1] = ""; }
            if ( !defined $eventin[2] ) { $eventin[2] = ""; }

            if ( $eventin[0] eq "MSwitch_Self" ) {
                $hash->{helper}{testevent_device} = $eventin[0];
                $hash->{helper}{testevent_event} =
                  $eventin[1] . ":" . $eventin[2];
                $dev_hash = $hash;
            }
            else {
                $dev_hash = $defs{ $eventin[0] };
                $hash->{helper}{testevent_device} = $eventin[0];
                $hash->{helper}{testevent_event} =
                  $eventin[1] . ":" . $eventin[2];
            }
        }
        else {
            my @eventin = split( /:/, $eventin, 3 );

            if ( !defined $eventin[0] ) { $eventin[0] = ""; }
            if ( !defined $eventin[1] ) { $eventin[1] = ""; }
            if ( !defined $eventin[2] ) { $eventin[2] = ""; }

            if ( $eventin[0] ne "MSwitch_Self" ) {
                $dev_hash =
                  $defs{ ReadingsVal( $Name, '.Trigger_device', '' ) };
                $hash->{helper}{testevent_device} =
                  ReadingsVal( $Name, '.Trigger_device', '' );
                $hash->{helper}{testevent_event} =
                  $eventin[0] . ":" . $eventin[1];
            }
            else {
                $dev_hash = $hash;
                $hash->{helper}{testevent_device} = "MSwitch_Self";
                $hash->{helper}{testevent_event} =
                  $eventin[1] . ":" . $eventin[2];
            }
        }
    }

    if ( $eventin eq $hash ) {
        my $logout = $hash->{helper}{writelog};
        my $triggerdevice =
          ReadingsVal( $Name, '.Trigger_device', 'no_trigger' );
        if ( ReadingsVal( $Name, '.Trigger_device', '' ) eq "all_events" ) {
            $dev_hash                         = $hash;
            $hash->{helper}{testevent_device} = 'Logfile';
            $hash->{helper}{testevent_event}  = "writelog:" . $logout;
        }
        elsif ( ReadingsVal( $Name, '.Trigger_device', '' ) eq "Logfile" ) {
            $dev_hash                         = $hash;
            $hash->{helper}{testevent_device} = 'Logfile';
            $hash->{helper}{testevent_event}  = "writelog:" . $logout;
        }
        else {
            $dev_hash = $defs{ ReadingsVal( $Name, '.Trigger_device', '' ) };
            $hash->{helper}{testevent_device} =
              ReadingsVal( $Name, '.Trigger_device', '' );
            $hash->{helper}{testevent_event} = "writelog:" . $logout;
        }
    }

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
  LOOP30: foreach (@affected) {
        @affname = split( /-/, $_ );
        $saveaffected{ $affname[0] } = 'on';
    }
    foreach my $a ( keys %saveaffected ) {
        $devices = $devices . $a . ' ';
    }
    chop($devices);
    return $devices;
}

#############################
sub MSwitch_checktrigger_new(@) {
    my ( $own_hash, $triggerfield, $zweig ) = @_;

    my $device       = $own_hash->{helper}{evtparts}{device};
    my $eventstellen = $own_hash->{helper}{evtparts}{parts};
    my $ownName      = $own_hash->{NAME};
    my $eventcopy    = $own_hash->{helper}{evtparts}{evtfull};

    return if !defined $eventcopy;

	MSwitch_LOG( $ownName, 6, "-> checktrigger $triggerfield, $zweig  L:" . __LINE__ );

	if ( $triggerfield =~ m/\[(.*)\:(.*)\]/ ) {
        $triggerfield = MSwitch_check_setmagic_i( $own_hash, $triggerfield );
    }

    my @eventsplit =
      split( /:/, $eventcopy, $own_hash->{helper}{evtparts}{parts} );
    my @triggerarray = split( /:/, $triggerfield );
    if ( @triggerarray == 1 && $triggerarray[0] =~ m/^[A-Z]+$/ ) {
        unshift( @triggerarray, "global" );
        push( @triggerarray, 'undef' );

        $triggerfield = join ":", @triggerarray;

    }

    if ( @triggerarray == 2 ) {

        # Systemumstellung Trigger 2stellig auf trigger 3stellig
        unshift( @triggerarray, $own_hash->{helper}{evtparts}{device} );
        $triggerfield = join ":", @triggerarray;
    }

    my $triggeron     = ReadingsVal( $ownName, '.Trigger_on',      '' );
    my $triggeroff    = ReadingsVal( $ownName, '.Trigger_off',     '' );
    my $triggercmdon  = ReadingsVal( $ownName, '.Trigger_cmd_on',  '' );
    my $triggercmdoff = ReadingsVal( $ownName, '.Trigger_cmd_off', '' );
    my $sequenzstate = ReadingsVal( $ownName, "SEQUENCE", '' );
    my $answer = "";

    # trigger ist sequenzmatch
    if ( $triggerfield eq "match_sequenz" ) {
        if ( $sequenzstate eq "match" ) {
            return $zweig;
        }
    }

########## teste zusatzbedingung #################
    # trigger enthält bedingung
    if ( $triggerfield =~ m/(.*)\[(.*)(\[.*?\])/ ) {
        my $begin     = $1;
        my $start     = $2;
        my $setmagic  = $3;
        my $workmagic = $3;
        $workmagic =~ s/\$SELF/$ownName/;
        $workmagic =~ s/.$//;
        $workmagic =~ s/^.//;
        my ( $device, $reading ) = split( /:/, $workmagic );
        my $magicinhalt = ReadingsVal( $device, $reading, 0 );
        $triggerfield = $begin . "[" . $start . $magicinhalt . "]";
    }

    if ( $triggerfield =~ m/(.*)\[(.*)\]/ ) {

        my $eventpart      = $1;
        my $eventbedingung = $2;
        $triggerfield = $eventpart;

        @triggerarray = split( /:/, $triggerfield );

        my $position;
        for ( my $i = 0 ; $i < 3 ; $i++ ) {

            if ( $triggerfield =~ m/^.*$/ ) {
                $position = $i;
            }
        }
        my $staris = $eventsplit[$position];
        my $newcondition = $eventbedingung;

        if ( $staris =~ m/^-?\d+(?:[\.,]\d+)?$/ ) {
            $newcondition =~ s/\*/$staris/g;
        }
        else {
            $newcondition =~ s/\*/"$staris"/g;

            # teste auf string/zahl vergleich
            my $testccondition = $newcondition;
            $testccondition =~ s/ //g;
            if ( $testccondition =~ m/(".*"(>|<)\d+)/ ) {
                return 'undef';
            }
        }

        my $ret = MSwitch_checkcondition( $newcondition, $ownName, $eventcopy );
		
		if ($ret ne "true"){
		MSwitch_LOG( $ownName, 6, "-> checktrigger answer = nicht wahr  L:" . __LINE__ );	
		MSwitch_LOG( $ownName, 6, "-> event: $eventcopy - condition: $newcondition  L:" . __LINE__ );	
        return 'undef' ;
		
		}
	
        $answer = "wahr";
    }

    # trigger enthält perl
    if ( $triggerfield =~ m/(.*?)\{(.*)\}/ ) {
        my $SELF = $ownName;
        my $exec = "\$triggerfield = " . $2;
        {
            no warnings;
            eval($exec);
        }
        $triggerfield = $1 . $triggerfield . $3;
    }

    if ( $triggerfield eq "*" ) {
        $triggerfield = ".*:.*:.*";
    }

################

    if ( $eventcopy =~ m/^$triggerfield/ ) 
	{
        $answer = "wahr";
		MSwitch_LOG( $ownName, 6, "-> checktrigger answer = wahr  L:" . __LINE__ );	
		MSwitch_LOG( $ownName, 6, "-> event: $eventcopy - triggerfeld: $triggerfield  L:" . __LINE__ );			
    }

    if (   $zweig eq 'on'
        && $answer eq 'wahr'
        && $eventcopy ne $triggercmdoff
        && $eventcopy ne $triggercmdon
        && $eventcopy ne $triggeroff )
    {
        return 'on';
    }

    if (   $zweig eq 'off'
        && $answer eq 'wahr'
        && $eventcopy ne $triggercmdoff
        && $eventcopy ne $triggercmdon
        && $eventcopy ne $triggeron )
    {
        return 'off';
    }

    if ( $zweig eq 'offonly' && $answer eq 'wahr' ) {
        return 'offonly';
    }

    if ( $zweig eq 'ononly' && $answer eq 'wahr' ) {
        return 'ononly';
    }
    return 'undef';
}
###############################
sub MSwitch_VersionUpdate($) {
    my ($hash)  = @_;
    my $Name    = $hash->{NAME};
    my $message = "";
    $message .= "MSwitch-Strukturupdate -> Autoupdate fuer MSwitch_Device $Name  \n";
	my $test = ReadingsVal( $Name, '.Device_Affected_Details', 'no_device' );

	if ($test ne "no_device"){
	$message.="     -> Anpassung der .Device_Affected_Details_new fuer $Name \n";
		
	$test =~ s/#\[dp\]/:/g;
	$test =~ s/#\[pt\]/./g;
    $test =~ s/#\[ti\]/~/g;
    $test =~ s/#\[se\]/;/g;
    $test =~ s/#\[dp\]/:/g;
    $test =~ s/\(DAYS\)/|/g;
    $test =~ s/#\[ko\]/,/g;     #neu
    $test =~ s/#\[bs\]/\\/g;    #neu
		
	delete $data{MSwitch}{$Name}{Device_Affected_Details};
	delete $data{MSwitch}{$Name}{TCond};
	#MSwitch_LOG( "test", 0,"ALL MSHEX ".__LINE__ );
	readingsSingleUpdate( $hash, ".Device_Affected_Details_new", MSwitch_Hex($test), 1 );	
	fhem("deletereading $Name .Device_Affected_Details");
	}

	my $test1 = ReadingsVal( $Name, '.sysconf', 'no_device' );

	if ($test1 ne "no_device"){
	$message.="     -> Anpassung der .sysconf fuer $Name \n";
	    $test1 =~ s/#\[tr\]/[tr]/g;
        $test1 =~ s/#\[wa\]/|/g;
        $test1 =~ s/#\[sp\]/ /g;
        $test1 =~ s/#\[se\]/;/g;
        $test1 =~ s/#\[bs\]/\\/g;
        $test1 =~ s/#\[dp\]/:/g;
        $test1 =~ s/#\[st\]/'/g;
        $test1 =~ s/#\[dst\]/\"/g;
        $test1 =~ s/#\[tab\]/    /g;
        $test1 =~ s/#\[ko\]/,/g;
        $test1 =~ s/\[tr\]/#[tr]/g;
#MSwitch_LOG( "test", 0,"ALL MSHEX ".__LINE__ );
	readingsSingleUpdate( $hash, ".sysconf", MSwitch_Hex($test1), 1 );
	fhem("deletereading $Name .Device_Affected_Details");
}

#########################################

	my $test2 = ReadingsVal( $Name, '.Trigger_condition', '' );
	if ($test2 ne "no_device"){
	$message.="     -> Anpassung der .Trigger_condition fuer $Name \n";
	$test2 =~ s/#\[sp\]/ /g;				
	$test2 =~ s/#\[dp\]/:/g; 
    $test2 =~ s/#\[pt\]/./g;
    $test2 =~ s/#\[ti\]/~/g;
	$test2 =~ s/#\[pt\]/./g;	
	#MSwitch_LOG( "test", 0,"ALL MSHEX ".__LINE__ );
	readingsSingleUpdate( $hash, ".Trigger_condition", MSwitch_Hex($test2), 1 ); 
	
	}
	$message.="     -> Loesche DEF fuer $Name \n";
	delete $hash->{DEF};

	$message.="     -> Anpassung der .V_Check fuer $Name \n";
	readingsSingleUpdate( $hash, ".V_Check", $vupdate, 0 );
		
	$message.="     -> Neuinitialisierung fuer $Name \n";
	MSwitch_LoadHelper($hash);
		
	$message.="     -> Loesche .Device_Events fuer $Name \n";
	readingsSingleUpdate( $hash, ".Device_Events", "no_trigger", 0 );
	 
	
	my @found_devices = devspec2array("TYPE=MSwitch:FILTER=.msconfig=1");
    if ( @found_devices > 0){
		fhem("delete TYPE=MSwitch:FILTER=.msconfig=1");
		$message.="     -> Loesche Configdevice  $found_devices[0]\n";
		 }
    return;
}

########################################
sub MSwitch_restore_this($$) {

    # arg backupfile oder configfile
    my ( $hash, $arg ) = @_;
    my $Name    = $hash->{NAME};
    my $Zeilen  = ("");
    my $aktname = $hash->{NAME};
   
	my $pfad =  AttrVal( 'global', 'backupdir', $restoredirn ) ;
	$pfad.="/MSwitch/";
	my $ret = "MSwitch $Name restored.\nPlease refresh device.";
	$Zeilen = $data{MSwitch}{$Name}{backupdatei};

 if ( $arg eq "configdevice" ) 
 {
	$aktname = "MSwitch_Config";
    my $error1 = AnalyzeCommand( $hash, "define " . $aktname . " mswitch" );
    if ( defined($error1) ) {
                my $encoded = urlEncode($error1);
                FW_directNotify( "FILTER=$Name", "#FHEMWEB:WEB",
                    "information('!!! Fehler aufgetreten: $encoded')", "" );
                
        }

	 
	if ( open( HELP, "<./$conffile" ) ) 
	{
    while (<HELP>) {
        $Zeilen = $Zeilen . $_;
    }
    close(HELP);
	}
	$ret = "MSwitch_Configdefice $Name wurde installiert.";
	}


    if ( $arg eq "configfile" ) {
        $Zeilen = $data{MSwitch}{$Name}{backupdatei};
        $data{MSwitch}{$Name}{backupdatei} = "";
    }



    if ( $arg eq "backupfile" ) {
        open( BACKUPDATEI,
            "<" . $pfad . "MSwitch_Device_" . $Name . ".txt" )
          || return "no Backupfile found!";
        while (<BACKUPDATEI>) {
            $Zeilen = $Zeilen . $_;
        }
        close(BACKUPDATEI);
    }
	

	
	if ( $arg eq "experimental" ) {
        open( BACKUPDATEI,
            "<" . $pfad . "MSwitch_Experimental_" . $Name . ".txt" )
          || return "no Backupfile found!";
        while (<BACKUPDATEI>) {
            $Zeilen = $Zeilen . $_;
        }
        close(BACKUPDATEI);
		
		unlink($pfad."MSwitch_Experimental_" . $Name . ".txt");
    }
	
	
	if ( $arg eq "undo" ) {

	    my $Zeilen = $data{MSwitch}{$hash}{undo};
		delete $data{MSwitch}{$hash}{undotime};
		delete $data{MSwitch}{$hash}{undo};
	
	}
	
	
	$Zeilen=MSwitch_Asc($Zeilen);
    my $backupdatei = $Zeilen;
    my @found = split( /\n/, $backupdatei );

    foreach (@found) {
        if ( $_ =~ m/#A (.*) -> (.*)/ )    # setattr
        {
            my $inhalt  = $2;
            my $aktattr = $1;
            $inhalt =~ s/#\[nl\]/\n/g;
            $inhalt =~ s/;/;;/g;
            my $cs = "attr $aktname $aktattr $inhalt";
            my $errors = AnalyzeCommandChain( undef, $cs );
            if ( defined($errors) ) {
                $data{MSwitch}{runningbackuperror} .= "\n - $errors";
            }
        }



if ( $_ =~ m/#UUID -> (.*)/ )    # setreading
        {
            my $aktattr = $1;
			#MSwitch_LOG( "test", 0,"setze uuid n:$aktattr / I:".__LINE__ );
			$defs{$aktname}{FUUID} = $aktattr;  
		} 
			

        if ( $_ =~ m/#S (.*?) -> (.*)/ )    # setreading
        {
            next if $1 eq "last_exec_cmd";
            next if $1 eq "EVTPART1";
            next if $1 eq "EVTPART2";
            next if $1 eq "EVTPART3";
            next if $1 eq "EVENT";
            next if $1 eq "last_activation_by";
            next if $1 eq "waiting";
            next if $1 eq "Next_Timer";
            next if $1 eq "last_event";

            if ( $2 eq 'undef' || $2 eq '' || $2 eq ' ' ) 
			{
            }
            else {
                my $Zeilen1 = $2;
                my $reading = $1;
                $Zeilen1 =~ s/#\[nl\]/\n/g;
				
				if ($reading eq ".Device_Affected_Details_new" || $reading eq ".sysconf" || $reading eq ".Trigger_condition")
				{
					#MSwitch_LOG( "test", 0,"ALL MSHEX ".__LINE__ );
					$Zeilen1=MSwitch_Hex($Zeilen1);
				}

                my $cs = "setreading $aktname $reading $Zeilen1";
                my $errors = AnalyzeCommandChain( undef, $cs );
                if ( defined($errors) ) {
                    $data{MSwitch}{runningbackuperror} .=
                      "\n - $aktname: $errors";
                    $data{MSwitch}{runningbackuperror} .=
                      "\n verursachende Zeile:";
                    $data{MSwitch}{runningbackuperror} .= "\n   $errors";
                }
            }
        }
    }

	delete $data{MSwitch}{$Name}{Device_Affected_Details};
	delete $data{MSwitch}{$Name}{TCond};

    if ( $arg eq "configfile" ) {
        return;
    }

	if ( $arg eq "configdevice" ) {
        return;
    }
	
    MSwitch_LoadHelper($hash);
	MSwitch_Createtimer($hash);
    return $ret;
}

################################
sub MSwitch_backup_this($$) {
    my ( $hash, $arg ) = @_;
    my $Name  = $hash->{NAME};
    my $modus = "backup";

    if ( $arg eq "cleanup" ) {
        $modus = "cleanup";
    }
	
	
	if ( $arg eq "experimental" ) {
        $modus = "experimental";
    }
	
	
	 if ( $arg eq "support" ) {
        $modus = "support";
    }
	

    if ( $arg eq "rename" ) {
        $modus = "rename";
    }

    if ( $arg eq "getconfig" ) {
        $modus = "config";
    }

    if ( $arg eq "undo" ) {
        $modus = "undo";
    }

    if ( $arg eq "getraw" ) {
        $modus = "getraw";
    }

    my %keys;
    my $INFO = "";
    my $BD   = "#T -> Einzelrestore\n";
    $BD .= "#N -> $Name\n";
	
	my $uuid = $defs{$Name}{FUUID};
	$BD .= "#UUID -> $uuid\n";








    my $testreading = $hash->{READINGS};
    my @areadings   = ( keys %{$testreading} );

    foreach my $key (@areadings) {
        next if $key eq "last_exec_cmd";
        next if $key eq "EVENT";
        next if $key eq "EVTFULL";
        next if $key eq "EVTPART1";
        next if $key eq "EVTPART2";
        next if $key eq "EVTPART3";
        next if $key eq "Next_Timer";
        next if $key eq "last_ID";
		
        my $tmp = ReadingsVal( $Name, $key, 'undef' );
		
		if (
				$key eq ".Device_Affected_Details_new" ||
				$key eq ".sysconf"||
				$key eq ".Trigger_condition"
				)
				{
					$tmp=MSwitch_Asc($tmp);	
				}
		
        $tmp =~ s/\n/#[nl]/g;
        $BD .= "#S $key -> $tmp\n";
    }

    if ( $modus ne "undo" and $modus ne "getraw" and $modus ne "cleanup"  and $modus ne "support" 
)
	{
        foreach my $attrdevice ( keys %{ $attr{$Name} } ) 
		{
            my $attr = AttrVal( $Name, $attrdevice, '' );
            my $inhalt = "#A $attrdevice -> " . $attr;
            $inhalt =~ s/\n/#[nl]/g;
            $BD .= $inhalt . "\n";
        }
#MSwitch_LOG( "test", 0,"ALL MSHEX ".__LINE__ );
		$BD = MSwitch_Hex($BD);	
    }
	
	
	
	
	    if ( $modus eq "support" 
)
	{
        foreach my $attrdevice ( keys %{ $attr{$Name} } ) 
		{
            my $attr = AttrVal( $Name, $attrdevice, '' );
            my $inhalt = "#A $attrdevice -> " . $attr;
            $inhalt =~ s/\n/#[nl]/g;
            $BD .= $inhalt . "\n";
        }
#MSwitch_LOG( "test", 0,"ALL MSHEX ".__LINE__ );
		#$BD = MSwitch_Hex($BD);	
    }
	
	
	
	
	

    if ( $modus eq "rename" ) 
	{
        return $BD;
    }

#############
    # modus getconfig
    if ( $modus eq "config" ) {
			asyncOutput( $hash->{CL},
			"<html><center>Configfile kann über den Wizard eingespielt werden.<br>"
			."<input type=\"button\" value=\"Copy to Clipboard\" "
			."style=\"text-align: center; background-color: Transparent;  font-size: 0.6em; height: 18px; width: #150px;\" "
			."onclick=\" javascript:"
			."var t = document.getElementById(\\\'edit1\\\');"
			."t.select();"
			."document.execCommand(\\\'copy\\\');"
			."\">"
			."<textarea name=\"edit1\" id=\"edit1\" rows=\""
          . "400\" cols=\"220\" STYLE=\"font-family:Arial;font-size:9pt;\">"
          . $BD
          . "</textarea><br></html>" );
    return;
    }

    if ( $modus eq "undo" ) 
	{
        return $BD;
    }

    if ( $modus eq "cleanup"||$modus eq "support"  ) 
	{
        ($BD) =~ s/(.|\n)/sprintf("%02lx ", ord $1)/eg;
        $BD =~ s/ //g;
        return $BD;
    }

    if ( $modus eq "getraw" )
	{
        ($BD) =~ s/(.|\n)/sprintf("%02lx ", ord $1)/eg;
        $BD =~ s/ //g;
        $BD .= "\n";
        foreach my $attrdevice ( keys %{ $attr{$Name} } ) {
            my $attr = AttrVal( $Name, $attrdevice, '' );
            my $inhalt = "attr $Name $attrdevice " . $attr;
            $inhalt =~ s/\n/\\\n/g;
            $BD .= $inhalt . "\n";
        }
        return $BD;
    }
#############
# modus backup und experimental
my $nzusatz="MSwitch_Device_";
	if ( $modus eq "experimental" )
	{
	$nzusatz="MSwitch_Experimental_";	
	}

	
my $pfad =  AttrVal( 'global', 'backupdir', $restoredirn ) ;
$pfad.="/MSwitch/";


if(-d $pfad) {
	# nichtvorhanden 
	} else { mkdir($pfad ,0777);}
#    open( BACKUPDATEI, ">" . $pfad . "MSwitch_Device_" . $Name . ".txt" );
open( BACKUPDATEI, ">" . $pfad . $nzusatz . $Name . ".txt" );

    print BACKUPDATEI "$BD";
    close(BACKUPDATEI);
    return "ready";
}

##########################

# lieferrt verfügbare backups an configdevice
sub MSwitch_Get_Backup($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
	
	my $pfad =  AttrVal( 'global', 'backupdir', $restoredirn ) ;
	$pfad.="/MSwitch/";
	
    opendir( DIR, "$pfad" ) || MSwitch_fileerror($hash);
    my @files = grep { /MSwitch_Full_.*/ } readdir DIR;
    closedir(DIR);

    opendir( DIR, "$pfad" ) || MSwitch_fileerror($hash);
    my @files1 = grep { /MSwitch_Save.*/ } readdir DIR;
    closedir(DIR);

    opendir( DIR, "$pfad" ) || MSwitch_fileerror($hash);
    my @files2 = grep { /MSwitch_Device_.*/ } readdir DIR;
    closedir(DIR);
	
	opendir( DIR, "$pfad" ) || MSwitch_fileerror($hash);
    my @files3 = grep { /MSwitch_Experimental_.*/ } readdir DIR;
    closedir(DIR);
	

    if ( @files == 0 && @files1 == 0 && @files2 == 0 && @files2 == 0) { return "leer"; }
	
    return "@files @files1 DEVICES @files2 EXPERIMENTAL @files3";
}
####################################################
sub MSwitch_fileerror($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
    MSwitch_LOG( $Name, 5, "no Restoredir $restoredir found!" );
    return;
}

################################
sub MSwitch_FullBackup_save(@) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
    MSwitch_LOG( $Name, 1, "$Name delayed Shutdown: start MSwitch_Save" );
    MSwitch_FullBackup( $hash, "save" );
    CancelDelayedShutdown($Name);
    return;
}

################################
sub MSwitch_FullBackup(@) {
    my ( $hash, $arg ) = @_;
    my $Name = $hash->{NAME};
    my %keys;
    my $BD   = "";
    my $INFO = "";
    my $time = localtime;
    $time =~ s/\s+/ /g;
    my @time = split( / /, $time );
    my $newtime;    # = $time[2].".".$time[1].".".$time[4]."_".$time[3];
    if ( !defined $arg ) { $arg = ""; }
    my $ans = @time;
    if ( $ans == 6 ) {
        $newtime = $time[3] . "" . $time[1] . "" . $time[5] . "_" . $time[4];
    }

    else {
        $newtime = $time[2] . "" . $time[1] . "" . $time[4] . "_" . $time[3];
    }

    my %MONATE = (
	'Jan' => '01',
	'Feb' => '02',
	'Mar' => '03',
	'Apr' => '04',
	'May' => '05',
	'Jun' => '06',
	'Jul' => '07',
	'Aug' => '08',
	'Sep' => '09',
    'Oct' => '10',	
	'Nov' => '11',
	'Dec' => '12'
    );
    my $MONKEYS = join( "|", keys(%MONATE) );
    FW_directNotify( "FILTER=$Name", "#FHEMWEB:WEB",
        "information('- $newtime')", "" );
    $newtime =~ s/($MONKEYS)/$MONATE{$1}/g;
	$newtime =~ s/://g;
    $BD .= "#T -> Fullrestore\n";
    foreach my $testdevice ( keys %{ $modules{MSwitch}{defptr} } )    #
    {
        if ( ReadingsVal( $testdevice, '.msconfig', 'undef' ) eq "1" ) {
            next;
        }

        if ( $arg ne "save" ) {
            FW_directNotify( "FILTER=$Name", "#FHEMWEB:WEB",
                "information('- schreibe Daten für $testdevice')", "" );
        }

        my $devhash     = $defs{$testdevice};
        my $testreading = $devhash->{READINGS};
        my @areadings   = ( keys %{$testreading} );

        $BD .= "#N -> $testdevice\n";

my $uuid = $defs{$testdevice}{FUUID};
	$BD .= "#UUID -> $uuid\n";


        foreach my $key (@areadings) {
            next if $key eq "last_exec_cmd";
            next if $key eq "EVENT";
            next if $key eq "EVTFULL";
            next if $key eq "EVTPART1";
            next if $key eq "EVTPART2";
            next if $key eq "EVTPART3";
            next if $key eq "Next_Timer";
            next if $key eq "last_ID";

            my $tmp = ReadingsVal( $testdevice, $key, 'undef' );
           

			if (
				$key eq ".Device_Affected_Details_new" ||
				$key eq ".sysconf"||
				$key eq ".Trigger_condition"
				)
				{
					$tmp=MSwitch_Asc($tmp);	
				}

			$tmp =~ s/\n/#[nl]/g;
            $BD .= "#S $key -> $tmp\n";
        }

        foreach my $attrdevice ( keys %{ $attr{$testdevice} } ) {
            my $attr = AttrVal( $testdevice, $attrdevice, '' );
            my $inhalt = "#A $attrdevice -> " . $attr;
            $inhalt =~ s/\n/#[nl]/g;
            $BD .= $inhalt . "\n";
        }

        if ( $arg eq "delete" ) {
            my $error = AnalyzeCommand( $hash, "delete " . $testdevice );
            FW_directNotify(
                "FILTER=$Name",                        "#FHEMWEB:WEB",
                "information('- delete $testdevice')", ""
            );
        }
    }
#MSwitch_LOG( "test", 0,"ALL MSHEX ".__LINE__ );
$BD = MSwitch_Hex($BD);

my $pfad =  AttrVal( 'global', 'backupdir', $restoredirn ) ;
$pfad.="/MSwitch/";

if(-d $pfad) {  
               # nichtvorhanden  
        }  
        else {  
             mkdir($pfad ,0777);
        }


    if ( $arg eq "save" ) {
        open( BACKUPDATEI, ">" . $pfad . "MSwitch_Save.txt" );
		print BACKUPDATEI "$BD";
        close(BACKUPDATEI);
      
	  
	  
	  
        return;
    }
    else {
		open( BACKUPDATEI, ">" . $pfad . "MSwitch_Full_" . $newtime . ".txt" );
        print BACKUPDATEI "$BD";
        close(BACKUPDATEI);

        FW_directNotify( "FILTER=$Name", "#FHEMWEB:WEB", "information(' ')",
            "" );
        FW_directNotify(
            "FILTER=$Name",
            "#FHEMWEB:WEB",
"information('############################################################################')",
            ""
        );
        FW_directNotify(
            "FILTER=$Name",
            "#FHEMWEB:WEB",
            "information('Backupdatei "
              . $pfad
              . "MSwitch_Full_$newtime wurde geschrieben.')",
            ""
        );
        FW_directNotify(
            "FILTER=$Name",
            "#FHEMWEB:WEB",
"information('############################################################################')",
            ""
        );
        return "MSwitch_" . $newtime . ".txt";
    }
}

################################

# lieferrt backupinhalt an browser
sub MSwitch_Get_Backup_inhalt(@) {

    my ( $hash, $arg1 ) = @_;
    my $Name   = $hash->{NAME};
    my $string = $arg1;
    my $Zeilen = "";
	
	my $pfad =  AttrVal( 'global', 'backupdir', $restoredirn ) ;
	$pfad.="/MSwitch/";
    open( BACKUPDATEI, "<" . $pfad . $string )
      || return "no Backupfile found!";
    while (<BACKUPDATEI>) {
        $Zeilen = $Zeilen . $_;
    }
    close(BACKUPDATEI);
    return $Zeilen;
}

####################################################

sub MSwitch_fullrestorelocal(@) {
    my ( $hash, $arg1  ) = @_;
    my $Name   = $hash->{NAME};
    my $string = $arg1;

    if ( $string eq "makefile" ) {
        FW_directNotify( "FILTER=$Name", "#FHEMWEB:WEB", "information(' ')",
            "" );
        FW_directNotify(
            "FILTER=$Name",                                   "#FHEMWEB:WEB",
            "information('Datei wird auf Server angelegt.')", ""
        );
		
		my $pfad =  AttrVal( 'global', 'backupdir', $restoredirn ) ;
		$pfad.="/MSwitch/";
        open( BACKUPDATEI, ">" . $pfad . "MSwitch_Local_Backup.txt" );
        print BACKUPDATEI $data{MSwitch}{localbackup};
        close(BACKUPDATEI);
        $data{MSwitch}{localbackup} = "";
        return;
    }
    $data{MSwitch}{localbackup} .= $arg1;
    return;
}

##############################################################################


sub MSwitch_uploadlocal(@) 
{
    my ( $hash, @args  ) = @_;
    my $Name   = $hash->{NAME};
    my $string = $args[0];
	my $filename = $args[1];
    if ( $string eq "makefile" ) {
        FW_directNotify( "FILTER=$Name", "#FHEMWEB:WEB", "information(' ')",
            "" );
        FW_directNotify(
            "FILTER=$Name",                                   "#FHEMWEB:WEB",
            "information('Datei $filename wird auf Server angelegt.')", ""
        );
		
		my $pfad =  AttrVal( 'global', 'backupdir', $restoredirn ) ;
		$pfad.="/MSwitch/";
        open( BACKUPDATEI, ">" . $pfad . $filename );
        print BACKUPDATEI $data{MSwitch}{localbackup};
        close(BACKUPDATEI);
        $data{MSwitch}{localbackup} = "";
        return;
    }
    $data{MSwitch}{localbackup} .= $string;
    return;
}


##############################################################################

sub MSwitch_fullrestore(@) {
    my ( $hash, $arg1 ,$arg2) = @_;
    my $Name    = $hash->{NAME};
    my $string  = $arg1;
    my $Zeilen  = "";
    my $aktname = "", my $devhash;
    my @devicenames;
    my $encoded;
    my $mode = "";
	my $pfad =  AttrVal( 'global', 'backupdir', $restoredirn ) ;
	$pfad.="/MSwitch/";

	if ($arg1 eq "extract")
	{
	$Zeilen = $arg2;
	}
	else
	{
    open( BACKUPDATEI, "<" . $pfad . $string )
      || return "no Backupfile found!";

    while (<BACKUPDATEI>) {
        $Zeilen = $Zeilen . $_;
    }
    close(BACKUPDATEI);
}



#MSwitch_LOG( "test", 0,"ALL MSHEX ".__LINE__ );
$Zeilen=MSwitch_Asc($Zeilen);

#my @output = ();
#	while ($Zeilen =~ /(.{2})/g) {
	#  push @output, $1;
	#}
	#my $newstring;
	#foreach (@output) {
	#	$newstring.=chr(hex $_)	
	#}
	#$Zeilen = $newstring;
    #($Zeilen) =~ s/([a-fA-F0-9]{2})?/chr(hex $1)/eg;
	
	
	
    $data{MSwitch}{$Name}{backupdatei} = $Zeilen;
    my @found = split( /\n/, $Zeilen );

    if ( $found[0] =~ m/#T -> Einzelrestore/ ) {
        FW_directNotify(
            "FILTER=$Name",                        "#FHEMWEB:WEB",
            "information('modus: Einzelrestore')", ""
        );
        $mode = "einzel";
    }
    else {
        FW_directNotify(
            "FILTER=$Name",                      "#FHEMWEB:WEB",
            "information('modus: Fullrestore')", ""
        );
        $data{MSwitch}{runningbackup} = "ja";

        # ÄNDERN nur wenn device vorhanden !
        AnalyzeCommand( $hash, "set TYPE=alexa stop" );
        $mode = "full";

        FW_directNotify( "FILTER=$Name", "#FHEMWEB:WEB",
            "information('Das System wird für den Restore vorbereitet.')",
            "" );
        FW_directNotify(
            "FILTER=$Name",
            "#FHEMWEB:WEB",
"information('Aus Sicherheitsgünden werden verschiedene Dienste gestoppt')",
            ""
        );
        FW_directNotify( "FILTER=$Name", "#FHEMWEB:WEB", "information(' ')",
            "" );
        FW_directNotify(
            "FILTER=$Name",
            "#FHEMWEB:WEB",
"information('MSwitch-Systemvorbereitung: Notifyverarbeitung gestoppt.')",
            ""
        );
        FW_directNotify( "FILTER=$Name", "#FHEMWEB:WEB",
            "information('MSwitch-Systemvorbereitung: Init-Check gestoppt.')",
            "" );
        FW_directNotify(
            "FILTER=$Name",
            "#FHEMWEB:WEB",
            "information('MSwitch-Systemvorbereitung: Load-helper gestoppt.')",
            ""
        );
        FW_directNotify(
            "FILTER=$Name",
            "#FHEMWEB:WEB",
            "information('MSwitch-Systemvorbereitung: Alexadevices gestoppt.')",
            ""
        );
        FW_directNotify( "FILTER=$Name", "#FHEMWEB:WEB", "information(' ')",
            "" );
    }

    $data{MSwitch}{runningbackuperror} = "";

    foreach (@found) 
	{
        if ( $_ =~ m/#N -> (.*)/ )    # setreading
        {
            $Zeilen = $1;
            $Zeilen =~ s/#\[nl\]/\n/g;
            $aktname = $Zeilen;
			# teste auf vorhandensein -vorhanden -> reset - ansonsten -> define
			my @found_devices = devspec2array("TYPE=MSwitch:FILTER=NAME=$aktname");
			# ##############
			if ( @found_devices > 0)
			{
	
			my $devhash = $defs{$aktname};
			my $cmd ="";
			my $check = "checked";
			MSwitch_Set_ResetDevice($devhash, $aktname, $cmd,$check) ;
		
		 }
		 else
		 {
			
			my $error1 = AnalyzeCommand( $hash, "define " . $aktname . " mswitch" );
            if ( defined($error1) ) 
			{
                $encoded = urlEncode($error1);
                FW_directNotify( "FILTER=$Name", "#FHEMWEB:WEB",
                    "information('!!! Fehler aufgetreten: $encoded')", "" );
                $data{MSwitch}{runningbackuperror} .= "\n - $error1";
            }
			
		 }
            push( @devicenames, $aktname );
        }
    }

    my $devnames = join( '|', @devicenames );
    $data{MSwitch}{$Name}{backupdevices}      = $devnames;
    $data{MSwitch}{$Name}{backupdeviceskompl} = $devnames;

    if ( @devicenames > 0 ) {
        my $timecond = gettimeofday() + 0.1;
        InternalTimer( $timecond, "MSwitch_fullrestore1", $hash );
        FW_directNotify(
            "FILTER=$Name",
            "#FHEMWEB:WEB",
"information('Die Devices wurden erstellt, beginne Datenimport ...')",
            ""
        );
        FW_directNotify( "FILTER=$Name", "#FHEMWEB:WEB", "information(' ')",
            "" );

        return;
    }
    else {
        my $timecond = gettimeofday() + 0.1;
        InternalTimer( $timecond, "MSwitch_fullrestore_end", $hash );
        return;
    }
}

###############################

sub MSwitch_fullrestore1($) {

    my ($hash)      = @_;
    my $Name        = $hash->{NAME};
    my $devnames    = $data{MSwitch}{$Name}{backupdevices};
    my $backupdatei = $data{MSwitch}{$Name}{backupdatei};
    my @devices = split( /\|/, $devnames );
    my $devhash;

    my $aktnametorestore = shift(@devices);
    my $aktname          = "";
    my $Zeilen;
    my $encoded;
    my $notif;

    $notif   = " - Importiere Daten fuer $aktnametorestore";
    $encoded = urlEncode($notif);

    FW_directNotify( "FILTER=$Name", "#FHEMWEB:WEB", "information('$encoded')","" );

    if ( @devices > 0 ) {
        $devnames = join( '|', @devices );
        $data{MSwitch}{$Name}{backupdevices} = $devnames;
    }

    my @found = split( /\n/, $backupdatei );

    foreach (@found) {
		
		
		
		
		
        if ( $_ =~ m/#N -> (.*)/ )    # setreading
        {
            $Zeilen = $1;
            $Zeilen =~ s/#\[nl\]/\n/g;
            $aktname = $Zeilen;
			delete $data{MSwitch}{$aktname}{Device_Affected_Details};
			delete $data{MSwitch}{$aktname}{TCond};
        }
		


        if ( $aktnametorestore ne $aktname ) {
            next;
        }


if ( $_ =~ m/#UUID -> (.*)/ )    # setreading
        {
            my $aktattr = $1;
			#MSwitch_LOG( "test", 0,"setze uuid n:$aktname / I:$aktattr".__LINE__ );
			$defs{$aktname}{FUUID} = $aktattr;
	
        }


        if ( $_ =~ m/#A (.*) -> (.*)/ )    # setattr
        {
            my $inhalt  = $2;
            my $aktattr = $1;
            $inhalt =~ s/#\[nl\]/\n/g;
            $inhalt =~ s/;/;;/g;
            my $cs = "attr $aktname $aktattr $inhalt";
            my $errors = AnalyzeCommandChain( undef, $cs );
            if ( defined($errors) ) {
                $encoded = urlEncode($errors);
                FW_directNotify( "FILTER=$Name", "#FHEMWEB:WEB",
                    "information('!!! Fehler aufgetreten: $encoded')", "" );
                $data{MSwitch}{runningbackuperror} .= "\n - $errors";
            }
        }

        if ( $_ =~ m/#S (.*?) -> (.*)/ )    # setreading
        {
            next if $1 eq "last_exec_cmd";
            next if $1 eq "EVTPART1";
            next if $1 eq "EVTPART2";
            next if $1 eq "EVTPART3";
            next if $1 eq "EVENT";
            next if $1 eq "last_activation_by";
            next if $1 eq "waiting";
            next if $1 eq "Next_Timer";
            next if $1 eq "last_event";

            if ( $2 eq 'undef' || $2 eq '' || $2 eq ' ' ) {
            }
            else {
                my $Zeilen1 = $2;
                my $reading = $1;
                $Zeilen1 =~ s/#\[nl\]/\n/g;
				
				if (
				$reading eq ".Device_Affected_Details_new" ||
				$reading eq ".sysconf"||
				$reading eq ".Trigger_condition"
				)
				{
					
					#MSwitch_LOG( "test", 0,"ALL MSHEX ".__LINE__ );
					$Zeilen1=MSwitch_Hex($Zeilen1);
				}

		 if ($reading eq ".Trigger_condition" && $Zeilen1 eq "no_device")
		 {  
		 next;
		 }
	
                my $cs = "setreading $aktname $reading $Zeilen1";
                my $errors = AnalyzeCommandChain( undef, $cs );
                if ( defined($errors) ) {
                    $encoded = urlEncode($errors);
                    FW_directNotify( "FILTER=$Name", "#FHEMWEB:WEB",
                        "information('!!! Fehler aufgetreten: $encoded')", "" );
                    $data{MSwitch}{runningbackuperror} .=
                      "\n - $aktname: $errors";
                    $data{MSwitch}{runningbackuperror} .=
                      "\n verursachende Zeile:";
                    my $encoded1 = urlEncode($cs);
                    $data{MSwitch}{runningbackuperror} .= "\n   $encoded1";
                }
            }
        }
    }

    if ( @devices > 0 ) {
        my $timecond = gettimeofday() + 0.1;
        InternalTimer( $timecond, "MSwitch_fullrestore1", $hash );
    }
    else {
        my $timecond = gettimeofday() + 0.1;
        InternalTimer( $timecond, "MSwitch_fullrestore_end", $hash );
    }
    return;
}

################################
sub MSwitch_fullrestore_end($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
    my $devnames   = $data{MSwitch}{$Name}{backupdeviceskompl};
    my @devices    = split( /\|/, $devnames );
    my $anzdevices = @devices;
    my $encoded    = urlEncode( "\n" . $data{MSwitch}{runningbackuperror} );

    $data{MSwitch}{$Name}{backupdeviceskompl} = "";
    $data{MSwitch}{$Name}{backupdevices}      = "";
    $data{MSwitch}{$Name}{backupdatei}        = "";
    $data{MSwitch}{$Name}{runningbackuperror} = "";

    FW_directNotify( "FILTER=$Name", "#FHEMWEB:WEB",
        "information('CLEARSCREEN')", "" );
    FW_directNotify( "FILTER=$Name", "#FHEMWEB:WEB",
        "information('###################################################')",
        "" );
    FW_directNotify(
        "FILTER=$Name",                    "#FHEMWEB:WEB",
        "information('Restore beendet.')", ""
    );
    FW_directNotify(
        "FILTER=$Name",
        "#FHEMWEB:WEB",
"information('Achtung , das MSwitch-Modul befindet sich in einem Restoremodus und ist nicht funktionsfähig.')",
        ""
    );
    FW_directNotify(
        "FILTER=$Name",
        "#FHEMWEB:WEB",
"information('Bitte ein fhem.save dürchführen und Fhem neu starten ')",
        ""
    );
    FW_directNotify( "FILTER=$Name", "#FHEMWEB:WEB", "information(' ')", "" );
    FW_directNotify( "FILTER=$Name", "#FHEMWEB:WEB",
        "information('es wurden $anzdevices Devices wiederhergestellt')", "" );

    foreach (@devices) {
        FW_directNotify( "FILTER=$Name", "#FHEMWEB:WEB",
            "information(' - $_')", "" );
    }

    FW_directNotify( "FILTER=$Name", "#FHEMWEB:WEB", "information(' ')", "" );
    FW_directNotify(
        "FILTER=$Name",                                      "#FHEMWEB:WEB",
        "information('Folgende Fehler sind aufgetreten: ')", ""
    );
    FW_directNotify( "FILTER=$Name", "#FHEMWEB:WEB", "information('$encoded')",
        "" );
    FW_directNotify( "FILTER=$Name", "#FHEMWEB:WEB", "information(' ')", "" );
    FW_directNotify( "FILTER=$Name", "#FHEMWEB:WEB",
        "information('###################################################')",
        "" );

 FW_directNotify( "FILTER=$Name", "#FHEMWEB:WEB",
        "information('   ')",
        "" );
		
		
		
    unlink( $restoredir . "MSwitch_Local_Backup.txt" );
	
	
	
	  FW_directNotify( "FILTER=$Name", "#FHEMWEB:WEB",
        "information('Neuinitialisierung aller Mswitches:')",
        "" );

	
	my @found_devices = devspec2array("TYPE=MSwitch");
	
	foreach (@found_devices) {
		
		FW_directNotify( "FILTER=$Name", "#FHEMWEB:WEB",
        "information('Initialisiere $_:')",
        "" );
			
	my $bridge = ReadingsVal( $_, '.Distributor', 'undef' );
	my $dhash  = $defs{$_};
    if ( $bridge ne "undef" ) {
        my @test = split( /\n/, $bridge );
         foreach my $testdevices (@test) {
             my ( $key, $val ) = split( /=>/, $testdevices );
             $dhash->{helper}{eventtoid}{$key} = $val;
         }
	 }	
	}
	
	
    return;
}
################################

sub MSwitch_Getsupport($) {
    my ($hash) = @_;
    my $Name   = $hash->{NAME};
    my $out    = '';
    my $startmessage = $data{MSwitch}{startmessage};
	
	$startmessage =~ s/\n/\\n/g;
	
	 
	
	#
	$out .= "Modulversion: $version\\n";
    $out .= "Datenstruktur: $vupdate\\n";
    $out .= "\\n----- Systemstart -----\\n";
	
	
    $out .= $startmessage;

    $out .= "\\n----- Devicename -----\\n";
    $out .= "$Name\\n";
	
    $out .= "\\n----- Attribute -----\\n";
     my %keys;

       foreach my $attrdevice ( keys %{ $attr{$Name} } )    #geht
      {
		  
		  
		  
		  
           my $tmp = AttrVal( $Name, $attrdevice, '' );
		   
		   $tmp =~ s/\n/\\n/g;
		   
           $out .= "Attribut $attrdevice: " . $tmp . "\\n";
		   
		   
		   #MSwitch_LOG( $Name, 0,"FOUNDLOG > $tmp")
		   
      }
	;

     $out .= "\\n----- Trigger -----\\n";
	
     $out .= "Trigger device:  ";
     my $tmp = ReadingsVal( $Name, '.Trigger_device', 'nicht definiert' );
	 $tmp = "kein Trigger definiert " if $tmp eq "no_trigger";
     $out .= "$tmp\\n";
	
     $out .= "Trigger time: ";
     $tmp = ReadingsVal( $Name, '.Trigger_time', 'kein Timer definiert' );
	 $tmp = "kein Timer definiert " if $tmp eq "no_trigger";
     $tmp =~ s/~/ /g;
     $out .= "$tmp\\n";
	
	
	
	
	
	
	
     $out .= "Trigger condition: ";
     $tmp = ReadingsVal( $Name, '.Trigger_condition', 'undef' );
	
	 $tmp = MSwitch_Load_Tcond($hash);
	
	 $tmp = "keine Triggercondition definiert " if $tmp eq "undef";
     $out .= "$tmp\\n";
	
     $out .= "Trigger Device Global Whitelist: ";
     $tmp = ReadingsVal( $Name, '.Trigger_Whitelist', 'undef' );
	 $tmp = "keine Trigger_Whitelist definiert " if $tmp eq "undef";
     $out .= "$tmp\\n";
	
     $out .= "\\n----- Trigger Details -----\\n";
     $out .= "Trigger cmd1: ";
     $tmp = ReadingsVal( $Name, '.Trigger_on', 'no_trigger' );
	 $tmp = "nicht definiert " if $tmp eq "no_trigger";
     $out .= "$tmp\\n";
	
     $out .= "Trigger cmd2: ";
     $tmp = ReadingsVal( $Name, '.Trigger_off', 'no_trigger' );
	 $tmp = "nicht definiert " if $tmp eq "no_trigger";
     $out .= "$tmp\\n";
	
	
	
	
	
	
     $out .= "Trigger cmd3: ";
     $tmp = ReadingsVal( $Name, '.Trigger_cmd_on', 'no_trigger' );
	 $tmp = "nicht definiert " if $tmp eq "no_trigger";
     $out .= "$tmp\\n";
	
     $out .= "Trigger cmd4: ";
     $tmp = ReadingsVal( $Name, '.Trigger_cmd_off', 'no_trigger' );
	 $tmp = "nicht definiert " if $tmp eq "no_trigger";
     $out .= "$tmp\\n";
	
     $out .= "\\n----- Bridge Details -----\\n";
     $tmp = ReadingsVal( $Name, '.Distributor', 'undef' );
	 $tmp = "keine Bridge definiert " if $tmp eq "undef";
     #$tmp =~ s/\n/#[nl]/g;
	 $tmp =~ s/\n/\\n/g;

     $out .= "$tmp\\n";




     my %savedetails = MSwitch_makeCmdHash($Name);
     $out .= "\\n----- Device Actions -----\\n";
	 my @affecteddevices =MSwitch_Load_Details($hash);
	 $out .= "keine Deviceactions definiert " if @affecteddevices < 1;
    foreach (@affecteddevices) {
		
		
		$_ =~ s/\n/\\n/g;
		
        my @devicesplit = split( /#\[NF\]/, $_ );
		
        $devicesplit[4] =~ s/'/\\'/g;
        $devicesplit[5] =~ s/'/\\'/g;
        $devicesplit[1] =~ s/'/\\'/g;
        $devicesplit[3] =~ s/'/\\'/g;
        $out .= "\\nDevice: " . $devicesplit[0] . "\\n";
		$out .= "--------------------------------\\n";
		$out .= "cmd1:\\n " . $devicesplit[1] . " " . $devicesplit[3] . "\\n";
		$out .= "cmd2:\\n " . $devicesplit[2] . " " . $devicesplit[4] . "\\n";
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

    $out =~ s/#\[sp\]/ /g;
  #  #$out =~ s/#\[nl\]/\n/g;
	$out =~ s/\(DAYS\)/|/g;

	   
	# entfernt speicherdaten
	   
	$out =~ s/-AbsCmd2//g;
	$out =~ s/-AbsCmd1//g;


	$out .= "--------------------------------\\n\\n";
	$out .="define ".$Name." mswitch HEX ".MSwitch_backup_this( $hash, "support" );
	
	 # $out =~ s/\[NEWLINWE\]/\\n/g;
	 $out =~ s/'/&#39;/g;
	 $out =~ s/"/&#34;/g;
     $out =~ s/&#160/&#38;nbsp;/g;

    asyncOutput( $hash->{CL},
			"<html><center>Bei Supportanfragen bitte untenstehene Datei anhängen.<br>"
			."<input type=\"button\" value=\"Copy to Clipboard\" "
			."style=\"text-align: center; background-color: Transparent;  font-size: 0.6em; height: 18px; width: #150px;\" "
			."onclick=\" javascript:"
			."var t = document.getElementById(\\\'edit1\\\');"
			."t.select();"
			."document.execCommand(\\\'copy\\\');"
			."\">"
			."<textarea name=\"edit1\" id=\"edit1\" rows=\""
          . "400\" cols=\"220\" STYLE=\"font-family:Arial;font-size:9pt;\">"
          . $out
          . "</textarea><br></html>" );
    return;
}
##################

sub MSwitch_Getconfig($$) {
    my ( $hash, $arg ) = @_;
    MSwitch_backup_this( $hash, "getconfig" );
    return;
	
	 }
##########################################

sub MSwitch_Getraw($) {
        my ($hash) = @_;#
        my $raw = MSwitch_backup_this( $hash, "getraw" );
        return $raw;
}


#######################################################
sub MSwitch_Sysextension($) {
    my ($hash) = @_;
    my $Name   = $hash->{NAME};
    my $count  = 30;
	my $out = MSwitch_Asc(ReadingsVal( $Name, '.sysconf', '' ));

#MSwitch_LOG( $Name, 0,"$out");


#

	$out =~ s/\n/[NEWLINWE]/g;
	#$out =~ s/\\n/&#92n/g;	

$out =~ s/\\/&#92/g;
	
	$out =~ s/\[NEWLINWE\]/\\n/g;
	
	
	
	
	$out =~ s/'/&#39;/g;
	$out =~ s/"/&#34;/g;
	$out =~ s/\//&#47/g;
    $out =~ s/&#160/&#38;nbsp;/g;
	
	
	
# $out =~ s/\n$/\\n/g;

#$out =~ s/\n$/\\n/g;



#MSwitch_LOG( $Name, 6,"FOUNDSYS > $out");




	asyncOutput( $hash->{CL},
			"<html><center>Code (Html/Javascript) wird unmittelbar unter DeviceOverview eingebettet<br>"
			."<input type=\"button\" value=\"Copy to Clipboard\" "
			."style=\"text-align: center; background-color: Transparent;  font-size: 0.6em; height: 18px; width: #150px;\" "
			."onclick=\" javascript:"
			."var t = document.getElementById(\\\'sys\\\');"
			."t.select();"
			."document.execCommand(\\\'copy\\\');"
			."\">"
			."&nbsp;<input type=\"button\" style=\"text-align: center; background-color: Transparent;  font-size: 0.6em; height: 18px; width: #150px;\" value=\"save changes\" onclick=\" javascript: savesys(document.querySelector(\\\'#sys\\\').value) \"><br>"
			
			."<textarea name=\"sys\" id=\"sys\" rows=\""
          . "$count\" cols=\"220\" STYLE=\"font-family:Arial;font-size:9pt;\">"
          . $out
          . "</textarea><br></html>"
    );
    return;
}

################################################
sub MSwitch_savesys($$) {
    my ( $hash, $cont ) = @_;
    my $name = $hash->{NAME};
    if ( !defined $cont ) { $cont = ""; }
    if ( $cont ne '' ) {
		# daten kommen bereits hexcodiert
        readingsSingleUpdate( $hash, '.sysconf',$cont, 0 );
    }
    else {
        fhem("deletereading $name .sysconf");
    }
	delete $data{MSwitch}{$name}{TCond};
	delete $data{MSwitch}{$name}{Device_Affected_Details};
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

    # configfile muss abgelegt werden !!!

    $data{MSwitch}{$name}{backupdatei} = $cont;
    my $ret = MSwitch_restore_this( $hash, "configfile" );

    ################# helperkeys abarbeiten #######

    readingsSingleUpdate( $hash, ".V_Check", $vupdate, 0 );

    delete( $hash->{helper}{safeconf} );
    delete( $hash->{helper}{mode} );
    ##############################################
    MSwitch_set_dev($hash);

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
    if ( AttrVal( $Name, 'MSwitch_Debug', '0' ) ne "0" ) { $showevents = 1 }
    my $param = AttrVal( $Name, 'MSwitch_RandomTime', '0' );
    my $min = substr( $param, 0, 2 ) * 3600;
    $min = $min + substr( $param, 3, 2 ) * 60;
    $min = $min + substr( $param, 6, 2 );
    my $max = substr( $param, 9, 2 ) * 3600;
    $max = $max + substr( $param, 12, 2 ) * 60;
    $max = $max + substr( $param, 15, 2 );
    my $sekmax = $max - $min;
    my $ret    = $min + int( rand $sekmax );
	
	$showevents = MSwitch_checkselectedevent( $hash, "Randomtimer" );
    readingsSingleUpdate( $hash, "Randomtimer", $ret, $showevents );
    return $ret;
}
############################################
sub MSwitch_replace_delay($$) {
    my ( $hash, $timerkey ) = @_;
	
	
	#$timerkey = "16:00:00";
	
	
    my $name  = $hash->{NAME};
    my $time  = time;
    my $ltime = TimeNow();
    my ( $aktdate, $akttime ) = split / /, $ltime;

    my $hh = ( substr( $timerkey, 0, 2 ) );
    my $mm = ( substr( $timerkey, 3, 2 ) );
    my $ss = ( substr( $timerkey, 6, 2 ) );

    my $referenz = time_str2num("$aktdate $hh:$mm:$ss");

    if ( $referenz < $time ) {
        $referenz = $referenz + 86400;
    }
    if ( $referenz >= $time ) {
    }
    $referenz = $referenz - $time;
    return $referenz;
}
############################################################
sub MSwitch_repeat($) {

    my ( $msg, $name ) = @_;

    # 4 - on / off

    my $incomming = $msg;
    my @msgarray = split( /\|/, $incomming );
    $name = $msgarray[1];

    # Return without any further action if the module is disabled
    return "" if ( IsDisabled($name) );

    if ( !exists $defs{$name} ) {
        return;
    }

    my $hash   = $defs{$name};
    my $time   = $msgarray[2];
    my $cs     = $msgarray[0];
    my $device = $msgarray[3];

    if ( !defined $device ) {
        return;
    }

    my $cmd = $msgarray[4];

    my %devicedetails = MSwitch_makeCmdHash($name);
	
	
	MSwitch_LOG( $name, 6,"\n ".localtime."\n---------- Moduleinstieg > MSwitch_repeat ----------\n- incomming: $incomming ");

    my $conditionkey = $device . "_condition" . $cmd;
    my $repconkey    = $device . "_repeatcondition";
    my $docheck      = $devicedetails{$repconkey};
    #
    if ( $docheck eq "1" ) {
        my $execute = "true";

        $execute =
          MSwitch_checkcondition( $devicedetails{$conditionkey}, $name, "" )
          if $devicedetails{$conditionkey} ne '';
        if ( $execute ne "true" ) {
            MSwitch_LOG( $name, 6,"-> Repeat abgebrochen , Bedingung nicht erfüllt L:" . __LINE__ );
            return;
        }
    }
    $cs =~ s/\n//g;
    $cs =~ s/MSwitch_Self/$name/g;
    if ( $cs =~ m/set (.*)(MSwitchtoggle)(.*)/ ) {
        $cs = MSwitch_toggle( $hash, $cs );
    }

    if ( AttrVal( $name, 'MSwitch_Debug', "0" ) ne '2' ) {
        MSwitch_LOG( $name, 6,"-> Befehlswiederholungen ausgeführt: $cs  L:" . __LINE__ );
        if ( $cs =~ m/{.*}/ ) {
            $cs = MSwitch_dec( $hash, $cs );
            {
                no warnings;
                eval($cs);
            }
            if ($@) {
                MSwitch_LOG( $name, 1,
                    "$name MSwitch_repeat: ERROR $cs: $@ " . __LINE__ );
            }
        }
        else {
            $cs = MSwitch_dec( $hash, $cs );

            my $errors = AnalyzeCommandChain( undef, $cs );
            if ( defined($errors) ) {
                MSwitch_LOG( $name, 1,
                    "$name Absent_repeat $cs: ERROR : $errors -> Comand: $cs" );
            }
        }
    }

    else {
        MSwitch_LOG( $name, 6,"-> nicht ausgeführte Befehlswiederholungen (Debug2): $cs  L:" . __LINE__ );

    }
    delete( $hash->{helper}{repeats}{$time} );
    return;
}

####################

sub MSwitch_RestartselftriggerTimer(@) {

    my ($hash) = @_;
    my $Name = $hash->{NAME};
    return "" if ( IsDisabled($Name) );

    my $selftrigger = $hash->{helper}{restartseltrigger};
    delete( $hash->{helper}{restartseltrigger} );
    $hash->{helper}{selftriggermode} =
      AttrVal( $Name, 'MSwitch_Selftrigger_always', 0 );

    MSwitch_Check_Event( $hash, $selftrigger );
    delete( $hash->{helper}{selftriggermode} );
    return;
}

###################

sub MSwitch_Restartselftrigger(@) {

    my ($hash)   = @_;
    my $Name     = $hash->{NAME};
    my $timecond = gettimeofday() + 0.1;
    InternalTimer( $timecond, "MSwitch_RestartselftriggerTimer", $hash );
    return;
}

######################

sub MSwitch_Restartcmdnew($) {

    my $incomming = $_[0];
    my ( $timecondition, $name ) = split( /-/, $incomming );
    my $hash = $modules{MSwitch}{defptr}{$name};
    my $showevents = AttrVal( $name, "MSwitch_generate_Events", 0 );
    if ( AttrVal( $name, 'MSwitch_Debug', '0' ) ne "0" ) { $showevents = 1 }
    return "" if ( IsDisabled($name) );
    $hash->{MSwitch_Eventsave} = 'unsaved';

    # checke versionskonflikt der datenstruktur
    if ( ReadingsVal( $name, '.V_Check', $vupdate ) ne $vupdate ) {
        my $ver = ReadingsVal( $name, '.V_Check', '' );
        MSwitch_LOG( $name, 1, "$name: Versionskonflikt - aktion abgebrochen" );
        return;
    }
	
	MSwitch_LOG( $name, 6,"\n ".localtime."\n---------- Moduleinstieg > SUB_Restartcmd ----------\n- verzögerte Befehlswiederholungen ausgeführt: $incomming  ");

    if ( !exists $hash->{helper}{delaydetails}{$timecondition}{cmd} ) {

        MSwitch_LOG( $name, 5, "ABBRUCH FILE not Found" );

        MSwitch_LOG( $name, 5,
            "delaydeteils: " . $hash->{helper}{delaydetails}{$timecondition} );

        return;
    }

    my $cs = $hash->{helper}{delaydetails}{$timecondition}{cmd};
    $cs =~ s/##/,/g;

	MSwitch_LOG( $name, 6, "-> restarted CMD  -> " . $cs );

    my $conditionkey = $hash->{helper}{delaydetails}{$timecondition}{check};
    my $event        = $hash->{helper}{delaydetails}{$timecondition}{Indikator};
    my $device       = $hash->{helper}{delaydetails}{$timecondition}{device};
    my $cmdzweig     = $hash->{helper}{delaydetails}{$timecondition}{state};
    my $delaytime    = $timecondition;

    my %devicedetails = MSwitch_makeCmdHash($name);

    if ( AttrVal( $name, 'MSwitch_RandomNumber', '' ) ne '' ) {
        MSwitch_Createnumber1($hash);
    }

    ### teste auf condition
    my $execute = "true";
    $devicedetails{$conditionkey} = "nocheck" if $conditionkey eq "nocheck";
    if ( $conditionkey ne 'nocheck' )    # msgarray[2]
    {
        $execute = MSwitch_checkcondition( $devicedetails{$conditionkey}, $name,
            $event );
    }

    my $toggle = '';
    if ( $execute eq 'true' ) {

        if ( $cs =~ m/set (.*)(MSwitchtoggle)(.*)/ ) {
            $toggle = $cs;
            $cs = MSwitch_toggle( $hash, $cs );
        }

        my $x = 0;

        if ( $devicedetails{ $device . '_repeatcount' } ) {
            while ( $devicedetails{ $device . '_repeatcount' } =~
                m/\[(.*)\:(.*)\]/ )
            {
                $x++;    # notausstieg notausstieg
                last if $x > 20;    # notausstieg notausstieg
                my $setmagic = ReadingsVal( $1, $2, 0 );
                $devicedetails{ $device . '_repeatcount' } = $setmagic;
            }
        }

        if ( $devicedetails{ $device . '_repeattime' } ) {
            $x = 0;
            while (
                $devicedetails{ $device . '_repeattime' } =~ m/\[(.*)\:(.*)\]/ )
            {
                $x++;               # notausstieg notausstieg
                last if $x > 20;    # notausstieg notausstieg
                my $setmagic = ReadingsVal( $1, $2, 0 );
                $devicedetails{ $device . '_repeattime' } = $setmagic;
            }
        }

        if ( !defined $devicedetails{ $device . '_repeatcount' } ) {
            $devicedetails{ $device . '_repeatcount' } = 0;
        }
        if ( !defined $devicedetails{ $device . '_repeattime' } ) {
            $devicedetails{ $device . '_repeattime' } = 0;
        }

        if ( $devicedetails{ $device . '_repeatcount' } eq "undefined" ) {
            $devicedetails{ $device . '_repeatcount' } = 0;
        }
        if ( $devicedetails{ $device . '_repeattime' } eq "undefined" ) {
            $devicedetails{ $device . '_repeattime' } = 0;
        }

        ######################################
        if (   defined $devicedetails{ $device . '_repeatcount' }
            && defined $devicedetails{ $device . '_repeattime' }
            && AttrVal( $name, 'MSwitch_Expert', "0" ) eq '1'
            && $devicedetails{ $device . '_repeatcount' } > 0
            && $devicedetails{ $device . '_repeattime' } > 0 )
        {
            my $i;
            for (
                $i = 1 ;
                $i <= $devicedetails{ $device . '_repeatcount' } ;
                $i++
              )
            {
                my $msg = $cs . "|" . $name;
                if ( $toggle ne '' ) {
                    $msg = $toggle . "|" . $name;
                }
                my $timecond = gettimeofday() +
                  ( ( $i + 1 ) * $devicedetails{ $device . '_repeattime' } );
                $msg = $msg . "|" . $timecond . "|$device|$cmdzweig";    #on/off
                $hash->{helper}{repeats}{$timecond} = "$msg";
                MSwitch_LOG( $name, 6,"-> Setze Befehlswiederholung $timecond" );
                InternalTimer( $timecond, "MSwitch_repeat", $msg );
            }
        }

        my $todec = $cs;
		my $msg;
		

        if ( AttrVal( $name, 'MSwitch_Debug', "0" ) eq '2' ) 
		{
            MSwitch_LOG( $name, 6, "-> Befehlsausführung -> " . $cs );
        }
        else 
		{
			if ( $cs =~ m/^\{/ )
			{
                $cs =~ s/\[SR\]/\|/g;
                MSwitch_LOG( $name, 6,"-> finale verzögerte Befehlsausführung auf Perlebene:\n\n$cs\n\n");
					{
						$cs = MSwitch_dec( $hash, $cs );
						$cs = MSwitch_makefreecmd( $hash, $cs );
						$msg = $cs;
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
				
				my $errors;
                MSwitch_LOG( $name, 6, "-> finale verzögerte Befehlsausführung auf Fhemebene:\n\n$cs\n\n");
				if ( AttrVal( $name, 'MSwitch_CMD_processing', $cmdprocessing ) eq "block" )
							{			
									MSwitch_LOG( $name, 6,"execute command BLOCKMODE-> $cs " . __LINE__ ."\n");	
									$cs = MSwitch_dec( $hash, $cs );
									$errors = AnalyzeCommandChain( undef, $cs );
									$msg=$cs;
							}	


				if ( AttrVal( $name, 'MSwitch_CMD_processing', $cmdprocessing ) eq "line" )
							{		
							
								MSwitch_LOG( $name, 6,"execute command LINEMODE-> $device " . __LINE__ );		
								my @lines = split( /;/, $cs );	
								MSwitch_LOG( $name, 6,"LINES-> @lines " . __LINE__ );		
								 foreach my $einzelline (@lines) 
								 {
									MSwitch_LOG( $name, 6,"LINE -> $einzelline " . __LINE__ );		
									$einzelline = MSwitch_dec( $hash, $einzelline );
									$errors = AnalyzeCommandChain( undef, $einzelline );
									$msg.=$einzelline.";";
								 }
								 
							}	

			   if ( defined($errors) and $errors ne "OK" )
				{

                    if ( $cs =~ m/^get.*/ ) 
					{
                        MSwitch_PerformGetRequest( $hash, $errors );
                    }
                    else 
					{
                        MSwitch_LOG( $name, 1,"$name MSwitch_Restartcmd :Fehler bei Befehlsausfuehrung  ERROR -$errors- ". __LINE__ );
                    }
                }
            }
        }

        if ( length($msg) > 100
            && AttrVal( $name, 'MSwitch_Debug', "0" ) ne '4' )
        {
            $msg = substr( $msg, 0, 100 ) . '....';
        }
		$showevents = MSwitch_checkselectedevent( $hash, "last_exec_cmd" );
        readingsSingleUpdate( $hash, "last_exec_cmd", $msg, $showevents )if $cs ne '';
    }

    RemoveInternalTimer($delaytime);
    delete( $hash->{helper}{delaydetails}{$delaytime} );

    foreach my $a ( keys %{ $hash->{helper}{delaydindikator} } ) {
        if ( $hash->{helper}{delaydindikator}{$a} eq $delaytime ) {
            delete( $hash->{helper}{delaydindikator}{$a} );
        }
    }

    foreach my $a ( keys %{ $hash->{helper}{delaynames} } ) {
        if ( $hash->{helper}{delaynames}{$a} eq $delaytime ) {
            delete( $hash->{helper}{delaynames}{$a} );
        }
    }
    return;
}

###############################
sub MSwitch_Safemode($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};

    my $aktmode = AttrVal( $Name, 'MSwitch_Safemode', $startsafemode );
	my $showevents;
    return if $aktmode == 0;
    my $time1 = gettimeofday();
    my $count = 0;

    my $timehash = $hash->{helper}{savemode};

    foreach my $a ( keys %{$timehash} ) {
        $count++;
        if ( $a < $time1 - $savemodetime )    #
        {
            delete( $hash->{helper}{savemode}{$a} );
            $count = $count - 1;
        }
    }

    $hash->{helper}{savemode}{$time1} = $time1;

    if ( $count > $savecount && $aktmode == 1 ) {

        MSwitch_LOG( $Name, 1,
                "Das Device "
              . $Name
              . " wurde automatisch deaktiviert ( Safemode 1 )" );
		
        $hash->{helper}{savemodeblock}{blocking} = 'on';
        readingsSingleUpdate( $hash, "Safemode", 'on', 1 );
        MSwitch_Delete_Delay( $hash, 'all' );
        MSwitch_Clear_timer($hash);
        readingsSingleUpdate( $hash, "state", 'disabled(safemode)', 1 );
        $attr{$Name}{disable} = '1';
    }

    if ( $count > $savecount && $aktmode == 2 ) {

		MSwitch_LOG( $Name, 6,"----------  SUB MSwitch_Safemode ----------");
        MSwitch_LOG( $Name, 1,
                "Das Device "
              . $Name
              . " wurde automatisch für $savemode2block sekunden blockiert ( Safemode 2 )"
        );

        MSwitch_LOG( $Name, 6,
                "-> Das Device "
              . $Name
              . " wurde automatisch für $savemode2block sekunden blockiert ( Safemode 2 )"
        );

        $hash->{helper}{statistics}{safemode_2_blocking_on}++
          if $statistic == 1;    #statistik


$showevents = MSwitch_checkselectedevent( $hash, "waiting" );
        readingsSingleUpdate( $hash, "waiting", ( time + $savemode2block ),$showevents );
    }

    return;
}

####################

sub MSwitch_Createnumber($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
    my $showevents = AttrVal( $Name, "MSwitch_generate_Events", 0 );
    if ( AttrVal( $Name, 'MSwitch_Debug', '0' ) ne "0" ) { $showevents = 1 }
    my $number = AttrVal( $Name, 'MSwitch_RandomNumber', '' ) + 1;
    my $number1 = int( rand($number) );
	
	$showevents = MSwitch_checkselectedevent( $hash, "RandomNr" );
    readingsSingleUpdate( $hash, "RandomNr", $number1, $showevents );
    return;
}
################################
sub MSwitch_Createnumber1($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
    my $showevents = AttrVal( $Name, "MSwitch_generate_Events", 0 );
    if ( AttrVal( $Name, 'MSwitch_Debug', '0' ) ne "0" ) { $showevents = 1 }
    my $number = AttrVal( $Name, 'MSwitch_RandomNumber', '' ) + 1;
    my $number1 = int( rand($number) );
	$showevents = MSwitch_checkselectedevent( $hash, "RandomNr1" );
    readingsSingleUpdate( $hash, "RandomNr1", $number1, $showevents );
    return;
}

#########################
sub MSwitch_EventBulk($$$$) {
    my ( $hash, $event, $update, $from ) = @_;

    # übergabe event ist altbestand / löschen
    my $name = $hash->{NAME};

    if ( AttrVal( $name, 'MSwitch_generate_Events', '0' ) ne "0" ) {
        $update = 1;
    }

    return if !defined $hash;
    if ( $hash eq "" ) { return; }

    my $evtfull = $hash->{helper}{evtparts}{evtfull};
    $event = $hash->{helper}{evtparts}{event};
    my $evtparts1   = $hash->{helper}{evtparts}{evtpart1};
    my $evtparts2   = $hash->{helper}{evtparts}{evtpart2};
    my $evtparts3   = $hash->{helper}{evtparts}{evtpart3};
    my $Eventupdate = 1;
	my $showevents;
    my $diff        = int(time) - $fhem_started;
    if ( $diff < 60 || $init_done != 1 ) {
        $update      = 0;
        $Eventupdate = 0;
    }

    my $encoded = urlEncode($evtfull);
    FW_directNotify( "FILTER=$name", "#FHEMWEB:WEB", "writeevent('$encoded')",
        "" );

	$showevents = MSwitch_checkselectedevent( $hash, "EVTFULL" );
    readingsSingleUpdate( $hash, "EVTFULL",  $evtfull,$showevents );
	
	$showevents = MSwitch_checkselectedevent( $hash, "EVENT" );	
    readingsSingleUpdate( $hash, "EVENT",    $event ,$showevents);
	
	$showevents = MSwitch_checkselectedevent( $hash, "EVTPART1" );	
    readingsSingleUpdate( $hash, "EVTPART1", $evtparts1,$showevents );
	
	$showevents = MSwitch_checkselectedevent( $hash, "EVTPART2" );	
    readingsSingleUpdate( $hash, "EVTPART2", $evtparts2 ,$showevents);
	
	$showevents = MSwitch_checkselectedevent( $hash, "EVTPART3" );	
    readingsSingleUpdate( $hash, "EVTPART3", $evtparts3 ,$showevents);

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
    foreach my $device (@devices) {

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
		MSwitch_LOG( $name, 6,"-> not $not");
        if ( $not eq "all_events" ) 
		{
            delete( $hash->{NOTIFYDEV} );
            my $argument = ReadingsVal( $name, '.Trigger_Whitelist', '' );
			MSwitch_LOG( $name, 6,"-> argument $argument");
            if ( $argument ne '' ) 
			{
                if ( $argument =~ m/\[(.*)\:(.*)\]/ ) 
				{
					
					$argument =~ s/\$SELF/$name/g;
					
                    $argument = MSwitch_check_setmagic_i( $hash, $argument );
                }
                $hash->{NOTIFYDEV} = $argument;
            }
        }
        elsif ( $not eq "MSwitch_Self" ) 
		{
            $hash->{NOTIFYDEV} = $name;

        }
        else {
            $hash->{NOTIFYDEV} = $not;
        }
    }
    else {
        $hash->{NOTIFYDEV} = 'no_trigger';
    }
}
################################################################
sub MSwitch_clearlog($) {
    my ( $hash, $cs ) = @_;
    my $name = $hash->{NAME};
	my $pfad =  AttrVal( 'global', 'logdir', './log/' ) ;
	open( BACKUPDATEI,  ">".$pfad."/MSwitch_debug_$name.log" );
    print BACKUPDATEI "Starte Log\n";    #
    close(BACKUPDATEI);
    return;
}
################################################################

sub MSwitch_setbridge($$) {
    my ( $hash, $bridge ) = @_;
    my $name = $hash->{NAME};

    if ( !defined $bridge ) {
        $bridge = "";
    }
	
    $bridge =~ s/\[NL\]/\n/g;
    $bridge =~ s/\[SP\]/ /g;

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
	my $pfad =  AttrVal( 'global', 'logdir', './log/' ) ;
	open( my $fh, ">>".$pfad."/MSwitch_debug_$name.log" )|| Log3( $name, 0, "ERROR" );
	print $fh  "$cs\n";
    close $fh;
	my $write =  $cs;
    if ( exists $hash->{helper}{aktivelog}
        && $hash->{helper}{aktivelog} eq 'on' )
    {
        my $encoded = urlEncode($write);
        FW_directNotify( "FILTER=$name", "#FHEMWEB:WEB",
            "writedebug('$encoded')", "" );
    }
    return;
}
##################################
sub MSwitch_LOG($$$) {
    my ( $name, $level, $cs ) = @_;
    my $hash      = $defs{$name};
	
	
	#return if $name ne "Haushaltsstrom";
	
	
    my $showlevel = 6;




    if ( exists $data{MSwitch}{perlteste}{loglevel} ) {

        $showlevel = $data{MSwitch}{perlteste}{loglevel};
    }

    my $logname = $data{MSwitch}{Log};
    if ( $logname eq "all" ) { $logname = $name; }

	if ( $logname ne $name ) {
        return;
    }

    if ((AttrVal( $name, 'MSwitch_Debug', "0" ) eq '2' || AttrVal( $name, 'MSwitch_Debug', "0" ) eq '3')&& ( $level eq $showlevel ) )
    {
		 MSwitch_debug2( $hash, $cs );
        return if $level eq $showlevel;
    }

    $level = 5 if $level eq $showlevel;
    my %UMLAUTE = (
        'Ä' => 'Ae',
        'Ö' => 'Oe',
        'Ü' => 'Ue',
        'ä' => 'ae',
        'ö' => 'oe',
        'ü' => 'ue'
    );
    my $UMLKEYS = join( "|", keys(%UMLAUTE) );

    Log3( $name, $level, $cs );
    return;
}
    
	
	
	
	
##############################################################
	
sub MSwitch_dec($$) {
	my ( $hash, $todec ) = @_;
    my $name    = $hash->{NAME};
	my $org = $todec;

	$todec = MSwitch_dec1( $hash, $todec );

	if ( $todec =~ m/(.*)\[Snippet:(.*?)\](.*)/s )
	{
	$todec = MSwitch_change_snippet( $hash, $todec );

	if ($org ne $todec){	
	$todec = MSwitch_dec1( $hash, $todec );	
	}
	
}
	return $todec;
	
}
	
##############################################################
sub MSwitch_dec1($$) {
    my ( $hash, $todec ) = @_;
    my $name    = $hash->{NAME};
    my $evtfull = "";
    my $event   = "";


   #





    if ( exists $hash->{helper}{aktevent} ) {

        $evtfull = $hash->{helper}{aktevent};
        $event   = $hash->{helper}{aktevent};
    }

#ACHTUNG
    if (!defined $event ) { $event = "";}
    my @eventteile = split( /:/, $event, 3 );

#next EVENT if @eventteile > 3;	# keine 4 stelligen events zulassen
#hier kann optiona eine zusammenfassung eingebaut werde ( zusammenfassung nach der 3 stelle

    if ( !defined $eventteile[0] ) { $eventteile[0] = ""; }
    if ( !defined $eventteile[1] ) { $eventteile[1] = ""; }
    if ( !defined $eventteile[2] ) { $eventteile[2] = ""; }

    my $evtparts1 = $eventteile[0];
    my $evtparts2 = $eventteile[1];
    my $evtparts3 = $eventteile[2];

    my $alias = AttrVal( $evtparts1, 'alias', $evtparts1 );



#todec =~ s/#\[pt\]/./g;

    if ( $todec =~ m/^(\{)(.*)(\})/s ) {

        # ersetzung für perlcode
        $todec =~ s/\n//g;
        $todec =~ s/\[\$SELF:/[$name:/g;
        $todec =~ s/MSwitch_Self/$name/g;
    }
    else 
	{
        # ersetzung für fhemcode
        $todec =~ s/\$NAME/$hash->{helper}{evtparts}{device}/g;
        $todec =~ s/\$SELF/$name/g;
        $todec =~ s/\n//g;
        $todec =~ s/#\[wa\]/|/g;
        $todec =~ s/#\[SR\]/|/g;
        $todec =~ s/MSwitch_Self/$name/g;
        $todec =~ s/\$EVTFULL/$evtfull/g;
        $todec =~ s/\$EVTPART3/$evtparts3/g;
        $todec =~ s/\$EVTPART2/$evtparts2/g;
        $todec =~ s/\$EVTPART1/$evtparts1/g;
        $todec =~ s/\$EVENT/$event/g;
        $todec =~ s/\$ALIAS/$alias/g;
    }

    # ersetzung für beide codes
    # setmagic ersetzung
	
	
	$todec =~ s/\[FREECMD\]//g;

    ###########################################################################
    ## ersetze gruppenname durch devicenamen
    ## test - nur wenn attribut gesetzt noch einfügen

    if ( AttrVal( $name, 'MSwitch_Device_Groups', 'undef' ) ne "undef" ) {
        my $testgroups = $data{MSwitch}{$name}{groups};
        my @msgruppen  = ( keys %{$testgroups} );

        foreach my $testgoup (@msgruppen) {
            my $x = 0;
            while ( $todec =~ m/(.*)(\s|")($testgoup)(\s|")(.*)/ ) {
                $x++;
                last if $x > 10;
                $todec =
                  $1 . $2 . $data{MSwitch}{$name}{groups}{$testgoup} . $4 . $5;
            }
        }
    }

	$todec = MSwitch_check_setmagic_i($hash,$todec);

    if ( $todec =~ m/^\{.*\}$/ )
	{
    }
	elsif( $todec =~ m/\[.*\]/)
	{
		MSwitch_LOG( $name, 6,"FOUND >");
	}
    else 
	{

        my $x = 0;
        while ( $todec =~ m/(.*)\{(.*)\}(.*)/ )
		{

            $x++;    # notausstieg
            last if $x > 20;    # notausstieg
            if ( defined $2 ) {
                my $part1 = $1;
                my $part2 = $2;
                my $part3 = $3;
                my $exec  = "my \$return = " . $part2 . ";return \$return;";
                $exec =~ s/#\[nl\]/\n/g;
                {
                    no warnings;
                    $part2 = eval $exec;
                }
                $todec = $part1 . $part2 . $part3;
            }
        }

    }

    my ( $sec, $min, $hour, $mday, $month, $year, $wday, $yday, $isdst ) =
      localtime( gettimeofday() );
    $month++;
    $year += 1900;
    $wday = 7 if $wday == 0;
	
	#my $mday2=$mday;
	#my $month2=$month;
	if ($mday<10){$mday="0".$mday;}
	if ($month<10){$month="0".$month;}
	
    my $hms = AnalyzeCommand( 0, '{return $hms}' );

    $todec =~ s/\$ARG/$hash->{helper}{timerarag}/g;
    $todec =~ s/\$min/$min/g;
    $todec =~ s/\$hour/$hour/g;
    $todec =~ s/\$sec/$sec/g;
    $todec =~ s/\$month/$month/g;
    $todec =~ s/\$year/$year/g;
    $todec =~ s/\$day/$mday/g;
    $todec =~ s/\$wday/$wday/g;
    $todec =~ s/\$yday/$yday/g;
    $todec =~ s/\$hms/$hms/g;
	
	#$todec =~ s/\$day2/$mday2/g;
	#$todec =~ s/\$month2/$month2/g;
	
	
	
    return $todec;
}

################################################################

sub MSwitch_makefreecmdonly($$) {

    #ersetzungen und variablen für freecmd
    # nur für freecmdperl

    my ( $hash, $cs ) = @_;
    my $name = $hash->{NAME};

    if ( $cs =~ m/(.*)(\{)(.*)(\})/s ) {

        my $evtfull = $hash->{helper}{aktevent};
        my $event   = $hash->{helper}{aktevent};

        my @eventteile = split( /:/, $event, 3 );

        if ( !defined $eventteile[0] ) { $eventteile[0] = ""; }
        if ( !defined $eventteile[1] ) { $eventteile[1] = ""; }
        if ( !defined $eventteile[2] ) { $eventteile[2] = ""; }

        my $evtparts1 = $eventteile[0];
        my $evtparts2 = $eventteile[1];
        my $evtparts3 = $eventteile[2];

        my $firstpart = $1;
        ## variablendeklaration für perlcode / wird anfangs eingefügt
        my $newcode = "";
        if ( exists $hash->{helper}{evtparts}{device} ) {
            $newcode .=
              "my \$NAME = \"" . $hash->{helper}{evtparts}{device} . "\";";
        }
        else {
            $newcode .= "my \$NAME = \"\";";
        }

        $newcode .= "my \$SELF = \"" . $name . "\";\n";
        $newcode .= "my \$EVTPART1 = \"" . $evtparts1 . "\";\n";
        $newcode .= "my \$EVTPART2 = \"" . $evtparts2 . "\";\n";
        $newcode .= "my \$EVTPART3 = \"" . $evtparts3 . "\";\n";
        $newcode .= "my \$EVENT = \"" . $event . "\";\n";
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




#MSwitch_LOG( $name, 6,"FOUNDSTARTfreecmd > $cs");


my $newcode = "";
    if ( $cs =~ m/^(\{)(.*)(\})/s ) {
        my $oldpart = $2;
        

        my $event   = $hash->{helper}{aktevent};
		if (!defined $event ){$event ="";}
		my $evtfull = $event;

        my @eventteile = split( /:/, $event, 3 );

#next EVENT if @eventteile > 3;	# keine 4 stelligen events zulassen
#hier kann optiona eine zusammenfassung eingebaut werde ( zusammenfassung nach der 3 stelle

        if ( !defined $eventteile[0] ) { $eventteile[0] = ""; }
        if ( !defined $eventteile[1] ) { $eventteile[1] = ""; }
        if ( !defined $eventteile[2] ) { $eventteile[2] = ""; }

        my $evtparts1 = $eventteile[0];
        my $evtparts2 = $eventteile[1];
        my $evtparts3 = $eventteile[2];

        if ( exists $hash->{helper}{evtparts}{device} ) {
			
			if ( $cs !~ m/my \$NAME = \"\"/ ){
			
            $newcode .="my \$NAME = \"" . $hash->{helper}{evtparts}{device} . "\";\n";
			}
	  }
        else 
		{
			
			if ( $cs !~ m/my \$NAME = \"\"/ ){
			
            $newcode .= "my \$NAME = \"\";\n";
			}
        }
		
		
		
		
		
       if ( $cs !~ m/my \$SELF =/ ){ $newcode .= "my \$SELF = \"" . $name . "\";\n";}
	if ( $cs !~ m/my \$EVTPART1 =/ ){$newcode .= "my \$EVTPART1 = \"" . $evtparts1 . "\";\n";}
if ( $cs !~ m/my \$EVTPART2 =/ ){$newcode .= "my \$EVTPART2 = \"" . $evtparts2 . "\";\n";}
if ( $cs !~ m/my \$EVTPART3 =/ ){$newcode .= "my \$EVTPART3 = \"" . $evtparts3 . "\";\n";}
if ( $cs !~ m/my \$EVENT =/ ){$newcode .= "my \$EVENT = \"" . $event . "\";\n";}
        if ( $cs !~ m/my \$EVTFULL =/ ){$newcode .= "my \$EVTFULL = \"" . $evtfull . "\";\n";}
        $newcode .= $oldpart;
		
		
		
        $cs = "{\n$newcode}";

        # entferne kommntarzeilen
        $cs =~ s/#\[SR\]/[SR]/g;


#MSwitch_LOG( $name, 6,"FOUNDendefreecmd > $cs");



        my $newcs = "";
        my @lines = split( /\n/, $cs );
        foreach my $lin (@lines) {
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
    my $futurelevel  = AttrVal( $name, 'MSwitch_Futurelevel', '0' );
	my $incomming = $msg;
    # setmagic ersetzung



	$msg =~ s/\[Snippet:/[Snippet/g;

	my $org = $msg;

	my $x = 0;
	while ( $org =~ m/(\[([ari]:)?([a-zA-Z\d._]+):([a-zA-Z\d._\/-]+)(:(t|sec|i|[dr]\d?))?\])/ )
	{

	$x++;    # notausstieg notausstieg
    last if $x > 20;    # notausstieg notausstieg
	
	my $all = $1;
	my $praefix = $2;
	my $targdevice = $3;
	my $targreadname = $4;
	my $suffix = $5;
	my $zielhash = $defs{$3};
	my $val;

	 if(!$praefix || $praefix eq "r:") 
		{
		  my $r = $zielhash->{READINGS};
		  
		  if($suffix && ($suffix eq ":t" || $suffix eq ":sec")) 
		  {
			#return $all if (!$r || !$r->{$n});
			$val = $r->{$targreadname}{TIME};
			$val = int(gettimeofday()) - time_str2num($val) if($suffix eq ":sec");
		  }
		  else
		  {
		  $val = $r->{$targreadname}{VAL} ;
		  }
		}
	 
	$val = $hash->{$targreadname}  if (defined $praefix && $praefix eq "i:");
	$val = $attr{$targdevice}{$targreadname} if ((defined $praefix && $praefix eq "a:") && $attr{$targdevice});
		
	if($suffix && $suffix =~ /:d|:r|:i/ && $val =~ /(-?\d+(\.\d+)?)/) 
		{
		  $val = $1;
		  $val = int($val)                         if($suffix eq ":i" );
		  $val = round($val, defined($1) ? $1 : 1) if($suffix =~ /^:r(\d)?/);
		  $val = round($val, $1)                   if($suffix =~ /^:d(\d)/); #100753
		}
			
	$val ="undef" if ( !defined $val || $val eq "");
	
	
	$val =~ s/\$SELF/$name/g;
	$org =~s/(\[([ari]:)?([a-zA-Z\d._]+):([a-zA-Z\d._\/-]+)(:(t|sec|i|[dr]\d?))?\])/$val/;
	}


$org =~ s/\[Snippet/[Snippet:/g;

return $org;
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
    my $savecmds =
      AttrVal( $name, 'MSwitch_DeleteCMDs', $deletesavedcmdsstandart );
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

    my @inhalt = split( /,/, $data{MSwitch}{$Name}{groups}{$gruppe} );

    # suche alle geräte
    my @alldevices    = ();
    my $anzahldevices = 0;    # anzahl der geräte
	
	    foreach my $dev (@inhalt) 
	{
		my @tmpdevices = devspec2array($dev);
        push( @alldevices, @tmpdevices );
	}
	
	
	
	my @finaldevices = ();
		
	foreach my $dev (@alldevices) 
		{
			if (defined($defs{$dev})) 
				{
				push( @finaldevices, $dev );
				}
			else
				{
				push( @finaldevices, "$dev - (Device not defined !)");		
				}
	
		}
	
	
    # foreach my $dev (@inhalt) 
	# {
		
		
		# if (defined($defs{$dev}))
		# {
        # my @tmpdevices = devspec2array($dev);
        # push( @alldevices, @tmpdevices );
		# }
		
      # # my @tmpdevices = devspec2array($dev);
      # # push( @alldevices, @tmpdevices );
	
    # }




    my @unfilter = ();
    foreach my $aktdevice (@finaldevices) {
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

        # escapen
        $allkeys =~ s/\[/\\\[/g;
        $allkeys =~ s/\{/\\\{/g;
        $allkeys =~ s/\./\\\./g;
        $allkeys =~ s/\$/\\\$/g;
        $allkeys =~ s/\*/\\\*/g;
        $allkeys =~ s/\+/\\\+/g;
        $allkeys =~ s/\(/\\\(/g;
        $allkeys =~ s/\)/\\\)/g;

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
    foreach my $dev (@inhalt) 
	{
		my @tmpdevices = devspec2array($dev);
        push( @alldevices, @tmpdevices );
	}
		
	my @finaldevices = ();
		
	foreach my $dev (@alldevices) 
		{
			if (defined($defs{$dev})) 
				{
				push( @finaldevices, $dev );
				}
			else
				{
				push( @finaldevices, "$dev - (Device not defined !)");		
				}
	
		}
    my $outfile = join( '\n', @finaldevices );
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
          || MSwitch_LOG( "test", 1, "ERROR " . $adress );
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
    my ($hash) = @_;
    my $Name = $hash->{NAME};

    my $param = {
        url     => "$preconffile",
        timeout => 5,
        hash    => $hash
        ,    # Muss gesetzt werden, damit die Callback funktion wieder $hash hat
        method => "GET",    # Lesen von Inhalten
        header => "User-Agent: None\r\nAccept: application/json"
        ,                   # Den Header gemäß abzufragender Daten ändern
        callback =>
          \&X_ParseHttpResponse # Diese Funktion soll das Ergebnis dieser HTTP Anfrage bearbeiten
    };

    my ( $err, $preconf ) = HttpUtils_BlockingGet($param);
    if (
        length($err) >
        1 )    # wenn ein Fehler bei der HTTP Abfrage aufgetreten ist
    {
        MSwitch_LOG $Name, 1, "$err";
        return;
    }

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
    my $Name     = $hash->{NAME};
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

sub MSwitch_notifyset($$) {
    my ( $hash, $arg1 ) = @_;
    my $Name   = $hash->{NAME};
    my $string = $arg1;

    if ( $string eq "all_events" ) {
        delete( $hash->{NOTIFYDEV} );
    }
    else {
        $hash->{NOTIFYDEV} = $string;
    }

    %ntfyHash = ();
    return $string;
}
##########################################
sub MSwitch_reloaddevices($$) {
    my ( $hash, $arg1 ) = @_;
    my $Name   = $hash->{NAME};
    my $string = '';
    my @devs;
    my @devscmd;
    my $aVal = $arg1;
    my @gset = split( /\[nl\]/, $aVal );
    foreach my $line (@gset) {
        my @lineset = split( /->/, $line );
        $lineset[0] =~ s/ //g;
        next if $lineset[0] eq "";
        push( @devs, $lineset[0] );
        $data{MSwitch}{$Name}{groups}{ $lineset[0] } = $lineset[1];
        $string = MSwitch_makegroupcmd( $hash, $lineset[0] );
        push( @devscmd, $string );
    }

    my $newnames = join( "[|]", @devs );
    my $newsets  = join( "[|]", @devscmd );
    $string = "$newnames" . "[TRENNER]" . "$newsets";
    return $string;
}

#########################################
sub MSwitch_reloadreadings($$) {
    my ( $hash, $arg1 ) = @_;
    my $Name = $hash->{NAME};
    #################
    my $devhash     = $defs{$arg1};           #name des devices
    my $testreading = $devhash->{READINGS};
    my @areadings =( keys %{$testreading} );    # enthält alle readings des devices
    my $readings = join( "[|]", sort @areadings );
    #####################
    return $readings;
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
    my $name        = $hash->{NAME};
    my $showevents  = AttrVal( $name, "MSwitch_generate_Events", 0 );
    my $maxreadings = AttrVal( $name, "MSwitch_ExtraktHTTP_max", '1000' );
    if ( AttrVal( $name, 'MSwitch_Debug', '0' ) ne "0" ) { $showevents = 1 }
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
    if (
        length($err) >
        1 )    # wenn ein Fehler bei der HTTP Abfrage aufgetreten ist
    {
        MSwitch_LOG $name, 1, "$err";
		
		$showevents = MSwitch_checkselectedevent( $hash, "FullHTTPResponse" );
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

    readingsBeginUpdate($hash);

    foreach my $line (@gset) {
        my @lineset    = split( /->/, $line );
        my $reading    = $lineset[0];
        my $reg        = $lineset[1];
        my $regex      = qr/$reg/;
        my $regexblank = $reg;

        fhem( "deletereading $name $reading" . "_.*" );

        if ( my @matches = $data =~ /$regex/sg ) {
            my $arg = join( "#[trenner]", @matches );

            # mapping
            if ( $mapss ne "no_mapping" ) {
                foreach my $mapping (@maps) {
                    my @mapset = split( /->/, $mapping );
                    my $org    = $mapset[0];
                    my $ers    = $mapset[1];

                    if ( defined $ers ) {
                        $arg =~ s/$org/$ers/g;
                    }
                    else {
						$ers ="";
                        $arg =~ s/$org/$ers/g;
                    }
                }
            }

            my @newmatch = split( /#\[trenner\]/, $arg );
            $arg = join( ",", @newmatch );
            my $x = 0;
            if ( @newmatch > 1 && $reading ne "FullHTTPResponse" ) {
                foreach my $match (@newmatch) {
                    last if $x > $maxreadings;
                    readingsBulkUpdate( $hash, $reading . "_" . $x, $match,1 );
                    $x++;
                }
            }

            if ( $reading eq "FullHTTPResponse" ) {
                $arg =
                    "for more details \"get $name HTTPresponse\"    ..... "
                  . substr( $arg, 0, 150 )
                  . " .....";
            }
            readingsBulkUpdate( $hash, $reading, $arg,1 );
        }
        else {
            MSwitch_LOG $name, 5, "no match found for regex $reg";
            readingsBulkUpdate( $hash, $reading, "no match" ,1);
        }
    }
    readingsEndUpdate( $hash, $showevents );
    return;
}

##############################################
sub MSwitch_PerformGetRequest($$) {
    my ( $hash, $data ) = @_;
    my $name = $hash->{NAME};

    my $showevents  = AttrVal( $name, "MSwitch_generate_Events", 0 );
    my $maxreadings = AttrVal( $name, "MSwitch_ExtraktHTTP_max", '1000' );
    if ( AttrVal( $name, 'MSwitch_Debug', '0' ) ne "0" ) { $showevents = 1 }
    $data{MSwitch}{$name}{HTTPresponse} = $data;
    my $mapss = AttrVal( $name, "MSwitch_ExtraktHTTPMapping", "no_mapping" );
    my @maps;
    @maps = split( /\n/, $mapss );
    my $regex =
      AttrVal( $name, "MSwitch_ExtraktfromHTTP", "FullGETResponse->(.*)" );
    my @gset = split( /\n/, $regex );

    readingsBeginUpdate($hash);

    foreach my $line (@gset) {
        my @lineset    = split( /->/, $line );
        my $reading    = $lineset[0];
        my $reg        = $lineset[1];
        my $regex      = qr/$reg/;
        my $regexblank = $reg;

        fhem( "deletereading $name $reading" . "_.*" );

        if ( my @matches = $data =~ /$regex/sg ) {
            my $arg = join( "#[trenner]", @matches );

            # mapping
            if ( $mapss ne "no_mapping" ) {
                foreach my $mapping (@maps) {
                    my @mapset = split( /->/, $mapping );
                    my $org    = $mapset[0];
                    my $ers    = $mapset[1];
                    $arg =~ s/$org/$ers/g if ( defined $ers );
                }
            }

            my @newmatch = split( /#\[trenner\]/, $arg );
            $arg = join( ",", @newmatch );
            my $x = 0;
            if ( @newmatch > 1 && $reading ne "FullGETResponse" ) {
                foreach my $match (@newmatch) {
                    last if $x > $maxreadings;
                    readingsBulkUpdate( $hash, $reading . "_" . $x, $match );
                    $x++;
                }
            }

            if ( $reading eq "FullGETResponse" ) {
                $arg =
                    "for more details \"get $name HTTPresponse\"    ..... "
                  . substr( $arg, 0, 150 )
                  . " .....";
            }
            readingsBulkUpdate( $hash, $reading, $arg );
        }
        else {
            MSwitch_LOG $name, 5, "no match found for regex $reg";
            readingsBulkUpdate( $hash, $reading, "no match" );
        }
    }
    readingsEndUpdate( $hash, $showevents );
    return;
}

###########################################################

sub X_ParseHttpResponse($) {
    my ( $param, $err, $data ) = @_;
    my $hash = $param->{hash};
    my $name = $hash->{NAME};
my $showevents = MSwitch_checkselectedevent( $hash, "fullResponse" );
    if ( $err ne "" )    # wenn ein Fehler bei der HTTP Abfrage aufgetreten ist
    {
        MSwitch_LOG $name, 1,
            "error while requesting "
          . $param->{url}
          . " - $err";    # Eintrag fürs Log
		

        readingsSingleUpdate( $hash, "fullResponse", "ERROR", 0 )
          ;               # Readings erzeugen
    }
    elsif ( $data ne ""
      ) # wenn die Abfrage erfolgreich war ($data enthält die Ergebnisdaten des HTTP Aufrufes)
    {
        Log3 $name, 1,
          "url " . $param->{url} . " returned: $data";    # Eintrag fürs Log
            # An dieser Stelle die Antwort parsen / verarbeiten mit $data
        readingsSingleUpdate( $hash, "fullResponse", $data, 0 )
          ;    # Readings erzeugen
    }
}

#######################

sub MSwitch_Countdown_new(@) {
    my ($countdevice) = @_;
    my ( $name, $oldtime ) = split( /\|/, $countdevice );
    my $hash     = $defs{$name};
    my $jump     = AttrVal( $name, "MSwitch_Delay_Count", 10 );
    my $fulltime = 0;

    readingsBeginUpdate($hash);
    foreach my $countdown ( keys %{ $hash->{helper}{countdown} } ) {
		
		my $showevents = MSwitch_checkselectedevent( $hash, $countdown );
	
        $hash->{helper}{countdown}{$countdown} =
          $hash->{helper}{countdown}{$countdown} - $jump;
        if ( $hash->{helper}{countdown}{$countdown} <= 0 ) {
            delete( $hash->{helper}{countdown}{$countdown} );
            my $format =
              AttrVal( $name, 'MSwitch_Format_Lastdelay', "HH:MM:SS" );
            $format =~ s/HH/00/g;
            $format =~ s/MM/00/g;
            $format =~ s/SS/00/g;
            $format =~ s/ss/0/g;
            readingsBulkUpdate( $hash, $countdown, $format,1 );
            next;
        }

        my $sek      = $hash->{helper}{countdown}{$countdown};
        my $h        = int( $sek / 3600 );
        my $rest     = $sek % 3600;
        my $min      = int( $rest / 60 );
        my $sekunden = $rest % 60;
        $h        = sprintf( "%2.2d", $h );
        $min      = sprintf( "%2.2d", $min );
        $sekunden = sprintf( "%2.2d", $sekunden );
        my $format = AttrVal( $name, 'MSwitch_Format_Lastdelay', "HH:MM:SS" );
        $format =~ s/HH/$h/g;
        $format =~ s/MM/$min/g;
        $format =~ s/SS/$sekunden/g;
        $format =~ s/ss/$sek/g;
        readingsBulkUpdate( $hash, $countdown, $format ,1);
        my $fulltimeincomming = $fulltime;
        $fulltime = $fulltime + $hash->{helper}{countdown}{$countdown};
    }

    readingsEndUpdate( $hash, 1 );

    if ( $fulltime > 0 ) {
        $hash->{helper}{countdownstatus} = "aktiv";
        # starte neuen timer nach $jump sekunden
        my $istzeit  = gettimeofday();
        my $diff     = $istzeit - $oldtime;
        my $timecond = $istzeit + $jump;
        if ( $diff > 0 ) { $timecond = $timecond - $diff; }
        $hash->{helper}{countdownnexttime} = $timecond;
        my $msg = "$name|$timecond";
        InternalTimer( $timecond, "MSwitch_Countdown_new", $msg );
    }
    else {
        $hash->{helper}{countdownstatus} = "inaktiv";
        delete( $hash->{helper}{countdownnexttime} );
    }
    return;
}



#######################
#######################
#######################
sub HILFSROUTINEN() { }
#######################
#######################
#######################

sub timetoseconds(@) {
    my ( $name, $string ) = @_;
    return if $string eq "";
    my $x = 0;
    while ( $string =~ m/(.*?)(\d{2}:\d{2}:\d{2})(.*)/ ) {
        $x++;    # notausstieg notausstieg
        last if $x > 20;    # notausstieg notausstieg
        my $firstpart = $1;
        my $lastpart  = $3;
        my $middle    = $2;
        my $hdel      = ( substr( $middle, 0, 2 ) ) * 3600;
        my $mdel      = ( substr( $middle, 3, 2 ) ) * 60;
        my $sdel      = ( substr( $middle, 6, 2 ) ) * 1;
        my $code      = $hdel + $mdel + $sdel;
        $string = $firstpart . $code . $lastpart;
    }
    return $string;
}
 
#######################

sub MSwitch_Get_Devices(@) {
    my ( $hash, ) = @_;
    my @found_devices = devspec2array("TYPE=.*");
    my $arg = join( ",", @found_devices );
    return $arg;
}


########################

sub MSwitch_checkselectedevent($$) {
my ( $hash, $tocheck ) = @_;
return 1 if $tocheck eq "state";
my $name     = $hash->{NAME};
my $showevents = AttrVal( $name, "MSwitch_generate_Events", 0 );
return 1 if $showevents == 1;


if ( exists  $hash->{helper}{selectedevents}{$tocheck} ){
$showevents = $hash->{helper}{selectedevents}{$tocheck} == 1? 1:0 ;

}
return $showevents ;
}

########################

sub MSwitch_assoziation($){
	my ( $hash ) = @_;
	my $Name     			= $hash->{NAME};
	my $trigger 			= ReadingsVal( $Name, '.Trigger_device', 'undef' );
	my $triggercond = MSwitch_Load_Tcond($hash);
	my $triggerwhitelist 	= ReadingsVal( $Name, '.Trigger_Whitelist', 'undef' );
	my @affecteddevices =  MSwitch_Load_Details($hash);
	my $conditions;
	my $assos;
	MSwitch_LOG( $Name, 6, "--- Execute sub MSwitch_assoziation --- L:" . __LINE__ );

	if ($triggercond ne "undef")
	{
		$conditions.=$triggercond;
	}
	
	if ($trigger eq "all_events")
	{
		if ($triggerwhitelist ne "undef")
		{
			my @found_devices = devspec2array($triggerwhitelist);
			$assos.= "@found_devices"." ";
		}
		else
		{
			my @found_devices = devspec2array("NAME=.*");
			$assos.= "@found_devices"." ";
		}
	}
	else
	{
		$assos.=$trigger." ";
	}
	
	foreach (@affecteddevices) 
	{
        my @devicesplit = split( /#\[NF\]/, $_ );
		my @affectedname = split( /-/,$devicesplit[0] );
		
		my $cond1 = $devicesplit[9];
        my $cond2 = $devicesplit[10];
		
		if ($cond1 ne "undef" && $cond1 ne "")
		{
			$conditions.=$cond1;
		}
		
		if ($cond2 ne "undef" && $cond2 ne "")
		{
			$conditions.=$cond2;
		}
		
		if ($affectedname[0] ne "FreeCmd")
			{
				$assos.=$affectedname[0]." ";
				next;
			}

		if ($affectedname[0] eq "FreeCmd")
			{
				my $summary = $devicesplit[1] . " " . $devicesplit[3];
				$summary .= " ".$devicesplit[3] . " " . $devicesplit[4];
				$summary =~ s/\$SELF/$Name/g;
				my $x = 0;
				while ( $summary =~ m/(.*)(set#\[sp\])(.*?)(#\[sp\])(.*)/ ) 
				{
					$x++;
					last if $x > 10;
					$assos.=$3." ";
					$summary = $1." CHANGED ".$5;
				}	
			}
	}

	if ($conditions ne "")
	{
		$conditions =~ s/#\[dp\]/:/g;
		$conditions =~ s/#\[sp\]/ /g;
		my $y = 0;
				while ( $conditions =~ m/(\[([ari]:)?([a-zA-Z\d._]+):([a-zA-Z\d._\/-]+)(:(t|sec|i|[dr]\d?))?\])/ ) 
				{
					$y++;
					last if $y > 10;
					$assos.=$3." ";
					$conditions =~ s/$3:$4/CHANGED/g;
				}
	}
	delete $hash->{DEF};
	$assos =~ s/$Name //g;
	chop($assos);
	my @arrayassos = split( / /,$assos );
	my %saw;
	my @out = grep(! $saw{$_}++, @arrayassos);  
	readingsSingleUpdate( $hash, ".associatedWith", "@out", 0 );
	return;
	}
######################################################

sub MSwitch_Set_deletefiles($@)
{
my ( $hash, $name, $cmd, $arg1 ) = @_;
my @entris = split (/,/,$arg1);
my $pfad =  AttrVal( 'global', 'backupdir', $restoredirn ) ;
$pfad.="/MSwitch/";
opendir(DIR, $pfad);
foreach (@entris){
my $delete = $pfad.'/'.$_;
unlink($delete);
	}
closedir(DIR);
return;
}

######################################################
sub MSwitch_Set_extractbackup($@){
	my ( $hash, $name, $cmd, $arg1 ) = @_;

    my $string  = $arg1;
    my $Zeilen  = "";
    my @devicenames;
	my $pfad =  AttrVal( 'global', 'backupdir', $restoredirn ) ;
	$pfad.="/MSwitch/";

    open( BACKUPDATEI, "<" . $pfad . $string )
      || return "no Backupfile found!\n";

    while (<BACKUPDATEI>) {
        $Zeilen = $Zeilen . $_;
    }
    close(BACKUPDATEI);
	
	$Zeilen=MSwitch_Asc($Zeilen);
	
	my @found = split( /\n/, $Zeilen );
	my $names;
	foreach (@found) {
        if ( $_ =~ m/#N -> (.*)/ )    # setreading
        {
            $Zeilen = $1;
            $Zeilen =~ s/#\[nl\]/\n/g;
            $names.= $Zeilen." ";
        }
    }
	return "$names";
}


######################################################
sub MSwitch_Set_extractbackup1($@){
	my ( $hash, $name, $cmd, $arg1 ,$arg2 ) = @_;
    my $string  = $arg1;
	my $Zeilen  = "";
    my @devicenames;
	my $pfad =  AttrVal( 'global', 'backupdir', $restoredirn ) ;
	$pfad.="/MSwitch/";
    open( BACKUPDATEI, "<" . $pfad . $string )
      || return "no Backupfile found!\n";

    while (<BACKUPDATEI>) {
        $Zeilen.= $_;
    }
	($Zeilen) =~ s/([a-fA-F0-9]{2})?/chr(hex $1)/eg;
	my @found = split( /\n/, $Zeilen );
	my $found =0;
	my $result ="";
	
	foreach (@found) 
	{
        if ( $_ =~ m/#N -> $arg2/ )    # setreading
        {
			$result.= "#T -> Einzelrestore"."\n";
			$result.= "#N -> $arg2"."\n";
			$found =1;
			next;
        }
		elsif  ( $_ =~ m/#N -> (.*)/ )
		{
			$found = 0;
		}
		next if ($found ==0);
		$result.= $_."\n";
    }
	
	($result) =~ s/(.|\n)/sprintf("%02lx ", ord $1)/eg;
    $result =~ s/ //g;
	return "$result";
}

######################################################
sub MSwitch_Hex($){
	my ($savedetaills) = @_;
	($savedetaills) =~ s/(.|\n)/sprintf("%02lx", ord $1)/eg;
	return $savedetaills;
	
}
 
######################################################
sub MSwitch_Asc($){
	my ($org)=@_;
	
	 if ( $org =~ m/[G-Zg-z]/ ) {
		 return $org; 
	 }
	
	my (@test) = $org =~ m/(\w{2})/g;
    my $savedetails ="";
	#my $Name = "test";
    foreach (@test) {
        $savedetails  .=  chr( hex $_ );
    }
	
	$savedetails =~ s/#\[se\]/;/g;
	$savedetails =~ s/#\[ti\]/~/g;
	$savedetails =~ s/#\[dp\]/:/g;
	
	
	$savedetails =~ s/#\[EK1\]/(/g;
	$savedetails =~ s/#\[EK2\]/)/g;
	$savedetails =~ s/#\[pr\]/%/g;

	return $savedetails;
}

######################################################
sub MSwitch_Save_Details($$){
my ($hash,$savedetails)=@_;
readingsSingleUpdate( $hash, ".Device_Affected_Details_new", MSwitch_Hex($savedetails), 1 );
return;
}
######################################################
sub MSwitch_Load_Details($){
my ($hash)=@_;
my $Name     			= $hash->{NAME};
my $test = ReadingsVal( $Name, '.Device_Affected_Details_new', 'no_device' );

return if $test eq "no_device";

if (exists $data{MSwitch}{$Name}{Device_Affected_Details} )
	{
		my $data = $data{MSwitch}{$Name}{Device_Affected_Details};
		my @testidsdev = split( /#\[ND\]/, $data );
		return @testidsdev ;
	}
else 
	{
	my $data = 	MSwitch_Asc($test);
	$data{MSwitch}{$Name}{Device_Affected_Details}=$data;
	my @testidsdev = split( /#\[ND\]/, $data  );
	
	
	return @testidsdev;
	}
return;
}
######################################################
sub MSwitch_Load_Tcond($){
my ($hash)=@_;
my $Name = $hash->{NAME};
my $data;

	if (exists $data{MSwitch}{$Name}{TCond} )
	{
		 $data = $data{MSwitch}{$Name}{TCond};
		return $data ;
	}
else 
	{
	my $test = ReadingsVal( $Name, '.Trigger_condition', '' );
	 $data = 	MSwitch_Asc($test);
	$data{MSwitch}{$Name}{TCond}=$data;
	return $data ;
	}
return $data;
}
####################################################




1;