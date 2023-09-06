// MSwitch_Wizard.js
// Autor:Byte09
// #########################

   window.addEventListener("error", fehlerbehandlung);
    function fehlerbehandlung (errorEvent) {
      var fehler = "Fehlermeldung:\n" + errorEvent.message + "\n" + errorEvent.filename + "\n" + errorEvent.lineno;
      zeigeFehler(fehler);
      errorEvent.preventDefault();
    }

    function zeigeFehler(meldung) {
      alert(meldung);
    }
 
	var version = 'V6.3';
	var jump="nojump";
	const Devices = [];
	const WIZARDVARS = [];
	const ATTRS = [];
	const GROUPS = [];
	const GROUPSCMD = [];
	var defineddevices= new Array;
	var PREASSIGMENT ="";
	var result= 0; // wird für waittimer in templates gebraucht
    var template;
	var nosave =0;
	var monitorid = "eventcontrol";
	var info = '';
	var logging ='off';
	var observer;
	var target;
	var lastevent;
	var show = 'off';
	var offtime =50;
	var sets = new Object();
	var preconfparts = new Array;
	var preconfpartsname = new Array;
	var preconfpartshelp = new Array;
	var style ="style='display:none'";
//var o =[];
	var configstart = [
	'#V Version',
	'#VS V6.3',
	'#S .First_init -> done',
	'#S .Trigger_off -> no_trigger',
	'#S .Trigger_cmd_off -> no_trigger',
	'#S .Trigger_device -> no_trigger',
	'#S .Trigger_log -> off',
	'#S .Trigger_on -> no_trigger',
	'#S .Trigger_cmd_on -> no_trigger',
	'#S .Trigger_condition -> ',
	'#S .V_Check -> V6.3',
	'#S .Device_Events -> no_trigger',
	'#S .Device_Affected -> no_device',
	'#S .Trigger_time_1 -> ',
	'#S .Trigger_time_2 -> ',
	'#S .Trigger_time_3 -> ',
	'#S .Trigger_time_4 -> ',
	'#S .Trigger_time_5 -> ',
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
	

	var configtemplate = [
	'#V Version',
	'#VS V6.3',
	'#S .First_init -> done',
	'#S .Trigger_off -> no_trigger',
	'#S .Trigger_cmd_off -> no_trigger',
	'#S .Trigger_device -> no_trigger',
	'#S .Trigger_log -> off',
	'#S .Trigger_on -> no_trigger',
	'#S .Trigger_cmd_on -> no_trigger',
	'#S .Trigger_condition -> ',
	'#S .V_Check -> V6.0',
	'#S .Device_Events -> no_trigger',
	'#S .Device_Affected -> no_device',
	'#S .Trigger_time_1 -> ',
	'#S .Trigger_time_2 -> ',
	'#S .Trigger_time_3 -> ',
	'#S .Trigger_time_4 -> ',
	'#S .Trigger_time_5 -> ',
	'#S .Device_Affected_Details_new -> '];

	var emptydevice = [
	'',
	'#[NF]no_action',
	'#[NF]no_action',
	'#[NF]',
	'#[NF]',
	'#[NF]delay1',
	'#[NF]delay1',
	'#[NF]00:00:00',
	'#[NF]00:00:00',
	'#[NF]',
	'#[NF]',
	'#[NF]undefined',
	'#[NF]undefined',
	'#[NF]1',
	'#[NF]0',
	'#[NF]',
	'#[NF]0',
	'#[NF]0',
	'#[NF]1',
	'#[NF]0'];

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
	
	if (document.getElementById('bank12').value == "pause")
	{
		return;
	}
	
	if (document.getElementById('bank12').value == "clear")
	{
		document.getElementById('bank12').value="";

		o=[];
	}
	
	var names = test.split(" ");
	
	var i = 0;
	var len =  names.length;
	for (i; i<len; i++)
	
		{
	var test =  names[i];
	
	document.getElementById('bank6').value=test;
	if(o[test]){continue;}
	var event = test.split(':');
	var newevent =  event[1]+':'+event[2]
	document.getElementById('bank7').value=event[0];
	document.getElementById('bank8').value=event[0];
		
	if ( event[0] != document.getElementById('bank1').value && document.getElementById('bank1').value != "all_events")
		{
			document.getElementById('bank4').value=document.getElementById('bank1').value;
			document.getElementById('bank2').value=event[0];
			continue;
		}
	if (logging == 'off')
		{ 
			continue;
		}
		
	if ( document.getElementById('bank1').value == "all_events")
		{	
		
		newevent =event[0]+':'+newevent;
		
		}
	lastevent=newevent;
	o[test] = test;		
	// eintrag in dropdown und fenster ausblenden
	newselect = $('<option value="'+newevent+'">'+newevent+'</option>');
	$(newselect).appendTo('#6step');

	// umwandlung des objekts in standartarray
	var a3 = Object.keys(o).map(function (k) { return o[k];})
	// array umdrehen
	a3.reverse();
	$( '#'+monitorid ).text( '' );
	var i;
	for (i = 0; i < 30; i++) 
		{
		if (a3[i])
			{
			var newselect = $('<option value=\"'+a3[i]+'\">'+a3[i]+'</option>');
			$(newselect).appendTo('#'+monitorid ); 
			}
		} 
		}
  });    
});

//####################################################################################################

function eventmonitorstop(){
	if (observer){
		FW_cmd(FW_root+'?cmd=set '+devicename+' notifyset no_trigger &XHR=1', function(data){})
		observer.disconnect();
	}	
	return;
}

function eventmonitorstart(){
	//alert("monitor start");
	inhalt1= document.getElementById('bank1').value;
	FW_cmd(FW_root+'?cmd=set '+devicename+' notifyset '+inhalt1+' &XHR=1', function(data){})
	var newselect = $('<option value="Event wählen">Event wählen:</option>');
	$(newselect).appendTo('#6step');
	observer.observe(target, config);
	return;
}

function clearmonitor(){
document.getElementById('eventcontrol1').innerHTML=""; 
document.getElementById('bank12').value="clear";
}

function playmonitor(){
document.getElementById('bank12').value="";
}

function pausemonitor(){
document.getElementById('bank12').value="pause";
return;
}

function closeall(){
		logging ='off';
		o = new Object();
		eventmonitorstop()
		document.getElementById('monitor').style.display='none';
		return;
}
	
// hauptfenster wählen
function conf(typ,but){
	eventmonitorstop()
	closeall();
	document.getElementById('help').innerHTML = '';	
	document.getElementById('importAT').style.display='none';
	document.getElementById('importNOTIFY').style.display='none';
	document.getElementById('importCONFIG').style.display='none';
	document.getElementById('importWIZARD').style.display='none';
	document.getElementById('importPRECONF').style.display='none';
	document.getElementById('importTemplate').style.display='none';
	document.getElementById('config').style.backgroundColor='';
	document.getElementById('importat').style.backgroundColor='';
	document.getElementById('importnotify').style.backgroundColor='';
	document.getElementById('importpreconf').style.backgroundColor='';
	document.getElementById('importTEMPLATE').style.backgroundColor='';
	document.getElementById('empty').style.display='none';
	document.getElementById(typ).style.display='block';
	document.getElementById(but).style.backgroundColor='#ffb900';
	document.getElementById('showtemplate').style.display='none';

	if (but == 'config'){
		// neustart wizard
		startconfig();
	}
	
	if (but == 'importat'){
	// neustart wizard
	startimportat();
	}
	
	if (but == 'importnotify'){
	// neustart wizard
	startimportnotify();
	}
	
	if (but == 'importpreconf'){
	// neustart wizard
	startimportpreconf();
	}
	return;
}	
	
function start1(name){
	eventmonitorstop();
	// this code will run after all other $(document).ready() scripts
    // have completely finished, AND all page elements are fully loaded.
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
	document.getElementById('mode').innerHTML += '<br>Wizard Version:'+version+'<br>Info:'+info;
	document.getElementById('mode').innerHTML += '<small><br>Templatefiles: '+templatefile;
	document.getElementById('mode').innerHTML += '<small><br>Preconffile: '+preconffile;
		
		// fülle configfenster

	document.getElementById('importAT').style.display='none';
	document.getElementById('importNOTIFY').style.display='none';
	document.getElementById('importCONFIG').style.display='none';
	document.getElementById('importWIZARD').style.display='none';
	document.getElementById('importPRECONF').style.display='none';
	document.getElementById('importTemplate').style.display='none';
	document.getElementById('empty').style.display='none';
	document.getElementById('help').innerHTML ="";
	document.getElementById('config').style.backgroundColor='';
	document.getElementById('importat').style.backgroundColor='';
	document.getElementById('importnotify').style.backgroundColor='';
	document.getElementById('importpreconf').style.backgroundColor='';
	document.getElementById('importTEMPLATE').style.backgroundColor='';
	setTimeout(function() {

}, 50);


if (templatesel != 'no'){
var targ = document.getElementById('templatefile');
 for (i = 0; i < targ.options.length; i++)
		{
		if (targ.options[i].value == templatesel)
		{
			targ.options[i].selected = true
			loadtemplate();
			break;
		}
		}
	}
}

function reset() {
	var nm = devicename;
	var  def = nm+' reset_device checked';
	location = location.pathname+'detail='+devicename+'&cmd=set '+addcsrf(def);
	return;
	}
	
	
	
	/*
function XXXmakeconfig(){
	if (document.getElementById('first').value == 'time'){
		// ändere config für timeevent
		string = document.getElementById('2').value;
		// ersetze dp durch #[dp]
		string = string.replace(/:/gi,"#[dp]");
		configstart[13] ='#S .Trigger_time -> on~off~ononly'+ string +'~offonly~onoffonly';
	}

	if (document.getElementById('first').value == 'event'){
		// ändere config für triggerevent
		configstart[5] ='#S .Trigger_device -> '+ document.getElementById('3').value;
		configstart[8] ='#S .Trigger_cmd_on -> '+ document.getElementById('5').value;
	}
	
	// ############ nur für volle befehlseingabe
	// affected devices und befehl
	
	if (document.getElementById('a11').value == 'FreeCmd')
	{
	// nur für freie befehlseingabe
	var cmdstring = document.getElementById('tra23end').value;
	configstart[12] ='#S .Device_Affected -> '+ document.getElementById('a11').value +'-AbsCmd1';
    var newcmdline = '#S .Device_Affected_Details -> '+ document.getElementById('a11').value +'-AbsCmd1'+'#[NF]undefined#[NF]cmd#[NF]'+cmdstring+'#[NF]#[NF]delay1#[NF]delay1#[NF]00:00:00#[NF]00:00:00#[NF]#[NF]#[NF]undefined#[NF]undefined#[NF]1#[NF]0#[NF]#[NF]0#[NF]0#[NF]1#[NF]0';
	configstart[29]=newcmdline;
	}
	else{
	// nur für definierte befehlseingabe
	configstart[12] ='#S .Device_Affected -> '+ document.getElementById('a11').value +'-AbsCmd1';
	// befehl aufteilen
	savedcmd = document.getElementById('tra33end').value;
	cmdarray= savedcmd.split(" ");
	if (cmdarray[1] != " "){
	secondstring = cmdarray[1];
	}
	if (cmdarray[2] != " "){
	secondstring = cmdarray[2];
	}
    var newcmdline = '#S .Device_Affected_Details -> '+ document.getElementById('a11').value +'-AbsCmd1'+'#[NF]'+cmdarray[0]+'#[NF]no_action#[NF]'+secondstring+'#[NF]#[NF]delay1#[NF]delay1#[NF]00:00:00#[NF]00:00:00#[NF]#[NF]#[NF]undefined#[NF]undefined#[NF]1#[NF]0#[NF]#[NF]0#[NF]0#[NF]1#[NF]0';
	configstart[29]=newcmdline;
		
	}
	fillconfig('rawconfig')
	return;
} 


*/

