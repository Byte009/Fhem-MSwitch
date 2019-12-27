	
	var version = 'V1.0';
	var config = [
	'#V 3.01 alpha',
	'#VS V2.00',
	'#S .First_init -> done',
	'#S .Trigger_off -> no_trigger',
	'#S .Trigger_cmd_off -> no_trigger',
	'#S Trigger_device -> no_trigger',
	'#S Trigger_log -> off',
	'#S .Trigger_on -> no_trigger',
	'#S .Trigger_cmd_on -> no_trigger',
	'#S .Trigger_condition -> ',
	'#S .V_Check -> V2.00',
	'#S .Device_Events -> no_trigger',
	'#S .Device_Affected -> no_device',
	'#S .Trigger_time -> ',
	'#A MSwitch_Debug -> 0',
	'#A MSwitch_Delete_Delays -> 0',
	'#A MSwitch_Eventhistory -> 0',
	'#A MSwitch_Safemode -> 1',
	'#A MSwitch_Lock_Quickedit -> 1',
	'#A MSwitch_Help -> 0',
	'#A room -> MSwitch_Devices',
	'#A MSwitch_Extensions -> 0',
	'#A MSwitch_Ignore_Types -> notify allowed at watchdog doif fhem2fhem telnet FileLog readingsGroup FHEMWEB autocreate eventtypes readingsproxy svg cul',
	'#A MSwitch_Include_Webcmds -> 0',
	'#A MSwitch_Include_MSwitchcmds -> 0',
	'#A MSwitch_Mode -> Notify',
	'#A MSwitch_Expert -> 0',
	'#A MSwitch_Include_Devicecmds -> 1'];


function settyp(inhalt,open,fill) {
	openraw=open;
	//  #inh1 =inhalt
	//  #open = freizuschaltendezeile
	//  #fill = zu füllendes feld
	
	open=openraw+'1';
	open1=openraw+'2';
	
	if (open == '3step1')
	{
		document.getElementById('2step1').style.display='none';
		document.getElementById('2step2').style.display='none';
		//document.getElementById('1step1').style.display='none';
		var o = new Object();
		$( '#eventcontrol' ).text( '' );
	}
	
	if (open == '2step1')
	{
		document.getElementById('3step1').style.display='none';
		document.getElementById('3step2').style.display='none';
		//document.getElementById('1step1').style.display='none';
	}
		
	if (open == '4step1')
	{
		var o = new Object();
		$( '#eventcontrol' ).text( '' );
		var text = 'Warte auf eingehende Events des Devices '+inhalt+' ... ';
		text =text+'<input name=\"5th\" id=\"5step\" type=\"button\" value=\"Event eingetroffen\" onclick=\"javascript: settyp(this.value,id,name)\">&nbsp;';
		document.getElementById('4step1').innerHTML = text;
		//document.getElementById('3step1').style.display='none';
		document.getElementById('monitor').style.display='block';
		logging='on';
	}	
	
	if (open == '5step1')
	{
		//alert('ok');
		logging = 'off';
		document.getElementById('4step1').style.display='none';
		document.getElementById('4step2').style.display='none';
		document.getElementById('monitor').style.display='none';
	}
		
	if (document.getElementById(fill)){document.getElementById(fill).value=inhalt;}
	
	if (document.getElementById(open)) {
		document.getElementById(open).style.display='block';
	}
	if (document.getElementById(open1)) {
		document.getElementById(open1).style.display='block';
	}
	return;
	}
	
	
	
	
	
function start1(name){
	    // this code will run after all other $(document).ready() scripts
        // have completely finished, AND all page elements are fully loaded.
		// alarm();
		$( ".makeSelect" ).text( "" );
		$( "[class='makeTable wide readings']" ).hide();
		$( "[class='makeTable wide internals']" ).hide();
		$( "[class='makeTable wide attributes']" ).hide();
		$( "[class=\"detLink iconFor\"]" ).hide();
		$( "[class=\"detLink rawDef\"]" ).hide();
		$( "[class=\"detLink devSpecHelp\"]" ).hide();
		$( "[class=\"detLink showDSI\"]" ).text( "" );
		var r3 = $('<a href=\"javascript: reset()\">Reset this device ('+name+')</a>');
		$(r3).appendTo('[class=\"detLink showDSI\"]');
		
		// fülle configfenster
		var showconf='';
		//alert(config[1]);
		conflines =  config.length ;
		for (i = 0; i < conflines; i++) 
		{
			showconf = showconf+config[i]+'\n';
		}
		document.getElementById('rawconfig').innerHTML = showconf;

	
		document.getElementById('version').innerHTML = 'Wizardversion '+version;
// htmlaufbau
		document.getElementById('monitor').style.display='none';
		
		line = 'Was für ein Ereigniss soll das MSwitch auslösen ( Trigger ) ?&nbsp;&nbsp;&nbsp;&nbsp;';
		line =line+'<input name=\"first\" id=\"2step\" type=\"button\" value=\"time\" onclick=\"javascript: settyp(this.value,id,name)\">&nbsp;';
		line =line+'<input name=\"first\" id=\"3step\" type=\"button\" value=\"event\" onclick=\"javascript: settyp(this.value,id,name)\">&nbsp;';
		document.getElementById('1step1').innerHTML = line;
		line ='<input id =\"first\" type=\"text\" value=\"\" disabled=\"disabled\">';
		document.getElementById('1step2').innerHTML = line;
		
		
		line = 'Zu welcher Zeit soll die Auslösung sein ? &nbsp;&nbsp;&nbsp;&nbsp;';
		line =line+'<input id=\"\" type=\"text\" value=\"HH:MM\" >';
		document.getElementById('2step1').innerHTML = line;
		document.getElementById('2step1').style.display='none';
		line ='<input id=\"2\" type=\"text\" value=\"\" disabled=\"disabled\">';
		document.getElementById('2step2').innerHTML = line;
		document.getElementById('2step2').style.display='none';
		
			
		line = 'Welches Gerärt soll der Auslöser sein ? &nbsp;&nbsp;&nbsp;&nbsp;';
		line =line+'<select id =\"4step\" name=\"3\" onchange=\"javascript: settyp(this.value,id,name)\">';
		for (i=0; i<len; i++)
			{
			line =line+'<option value='+devices[i]+'>'+devices[i]+'</option>';
			}
		line =line+'</select>';
		document.getElementById('3step1').innerHTML = line;
		document.getElementById('3step1').style.display='none';
		line ='<input id=\"3\" type=\"text\" value=\"\" disabled=\"disabled\">';
		document.getElementById('3step2').innerHTML = line;
		document.getElementById('3step2').style.display='none';
		
		line = 'Warte auf eingehende Events des Devices ';
		document.getElementById('4step1').innerHTML = line;
		document.getElementById('4step1').style.display='none';
		
		line = 'Auslösendes Event wählen ? &nbsp;&nbsp;&nbsp;&nbsp;';
		line =line+'<select id =\"6step\" name=\"5\" onchange=\"javascript: settyp(this.value,id,name)\">';
		
		line =line+'</select>';
		document.getElementById('5step1').innerHTML = line;
		document.getElementById('5step1').style.display='none';
		line ='<input id=\"5\" type=\"text\" value=\"\" disabled=\"disabled\">';
		document.getElementById('5step2').innerHTML = line;
		document.getElementById('5step2').style.display='none';

	return ;

	}