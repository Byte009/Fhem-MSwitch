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
  
  
  
	var version = 'V3.8';
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
	// debugger
	// style ="";
	
	
	var configstart = [
	'#V Version',
	'#VS V2.01',
	'#S .First_init -> done',
	'#S .Trigger_off -> no_trigger',
	'#S .Trigger_cmd_off -> no_trigger',
	'#S Trigger_device -> no_trigger',
	'#S Trigger_log -> off',
	'#S .Trigger_on -> no_trigger',
	'#S .Trigger_cmd_on -> no_trigger',
	'#S .Trigger_condition -> ',
	'#S .V_Check -> V2.01',
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




	var configtemplate = [
	'#V Version',
	'#VS V2.01',
	'#S .First_init -> done',
	'#S .Trigger_off -> no_trigger',
	'#S .Trigger_cmd_off -> no_trigger',
	'#S Trigger_device -> no_trigger',
	'#S Trigger_log -> off',
	'#S .Trigger_on -> no_trigger',
	'#S .Trigger_cmd_on -> no_trigger',
	'#S .Trigger_condition -> ',
	'#S .V_Check -> V2.01',
	'#S .Device_Events -> no_trigger',
	'#S .Device_Affected -> no_device',
	'#S .Trigger_time -> ',
	'#S .Device_Affected_Details -> '];


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

// starte Hauptfenster



// conf('importWIZARD','wizard');

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


//alert(test);  

document.getElementById('bank6').value=test;


	if(o[test]){return;}

	var event = test.split(':');
	var newevent =  event[1]+':'+event[2]
	if ( event[0] != document.getElementById('bank1').value && document.getElementById('bank1').value != "all_events")
		{
			//document.getElementById('bank3').value=document.getElementById('3').value;
			document.getElementById('bank4').value=document.getElementById('bank1').value;
			document.getElementById('bank2').value=event[0];
			return;
		}
	if (logging == 'off')
		{
			return;
		}
		
	if ( document.getElementById('bank1').value == "all_events")
		{	
		
		newevent =event[0]+':'+newevent;
		
		}
		//alert(newevent);
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
  });    
});


//####################################################################################################


function eventmonitorstop(){
	if (observer){
		observer.disconnect();
	}	
	return;
}

function eventmonitorstart(){
	
	var newselect = $('<option value="Event wählen">Event wählen:</option>');
	$(newselect).appendTo('#6step');
	observer.observe(target, config);
	return;
}


function clearmonitor(){
	eventmonitorstop();
	var selectobject = document.getElementById("eventcontrol1");
for (var i=0; i<10000; i++) {
        selectobject.remove(i);
}


document.getElementById('eventcontrol1').innerHTML=""; 

eventmonitorstart();

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
	
	//document.getElementById('wizard').style.backgroundColor='';
	document.getElementById('config').style.backgroundColor='';
	document.getElementById('importat').style.backgroundColor='';
	document.getElementById('importnotify').style.backgroundColor='';
	document.getElementById('importpreconf').style.backgroundColor='';
	document.getElementById('importTEMPLATE').style.backgroundColor='';
	document.getElementById('empty').style.display='none';
	document.getElementById(typ).style.display='block';
	document.getElementById(but).style.backgroundColor='#ffb900';
	
	
	document.getElementById('showtemplate').style.display='none';

/* 	if (but == 'wizard'){
		// neustart wizard
		
		startwizardtrigger();
	} */
	
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
	//alert('aufruf');
	startimportpreconf();
	}
	
	return;
}	
	
function start1(name){
	//alert("start");
	// return;

	
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
		// fülle configfenster
		
		// --------------------------
		//fillconfig('rawconfig');
		//startwizardtrigger();
		
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
		configstart[5] ='#S Trigger_device -> '+ document.getElementById('3').value;
		configstart[8] ='#S .Trigger_cmd_on -> '+ document.getElementById('5').value;
	}
	
	// ############ nur für volle befehlseingabe
	// affected devices und befehl
	
	if (document.getElementById('a11').value == 'FreeCmd')
	{
	// nur für freie befehlseingabe
	// alert('zweig nicht definiert');
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

   // #########################################
	fillconfig('rawconfig')
	
	return;
} 