function fillconfig(name){
	
	//alert(name);
	
	var showconf='';
	configstart[0] = '#V '+mVersion;
	conflines =  configstart.length ;
	for (i = 0; i < conflines; i++) 
		{
			showconf = showconf+configstart[i]+'\n';
		}
	document.getElementById(name).innerHTML = showconf;
	}


function checkaktformat(arg){

	inhalt = document.getElementById(arg).value;
	var modus = "";
	var newmodus = "";
	
    treffer = inhalt.match(/[A-Zg-z]/g);
	if (treffer!=null)
	{
		document.getElementById('convert').value="Konvertiere zu HEX";
		document.getElementById('saveconf1').value="Konfiguration speichern (nur im HEx-Format möglich)";
		document.getElementById('saveconf1').disabled = true;
		document.getElementById('saveconf1').style.background='#888888';
	}
	else
	{
		document.getElementById('convert').value="Konvertiere zu STRING";
		document.getElementById('saveconf1').value="Konfiguration speichern";
		document.getElementById('saveconf1').disabled = false;
		document.getElementById('saveconf1').style.background='';
	}
	return; 
}


function checkformat(arg){
	//alert('checkformat');
	inhalt = document.getElementById(arg).value;
	
	var modus = "";
	var newmodus = "";

treffer = inhalt.match(/[A-Zg-z]/g);

	if (treffer!=null)
	{
	modus="string";
	newmodus="hex";
	document.getElementById('convert').value="Konvertiere zu STRING";
	document.getElementById('saveconf1').value="Konfiguration speichern";
	
	document.getElementById('saveconf1').disabled = false;
	document.getElementById('saveconf1').style.background='';
	newinhalt = str2hex(inhalt);
	}
	else
	{
	modus = "hex";
	newmodus="string";
	
	document.getElementById('convert').value="Konvertiere zu HEX";
	document.getElementById('saveconf1').value="Konfiguration speichern (nur im HEx-Format möglich)";
	
	document.getElementById('saveconf1').disabled = true;
	document.getElementById('saveconf1').style.background='#888888';
	newinhalt = hext2str(inhalt);	
	}

	document.getElementById(arg).value=newinhalt;
	return;
}


	function str2hex(arg){

	var result = "";
    for (i=0; i<arg.length; i++) {
        hex = arg.charCodeAt(i).toString(16);
        result += ("0"+hex).slice(-2)+" ";
    }
	
/* 	
2021.10.23 17:32:50 0:ä Ã¤ -> c3 a4 
2021.10.23 17:32:50 0:ö Ã¤ -> c3 b6 
2021.10.23 17:32:50 0:ü Ã¤ -> c3 bc 
2021.10.24 06:03:46 0:Ä Ã„ -> c3 84   c4
2021.10.24 06:03:46 0:Ö Ã– -> c3 96   d6
2021.10.24 06:03:46 0:Ü Ãœ -> c3 9c   dc
2021.10.24 06:03:46 0:ß ÃŸ -> c3 9f    df*/   

	result = result.replace(/e4/g,'c3 a4');
	result = result.replace(/f6/g,'c3 b6');
	result = result.replace(/fc/g,'c3 bc');
	result = result.replace(/c4/g,'c3 84');
	result = result.replace(/d6/g,'c3 96');
	result = result.replace(/dc/g,'c3 9c');
	result = result.replace(/df/g,'c3 9f');
	result = result.replace(/ /g,'');

return result;
}


function hext2str(arg){
	
	var j;
    var hexes = arg.match(/.{1,2}/g) || [];
    var result = "";
    for(j = 0; j<hexes.length; j++) {
        result += String.fromCharCode(parseInt(hexes[j], 16));
    }
	return result;
}


function saveconfig(name,mode){
	if (mode == 'wizard'){
	// makeconfig();
	}
	conf = document.getElementById(name).value;
	var nm = devicename;
	var def = nm+' saveconfig '+encodeURIComponent(conf);
	location = location.pathname+'?detail='+devicename+'&cmd=set '+addcsrf(def);
	return;
}

function devicelist(id,name,script,flag){
	ret="";
	
	if (script == "no_script"){
		ret = '<select id =\"'+id+'\" name=\"'+name+'\" >';
	}
	else{
		ret = '<select id =\"'+id+'\" name=\"'+name+'\" onchange=\"javascript: '+script+'(this.value,id,name)\">';
	}
	// erstelle geräteliste'+id+'+name+'
	count =0;
	ret +='<option value=\"select\">bitte wählen:</option>';
	if (flag == '1' || flag =="3"){
		ret +='<option value=\"free\">freie Befehlseingabe</option>';
	}
	
	if (flag == '2'){
		ret +='<option value=\'all_events\'>GLOBAL</option>';
	}
	
	for (i=count; i<(len); i++)
		{
		if (flag == '1'){
			ret +='<option value='+i+'>'+devices[i]+'</option>';
			}
		else{
			
			ret +='<option value='+devices[i]+'>'+devices[i]+'</option>';
			}
		}
			
		var test = GROUPS.length ;
		for (i=count; i<test; i++)
		{

			ret +='<option value='+GROUPS[i]+'>'+GROUPS[i]+' (MSwitch Gruppe)</option>';
		} 
	ret +='</select>';
	return ret;
}

// ############################

function devicelistmultiple(id,name){
	ret="";
	ret = '<select style="width: 50em;" size="10" multiple id =\"'+id+'\" name=\"'+name+'\" onchange=\"javascript: takeselected(id,name)\">';
	count =0;
	for (i=count; i<len; i++)
		{
		ret +='<option value='+devices[i]+'>'+devices[i]+'</option>';
		}
	ret +='</select>';
	return ret;	
}




function devicelistone(id,name){
	ret="";
	ret = '<select style="width: 50em;" size="10" id =\"'+id+'\" name=\"'+name+'\" onchange=\"javascript: takeselected(id,name)\">';
	count =0;
	for (i=count; i<len; i++)
		{
		ret +='<option value='+devices[i]+'>'+devices[i]+'</option>';
		}
	ret +='</select>';
	return ret;	
}



/// #######################

function takeselected(id,name){
	var values = $('#'+id).val();
	document.getElementById('input').value = values;
	return;
}

/// #######################

function takeselectedmultiple(id,name){
	var values = $('#'+id).val();
	var values1 = values.join("|");
	document.getElementById('input').value = values1;
	return;
}

//#####################

function attrlist(id,name,attr){
ret="";
attrset = (ownattr[attr]).split(",");
if (attrset == "textField-long"){
ret += '<textarea id =\"'+id+'\" name=\"'+name+'\" cols="40" rows="4"></textarea>';
}else if(attrset == ""){	
ret += '<input id =\"'+id+'\" name=\"'+name+'\" value=\"\">';
}else{
ret += '<select id =\"'+id+'\" name=\"'+name+'\" >';
	var anzahl = attrset.length;
	for (i=0; i<anzahl; i++)
		{
		ret +='<option value='+attrset[i]+'>'+attrset[i]+'</option>';
		}
ret +='</select>';
}
return ret;
}

function startconfig(){
	var html='<table><tr><td style=\"text-align: center; vertical-align: middle;\">';
	html+='<textarea onpaste=\"setTimeout(function() {checkaktformat(\'rawconfig3\');}, 0);\" id=\"rawconfig3\" style=\"width: 950px; height: 600px\"></textarea>';
	//html+='<textarea id=\"rawconfig4\" style=\"width: 950px; height: 600px\"></textarea>';
	html+='</td>';
	html+='</tr>';
	html+='<tr><td style=\"text-align: center; vertical-align: middle;\">';
	// html+='<input name=\"\" id=\"\" type=\"button\" value=\"test\" onclick=\"javascript: checkaktformat(\'rawconfig3\')\"\">';
	html+='<input name=\"convert\" id=\"convert\" type=\"button\" value=\"Konvertiere zu HEX\" onclick=\"javascript: checkformat(\'rawconfig3\')\"\">';
	html+='&nbsp;';
	html+='<input style=\"background: #888888;\" disabled name=\"saveconf\" id=\"saveconf1\" type=\"button\" value=\"Konfiguration speichern (nur im HEX-Format möglich)\" onclick=\"javascript: saveconfig(\'rawconfig3\')\"\">';
	html+='</td>';
	html+='</tr>';
	html+='</table>';
	document.getElementById('importCONFIG').innerHTML = html;
	document.getElementById('help').innerHTML = 'Hier können MSwitch_Konfigurationsdateien eingespielt werden. Dieses sollte nur von erfahrenen Usern genutzt werden. Es findet keine Prüfung auf Fehler statt und fehlerhafte Dateien können Fhem zum Absturz bringen.<br>Die vorgegebene Datei entspricht einem unkonfigurierten MSwitch';
	fillconfig('rawconfig3');
	return;
}

function startimportat(){
	script = 'setat';
	ret = '<select id =\"\" name=\"\" onchange=\"javascript: '+script+'(this.value)\">';
	ret +='<option value=\"empty\">bitte zu importierendes AT wählen</option>';
	count =0;
	var len = at.length;
	for (i=count; i<len; i++)
		{
			ret +='<option value='+at[i]+'>'+at[i]+'</option>';
		}	 
	ret +='</select>';
	var html='';
	html+='<table border=\"0\">';
	html+='<tr><td style=\"vertical-align: top;\">';
	html+='<table border=\"0\">';
	html+='<tr><td colspan=\"3\">';
	html+='';
	html+='</td></tr>';
	html+='<tr><td style=\"text-align: center;\">';
	html+=ret;
	html+='<br><br><input disabled name=\"\" id=\"sat\" type=\"button\" value=\"importiere dieses AT\" onclick=\"javascript: saveat()\"\">';
	html+='</td>';
	html+='<td>';
	html+='<table border=\"0\">';
	html+='<tr>'
	html+='<td>Comand: </td>';
	html+='<td>';
	html+='<textarea id ="def" cols="40" rows="2"></textarea>';
	html+='</td></tr>';
	html+='<tr>'
	html+='<td>Timespec: </td>';
	html+='<td>';
	html+='<textarea id ="defcmd" cols="40" rows="2"></textarea>';
	html+='</td></tr>';
	html+='<tr>'
	html+='<td>Steuerflag </td>';
	html+='<td>';
	html+='<textarea id ="deftspec" cols="40" rows="2"></textarea>';
	html+='</td></tr>';
	html+='<tr>'
	html+='<td>defflag </td>';
	html+='<td>';
	html+='<textarea id ="defflag" cols="40" rows="2"></textarea>';
	html+='</td></tr>';
	html+='<tr>'
	html+='<td>Triggertime: </td>';
	html+='<td>';
	html+='<textarea id ="trigtime" cols="40" rows="2"></textarea>';	
	html+='</td></tr>';
	html+='</table>';
	html+='</td>';
	html+='</tr>';
	html+='<tr><td colspan=\"3\" style=\"text-align: center; vertical-align: middle;\">';
	html+='</td>';
	html+='</tr>';
	html+='</table>';
	html+='</td>';
	html+='<td>';
	html+='<textarea disabled id=\'rawconfig1\' style=\'width: 450px; height: 600px\'></textarea>';
	html+='</td>';
	html+='</tr>';
	html+='</table>';
	
	document.getElementById('help').innerHTML = 'Es können nur periodisch wiederkehrende ATs importiert werden und nur diese werden zur Auswahl angeboten. Mswitch ist für einmalige Ats ungeeignet. Bei importiertem At berücksichtigt MSwitch keine Sekundenangaben.<br>Es ist darauf zu achten , das nach dem Import sowohl das AT, als auch das MSwitch aktiv sind und eines der beiden deaktiviert werden sollte.';
	document.getElementById('importAT').innerHTML = html;
	document.getElementById('sat').style.backgroundColor='#ff0000';
	fillconfig('rawconfig1');
	return;
}

