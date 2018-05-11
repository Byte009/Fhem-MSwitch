
#################################################################
# $Id:
# 98_MSwitch.pm
#
# Published under GNU GPL License, v2
# written by Byte09
#################################################################
#
# 17.12.17	V 0.11	-	Add manually Trigger Events
# 22.12.17	V 0.14	-	Add Wildcard Trigger - Add Variable $EVENT
# 24.12.17	V 0.15	-	Bugfix: Ausführung des "off" Kommandozweiges
# 24.12.17	V 0.16	-	Add GLOBAL als zu triggerndes Device eingefügt
#					-	Add ATTR Expert
#					-	gleicher Trigger für "on" und "off" zweig verhindert ( nicht für reines Notify )
# 25.12.17	V 0.17	-	some Code-Changes
#					-	Fixing some bugs
#					-	change Debug function
# 04.01.18	V 0.18	-	some Code-Changes
#					-	add 'check condition'
# 07.01.18	V 0.19	-	Bugfix timeformat ( [24:00] )
#
#################################################################
# Todo's:
#
#
#################################################################

package main;

use Time::Local;
use strict;
use warnings;
use POSIX;

my $version = '1.3';
my $vupdate = 'V 0.3';

sub MSwitch_Checkcond_time($$);
sub MSwitch_Checkcond_state($$);
sub MSwitch_Checkcond_day($$$$);
sub MSwitch_Settimecontrol($);
sub MSwitch_Createtimer($);
sub MSwitch_Execute_Timer($);
sub MSwitch_LoadHelper($);
sub MSwitch_ChangeCode($$);
sub MSwitch_Add_Device($$);
sub MSwitch_Del_Device($$);
sub MSwitch_Debug($);
sub MSwitch_Exec_Notif($$$$);
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

my %sets = (
    "on"             => "noArg",
    "off"            => "noArg",
    "devices"        => "noArg",
    "details"        => "noArg",
    "del_trigger"    => "noArg",
    "del_delays"     => "noArg",
    "trigger"        => "noArg",
    "filter_trigger" => "noArg",
    "add_device"     => "noArg",
    "del_device"     => "noArg",
    "addevent"       => "noArg",
    "backup_MSwitch" => "noArg",
    "import_config"  => "noArg",
    "saveconfig"     => "noArg",
    "set_trigger"    => "noArg"
);
my %gets = (
    "active_timer"         => "noArg",
    "restore_MSwitch_Data" => "noArg",
    "get_config"           => "noArg"
);

my @doignore =
  qw(notify allowed at watchdog doif fhem2fhem telnet FileLog readingsGroup FHEMWEB autocreate eventtypes readingsproxy svg cul);