function fillconfig(name){
	var showconf='';
	configstart[0] = '#V '+mVersion;
	conflines =  configstart.length ;
	for (i = 0; i < conflines; i++) 
		{
			showconf = showconf+configstart[i]+'\n';
		}
	document.getElementById(name).innerHTML = showconf;	
}

function saveconfig(name,mode){
	
	if (mode == 'wizard'){
	makeconfig();
	}
	
	
	
	
	
	
	
	
	conf = document.getElementById(name).value;
	
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
			
		
		
		//test1 = GROUPS.join("-");
		//alert('GROUPS: '+test1);
		
		
		
		
		
		var test = GROUPS.length ;
 		//alert('GROUPSlänge: '+test);
		 
		for (i=count; i<test; i++)
		{
			//alert("GUPPEN-"+GROUPS[i]);
		//if (flag == '1'){
		//	ret +='<option value='+i+'>'+GROUPS[i]+'</option>';
		//	}
		//else{
			ret +='<option value='+GROUPS[i]+'>'+GROUPS[i]+' (MSwitch Gruppe)</option>';
			//}
		} 
	ret +='</select>';
	return ret;
}




// ############################




function devicelistmultiple(id,name){
	ret="";
	
	//if (script == "no_script"){
		ret = '<select style="width: 50em;" size="5" multiple id =\"'+id+'\" name=\"'+name+'\" onchange=\"javascript: takeselected(id,name)\">';
/* 	}
	else{
		ret = '<select style="width: 30em;" size="5" multiple id =\"'+id+'\" name=\"'+name+'\" onchange=\"javascript: '+script+'(this.value,id,name)\">';
	} */
	// erstelle geräteliste'+id+'+name+'
	
	count =0;
	
	//ret +='<option value=\"select\">bitte wählen:</option>';

	for (i=count; i<len; i++)
		{
		//if (flag == '1'){
			ret +='<option value='+devices[i]+'>'+devices[i]+'</option>';
			//}
/* 		else{
			
			ret +='<option value='+devices[i]+'>'+devices[i]+'</option>';
			} */
		}
	ret +='</select>';
	return ret;
		
}

/// #######################

function takeselected(id,name){
	
	var values = $('#'+id).val();
	//alert(values);
	
	document.getElementById('input').value = values;
	return;
}


/// #######################