function setat(name){
	if (name == "empty"){
		document.getElementById('sat').disabled = true;
		document.getElementById('def').value='';
		document.getElementById('defcmd').value='';
		document.getElementById('deftspec').value='';
		document.getElementById('defflag').value='';
		document.getElementById('trigtime').value='';
		document.getElementById('sat').style.backgroundColor='#ff0000';
		return;
	}
	FW_cmd(FW_root+'?cmd=set '+devicename+' loadat '+name+' &XHR=1', function(data){setat1(data)})
}

	
function setat1(name){	
atarray= name.split("\[TRENNER\]");
	document.getElementById('sat').style.backgroundColor='';
	document.getElementById('sat').disabled = false;
	document.getElementById('def').value=atarray[0];
	document.getElementById('defcmd').value=atarray[1];
	document.getElementById('deftspec').value=atarray[2];
	defflag = atarray[0].substr(0,1);
	document.getElementById('defflag').value=defflag;
	document.getElementById('trigtime').value=atarray[3];
	return;
}

function saveat(){
	var cmdstring = document.getElementById('defcmd').value;
	cmdstring = cmdstring.replace(/\n/g,'#[nl]');
	cmdstring = cmdstring.replace(/ /g,'#[sp]');
	
	/*cmdstring = cmdstring.replace(/:/g,'#[dp]');
	cmdstring = cmdstring.replace(/;/g,'#[se]');
	cmdstring = cmdstring.replace(/\t/g,'#[tab]');
	cmdstring = cmdstring.replace(/\\/g,'#[bs]');
	cmdstring = cmdstring.replace(/,/g,'#[ko]');
	cmdstring = cmdstring.replace(/\|/g,'#[wa]');
	cmdstring = cmdstring.replace(/\|/g,'#[wa]');
	
	*/
	
	configstart[12] ='#S .Device_Affected -> FreeCmd-AbsCmd1';
    var newcmdline = '#S .Device_Affected_Details_new -> FreeCmd-AbsCmd1'+'#[NF]undefined#[NF]cmd#[NF]'+cmdstring+'#[NF]#[NF]delay1#[NF]delay1#[NF]00:00:00#[NF]00:00:00#[NF]#[NF]#[NF]undefined#[NF]undefined#[NF]1#[NF]0#[NF]#[NF]0#[NF]0#[NF]1#[NF]0';

	configstart[29]=newcmdline;
	
	if (document.getElementById('defflag').value == "*")
	{
		string = document.getElementById('deftspec').value;
		//string = string.replace(/:/gi,"#[dp]");
		configstart[15] ='#S .Trigger_time_3 -> TIME='+ string;
	}
	
	if (document.getElementById('defflag').value == "+")
	{
		string = document.getElementById('deftspec').value;
		string = 'REPEAT='+string+'*00:01-23:59';
		//string = string.replace(/:/gi,"#[dp]");
		configstart[15] ='#S .Trigger_time_3 ->'+ string;
	}
	
	fillconfig('rawconfig1');
	inhalt=document.getElementById('rawconfig1').value;
	inhalthex= str2hex(inhalt);
	document.getElementById('rawconfig1').value=inhalthex;
	saveconfig('rawconfig1');
	return;
}


function startimportnotify(){
	script = 'setnotify';
	ret = '<select id =\"\" name=\"\" onchange=\"javascript: '+script+'(this.value)\">';
	ret +='<option value=\"empty\">bitte zu importierendes NOTIFY wählen</option>';
	count =0;
	len = notify.length;
	for (i=count; i<len; i++)
		{
			ret +='<option value='+notify[i]+'>'+notify[i]+'</option>';
		}
	ret +='</select>';
	var html='';
	html+='<table border=\"0\">';
	html+='<tr><td style=\"vertical-align: top;\">';
	html+='<table border=\"0\">';
	html+='<tr><td colspan=\"3\">';
	html+='</td></tr>';
	html+='<tr><td style=\"text-align: center;\">';
	html+=ret;
	html+='<br><br><input disabled name=\"\" id=\"not\" type=\"button\" value=\"import this NOTIFY\" onclick=\"javascript: savenot()\"\">';
	html+='</td>';
	html+='<td>';
	html+='<table border=\"0\">';
	html+='<tr>'
	html+='<td>Definition: </td>';
	html+='<td>';
	html+='<textarea id ="defnotify" cols="40" rows="2"></textarea>';
	html+='</td></tr>';
	html+='<tr>'
	html+='<td>Comand: </td>';
	html+='<td>';
	html+='<textarea id ="comandnotify" cols="40" rows="2"></textarea>';
	html+='</td></tr>';
	html+='<tr>'
	html+='<td>Trigger-Device: </td>';
	html+='<td>';
	html+='<textarea id ="trigdev" cols="40" rows="2"></textarea>';
	html+='</td></tr>';
	html+='<tr>'
	html+='<td>Trigger-Event: </td>';
	html+='<td>';
	html+='<textarea id ="trigevent" cols="40" rows="2"></textarea>';
	html+='</td></tr>';
	html+='<tr>'
	html+='<td>Control: </td>';
	html+='<td>';
	html+='<textarea id ="globaltest" cols="40" rows="2"></textarea>';	
	html+='</td></tr>';
	html+='<tr>'
	html+='<td>Control: </td>';
	html+='<td>';
	html+='<textarea id ="notifytest" cols="40" rows="2"></textarea>';
	html+='</td></tr>';
	html+='</table>';
	html+='</td>';
	html+='</tr>';
	html+='<tr><td colspan=\"3\" style=\"text-align: center; vertical-align: middle;\">';
	html+='</td>';
	html+='</tr>';
	html+='</table>';
	html+='</td>';
	html+='<td>';
	html+='<textarea disabled id=\'rawconfig2\' style=\'width: 450px; height: 600px\'></textarea>';
	html+='</td>';
	html+='</tr>';
	html+='</table>';
	document.getElementById('help').innerHTML = 'Es ist darauf zu achten, das nach dem Import sowohl das Notify, als auch das MSwitch aktiv sind und eines der beiden deaktiviert werden sollte.';
	document.getElementById('importNOTIFY').innerHTML = html;
	document.getElementById('not').style.backgroundColor='#ff0000';
	fillconfig('rawconfig2');
	return;
}


function setnotify(name){
		document.getElementById('not').disabled = true;
		document.getElementById('not').style.backgroundColor='#ff0000';
		document.getElementById('defnotify').value='';
		document.getElementById('comandnotify').value='';
		document.getElementById('trigdev').value='';
		document.getElementById('trigevent').value='';	
		document.getElementById('globaltest').value='';	
		document.getElementById('notifytest').value='';	
	
	if (name == "empty"){
		return;
		}
		FW_cmd(FW_root+'?cmd=set '+devicename+' loadnotify '+name+' &XHR=1', function(data){setnotify1(data)})
}
	
	
function setnotify1(name){
	document.getElementById('not').style.backgroundColor='';
	document.getElementById('not').disabled = false;
	document.getElementById('defnotify').value=name;
	var first =  name.indexOf(" ");
	var laenge = name.length;
	var cmd = name.substring(first+1,laenge);
	document.getElementById('comandnotify').value=cmd;
	var trigger = name.substring(0,first);

	var mapp = trigger.match(/^(\()(.*)(\))/);
	if (mapp!=null && mapp.length!=0)
		{	
		trigger=mapp[0];
		// voll globales triggern
		// im cmd eventausdrücke auf mswitchausdrücke mappen !!!
		trigger = trigger.replace(/:\./g,':.*');
		trigger = "\"\$EVENT\" =~m/"+trigger+"/";
		document.getElementById('globaltest').value=trigger;
		document.getElementById('trigevent').value=".*";
		document.getElementById('trigdev').value="all_events";
		return;
		}
	
	var mapp1 = trigger.match(/(.*):(.*:.*)/);
	
	
	
	if (mapp1!=null && mapp1.length!=0)
		{	
		var tdevice = mapp1[1];
		var tevent = mapp1[2];
		tevent = tevent.replace(/:\./g,':');
		document.getElementById('trigdev').value=tdevice;
		document.getElementById('trigevent').value=tevent;
		return;	
		}
		else
		{
		var mapp2 = trigger.match(/(.*):(.*)/);
		var tdevice = mapp2[1];
		var tevent = mapp2[2];
		tevent = tevent.replace(/:\./g,':');
		document.getElementById('trigdev').value=tdevice;
		document.getElementById('trigevent').value=tevent;
		}
	return;	
}


function savenot(){
	var cmdstring = document.getElementById('comandnotify').value;
	//return;
	// funktionsfähige ersetzung für detailübertragung
	cmdstring = cmdstring.replace(/\n/g,'#[nl]');
	cmdstring = cmdstring.replace(/ /g,'#[sp]');
	
	
	
	/*
	cmdstring = cmdstring.replace(/:/g,'#[dp]');
	cmdstring = cmdstring.replace(/;/g,'#[se]');
	cmdstring = cmdstring.replace(/\t/g,'#[tab]');
	cmdstring = cmdstring.replace(/\\/g,'#[bs]');
	cmdstring = cmdstring.replace(/,/g,'#[ko]');
	cmdstring = cmdstring.replace(/\|/g,'#[wa]');
	cmdstring = cmdstring.replace(/\|/g,'#[wa]');
	*/
	
	
	
	// hier notify to mswitch mappen
	// EVENT - EVTPART3
	// NAME
	//
	cmdstring = cmdstring.replace(/\$NAME/g,'$NAME');
	cmdstring = cmdstring.replace(/\$EVENT/g,'$EVTPART3');
	
	document.getElementById('notifytest').value=cmdstring;
	configstart[12] ='#S .Device_Affected -> FreeCmd-AbsCmd1';
    var newcmdline = '#S .Device_Affected_Details_new -> FreeCmd-AbsCmd1'+'#[NF]undefined#[NF]cmd#[NF]'+cmdstring+'#[NF]#[NF]delay1#[NF]delay1#[NF]00:00:00#[NF]00:00:00#[NF]#[NF]#[NF]undefined#[NF]undefined#[NF]1#[NF]0#[NF]#[NF]0#[NF]0#[NF]1#[NF]0';
	configstart[29]=newcmdline;
	configstart[5] ='#S .Trigger_device -> '+ document.getElementById('trigdev').value;
	
	var testevent = document.getElementById('trigevent').value.indexOf(":")
	if (testevent == -1 && document.getElementById('trigdev').value != 'global' && document.getElementById('trigevent').value != '.*')
	{
		configstart[8] ='#S .Trigger_cmd_on -> state:'+ document.getElementById('trigevent').value;
	}
	else{
		configstart[8] ='#S .Trigger_cmd_on -> '+ document.getElementById('trigevent').value;
	}
	
	if (document.getElementById('trigdev').value =="all_events")
	{
		configstart[26] ='#A MSwitch_Expert -> 1';
		configstart[9] ='#S .Trigger_condition -> '+document.getElementById('globaltest').value;
		configstart[28] ='#S .Trigger_Whitelist -> NAME!='+devicename;
	}
	
	fillconfig('rawconfig2');
	// hexumwandlung
	inhalt=document.getElementById('rawconfig2').value;
	
	
	//alert(inhalt);
	inhalthex= str2hex(inhalt);
	document.getElementById('rawconfig2').value=inhalthex;
	//return;
	saveconfig('rawconfig2');
	return;
}


function startimportpreconf(){
	FW_cmd(FW_root+'?cmd=set '+devicename+' loadpreconf &XHR=1', function(data){startimportpreconf1(data)})
	return;
}

