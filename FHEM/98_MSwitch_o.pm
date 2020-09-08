# $Id: 98_MSwitch.pm 21264 2020-02-24 04:44:59Z Byte09 $
# 98_MSwitch.pm
#
# copyright #####################################################
#
# 98_MSwitch.pm
#
# written by Byte09
# Maintained by Byte09
#
# This file is part of FHEM.
#
# FHEM is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# FHEM is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with FHEM.  If not, see <http://www.gnu.org/licenses/>.
#################################################################
#
# MSwitchtoggle Suchmuster ab V3 [Befehl 1,Befehl 2,Befehl 3]:[1,2,3]:[reading]
#                                [auszuführender Befehl]:[Inhalt reading]:[Name des readings]
#
#################################################################
# Todo's:  CommandSet() statt fhem()
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
##---------------------------------------------------------------
#
#################################################################

package main;
use Time::Local;
use strict;
use warnings;
use POSIX;
use SetExtensions;
use LWP::Simple;

use HttpUtils;

#use utf8;

#use utf8;

my $updateinfo  = "";    # wird mit info zu neuen versionen besetzt
my $generalinfo = "";    # wird mit aktuellen informationen besetzt
my $updateinfolink =
"https://raw.githubusercontent.com/Byte009/FHEM-MSwitch/master/updateinfo.txt";
my $preconffile =
"https://raw.githubusercontent.com/Byte009/MSwitch_Addons/master/MSwitch_Preconf.conf";

my $templatefile =
  "https://raw.githubusercontent.com/Byte009/MSwitch_Templates/master/";

my $helpfile    = "www/MSwitch/MSwitch_Help.txt";
my $helpfileeng = "www/MSwitch/MSwitch_Help_eng.txt";
my $support =
"Support Whatsapp: https://chat.whatsapp.com/IOr3APAd6eh6tVYsHpbDqd Mail: Byte009\@web.de";
my $autoupdate   = 'on';     # off/on
my $version      = '4.03';
my $wizard       = 'on';     # on/off
my $importnotify = 'on';     # on/off
my $importat     = 'on';     # on/off
my $vupdate      = 'V2.01'
  ; # versionsnummer der datenstruktur . änderung der nummer löst MSwitch_VUpdate aus .
my $savecount = 50
  ; # anzahl der zugriff im zeitraum zur auslösung des safemodes. kann durch attribut überschrieben werden .
my $savemodetime       = 10000000;    # Zeit für Zugriffe im Safemode
my $rename             = "on";        # on/off rename in der FW_summary möglich
my $standartstartdelay = 30
  ; # zeitraum nach fhemstart , in dem alle aktionen geblockt werden. kann durch attribut überschrieben werden .

#my $eventset = '0';
my $deletesavedcmds = 1800
  ; # zeitraum nachdem gespeicherte devicecmds gelöscht werden ( beschleunugung des webinterfaces )
my $deletesavedcmdsstandart = "automatic"
  ; # standartverhalten des attributes "MSwitch_DeleteCMDs" <manually,nosave,automatic>

# standartlist ignorierter Devices . kann durch attribut überschrieben werden .
my @doignore =
  qw(notify allowed at watchdog doif fhem2fhem telnet FileLog readingsGroup FHEMWEB autocreate eventtypes readingsproxy svg cul);
my $startmode   = "Notify";    # Startmodus des Devices nach Define
my $wizardreset = 3600;        #Timeout für Wizzard

# degug
#my $ip = qx(hostname -I);
#chop($ip);
#chop($ip);
my $debugging = "0";

#$debugging = "0" if $ip ne "192.168.178.109";
$data{MSwitch}{udateinfolink} = $updateinfolink;
$data{MSwitch}{version}       = $version;

$updateinfo = get($updateinfolink);

$updateinfo =~ s/\n/[LINE]/g;

my @uinfos = split( /\[LINE\]/, $updateinfo );

$data{MSwitch}{Version}            = $uinfos[1];
$data{MSwitch}{Updateinformation}  = $uinfos[2];
$data{MSwitch}{Generalinformation} = $uinfos[3];

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
sub MSwitch_backup_done($);
sub MSwitch_checktrigger(@);
sub MSwitch_Cmd(@);
sub MSwitch_toggle($$);
sub MSwitch_Getconfig($);
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
sub MSwitch_sort;
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
    "filter_trigger"    => "noArg",
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
    "restore_MSwitch_Data" => "noArg",
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
    $hash->{FW_summaryFn}      = "MSwitch_summary";
    $hash->{NotifyOrderPrefix} = "45-";
    $hash->{AttrList} =
        "  disable:0,1"
      . "  disabledForIntervals"
      . "  MSwitch_Language:EN,DE"
      . "  stateFormat:textField-long"
      . "  MSwitch_Comments:0,1"
      . "  MSwitch_Read_Log:0,1"
      . "  MSwitch_Hidecmds"
      . "  MSwitch_Help:0,1"
      . "  MSwitch_Debug:0,1,2,3,4"
      . "  MSwitch_Expert:0,1"
      . "  MSwitch_Delete_Delays:0,1,2"
      . "  MSwitch_Include_Devicecmds:0,1"
      . "  MSwitch_Modul_Mode:0,1"
      . "  MSwitch_generate_Events:0,1"
      . "  MSwitch_Include_Webcmds:0,1"
      . "  MSwitch_Include_MSwitchcmds:0,1"
      . "  MSwitch_Activate_MSwitchcmds:0,1"
      . "  MSwitch_Lock_Quickedit:0,1"
      . "  MSwitch_Ignore_Types:textField-long "
      . "  MSwitch_Reset_EVT_CMD1_COUNT"
      . "  MSwitch_Reset_EVT_CMD2_COUNT"
      . "  MSwitch_Trigger_Filter"
      . "  MSwitch_Extensions:0,1"
      . "  MSwitch_Inforoom"
      . "  MSwitch_DeleteCMDs:manually,automatic,nosave"
      . "  MSwitch_Mode:Full,Notify,Toggle,Dummy"
      . "  MSwitch_Condition_Time:0,1"
      . "  MSwitch_Selftrigger_always:0,1"
      . "  MSwitch_RandomTime"
      . "  MSwitch_RandomNumber"
      . "  MSwitch_Safemode:0,1"
      . "  MSwitch_Startdelay:0,10,20,30,60,90,120"
      . "  MSwitch_Wait"
      . "  MSwitch_Sequenz:textField-long "
      . "  MSwitch_Sequenz_time"
      . "  MSwitch_setList:textField-long "
      . "  setList:textField-long "
      . "  readingList:textField-long "
      . "  MSwitch_Event_Id_Distributor:textField-long "
      . "  MSwitch_Eventhistory:0,1,2,3,4,5,10,20,30,40,50,60,70,80,90,100,150,200"
      . "  MSwitch_Device_Groups:textField-long"
      . "  MSwitch_ExtraktfromHTTP:textField-long"
      . "  MSwitch_ExtraktHTTPMapping:textField-long"
      . "  MSwitch_Switching_once:0,1"
      . "  textField-long "

      . $readingFnAttributes;
    $hash->{FW_addDetailToSummary} = 0;

    #
}
####################
sub MSwitch_Rename($) {

    my ( $new_name, $old_name ) = @_;
    my $hash_new = $defs{$new_name};

    my $hashold = $defs{$new_name}{$old_name};
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
sub MSwitch_Shutdown($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};

    # speichern gesetzter delays
    my $delays = $hash->{helper}{delays};
    my $x      = 1;
    my $seq;
    foreach my $seq ( keys %{$delays} ) {
        readingsSingleUpdate( $hash, "SaveDelay_$x", $seq, 1 );
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
    my @areadings =
      qw(.Device_Affected .Device_Affected_Details .Device_Events .First_init .Trigger_Whitelist .Trigger_cmd_off .Trigger_cmd_on .Trigger_condition .Trigger_off .Trigger_on .Trigger_time .V_Check last_exec_cmd Trigger_device Trigger_log last_event state .sysconf Sys_Extension)
      ;    #alle readings
    my $cs = "attr $new_name disable 1";
    my $errors = AnalyzeCommandChain( undef, $cs );
    if ( defined($errors) ) {
        MSwitch_LOG( $new_name, 1, "ERROR $cs" );
    }
    foreach my $key (@areadings) {
        my $tmp = ReadingsVal( $old_name, $key, 'undef' );
        fhem( "setreading " . $new_name . " " . $key . " " . $tmp );
    }
    MSwitch_LoadHelper($hash);
    return;
}

####################
sub MSwitch_summary($) {
    my ( $wname, $name, $room, $test1 ) = @_;
    my $hash     = $defs{$name};
    my $testroom = AttrVal( $name, 'MSwitch_Inforoom', 'undef' );
    my $mode     = AttrVal( $name, 'MSwitch_Mode', 'Notify' );
    if ( exists $hash->{helper}{mode} && $hash->{helper}{mode} eq "absorb" ) {
        return "Device ist im Konfigurationsmodus.";
    }

    my @areadings = ( keys %{$test1} );

    # if ( !grep /group/, @areadings ) {
    # return;
    # }
    return if !grep /group/, @areadings;
    return if $testroom ne $room;

    my $info = AttrVal( $name, 'comment', 'No Info saved at ATTR omment' );
    my $image    = ReadingsVal( $name, 'state', 'undef' );
    my $ret      = '';
    my $devtitle = '';
    my $option   = '';
    my $html     = '';
    my $triggerc = 1;
    my $timer    = 1;
    my $trigger  = ReadingsVal( $name, 'Trigger_device', 'undef' );
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
    my $triggertime  = ReadingsVal( $name, 'Trigger_device', 'not defined' );
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

    if ( $mode ne "Notify" ) {
        $optiontime .=
          "<option value=\"$devtime[0]\">" . $devtime[0] . "</option>"
          if defined $devtime[0];
        $optiontime .=
          "<option value=\"$devtime[1]\">" . $devtime[1] . "</option>"
          if defined $devtime[1];
    }

    $optiontime .= "<option value=\"$devtime[2]\">" . $devtime[2] . "</option>"
      if defined $devtime[2];
    $optiontime .= "<option value=\"$devtime[3]\">" . $devtime[3] . "</option>"
      if defined $devtime[3];

    my $affectedtime = '';
    if ( $count == 0 ) {
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
    my $oldtrigger = ReadingsVal( $Name, 'Trigger_device', 'undef' );
    if ( $oldtrigger ne 'undef' ) {
        $hash->{NOTIFYDEV} = $oldtrigger;
        readingsSingleUpdate( $hash, "Trigger_device", $oldtrigger, 0 );
    }
    return;
}

####################
sub MSwitch_LoadHelper($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
    my $oldtrigger = ReadingsVal( $Name, 'Trigger_device', 'undef' );
    my $devhash    = undef;
    my $cdev       = '';
    my $ctrigg     = '';

    if ( $hash->{INIT} eq "def" ) {
        return;
    }

    if ( defined $hash->{DEF} ) {
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
                readingsSingleUpdate( $hash, "Trigger_device", $cdev, 0 );
            }
        }
        else {
            $hash->{NOTIFYDEV} = 'no_trigger';
            readingsSingleUpdate( $hash, "Trigger_device", 'no_trigger', 0 );
        }
    }

    if (   !defined $hash->{NOTIFYDEV}
        || $hash->{NOTIFYDEV} eq 'undef'
        || $hash->{NOTIFYDEV} eq '' )
    {
        $hash->{NOTIFYDEV} = 'no_trigger';
    }

    if ( $oldtrigger ne 'undef' ) {
        $hash->{NOTIFYDEV} = $oldtrigger;
        readingsSingleUpdate( $hash, "Trigger_device", $oldtrigger, 0 );
    }
################
    MSwitch_set_dev($hash);
################
    if ( AttrVal( $Name, 'MSwitch_Activate_MSwitchcmds', "0" ) eq '1' ) {
        addToAttrList('MSwitchcmd');
    }
################ erste initialisierung eines devices
    if ( ReadingsVal( $Name, '.V_Check', 'undef' ) ne $vupdate
        && $autoupdate eq "on" )
    {
        MSwitch_VUpdate($hash);
    }
################
    if ( ReadingsVal( $Name, '.First_init', 'undef' ) ne 'done' ) {

        $hash->{helper}{config} = "no_config";
        readingsBeginUpdate($hash);
        readingsBulkUpdate( $hash, ".V_Check", $vupdate );
        readingsBulkUpdate( $hash, "state",    'active' );
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
        readingsBulkUpdate( $hash, "Trigger_log",      'off' );
        readingsBulkUpdate( $hash, ".Device_Affected", 'no_device' );
        readingsBulkUpdate( $hash, ".First_init",      'done' );
        readingsBulkUpdate( $hash, ".V_Check",         $vupdate );
        readingsEndUpdate( $hash, 0 );

        # setze ignoreliste
        $attr{$Name}{MSwitch_Ignore_Types} = join( " ", @doignore );

        # setze attr inforoom
        my $testdev = '';
      LOOP22:
        foreach my $testdevices ( keys %{ $modules{MSwitch}{defptr} } ) {
            if ( $Name eq $testdevices ) { next LOOP22; }
            $testdev = AttrVal( $testdevices, 'MSwitch_Inforoom', '' );
        }
        if ( $testdev ne '' ) {
            $attr{$Name}{MSwitch_Inforoom} = $testdev,;
        }

############################

        # nur temporär für versionswechsel

        my $attrzerolist =
            "  disable:0,1"
          . "  disabledForIntervals"
          . "  MSwitch_Language:EN,DE"
          . "  stateFormat:textField-long"
          . "  MSwitch_Comments:0,1"
          . "  MSwitch_Read_Log:0,1"
          . "  MSwitch_Hidecmds"
          . "  MSwitch_Help:0,1"
          . "  MSwitch_Debug:0,1,2,3,4"
          . "  MSwitch_Expert:0,1"
          . "  MSwitch_Delete_Delays:0,1,2"
          . "  MSwitch_Include_Devicecmds:0,1"
          . "  MSwitch_generate_Events:0,1"
          . "  MSwitch_Include_Webcmds:0,1"
          . "  MSwitch_Include_MSwitchcmds:0,1"
          . "  MSwitch_Activate_MSwitchcmds:0,1"
          . "  MSwitch_Lock_Quickedit:0,1"
          . "  MSwitch_Ignore_Types:textField-long "
          . "  MSwitch_Reset_EVT_CMD1_COUNT"
          . "  MSwitch_Reset_EVT_CMD2_COUNT"
          . "  MSwitch_Trigger_Filter"
          . "  MSwitch_Extensions:0,1"
          . "  MSwitch_Inforoom"
          . "  MSwitch_Modul_Mode:0,1"
          . "  MSwitch_DeleteCMDs:manually,automatic,nosave"
          . "  MSwitch_Mode:Full,Notify,Toggle,Dummy"
          . "  MSwitch_Condition_Time:0,1"
          . "  MSwitch_Selftrigger_always:0,1"
          . "  MSwitch_RandomTime"
          . "  MSwitch_RandomNumber"
          . "  MSwitch_Safemode:0,1"
          . "  MSwitch_Startdelay:0,10,20,30,60,90,120"
          . "  MSwitch_Wait"
          . "  MSwitch_Sequenz:textField-long "
          . "  MSwitch_Sequenz_time"
          . "  MSwitch_setList:textField-long "
          . "  setList:textField-long "
          . "  readingList:textField-long "
          . "  MSwitch_Eventhistory:0,1,2,3,4,5,10,20,30,40,50,60,70,80,90,100,150,200"
          . "  MSwitch_Device_Groups:textField-long"
          . "  MSwitch_ExtraktfromHTTP:textField-long"
          . "  MSwitch_ExtraktHTTPMapping:textField-long"
          . "  MSwitch_Switching_once:0,1"
          . "  textField-long "
          . $readingFnAttributes;

        setDevAttrList( $Name, $attrzerolist );
        my @found_devices = devspec2array("TYPE=MSwitch:FILTER=.msconfig=1");

        ##############
        if (
            $defs{ $found_devices[0] }
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
                    next if ( $key !~ m/(^MSwitch_.*|^disabled.*)/ );
                    if (   $key ne "MSwitch_Help"
                        && $key ne "MSwitch_Ignore_Types" )
                    {
                    }
                    next
                      if ReadingsVal( $found_devices[0], $key, 'undef' ) eq "";
                    my $aktset =
                      ReadingsVal( $found_devices[0], $key, 'undef' );
                    $attr{$Name}{$key} = "$aktset";
                }
            }

        }

        else {

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
            fhem("attr $Name room MSwitch_Devices");
        }
        ################
    }

    # NEU; ZUVOR IN SET
    my $testnew = ReadingsVal( $Name, '.Trigger_on', 'undef' );
    if ( $testnew eq 'undef' ) {
        readingsBeginUpdate($hash);
        readingsBulkUpdate( $hash, ".Device_Events",   'no_trigger' );
        readingsBulkUpdate( $hash, ".Trigger_on",      'no_trigger' );
        readingsBulkUpdate( $hash, ".Trigger_off",     'no_trigger' );
        readingsBulkUpdate( $hash, "Trigger_log",      'on' );
        readingsBulkUpdate( $hash, ".Device_Affected", 'no_device' );
        readingsEndUpdate( $hash, 0 );
    }

    MSwitch_Createtimer($hash);    #Neustart aller timer
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

    Log3( $name, 5, "defstring $defstring" );

    #Log3( $name, 0, "template: @a" );

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

    if ( $version ne $data{MSwitch}{Version} ) {
        $hash->{Update} =
          "Modulversion " . $data{MSwitch}{Version} . " verfügbar";

    }

    if ( $defstring ne "" and $defstring =~ m/(\(.+?\))/ ) {

        Log3( $name, 1, "ERROR MSwitch define over onelinemode deactivated" )
          ;    #LOG
        return "This mode is deactivated";
    }
    else {
        $hash->{INIT} = 'fhem.save';
    }

    if ( $defstring =~ m/wizard.*/ )

    {
        Log3( $name, 1, "starte wizard" );

        $hash->{helper}{mode}      = 'absorb';
        $hash->{helper}{modesince} = time;
        $hash->{helper}{template}  = $template;
    }

    if ( $init_done && !defined( $hash->{OLDDEF} ) ) {
        my $timecond = gettimeofday() + 5;
        InternalTimer( $timecond, "MSwitch_check_init", $hash );
    }
    else {
    }
    return;
}

####################