function takeselectedmultiple(id,name){
	
	var values = $('#'+id).val();
	//alert(values);
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

//alert (attrset);
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
	html+='<textarea id=\"rawconfig3\" style=\"width: 950px; height: 600px\"></textarea>';
	html+='</td>';
	html+='</tr>';
	html+='<tr><td style=\"text-align: center; vertical-align: middle;\">';
	html+='<input name=\"saveconf\" id=\"saveconf\" type=\"button\" value=\"Konfiguration speichern\" onclick=\"javascript: saveconfig(\'rawconfig3\')\"\">';
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
	
	
//	alert("firstname: "+name);
	
	
	
	
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


//alert("NAME: "+name);
//return;

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
	cmdstring = cmdstring.replace(/:/g,'#[dp]');
	cmdstring = cmdstring.replace(/;/g,'#[se]');
	cmdstring = cmdstring.replace(/ /g,'#[sp]');
	//cmdstring = cmdstring.replace(/'/g,'#[st]');
	cmdstring = cmdstring.replace(/\t/g,'#[tab]');
	cmdstring = cmdstring.replace(/\\/g,'#[bs]');
	cmdstring = cmdstring.replace(/,/g,'#[ko]');
	cmdstring = cmdstring.replace(/\|/g,'#[wa]');
	cmdstring = cmdstring.replace(/\|/g,'#[wa]');
	
	
	
	
	configstart[12] ='#S .Device_Affected -> FreeCmd-AbsCmd1';
    var newcmdline = '#S .Device_Affected_Details -> FreeCmd-AbsCmd1'+'#[NF]undefined#[NF]cmd#[NF]'+cmdstring+'#[NF]#[NF]delay1#[NF]delay1#[NF]00:00:00#[NF]00:00:00#[NF]#[NF]#[NF]undefined#[NF]undefined#[NF]1#[NF]0#[NF]#[NF]0#[NF]0#[NF]1#[NF]0';

	configstart[29]=newcmdline;
	
	if (document.getElementById('defflag').value == "*")
	{
		string = document.getElementById('deftspec').value;
		// ersetze dp durch #[dp]
		string ="["+string+"]";
		string = string.replace(/:/gi,"#[dp]");
		configstart[13] ='#S .Trigger_time -> on~off~ononly'+ string +'~offonly~onoffonly';
	}
	

	if (document.getElementById('defflag').value == "+")
	{
		string = document.getElementById('deftspec').value;
		// ersetze dp durch #[dp]
		string = '['+string+'*00:01-23:59]';
		string = string.replace(/:/gi,"#[dp]");
		configstart[13] ='#S .Trigger_time -> on~off~ononly'+ string +'~offonly~onoffonly';
	}
	
	fillconfig('rawconfig1');
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
	//alert(trigger);
	
	
	var mapp = trigger.match(/^(\()(.*)(\))/);
	if (mapp!=null && mapp.length!=0)
		{	
	//alert(mapp[0]);
		trigger=mapp[0];
		
		
		// voll globales triggern
		
		// im cmd eventausdrücke auf mswitchausdrücke mappen !!!
		trigger = trigger.replace(/:\./g,':.*');
		trigger = "\"\$EVENT\" =~m/"+trigger+"/";
	//alert(trigger);
		
		
		
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
	cmdstring = cmdstring.replace(/:/g,'#[dp]');
	cmdstring = cmdstring.replace(/;/g,'#[se]');
	cmdstring = cmdstring.replace(/ /g,'#[sp]');
	//cmdstring = cmdstring.replace(/'/g,'#[st]');
	cmdstring = cmdstring.replace(/\t/g,'#[tab]');
	cmdstring = cmdstring.replace(/\\/g,'#[bs]');
	cmdstring = cmdstring.replace(/,/g,'#[ko]');
	cmdstring = cmdstring.replace(/\|/g,'#[wa]');
	cmdstring = cmdstring.replace(/\|/g,'#[wa]');
	
	// hier notify to mswitch mappen
	// EVENT - EVTPART3
	// NAME
	//
	cmdstring = cmdstring.replace(/\$NAME/g,'$NAME');
	cmdstring = cmdstring.replace(/\$EVENT/g,'$EVTPART3');
	
	
	document.getElementById('notifytest').value=cmdstring;
	
	
	
	
	//alert(cmdstring);
	//return;
	configstart[12] ='#S .Device_Affected -> FreeCmd-AbsCmd1';
    var newcmdline = '#S .Device_Affected_Details -> FreeCmd-AbsCmd1'+'#[NF]undefined#[NF]cmd#[NF]'+cmdstring+'#[NF]#[NF]delay1#[NF]delay1#[NF]00:00:00#[NF]00:00:00#[NF]#[NF]#[NF]undefined#[NF]undefined#[NF]1#[NF]0#[NF]#[NF]0#[NF]0#[NF]1#[NF]0';
	configstart[29]=newcmdline;
	
	
	
	configstart[5] ='#S Trigger_device -> '+ document.getElementById('trigdev').value;
	
	
	
	
	
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
	
	
	//#S .Trigger_Whitelist -> NAME!=Template
	
	configstart[28] ='#S .Trigger_Whitelist -> NAME!='+devicename;
	//#S .Trigger_condition -> "$EVENT"#[sp]=#[ti]m/(G_Steckdosen_2E070C#[dp]ENERGY_Power#[dp].*|G_Steckdosen_2E070C/
}
	
	fillconfig('rawconfig2');
	
	
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
	//alert("anzahl: "+anzahl);
	//alert(preconfparts);
	for (i=count; i<anzahl; i++)
		{
		treffer = preconfparts[i].match(/#NAME.(.*?)(#\[NEWL\])/);
		//alert(treffer);
		help = preconfparts[i].match(/#HELP.(.*?)(#\[NEWL\])/);
		//alert(help);
		preconfparts[i] = (preconfparts[i].split(treffer[0]).join(''));
		preconfparts[i] = (preconfparts[i].split(help[0]).join(''));
		//preconfparts[i] = preconfparts[i].replace(/\n/g,'#[REGEXN]');
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
	//html+='<input disabled name=\"\" id=\"prec\" type=\"button\" value=\"importiere dieses MSwitch\" onclick=\"javascript: savepreconf()\"\">';
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
	
	// teste auf version
		
		
		
		
		var testversion = preconfparts[name];
		var myRegEx = new RegExp('#VS.(V.*)');  
		treffer = testversion.match(myRegEx);
		//alert(treffer[1]+" "+MSDATAVERSION);
		
		
		if (treffer[1] != MSDATAVERSION)
		{
			var wrongversion =' <strong><u>Versionskonflikt:</u><br>Diese Version ist nciht für die aktuelle Datenstruktur vorgesehen \
			und kann nicht importiert werden.\
			<br>Bitte den Support kontaktieren.\
			<br>geforderte/benoetigte Version: '+MSDATAVERSION+'\
			<br>Deviceversion: '+treffer[1]+'\
			</strong><br><br>';
			document.getElementById('rawconfig4').innerHTML = "";
			document.getElementById('prec').disabled = true;
			document.getElementById('prec').style.backgroundColor='#ff0000';
			document.getElementById('rawconfig4').innerHTML = preconfparts[name];
			document.getElementById('infotext1').innerHTML = wrongversion+preconfpartshelp[name];
			
			return;
		}
		
		
	// ende
	
	document.getElementById('rawconfig4').innerHTML = preconfparts[name];
	document.getElementById('infotext1').innerHTML = preconfpartshelp[name];
	document.getElementById('prec').disabled = false;
	document.getElementById('prec').style.backgroundColor='';
}

// #################

function savepreconf(name){
	mode = 'preconf';
	saveconfig('rawconfig4',mode);
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
	//conf = conf.replace(/:/g,'#c[dp]');
	tosave = tosave.replace(/;/g,'[SE]');
	tosave = tosave.replace(/ /g,'[SP]');
	tosave = tosave.replace(/#/g,'[RA]');
	tosave = tosave.replace(/\+/g,'[PL]');
	tosave = tosave.replace(/"/g,'[AN]');
	tosave = tosave.replace(/&/g,'[AND]');
	
	
	
	templatename = templatename.replace(/local\//g,'');
	
	
	//alert(tosave);
	//alert(templatename);
	
	var newname = "local / "+templatename;
	var newinhalt = "local/"+templatename;
	
	//alert("name "+newname);
	//alert("inhalt "+newinhalt);
	
	var targ = document.getElementById('templatefile');
	var found = "notfound";
	
  for (i = 0; i < targ.options.length; i++)
		 {
		 // alert (targ.options[i].value);
		 if (targ.options[i].value == newinhalt )
		 {
			found = "found";
			targ.options[i].selected = true;	
		}
	}
	
	//alert (found);
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
	if (jump == "nojump"){
	//alert(template);
	//alert(jump);
	//alert(configtemplate.join("\n"));
	}
	
	//alert(document.getElementById('rawconfig10'));
	
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
	
	
	
	//alert(aktline);
	
	
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
	conf = conf.replace(/\n/g,'#[EOL]');
	conf = conf.replace(/#\[REGEXN\]/g,'\\n');
	conf = conf.replace(/:/g,'#c[dp]');
	conf = conf.replace(/;/g,'#c[se]');
	conf = conf.replace(/ /g,'#c[sp]');
	
	//  doppelt - auch im execute vorhanden
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
		conf = changevar(conf);
		var nm = devicename;
		var def = nm+' saveconfig '+encodeURIComponent(conf);
		location = location.pathname+'?detail='+devicename+'&cmd=set '+addcsrf(def);
		}
	}
	return;	
}

// #################
// #################
function testline(line,newtemplate){
	var cmdsatz = line.split(">>");
	if (cmdsatz[0] == "" || cmdsatz[0] == " " ){return;}
	if (cmdsatz[0] != "MSwitch_Device_Groups" && cmdsatz[0] != "VARDEC" &&  cmdsatz[0] != "VARINC" && cmdsatz[0] != "DEBUG" && cmdsatz[0] != "GOTO" && cmdsatz[0] != "TEXT" && cmdsatz[0] != "EXIT" && cmdsatz[0] != "PREASSIGMENT" && cmdsatz[0] != "VAREVENT" &&  cmdsatz[0] != "VARSET" && cmdsatz[0] != "VARDEVICES" && cmdsatz[0] != "VARASK" && cmdsatz[0] != "REPEAT" && cmdsatz[0] != "EVENT" && cmdsatz[0] != "ASK" && cmdsatz[0] != "OPT" && cmdsatz[0] != "ATTR" && cmdsatz[0] != "SET" && cmdsatz[0] != "SELECT" && cmdsatz[0] != "INQ" ){

		if (INQ[cmdsatz[0]]== "1")
		{
		cmdsatz.shift(); 	
		}
		else{
		return;
		}
}


//alert(cmdsatz[0]);



//text
if (cmdsatz[0] == "TEXT"){
	var out ="";
	//alert (cmdsatz[1]);
	out+=changevar(cmdsatz[1]);
	out+="<br>&nbsp;<br><input type='button' value='weiter' onclick='javascript: setTEXTok(\""+"\")'>";
	document.getElementById('importTemplate1').innerHTML = out;
return "stop";
}



// DEBUG
if (cmdsatz[0] == "DEBUG")
{
	if (cmdsatz[1] =="on"){
	document.getElementById('speicherbank').style.display='block';
	document.getElementById('speicherbank1').style.display='block';
	document.getElementById('importTemplate2').style.display='block';
	}
	if (cmdsatz[1] =="off"){
	document.getElementById('speicherbank').style.display='none';
	document.getElementById('speicherbank1').style.display='none';
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
		//var data="";
		//alert("found");
		inhalt1 = changevar(cmdsatz[1]);
		//alert(inhalt1);
		
		
		var newcmd  = "ATTR>>SET>>MSwitch_Device_Groups>>"+inhalt1;
		
		//FW_cmd(FW_root+'?cmd=set '+devicename+' groupreload '+inhalt1+'&XHR=1', function(data){FW_okDialog(data)});
		inhalt1 = inhalt1.replace(/#\[nl\]/g,'[nl]');
		
		
		
		
		
		
		FW_cmd(FW_root+'?cmd=set '+devicename+' groupreload '+inhalt1+' &XHR=1', function(data){renewdevices(data,newtemplate,newcmd)})
/* 		
 		var d = new Date();
		var n = d.getTime();
		var ziel = n+1000;
		
		while (n < ziel) {
		d = new Date();
		 n = d.getTime();
} 
		 */
		
	//newattr = "#S MSwitch_Device_Groups -> "+inhalt1;
	//configuration[conflenght] = newattr;
		
		
		
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


var typ="";
if (cmdsatz[0] == "ATTR"){
	typ="A";
	cmdsatz.shift(); 
	}
	else{
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

function setVARDEVICES(text,varname,newtemplate){
var out ="";
out+=text;
out=changevar(out);
out+="<br>&nbsp;<br>";
selectlist = devicelistmultiple('selectlist','name')
out+=selectlist;
out+="<br>&nbsp;<br><input id='input' type='text' value='' size='60'>";
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
out+="<input id='input' type='text' value='"+PREASSIGMENT+"' size='60'><br>&nbsp;<br>";
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
observer.observe(target, config);
var out ="";
out+=text;
out=changevar(out);
out+="<br>&nbsp;<br>";
out+="<select multiple style=\"width: 30em;\" size=\"5\" id =\"eventcontrol1\" onchange=\"javascript: takeselectedmultiple(id,name)\"></select>";


out+="<br>&nbsp;<input type='button' value='||' onclick='javascript: eventmonitorstop()'>";
out+="&nbsp;<input type='button' value='>' onclick='javascript: eventmonitorstart()'>";
out+="&nbsp;<input type='button' value='clear' onclick='javascript: clearmonitor()'>";
out+="&nbsp;Filter: <input id='filter' type='text' value='' size='10'>";



out+="<br>&nbsp;<br><input id='input' type='text' value='' size='50'>";



out+="<br>&nbsp;<br><input type='button' value='weiter' onclick='javascript: eventinputok(\""+toset+"\",\""+typ+"\")'>";
out+="<input id='newtemplate' type='text' value='"+newtemplate+"' "+style+">";
document.getElementById('importTemplate1').innerHTML = out;
return;
}
// #################


function eventinputvar(text,toset,newtemplate,typ){
monitorid ="eventcontrol1";
logging="on";
observer.observe(target, config);
var out ="";
out+=text;
out=changevar(out);
out+="<br>&nbsp;<br>";
out+="<select multiple style=\"width: 30em;\" size=\"5\" id =\"eventcontrol1\" onchange=\"javascript: takeselectedmultiple(id,name)\"></select>";

out+="<br>&nbsp;<input type='button' value='||' onclick='javascript: eventmonitorstop()'>";
out+="&nbsp;<input type='button' value='>' onclick='javascript: eventmonitorstart()'>";
out+="&nbsp;<input type='button' value='clear' onclick='javascript: clearmonitor()'>";
out+="&nbsp;Filter: <input id='filter' type='text' value='' size='10'>";


out+="<br>&nbsp;<br><input id='input' type='text' value='' size='50'>";
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

//alert(event);
if ( document.getElementById('bank1').value != "all_events")
		{	
event.shift();
		}
var befehl = event.join(":");
//alert (toset+"-"+befehl);
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
if ( document.getElementById('bank1').value != "all_events")
		{	
event.shift();
		}
var befehl = "SET>>"+toset+">>"+event.join(":");
execcmd(befehl);
starttemplate(newtemplate);
return;
}

// #################

function freeinput(text,toset,newtemplate,typ){
var ret = "<input id='input' type='text' value='"+PREASSIGMENT+"' size='60'><br>&nbsp;<br>";
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
			
			//alert(toset);
			selectlist =cmdselect(text,toset,newtemplate,typ)
			out+=selectlist;
			out+="<br>&nbsp;<br><input type='button' value='weiter' onclick='javascript: cmdselectok(\""+toset+"\",\""+typ+"\")'>";
			out+="<br>&nbsp;<br>&nbsp;<br>";
			out+="<input id='newtemplate' type='text' value='"+newtemplate+"' "+style+">";
			document.getElementById('importTemplate1').innerHTML = out;
			return;
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
	document.getElementById('help').innerHTML = inhalt;
	return;
	}
	// #A MSwitch_Expert -> 1	
	var configuration=document.getElementById('rawconfig10').value;
	configuration = configuration.split("\n");
	conflenght = configuration.length;
	
	
	//alert(befehl);
	
	
	
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
	
	
	
	
	//timerfelder vorbereiten
	var fields = configuration[13].split("->");
	if (fields[1] ==" "){
		fields[1]="on~off~ononly~offonly~onoffonly";
	}
	var satz = fields[1].split("~");
	if (befehl == "Trigger_device"){
	
	//alert(befehl);
	//alert(inhalt);
	
		if (inhalt =="GLOBAL")
		{ 
	configuration[5] = "#S Trigger_device -> all_events";
	document.getElementById('bank1').value = 'all_events';
	}else{
		
		configuration[5] = "#S Trigger_device -> "+inhalt;
		
		document.getElementById('bank1').value = inhalt;
	}
	
	
	}

	if (befehl == "Trigger_Whitelist"){
	var newinhalt= 	changevar(inhalt)
	FW_cmd(FW_root+'?cmd=set '+devicename+' whitelist '+newinhalt+' &XHR=1')
	configuration[conflenght] = "#S .Trigger_Whitelist -> "+newinhalt;
	}
	
	
// comand_READING
	if (befehl == "READING" ){
	newattr = "#S "+inhalt+" -> "+arg;
	configuration[conflenght] = newattr;
	}
	
	//time_on
	if (befehl == "Time_on"){
	inhalt = inhalt.replace(/:/gi,"#[dp]");
	satz[0]= satz[0]+inhalt;
	var newsatz = satz.join("~");
	configuration[13] = "#S .Trigger_time -> "+newsatz;
	}
	
	//time_off
	if (befehl == "Time_off"){
	inhalt = inhalt.replace(/:/gi,"#[dp]");
	satz[1]= satz[1]+inhalt;
	var newsatz = satz.join("~");
	configuration[13] = "#S .Trigger_time -> "+newsatz;
	}
	
	// Time_cmd1
	if (befehl == "Time_cmd1"){
	inhalt = inhalt.replace(/:/gi,"#[dp]");
	satz[2]= satz[2]+inhalt;
	var newsatz = satz.join("~");
	configuration[13] = "#S .Trigger_time -> "+newsatz;
	}
	
	// Time_cmd2
	if (befehl == "Time_cmd2"){
	inhalt = inhalt.replace(/:/gi,"#[dp]");
	satz[3]= satz[3]+inhalt;
	var newsatz = satz.join("~");
	configuration[13] = "#S .Trigger_time -> "+newsatz;
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
	//alert(configuration);
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
	

	
// comand_ID
	if (befehl == "ID" ){
	var device =  document.getElementById('bank6').value.split("\n");
	device[14]="#[NF]"+inhalt;
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
	//alert(inhalt);
	if (inhalt == "free"){ inhalt = "FreeCmd";}
	
	
	
	
	defineddevices.push(inhalt);
	
	
	// var min = 1000;
// var max = 9999;
// var x = Math.round(Math.random() * (max - min)) + min;
	
	
	// var codeinhalt=inhalt +'_MSwitch_ID_'+x;
	
	
	
	var inhalt1 = configuration[12].split("-> ");	
	var inhalt2 = inhalt1[1].split("#\[ND\]");
	var anzdevices=inhalt2.lenght;
	if (anzdevices === undefined){anzdevices=0;}
	var satz = inhalt1[1].split(",");
	if (satz[0] == "no_device"){
		satz.shift(); 
	}
	
	
	
	//alert(defineddevices);
	//conflines =  configstart.length
	document.getElementById('bank1').value = inhalt;
	
	var anzahl =0;
	for (i = 0; i < defineddevices.length; i++) 
		{
			//alert("definedevices"+i+": "+defineddevices[i]+" - "+document.getElementById('bank1').value);
			if (document.getElementById('bank1').value ==defineddevices[i])
			{
				//alert("found");
				anzahl++;
			}
		}
	
	
	//alert("anzahl: "+anzahl);
	
	satz.push(inhalt+"-AbsCmd"+anzahl); 
	var newsatz = satz.join(",");
	configuration[12] = "#S .Device_Affected -> "+newsatz;
	emptydevice[0]=inhalt+"-AbsCmd"+anzahl;
	document.getElementById('bank6').value = emptydevice.join("\n");
	//document.getElementById('bank2').value = codeinhalt;
	
	configuration =  makedevice(configuration);
	} 

var newconfig =configuration.join("\n");
//alert(newconfig);
document.getElementById('rawconfig10').value = newconfig;
return;
}

// #################


function makedevicenew(configuration){
	
	
	//alert(configuration);
	var device=document.getElementById('bank6').value;
	device = device.replace(/#\[NF\]/g,'');
	device =device.split("\n");
	document.getElementById('bank7').value=device.join("#[NF]");
	var key  = document.getElementById('bank2').value;
	
	Devices[key] = document.getElementById('bank7').value;
	
	
	var newmasterline ="";
	//var affected= configuration[12].split("-> ");
	//var affecteddevices = affected[1].split(",");
	
	//alert(key);
	//alert(Devices[key]);
	
	
	for (var key in Devices) {
    var value = Devices[key];
   // alert("key: "+key);
   // alert("value: "+value);
   
    newmasterline += value+"#[ND]";
	
	
}
	
	
	
	
	
	// for (var i = 0; i < affecteddevices.length; i++) {
		// var name = affecteddevices[i];
		
		// //alert(name);
		// newmasterline += Devices[name]+"#[ND]";
    // }
	
	newmasterline=newmasterline.substr(0,newmasterline.length - 5);
	configuration[14] = "#S .Device_Affected_Details -> "+newmasterline;
	return configuration;
}





function makedevice(configuration){
	
	
	//alert(configuration);
	var device=document.getElementById('bank6').value;
	device = device.replace(/#\[NF\]/g,'');
	device =device.split("\n");
	
	//alert("devices :"+defineddevices);
	//conflines =  configstart.length
	
	
	var anzahl =0;
	for (i = 0; i < defineddevices.length; i++) 
		{
			//alert("defineddevice"+i+":"+defineddevices[i]);
			if (document.getElementById('bank1').value ==defineddevices[i])
			{
				
				anzahl++;
			}
		}
	
	//alert("anzahl: "+anzahl);
	
	
	document.getElementById('bank7').value=device.join("#[NF]");
	var key  = document.getElementById('bank1').value+"-AbsCmd"+anzahl;
	
	
	//alert(key);
	
	
	Devices[key] = document.getElementById('bank7').value;
	var newmasterline ="";
	var affected= configuration[12].split("-> ");
	var affecteddevices = affected[1].split(",");
	
	
	//alert(affecteddevices);
	
	
	for (var i = 0; i < affecteddevices.length; i++) {
		var name = affecteddevices[i];
		
		//alert(name);
		newmasterline += Devices[name]+"#[ND]";
    }
	
	newmasterline=newmasterline.substr(0,newmasterline.length - 5);
	configuration[14] = "#S .Device_Affected_Details -> "+newmasterline;
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
	
	
	
	
	
	
	document.getElementById('setcmd1temp').innerHTML ='';
	// wenn undefined textfeld erzeugen
	if (sets[inhalt] == 'noArg'){ return;}
	// wenn noarg befehl übernehmen
	
	//  alert(sets[inhalt]);
	if (sets[inhalt] === undefined){ 
	retoption1 = '<input name=\"\" id=\"comand1\" type=\"text\" value=\"'+PREASSIGMENT+'\">&nbsp;';
	document.getElementById('setcmd1temp').innerHTML = retoption1;
	return;
	}
	
	
	if (inhalt == "rgb"){
	retoption1 = '<input name=\"\" id=\"comand1\" type=\"text\" value=\"'+PREASSIGMENT+'\">&nbsp;';
	document.getElementById('setcmd1temp').innerHTML = retoption1;
	return;
	
	}
	
	
	
	// wenn liste subcmd erzeugen
	var retoption1;
	retoption1 = '<select id =\"comand1\" name=\"\">';
	retoption1 +='<option selected value=\"0\">Option wählen</option>';
	
	var cmdset1= new Array;
	cmdset1= sets[inhalt].split(",");
	console.log(cmdset1);
	var anzahl = cmdset1.length;
	for (i=0; i<anzahl; i++)
		{
		retoption1 +='<option value='+cmdset1[i]+'>'+cmdset1[i]+'</option>';
		}
	retoption1 +='</select>';
	document.getElementById('setcmd1temp').innerHTML = retoption1;
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
	
	
	//alert(data);
	//alert(newtemplate);
	
	
	
	parts = data.split("\[TRENNER\]");
	//alert(parts[0]);
	//alert(parts[1]);
	
	
	
	newdevices = parts[0].split("\[|\]");
	newcmds = parts[1].split("\[|\]");
	
	
	//var test = newdevices.length;
	//alert('anzahl: '+test);
	
	
	
	for (i = 0; i < newdevices.length; i++) 
	{
		
	GROUPS.push(newdevices[i]); 
	GROUPSCMD.push(newcmds[i]); 
		
	}
	
	
	//alert('push groups');
	
	//GROUPS.push(parts[0]); 
	//GROUPSCMD.push(parts[1]); 
	var test1 = GROUPS.length;
	//alert('nach push: '+test1);
	
	
	

	
	
	newtemplate=newcmd+"\n"+newtemplate;
	
	
	starttemplate(newtemplate);
	return;
}