function startimportpreconf1(data){
	preconf = data;
	
	preconfparts = preconf.split("#-NEXT-");
	
	
	
	
	var anzahl = preconfparts.length;
	var count =0;
	for (i=count; i<anzahl; i++)
		{
			
		//alert(i);	
			
		treffer = preconfparts[i].match(/#NAME.(.*?)(#\[NEWL\])/);
		help = preconfparts[i].match(/#HELP.(.*?)(#\[NEWL\])/);
		//alert(treffer);
		
		
		if (treffer == null) { 
		
	
		continue;
		}
		
		preconfparts[i] = (preconfparts[i].split(treffer[0]).join(''));
		
		
		preconfparts[i] = (preconfparts[i].split(help[0]).join(''));
		
		
		preconfparts[i] = preconfparts[i].replace(/#\[NEWL\]/gi,"\n");
		
		
		preconfpartsname.push(treffer[1]);
		
		preconfpartshelp.push(help[1]); 
		}

	script = 'setpreconf';
	ret = '<select id =\"\" name=\"\" onchange=\"javascript: '+script+'(this.value)\">';
	ret +='<option value=\"empty\">bitte Device wählen</option>';
	count =0;
	for (i=count; i<anzahl; i++)
		{
			ret +='<option value='+i+'>'+preconfpartsname[i]+'</option>';
		}
	ret +='</select>';
	var html='';
	html+='<table width=\"100%\" border=\"0\">';
	html+='<tr>';
	html+='<td width=\"100%\" style=\"vertical-align: top;\">';
	html+='';
	html+='<table width = \"100%\" border=\"0\">';
	html+='<tr>';
	html+='<td style=\"text-align: center; vertical-align: middle;\">';
	html+=ret;
	html+='<br><br><input disabled name=\"\" id=\"prec\" type=\"button\" value=\"importiere dieses MSwitch\" onclick=\"javascript: savepreconf()\"\">';
	html+='</td>';
	html+='</tr>';
	html+='<tr>';
	html+='<td id=\"infotext\" style=\"text-align: center; vertical-align: middle;\">';
	html+='&nbsp;';
	html+='</td>';
	html+='</tr>';
	html+='<tr>';
	html+='<td height=300 id=\"infotext1\" style=\"text-align: center;vertical-align: top;\">';
	html+='';
	html+='</td>';
	html+='</tr>';
	html+='<tr>';
	html+='<td id=\"infotext2\" style=\"text-align: center; vertical-align: middle;\">';
	html+='</td>';
	html+='</tr>';
	html+='</table>';
	html+='</td>';
	html+='<td>';
	html+='<textarea disabled id=\"rawconfig4\" style=\"width: 400px; height: 400px\"></textarea>';
	html+='</td>';
	html+='</tr>';
	html+='</table>';
	
	document.getElementById('help').innerHTML = 'Hier können vorkonfigurierte Mswitch-Devices importiert werden. Bei diesen müssen in der Regel keine weiteren Einstellungen mehr vorgenommen werden. Falls doch Änderungen notwendig sind wird im Device darauf hingewiesen.';
	document.getElementById('importPRECONF').innerHTML = html;
	document.getElementById('prec').style.backgroundColor='#ff0000';
	return;
} 

function setpreconf(name){
	if (name == "empty"){
		document.getElementById('rawconfig4').innerHTML = "";
		document.getElementById('prec').disabled = true;
		document.getElementById('prec').style.backgroundColor='#ff0000';
		return;
	}

		var testversion = preconfparts[name];
		var myRegEx = new RegExp('#VS.(V.*)');  
		treffer = testversion.match(myRegEx);
		
		//var testversion = preconfparts[name];
		var myRegEx = new RegExp('#CONF.(.*)');  
		config = testversion.match(myRegEx);
		
		
		
		if (treffer[1] != MSDATAVERSION)
		{
			var wrongversion =' <strong><u>Versionskonflikt:</u><br>Diese Version ist nicht für die aktuelle Datenstruktur vorgesehen \
			und kann nicht importiert werden.\
			<br>Bitte den Support kontaktieren.\
			<br>geforderte/benoetigte Version: '+MSDATAVERSION+'\
			<br>Deviceversion: '+treffer[1]+'\
			</strong><br><br>';
			document.getElementById('rawconfig4').innerHTML = "";
			document.getElementById('prec').disabled = true;
			document.getElementById('prec').style.backgroundColor='#ff0000';
			// document.getElementById('rawconfig4').innerHTML = preconfparts[name];
			
			document.getElementById('rawconfig4').innerHTML = config[1];
			
			
			document.getElementById('infotext1').innerHTML = wrongversion+preconfpartshelp[name];
			return;
		}

	document.getElementById('rawconfig4').innerHTML = config[1];
	document.getElementById('infotext1').innerHTML = preconfpartshelp[name];
	document.getElementById('prec').disabled = false;
	document.getElementById('prec').style.backgroundColor='';
}

// #################

function savepreconf(name){
	var html='';
	html+='<table width=\"100%\" border=\"0\">';
	
	html+='<tr>';
	html+='<td width=\"100%\" style=\"vertical-align: top;\">';
	html+='<center>Das Device wird importiert. Dieser Vorgang kann einen Moment dauern ...';
	html+='</td>';
	html+='</tr>';
	
		
	html+='<tr>';
	html+='<td width=\"100%\" style=\"vertical-align: top;\">';
	html+='<center>&nbsp;';
	html+='</td>';
	html+='</tr>';
	
	html+='';
	
	html+='<tr>';
	html+='<td width=\"100%\" style=\"vertical-align: top;\">';
	html+='<center>Seite wird nach erfolgtem Import automatisch mit der Detailansicht des Devices neu geladen.';
	html+='</td>';
	html+='</tr>';
	
	html+='';
	
	html+='<tr>';
	html+='<td width=\"100%\" style=\"vertical-align: top;\">';
	html+='<center>&nbsp;';
	html+='</td>';
	html+='</tr>';
	
	html+='</table>';

	mode = 'preconf';
	saveconfig('rawconfig4',mode);
	document.getElementById('importPRECONF').innerHTML = html;;
	return;
}

// #################

function decode(){
	var second = document.getElementById('decode1').value;
	second = second.replace(/\n/g,'#[nl]');
	second = second.replace(/:/g,'#[dp]');
	second = second.replace(/;/g,'#[se]');
	second = second.replace(/ /g,'#[sp]');
	second = second.replace(/\t/g,'#[tab]');
	second = second.replace(/\\/g,'#[bs]');
	second = second.replace(/,/g,'#[ko]');
	second = second.replace(/\|/g,'#[wa]');
	second = second.replace(/\|/g,'#[wa]');
	second = second.replace(/'/g,'#[st]');
	document.getElementById('decode1').value = second;
	return;
}

// #################

function encode(){
	var second = document.getElementById('decode1').value;
	second = second.replace(/#\[nl\]/g,'\n');
	 second = second.replace(/#\[dp\]/g,':');
	 second = second.replace(/#\[se\]/g,';');
	 second = second.replace(/#\[sp\]/g,' ');
	 second = second.replace(/#\[tab\]/g,'\t');
	 second = second.replace(/#\[bs\]/g,'\\');
	 second = second.replace(/#\[ko\]/g,',');
	 second = second.replace(/#\[wa\]/g,'|');
	 second = second.replace(/#\[st\]/g,'\'');
	document.getElementById('decode1').value = second;
	return;
}

// #################
function showkode(){
	if (document.getElementById('decode').style.display == "none"){
	document.getElementById('decode').style.display='block';
	}
	else
	{
		document.getElementById('decode').style.display='none';
	}
	return;
}
// #################

function toggletemplate(){
	if (document.getElementById('empty').style.display == "none"){
	document.getElementById('empty').style.display='block';
	document.getElementById('showtemplate').value="verberge Template";
	}
	else
	{
		document.getElementById('showtemplate').value="zeige Template";
		document.getElementById('empty').style.display='none';
	}
	return;
}

// TEMPLATE BELOW
//templatesteuerung
// #################

function savetemplate (){
	var tosave = document.getElementById('emptyarea').value;
	var templatename = document.getElementById('templatename').value;
	tosave = tosave.replace(/\n/g,'[EOL]'); // !!!
	tosave = tosave.replace(/;/g,'[SE]');
	tosave = tosave.replace(/ /g,'[SP]');
	tosave = tosave.replace(/#/g,'[RA]');
	tosave = tosave.replace(/\+/g,'[PL]');
	tosave = tosave.replace(/"/g,'[AN]');
	tosave = tosave.replace(/&/g,'[AND]');
	templatename = templatename.replace(/local\//g,'');
	var newname = "local / "+templatename;
	var newinhalt = "local/"+templatename;
	var targ = document.getElementById('templatefile');
	var found = "notfound";
	
  for (i = 0; i < targ.options.length; i++)
	{
		if (targ.options[i].value == newinhalt )
		{
			found = "found";
			targ.options[i].selected = true;	
		}
	}
	
	if (found == "notfound")
	{
	var number = targ.options.length;
	var option = new Option(newname, newinhalt);
    targ.options[number] = option;
	targ.options[number].selected = true;
	}

	FW_cmd(FW_root+'?cmd=set '+devicename+' savetemplate '+templatename+' '+tosave+'&XHR=1');
	return ;
}

// #################

function loadtemplate(){

	document.getElementById('help').innerHTML = '';	
	document.getElementById('importAT').style.display='none';
	document.getElementById('importNOTIFY').style.display='none';
	document.getElementById('importCONFIG').style.display='none';
	document.getElementById('importWIZARD').style.display='none';
	document.getElementById('importPRECONF').style.display='none';
	document.getElementById('importTemplate').style.display='block';
	document.getElementById('config').style.backgroundColor='';
	document.getElementById('importat').style.backgroundColor='';
	document.getElementById('importnotify').style.backgroundColor='';
	document.getElementById('importpreconf').style.backgroundColor='';
	document.getElementById('importTEMPLATE').style.backgroundColor='#ffb900';
	document.getElementById('showtemplate').value="zeige Template";
	defineddevices.length = 0;
	for (elem in INQ) {
		delete INQ[elem];
		}
	var html = '<table width="100%">';
	html += '<tr>'
	html += '<td width ="100%" id="importTemplate1" valign=top ></td>';
	html += '<td id="importTemplate2" style=\'display: none;\'>';
	html+='Configfile:<br><textarea disabled id=\"rawconfig10\" style=\"width: 400px; height: 400px\"></textarea>';
	html += '</td>';
	html += '</tr>';
	html += '</table>';
	document.getElementById('importTemplate').innerHTML = html;
	var file = document.getElementById('templatefile').value;
	document.getElementById('bank5').value='';
	document.getElementById('templatename').value=file;
	nosave=0;
	if (file == "empty_template")
	{
		document.getElementById('empty').style.display='block';
		var cookie = getCookieValue("Mswitch_template");
		if (cookie != "")
		{
			var Wert = cookie;  
			Wert=Wert.split("\[TRENNER\]");
			Wert=Wert.join("\n");
			document.getElementById('emptyarea').value=Wert;
			FW_okDialog("Templatedaten wurden aus letztem bearbeitetem Template wieder hergestellt");
		}

		document.getElementById('showtemplate').style.display='none';
		document.getElementById('execbutton').value="Template ausführen";
		nosave=1;
		return;
	}
	
	document.getElementById('empty').style.display='none';
	document.getElementById('showtemplate').style.display='block';
	file+=".txt";
	FW_cmd(FW_root+'?cmd=set '+devicename+' template '+file+'&XHR=1', function(data){filltemplate(data)})
	return;
}


// #################
function getCookieValue(a) {
   const b = document.cookie.match('(^|;)\\s*' + a + '\\s*=\\s*([^;]+)');
   return b ? b.pop() : '';
}

// #################
function filltemplate(data){

document.getElementById('emptyarea').value=data;
document.getElementById('execbutton').value="Template neu starten";
	starttemplate(data);
}

// mainloop aller lines
// #################

function schreibespeicher(aktline)
{
	if (aktline.length == "0")
		{
		return;
		}
	var inhalt = document.getElementById('bank5').value;
	inhalt = aktline+"\n"+inhalt;
	document.getElementById('bank5').value=inhalt;
	return;
}

// #################

function saveempty(){
	
	
	alert("saveempty");
	
	conf = document.getElementById('rawconfig10').value;
	conf = conf.replace(/\n/g,'#[EOL]');
	conf = conf.replace(/#\[REGEXN\]/g,'\\n');
	conf = conf.replace(/:/g,'#c[dp]');
	conf = conf.replace(/;/g,'#c[se]');
	conf = conf.replace(/ /g,'#c[sp]');
	conf = changevar(conf);
	var nm = devicename;
	var def = nm+' saveconfig '+encodeURIComponent(conf);
	location = location.pathname+'?detail='+devicename+'&cmd=set '+addcsrf(def);
	return;
}

// #################

function execempty(){
	if (nosave =="1"){
	var jetzt = new Date();
	var Verfall = 1000 * 60 * 60 *12;
	var Auszeit = new Date(jetzt.getTime() + Verfall);
	var Wert = document.getElementById('emptyarea').value.split("\n");;
	Wert=Wert.join("[TRENNER]");
	document.cookie = "Mswitch_template" + "=" + Wert + "; expires=" + Auszeit.toGMTString() + ";";
	}
	data = document.getElementById('emptyarea').value;
	for (elem in INQ) {
		delete INQ[elem];
}
defineddevices.length = 0;
	document.getElementById('rawconfig10').value = configtemplate.join("\n");
	document.getElementById('bank5').value='';
	starttemplate(data);
	return;
}

// #################

function starttemplate(template){
	closeall();	
	if (jump == "nojump")
	{
	}
	
	if (document.getElementById('rawconfig10').value =="")
	{
	document.getElementById('rawconfig10').value = configtemplate.join("\n");
	}
	
	var tmplsatz = template.split("\n");
	var len= tmplsatz.length;
	var newtmp = "";
	
	for (lines=0; lines<len; lines++){
		if (jump != "nojump")
		{
			
			if (tmplsatz[lines] != jump)
			{
				tmplsatz[lines]="# abgearbeitet";
	            newtemplate = tmplsatz.join("\n");
				continue;
			}
			else{
				jump = "nojump";
			}
		}
	
		if (tmplsatz[lines].match(/^#/))
		{
			continue;
		}
		
	var aktline = tmplsatz[lines];

	schreibespeicher(aktline);
	tmplsatz[lines]="# abgearbeitet";
	newtemplate = tmplsatz.join("\n");
	
    var check = testline(aktline,newtemplate);
	
	if ( check == "jump" )
	{
	data = document.getElementById('emptyarea').value;
	starttemplate(data);
	break;
	}
	
	if ( check == "stop" )
	{
	break;
	}

	tmplsatz[lines]="# abgearbeitet";
	execcmd(aktline); // durchreichung von set befehlen
	}
	
	if (len <= lines)
	{
		if (nosave =="0"){
		var out ="Configfile wurde erstellt !  .... wird gespeichert .....";
		}
		else{
		var out ="Configfile wurde erstellt.<br><input type='button' value='MSwitch erstellen' onclick='javascript: saveempty()'>";
		}
	document.getElementById('importTemplate1').innerHTML = out;
	conf = document.getElementById('rawconfig10').value;

	if (nosave =="1"){
	// cookie setzen
	var jetzt = new Date();
	var Verfall = 1000 * 60 * 60 *12;
	var Auszeit = new Date(jetzt.getTime() + Verfall);
	var Wert = document.getElementById('emptyarea').value.split("\n");;
	Wert=Wert.join("[TRENNER]");
	document.cookie = "Mswitch_template" + "=" + Wert + "; expires=" + Auszeit.toGMTString() + ";";
	//
	}

	if (nosave =="0"){
		
		
		
	/* 		
	$test =~ s/#\[dp\]/:/g;
	$test =~ s/#\[pt\]/./g;
    $test =~ s/#\[ti\]/~/g;
    $test =~ s/#\[se\]/;/g;
    $test =~ s/#\[dp\]/:/g;
    $test =~ s/\(DAYS\)/|/g;
    $test =~ s/#\[ko\]/,/g;     #neu
    $test =~ s/#\[bs\]/\\/g; 
		
		 */
		
/* 		
 	conf = conf.replace(/#\[nl\]/g,'\n');
	
	conf = conf.replace(/#\[tab\]/g,'\t'); */
	conf = conf.replace(/#\[sp\]/g,' ');
	conf = conf.replace(/#\[se\]/g,';');	
	conf = conf.replace(/#\[dp\]/g,':');
	conf = conf.replace(/#\[bs\]/g,'\\');
	conf = conf.replace(/#\[ko\]/g,',');
	conf = conf.replace(/#\[wa\]/g,'|');
	conf = conf.replace(/#\[st\]/g,'\'');
		 
		
		
		
		//alert("change");
		
		
		
		
		document.getElementById('rawconfig10').value=conf;
		conf= str2hex(changevar(conf));
		var nm = devicename;
		var def = nm+' saveconfig '+conf;
		
		
		//alert("save");
		//return;
		
		location = location.pathname+'?detail='+devicename+'&cmd=set '+addcsrf(def);
		}
	}
	return;	
}

// #################
// MAINLOOP
// #################


function testline(line,newtemplate){
	
	
	var cmdsatz = line.split(">>");
	if (cmdsatz[0] == "" || cmdsatz[0] == " " ){return;}
	if (cmdsatz[0] != "IF" && cmdsatz[0] != "INCSELECT" && cmdsatz[0] != "MSwitch_Device_Groups" && cmdsatz[0] != "VARDEC" &&  cmdsatz[0] != "VARINC" && cmdsatz[0] != "DEBUG" && cmdsatz[0] != "MINIMAL" && cmdsatz[0] != "GOTO" && cmdsatz[0] != "TEXT" && cmdsatz[0] != "EXIT" && cmdsatz[0] != "PREASSIGMENT" && cmdsatz[0] != "VAREVENT" &&  cmdsatz[0] != "VARREADING" &&  cmdsatz[0] != "VARSET" && cmdsatz[0] != "VARADD" && cmdsatz[0] != "VARDEVICES" && cmdsatz[0] != "VARASK" && cmdsatz[0] != "REPEAT" && cmdsatz[0] != "EVENT" && cmdsatz[0] != "ASK" && cmdsatz[0] != "OPT" && cmdsatz[0] != "ATTR" && cmdsatz[0] != "SET" && cmdsatz[0] != "SELECT" && cmdsatz[0] != "INQ"  ){

		if (INQ[cmdsatz[0]]== "1")
		{
		cmdsatz.shift(); 	
		}
		else{
		return;
		}
}


if (cmdsatz[0] == "SET"){
	
	//alert(cmdsatz[0]+ " - "+cmdsatz[1]);
}

// 

if (cmdsatz[0] == "IF"){	
bedingung = changevar(cmdsatz[1]);
document.getElementById('bank10').value=cmdsatz[1];
document.getElementById('bank11').value ="0";
var string = "result = 0; if ("+bedingung+"){result = 1};document.getElementById('bank11').value=result;";
eval(string);
result = document.getElementById('bank11').value;

if (result == "1")
{
	cmdsatz.shift ();
	cmdsatz.shift ();
}
else
{
return;
}
}


if (cmdsatz[0] == "TEXT"){
	var out ="";
	out+=changevar(cmdsatz[1]);
	out+="<br>&nbsp;<br><input type='button' value='weiter' onclick='javascript: setTEXTok(\""+"\")'>";
	document.getElementById('importTemplate1').innerHTML = out;
return "stop";
}

// DEBUG
if (cmdsatz[0] == "MINIMAL")
{
	if (cmdsatz[1] > MSDATAVERSIONDIGIT )
	{
	out="<br>Aufgrund eines Versionskonfliktes kann dieses Template nicht ausgeführt werden.<br>Bitte MSwitch aktualisieren.";
	out+="<br>gedorderte Strukturversion: V" + cmdsatz[1];
	out+="<br>vorhandene Strukturversion: V" + MSDATAVERSIONDIGIT;
	document.getElementById('importTemplate1').innerHTML = out;
	return "stop";
	} 
	return;
}

// DEBUG
if (cmdsatz[0] == "DEBUG")
{
	if (cmdsatz[1] =="on"){
	document.getElementById('speicherbank').style.display='block';
	document.getElementById('speicherbank1').style.display='block';
	document.getElementById('speicherbank2').style.display='block';
	document.getElementById('importTemplate2').style.display='block';
	}
	if (cmdsatz[1] =="off"){
	document.getElementById('speicherbank').style.display='none';
	document.getElementById('speicherbank1').style.display='none';
	document.getElementById('speicherbank2').style.display='none';
	document.getElementById('importTemplate2').style.display='none';
	}
	return;
}

// EXIT
if (cmdsatz[0] == "EXIT")
{
	lines = 10000; 
	return;
}

// GOTO
if (cmdsatz[0] == "GOTO")
{
	jump = cmdsatz[1];
	return "jump";;
}

// map select aus set bei bedarf  MSwitch_Device_Groups
if (cmdsatz[0] == "SELECT")
	{
		if (( cmdsatz[1] == "comand_cmd1" || cmdsatz[1] == "comand_cmd2" ) && document.getElementById('bank1').value == "FreeCmd"){
		cmdsatz[0] ="ASK";	 
		} 
}

// INQ
if (cmdsatz[0] == "INQ"){
	 text = cmdsatz[4];
	 benenner = cmdsatz[3];
	 setINQ(text,cmdsatz[1],cmdsatz[2],benenner,newtemplate);
	 return "stop";
}


if (cmdsatz[0] == "INCSELECT"){
	 text = cmdsatz[3];
	 setINQSELECT(text,cmdsatz[1],cmdsatz[2],newtemplate);
	 return "stop";
}


if (cmdsatz[0] == "REPEAT"){
	 text = cmdsatz[2];
	 anzahl = cmdsatz[1];
	 setREPEAT(text,anzahl,newtemplate);
	 return "stop";
}

// PREASSIGMENT
if (cmdsatz[0] == "PREASSIGMENT"){
	PREASSIGMENT=changevar(cmdsatz[1]);
}

	if (cmdsatz[0] == 'MSwitch_Device_Groups')
	{
		inhalt1 = changevar(cmdsatz[1]);
		var newcmd  = "ATTR>>SET>>MSwitch_Device_Groups>>"+inhalt1;
		inhalt1 = inhalt1.replace(/#\[nl\]/g,'[nl]');
		FW_cmd(FW_root+'?cmd=set '+devicename+' groupreload '+inhalt1+' &XHR=1', function(data){renewdevices(data,newtemplate,newcmd)})
	return "stop";
	}


// VARINC

if (cmdsatz[0] == "VARINC"){
	oldvar=WIZARDVARS[cmdsatz[1]];
	oldvar++;
	WIZARDVARS[cmdsatz[1]]=oldvar;
	return;
}

if (cmdsatz[0] == "VARDEC"){
	oldvar=WIZARDVARS[cmdsatz[1]];
	oldvar--;
	WIZARDVARS[cmdsatz[1]]=oldvar;
	return;
}

// VAREVENT>>VARNAME>>VARTEXT

if (cmdsatz[0] == "VAREVENT"){
	var testvar = cmdsatz[1].match(/^\$.*/);
	if (testvar!=null && testvar.length!=0)
	{
				var toset = cmdsatz[1];
				var text = cmdsatz[2];
				eventinputvar(text,toset,newtemplate,typ);
				return "stop";
	}
		else{
	alert("ERROR: Variablen müssen mit einem einleitenden $ deklariert werden .");
	}
}

// VAREVENT>>VARNAME>>VARTEXT
if (cmdsatz[0] == "VARREADING"){
	var testvar = cmdsatz[1].match(/^\$.*/);
	inhalt1 = changevar(cmdsatz[2]);
	//alert(testvar);
	
	if (testvar!=null && testvar.length!=0)
	{
		var toset = cmdsatz[1];
		var readingdevice = cmdsatz[2];
		var text = cmdsatz[3];
			
		document.getElementById('bank4').value=toset;	
		document.getElementById('bank7').value=text;			
		document.getElementById('bank8').value=newtemplate;		
		FW_cmd(FW_root+'?cmd=set '+devicename+' loadreadings '+inhalt1+' &XHR=1', function(data){VARREADINGS(data)})
		return "stop";
	}
	else
	{
	alert("ERROR: Variablen müssen mit einem einleitenden $ deklariert werden .");
	}
}

// VARASK>>VARNAME>>VARTEXT
if (cmdsatz[0] == "VARASK"){
	var testvar = cmdsatz[1].match(/^\$.*/);
	if (testvar!=null && testvar.length!=0)
	{
		text = cmdsatz[2];
		varname = cmdsatz[1];
		setVAR(text,varname,newtemplate);
		return "stop";
	}
		else{
	alert("ERROR: Variablen müssen mit einem einleitenden $ deklariert werden .");
	}
}

// VARSET>>VARNAME>>VARINHALT
if (cmdsatz[0] == "VARSET"){
	var testvar = cmdsatz[1].match(/^\$.*/);
	if (testvar!=null && testvar.length!=0)
	{
		newvar=changevar(cmdsatz[2]);
		WIZARDVARS[cmdsatz[1]] = newvar;
	}
		else{
	alert("ERROR: Variablen müssen mit einem einleitenden $ deklariert werden .");
	}
}

// VARADD


// VARDEVICES>>VARNAME>>VARTEXT
if (cmdsatz[0] == "VARDEVICES"){
	var testvar = cmdsatz[1].match(/^\$.*/);
	if (testvar!=null && testvar.length!=0)
	{
		text = cmdsatz[2];
		varname = cmdsatz[1];
		setVARDEVICES(text,varname,newtemplate);
		return "stop";
	}
		else{
	alert("ERROR: Variablen müssen mit einem einleitenden $ deklariert werden .");
	}
} 


if (cmdsatz[0] == "VARDEVICE"){
	var testvar = cmdsatz[1].match(/^\$.*/);
	if (testvar!=null && testvar.length!=0)
	{
		text = cmdsatz[2];
		varname = cmdsatz[1];
		setVARDEVICE(text,varname,newtemplate);
		return "stop";
	}
		else{
	alert("ERROR: Variablen müssen mit einem einleitenden $ deklariert werden .");
	}
} 



var typ="";
if (cmdsatz[0] == "ATTR")
{
	typ="A";
	cmdsatz.shift(); 
	}
	else
	{
	typ="S";
	}
		var befehl = cmdsatz[0];
		if (befehl == "ASK"){
			var toset = cmdsatz[1];
			var text = cmdsatz[2];
			freeinput(text,toset,newtemplate,typ);
			return "stop";
		}
		
		if (befehl == "EVENT"){
			var toset = cmdsatz[1];
			var text = cmdsatz[2];
			eventinput(text,toset,newtemplate,typ);
			return "stop";
		}
		
		if (befehl == "OPT"){
			var toset = cmdsatz[1];
			var options = cmdsatz[2];
			var text = cmdsatz[3];
			optioninput(text,toset,options,newtemplate,typ);
			return "stop";
		}

		if (befehl == "SELECT"){
		
			var toset = cmdsatz[1];
			var text = cmdsatz[2];
			selectinput(text,toset,newtemplate,typ);
			return "stop";
		}
	
		if (befehl == "SET"){
		var befehl =cmdsatz.join(">>");
		if (typ =="A"){
			befehl="ATTR>>"+befehl;
			}
		execcmd(befehl);
		starttemplate(newtemplate);
		return "stop";
		}
return "go";
}

// #################

function VARREADINGS(readings){
	var out ="";
	readings = readings.substr(0, readings.length - 1);
	ret="";
	ret+=document.getElementById('bank7').value;
	ret=changevar(ret);
	ret+="<br>&nbsp;<br>";
	ret+= '<select id =\"readings\" name=\"readings\" >';
	newreadings = readings.split("\[|\]");
	ret +='<option value=\"select\">bitte wählen:</option>';
	for (i = 0; i < newreadings.length; i++) 
	{
	ret +='<option value=\''+newreadings[i]+'\'>'+newreadings[i]+'</option>';	
	}
	ret +='</select>';
	ret+="<br>&nbsp;<br><input type='button' value='weiter' onclick='javascript: setVARREADINGok(\"\")'>";
	ret+="<br>&nbsp;<br>&nbsp;<br>";
	ret+="<input id='newtemplate' type='text' value='"+document.getElementById('bank8').value+"' "+style+">";
	document.getElementById('importTemplate1').innerHTML = ret;
	
return;
}

function setVARREADINGok(input){
varname = document.getElementById('bank4').value;
WIZARDVARS[varname] = document.getElementById('readings').value
newtemplate = document.getElementById('bank8').value;
starttemplate(newtemplate);
return;
}


function setVARDEVICES(text,varname,newtemplate){
var out ="";
out+=text;
out=changevar(out);
out+="<br>&nbsp;<br>";
selectlist = devicelistmultiple('selectlist','name')
out+=selectlist;
out+="<br>&nbsp;<br><input id='input' type='text' value='"+PREASSIGMENT+"' size='100'>";
out+="<br>&nbsp;<br><input type='button' value='weiter' onclick='javascript: setVARok(\""+varname+"\")'>";
out+="<br>&nbsp;<br>&nbsp;<br>";
out+="<input id='newtemplate' type='text' value='"+newtemplate+"' "+style+">";
document.getElementById('importTemplate1').innerHTML = out;
return;
}


function setVARDEVICE(text,varname,newtemplate){
var out ="";
out+=text;
out=changevar(out);
out+="<br>&nbsp;<br>";
selectlist = devicelistone('selectlist','name')
out+=selectlist;
out+="<br>&nbsp;<br><input id='input' type='text' value='"+PREASSIGMENT+"' size='100'>";
out+="<br>&nbsp;<br><input type='button' value='weiter' onclick='javascript: setVARok(\""+varname+"\")'>";
out+="<br>&nbsp;<br>&nbsp;<br>";
out+="<input id='newtemplate' type='text' value='"+newtemplate+"' "+style+">";
document.getElementById('importTemplate1').innerHTML = out;
return;
}




// #################
function setVAR(text,varname,newtemplate){
var out ="";
out+=text;
out=changevar(out);
out+="<br>&nbsp;<br>";
out+="<input id='input' type='text' value='"+PREASSIGMENT+"' size='100'><br>&nbsp;<br>";
out+="<br>&nbsp;<br><input type='button' value='weiter' onclick='javascript: setVARok(\""+varname+"\")'>";
out+="<br>&nbsp;<br>&nbsp;<br>";
out+="<input id='newtemplate' type='text' value='"+newtemplate+"' "+style+">";
document.getElementById('importTemplate1').innerHTML = out;
return;
}

// ###########################################

function setVARok(input){
WIZARDVARS[varname] = document.getElementById('input').value
starttemplate(newtemplate);
return;
}

// ###########################################

function setTEXTok(input){
starttemplate(newtemplate);
return;
}

// ###########################################

function setREPEAT(text,anzahl,newtemplate){
var out ="";
out+=text;
out=changevar(out);
out+="<br>&nbsp;<br>";
out+="<fieldset>";
out+="<input type=\"radio\" id=\"REPEAT1\" name=\"radio\" value=\"0\">";
out+="<label for=\"REPEAT1\"> ja</label><br> ";
out+="<input type=\"radio\" id=\"REPEAT2\" name=\"radio\" value=\"1\">";
out+="<label for=\"REPEAT2\"> nein</label><br> ";	
out+="</fieldset>";		
out+="<br>&nbsp;<br><input type='button' value='weiter' onclick='javascript: setREPEATok(\""+anzahl+"\")'>";
out+="<br>&nbsp;<br>&nbsp;<br>";
out+="<input id='newtemplate' type='text' value='"+newtemplate+"' "+style+">";
document.getElementById('importTemplate1').innerHTML = out;
return;
}

// #################

function setREPEATok(anzahl)
{
var radios = document.getElementsByName('radio');
var value;
for (var i = 0; i < radios.length; i++) {
    if (radios[i].type === 'radio' && radios[i].checked) {
        value = radios[i].value;   
    }
}
var template = document.getElementById('newtemplate').value;
if (value =="0"){
	var alllastlines = document.getElementById('bank5').value.split("\n");
	for (var i = 0; i < anzahl; i++) {
		newtemplate=alllastlines[i]+"\n"+newtemplate;
	}
}
starttemplate(newtemplate);
return;
}


// #################

function setINQSELECT(text,inq,inq1,newtemplate){
var ret ="";
ret+=text;
ret+="<br>&nbsp;<br>";
ret+= '<select id=\"INQCSELECT\" name=\"'+name+'\" >';
	var count =0;
	var names = inq.split(",");
	var options = inq1.split(",");
	var len =  names.length;
for (i=count; i<len; i++)
	
		{
			ret +='<option value='+names[i]+'>'+options[i]+'</option>';
		}
	ret +='</select>';
	ret+="<br>&nbsp;<br><input type='button' value='weiter' onclick='javascript: setINCSELECTok()'>";
	ret+="<br>&nbsp;<br>&nbsp;<br>";
	ret+="<input id='newtemplate' type='text' value='"+newtemplate+"' "+style+">";
	document.getElementById('importTemplate1').innerHTML = ret;
	return ;
}

// #################

function setINCSELECTok()
{
var inhalt = document.getElementById('INQCSELECT').value;
var value;
var template = document.getElementById('newtemplate').value;
INQ[inhalt]  = "1";
starttemplate(newtemplate);
return;
}

// #################

function setINQ(text,inq,inq1,benenner,newtemplate){
var names = benenner.split(",");
var out ="";
out+=text;
out=changevar(out);
out+="<br>&nbsp;<br>";
out+="<fieldset>";
out+="<input type=\"radio\" id=\"INQ1\" name=\"radio\" value=\"0\">";
out+="<label for=\"INQ1\"> "+names[0]+"</label><br> ";
out+="<input type=\"radio\" id=\"INQ2\" name=\"radio\" value=\"1\">";
out+="<label for=\"INQ2\"> "+names[1]+"</label><br> ";	
out+="</fieldset>";		
out+="<br>&nbsp;<br><input type='button' value='weiter' onclick='javascript: setINQok(\""+inq+"\",\""+inq1+"\")'>";
out+="<br>&nbsp;<br>&nbsp;<br>";
out+="<input id='newtemplate' type='text' value='"+newtemplate+"' "+style+">";
document.getElementById('importTemplate1').innerHTML = out;
return;
}

// #################

function setINQok(toset1,toset2)
{
var radios = document.getElementsByName('radio');
var value;
for (var i = 0; i < radios.length; i++) {
    if (radios[i].type === 'radio' && radios[i].checked) {
        // get value, set checked flag or do whatever you need to
        value = radios[i].value;   	
    }
}
var template = document.getElementById('newtemplate').value;
if (value =="0"){
	INQ[toset1]  = "1";
}
if (value =="1"){
	INQ[toset2]  = "1";
}
starttemplate(newtemplate);
return;
}

// #################

function eventinput(text,toset,newtemplate,typ){
monitorid ="eventcontrol1";
logging="on";
inhalt1= document.getElementById('bank1').value;
FW_cmd(FW_root+'?cmd=set '+devicename+' notifyset '+inhalt1+' &XHR=1', function(data){})
observer.observe(target, config);
var out ="";
out+=text;
out=changevar(out);
out+="<br>&nbsp;<br>";
out+="<select multiple style=\"width: 40em;\" size=\"5\" id =\"eventcontrol1\" onchange=\"javascript: takeselectedmultiple(id,name)\"></select>";
out+="<br>&nbsp;<input type='button' value='||' onclick='javascript: pausemonitor()'>";
out+="&nbsp;<input type='button' value='>' onclick='javascript: playmonitor()'>";
out+="&nbsp;<input type='button' value='clear' onclick='javascript: clearmonitor()'>";
//out+="&nbsp;Filter: <input id='filter' type='text' value='' size='10'>";
out+="<br>&nbsp;<br><input id='input' type='text' value='"+PREASSIGMENT+"' size='100'>";
out+="<br>&nbsp;<br><input type='button' value='weiter' onclick='javascript: eventinputok(\""+toset+"\",\""+typ+"\")'>";
out+="<input id='newtemplate' type='text' value='"+newtemplate+"' "+style+">";
document.getElementById('importTemplate1').innerHTML = out;
return;
}
// #################


function eventinputvar(text,toset,newtemplate,typ){
monitorid ="eventcontrol1";
logging="on";
inhalt1= document.getElementById('bank1').value;
FW_cmd(FW_root+'?cmd=set '+devicename+' notifyset '+inhalt1+' &XHR=1', function(data){})


observer.observe(target, config);
var out ="";
out+=text;
out=changevar(out);
out+="<br>&nbsp;<br>";
out+="<select multiple style=\"width: 40em;\" size=\"5\" id =\"eventcontrol1\" onchange=\"javascript: takeselectedmultiple(id,name)\"></select>";
out+="<br>&nbsp;<input type='button' value='||' onclick='javascript: eventmonitorstop()'>";
out+="&nbsp;<input type='button' value='>' onclick='javascript: eventmonitorstart()'>";
out+="&nbsp;<input type='button' value='clear' onclick='javascript: clearmonitor()'>";
//out+="&nbsp;Filter: <input id='filter' type='text' value='' size='10'>";
out+="<br>&nbsp;<br><input id='input' type='text' value='"+PREASSIGMENT+"'size='100'>";
out+="<br>&nbsp;<br><input type='button' value='weiter' onclick='javascript: eventinputvarok(\""+toset+"\",\""+typ+"\")'>";
out+="<input id='newtemplate' type='text' value='"+newtemplate+"' "+style+">";
document.getElementById('importTemplate1').innerHTML = out;
return;
}

// #################

function eventinputvarok(toset,typ)
{
monitorid ="eventcontrol";
logging="off";
eventmonitorstop();
var event = document.getElementById('input').value.split(":");
if ( document.getElementById('bank1').value != "all_events")
		{	
event.shift();
		}
var befehl = event.join(":");
WIZARDVARS[toset] = befehl;
starttemplate(newtemplate);
return;
}

// #################

function eventinputok(toset,typ)
{
monitorid ="eventcontrol";
logging="off";
eventmonitorstop();
var event = document.getElementById('input').value.split(":");
var befehl = "SET>>"+toset+">>"+event.join(":");
execcmd(befehl);
starttemplate(newtemplate);
return;
}

// #################

function freeinput(text,toset,newtemplate,typ){
var ret = "<input id='input' type='text' value='"+PREASSIGMENT+"' size='100'><br>&nbsp;<br>";
	if( document.getElementById('bank1').value == "FreeCmd" && (toset =="comand_cmd1" || toset =="comand_cmd2"))
	{
		ret = '<textarea id ="input" cols="40" rows="4"></textarea><br>&nbsp;<br>';
	}
	
var out ="";
out+=text;
out=changevar(out);
out+="<br>&nbsp;<br>";
out+=ret;
out+=" <input type='button' value='weiter' onclick='javascript: freeinputok(\""+toset+"\",\""+typ+"\")'>";
out+="<br>&nbsp;<br>&nbsp;<br>";
out+="<input id='newtemplate' type='text' value='"+newtemplate+"' "+style+">";
document.getElementById('importTemplate1').innerHTML = out;
return;
}

// #################

function freeinputok(toset,typ)
{
var befehl = "SET>>"+toset+">>"+document.getElementById('input').value;
	if (typ =="A"){
		befehl="ATTR>>"+befehl;
	}
execcmd(befehl);
starttemplate(newtemplate);
return;
}

// #################

function optioninput(text,toset,options,newtemplate,typ){
var out ="";
out+=text;
out=changevar(out);
out+="<br>&nbsp;<br>";
out+="<fieldset>";
var mapp = options.match(/(.*)\{(.*)\}/);
if (mapp!=null && mapp.length!=0)
	{	
	var optionssatz = mapp[1].split(",");
	var mapsatz= mapp[2].split(",");
	}
else{
	var optionssatz = options.split(",");
	var mapsatz = optionssatz;
	}
	var len= optionssatz.length;
	for (i=0; i<len; i++){
	out+="<input type=\"radio\" id=\"ID"+i+"\" name=\"radio\" value=\""+optionssatz[i]+"\">";
	out+="<label for=\"ID"+i+"\"> "+mapsatz[i]+"</label><br> ";
	}
	out+="</fieldset>";		
	out+="<br><input type='button' value='weiter' onclick='javascript: optioninputok(\""+toset+"\",\""+typ+"\")'>";
	out+="<br>&nbsp;<br>&nbsp;<br>";
	out+="<input id='newtemplate' type='text' value='"+newtemplate+"' "+style+">";
	document.getElementById('importTemplate1').innerHTML = out;
	return;
}

// #################

function optioninputok(toset,typ)
{
var radios = document.getElementsByName('radio');
var value;
for (var i = 0; i < radios.length; i++) {
    if (radios[i].type === 'radio' && radios[i].checked) {
        value = radios[i].value;   
    }
}
var befehl = "SET>>"+toset+">>"+value;
if (typ =="A"){
	befehl="ATTR>>"+befehl;
}
var template = document.getElementById('newtemplate').value;
execcmd(befehl);
starttemplate(newtemplate);
return;
}

// #################

function cmdselect(text,toset,newtemplate,typ){
var devicetocmd = document.getElementById('bank1').value
var number = devices.indexOf(devicetocmd);
if ( number >-1)
{
seloptions = makecmdhashtemp(cmds[number]);	
}
else {
	number = GROUPS.indexOf(devicetocmd);
	seloptions = makecmdhashtemp(GROUPSCMD[number]);
}
return seloptions+"<span id=\"setcmd1temp\"></span>";
}

// #################

function cmdselectok(toset,typ)
{
	var befehlfirst = "";
	var befehlsecond = "";
	befehlfirst = document.getElementById('comand').value;
	if( $("#comand1").length > 0 ) {
	befehlsecond = document.getElementById('comand1').value;
	}
var befehl = "SET>>"+toset+">>"+befehlfirst+" "+befehlsecond;
var template = document.getElementById('newtemplate').value;
execcmd(befehl);
starttemplate(newtemplate);
return;
}

// #################

function selectinput(text,toset,newtemplate,typ){
var out ="";
out+=text;
out=changevar(out);
out+="<br>&nbsp;<br>";

	if (typ =="S")
	{
		if(toset == "Device_to_switch")
		{
			selectlist = devicelist('selectlist','name','no_script',3)
		}
		else if(toset == "comand_cmd1" || toset == "comand_cmd2")
		{
			// ##############################
			selectlist =cmdselect(text,toset,newtemplate,typ)
			out+=selectlist;
			out+="<br>&nbsp;<br><input type='button' value='weiter' onclick='javascript: cmdselectok(\""+toset+"\",\""+typ+"\")'>";
			out+="<br>&nbsp;<br>&nbsp;<br>";
			out+="<input id='newtemplate' type='text' value='"+newtemplate+"' "+style+">";
			document.getElementById('importTemplate1').innerHTML = out;
			return;
			
			
			// ###############################
		}
		else
		{
			selectlist = devicelist('selectlist','name','no_script',2)
		}
	}
	else// typ = A
	{
	selectlist = attrlist('selectlist','name',toset)	
	}

out+=selectlist;
out+="<br>&nbsp;<br><input type='button' value='weiter' onclick='javascript: selectinputok(\""+toset+"\",\""+typ+"\")'>";
out+="<br>&nbsp;<br>&nbsp;<br>";
out+="<input id='newtemplate' type='text' value='"+newtemplate+"' "+style+">";
document.getElementById('importTemplate1').innerHTML = out;
return;

}

// #################

function selectinputok(toset,typ)
{
var befehl = "SET>>"+toset+">>"+document.getElementById('selectlist').value;
if (typ =="A"){
	befehl="ATTR>>"+befehl;
}
var template = document.getElementById('newtemplate').value;
execcmd(befehl);
starttemplate(newtemplate);
return;
}
// #################
function execcmd(befehl)
{
var cmdsatz = befehl.split(">>");
if (cmdsatz[0] == "ATTR"){
	typa="A";
	cmdsatz.shift(); 
}
else{
typa="S";
}

	var befehl = cmdsatz[1];
	var typ = cmdsatz[0];
	var inhalt = cmdsatz[2];
	var arg = cmdsatz[3];

	if (befehl == "INFO"){
	inhalt = changevar(inhalt);
	document.getElementById('help').innerHTML = inhalt;
	return;
	}
	var configuration=document.getElementById('rawconfig10').value;
	configuration = configuration.split("\n");
	conflenght = configuration.length;

if (typa == "A" ){
	
	if (inhalt != "")
	{
	inhalt1 = changevar(inhalt);
	newattr = "#A "+befehl+" -> "+inhalt1;
	var newconfig =configuration.join("\n");
	ATTRS[befehl] = inhalt1;	
	newconfig=newconfig+"\n"+newattr;
	}
	document.getElementById('rawconfig10').value = newconfig;
	return;
	}
	
//###############################

	if (befehl == "Trigger_device"){
	var newinhalt= 	changevar(inhalt)
	if (newinhalt =="GLOBAL")
	{ 
	configuration[5] = "#S .Trigger_device -> all_events";
	document.getElementById('bank1').value = 'all_events';
	}else
	{
		configuration[5] = "#S .Trigger_device -> "+newinhalt;
		document.getElementById('bank1').value = newinhalt;
	}
	}

	if (befehl == "Trigger_Whitelist"){
	var newinhalt= 	changevar(inhalt)
	FW_cmd(FW_root+'?cmd=set '+devicename+' whitelist '+newinhalt+' &XHR=1')
	configuration[conflenght] = "#S .Trigger_Whitelist -> "+newinhalt;
	}
	
// comand_READING
	if (befehl == "READING" ){
	var newarg= 	changevar(arg)
	newattr = "#S "+inhalt+" -> "+newarg;
	configuration[conflenght] = newattr;
	}
	
	//time_on1
	if (befehl == "Time_on"){
	inhalt = inhalt.replace(/:/gi,"#[dp]");
	configuration[13] = "#S .Trigger_time_1 -> "+inhalt;
	
	}
	
	//time_off 2
	if (befehl == "Time_off"){
	inhalt = inhalt.replace(/:/gi,"#[dp]");
	configuration[14] = "#S .Trigger_time_2 -> "+inhalt;
	
	}
	
	// Time_cmd 1 3
	if (befehl == "Time_cmd1"){
	inhalt = inhalt.replace(/:/gi,"#[dp]");
	configuration[15] = "#S .Trigger_time_3 -> "+inhalt;
	}
	
	// Time_cmd2 4
	if (befehl == "Time_cmd2"){
	inhalt = inhalt.replace(/:/gi,"#[dp]");
	configuration[16] = "#S .Trigger_time_4 -> "+inhalt;
	}
	
	// Trigger_condition
 	if (befehl == "Trigger_condition"){
	configuration[9] = "#S .Trigger_condition -> "+inhalt;
	} 
	
// Trigger_on
 	if (befehl == "MSwitch_on"){
	inhalt= 	changevar(inhalt)
	configuration[7] = "#S .Trigger_on -> "+inhalt;
	} 
	
// Trigger_off
 	if (befehl == "MSwitch_off"){
		inhalt= 	changevar(inhalt)
	configuration[3] = "#S .Trigger_off -> "+inhalt;
	} 
	
// Trigger_cmd1
 	if (befehl == "MSwitch_cmd1"){
	inhalt= 	changevar(inhalt)
	configuration[8] = "#S .Trigger_cmd_on -> "+inhalt;
	} 
	
// Trigger_cmd2
 	if (befehl == "MSwitch_cmd2"){
	inhalt= 	changevar(inhalt)
	configuration[4] = "#S .Trigger_cmd_off -> "+inhalt;
	} 
	
	
// comand_priority
	if (befehl == "PRIORITY" ){
	var device =  document.getElementById('bank6').value.split("\n");
	device[13]="#[NF]"+inhalt;
	document.getElementById('bank6').value=device.join("\n");
	configuration =  makedevice(configuration);
	} 
	
	if (befehl == "HIDEDISPLAY" ){
	var device =  document.getElementById('bank6').value.split("\n");
	device[19]="#[NF]"+inhalt;
	document.getElementById('bank6').value=device.join("\n");
	configuration =  makedevice(configuration);
	}
	
	// comand_HIDE
	if (befehl == "HIDE" ){
	var device =  document.getElementById('bank6').value.split("\n");
	device[19]="#[NF]"+inhalt;
	document.getElementById('bank6').value=device.join("\n");
	configuration =  makedevice(configuration);
	}
	
	
// comand_ID
	if (befehl == "ID" ){
	var device =  document.getElementById('bank6').value.split("\n");
	device[14]="#[NF]"+inhalt;
	document.getElementById('bank6').value=device.join("\n");
	configuration =  makedevice(configuration);
	}
	
	

// comand_cmd1 und 2
	if (befehl == "comand_cmd1" || befehl == "comand_cmd2"){
		if (befehl == "comand_cmd1"){
			var field1 =1;
			var field2 =3;
		}
		if (befehl == "comand_cmd2"){
			var field1 =2;
			var field2 =4;
		}
		
	inhalt = inhalt.split(" ");
	var first =  inhalt.shift();
	var second = inhalt.join(" ");
	
	first = changevar(first);
	second = changevar(second);

	var device =  document.getElementById('bank6').value.split("\n");	
	if (document.getElementById('bank1').value == "FreeCmd")
	{	
	first = first.replace(/\n/g,';;');	
	second = second.replace(/\n/g,';;');
	
	first = first.replace(/\n/g,'#[nl]');
	first = first.replace(/:/g,'#[dp]');
	first = first.replace(/;/g,'#[se]');
	first = first.replace(/ /g,'#[sp]');
	first = first.replace(/\t/g,'#[tab]');
	first = first.replace(/\\/g,'#[bs]');
	first = first.replace(/,/g,'#[ko]');
	first = first.replace(/\|/g,'#[wa]');
	first = first.replace(/\|/g,'#[wa]');

	second = second.replace(/\n/g,'#[nl]');
	second = second.replace(/:/g,'#[dp]');
	second = second.replace(/;/g,'#[se]');
	second = second.replace(/ /g,'#[sp]');
	second = second.replace(/\t/g,'#[tab]');
	second = second.replace(/\\/g,'#[bs]');
	second = second.replace(/,/g,'#[ko]');
	second = second.replace(/\|/g,'#[wa]');
	second = second.replace(/\|/g,'#[wa]');

	device[field1]= "#[NF]cmd"
	device[field2]="#[NF]"+first+" "+second;
	}
	else
	{
	device[field1]= "#[NF]"+first;
	device[field2]="#[NF]"+second;
	}
	document.getElementById('bank6').value=device.join("\n");
	configuration =  makedevice(configuration);
	}
	
// cmd_repeat
	if (befehl == "cmd_repeat"){
	var device =  document.getElementById('bank6').value.split("\n");
	device[11]="#[NF]"+inhalt;
	document.getElementById('bank6').value=device.join("\n");
	configuration =  makedevice(configuration);
	}
	
	// cmd_repeat_time
	if (befehl == "cmd_repeat_time"){
	var device =  document.getElementById('bank6').value.split("\n");
	device[12]="#[NF]"+inhalt;
	document.getElementById('bank6').value=device.join("\n");
	configuration =  makedevice(configuration);
	}
	
	// delay_cmd1
	if (befehl == "delay_cmd1"){
		inhalt = changevar(inhalt);
	var device =  document.getElementById('bank6').value.split("\n");
	device[7]="#[NF]"+inhalt;
	document.getElementById('bank6').value=device.join("\n");
	configuration =  makedevice(configuration);
	}
	
	// delay_cmd2
	if (befehl == "delay_cmd2"){
		
		inhalt = changevar(inhalt);
	var device =  document.getElementById('bank6').value.split("\n");
	device[8]="#[NF]"+inhalt;
	document.getElementById('bank6').value=device.join("\n");
	configuration =  makedevice(configuration);
	}
	
	// condition_cmd1
	if (befehl == "condition_cmd1"){
		 
	inhalt = changevar(inhalt);	
		
	var device =  document.getElementById('bank6').value.split("\n");
	device[9]="#[NF]"+inhalt;
	document.getElementById('bank6').value=device.join("\n");
	configuration =  makedevice(configuration);
	}
	
	// condition_cmd2
	if (befehl == "condition_cmd2"){
		
		inhalt = changevar(inhalt);
		
	var device =  document.getElementById('bank6').value.split("\n");
	device[10]="#[NF]"+inhalt;
	document.getElementById('bank6').value=device.join("\n");
	configuration =  makedevice(configuration);
	}
	
	// Device_to_switch
	if (befehl == "Device_to_switch"){
		inhalt = changevar(inhalt);
	if (inhalt == "free"){ inhalt = "FreeCmd";}
	
	defineddevices.push(inhalt);

	var inhalt1 = configuration[12].split("-> ");	
	var inhalt2 = inhalt1[1].split("#\[ND\]");
	var anzdevices=inhalt2.lenght;
	if (anzdevices === undefined){anzdevices=0;}
	var satz = inhalt1[1].split(",");
	if (satz[0] == "no_device"){
		satz.shift(); 
	}
	

	//conflines =  configstart.length
	document.getElementById('bank1').value = inhalt;
	
	var anzahl =0;
	for (i = 0; i < defineddevices.length; i++) 
		{
			if (document.getElementById('bank1').value ==defineddevices[i])
			{
				anzahl++;
			}
		}

	satz.push(inhalt+"-AbsCmd"+anzahl); 
	var newsatz = satz.join(",");
	configuration[12] = "#S .Device_Affected -> "+newsatz;
	emptydevice[0]=inhalt+"-AbsCmd"+anzahl;
	document.getElementById('bank6').value = emptydevice.join("\n");
	configuration =  makedevice(configuration);
	} 
var newconfig =configuration.join("\n");
document.getElementById('rawconfig10').value = newconfig;
return;
}

// #################

function makedevicenew(configuration){
	
	var device=document.getElementById('bank6').value;
	device = device.replace(/#\[NF\]/g,'');
	device =device.split("\n");
	document.getElementById('bank7').value=device.join("#[NF]");
	var key  = document.getElementById('bank2').value;
	Devices[key] = document.getElementById('bank7').value;
	var newmasterline ="";
	for (var key in Devices) {
    var value = Devices[key];
    newmasterline += value+"#[ND]";
}
	

	
	newmasterline=newmasterline.substr(0,newmasterline.length - 5);
	configuration[18] = "#S .Device_Affected_Details_new -> "+newmasterline;
	return configuration;
}


function makedevice(configuration){
	
	var device=document.getElementById('bank6').value;
	device = device.replace(/#\[NF\]/g,'');
	device =device.split("\n");

	var anzahl =0;
	for (i = 0; i < defineddevices.length; i++) 
		{
			if (document.getElementById('bank1').value ==defineddevices[i])
			{
				
				anzahl++;
			}
		}
	
	document.getElementById('bank7').value=device.join("#[NF]");
	var key  = document.getElementById('bank1').value+"-AbsCmd"+anzahl;

	Devices[key] = document.getElementById('bank7').value;
	var newmasterline ="";
	var affected= configuration[12].split("-> ");
	var affecteddevices = affected[1].split(",");

	for (var i = 0; i < affecteddevices.length; i++) {
		var name = affecteddevices[i];
		newmasterline += Devices[name]+"#[ND]";
    }
	
	newmasterline=newmasterline.substr(0,newmasterline.length - 5);
	configuration[18] = "#S .Device_Affected_Details_new -> "+newmasterline;
	return configuration;
}

// #################

function makecmdhashtemp(line){
	if (line === undefined){
		return;
	}
	
	
	var retoption = '<select id =\"comand\" name=\"\" onchange=\"javascript: selectcmdoptionstemp(this.value)\">';
	retoption +='<option selected value=\"0\">Befehl wählen</option>';
	
	sets = new Object();
	var cmdset = new Array;
	cmdset = line.split(" ");
	var anzahl = cmdset.length;
	
	for (i=0; i<anzahl; i++)
		{
		aktset = cmdset[i].split(":");	
		sets[aktset[0]]=aktset[1];
		if (aktset[0] != ""){
		retoption +='<option value='+aktset[0]+'>'+aktset[0]+'</option>';
			}
		}
	retoption +='</select>';
	var arraysetskeys = Object.keys(sets);
	
	return retoption;
}

// #################

function selectcmdoptionstemp(inhalt){
 // t("erstelle  params ");
	
	document.getElementById('setcmd1temp').innerHTML ='';
	// wenn undefined textfeld erzeugen
	
	if (sets[inhalt] == 'noArg'){ return;}
	// wenn noarg befehl übernehmen
	if (sets[inhalt] === undefined){ 
	retoption1 = '<input name=\"\" id=\"comand1\" type=\"text\" value=\"'+PREASSIGMENT+'\">&nbsp;';
	document.getElementById('setcmd1temp').innerHTML = retoption1;
	return;
	}
	
	
	// wenn liste subcmd erzeugen
	var retoption1;


	var cmdset1= new Array;
	cmdset1= sets[inhalt].split(",");
	console.log(cmdset1);
	var anzahl = cmdset1.length;
	
		retoption1 = '<input style=\'background-color : #d1d1d1\' readonly name=\"\" id=\"comand1\" type=\"text\" value=\"'+PREASSIGMENT+'\"><br>&nbsp;<br>';
		
		retoption1 +="<div class='fhemWidget' cmd='wizardcont' reading='container' dev='"+devicename+"' arg='"+cmdset1+"' current='10'></div>";
		
		document.getElementById('setcmd1temp').innerHTML = retoption1;
		
		var r = $("head").attr("root");
		if(r)
		FW_root = r;
		FW_replaceWidgets($("html"));
		return;
//	}
	
	// nicht genutzt
	retoption1 = '<select id =\"comand1\" name=\"\">';
	retoption1 +='<option selected value=\"0\">Option wählen</option>';
	
	for (i=0; i<anzahl; i++)
		{
		retoption1 +='<option value='+cmdset1[i]+'>'+cmdset1[i]+'</option>';
		}
	retoption1 +='</select>';
	document.getElementById('setcmd1temp').innerHTML = retoption1;
	return;
}


// ######################
function changevar(text){
	if ( text === undefined || text == "undefined"){ 
	return text;
	}
	
 	for (var key in WIZARDVARS) {
		//alert (key);
		var replace = "\\"+key+"\\b";
        var re = new RegExp(replace,"g");
        newtest=text.replace(re, WIZARDVARS[key]);
		text= newtest;
		}
return text;
}
 
// ##################################

function setATTRS()
{
}

// ##################################
function renewdevices(data,newtemplate,newcmd)
{
	parts = data.split("\[TRENNER\]");
	newdevices = parts[0].split("\[|\]");
	newcmds = parts[1].split("\[|\]");

	for (i = 0; i < newdevices.length; i++) 
	{
		
	GROUPS.push(newdevices[i]); 
	GROUPSCMD.push(newcmds[i]); 
		
	}
	var test1 = GROUPS.length;
	newtemplate=newcmd+"\n"+newtemplate;
	starttemplate(newtemplate);
	return;
}

// ##################################
// erhält deten von fhem.pl über gesetzte widgets
function setargument(argument){
document.getElementById('comand1').value=argument;
return;
}


function setargument(argument){
	var help = "";
}