sub MSwitch_Get($$@) {
    my ( $hash, $name, $opt, @args ) = @_;
    my $ret;
    if ( ReadingsVal( $name, '.change', '' ) ne '' ) {
        return "Unknown argument, choose one of ";
    }
    return "\"get $name\" needs at least one argument" unless ( defined($opt) );
####################
    if ( $opt eq 'restore_MSwitch_Data' && $args[0] eq "this_Device" ) {
        $ret = MSwitch_backup_this($hash);
        return $ret;
    }
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
        $NOTIMER    = "Timer werden nicht ausgeführt";
        $SYSTEMZEIT = "Systemzeit:";
        $SCHALTZEIT = "Schaltzeiten (at - kommandos)";
    }
    else {

        $KLAMMERFEHLER =
"Error in brace replacement, number of opening and closing parentheses does not match.";
        $CONDTRUE        = "Condition is true and is executed";
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
        $NOTIMER    = "Timers are not running";
        $SYSTEMZEIT = "system time:";
        $SCHALTZEIT = "Switching times (at - commands)";
    }

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
################
    if ( $opt eq 'restore_MSwitch_Data' && $args[0] eq "all_Devices" ) {
        open( BACKUPDATEI, "<MSwitch_backup_$vupdate.cfg" )
          || return "no Backupfile found\n";
        close(BACKUPDATEI);
        $hash->{helper}{RESTORE_ANSWER} = $hash->{CL};
        my $ret = MSwitch_backup_all($hash);
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
        $ret = MSwitch_Getconfig($hash);
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
              $readname . "     " . $INHALT . " " . $readinginhalt . "<br>";
        }

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

        my $inhalt .= $data{MSwitch}{$name}{HTTPresponse};
        $ret .= "<textarea cols='120' rows='30>$inhalt</textarea>";

        if (
            length($inhalt) <
            1 )    # wenn ein Fehler bei der HTTP Abfrage aufgetreten ist
        {
            $ret = "<html>Keine Daten vorhanden</html>";
        }

        $ret = "<html>" . $ret . "</html>";

        return $ret;
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
        $ret .= "<div nowrap>" . $SYSTEMZEIT . " " . localtime() . "</div><hr>";
        $ret .= "<div nowrap>" . $SCHALTZEIT . "</div><hr>";

        #timer
        my $timehash = $hash->{helper}{timer};

        foreach my $a ( sort keys %{$timehash} ) {
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

        #delays
        $ret .= "<br>&nbsp;<br><div nowrap>aktive Delays:</div><hr>";
        $timehash = $hash->{helper}{delays};

        foreach my $a ( sort keys %{$timehash} ) {

            #Log3("test",0,$a);

            my $b      = substr( $hash->{helper}{delays}{$a}, 0, 10 );
            my $time   = FmtDateTime($b);
            my @timers = split( /#\[tr\]/, $a );

            $ret .= "<div nowrap><strong>Ausführungszeitpunkt:</strong> "
              . $time . "<br>";

            $ret .= "<strong>Indikator: </strong>" . $timers[3] . "<br>";
            $ret .= "<strong>auszuführender Befehl:</strong><br>"
              . $timers[0] . "<br>";

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

    my $extension = '';
    if ( ReadingsVal( $name, 'Sys_Extension', '' ) eq 'on' ) {
        $extension = 'sysextension:noArg';
    }

### modulmode - no sets
    if ( AttrVal( $name, 'MSwitch_Modul_Mode', "0" ) eq '1' ) {
        return
"Unknown argument $opt, choose one of reset_Switching_once:noArg  HTTPresponse:noArg config:noArg support_info:noArg active_timer:show";

    }
#######




    if ( AttrVal( $name, 'MSwitch_Mode', 'Notify' ) eq "Dummy" ) {
        if ( AttrVal( $name, "MSwitch_Selftrigger_always", 0 ) eq "1" ) {
            return
"Unknown argument $opt, choose one of reset_Switching_once:noArg HTTPresponse:noArg Eventlog:timeline,clear config:noArg support_info:noArg restore_MSwitch_Data:this_Device,all_Devices active_timer:show,delete";
        }
        else {
            return
"Unknown argument $opt, choose one of reset_Switching_once:noArg HTTPresponse:noArg support_info:noArg restore_MSwitch_Data:this_Device,all_Devices";
        }
    }

    if ( ReadingsVal( $name, '.lock', 'undef' ) ne "undef" ) {
        return
"Unknown argument $opt, choose one of reset_Switching_once:noArg HTTPresponse:noArg support_info:noArg active_timer:show,delete config:noArg restore_MSwitch_Data:this_Device,all_Devices ";
    }
    else {
        return
"Unknown argument $opt, choose one of reset_Switching_once:noArg HTTPresponse:noArg Eventlog:sequenzformated,timeline,clear support_info:noArg config:noArg active_timer:show,delete restore_MSwitch_Data:this_Device,all_Devices $extension";
    }
}
####################
sub MSwitch_AsyncOutput ($) {
    my ( $client_hash, $text ) = @_;
    return $text;
}
####################
sub MSwitch_Set($@) {
    my ( $hash, $name, $cmd, @args ) = @_;
    my $dynlist = "";


    #################################
    if ( $cmd eq 'writelog' ) {
		my @logs = split( /\|/, $args[0] );
	    shift @args;
        MSwitch_LOG($name,$logs[0],"@args");
        return;
    }

    #################################
    if ( $cmd eq 'showgroup' ) {
        MSwitch_makegroupcmdout( $hash, $args[0] );
        return;
    }


    #################################

    if ( $cmd eq 'reset_Switching_once' ) {
		delete( $hash->{helper}{lastexecute});
		MSwitch_LOG( $name, 6, "Blockierung von gleichen Befehlsketten zurückgesetzt L:" . __LINE__ );

        return;
    }

    #################################

    if ( $cmd eq 'savetemplate' ) {
        my $ret = MSwitch_savetemplate( $hash, $args[0], $args[1] );
        return;
    }

    #################################
    if ( $cmd eq 'template' ) {
        my $ret = MSwitch_gettemplate( $hash, $args[0] );
        return $ret;
    }

    #################################
    if ( $cmd eq 'reloaddevices' ) {
        my $ret = MSwitch_reloaddevices( $hash, $args[0] );
        return $ret;
    }

    #################################
    if ( $cmd eq 'whitelist' ) {
        my $ret = MSwitch_whitelist( $hash, $args[0] );
        return $ret;
    }

    #################################
    if ( $cmd eq 'loadpreconf' ) {
        my $ret = MSwitch_loadpreconf($hash);
        return $ret;
    }

    #################################
    if ( $cmd eq 'loadnotify' ) {
        my $ret = MSwitch_loadnotify( $hash, $args[0] );
        return $ret;
    }

    #################################
    if ( $cmd eq 'loadat' ) {
        my $ret = MSwitch_loadat( $hash, $args[0] );
        return $ret;
    }

############# Befehle  aus web.js
    if ( $cmd eq 'logging' ) {
        if ( $args[0] eq "1" ) {
            $hash->{helper}{aktivelog} = "on";
        }
        else {
            delete( $hash->{helper}{aktivelog} );
        }
        return;
    }
############################
    if ( $cmd eq 'clearlog' ) {
        MSwitch_clearlog($hash);
        return;
    }
############################
    if ( $cmd eq 'setbridge' ) {
        MSwitch_setbridge( $hash, $args[0] );
        return;
    }
############################

    # korrigiere version
    if ( ReadingsVal( $name, '.V_Check', 'undef' ) ne $vupdate
        && $autoupdate eq "on" )
    {
        MSwitch_VUpdate($hash);
    }
##########################

    if ( $cmd ne "?" ) {

        MSwitch_LOG( $name, 6,
            "eingehender Setbefehl: $cmd @args L:" . __LINE__ );
    }

    #lösche saveddevicecmd
    MSwitch_del_savedcmds($hash);
    return ""
      if ( IsDisabled($name) && ( $cmd eq 'on' || $cmd eq 'off' ) )
      ;    # Return without any further action if the module is disabled
    my $execids = "0";
    $hash->{eventsave} = 'unsaved';
    my $ic = 'leer';
    $ic = $hash->{IncommingHandle} if ( $hash->{IncommingHandle} );
    my $showevents = AttrVal( $name, "MSwitch_generate_Events", 1 );
    my $devicemode = AttrVal( $name, 'MSwitch_Mode',            'Notify' );
    my $delaymode  = AttrVal( $name, 'MSwitch_Delete_Delays',   '0' );

###################################################################################

    # verry special commands readingactivated (
    my $special = '';


##########################

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

###########################

    # nur bei funktionen in setlist !!!!

    if ( AttrVal( $name, "MSwitch_Selftrigger_always", 0 ) eq "1"
        and $cmd ne "?" )
    {
        my $atts = AttrVal( $name, 'setList', "" );
        my @testarray = split( " ", $atts );
        my %setlist;
        foreach (@testarray) {
            my ( $arg1, $arg2 ) = split( ":", $_ );
            if ( !defined $arg2 or $arg2 eq "" ) { $arg2 = "noArg" }
            $setlist{$arg1} = $arg2;
        }

        MSwitch_Check_Event( $hash, "MSwitch_self:" . $cmd . ":" . $args[0] )
          if defined $setlist{$cmd};
    }

    if ( AttrVal( $name, "MSwitch_Selftrigger_always", 0 ) eq "1"
        and $cmd ne "?" )
    {
        # && defined $setlist{$cmd}
        my %setlist;
        foreach (@arraydynsetlist) {
            my ( $arg1, $arg2 ) = split( ":", $_ );
            if ( !defined $arg2 or $arg2 eq "" ) { $arg2 = "noArg" }
            $setlist{$arg1} = $arg2;
        }

        MSwitch_Check_Event( $hash, "MSwitch_self:" . $cmd . ":" . $args[0] )
          if defined $setlist{$cmd};
    }

    my %setlist;

    if ( !defined $args[0] ) { $args[0] = ''; }

    my $setList = AttrVal( $name, "setList", " " );
    $setList =~ s/\n/ /g;

    if ( !exists( $sets{$cmd} ) ) {
        my @cList;

        # Overwrite %sets with setList
        my $atts = AttrVal( $name, 'setList', "" );
        my @testarray = split( " ", $atts );
        foreach (@testarray) {
            my ( $arg1, $arg2 ) = split( ":", $_ );
            if ( !defined $arg2 or $arg2 eq "" ) { $arg2 = "noArg" }
            $setlist{$arg1} = $arg2;
        }
##########################

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
                    readingsSingleUpdate( $hash, $cmd, "@args", 1 );
                }
                else {
                    readingsSingleUpdate( $hash, "state", $cmd . " @args", 1 );
                }
                return;
            }

            @gefischt = grep( /$re/, @arraydynsetlist );
            if ( @arraydynsetlist && grep /$re/, @arraydynsetlist ) {

                readingsSingleUpdate( $hash, $cmd, "@args", 1 );
                return;
            }

##############################
            # dummy state setzen und exit
            if ( $devicemode eq "Dummy" ) {

                if ( $cmd eq "on" || $cmd eq "off" ) {
                    readingsSingleUpdate( $hash, "state", $cmd . " @args", 1 );
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

            #AUFRUF DEBUGFUNKTIONEN
            if ( AttrVal( $name, 'MSwitch_Debug', "0" ) eq '4' ) {
                MSwitch_Debug($hash);
            }
            delete( $hash->{IncommingHandle} );
        }
############################################

        if ( exists $hash->{helper}{config}
            && $hash->{helper}{config} eq "no_config" )
        {
            return "Unknown argument $cmd, choose one of wizard:noArg";
        }

### modulmode - no sets
        if ( AttrVal( $name, 'MSwitch_Modul_Mode', "0" ) eq '1' ) {
            return "Unknown argument $cmd, choose one of $dynsetlist $setList ";

        }
#######

        if ( $devicemode eq "Notify" ) {
            return
"Unknown argument $cmd, choose one of $dynsetlist writelog reset_Switching_once:noArg loadHTTP reset_device:noArg active:noArg inactive:noArg del_function_data:noArg del_delays backup_MSwitch:all_devices fakeevent exec_cmd_1 exec_cmd_2 wait reload_timer:noArg del_repeats:noArg change_renamed reset_cmd_count:1,2,all $setList "
              ;    #$special
        }
        elsif ( $devicemode eq "Toggle" ) {
            return
"Unknown argument $cmd, choose one of $dynsetlist writelog reset_Switching_once:noArg reset_device:noArg active:noArg del_function_data:noArg inactive:noArg on off del_delays:noArg backup_MSwitch:all_devices fakeevent wait reload_timer:noArg del_repeats:noArg change_renamed $setList "
              ;    #$special
        }
        elsif ( $devicemode eq "Dummy" ) {

            if ( AttrVal( $name, 'useSetExtensions', "0" ) eq '1' ) {
                return SetExtensions( $hash, $setList, $name, $cmd, @args );
            }
            else {
                if ( AttrVal( $name, "MSwitch_Selftrigger_always", 0 ) eq "1" )
                {
                    return
"Unknown argument $cmd, choose one of $dynsetlist writelog reset_Switching_once:noArg loadHTTP del_repeats:noArg del_delays exec_cmd_1 exec_cmd_2 reset_device:noArg wait backup_MSwitch:all_devices $setList $special";
                }
                else {
                    return
"Unknown argument $cmd, choose one of $dynsetlist writelog reset_Switching_once:noArg loadHTTP reset_device:noArg backup_MSwitch:all_devices $setList $special";
                }
            }
        }
        else {
            #full
            return
"Unknown argument $cmd, choose one of $dynsetlist writelog reset_Switching_once:noArg loadHTTP del_repeats:noArg reset_device:noArg active:noArg del_function_data:noArg inactive:noArg on off  del_delays backup_MSwitch:all_devices fakeevent exec_cmd_1 exec_cmd_2 wait del_repeats:noArg reload_timer:noArg change_renamed reset_cmd_count:1,2,all $setList $special";
        }
    }

    if (   ( ( $cmd eq 'on' ) || ( $cmd eq 'off' ) )
        && ( $args[0] ne '' )
        && ( $ic ne 'fromnotify' ) )
    {
        readingsSingleUpdate( $hash, "Parameter", $args[0], 1 );
        if ( $cmd eq 'on' ) {
            $args[0] = "$name:on_with_Parameter:$args[0]";
        }
        if ( $cmd eq 'off' ) {
            $args[0] = "$name:off_with_Parameter:$args[0]";
        }
    }

    if ( AttrVal( $name, 'MSwitch_RandomNumber', '' ) ne '' ) {

        # randomnunner erzeugen wenn attr an
        MSwitch_Createnumber1($hash);
    }
#############################
    # wizard
    if ( $cmd eq 'wizard' ) {
        $hash->{helper}{mode}      = 'absorb';
        $hash->{helper}{modesince} = time;
    }

    #############################
    # loadHTTP
    if ( $cmd eq 'loadHTTP' ) {
        MSwitch_PerformHttpRequest( $hash, $args[0] );
        return;

    }

##############################
    if ( $cmd eq 'reset_device' ) {
        if ( $args[0] eq 'checked' ) {

            $hash->{helper}{config} = "no_config";

            #readings
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

            # $hash->{Support_Fhemforum} =
            # "https://forum.fhem.de/index.php/topic,86199.0.html";
            %setlist = ();
            %sets    = ();

            %sets = (
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
                "filter_trigger"    => "noArg",
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
                "loadHTTP"          => "noArg",
				"reset_Switching_once"   => "",
                "change_renamed"    => ""
            );

            readingsBeginUpdate($hash);
            readingsBulkUpdate( $hash, ".Device_Events",   "no_trigger", 1 );
            readingsBulkUpdate( $hash, ".Trigger_cmd_off", "no_trigger", 1 );
            readingsBulkUpdate( $hash, ".Trigger_cmd_on",  "no_trigger", 1 );
            readingsBulkUpdate( $hash, ".Trigger_off",     "no_trigger", 1 );
            readingsBulkUpdate( $hash, ".Trigger_on",      "notrigger",  1 );
            readingsBulkUpdate( $hash, "Trigger_device",   "no_trigger", 1 );
            readingsBulkUpdate( $hash, "Trigger_log",      "off",        1 );
            readingsBulkUpdate( $hash, "state",            "active",     1 );
            readingsBulkUpdate( $hash, ".V_Check",         $vupdate,     1 );
            readingsBulkUpdate( $hash, ".First_init",      'done' );
            readingsEndUpdate( $hash, 0 );

            my $attrdefinelist =
                "  disable:0,1"
              . "  disabledForIntervals"
              . "  stateFormat:textField-long"
              . "  MSwitch_Comments:0,1"
              . "  MSwitch_Read_Log:0,1"
              . "  MSwitch_Hidecmds"
              . "  MSwitch_Help:0,1"
              . "  MSwitch_Debug:0,1,2,3,4"
              . "  MSwitch_Expert:0,1"
              . "  MSwitch_Delete_Delays:0,1,2"
              . "  MSwitch_Include_Devicecmds:0,1"
              . "  MSwitch_generate_Events:0,1"
              . "  MSwitch_Include_Webcmds:0,1"
              . "  MSwitch_Include_MSwitchcmds:0,1"
              . "  MSwitch_Activate_MSwitchcmds:0,1"
              . "  MSwitch_Lock_Quickedit:0,1"
              . "  MSwitch_Ignore_Types:textField-long "
              . "  MSwitch_Reset_EVT_CMD1_COUNT"
              . "  MSwitch_Reset_EVT_CMD2_COUNT"
              . "  MSwitch_Trigger_Filter"
              . "  MSwitch_Extensions:0,1"
              . "  MSwitch_Inforoom"
              . "  MSwitch_DeleteCMDs:manually,automatic,nosave"
              . "  MSwitch_Mode:Full,Notify,Toggle,Dummy"
              . "  MSwitch_Condition_Time:0,1"
              . "  MSwitch_Selftrigger_always:0,1"
              . "  MSwitch_RandomTime"
              . "  MSwitch_RandomNumber"
              . "  MSwitch_Safemode:0,1"
              . "  MSwitch_Startdelay:0,10,20,30,60,90,120"
              . "  MSwitch_Wait"
              . "  MSwitch_Event_Id_Distributor:textField-long "
              . "  MSwitch_Sequenz:textField-long "
              . "  MSwitch_Sequenz_time"
              . "  MSwitch_setList:textField-long "
              . "  setList:textField-long "
              . "  readingList:textField-long "
              . "  MSwitch_Device_Groups:textField-long"
              . "  MSwitch_ExtraktfromHTTP:textField-long"
              . "  MSwitch_ExtraktHTTPMapping:textField-long"
              . "  MSwitch_Eventhistory:0,1,2,3,4,5,10,20,30,40,50,60,70,80,90,100,150,200"
              . "  textField-long "
              . "  MSwitch_Switching_once:0,1"
              . $readingFnAttributes;

            setDevAttrList( $name, $attrdefinelist );
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
            fhem("attr $name MSwitch_Inforoom $oldinforoom")
              if $oldinforoom ne "undef";
            return;
        }
        my $client_hash = $hash->{CL};
        $hash->{helper}{tmp}{reset} = "on";
        return;
    }
##############################
    if ( $cmd eq 'del_delays' ) {

        if ( $args[0] eq "" ) {

            # löschen aller delays
            MSwitch_Delete_Delay( $hash, $name );
        }
        else {
            MSwitch_Delete_specific_Delay( $hash, $name, $args[0] );

        }

        # delete spezific delay

        MSwitch_LOG( $name, 6, "Delays gelöscht L:" . __LINE__ );
        return;
    }
##############################
    if ( $cmd eq 'del_repeats' ) {
        my $inhalt = $hash->{helper}{repeats};
        foreach my $a ( sort keys %{$inhalt} ) {
            my $key = $hash->{helper}{repeats}{$a};
            RemoveInternalTimer($key);
        }
        delete( $hash->{helper}{repeats} );
        MSwitch_LOG( $name, 6, "Repeats gelöscht L:" . __LINE__ );
        return;

        #  MSwitch_Delete_Delay( $hash, $name );
    }
##############################
    if ( $cmd eq 'inactive' ) {

        # setze device auf inaktiv
        readingsSingleUpdate( $hash, "state", 'inactive', 1 );
        MSwitch_LOG( $name, 6, "inactiv gesetzt L:" . __LINE__ );
        return;
    }
##############################
    if ( $cmd eq 'active' ) {

        # setze device auf aktiv
        readingsSingleUpdate( $hash, "state", 'active', 1 );
        MSwitch_LOG( $name, 6, "aktiv gesetzt L:" . __LINE__ );
        return;
    }
##############################
    if ( $cmd eq 'change_renamed' ) {
        my $changestring = $args[0] . "#" . $args[1];
        MSwitch_confchange( $hash, $changestring );
        MSwitch_LOG( $name, 6, "Name geändertt L:" . __LINE__ );
        return;
    }
##################################
    if ( $cmd eq 'reset_cmd_count' ) {
        if ( $args[0] eq "1" ) {
            readingsSingleUpdate( $hash, "EVT_CMD1_COUNT", 0, 1 );
        }
        if ( $args[0] eq "2" ) {
            readingsSingleUpdate( $hash, "EVT_CMD2_COUNT", 0, 1 );
        }
        if ( $args[0] eq "all" ) {
            readingsSingleUpdate( $hash, "EVT_CMD1_COUNT", 0, 1 );
            readingsSingleUpdate( $hash, "EVT_CMD2_COUNT", 0, 1 );
        }
        MSwitch_LOG( $name, 6, "Counter resettet L:" . __LINE__ );
        return;
    }
#######################################
    if ( $cmd eq 'reload_timer' ) {
        MSwitch_Clear_timer($hash);
        MSwitch_Createtimer($hash);
        MSwitch_LOG( $name, 6, "Timer neu berechnet L:" . __LINE__ );
        return;
    }
#######################################
    if ( $cmd eq 'Writesequenz' ) {
        MSwitch_Writesequenz($hash);
        return;
    }
#######################################
    if ( $cmd eq 'VUpdate' ) {
        MSwitch_VUpdate($hash);
        return;
    }
#######################################
    if ( $cmd eq 'confchange' ) {
        MSwitch_confchange( $hash, $args[0] );
        return;
    }
###################################

    if ( $cmd eq 'deletesinglelog' ) {
        my $ret = MSwitch_delete_singlelog( $hash, $args[0] );
        return;
    }
##############################
    if ( $cmd eq 'wait' ) {
        readingsSingleUpdate( $hash, "waiting", ( time + $args[0] ),
            $showevents );
        return;
    }
###############################
    if ( $cmd eq 'sort_device' ) {
        readingsSingleUpdate( $hash, ".sortby", $args[0], 0 );
        return;
    }
    if ( $cmd eq 'fakeevent' ) {

        # fakeevent abarbeiten
        MSwitch_Check_Event( $hash, $args[0] );
        return;
    }
##############################
    if ( $cmd eq 'exec_cmd_1' ) {
        if ( $args[0] eq 'ID' ) {
            $execids = $args[1];
            $args[0] = 'ID';
        }
        if ( $args[0] eq "" ) {
            MSwitch_Exec_Notif( $hash, 'on', 'nocheck', '', 0 );
            return;
        }

        if ( $args[0] ne 'ID' || $args[0] ne '' ) {
            if ( $args[1] !~ m/\d/ ) {
                Log3( $name, 1,
"error at id call $args[1]: format must be exec_cmd_1 <ID x,z,y>"
                );
                return;
            }
        }

        # cmd1 abarbeiten
        MSwitch_LOG( $name, 6,
            "ausführung exec_cmd_1 $args[1] L:" . __LINE__ );
        MSwitch_Exec_Notif( $hash, 'on', 'nocheck', '', $execids );

        return;
    }

##############################

    if ( $cmd eq 'exec_cmd_2' ) {
        if ( $args[0] eq 'ID' ) {
            $execids = $args[1];
            $args[0] = 'ID';
        }
        if ( $args[0] eq "" ) {
            MSwitch_Exec_Notif( $hash, 'off', 'nocheck', '', 0 );
            return;
        }
        if ( $args[0] ne '' || $args[0] ne "ID" ) {
            if ( $args[1] !~ m/\d/ ) {
                Log3( $name, 1,
"error at id call $args[1]: format must be exec_cmd_2 <ID x,z,y>"
                );
                return;
            }
        }

        # cmd2 abarbeiten
        MSwitch_LOG( $name, 6,
            "ausführung exec_cmd_2 $args[1] L:" . __LINE__ );
        MSwitch_Exec_Notif( $hash, 'off', 'nocheck', '', $execids );
        return;
    }

##############################
    if ( $cmd eq 'backup_MSwitch' ) {

        # backup erstellen
        MSwitch_backup($hash);
        MSwitch_LOG( $name, 6, "Backup erstellt L:" . __LINE__ );
        return;
    }
##############################
    if ( $cmd eq 'saveconfig' ) {

        # configfile speichern
        $args[0] =~ s/\[s\]/ /g;
        MSwitch_saveconf( $hash, $args[0] );
        return;
    }
##############################
    if ( $cmd eq 'savesys' ) {

        # sysfile speichern
        MSwitch_savesys( $hash, $args[0] );
        return;
    }
##############################
    if ( $cmd eq "delcmds" ) {
        delete $data{MSwitch}{devicecmds1};
        delete $data{MSwitch}{last_devicecmd_save};
        return;
    }

##############################
    if ( $cmd eq "del_function_data" ) {
        delete( $hash->{helper}{eventhistory} );
        fhem("deletereading $name DIFFERENCE");
        fhem("deletereading $name TENDENCY");
        fhem("deletereading $name AVERAGE");
        return;
    }
##############################
    if ( $cmd eq "addevent" ) {

        delete( $hash->{helper}{config} );

        # event manuell zufügen
        my $devName = ReadingsVal( $name, 'Trigger_device', '' );
        $args[0] =~ s/\[sp\]/ /g;
        my @newevents = split( /,/, $args[0] );
        if ( ReadingsVal( $name, 'Trigger_device', '' ) eq "all_events" ) {
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
##############################
    if ( $cmd eq "add_device" ) {
        delete( $hash->{helper}{config} );

        #add device
        MSwitch_Add_Device( $hash, $args[0] );
        return;
    }
##############################
    if ( $cmd eq "del_device" ) {

        #del device
        MSwitch_Del_Device( $hash, $args[0] );
        return;
    }
##############################
    if ( $cmd eq "del_trigger" ) {

        #lösche trigger
        MSwitch_Delete_Triggermemory($hash);
        return;
    }
##############################
    if ( $cmd eq "filter_trigger" ) {

        #filter to trigger
        MSwitch_Filter_Trigger($hash);
        return;
    }
##############################
    if ( $cmd eq "set_trigger" ) {
        delete( $hash->{helper}{config} );
        delete( $hash->{helper}{wrongtimespeccond} );
        chop( $args[1], $args[2], $args[3], $args[4], $args[5], $args[6] );
        my $triggertime = 'on'
          . $args[1] . '~off'
          . $args[2]
          . '~ononly'
          . $args[3]
          . '~offonly'
          . $args[4]
          . '~onoffonly'
          . $args[5];

        my $oldtrigger = ReadingsVal( $name, 'Trigger_device', '' );
        readingsSingleUpdate( $hash, "Trigger_device",     $args[0], '1' );
        readingsSingleUpdate( $hash, ".Trigger_condition", $args[6], 0 );

        if ( !defined $args[7] ) {
            readingsDelete( $hash, '.Trigger_Whitelist' );
        }
        else {
            readingsSingleUpdate( $hash, ".Trigger_Whitelist", $args[7], 0 );
        }

        if ( $oldtrigger ne $args[0] ) {
            MSwitch_Delete_Triggermemory($hash);    # lösche alle events
        }

        if (   $args[1] ne ''
            || $args[2] ne ''
            || $args[3] ne ''
            || $args[4] ne ''
            || $args[5] ne '' )
        {
            readingsSingleUpdate( $hash, ".Trigger_time", $triggertime, 0 );
            MSwitch_Createtimer($hash);
        }
        else {
            readingsSingleUpdate( $hash, ".Trigger_time", '', 0 );
            MSwitch_Clear_timer($hash);
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
##############################
    if ( $cmd eq "trigger" ) {
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
        my $device     = ReadingsVal( $name, 'Trigger_device', '' );
        my $newtrigger = "([" . $device . ":" . $args[3] . "])" . $part2;
        $newtrigger =~ s/#\[nl\]/\n/g;
        $hash->{DEF} = $newtrigger;
        fhem( "modify $name " . $newtrigger );
        return;
    }

##############################
    if ( $cmd eq "devices" ) {
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
        $devices = MSwitch_makeAffected($hash);

        if ( defined $hash->{DEF} ) {
            my $devhash = $hash->{DEF};
            my @dev = split( /#/, $devhash );
            $hash->{DEF} = $dev[0] . ' # ' . $devices;
        }
        else {
            $hash->{DEF} = ' # ' . $devices;
        }
        return;
    }
##############################
    if ( $cmd eq "details" ) {
        delete( $hash->{helper}{config} );

        # setze devices details
        $args[0] = urlDecode( $args[0] );
        $args[0] =~ s/#\[pr\]/%/g;

        #devicehasch
        my %devhash = split( /#\[DN\]/, $args[0] );
        my @devices =
          split( /,/, ReadingsVal( $name, '.Device_Affected', '' ) );
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
                $savedetails = $savedetails . $devicecmds[18] . '#[ND]';
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
        readingsSingleUpdate( $hash, ".Device_Affected_Details", $savedetails,
            0 );

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

    ##################################
    my $update = '';

    # unbedingt überarbeiten !!!
    my @testdetails =
      qw(_on _off _onarg _offarg _playback _record _timeon _timeoff _conditionon _conditionoff);
    my @testdetailsstandart =
      ( 'no_action', 'no_action', '', '', 'nein', 'nein', 0, 0, '', '' );
    ##################################

    #neu ausführung on/off
    if ( $cmd eq "off" || $cmd eq "on" ) {



my @timers;
    my $timercounter = 0;



        MSwitch_LOG( $name, 6, "ausführung on/off L:" . __LINE__ );

        if ( $devicemode eq "Dummy"
            && AttrVal( $name, "MSwitch_Selftrigger_always", 0 ) eq "0" )
        {
            readingsSingleUpdate( $hash, "state", $cmd, 1 );
            return;
        }

        if ( $devicemode eq "Dummy" ) {
            if ( $cmd eq "on"
                && ReadingsVal( $name, '.Trigger_cmd_on', 'no_trigger' ) eq
                "no_trigger" )
            {
                readingsSingleUpdate( $hash, "state", $cmd, 1 );
                return;
            }
            if ( $cmd eq "off"
                && ReadingsVal( $name, '.Trigger_cmd_off', 'no_trigger' ) eq
                "no_trigger" )
            {
                readingsSingleUpdate( $hash, "state", $cmd, 1 );
                return;
            }
        }

###################################################

        ### neu
        if ( $delaymode eq '1' ) {
            MSwitch_Delete_Delay( $hash, $name );
        }
        ############
        if ( $ic ne 'fromnotify' && $ic ne 'fromtimer' ) {
            readingsSingleUpdate( $hash, "last_activation_by", 'manual',
                $showevents );
        }
        delete( $hash->{IncommingHandle} );

        # ausführen des off befehls
        my $zweig = 'nicht definiert';
        $zweig = "cmd1" if $cmd eq "on";
        $zweig = "cmd2" if $cmd eq "off";

        my $exittest = '';
        $exittest = "1" if $cmd eq "on";
        $exittest = "2" if $cmd eq "off";

        my $ekey = '';
        my $out  = '0';

        MSwitch_Safemode($hash);

        my @cmdpool;
        my %devicedetails = MSwitch_makeCmdHash($name);
        my @devices =
          split( /,/, ReadingsVal( $name, '.Device_Affected', '' ) );

        # liste anpassen ( reihenfolge ) wenn expert = 1
        @devices = MSwitch_priority( $hash, $execids, @devices );

        my $expertmode = AttrVal( $name, 'MSwitch_Expert',     "0" );
        my $randomtime = AttrVal( $name, 'MSwitch_RandomTime', '' );

      LOOP1: foreach my $device (@devices) {
            $out = '0';
            if ( $expertmode eq '1' ) {
                $ekey = $device . "_exit" . $exittest;
                $out  = $devicedetails{$ekey};
            }

            # teste auf on kommando
            next LOOP1 if $device eq "no_device";
            my @devicesplit = split( /-AbsCmd/, $device );
            my $devicenamet = $devicesplit[0];
            my $count       = 0;
            foreach my $testset (@testdetails) {
                if ( !defined( $devicedetails{ $device . $testset } ) ) {
                    my $key = '';
                    $key = $device . $testset;
                    $devicedetails{$key} = $testdetailsstandart[$count];
                }
                $count++;
            }

            # teste auf delayinhalt
            ###########################################################
            my $key      = $device . "_" . $cmd;
            my $timerkey = $device . "_time" . $cmd;

            # prüfe auf zufälligen timer [random]
            if ( $randomtime ne '' && $devicedetails{$timerkey} eq '[random]' )
            {
                $devicedetails{$timerkey} = MSwitch_Execute_randomtimer($hash);
            }
            elsif ($randomtime eq ''
                && $devicedetails{$timerkey} eq '[random]' )
            {
                $devicedetails{$timerkey} = 0;
            }
            ###

            if ( $devicedetails{$timerkey} =~ m/{.*}/ ) {
                $devicedetails{$timerkey} = eval $devicedetails{$timerkey};
            }
            if ( $devicedetails{$timerkey} =~ m/\[.*:.*\]/ ) {
                $devicedetails{$timerkey} =
                  eval MSwitch_Checkcond_state( $devicedetails{$timerkey},
                    $name );
            }

            if ( $devicedetails{$timerkey} =~ m/[\d]{2}:[\d]{2}:[\d]{2}/ ) {
                my $hdel = ( substr( $devicedetails{$timerkey}, 0, 2 ) ) * 3600;
                my $mdel = ( substr( $devicedetails{$timerkey}, 3, 2 ) ) * 60;
                my $sdel = ( substr( $devicedetails{$timerkey}, 6, 2 ) ) * 1;
                $devicedetails{$timerkey} = $hdel + $mdel + $sdel;
            }
            elsif ( $devicedetails{$timerkey} =~ m/^\d*\.?\d*$/ ) {
                $devicedetails{$timerkey} = $devicedetails{$timerkey};
            }
            else {
                $devicedetails{$timerkey} = 0;
            }

            # suche befehl
            if (   $devicedetails{$key} ne ""
                && $devicedetails{$key} ne "no_action" )    #befehl gefunden
            {
                my $cs = '';

                $cs =
"$devicedetails{$device.'_off'} $devicedetails{$device.'_offarg'}"
                  if $cmd eq "off";
                $cs =
"$devicedetails{$device.'_on'} $devicedetails{$device.'_onarg'}"
                  if $cmd eq "on";

                my $pos = index( $cs, "\[FREECMD\]" );
                if ( $pos >= 0 ) {
                    ##ggf set und name entferne

                    $cs = MSwitch_makefreecmdonly( $hash, $cs );
                }
                else {
                    $cs = "set $devicenamet " . $cs;
                }

                if ( $devicenamet eq 'FreeCmd' ) {
                    $cs = "$devicedetails{$device.'_'.$cmd.'arg'}";
                    $cs = MSwitch_makefreecmd( $hash, $cs );
                }

                my $conditionkey = $device . "_condition" . $cmd;

                if (   $devicedetails{$timerkey} eq "0"
                    || $devicedetails{$timerkey} eq "" )
                {

                    my $execute = "true";
                    $execute =
                      MSwitch_checkcondition( $devicedetails{$conditionkey},
                        $name, $args[0] )
                      if $devicedetails{$conditionkey} ne '';

                    if ( $execute eq 'true' ) {
                        push @cmdpool, $cs . '|' . $device;
                        $update = $device . ',' . $update;

                        if ( $out eq '1' ) {
                            last LOOP1;
                        }
                    }
                }
                else {
                    ##################################################
					
				
					
                    my $execute = "true";
            # conditiontest nur dann, wenn cond-test nicht nur nach verzögerung
                    if ( $devicedetails{ $device . "_delayat" . $cmd } ne
                        "delay2"
                        && $devicedetails{ $device . "_delayat" . $cmd } ne
                        "at02" )
                    {
                        $execute =
                          MSwitch_checkcondition( $devicedetails{$conditionkey},
                            $name, $args[0] );

                    }

                    if ( $execute eq 'true' ) {

                        my $delaykey     = $device . "_delayat" . $cmd;
                        my $delayinhalt  = $devicedetails{$delaykey};
                        my $delaykey1    = $device . "_delayat" . $cmd . "org";
                        my $teststateorg = $devicedetails{$delaykey1};

                        if ( $delayinhalt eq 'at0' || $delayinhalt eq 'at1' ) {

                            $devicedetails{$timerkey} =
                              MSwitch_replace_delay( $hash, $teststateorg );
                            MSwitch_LOG( $name, 6,
                                    "Verzögerung ersetzt durch: -> "
                                  . $devicedetails{$timerkey} . " "
                                  . __LINE__ );
                        }

                        if ( $delayinhalt eq 'at1' || $delayinhalt eq 'delay0' )
                        {
                            $conditionkey = 'nocheck';
                        }

                        my $timecond =gettimeofday() + $devicedetails{$timerkey};
                       

						$cs =~ s/\n/#[MSNL]/g;

						my $msg1 =
                            $cs . "#[tr]"
                          . $name . "#[tr]"
                          . $conditionkey . "#[tr]"
                          . "MSWITCH:SET:$cmd#[tr]"
                          . "TIMECOND" . "#[tr]"
                          . $device;
						  
						  
						  
                        # variabelersetzung
                        $msg1 = MSwitch_check_setmagic_i( $hash, $msg1 );
                        
						
						
						 my $timerset = "[TIMER][NUMBER$timercounter]$msg1";
							 $timers[$timercounter] = $timecond;
                            #   push( @execute, $timerset );
                             
						push @cmdpool, $timerset;
						
						
                        MSwitch_LOG( $name, 6,
                            "setze verzögerte Befehl auf stapel: $timerset L:"
                              . __LINE__ );
							  
						MSwitch_LOG( $name, 6,
                            "setze verzögerte Befehl time: $timers[$timercounter] L:"
                              . __LINE__ );	  
							 
						
                        MSwitch_LOG( $name, 6,
                            "setze verzögerte Befehl: $cmd @args L:"
                              . __LINE__ );
							  
						 $timercounter++; 	  
							  
						#$hash->{helper}{delays}{$msg} = $timecond;	  
                       # InternalTimer( $timecond, "MSwitch_Restartcmd", $msg );
						
						
						
						
						
                        if ( $out eq '1' ) {
                            last LOOP1;
                        }
                    }
                }
            }
        }

        if ( $devicemode ne "Notify" ) {
            readingsSingleUpdate( $hash, "state", $cmd, 1 );
        }
        else {
            # nothing
        }
        my $anzahl = @cmdpool;
		  
		$hash->{helper}{delaytimers}= "@timers";
  
        MSwitch_Cmd( $hash, @cmdpool ) if $anzahl > 0;
        return;
    }
    return;
}

###################################

sub MSwitch_Cmd(@) {

    my ( $hash, @cmdpool ) = @_;
    my $Name = $hash->{NAME};

 my @timers=split/ /,$hash->{helper}{delaytimers};


delete( $hash->{helper}{delaytimers});

		 		  
    my $fullstring = join( '[|]', @cmdpool );

    if ( AttrVal( $Name, 'MSwitch_Switching_once', 0 ) == 1
        && $fullstring eq $hash->{helper}{lastexecute} )
    {
        MSwitch_LOG( $Name, 6,
"Ausführung Befehlsstapel abgebrochen, Stapel wurde bereits ausgeführt L:"
              . __LINE__ );
        MSwitch_LOG( $Name, 6,
            "(attr MSwitch_Switching_once gesetzt) L:" . __LINE__ );
        return;
    }

   # MSwitch_LOG( $Name, 6, "Kommandoausführumg\n@cmdpool\nL:" . __LINE__ );

    my $lastdevice;
    my $showevents = AttrVal( $Name, "MSwitch_generate_Events", 1 );
    my %devicedetails = MSwitch_makeCmdHash($Name);
	
	
	
    foreach my $cmds (@cmdpool) {
       # MSwitch_LOG( $Name, 6, "cmds: $cmds L:" . __LINE__ );
		

		
		
		 if ( $cmds =~ m/\[TIMER\].*/ ) {
                MSwitch_LOG( $Name, 6, "Timerhandling: $cmds" . __LINE__ );
                $cmds =~ m/\[NUMBER(.*?)](.*)/;
                my $number = $1;
                my $string = $2;
				$string =~ s/#\[MSNL\]/\n/g;
                MSwitch_LOG( $Name, 5,
                    "extrahierte Nummer: $number L:" . __LINE__ );
                MSwitch_LOG( $Name, 5,
                    "extrahierte String: $string L:" . __LINE__ );
                my $timecondition = $timers[$number];
                MSwitch_LOG( $Name, 5,
                    "extrahierte Timecondition: $timecondition L:" . __LINE__ );
                $string =~ s/TIMECOND/$timecondition/g;
                MSwitch_LOG( $Name, 6, "setze Timer: $string L:" . __LINE__ );
				
				
				#$hash->{helper}{delays}{$msg} = $timecond;	  
                # InternalTimer( $timecond, "MSwitch_Restartcmd", $msg );
					      
                $hash->{helper}{delays}{$string} = $timecondition;
                InternalTimer( $timecondition, "MSwitch_Restartcmd", $string );
                next;
            }
		
		
		
		
	
		
		
		
        my @cut = split( /\|/, $cmds );
        $cmds = $cut[0];

        #ersetze platzhakter vor ausführung
        my $device = $cut[1];
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
                $msg = $msg . "|" . $timecond;
                $hash->{helper}{repeats}{$timecond} = "$msg";
                MSwitch_LOG( $Name, 6, "setze Wiederholungen L:" . __LINE__ );
                InternalTimer( $timecond, "MSwitch_repeat", $msg );
            }
        }

        my $todec = $cmds;

        $cmds = MSwitch_dec( $hash, $todec );

############################
        # debug2 mode , kein execute
        if ( AttrVal( $Name, 'MSwitch_Debug', "0" ) eq '2' ) {

            MSwitch_LOG( $Name, 6,
                "ausgeführter Befehl:\n $cmds \nL:" . __LINE__ );
        }
        else {
            if ( $cmds =~ m/(\{)(.*)(\})/ ) {

                $cmds =~ s/\[SR\]/\|/g;
                MSwitch_LOG( $Name, 6,
                    "ausgeführter Befehl auf Perlebene:\n $cmds L:"
                      . __LINE__ );
                my $out = eval($cmds);
                if ($@) {
                    MSwitch_LOG( $Name, 0,
                        "MSwitch_Set: ERROR $cmds: $@ " . __LINE__ );
                }
            }
            else {
                MSwitch_LOG( $Name, 6,
                    "ausgeführter Befehl auf Fhemebene:\n $cmds \nL:"
                      . __LINE__ );
                my $errors = AnalyzeCommandChain( undef, $cmds );
                if ( defined($errors) and $errors ne "OK" ) {
                    MSwitch_LOG( $Name, 1,
                        "MSwitch_Set: ERROR $cmds: $errors " . __LINE__ );
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
    if ( AttrVal( $Name, 'MSwitch_Expert', '0' ) eq "1" ) {
        readingsSingleUpdate( $hash, "last_cmd",
        $hash->{helper}{priorityids}{$lastdevice}, $showevents ) if defined $lastdevice;
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
	
	#$togglepart[0]=~ s/#\[SR\]/|/g;

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
	#MSwitch_LOG( $Name, 6, "FOUND TRENNER !!! L:" . __LINE__ );
}
	
	
	

    if ( $togglepart[0] ) {
        $togglepart[0] =~ s/\[//g;
        $togglepart[0] =~ s/\]//g;
        @cmds = split( /$trenner/, $togglepart[0] );
		
		#MSwitch_LOG( $Name, 6, "cmds @cmds!!! L:" . __LINE__ );
		
		
		
        $anzcmds = @cmds;
    }

    if ( $togglepart[1] ) {
		
		#$togglepart[1]=~ s/#\[SR\]/|/g;
		
		
        $togglepart[1] =~ s/\[//g;
        $togglepart[1] =~ s/\]//g;
        @muster = split( /$trenner/, $togglepart[1] );
		
		MSwitch_LOG( $Name, 6, "cmds @cmds!!! L:" . __LINE__ );
				
				
        $anzmuster = @cmds;
    }
    else {
        @muster    = @cmds;
        $anzmuster = $anzcmds;
    }

    if ( $togglepart[2] ) {
		
		#$togglepart[1]=~ s/#\[SR\]/|/g;
		
		
        $togglepart[2] =~ s/\[//g;
        $togglepart[2] =~ s/\]//g;
        $reading = $togglepart[2];
    }


my $aktstate;


#MSwitch_LOG( $Name, 6, "S2 $devicename L:" . __LINE__ );


if ($reading eq "MSwitch_self")
{
	$aktstate = ReadingsVal( $Name, 'last_toggle_state', 'undef' );	
} else {
	$aktstate = ReadingsVal( $devicename, $reading, 'undef' );	
}


#MSwitch_LOG( $Name, 6, "NAME -$Name- Reading -$reading-!!! $aktstate L:" . __LINE__ );
#MSwitch_LOG( $Name, 6, "AKTSTATE von reading $reading = $aktstate L:" . __LINE__ );


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
	readingsSingleUpdate( $hash, "last_toggle_state", $nextcmd, 1 );
    MSwitch_LOG( $Name, 6, "Toggle Rückgabe:\n $newcomand \nL:" . __LINE__ );
    return $newcomand;
}

######################################

######################################
sub MSwitch_toggleold($$) {

    my ( $hash, $cmds ) = @_;
    my $Name = $hash->{NAME};
    $cmds =~ m/(set) (.*)( )MSwitchtoggle (.*)/;
    my @tcmd = split( /\//, $4 );
    if ( !defined $tcmd[2] ) { $tcmd[2] = 'state' }
    if ( !defined $tcmd[3] ) { $tcmd[3] = $tcmd[0] }
    if ( !defined $tcmd[4] ) { $tcmd[4] = $tcmd[1] }
    my $cmd1    = $1 . " " . $2 . " " . $tcmd[0];
    my $cmd2    = $1 . " " . $2 . " " . $tcmd[1];
    my $chk1    = $tcmd[0];
    my $chk2    = $tcmd[1];
    my $testnew = ReadingsVal( $2, $tcmd[2], 'undef' );
    if ( $testnew =~ m/$tcmd[3]/ ) {
        $cmds = $cmd2;
    }
    elsif ( $testnew =~ m/$tcmd[4]/ ) {
        $cmds = $cmd1;
    }
    else {
        $cmds = $cmd1;
    }
    return $cmds;
}

##############################

sub MSwitch_Log_Event(@) {
    my ( $hash, $msg, $me ) = @_;
    my $Name          = $hash->{NAME};
    my $triggerdevice = ReadingsVal( $Name, 'Trigger_device', 'no_trigger' );
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

    my $attrlist =
        "  disable:0,1"
      . "  disabledForIntervals"
      . "  MSwitch_Language:EN,DE"
      . "  stateFormat:textField-long"
      . "  MSwitch_Comments:0,1"
      . "  MSwitch_Read_Log:0,1"
      . "  MSwitch_Hidecmds"
      . "  MSwitch_Help:0,1"
      . "  MSwitch_Debug:0,1,2,3,4"
      . "  MSwitch_Expert:0,1"
      . "  MSwitch_Delete_Delays:0,1,2"
      . "  MSwitch_Include_Devicecmds:0,1"
      . "  MSwitch_generate_Events:0,1"
      . "  MSwitch_Include_Webcmds:0,1"
      . "  MSwitch_Include_MSwitchcmds:0,1"
      . "  MSwitch_Activate_MSwitchcmds:0,1"
      . "  MSwitch_Lock_Quickedit:0,1"
      . "  MSwitch_Ignore_Types:textField-long "
      . "  MSwitch_Reset_EVT_CMD1_COUNT"
      . "  MSwitch_Reset_EVT_CMD2_COUNT"
      . "  MSwitch_Trigger_Filter"
      . "  MSwitch_Extensions:0,1"
      . "  MSwitch_Inforoom"
      . "  MSwitch_DeleteCMDs:manually,automatic,nosave"
      . "  MSwitch_Mode:Full,Notify,Toggle,Dummy"
      . "  MSwitch_Condition_Time:0,1"
      . "  MSwitch_Modul_Mode:0,1"
      . "  MSwitch_Selftrigger_always:0,1"
      . "  MSwitch_RandomTime"
      . "  MSwitch_RandomNumber"
      . "  MSwitch_Safemode:0,1"
      . "  MSwitch_Startdelay:0,10,20,30,60,90,120"
      . "  MSwitch_Wait"
      . "  MSwitch_Sequenz:textField-long "
      . "  MSwitch_Sequenz_time"
      . "  MSwitch_setList:textField-long "
      . "  setList:textField-long "
      . "  readingList:textField-long "
      . "  MSwitch_Eventhistory:0,1,2,3,4,5,10,20,30,40,50,60,70,80,90,100,150,200"
      . "  MSwitch_Device_Groups:textField-long"
      . "  MSwitch_ExtraktfromHTTP:textField-long"
      . "  MSwitch_ExtraktHTTPMapping:textField-long"
      . "  MSwitch_Switching_once:0,1"
      . "  textField-long "
      . $readingFnAttributes;

    $hash->{FW_addDetailToSummary} = 0;

    if ( $aName eq 'MSwitch_Debug' && ( $aVal == 2 || $aVal == 3 ) ) {
        readingsSingleUpdate( $hash, "Debug", 'Start_Debug', 1 );
    }
    else {
        delete( $hash->{READINGS}{Debug} );
    }

    if ( $aName eq 'MSwitch_Debug'
        && ( $aVal == 0 || $aVal == 1 || $aVal == 2 || $aVal == 3 ) )
    {
        delete( $hash->{READINGS}{Bulkfrom} );
        delete( $hash->{READINGS}{Device_Affected} );
        delete( $hash->{READINGS}{Device_Affected_Details} );
        delete( $hash->{READINGS}{Device_Events} );
    }

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
##################################

    if ( $cmd eq 'set' && $aName eq 'MSwitch_Device_Groups' ) {

        delete $data{MSwitch}{$name}{groups};
        my @gset = split( /\n/, $aVal );

        foreach my $line (@gset) {
            my @lineset = split( /->/, $line );
            $data{MSwitch}{$name}{groups}{ $lineset[0] } = $lineset[1];
            my @areadings = ( keys %{ $data{MSwitch}{$name}{groups} } );
        }
        return;
    }

    if ( $cmd eq 'del' && $aName eq 'MSwitch_Device_Groups' ) {
        delete $data{MSwitch}{$name}{groups};
        return;
    }

###################################
    if ( $cmd eq 'set' && $aName eq 'MSwitch_DeleteCMDs' ) {
        delete $data{MSwitch}{devicecmds1};
        delete $data{MSwitch}{last_devicecmd_save};
    }

    if ( $cmd eq 'set' && $aName eq 'MSwitch_Reset_EVT_CMD1_COUNT' ) {
        readingsSingleUpdate( $hash, "EVT_CMD1_COUNT", 0, 1 );
    }
    if ( $cmd eq 'set' && $aName eq 'MSwitch_Reset_EVT_CMD2_COUNT' ) {
        readingsSingleUpdate( $hash, "EVT_CMD2_COUNT", 0, 1 );
    }

    if ( $cmd eq 'set' && $aName eq 'disable' && $aVal == 1 ) {
        $hash->{NOTIFYDEV} = 'no_trigger';
        MSwitch_Delete_Delay( $hash, 'all' );
        MSwitch_Clear_timer($hash);
    }

    if ( $cmd eq 'set' && $aName eq 'disable' && $aVal == 0 ) {
        delete( $hash->{helper}{savemodeblock} );
        delete( $hash->{READINGS}{Safemode} );
        MSwitch_Createtimer($hash);

        if (
            ReadingsVal( $name, 'Trigger_device', 'no_trigger' ) ne 'no_trigger'
            and ReadingsVal( $name, 'Trigger_device', 'no_trigger' ) ne
            "MSwitch_Self" )
        {
            $hash->{NOTIFYDEV} =
              ReadingsVal( $name, 'Trigger_device', 'no_trigger' );
        }

        if ( $init_done == 1
            and ReadingsVal( $name, 'Trigger_device', 'no_trigger' ) eq
            "MSwitch_Self" )
        {
            $hash->{NOTIFYDEV} = $name;
        }
    }

    if ( $aName eq 'MSwitch_Activate_MSwitchcmds' && $aVal == 1 ) {
        addToAttrList('MSwitchcmd');
    }

    if ( $aName eq 'MSwitch_Debug' && $aVal eq '0' ) {
        unlink("./log/MSwitch_debug_$name.log");
    }

    if ( defined $aVal
        && ( $aName eq 'MSwitch_Debug' && ( $aVal eq '2' || $aVal eq '3' ) ) )
    {
        MSwitch_clearlog($hash);
    }

    if ( $cmd eq 'set' && $aName eq 'MSwitch_Inforoom' ) {
        my $testarg = $aVal;
        foreach my $testdevices ( keys %{ $modules{MSwitch}{defptr} } ) {
            $attr{$testdevices}{MSwitch_Inforoom} = $testarg;
        }
    }

    if ( $aName eq 'MSwitch_Mode' && ( $aVal eq 'Full' || $aVal eq 'Toggle' ) )
    {
        delete( $hash->{helper}{config} );
        my $cs = "setstate $name ???";
        my $errors = AnalyzeCommandChain( undef, $cs );
        $hash->{MODEL} = 'Full' . " " . $version   if $aVal eq 'Full';
        $hash->{MODEL} = 'Toggle' . " " . $version if $aVal eq 'Toggle';
        setDevAttrList( $name, $attrlist );
    }

#############################
    if ( $aName eq 'MSwitch_Mode' && ( $aVal eq 'Dummy' ) ) {
        delete( $hash->{helper}{config} );
        MSwitch_Delete_Delay( $hash, 'all' );
        MSwitch_Clear_timer($hash);
        $hash->{NOTIFYDEV} = 'no_trigger';
        $hash->{MODEL}     = 'Dummy' . " " . $version;

        fhem("deleteattr $name MSwitch_Include_Webcmds");
        fhem("deleteattr $name MSwitch_Include_MSwitchcmds");
        fhem("deleteattr $name MSwitch_Include_Devicecmds");
        fhem("deleteattr $name MSwitch_Safemode");
        fhem("deleteattr $name MSwitch_Extensions");
        fhem("deleteattr $name MSwitch_Lock_Quickedit");
        fhem("deleteattr $name MSwitch_Delete_Delays");
        delete( $hash->{NOTIFYDEV} );
        delete( $hash->{NTFY_ORDER} );
        delete( $hash->{READINGS}{Trigger_device} );
        delete( $hash->{IncommingHandle} );
        delete( $hash->{READINGS}{EVENT} );
        delete( $hash->{READINGS}{EVTFULL} );
        delete( $hash->{READINGS}{EVTPART1} );
        delete( $hash->{READINGS}{EVTPART2} );
        delete( $hash->{READINGS}{EVTPART3} );
        delete( $hash->{READINGS}{last_activation_by} );
        delete( $hash->{READINGS}{last_event} );
        delete( $hash->{READINGS}{last_exec_cmd} );

        my $attrzerolist =
            "  disable:0,1"
          . "  MSwitch_Language:EN,DE"
          . "  MSwitch_Debug:0,1"
          . "  disabledForIntervals"
          . "  MSwitch_Expert:0,1"
          . "  MSwitch_Modul_Mode:0,1"
          . "  stateFormat:textField-long"
          . "  MSwitch_Eventhistory:0,10"
          . "  MSwitch_Delete_Delays:0,1,2"
          . "  MSwitch_Help:0,1"
          . "  MSwitch_Ignore_Types:textField-long "
          . "  MSwitch_Extensions:0,1"
          . "  MSwitch_Inforoom"
          . "  MSwitch_DeleteCMDs:manually,automatic,nosave"
          . "  MSwitch_Mode:Full,Notify,Toggle,Dummy"
          . "  MSwitch_Selftrigger_always:0,1"
          . "  useSetExtensions:0,1"
          . "  MSwitch_setList:textField-long "
          . "  setList:textField-long "
          . "  readingList:textField-long "
          . "  MSwitch_Device_Groups:textField-long"
          . "  MSwitch_ExtraktfromHTTP:textField-long"
          . "  MSwitch_ExtraktHTTPMapping:textField-long"
          . "  MSwitch_Switching_once:0,1"
          . "  textField-long ";

        setDevAttrList( $name, $attrzerolist );
    }

    if ( $aName eq 'MSwitch_Mode' && $aVal eq 'Notify' ) {
        $hash->{MODEL} = 'Notify' . " " . $version;
        my $cs = "setstate $name active";
        my $errors = AnalyzeCommandChain( undef, $cs );
        if ( defined($errors) ) {
            MSwitch_LOG( $name, 1,
"$name MSwitch_Notify: Fehler bei Befehlsausführung $errors -> Comand: $_ "
                  . __LINE__ );
        }
        setDevAttrList( $name, $attrlist );
    }
#############

    if ( $cmd eq 'del' ) {
        my $testarg = $aName;
        my $errors;
        if ( $testarg eq 'MSwitch_Inforoom' ) {
          LOOP21:
            foreach my $testdevices ( keys %{ $modules{MSwitch}{defptr} } ) {
                if ( $testdevices eq $name ) { next LOOP21; }
                delete( $attr{$testdevices}{MSwitch_Inforoom} );
            }
        }

        if ( $testarg eq 'disable' ) {
            MSwitch_Delete_Delay( $hash, "all" );
            MSwitch_Clear_timer($hash);
            delete( $hash->{helper}{savemodeblock} );
            delete( $hash->{READINGS}{Safemode} );
        }

        if ( $testarg eq 'MSwitch_Reset_EVT_CMD1_COUNT' ) {
            delete( $hash->{READINGS}{EVT_CMD1_COUNT} );

        }

        if ( $testarg eq 'MSwitch_Reset_EVT_CMD2_COUNT' ) {
            delete( $hash->{READINGS}{EVT_CMD2_COUNT} );

        }

        if ( $testarg eq 'MSwitch_DeleteCMDs' ) {
            delete $data{MSwitch}{devicecmds1};
            delete $data{MSwitch}{last_devicecmd_save};

        }
    }

    #return undef;#pbp
    return;
}
####################
sub MSwitch_Delete($$) {
    my ( $hash, $name ) = @_;
    RemoveInternalTimer($hash);

    #return undef;#pbp
    return;
}
####################
sub MSwitch_Undef($$) {
    my ( $hash, $name ) = @_;
    RemoveInternalTimer($hash);
    delete( $modules{MSwitch}{defptr}{$name} );

    #return undef;#pbp
    return;
}
####################

sub MSwitch_Notify($$) {
    my $testtoggle = '';
    my ( $own_hash, $dev_hash ) = @_;
    my $ownName = $own_hash->{NAME};    # own name / hash
    my $devName;
    $devName = $dev_hash->{NAME};
    my $events = deviceEvents( $dev_hash, 1 );

########## korrigiere version
    #  if ( ReadingsVal( $ownName, '.V_Check', 'undef' ) ne $vupdate
    #        && $autoupdate eq "on" )
    #    {
    #        MSwitch_VUpdate($own_hash);
    #    }
    #
############################

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
            readingsBulkUpdate( $own_hash, ".Device_Events", "no_trigger", 1 );
            readingsBulkUpdate( $own_hash, ".Trigger_cmd_off", "no_trigger",
                1 );
            readingsBulkUpdate( $own_hash, ".Trigger_cmd_on", "no_trigger", 1 );
            readingsBulkUpdate( $own_hash, ".Trigger_off",    "no_trigger", 1 );
            readingsBulkUpdate( $own_hash, ".Trigger_on",     "no_trigger", 1 );
            readingsBulkUpdate( $own_hash, "Trigger_device",  "no_trigger", 1 );
            readingsBulkUpdate( $own_hash, "Trigger_log",     "off",        1 );
            readingsBulkUpdate( $own_hash, "state",           "active",     1 );
            readingsBulkUpdate( $own_hash, ".V_Check",        $vupdate,     1 );
            readingsBulkUpdate( $own_hash, ".First_init",     'done' );
            readingsEndUpdate( $own_hash, 0 );
            return;
        }
        return if $devName eq $ownName;
        my @eventscopy = ( @{$events} );
        foreach my $event (@eventscopy) {
            readingsSingleUpdate( $own_hash, "EVENTCONF",
                $devName . ": " . $event, 1 );
        }

        return;
    }

########## jede aktion füe eigenes debug abbrechen

    if ( $devName eq $ownName
        && grep( m/.*Debug|clearlog.*/, @{$events} ) )
    {
        return;
    }

############################

    if ( ReadingsVal( $ownName, '.First_init', 'undef' ) ne 'done' ) {

        # events blocken wenn datensatz unvollständig
        return;
    }

    # lösche saveddevicecmd #
    MSwitch_del_savedcmds($own_hash);

    if (   $own_hash->{helper}{testevent_device}
        && $own_hash->{helper}{testevent_device} eq 'Logfile' )
    {
        $devName = 'Logfile';
    }

    my $trigevent = '';

    #my $eventset  = '0';
    my $execids        = "0";
    my $foundcmd1      = 0;
    my $foundcmd2      = 0;
    my $foundcmdbridge = 0;
    my $showevents     = AttrVal( $ownName, "MSwitch_generate_Events", 1 );
    my $evhistory      = AttrVal( $ownName, "MSwitch_Eventhistory", 10 );
    my $resetcmd1      = AttrVal( $ownName, "MSwitch_Reset_EVT_CMD1_COUNT", 0 );
    my $resetcmd2      = AttrVal( $ownName, "MSwitch_Reset_EVT_CMD2_COUNT", 0 );

    if ( $resetcmd1 > 0
        && ReadingsVal( $ownName, 'EVT_CMD1_COUNT', '0' ) >= $resetcmd1 )
    {
        readingsSingleUpdate( $own_hash, "EVT_CMD1_COUNT", 0, $showevents );
    }

    if ( $resetcmd2 > 0
        && ReadingsVal( $ownName, 'EVT_CMD2_COUNT', '0' ) >= $resetcmd1 )
    {
        readingsSingleUpdate( $own_hash, "EVT_CMD2_COUNT", 0, $showevents );
    }

    # nur abfragen für eigenes Notify
    if (   $init_done
        && $devName eq "global"
        && grep( m/^MODIFIED $ownName$/, @{$events} ) )
    {
        # reaktion auf eigenes notify start / define / modify
        my $timecond = gettimeofday() + 5;
        InternalTimer( $timecond, "MSwitch_LoadHelper", $own_hash );
    }

    if (   $init_done
        && $devName eq "global"
        && grep( m/^DEFINED $ownName$/, @{$events} ) )
    {
        # reaktion auf eigenes notify start / define / modify
        my $timecond = gettimeofday() + 5;
        InternalTimer( $timecond, "MSwitch_LoadHelper", $own_hash );
    }

    if ( $devName eq "global"
        && grep( m/^INITIALIZED|REREADCFG$/, @{$events} ) )
    {
        # reaktion auf eigenes notify start / define / modify
        MSwitch_LoadHelper($own_hash);
    }

    # nur abfragen für eigenes Notify ENDE
    return "" if ( IsDisabled($ownName) );

    # Return without any further action if the module is disabled

    my $devicemode   = AttrVal( $ownName, 'MSwitch_Mode',           'Notify' );
    my $devicefilter = AttrVal( $ownName, 'MSwitch_Trigger_Filter', 'undef' );
    my $debugmode    = AttrVal( $ownName, 'MSwitch_Debug',          "0" );
    my $startdelay =
      AttrVal( $ownName, 'MSwitch_Startdelay', $standartstartdelay );
    my $attrrandomnumber = AttrVal( $ownName, 'MSwitch_RandomNumber', '' );

    if ( AttrVal( $ownName, "MSwitch_Selftrigger_always", 0 ) ne "1" ) {
        return
          if ( ReadingsVal( $ownName, "Trigger_device", "no_trigger" ) eq
            'no_trigger' );
        return
          if ( !$own_hash->{NOTIFYDEV}
            && ReadingsVal( $ownName, 'Trigger_device', 'no_trigger' ) ne
            "all_events" );
    }
    else {
    }

    # startverzöferung abwarten
    my $diff = int(time) - $fhem_started;
    if ( $diff < $startdelay ) {

        MSwitch_LOG( $ownName, 6,
            "Event blockiert - Startverzögerung $diff L:" . __LINE__ );
        return;
    }

    # safemode testen

    # versionscheck
    if ( ReadingsVal( $ownName, '.V_Check', $vupdate ) ne $vupdate ) {
        my $ver = ReadingsVal( $ownName, '.V_Check', '' );
        MSwitch_LOG( $ownName, 1,
            "Event blockiert - Versionskonflikt L:" . __LINE__ );
        return;
    }

    if ( $attrrandomnumber ne '' ) {

        # create randomnumber wenn attr an
        MSwitch_Createnumber1($own_hash);
    }

    my $incommingdevice = '';
    if ( defined( $own_hash->{helper}{testevent_device} )
        && $own_hash->{helper}{testevent_device} eq $ownName )
    {
        $incommingdevice = "MSwitch_Self";
        $events          = 'x';
    }
    elsif ( defined( $own_hash->{helper}{testevent_device} ) ) {

        # unklar
        $events          = 'x';
        $incommingdevice = ( $own_hash->{helper}{testevent_device} );
    }
    else {
        $incommingdevice = $dev_hash->{NAME};    # aufrufendes device
    }

##### test wait attribut

    if ( ReadingsVal( $ownName, "waiting", '0' ) > time ) {

        MSwitch_LOG( $ownName, 6,
                "Event blockiert - Wait gesetzt "
              . ReadingsVal( $ownName, "waiting", '0' ) . " L:"
              . __LINE__ );

        # teste auf attr waiting verlesse wenn gesetzt
        return "";
    }
    else {

        # reading löschen
        delete( $own_hash->{READINGS}{waiting} );
    }

#####
    if ( !$events && $own_hash->{helper}{testevent_device} ne 'Logfile' ) {
        return;
    }

    readingsSingleUpdate( $own_hash, "last_activation_by", 'event', 0 );
    my $triggerdevice =
      ReadingsVal( $ownName, 'Trigger_device', '' );    # Triggerdevice
    my @cmdarray;
    my @cmdarray1;    # enthält auszuführende befehle nach conditiontest

########### ggf. löschen
    my $triggeron     = ReadingsVal( $ownName, '.Trigger_on',      '' );
    my $triggeroff    = ReadingsVal( $ownName, '.Trigger_off',     '' );
    my $triggercmdon  = ReadingsVal( $ownName, '.Trigger_cmd_on',  '' );
    my $triggercmdoff = ReadingsVal( $ownName, '.Trigger_cmd_off', '' );
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

    my $set       = "noset";
    my $eventcopy = "";

    # notify für eigenes device
    my $devcopyname = $devName;

    my @eventscopy;
    if ( defined( $own_hash->{helper}{testevent_event} ) ) {
        @eventscopy = "$own_hash->{helper}{testevent_event}";

        $devName = $own_hash->{helper}{testevent_device};
    }
    else {
        @eventscopy = ( @{$events} ) if $events ne "x";
    }

    $own_hash->{helper}{eventfrom} = $devName;

    my $triggerlog = ReadingsVal( $ownName, 'Trigger_log', 'off' );

    if (   $incommingdevice eq $triggerdevice
        || $triggerdevice eq "all_events"
        || $triggerdevice eq "MSwitch_Self"
        || $incommingdevice eq "MSwitch_Self" )
    {
        # teste auf triggertreffer oder GLOBAL trigger
        my $activecount = 0;
        my $anzahl;

#### SEQUENZE
######################################
        my @sequenzall =
          split( /\//, AttrVal( $ownName, 'MSwitch_Sequenz', 'undef' ) );
        my $sequenzarrayfull = AttrVal( $ownName, 'MSwitch_Sequenz', 'undef' );
        $sequenzarrayfull =~ s/\// /g;
        my @sequenzarrayfull = split( / /, $sequenzarrayfull );
        my @sequenzarray;
        my $sequenz;
        my $x = 0;
        my $sequenztime = AttrVal( $ownName, 'MSwitch_Sequenz_time', 5 );

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
##########################

      EVENT: foreach my $event (@eventscopy)
		{
			
		
			
            if ( $event =~ m/^.*:.\{.*\}?/ ) {
                MSwitch_LOG( $ownName, 2, "$ownName:    found jason -> $event  " );
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

           # MSwitch_LOG( $ownName, 6, "eigegangenes Event $event L:" . __LINE__ );

            $own_hash->{eventsave} = 'unsaved';

            # durchlauf für jedes ankommende event
            $event = "" if ( !defined($event) );
            $eventcopy = $event;
            $eventcopy =~ s/: /:/s;    # BUG  !!!!!!!!!!!!!!!!!!!!!!!!
            $event =~ s/: /:/s;




####################################


  my $eventcopy1 = $eventcopy;
  
  
                if ( $triggerdevice eq "all_events" )
				{
				# fügt dem event den devicenamen hinzu , wenn global getriggert wird
                $eventcopy1 = "$devName:$eventcopy";
				}

                if ( AttrVal( $ownName, "MSwitch_Selftrigger_always", 0 ) eq "1" && $incommingdevice eq "MSwitch_Self" )
                {
                $eventcopy1 = "MSwitch_Self:$eventcopy";
                }

##########################################

                #aktualisiere Readings





    # Teste auf einhaltung Triggercondition für ausführung zweig 1 und zweig 2
    # kann ggf an den anfang der routine gesetzt werden ? test erforderlich
            my $triggercondition =
              ReadingsVal( $ownName, '.Trigger_condition', '' );
            $triggercondition =~ s/#\[dp\]/:/g;
            $triggercondition =~ s/#\[pt\]/./g;
            $triggercondition =~ s/#\[ti\]/~/g;
            $triggercondition =~ s/#\[sp\]/ /g;

           
                #my $eventcopy1 = $eventcopy;
                #if ( $triggerdevice eq "all_events" ) {

				# fügt dem event den devicenamen hinzu , wenn global getriggert wird
                 #   $eventcopy1 = "$devName:$eventcopy";
                #}
				
				
				
				
				
 if ( $triggercondition ne '' ) 
			{
                my $ret = MSwitch_checkcondition( $triggercondition, $ownName,
                    $eventcopy1 );

                if ( $ret eq 'false' )
				{
                    next EVENT;
                }
            }
			
			
			

            # Triggerfilter
            if ( $devicefilter ne 'undef' && $devicefilter ne "" ) 
			{
                # my $eventcopy1 = $eventcopy;
                # if ( $triggerdevice eq "all_events" ) {

				# # fügt dem event den devicenamen hinzu , wenn global getriggert wird
                    # $eventcopy1 = "$devName:$eventcopy";
                # }

                my @filters = split( /,/, $devicefilter )
                  ;    # beinhaltet filter durch komma getrennt

                foreach my $filter (@filters) {
                    if ( $filter eq "*" ) { $filter = ".*"; }

                    if ( $eventcopy1 =~ m/$filter/ ) {

                        next EVENT;
                    }
                }
            }
            delete( $own_hash->{helper}{history} )
              ; # lösche historyberechnung verschieben auf nach abarbeitung conditions





if ( $event ne '' ) 
			{


MSwitch_LOG( $ownName, 6, "--- eigegangenes Event --- $event ---L:" . __LINE__ );


                if ( AttrVal( $ownName, "MSwitch_Selftrigger_always", 0 ) eq "1" && $incommingdevice eq "MSwitch_Self" )
                {
                    MSwitch_EventBulk( $own_hash, $eventcopy1, '0','MSwitch_Notify' );
                }
                elsif (AttrVal( $ownName, "MSwitch_Selftrigger_always", 0 ) eq "0"&& $incommingdevice ne "MSwitch_Self" )
				{
					MSwitch_EventBulk( $own_hash, $eventcopy1, '0','MSwitch_Notify' );
				}
				else
				{
                    MSwitch_EventBulk( $own_hash, $eventcopy1, '0','MSwitch_Notify' );
                }

			}

######################################
































            # sequenz
            my $x    = 0;
            my $zeit = time;
          SEQ: foreach my $sequenz (@sequenzall) {
                $x++;
                if ( $sequenz ne "undef" ) {
                    my $fulldev = "$devName:$eventcopy";

                    foreach my $test (@sequenzarrayfull) {
                        if ( $fulldev =~ /$test/ ) {
                            $own_hash->{helper}{sequenz}{$x}{$zeit} = $fulldev;
                        }
                    }

                    my $seqhash    = $own_hash->{helper}{sequenz}{$x};
                    my $aktsequenz = "";
                    foreach my $seq ( sort keys %{$seqhash} ) {
                        $aktsequenz .=
                          $own_hash->{helper}{sequenz}{$x}{$seq} . " ";
                    }

                    if ( $aktsequenz =~ /$sequenz/ ) {
                        delete( $own_hash->{helper}{sequenz}{$x} );

                        MSwitch_LOG( $ownName, 6,
                            "Sequenz $x gefunden L:" . __LINE__ );
 
                        readingsSingleUpdate( $own_hash, "SEQUENCE", 'match',
                            1 );
                        readingsSingleUpdate( $own_hash, "SEQUENCE_Number", $x,
                            1 );
                        last SEQ;
                    }
                    else {
                        if ( ReadingsVal( $ownName, "SEQUENCE", 'undef' ) eq
                            "match" )
                        {
                            readingsSingleUpdate( $own_hash, "SEQUENCE",
                                'no_match', 1 );
                        }
                        if ( ReadingsVal( $ownName, "SEQUENCE_Number", 'undef' )
                            ne "0" )
                        {
                            readingsSingleUpdate( $own_hash, "SEQUENCE_Number",
                                '0', 1 );
                        }
                    }
                }
            }

            # Triggerlog/Eventlog

            if ( $triggerlog eq 'on' ) {
                my $zeit = time;
                if ( $incommingdevice ne "MSwitch_Self" ) {
                    if ( $triggerdevice eq "all_events" ) {
                        $own_hash->{helper}{events}{'all_events'}
                          { $devName . ':' . $eventcopy } = "on";
                    }
                    else {
                        $own_hash->{helper}{events}{$devName}{$eventcopy} =
                          "on";
                    }
                }
                else {
                    $own_hash->{helper}{events}{MSwitch_Self}{$eventcopy} =
                      "on";
                }
            }

            if ( $evhistory > 0 ) {
                my $zeit = time;
                if ( $incommingdevice ne "MSwitch_Self" ) {
                    if ( $triggerdevice eq "all_events" ) {
                        $own_hash->{helper}{eventlog}{$zeit} =
                          $devName . ':' . $eventcopy;
                    }
                    else {
                        $own_hash->{helper}{eventlog}{$zeit} =
                          $devName . ':' . $eventcopy;
                    }
                }
                else {
                    $own_hash->{helper}{eventlog}{$zeit} =
                      "MSitch_Self:" . $eventcopy;
                }
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
            #anzahl checken / ggf nicht mehr nötig
            #check checken  / ggf nicht mehr nötig

            my $check = 0;
            if ( $event ne '' ) 
			{
                 # my $eventcopy1 = $eventcopy;
                # if ( $triggerdevice eq "all_events" ) {

           # # fügt dem event den devicenamen hinzu , wenn global getriggert wird
                    # $eventcopy1 = "$devName:$eventcopy";
                # }

                # if ( AttrVal( $ownName, "MSwitch_Selftrigger_always", 0 ) eq "1"
                    # && $incommingdevice eq "MSwitch_Self" )
                # {
                    # $eventcopy1 = "MSwitch_Self:$eventcopy";
                # }

##########################################

                #aktualisiere Readings

                # if ( AttrVal( $ownName, "MSwitch_Selftrigger_always", 0 ) eq "1"
                    # && $incommingdevice eq "MSwitch_Self" )
                # {

                    # MSwitch_EventBulk( $own_hash, $eventcopy1, '0',
                        # 'MSwitch_Notify' );
                # }
                # elsif 
				# (
                    # AttrVal( $ownName, "MSwitch_Selftrigger_always", 0 ) eq "0"
                    # && $incommingdevice ne "MSwitch_Self" )
					# {

                    # MSwitch_EventBulk( $own_hash, $eventcopy1, '0',
                        # 'MSwitch_Notify' );
					# }
                # else {
                    # MSwitch_EventBulk( $own_hash, $eventcopy1, '0',
                        # 'MSwitch_Notify' );
                # }

##########################################
                ### pruefe Bridge
                #Log3("test",6,"aufruf checkbridge");

                my ( $chbridge, $zweig, $bridge ) =
                  MSwitch_checkbridge( $own_hash, $ownName, $eventcopy1, );

                next EVENT if $chbridge eq "found bridge";

                ########################## prüfe Bridge

            }

            # Teste auf einhaltung Triggercondition ENDE
############################################################################################################

         #   my $eventcopy1 = $eventcopy;
           # if ( $triggerdevice eq "all_events" ) {

           # fügt dem event den devicenamen hinzu , wenn global getriggert wird
          # ##     $eventcopy1 = "$devName:$eventcopy";
            #}

            if ( AttrVal( $ownName, "MSwitch_Selftrigger_always", 0 ) eq "1"
                && $incommingdevice eq "MSwitch_Self" )
            {
                $eventcopy1 = "MSwitch_Self:$eventcopy";
                $eventcopy  = $eventcopy1;
            }

            my $direktswitch = 0;
            my @eventsplit   = split( /\:/, $eventcopy );
            my $eventstellen = @eventsplit;
            my $testvar      = '';

            #test auf zweige cmd1/2 and switch MSwitch on/off
            if ( $triggeron ne 'no_trigger' ) {

                $testvar =
                  MSwitch_checktrigger( $own_hash, $ownName,
                    $eventstellen, $triggeron, $incommingdevice, 'on',
                    $eventcopy, @eventsplit );

                if ( $testvar ne 'undef' ) {

                    # next EVENT if $chbridge ne "no_bridge";
                    $set       = $testvar;
                    $check     = 1;
                    $foundcmd1 = 1;
                    $trigevent = $eventcopy;
                }

            }

            if ( $triggeroff ne 'no_trigger' ) {

                $testvar =
                  MSwitch_checktrigger( $own_hash, $ownName,
                    $eventstellen, $triggeroff, $incommingdevice, 'off',
                    $eventcopy, @eventsplit );
                if ( $testvar ne 'undef' ) {

      # my $chbridge = MSwitch_checkbridge( $own_hash, $ownName, $eventcopy1, );
      #next EVENT if $chbridge ne "no_bridge";

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
                  MSwitch_checktrigger( $own_hash, $ownName,
                    $eventstellen, $triggercmdoff, $incommingdevice, 'offonly',
                    $eventcopy, @eventsplit );
                if ( $testvar ne 'undef' ) {

       #my $chbridge = MSwitch_checkbridge( $own_hash, $ownName, $eventcopy1, );
       # next EVENT if $chbridge ne "no_bridge";

                    MSwitch_LOG( $ownName, 6,
                        "Befehl eingefuegt  L:" . __LINE__ );
                    push @cmdarray, $own_hash . ',off,check,' . $eventcopy1;
                    $check     = 1;
                    $foundcmd2 = 1;
                }

            }

            if ( $triggercmdon ne 'no_trigger' ) {

                $testvar =
                  MSwitch_checktrigger( $own_hash, $ownName,
                    $eventstellen, $triggercmdon, $incommingdevice, 'ononly',
                    $eventcopy, @eventsplit );

                if ( $testvar ne 'undef' ) {

                    MSwitch_LOG( $ownName, 6,
                        "Befehl eingefuegt  L:" . __LINE__ );

        #my $chbridge = MSwitch_checkbridge( $own_hash, $ownName,$eventcopy1, );
        #next EVENT if $chbridge ne "no_bridge";
                    push @cmdarray, $own_hash . ',on,check,' . $eventcopy1;
                    $check     = 1;
                    $foundcmd1 = 1;
                }
            }

            # speichert 20 events ab zur weiterne funktion ( funktionen )
            # ändern auf bedarfschaltung

            if (    $check == '1'
                and defined( ( split( /:/, $eventcopy ) )[1] )
                and ( ( split( /:/, $eventcopy ) )[1] =~ /^[-]?[0-9,.E]+$/ ) )
            {
                my $evwert    = ( split( /:/, $eventcopy ) )[1];
                my $evreading = ( split( /:/, $eventcopy ) )[0];
                my @eventfunction;
				@eventfunction = split( / /, $own_hash->{helper}{eventhistory}{$evreading} ) if defined $evreading;
                unshift( @eventfunction, $evwert );
                while ( @eventfunction > $evhistory ) {
                    pop(@eventfunction);
                }
                my $neweventfunction = join( ' ', @eventfunction );
                $own_hash->{helper}{eventhistory}{$evreading} =
                  $neweventfunction;
            }
######################################
            #test auf zweige cmd1/2 only ENDE

            $anzahl = @cmdarray;

            $own_hash->{IncommingHandle} = 'fromnotify'
              if AttrVal( $ownName, 'MSwitch_Mode', 'Notify' ) ne "Dummy";
            $event =~ s/~/ /g;    #?
            if ( $devicemode eq "Notify" and $activecount == 0 ) {

                # reading activity aktualisieren
                readingsSingleUpdate( $own_hash, "state",
                    'active', $showevents )
                  if ReadingsVal( $ownName, 'state', '0' ) eq "active";
                $activecount = 1;
            }

         # abfrage und setzten von blocking
         # schalte blocking an , wenn anzahl grösser 0 und MSwitch_Wait gesetzt
            my $mswait = $attr{$ownName}{MSwitch_Wait};
            if ( !defined $mswait ) { $mswait = '0'; }
            if ( $anzahl > 0 && $mswait > 0 ) {
                readingsSingleUpdate( $own_hash, "waiting", ( time + $mswait ),
                    0 );
            }

            # abfrage und setzten von blocking ENDE
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
                    }
                }
                return;
            }
        }











        #foundcmd1/2
        if ( $foundcmd1 eq "1"
            && AttrVal( $ownName, "MSwitch_Reset_EVT_CMD1_COUNT", 'undef' ) ne
            'undef' )
        {
            my $inhalt = ReadingsVal( $ownName, 'EVT_CMD1_COUNT', '0' );
            if ( $resetcmd1 == 0 ) {
                $inhalt++;
                readingsSingleUpdate( $own_hash, "EVT_CMD1_COUNT",
                    $inhalt, $showevents );
            }
            elsif ( $resetcmd1 > 0 && $inhalt < $resetcmd1 ) {
                $inhalt++;
                readingsSingleUpdate( $own_hash, "EVT_CMD1_COUNT",
                    $inhalt, $showevents );
            }
        }

        if ( $foundcmd2 eq "1"
            && AttrVal( $ownName, "MSwitch_Reset_EVT_CMD2_COUNT", 'undef' ) ne
            'undef' )
        {
            my $inhalt = ReadingsVal( $ownName, 'EVT_CMD2_COUNT', '0' );
            if ( $resetcmd2 == 0 ) {
                $inhalt++;
                readingsSingleUpdate( $own_hash, "EVT_CMD2_COUNT",
                    $inhalt, $showevents );
            }
            elsif ( $resetcmd2 > 0 && $inhalt < $resetcmd2 ) {
                $inhalt++;
                readingsSingleUpdate( $own_hash, "EVT_CMD2_COUNT",
                    $inhalt, $showevents );
            }
        }

     #ausführen aller cmds in @cmdarray nach triggertest aber vor conditiontest
     #my @cmdarray1;	#enthält auszuführende befehle nach conditiontest
     #schaltet zweig 3 und 4

        # ACHTUNG
        if ( $anzahl && $anzahl != 0 ) {

            MSwitch_LOG( $ownName, 6,
                "$anzahl auszuführende Befehle gefunden L:" . __LINE__ );
            MSwitch_LOG( $ownName, 6, "Befehlsarray: @cmdarray L:" . __LINE__ );

            #aberabeite aller befehlssätze in cmdarray
            MSwitch_Safemode($own_hash);

          LOOP31: foreach (@cmdarray) {

                my $test = $_;
                if ( $_ eq 'undef' ) { next LOOP31; }
                my ( $ar1, $ar2, $ar3, $ar4 ) = split( /,/, $test );
                if ( !defined $ar2 ) { $ar2 = ''; }
                if ( $ar2 eq '' ) {
                    next LOOP31;
                }
                my $returncmd = 'undef';
				
				
				
				
MSwitch_LOG( $ownName, 6, "aufruf execnotif: $ar2, $ar3, $ar4, $execids L:" . __LINE__ );
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
                        MSwitch_LOG( $ownName, 6,
                            "XXXX -  Befehlsausführung: $_ L:" . __LINE__ );
                        my $errors = AnalyzeCommandChain( undef, $_ );
                        if ( defined($errors) ) {
                            MSwitch_LOG( $ownName, 1,
"$ownName MSwitch_Notify: Fehler bei Befehlsausführung $errors -> Comand: $_ "
                                  . __LINE__ );
                        }
                    }

                    if ( length($ecec) > 100 ) {
                        $ecec = substr( $ecec, 0, 100 ) . '....';
                    }

                    readingsSingleUpdate( $own_hash, "last_exec_cmd", $ecec,
                        $showevents )
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
        my $events      = '';
        my $eventhash   = $own_hash->{helper}{events}{$devName};
        if ( AttrVal( $ownName, "MSwitch_Selftrigger_always", 0 ) eq "1" ) {
            $eventhash = $own_hash->{helper}{events}{MSwitch_Self};
            foreach my $name ( keys %{$eventhash} ) {
                $events = $events . 'MSwitch_Self:' . $name . '#[tr]';
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
            readingsSingleUpdate( $own_hash, ".Device_Events", $events, 1 );
        }

        # schreiben ende
        # schalte modul an/aus bei entsprechendem notify
        # teste auf condition
        return if $set eq 'noset';   # keine MSwitch on/off incl cmd1/2 gefunden

######################
# schaltet zweig 1 und 2 , wenn $set befehl enthält , es wird nur MSwitch geschaltet, Devices werden dann 'mitgerissen'
        my $cs;

        if ( $triggerdevice eq "all_events" ) {
            $cs = "set $ownName $set $devName:$trigevent";
        }
        else {
            $cs = "set $ownName $set $trigevent";
        }

        if ( $attrrandomnumber ne '' ) {
            MSwitch_Createnumber($own_hash);
        }

        if ( $debugmode ne '2' ) {
            MSwitch_LOG( $ownName, 6, "Befehlsausführung: $cs L:" . __LINE__ );
            my $errors = AnalyzeCommandChain( undef, $cs );
        }
        return;
    }
}
#########################
sub MSwitch_checkbridge($$$) {
    my ( $hash, $name, $event ) = @_;
    MSwitch_LOG( $name, 6, "SUB BRIDGE: $event L:" . __LINE__ );
    my $bridgemode = ReadingsVal( $name, '.Distributor', '0' );
    my $expertmode = AttrVal( $name, 'MSwitch_Expert', '0' );

    MSwitch_LOG( $name, 6, "SUB BRIDGE bridgemode: $bridgemode L:" . __LINE__ );
    return "no_bridge" if $expertmode eq "0";
    return "no_bridge" if $bridgemode eq "0";

    my $foundkey = "undef";
    my $etikeys  = $hash->{helper}{eventtoid};
    foreach my $a ( sort keys %{$etikeys} ) {

        MSwitch_LOG( $name, 6, "SUB BRIDGE KEY: $a L:" . __LINE__ );

        my $re = qr/$a/;
        $foundkey = $a if ( $event =~ /$re/ );

    }

    if ( !defined $hash->{helper}{eventtoid}{$foundkey} ) {
        return "NO BRIDGE FOUND !";
    }
    my @bridge = split( / /, $hash->{helper}{eventtoid}{$foundkey} );
    my $zweig;

    $zweig = "on"  if $bridge[0] eq "cmd1";
    $zweig = "off" if $bridge[0] eq "cmd2";

    MSwitch_LOG( $name, 6,
            "ID Bridge gefunden: zweig $bridge[0] , $bridge[2] "
          . @bridge . " L:"
          . __LINE__ );
	$hash->{helper}{aktevent}=$event;
    MSwitch_Exec_Notif( $hash, $zweig, 'nocheck', '', $bridge[2] );

    return ( "bridge found", $zweig, $bridge[2] );
}
############################

sub clear_utf8_flag {
    my ($data) = @_;

    my $wanted = sub {
        if ( ref $_ ) {
            my $obj = $_;
            if ( 'HASH' eq reftype $obj) {
                foreach my $key ( keys %$obj ) {
                    if ( Encode::is_utf8($key) ) {
                        my $value = delete $obj->{$key};
                        Encode::_utf8_off($key);
                        $obj->{$key} = $value;
                    }

                    my $value = $obj->{$key};
                    if (   defined $value
                        && !ref $value
                        && Encode::is_utf8($value) )
                    {
                        Encode::_utf8_off( $obj->{$key} );
                    }
                }
            }
            elsif ( 'ARRAY' eq reftype $obj) {
                foreach my $item (@$obj) {
                    if (   defined $item
                        && !ref $item
                        && Encode::is_utf8($item) )
                    {
                        Encode::_utf8_off($item);
                    }
                }
            }
        }
    };

    return $data;
}

############################
sub MSwitch_fhemwebconf($$$$) {

    my ( $FW_wname, $d, $room, $pageHash ) =
      @_;    # pageHash is set for summaryFn.
    my $hash = $defs{$d};
    my $Name = $hash->{NAME};
    my @found_devices;
    delete( $hash->{NOTIFYDEV} );
    readingsSingleUpdate( $hash, "EVENTCONF", "start", 1 );

    my $preconf1 = '';
    my $preconf  = '';

    my $devstring;
    my $cmds;
	
    $cmds .=
"' reset_Switching_once loadHTTP del_repeats reset_device active del_function_data inactive on off del_delays backup_MSwitch fakeevent exec_cmd_1 exec_cmd_2 wait del_repeats reload_timer change_renamed reset_cmd_count ',";
    $devstring .= "'MSwitch_Self',";

    @found_devices = devspec2array("TYPE=.*");
    for (@found_devices) {
        my $test = getAllSets($_);
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
    my $at;
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
    chop $at;

    $at = "[" . $at . "]";

    # suche notify

    my $nothash;
    my $notinsert;
    my $notify;
    my $notifydef;

    @found_devices = devspec2array("TYPE=notify");
    for (@found_devices) {
        $nothash   = $defs{$_};
        $notinsert = $nothash->{DEF};
        $notify .= "'" . $_ . "',";
    }
    chop $notifydef;
    chop $notify;

    $notify = "[" . $notify . "]";

    my $return = "

	<div id='mode'>Konfigurationsmodus:&nbsp;";
    $return .=
"<input name=\"conf\" id=\"config\" type=\"button\" value=\"import MSwitch_Config\" onclick=\"javascript: conf('importCONFIG',id)\"\">&nbsp;
	<input name=\"conf\" id=\"importat\" type=\"button\" value=\"import AT\" onclick=\"javascript: conf('importAT',id)\"\">&nbsp;
	<input name=\"conf\" id=\"importnotify\" type=\"button\" value=\"import NOTIFY\" onclick=\"javascript: conf('importNOTIFY',id)\"\">
	<input name=\"conf\" id=\"importpreconf\" type=\"button\" value=\"import PRECONF\" onclick=\"javascript: conf('importPRECONF',id)\"\">
	";

    my $templateinhalt = '';
    my $template       = "";
    my $adress         = $templatefile . "01_inhalt.txt";

    #

    $templateinhalt = get($adress);

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

    $return .= "
	<div id='importWIZARD' style=\"display:none\">
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
    foreach my $akt (@owna) {
        next if $akt eq "";
        my @test = split( /:/, $akt );
        $j1 .= "ownattr['$test[0]']  = '$test[1]';\n";
    }

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
	var notify = " . $notify . ";
	var at = " . $at . ";
	var templatesel ='" . $hash->{helper}{template} . "';

	\$(document).ready(function() {
    \$(window).load(function() {
	name = '$Name';
	// loadScript(\"pgm2/MSwitch_Preconf.js?v=" . $fileend . "\");
    loadScript(\"pgm2/MSwitch_Wizard.js?v=" . $fileend
      . "\", function(){start1(name)});";

    if ( $hash->{helper}{template} ne "no" ) {

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
    my $hash       = $defs{$d};
    my $Name       = $hash->{NAME};
    my $jsvarset   = '';
    my $j1         = '';
    my $border     = 0;
    my $ver        = ReadingsVal( $Name, '.V_Check', '' );
    my $expertmode = AttrVal( $Name, 'MSwitch_Expert', '0' );
    my $noshow     = 0;
    my @hidecmds = split( /,/, AttrVal( $Name, 'MSwitch_Hidecmds', 'undef' ) );

    my $testgroups = $data{MSwitch}{$Name}{groups};
    my @msgruppen  = ( keys %{$testgroups} );
    my $info       = '';
    #systemintegration
    my $system = ReadingsVal( $Name, '.sysconf', '' );

    if ( $system ne '' ) {

        $system =
            "<script type=\"text/javascript\">var nameself ='"
          . $Name
          . "';</script>"
          . $system;

        $system =~ s/#\[tr\]/[tr]/g;
        $system =~ s/#\[wa\]/|/g;
        $system =~ s/#\[sp\]/ /g;
        $system =~ s/#\[nl\]/\n/g;
        $system =~ s/#\[se\]/;/g;
        $system =~ s/#\[bs\]/\\/g;
        $system =~ s/#\[dp\]/:/g;
        $system =~ s/#\[st\]/'/g;
        $system =~ s/#\[dst\]/\"/g;
        $system =~ s/#\[tab\]/    /g;
        $system =~ s/#\[ko\]/,/g;
        $system =~ s/\[tr\]/#[tr]/g;

    }

########## korrigiere version
    if ( ReadingsVal( $Name, '.V_Check', 'undef' ) ne $vupdate
        && $autoupdate eq "on" )
    {
        MSwitch_VUpdate($hash);
    }

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
    my $Triggerdevice  = ReadingsVal( $Name, 'Trigger_device', '' );
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

        if ( $_ eq 'no_trigger' ) {
            next LOOP12;
        }

        if ( $triggeron eq $_ ) {
            $optionon =
                $optionon
              . "<option selected=\"selected\" value=\"$_\">"
              . $_
              . "</option>";
            $to = '1';
        }
        else {
            $optionon .= "<option value=\"$_\">" . $_ . "</option>";
        }

        if ( $triggercmdon eq $_ ) {
            $optioncmdon =
                $optioncmdon
              . "<option selected=\"selected\" value=\"$_\">"
              . $_
              . "</option>";
            $toc = '1';
        }
        else {
            $optioncmdon .= "<option value=\"$_\">" . $_ . "</option>";
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
        $optiongeneral .= "<option value=\"$op\">" . $op . "</option>";

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
              . "<option selected=\"selected\" value=\"$_\">$_</option>";
            $to = '1';
        }
        else {
            $optionoff = $optionoff . "<option value=\"$_\">$_</option>";
        }

        if ( $triggercmdoff eq $_ ) {
            $optioncmdoff = $optioncmdoff
              . "<option selected=\"selected\" value=\"$_\">$_</option>";
            $toc = '1';
        }
        else {
            $optioncmdoff = $optioncmdoff . "<option value=\"$_\">$_</option>";
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

    if ( ReadingsVal( $Name, 'Trigger_device', 'no_trigger' ) eq 'no_trigger' )
    {
        $triggerdevices =
"<option selected=\"selected\" value=\"no_trigger\">no_trigger</option>";
    }
    else {
        $triggerdevices = "<option  value=\"no_trigger\">no_trigger</option>";
    }

    if ( $expertmode eq '1' ) {

        if ( ReadingsVal( $Name, 'Trigger_device', 'no_trigger' ) eq
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
        if ( ReadingsVal( $Name, 'Trigger_device', 'no_trigger' ) eq 'Logfile' )
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
        ReadingsVal( $Name, 'Trigger_device', 'no_trigger' ) eq 'MSwitch_Self' )
    {
        $triggerdevices .=
"<option selected=\"selected\" value=\"MSwitch_Self\">MSwitch_Self ($Name)</option>";
    }
    else {
        $triggerdevices .=
          "<option  value=\"MSwitch_Self\">MSwitch_Self ($Name)</option>";
    }

    my $affecteddevices = ReadingsVal( $Name, '.Device_Affected', 'no_device' );

    # affected devices to hash
    my %usedevices;
    my @deftoarray = split( /,/, $affecteddevices );
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
    my $Triggerdevicetmp = ReadingsVal( $Name, 'Trigger_device', '' );
    my $savecmds =
      AttrVal( $Name, 'MSwitch_DeleteCMDs', $deletesavedcmdsstandart );

  LOOP9: for my $name ( sort @found_devices ) {
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
        if ( $MSwitchIncludeDevicecmds eq '1' and $hash->{INIT} ne "define" ) {
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
execute and exit if applies->Abbruch nach Ausführung
Repeats:->Befehlswiederholungen:
Repeatdelay in sec:->Wiederholungsverzögerung in Sekunden:
delay with Cond-check immediately and delayed:->Verzögerung mit Bedingungsprüfung sofort und vor Ausführung:
delay with Cond-check immediately only:->Verzögerung mit Bedingungsprüfung sofort:
delay with Cond-check delayed only:->Verzögerung mit Bedingungsprüfung vor Ausführung:
at with Cond-check immediately and delayed:->Ausführungszeit mit Bedingungsprüfung sofort und vor Ausführung:
at with Cond-check immediately only:->Ausführungszeit mit Bedingungsprüfung sofort:
at with Cond-check delayed only->Ausführungszeit mit Bedingungsprüfung vor Ausführung:
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
    my @affecteddevices =
      split( /,/, ReadingsVal( $Name, '.Device_Affected', 'no_device' ) );
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

            @befehlssatz = split( / /, $cmdsatz{$devicenamet} );
            my $aktdevice = $_;
            ## optionen erzeugen
            my $option1html  = '';
            my $option2html  = '';
            my $selectedhtml = "";

            if ( !defined( $savedetails{ $aktdevice . '_on' } ) ) {
                my $key = '';
                $key = $aktdevice . "_on";
                $savedetails{$key} = 'no_action';
            }

            if ( !defined( $savedetails{ $aktdevice . '_off' } ) ) {
                my $key = '';
                $key = $aktdevice . "_off";
                $savedetails{$key} = 'no_action';
            }

            if ( !defined( $savedetails{ $aktdevice . '_onarg' } ) ) {
                my $key = '';
                $key = $aktdevice . "_onarg";
                $savedetails{$key} = '';
            }

            if ( !defined( $savedetails{ $aktdevice . '_offarg' } ) ) {
                my $key = '';
                $key = $aktdevice . "_offarg";
                $savedetails{$key} = '';
            }

            if ( !defined( $savedetails{ $aktdevice . '_delayaton' } ) ) {
                my $key = '';
                $key = $aktdevice . "_delayaton";
                $savedetails{$key} = 'delay1';
            }

            if ( !defined( $savedetails{ $aktdevice . '_delayatoff' } ) ) {
                my $key = '';
                $key = $aktdevice . "_delayatoff";
                $savedetails{$key} = 'delay1';
            }

            if ( !defined( $savedetails{ $aktdevice . '_timeon' } ) ) {
                my $key = '';
                $key = $aktdevice . "_timeon";

                #$savedetails{$key} = '000000';   #change
                $savedetails{$key} = '00:00:00';
            }

            if ( !defined( $savedetails{ $aktdevice . '_timeoff' } ) ) {
                my $key = '';
                $key = $aktdevice . "_timeoff";

                #$savedetails{$key} = '000000';  #change
                $savedetails{$key} = '00:00:00';
            }

            if ( !defined( $savedetails{ $aktdevice . '_conditionon' } ) ) {
                my $key = '';
                $key = $aktdevice . "_conditionon";
                $savedetails{$key} = '';
            }

            if ( !defined( $savedetails{ $aktdevice . '_conditionoff' } ) ) {
                my $key = '';
                $key = $aktdevice . "_conditionoff";
                $savedetails{$key} = '';
            }

            foreach (@befehlssatz)    #befehlssatz einfügen
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

            if ( '' eq $savedetails{ $aktdevice . '_delayaton' } ) {
                $savedetails{ $aktdevice . '_delayaton' } = 'delay1';
            }

            if ( '' eq $savedetails{ $aktdevice . '_delayatoff' } ) {
                $savedetails{ $aktdevice . '_delayatoff' } = 'delay1';
            }

            if ( '' eq $savedetails{ $aktdevice . '_timeoff' } ) {
                $savedetails{ $aktdevice . '_timeoff' } = '0';
            }

            if ( '' eq $savedetails{ $aktdevice . '_timeon' } ) {
                $savedetails{ $aktdevice . '_timeon' } = '0';
            }

            if ( !defined $savedetails{ $aktdevice . '_showreihe' }
                || '' eq $savedetails{ $aktdevice . '_showreihe' } )
            {
                $savedetails{ $aktdevice . '_showreihe' } = '1';
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

            if ( $devicenamet ne 'FreeCmd' ) {
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

                if (   AttrVal( $Name, 'MSwitch_Debug', "0" ) eq '1'
                    || AttrVal( $Name, 'MSwitch_Debug', "0" ) eq '3' )
                {
                    $MSTEST1 =
                        "<input name='info' name='TestCMD"
                      . $_
                      . "' id='TestCMD"
                      . $_
                      . "'type='button' value='test comand' onclick=\"javascript: testcmd('cmdon$nopoint','$devicenamet','cmdonopt$nopoint')\">";

                    $MSTEST2 =
                        "<input name='info' name='TestCMD"
                      . $_
                      . "' id='TestCMD"
                      . $_
                      . "'type='button' value='test comand' onclick=\"javascript: testcmd('cmdoff$nopoint','$devicenamet','cmdoffopt$nopoint')\">";
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

                if (   AttrVal( $Name, 'MSwitch_Debug', "0" ) eq '1'
                    || AttrVal( $Name, 'MSwitch_Debug', "0" ) eq '3' )
                {
                    $MSTEST1 =
                        "<input name='info' name='TestCMD"
                      . $_
                      . "' id='TestCMD"
                      . $_
                      . "'type='button' value='test comand' onclick=\"javascript: testcmd('cmdonopt$nopoint','$devicenamet')\">";

                    $MSTEST2 =
                        "<input name='info' name='TestCMD"
                      . $_
                      . "' id='TestCMD"
                      . $_
                      . "'type='button' value='test comand' onclick=\"javascript: testcmd('cmdoffopt$nopoint','$devicenamet')\">";

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
"Repeats: <input type='text' id='repeatcount' name='repeatcount"
                  . $nopoint
                  . "' size='10' value ='"
                  . $savedetails{ $aktdevice . '_repeatcount' } . "'>
						&nbsp;&nbsp;&nbsp;
						Repeatdelay in sec:
						<input type='text' id='repeattime' name='repeattime"
                  . $nopoint
                  . "' size='10' value ='"
                  . $savedetails{ $aktdevice . '_repeattime' } . "'>";
            }

            if ( $devicenumber == 1 ) {
                $ACTIONsatz =
                  "<input name='info' class=\"randomidclass\" id=\"add_action1_"
                  . rand(1000000)
                  . "\" type='button' value='add action for $add' onclick=\"javascript: addevice('$add')\">";
            }

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
            foreach (@translate) {
                my ( $wert1, $wert2 ) = split( /->/, $_ );
                $controlhtmldevice =~ s/$wert1/$wert2/g;
            }

            my $aktpriority = $savedetails{ $aktdevice . '_showreihe' };
            if ( grep { $_ eq $aktpriority } @hidecmds ) {
                $noshow++;
                $detailhtml .=
"<div t='1' id='MSwitchWebTR' nm='$hash->{NAME}' name ='noshow' cellpadding='0' style='display: none;border-spacing:0px;'>"
                  . $controlhtmldevice
                  . "</div>";
            }
            else {

                if ( $savedetails{ $aktdevice . '_hidecmd' } eq "1" ) {
                    $noshow++;
                    $detailhtml .=
"<div t='1' id='MSwitchWebTR' nm='$hash->{NAME}' name ='noshow' cellpadding='0' style='display: none;border-spacing:0px;'>"
                      . $controlhtmldevice
                      . "</div>";
                }
                else {
                    $detailhtml .=
"<div t='1' id='MSwitchWebTR' nm='$hash->{NAME}' cellpadding='0' style='border-spacing:0px;'>"
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
			devices += '#[DN]';
			";
        }

        # textersetzung modify

        if ( $noshow > 0 ) {
            $modify =
"<table width = '100%' border='0' class='block wide' name ='noshowtask' id='MSwitchDetails' cellpadding='4' style='border-spacing:0px;' nm='MSwitch'>
			<tr class='even'><td><br>
			Hidden command branches are available ($noshow)

			<input type='button' id='aw_show' value='show hidden cmds' >
			
			<br>&nbsp;
			</td></tr></table><br>
			" . $modify;
        }

        foreach (@translate) {
            my ( $wert1, $wert2 ) = split( /->/, $_ );
            $modify =~ s/$wert1/$wert2/g;
        }

        $detailhtml .= $modify;
    }

    # ende kommandofelder
####################
    my $triggercondition = ReadingsVal( $Name, '.Trigger_condition', '' );
    $triggercondition =~ s/~/ /g;

    $triggercondition =~ s/#\[dp\]/:/g;
    $triggercondition =~ s/#\[pt\]/./g;
    $triggercondition =~ s/#\[ti\]/~/g;
    $triggercondition =~ s/#\[sp\]/ /g;

    my $triggertime = ReadingsVal( $Name, '.Trigger_time', '' );
    $triggertime =~ s/#\[dp\]/:/g;

    my @triggertimes = split( /~/, $triggertime );
    my $condition = ReadingsVal( $Name, '.Trigger_time', '' );
    $condition = "" if $condition eq "undef";

    my $lenght        = length($condition);
    my $timeon        = '';
    my $timeoff       = '';
    my $timeononly    = '';
    my $timeoffonly   = '';
    my $timeonoffonly = '';

    if ( $lenght != 0 ) {
        $timeon        = substr( $triggertimes[0], 2 );
        $timeoff       = substr( $triggertimes[1], 3 );
        $timeononly    = substr( $triggertimes[2], 6 );
        $timeoffonly   = substr( $triggertimes[3], 7 );
        $timeonoffonly = substr( $triggertimes[4], 9 );
    }

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
        if ( $hash->{helper}{aktivelog} eq 'on' ) {
            $activelog = 'checked';
        }

        $ret .= "<table border='$border' class='block wide' id=''>
			 <tr class='even'>
			 <td><center>&nbsp;<br>
			 $text<br>&nbsp;<br>
			 <textarea name=\"log\" id=\"log\" rows=\"5\" cols=\"160\" STYLE=\"font-family:Arial;font-size:9pt;\">"
          . $Zeilen . "</textarea>
			  <br>&nbsp;<br>
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
        $ret .= "<br>&nbsp;</td></tr></table><br>
		
		 ";
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

    if ( $system ne '' ) {
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
      . $timeon . "' onClick=\"javascript:bigwindow(this.id);\">";
    $MSonand2 =
      "<input type='text' id='timeoff' name='timeoff' size='35'  value ='"
      . $timeoff . "' onClick=\"javascript:bigwindow(this.id);\">";
    $MSexec1 =
      "<input type='text' id='timeononly' name='timeononly' size='35'  value ='"
      . $timeononly . "' onClick=\"javascript:bigwindow(this.id);\">";

    if ( $hash->{INIT} ne 'define' ) {
        $MSexec2 =
"<input type='text' id='timeoffonly' name='timeoffonly' size='35'  value ='"
          . $timeoffonly . "'onClick=\"javascript:bigwindow(this.id);\">";

        $MSexec12 =
"<input type='text' id='timeoffonly' name='timeoffonly' size='35'  value ='"
          . $timeonoffonly . "' onClick=\"javascript:bigwindow(this.id);\">";
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
apply filter to saved events->Filter auf gespeicherte Events anwenden
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
    my $testlog        = ReadingsVal( $Name, 'Trigger_log', 'on' );
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

    $MSMODLINE =
"<input type=\"button\" id=\"aw_md1\" value=\"apply filter to saved events\" $disable>
		<input type=\"button\" id=\"aw_md20\" value=\"clear saved events\" $disable>";

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

    if (   ReadingsVal( $Name, 'Trigger_device', 'no_trigger' ) ne 'no_trigger'
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
            ReadingsVal( $Name, 'Trigger_device', 'no_trigger' ) ne 'no_trigger'
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
				$MSDISTRIBUTOREVENT:
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
        && ReadingsVal( $Name, 'Trigger_device', 'no_trigger' ) ne
        'no_trigger' )
    {
        $selftrigger       = "1";
        $showtriggerdevice = $showtriggerdevice . " (or MSwitch_Self)";
    }
    elsif (AttrVal( $Name, "MSwitch_Selftrigger_always", 0 ) eq "1"
        && ReadingsVal( $Name, 'Trigger_device', 'no_trigger' ) eq
        'no_trigger' )
    {
        $selftrigger       = "1";
        $showtriggerdevice = "MSwitch_Self:";
    }
    if ( ReadingsVal( $Name, 'Trigger_device', 'no_trigger' ) ne 'no_trigger'
        || $selftrigger ne "" )
    {
        $MSTRIGGER = "Trigger " . $showtriggerdevice . "";
        $MSCMDONTRIGGER =
          "<select id = \"trigon\" name=\"trigon\">" . $optionon . "</select>";
##############
        my $fieldon = "";
        if ( $triggeron =~ m/{(.*)}/ ) {
            my $exec = "\$fieldon = " . $1;

            eval($exec);
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

            eval($exec);
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

            eval($exec);
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

                eval($exec);
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
        $ret .=
"<table border='$border' class='block wide' id='MSwitchWebAF' nm='$hash->{NAME}'>
	<tr class=\"even\">
	<td><center><br>$DUMMYMODE<br>&nbsp;<br></td></tr></table>
	";
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
    my $language =
      AttrVal( $Name, 'MSwitch_Language',
        AttrVal( 'global', 'language', 'EN' ) );
    my $quickedit = AttrVal( $Name, 'MSwitch_Lock_Quickedit', "1" );
    my $exec1     = 0;
    my $devicetyp = AttrVal( $Name, 'MSwitch_Mode', 'Notify' );
    my $debugmode = AttrVal( $Name, 'MSwitch_Debug', '0' );

    my $Helpmode = AttrVal( $Name, 'MSwitch_Help', '0' );
    my $Help = '';

    if ( $Helpmode eq '1' ) {
        if ( $language eq "EN" ) {
            open( HELP, "<./$helpfileeng" ) || return "no Helpfile found";
        }
        else {
            open( HELP, "<./$helpfile" ) || return "no Helpfile found";
        }
        while (<HELP>) {
            $Help = $Help . $_;
        }
        close(BACKUPDATEI);
        $Help =~ s/\n/#[LINE]\\\n/g;
        $Help =~ s/"/#[DA]/g;
        $Help =~ s/'/#[A]/g;

        my %UMLAUTE = (
            'Ä' => 'Ae',
            'Ö' => 'Oe',
            'Ü' => 'Ue',
            'ä' => 'ae',
            'ö' => 'oe',
            'ü' => 'ue'
        );
        my $UMLKEYS = join( "|", keys(%UMLAUTE) );
        $Help =~ s/($UMLKEYS)/$UMLAUTE{$1}/g;
    }

    if ( $affecteddevices[0] ne 'no_device' and $hash->{INIT} ne 'define' ) {
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
    if ( AttrVal( $Name, 'MSwitch_Modul_Mode', "0" ) eq '1' ) {
        return "$info$system$hidecode";
    }
    return "$ret<br>$detailhtml$helpfile<br>$j1$hidecode";
}

####################

####################

sub MSwitch_makeCmdHash($) {
    my $loglevel = 5;
    my ($Name) = @_;

    # detailsatz in scalar laden
    my @devicedatails;
    @devicedatails =
      split( /#\[ND\]/, ReadingsVal( $Name, '.Device_Affected_Details', '' ) );
    my %savedetails;

    foreach (@devicedatails) {

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

        my @detailarray = split( /#\[NF\]/, $_ )
          ;    #enthält daten 0-5 0 - name 1-5 daten 7 und9 sind zeitangaben
        my $key = '';
        $key = $detailarray[0] . "_delayatonorg";
        $savedetails{$key} = $detailarray[7];

##### on

        my $testtimestron = $detailarray[8];
        $key = $detailarray[0] . "_delayatofforg";
        $savedetails{$key} = $detailarray[8];

        $detailarray[8]    = $testtimestron;
        $key               = $detailarray[0] . "_on";
        $savedetails{$key} = $detailarray[1];
        $key               = $detailarray[0] . "_off";
        $savedetails{$key} = $detailarray[2];
        $key               = $detailarray[0] . "_onarg";
        $savedetails{$key} = $detailarray[3];
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
    }

    my @pass = %savedetails;
    return @pass;
}
########################################

sub MSwitch_Delete_Triggermemory($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
    my $events        = ReadingsVal( $Name, '.Device_Events', '' );
    my $Triggerdevice = $hash->{Trigger_device};
    my $triggeron     = ReadingsVal( $Name, '.Trigger_on', 'no_trigger' );
    if ( !defined $triggeron ) { $triggeron = "" }
    my $triggeroff = ReadingsVal( $Name, '.Trigger_off', 'no_trigger' );
    if ( !defined $triggeroff ) { $triggeroff = "" }
    my $triggercmdon = ReadingsVal( $Name, '.Trigger_cmd_on', 'no_trigger' );
    if ( !defined $triggercmdon ) { $triggercmdon = "" }
    my $triggercmdoff = ReadingsVal( $Name, '.Trigger_cmd_off', 'no_trigger' );
    if ( !defined $triggercmdoff ) { $triggercmdoff = "" }
    my $triggerdevice = ReadingsVal( $Name, 'Trigger_device', '' );
    delete( $hash->{helper}{events} );

    $hash->{helper}{events}{$triggerdevice}{'no_trigger'}   = "on";
    $hash->{helper}{events}{$triggerdevice}{$triggeron}     = "on";
    $hash->{helper}{events}{$triggerdevice}{$triggeroff}    = "on";
    $hash->{helper}{events}{$triggerdevice}{$triggercmdon}  = "on";
    $hash->{helper}{events}{$triggerdevice}{$triggercmdoff} = "on";
    readingsSingleUpdate( $hash, ".Device_Events", 'no_trigger', 1 );
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
sub MSwitch_Exec_Notif($$$$$) {

    #Inhalt Übergabe ->  push @cmdarray, $own_hash . ',on,check,' . $eventcopy1
    my ( $hash, $comand, $check, $event, $execids ) = @_;
    my $name      = $hash->{NAME};
    my $protokoll = '';
    my $satz;

    if ( !$execids ) { $execids = "0" }
    my $showevents     = AttrVal( $name, "MSwitch_generate_Events", 1 );
    my $debugmode      = AttrVal( $name, 'MSwitch_Debug',           "0" );
    my $expertmode     = AttrVal( $name, 'MSwitch_Expert',          "0" );
    my $delaymode      = AttrVal( $name, 'MSwitch_Delete_Delays',   '0' );
    my $attrrandomtime = AttrVal( $name, 'MSwitch_RandomTime',      '' );
    my $exittest       = '';
    $exittest = "1" if $comand eq "on";
    $exittest = "2" if $comand eq "off";
    my $ekey = '';
    my $out  = '0';
    return ""
      if ( IsDisabled($name) )
      ;    # Return without any further action if the module is disabled

    if ( $delaymode eq '2' ) {
        MSwitch_Delete_specific_Delay( $hash, $name, $event );
    }

    my %devicedetails = MSwitch_makeCmdHash($name);

    # betroffene geräte suchen
    my @devices =split( /,/, ReadingsVal( $name, '.Device_Affected', 'no_device' ) );
    my $update     = '';
    my $testtoggle = '';
	 
MSwitch_LOG( $name, 6, "devices id:$execids @devices L:" . __LINE__ );

    # liste nach priorität ändern , falls expert
    @devices = MSwitch_priority( $hash, $execids, @devices );
	
	
	MSwitch_LOG( $name, 6, "devices nach priority @devices L:" . __LINE__ );
	
	
	
	
    my $lastdevice;

    my @execute;
    my @timers;
    my $timercounter = 0;
    my $eventcount=0;




  LOOP45: foreach my $device (@devices) {

        MSwitch_LOG( $name, 6, "device:-$device- L:" . __LINE__ );

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

        if ( $devicedetails{$timerkey} =~ m/{.*}/ ) {
            $devicedetails{$timerkey} = eval $devicedetails{$timerkey};
        }

        if ( $devicedetails{$timerkey} =~ m/\[.*:.*\]/ ) {

            $devicedetails{$timerkey} =
              eval MSwitch_Checkcond_state( $devicedetails{$timerkey}, $name );
        }

        if ( $devicedetails{$timerkey} =~ m/[\d]{2}:[\d]{2}:[\d]{2}/ ) {

            my $hdel = ( substr( $devicedetails{$timerkey}, 0, 2 ) ) * 3600;
            my $mdel = ( substr( $devicedetails{$timerkey}, 3, 2 ) ) * 60;
            my $sdel = ( substr( $devicedetails{$timerkey}, 6, 2 ) ) * 1;
            $devicedetails{$timerkey} = $hdel + $mdel + $sdel;
        }
        elsif ( $devicedetails{$timerkey} =~ m/^\d*\.?\d*$/ ) {
            $devicedetails{$timerkey} = $devicedetails{$timerkey};
        }
        else {

            $devicedetails{$timerkey} = 0;
        }

        # teste auf condition
        # antwort $execute 1 oder 0 ;

        my $conditionkey = $device . "_condition" . $comand;
        if ( $devicedetails{$key} ne "" && $devicedetails{$key} ne "no_action" )
        {
            my $cs = '';
            if ( $devicenamet eq 'FreeCmd' ) {
                $cs = "  $devicedetails{$device.'_'.$comand.'arg'}";
				
				MSwitch_LOG( $name, 6, "AUFRUF FREECMD $event L:" . __LINE__ );
				
				$hash->{helper}{aktevent}=$event;
				
				
				
                $cs = MSwitch_makefreecmd( $hash, $cs );
delete( $hash->{helper}{aktevent} );
                #variableersetzung erfolgt in freecmd
            }
            else {
                $cs =
"$devicedetails{$device.'_'.$comand} $devicedetails{$device.'_'.$comand.'arg'}";

                my $pos = index( $cs, "[FREECMD]" );
                if ( $pos >= 0 ) {
                    ##ggf set und name entferne
					
					$hash->{helper}{aktevent}=$event;
					
                    $cs = MSwitch_makefreecmdonly( $hash, $cs );
					
					delete( $hash->{helper}{aktevent} );
					
                }
                else {
                    $cs = "set $devicenamet " . $cs;
                }

            }

            #Variabelersetzung

            if (   $devicedetails{$timerkey} eq "0"
                || $devicedetails{$timerkey} eq "" )
            {
                # teste auf condition
                # antwort $execute 1 oder 0 ;
                $conditionkey = $device . "_condition" . $comand;
                my $execute =
                  MSwitch_checkcondition( $devicedetails{$conditionkey},
                    $name, $event );
                $testtoggle = 'undef';
                if ( $execute eq 'true' ) {
                    $lastdevice = $device;
                    $testtoggle = $cs;
                    #############

                    my $toggle = '';
                    if ( $cs =~ m/set (.*)(MSwitchtoggle)(.*)/ ) {
                        $toggle = $cs;
                        $cs = MSwitch_toggle( $hash, $cs );
                    }

                    # neu
                    $devicedetails{ $device . '_repeatcount' } = 0
                      if !defined $devicedetails{ $device . '_repeatcount' };
                    $devicedetails{ $device . '_repeattime' } = 0
                      if !defined $devicedetails{ $device . '_repeattime' };

                    my $x = 0;
                    while ( $devicedetails{ $device . '_repeatcount' } =~
                        m/\[(.*)\:(.*)\]/ )
                    {
                        $x++;    # exit
                        last if $x > 20;    # exit
                        my $setmagic = ReadingsVal( $1, $2, 0 );
                        $devicedetails{ $device . '_repeatcount' } = $setmagic;
                    }

                    $x = 0;
                    while ( $devicedetails{ $device . '_repeattime' } =~
                        m/\[(.*)\:(.*)\]/ )
                    {
                        $x++;               # exit
                        last if $x > 20;    # exit
                        my $setmagic = ReadingsVal( $1, $2, 0 );
                        $devicedetails{ $device . '_repeattime' } = $setmagic;
                    }

                    if ( $devicedetails{ $device . '_repeatcount' } ne
                        "undefined"
                        && $devicedetails{ $device . '_repeattime' } ne
                        "undefined" )
                    {

                        if ( $devicedetails{ $device . '_repeatcount' } eq "" )
                        {
                            $devicedetails{ $device . '_repeatcount' } = 0;
                        }
                        if ( $devicedetails{ $device . '_repeattime' } eq "" ) {
                            $devicedetails{ $device . '_repeattime' } = 0;
                        }

                        if (   $expertmode eq '1'
                            && $devicedetails{ $device . '_repeatcount' } > 0
                            && $devicedetails{ $device . '_repeattime' } > 0 )
                        {
                            my $i;
                            for (
                                $i = 1 ;
                                $i <=
                                $devicedetails{ $device . '_repeatcount' } ;
                                $i++
                              )
                            {


								$cs =~ s/\n/#[MSNL]/g;
								
                                my $msg2 = $cs . "|" . $name;

                                if ( $toggle ne '' ) {

                                    $msg2 = $toggle . "|" . $name;
                                }
                                my $timecond =
                                  gettimeofday() +
                                  ( ( $i + 1 ) *
                                      $devicedetails{ $device . '_repeattime' }
                                  );

                                $msg2 = $msg2 . ",TIMECOND";
                                MSwitch_LOG( $name, 6,
"Befehlswiederholungen gesetzt: $timecond  L:"
                                      . __LINE__ );

                                my $timerset =
                                  "[REPEATER][NUMBER$timercounter]$msg2";

                                $timers[$timercounter] = $timecond;
                                push( @execute, $timerset );
                                $timercounter++;

                                if ( $out eq '1' ) {

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




                    ############################
                    if ( $cs =~ m/{.*}/ ) {

                        $cs =~ s/\[SR\]/\|/g;
                        MSwitch_LOG( $name, 6,
"finaler Befehl auf Ausführungsstapel geschoben:\n###\n$cs\n### L:"
                              . __LINE__ );
                        push( @execute, $cs );
                        if ( $out eq '1' ) {
                            MSwitch_LOG( $name, 6,
                                    "$name: Abbruchbefehl ehalten von: "
                                  . $device . " "
                                  . __LINE__ );

                            $lastdevice = $device;
                            last LOOP45;
                        }

                    }
                    else {
                        MSwitch_LOG( $name, 6,
"finaler Befehl auf Ausführungsstapel geschoben:\n###\n$cs\n### L:"
                              . __LINE__ );

                        push( @execute, $cs );
                        if ( $out eq '1' ) {
                            MSwitch_LOG( $name, 6,
                                    "Abbruchbefehl erhalten von "
                                  . $device . " "
                                  . __LINE__ );
                            $lastdevice = $device;
                            last LOOP45;
                        }
                    }
                }
            }
            else {
                if (   $attrrandomtime ne ''
                    && $devicedetails{$timerkey} eq '[random]' )
                {
                    MSwitch_LOG( $name, 6,
                        "setze zufälligen Timer L:" . __LINE__ );

                    $devicedetails{$timerkey} =
                      MSwitch_Execute_randomtimer($hash);

                    # ersetzt $devicedetails{$timerkey} gegen randomtimer
                }
                elsif ($attrrandomtime eq ''
                    && $devicedetails{$timerkey} eq '[random]' )
                {

                    MSwitch_LOG( $name, 6,
                        "setze zufälligen Timer 0 -nicht definiert L:"
                          . __LINE__ );
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

                if ( $delayinhalt ne "delay2" && $delayinhalt ne "at02" ) {
                    $execute =
                      MSwitch_checkcondition( $devicedetails{$conditionkey},
                        $name, $event );
                }

                if ( $execute eq "true" ) {
                    if ( $delayinhalt eq 'at0' || $delayinhalt eq 'at1' ) {
                        $timecond =
                          MSwitch_replace_delay( $hash, $teststateorg );
                    }

                    if ( $delayinhalt eq 'at1' || $delayinhalt eq 'delay0' ) {
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
                      . $device;

                    $testtoggle = 'undef';
                    MSwitch_LOG( $name, 6,
                        "setze Verzögerung $timecond L:" . __LINE__ );

                    my $timerset = "[TIMER][NUMBER$timercounter]$msg2";

                    $timers[$timercounter] = $timecond;
                    push( @execute, $timerset );
                    $timercounter++;

                    if ( $expertmode eq "1" && $device ) {
                        readingsSingleUpdate( $hash, "last_cmd",
                            $hash->{helper}{priorityids}{$device},
                            $showevents );
                    }

                    if ( $out eq '1' ) {

                        #abbruchbefehl erhalten von $device
                        MSwitch_LOG( $name, 6,
                                "Abbruchbefehl erhalten von "
                              . $device . " L:"
                              . __LINE__ );
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

    if ( $expertmode eq "1" && $lastdevice ) {
        readingsSingleUpdate( $hash, "last_cmd",
            $hash->{helper}{priorityids}{$lastdevice}, $showevents );
    }

    my $fullstring = join( '[|]', @execute );
	
	
    my $msg;
	
	
	
	
	

    MSwitch_LOG( $name, 6, "Ausführung Befehlsstapel L:" . __LINE__ );
	
	


    if ( AttrVal( $name, 'MSwitch_Switching_once', 0 ) == 1
        && $fullstring eq $hash->{helper}{lastexecute} )
    {
        MSwitch_LOG( $name, 6,
"Ausführung Befehlsstapel abgebrochen, Stapel wurde bereits ausgeführt L:"
              . __LINE__ );
        MSwitch_LOG( $name, 6,
            "(attr MSwitch_Switching_once gesetzt) L:" . __LINE__ );
    }
    else 
	{
		
		
	MSwitch_LOG( $name, 6,"anzahl befehle : ".@execute );	

		
        foreach my $device (@execute) {
			
	
		 MSwitch_LOG( $name, 6,"-- Ausgeführter Befehl: -$device- L:". __LINE__ );	
            next if $device eq "";
            next if $device eq " ";
            next if $device eq "  ";

            if ( $debugmode eq '2' ) {

                MSwitch_LOG( $name, 6,
                    "nicht Ausgeführter (Debug2) Befehl: $device L:"
                      . __LINE__ );
                next;
            }



#my $devictest =  $device;
#$devictest =~ s/\n/#[MSNL]/g;




            if ( $device =~ m/\[REPEATER\].*/ ) {
			
                MSwitch_LOG( $name, 6, "Repeaterhandling: $device" . __LINE__ );
                $device =~ m/\[NUMBER(.*?)](.*)/;
                my $number = $1;
                my $string = $2;
				
				$string =~ s/#\[MSNL\]/\n/g;
				
				
                MSwitch_LOG( $name, 5,
                    "extrahierte Nummer: $number L:" . __LINE__ );
                MSwitch_LOG( $name, 5,
                    "extrahierte String: $string L:" . __LINE__ );
                my $timecondition = $timers[$number];
                MSwitch_LOG( $name, 5,
                    "extrahierte Timecondition: $timecondition L:" . __LINE__ );
                $string =~ s/TIMECOND/$timecondition/g;
                MSwitch_LOG( $name, 6, "setze Repeat: $string L:" . __LINE__ );
				
				
                $hash->{helper}{repeats}{$timecondition} = "$string";
                InternalTimer( $timecondition, "MSwitch_repeat", $string );
                next;
            }

            if ( $device =~ m/\[TIMER\].*/ ) {
			
                MSwitch_LOG( $name, 6, "Timerhandling: $device" . __LINE__ );
                $device =~ m/\[NUMBER(.*?)](.*)/;
                my $number = $1;
                my $string = $2;
				$string =~ s/#\[MSNL\]/\n/g;
                MSwitch_LOG( $name, 6,
                    "extrahierte Nummer: $number L:" . __LINE__ );
                MSwitch_LOG( $name, 6,
                    "extrahierte String: $string L:" . __LINE__ );
                my $timecondition = $timers[$number];
                MSwitch_LOG( $name, 6,
                    "extrahierte Timecondition: $timecondition L:" . __LINE__ );
                $string =~ s/TIMECOND/$timecondition/g;
                MSwitch_LOG( $name, 6, "setze Timer: $string L:" . __LINE__ );
                $hash->{helper}{delays}{$string} = $timecondition;
                InternalTimer( $timecondition, "MSwitch_Restartcmd", $string );
                next;
            }



			$msg.=$device.";";



            if ( $device =~ m/{.*}/ ) {
                MSwitch_LOG( $name, 6, "$device" );
                eval($device);
                if ( $@ and $@ ne "OK" ) {
                    MSwitch_LOG( $name, 1,
                        "$name MSwitch_Set: ERROR $device: $@ " . __LINE__ );
                }
            }
            else {
                MSwitch_LOG( $name, 6, "$device" );
                my $errors = AnalyzeCommandChain( undef, $device );
                if ( defined($errors) and $errors ne "OK" ) {
                    MSwitch_LOG( $name, 1,
"MSwitch_Exec_Notif $comand: ERROR $device: $errors -> Comand: $device"
                          . " "
                          . __LINE__ );
                }
            }
        }

        if ( defined $msg && length($msg) > 100 ) { $msg = substr( $msg, 0, 100 ) . '....'; }
		
		
        readingsSingleUpdate( $hash, "last_exec_cmd", $msg, $showevents ) if defined $msg ;
	
		
		if (@execute > 0){
        $hash->{helper}{lastexecute} = $fullstring;
		MSwitch_LOG( $name, 6, "LOCK gelöscht" );
		}
		else
		{
			MSwitch_LOG( $name, 6, "LOCK nicht gelöscht" );
		}
    }

    return $satz;
}
####################
sub MSwitch_Filter_Trigger($) {
    my ($hash)        = @_;
    my $Name          = $hash->{NAME};
    my $Triggerdevice = $hash->{Trigger_device};
    my $triggeron = ReadingsVal( $Name, '.Trigger_on', 'no_trigger' );
    if ( !defined $triggeron ) { $triggeron = "" }
    my $triggeroff = ReadingsVal( $Name, '.Trigger_off', 'no_trigger' );
    if ( !defined $triggeroff ) { $triggeroff = "" }
    my $triggercmdon = ReadingsVal( $Name, '.Trigger_cmd_on', 'no_trigger' );
    if ( !defined $triggercmdon ) { $triggercmdon = "" }
    my $triggercmdoff = ReadingsVal( $Name, '.Trigger_cmd_off', 'no_trigger' );
    if ( !defined $triggercmdoff ) { $triggercmdoff = "" }
    my $triggerdevice = ReadingsVal( $Name, 'Trigger_device', '' );
    delete( $hash->{helper}{events}{$Triggerdevice} );
    $hash->{helper}{events}{$Triggerdevice}{'no_trigger'}   = "on";
    $hash->{helper}{events}{$Triggerdevice}{$triggeron}     = "on";
    $hash->{helper}{events}{$Triggerdevice}{$triggeroff}    = "on";
    $hash->{helper}{events}{$Triggerdevice}{$triggercmdon}  = "on";
    $hash->{helper}{events}{$Triggerdevice}{$triggercmdoff} = "on";
    my $events = ReadingsVal( $Name, '.Device_Events', '' );
    my @eventsall = split( /#\[tr\]/, $events );
  EVENT: foreach my $eventcopy (@eventsall) {
        my @filters =
          split( /,/, AttrVal( $Name, 'MSwitch_Trigger_Filter', '' ) )
          ;    # beinhaltet filter durch komma getrennt
        foreach my $filter (@filters) {
            if ( $filter eq "*" ) { $filter = ".*"; }

            if ( $eventcopy =~ m/$filter/ ) {

                next EVENT;
            }
        }
        $hash->{helper}{events}{$Triggerdevice}{$eventcopy} = "on";
    }
    my $eventhash = $hash->{helper}{events}{$Triggerdevice};
    $events = "";
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
####################
sub MSwitch_Restartcmd($) {
    my $incomming  = $_[0];
    my @msgarray   = split( /#\[tr\]/, $incomming );
    my $name       = $msgarray[1];
    my $hash       = $modules{MSwitch}{defptr}{$name};
    my $showevents = AttrVal( $name, "MSwitch_generate_Events", 1 );
    return "" if ( IsDisabled($name) );

    $hash->{eventsave} = 'unsaved';

    # checke versionskonflikt der datenstruktur
    if ( ReadingsVal( $name, '.V_Check', $vupdate ) ne $vupdate ) {
        my $ver = ReadingsVal( $name, '.V_Check', '' );
        MSwitch_LOG( $name, 1, "$name: Versionskonflikt - aktion abgebrochen" );
        return;
    }

    my $cs = $msgarray[0];
    $cs =~ s/##/,/g;
    my $conditionkey = $msgarray[2];
    my $event        = $msgarray[2];
    my $device       = $msgarray[5];

    my %devicedetails = MSwitch_makeCmdHash($name);

    if ( AttrVal( $name, 'MSwitch_RandomNumber', '' ) ne '' ) {
        MSwitch_Createnumber1($hash);
    }

    ### teste auf condition
    ### antwort $execute 1 oder 0 ;

    my $execute = "true";
    $devicedetails{$conditionkey} = "nocheck" if $conditionkey eq "nocheck";

    if ( $msgarray[2] ne 'nocheck' ) {

        $execute = MSwitch_checkcondition( $devicedetails{$conditionkey}, $name,
            $event );
        MSwitch_LOG( $name, 6,
            "Ergebnissrgebniss Conditioncheck: $execute L:" . __LINE__ );
    }

    my $toggle = '';
    if ( $execute eq 'true' ) {

        if ( $cs =~ m/set (.*)(MSwitchtoggle)(.*)/ ) {
            $toggle = $cs;
            $cs = MSwitch_toggle( $hash, $cs );
        }

        my $x = 0;
        while (
            $devicedetails{ $device . '_repeatcount' } =~ m/\[(.*)\:(.*)\]/ )
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

                $msg = $msg . "|" . $timecond;
                $hash->{helper}{repeats}{$timecond} = "$msg";
                MSwitch_LOG( $name, 6,
                    "Setze Befehlswiederholung $timecond L:" . __LINE__ );

                InternalTimer( $timecond, "MSwitch_repeat", $msg );
            }
        }

        my $todec = $cs;
        $cs = MSwitch_dec( $hash, $todec );
        ############################

        if ( AttrVal( $name, 'MSwitch_Debug', "0" ) eq '2' ) {
            MSwitch_LOG( $name, 6, "Befehlsausführung -> " . $cs );
        }
        else {

            if ( $cs =~ m/{.*}/ ) {

                $cs =~ s/\[SR\]/\|/g;
                MSwitch_LOG( $name, 6,
                    "finale verzögerte Befehlsausführung auf Perlebene:\n$cs\n L:"
                      . __LINE__ );
                eval($cs);
                if ($@) {
                    MSwitch_LOG( $name, 1,
                        "$name MSwitch_Set: ERROR $cs: $@ " . __LINE__ );

                }
            }
            else {
                MSwitch_LOG( $name, 6,
                    "finale verzögerte Befehlsausführung auf Fhemebene:\n$cs\n L:"
                      . __LINE__ );
                my $errors = AnalyzeCommandChain( undef, $cs );
                if ( defined($errors) and $errors ne "OK" ) {
                    MSwitch_LOG( $name, 1,
"$name MSwitch_Restartcmd :Fehler bei Befehlsausfuehrung  ERROR $errors "
                          . __LINE__ );

                }
            }
        }

        if ( length($cs) > 100
            && AttrVal( $name, 'MSwitch_Debug', "0" ) ne '4' )
        {
            $cs = substr( $cs, 0, 100 ) . '....';
        }
        readingsSingleUpdate( $hash, "last_exec_cmd", $cs, $showevents )
          if $cs ne '';
    }
    RemoveInternalTimer($incomming);
    delete( $hash->{helper}{delays}{$incomming} );

    return;
}
####################
sub MSwitch_checkcondition($$$) {

    my ( $sec, $min, $hour, $mday, $month, $year, $wday, $yday, $isdst ) =
      localtime( gettimeofday() );

    $month++;
    $year += 1900;
    my ( $condition, $name, $event ) = @_;

    MSwitch_LOG( $name, 6,
        "Bedingungsprüfung Bedingung: $condition L:" . __LINE__ );
    MSwitch_LOG( $name, 6, "Bedingungsprüfung Event: $event L:" . __LINE__ );

    # antwort execute 0 oder 1

    my $hash = $modules{MSwitch}{defptr}{$name};
    $event =~ s/"/\\"/g;    # keine " im event zulassen ERROR
    my $attrrandomnumber = AttrVal( $name, 'MSwitch_RandomNumber', '' );
    my $debugmode        = AttrVal( $name, 'MSwitch_Debug',        "0" );



#delete ($hash->{helper}{warning}{$name});



if ( $condition =~ m/\[(\$EVENT|\$EVTPART1|\$EVTPART2\|\$EVTPART3]|\$EVTFULL)]/ ) 
{
	if ($data{MSwitch}{warnings}{$name} ne "1"){
	MSwitch_LOG( $name, 0, "
	########################################################################################
	ACHTUNG: in dem MSwitch-Device $name wurde eine auslaufende Funktion gefunden
	
	In einer Bedingung wurde ein Ausdruck [\$EVENT] oder ähnlich gefunden.
	Dieses ist ab kommender Version nicht mehr zulässig und sollte geändert werden.
	Zugriff auf aktuelle Events in Bedingungen ist nur noch mit:
	\$EVENT,\$EVTFULL,\$EVTPART1,\$EVTPART2,\$EVTPART3
	zulässig. 
	( es wird nur eine beispielhafte Bedingung angezeigt )
	Die betreffende Bedingung lautet:
	
	$condition
	
	Bitte dieses Device entsprechend anpassen.
	In dieser Version erfolgt automatisch ein entsprechendes Mapping, in folgenden Versionen wird dieses entfallen.
	########################################################################################
	");
	}
	$hash->{helper}{warning}{$name}=1;
	
	$data{MSwitch}{warnings}{$name}=1;
	
}

# if ( $condition =~ m/[(\$SELF\:\$EVENT|\$SELF\:\$EVTPART1|\$SELF\:\$EVTPART2\|\$SELF\:\$EVTPART3]|\$SELF\:\$EVTFULL)]/ ) 
# {
	# if ($hash->{helper}{warning}{$name} ne "1"){
	# MSwitch_LOG( $name, 0, "ACHTUNG Device $name ...... found alten Zopf L:" . __LINE__ );
	# }
	# $hash->{helper}{warning}{$name}=1;
# }

if ( $condition =~ m/"\$EVENT|\$EVTPART1|\$EVTPART2\|\$EVTPART3]|\$EVTFULL"/ ) 
{
	if ($data{MSwitch}{warnings}{$name} ne "1"){
		
		
	MSwitch_LOG( $name, 0, "
	########################################################################################
	ACHTUNG: in dem MSwitch-Device $name wurde eine auslaufende Funktion gefunden
	
	In einer Bedingung wurde ein Ausdruck \"\$EVENT\" oder ähnlich gefunden.
	Dieses ist ab kommender Version nicht mehr zulässig und sollte geändert werden.
	Zugriff auf aktuelle Events in Bedingungen ist nur noch mit:
	\$EVENT,\$EVTFULL,\$EVTPART1,\$EVTPART2,\$EVTPART3
	zulässig. 
	 
	Die betreffende Bedingung lautet:
	( es wird nur eine beispielhafte Bedingung angezeigt )
	$condition
	
	
	Bitte dieses Device entsprechend anpassen.
	In dieser Version erfolgt automatisch ein entsprechendes Mapping, in folgenden Versionen wird dieses entfallen.
	########################################################################################
	");
	
	
	
	}
	$hash->{helper}{warning}{$name}=1;
	$data{MSwitch}{warnings}{$name}=1;
}


    # #### kompatibilität v < 2.01
    # $condition =~ s/\[\$EVENT\]/"\$EVENT"/g;
    # $condition =~ s/\[\$EVTFULL\]/"\$EVTFULL"/g;
    # $condition =~ s/\[\$EVTPART1\]/"\$EVTPART1"/g;
    # $condition =~ s/\[\$EVTPART2\]/"\$EVTPART2"/g;
    # $condition =~ s/\[\$EVTPART3\]/"\$EVTPART3"/g;
    # $condition =~ s/\[\$EVT_CMD1_COUNT\]/"\$EVT_CMD1_COUNT"/g;
    # $condition =~ s/\[\$EVT_CMD2_COUNT\]/"\$EVT_CMD2_COUNT"/g;
    # #### evt anpassung wenn alleinstehend

    # $condition =~ s/(?<!")\$EVENT(?!")|\[EVENT]/[$name:EVENT]/g;
    # $condition =~ s/(?<!")\$EVTFULL(?!")|\[EVTFULL]/[$name:EVTFULL]/g;
    # $condition =~ s/(?<!")\$EVTPART1(?!")|\[EVTPART1]/[$name:EVTPART1]/g;
    # $condition =~ s/(?<!")\$EVTPART2(?!")|\[EVTPART2]/[$name:EVTPART2]/g;
    # $condition =~ s/(?<!")\$EVTPART3(?!")|\[EVTPART3]/[$name:EVTPART3]/g;
	
	
	
	##################################
	
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
	
	
	###################################################
	





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

    MSwitch_LOG( $name, 6, "Bedingungsprüfung1: $condition L:" . __LINE__ );

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

    if ( $condition =~ m/YEAR|MONTH|DAY|MIN|HOUR|HMS/ ) {
        while ( $condition =~ m/(.*)\[YEAR\](.*)([\d]{4})(.*)/ ) {
            $condition = $1 . "$year$2$3" . $4;
        }
        while ( $condition =~ m/(.*)\[MONTH\](.*)([\d]{1,2})(.*)/ ) {

            $condition = $1 . "$month$2$3" . $4;
        }
        while ( $condition =~ m/(.*)\[DAY\](.*)([\d]{1,2})(.*)/ ) {
            $condition = $1 . "$mday$2$3" . $4;
        }

        while ( $condition =~ m/(.*)\[MIN\](.*)([\d]{1,2})(.*)/ ) {
            $condition = $1 . "$min$2$3" . $4;
        }
        while ( $condition =~ m/(.*)\[HOUR\](.*)([\d]{1,2})(.*)/ ) {
            $condition = $1 . "$hour$2$3" . $4;
        }
        while ( $condition =~ m/(.*)\[HMS\](.*)/ ) {
            $condition = $1 . "\"$hms\"" . $2;
        }
    }

    if ( $condition =~ m/DIFF|TEND|AVG|INC/ ) {

        if ( $condition =~ m/(.*)(\[DIFF.*[>|<].*?\d{1,3})(.*)/ ) {
            $funktionstring = $2;
            $condition      = $1 . "[$name:DIFFERENCE] eq \"true\"" . $3;
        }

        if ( $condition =~ m/(.*)(\[TEND.*[>|<].*?\d{1,3})(.*)/ ) {
            $funktionstring = $2;
            $condition      = $1 . "[$name:TENDENCY] eq \"true\"" . $3;

        }

        if ( $condition =~ m/(.*)(\[AVG.*[>|<].*?\d{1,3})(.*)/ ) {
            $funktionstring = $2;
            $condition      = $1 . "[$name:AVERAGE] eq \"true\"" . $3;

        }

        if ( $condition =~ m/(.*)(\[INC.*[>|<].*?\d{1,3})(.*)/ ) {
            $funktionstring = $2;
            $condition      = $1 . "[$name:INCREASE] eq \"true\"" . $3;

        }

        if ( $funktionstring =~ m/\[(INC.*|DIFF.*?|TEND.*?|AVG.*?):(.+)\](.+)/ )
        {

######## oldplace

            my $function      = $1;
            my $eventhistorie = $2;
            my $ausdruck      = $3;
            my $vergloperand  = 0;

            $funktionsstringdiff = $1;
            $funktionsstringtend = $1;
            $funktionsstringavg  = $1;
            $funktionsstringinc  = $1;

######## unterscheidung der funktionen

            #Function DIFF
            if ( $funktionsstringdiff =~ m/(DIFF)(.*)/ ) {
                my $finaldiff;
                my $finaldiff1;

                $vergloperand = $2;
                $vergloperand = 0 if $2 eq "";
                my $function = "DIFF";

                $ausdruck =~ m/.*?([<>]).*?(\d.*)/;
                my $rechenzeichen  = $1;
                my $vergleichswert = $2;

                my @eventfunction =
                  split( / /, $hash->{helper}{eventhistory}{$eventhistorie} );

                if ( @eventfunction < $vergloperand ) {
                    MSwitch_LOG( $name, 4,
"$name:  Funktionberechnung DIFF erkannt-> nicht genug Daten für berechnung vorhanden"
                    );

                    $finaldiff =
"Funktionberechnung DIFFERENCE<br>Berechnung nicht möglich, nicht genug Daten vorhanden<br>Ergebniss: false";
                    $hash->{helper}{eventhistory}{DIFFERENCE} = $finaldiff;
                    readingsSingleUpdate( $hash, "DIFFERENCE", 'false', 1 );

                }
                else {
                    my $operand = $eventfunction[0];
                    my $index   = $vergloperand - 1;
                    $index = 0 if $index < 0;
                    my $operand1 = $eventfunction[$index];

                    readingsSingleUpdate( $hash, "Debug-DIFF-Wert1", $operand,
                        1 )
                      if ( $debugmode > 0 );
                    readingsSingleUpdate( $hash, "Debug-DIFF-Wert2", $operand1,
                        1 )
                      if ( $debugmode > 0 );

                    my $diff = abs( $operand1 - $operand );
                    MSwitch_LOG( $name, 5, "$name:  Differenz  : $diff" );
                    my $ret;
                    my $erg =
                        "\$ret ='false';\$ret = 'true' if "
                      . $diff
                      . $rechenzeichen
                      . $vergleichswert
                      . ";return \$ret;";

                    my $erg2 = eval $erg;

                    $finaldiff =
"Funktionberechnung DIFFERENCE<br>Wertepaar: $operand - $operand1<br>Differenz (Zahlenwert): $diff<br>Wahr wenn $diff $rechenzeichen $vergleichswert<br>Ergebniss: $erg2";
                    $finaldiff1 =
"Funktionberechnung: Wertepaar: $operand - $operand1-Differenz (Zahlenwert): $diff-Wahr wenn $diff $rechenzeichen $vergleichswert-Ergebniss: $erg2";

                    $hash->{helper}{eventhistory}{DIFFERENCE} = $finaldiff;
                    readingsSingleUpdate( $hash, "DIFFERENCE", $erg2, 1 );

                    if ( $operand > $operand1 ) {
                        readingsSingleUpdate( $hash, "DIFFDIRECTION", "up", 1 );
                    }
                    elsif ( $operand < $operand1 ) {
                        readingsSingleUpdate( $hash, "DIFFDIRECTION", "down",
                            1 );
                    }
                    else {
                        readingsSingleUpdate( $hash, "DIFFDIRECTION",
                            "no_tendency", 1 );
                    }
                }

                if ( $debugmode > 0 ) {
                    readingsSingleUpdate( $hash, "Debug-DIFF-Event-History",
                        $hash->{helper}{eventhistory}{$eventhistorie}, 1 );
                    readingsSingleUpdate( $hash, "Debug-DIFF-Summary",
                        $finaldiff1, 1 );
                }
				
			# DIFF ende ##########################	
            }

            #Function TEND
            if ( $funktionsstringtend =~ m/(TEND)(.*)/ ) {
                my $finaltend;
                $vergloperand = $2;
                $vergloperand = 0 if $2 eq "";
                my $function = "TEND";

                $ausdruck =~ m/.*?([<>]).*?(\d.*)/;
                my $rechenzeichen  = $1;
                my $vergleichswert = $2;

                my $anzahl =
                  $vergloperand;    # anzahl der getesteten events aus historia
                my $anzahl1 =
                  $vergloperand * 2; # anzahl der getesteten events aus historia

                my @eventfunction =
                  split( / /, $hash->{helper}{eventhistory}{$eventhistorie} );
                if ( @eventfunction < $anzahl1 ) {

                    $finaltend =
"Funktionberechnung TENDENCY<br>Berechnung nicht möglich, nicht genug Daten vorhanden";
                    $hash->{helper}{eventhistory}{TENDENCY} = $finaltend;
                    readingsSingleUpdate( $hash, "TENDENCY", 'false', 1 );

                    readingsSingleUpdate(
                        $hash,
                        "Debug-TENDENCY-Result",
'FALSE - nicht genug Daten für berechnung vorhanden. Benötigt:'
                          . $anzahl1
                          . ' Vorhanden:'
                          . @eventfunction,
                        1
                    ) if ( $debugmode > 0 );

                }
                else {
                    my $wert1 = 0;
                    my $wert2 = 0;
                    my $count = 0;
                    my @wertpaar1;
                    my @wertpaar2;

                    foreach (@eventfunction) {
                        last if $count >= $anzahl1;
                        $wert1 = $wert1 + $_ if $count < $anzahl;
                        push( @wertpaar1, $_ ) if $count < $anzahl;
                        $wert2 = $wert2 + $_ if $count >= $anzahl;
                        push( @wertpaar2, $_ ) if $count >= $anzahl;
                        $count++;
                    }

                    $wert1 = $wert1 / $anzahl;
                    $wert2 = $wert2 / $anzahl;

                    my $tendenz = 'notendenz';

                    $tendenz = "down" if $wert1 < $wert2;
                    $tendenz = "up"   if $wert1 > $wert2;

                    my $tendenzwert = abs( $wert1 - $wert2 );

                    my $tendenzgefordert = "no_entry";

                    $tendenzgefordert = "up"   if $rechenzeichen eq ">";
                    $tendenzgefordert = "down" if $rechenzeichen eq "<";

                    my $tendenzwertgefordert;
                    $tendenzwertgefordert = $vergleichswert;

                    if ( !defined $hash->{helper}{eventhistory}{TENDlast}
                        {$tendenzgefordert} )
                    {
                        $hash->{helper}{eventhistory}{TENDlast}
                          {$tendenzgefordert} = "not_set";

                        # mögliche zustände: not_set / set
                    }

                    # debug

                    if ( $debugmode > 0 ) {
                        readingsSingleUpdate( $hash, "Debug-TENDENCY-Wert-Ist",
                            $tendenzwert, 1 );
                        readingsSingleUpdate( $hash,
                            "Debug-TENDENCY-Wert-Soll", $tendenzwertgefordert,
                            1 );
                        readingsSingleUpdate(
                            $hash,
                            "Debug-TENDENCY-Event-History",
                            $hash->{helper}{eventhistory}{$eventhistorie}, 1
                        );
                        if (
                            defined $hash->{helper}{eventhistory}{TENDlast}
                            {$tendenzgefordert} )
                        {
                            readingsSingleUpdate(
                                $hash,
                                "Debug-TENDENCY-Schaltung-erfolgt",
                                $hash->{helper}{eventhistory}{TENDlast}
                                  {$tendenzgefordert},
                                1
                            );
                        }
                        else {
                            readingsSingleUpdate( $hash,
                                "Debug-TENDENCY-Schaltung-erfolgt",
                                "not_set", 1 );
                        }

                        readingsSingleUpdate( $hash,
                            "Debug-TENDENCY-Wertepaar-1", "@wertpaar1", 1 );
                        readingsSingleUpdate( $hash,
                            "Debug-TENDENCY-Wertepaar-2", "@wertpaar2", 1 );
                        readingsSingleUpdate( $hash,
                            "Debug-TENDENCY-Wertepaar-Schnitt-1",
                            $wert1, 1 );
                        readingsSingleUpdate( $hash,
                            "Debug-TENDENCY-Wertepaar-Schnitt-2",
                            $wert2, 1 );
                        readingsSingleUpdate( $hash,
                            "Debug-TENDENCY-Soll-Richtung",
                            $tendenzgefordert, 1 );
                    }

                    #

                    my $tendenzsetsoon = $hash->{helper}{eventhistory}{TENDlast}
                      {$tendenzgefordert};

                    # verfügbare werte

                    # abbruch wenn tendenzwert unter gefordertem wert

                    if ( $tendenzwert < $tendenzwertgefordert ) {

                        $finaltend =
"Funktionberechnung DIFFERENCE<br>geforderter Tendenzumkehrwert nicht erreicht";
                        $hash->{helper}{eventhistory}{TENDENCY} = $finaltend;
                        readingsSingleUpdate( $hash, "TENDENCY", 'false', 1 );
                        readingsSingleUpdate(
                            $hash,
                            "Debug-TENDENCY-Result",
'FALSE - geforderter Tendenzumkehrwert nicht erreicht',
                            1
                        ) if ( $debugmode > 0 );
                    }
                    elsif ( $tendenzgefordert ne $tendenz )

# löschen des gesetzten bereits geschaltet tags bei umgekehrter tendenz und abbrechen
                    {
                        #$tendenzgefordert
                        #$tendenz
                        $hash->{helper}{eventhistory}{TENDlast}
                          {$tendenzgefordert} = "not_set";

                        $finaltend =
"TENDenzumkehr in nicht geforderte Richtung erkannt loesche bereits 'gesetzt' Tag ";
                        $hash->{helper}{eventhistory}{TENDENCY} = $finaltend;
                        readingsSingleUpdate( $hash, "TENDENCY", 'false', 1 );
                        readingsSingleUpdate(
                            $hash,
                            "Debug-TENDENCY-Result",
'FALSE - TENDenzumkehr entgegen geforderter Richtung erkannt loesche bereits gesetzt Tag',
                            1
                        ) if ( $debugmode > 0 );

                    }
                    elsif ( $tendenzsetsoon eq "set" )
                      ##
                      ## zustand hier umschaltwert nicht erreicht ausgeschlossen - richtungsumkehr in nicht gefordrte richtung ausgeschlossen
                      ##
                      ## zustandsmöglichkeiten ab hier richtige richtung erkannt - schon gesetzt/nicht gesetzt unklar
                      ## aktion ab hier: 'false' liefern falls 'bereits gesetzt Tag' existiert 'set'
                      ## aktion ab hier: 'true' liefern und 'bereits gesetzt Tag' setzen falls auf 'not_set'
                      # geforderte tendenz erkannt aber bereits geschaltet
                    {

                        $finaltend =
"TEND geforderte Tendenz erkannt, Schaltbefehl ist bereits erfolgt. Warte auf Richtungsumkehr";
                        $hash->{helper}{eventhistory}{TENDENCY} = $finaltend;
                        readingsSingleUpdate( $hash, "TENDENCY", 'false', 1 );
                        readingsSingleUpdate(
                            $hash,
                            "Debug-TENDENCY-Result",
'FALSE - Tendenz erkannt, Schaltbefehl ist bereits erfolgt. Warte auf Richtungsumkehr',
                            1
                        ) if ( $debugmode > 0 );

                    }
                    elsif ( $tendenzsetsoon eq "not_set" ) {

                        $hash->{helper}{eventhistory}{TENDlast}
                          {$tendenzgefordert} = "set";
                        $finaltend =
"TEND geforderte Tendenz erkannt, Schaltbefehl erfolgt.";
                        $hash->{helper}{eventhistory}{TENDENCY} = $finaltend;
                        readingsSingleUpdate( $hash, "TENDENCY", 'true', 1 );
                        readingsSingleUpdate(
                            $hash,
                            "Debug-TENDENCY-Result",
'TRUE - geforderte Tendenz erkannt, Schaltbefehl erfolgt',
                            1
                        ) if ( $debugmode > 0 );
                    }

                }
            }

            #Function AVG
            if ( $funktionsstringavg =~ m/(AVG)(.*)/ ) {

                my $finalavg;

                $vergloperand = $2;
                $vergloperand = 1 if $2 eq "";
                my $function = "AVG";

                $ausdruck =~ m/.*?([<>]).*?(\d.*)/;
                my $rechenzeichen  = $1;
                my $vergleichswert = $2;

                my @eventfunction =
                  split( / /, $hash->{helper}{eventhistory}{$eventhistorie} );
                if ( @eventfunction < $vergloperand ) {

                    $finalavg =
"Funktionberechnung AVERAGE<br>Berechnung nicht möglich, nicht genug Daten vorhanden";
                    $hash->{helper}{eventhistory}{AVERAGE} = $finalavg;
                    readingsSingleUpdate( $hash, "AVERAGE", 'false', 1 );
                }
                else {

                    my $wert  = 0;
                    my $count = 0;

                    my @finalarray;
                    foreach (@eventfunction) {
                        last if $count >= $vergloperand;
                        $wert = $wert + $_;
                        push @finalarray, $_;
                        $count++;
                    }

                    my $schnitt = $wert / $vergloperand;

                    my $ret;
                    my $erg =
                        "\$ret ='false';\$ret = 'true' if "
                      . $schnitt
                      . $rechenzeichen
                      . $vergleichswert
                      . ";return \$ret;";

                    my $erg1 = eval $erg;

                    $finalavg =
                        "Funktionberechnung AVERAGE<br>Herangezogene Werte: "
                      . @finalarray
                      . "<br>(@finalarray)<br>Schnitt : $schnitt<br>Wahr wenn $schnitt $rechenzeichen $vergleichswert<br>Ergebniss: $erg1";
                    $hash->{helper}{eventhistory}{AVERAGE} = $finalavg;
                    readingsSingleUpdate( $hash, "AVERAGE", $erg1, 1 );
                }

            }


            #Function INC
            if ( $funktionsstringinc =~ m/(INC)(.*)/ ) {
                my $finalinc;

                $vergloperand = $2;
                $vergloperand = 1 if $2 eq "";
                my $function = "INC";

                $ausdruck =~ m/.*?([<>]).*?(\d.*)/;
                my $rechenzeichen  = $1;
                my $vergleichswert = $2;

                my @eventfunction =
                  split( / /, $hash->{helper}{eventhistory}{$eventhistorie} );
                if ( @eventfunction < $vergloperand ) {

                    $finalinc =
"Funktionberechnung INCREASE<br>Berechnung nicht möglich, nicht genug Daten vorhanden";
                    $hash->{helper}{eventhistory}{INCREASE} = $finalinc;
                    readingsSingleUpdate( $hash, "INCREASE", 'false', 1 );
                }
                else {
                    my $wert  = 0;
                    my $wert2 = 1;    # illegel division
                    my $count = 0;

                    my @finalarray;

                    foreach (@eventfunction) {

                        last if $count > $vergloperand;
                        $wert  = $_          if $count == 0;
                        $wert2 = $wert2 + $_ if $count > 0;
                        push @finalarray, $_ if $count > 0;
                        $count++;
                    }

                    my $schnitt = $wert2 / $vergloperand;

                    $wert2 = 1 if $wert2 < 1;

                    my $steigung = ( $wert - $schnitt ) / $wert2 * 100;

                    my $testdirection = $wert - $schnitt;

                    if ( $testdirection <= 0 ) {

                        # abnahme erkannt / abbruch
                        $finalinc =
"Funktionberechnung INCREASE<br>Herangezogene Werte: letzter Wert "
                          . $wert
                          . " Schnitt der vorherigen Werte "
                          . $schnitt
                          . "<br>( @finalarray )<br>erkannte Abnahme: $steigung%<br>Wahr wenn $steigung $rechenzeichen $vergleichswert bei Zunnahme <br>Ergebniss: false";

                        $hash->{helper}{eventhistory}{INCREASE} = $finalinc;
                        readingsSingleUpdate( $hash, "INCREASE", 'false', 1 );
                    }
                    else {
                        my $ret;
                        my $erg =
                            "\$ret ='false';\$ret = 'true' if "
                          . $steigung
                          . $rechenzeichen
                          . $vergleichswert
                          . ";return \$ret;";

                        my $erg1 = eval $erg;
                        $finalinc =
"Funktionberechnung INCREASE<br>Herangezogene Werte: letzter Wert "
                          . $wert
                          . " Schnitt der vorherigen Werte "
                          . $schnitt
                          . "<br>( @finalarray )<br>erkannte Steigung: $steigung %<br>Wahr wenn $steigung $rechenzeichen $vergleichswert bei Zunnahme <br>Ergebniss: $erg1";
                        $hash->{helper}{eventhistory}{INCREASE} = $finalinc;
                        readingsSingleUpdate( $hash, "INCREASE", $erg1, 1 );
                    }
                }
                ####
            }
        }
    }

##############
    # $condition
    # perlersetzung
##############
    my $x     = 0;
    my $field = "";
    my $SELF  = $name;



#prüfung reading,internal etc.
    while ( $condition =~
m/(.*?)\[(ReadingsVal|ReadingsNum|ReadingsAge|AttrVal|InternalVal):(.+):(.+):(.+)\](.+)/
      )
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

        if ( $secondpart =~ m/(!\$.*|\$.*)/ ) {
            $field = $secondpart;
        }
        else {

            eval($exec);
        }

        if ( $field =~ m/([0-9]{2}):([0-9]{2}):([0-9]{2})/ ) {
            my $hh = $1;
            if ( $hh > 23 ) { $hh = $hh - 24 }

            #if ( $hh < 10 ) { $hh = "0" . $hh }
            $field = $hh . ":" . $2;
        }

        $condition = $firstpart . $field . $lastpart;

        $x++;
        last if $x > 10;    #notausstieg
    }

    if ( $attrrandomnumber ne '' ) {
        MSwitch_Createnumber($hash);
    }
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

    if ($event) {

        @evtparts = split( /:/, $event );
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



MSwitch_LOG( $name, 6, "COND1 $condition L:" . __LINE__ );

###

    $condition =~ s/\$EVENT/"$event"/ig;
    $condition =~ s/\$EVTFULL/"$evtfull"/ig;
    $condition =~ s/\$EVTPART1/"$evtparts[0]"/ig;
    $condition =~ s/\$EVTPART2/"$evtparts[1]"/ig;
    $condition =~ s/\$EVTPART3/"$evtparts[2]"/ig;

####




    my $evtcmd1 = ReadingsVal( $name, 'EVT_CMD1_COUNT', '0' );
    my $evtcmd2 = ReadingsVal( $name, 'EVT_CMD2_COUNT', '0' );

    $condition =~ s/\$EVT_CMD1_COUNT/$evtcmd1/ig;

    $condition =~ s/\$EVT_CMD2_COUNT/$evtcmd2/ig;

    ######################################
    $condition =~ s/{!\$we}/ !\$we /ig;
    $condition =~ s/{\$we}/ \$we /ig;
    $condition =~ s/{sunset\(\)}/{ sunset\(\) }/ig;
    $condition =~ s/{sunrise\(\)}/{ sunrise\(\) }/ig;



MSwitch_LOG( $name, 6, "COND2 $condition L:" . __LINE__ );



    $x = 0;
    while ( $condition =~ m/(.*?)(\$NAME)(.*)?/ ) {
        my $firstpart  = $1;
        my $secondpart = $2;
        my $lastpart   = $3;
        $condition = $firstpart . $name . $lastpart;
        $x++;
        last if $x > 10;    #notausstieg
    }

    $x = 0;
    while ( $condition =~ m/(.*?)(\$SELF)(.*)?/ ) {
        my $firstpart  = $1;
        my $secondpart = $2;
        my $lastpart   = $3;
        $condition = $firstpart . $name . $lastpart;
        $x++;
        last if $x > 10;    #notausstieg
    }

    my $searchstring;
    $x = 0;
    while ( $condition =~
m/(.*?)(\[\[[a-zA-Z][a-zA-Z0-9_]{0,30}:[a-zA-Z0-9_]{0,30}\]-\[[a-zA-Z][a-zA-Z0-9_]{0,30}:[a-zA-Z0-9_]{0,30}\]\])(.*)?/
      )
    {
        my $firstpart = $1;
        $searchstring = $2;
        my $lastpart = $3;
        $x++;
        last if $x > 10;    #notausstieg
        my $x = 0;

        # Searchstring -> [[t1:state]-[t2:state]]
        while ( $searchstring =~
            m/(.*?)(\[[a-zA-Z][a-zA-Z0-9_]{0,30}:[a-zA-Z0-9_]{0,30}\])(.*)?/ )
        {

            my $read1           = '';
            my $firstpart       = $1;
            my $secsearchstring = $2;
            my $lastpart        = $3;
            if ( $secsearchstring =~ m/\[(.*):(.*)\]/ ) {
                $read1 = ReadingsVal( $1, $2, 'undef' );
            }
            $searchstring = $firstpart . $read1 . $lastpart;
            $x++;
            last if $x > 10;    #notausstieg
        }
        $condition = $firstpart . $searchstring . $lastpart;
    }



MSwitch_LOG( $name, 6, "COND2 $condition L:" . __LINE__ );



    $x = 0;
    while ( $condition =~ m/(.*)(\{ )(.*)(\$we)( \})(.*)/ ) {
        last if $x > 20;        # notausstieg
        $condition = $1 . " " . $3 . $4 . " " . $6;
    }

    ###################################################
    # ersetzte sunset sunrise
    $x = 0;    # notausstieg
    while (
        $condition =~ m/(.*)(\{ )(sunset\([^}]*\)|sunrise\([^}]*\))( \})(.*)/ )
    {
        $x++;    # notausstieg
        last if $x > 20;    # notausstieg
        if ( defined $2 ) {

            my $part2 = eval $3;
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



MSwitch_LOG( $name, 6, "COND3x $condition L:" . __LINE__ );
    ## verursacht fehlerkennung bei angabe von regex [a-zA-Z]
  ARGUMENT: for ( $i = 0 ; $i <= 10 ; $i++ ) {
        $pos = index( $condition, "[", 0 );
        my $x = $pos;
        if ( $x == '-1' ) { last ARGUMENT; }
        $pos1 = index( $condition, "]", 0 );
        $argarray[$arraycount] =
          substr( $condition, $pos, ( $pos1 + 1 - $pos ) );
        $lenght = length($condition);
        $part1  = substr( $condition, 0, $pos );
        $part2  = 'ARG' . $arraycount;
        $part3 =
          substr( $condition, ( $pos1 + 1 ), ( $lenght - ( $pos1 + 1 ) ) );
        $condition = $part1 . $part2 . $part3;
        $arraycount++;
    }


MSwitch_LOG( $name, 6, "COND3y $condition L:" . __LINE__ );



    $condition =~ s/ AND / && /ig;
    $condition =~ s/ OR / || /ig;
    $condition =~ s/ = / == /ig;

#$condition =~ s/(?<==)=//ig; #https://www.regular-expressions.info/refadv.html
#$condition =~ s/(?<!\!)=(?!~)/==/ig; #https://www.dev-insider.de/regex-zum-suchen-und-ersetzen-nutzen-a-840347/

  END:
 
    # teste auf typ
    my $count = 0;
    my $testarg;
    my @newargarray;
    foreach my $args (@argarray) {
        $testarg = $args;

        if ( $testarg =~ '.*:h\d{1,3}' ) {

            # historyformatierung erkannt - auswerten über sub
            # in der regex evtl auf zeilenende definieren
            $newargarray[$count] = MSwitch_Checkcond_history( $args, $name );
            $count++;
            next;
        } 
        $testarg =~ s/[0-9]+//gs;
        if ( $testarg eq '[:-:|]' || $testarg eq '[:-:]' ) {

            # timerformatierung erkannt - auswerten über sub
            # my $param = $argarray[$count];
            $newargarray[$count] = MSwitch_Checkcond_time( $args, $name );
        }
        elsif ( $testarg =~ '[.*:.*]' ) {

            # stateformatierung erkannt - auswerten über sub
            $newargarray[$count] = MSwitch_Checkcond_state( $args, $name );
        }
        else {
            $newargarray[$count] = $args;
        }
        $count++;
    }

    $count = 0;
    my $tmp;
    foreach my $args (@newargarray) {

        $tmp = 'ARG' . $count;
        $condition =~ s/$tmp/$args/ig;
        $count++;
    }


MSwitch_LOG( $name, 6, "COND4 $condition L:" . __LINE__ );


  #  $condition =~ s/\$EVENT/$event/ig;
   # $condition =~ s/\$EVTFULL/$evtfull/ig;
  #  $condition =~ s/\$EVTPART1/$evtparts[0]/ig;
  #  $condition =~ s/\$EVTPART2/$evtparts[1]/ig;
  #  $condition =~ s/\$EVTPART3/$evtparts[2]/ig;





#\$EVENT='".$event."';\$EVTPART3 ='".$evtparts[2]."';

    $finalstring ="if (" . $condition . "){\$answer = 'true';} else {\$answer = 'false';} ";

    MSwitch_LOG( $name, 6,
        "Bedingungsprüfung2 (final): $finalstring = L:" . __LINE__ );

    my $ret = eval $finalstring;

    MSwitch_LOG( $name, 6,
        "Ergebniss Bedingungsprüfung : $ret L:" . __LINE__ );

    if ( $ret ne "true" ) {

        MSwitch_LOG( $name, 6,
            "Befehlsabbruch - Bedingung nicht erfüllt L:" . __LINE__ );
    }

    if ($@) {
        MSwitch_LOG( $name, 1, "$name EERROR: $@ " . __LINE__ );
        $hash->{helper}{conditionerror} = $@;
        return 'false';
    }

    my $test = ReadingsVal( $name, 'last_event', 'undef' );
    $hash->{helper}{conditioncheck} = $finalstring;

    return $ret;
}
####################
####################
sub MSwitch_Checkcond_state($$) {
    my ( $condition, $name ) = @_;

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

    MSwitch_LOG( $name, 6,
        "zeitbezogene Bedingung gefunden: $condition L:" . __LINE__ );

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
    my ( $tday, $tmonth, $tdate, $tn );   #my ($tday,$tmonth,$tdate,$tn,$time1);
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
    ### new
    if ( $timeaktuell < $timecond2 && $timecond2 < $timecond1 ) {
        use constant SECONDS_PER_DAY => 60 * 60 * 24;
        $timecond1 = $timecond1 - SECONDS_PER_DAY;
        $adday     = 1;
    }
    if ( $timeaktuell > $timecond1 && $timecond2 < $timecond1 ) {
        use constant SECONDS_PER_DAY => 60 * 60 * 24;
        $timecond2 = $timecond2 + SECONDS_PER_DAY;
        $adday     = 1

    }
    my $return = "($timecond1 <= $timeaktuell && $timeaktuell <= $timecond2)";
    if ( $days ne '' ) {
        $daycondition = MSwitch_Checkcond_day( $days, $name, $adday, $day );
        $return = "($return $daycondition)";
    }

    MSwitch_LOG( $name, 6,
        "Ergebniss zeitbezogene Bedingung: $return L:" . __LINE__ );

    return $return;
}
####################
sub MSwitch_Checkcond_history($$) {
    my ( $condition, $name ) = @_;
    $condition =~ s/\[//;
    $condition =~ s/\]//;
    my $hash = $defs{$name};

    MSwitch_LOG( $name, 6,
        "historybezogene Bedingung gefunden: $condition L:" . __LINE__ );

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
              $historyevent[1] . ":" . $historyevent[2];
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

    MSwitch_LOG( $name, 6,
        "Ergebniss historybezogene Bedingung: $condition L:" . __LINE__ );
    return $return;
}
####################
sub MSwitch_Checkcond_day($$$$) {
    my ( $days, $name, $adday, $day ) = @_;
    MSwitch_LOG( $name, 6,
        "tagesbezogene Bedingung gefunden: $days L:" . __LINE__ );
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
        $daycond = $daycond . "($day == $args) || ";
    }
    chop $daycond;
    chop $daycond;
    chop $daycond;
    chop $daycond;
    $daycond = "&& ($daycond)";

    MSwitch_LOG( $name, 6,
        "Ergebniss tagesbezogene Bedingung: $daycond L:" . __LINE__ );
    return $daycond;
}
####################
sub MSwitch_Createtimer($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
    delete( $hash->{helper}{wrongtimespec} );

    # keine timer vorhenden
    my $condition = ReadingsVal( $Name, '.Trigger_time', '' );
    $condition =~ s/#\[dp\]/:/g;
    my $x = 0;
    while ( $condition =~ m/(.*)(\[)([0-9]?[a-zA-Z]{1}.*)\:(.*)(\])(.*)/ ) {
        $x++;    # notausstieg notausstieg
        last if $x > 20;    # notausstieg notausstieg
        my $setmagic = ReadingsVal( $3, $4, 0 );
        $condition = $1 . '[' . $setmagic . ']' . $6;
    }
    my $lenght = length($condition);

    #remove all timers
    MSwitch_Clear_timer($hash);
    if ( $lenght == 0 ) {
        return;
    }

    # trenne timerfile
    my $key = 'on';
    $condition =~ s/$key//ig;
    $key = 'off';
    $condition =~ s/$key//ig;
    $key = 'ly';
    $condition =~ s/$key//ig;
    $condition =~ s/\$name/$Name/g;
    $condition =~ s/\$SELF/$Name/g;
    $x = 0;

    MSwitch_LOG( $Name, 5, "Timer: $condition" . __LINE__ );

    # achtung perl 5.30
    while ( $condition =~ m/(.*)\{(.*)\}(.*)/ ) {
        $x++;    # notausstieg
        last if $x > 20;    # notausstieg
        if ( defined $2 ) {
            my $part1 = $1;
            my $part3 = $3;

            my $part2 = eval $2;
            if ( $part2 !~ m/^[0-9]{2}:[0-9]{2}$|^[0-9]{2}:[0-9]{2}:[0-9]{2}$/ )
            {
                MSwitch_LOG( $Name, 1,
"$Name:  ERROR wrong format in set timer. There are no timers running. Format must be HH:MM. Format is: $part2 "
                );
                return;
            }
            $part2 = substr( $part2, 0, 5 );
            my $test = substr( $part2, 0, 2 ) * 1;
            $part2 = "" if $test > 23;
            $condition = $part1 . $part2 . $part3;
        }
    }
    my @timer = split /~/, $condition;
    $timer[0] = '' if ( !defined $timer[0] );    #on
    $timer[1] = '' if ( !defined $timer[1] );    #off
    $timer[2] = '' if ( !defined $timer[2] );    #cmd1
    $timer[3] = '' if ( !defined $timer[3] );    #cmd2
    $timer[4] = '' if ( !defined $timer[4] );    #cmd1+2
                                                 # lösche bei notify und toggle

    if ( AttrVal( $Name, 'MSwitch_Mode', 'Notify' ) eq "Notify" ) {
        $timer[0] = '';
        $timer[1] = '';
    }
    if ( AttrVal( $Name, 'MSwitch_Mode', 'Notify' ) eq "Toggle" ) {
        $timer[1] = '';
        $timer[2] = '';
        $timer[3] = '';
        $timer[4] = '';
    }
    my $akttimestamp = TimeNow();
    my ( $aktdate, $akttime ) = split / /, $akttimestamp;
    my ( $aktyear, $aktmonth, $aktmday ) = split /-/, $aktdate;
    $aktmonth = $aktmonth - 1;
    $aktyear  = $aktyear - 1900;
    my $jetzt = gettimeofday();

    # aktuelle zeit setzen
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
    $day = $daysforcondition{$day};    # enthält aktuellen tag
    ## für jeden Timerfile ( 0 -4 )
    my $i  = 0;
    my $id = "";
  LOOP2: foreach my $option (@timer) {
        $i++;
        $id = "";
        #### inhalt array für eine option on , off ...
        $key = '\]\[';
        $option =~ s/$key/ /ig;
        $key = '\[';
        $option =~ s/$key//ig;
        $key = '\]';
        $option =~ s/$key//ig;
        my $y = 0;

        while ( $option =~
m/(.*?)([0-9]{2}):([0-9]{2})\*([0-9]{2}:[0-9]{2})-([0-9]{2}:[0-9]{2})\|?([0-9!\$we]{0,7})(.*)?/
          )
        {
            $y++;
            last if $y > 20;
            my $part1 = '';
            $part1 = $1 . ' ' if defined $1;
            my $part6 = '';
            if ( defined $6 && $6 ne '' ) { $part6 = '|' . $6 }
            my $part7 = '';
            $part7 = ' ' . $7 if defined $7;
            my $sectoadd     = $2 * 3600 + $3 * 60;
            my $t1           = $4;
            my $t2           = $5;
            my $timecondtest = localtime;
            $timecondtest =~ s/\s+/ /g;
            my ( $tday, $tmonth, $tdate, $tn, $time1 ) =
              split( / /, $timecondtest );

            if ( substr( $t1, 0, 2 ) > 23 || substr( $t1, 3, 2 ) > 59 ) {
                $hash->{helper}{wrongtimespec} =
                  "ERROR: wrong timespec. $option $i";
                return;
            }
            my $timecond1 = timelocal(
                '00',
                substr( $t1, 3, 2 ),
                substr( $t1, 0, 2 ),
                $tdate, $tmonth, $time1
            );
            if ( substr( $t2, 0, 2 ) > 23 || substr( $t2, 3, 2 ) > 59 ) {
                $hash->{helper}{wrongtimespec} =
                  "ERROR: wrong timespec. $option $i";
                return;
            }
            my $timecond2 = timelocal(
                '00',
                substr( $t2, 3, 2 ),
                substr( $t2, 0, 2 ),
                $tdate, $tmonth, $time1
            );
            my @newarray;
            while ( $timecond1 < $timecond2 ) {

                #my $timestamp = FmtDateTime($timecond1);
                my $timestamp =
                  substr( FmtDateTime($timecond1), 11, 5 ) . $part6;
                $timecond1 = $timecond1 + $sectoadd;
                push( @newarray, $timestamp );
            }
            my $newopt = join( ' ', @newarray );
            my $newoption = $part1 . $newopt . $part7;
            $newoption =~ s/  / /g;
            $option = $newoption;
        }
        my @optionarray = split / /, $option;

        # für jede angabe eines files
      LOOP3: foreach my $option1 (@optionarray) {
            $id = "";
            next LOOP3 if $option1 eq "";
            if ( $option1 =~ m/(.*)\|(ID.*)$/ ) {
                $id      = $2;
                $option1 = $1;
            }
            if ( $option1 =~
                m/\?(.*)(-)([0-9]{2}:[0-9]{2})(\|[0-9]{0,7})?(.*)?/ )
            {
                my $testrandom = $1 . $2 . $3;
                my $part4      = '';
                $part4 = $4 if defined $4;
                my $opdays = $part4;

                #testrandomsaved erstellen
                my $newoption1 = MSwitch_Createrandom( $hash, $1, $3 );
                $option1 = $newoption1 . $opdays;
            }
            if ( $option1 =~ m/{/i || $option1 =~ m/}/i ) {
                my $newoption1 = MSwitch_ChangeCode( $hash, $option1 );
                $option1 = $newoption1;
            }
            my ( $time, $days ) = split /\|/, $option1;
            $time = '' if ( !defined $time );
            $days = '' if ( !defined $days );
            if ( $days eq '!$we' || $days eq '$we' ) {
                my $we = AnalyzeCommand( 0, '{return $we}' );
                if ( $days eq '$we'  && $we == 1 ) { $days = $day; }
                if ( $days eq '!$we' && $we == 0 ) { $days = $day; }
            }
            if ( !defined($days) ) { $days = '' }
            if ( $days eq '' )     { $days = '1234567' }
            if ( index( $days, $day, 0 ) == -1 ) {
                next LOOP3;
            }
            $time = $time . ':00';
            delete( $hash->{helper}{error} );
            if ( $time ne "undef:00"
                and
                ( substr( $time, 0, 2 ) > 23 || substr( $time, 3, 2 ) > 59 ) )
            {
                $hash->{helper}{wrongtimespec} =
                  "ERROR: wrong timespec. $option $i";
                return;
            }
            my $timecond = timelocal(
                substr( $time, 6, 2 ),
                substr( $time, 3, 2 ),
                substr( $time, 0, 2 ),
                $date, $aktmonth, $aktyear
            );
            my $test      = FmtDateTime($timecond);
            my $sectowait = $timecond - $jetzt;
            if ( $timecond > $jetzt ) {

                my $number = $i;
                if ( $id ne "" && ( $i == 3 || $i == 4 ) ) {
                    $number = $number + 3;
                }
                if ( $i == 5 ) { $number = 9; }
                if ( $id ne "" && $number == 9 ) { $number = 10; }
                my $inhalt = $timecond . "-" . $number . $id;
                $hash->{helper}{timer}{$inhalt} = "$inhalt";
                my $msg = $Name . " " . $timecond . " " . $number . $id;
                InternalTimer( $timecond, "MSwitch_Execute_Timer", $msg );
            }
        }
    }

    # berechne zeit bis 23,59 und setze timer auf create timer
    my $newask = timelocal( '00', '59', '23', $date, $aktmonth, $aktyear );
    $newask = $newask + 70;
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
    my $hash = $defs{$Name};
    return "" if ( IsDisabled($Name) );

    MSwitch_LOG( $Name, 6,
        "ausführung Timer $timecond, $param L:" . __LINE__ );

    if ( defined $hash->{helper}{wrongtimespec}
        and $hash->{helper}{wrongtimespec} ne "" )
    {
        my $ret = $hash->{helper}{wrongtimespec};
        $ret .= " - Timer werden nicht ausgefuehrt ";
        return;
    }
    my @string = split( /ID/, $param );
    my $showevents = AttrVal( $Name, "MSwitch_generate_Events", 1 );
    $param = $string[0];
    my $execid = 0;
    $execid = $string[1] if ( $string[1] );
    $hash->{eventsave} = 'unsaved';
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
    $hash->{IncommingHandle} = 'fromtimer'
      if AttrVal( $Name, 'MSwitch_Mode', 'Notify' ) ne "Dummy";
    readingsSingleUpdate( $hash, "last_activation_by", 'timer', $showevents );

    if ( AttrVal( $Name, 'MSwitch_RandomNumber', '' ) ne '' ) {
        MSwitch_Createnumber1($hash);
    }
    if ( $param eq '5' ) {
        MSwitch_Createtimer($hash);
        return;
    }
    if ( AttrVal( $Name, 'MSwitch_Condition_Time', "0" ) eq '1' ) {
        my $triggercondition = ReadingsVal( $Name, '.Trigger_condition', '' );

        # $triggercondition =~ s/\./:/g;
        $triggercondition =~ s/#\[dp\]/:/g;
        $triggercondition =~ s/#\[pt\]/./g;
        $triggercondition =~ s/#\[ti\]/~/g;
        $triggercondition =~ s/#\[sp\]/ /g;
        if ( $triggercondition ne '' ) {
            my $ret = MSwitch_checkcondition( $triggercondition, $Name, '' );
            if ( $ret eq 'false' ) {
                return;
            }
        }
    }
    my $extime = POSIX::strftime( "%H:%M", localtime );
    readingsBeginUpdate($hash);
    readingsBulkUpdate( $hash, "EVENT",
        $Name . ":execute_timer_P" . $param . ":" . $extime );
    readingsBulkUpdate( $hash, "EVTFULL",
        $Name . ":execute_timer_P" . $param . ":" . $extime );
    readingsBulkUpdate( $hash, "EVTPART1", $Name );
    readingsBulkUpdate( $hash, "EVTPART2", "execute_timer_P" . $param );
    readingsBulkUpdate( $hash, "EVTPART3", $extime );
    readingsEndUpdate( $hash, 1 );

    if ( $param eq '1' ) {
        my $cs = "set $Name on";
        MSwitch_LOG( $Name, 6,
            "finale Befehlsausführung auf Fhemebene:\n$cs\n L:" . __LINE__ );
        my $errors = AnalyzeCommandChain( undef, $cs );
        if ( defined($errors) ) {
            MSwitch_LOG( $Name, 1,
"$Name MSwitch_Execute_Timer: Fehler bei Befehlsausfuehrung ERROR $Name: $errors "
                  . __LINE__ );
        }
        return;
    }
    if ( $param eq '2' ) {
        my $cs = "set $Name off";
        MSwitch_LOG( $Name, 6,
            "finale Befehlsausführung auf Fhemebene:\n$cs\n L:" . __LINE__ );

        my $errors = AnalyzeCommandChain( undef, $cs );
        if ( defined($errors) ) {
            MSwitch_LOG( $Name, 1,
"$Name MSwitch_Execute_Timer: Fehler bei Befehlsausfuehrung ERROR $Name: $errors "
                  . __LINE__ );
        }
        return;
    }
    if ( $param eq '3' ) {
        MSwitch_Exec_Notif( $hash, 'on', 'nocheck', '', 0 );
        return;
    }
    if ( $param eq '4' ) {
        MSwitch_Exec_Notif( $hash, 'off', 'nocheck', '', 0 );
        return;
    }
    if ( $param eq '6' ) {

        MSwitch_Exec_Notif( $hash, 'on', 'nocheck', '', $execid );
        return;
    }
    if ( $param eq '7' ) {
        MSwitch_Exec_Notif( $hash, 'off', 'nocheck', '', $execid );
        return;
    }
    if ( $param eq '9' ) {
        MSwitch_Exec_Notif( $hash, 'on',  'nocheck', '', 0 );
        MSwitch_Exec_Notif( $hash, 'off', 'nocheck', '', 0 );
        return;
    }
    if ( $param eq '10' ) {
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
    while ( $option =~ m/(.*)\{(sunset|sunrise)(.*)\}(.*)/ ) {
        $x++;                   # exit secure
        last if $x > 20;        # exit secure
        if ( defined $2 ) {

            my $part2 = eval $2 . $3;
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
    my @olddevices = split( /,/, ReadingsVal( $Name, '.Device_Affected', '' ) );
    my $count      = 1;
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
    readingsSingleUpdate( $hash, ".Device_Affected", $newdevices, 1 );
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
    readingsBeginUpdate($hash);
    readingsBulkUpdate( $hash, ".Device_Affected",         $newaffected );
    readingsBulkUpdate( $hash, ".Device_Affected_Details", $newaffecteddet );
    readingsEndUpdate( $hash, 0 );
    my $devices = MSwitch_makeAffected($hash);
    my $devhash = $hash->{DEF};
    my @dev     = split( /#/, $devhash );
    $hash->{DEF} = $dev[0] . ' # ' . $devices;
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

    #Log3("test",0,"device: $device");

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

            #Log3("test",0,"a: $a");

            my $pos = index( $a, "$device", 0 );
            if ( $pos != -1 ) {
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
    foreach my $a ( sort keys %{$timehash} ) {
        my @timers = split( /#\[tr\]/, $a );
        if ( index( $timers[3], $indikator ) > -1 ) {
            my $inhalt = $hash->{helper}{delays}{$a};
            RemoveInternalTimer($a);
            RemoveInternalTimer($inhalt);
            delete( $hash->{helper}{delays}{$a} );
        }

    }

    return;
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
    delete( $hash->{helper}{timer} );
}
##################################
# Eventsimulation
sub MSwitch_Check_Event($$) {
    my ( $hash, $eventin ) = @_;
    my $Name = $hash->{NAME};
    $eventin =~ s/~/ /g;
    my $dev_hash = "";

    if ( $eventin ne $hash ) {
        if ( ReadingsVal( $Name, 'Trigger_device', '' ) eq "all_events" ) {
            my @eventin = split( /:/, $eventin );
            $dev_hash = $defs{ $eventin[0] };

            if ( $eventin[0] eq "MSwitch_self" ) {
                $hash->{helper}{testevent_device} = $eventin[0];
                $hash->{helper}{testevent_event} =
                  $eventin[1] . ":" . $eventin[2];
            }
            else {

                $hash->{helper}{testevent_device} = $eventin[0];
                $hash->{helper}{testevent_event} =
                  $eventin[1] . ":" . $eventin[2];

            }

        }
        else {
            my @eventin = split( /:/, $eventin );

            if ( $eventin[0] ne "MSwitch_self" ) {
                $dev_hash = $defs{ ReadingsVal( $Name, 'Trigger_device', '' ) };
                $hash->{helper}{testevent_device} =
                  ReadingsVal( $Name, 'Trigger_device', '' );
                $hash->{helper}{testevent_event} =
                  $eventin[0] . ":" . $eventin[1];
            }
            else {
                $dev_hash = $hash;
                $hash->{helper}{testevent_device} = $Name;
                $hash->{helper}{testevent_event} =
                  $eventin[1] . ":" . $eventin[2];

            }
        }
    }
    if ( $eventin eq $hash ) {
        my $logout = $hash->{helper}{writelog};
        $logout =~ s/:/[#dp]/g;

        my $triggerdevice =
          ReadingsVal( $Name, 'Trigger_device', 'no_trigger' );

        if ( ReadingsVal( $Name, 'Trigger_device', '' ) eq "all_events" ) {

            $dev_hash                         = $hash;
            $hash->{helper}{testevent_device} = 'Logfile';
            $hash->{helper}{testevent_event}  = "writelog:" . $logout;

        }
        elsif ( ReadingsVal( $Name, 'Trigger_device', '' ) eq "Logfile" ) {

            $dev_hash                         = $hash;
            $hash->{helper}{testevent_device} = 'Logfile';
            $hash->{helper}{testevent_event}  = "writelog:" . $logout;

        }
        else {
            $dev_hash = $defs{ ReadingsVal( $Name, 'Trigger_device', '' ) };
            $hash->{helper}{testevent_device} =
              ReadingsVal( $Name, 'Trigger_device', '' );
            $hash->{helper}{testevent_event} = "writelog:" . $logout;

        }
    }
    my $we = AnalyzeCommand( 0, '{return $we}' );
    MSwitch_Notify( $hash, $dev_hash );
    delete( $hash->{helper}{testevent_device} );
    delete( $hash->{helper}{testevent_event} );
    delete( $hash->{helper}{testevent_event1} );
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
sub MSwitch_checktrigger(@) {
    my ( $own_hash, $ownName, $eventstellen, $triggerfield, $device, $zweig,
        $eventcopy, @eventsplit )
      = @_;

    MSwitch_LOG( $ownName, 6,
        "prüfe trigger $triggerfield und Event $eventcopy L:" . __LINE__ );

    my $triggeron     = ReadingsVal( $ownName, '.Trigger_on',      '' );
    my $triggeroff    = ReadingsVal( $ownName, '.Trigger_off',     '' );
    my $triggercmdon  = ReadingsVal( $ownName, '.Trigger_cmd_on',  '' );
    my $triggercmdoff = ReadingsVal( $ownName, '.Trigger_cmd_off', '' );
    my $answer        = "";
    if ( $triggerfield =~ m/{(.*)}/ ) {
        my $SELF = $ownName;
        my $exec = "\$triggerfield = " . $1;

        eval($exec);
    }
    unshift( @eventsplit, $device )
      if ReadingsVal( $ownName, 'Trigger_device', '' ) eq "all_events";

    if ( ReadingsVal( $ownName, 'Trigger_device', '' ) eq "all_events" ) {
        $eventcopy = $device . ":" . $eventcopy;
        if ( $triggerfield eq "*" ) {

            $triggerfield = "*:*:*";
        }
    }
    if ( $triggerfield eq "*"
        && ReadingsVal( $ownName, 'Trigger_device', '' ) ne "all_events" )
    {
        $triggerfield = "*:*";
    }
    $triggerfield =~ s/\*/.*/g;

    # erkennunhg der formartierung bis v1.66 ( <1.67)
    my $x = 0;
    while ( $triggerfield =~ m/(.*)(\()(.*)(\/)(.*)(\))(.*)/ ) {
        $x++;    # exit secure
        last if $x > 20;    # exit secure
        $triggerfield = $1 . $3 . "|" . $5 . $7;
    }
################
    if ( $eventcopy =~ m/^$triggerfield/ ) {
        $answer = "wahr";
    }

    if (   $zweig eq 'on'
        && $answer eq 'wahr'
        && $eventcopy ne $triggercmdoff
        && $eventcopy ne $triggercmdon
        && $eventcopy ne $triggeroff )
    {
        MSwitch_LOG( $ownName, 6,
            "rückgabe trigger: ON and CMD1 L:" . __LINE__ );
        return 'on';
    }

    if (   $zweig eq 'off'
        && $answer eq 'wahr'
        && $eventcopy ne $triggercmdoff
        && $eventcopy ne $triggercmdon
        && $eventcopy ne $triggeron )
    {
        MSwitch_LOG( $ownName, 6,
            "rückgabe trigger: OFF and CMD1 L:" . __LINE__ );
        return 'off';
    }

    if ( $zweig eq 'offonly' && $answer eq 'wahr' ) {
        MSwitch_LOG( $ownName, 6, "rückgabe trigger: CMD2 L:" . __LINE__ );
        return 'offonly';
    }

    if ( $zweig eq 'ononly' && $answer eq 'wahr' ) {
        MSwitch_LOG( $ownName, 6, "rückgabe trigger: CMD1 L:" . __LINE__ );
        return 'ononly';
    }

    MSwitch_LOG( $ownName, 6,
        "rückgabe trigger: kein treffer - es wird kein Zweig ausgeführt L:"
          . __LINE__ );
    return 'undef';
}
###############################
sub MSwitch_VUpdate($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
    readingsSingleUpdate( $hash, ".V_Check", $vupdate, 0 );

    if ( AttrVal( $Name, 'MSwitch_Event_Id_Distributor', 'undef' ) ne "undef" )
    {
        my $test = AttrVal( $Name, 'MSwitch_Event_Id_Distributor', 'undef' );

        readingsSingleUpdate( $hash, ".Distributor", $test, 0 );
        fhem("deletereading $Name Exec_cmd");
        fhem("deleteattr $Name MSwitch_Event_Id_Distributor");
        fhem("einlesen der Bridge in ein Hash");
        delete( $hash->{helper}{eventtoid} );
        my $bridge = ReadingsVal( $Name, '.Distributor', 'undef' );

        if ( $bridge ne "undef" ) {
            my @test = split( /\n/, $bridge );
            foreach my $testdevices (@test) {
                my ( $key, $val ) = split( /=>/, $testdevices );
                $hash->{helper}{eventtoid}{$key} = $val;
            }

        }

    }
    return;
}
################################
sub MSwitch_backup($) {
    my ($hash)      = @_;
    my $Name        = $hash->{NAME};
    my $testreading = $hash->{READINGS};
    my @areadings   = ( keys %{$testreading} );
    my %keys;
    open( BACKUPDATEI, ">MSwitch_backup_$vupdate.cfg" )
      ;                                         # Datei zum Schreiben öffnen
    print BACKUPDATEI "# Mswitch Devices\n";    #
    foreach my $testdevice ( keys %{ $modules{MSwitch}{defptr} } )    #
    {
        print BACKUPDATEI "$testdevice\n";
    }
    print BACKUPDATEI "# Mswitch Devices END\n";                      #

    print BACKUPDATEI "\n";    # HTML-Datei schreiben
    foreach my $testdevice ( keys %{ $modules{MSwitch}{defptr} } )    #
    {
        print BACKUPDATEI "#N -> $testdevice\n";                      #
        foreach my $key (@areadings) {
            next if $key eq "last_exec_cmd";

            my $tmp = ReadingsVal( $testdevice, $key, 'undef' );
            print BACKUPDATEI "#S $key -> $tmp\n";
        }
        my %keys;
        foreach my $attrdevice ( keys %{ $attr{$testdevice} } )       #geht
        {
            my $inhalt =
              "#A $attrdevice -> " . AttrVal( $testdevice, $attrdevice, '' );
            $inhalt =~ s/\n/#[nla]/g;
            print BACKUPDATEI $inhalt . "\n";

            #CHANGE einspielen ungeprüft
        }
        print BACKUPDATEI "#E -> $testdevice\n";
        print BACKUPDATEI "\n";
    }
    close(BACKUPDATEI);
}
################################
sub MSwitch_backup_this($) {
    my ($hash)  = @_;
    my $Name    = $hash->{NAME};
    my $Zeilen  = ("");
    my $Zeilen1 = "";
    open( BACKUPDATEI, "<MSwitch_backup_$vupdate.cfg" )
      || return "no Backupfile found!\n";
    while (<BACKUPDATEI>) {
        $Zeilen = $Zeilen . $_;
    }
    close(BACKUPDATEI);
    $Zeilen =~ s/\n/[NL]/g;
    if ( $Zeilen !~ m/#N -> $Name\[NL\](.*)#E -> $Name\[NL\]/ ) {
        return "no Backupfile found\n";
    }
    my @found = split( /\[NL\]/, $1 );
    foreach (@found) {
        if ( $_ =~ m/#S (.*) -> (.*)/ )    # setreading
        {
            next if $1 eq "last_exec_cmd";
            if ( $2 eq 'undef' || $2 eq '' || $2 eq ' ' ) {
            }
            else {
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
            if ( defined($errors) ) {
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
    my $tmp = ReadingsVal( $Name, 'Trigger_device', 'undef' );
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
sub MSwitch_Getconfig($) {
    my ($hash)      = @_;
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

    #  my %keys;
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
sub MSwitch_backup_all($) {
    my ($hash) = @_;
    my $Name   = $hash->{NAME};
    my $answer = '';
    my $Zeilen = ("");
    open( BACKUPDATEI, "<MSwitch_backup_$vupdate.cfg" )
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

            #Log3("test",0,"$_");
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
sub MSwitch_backup_done($) {
    my ($string) = @_;
    return unless ( defined($string) );
    my @a      = split( "\\|", $string );
    my $Name   = $a[0];
    my $answer = $a[1];
    my $hash   = $defs{$Name};
    delete( $hash->{helper}{RUNNING_PID} );
    my $client_hash = $hash->{helper}{RESTORE_ANSWER};
    $answer =~ s/\[nl\]/\n/g;

    foreach my $testdevice ( keys %{ $modules{MSwitch}{defptr} } )    #
    {
        my $devhash = $defs{$testdevice};
        MSwitch_Createtimer($devhash);
    }
    asyncOutput( $client_hash, $answer );
    return;
}
###########################################
sub MSwitch_Execute_randomtimer($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
    my $param = AttrVal( $Name, 'MSwitch_RandomTime', '0' );
    my $min = substr( $param, 0, 2 ) * 3600;
    $min = $min + substr( $param, 3, 2 ) * 60;
    $min = $min + substr( $param, 6, 2 );
    my $max = substr( $param, 9, 2 ) * 3600;
    $max = $max + substr( $param, 12, 2 ) * 60;
    $max = $max + substr( $param, 15, 2 );
    my $sekmax = $max - $min;
    my $ret    = $min + int( rand $sekmax );
	
	readingsSingleUpdate( $hash, "Randomtimer", $ret,
                            1 );
	
	
	
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
    my $incomming = $_[0];
    my @msgarray = split( /\|/, $incomming );
    $name = $msgarray[1];
    my $time = $msgarray[2];
    my $cs   = $msgarray[0];
    my $hash = $defs{$name};
    $cs =~ s/\n//g;

    if ( $cs =~ m/set (.*)(MSwitchtoggle)(.*)/ ) {
        $cs = MSwitch_toggle( $hash, $cs );

    }

    if ( AttrVal( $name, 'MSwitch_Debug', "0" ) ne '2' ) {

        MSwitch_LOG( $name, 6,
            "Befehlswiederholungen ausgeführt: $cs  L:" . __LINE__ );

        if ( $cs =~ m/{.*}/ ) {

            $cs =~ s/\[SR\]/\|/g;
            eval($cs);
            if ($@) {
                MSwitch_LOG( $name, 1,
                    "$name MSwitch_repeat: ERROR $cs: $@ " . __LINE__ );

            }
        }
        else {
            my $errors = AnalyzeCommandChain( undef, $cs );
            if ( defined($errors) ) {
                MSwitch_LOG( $name, 1,
                    "$name Absent_repeat $cs: ERROR : $errors -> Comand: $cs" );

            }
        }
    }

    else {
        MSwitch_LOG( $name, 6,
            "nicht ausgeführte Befehlswiederholungen (Debug2): $cs  L:"
              . __LINE__ );

    }
    delete( $hash->{helper}{repeats}{$time} );
}
#########################
sub MSwitch_Createnumber($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
    my $number = AttrVal( $Name, 'MSwitch_RandomNumber', '' ) + 1;
    my $number1 = int( rand($number) );
    readingsSingleUpdate( $hash, "RandomNr", $number1, 1 );
    return;
}
################################
sub MSwitch_Createnumber1($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
    my $number = AttrVal( $Name, 'MSwitch_RandomNumber', '' ) + 1;
    my $number1 = int( rand($number) );
    readingsSingleUpdate( $hash, "RandomNr1", $number1, 1 );
    return;
}
###############################
sub MSwitch_Safemode($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
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
        readingsSingleUpdate( $hash, "Safemode", 'on', 1 );
        foreach my $a ( keys %{$timehash} ) {
            delete( $hash->{helper}{savemode}{$a} );
        }
        $attr{$Name}{disable} = '1';
    }
    return;
}
###############################################################
sub MSwitch_EventBulk($$$$) {
    my ( $hash, $event, $update, $from ) = @_;
    my $name = $hash->{NAME};
    my $showevents = AttrVal( $name, "MSwitch_generate_Events", 1 );
    return if !defined $event;
    return if !defined $hash;
    if ( $hash eq "" ) { return; }

    #Log3("test",2,"everntbulk - $name : $event");
    MSwitch_LOG( $name, 6, "+++ +++ aktualisiere Eventreadings L:" . __LINE__ );

    my @evtparts = split( /:/, $event );
    $update = '1';
    my $evtsanzahl = @evtparts;

    if ( $evtsanzahl < 3 ) {
        my $eventfrom = $hash->{helper}{eventfrom};
        unshift( @evtparts, $eventfrom );
        $evtsanzahl = @evtparts;
    }
    my $evtfull = join( ':', @evtparts );
    $evtparts[2] = '' if !defined $evtparts[2];
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

        MSwitch_LOG( $name, 6,
            "ausführung aktualisiere Eventreadings: $event  L:" . __LINE__ );

        $hash->{eventsave} = "saved";
        readingsBeginUpdate($hash);
        readingsBulkUpdate( $hash, "EVENT", $event, 1 )
          if $event ne '';
        readingsBulkUpdate( $hash, "EVTFULL", $evtfull, $showevents )
          if $evtfull ne '';
        readingsBulkUpdate( $hash, "EVTPART1", $evtparts[0], $showevents )
          if $evtparts[0] ne '';
        readingsBulkUpdate( $hash, "EVTPART2", $evtparts[1], $showevents )
          if $evtparts[1] ne '';
        readingsBulkUpdate( $hash, "EVTPART3", $evtparts[2], $showevents )
          if $evtparts[2] ne '';
        readingsBulkUpdate( $hash, "last_event", $event, $showevents )
          if $event ne '';
        readingsEndUpdate( $hash, $update );
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
    my $not = ReadingsVal( $name, 'Trigger_device', '' );

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
#######################
sub MSwitch_clearlog($) {
    my ( $hash, $cs ) = @_;
    my $name = $hash->{NAME};
    open( BACKUPDATEI, ">./log/MSwitch_debug_$name.log" );
    print BACKUPDATEI localtime() . " Starte Log\n";    #
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
    print $fh localtime() . ": -> $cs\n";
    close $fh;

    my $hms = AnalyzeCommand( 0, '{return $hms}' );

    my $write = $hms . ": -> " . $cs;
    if ( exists $hash->{helper}{aktivelog}
        && $hash->{helper}{aktivelog} eq 'on' )
    {
        readingsSingleUpdate( $hash, "Debug", $write, 1 );
    }
    return;
}
##################################
sub MSwitch_LOG($$$) {
    my ( $name, $level, $cs ) = @_;
    my $hash = $defs{$name};

    if (
        (
               AttrVal( $name, 'MSwitch_Debug', "0" ) eq '2'
            || AttrVal( $name, 'MSwitch_Debug', "0" ) eq '3'
        )
        && ( $level eq "6" )
      )
    {
        MSwitch_debug2( $hash, $cs );
        $cs = "[$name] " . $cs;
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
        readingsSingleUpdate( $hash, ".Device_Affected_Details", $tochange2,
            0 );
    }
    fhem("deletereading $name .change");
    fhem("deletereading $name .change_info");
    return;
}

##############################################################
sub MSwitch_dec($$) {

    my ( $hash, $todec ) = @_;
    my $name = $hash->{NAME};




#MSwitch_LOG( $name, 0,"Durchlauf todec $todec L:" . __LINE__ );

 my @evtparts;
 my $event;
    if ($hash->{helper}{aktevent}) {

        @evtparts = split( /:/, $hash->{helper}{aktevent} );
		$event=$hash->{helper}{aktevent};
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

	

		$event       = "undef" if $event eq "";
        $evtparts[0] = "undef" if $evtparts[0] eq "";
        $evtparts[1] = "undef" if $evtparts[1] eq "";
        $evtparts[2] = "undef" if $evtparts[2] eq "";
		$evtfull   = "undef" if $evtfull eq "::";



    # ersetzungen direkt vor befehlsausführung
    # gilt für fhemcode, freecmdperl freecmd fhem

    if ( $todec =~ m/(\{)(.*)(\})/s ) {

        # ersetzung für perlcode

        $todec =~ s/\n//g;
        $todec =~ s/\[\$SELF:/[$name:/g;

    }
    else {
		
		#MSwitch_LOG( $name, 0,"FHEMCODE ERSETZUNG ERKANNT L:" . __LINE__ );
		
        # ersetzung für fhemcode
        $todec =~ s/\$NAME/$hash->{helper}{eventfrom}/g;
		#$todec =~ s/\$NAME/$hash->{helper}{eventfrom}/g;
		
		
        $todec =~ s/\$SELF/$name/g;
        $todec =~ s/\n//g;
        $todec =~ s/#\[wa\]/|/g;
        $todec =~ s/#\[SR\]/|/g;

        
        $todec =~ s/MSwitch_Self/$name/g;
        my $ersetzung;
		
		$todec =~ s/\$EVENT/$event/g;
		
        $todec =~ s/\$EVTPART3/$evtparts[2]/g;
       
        $todec =~ s/\$EVTPART2/$evtparts[1]/g;
       
        $todec =~ s/\$EVTPART1/$evtparts[0]/g;
       
        $todec =~ s/\$EVENT/$event/g;
       
        $todec =~ s/\$EVTFULL/$evtfull/g;
	
		
        # $ersetzung = ReadingsVal( $name, "EVTPART3", "" );
        # $todec =~ s/\$EVTPART3/$ersetzung/g;
        # $ersetzung = ReadingsVal( $name, "EVTPART2", "" );
        # $todec =~ s/\$EVTPART2/$ersetzung/g;
        # $ersetzung = ReadingsVal( $name, "EVTPART1", "" );
        # $todec =~ s/\$EVTPART1/$ersetzung/g;
        # $ersetzung = ReadingsVal( $name, "EVENT", "" );
        # $todec =~ s/\$EVENT/$ersetzung/g;
        # $ersetzung = ReadingsVal( $name, "EVENTFULL", "" );
        # $todec =~ s/\$EVENTFULL/$ersetzung/g;
   



   }

    # ersetzung für beide codes
    # setmagic ersetzung
    my $x = 0;
    while ( $todec =~
        m/(.*)\[([a-zA-Z0-9._\$]{1,50})\:([a-zA-Z0-9._]{1,50})\](.*)/ )
    {
        $x++;    # notausstieg notausstieg
        last if $x > 20;    # notausstieg notausstieg

        MSwitch_LOG( $name, 6, "TODEC : $todec" );
        MSwitch_LOG( $name, 6, "- found : $1" );
        MSwitch_LOG( $name, 6, "- found setmagic ersetzung: $2:$3" );
        MSwitch_LOG( $name, 6, "- found : $4" );

        my $firstpart   = $1;
        my $lastpart    = $4;
        my $readingname = $3;
        my $devname     = $2;
        $devname =~ s/\$SELF/$name/;
        my $setmagic = ReadingsVal( $devname, $readingname, 0 );

        MSwitch_LOG( $name, 6,
"- found setmagic ersetzung: ReadingsVal( \"$devname\", \"$readingname\", 0 )"
        );

        MSwitch_LOG( $name, 6, "- change setmagic ersetzung: $setmagic" );

        $todec = $firstpart . $setmagic . $lastpart;

    }

    $todec =~ s/\[FREECMD\]//g;

    ###########################################################################
    ## ersetze gruppenname durch devicenamen
    ## test - nur wenn attribut gesetzt noch einfügen

    if ( AttrVal( $name, 'MSwitch_Device_Groups', 'undef' ) ne "undef" ) {
        my $testgroups = $data{MSwitch}{$name}{groups};
        my @msgruppen  = ( keys %{$testgroups} );

        foreach my $testgoup (@msgruppen) {

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

        @evtparts = split( /:/, $hash->{helper}{aktevent} );
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
		
		
        # $newcode .=
          # "my \$EVTPART1 = \"" . ReadingsVal( $name, "EVTPART1", "" ) . "\";";
        # $newcode .=
          # "my \$EVTPART2 = \"" . ReadingsVal( $name, "EVTPART2", "" ) . "\";";
        # $newcode .=
          # "my \$EVTPART3 = \"" . ReadingsVal( $name, "EVTPART3", "" ) . "\";";
        # $newcode .=
          # "my \$EVENTFULL = \"" . ReadingsVal( $name, "EVENTFULL", "" ) . "\";";

$newcode .=
          "my \$EVTPART1 = \"" . $evtparts[0] . "\";\n";
        $newcode .=
          "my \$EVTPART2 = \"" . $evtparts[1] . "\";\n";
        $newcode .=
          "my \$EVTPART3 = \"" .$evtparts[2] . "\";\n";
        $newcode .=
          "my \$EVTFULL = \"" . $evtfull . "\";\n";




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

        $cs = $firstpart . "" . eval($cs);

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
    if ( $cs =~ m/(\{)(.*)(\})/s ) {
        my $oldpart = $2;

        my $newcode = "";





 my @evtparts;
 my $event;
    if ($hash->{helper}{aktevent}) {

        @evtparts = split( /:/, $hash->{helper}{aktevent} );
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











        ## variablendeklaration für perlcode / wird anfangs eingefügt
        if ( exists $hash->{helper}{eventfrom} ) {
            $newcode .= "my \$NAME = \"" . $hash->{helper}{eventfrom} . "\";\n";
        }
        else {
            $newcode .= "my \$NAME = \"\";\n";
        }

        $newcode .= "my \$SELF = \"" . $name . "\";\n";
		
		
		
        # $newcode .=
          # "my \$EVTPART1 = \"" . ReadingsVal( $name, "EVTPART1", "" ) . "\";\n";
        # $newcode .=
          # "my \$EVTPART2 = \"" . ReadingsVal( $name, "EVTPART2", "" ) . "\";\n";
        # $newcode .=
          # "my \$EVTPART3 = \"" . ReadingsVal( $name, "EVTPART3", "" ) . "\";\n";
        # $newcode .=
          # "my \$EVTFULL = \"" . ReadingsVal( $name, "EVTFULL", "" ) . "\";\n";



$newcode .=
          "my \$EVTPART1 = \"" . $evtparts[0] . "\";\n";
        $newcode .=
          "my \$EVTPART2 = \"" . $evtparts[1] . "\";\n";
        $newcode .=
          "my \$EVTPART3 = \"" .$evtparts[2] . "\";\n";
        $newcode .=
          "my \$EVTFULL = \"" . $evtfull . "\";\n";



        # $newcode .= "# deklaration ende\n";
        $newcode .= $oldpart;
        $cs = "{\n$newcode}";

        # entferne kommntarzeilen
        $cs =~ s/#\[SR\]/[SR]/g;

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

    #return;
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

sub OLD_MSwitch_gettemplate($$) {
    my ( $hash, $template ) = @_;
    my $Name    = $hash->{NAME};
    my $tZeilen = "";
    my %UMLAUTE = (
        'Ä' => 'Ae',
        'Ö' => 'Oe',
        'Ü' => 'Ue',
        'ä' => 'ae',
        'ö' => 'oe',
        'ü' => 'ue'
    );
    my $UMLKEYS = join( "|", keys(%UMLAUTE) );

    #my $Verzeichnis ="./FHEM/MSwitch";
    open( BACKUPDATEI, "<./FHEM/MSwitch/$template" )
      || return "no Backupfile found!\n";
    while (<BACKUPDATEI>) {

        $_ =~ s/($UMLKEYS)/$UMLAUTE{$1}/g;

        $tZeilen = $tZeilen . $_;
    }
    close(BACKUPDATEI);
    return "$tZeilen";

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

        #Log3("test",0,"FOUND CODE".$data);

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

    my @gset = split( /\n/, $aVal );
    foreach my $line (@gset) {
        my @lineset = split( /->/, $line );
        $lineset[0] =~ s/ //g;
        next if $lineset[0] eq "";
        push( @devs, $lineset[0] );
        $data{MSwitch}{$Name}{groups}{ $lineset[0] } = $lineset[1];
        $string = MSwitch_makegroupcmd( $hash, $lineset[0] );
        push( @devscmd, $string );

    }

    $string = "@devs" . "[TRENNER]" . "@devscmd";

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
        Log3 $name, 1, "$err";

        readingsSingleUpdate( $hash, "FullHTTPResponse", $err, 1 );
        return;

    }
    $data{MSwitch}{$name}{HTTPresponse} = $data;

    my $mapss = AttrVal( $name, "MSwitch_ExtraktHTTPMapping", "no_mapping" );
    my @maps;
    @maps = split( /\n/, $mapss );
    my $regex =
      AttrVal( $name, "MSwitch_ExtraktfromHTTP", "FullHTTPResponse->(.*)" );
    my @gset = split( /\n/, $regex );
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
                    $arg =~ s/$org/$ers/g;
                }
            }

            my @newmatch = split( /#\[trenner\]/, $arg );
            $arg = join( ",", @newmatch );
            my $x = 0;
            if ( @newmatch > 1 && $reading ne "FullHTTPResponse" )

            {
                foreach my $match (@newmatch) {
                    readingsSingleUpdate( $hash, $reading . "_" . $x,
                        $match, 1 );
                    $x++;

                }
            }

            if ( $reading eq "FullHTTPResponse" ) {
                $arg =
                    "for more details \"get $name HTTPresponse\"    ..... "
                  . substr( $arg, 0, 150 )
                  . " .....";
            }

            readingsSingleUpdate( $hash, $reading, $arg, 1 );
        }
        else {
            Log3 $name, 1, "no match found for regex $reg";
            readingsSingleUpdate( $hash, $reading, "no match", 1 );
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
        Log3 $name, 0,
            "error while requesting "
          . $param->{url}
          . " - $err";    # Eintrag fürs Log
        readingsSingleUpdate( $hash, "fullResponse", "ERROR", 0 )
          ;               # Readings erzeugen
    }

    elsif ( $data ne ""
      ) # wenn die Abfrage erfolgreich war ($data enthält die Ergebnisdaten des HTTP Aufrufes)
    {
        Log3 $name, 0,
          "url " . $param->{url} . " returned: $data";    # Eintrag fürs Log

        # An dieser Stelle die Antwort parsen / verarbeiten mit $data

        readingsSingleUpdate( $hash, "fullResponse", $data, 0 )
          ;                                               # Readings erzeugen
    }

    # Damit ist die Abfrage zuende.
    # Evtl. einen InternalTimer neu schedulen
}

1;