####################
sub MSwitch_Initialize($) {
    my ($hash) = @_;
    $hash->{SetFn}             = "MSwitch_Set";
    $hash->{AsyncOutput}       = "MSwitch_AsyncOutput";
    $hash->{GetFn}             = "MSwitch_Get";
    $hash->{DefFn}             = "MSwitch_Define";
    $hash->{UndefFn}           = "MSwitch_Undef";
    $hash->{DeleteFn}          = "MSwitch_Delete";
    $hash->{ParseFn}           = "MSwitch_Parse";
    $hash->{AttrFn}            = "MSwitch_Attr";
    $hash->{NotifyFn}          = "MSwitch_Notify";
    $hash->{FW_detailFn}       = "MSwitch_fhemwebFn";
    $hash->{FW_deviceOverview} = 1;
    $hash->{FW_summaryFn}      = "MSwitch_summary";
    $hash->{NotifyOrderPrefix} = "45-";
    $hash->{AttrList} =
        " disable:0,1"
      . "  MSwitch_Help:0,1"
      . "  MSwitch_Debug:0,1,2"
      . "  MSwitch_Expert:0,1"
      . "  MSwitch_Delete_Delays:0,1"
      . "  MSwitch_Include_Devicecmds:0,1"
      . "  MSwitch_Include_Webcmds:0,1"
      . "  MSwitch_Include_MSwitchcmds:0,1"
      . "  MSwitch_Activate_MSwitchcmds:0,1"
      . "  MSwitch_Lock_Quickedit:0,1"
      . "  MSwitch_Ignore_Types"
      . "  MSwitch_Trigger_Filter"
      . "  MSwitch_Extensions:0,1"
      . "  MSwitch_Inforoom";
    $hash->{FW_addDetailToSummary} = 0;
}
####################
sub MSwitch_summary($) {

    my ( $wname, $name, $room ) = @_;
    my $hash = $defs{$name};

    # my $tvar = %ENV ;

    # foreach my $testdevices ( keys %ENV )  {
    # my $tvar1 = $ENV{$testdevices} ;
    # Log3( $name, 0, " wname : $testdevices  - $tvar1  L:" . __LINE__ );
    # }

    my $testroom = AttrVal( $name, 'MSwitch_Inforoom', 'undef' );
    if ( $testroom ne $room ) { return; }
    my $test = AttrVal( $name, 'comment', '0' );
    my $info = AttrVal( $name, 'comment', 'No Info saved at ATTR omment' );
    my $image    = ReadingsVal( $name, 'state', 'undef' );
    my $ret      = '';
    my $devtitle = '';
    my $option   = '';
    my $html     = '';
    my $triggerc = 1;
    my $timer    = 1;

###devices
    my $trigger = ReadingsVal( $name, 'Trigger_device', 'undef' );
    my @devaff = split( / /, MSwitch_makeAffected($hash) );
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
### time
    my $optiontime;
    my $devtitletime = '';
    my $triggertime  = ReadingsVal( $name, 'Trigger_device', 'not defined' );
    my @devtime      = split( /~/, ReadingsVal( $name, '.Trigger_time', '' ) );
    $optiontime .= "<option value=\"Time:\">Time: aktiv</option>";
    my $count = 0;

    foreach (@devtime) {

        $count++;
        $devtitletime .= $_ . ", ";
        $optiontime   .= "<option value=\"$_\">" . $_ . "</option>";

    }

    my $affectedtime = '';
    if ( $count == 0 ) {
        $timer = 0;
        $affectedtime =
            "<select style='width: 12em;' title=\""
          . $devtitletime
          . "\" disabled ><option value=\"Time:\">Time: inaktiv</option></select>";
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

    if ( $trigger eq 'no_trigger' || $trigger eq 'undef' ) {
        $triggerc = 0;

        if ( $triggerc != 0 || $timer != 0 ) {
            $ret .=
"<select style='width: 18em;' title=\"\" disabled ><option value=\"Trigger:\">Trigger: inaktiv</option></select>";
        }
        else {
            $affectedtime = "";
            $ret .= "&nbsp;&nbsp;Multiswitchmode (no trigger / no timer)&nbsp;";
        }

    }
    else {
        $ret .= "<select style='width: 18em;' title=\"\" >";
        $ret .= "<option value=\"Trigger:\">Trigger: " . $trigger . "</option>";
        $ret .=
            "<option value=\"Trigger:\">on: "
          . ReadingsVal( $name, '.Trigger_on', 'not defined' )
          . "</option>";
        $ret .=
            "<option value=\"Trigger:\">off: "
          . ReadingsVal( $name, '.Trigger_off', 'not defined' )
          . "</option>";
        $ret .=
            "<option value=\"Trigger:\">only_cmd_on: "
          . ReadingsVal( $name, '.Trigger_cmd_on', 'not defined' )
          . "</option>";
        $ret .=
            "<option value=\"Trigger:\">only_cmd_off: "
          . ReadingsVal( $name, '.Trigger_cmd_off', 'not defined' )
          . "</option>";
        $ret .= "</select>";
    }
    $ret .= $affectedtime;
    $ret .= $affected;

    #$ret .="</td><td informId=\"".$name."tmp\">".$triggerc." ".$timer."";

    if ( AttrVal( $name, 'disable', "0" ) eq '1' ) {
        $ret .= "
	</td><td informId=\"" . $name . "tmp\">State: 
	</td><td informId=\"" . $name . "tmp\">
	<div class=\"dval\" informid=\"" . $name . "-state\"></div>
	</td><td informId=\"" . $name . "tmp\">
	<div informid=\"" . $name . "-state-ts\">disabled</div>
	 ";
    }
    else {

        #log:".AttrVal( $name, 'verbose', '0' )."

        $ret .= "
	</td><td informId=\"" . $name . "tmp\">
	
	State: 
	</td><td informId=\"" . $name . "tmp\">
	<div class=\"dval\" informid=\""
          . $name
          . "-state\">"
          . ReadingsVal( $name, 'state', '' ) . "</div>
	</td><td informId=\"" . $name . "tmp\">
	<div informid=\""
          . $name
          . "-state-ts\">"
          . ReadingsTimestamp( $name, 'state', '' ) . "</div>
	 ";
    }

    $ret .= "<script>

	\$( \"td[informId|=\'" . $name . "\']\" ).attr(\"informId\", \'test\');
	\$(document).ready(function(){
	\$( \".col3\" ).text( \"\" );
	\$( \".devType\" ).text( \"MSwitch Inforoom: Anzeige der Deviceinformationen, Änderungen sind nur in den Details möglich.\" );
	});
</script>";

    # alertmessage()
    return $ret;
}

####################
sub MSwitch_LoadHelper($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
    my $oldtrigger = ReadingsVal( $Name, 'Trigger_device', 'undef' );
    my $devhash    = undef;
    my $cdev       = '';
    my $ctrigg     = '';
    if ( defined $hash->{DEF} ) {
        $devhash = $hash->{DEF};
        my @dev = split( /#/, $devhash );
        $devhash = $dev[0];
        ( $cdev, $ctrigg ) = split( / /, $devhash );
        if ( defined $ctrigg ) {
            $ctrigg =~ s/\.//g;
        }
        else { $ctrigg = '' }
        if ( defined $devhash ) {
            Log3( $Name, 5,
                "MSwitch_LoadHelper: devhash : $devhash L:" . __LINE__ );
            $hash->{NOTIFYDEV} = $cdev; # stand aug global ... änderung auf ...
            readingsSingleUpdate( $hash, "Trigger_device", $cdev, 0 );
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
    if ( AttrVal( $Name, 'MSwitch_Activate_MSwitchcmds', "0" ) eq '1' ) {
        addToAttrList('MSwitchcmd');
    }
##########################################erste initialisierung eines devices
    Log3( $Name, 5,
            "MSwitch_LoadHelper: Vcheck  "
          . ReadingsVal( $Name, '.V_Check', 'undef' )
          . " -> $vupdate  L:"
          . __LINE__ );
    if ( ReadingsVal( $Name, '.V_Check', 'undef' ) ne $vupdate ) {
        MSwitch_VUpdate($hash);

    }
###############################################################################

    if ( ReadingsVal( $Name, '.First_init', 'undef' ) ne 'done' ) {

        readingsBeginUpdate($hash);
        readingsBulkUpdate( $hash, ".V_Check", $vupdate );
        readingsBulkUpdate( $hash, "state",    'off' );
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
        readingsEndUpdate( $hash, 0 );

        # setze ignoreliste
        $attr{$Name}{MSwitch_Ignore_Types} = join( " ", @doignore );

        # setze attr inforoom
        my $testdev = '';
      LOOP22:
        foreach my $testdevices ( keys %{ $modules{MSwitch}{defptr} } )    #
        {
            if ( $Name eq $testdevices ) { next LOOP22; }
            $testdev = AttrVal( $testdevices, 'MSwitch_Inforoom', '' );
            Log3( $Name, 5,
                "MSwitch_LoadHelper: $testdevices tsetdev =  $testdev L:"
                  . __LINE__ );
        }
        if ( $testdev ne '' ) { $attr{$Name}{MSwitch_Inforoom} = $testdev }

        #setze alle attrs
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
    }
    MSwitch_Createtimer($hash);    #Neustart aller timer
}

####################
sub MSwitch_Define($$) {
    my $loglevel = 0;
    my ( $hash, $def ) = @_;
    my @a          = split( "[ \t][ \t]*", $def );
    my $name       = $a[0];
    my $devpointer = $name;
    my $devhash    = '';
    $modules{MSwitch}{defptr}{$devpointer} = $hash;
    $hash->{Version} = $version;
    MSwitch_LoadHelper($hash) if ($init_done);
    return;
}

####################
sub MSwitch_Get($$@) {
    my ( $hash, $name, $opt, @args ) = @_;
    my $ret;
    my $loglevel = 5;
    return "\"get $name\" needs at least one argument" unless ( defined($opt) );
####################
    if ( $opt eq 'restore_MSwitch_Data' && $args[0] eq "this_Device" ) {
        $ret = MSwitch_backup_this($hash);
        return $ret;
    }
####################
    if ( $opt eq 'restore_MSwitch_Data' && $args[0] eq "all_Devices" ) {
        open( BACKUPDATEI, "<MSwitch_backup.cfg" )
          || return "no Backupfile found\n";
        close(BACKUPDATEI);
        $hash->{helper}{RESTORE_ANSWER} = $hash->{CL};

        #$hash->{helper}{RUNNING_PID} =;
        #BlockingCall( 'MSwitch_backup_all', $hash, 'MSwitch_backup_done' );

        my $ret = MSwitch_backup_all($hash);

        return $ret;
    }
####################
    if ( $opt eq 'checkevent' ) {
        $ret = MSwitch_Check_Event( $hash, $args[0] );
        return $ret;
    }
####################
    if ( $opt eq 'get_config' ) {
        $ret = MSwitch_Getconfig($hash);
        return $ret;
    }
####################

    if ( $opt eq 'checkcondition' ) {
        Log3( $name, 5, "$name condition args[0] -> $args[0] L:" . __LINE__ );
        my ( $condstring, $eventstring ) = split( /\|/, $args[0] );
        $condstring =~ s/\(DAYS\)/|/g;
        Log3( $name, 5,
"$name condition condstring, eventstring -> $condstring, $eventstring L:"
              . __LINE__ );
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
                '<div style="color: #FF0000">Syntaxfehler:<br>'
              . $errorstring
              . '</div><br>';
        }
        elsif ( $condstring1 eq 'Klammerfehler' ) {
            $ret1 =
'<div style="color: #FF0000">Syntaxfehler:<br>Fehler in der Klammersetzung, die Anzahl öffnender und schliessender Klammern stimmt nicht überein . </div><br>';
        }
        else {
            if ( $ret1 eq 'true' ) {
                $ret1 = 'Bedingung ist Wahr und wird ausgeführt';
            }
            if ( $ret1 eq 'false' ) {
                $ret1 = 'Bedingung ist nicht Wahr und wird nicht ausgeführt';
            }
        }
        $condstring =~ s/~/ /g;
        my $condmarker = $condstring1;
        my $x          = 0;              # exit secure
        while ( $condmarker =~ m/(.*)(\d{10})(.*)/ ) {
            $x++;                        # exit secure
            last if $x > 20;             # exit secure
            my $timestamp = FmtDateTime($2);
            chop $timestamp;
            chop $timestamp;
            chop $timestamp;
            my ( $st1, $st2 ) = split( / /, $timestamp );
            $condmarker = $1 . $st2 . $3;
        }
        $ret =
"eingehender String:<br>$condstring<br><br>If Anweisung Perl:<br>$condstring1<br><br>";
        $ret .= "If Anweisung Perl Klarzeiten:<br>$condmarker<br><br>"
          if $x > 0;
        $ret .= $ret1;
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

    if ( $opt eq 'active_timer' ) {
        my $timehash = $hash->{helper}{timer};
        foreach my $a ( keys %{$timehash} ) {
            my $time = FmtDateTime( $hash->{helper}{timer}{$a} );
            if ( $args[0] eq 'delete' ) {
                $ret .= "deleted: " . $time . " - $a <br>";
                RemoveInternalTimer($a);
                delete( $hash->{helper}{timer}{$a} );
            }
            else {

                my @timers = split( /,/, $a );

                $ret .= $time . " - $timers[0] <br>";
            }
        }
        if ( $args[0] eq 'delete' ) {
            MSwitch_Createtimer($hash);
            $ret .=
              "<br>INFO: Alle anstehenden Timer wurden neu berechnet.<br>";
        }
        if ( $ret ne "" ) { return $ret; }
        return
          "<span style=\"font-size: medium\"> no active timers found. <\/span>";
    }
    return
"Unknown argument $opt, choose one of get_config:noArg active_timer:show,delete restore_MSwitch_Data:this_Device,all_Devices";
}

####################
sub MSwitch_AsyncOutput ($) {
    my ( $client_hash, $text ) = @_;
    return $text;
}
#####################################
sub MSwitch_Set($@) {
    my ( $hash, $name, $cmd, @args ) = @_;

    Log3( $name, 5, "args  " . $args[0] );

    Log3( $name, 5, "SUB  " . ( caller(0) )[3] );

    return ""
      if ( IsDisabled($name) )
      ;    # Return without any further action if the module is disabled

    if ( AttrVal( $name, 'MSwitch_Debug', "0" ) eq '2' ) {
        MSwitch_Debug($hash);
    }

    if ( !exists( $sets{$cmd} ) ) {
        my @cList;

        # Overwrite %sets with setList
        my $atts = AttrVal( $name, 'setList', "" );
        my %setlist = split( "[: ][ ]*", $atts );
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
        return
"Unknown argument $cmd, choose one of on:noArg off:noArg del_delays:noArg backup_MSwitch:all_devices";
    }
###### teste auf new defined
###### umlegen auf define oder loadhelper !!!! TODO
    my $testnew = ReadingsVal( $name, '.Trigger_on', 'undef' );
    if ( $testnew eq 'undef' ) {
        readingsBeginUpdate($hash);
        readingsBulkUpdate( $hash, ".Device_Events",   'no_trigger' );
        readingsBulkUpdate( $hash, ".Trigger_on",      'no_trigger' );
        readingsBulkUpdate( $hash, ".Trigger_off",     'no_trigger' );
        readingsBulkUpdate( $hash, "Trigger_log",      'on' );
        readingsBulkUpdate( $hash, ".Device_Affected", 'no_device' );
        readingsEndUpdate( $hash, 0 );
    }
####################
    if ( $cmd eq 'backup_MSwitch' ) {
        MSwitch_backup($hash);
        return;
    }
#################################################

    if ( $cmd eq 'del_delays' ) {
        MSwitch_Delete_Delay( $hash, $name );
        MSwitch_Createtimer($hash);
        return;
    }

####################

####################
    if ( $cmd eq 'saveconfig' ) {

        $args[0] =~ s/\[s\]/ /g;

  #Log3( $name, 0,"$name $args[0] $args[1]  saveconfig reached L:" . __LINE__ );
        MSwitch_saveconf( $hash, $args[0] );

        return;
    }

####################

    # if ( $cmd eq 'import_config' ) {
    # MSwitch_import($hash);
    # return ;
    # }

####################
    if ( $cmd eq "addevent" ) {
        my $devName = ReadingsVal( $name, 'Trigger_device', '' );
        $args[0] =~ s/~/ /g;
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
            $events = $events . $name . '|';
        }
        chop($events);
        readingsSingleUpdate( $hash, ".Device_Events", $events, 1 );
        return;
    }
####################
    #add device
    if ( $cmd eq "add_device" ) {
        MSwitch_Add_Device( $hash, $args[0] );
        return;
    }
####################
    #del device
    if ( $cmd eq "del_device" ) {
        MSwitch_Del_Device( $hash, $args[0] );
        return;
    }
####################
    #lösche trigger
    if ( $cmd eq "del_trigger" ) {
        MSwitch_Delete_Triggermemory($hash);
        return;
    }
####################
    #filter to trigger
    if ( $cmd eq "filter_trigger" ) {
        MSwitch_Filter_Trigger($hash);
        return;
    }
####################
    # setze trigger
    if ( $cmd eq "set_trigger" ) {
        chop( $args[1], $args[2], $args[3], $args[4], $args[5] );
        my $triggertime = 'on'
          . $args[1] . '~off'
          . $args[2]
          . '~ononly'
          . $args[3]
          . '~offonly'
          . $args[4];

        my $oldtrigger = ReadingsVal( $name, 'Trigger_device', '' );
        readingsSingleUpdate( $hash, "Trigger_device",     $args[0], '1' );
        readingsSingleUpdate( $hash, ".Trigger_condition", $args[5], 0 );

        if ( !defined $args[6] ) {
            readingsDelete( $hash, '.Trigger_Whitelist' );
        }
        else {
            readingsSingleUpdate( $hash, ".Trigger_Whitelist", $args[6], 0 );
        }
        my $testtrig = ReadingsVal( $name, 'Trigger_device', '' );
        if ( $oldtrigger ne $args[0] ) {

            # lösche alle events
            MSwitch_Delete_Triggermemory($hash);
        }
        if (   $args[1] ne ''
            || $args[2] ne ''
            || $args[3] ne ''
            || $args[4] ne '' )
        {
            readingsSingleUpdate( $hash, ".Trigger_time", $triggertime, 0 );
            MSwitch_Createtimer($hash);
        }
        else {
            readingsSingleUpdate( $hash, ".Trigger_time", '', 0 );
            delete( $hash->{READINGS}{Next_Time_Event} );
            delete( $hash->{NEXT_TIMERCHECK} );
            delete( $hash->{NEXT_TIMEREVENT} );
            RemoveInternalTimer($hash);
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
                $hash->{NOTIFYDEV} = $args[0];
                my $devices = MSwitch_makeAffected($hash);
                $hash->{DEF} = $args[0] . ' # ' . $devices;
            }
        }
        else {
            $hash->{NOTIFYDEV} = 'no_trigger';
            delete $hash->{DEF};
        }
        return;
    }
####################
    # setze trigger events
    if ( $cmd eq "trigger" ) {
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
        readingsBulkUpdate( $hash, ".Trigger_on",  $triggeron );
        readingsBulkUpdate( $hash, ".Trigger_off", $triggeroff );

        if ( $args[2] eq 'nein' ) {
            readingsBulkUpdate( $hash, "Trigger_log", 'off' );
        }
        if ( $args[2] eq 'ja' ) {
            readingsBulkUpdate( $hash, "Trigger_log", 'on' );
        }
        readingsBulkUpdate( $hash, ".Trigger_cmd_on",  $triggercmdon );
        readingsBulkUpdate( $hash, ".Trigger_cmd_off", $triggercmdoff );
        readingsEndUpdate( $hash, 0 );
        return;
    }
###################
    # setze devices
    if ( $cmd eq "devices" ) {
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

                if ( $oldcmd eq '1' ) { next LOOP6 }
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
        readingsSingleUpdate( $hash, ".Device_Affected", $devices, 0 )
          ;    # alle gesetzten geräte durch komma getrennt
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

    # setze devices details
    if ( $cmd eq "details" ) {
        $args[0] = urlDecode( $args[0] );
        chop( $args[0] );
        my @devices =
          split( /,/, ReadingsVal( $name, '.Device_Affected', '' ) );
        my @inputcmds = split( /,/, $args[0] )
          ; # formfelder für geräte durch | getrennt , devices durch komma getrennt
        my $counter     = 0;
        my $error       = '';
        my $key         = '';
        my $savedetails = '';
      LOOP10: foreach (@devices) {
            if ( $inputcmds[$counter] eq '' ) { next LOOP10; }
            $inputcmds[$counter] =~ s/\(:\)/:/g;
            my @devicecmds = split( /\|/, $inputcmds[$counter] );
            $savedetails = $savedetails . $_ . ',';
            $savedetails = $savedetails . $devicecmds[0] . ',';
            $savedetails = $savedetails . $devicecmds[1] . ',';
            $savedetails = $savedetails . $devicecmds[2] . ',';
            $savedetails = $savedetails . $devicecmds[3] . ',';
            $savedetails = $savedetails . $devicecmds[4] . ',';
            $savedetails = $savedetails . $devicecmds[5] . ',';
            $savedetails = $savedetails . $devicecmds[7] . ',';
            $savedetails = $savedetails . $devicecmds[6] . ',';

            if ( defined $devicecmds[8] ) {

                #$devicecmds[8] =~ s/\|/(X)/g;
                $savedetails = $savedetails . $devicecmds[8] . ',';
            }
            else {
                $savedetails = $savedetails . '' . ',';
            }
            if ( defined $devicecmds[9] ) {

                #$devicecmds[9] =~ s/\|/(X)/g;
                $savedetails = $savedetails . $devicecmds[9] . '|';
            }
            else {
                $savedetails = $savedetails . '' . '|';
            }
            $counter++;
        }
        chop($savedetails);
        readingsSingleUpdate( $hash, ".Device_Affected_Details", $savedetails,
            0 );
        return;
    }
####################
    my $update = '';
    my @testdetails =
      qw(_on _off _onarg _offarg _playback _record _timeon _timeoff _conditionon _conditionoff);
    my @testdetailsstandart =
      ( 'no_action', 'no:action', '', '', 'nein', 'nein', 0, 0, '', '' );
    if ( $cmd eq "on" ) {
        ### ausführen des on befehls
        my @cmdpool;    # beinhaltet alle befehle die ausgeführt werden müssen
        my %devicedetails = MSwitch_makeCmdHash($name);

        my @devices =
          split( /,/, ReadingsVal( $name, '.Device_Affected', '' ) );
      LOOP: foreach my $device (@devices) {

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

            if ( AttrVal( $name, 'MSwitch_Delete_Delays', '0' ) eq '1' ) {
                MSwitch_Delete_Delay( $hash, $device );
            }

            # teste auf on kommando
            if ( $device eq "no_device" ) {
                next LOOP;
            }
            my $key      = $device . "_on";
            my $timerkey = $device . "_timeon";
            $devicedetails{ $device . '_onarg' } =~ s/~/ /g;
            $devicedetails{ $device . '_offarg' } =~ s/~/ /g;
            my $testtstate = $devicedetails{$timerkey};

            $testtstate =~ s/[A-Za-z0-9#\.\-_]//g;
            if ( $testtstate eq "[:]" ) {
                $devicedetails{$timerkey} =
                  eval MSwitch_Checkcond_state( $devicedetails{$timerkey},
                    $name );
                my $hdel = ( substr( $devicedetails{$timerkey}, 0, 2 ) ) * 3600;
                my $mdel = ( substr( $devicedetails{$timerkey}, 3, 2 ) ) * 60;
                my $sdel = ( substr( $devicedetails{$timerkey}, 6, 2 ) ) * 1;
                $devicedetails{$timerkey} = $hdel + $mdel + $sdel;
            }
            #### teste auf condition
            #### antwort $execute 1 oder 0 ;
            my $conditionkey = $device . "_conditionon";
            if (   $devicedetails{$key} ne ""
                && $devicedetails{$key} ne "no_action" )    #befehl gefunden
            {
                my $cs =
"set $devicenamet $devicedetails{$device.'_on'} $devicedetails{$device.'_onarg'}";
                if ( $devicenamet eq 'FreeCmd' ) {
                    $cs = "$devicedetails{$device.'_onarg'}";
                }

                if (   $devicedetails{$timerkey} eq "0"
                    || $devicedetails{$timerkey} eq "" )
                {
                    ########### teste auf condition
                    ### antwort $execute 1 oder 0 ;

                    Log3( $name, 3,
                        "$name MSwitch_Set: aufruf MSwitch_checkcondition L:"
                          . __LINE__ );

                    my $execute =
                      MSwitch_checkcondition( $devicedetails{$conditionkey},
                        $name, $args[0] );

                    if ( $execute eq 'true' ) {
                        Log3( $name, 3,
                            "$name MSwitch_Set: Befehlsausfuehrung -> $cs L:"
                              . __LINE__ );

                        # variabelersetzung
                        $cs =~ s/\$NAME/$hash->{helper}{eventfrom}/;
                        push @cmdpool, $cs;
                        $update = $device . ',' . $update;
                    }
                }
                else {

                    ####################################################
                    Log3( $name, 4,
                        "$name MSwitch_Set: delay oder at gefunden L:"
                          . __LINE__ );

                    my $execute =
                      MSwitch_checkcondition( $devicedetails{$conditionkey},
                        $name, $args[0] );
                    if ( $execute eq 'true' ) {
                        Log3( $name, 3,
"$name MSwitch_Set: conidtion ok - Befehl mt at/delay wird ausgefuehrt -> $cs L:"
                              . __LINE__ );

                        my $delaykey     = $device . "_delayaton";
                        my $delayinhalt  = $devicedetails{$delaykey};
                        my $delaykey1    = $device . "_delayatonorg";
                        my $teststateorg = $devicedetails{$delaykey1};
                        Log3( $name, 3,
"$name MSwitch_Set: teststateorg -> $teststateorg L:"
                              . __LINE__ );
                        if ( $delayinhalt eq 'at0' || $delayinhalt eq 'at1' ) {
                            $devicedetails{$timerkey} =
                              MSwitch_replace_delay( $hash, $teststateorg );
                        }
                        ##################################

                        my $timecond =
                          gettimeofday() + $devicedetails{$timerkey};

                        if ( $delayinhalt eq 'at1' || $delayinhalt eq 'delay0' )
                        {
                            $conditionkey = 'nocheck';
                        }

                        my $msg =
                            $cs . ","
                          . $name . ","
                          . $conditionkey . ",,"
                          . $timecond;

                        # variabelersetzung
                        $msg =~ s/\$NAME/$hash->{helper}{eventfrom}/;

                        Log3( $name, 4,
                            "$name MSwitch_Set: $msg L:" . __LINE__ );

                        $hash->{helper}{timer}{$msg} = $timecond;
                        InternalTimer( $timecond, "MSwitch_Restartcmd", $msg );
                    }
                }
            }

        }
        readingsSingleUpdate( $hash, "state", $cmd, 1 );
        MSwitch_Cmd( $hash, @cmdpool );
        return;
    }

    if ( $cmd eq "off" ) {
        my @cmdpool;
        if ( defined( $args[0] ) ) {
            readingsSingleUpdate( $hash, "last_event", $args[0], 0 );
        }
        ### ausführen des off befehls
        my %devicedetails = MSwitch_makeCmdHash($name);

        # betroffene geräte suchen
        my @devices =
          split( /,/, ReadingsVal( $name, '.Device_Affected', '' ) );
      LOOP1: foreach my $device (@devices) {
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

            # teste auf on kommando
            if ( $device eq "no_device" ) {
                next LOOP1;
            }
            my $key      = $device . "_off";
            my $timerkey = $device . "_timeoff";
            $devicedetails{ $device . '_onarg' } =~ s/~/ /g;
            $devicedetails{ $device . '_offarg' } =~ s/~/ /g;
            my $testtstate = $devicedetails{$timerkey};

            $testtstate =~ s/[A-Za-z0-9#\.\-_]//g;
            if ( $testtstate eq "[:]" ) {
                $devicedetails{$timerkey} =
                  eval MSwitch_Checkcond_state( $devicedetails{$timerkey},
                    $name );
                my $hdel = ( substr( $devicedetails{$timerkey}, 0, 2 ) ) * 3600;
                my $mdel = ( substr( $devicedetails{$timerkey}, 3, 2 ) ) * 60;
                my $sdel = ( substr( $devicedetails{$timerkey}, 6, 2 ) ) * 1;
                $devicedetails{$timerkey} = $hdel + $mdel + $sdel;
            }
            ############ teste auf condition
            ### antwort $execute 1 oder 0 ;
            my $conditionkey = $device . "_conditionoff";

            #nur wenn kein timer   !!!!!!!!!!!!!!!!!!
            if (   $devicedetails{$key} ne ""
                && $devicedetails{$key} ne "no_action" )    #befehl gefunden
            {
                my $cs =
"set $devicenamet $devicedetails{$device.'_off'} $devicedetails{$device.'_offarg'}";
                if ( $devicenamet eq 'FreeCmd' ) {
                    $cs = "$devicedetails{$device.'_offarg'}";
                }

                #my $conditionkey;
                if (   $devicedetails{$timerkey} eq "0"
                    || $devicedetails{$timerkey} eq "" )
                {
                    ### teste auf condition
                    ### antwort $execute 1 oder 0 ;
                    $conditionkey = $device . "_conditionoff";
                    Log3( $name, 5,
                        "$name MSwitch_Set: aufruf MSwitch_Checkkondition L:"
                          . __LINE__ );

                    # my $execute =
                    # MSwitch_checkcondition( $devicedetails{$conditionkey},
                    # $name, '' );

                    my $execute =
                      MSwitch_checkcondition( $devicedetails{$conditionkey},
                        $name, $args[0] );

                    if ( $execute eq 'true' ) {

                        # my $errors = AnalyzeCommandChain( undef, $cs );
                        # variabelersetzung
                        $cs =~ s/\$NAME/$hash->{helper}{eventfrom}/;
                        push @cmdpool, $cs;
                        $update = $device . ',' . $update;
                    }
                }
                else {

                    ####################################################
                    Log3( $name, 4,
                        "$name MSwitch_Set: delay oder at gefunden L:"
                          . __LINE__ );

                    my $execute =
                      MSwitch_checkcondition( $devicedetails{$conditionkey},
                        $name, $args[0] );
                    if ( $execute eq 'true' ) {
                        Log3( $name, 3,
"$name MSwitch_Set: conidtion ok - Befehl mt at/delay wird ausgefuehrt -> $cs L:"
                              . __LINE__ );

                        my $delaykey    = $device . "_delayatoff";
                        my $delayinhalt = $devicedetails{$delaykey};

                        my $delaykey1    = $device . "_delayatofforg";
                        my $teststateorg = $devicedetails{$delaykey1};

                        if ( $delayinhalt eq 'at0' || $delayinhalt eq 'at1' ) {
                            $devicedetails{$timerkey} =
                              MSwitch_replace_delay( $hash, $teststateorg );
                        }

                        ##################################
                        my $timecond =
                          gettimeofday() + $devicedetails{$timerkey};

                        if ( $delayinhalt eq 'at1' || $delayinhalt eq 'delay0' )
                        {
                            $conditionkey = 'nocheck';
                        }

                        my $msg =
                            $cs . ","
                          . $name . ","
                          . $conditionkey . ",,"
                          . $timecond;

                        # variabelersetzung
                        $msg =~ s/\$NAME/$hash->{helper}{eventfrom}/;
                        $hash->{helper}{timer}{$msg} = $timecond;
                        InternalTimer( $timecond, "MSwitch_Restartcmd", $msg );
                    }
                }
            }
        }
        readingsSingleUpdate( $hash, "state", $cmd, 1 );
        MSwitch_Cmd( $hash, @cmdpool );
        return;
    }
    return;
}
###################################

sub MSwitch_Cmd(@) {
    my ( $hash, @cmdpool ) = @_;
    my $Name = $hash->{NAME};

    Log3( $Name, 5, "SUB  " . ( caller(0) )[3] );

    foreach my $cmds (@cmdpool) {

        Log3( $Name, 5, "$Name MSwitch_Set:  $cmds " . __LINE__ );

        if ( $cmds =~ m/set (.*)(MSwitchtoggle)(.*)/ ) {
            Log3( $Name, 5, "$Name MSwitch_Set:  $cmds " . __LINE__ );
            $cmds = MSwitch_toggle( $hash, $cmds );
        }

        Log3( $Name, 5, "$Name errechneter befehl:  $cmds " . __LINE__ );

        my $errors = AnalyzeCommandChain( undef, $cmds );
        if ( defined($errors) ) {
            Log3( $Name, 1,
                "$Name MSwitch_Set: ERROR $cmds: $errors " . __LINE__ );
        }
    }
    my $showpool = join( ',', @cmdpool );
    readingsSingleUpdate( $hash, "Exec_cmd", $showpool, 1 );
}
####################

sub MSwitch_toggle($$) {
    my ( $hash, $cmds ) = @_;
    my $Name = $hash->{NAME};
    Log3( $Name, 5, "$Name MSwitch_toggle:  $cmds " . __LINE__ );
    $cmds =~ m/(set) (.*)( )MSwitchtoggle (.*)\/(.*)/;

    Log3( $Name, 5, "$Name MSwitch_toggle:  x$1x " . __LINE__ );
    Log3( $Name, 5, "$Name MSwitch_toggle:  x$2x " . __LINE__ );
    Log3( $Name, 5, "$Name MSwitch_toggle:  x$3x " . __LINE__ );
    Log3( $Name, 5, "$Name MSwitch_toggle:  x$4x " . __LINE__ );
    Log3( $Name, 5, "$Name MSwitch_toggle:  x$5x " . __LINE__ );

    my $cmd1 = $1 . " " . $2 . " " . $4;
    my $cmd2 = $1 . " " . $2 . " " . $5;

    my $chk1 = $4;
    my $chk2 = $5;

    my $testnew = ReadingsVal( $2, 'state', 'undef' );

    if    ( $testnew eq $chk1 ) { $cmds = $cmd2 }
    elsif ( $testnew eq $chk2 ) { $cmds = $cmd1 }
    else                        { $cmds = $cmd1 }

    Log3( $Name, 5, "$Name MSwitch_toggle: testnew -> $testnew " . __LINE__ );
    Log3( $Name, 5, "$Name MSwitch_toggle: cmd1 -> $cmd1 " . __LINE__ );
    Log3( $Name, 5, "$Name MSwitch_toggle: cmd2 -> $cmd2 " . __LINE__ );
    Log3( $Name, 5, "$Name MSwitch_toggle: neuer befehl -> $cmds " . __LINE__ );

    return $cmds;
}

########################################

sub MSwitch_Attr(@) {
    my ( $cmd, $name, $aName, $aVal ) = @_;
    my $hash = $defs{$name};
    if ( $aName eq 'MSwitch_Debug' && ( $aVal == 0 || $aVal == 1 ) ) {
        delete( $hash->{READINGS}{Device_Affected} );
        delete( $hash->{READINGS}{Device_Affected_Details} );
        delete( $hash->{READINGS}{Device_Events} );
    }
    if ( $cmd eq 'set' && $aName eq 'disable' && $aVal == 1 ) {
        $hash->{NOTIFYDEV} = 'no_trigger';
    }
    if (   $cmd eq 'set'
        && $aName eq 'disable'
        && $aVal == 0
        && ReadingsVal( $name, 'Trigger_device', 'no_trigger' ) ne
        'no_trigger' )
    {
        $hash->{NOTIFYDEV} =
          ReadingsVal( $name, 'Trigger_device', 'no_trigger' );
    }
    if (   $cmd eq 'del'
        && $aName eq 'disable'
        && ReadingsVal( $name, 'Trigger_device', 'no_trigger' ) ne
        'no_trigger' )
    {
        $hash->{NOTIFYDEV} =
          ReadingsVal( $name, 'Trigger_device', 'no_trigger' );
    }

    if ( $aName eq 'MSwitch_Activate_MSwitchcmds' && $aVal == 1 ) {
        addToAttrList('MSwitchcmd');
    }

    if ( $cmd eq 'set' && $aName eq 'MSwitch_Inforoom' ) {
        my $testarg = $aVal;
        foreach my $testdevices ( keys %{ $modules{MSwitch}{defptr} } )    #
        {
            $attr{$testdevices}{MSwitch_Inforoom} = $testarg;
        }
    }
###############ende set
    if ( $cmd eq 'del' ) {
        my $testarg = $aName;
        my $errors;
        if ( $testarg eq 'MSwitch_Inforoom' ) {
          LOOP21:
            foreach my $testdevices ( keys %{ $modules{MSwitch}{defptr} } )    #
            {
                if ( $testdevices eq $name ) { next LOOP21; }
                delete( $attr{$testdevices}{MSwitch_Inforoom} );
            }
        }
    }
###############ende del
    return undef;
}
####################
sub MSwitch_Delete($$) {
    my ( $hash, $name ) = @_;
    RemoveInternalTimer($hash);
    return undef;
}
####################
sub MSwitch_Undef($$) {
    my ( $hash, $name ) = @_;
    RemoveInternalTimer($hash);
    delete( $modules{MSwitch}{defptr}{$name} );
    return undef;
}
####################
sub MSwitch_Notify($$) {
    my $testtoggle = '';
    my ( $own_hash, $dev_hash ) = @_;
    my $ownName = $own_hash->{NAME};    # own name / hash

    Log3( $ownName, 5, "SUB  " . ( caller(0) )[3] );

    my @cmdarray;
    my @cmdarray1;    #enthält auszuführende befehle nach conditiontest
    return ""
      if ( IsDisabled($ownName) )
      ;    # Return without any further action if the module is disabled
    my $events = deviceEvents( $dev_hash, 1 );

    my $incommingdevice = '';
    if ( defined( $own_hash->{helper}{testevent_device} ) ) {
        $events          = 'x';
        $incommingdevice = ( $own_hash->{helper}{testevent_device} );
    }
    else {
        $incommingdevice = $dev_hash->{NAME};    # aufrufendes device
    }
    my $triggerdevice = ReadingsVal( $ownName, 'Trigger_device', '' )
      ;    # device welches das modul an/aus schaltet
    my $devName = $dev_hash->{NAME};    # Device that created the event
    if ( $devName eq "global"
        && grep( m/^INITIALIZED|REREADCFG$/, @{$events} ) )
    {
        MSwitch_LoadHelper($own_hash);
    }
    return if ( !$events );
########### ggf. löschen
    my $triggeron     = ReadingsVal( $ownName, '.Trigger_on',      '' );
    my $triggeroff    = ReadingsVal( $ownName, '.Trigger_off',     '' );
    my $triggercmdon  = ReadingsVal( $ownName, '.Trigger_cmd_on',  '' );
    my $triggercmdoff = ReadingsVal( $ownName, '.Trigger_cmd_off', '' );
##############################
    my $triggerlog = ReadingsVal( $ownName, 'Trigger_log', 'off' );
    my $set        = "noset";
    my $eventcopy  = "";

    # notify für eigenes device #
    my $devcopyname = $devName;
    $own_hash->{helper}{eventfrom} = $devName;
    my @eventscopy;
    if ( defined( $own_hash->{helper}{testevent_event} ) ) {

        # wenn global , sonst ohne 1
        @eventscopy =
          "$own_hash->{helper}{testevent_event}";    ###########estevent1
    }
    else {
        @eventscopy = ( @{$events} );
    }

    if (   $incommingdevice eq $triggerdevice
        || $triggerdevice eq "all_events" )          #
    {
        # teste auf triggertreffer
        #EVENT: foreach my $event (@{$events})
      EVENT: foreach my $event (@eventscopy)

        {
            Log3( $ownName, 5, "  $ownName $event" );
            $event = "" if ( !defined($event) );
            $eventcopy = $event;
            $eventcopy =~ s/: /:/s;    # BUG  !!!!!!!!!!!!!!!!!!!!!!!!
            if ( $triggerlog eq 'on' ) {
                my @filters =
                  split( /,/,
                    AttrVal( $ownName, 'MSwitch_Trigger_Filter', '' ) )
                  ;                    # beinhaltet filter durch komma getrennt
                foreach my $filter (@filters) {
                    my $wildcarttest = index( $filter, "*", 0 );
                    if ( $wildcarttest > -1 )    ### filter auf wildcart
                    {
                        $filter = substr( $filter, 0, $wildcarttest );
                        my $testwildcart = index( $eventcopy, $filter, 0 );
                        if ( $testwildcart eq '0' ) { next EVENT; }
                    }
                    else                         ### filter genauen ausdruck
                    {
                        if ( $eventcopy eq $filter ) { next EVENT; }
                    }
                }
########################################
                if ( $triggerdevice eq "all_events" ) {
                    $own_hash->{helper}{events}{'all_events'}
                      { $devName . ':' . $eventcopy } = "on";
                }
                else {
                    $own_hash->{helper}{events}{$devName}{$eventcopy} = "on";
                }
            }

            my $eventcopy1 = $eventcopy;
            if ( $triggerdevice eq "all_events" ) {
                $eventcopy1 = "$devName:$eventcopy";
            }

            my $direktswitch = 0;
            my @eventsplit   = split( /\:/, $eventcopy );
            my $eventstellen = @eventsplit;
            if ( $triggeron ne 'no_trigger' ) {
                my $testvar =
                  MSwitch_checktrigger( $own_hash, $ownName, $eventstellen,
                    $triggeron, $incommingdevice, 'on', $eventcopy,
                    @eventsplit );
                $set = $testvar if $testvar ne 'undef';
            }

            if ( $triggeroff ne 'no_trigger' ) {
                my $testvar =
                  MSwitch_checktrigger( $own_hash, $ownName, $eventstellen,
                    $triggeroff, $incommingdevice, 'off', $eventcopy,
                    @eventsplit );
                $set = $testvar if $testvar ne 'undef';
            }
            if ( $triggercmdoff ne 'no_trigger' )    #
            {
                my $testvar =
                  MSwitch_checktrigger( $own_hash, $ownName, $eventstellen,
                    $triggercmdoff, $incommingdevice, 'offonly', $eventcopy,
                    @eventsplit );
                push @cmdarray, $own_hash . ',off,check,' . $eventcopy1
                  if $testvar ne 'undef';
            }
            if ( $triggercmdon ne 'no_trigger' )     #
            {
                my $testvar =
                  MSwitch_checktrigger( $own_hash, $ownName, $eventstellen,
                    $triggercmdon, $incommingdevice, 'ononly', $eventcopy,
                    @eventsplit );
                push @cmdarray, $own_hash . ',on,check,' . $eventcopy1
                  if $testvar ne 'undef';
            }

            #verlasse routine wenn keine werte im array
            my $anzahl = @cmdarray;

    #ausführen aller cmds	 in @cmdarray nach triggertest aber vor conditiontest
    #my @cmdarray1;	#enthält auszuführende befehle nach conditiontest
    # schaltet zweig 3 und 4
            if ( $anzahl != 0 ) {
              LOOP31: foreach (@cmdarray) {
                    if ( $_ eq 'undef' ) { next LOOP31; }
                    my ( $ar1, $ar2, $ar3, $ar4 ) = split( /,/, $_ );
                    Log3( $ownName, 5,
"$ownName MSwitch_Notify: aufruf MSwitch_Exec_Notif -> $own_hash, $ar2, $ar3, $ar4  L:"
                          . __LINE__ );
                    my $returncmd = 'undef';
                    $returncmd =
                      MSwitch_Exec_Notif( $own_hash, $ar2, $ar3, $ar4 );
                    if ( defined $returncmd && $returncmd ne 'undef' ) {
                        chop $returncmd;    #CHANGE
                        push( @cmdarray1, $returncmd );
                    }
                }
                my $befehlssatz = join( ',', @cmdarray1 );
                Log3( $ownName, 5,
                    "$ownName MSwitch_Notify: Befehlsatz -> $befehlssatz  L:"
                      . __LINE__ );
                foreach ( split( /,/, $befehlssatz ) ) {
                    Log3( $ownName, 5,
                        "$ownName MSwitch_Notify: Befehlsausfuehrung -> $_ L:"
                          . __LINE__ );
                    my $ecec = $_;
                    my $errors = AnalyzeCommandChain( undef, $_ );
                    if ( defined($errors) ) {
                        Log3( $ownName, 1,
"$ownName MSwitch_Notify: Fehler bei Befehlsausführung $errors -> Comand: $_ "
                              . __LINE__ );
                    }
                    readingsSingleUpdate( $own_hash, "Exec_cmd", $ecec, 1 );
                }
            }
            Log3( $ownName, 5,
                "$ownName MSwitch_Notify: einzeleventtest ende L:" . __LINE__ );
            #### ende loopeinzeleventtest
        }

        # schreibe gruppe mit events
        my $events    = '';
        my $eventhash = $own_hash->{helper}{events}{$devName};
        if ( $triggerdevice eq "all_events" ) {
            $eventhash = $own_hash->{helper}{events}{all_events};
        }
        else {
            $eventhash = $own_hash->{helper}{events}{$devName};
        }
        foreach my $name ( keys %{$eventhash} ) {
            $events = $events . $name . '|';
        }
        chop($events);
        if ( $events ne "" ) {
            readingsSingleUpdate( $own_hash, ".Device_Events", $events, 1 );
        }
###### schreiben ende
        # schalte modul an/aus bei entsprechendem notify
        # teste auf condition
        my $triggercondition =
          ReadingsVal( $ownName, '.Trigger_condition', '' );
        $triggercondition =~ s/\./:/g;

        # schaltet zweig 1 und 2 , $set enthält befehl
        if ( $triggercondition ne '' ) {
            Log3( $ownName, 5,
                "$ownName MSwitch_Notif: Aufruf MSwitch_checkkondition  L:"
                  . __LINE__ );
            my $ret =
              MSwitch_checkcondition( $triggercondition, $ownName, $eventcopy );
            if ( $ret eq 'false' ) {
                Log3( $ownName, 5,
"$ownName MSwitch_Notif: trigger nicht ausgefuehrt (condition $ret) "
                      . __LINE__ );
                Log3( $ownName, 5,
"$ownName MSwitch_Notif: triggercondition -> $triggercondition "
                      . __LINE__ );
                return;
            }
        }
        Log3( $ownName, 5,
"$ownName MSwitch_Notif: var set für folgenden Befehlsaufruf ->  $set - $eventcopy "
              . __LINE__ );
        if ( $set ne "noset" ) {

            my $cs;

            if ( $triggerdevice eq "all_events" ) {
                $cs = "set $ownName $set $devName:$eventcopy";

            }
            else {

                $cs = "set $ownName $set $eventcopy";
            }

            Log3( $ownName, 3,
                "$ownName MSwitch_Notif: Befehlsausfuehrung -> $cs "
                  . __LINE__ );

            # variabelersetzung
            $cs =~ s/\$NAME/$own_hash->{helper}{eventfrom}/;
            my $errors = AnalyzeCommandChain( undef, $cs );
        }
        return;
    }
}
#########################
sub MSwitch_fhemwebFn($$$$) {

    #  my $loglevel = 5;
    my ( $FW_wname, $d, $room, $pageHash ) =
      @_;    # pageHash is set for summaryFn.
    my $hash     = $defs{$d};
    my $Name     = $hash->{NAME};
    my $jsvarset = '';
    my $j1       = '';
    ### teste auf new defined device
    my $hidden = '';
    if ( AttrVal( $Name, 'MSwitch_Debug', "0" ) eq '2' ) { $hidden = '' }
    else                                                 { $hidden = 'hidden' }

    my $triggerdevices = '';
    my $events         = ReadingsVal( $Name, '.Device_Events', '' );
    my @eventsall      = split( /\|/, $events );
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

    #eigene trigger festlegen
    my $optionon      = '';
    my $optiongeneral = '';
    my $optioncmdon   = '';
    my $alltriggers   = '';
    my $to            = '';
    my $toc           = '';
  LOOP12: foreach (@eventsall) {
        $alltriggers =
          $alltriggers . "<option value=\"$_\">" . $_ . "</option>";

        if ( $_ eq 'no_trigger' ) { next LOOP12 }
        if ( $triggeron eq $_ ) {
            $optionon =
                $optionon
              . "<option selected=\"selected\" value=\"$_\">"
              . $_
              . "</option>";
            $to = '1';
        }
        else {
            $optionon = $optionon . "<option value=\"$_\">" . $_ . "</option>";
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
            $optioncmdon =
              $optioncmdon . "<option value=\"$_\">" . $_ . "</option>";
        }

        ####################  nur bei entsprechender regex
        Log3( $Name, 5, "$Name MSwitch_testregex: $_  " );
        my $test = $_;
        if ( $test =~ m/(.*)\((.*)\)(.*)/ ) {
            Log3( $Name, 5, "$Name MSwitch_testregex: wahr  " );
        }
        else {
            Log3( $Name, 5, "$Name MSwitch_testregex: unwahr  " );

            if ( index( $_, '*', 0 ) == -1 ) {
                if (
                    ReadingsVal( $Name, 'Trigger_device', '' ) ne "all_events" )
                {
                    $optiongeneral =
                        $optiongeneral
                      . "<option value=\"$_\">"
                      . $_
                      . "</option>";
                }
                else {

                    $optiongeneral =
                        $optiongeneral
                      . "<option value=\"$_\">"
                      . $_
                      . "</option>";
                }
            }
        }

        #####################
    }
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
####################
    # mögliche affected devices und mögliche triggerdevices
    my $devicesets;
    my $deviceoption = "";
    my $selected     = "";
    my $errors       = "";
    my $javaform     = "";    # erhält javacode für übergabe devicedetail
    my $cs           = "";
    my %cmdsatz;              # ablage desbefehlssatzes jedes devices
    my $globalon = 'off';

    if ( ReadingsVal( $Name, 'Trigger_device', 'no_trigger' ) eq 'no_trigger' )
    {
        $triggerdevices =
"<option selected=\"selected\" value=\"no_trigger\">no_trigger</option>";
    }
    else {
        $triggerdevices = "<option  value=\"no_trigger\">no_trigger</option>";
    }
    if ( AttrVal( $Name, 'MSwitch_Expert', "0" ) eq '1' ) {
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
    my @notype = split( / /, AttrVal( $Name, 'MSwitch_Ignore_Types', "" ) );
    my $affecteddevices = ReadingsVal( $Name, '.Device_Affected', '' );

    # affected devices to hash
    my %usedevices;
    my @deftoarray = split( /,/, $affecteddevices );
    foreach (@deftoarray) {
        my ( $a, $b ) = split( /-/, $_ );
        $usedevices{$a} = 'on';
    }
  LOOP9: for my $name ( sort keys %defs ) {

        my $selectedtrigger = '';
        my $devicealias = AttrVal( $name, 'alias', "" );
        my $devicewebcmd =
          AttrVal( $name, 'webCmd', "noArg" );    # webcmd des devices
        my $devicehash = $defs{$name};            #devicehash
        my $deviceTYPE = $devicehash->{TYPE};

        # triggerfile erzeugen
        foreach (@notype) {
            if ( lc($_) eq lc($deviceTYPE) ) { next LOOP9; }
        }
        if ( ReadingsVal( $Name, 'Trigger_device', '' ) eq $name ) {
            $selectedtrigger = 'selected=\"selected\"';
            if ( $name eq 'all_events' ) { $globalon = 'on' }
        }
        $triggerdevices .=
"<option $selectedtrigger value=\"$name\">$name (a:$devicealias t:$deviceTYPE)</option>";

        # filter auf argumente on oder off ;
        if ( $name eq '' ) { next LOOP9; }
        my $cs = "set $name ?";

        # abfrage und auswertung befehlssatz
        if ( AttrVal( $Name, 'MSwitch_Include_Devicecmds', "1" ) eq '1' ) {

            $errors = AnalyzeCommandChain( undef, $cs );
            if ($errors) {

            }
        }
        else {
            $errors = '';
        }
        if ( !defined $errors ) { $errors = '' }
        my @tmparg = split( /of /, $errors );
        if ( defined $tmparg[1] && $tmparg[1] ne '' ) { $errors = $tmparg[1]; }
        $errors = '|' . $errors;
        $errors =~ s/\| //g;
        $errors =~ s/\|//g;

        if ( $errors eq ''
            && AttrVal( $Name, 'MSwitch_Include_Webcmds', "1" ) eq '1' )
        {
            if ( $devicewebcmd ne "noArg" ) {
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
                $errors       = $devicewebcmd;

            }
        }
        my $usercmds = AttrVal( $name, 'MSwitchcmd', '' );
        if ( $usercmds ne ''
            && AttrVal( $Name, 'MSwitch_Include_MSwitchcmds', "1" ) eq '1' )
        {
            $usercmds =~ tr/:/ /;
            $errors .= ' ' . $usercmds;
        }
        ######################################
        # change

        my $extensions = AttrVal( $Name, 'MSwitch_Extensions', "0" );

        # Log3( $Name, 0," $Name extension -> $extensions". __LINE__ );

        if ( $extensions eq '1' ) {
            $errors .= ' ' . 'MSwitchtoggle';
        }
        ######################################

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
            Log3( $Name, 5,
"$Name MSwitch_FhemwebFn: Device $name wird ignoriert - kein Befehlssatz gefunden L:"
                  . __LINE__ );
        }
    }
    my $select = index( $affecteddevices, 'FreeCmd', 0 );
    if ( $select > -1 ) { $selected = "selected=\"selected\" " }
    $deviceoption =
        "<option "
      . "value=\"FreeCmd\" "
      . $selected
      . ">Free Cmd (nicht an ein Device gebunden)</option>"
      . $deviceoption;
####################
# #devices details
# detailsatz in scalar laden
# my @devicedatails = split(/:/,ReadingsVal($Name, '.Device_Affected_Details', '')); #inhalt decice und cmds durch komma getrennt
    my %savedetails = MSwitch_makeCmdHash($Name);
    my $detailhtml  = "";
    my @affecteddevices =
      split( /,/, ReadingsVal( $Name, '.Device_Affected', '' ) );
    if ( $affecteddevices[0] ne 'no_device' ) {
        $detailhtml =
"<table border='0' class='block wide' id='MSwitchDetails' nm='MSwitch'>
				<tr class='even'>
				<td colspan='5'>device actions :<br>&nbsp;
				<input type='hidden' id='affected' name='affected' size='40'  value ='"
          . ReadingsVal( $Name, '.Device_Affected', '' ) . "'>
				</td>
				</tr>";    #start
        foreach (@affecteddevices) {

         # $cmdsatz{$_} enthält befehlssatz als string getrennt durch " " und :
            my @devicesplit  = split( /-AbsCmd/, $_ );
            my $devicenamet  = $devicesplit[0];
            my $devicenumber = $devicesplit[1];
            my @befehlssatz  = '';
            ##################################
#if( !defined $cmdsatz{$devicenamet}){Log3( $Name, 0, "debug: v -> $_ Name->$Name devicenamet->$devicenamet L:" . __LINE__ );}
            #####################################
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
                $savedetails{$key} = '000000';    #changed 
            }
            if ( !defined( $savedetails{ $aktdevice . '_timeoff' } ) ) {
                my $key = '';
                $key = $aktdevice . "_timeoff";
                $savedetails{$key} = '000000';    #changed
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

            # ACHTUNG CHANGE
            foreach (@befehlssatz)    #befehlssatz einfügen
            {
                #	Log3( $Name, 0, "debug: $_ L:" . __LINE__ );

                my @aktcmdset =
                  split( /:/, $_ );    # befehl von noarg etc. trennen

                $selectedhtml = "";
                if ( $aktcmdset[0] eq $savedetails{ $aktdevice . '_on' } ) {
                    $selectedhtml = "selected=\"selected\"";
                }
                $option1html = $option1html
                  . "<option $selectedhtml value=\"$aktcmdset[0]\">$aktcmdset[0]</option>";
                $selectedhtml = "";
                if ( $aktcmdset[0] eq $savedetails{ $aktdevice . '_off' } ) {
                    $selectedhtml = "selected=\"selected\"";
                }
                $option2html = $option2html
                  . "<option $selectedhtml value=\"$aktcmdset[0]\">$aktcmdset[0]</option>";
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
            $savedetails{ $aktdevice . '_conditionon' } =~ s/~/ /g;
            $savedetails{ $aktdevice . '_conditionoff' } =~ s/~/ /g;
            $savedetails{ $aktdevice . '_onarg' } =~ s/~/ /g;
            $savedetails{ $aktdevice . '_offarg' } =~ s/~/ /g;

            my $dalias = "(a: " . AttrVal( $devicenamet, 'alias', "no" ) . ")"
              if AttrVal( $devicenamet, 'alias', "no" ) ne "no";

            ## block on
            $detailhtml = $detailhtml . "
			<tr class='odd'>
			<td colspan='5' class='col1'>$devicenamet&nbsp&nbsp;&nbsp;$dalias
			</td></tr>
			<tr class=''>
			";

            if ( $devicenumber == 1 ) {

                $detailhtml = $detailhtml
                  . "<td class='col2' rowspan='6'>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;";
            }
            else {
                $detailhtml = $detailhtml
                  . "<td rowspan='6' class='col2'>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;";
            }
            if ( $devicenamet ne 'FreeCmd' ) {
                $detailhtml = $detailhtml . "</td>
			<td nowrap class='col2' style='text-align: left;'>&nbsp;<br>MSwitch on cmd: 
			Set <select id='"
                  . $_
                  . "_on' name='cmdon"
                  . $_
                  . "' onchange=\"javascript: activate(document.getElementById('"
                  . $_
                  . "_on').value,'"
                  . $_
                  . "_on_sel','"
                  . $cmdsatz{$devicenamet}
                  . "','cmdonopt"
                  . $_
                  . "1')\" >
			<option value='no_action'>no_action</option>";
                $detailhtml = $detailhtml . $option1html;
                $detailhtml = $detailhtml . "
			</select>
			<td nowrap id='" . $_ . "_on_sel'>&nbsp;</td>
			<td nowrap>
			</td>
			<td  class='col2' style=\"width: 100%\">&nbsp;<br><input type='$hidden' id='cmdseton"
                  . $_
                  . "' name='cmdseton"
                  . $_
                  . "' size='20'  value ='"
                  . $cmdsatz{$devicenamet} . "'>
			<input type='$hidden' id='cmdonopt"
                  . $_
                  . "1' name='cmdonopt"
                  . $_
                  . "' size='20'  value ='"
                  . $savedetails{ $aktdevice . '_onarg' }
                  . "'>&nbsp;&nbsp;
			";
            }
            else {

                $detailhtml = $detailhtml . "</td>
			<td  class='col2' nowrap style='text-align: left;'>&nbsp;<br>MSwitch on cmd: 
			<input type='' id='cmdonopt"
                  . $_
                  . "1' name='cmdonopt"
                  . $_
                  . "' size='40'  value ='"
                  . $savedetails{ $aktdevice . '_onarg' }
                  . "'&nbsp;&nbsp: onClick=\"javascript:bigwindow(this.id);\">
			&nbsp;<br><input type='$hidden' id='"
                  . $_ . "_on' name='cmdon" . $_ . "' size='20'  value ='cmd'>
			<td  class='col2' nowrap id='" . $_ . "_on_sel'>&nbsp;</td>
			<td nowrap>
			</td>
			<td  class='col2' style=\"width: 100%\">&nbsp;<br><input type='$hidden' id='cmdseton"
                  . $_ . "' name='cmdseton" . $_ . "' size='10'  value ='cmd'>
			";
            }

            if ( AttrVal( $Name, 'MSwitch_Help', "0" ) eq '1' ) {
                $detailhtml = $detailhtml
                  . "<input name='info' type='button' value='?' onclick=\"javascript: info('onoff')\">";
            }
            $detailhtml = $detailhtml . "
		</td></td>
		</tr>
		";

            # block off #$devicename
            if ( $devicenamet ne 'FreeCmd' ) {
                $detailhtml = $detailhtml . "		
			<tr class='even'>
			<td  class='col2' nowrap style='text-align: left;'>MSwitch off cmd:
			Set <select id='"
                  . $_
                  . "_off' name='cmdoff"
                  . $_
                  . "' onchange=\"javascript: activate(document.getElementById('"
                  . $_
                  . "_off').value,'"
                  . $_
                  . "_off_sel','"
                  . $cmdsatz{$devicenamet}
                  . "','cmdoffopt"
                  . $_
                  . "1')\" >
			<option value='no_action'>no_action</option>";
                $detailhtml = $detailhtml
                  . $option2html;    #achtung tausch $_ devicenamet oben unten
                $detailhtml = $detailhtml . "
			</select>
			</td>
			<td  class='col2' nowrap id='" . $_ . "_off_sel' >&nbsp;</td>
			<td>
			</td>
			<td  class='col2' nowrap>
			<input type='$hidden' id='cmdsetoff"
                  . $_
                  . "' name='cmdsetoff"
                  . $_
                  . "' size='20'  value ='"
                  . $cmdsatz{$devicenamet} . "'>
			<input type='$hidden'   id='cmdoffopt"
                  . $_
                  . "1' name='cmdoffopt"
                  . $_
                  . "' size='20' value ='"
                  . $savedetails{ $aktdevice . '_offarg' } . "'>
			&nbsp;&nbsp;&nbsp;";
            }
            else {
                $detailhtml = $detailhtml . "		
			<tr class='even'>
			<td  class='col2' nowrap style='text-align: left;'>MSwitch off cmd:
			<input type=''   id='cmdoffopt"
                  . $_
                  . "1' name='cmdoffopt"
                  . $_
                  . "' size='40' value ='"
                  . $savedetails{ $aktdevice . '_offarg' }
                  . "'  onClick=\"javascript:bigwindow(this.id);\">
			&nbsp;&nbsp;&nbsp;
			<input type='$hidden' id='"
                  . $_ . "_off' name='cmdoff" . $_ . "' size='20'  value ='cmd'>
			</td>
			<td  class='col2' nowrap id='" . $_ . "_off_sel' >&nbsp;</td>
			<td>
			</td>
			<td  class='col2' nowrap>
			<input type='$hidden' id='cmdsetoff"
                  . $_
                  . "' name='cmdsetoff"
                  . $_
                  . "' size='20'  value ='cmd'>";
            }
            if ( AttrVal( $Name, 'MSwitch_Help', "0" ) eq '1' ) {
                $detailhtml = $detailhtml
                  . "<input name='info' type='button' value='?' onclick=\"javascript: info('onoff')\">";
            }
            $detailhtml = $detailhtml . "</td>
		</tr>
		";
            $detailhtml = $detailhtml . "	
		<tr class='even'>
		<td  class='col2' colspan='4' nowrap style='text-align: left;'>
		on condition: <input type='text' id='conditionon"
              . $_
              . "' name='conditionon"
              . $_
              . "' size='55' value ='"
              . $savedetails{ $aktdevice . '_conditionon' }
              . "' onClick=\"javascript:bigwindow(this.id);\">&nbsp;&nbsp;&nbsp;";

            if ( AttrVal( $Name, 'MSwitch_Debug', "0" ) eq '1' ) {
                $detailhtml =
                    $detailhtml
                  . "<input name='info' type='button' value='check condition' onclick=\"javascript: checkcondition('conditionon"
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

            #alltriggers
            if ( AttrVal( $Name, 'MSwitch_Help', "0" ) eq '1' ) {
                $detailhtml = $detailhtml
                  . "<input name='info' type='button' value='?' onclick=\"javascript: info('condition')\">";
            }
            $detailhtml = $detailhtml . "</td>
			
			
		</tr>
		<tr class='even'>
		<td  class='col2' colspan='4' nowrap style='text-align: left;'>
		off condition: <input type='text' id='conditionoff"
              . $_
              . "' name='conditionoff"
              . $_
              . "' size='55' value ='"
              . $savedetails{ $aktdevice . '_conditionoff' }
              . "' onClick=\"javascript:bigwindow(this.id);\">&nbsp;&nbsp;&nbsp;";

            if ( AttrVal( $Name, 'MSwitch_Debug', "0" ) eq '1' ) {
                $detailhtml =
                    $detailhtml
                  . "<input name='info' type='button' value='check condition' onclick=\"javascript: checkcondition('conditionoff"
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
            #### zeitrechner
            my $delaym = 0;
            my $delays = 0;
            my $delayh = 0;
            my $timestroff;
            my $testtimestroff = $savedetails{ $aktdevice . '_timeoff' };
            $testtimestroff =~ s/[A-Za-z0-9#\.\-_]//g;
            if ( $testtimestroff eq "[:]" ) {
                $timestroff = $savedetails{ $aktdevice . '_timeoff' }; #sekunden
            }
            else {
                $timestroff = $savedetails{ $aktdevice . '_timeoff' }; #sekunden
                $delaym     = int $timestroff / 60;
                $delays     = $timestroff - ( $delaym * 60 );
                $delayh     = int $delaym / 60;
                $delaym     = $delaym - ( $delayh * 60 );
                $timestroff =
                  sprintf( "%02d:%02d:%02d", $delayh, $delaym, $delays );
            }
            my $timestron;
            my $testtimestron = $savedetails{ $aktdevice . '_timeon' };
            $testtimestron =~ s/[A-Za-z0-9#\.\-_]//g;
            if ( $testtimestron eq "[:]" ) {
                $timestron = $savedetails{ $aktdevice . '_timeon' };   #sekunden
            }
            else {
                $timestron = $savedetails{ $aktdevice . '_timeon' };   #sekunden
                $delaym    = int $timestron / 60;
                $delays    = $timestron - ( $delaym * 60 );
                $delayh    = int $delaym / 60;
                $delaym    = $delaym - ( $delayh * 60 );
                $timestron =
                  sprintf( "%02d:%02d:%02d", $delayh, $delaym, $delays );
            }

            if ( AttrVal( $Name, 'MSwitch_Help', "0" ) eq '1' ) {
                $detailhtml = $detailhtml
                  . "<input name='info' type='button' value='?' onclick=\"javascript: info('condition')\">";
            }

            #my $testkey =$savedetails{ $aktdevice . '_ondelaylat' };
            $detailhtml = $detailhtml . "</td>
			
		
	
		</tr>
		<tr class='even'>
		<td  class='col2' colspan='4' nowrap style='text-align: left;'>
		on&nbsp;
		<select id = '' name='onatdelay" . $_ . "'>";

            my $se11 = '';
            my $sel2 = '';
            my $sel3 = '';
            my $sel4 = '';

            my $testkey = $aktdevice . '_delaylaton';
            Log3( $Name, 5, "->  $aktdevice   . L:" . __LINE__ );
            Log3( $Name, 5, "-> key $testkey . L:" . __LINE__ );
            Log3( $Name, 5,
                "-> savekey  $savedetails{$testkey} . L:" . __LINE__ );

            if ( $savedetails{ $aktdevice . '_delayaton' } eq "delay1" ) {
                $se11 = 'selected';
            }
            if ( $savedetails{ $aktdevice . '_delayaton' } eq "delay0" ) {
                $sel2 = 'selected';
            }
            if ( $savedetails{ $aktdevice . '_delayaton' } eq "at0" ) {
                $sel4 = 'selected';
            }
            if ( $savedetails{ $aktdevice . '_delayaton' } eq "at1" ) {
                $sel3 = 'selected';
            }

            $detailhtml = $detailhtml
              . "<option $se11 value='delay1'>delay with Cond-check: +</option>";
            $detailhtml = $detailhtml
              . "<option $sel2 value='delay0'>delay without Cond-check: +</option>";
            $detailhtml = $detailhtml
              . "<option $sel3 value='at1'>at without Cond-check:</option>";
            $detailhtml = $detailhtml
              . "<option $sel4 value='at0'>at with Cond-check:</option>";

            $detailhtml = $detailhtml . "</select>
		
		
		
		<input type='text' id='timeseton"
              . $_
              . "' name='timeseton"
              . $_
              . "' size='10' value ='"
              . $timestron
              . "'> (hh:mm:ss)&nbsp;&nbsp;&nbsp;
		off&nbsp;
		<select id = '' name='offatdelay" . $_ . "'>";

            $se11 = '';
            $sel2 = '';
            $sel3 = '';
            $sel4 = '';

            $testkey = $aktdevice . '_delaylatoff';
            Log3( $Name, 5, "->  $aktdevice   . L:" . __LINE__ );
            Log3( $Name, 5, "-> key $testkey . L:" . __LINE__ );
            Log3( $Name, 5,
                "-> savekey  $savedetails{$testkey} . L:" . __LINE__ );

            if ( $savedetails{ $aktdevice . '_delayatoff' } eq "delay1" ) {
                $se11 = 'selected';
            }
            if ( $savedetails{ $aktdevice . '_delayatoff' } eq "delay0" ) {
                $sel2 = 'selected';
            }
            if ( $savedetails{ $aktdevice . '_delayatoff' } eq "at0" ) {
                $sel4 = 'selected';
            }
            if ( $savedetails{ $aktdevice . '_delayatoff' } eq "at1" ) {
                $sel3 = 'selected';
            }

            $detailhtml = $detailhtml
              . "<option $se11 value='delay1'>delay with Cond-check: +</option>";
            $detailhtml = $detailhtml
              . "<option $sel2 value='delay0'>delay without Cond-check: +</option>";
            $detailhtml = $detailhtml
              . "<option $sel3 value='at1'>at without Cond-check:</option>";
            $detailhtml = $detailhtml
              . "<option $sel4 value='at0'>at with Cond-check:</option>";
            $detailhtml = $detailhtml . "</select>
		
		<input type='text' id='timesetoff"
              . $_
              . "' name='timesetoff"
              . $_
              . "' size='10' value ='"
              . $timestroff
              . "'> (hh:mm:ss)&nbsp;&nbsp;&nbsp;";
            if ( AttrVal( $Name, 'MSwitch_Help', "0" ) eq '1' ) {
                $detailhtml = $detailhtml
                  . "<input name='info' type='button' value='?' onclick=\"javascript: info('timer')\">";
            }
            $detailhtml = $detailhtml . "</td>	
			
		</tr>";
##########

# if ($devicenumber == 1)
# {
# $detailhtml=$detailhtml."<tr class='even'>
# <td colspan='4'>
# <input $selectedcheck1 name='cmdplay".$_."' type='checkbox' disabled >
# Playback events
# <input $selectedcheck2 name='cmdrec".$_."' type='checkbox' disabled>
# Record events
# <input type='button' id='aw_showevent' value='edit event file' disabled/>&nbsp;&nbsp;&nbsp;";
# if (AttrVal($Name,'MSwitch_Help',"0") eq '1'){$detailhtml=$detailhtml."<input name='info' type='button' value='?' onclick=\"javascript: info('playback')\">";}
# $detailhtml=$detailhtml."</td>
# </tr>";
# }

            # #
            #
            #
            #
            #
            #

            $detailhtml = $detailhtml . "<tr class='even'>
		<td  class='col2' colspan='4' style='text-align: left;'>";
            if ( $devicenumber == 1 ) {
                $detailhtml = $detailhtml
                  . "<input name='info' type='button' value='add action for $devicenamet' onclick=\"javascript: addevice('$devicenamet')\">";
            }
            $detailhtml = $detailhtml
              . "<input name='info' type='button' value='delete this action for $devicenamet' onclick=\"javascript: deletedevice('$_')\">";
            $detailhtml = $detailhtml . "<br>&nbsp;</td>
		</tr>
		";

            #middle
####################
            # javazeile für übergabe erzeugen
            $javaform = $javaform . "
devices += \$(\"[name=cmdon$_]\").val()+'|';
devices += \$(\"[name=cmdoff$_]\").val()+'|';
change = \$(\"[name=cmdonopt$_]\").val();
change1 = change.replace(/ /g,'~');
change1 =  encodeURIComponent(change1);
devices += change1+'|';;
change = \$(\"[name=cmdoffopt$_]\").val();
change1 = change.replace(/ /g,'~');
change1 =  encodeURIComponent(change1);
devices += change1+'|';;



devices += \$(\"[name=onatdelay$_]\").val();
devices += '|';
devices += \$(\"[name=offatdelay$_]\").val();
devices += '|';





delay1 = \$(\"[name=timesetoff$_]\").val();
test = delay1.indexOf('[') ;
if (test == 0)
{
delay1 = delay1.replace(/:/g,'(:)');
}
else{
delay1 = delay1.replace(/:/g,'');
}
devices += delay1+'|';
delay2 = \$(\"[name=timeseton$_]\").val();
test = delay2.indexOf('[') ;
if (test == 0)
{
delay2 = delay2.replace(/:/g,'(:)');
}
else{
delay2 = delay2.replace(/:/g,'');
}
devices += delay2+'|';
devices1 = \$(\"[name=conditionon$_]\").val();
devices2 = \$(\"[name=conditionoff$_]\").val();
devices1 = devices1.replace(/\\|/g,'(DAYS)');
devices2 = devices2.replace(/\\|/g,'(DAYS)');
devices3 = devices1.replace(/:/g,'(:)');
devices4 = devices2.replace(/:/g,'(:)');
devices5 = devices3.replace(/ /g,'~');
devices6 = devices4.replace(/ /g,'~');
devices += devices5+'|';
devices += devices6;
devices += ',';
";
        }
####################
        $detailhtml = $detailhtml;
        $detailhtml = $detailhtml . "
		<tr class='even'>
		<td colspan='5'><left>
		<input type='button' id='aw_det' value='modify Actions' >
		</td>
		</tr>
		</table>
		";    #end
    }
####################
    my $triggercondition = ReadingsVal( $Name, '.Trigger_condition', '' );
    $triggercondition =~ s/\./:/g;
    $triggercondition =~ s/~/ /g;
    my @triggertimes = split( /~/, ReadingsVal( $Name, '.Trigger_time', '' ) );
    my $condition   = ReadingsVal( $Name, '.Trigger_time', '' );
    my $lenght      = length($condition);
    my $timeon      = '';
    my $timeoff     = '';
    my $timeononly  = '';
    my $timeoffonly = '';

    if ( $lenght != 0 ) {
        $timeon      = substr( $triggertimes[0], 2 );
        $timeoff     = substr( $triggertimes[1], 3 );
        $timeononly  = substr( $triggertimes[2], 6 );
        $timeoffonly = substr( $triggertimes[3], 7 );
    }
    my $ret .=
"<p id=\"triggerdevice\"><table class='block wide' id='MSwitchWebTR' nm='$hash->{NAME}'>
	<tr class=\"even\">
	<td colspan=\"3\" id =\"savetrigger\">trigger device/time:&nbsp;&nbsp;&nbsp;";
    if ( AttrVal( $Name, 'MSwitch_Help', "0" ) eq '1' ) {
        $ret = $ret
          . "<input name='info' type='button' value='?' onclick=\"javascript: info('trigger')\">";
    }
    $ret = $ret . "</td>
	</tr>
	<tr class=\"even\">
	<td></td>
	<td></td>
	<td></td>
	</tr>
	<tr class=\"even\">
	<td>Trigger device: </td>
	<td  colspan =\"2\">
	<select id =\"trigdev\" name=\"trigdev\">" . $triggerdevices . "</select>
	</td>
	</tr>";
    my $visible = 'visible';
    if ( $globalon ne 'on' ) {
        $visible = 'collapse';
    }

    $ret =
        $ret
      . "<tr class=\"even\"  id='triggerwhitelist' style=\"visibility:"
      . $visible . ";\" >
	<td nowrap>Trigger Device Global Whitelist: 
	</td>
	<td></td>
	<td><input type='text' id ='triggerwhite' name='triggerwhitelist' size='30' value ='"
      . ReadingsVal( $Name, '.Trigger_Whitelist', '' )
      . "' onClick=\"javascript:bigwindow(this.id);\" >";
    if ( AttrVal( $Name, 'MSwitch_Help', "0" ) eq '1' ) {
        $ret = $ret
          . "&nbsp;<input name='info' type='button' value='?' onclick=\"javascript: info('whitelist')\">";
    }
    $ret = $ret . "</td>
	</tr>
	<tr class=\"even\">
	<td>Trigger condition: </td>
	<td></td>
	<td><input type='text' id='triggercondition' name='triggercondition' size='30' value ='"
      . $triggercondition . "' onClick=\"javascript:bigwindow(this.id);\" >";

    if ( AttrVal( $Name, 'MSwitch_Debug', "0" ) eq '1' ) {
        $ret = $ret
          . " <input name='info' type='button' value='check condition' onclick=\"javascript: checkcondition('triggercondition',document.querySelector('#triggercondition').value)\">";
    }

    if ( AttrVal( $Name, 'MSwitch_Help', "0" ) eq '1' ) {
        $ret = $ret
          . "&nbsp;<input name='info' type='button' value='?' onclick=\"javascript: info('triggercondition')\">";
    }

    $ret = $ret . "</td>
	</tr>
	<tr class=\"even\">
	<td>Trigger time: </td>
	<td></td>
	<td>
	</td>
	</tr>

	<tr class=\"even\">
	<td></td>
	<td>switch MSwitch on + execute 'on' commands at :</td>
	<td><input type='text' id='timeon' name='timeon' size='60'  value ='"
      . $timeon . "'></td>
	</tr>
	<tr class=\"even\">
	<td></td>
	<td>switch MSwitch off + execute 'off' commands at :</td>
	<td><input type='text' id='timeoff' name='timeoff' size='60'  value ='"
      . $timeoff . "'></td>
	</tr>
	<tr class=\"even\">
	<td></td>
	<td>execute 'on' commands only at :</td>
	<td><input type='text' id='timeononly' name='timeononly' size='60'  value ='"
      . $timeononly . "'></td>
	</tr>
	<tr class=\"even\">
	<td></td>
	<td>execute 'off' commands only at :</td>
	<td><input type='text' id='timeoffonly' name='timeoffonly' size='60'  value ='"
      . $timeoffonly . "'></td>
	</tr>
	<tr class=\"even\">
	<td colspan=\"3\"><left>
	<input type=\"button\" id=\"aw_trig\" value=\"modify Trigger Device\"$disable>
	</td>
	</tr>
	</table></p>";
####################
    # triggerdetails
    my $selectedcheck3 = "";
    my $testlog = ReadingsVal( $Name, 'Trigger_log', 'on' );
    if ( $testlog eq 'on' ) {
        $selectedcheck3 = "checked=\"checked\"";
    }
    if ( ReadingsVal( $Name, 'Trigger_device', 'no_trigger' ) ne 'no_trigger' )
    {
        $ret .=
          "<table class='block wide' id='MSwitchWebTRDT' nm='$hash->{NAME}'>
		  <tr class=\"even\">
				<td id =\"triggerdetails\">trigger details :</td>
				<td></td>
				<td></td>
			</tr>
			 <tr class=\"even\">
				<td></td>
				<td></td>
				<td></td>
			</tr>
			<tr class=\"even\">
				<td>switch " . $Name . " on + execute 'on' commands</td>
				<td>
				Trigger " . $Triggerdevice . " :
				</td>
				<td>
					<select id = \"trigon\" name=\"trigon\">" . $optionon . "</select>
				</td>
			</tr>
			<tr class=\"even\">
				<td>switch " . $Name . " off + execute 'off' commands</td>
				<td>
				Trigger " . $Triggerdevice . " :
				</td>
				<td>
					<select id = \"trigoff\" name=\"trigoff\">" . $optionoff . "</select>
				</td>
			</tr>
			<tr class=\"even\">
			<td colspan=\"3\" >&nbsp</td>
			</tr>
			<tr class=\"even\">
				<td>execute 'on' commands only</td>
				<td>
				Trigger " . $Triggerdevice . " :
				</td>
				<td>
					<select id = \"trigcmdon\" name=\"trigcmdon\">" . $optioncmdon . "</select>
				</td>
			</tr>
			<tr class=\"even\">
				<td>execute 'off' commands only</td>
				<td>
				Trigger " . $Triggerdevice . " :
				</td>
				<td>
					<select id = \"trigcmdoff\" name=\"trigcmdoff\">"
          . $optioncmdoff . "</select>
				</td>
			</tr>
			<tr class=\"even\">
			<td colspan=\"1\"><left>
			Save incomming events : 
			<input $selectedcheck3 name=\"aw_save\" type=\"checkbox\" $disable>
			</td>
			<td><left>
			<input type='text' id='add_event' name='add_event' size='40'  value =''>
			<input type=\"button\" id=\"aw_addevent\" value=\"add event\"$disable>";

        if ( AttrVal( $Name, 'MSwitch_Help', "0" ) eq '1' ) {
            $ret = $ret
              . "&nbsp;<input name='info' type='button' value='?' onclick=\"javascript: info('addevent')\">";
        }

        $ret .= "</td>
			<td><left>
			</td>
			</tr>
			<tr class=\"even\">
			<td colspan=\"2\"><left>
			<input type=\"button\" id=\"aw_md\" value=\"modify Trigger\"$disable>
			<input type=\"button\" id=\"aw_md1\" value=\"apply filter to saved events\" $disable>
			<input type=\"button\" id=\"aw_md2\" value=\"clear saved events\"$disable>&nbsp;&nbsp;&nbsp;
			</td>
			<td><left>";

        if ( AttrVal( $Name, 'MSwitch_Debug', "0" ) eq '1'
            && $optiongeneral ne '' )
        {
            $ret .=
                "<select id = \"eventtest\" name=\"eventtest\">"
              . $optiongeneral
              . "</select><input type=\"button\" id=\"aw_md2\" value=\"test event\"$disable onclick=\"javascript: checkevent(document.querySelector('#eventtest').value)\">";
        }
        $ret .= "</td>
			</tr>	
			</table></p>
			";
    }
    else {
        $ret .= "<p id=\"MSwitchWebTRDT\"></p>";
    }

    # affected devices
    $ret .= "<table class='block wide' id='MSwitchWebAF' nm='$hash->{NAME}'>
		<tr class=\"even\">
			<td>affected devices :</td>
			<td></td>
			<td></td>
		</tr>
		<tr class=\"even\">
			<td>
			</td>
			<td>
			</td>
			<td></td>
		</tr>
		<tr class=\"even\">
			<td>multiple selection with ctrl + mousebutton</td>
			<td><p id =\"textfie\">
			<select id =\"devices\" multiple=\"multiple\" name=\"affected_devices\" size=\"6\" disabled >";
    $ret .= $deviceoption;
    $ret .= "</select>
	</p>
		</td>
			<td><center>
			<input type=\"button\" id=\"aw_great\"
			value=\"edit list\" onClick=\"javascript:deviceselect();\">
			<br>
			<input onChange=\"javascript:switchlock();\" checked=\"checked\" id=\"lockedit\" name=\"lockedit\" type=\"checkbox\" value=\"lockedit\" /> quickedit locked
			<br>
			<br>
			</td>
		</tr>
		<tr class=\"even\">
			<td><leftt>
			<input type=\"button\" id=\"aw_dev\" value=\"modify Devices\"$disable>
			</td>
			<td>&nbsp;</td>
			<td>&nbsp;</td>
		</tr>
	</table>";
####################
    #javascript$jsvarset
    my $triggerdevicehtml = $Triggerdevice;
    $triggerdevicehtml =~ s/\(//g;
    $triggerdevicehtml =~ s/\)//g;

    $j1 = "
<script type=\"text/javascript\">
{


 ";

    if ( AttrVal( $Name, 'MSwitch_Lock_Quickedit', "1" ) eq '0' ) {
        $j1 .= "
\$(\"#devices\").prop(\"disabled\", false);
document.getElementById('aw_great').value='schow greater list';
document.getElementById('lockedit').checked = false  ;	
";
    }

    if ( $affecteddevices[0] ne 'no_device' ) {
        $j1 .= "	
var affected = document.getElementById('affected').value 
var devices = affected.split(\",\");
var i;
var len = devices.length;
for (i=0; i<len; i++)
{
testname = devices[i].split(\"-\");
if (testname[0] == \"FreeCmd\") {
continue;
}
sel = devices[i] + '_on';
sel1 = devices[i] + '_on_sel';
sel2 = 'cmdonopt' +  devices[i] + '1';
sel3 = 'cmdseton' +  devices[i];
aktcmd = document.getElementById(sel).value;
aktset = document.getElementById(sel3).value;
activate(document.getElementById(sel).value,sel1,aktset,sel2);
sel = devices[i] + '_off';
sel1 = devices[i] + '_off_sel';
sel2 = 'cmdoffopt' +  devices[i] + '1';
sel3 = 'cmdsetoff' +  devices[i];
aktcmd = document.getElementById(sel).value;
aktset = document.getElementById(sel3).value;
activate(document.getElementById(sel).value,sel1,aktset,sel2); 
}
;"
    }

    $j1 .= "
var triggerdetails = document.getElementById('MSwitchWebTRDT').innerHTML;
var saveddevice = '" . $triggerdevicehtml . "';
var sel = document.getElementById('trigdev');
sel.onchange = function() 
{
trigdev = this.value;
if (trigdev != '";
    $j1 .= $triggerdevicehtml;
    $j1 .= "')
{
document.getElementById('savetrigger').innerHTML = '<font color=#FF0000>trigger device : unsaved!</font> ';	 
document.getElementById('MSwitchWebTRDT').innerHTML = '';
}
else
{	
document.getElementById('savetrigger').innerHTML = 'trigger device :';
document.getElementById('MSwitchWebTRDT').innerHTML = triggerdetails;	
}
if (trigdev == 'all_events')
{
document.getElementById(\"triggerwhitelist\").style.visibility = \"visible\"; 
}
else
{
document.getElementById(\"triggerwhitelist\").style.visibility = \"collapse\"; 
}
}
";

    $j1 .= "

function saveconfig(conf){

//alert(conf);

conf = conf.replace(/ /g,'[s]');
conf = conf.replace(/\\n/g,'[nl]');
var nm = \$(t).attr(\"nm\");
var  def = nm+\" saveconfig \"+encodeURIComponent(conf);
location = location.pathname+\"?detail=" . $Name . "&cmd=set \"+addcsrf(def);

//var nm = \$(t).attr(\"nm\");
//var  def = nm+\" del_device \"+device;
//location = location.pathname+\"?detail=" . $Name . "&cmd=set \"+addcsrf(def);


}




function checkcondition(condition,event){		
var selected =document.getElementById(condition).value;
if (selected == '')
{
var textfinal = \"<div style ='font-size: medium;'>Es ist keine Bedingung definiert, das Kommando wird immer ausgeführt.</div>\";
FW_okDialog(textfinal);
return;
}
selected = selected.replace(/ /g,'~');
selected = selected.replace(/\\|/g,'(DAYS)');
event = event.replace(/ /g,'~');
cmd ='get " . $Name . " checkcondition '+selected+'|'+event;
FW_cmd(FW_root+'?cmd='+encodeURIComponent(cmd)+'&XHR=1', function(resp){FW_okDialog(resp);});
}

function checkevent(event){	
event = event.replace(/ /g,'~');
cmd ='get " . $Name . " checkevent '+event;
FW_cmd(FW_root+'?cmd='+encodeURIComponent(cmd)+'&XHR=1');
}

function info(from){
if (from == 'timer'){
text = 'Hier kann entweder eine direkte Angabe einer Verzögerungszeit (delay with Cond_check) angegeben werden, oder es kann eine Ausführungszeit (at with Cond-check) für den Befehl angegeben werden<br> Bei der Angabe einer Ausführungszeit wird der Schaltbefehl beim nächsten erreichen der angegebenen Zeit ausgeführt. Ist die Zeit am aktuellen Tag bereits überschritten , wird der angegebene Zeitpunkt am Folgetag gesetzt.<br>Die Auswahl \"with Conf-check\" oder \"without Conf-check\" legt fest, ob unmittelbar vor Befehlsausführung nochmals die Condition für den Befehl geprüft wird oder nicht.<br><brAlternativ kann hier auch ein Verweis auf ein beliebiges Reading eines Devices erfolgen, das entsprechenden Wert enthält. Dieser Verweis muss in folgendem Format erfolgen:<br><br>[NAME.reading] des Devices  ->z.B.  [dummy.state]<br>Das Reading muss in folgendem Format vorliegen: hh:mm:ss ';}
				   
if (from == 'trigger'){
text = 'Trigger ist das Gerät, oder die Zeit, auf die das Modul reagiert, um andere devices anzusprechen.<br>Das Gerät kann aus der angebotenen Liste ausgewählt werden, sobald dieses ausgewählt ist werden  weitere Optionen angeboten.<br>Auch Zeitangaben können als Trigger genutzt werden, das Format muss wie folgt lauten:<br><br> [STUNDEN:MINUTEN|TAGE] - Tage werden von 1-7 gezählt, wobei 1 für Montag steht, 7 für Sonntag.<br>Die Variable \$we ist anstatt der Tagesangabe verwendbar<br> [STUNDEN:MINUTEN|\$we] - Schaltvorgang nur an Wochenenden.<br>[STUNDEN:MINUTEN|!\$we] - Schaltvorgang nur an Werktagen.<br>Mehrere Zeitvorgaben können aneinandergereiht werden.<br><br>[17:00|1][18:30|23] würde den Trigger Montags um 17 Uhr auslösen und Dienstags,Mittwochs um 18 Uhr 30.<br><br>Es ist eine gleichzeitige Nutzung für Trigger durch Zeitangaben und Trigger durch Deviceevents möglich.<br>Sunset - Zeitangaben können mit folgender Sytax eingebunden werden: z.B [{sunset()}] , [{sunrise(+1800)}].';}
				   
if (from == 'triggercondition'){
text = 'Hier kann die Angabe von Bedingungen erfolgen, die zusätzlich zu dem triggernden Device erfuellt sein müssen.<br> Diese Bedingunge sind eng an DOIF- Bedingungen angelehnt .<br>Zeitabhängigkeit: [19.10-23:00] - Trigger des Devices erfolgt nur in angegebenem Zeitraum<br>Readingabhängige Trigger [Devicename:Reading] =/>/< X oder [Devicename:Reading] eq \"x\" - Trigger des Devicec erfolgt nur bei erfüllter Bedingung.<br>Achtung ! Bei der Abfrage von Readings nach Strings ( on,off,etc. ) ist statt \"=\" \"eq\" zu nutzen und der String muss in \"\" gesetzt werden!<br>Die Kombination mehrerer Bedingungen und Zeiten ist durch AND oder OR möglich.<br>[19.10-23:00] AND [Devicename:Reading] = 10 - beide Bedingungen müssen erfüllt sein<br>[19.10-23:00] OR [Devicename:Reading] = 10 - eine der Bedingungen muss erfüllt sein.<br>Es ist auf korrekte Eingabe der Leerzeichen zu achten.<br><br>sunset - Bedingungen werden mit zusätzlichen {} eingefügt z.B. : [{ sunset() }-23:00].<br><br>Variable \$we:<br>Die globlae Variable \$we ist nutzbar und muss in {} gesetzt werden .<br>{ !\$we } löst den Schaltvorgang nur Werktagen an aus<br>{ \$we } löst den Schaltvorgang nur an Wochenenden, Feiertagen aus<br><br>Soll nur an bestimmten Wochentagen geschaltet werden, muss eine Zeitangsbe gemacht werden und durch z.B. |135 ergänzt werden.<br>[10:00-11:00|13] würde den Schaltvorgang z.B nur Montag und Mitwoch zwischen 10 uhr und 11 uhr auslösen. Hierbei zählen die Wochentage von 1-7 für Montag-Sonntag.<br>Achtung: Bei Anwendung der geschweiften Klammern zur einletung eines Perlasdrucks ist unbedingt auf die Leerzeichen hinter und vor der Klammer zu achten !<br> Überschreitet die Zeitangabe die Tagesgrenze (24.00 Uhr ), so gelten die angegebenen Tage noch bis zum ende der angegebenen Schaltzeit,<br> d.H. es würde auch am Mitwoch noch der schaltvorgang erfolgen, obwohl als Tagesvorgabe Dienstag gesetzt wurde.<br><br>Wird in diesem Feld keine Angabe gemacht , so erfolgt der Schaltvorgang nur durch das triggernde Device ohne weitere Bedingungen.<br><br>Achtung: Conditions gelten nur für auslösende Trigger eines Devices und habe keinen Einfluss auf zeitgesteuerte Auslöser.';}
				   
if (from == 'whitelist'){
text = 'Bei der Auswahl \\\'GLOBAL\\\' als Triggerevent werde alle von Fhem erzeugten Events an dieses Device weitergeleitet. Dieses kann eine erhöhte Systemlast erzeugen.<br>In dem Feld \\\'Trigger Device Global Whitelist:\\\' kann dieses eingeschränkt werden , indem Devices oder Module benannt werden , deren Events Berücksichtigt werden. Sobald hier ein Eintrag erfolgt , werden nur noch Diese berücksichtigt , gibt es keinen Eintrag , werden alle berücksichtigt ( Whitelist ).<br> Format: Die einzelnen Angaben müssen durch Komma getrennt werden .<br><br>Mögliche Angaben :<br>Modultypen: TYPE=CUL_HM<br>Devicenamen: NAME<br><br>';}
				   
if (from == 'addevent'){
text = 'Hier können manuell Events zugefügt werden , die in den Auswahllisten verfügbar sein sollen und auf die das Modul reagiert.<br>Grundsätzlich ist zu unterscheiden , ob das Device im Normal-, oder Globalmode betrieben wird<br>Im Normalmode bestehen die Events aus 2 Teilen , dem Reading und dem Wert \"state:on\"<br>Wenn sich das Device im GLOBAL Mode befindet müssen die Events aus 3 Teilen bestehen , dem Devicename, dem Reading und dem Wert \"device:state:on\".<br>Wird hier nur ein \"*\" angegeben , reagiert der entsprechende Zweig auf alle eingehenden Events.<br>Weitherhin sind folgende Syntaxmöglichkeiten vorgesehen :<br> device:state:*, device:*:*, *:state:* , etc.<br>Der Wert kann mehrere Auswahlmöglichkeiten haben , durch folgende Syntax: \"device:state:(on/off)\". In diesem Fal reagiert der Zweig sowohl auf den Wert on, als auch auf off.<br><br>Es können mehrere Evebts gleichzeitig angelegt werden . Diese sind durch Komma zu trennen .';}
				   
if (from == 'condition'){
text = 'Hier kann die Angabe von Bedingungen erfolgen, die erfüllt sein müssen um den Schaltbefehl auszuführen.<br>Diese Bedingunge sind eng an DOIF- Bedingungen angelehnt.<br><br>Zeitabhängiges schalten: [19.10-23:00] - Schaltbefehl erfolgt nur in angegebenem Zeitraum<br>Readingabhängiges schalten [Devicename:Reading] =/>/< X oder [Devicename:Reading] eq \"x\" - Schaltbefehl erfolgt nur bei erfüllter Bedingung.<br>Achtung! Bei der Abfrage von Readings nach Strings ( on,off,etc. ) ist statt \"=\" \"eq\" zu nutzen und der String muss in \"x\" gesetzt werden!<br> Die Kombination mehrerer Bedingungen und Zeiten ist durch AND oder OR möglich:<br> [19.10-23:00] AND [Devicename:Reading] = 10 - beide Bedingungen müssen erfüllt sein<br>[19.10-23:00] OR [Devicename:Reading] = 10 - eine der Bedingungen muss erfüllt sein.<br>Es ist auf korrekte Eingabe der Leerzeichen zu achten.<br><br>sunset - Bedingungen werden mit zusätzlichen {} eingefügt z.B. : [{ sunset() }-23:00].<br><br>Variable \$we:<br>Die globlae Variable \$we ist nutzbar und muss {} gesetzt werden .<br>{ !\$we } löst den Schaltvorgang nur Werktagen aus<br>{ \$we } löst den Schaltvorgang nur Wochenenden, Feiertagen aus<br><br>Soll nur an bestimmten Wochentagen geschaltet werden, muss eine Zeitangsbe gemacht werden und durch z.B. |135 ergänzt werden.<br>[10:00-11:00|13] würde den Schaltvorgang z.B nur Montag und Mitwoch zwischen 10 uhr und 11 uhr auslösen. Hierbei zählen die Wochentage von 1-7 für Montag-Sonntag.<br>Achtung: Bei Anwendung der geschweiften Klammern zur einletung eines Perlasdrucks ist unbedingt auf die Leerzeichen hinter und vor der Klammer zu achten !<br>Überschreitet die Zeitangabe die Tagesgrenze (24.00 Uhr ), so gelten die angegebenen Tage noch bis zum ende der angegebenen Schaltzeit , d.H. es würde auch am Mitwoch noch der schaltvorgang erfolgen, obwohl als Tagesvorgabe Dienstag gesetzt wurde.<br><br>\$EVENT Variable: Die Variable EVENT enthält den auslösenden Trigger, d.H. es kann eine Reaktion in direkter Abhängigkeit zum auslösenden Trigger erfolgen.<br>[\$EVENT] eq \"state:on\" würde den Kommandozweig nur dann ausführen, wenn der auslösende Trigger \"state:on\" war.<br>Wichtig ist dieses, wenn bei den Triggerdetails nicht schon auf ein bestimmtes Event getriggert wird, sondern hier durch die Nutzung eines wildcards (*) auf alle Events getriggert wird, oder auf alle Events eines Readings z.B. (state:*)<br><br>Bei eingestellter Delayfunktion werden die Bedingungen erst nach Ablauf des Delay geprüft, d.H hiermit sind verzögerte Ein-, und Ausschaltbefehle möglich die z.B Nachlauffunktionen oder verzögerte Einschaltfunktionen ermöglichen, die sich selbst überprüfen. z.B. [wenn Licht im Bad an -> schalte Lüfter 2 Min später an -> nur wenn Licht im Bad noch an ist]';}
				   
if (from == 'onoff'){
text = 'Einstellung des auzuführenden Kommandos bei entsprechendem getriggerten Event.<br>Bei angebotenen Zusatzfeldern kann ein Verweis auf ein Reading eines anderen Devices gesetzt werden mit [Device:Reading].<br>\$NAME wird ersetzt durch den Namen des triggernden Devices.';}
				   
if (from == 'playback'){
text = 'Diese Funktion ist noch nicht verfügbar ';}

var textfinal =\"<div style ='font-size: medium;'>\"+ text +\"</div>\";
FW_okDialog(textfinal);
return;
}
 
function aktvalue(target,cmd){
document.getElementById(target).value = cmd; 
return;
}

function noarg(target,copytofield){
document.getElementById(copytofield).value = '';
document.getElementById(target).innerHTML = '';
return;
}
				   
function noaction(target,copytofield){
document.getElementById(copytofield).value = '';
document.getElementById(target).innerHTML = '';
return;}

function slider(first,step,last,target,copytofield){
var selected =document.getElementById(copytofield).value;
var selectfield = \"&nbsp;<br><input type='text' id='\" + target +\"_opt' size='3' value='' readonly>&nbsp;&nbsp;&nbsp;\" + first +\"<input type='range' min='\" + first +\"' max='\" + last + \"' value='\" + selected +\"' step='\" + step + \"' onchange=\\\"javascript: showValue(this.value,'\" + copytofield + \"','\" + target + \"')\\\">\" + last  ;
document.getElementById(target).innerHTML = selectfield + '<br>';
var opt = target + '_opt';
document.getElementById(opt).value=selected;
return;
}

function showValue(newValue,copytofield,target){
var opt = target + '_opt';
document.getElementById(opt).value=newValue;
document.getElementById(copytofield).value = newValue;
}

function showtextfield(newValue,copytofield,target){
document.getElementById(copytofield).value = newValue;
}

function textfield(copytofield,target){
//alert(copytofield,target);
var selected =document.getElementById(copytofield).value;
if (copytofield.indexOf('cmdonopt') != -1) {

var selectfield = \"&nbsp;<br><input type='text' size='10' value='\" + selected +\"' onchange=\\\"javascript: showtextfield(this.value,'\" + copytofield + \"','\" + target + \"')\\\">\"  ;
document.getElementById(target).innerHTML = selectfield + '<br>';	
   }
   else{
   var selectfield = \"<input type='text' size='10' value='\" + selected +\"' onchange=\\\"javascript: showtextfield(this.value,'\" + copytofield + \"','\" + target + \"')\\\">\"  ;
document.getElementById(target).innerHTML = selectfield + '<br>';
   
   
   
   }



return;
}

function selectfield(args,target,copytofield){
var cmdsatz = args.split(\",\");
var selectstart = \"<select id=\\\"\" +target +\"1\\\" name=\\\"\" +target +\"1\\\" onchange=\\\"javascript: aktvalue('\" + copytofield + \"',document.getElementById('\" +target +\"1').value)\\\">\"; 
var selectend = '<\\select>';
var option ='<option value=\"noArg\">noArg</option>'; 
var i;
var len = cmdsatz.length;
var selected =document.getElementById(copytofield).value;
for (i=0; i<len; i++){
if (selected == cmdsatz[i]){
option +=  '<option selected value=\"' + cmdsatz[i] + '\">' + cmdsatz[i] + '</option>';
}
else{
option +=  '<option value=\"' + cmdsatz[i] + '\">' + cmdsatz[i] + '</option>';
}
}
var selectfield = selectstart + option + selectend;
document.getElementById(target).innerHTML = selectfield + '<br>';	
return;
}

function activate(state,target,options,copytofield) ////aufruf durch selctfield
{
var ausgabe = target + '<br>' + state + '<br>' + options;
if (state == 'no_action'){noaction(target,copytofield);return}
var optionarray = options.split(\" \");
var werte = new Array();
for (var key in optionarray )
{
var satz = optionarray[key].split(\":\");
werte[satz[0]] = satz[1];
}
var devicecmd = new Array();
if (typeof werte[state] === 'undefined') {werte[state]='textField';}
devicecmd = werte[state].split(\",\");
if (devicecmd[0] == 'noArg'){noarg(target,copytofield);return;}
else if (devicecmd[0] == 'slider'){slider(devicecmd[1],devicecmd[2],devicecmd[3],target,copytofield);return;}
else if (devicecmd[0] == 'undefined'){textfield(copytofield,target);return;}
else if (devicecmd[0] == 'textField'){textfield(copytofield,target);return;}
else if (devicecmd[0] == 'colorpicker'){textfield(copytofield,target);return;}
else if (devicecmd[0] == 'RGB'){textfield(copytofield,target);return;}
else if (devicecmd[0] == 'no_Action'){noaction();return;}
else {selectfield(werte[state],target,copytofield);return;}
return;
}

function addevice(device){
var nm = \$(t).attr(\"nm\");
var  def = nm+\" add_device \"+device;
location = location.pathname+\"?detail=" . $Name . "&cmd=set \"+addcsrf(def);
}

function deletedevice(device){
var nm = \$(t).attr(\"nm\");
var  def = nm+\" del_device \"+device;
location = location.pathname+\"?detail=" . $Name . "&cmd=set \"+addcsrf(def);
}
";

    $j1 .=
"var t=\$(\"#MSwitchWebTR\"), ip=\$(t).attr(\"ip\"), ts=\$(t).attr(\"ts\");
FW_replaceWidget(\"[name=aw_ts]\", \"aw_ts\", [\"time\"], \"12:00\");
\$(\"[name=aw_ts] input[type=text]\").attr(\"id\", \"aw_ts\");
   
// modify trigger aw_save
\$(\"#aw_md\").click(function(){
var nm = \$(t).attr(\"nm\");
trigon = \$(\"[name=trigon]\").val();
trigon = trigon.replace(/ /g,'~');
trigoff = \$(\"[name=trigoff]\").val();
trigoff = trigoff.replace(/ /g,'~');
trigcmdon = \$(\"[name=trigcmdon]\").val();
trigcmdon = trigcmdon.replace(/ /g,'~');
trigcmdoff = \$(\"[name=trigcmdoff]\").val();
trigcmdoff = trigcmdoff.replace(/ /g,'~');
trigsave = \$(\"[name=aw_save]\").prop(\"checked\") ? \"ja\":\"nein\";
trigwhite = \$(\"[name=triggerwhitelist]\").val();
if (trigcmdon == trigon  && trigcmdon != 'no_trigger' && trigon != 'no_trigger'){
FW_okDialog('on triggers for \\'switch Test on + execute on commands\\' and \\'execute on commands only\\' may not be the same !');
return;
} 
if (trigcmdoff == trigoff && trigcmdoff != 'no_trigger' && trigoff != 'no_trigger'){
FW_okDialog('off triggers for \\'switch Test off + execute on commands\\' and \\'execute off commands only\\' may not be the same !');
return;
} 
if (trigon == trigoff && trigon != 'no_trigger'){
FW_okDialog('trigger for \\'switch Test on + execute on commands\\' and \\'switch Test off + execute off commands\\' must not both be \\'*\\'');
return;
} 

var  def = nm+\" trigger \"+trigon+\" \"+trigoff+\" \"+trigsave+\" \"+trigcmdon+\" \"+trigcmdoff+\" \"  ;
location = location.pathname+\"?detail=" . $Name . "&cmd=set \"+addcsrf(def);
});
	
//delete trigger
\$(\"#aw_md2\").click(function(){
var nm = \$(t).attr(\"nm\");
var  def = nm+\" del_trigger \";
location = location.pathname+\"?detail=" . $Name . "&cmd=set \"+addcsrf(def);
});
	
//aplly filter to trigger
\$(\"#aw_md1\").click(function(){
var nm = \$(t).attr(\"nm\");
var  def = nm+\" filter_trigger \";
location = location.pathname+\"?detail=" . $Name . "&cmd=set \"+addcsrf(def);
});

\$(\"#aw_trig\").click(function(){
var nm = \$(t).attr(\"nm\");
trigdev = \$(\"[name=trigdev]\").val();
timeon =  \$(\"[name=timeon]\").val()+':';
timeoff =  \$(\"[name=timeoff]\").val()+':';
timeononly =  \$(\"[name=timeononly]\").val()+':';
timeoffonly =  \$(\"[name=timeoffonly]\").val()+':';
trigdevcond = \$(\"[name=triggercondition]\").val();
trigdevcond = trigdevcond.replace(/:/g,'.');
trigdevcond = trigdevcond.replace(/ /g,'~');
trigdevcond = trigdevcond+':';
timeon = timeon.replace(/ /g, '');
timeoff = timeoff.replace(/ /g, '');
timeoff = timeoff.replace(/ /g, '');
timeoffonly = timeoffonly.replace(/ /g, '');
trigwhite = \$(\"[name=triggerwhitelist]\").val();
var  def = nm+\" set_trigger  \"+trigdev+\" \"+timeon+\" \"+timeoff+\" \"+timeononly+\" \"+timeoffonly+\" \"+trigdevcond+\" \"+trigwhite+\" \" ;
def =  encodeURIComponent(def);
location = location.pathname+\"?detail=" . $Name . "&cmd=set \"+addcsrf(def);
});
	
\$(\"#aw_addevent\").click(function(){
var nm = \$(t).attr(\"nm\");
event = \$(\"[name=add_event]\").val();
event= event.replace(/ /g,'~');
if (event == ''){
alert('no event specified');
return;
}	  
var  def = nm+\" addevent \"+event+\" \";
location = location.pathname+\"?detail=" . $Name . "&cmd=set \"+addcsrf(def);
});
	
\$(\"#aw_dev\").click(function(){
var nm = \$(t).attr(\"nm\");
devices = \$(\"[name=affected_devices]\").val();
var  def = nm+\" devices \"+devices+\" \";
location = location.pathname+\"?detail=" . $Name . "&cmd=set \"+addcsrf(def);
});
	
\$(\"#aw_det\").click(function(){
var nm = \$(t).attr(\"nm\");
devices = '';
$javaform
var  def = nm+\" details \"+devices+\" \";
def =  encodeURIComponent(def);
location = location.pathname+\"?detail=" . $Name . "&cmd=set \"+addcsrf(def);
});
	
function  switchlock(){	
test = document.getElementById('lockedit').checked ;	
if (test){
\$(\"#devices\").prop(\"disabled\", 'disabled');
document.getElementById('aw_great').value='edit list';
}
else{
\$(\"#devices\").prop(\"disabled\", false);
document.getElementById('aw_great').value='schow greater list';
}
}
	
function  deviceselect(){
	sel ='<div style=\"white-space:nowrap;\"><br>';
	var ausw=document.getElementById('devices');
	for (i=0; i<ausw.options.length; i++)
		{
			var pos=ausw.options[i];
			if(pos.selected)
				{
					//targ.options[i].selected = true;
					sel = sel+'<input id =\"Checkbox-'+i+'\" checked=\"checked\" name=\"Checkbox-'+i+'\" type=\"checkbox\" value=\"test\" /> '+pos.value+'<br />';
				}
				else 
				{
					sel = sel+'<input id =\"Checkbox-'+i+'\" name=\"Checkbox-'+i+'\" type=\"checkbox\" /> '+pos.value+'<br />';
				}
			} 
	sel = sel+'</div>';
	FW_okDialog(sel,'',removeFn) ; 
  }
	
function bigwindow(targetid){	
	targetval =document.getElementById(targetid).value;
	sel ='<div style=\"white-space:nowrap;\"><br>';
	sel = sel+'<textarea id=\"valtrans\" cols=\"80\" name=\"TextArea1\" rows=\"10\" onChange=\" document.getElementById(\\\''+targetid+'\\\').value=this.value; \">'+targetval+'</textarea>';
	sel = sel+'</div>';
	FW_okDialog(sel,''); 
}	

function removeFn() {
    var targ = document.getElementById('devices');
    for (i = 0; i < targ.options.length; i++) {
        test = document.getElementById('Checkbox-' + i).checked;
        targ.options[i].selected = false;
        if (test) {
            targ.options[i].selected = true;
        }
    }
}
	
\$(\"#aw_little\").click(function(){
var veraenderung = 3; // Textfeld veraendert sich stets um 3 Zeilen
var sel = document.getElementById('textfie').innerHTML;
var show = document.getElementById('textfie2');
var2 = \"size=\\\"6\\\"\";
var result = sel.replace(/size=\\\"15\\\"/g,var2);
document.getElementById('textfie').innerHTML = result;      
});
	
  }
</script>
";
    return "$ret<br>$detailhtml<br>$j1";
}
####################
sub MSwitch_makeCmdHash($) {
    my $loglevel = 5;
    my ($Name) = @_;

    Log3( $Name, 5, "SUB  " . ( caller(0) )[3] );

    # detailsatz in scalar laden
    my @devicedatails =
      split( /\|/, ReadingsVal( $Name, '.Device_Affected_Details', '' ) )
      ;    #inhalt decice und cmds durch komma getrennt
    Log3( $Name, 5, "MSwitch_makeCmdHash: @devicedatails L:" . __LINE__ );
    my %savedetails;
    foreach (@devicedatails) {
        my @detailarray = split( /,/, $_ )
          ;    #enthält daten 0-5 0 - name 1-5 daten 7 und9 sind zeitangaben
        ## ersetzung für delayangaben
        Log3( $Name, 5, "MSwitch_makeCmdHash: @detailarray L:" . __LINE__ );

        my $key = '';

        my $testtimestroff = $detailarray[7];

        $key = $detailarray[0] . "_delayatonorg";
        $savedetails{$key} = $detailarray[7];

        Log3( $Name, 5,
            "MSwitch_makeCmdHash: $key ->  $savedetails{$key} L:" . __LINE__ );

        $testtimestroff =~ s/[A-Za-z0-9#\.\-_]//g;
        Log3( $Name, 5, "MSwitch_makeCmdHash: $testtimestroff L:" . __LINE__ );
        if ( $testtimestroff ne "[:]" ) {
            my $hdel = ( substr( $detailarray[7], 0, 2 ) ) * 3600;
            my $mdel = ( substr( $detailarray[7], 2, 2 ) ) * 60;
            my $sdel = ( substr( $detailarray[7], 4, 2 ) ) * 1;
            $detailarray[7] = $hdel + $mdel + $sdel;
        }
        my $testtimestron = $detailarray[8];

        $key = $detailarray[0] . "_delayatofforg";
        $savedetails{$key} = $detailarray[8];

        $testtimestron =~ s/[A-Za-z0-9#\.\-_]//g;
        Log3( $Name, 5, "MSwitch_makeCmdHash: $testtimestron L:" . __LINE__ );
        if ( $testtimestron ne "[:]" ) {
            my $hdel = substr( $detailarray[8], 0, 2 ) * 3600;
            my $mdel = substr( $detailarray[8], 2, 2 ) * 60;
            my $sdel = substr( $detailarray[8], 4, 2 ) * 1;
            $detailarray[8] = $hdel + $mdel + $sdel;
        }

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
        $key               = $detailarray[0] . "_conditionon";

        #$key               = $detailarray[0] . "_delayaton";

#
#Log3( $Name, 5, "MSwitch_makeCmdHash:key   $key L:" . __LINE__ );
#Log3( $Name, 5, "MSwitch_makeCmdHash:savekey   $savedetails{$key} L:" . __LINE__ );

        if ( defined $detailarray[9] ) {
            $detailarray[9] =~ s/\(:\)/:/g;
            $detailarray[9] =~ s/\(DAYS\)/|/g;
            $savedetails{$key} = $detailarray[9];
        }
        else {
            $savedetails{$key} = '';
        }
        $key = $detailarray[0] . "_conditionoff";
        if ( defined $detailarray[10] ) {
            $detailarray[10] =~ s/\(:\)/:/g;
            $detailarray[10] =~ s/\(DAYS\)/|/g;
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
    my $events = ReadingsVal( $Name, '.Device_Events', '' );
    my @eventsall     = split( /\|/, $events );
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
        $events = $events . $name . '|';
    }
    chop($events);
    readingsSingleUpdate( $hash, ".Device_Events", $events, 0 );
    return;
}
###########################################################################
sub MSwitch_Exec_Notif($$$$) {
    my ( $hash, $comand, $check, $event ) = @_;
    my $name      = $hash->{NAME};
    my $protokoll = '';
    my $satz;

    Log3( $name, 3, "SUB  " . ( caller(0) )[3] );

    #### teste auf condition nur wenn nicht von timer

    #Log3( $name, 3,"check -> $check  " );

    if ( $check ne 'nocheck' ) {
        my $triggercondition = ReadingsVal( $name, '.Trigger_condition', '' );
        $triggercondition =~ s/\./:/g;
        if ( $triggercondition ne '' ) {
            Log3( $name, 5,
                "$name MSwitch_Notif: Aufruf MSwitch_checkcondition "
                  . __LINE__ );
            my $ret = MSwitch_checkcondition( $triggercondition, $name, '' );
            if ( $ret eq 'false' ) {
                Log3( $name, 5,
"$name MSwitch_Notif: Befehl nicht ausgefuehrt ( condition false ) "
                      . __LINE__ );
                return;
            }
        }
    }

    ### ausführen des on befehls
    my %devicedetails = MSwitch_makeCmdHash($name);

    # betroffene geräte suchen
    my @devices    = split( /,/, ReadingsVal( $name, '.Device_Affected', '' ) );
    my $update     = '';
    my $testtoggle = '';
    foreach my $device (@devices) {
        if ( AttrVal( $name, 'MSwitch_Delete_Delays', '0' ) eq '1' ) {
            Log3( $name, 5,
"$name MSwitch_Exec_Notif: delays werden geloescht $name -> delay fuer $device geloescht L:"
                  . __LINE__ );
            MSwitch_Delete_Delay( $hash, $device );
        }
        my @devicesplit = split( /-AbsCmd/, $device );
        my $devicenamet = $devicesplit[0];

        # teste auf on kommando
        my $key      = $device . "_" . $comand;
        my $timerkey = $device . "_time" . $comand;
        $devicedetails{ $device . '_onarg' } =~ s/~/ /g;
        $devicedetails{ $device . '_offarg' } =~ s/~/ /g;
        my $testtstate = $devicedetails{$timerkey};
        $testtstate =~ s/[A-Za-z0-9#\.\-_]//g;
        Log3( $name, 5, "MSwitch_makeCmdHash: $testtstate L:" . __LINE__ );
        if ( $testtstate eq "[:]" ) {
            $devicedetails{$timerkey} =
              eval MSwitch_Checkcond_state( $devicedetails{$timerkey}, $name );
            Log3( $name, 5,
                "MSwitch_makeCmdHash: timerkey -> $devicedetails{$timerkey} L:"
                  . __LINE__ );
            my $hdel = ( substr( $devicedetails{$timerkey}, 0, 2 ) ) * 3600;
            my $mdel = ( substr( $devicedetails{$timerkey}, 3, 2 ) ) * 60;
            my $sdel = ( substr( $devicedetails{$timerkey}, 6, 2 ) ) * 1;
            $devicedetails{$timerkey} = $hdel + $mdel + $sdel;
        }
        Log3( $name, 5,
            "MSwitch_makeCmdHash: timerkey -> $devicedetails{$timerkey} L:"
              . __LINE__ );
        ############ teste auf condition
        ### antwort $execute 1 oder 0 ;
        my $conditionkey = $device . "_condition" . $comand;
        if ( $devicedetails{$key} ne "" && $devicedetails{$key} ne "no_action" )
        {
            my $cs = '';
            if ( $devicenamet eq 'FreeCmd' ) {
                $cs = "  $devicedetails{$device.'_'.$comand.'arg'}";
            }
            else {
                $cs =
"set $devicenamet $devicedetails{$device.'_'.$comand} $devicedetails{$device.'_'.$comand.'arg'}";
            }

            #Variabelersetzung
            $cs =~ s/\$NAME/$hash->{helper}{eventfrom}/;
            if (   $devicedetails{$timerkey} eq "0"
                || $devicedetails{$timerkey} eq "" )
            {
                ############ teste auf condition
                ### antwort $execute 1 oder 0 ;
                $conditionkey = $device . "_condition" . $comand;
                Log3( $name, 5,
                    "$name MSwitch_Notif: Aufruf MSwitch_checkcondition -> $cs "
                      . __LINE__ );

                my $execute =
                  MSwitch_checkcondition( $devicedetails{$conditionkey},
                    $name, $event );
                $testtoggle = 'undef';
                if ( $execute eq 'true' ) {
                    Log3( $name, 3,
                        "$name MSwitch_Notif: Befehlsausfüehrung -> $cs "
                          . __LINE__ );
                    $testtoggle = $cs;
                    #############
                    my $errors = AnalyzeCommandChain( undef, $cs );
                    if ( defined($errors) ) {
                        Log3( $name, 1,
"$name Absent_Exec_Notif $comand: ERROR $device: $errors -> Comand: $cs"
                        );
                    }
                    my $msg = $cs;
                    readingsSingleUpdate( $hash, "Exec_cmd", $msg, 1 );
                    ############
                }
            }
            else {
                my $timecond = gettimeofday() + $devicedetails{$timerkey};

                Log3( $name, 4,
                    "$name MSwitch_Set: delay oder at gefunden L:" . __LINE__ );
                my $delaykey     = $device . "_delayat" . $comand;
                my $delayinhalt  = $devicedetails{$delaykey};
                my $delaykey1    = $device . "_delayat" . $comand . "org";
                my $teststateorg = $devicedetails{$delaykey1};
                Log3( $name, 3,
                    "$name MSwitch_Set: teststateorg -> $teststateorg L:"
                      . __LINE__ );
                if ( $delayinhalt eq 'at0' || $delayinhalt eq 'at1' ) {
                    $timecond = MSwitch_replace_delay( $hash, $teststateorg );
                }

                if ( $delayinhalt eq 'at1' || $delayinhalt eq 'delay0' ) {
                    $conditionkey = "nocheck";
                }

                my $msg =
                    $cs . ","
                  . $name . ","
                  . $conditionkey . ","
                  . $event . ","
                  . $timecond;
                $hash->{helper}{timer}{$msg} = $timecond;
                Log3( $name, 5,
                    "$name MSwitch_Notif: Timer wird gesetzt -> $cs "
                      . __LINE__ );
                $testtoggle = 'undef';
                InternalTimer( $timecond, "MSwitch_Restartcmd", $msg );
            }
        }
        if ( $testtoggle ne '' && $testtoggle ne '' && $testtoggle ne 'undef' )
        {
            $satz .= $testtoggle . ',';
        }
    }
    return $satz;
}
####################
sub MSwitch_Filter_Trigger($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};

    Log3( $Name, 5, "SUB  " . ( caller(0) )[3] );
    if ( !exists $hash->{Trigger_device} ) { return; }    #CHANGE
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
    my @eventsall = split( /\|/, $events );
  EVENT: foreach my $eventcopy (@eventsall) {
        my @filters =
          split( /,/, AttrVal( $Name, 'MSwitch_Trigger_Filter', '' ) )
          ;    # beinhaltet filter durch komma getrennt
        foreach my $filter (@filters) {
            my $wildcarttest = index( $filter, "*", 0 );
            if ( $wildcarttest > -1 )    ### filter auf wildcart
            {
                $filter = substr( $filter, 0, $wildcarttest );
                my $testwildcart = index( $eventcopy, $filter, 0 );
                if ( $testwildcart eq '0' ) {
                    next EVENT;
                }
            }
            else                         ### filter genauen ausdruck
            {
                if ( $eventcopy eq $filter ) {
                    next EVENT;
                }
            }
        }
        $hash->{helper}{events}{$Triggerdevice}{$eventcopy} = "on";
    }
    my $eventhash = $hash->{helper}{events}{$Triggerdevice};
    $events = "";
    foreach my $name ( keys %{$eventhash} ) {
        $events = $events . $name . '|';
    }
    chop($events);
    readingsSingleUpdate( $hash, ".Device_Events", $events, 0 );
    return;
}
####################
sub MSwitch_Restartcmd($) {
    my $incomming     = $_[0];
    my @msgarray      = split( /,/, $incomming );
    my $name          = $msgarray[1];
    my $cs            = $msgarray[0];
    my $conditionkey  = $msgarray[2];
    my $event         = $msgarray[2];
    my $hash          = $modules{MSwitch}{defptr}{$name};
    my %devicedetails = MSwitch_makeCmdHash($name);
    ############ teste auf condition
    ### antwort $execute 1 oder 0 ;
    Log3( $name, 3,
"$name MSwitch_Restartcm: Aufruf MSwitch_checkcondition $devicedetails{$conditionkey}, $name, $event"
          . __LINE__ );

    my $execute;
    if ( $msgarray[2] ne 'nocheck' ) {
        $execute = MSwitch_checkcondition( $devicedetails{$conditionkey}, $name,
            $event );
        Log3( $name, 3,
            "$name MSwitch_Restartcm:  condcheck ausgefuehrt " . __LINE__ );
    }
    else {
        $execute = 'true';

        Log3( $name, 3,
            "$name MSwitch_Restartcm: kein condcheck ausgefuehrt " . __LINE__ );
    }

    Log3( $name, 3,
"$name MSwitch_Restartcm: Aufruf MSwitch_checkcondition ergebniss condcheck -> $execute "
          . __LINE__ );

    if ( $execute eq 'true' ) {
        Log3( $name, 3,
            "$name MSwitch_Restartcm: Befehlsausfuehrung -> $cs " . __LINE__ );

        if ( $cs =~ m/set (.*)(MSwitchtoggle)(.*)/ ) {
            Log3( $name, 5, "$name MSwitch_Set:  $cs " . __LINE__ );
            $cs = MSwitch_toggle( $hash, $cs );
        }

        my $errors = AnalyzeCommandChain( undef, $cs );
        if ( defined($errors) ) {
            Log3( $name, 1,
"$name MSwitch_Restartcmd :Fehler bei Befehlsausfuehrung  ERROR $errors "
                  . __LINE__ );
        }
        readingsSingleUpdate( $hash, "Exec_cmd", $cs, 1 );
    }
    RemoveInternalTimer($incomming);
    delete( $hash->{helper}{timer}{$incomming} );
    return;
}
####################
sub MSwitch_checkcondition($$$) {

    # antwort execute 0 oder 1
    my ( $condition, $name, $event ) = @_;

    Log3( $name, 5, "SUB  " . ( caller(0) )[3] );

    Log3( $name, 5, "$name MSwitch_checkcondition: -> $condition " . __LINE__ );
    if ( !defined($condition) ) { return 'true'; }
    if ( $condition eq '' )     { return 'true'; }
    my $hash     = $modules{MSwitch}{defptr}{$name};
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
    Log3( $name, 5, "$name EVENT: -> $event " . __LINE__ );
    $event =~ s/ //ig;
    $event =~ s/~/ /g;
    readingsSingleUpdate( $hash, "last_event", $event, 1 );
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
    #############################################
    ########################## wildcardcheck
    #############################################
    # my $wekend = AnalyzeCommand( 0, '{return $we}' );
    #my $wekend1 = AnalyzeCommand( 0, '{return !$we}' );
    #my $we1 = AnalyzeCommand( 0, '{return $we}' );
    #my $we2 = AnalyzeCommand( 0, '{return !$we}' );

    my $we = AnalyzeCommand( 0, '{return $we}' );

   #Log3( $name, 5,"name MSwitch_checkcondition: we1 = $we1 L:". __LINE__ );
   #Log3( $name, 5,"name MSwitch_checkcondition: we2 = $we2 L:". __LINE__ );
   #Log3( $name, 0,"name MSwitch_checkcondition: we = $wekend L:". __LINE__ );
   #Log3( $name, 0,"name MSwitch_checkcondition: we1 = $wekend1 L:". __LINE__ );

    # if ({$we})
    # {Log3( $name, 0,"!weekend L:". __LINE__ );}
    # else
    # {Log3( $name, 0,"!no weekend L:". __LINE__ );}

    # if ({!$we})
    # {Log3( $name, 0,"!weekend L:". __LINE__ );}
    # else
    # {Log3( $name, 0,"!no weekend L:". __LINE__ );}

    my @perlarray;
    ### perlteile trennen

    # $condition =~ s/{!\$we}/{~!\$we~}/ig;
    # $condition =~ s/{\$we}/{~\$we~}/ig;

    #my $we = AnalyzeCommand( 0, '{return $we}' );
    $condition =~ s/{!\$we}/~!\$we~/ig;
    $condition =~ s/{\$we}/~\$we~/ig;

    # $condition =~ s/{~\$we~}/~\$we~/ig;

    $condition =~ s/{sunset\(\)}/{~sunset\(\)~}/ig;
    $condition =~ s/{sunrise\(\)}/{~sunrise\(\)~}/ig;
    $condition =~ s/\$EVENT/$name\:last_event/ig;

    Log3( $name, 5, "cond -> $condition L:" . __LINE__ );

    my $x = 0;    # exit secure
    while ( $condition =~ m/(.*)({~)(.*)(\$we)(~})(.*)/ ) {
        last if $x > 20;    # exit secure
        $condition = $1 . " " . $3 . $4 . " " . $6;
    }
    Log3( $name, 5, "cond -> $condition L:" . __LINE__ );

    ###################################################
    # ersetzte sunset sunrise
    # regex (.*[^~])(~{|{)(sunset\(|sunrise\()(.*\))(~}|})(.*)
    $x = 0;    # exit secure
    while (
        $condition =~ m/(.*)({~)(sunset\([^}]*\)|sunrise\([^}]*\))(~})(.*)/ )
    {
        $x++;    # exit secure
        last if $x > 20;    # exit secure
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
    $condition =~ s/~AND~/ && /ig;
    $condition =~ s/~OR~/ || /ig;
    $condition =~ s/~/ /ig;
    $condition =~ s/ = / == /ig;
  END:

    # teste auf typ
    my $count = 0;
    my $testarg;
    my @newargarray;
    foreach my $args (@argarray) {
        $testarg = $args;
        $testarg =~ s/[0-9]+//gs;
        if ( $testarg eq '[:-:|]' || $testarg eq '[:-:]' ) {

            # timerformatierung erkannt - auswerten über sub
            my $param = $argarray[$count];
            Log3( $name, 5,
                "name MSwitch_checkcondition: aufruf checktime  -> $param:"
                  . __LINE__ );
            $newargarray[$count] = MSwitch_Checkcond_time( $args, $name );
        }
        else {
            my $param = $argarray[$count];

            # stateformatierung erkannt - auswerten über sub
            $newargarray[$count] = MSwitch_Checkcond_state( $args, $name );
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
    $finalstring =
      "if (" . $condition . "){\$answer = 'true';} else {\$answer = 'false';} ";
    Log3( $name, 5,
        "name MSwitch_checkcondition: Finalstringt = $finalstring L:"
          . __LINE__ );

    my $ret = eval $finalstring;
    Log3( $name, 5, "name MSwitch_checkcondition: ret = $ret L:" . __LINE__ );
    if ($@) {
        Log3( $name, 1, "ERROR: $@ " . __LINE__ );
        $hash->{helper}{conditionerror} = $@;
        return 'false';
    }
    my $test = ReadingsVal( $name, 'last_event', 'undef' );
    $hash->{helper}{conditioncheck} = $finalstring;
    Log3( $name, 5,
"$name MSwitch_checkcondition: $test finalstring = $finalstring -> return: $ret L:"
          . __LINE__ );
    return $ret;
}
####################
sub MSwitch_Checkcond_state($$) {
    my ( $condition, $name ) = @_;
    $condition =~ s/\[//;
    $condition =~ s/\]//;
    my @reading = split( /:/, $condition );
    my $return  = "ReadingsVal('$reading[0]', '$reading[1]', 'undef')";
    my $test    = ReadingsVal( $reading[0], $reading[1], 'undef' );
    return $return;
}
####################
sub MSwitch_Checkcond_time($$) {
    my ( $condition, $name ) = @_;
    $condition =~ s/\[//;
    $condition =~ s/\]//;
    my $adday        = 0;
    my $days         = '';
    my $daycondition = '';
    ( $condition, $days ) = split( /\|/, $condition )
      if index( $condition, "|", 0 ) > -1;
    my $hour1 = substr( $condition, 0, 2 );
    my $min1  = substr( $condition, 3, 2 );
    my $hour2 = substr( $condition, 6, 2 );
    my $min2  = substr( $condition, 9, 2 );

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

    #my $time1;
    my ( $tday, $tmonth, $tdate, $tn );   #my ($tday,$tmonth,$tdate,$tn,$time1);
    if ( ( $akthour < $hour1 && $akthour < $hour2 ) && $hour2 < $hour1 )   # und
    {
        use constant SECONDS_PER_DAY => 60 * 60 * 24;
        $timecondtest = localtime( time - SECONDS_PER_DAY );
        $timecondtest =~ s/\s+/ /g;
        ( $tday, $tmonth, $tdate, $tn, $time1 ) = split( / /, $timecondtest );
        $timecond1 = timelocal( '00', $min1, $hour1, $tdate, $tmonth, $time1 );
        $adday = 1;
    }
    else {
        $timecondtest = localtime;
        $timecondtest =~ s/\s+/ /g;
        ( $tday, $tmonth, $tdate, $tn, $time1 ) = split( / /, $timecondtest );
        $timecond1 = timelocal( '00', $min1, $hour1, $tdate, $tmonth, $time1 );
    }
    ############# timecondition 2
    my $timecond2;
    $timecondtest = localtime;
    if ( $hour2 < $hour1 ) {
        if ( $akthour < $hour1 && $akthour < $hour2 ) {
            $timecondtest = localtime;
            $timecondtest =~ s/\s+/ /g;
            ( $tday, $tmonth, $tdate, $tn, $time1 ) =
              split( / /, $timecondtest );
            $timecond2 =
              timelocal( '00', $min2, $hour2, $tdate, $tmonth, $time1 );
        }
        else {
            use constant SECONDS_PER_DAY => 60 * 60 * 24;
            $timecondtest = localtime( time + SECONDS_PER_DAY );
            $timecondtest =~ s/\s+/ /g;
            my ( $tday, $tmonth, $tdate, $tn, $time1 ) =
              split( / /, $timecondtest );
            $timecond2 =
              timelocal( '00', $min2, $hour2, $tdate, $tmonth, $time1 );
            $adday = 1;
        }
    }
    else {
        $timecondtest = localtime;
        $timecondtest =~ s/\s+/ /g;
        ( $tday, $tmonth, $tdate, $tn, $time1 ) = split( / /, $timecondtest );
        $timecond2 = timelocal( '00', $min2, $hour2, $tdate, $tmonth, $time1 );
    }
    my $timeaktuell =
      timelocal( '00', $aktmin, $akthour, $date, $month, $time1 );
    my $return = "($timecond1 < $timeaktuell && $timeaktuell < $timecond2)";
    if ( $days ne '' ) {
        $daycondition = MSwitch_Checkcond_day( $days, $name, $adday, $day );
        $return = "($return $daycondition)";
    }
    return $return;
}
####################
sub MSwitch_Checkcond_day($$$$) {
    my ( $days, $name, $adday, $day ) = @_;

    Log3( $name, 5, "SUB  " . ( caller(0) )[3] );

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
    return $daycond;
}
####################
sub MSwitch_Settimecontrol($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};

    Log3( $Name, 5, "SUB  " . ( caller(0) )[3] );

    # alle vorhandenen timer löschen !
    Log3( $Name, 5,
        "$Name MSwitch_Settimecontrol: loesche alle delays L:" . __LINE__ );
    RemoveInternalTimer($hash);
    my $timeoptions = ReadingsVal( $Name, '.Trigger_time', '' );

    #berechner erneutes holen der timer um 00:00:02
    my $akttimeunix      = gettimeofday();
    my $akttime          = TimeNow();
    my $tomorrowtimeunix = $akttimeunix + 86400;
    my $tomorrowtime     = FmtDateTime($tomorrowtimeunix);
    my ( $tdate, $ttime ) = split( / /, $tomorrowtime );
    my ( $year, $month, $mday ) = split( /-/, $tdate );
    $year  = $year - 1900;
    $month = $month - 1;
    my $intervaltimeunix = fhemTimeLocal( 01, 00, 00, $mday, $month, $year );
    my $kontrolltime = FmtDateTime($intervaltimeunix);
    $hash->{helper}{timer}{$hash} = $intervaltimeunix;
    InternalTimer( $intervaltimeunix, 'MSwitch_Createtimer', $hash );
    $hash->{NEXT_TIMERCHECK} = $kontrolltime;
    Log3( $Name, 5,
        "$Name MSwitch_Settimecontrol: neuer timer -> $kontrolltime L:"
          . __LINE__ );
    return;
}
####################
sub MSwitch_Createtimer($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};

    Log3( $Name, 5, "SUB  " . ( caller(0) )[3] );

    my $condition = ReadingsVal( $Name, '.Trigger_time', '' );
    my $lenght = length($condition);
    if ( $lenght == 0 ) {
        Log3( $Name, 5,
"$Name MSwitch_Createtimer: Abbruch -> keine conditions , loesche alle Timer L:"
              . __LINE__ );
        delete( $hash->{READINGS}{Next_Time_Event} );
        delete( $hash->{NEXT_TIMERCHECK} );
        delete( $hash->{NEXT_TIMEREVENT} );
        RemoveInternalTimer($hash);
        return;
    }

    my $key = 'on';
    $condition =~ s/$key//ig;
    $key = 'off';
    $condition =~ s/$key//ig;
    $key = 'ly';
    $condition =~ s/$key//ig;
    my @timer = split /~/, $condition;
    my $time = localtime;
    $time =~ s/\s+/ /g;
    my ( $day, $month, $date, $n, $time1 ) =
      split( / /, $time );    # day enthält aktuellen tag als wochentag
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
    my $count = 1;
    my @reltimes;
    my @relopt;
  LOOP2: foreach my $option (@timer) {
        #### inhalt array für eine option on , off ...
        $key = '\]\[';
        $option =~ s/$key/ /ig;
        $key = '\[';
        $option =~ s/$key//ig;
        $key = '\]';
        $option =~ s/$key//ig;

        my @optionarray = split / /, $option;
      LOOP3: foreach my $option1 (@optionarray) {
            Log3( $Name, 5,
                "$Name MSwitch_createtimer: option1 -> $option1 L:"
                  . __LINE__ );
            if ( $option1 =~ m/{/i || $option1 =~ m/}/i ) {
                Log3( $Name, 5,
"$Name MSwitch_createtimer: teste auf perlcode -> enthalten ! L:"
                      . __LINE__ );
                my $newoption1 = MSwitch_ChangeCode( $hash, $option1 );
                $option1 = $newoption1;
            }
            my ( $time, $days ) = split /\|/, $option1;
            Log3( $Name, 5,
                "$Name MSwitch_createtimer: days -> $days L:" . __LINE__ );
            if ( $days eq '!$we' || $days eq '$we' )

              #!$we
            {
                my $we = AnalyzeCommand( 0, '{return $we}' );
                Log3( $Name, 5,
                    "$Name MSwitch_createtimer: WE gefunden we ist $we L:"
                      . __LINE__ );
                if ( $days eq '$we'  && $we == 1 ) { $days = $day; }
                if ( $days eq '!$we' && $we == 0 ) { $days = $day; }
            }

            if ( !defined($days) ) { $days = '' }
            if ( $days eq '' )     { $days = '1234567' }

            if ( index( $days, $day, 0 ) == -1 ) {
                next LOOP3;
            }

            #### auslagernfür einmalige ausführung
            my ( $hour, $min ) = split /:/, $time;
            my $akttimestamp = TimeNow();
            my ( $aktdate, $akttime ) = split / /, $akttimestamp;
            my ( $aktyear, $aktmday, $aktmonth ) = split /-/, $aktdate;
            $aktmonth = $aktmonth - 1;
            $aktyear  = $aktyear - 1900;
            my $timestamp =
              fhemTimeLocal( 00, $min, $hour, $aktmday, $aktmonth, $aktyear );
            my $kontrolle = FmtDateTime($timestamp);
            push( @reltimes, $timestamp );    # Den Eintrag peter hinzufügen
            push( @relopt,   $count );        # Den Eintrag peter hinzufügen
        }
        $count++;
    }
    my $akttimestamp = TimeNow();
    my ( $aktdate, $akttime ) = split / /, $akttimestamp;
    my ( $aktyear, $aktmday, $aktmonth ) = split /-/, $aktdate;
    $aktmonth = $aktmonth - 1;
    $aktyear  = $aktyear - 1900;
    my ( $akthour, $aktmin, $aktsec ) = split /:/, $akttime;
    ####################################
    my $timestamp =
      fhemTimeLocal( $aktsec, $aktmin, $akthour, $aktmday, $aktmonth,
        $aktyear );
    my $mind = 2000000000;    #ersetzen gegen akttime
    $count = 0;
    my $next;
    my $testvar = 0;
  LOOP4: foreach my $option (@reltimes) {
        if ( $option < $timestamp ) { $count++; next LOOP4; }
        if ( $option < $mind ) {
            $mind = $option;
            $next = $count;
        }
        $testvar = 1;
        $count++;
    }
    #########  alles löschen  !
    if ( $testvar == 0 ) {
        delete( $hash->{READINGS}{Next_Time_Event} );
        delete( $hash->{NEXT_TIMEREVENT} );
        RemoveInternalTimer($hash);
        $hash->{helper}{timer}{$hash} = gettimeofday() + 61;
        InternalTimer( gettimeofday() + 61, "MSwitch_Settimecontrol", $hash );
        Log3( $Name, 5,
"$Name MSwitch_createtimer: keine timer fuer aktuellen tag gefunden - alle geloescht restart +61"
              . __LINE__ );
        return;
    }
    my $difftostart = $reltimes[$next] - $timestamp;
    my $gettime     = gettimeofday();
    $hash->{NEXT_TIMEREVENT} = FmtDateTime( $gettime + $difftostart );
    readingsSingleUpdate( $hash, "Next_Time_Event",
        $gettime + $difftostart . '-' . $relopt[$next], 1 );
    Log3( $Name, 5,
"$Name MSwitch_createtimer: setze neuen Timer -> $gettime+$difftostart - $relopt[$next] L:"
          . __LINE__ );
    $hash->{helper}{timer}{$hash} = $gettime + $difftostart;
    InternalTimer( $gettime + $difftostart, "MSwitch_Execute_Timer", $hash );
    return;
}
####################
sub MSwitch_Execute_Timer($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};

    Log3( $Name, 5, "SUB  " . ( caller(0) )[3] );

    Log3( $Name, 5, "$Name MSwitch_Execute_Timer: start L:" . __LINE__ );
    delete( $hash->{NEXT_TIMEREVENT} );
    $hash->{helper}{timer}{$hash} = gettimeofday() + 61;
    InternalTimer( gettimeofday() + 61, "MSwitch_Createtimer", $hash );

    # ausführen des befehls
    my $seting = ReadingsVal( $Name, 'Next_Time_Event', '' );
    my ( $timer, $param ) = split /-/, $seting;
    if ( $param eq '1' ) {
        my $cs = "set $Name on";
        Log3( $Name, 3,
            "$Name MSwitch_Execute_Timer: Befehlsausfuehrung -> $cs"
              . __LINE__ );
        my $errors = AnalyzeCommandChain( undef, $cs );
        if ( defined($errors) ) {
            Log3( $Name, 1,
"$Name MSwitch_Execute_Timer: Fehler bei Befehlsausfuehrung ERROR $Name: $errors "
                  . __LINE__ );
        }
        return;
    }
    if ( $param eq '2' ) {
        my $cs = "set $Name off";
        Log3( $Name, 3,
            "$Name MSwitch_Execute_Timer: Befehlsausfuehrung -> $cs"
              . __LINE__ );
        my $errors = AnalyzeCommandChain( undef, $cs );
        if ( defined($errors) ) {
            Log3( $Name, 1,
"$Name MSwitch_Execute_Timer: Fehler bei Befehlsausfuehrung ERROR $Name: $errors "
                  . __LINE__ );
        }
        return;
    }
    if ( $param eq '3' ) {
        Log3( $Name, 5,
            "$Name MSwitch_Execute_Timer: Aufruf MSwitch_Execute_timer L"
              . __LINE__ );
        Log3( $Name, 5,
            "$Name MSwitch_Execute_Timer: set $Name trigger on L:" . __LINE__ );
        MSwitch_Exec_Notif( $hash, 'on', 'nocheck', '' );
        return;
    }
    if ( $param eq '4' ) {
        Log3( $Name, 5,
            "$Name MSwitch_Execute_Timer: Aufruf MSwitch_Execute_timer L"
              . __LINE__ );
        Log3( $Name, 5,
            "$Name MSwitch_Execute_Timer: set $Name trigger off L:"
              . __LINE__ );
        MSwitch_Exec_Notif( $hash, 'off', 'nocheck', '' );
        return;
    }
}
####################
sub MSwitch_ChangeCode($$) {
    my ( $hash, $option ) = @_;
    my $Name = $hash->{NAME};
    my $x    = 0;               # exit secure
    while ( $option =~ m/(.*){(sunset|sunrise)(.*)}(.*)/ ) {
        $x++;                   # exit secure
        last if $x > 20;        # exit secure
        if ( defined $2 ) {
            Log3( $Name, 5, "$Name s1 s2 -> $2 $3 L:" . __LINE__ );
            my $part2 = eval $2 . $3;
            Log3( $Name, 5, "$Name part2 -> $part2 L:" . __LINE__ );
            chop($part2);
            chop($part2);
            chop($part2);
            $option = $part2;
            $option = $1 . $option if ( defined $1 );
            $option = $option . $4 if ( defined $4 );
        }
        Log3( $Name, 5, "$Name option -> $option L:" . __LINE__ );
    }
    Log3( $Name, 5,
        "$Name MSwitch_ChangeCode: returned -> $option L:" . __LINE__ );
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
      split( /\|/, ReadingsVal( $Name, '.Device_Affected_Details', '' ) );
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
        my ( $name,       @comands )   = split( /,/,       $_ );
        my ( $devicename, $devicecmd ) = split( /-AbsCmd/, $name );
        if ( $devicemaster eq $devicename ) {
            my $newname =
              $devicename . '-AbsCmd' . $count . ',' . join( ',', @comands );
            push( @newdevicesset1, $newname );
            $count++;
            next LOOP10;
        }
        push( @newdevicesset1, $_ );
    }
    my $newaffected = join( ',', @newdevice1 );
    if ( $newaffected eq '' ) { $newaffected = 'no_device' }
    my $newaffecteddet = join( '|', @newdevicesset1 );
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
    my $timehash = $hash->{helper}{timer};
    my $out;
    foreach my $a ( keys %{$timehash} ) {
        my $pos = index( $a, "$device", 0 );
        if ( $pos != -1 ) {
            RemoveInternalTimer($a);
            delete( $hash->{helper}{timer}{$a} );
        }
    }
}
###################################
sub MSwitch_Check_Event($$) {
    my ( $hash, $eventin ) = @_;
    my $Name = $hash->{NAME};
    $eventin =~ s/~/ /g;
    my $dev_hash = "";
    if ( ReadingsVal( $Name, 'Trigger_device', '' ) eq "all_events" ) {
        my @eventin = split( /:/, $eventin );
        $dev_hash                         = $defs{ $eventin[0] };
        $hash->{helper}{testevent_device} = $eventin[0];
        $hash->{helper}{testevent_event}  = $eventin[1] . ":" . $eventin[2];
        $hash->{helper}{testevent_event}  = $eventin[1] . ":" . $eventin[2];
    }
    else {
        my @eventin = split( /:/, $eventin );
        $dev_hash = $defs{ ReadingsVal( $Name, 'Trigger_device', '' ) };
        $hash->{helper}{testevent_device} =
          ReadingsVal( $Name, 'Trigger_device', '' );
        $hash->{helper}{testevent_event} = $eventin[0] . ":" . $eventin[1];
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
#########################################
sub MSwitch_checktrigger(@) {
    my ( $own_hash, $ownName, $eventstellen, $triggerfield, $device, $zweig,
        $eventcopy, @eventsplit )
      = @_;
    my $wildcard      = 'off';
    my $triggeron     = ReadingsVal( $ownName, '.Trigger_on', '' );
    my $triggeroff    = ReadingsVal( $ownName, '.Trigger_off', '' );
    my $triggercmdon  = ReadingsVal( $ownName, '.Trigger_cmd_on', '' );
    my $triggercmdoff = ReadingsVal( $ownName, '.Trigger_cmd_off', '' );
    unshift( @eventsplit, $device )
      if ReadingsVal( $ownName, 'Trigger_device', '' ) eq "all_events";
    if ( $triggerfield eq "*"
        && ReadingsVal( $ownName, 'Trigger_device', '' ) eq "all_events" )
    {
        $wildcard     = 'on';
        $triggerfield = "*:*:*";
    }
    if ( $triggerfield eq "*"
        && ReadingsVal( $ownName, 'Trigger_device', '' ) ne "all_events" )
    {
        $wildcard     = 'on';
        $triggerfield = "*:*";
    }
    $triggerfield =~ s/\*/.*/g;

    # wenn global auf 3 stellen bringen , wenn nicht auf  2 stellen
    # trigger und event auf 3 werte ändern
    my @trigger = split( /\:/, $triggerfield );
    my $answer  = 'wahr';
    my $count   = 0;
  LOOP44: foreach (@trigger) {
        my $test = $_;
        if ( $test =~ m/(.*)\((.*)\)(.*)/ ) {
            my $var1new = $1;
            my $var2new = $2;
            my $var3new = $3;
            $var2new =~ s/\//|/g;
            $_ = $var1new . "(" . $var2new . ")" . $var3new;
        }
        if ( $eventsplit[$count] =~ m/^$_$/i ) {
            $answer = 'wahr';
        }
        else {
            $answer = 'unwahr';
            last LOOP44;
        }
        $count++;
    }
    return 'on'
      if $zweig eq 'on'
      && $answer eq 'wahr'
      && $wildcard eq 'on'
      && $eventcopy ne $triggercmdoff
      && $eventcopy ne $triggercmdon
      && $eventcopy ne $triggeroff;
    return 'on' if $zweig eq 'on' && $answer eq 'wahr' && $wildcard eq 'off';
    return 'off'
      if $zweig eq 'off'
      && $answer eq 'wahr'
      && $wildcard eq 'on'
      && $eventcopy ne $triggercmdoff
      && $eventcopy ne $triggercmdon
      && $eventcopy ne $triggeron;
    return 'off' if $zweig eq 'off' && $answer eq 'wahr' && $wildcard eq 'off';
    return 'offonly' if $zweig eq 'offonly' && $answer eq 'wahr';
    return 'ononly'  if $zweig eq 'ononly'  && $answer eq 'wahr';
    return 'undef';
}
###############################
sub MSwitch_VUpdate($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
    my $condition = ReadingsVal( $Name, '.Trigger_time', 'undef' );
    if ( $condition ne 'undef' ) {
        my @timer = split /,/, $condition;
        my $newcondition = join( '~', @timer );
        readingsSingleUpdate( $hash, ".Trigger_time", $newcondition, 0 );
        Log3( $Name, 5,
            "Datensatzaenderung: $Name -> $newcondition  . L:" . __LINE__ );
        Log3( $Name, 5, "Timerberechnung: $Name ->   . L:" . __LINE__ );
        MSwitch_Createtimer($hash);
    }
    readingsSingleUpdate( $hash, ".V_Check", $vupdate, 0 );
    return;
}
################################
sub MSwitch_backup($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};
    Log3( $Name, 5, "starte Backup  . L:" . __LINE__ );
    my @areadings =
      qw(.Device_Affected .Device_Affected_Details .Device_Events .First_init .Trigger_Whitelist .Trigger_cmd_off .Trigger_cmd_on .Trigger_condition .Trigger_off .Trigger_on .Trigger_time .V_Check Exec_cmd Trigger_device Trigger_log last_event state)
      ;    #alle readings
    my %keys;
    open( BACKUPDATEI, ">MSwitch_backup.cfg" );    # Datei zum Schreiben öffnen
    print BACKUPDATEI "# Mswitch Devices\n";       #
    foreach my $testdevice ( keys %{ $modules{MSwitch}{defptr} } )    #
    {
        print BACKUPDATEI "$testdevice\n";
    }
    print BACKUPDATEI "# Mswitch Devices END\n";    #
    print BACKUPDATEI "\n";                         # HTML-Datei schreiben
    foreach my $testdevice ( keys %{ $modules{MSwitch}{defptr} } )    #
    {
        print BACKUPDATEI "#N -> $testdevice\n";                      #
        foreach my $key (@areadings) {
            my $tmp = ReadingsVal( $testdevice, $key, 'undef' );
            print BACKUPDATEI "#S $key -> $tmp\n";
        }
        my %keys;
        foreach my $attrdevice ( keys %{ $attr{$testdevice} } )       #geht
        {
            print BACKUPDATEI "#A $attrdevice -> "
              . AttrVal( $testdevice, $attrdevice, '' ) . "\n";
        }
        print BACKUPDATEI "#E -> $testdevice\n";
        print BACKUPDATEI "\n";
    }
    close(BACKUPDATEI);

    #asyncOutput($hash->{CL}, "Backup wurde erstellt ");
}

################################
sub MSwitch_backup_this($) {
    my ($hash) = @_;
    my $Name   = $hash->{NAME};
    my $Zeilen = ("");
    open( BACKUPDATEI, "<MSwitch_backup.cfg" )
      || return "no Backupfile found\n";
    while (<BACKUPDATEI>) {
        $Zeilen = $Zeilen . $_;
    }
    close(BACKUPDATEI);
    $Zeilen =~ s/\n/[nl]/g;
    if ( $Zeilen !~ m/#N -> $Name\[nl\](.*)#E -> $Name\[nl\]/ ) {
        return "no Backupfile found\n";
    }
    my @found = split( /\[nl\]/, $1 );
    foreach (@found) {
        Log3( $Name, 5, "$_  . L:" . __LINE__ );
        if ( $_ =~ m/#S (.*) -> (.*)/ )    # setreading
        {
            if ( $2 eq 'undef' || $2 eq '' || $2 eq ' ' ) {
                Log3( $Name, 5, " no write reading $1 " );
            }
            else {
                Log3( $Name, 0, " write reading $hash, $1, $2, 0 " );
                readingsSingleUpdate( $hash, "$1", $2, 0 );
            }
        }
        if ( $_ =~ m/#A (.*) -> (.*)/ )    # setattr
        {
            my $cs = "attr $Name $1 $2";
            Log3( $Name, 5, " write attribut $1 -> $2 " );
            my $errors = AnalyzeCommandChain( undef, $cs );
            if ( defined($errors) ) {
                Log3( $Name, 5, "ERROR $cs" );
            }
        }
    }
    MSwitch_Createtimer($hash);
    return "MSwitch $Name restored.\nPlease refresh device.";
}

# ################################
# sub MSwitch_import($) {
# my ($hash) = @_;
# my $Name = $hash->{NAME};

# $hash->{helper}{import} = 'on';

# return;
# }

################################
sub MSwitch_Getconfig($) {
    my ($hash) = @_;
    my $Name = $hash->{NAME};

    Log3( $Name, 5, "starte Backup  . L:" . __LINE__ );
    my @areadings =
      qw(.Device_Affected .Device_Affected_Details .Device_Events .First_init .Trigger_Whitelist .Trigger_cmd_off .Trigger_cmd_on .Trigger_condition .Trigger_off .Trigger_on .Trigger_time .V_Check Exec_cmd Trigger_device Trigger_log last_event state)
      ;    #alle readings
           #   my %keys;
    my $count      = 0;
    my $out        = '';
    my $testdevice = $Name;

    # $out.=  "#N -> $testdevice\\n";                      #
    foreach my $key (@areadings) {
        my $tmp = ReadingsVal( $testdevice, $key, 'undef' );
        $out .= "#S $key -> $tmp\\n";
        $count++;
    }

    #  my %keys;
    foreach my $attrdevice ( keys %{ $attr{$testdevice} } )    #geht
    {
        $out .= "#A $attrdevice -> "
          . AttrVal( $testdevice, $attrdevice, '' ) . "\\n";
        $count++;
    }

    # $out.=   "#E -> $testdevice\\n";
    # $out.=   "\\n";
    $count++;
    $count++;
    my $client_hash = $hash->{CL};

    asyncOutput( $hash->{CL},
            "<html><textarea name=\"edit1\" id=\"edit1\" rows=\""
          . $count
          . "\" cols=\"160\" STYLE=\"font-family:Arial;font-size:9pt;\">"
          . $out
          . "</textarea><input name\"edit\" type=\"button\" value=\"save changes\" onclick=\" javascript: saveconfig(document.querySelector(\\\'#edit1\\\').value) \"></html>"
    );

#asyncOutput($hash->{CL}, "<html><textarea name=\"edit1\" id=\"edit1\" rows=\"40\" cols=\"160\" STYLE=\"font-family:Arial;font-size:9pt;\">".$out."</textarea></html>");

    return;
}

################################
sub MSwitch_backup_all($) {
    my ($hash) = @_;
    my $Name   = $hash->{NAME};
    my $answer = '';
    my $Zeilen = ("");
    open( BACKUPDATEI, "<MSwitch_backup.cfg" )
      || return "$Name|no Backupfile found\n";
    while (<BACKUPDATEI>) {
        $Zeilen = $Zeilen . $_;
    }
    close(BACKUPDATEI);

    Log3( $Name, 5, "wiederherstellung  start . L:" . __LINE__ );

    foreach my $testdevice ( keys %{ $modules{MSwitch}{defptr} } )    #
    {

        #if ($testdevice ne "Deko_Ctrl"){next;}
        Log3( $testdevice, 5,
            "wiederherstellung  $testdevice . L:" . __LINE__ );
        my $devhash = $defs{$testdevice};
        $Zeilen =~ s/\n/[nl]/g;
        if ( $Zeilen !~ m/#N -> $testdevice\[nl\](.*)#E -> $testdevice\[nl\]/ )
        {
            $answer = $answer . "no Backupfile found for $testdevice\n";
        }
        my @found = split( /\[nl\]/, $1 );
        foreach (@found) {
            Log3( $testdevice, 5, "$_  . L:" . __LINE__ );
            if ( $_ =~ m/#S (.*) -> (.*)/ )    # setreading
            {
                if ( $2 eq 'undef' || $2 eq '' || $2 eq ' ' ) {
                    Log3( $testdevice, 5, " no write reading $1 " );
                }
                else {
                    Log3( $testdevice, 5, " write reading $1 -> $2 " );
                    readingsSingleUpdate( $devhash, "$1", $2, 0 );
                }
            }
            if ( $_ =~ m/#A (.*) -> (.*)/ )    # setattr
            {
                my $cs = "attr  $testdevice $1 $2";
                Log3( $testdevice, 5, " write attribut $1 -> $2 " );
                my $errors = AnalyzeCommandChain( undef, $cs );
                if ( defined($errors) ) {
                    Log3( $testdevice, 1, "ERROR $cs" );
                }
            }
        }
        MSwitch_Createtimer($devhash);
        $answer = $answer . "MSwitch $testdevice restored.\n";

        # my $cs = "attr $testdevice $1 $2";
        # Log3( $testdevice, 0, " write attribut $1 -> $2 " );
        # my $errors = AnalyzeCommandChain( undef, $cs );
        # if ( defined($errors) ) {
        # Log3( $testdevice, 0, "ERROR $cs" );
        # }
    }

    Log3( $Name, 5, "wblocking end $hash $answer . L:" . __LINE__ );
    return $answer;
}
################################################
sub MSwitch_saveconf($$) {

    my ( $hash, $cont ) = @_;
    my $name = $hash->{NAME};
    Log3( $name, 0, "$name $cont  saveconfig reached L:" . __LINE__ );

    my @found = split( /\[nl\]/, $cont );
    foreach (@found) {
        Log3( $name, 0, "$_  . L:" . __LINE__ );
        if ( $_ =~ m/#S (.*) -> (.*)/ )    # setreading
        {
            if ( $2 eq 'undef' || $2 eq '' || $2 eq ' ' ) {
                Log3( $name, 0, " no write reading $1 " );
            }
            else {
                Log3( $name, 0, " write reading $1 -> $2 " );
                readingsSingleUpdate( $hash, "$1", $2, 0 );
            }
        }
        if ( $_ =~ m/#A (.*) -> (.*)/ )    # setattr
        {
            # my $cs = "get $name $1 $2";
            # Log3( $name, 0, " write attribut $1 -> $2 " );
            # my $errors = AnalyzeCommandChain( undef, $cs );
            # if ( defined($errors) ) {
            # Log3( $name, 0, "ERROR $cs" );
            # }

            $attr{$name}{$1} = $2;

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
    Log3( $Name, 5,
        "$Name wiederherstellung  abgeschlossen . $client_hash - $hash L:"
          . __LINE__ );
    $answer =~ s/\[nl\]/\n/g;

    foreach my $testdevice ( keys %{ $modules{MSwitch}{defptr} } )    #
    {
        Log3( $Name, 5, "restart timer  $testdevice . L:" . __LINE__ );
        my $devhash = $defs{$testdevice};
        MSwitch_Createtimer($devhash);
    }

    asyncOutput( $client_hash, $answer );
    return;
}
############################################
sub MSwitch_replace_delay($$) {
    my ( $hash, $timerkey ) = @_;
    my $name = $hash->{NAME};

    #my $akttimeunix      = gettimeofday();
    #   my $akttime          = TimeNow();
    my $time  = time;
    my $ltime = TimeNow();
    Log3( $name, 4, "$name MSwitch_Set: localtime = $ltime L:" . __LINE__ );
    my ( $aktdate, $akttime ) = split / /, $ltime;

    Log3( $name, 4, "$name MSwitch_Set: time = $time L:" . __LINE__ );
    Log3( $name, 4, "$name replace delay ->  $timerkey . L:" . __LINE__ );

    my $hh = ( substr( $timerkey, 0, 2 ) );
    my $mm = ( substr( $timerkey, 2, 2 ) );
    my $ss = ( substr( $timerkey, 4, 2 ) );

    Log3( $name, 4,
        "$name replace delay gesuchte zeit $hh:$mm:$ss . L:" . __LINE__ );
    my $referenz = time_str2num("$aktdate $hh:$mm:$ss");

    Log3( $name, 4, "$name MSwitch_Set: referenz = $referenz L:" . __LINE__ );

    if ( $referenz < $time ) {
        Log3( $name, 4,
"$name MSwitch_Set: Schaltzeit ueberschritten , addiere 24 Stunden L:"
              . __LINE__ );
        $referenz = $referenz + 86400;
    }
    if ( $referenz >= $time ) {
        Log3( $name, 4,
            "$name MSwitch_Set: Schaltzeit noch nicht erreicht L:" . __LINE__ );
    }

    $referenz = $referenz - $time;

    Log3( $name, 4,
        "$name MSwitch_Set: referenzend = $referenz L:" . __LINE__ );
    my $timestampGMT = FmtDateTimeRFC1123($referenz);
    Log3( $name, 4,
        "$name MSwitch_Set: referenzend = $timestampGMT L:" . __LINE__ );

    return $referenz;

}

1;

