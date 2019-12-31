
	var version = 'V0.3 beta';
	var logging ='off';
	var observer;
	var target;
	var lastevent;
	
	var configstart = [
	'#V Version',
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







// starte Hauptfenster
conf('importWIZARD','wizard');

//####################################################################################################
// init eventmonitor

// Konfiguration des Observers: alles melden - Änderungen an Daten, Kindelementen und Attributen
	var config = { attributes: true, childList: true, characterData: true };
// test observer
// zu überwachende Zielnode (target) auswählen
	target = document.querySelector('div[informid="'+devicename+'-EVENTCONF"]');
 
// eine Instanz des Observers erzeugen
	observer = new MutationObserver(function(mutations) {
		mutations.forEach(function(mutation) {

	var test = $( "div[informId='"+devicename+"-EVENTCONF']" ).text();
	test = test.replace(/ /gi,"");

	document.getElementById('tf').innerHTML = test;
	
	if(o[test]){return;}
	//test= test.substring(0, test.length - 19);
	//alert(test);
	var event = test.split(':');
	var newevent =  event[1]+':'+event[2]
	if (event[0] != document.getElementById('3').value)
		{
			return;
		}
	if (logging == 'off')
		{
			return;
		}
	lastevent=newevent;
	o[test] = test;		
		
	// eintrag in dropdown und fenster ausblenden
	var newselect = $('<option value="'+newevent+'">'+newevent+'</option>');
	$(newselect).appendTo('#6step');
	// document.getElementById(\"4step1\").style.display=\"none\";
	// document.getElementById(\"5step1\").style.display=\"block\";
	
	// umwandlung des objekts in standartarray
	var a3 = Object.keys(o).map(function (k) { return o[k];})
	// array umdrehen
	a3.reverse();
	$( '#eventcontrol' ).text( '' );
	var i;
	for (i = 0; i < 30; i++) 
		{
		if (a3[i])
			{
			var newselect = $('<option value=\"'+a3[i]+'\">'+a3[i]+'</option>');
			$(newselect).appendTo('#eventcontrol'); 
			}
		}  
  });    
});


//####################################################################################################


function eventmonitorstop(){
	//alert('monitor off');
	if (observer){
		observer.disconnect();
		document.getElementById('tf').innerHTML = 'Monitor angehalten';
	}	
	return;
}

function eventmonitorstart(){
	//alert('monitor on');
	observer.observe(target, config);
	return;
}

function closeall(){
	
		logging ='off';
		o = new Object();
		eventmonitorstop()
		
		document.getElementById('4step1').style.display='none';
		document.getElementById('4step2').style.display='none';
		document.getElementById('5step1').style.display='none';
		document.getElementById('5step2').style.display='none';
		document.getElementById('2step1').style.display='none';
		document.getElementById('2step2').style.display='none';
		document.getElementById('3step1').style.display='none';
		document.getElementById('3step2').style.display='none';
		document.getElementById('monitor').style.display='none';
	
	return;
}

function settyp(inhalt,open,fill) {
	openraw=open;
	//  #inh1 =inhalt
	//  #open = freizuschaltendezeile
	//  #fill = zu füllendes feld
	
	open=openraw+'1';
	open1=openraw+'2';
	
	if (open == '3step1')
	{
		closeall();
		$( '#eventcontrol' ).text( '' );
		document.getElementById('help').innerHTML = 'Bitte das Device wählen , das als Trigger dient.';	

	}
	
	if (open == '2step1')
	{
		closeall();
		
		document.getElementById('help').innerHTML = 'Bitte die Zeit angeben, zu der das MSwitc-Device auslösen soll.<br>';	
		document.getElementById('help').innerHTML += 'Hier stehen mehrere Formate zur Verfügung<br>';
		document.getElementById('help').innerHTML += 'Bitte eine Vorauswahl treffen :<br>&nbsp;<br>';
	
	}
		
	if (open == '4step1')
	{
		closeall();
		document.getElementById('3step1').style.display='block';
		document.getElementById('3step2').style.display='block';
		document.getElementById('monitor').style.display='block';
		document.getElementById('4step1').style.display='block';
		document.getElementById('4step2').style.display='block';
		
		document.getElementById('help').innerHTML = 'Bitte das entsprechende Event manuell auslösen. Entweder durch der gewählten Hardware, oder durch schalten des entsprechenden MSwitchdevices.Wenn das gewünschte Event im Monitor sichtbar ist auf den Button klicken';	

		
		$( '#6step' ).text( '' );
		$( '#eventcontrol' ).text( '' );
		text = 'Warte auf eingehende Events des Devices '+inhalt+' ... ';
		text =text+'<input name=\"5th\" id=\"5step\" type=\"button\" value=\"Event eingetroffen\" onclick=\"javascript: settyp(this.value,id,name)\">&nbsp;';
		document.getElementById('4step1').innerHTML = text;
	
		logging='on';
		eventmonitorstart();
	}	
	
	if (open == '5step1')
	{
		eventmonitorstop();
		logging = 'off';
		
		// 5
		document.getElementById('5').value=lastevent;
		document.getElementById('help').innerHTML = 'Bitte das auslösende Event aus der Dropdownliste wählen. Im rechten Feld kann das Event manuell angepasst werden.';	

		
		document.getElementById('4step1').style.display='none';
		document.getElementById('4step2').style.display='none';
		document.getElementById('monitor').style.display='none';
	}
	
	if (open == '6step1')
	{
		// wird von fertig gewähltem event aufgerufen
	}
	
	if (open == '6step1')
	{
		// wird von fertig gewählter zeit aufgerufen 
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
	
	
function reset() {
	var nm = devicename;
	var  def = nm+' reset_device checked';
	location = location.pathname+'detail='+devicename+'&cmd=set '+addcsrf(def);
	return;
	}
	
	
// hauptfenster wählen
function conf(typ,but){
	eventmonitorstop()
	//alert(typ+'-'+but);
	document.getElementById('help').innerHTML = '';	

	document.getElementById('importAT').style.display='none';
	document.getElementById('importNOTIFY').style.display='none';
	document.getElementById('importCONFIG').style.display='none';
	document.getElementById('importWIZARD').style.display='none';
	
	document.getElementById('wizard').style.backgroundColor='';
	document.getElementById('config').style.backgroundColor='';
	document.getElementById('importat').style.backgroundColor='';
	document.getElementById('importnotify').style.backgroundColor='';
	
	document.getElementById(typ).style.display='block';
	document.getElementById(but).style.backgroundColor='#ffb900';

	if (but == 'wizard'){
		// neustart wizard
		startwizard();
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
		r3 = $('<a href=\"javascript: reset()\">Reset this device ('+name+')</a>');
		$(r3).appendTo('[class=\"detLink showDSI\"]');
		
// fülle configfenster
		fillconfig();
		startwizard();
}

function startwizard(){	
	
// help
		document.getElementById('help').innerHTML = 'Bitte wählen, ob die Auslösung des MSwitch-Devices durch ein Event oder zeitgesteuert erfolgen soll.';	
	
// htmlaufbau	
		document.getElementById('version').innerHTML = 'Wizardversion '+version;
		document.getElementById('monitor').style.display='none';
// ##		
		line = 'Was für ein Ereigniss soll das MSwitch auslösen ( Trigger ) ?&nbsp;&nbsp;&nbsp;&nbsp;';
		line =line+'<input name=\"first\" id=\"2step\" type=\"button\" value=\"time\" onclick=\"javascript: settyp(this.value,id,name)\">&nbsp;';
		line =line+'<input name=\"first\" id=\"3step\" type=\"button\" value=\"event\" onclick=\"javascript: settyp(this.value,id,name)\">&nbsp;';
		document.getElementById('1step1').innerHTML = line;
// ##
		line ='<input id =\"first\" type=\"text\" value=\"\" disabled=\"disabled\">';
		document.getElementById('1step2').innerHTML = line;
// ##
		line = '<table border ="0"><tr>';
		line += '<td>';
		
		line += '<select id="timetyps" name="timetyp" name="timetyp" onchange=\"javascript: settimetyp(this.value)\">';
		line += '<option id ="" value="typ0">wähle Zeit-Typ:</option>';
		line += '<option id ="" value="typ1">exakte Zeitangabe</option>';
		line += '<option id ="" value="typ2">zufällige Schaltzeit zwischen zwei Zeitpunkten</option>';
		line += '<option id ="" value="typ3">periodische Auslösung zwischen zwei Zeitpunkten</option>';
		line += '</select>';
		line += '</td>'
		line += '</tr>'
		line += '<tr>'
		
		line += '<td>';
		
		fbutton = '<input name=\"selecttyp\" id=\"selecttyp\" type=\"button\" value=\"übernehmen\" onclick=\"javascript: settime()\">';
			
		line += '<div id ="typ1" style="display:none">Um '+gettime('normal')+' Uhr '+getday('day1')+fbutton+'</div>';
		line += '<div id ="typ2" style="display:none">zwischen '+gettime('zufall')+' Uhr und '+gettime('zufall1') +'Uhr '+getday('zufal3')+fbutton+'</div>';
		line += '<div id ="typ3" style="display:none">periodisch alle '+gettime('periodic')+' zwischen '+gettime('periodic1') +'Uhr und'+gettime('periodic3')+'Uhr'+getday('periodic4')+fbutton+'</div>';
			
		line += '</td>'
		line += '</tr></table>';		

		document.getElementById('2step1').innerHTML = line;
		document.getElementById('2step1').style.display='none';
		line ='<input id=\"2\" type=\"text\" value=\"\" disabled=\"disabled\"> ';
		document.getElementById('2step2').innerHTML = line;
		document.getElementById('2step2').style.display='none';
			
// ##

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
// ##		
		line = 'Warte auf eingehende Events des Devices ';
		document.getElementById('4step1').innerHTML = line;
		document.getElementById('4step1').style.display='none';
// ##		
		line = 'Auslösendes Event wählen ? &nbsp;&nbsp;&nbsp;&nbsp;';
		line =line+'<select id =\"6step\" name=\"5\" onchange=\"javascript: settyp(this.value,id,name)\">';
// ##		
		line =line+'</select>';
		document.getElementById('5step1').innerHTML = line;
		document.getElementById('5step1').style.display='none';
		line ='<input id=\"5\" type=\"text\" value=\"\" >';
		document.getElementById('5step2').innerHTML = line;
		document.getElementById('5step2').style.display='none';

	return ;

	}
	
function makeconfig(){
	//alert('starte makeconfig');
	// configstart[0] = '#V '+mVersion;
	if (document.getElementById('first').value == 'time'){
		// ändere config für timeevent
		// 6 #S .Trigger_time -> on~off~ononly[20#[dp]00|1]~offonly~onoffonly
		
		string = document.getElementById('2').value;
		// ersetze dp durch #[dp]
		string = string.replace(/:/gi,"#[dp]");
		
		configstart[13] ='#S .Trigger_time -> on~off~ononly'+ string +'~offonly~onoffonly';
		
		
	}

	if (document.getElementById('first').value == 'event'){
		// ändere config für triggerevent
		// 5 #S Trigger_device -> no_trigger element 3
		configstart[5] ='#S Trigger_device -> '+ document.getElementById('3').value;
		// 8 #S .Trigger_cmd_on -> state:on  element 5
		configstart[8] ='#S .Trigger_cmd_on -> '+ document.getElementById('5').value;
		
	}
	
	fillconfig()
	return;
}


function fillconfig(){
	var showconf='';
	configstart[0] = '#V '+mVersion;
	conflines =  configstart.length ;
	for (i = 0; i < conflines; i++) 
		{
			showconf = showconf+configstart[i]+'\n';
		}
	document.getElementById('rawconfig').innerHTML = showconf;
	
}

function saveconfig(){
	//alert('nicht verfügbar !');
	//return;
	// alert('funk save')
	conf = document.getElementById('rawconfig').value;
	
	// alert (conf);
	// return;
	conf = conf.replace(/\n/g,'#[EOL]');
	conf = conf.replace(/:/g,'#c[dp]');
	conf = conf.replace(/;/g,'#c[se]');
	conf = conf.replace(/ /g,'#c[sp]');
	
	var nm = devicename;
	var def = nm+' saveconfig '+encodeURIComponent(conf);
	
	// alert (devicename);
	//return;	
	// document.getElementById('tf').innerHTML=def;
	
	// return;
	location = location.pathname+'?detail='+devicename+'&cmd=set '+addcsrf(def);
	return;
}

function getday(name){
	var addon = '<select id="'+name+'day">';
	addon += '<option value="">jeden Tag</option>';
	addon += '<option value="|$we">am Wochenende</option>';
	addon += '<option value="|!$we">an Wochentagen</option>';
	addon += '<option value="|1">Montag</option>';
	addon += '<option value="|2">Dienstag</option>';
	addon += '<option value="|3">Mitwoch</option>';
	addon += '<option value="|4">Donnerstag</option>';
	addon += '<option value="|5">Freitag</option>';
	addon += '<option value="|6">Samstag</option>';
	addon += '<option value="|7">Sonntag</option>';
	addon += '</select>';
	//addon='test';
	return addon;
}


function settimetyp(name){
	
	
	document.getElementById('typ1').style.display='none';
	document.getElementById('typ2').style.display='none';
	document.getElementById('typ3').style.display='none';
	//document.getElementsByClassName('timetyp').style.display='block';
	
	
	if (name == 'typ0'){return;}
	document.getElementById(name).style.display='block';
	return;
	
}



function gettime(name){	
	var hour;
	for (i=0; i<24; i++)
				{
				change = ("00" + i).slice(-2);
				hour += '<option>'+change+'</option>';
				}
	var min;
	for (i=0; i<60; i++)
				{
				change=("00" + i).slice(-2);
				min += '<option>'+change+'</option>';
				}

	var sel1 = '<select id="'+name+'1">';
	sel1 += hour;
	sel1 += '</select>';
	sel1 += ':';
	sel1 += '<select id="'+name+'2">';
	sel1 += min;
	sel1 += '</select>';

return sel1;
}

function settime(){	
	typ = document.getElementById('timetyps').value;
	//alert(typ)
	var ret;
	if ( typ =='typ0'){
		return;
	}
	
	if ( typ =='typ1'){
		// exakte Zeitangabe
		hh = document.getElementById('normal1').value;
		mm = document.getElementById('normal2').value;
		// tag
		dd = document.getElementById('day1day').value;
		ret = '['+hh+':'+mm+dd+']';
		//alert(ret);
	}
	
	if ( typ =='typ2'){
		// exakte Zeitangabe
		// zeitpunkt 1
		hh = document.getElementById('zufall1').value;
		mm = document.getElementById('zufall2').value;
		// zeitpunkt 2
		hh1 = document.getElementById('zufall11').value;
		mm1 = document.getElementById('zufall12').value;
		//  tag
		dd1 = document.getElementById('zufal3day').value;
		ret = '[?'+hh+':'+mm+'-'+hh1+':'+mm1+dd1+']';
		//alert(ret);
	}
	
	if ( typ =='typ3'){
		// exakte Zeitangabe
		// zeitpunkt 1
		hh = document.getElementById('periodic11').value;
		mm = document.getElementById('periodic12').value;
		// zeitpunkt 2
		hh1 = document.getElementById('periodic31').value;
		mm1 = document.getElementById('periodic32').value;
		//  tag
		dd1 = document.getElementById('periodic4day').value;
		// intrtvall
		intervallhh=document.getElementById('periodic1').value;
		intervallmm=document.getElementById('periodic2').value;
		
		// [00:02*04:10-06:30] 
		ret = '['+intervallhh+':'+intervallmm+'*'+hh+':'+mm+'-'+hh1+':'+mm1+dd1+']';
		// alert(ret);
	}
	
	
	settyp(ret,'7step','2');

return;
}

