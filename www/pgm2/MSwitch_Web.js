// MSwitch_Web.js
// Autor:Byte09
// #########################
// ##############################################
// gesetzt aus perl
	// var logging ='off';
	// var devices = " . $devstring . ";
	// var cmds = " . $cmds . ";
	// var i;
	// var len = devices.length;
	// var o = new Object();
	// var devicename= '" . $Name . "';
	// var mVersion= '" . $version . "';
	// var MSDATAVERSION = '" . $vupdate . "';
	// var MSDATAVERSIONDIGIT = " . $vupdatedigit . ";
	// var notify = " . $notify . ";
	// var at = " . $at . ";
	// var templatesel ='" . $hash->{helper}{template} . "';
// ###############################################

	var version = '6.62';
	var info = '';
	var debug ='off';
	var datatarget ='undef';
	
//var innerset = $( "div[cmd='set']" ).html();
//####################################################################################################
	var checkfield ='';
// speichern von originalcodes für not avaible
// var ORGdistricode = $( "#Distributor" ).html();

	var globaldetails2 = 'start';
	var globallock='';
	var t=$("#MSwitchWebTR"), ip=$(t).attr("ip"), ts=$(t).attr("ts");
	FW_replaceWidget("[name=aw_ts]", "aw_ts", ["time"], "12:00");
	$("[name=aw_ts] input[type=text]").attr("id", "aw_ts");  
	
	var randomdev=[];
	var globalaffected;
	var auswfirst=document.getElementById('devices');
	var target = document.querySelector('div[informid="'+devicename+'-Debug"]'); // logging
	var config = { attributes: true, childList: true, characterData: true };  // logging
	
	$(function(){
				$( "<p style='text-align: left;' name='sethelp'>Hilfe</p>" ).appendTo( "div[cmd='get']" );
				$("[name=sethelp]").css("display","none");
				
				
				$( "<p style='text-align: left;' name='attrhelp'>Hilfe</p>" ).appendTo( "div[cmd='attr']" );
				$("[name=attrhelp]").css("display","none");
				
	});

$('#sel_set'+devicename).change(function(){
	if( HELPMODE =="0"){ return; }
	var inhalt = document.getElementById("sel_set"+devicename).value;
	$("[name=attrhelp]").css("display","none");
	$("[name=sethelp]").css("display","");		
	var text = HELP;
	text = text.replace(/#\[LINE\]/gi,"<br>");
	text = text.replace(/#\[A\]/gi,"'");
	text = text.replace(/#\[DA\]/gi,"\"");
	var myRegEx = new RegExp('<strong>set DEVICE '+inhalt+'(.*?)</strong>(.*?)(<strong)');  
	treffer = text.match(myRegEx);
	if( treffer == null){
	out = "dieser Hilfetext ist nicht vorhanden";
	}else{
	out = treffer[2];	
	}
	$( "[name=sethelp]" ).html(out);
	return;
	}); 
	
$('#sel_get'+devicename).change(function(){
	if( HELPMODE =="0"){ return; }
	var inhalt = document.getElementById("sel_get"+devicename).value;
	$("[name=attrhelp]").css("display","none");
	$("[name=sethelp]").css("display","");		
	var text = HELP;
	text = text.replace(/#\[LINE\]/gi,"<br>");
	text = text.replace(/#\[A\]/gi,"'");
	text = text.replace(/#\[DA\]/gi,"\"");
	var myRegEx = new RegExp('<strong>get DEVICE '+inhalt+'(.*?)</strong>(.*?)(<strong)');  
	treffer = text.match(myRegEx);
	if( treffer == null){
	out = "dieser Hilfetext ist nicht vorhanden";
	}else{
	out = treffer[2];	
	}
	$( "[name=sethelp]" ).html(out);
	return;
	}); 


$('#sel_attr'+devicename).change(function(){
	if( HELPMODE =="0"){ return; }
	var inhalt = document.getElementById("sel_attr"+devicename).value;
	$("[name=sethelp]").css("display","none");
	$("[name=attrhelp]").css("display","");	
	
	var text = HELP;
	text = text.replace(/#\[LINE\]/gi,"<br>");
	text = text.replace(/#\[A\]/gi,"'");
	text = text.replace(/#\[DA\]/gi,"\"");
	//var myRegEx = new RegExp('<strong>'+inhalt+'[^_](.*?)</strong>(.*?)(<strong)');  
	var myRegEx = new RegExp('<strong>'+inhalt+'</strong>(.*?)(<strong)');  
	
	
	treffer = text.match(myRegEx);
	
	//alert (inhalt);
	//alert (treffer[1]);
	
	if( treffer == null){
	out = inhalt+" - dieser Hilfetext ist nicht vorhanden";
	}else{
	out = treffer[1];	
	}
	$( "[name=attrhelp]" ).html(out);
	return;
	}); 






function teststart(){
// alle startfunktionen ausführen 



const shortarray1 = ['.Device_Affected_Details_new', '.sysconf', '.AttrList', '.Trigger_condition' , '.Device_Events'];

for (const element of shortarray1) {
  //alert(element);
  
  if ($('div[informid="'+devicename+'-'+element+'"]').length > 0) {
	var disp = $('div[informid="'+devicename+'-'+element+'"]').html();
	var res;
	if(disp.length > 35)
		{
		res = disp.substring(0,35);
		$('div[informid="'+devicename+'-'+element+'"]').html(res+'... (gekürzt)');
		}
		/* else
		{
			res = disp;
			$('div[informid="'+devicename+'-'+element+'"]').html(res);
		} */
	
	}
 
}

if ($('#disp').length > 0) {
	var disp = $('#disp').html();
	var res;
	if(disp.length > 15){
		res = disp.substring(0,15);
		}
	$('#disp').html(res+'... (gekürzt)');
	}















var confdevice = devicename+"-MSwitch_Experimental_mode";
var confinhalt = $('div[informid="'+confdevice+'"]').html();

if (confinhalt == "on backup exists"){
		
var cn ="<input title ='doubleclick to execute' ondblclick='javascript:restoreexperimental();' style='text-align: center; background-color: Transparent; border-color: green; font-size: 0.6em; height: 18px; width: 150px;' type='input' value='on -> restore last save' />";

confinhalt = confinhalt+" "+cn;
$('div[informid="'+confdevice+'"]').html(cn);

}







var confdevice = devicename+"-MSwitch_Undo_mode";
var confinhalt = $('div[informid="'+confdevice+'"]').html();

if (confinhalt == "on backup exists"){
		
var cn ="<input title='doubleclick to execute' ondblclick='javascript:undo();' style='text-align: center; background-color: Transparent; border-color: green; font-size: 0.6em; height: 18px; width: 150px;' type='input' value='on -> undo last change' />";

confinhalt = confinhalt+" "+cn;
$('div[informid="'+confdevice+'"]').html(cn);

}















var confdevice = devicename+"-MSwitch_Configdevice";
var confinhalt = $('div[informid="'+confdevice+'"]').html();

if (confinhalt == "installed"){
var cn ="<input onClick='javascript:openconf();' style='text-align: center; background-color: Transparent; border-color: green; font-size: 0.6em; height: 18px; width: 150px;' type='input' value='installed -> open device' />";
//confinhalt = confinhalt+" "+cn;
//$('div[informid="'+confdevice+'"]').html(cn);
}

if (confinhalt == "not installed"){
var cn ="<input onClick='javascript:instconf();' style='text-align: center; background-color: Transparent; border-color: red; font-size: 0.6em; height: 18px; width: 150px;' type='input' value='not installed ( click to install )' />";
//confinhalt = confinhalt+" "+cn;
//$('div[informid="'+confdevice+'"]').html(cn);
}

confinhalt = confinhalt+" "+cn;
$('div[informid="'+confdevice+'"]').html(cn);




// eventmonitor init
	$( "#log2" ).text( "" );
	$( "#log1" ).text( "" );
	$( "#log3" ).text( "" );
	//var field = $('<br><select style="width: 30em;" size="5" id ="lf" multiple="multiple" name="lf" size="6"  onclick="javascript:transferevent()" ></select>');
	//$(field).appendTo('#log2');
	
	events = new Array;
	
// funktion rename aktivieren
if (debug == 'on'){ alert(devicename+' Debug MSwitchweb an') };


  ALLDEVICESALIAS.unshift("");
  
  // doubletten entfernen
   const ACTIVEMOD = ALLDEVICESTYPE.filter(function(ele , pos)
		{
		return ALLDEVICESTYPE.indexOf(ele) == pos;
		})  		
	ACTIVEMOD.unshift(".*");	
	var selectElement = document.getElementById('modtype');
	for (var key in ACTIVEMOD) {
	if (ACTIVEMOD[key] == ""){continue;}	
	var option = new Option(ACTIVEMOD[key], ACTIVEMOD[key]);
    selectElement.options[key] = option;
	}
		

	var selectElement = document.getElementById('affected_third_devices');
	for (var key in ALLDEVICESSELECTED) {
	if (ALLDEVICESSELECTED[key] == ""){continue;}	
	var option = new Option(ALLDEVICESSELECTED[key], ALLDEVICESSELECTED[key]);
    selectElement.options[key] = option;
	}

	var selectElement = document.getElementById('affected_second_devices');
	for (var key in ALLDEVICES) {
 
	if (ALLDEVICESALIAS[key]!=""){
	var option = new Option(ALLDEVICES[key]+" (a:"+ALLDEVICESALIAS[key]+")", ALLDEVICES[key]);
	}
	else{
		var option = new Option(ALLDEVICES[key], ALLDEVICES[key]);
	}

    selectElement.options[key] = option;
	}
	var select = document.getElementById('affected_third_devices');	
	var length = select.options.length;	
		if (length < 1)
		{
			$(affected_third_devices).css("width","175px");	
		}
		
	

//alert(DEVICETOTRIGGERSELECT);
var selectElement = document.getElementById('trigdevnew');
	for (var key in ALLDEVICESTOTRIGGER) {
	if (ALLDEVICESTOTRIGGER[key] == ""){continue;}	
	var option = new Option(ALLDEVICESTOTRIGGERZUSATZ[key], ALLDEVICESTOTRIGGER[key]);
    selectElement.options[key] = option;
	if (ALLDEVICESTOTRIGGER[key] == DEVICETOTRIGGERSELECT){
	selectElement.options[key].selected = true;}
	}



// devicerename
if (RENAME == 'on'){
	//alert("RENAME");
	
	var r1 = $('<input type="button" value="'+RENAMEBUTTON+'" onclick=" javascript: newname() "/>');
	var r2 = $('<input type="button" value="'+RELOADBUTTON+'" onclick=" javascript: reload() \"/>');
	var r3 = $('<input type="text" id = "newname" value="'+devicename+'"/>');
	$( ".col1" ).text( "" );
	$(r3).appendTo('.col1');
	$(r2).appendTo('.col1');
	$(r1).appendTo('.col1');
}


// definiere hilfe fürbigwindow

	varinf = '<table id="t1" width="100%">';
	varinf = varinf+'<tr>';
	varinf = varinf+'<td><small>Verfügbare Variablen und Ausdrücke <input type="button" value="show" onclick="javascript: showvars()"></td>';
	varinf = varinf+'</tr>';
	varinf = varinf+'</table>';
	
	varinf = varinf+'<table id="t2" width="100%" style="display:none">';
	varinf = varinf+'<tr>';
	varinf = varinf+'<td><small>Verfügbare Variablen und Ausdrücke <input type="button" value="hide" onclick="javascript: hidevars()"></td>';
	varinf = varinf+'</tr>';
	varinf = varinf+'</table>';
	
	varinf = varinf+'<table  id="vars" border ="0" width="100%" style="display:none">';
	varinf = varinf+'<tr>';
	varinf = varinf+'<td>';
	
	varinf = varinf+'<table border ="1">';

	varinf = varinf+'<tr>';
	varinf = varinf+'<td><small>\$we / !\$we </td>';
	varinf = varinf+'<td><small>&nbsp;-&nbsp;</td>';
	varinf = varinf+'<td><small>nur an Wochenenden / Wochentagen</td>';
	varinf = varinf+'</tr>';
	
	varinf = varinf+'<tr>';
	varinf = varinf+'<td nowrap><small>isday / !isday </td>';
	varinf = varinf+'<td><small>&nbsp;-&nbsp;</td>';
	varinf = varinf+'<td><small>Tag / nicht Tag</td>';
	varinf = varinf+'</tr>';
	
	varinf = varinf+'<tr>';
	varinf = varinf+'<td><small>\$year </td>';
	varinf = varinf+'<td><small>&nbsp;-&nbsp;</td>';
	varinf = varinf+'<td><small>Jahr</td>';
	varinf = varinf+'</tr>';
	
	varinf = varinf+'<tr >';
	varinf = varinf+'<td><small>\$month </td>';
	varinf = varinf+'<td><small>&nbsp;-&nbsp;</td>';
	varinf = varinf+'<td><small>Monat (1-12)</td>';
	varinf = varinf+'</tr>';
	
	varinf = varinf+'<tr>';
	varinf = varinf+'<td><small>\$day </td>';
	varinf = varinf+'<td><small>&nbsp;-&nbsp;</td>';
	varinf = varinf+'<td><small>Tag des Monats (1-30/31)</td>';
	varinf = varinf+'</tr>';
	
	varinf = varinf+'<tr>';
	varinf = varinf+'<td><small>\$wday </td>';
	varinf = varinf+'<td><small>&nbsp;-&nbsp;</td>';
	varinf = varinf+'<td><small>Wochentag (1-7)</td>';
	varinf = varinf+'</tr>';
	
	varinf = varinf+'<tr>';
	varinf = varinf+'<td><small>\$yday </td>';
	varinf = varinf+'<td><small>&nbsp;-&nbsp;</td>';
	varinf = varinf+'<td><small>Kalendertag (1-356)</td>';
	varinf = varinf+'</tr>';
	
	varinf = varinf+'<tr>';
	varinf = varinf+'<td><small>\$hms </td>';
	varinf = varinf+'<td><small>&nbsp;-&nbsp;</td>';
	varinf = varinf+'<td><small>aktuelle Zeit (hh:mm:ss)</td>';
	varinf = varinf+'</tr>';
	
	varinf = varinf+'<tr>';
	varinf = varinf+'<td><small>\$timestamp </td>';
	varinf = varinf+'<td><small>&nbsp;-&nbsp;</td>';
	varinf = varinf+'<td><small>aktuelle Zeit als Zeitstempel (unix)</td>';
	varinf = varinf+'</tr>';
	
	varinf = varinf+'<tr>';
	varinf = varinf+'<td><small>\$SELF </td>';
	varinf = varinf+'<td><small>&nbsp;-&nbsp;</td>';
	varinf = varinf+'<td><small>enthält den eigenen Namen</td>';
	varinf = varinf+'</tr>';
	
	varinf = varinf+'<tr>';
	varinf = varinf+'<td><small>\$ARG </td>';
	varinf = varinf+'<td><small>&nbsp;-&nbsp;</td>';
	varinf = varinf+'<td><small>enthält ein uebergebenes Argument (ARG) aus Timern</td>';
	varinf = varinf+'</tr>';
	
	varinf = varinf+'</table>';

	varinf = varinf+'</td>';
	varinf = varinf+'<td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>';
	varinf = varinf+'<td>';

	varinf = varinf+'<table border ="1">';
	
	varinf = varinf+'<tr>';
	varinf = varinf+'<td nowrap><small>[HH:MM-HH:MM] </td>';
	varinf = varinf+'<td><small>&nbsp;-&nbsp;</td>';
	varinf = varinf+'<td><small>schaltet nur in angegebenem Zeitraum</td>';
	varinf = varinf+'</tr>';
	
	varinf = varinf+'<tr>';
	varinf = varinf+'<td nowrap><small>[HH:MM-HH:MM|1234567] </td>';
	varinf = varinf+'<td><small>&nbsp;-&nbsp;</td>';
	varinf = varinf+'<td><small>schaltet nur in angegebenem Zeitraum an agegebenen Tagen</td>';
	varinf = varinf+'</tr>';
	
	varinf = varinf+'<tr>';
	varinf = varinf+'<td nowrap><small>[!HH:MM-HH:MM] </td>';
	varinf = varinf+'<td><small>&nbsp;-&nbsp;</td>';
	varinf = varinf+'<td><small>schaltet nur ausserhalb des angegebenem Zeitraumes</td>';
	varinf = varinf+'</tr>';
	
	varinf = varinf+'</table>';
	
	varinf = varinf+'<br>';
	
	varinf = varinf+'<table border ="1">';
	
	varinf = varinf+'<tr>';
	varinf = varinf+'<td nowrap><small>$EVENT</td>';
	varinf = varinf+'<td><small>&nbsp;-&nbsp;</td>';
	varinf = varinf+'<td><small>Enthält das zuletzt eingegangene Event </td>';
	varinf = varinf+'</tr>';
	
	varinf = varinf+'<tr>';
	varinf = varinf+'<td nowrap><small>$EVTFULL</td>';
	varinf = varinf+'<td><small>&nbsp;-&nbsp;</td>';
	varinf = varinf+'<td><small>Enthält das zuletzt eingegangene Event </td>';
	varinf = varinf+'</tr>';
	
	varinf = varinf+'<tr>';
	varinf = varinf+'<td nowrap><small>$EVTPART* (1,2,3)</td>';
	varinf = varinf+'<td><small>&nbsp;-&nbsp;</td>';
	varinf = varinf+'<td><small>Enthält entsprechende Teile des zuletzt eingegangenen Events </td>';
	varinf = varinf+'</tr>';
	
	varinf = varinf+'<tr>';
	varinf = varinf+'<td nowrap><small>[EV(ENT/TFULL/TPART1,2,3):h*]</td>';
	varinf = varinf+'<td><small>&nbsp;-&nbsp;</td>';
	varinf = varinf+'<td><small>Enthält historisch eingegangene Events * -> Nummer, 0 ist das letzte Event </td>';
	varinf = varinf+'</tr>';
	
	varinf = varinf+'</table>';
	varinf = varinf+'</td>';
	varinf = varinf+'<td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>';
	varinf = varinf+'<td>';

	varinf = varinf+'<table border ="1">';
	
	varinf = varinf+'<tr>';
	varinf = varinf+'<td><small>\[Device:Reading\] </td>';
	varinf = varinf+'<td><small>&nbsp;-&nbsp;</td>';
	varinf = varinf+'<td><small> liefert Inhalt eines Readings</td>';
	varinf = varinf+'</tr>';	
	
	varinf = varinf+'<tr>';
	varinf = varinf+'<td><small>\[Device:Reading:d\] </td>';
	varinf = varinf+'<td><small>&nbsp;-&nbsp;</td>';
	varinf = varinf+'<td><small> liefert numerischen Inhalt eines Readings</td>';
	varinf = varinf+'</tr>';	
	
	varinf = varinf+'<tr>';
	varinf = varinf+'<td><small>\[ReadingsVal:Device:Reading:Standard\] </td>';
	varinf = varinf+'<td><small>&nbsp;-&nbsp;</td>';
	varinf = varinf+'<td><small> Zugriff auf Reading</td>';
	varinf = varinf+'</tr>';	
	
	varinf = varinf+'<tr>';
	varinf = varinf+'<td><small>\[ReadingsNum:Device:Reading:Standard\] </td>';
	varinf = varinf+'<td><small>&nbsp;-&nbsp;</td>';
	varinf = varinf+'<td><small> Zugriff auf Reading (numerisch)</td>';
	varinf = varinf+'</tr>';	
	
	varinf = varinf+'<tr>';
	varinf = varinf+'<td><small>\[ReadingsAge:Device:Reading:Standard\] </td>';
	varinf = varinf+'<td><small>&nbsp;-&nbsp;</td>';
	varinf = varinf+'<td><small> Zugriff auf Readingsalter</td>';
	varinf = varinf+'</tr>';	
	
	varinf = varinf+'<tr>';
	varinf = varinf+'<td><small>\[AttrVal:Device:Attr:Standard\] </td>';
	varinf = varinf+'<td><small>&nbsp;-&nbsp;</td>';
	varinf = varinf+'<td><small> Zugriff auf Attribut</td>';
	varinf = varinf+'</tr>';	
	
	varinf = varinf+'<tr>';
	varinf = varinf+'<td><small>\[InternalVal:Device:Reading:Standard\] </td>';
	varinf = varinf+'<td><small>&nbsp;-&nbsp;</td>';
	varinf = varinf+'<td><small> Zugriff auf Internal</td>';
	varinf = varinf+'</tr>';	
	
	varinf = varinf+'</table>';

	varinf = varinf+'</td>';
	varinf = varinf+'</tr>';
	varinf = varinf+'</table>';	


// devhelp ersetzen


$.each( $(".detLink"), function (test) {
	var htmlString = $( this ).html();
	if (htmlString == '<a href="#">Help for MSwitch</a>'){
	$( this ).html( '<a href=\"javascript: fullhelp()\">Help for MSwitch</a>' );
  }
    if (htmlString == '<a href="#">Copy for forum.fhem.de</a>'){
    $( this ).html( '<a href=\"javascript: forum()\">Copy for forum.fhem.de</a>' );
  }
});


// &nbsp;<a href=\"javascript: raw()\">Raw definition</a>
// <a href=\"javascript: reset(\'check\')\">Reset this device ('+devicename+')</a>&nbsp;&nbsp;

var $el = $("#moreCmds");
$el.empty();
// dropdown neu anlegen
$el.append($("<option></option>").attr("new-cmd", "...").text("..."));
$el.append($("<option></option>").attr("new-cmd", "rawDef").text("Raw definition"));
$el.append($("<option></option>").attr("new-cmd", "reset").text("Reset device"));
$el.append($("<option></option>").attr("data-cmd", "style iconFor "+devicename).text("Select icon"));
$el.append($("<option></option>").attr("data-cmd", "style showDSI "+devicename).text("Extend devStateIcon"));
$el.append($("<option></option>").attr("data-cmd", "delete "+devicename).text("Delete "+devicename));


// zufügen des hilfebereichs
r4 = $('<br><div id="helptext">Hilfetext<\div>');
$(r4).appendTo("#content");
$("#helptext").css("display","none");


// EXEC1   ##################################################
	
	if (EXEC1 == '1'){
	//alert('aus java '+EXEC1);
	if (debug == 'on'){ alert('EXEC1') };	
	var affected = document.getElementById('affected').value ;
	var devices = affected.split(",");
	var i;
	var len = devices.length;
	for (i=0; i<len; i++)
		{
		testname = devices[i].split("-");
		if (testname[0] == "FreeCmd") 
			{
			continue;
			}
		sel = devices[i] + '_on';
		sel1 = devices[i] + '_on_sel';
		sel2 = 'cmdonopt' +  devices[i] + '1';
		sel3 = 'cmdseton' +  devices[i];
		aktcmd = document.getElementById(sel).value;
		aktset = document.getElementById(sel3).value;
		
		if (debug == 'on1')
		{ 
			alert('document: '+document.getElementById(sel).value+'\n sel: '+sel1+'\n aktset: '+aktset+'\n sel12: '+sel2) 
		}
		
		activate(document.getElementById(sel).value,sel1,aktset,sel2);
		sel = devices[i] + '_off';
		sel1 = devices[i] + '_off_sel';
		sel2 = 'cmdoffopt' +  devices[i] + '1';
		sel3 = 'cmdsetoff' +  devices[i];
		aktcmd = document.getElementById(sel).value;
		aktset = document.getElementById(sel3).value;
		
		if (debug == 'on1')
		{ 
			alert(document.getElementById(sel).value+' '+sel1+' '+aktset+' '+sel2) 
		}
		
		activate(document.getElementById(sel).value,sel1,aktset,sel2); 
		}
	}
	
	var x = document.getElementsByClassName('randomidclass');
    for (var i = 0; i < x.length; i++) 
		{
		var t  = x[i].id;
		randomdev.push(t);
		} 
	
	// --------------------
	
	globaldetails2='undefined';
	
	var x = document.getElementsByClassName('devdetails2');
    for (var i = 0; i < x.length; i++) 
	{
    var t  = x[i].id;
	globaldetails2 +=document.getElementById(t).value;
	}

	var globaldetails='undefined';
	var x = document.getElementsByClassName('devdetails');
    for (var i = 0; i < x.length; i++) 
	{
    var t  = x[i].id;
	globaldetails +=document.getElementById(t).value;
	
	document.getElementById(t).onchange = function() 
	{
	var changedetails;
	var y = document.getElementsByClassName('devdetails');
    for (var i = 0; i < y.length; i++) 
	{
    var t  = y[i].id;
	changedetails +=document.getElementById(t).value;
	}
	if( changedetails != globaldetails)
		{
		globallock =' unsaved device actions';
		[ "aw_dist1","aw_dist2","aw_dist","aw_trig","aw_md20","aw_addevent","aw_dev"].forEach (lock,);
		randomdev.forEach (lock);
		}
	if( changedetails == globaldetails)
		{
		[ "aw_dist1","aw_dist2","aw_dist","aw_trig","aw_md20","aw_addevent","aw_dev"].forEach (unlock,);
			randomdev.forEach (unlock);
		}
	}
	}

// next   ##################################################
	

if ( DEVICETYP != 'dummy')
{
	var triggerdetails = document.getElementById('MSwitchWebTRDT').innerHTML;
	var saveddevice = TRIGGERDEVICEHTML;
	var sel = document.getElementById('trigdevnew');
	sel.onchange = function() 
	{
	trigdev = this.value;
	if (trigdev != TRIGGERDEVICEHTML)
		{
		globallock =' unsaved trigger';
		["aw_md20","aw_md","aw_dist1","aw_dist2","aw_dist","aw_dev", "aw_det"].forEach (lock);
		randomdev.forEach (lock,);
		}
	else
		{	
		["aw_md20","aw_md","aw_dist1","aw_dist2","aw_dist","aw_dev", "aw_det"].forEach (lock);
		randomdev.forEach (unlock);
		document.getElementById('MSwitchWebTRDT').innerHTML = triggerdetails;	
		}
	
	if (trigdev == 'all_events')
		{
		document.getElementById("triggerwhitelist").style.visibility = "visible"; 
		}
	else
		{
		document.getElementById("triggerwhitelist").style.visibility = "collapse"; 
		}
	}

}

// next   ##################################################


if (document.getElementById('trigon'))
{
	var trigonfirst = document.getElementById('trigon').value;
	var sel2 = document.getElementById('trigon');
	sel2.onchange = function() 
		{
		if (trigonfirst != document.getElementById('trigon').value)
			{
			closetrigger();
			}
			else{
			opentrigger();
			}
		}
	}
	
	if (document.getElementById('trigoff')){
	var trigofffirst = document.getElementById('trigoff').value;
	var sel3 = document.getElementById('trigoff');
	sel3.onchange = function() 
		{
		if (trigofffirst != document.getElementById('trigoff').value)
			{
			closetrigger();
			}
			else{
			opentrigger();
			}
		}
	}
	
	if (document.getElementById('trigcmdoff')){
	var trigcmdofffirst = document.getElementById('trigcmdoff').value;
	var sel4 = document.getElementById('trigcmdoff');
	sel4.onchange = function() 
		{
		if (trigcmdofffirst != document.getElementById('trigcmdoff').value)
			{
			closetrigger();
			}
			else{
			opentrigger();
			}
		}
	}
	
if (document.getElementById('trigcmdon'))
	{
		var trigcmdonfirst = document.getElementById('trigcmdon').value;
		var sel5 = document.getElementById('trigcmdon');
		sel5.onchange = function() 
		{
		if (trigcmdonfirst != document.getElementById('trigcmdon').value)
				{
				closetrigger();
				}
			else
				{
				opentrigger();
				}
		}
	}


	// teste auch showids
    var cookie = getCookieValue("Mswitch_ids_"+devicename);
	if (cookie == ""){
	}
	else{
	document.getElementById('aw_showid1').value=cookie;
	$("[name=noshow]").css("display","none");
	allids = cookie.split(",");

	for (i = 0; i < allids.length; i++) {
	test ="[idnumber="+allids[i]+"]";
	$(test).css("display","block");
	}
	}

return;
} // ende startfunktionen



function writeevent(line){
	
	encodedline = decodeURIComponent(line);
	var check = $("[name=eventmonitor]").prop("checked") ? "1":"0";
	if (check == 0)
		{
		return;
		}
	index = events.indexOf(encodedline);
	if (index > -1)
	{
		return;
	}
	events.push(encodedline);
	var newselect = $('<option value="'+encodedline+'">'+encodedline+'</option>');
	$(newselect).appendTo('#lf'); 
	return;
}


function writedebug(line){
	encodedline = decodeURIComponent(line);
	var old = document.getElementById("log").value;
	 var textarea = document.getElementById('log');
	 document.getElementById("log").value=old+'\n'+encodedline;
	 testautoscroll = $("[name=autoscroll]").prop("checked") ? "ja":"nein";
	 if (testautoscroll == 'ja')
		 {
		 textarea.scrollTop = textarea.scrollHeight;
	 }
	return;
}


//#####################################################################################################

function deletedistributor(line){
	//alert(line);
	if (debug == 'on'){ alert('deletedistributor') };
	
	document.getElementById('aw_dist1').style.display='none';
	document.getElementById('line1-'+line).innerHTML = '';
	document.getElementById('line2-'+line).innerHTML = '';
	checkdistricode()
	return;
}

function adddistributor(){
	if (debug == 'on'){ alert('adddistributor') };	//alert('line');
	
	document.getElementById('aw_dist1').style.display='none';
	
	var add = $( "#rawcode" ).html();
	add = add.replace(/LINENUMBER/gi,DISTRIBUTLINES);
	add = add.replace(/line1-/gi,"line1-"+DISTRIBUTLINES);
	add = add.replace(/line2-/gi,"line2-"+DISTRIBUTLINES);
	add = add.replace(/ideventNR/gi,"ideventNR"+DISTRIBUTLINES);
	add = add.replace(/ideventCMD/gi,"ideventCMD"+DISTRIBUTLINES);
	add = add.replace(/ideventID/gi,"ideventID"+DISTRIBUTLINES);
	DISTRIBUTLINES++;
	var old = $( "#Distributor" ).html();
	old = old.replace(/<!--newline-->/gi,add+"<!--newline-->");
	$( "#Distributor" ).html(old);
	checkdistricode()
	return;
}

function savedistributor(){
	if (debug == 'on'){ alert('savedistributor') };

	var newidfile='';
	for (i=0; i<DISTRIBUTLINES; i++)
		{
			aktline =  $("#ideventNR"+i).val();
			if (aktline === undefined) { continue; }
			if (aktline == 'undefined') { continue; }
			aktline = aktline.replace(/ /g,'[SP]');
			aktcmd=  $("#ideventCMD"+i).val();
			aktid=  $("#ideventID"+i).val();
			newidfile +=aktline+"=>cmd"+aktcmd+"[SP]ID[SP]"+aktid+"[NL]";		
		}
[ "aw_md","aw_trig","aw_md20","aw_addevent","aw_dev"].forEach (unlock,);
	randomdev.forEach (unlock);

	 var nm = $(t).attr("nm");
	var def = nm + " setbridge "+newidfile;
		
		
		location = location.pathname + "?detail=" + devicename + "&cmd=set " + addcsrf(def);
	
}


function checkdistricode(){
	
	// blockiert alles butttons wenn districode verändert
				globallock =' unsaved disributor ';
				[ "aw_md","aw_trig","aw_md20","aw_addevent","aw_dev"].forEach (lock,);
				randomdev.forEach (lock);	
	return;
}


function fullhelp(){

$("#helptext").css("display","block");

var text ="Mswitch hat eine im Frontend integrierte Hilfe.<br><br>\
Dafür bitte das Attribut MSwitch_Help auf 1 setzen.\n<br>\
Soll dieses Attribut jetzt aktiviert werden ? \
<input type='button' value='Ja' onclick='javascript: aktivatehelp()'>\
<br>\
<br>\
<br>&nbsp;\
";

$("#helptext").html(text);
 $('html, body').animate({
          scrollTop: $("#helptext").offset().top -80
        }, 500);


return;
}


function aktivatehelp(){
FW_cmd(FW_root+'?cmd=attr '+devicename+' MSwitch_Help 1&XHR=1');


var text ="<br><br>Hilfe wurde aktiviert. \
<input type='button' value='Seite neu laden' onclick='javascript: reload()'>\
<br>\
<br>\
<br>\
<br>\
<br>&nbsp;\
";


$("#helptext").html(text);
 $('html, body').animate({
          scrollTop: $("#helptext").offset().top -80
        }, 500);


return;
}


function hilfe(field){

	
	if (debug == 'on'){ alert('hilfe') };
	var text = HELP;
	text = text.replace(/#\[LINE\]/gi,"<br>");
	text = text.replace(/#\[A\]/gi,"'");
	text = text.replace(/#\[DA\]/gi,"\"");
	var myRegEx = new RegExp('<-.'+field+'-(.*?)(->)');  
	// <strong>MSwitch_Expert</strong>
	//alert(myRegEx);
	//alert(HELP);
	treffer = text.match(myRegEx);
	
	if( treffer == null){
	out = "dieser Hilfetext ist nicht vorhanden";
	}else{
	out = treffer[1];	
	}
	var textfinal ="<div style ='font-size: small;'>Hilfe "+field+":<br>"+ out +"</div>";
	FW_okDialog(textfinal);
	return;
}


function noarg(target,copytofield){
	if (debug == 'on'){ alert('noarg') };
	document.getElementById(copytofield).value = '';
	document.getElementById(target).innerHTML = '';
	return;
	}



function noaction(target,copytofield){
	if (debug == 'on'){ alert('noaction') };
	document.getElementById(copytofield).value = '';
	document.getElementById(target).innerHTML = '';
	return;}



// widgets frontend

 function slider(first,step,last,target,copytofield){
	if (debug == 'on'){ alert('slider') };
	var selected =document.getElementById(copytofield).value;
	var selectfield = "<div class='col3'><div class='fhemWidget' cmd='pct' reading='state' dev='webtestdummy' arg='slider,1,10,100' current='farbe test1'></div></div>";
	document.getElementById(target).innerHTML = selectfield + '<br>';
	FW_replaceWidgets();
	return;
	}  
	

 function colorpicker(aktuell,target,copytofield){
	if (debug == 'on'){ alert('slider') };
	var selected =document.getElementById(copytofield).value;
	var selectfield = "<input type='color' id='favcolor' name='favcolor' value='#ff0000'>";
	document.getElementById(target).innerHTML = selectfield + '<br>';
	return;
	}  


function textfieldlong(copytofield,target)
	{
	if (debug == 'on'){ alert('textfield') };
		var selected =document.getElementById(copytofield).value;
		var ID = Math.random();
		var ID1 = Math.random();
		var IDFinish =ID1+ID;
		if (copytofield.indexOf('cmdonopt') != -1) {
		var selectfield = "<input id='"+IDFinish+"' onClick='javascript:bigwindow(this.id);' type='text' size='30' value='" + selected +"' onfocus=\"javascript: showtextfield(this.value,'" + copytofield + "','" + target + "')\"     onchange=\"javascript: showtextfield(this.value,'" + copytofield + "','" + target + "')\"  >"  ;
		document.getElementById(target).innerHTML = selectfield + '<br>';	
		}
		else{
		var selectfield = "<input id='"+IDFinish+"' onClick='javascript:bigwindow(this.id);' type='text' size='30' value='" + selected +"' onfocus=\"javascript: showtextfield(this.value,'" + copytofield + "','" + target + "')\" onchange=\"javascript: showtextfield(this.value,'" + copytofield + "','" + target + "')\">"  ;
		document.getElementById(target).innerHTML = selectfield + '<br>';
		}
		return;
	}


function setargument(argument1,argument2){
document.getElementById(argument1).value=argument2;
return;
}



function changeinput(argument1,argument3,argument4,argument5){

	var argument2 = argument1+"_widget";
	var selected =document.getElementById(argument3).value;
	var myRegEx = new RegExp('\\[|\\$|{|\s');  
	treffer = selected.match(myRegEx);
	if (treffer !== null)
	{
		var sel ="";
		
		
		if (LANGUAGE == "DE"){sel = "Anzeige des Widgets ist mit angegebenen Werten nicht möglich ";}
		if (LANGUAGE == "EN"){sel = "The widget cannot be displayed with the specified values";}
		
		FW_okDialog(sel) ;
		return;
	}
	
var test = document.getElementById(argument1).style.display;
var test1 = document.getElementById(argument2).style.display;
var oldval = document.getElementById(argument3).value;
var tofield = argument3+"_oldval";


 if ( test1 == 'none'){
	 
	 activate(document.getElementById(argument5).value, argument1, argument4, argument3)
	 
 }
 else{
 $("#"+argument2+"").css("display","none");
 }


//textfeld wird an
if ( test == 'none'){
	
	document.getElementById(tofield).value = oldval;
	
$("#"+argument1+"").css("display","table-cell");
}
else{
$("#"+argument1+"").css("display","none");
}

return;
}



function makewidget(copytofield,target,werte){
	
	var selected =document.getElementById(copytofield).value;
	
	retoption1 ="<table border ='0'>";
	retoption1 +="<tr>";
	retoption1 +="<td>";
	retoption1 +="<div class='fhemWidget' type='set "+devicename+" wizardcont1 "+copytofield+" ' cmd='' reading='container' dev='' arg='"+werte+"' current='"+selected+"'></div>";
	retoption1 +="</td>";
	retoption1 +="</tr>";
	retoption1 +="</table>";

	document.getElementById(target+"_widget").innerHTML = retoption1  + '';
	
	$("#"+target+"").css("display","none");

	var datatarget =target;
	return;
}


function textfield(copytofield,target)
	{
	if (debug == 'on'){ alert('textfield') };
		var selected =document.getElementById(copytofield).value;
	
		if (copytofield.indexOf('cmdonopt') != -1) {
		var selectfield = "<input id='"+copytofield+"_oldval' type='text' size='30' value='" + selected +"' onfocus=\"javascript: showtextfield(this.value,'" + copytofield + "','" + target + "')\"     onchange=\"javascript: showtextfield(this.value,'" + copytofield + "','" + target + "')\"    >"  ;
		document.getElementById(target).innerHTML = selectfield + '';

		
		}
		else
		{
		var selectfield = "<input id='"+copytofield+"_oldval'  type='text' size='30' value='" + selected +"' onfocus=\"javascript: showtextfield(this.value,'" + copytofield + "','" + target + "')\" onchange=\"javascript: showtextfield(this.value,'" + copytofield + "','" + target + "')\"  >"  ;
		document.getElementById(target).innerHTML = selectfield + '';
		}
		return;
	}

function selectfield(args,target,copytofield){
	if (debug == 'on'){ alert('selectfield') };
	var cmdsatz = args.split(",");
	var selectstart = "<select id=\"" +target +"1\" name=\"" +target +"1\" onchange=\"javascript: aktvalue('" + copytofield + "',document.getElementById('" +target +"1').value)\">"; 
	var selectend = '<\select>';
	var option ='<option value="noArg">noArg</option>'; 
	var i;
	var len = cmdsatz.length;
	var selected =document.getElementById(copytofield).value;
	for (i=0; i<len; i++){
	if (selected == cmdsatz[i]){
	option +=  '<option selected value="' + cmdsatz[i] + '">' + cmdsatz[i] + '</option>';
	}
	else{
	option +=  '<option value="' + cmdsatz[i] + '">' + cmdsatz[i] + '</option>';
	}
	}
	var selectfield = selectstart + option + selectend;
	document.getElementById(target).innerHTML = selectfield + '<br>';	
	return;
	}
	
	
function activate(state,target,options,copytofield){
	////aufruf durch selctfield
	if (debug == 'on'){ alert('activate') };
	debug = 'state: '+state+'<br>';
	debug += 'target: '+target+'<br>';
	debug += 'options: '+options+'<br>';
	debug += 'copytofield: '+copytofield+'<br>';
	
	var globaldetails3='undefined';
	var x = document.getElementsByClassName('devdetails2');
    for (var i = 0; i < x.length; i++) 
		{
		var t  = x[i].id;
		globaldetails3 +=document.getElementById(t).value;
		}
	if ( globaldetails2 && globaldetails2 != 'start')
		{
		if (globaldetails3 != globaldetails2)
			{
			globallock =' unsaved device actions';
				[ "aw_dist1","aw_dist2","aw_dist","aw_trig","aw_md20","aw_addevent","aw_dev"].forEach (lock,);
				randomdev.forEach (lock);
			}
		else
			{
			[ "aw_dist1","aw_dist2","aw_dist","aw_trig","aw_md20","aw_addevent","aw_dev"].forEach (unlock,);
					randomdev.forEach (unlock);
			}
		}
	if (state == 'no_action')
		{
			
	var but = target+"_but";
	var widget = target+"_widget";

	 $("#"+but+"").css("display","none");
	 $("#"+widget+"").css("display","none");
		return;
		
		}
		
	var optionarray = options.split(" ");
	var werte = new Array();
	for (var key in optionarray )
	{
		var satz = optionarray[key].split(":");
		var wert1 = satz[0];
		wert3 = satz[1];
		satz.shift() ;
		var wert2 = satz.join(":");
		werte[wert1] = wert2;
	}
	var devicecmd = new Array();
	if ( werte[state] == '') 
		{
		werte[state]='textField';
		}	
	devicecmd = werte[state].split(",");
	
	if (devicecmd[0] == 'noArg'){noarg(target,copytofield);}
	else if (devicecmd[0] == 'no_Action')
	{
		noaction();
	}
	
	else if (devicecmd[0] == 'textfieldLong'){textfieldlong(copytofield,target);}
	else {textfield(copytofield,target);}
	
	if (webwidget == 1 && state != '[FREECMD]' && devicecmd[0] != "noArg" && devicecmd[0] != "textField" )
	{

	var selected =document.getElementById(copytofield).value;
	var myRegEx = new RegExp('\\[|\\$|{|\s');  
	treffer = selected.match(myRegEx);
	
	
	if ( werte[state]  != "noArg" && treffer === null)
	{
	makewidget(copytofield,target,werte[state]);
	
	var r = $("head").attr("root");
		if(r)
		FW_root = r;
		FW_replaceWidgets($("html"));
		 
	
	var but = target+"_but"; 
	$("#"+but+"").css("display","");
	
	var widget = target+"_widget";
	 $("#"+widget+"").css("display","table-cell");
	 return;
	 
	 
	}
	else if ( werte[state]  != "noArg"  && treffer !== null )
	{
		
	makewidget(copytofield,target,werte[state]);
	
	var r = $("head").attr("root");
		if(r)
		FW_root = r;
		FW_replaceWidgets($("html"));
		 
	
	var but = target+"_but"; 
	$("#"+but+"").css("display","");
	
	
	$("#"+target+"").css("display","table-cell");
	
	var widget = target+"_widget";
	 $("#"+widget+"").css("display","none");
	 return;	

	}
	}
	
	var but = target+"_but";
	var widget = target+"_widget";
	$("#"+but+"").css("display","none");
	$("#"+widget+"").css("display","none");
	
	return;
	}
	
// ###############################################
function testcmd(field,cmdname,opt,eventfield){
	if (debug == 'on'){ alert('testcmd') };
	comand = $("[name="+field+"]").val();
	comand=comand.trim();
	
 	if (comand == 'no_action')
		{
		return;
		}

	if (cmdname != 'FreeCmd')
		{
		comand1 = $("[name="+opt+"]").val();
		comand =comand+" "+comand1;
		comand = comand.replace(/ /g,'#[sp]');
		comand =comand+" "+eventfield;
		cmd ='get '+devicename+' extcmd '+cmdname+' '+encodeURIComponent(comand);
		FW_cmd(FW_root+'?cmd='+cmd+'&XHR=1', function(resp){FW_okDialog(resp);});
		} 
	else
		{
		comand = comand.replace(/ /g,'#[sp]')
		comand = comand.replace(/;/g,'#[se]')
		comand = comand.replace(/\n/g,'#[nl]')
		comand =comand+" "+eventfield;
		cmd ='get '+devicename+' extcmd '+cmdname+' '+encodeURIComponent(comand);
		FW_cmd(FW_root+'?cmd='+cmd+'&XHR=1', function(resp){FW_okDialog(resp);});
		} 
	return;	
	}


function closetrigger(){
	if (debug == 'on'){ alert('closetrigger') }
			globallock =' unsaved trigger details';
			["aw_dist1","aw_dist2","aw_dist","aw_dev", "aw_det","aw_trig","aw_md20","aw_addevent"].forEach (lock,);
			randomdev.forEach (lock);
	}
	
function opentrigger(){
	if (debug == 'on'){ alert('opentrigger') }
			["aw_dist1","aw_dist2","aw_dist", "aw_dev","aw_det","aw_trig","aw_md20","aw_addevent"].forEach (unlock,);
			randomdev.forEach (unlock);
	}


function reload(){
if (debug == 'on'){ alert('reload') }
	window.location.href="/fhem?detail="+devicename;
	}


function newname(){
if (debug == 'on'){ alert('newname') }
	newname = document.getElementById('newname').value;
	if (devicename == newname){return;}
	if (newname == ''){return;}
	comand = 'rename'+devicename+newname;
	
	cmd = comand;
	
	window.location.href="/fhem?cmd=rename "+devicename+" "+newname+"&detail="+newname+""+CSRF;
	return;
	} 
	
	
	
function rename(device){
if (debug == 'on'){ alert('rename') }


	newname = document.getElementById('ren2_'+device).value;
	if (devicename == device){return;}
	if (newname == ''){return;}
	
	conf=device+" "+newname;
	var nm = $(t).attr("nm");
	var  def = nm+" change_renamed "+encodeURIComponent(conf);
	location = location.pathname+"?detail="+devicename+"&cmd=set "+addcsrf(def);
	
	return;
	} 
	

// sperrt eingabefelder
function lock(elem, text){
	
	return;
	
if (debug == 'on'){ alert('lock') }
	if (document.getElementById(elem)){
	document.getElementById(elem).style.backgroundColor = "#ADADAD";
	document.getElementById(elem).disabled = true;
	if (!document.getElementById(elem).model)
	{
	document.getElementById(elem).model=document.getElementById(elem).value;
	}
	document.getElementById(elem).value = 'N/A'+globallock;
	}
	}

function unlock(elem, index){
	
	return;
if (debug == 'on'){ alert('unlock') }
	if (document.getElementById(elem)){
	document.getElementById(elem).style.backgroundColor = "";
	document.getElementById(elem).disabled = false;
	if (document.getElementById(elem).model === undefined)
	{
		return;
	}	
	document.getElementById(elem).value=document.getElementById(elem).model;
	
	}
}
	
function saveconfig(conf){
	if (debug == 'on'){ alert('saveconfig') };
	conf = conf.replace(/\n/g,'#[EOL]'); // !!!
	conf = conf.replace(/:/g,'#c[dp]');
	conf = conf.replace(/;/g,'#c[se]');
	conf = conf.replace(/ /g,'#c[sp]');
	var nm = $(t).attr("nm");
	var  def = nm+" saveconfig "+encodeURIComponent(conf);
	location = location.pathname+"?detail="+devicename+"&cmd=set "+addcsrf(def);
	}

 
function vupdate(){
	if (debug == 'on'){ alert('vupdate') };
    conf='';
	var nm = $(t).attr("nm");
	var  def = nm+" VUpdate "+encodeURIComponent(conf);
	location = location.pathname+"?detail="+devicename+"&cmd=set "+addcsrf(def);
	}

// Fenster für Schaltbedingungen	
function bigwindow(targetid,fromsc,type){
if (debug == 'on'){ alert('bigwindow') };



if(typeof fromsc == 'undefined'){
	fromsc = "noweb";
}

if(typeof type == 'undefined'){
	type = 0;
}

	targetval =document.getElementById(targetid).value;
	targetval = targetval.replace(/\u2424/g,'\n');
	sel ='<div style="white-space:nowrap;"><br>';
	sel = sel+'<textarea id="valtrans" cols="130" name="TextArea1" rows="10" onChange="bigwindowformat(\''+targetid+'\',\''+fromsc+'\')">'+targetval+'</textarea>';
	sel = sel+'</div>';
	
	if (type===1)
	{
	sel = sel+varinf;
	}
	
	FW_okDialog(sel,''); 
	}	


function showvars(){

$("#vars").css("display","block");
$("#t1").css("display","none");
$("#t2").css("display","block");
return;
}

function hidevars(){

$("#vars").css("display","none");
$("#t1").css("display","block");
$("#t2").css("display","none");
return;
}

function bigwindowformat(targetid,fromsc){
	if (debug == 'on'){ alert('bigwindowformat') };
	var value = document.getElementById('valtrans').value
	
	if (fromsc == "web"){
	value = value.replace(/\n/g, '\u2424');
	}
	document.getElementById(targetid).value=value; 
 
}


	// gruppen anzeigen
	function  showgroup(group){
	cmd ='set '+devicename+' showgroup '+group;
	FW_cmd(FW_root+'?cmd='+encodeURIComponent(cmd)+'&XHR=1');
		 return;
	 } 
	  
// lösche log
function deletelog() {
if (debug == 'on'){ alert('deletelog') };
	anzahl =document.getElementById('dellog').value;
	arg ='';
	for (i = 1; i <  anzahl; i++) {
	test = document.getElementById('Checkbox-' + i).checked;
	if (document.getElementById('Checkbox-' + i).checked)
	{
	arg=arg+i+',';
	}
	}
	conf=arg;
	var nm = $(t).attr("nm");
	var  def = nm+" deletesinglelog "+encodeURIComponent(conf);
	location = location.pathname+"?detail="+devicename+"&cmd=set "+addcsrf(def);
	return;
	}
	
	
// löscht vergösserte Fenster
function removeFn() {
if (debug == 'on'){ alert('removefn') };
    var targ = document.getElementById('devices');
    for (i = 0; i < targ.options.length; i++)
		{
		test = document.getElementById('Checkbox-' + i).checked;
		targ.options[i].selected = false;
		if (test)
			{
			targ.options[i].selected = true;
			}
		}
	}
	
// reset device	
function reset(option) {
if (debug == 'on'){ alert('reset') };
	var nm = $(t).attr("nm");
	
	if (option == "check"){
	var  def = nm+" reset_device";
	}else{
	var  def = nm+" reset_device checked";
	}
	location = location.pathname+"?detail="+devicename+"&cmd=set "+addcsrf(def);
	return;
	}	
	
	
	
// geräteauswahl
function selectdevices(){
	var ausw=document.getElementById('affected_second_devices');
	for (i=0; i<ausw.options.length; i++)
		{
		var pos=ausw.options[i];
			if(pos.selected)
			{
				if (ALLDEVICESSELECTED.includes(pos.value))
				{
					continue;
				}
				
				
				
				ALLDEVICESSELECTED.unshift(pos.value);
				
				
			}
			
			
		// prüfe auf doubletten
		const filteredArray = ALLDEVICESSELECTED	
		var selectElement = document.getElementById('affected_third_devices');
		for (var key in filteredArray) 
			{
				
				//alert(key);
			if (filteredArray[key] != ""){
			var option = new Option(filteredArray[key], filteredArray[key]);
			selectElement.options[key] = option;
			
				}
			
			}
		}		
		return;
}
	
	
	// geräteauswahl entfernen
function deletedevices(){
	
	var NEWLIST=[];
	var ausw=document.getElementById('affected_third_devices');
	for (i=0; i<ausw.options.length; i++)
		{
		var pos=ausw.options[i];
			if(pos.selected)
			{
			continue;
			}
		NEWLIST.unshift(pos.value);	
		}
				
var select = document.getElementById("affected_third_devices");
var length = select.options.length;
for (i = length-1; i >= 0; i--) {
  select.options[i] = null;
}
			
		var selectElement = document.getElementById('affected_third_devices');
		for (var key in NEWLIST) 
			{
			var option = new Option(NEWLIST[key], NEWLIST[key]);
			selectElement.options[key] = option;
			}
			ALLDEVICESSELECTED=NEWLIST;
		var length = select.options.length;	
		if (length < 1){
		$(affected_third_devices).css("width","175px");	
		}
		else{
			
			$(affected_third_devices).css("width","");	
		}
		return;
}	
	


function searchdevice(){
	var value = document.getElementById('searchstring').value;
	var akttype = document.getElementById('modtype').value;
	var regex = new RegExp(value, 'gi');
	var NEWLIST=[];
	var NEWLISTALIAS=[];
	var NEWLISTTYPES=[];
	for (var key in ALLDEVICES)
	{
		var testdevice = ALLDEVICES[key]+"(a:"+ALLDEVICESALIAS[key]+")";
		treffer = testdevice.match(regex);
		
		if (treffer === null)
		{
		}
		else
		{
			if ( akttype ==".*" || akttype == ALLDEVICESTYPE[key] )
			{
				NEWLIST.push(ALLDEVICES[key]);	
				NEWLISTALIAS.push(ALLDEVICESALIAS[key]);
				NEWLISTTYPES.push(ALLDEVICESTYPE[key]);
			}
		}
	}
	
	
	var select = document.getElementById("affected_second_devices");
	var length = select.options.length;

	for (i = length-1; i >= 0; i--) 
	{
	  select.options[i] = null;
	}
	
	var selectElement = document.getElementById('affected_second_devices');

	if (value =="" && akttype ==".*")
	{
		NEWLIST=ALLDEVICES;
		NEWLISTALIAS=ALLDEVICESALIAS;
		}
	
	
	for (var key in NEWLIST)
	{	
		if (NEWLIST[key] == ""){continue;}	
		var option = new Option(NEWLIST[key], NEWLIST[key]);
		var option = new Option(NEWLIST[key]+" (a:"+NEWLISTALIAS[key]+")", NEWLIST[key]);
		selectElement.options[key] = option;
	}
	return;
	}
	
	
function searchtriggerdevice(){
	var value = document.getElementById('searchstringtrigger').value;
	var selectElement = document.getElementById('trigdevnew');
	var regex = new RegExp(value, 'gi');
	var NEWLIST=[];
	var NEWLISTALIAS=[];

	for (var key in ALLDEVICESTOTRIGGERZUSATZ)
	{
		var testdevice = ALLDEVICESTOTRIGGERZUSATZ[key];
		treffer = testdevice.match(regex);
		
		if (treffer === null)
		{
		}
		else
		{
				NEWLISTALIAS.push(ALLDEVICESTOTRIGGERZUSATZ[key]);	
				NEWLIST.push(ALLDEVICESTOTRIGGER[key]);
			
		}
	}
	
	var length = selectElement.options.length;

	for (i = length-1; i >= 0; i--) 
	{
	  selectElement.options[i] = null;
	}
	
	for (var key in NEWLIST)
	{	
		if (NEWLIST[key] == ""){continue;}	
		var option = new Option(NEWLISTALIAS[key], NEWLIST[key]);
		selectElement.options[key] = option;
		
		if (NEWLIST[key] == DEVICETOTRIGGERSELECT){
		selectElement.options[key].selected = true;}
	}
	
	if ( NEWLIST.length < 10)
	{
		selectElement.size = NEWLIST.length;
	}
	else
	{
		selectElement.size = "1";
	}
	}
	
	
// events from monitor to edit
function transferevent(){
if (debug == 'on'){ alert('transferevent') };
		var values = $('#lf').val();
		if (values){
		var string = values.join(',');
		document.getElementById('add_event').value = string;
		}
	}
	
	
// Sortierung ändern
function changesort(){
if (debug == 'on'){ alert('changesort') };
	sortby = $("[name=sort]").val();
	var nm = $(t).attr("nm");
	var  def = nm+" sort_device "+sortby;
	location = location.pathname+"?detail="+devicename+"&cmd=set "+addcsrf(def);
	}

// device zufügen
function addevice(device){
if (debug == 'on'){ alert('adddevice') };
	var nm = $(t).attr("nm");
	var  def = nm+" add_device "+device;
	location = location.pathname+"?detail="+devicename+"&cmd=set "+addcsrf(def);
	}
	
// device löschen
function deletedevice(device){
if (debug == 'on'){ alert('deletedevice') };
	var nm = $(t).attr("nm");
	var  def = nm+" del_device "+device;
	location = location.pathname+"?detail="+devicename+"&cmd=set "+addcsrf(def);
	}

// unbekannt		
function aktvalue(target,cmd){
if (debug == 'on'){ alert('aktvalue') };
	document.getElementById(target).value = cmd; 
	return;
	}

// unbekannt
function writeattr(){
if (debug == 'on'){ alert('writeattr') };
    conf='';
	var nm = $(t).attr("nm");
	var  def = nm+" Writesequenz "+encodeURIComponent(conf);
	location = location.pathname+"?detail="+devicename+"&cmd=set "+addcsrf(def);
	}

// lösche log
function clearlog(){
if (debug == 'on'){ alert('clearlog') };
    
	clearlogwindow()
	FW_cmd(FW_root+'?cmd=set '+devicename+' clearlog &XHR=1');
	return;
	 }
	 
// lösche log
function clearlogwindow(){
if (debug == 'on'){ alert('clearlogwindow') };
     document.getElementById("log").value='';
	 return;
	 }
// unbekannt	
 
function savesys(conf){
if (debug == 'on'){ alert('savesys') };



	/* conf = conf.replace(/:/g,'#[dp]');
	conf = conf.replace(/;/g,'#[se]');
	conf = conf.replace(/ /g,'#[sp]');
	conf = conf.replace(/'/g,'#[st]');
	conf = conf.replace(/\t/g,'#[tab]');
	 */
	
	
	conf = conf.replace(/&nbsp;/g,'&#160')
	
	//alert(conf);
	
	//return;
	conf=str2hex(conf);
	
	
	
	//
	
	
	var nm = $(t).attr("nm");
	var  def = nm+" savesys "+encodeURIComponent(conf);
	
	
	var  def = nm+" savesys "+conf;
	
	location = location.pathname+"?detail="+devicename+"&cmd=set "+addcsrf(def);
	}

// unbekannt
 function showValue(newValue,copytofield,target){
	if (debug == 'on'){ alert('showValue') };
	var opt = target + '_opt';
	document.getElementById(opt).value=newValue;
	document.getElementById(copytofield).value = newValue;
	}

// unbekannt

function getCookieValue(a) {
   const b = document.cookie.match('(^|;)\\s*' + a + '\\s*=\\s*([^;]+)');
   return b ? b.pop() : '';
}


function showtextfield(newValue,copytofield,target)
	{
	if (debug == 'on'){ alert('showtextfield') };
	//alert("showtextfield");
	document.getElementById(copytofield).value = newValue;
	}

// unbekannt
function checkevent(event){	
if (debug == 'on'){ alert('checkevent') };
	event = event.replace(/ /g,'~');
	cmd ='get '+devicename+' checkevent '+event;
	FW_cmd(FW_root+'?cmd='+encodeURIComponent(cmd)+'&XHR=1');
	}
	
	
function checkcondition(condition,event){	
if (debug == 'on'){ alert('checkcondition') }
	var selected =document.getElementById(condition).value;
	if (selected == '')
		{
		var textfinal = "<div style ='font-size: medium;'>"+NOCONDITION+"</div>";
		FW_okDialog(textfinal);
		return;
		}

	 
	//selected = selected.replace(/\./g,'#[pt]'); // !!!
	//selected = selected.replace(/:/g,'#[dp]');
	//selected= selected.replace(/~/g,'#[ti]');
	//event = event.replace(/~/g,'#[ti]');
	
	
	selected = selected.replace(/\|/g,'(DAYS)'); // !!!
	selected = selected.replace(/ /g,'#[sp]');
	event = event.replace(/ /g,'#[sp]');
	  
	transfer = selected+'|'+event;
	transfer= str2hex(transfer);
	
	cmd ='get '+devicename+' checkcondition '+transfer;

	FW_cmd(FW_root+'?cmd='+cmd+'&XHR=1', function(resp){FW_okDialog(resp);});
	}
	
	
	$("#trigon").click(function(){
	trigon = $("[name=trigon]").val();	
	$("#add_event").val(trigon);
	return;
	});	
	
	$("#trigoff").click(function(){
	trigoff = $("[name=trigoff]").val();	
	$("#add_event").val(trigoff);
	return;
	});	
	
	$("#trigcmdoff").click(function(){
	trigcmdoff = $("[name=trigcmdoff]").val();	
	$("#add_event").val(trigcmdoff);
	return;
	});	
	
	$("#trigcmdon").click(function(){
	trigcmdon = $("[name=trigcmdon]").val();	
	$("#add_event").val(trigcmdon);
	return;
	});	
// next 

	
	$("#eventmonitor").click(function(){
	var check = $("[name=eventmonitor]").prop("checked") ? "1":"0";
	if (check == 1)
		{
		$( "#log2" ).text( "" );
		$( "#log1" ).text( "eingehende events:" );
		$( "#log3" ).text( "" );
		var field = $('<br><select style="width: 30em;" size="5" id ="lf" multiple="multiple" name="lf" size="6"  onchange="javascript:transferevent()"></select>');
		$(field).appendTo('#log2');
		events = [];
		return;
		}
		else{
			
		$( "#log2" ).text( "" );
		$( "#log1" ).text( "" );
		$( "#log3" ).text( "" );	
			events = [];
		return;
		}
	});
	

// next
	
	$("#activelog").click(function(){
	var checka = $("[name=activelogging]").prop("checked") ? "1":"0";
	var arg = "set eventtest logging";
	FW_cmd(FW_root+'?cmd=set '+devicename+' logging '+checka+'&XHR=1');
	return;
	});
	
	
// clickfunktions
// modify trigger aw_save
	$("#aw_md").click(function(){
	if (debug == 'on'){ alert('#aw_md') };
	var nm = $(t).attr("nm");
	trigon = $("[name=trigon]").val();
	trigon = trigon.replace(/ /g,'~');
	trigoff = $("[name=trigoff]").val();
	trigoff = trigoff.replace(/ /g,'~');
	trigcmdon = $("[name=trigcmdon]").val();
	trigcmdon = trigcmdon.replace(/ /g,'~');
	trigcmdoff = $("[name=trigcmdoff]").val();
	if(typeof(trigcmdoff)=="undefined"){trigcmdoff="no_trigger"}
	trigcmdoff = trigcmdoff.replace(/ /g,'~');
	//trigsave = $("[name=aw_save]").prop("checked") ? "ja":"nein";
	trigsave = 'nosave';
	trigwhite = $("[name=triggerwhitelist]").val();
	if (trigcmdon == trigon  && trigcmdon != 'no_trigger' && trigon != 'no_trigger'){
	FW_okDialog('on triggers for \'switch Test on + execute on commands\' and \'execute on commands only\' may not be the same !');
	return;
	} 
	if (trigcmdoff == trigoff && trigcmdoff != 'no_trigger' && trigoff != 'no_trigger'){
	FW_okDialog('off triggers for \'switch Test off + execute on commands\' and \'execute off commands only\' may not be the same !');
	return;
	} 
	if (trigon == trigoff && trigon != 'no_trigger'){
	FW_okDialog('trigger for \'switch Test on + execute on commands\' and \'switch Test off + execute off commands\' must not both be \'*\'');
	return;
	} 
	var  def = nm+" trigger "+trigon+" "+trigoff+" "+trigsave+" "+trigcmdon+" "+trigcmdoff+" "  ;
	location = location.pathname+"?detail="+devicename+"&cmd=set "+addcsrf(def);
	});
	
	// umschalten permanentes eventsave
	$("#eventsave").click(function(){
	if (debug == 'on'){ alert('#eventsave') };
	
	trigsave = $("[name=aw_save]").prop("checked") ? "on":"off";
	FW_cmd(FW_root+'?cmd=setreading '+devicename+' .Trigger_log '+trigsave+'&XHR=1');
	return;
	});

	// unbekannt
	$("#aw_little").click(function(){
	if (debug == 'on'){ alert('#aw_little') };
	var veraenderung = 3; // Textfeld veraendert sich stets um 3 Zeilen
	var sel = document.getElementById('textfie').innerHTML;
	var show = document.getElementById('textfie2');
	var2 = "size=\"6\"";
	var result = sel.replace(/size=\"15\"/g,var2);
	document.getElementById('textfie').innerHTML = result;      
	});
	
	//delete trigger
	$("#aw_md20").click(function(){
	if (debug == 'on'){ alert('#aw_md20') };
	//alert('#aw_md20')
	var nm = $(t).attr("nm");
	var  def = nm+" del_trigger ";
	location = location.pathname+"?detail="+devicename+"&cmd=set "+addcsrf(def);
	});
		
	//delete svedcmds
	$("#del_savecmd").click(function(){
	if (debug == 'on'){ alert('#del_savecmd') };
	var nm = $(t).attr("nm");
	var  def = nm+" delcmds ";
	location = location.pathname+"?detail="+devicename+"&cmd=set "+addcsrf(def);
	});	
	
// geräteauswahl speichern
	$("#aw_dev").click(function(){
	if (debug == 'on'){ alert('#aw_dev') };
	var nm = $(t).attr("nm");
	devices = $("[name=affected_devices]").val();
	
	

	var  def = nm+" devices "+devices+" ";
	location = location.pathname+"?detail="+devicename+"&cmd=set "+addcsrf(def);
	}); 
	
	// geräteauswahl speichern neu
	$("#aw_new_dev").click(function(){
	if (debug == 'on'){ alert('#aw_dev') };
	var nm = $(t).attr("nm");
	
	var NEWLIST=[];
	var ausw=document.getElementById('affected_third_devices');
	
	//alert ("-"+ausw.options.length+"-");
	
	if (ausw.options.length >  0)
	{
	
	for (i=0; i<ausw.options.length; i++)
		{
		var pos=ausw.options[i];
		
		if (pos.value !=""){
		NEWLIST.unshift(pos.value);
		}
		
		}
	}
	else{
		NEWLIST="null";
	}
	
	var  def = nm+" devices "+NEWLIST+" ";
	location = location.pathname+"?detail="+devicename+"&cmd=set "+addcsrf(def);
	}); 
	
//zeige versteckte geräte
	$("#aw_show").click(function(){
	if (debug == 'on'){ alert('#aw_show') };
	$("[name=noshow]").css("display","block");
	var jetzt = new Date();
	var Auszeit = new Date(jetzt.getTime());
	document.cookie = "Mswitch_ids_"+devicename + "=" + "" + "; expires=" + Auszeit.toGMTString() + ";";
	document.getElementById('aw_showid1').value="";
	$("#anzid").html('0');
	});
	
	
// zeige geräte mit ID
	$("#aw_showid").click(function(){
	if (debug == 'on'){ alert('#aw_show') };
	//alert("ok");
	showids = document.getElementById('aw_showid1').value;

	// cookie setzen
	var jetzt = new Date();
	var Verfall = 1000 * 60 * 60 *12;
	var Auszeit = new Date(jetzt.getTime() + Verfall);
	document.cookie = "Mswitch_ids_"+devicename + "=" + showids + "; expires=" + Auszeit.toGMTString() + ";";
	if (showids == "")
	{
		$("[name=noshow]").css("display","block");
		return;
	}
	
	
	
	
	$("[name=noshow]").css("display","none");
	allids = showids.split(",");
	for (i = 0; i < allids.length; i++) {
	test ="[idnumber="+allids[i]+"]";
	$(test).css("display","block");
	}
	allcmds=$("[name=noshow]:hidden").length;	
	$("#anzid").html(allcmds);
	});
	
	// Helpauslöser
	
	$("#detLink select#moreCmds").change(function(){
   //doDetCmd($(this).find("option:selected").attr("data-cmd"));
   
   var sel = $(this).find("option:selected").attr("new-cmd");
   execbottomline(sel);
   return;
  });
	
	
	

//unbekannt	
	$("#aw_addevent").click(function(){
	if (debug == 'on'){ alert('#aw_addevent') };
	var nm = $(t).attr("nm");
	event = $("[name=add_event]").val();
	event= event.replace(/ /g,'[sp]');
	event= event.replace(/\|/g,'[bs]');
	if (event == '')
		{
		return; 
		}	  
	var  def = nm+" addevent "+event+" ";
	location = location.pathname+"?detail="+devicename+"&cmd=set "+addcsrf(def);
	});
	
//Timer und Trigger speichern
	$("#aw_trig").click(function(){
	if (debug == 'on'){ alert('#aw_trig') };	
	var nm = $(t).attr("nm");
	trigdev = $("[name=trigdevnew]").val();
	
	timeon =  $("[name=timeon]").val();
	if(typeof(timeon)=="undefined"){timeon="NoTimer"};
	if(timeon==""){timeon="NoTimer"};
	
	timeoff =  $("[name=timeoff]").val();
	if(typeof(timeoff)=="undefined"){timeoff="NoTimer"};
	if(timeoff==""){timeoff="NoTimer"};
	
	timeononly =  $("[name=timeononly]").val();
	if(typeof(timeononly)=="undefined"){timeononly="NoTimer"};
	if(timeononly==""){timeononly="NoTimer"};
	
	timeoffonly =  $("[name=timeoffonly]").val();
	if(typeof(timeoffonly)=="undefined"){timeoffonly="NoTimer"};
	if(timeoffonly==""){timeoffonly="NoTimer"};
	
	timeonoffonly =  $("[name=timeonoffonly]").val();
	if(typeof(timeonoffonly)=="undefined"){timeonoffonly="NoTimer"};
	if(timeonoffonly==""){timeonoffonly="NoTimer"};
	
	trigdevcond = $("[name=triggercondition]").val();
	if(typeof(trigdevcond)=="undefined")
	{
		//alert ("cond undef");
		trigdevcond="NoCondition";
}
	if(trigdevcond=="")
	{
		//alert("cond leer");
		trigdevcond="NoCondition";
		}
	
	
	//trigdevcond= str2hex(trigdevcond);
	
	//alert(trivdevcondHEX);
	
	//trigdevcond = trigdevcond.replace(/\\./g,'#[pt]');
	//trigdevcond = trigdevcond.replace(/:/g,'#[dp]');
	//trigdevcond= trigdevcond.replace(/~/g,'#[ti]');
	trigdevcond = trigdevcond.replace(/ /g,'#[sp]');
	
	
	trigwhite = $("[name=triggerwhitelist]").val();
	
	
	var transfer = trigdev+" "+timeon+" "+timeoff+" "+timeononly+" "+timeoffonly+" "+timeonoffonly+" "+trigdevcond+" "+trigwhite+" " ;
	transfer = transfer.replace(/\n/g, '[NEXTTIMER]');
	transfer = transfer.replace(/\u2424/g,'[NEXTTIMER]');
	
	
	
	//alert(transfer);
	transfer = str2hex(transfer);
	
	//var  def = nm+" set_trigger  "+trigdev+" "+timeon+" "+timeoff+" "+timeononly+" "+timeoffonly+" "+timeonoffonly+" "+trigdevcond+" "+trigwhite+" " ;
	var  def = nm+" set_trigger  "+transfer ;


//alert(def);
//return;
	//def =  encodeURIComponent(def);
	location = location.pathname+"?detail="+devicename+"&cmd=set "+addcsrf(def);
	});
	


function checklines(name)
{
	if (checkfield != name){
	text = $("[name="+name+"]").val();
	var zeilen = 0;
	var pos = 0;
	while (pos !== -1) {
	zeilen++;
	pos = text.indexOf("\n", pos + 1);
	} 
	checkfield = name;
	if (zeilen < 10){
	zeilen = 10;
	}
	
	if (zeilen > 100){
	zeilen = 100;
	}
	
	$("[name="+name+"]").attr('rows', zeilen);
	}
	return;
}

function readhelp()
{
	return;
}


function raw()
{
	if( $("#rawDef").length > 0 ) {
	$("#rawDef").remove(); 
	return;
	}
	
	FW_cmd(FW_root+'?cmd=set '+devicename+' getraw &XHR=1', function(data){raw1(data)});
	return;
}


function raw1(data)
{

	var textAreaStyle = typeof AddCodeMirror == 'function'?'opacity:0':'';
	 $("#content").append('<div id="rawDef">'+
          '<textarea id="td_rawDef" rows="25" cols="60" style="width:99%; '+
                textAreaStyle+'"/>'+
        '<br><br></div>');
	
	data='defmod '+devicename+' MSwitch HEX '+data;
	document.getElementById('td_rawDef').value=data;

    $('html, body').animate({ scrollTop: $("#rawDef").offset().top}, 100);
	return;
}


function showedit(data)
{

	field=data+"-EDIT";
	field1=data+"-PLAIN";
	field2=data+"-BUTTON";
	field3=data+"-SAVE";

fieldx = field.replace(/\./,'\\.');
field1x = field1.replace(/\./,'\\.');
field2x = field2.replace(/\./,'\\.');
field3x = field3.replace(/\./,'\\.');

if( $("#"+field3x).val() =="empty" ) {
	inhalt = generatesaved(data);
	$("#"+field3x).val(inhalt);
	}

	$("[name="+fieldx+"]").css("display","");
	$("[name="+field1x+"]").css("display","none");
	 
	newname  = $("#"+field2x).attr('text1');
	
	document.getElementById(field2).value=newname;
	
	check = "javascript: hideedit(\""+data+"\") ";
	$("[name="+field2x+"]").attr('onClick', check);
	
	field10=data+"-SAVE-BUTTON";
	field10 = field10.replace(/\./,'\\.');
	
	$("#"+field10).css("display","none");
	return;

}

function hideedit(data)
{
	
	datax = data.replace(/\./,'\\.');

	fieldx=datax+"-EDIT";
	field1x=datax+"-PLAIN";
	field2x=datax+"-BUTTON";
	field3x=datax+"_plain1";
	field6x=datax+"_plain2";
	
	$("[name="+fieldx+"]").css("display","none");
	$("[name="+field1x+"]").css("display","block");

	newname  = $("#"+field2x).attr('text2');
	document.getElementById(field2).value=newname;
	
	check = "javascript: showedit(\""+data+"\") ";
	$("[name="+field2x+"]").attr('onClick', check);

	field4x=datax+"_on";
	inhalt1 = "CMD1: "+$('#'+field4x+'').val();

	field5x="cmdonopt"+datax+"1";
    inhalt2 = $('#'+field5x+'').val();

	newinhalt = inhalt1+" "+inhalt2;

	field4x=datax+"_off";
	inhalt1 = "CMD2: "+$('#'+field4x+'').val();
	field5x="cmdoffopt"+datax+"1";
    inhalt2 = $('#'+field5x+'').val();
	newinhalt1 = inhalt1+" "+inhalt2;
devicetypetest = $("[name=devicename"+datax+"]").val();
let result = devicetypetest.match(/FreeCmd-AbsCmd.*/ig);

if( result == null ) 
	{	

	$("#"+field3x+"").text(newinhalt);
	$("#"+field6x+"").text(newinhalt1);
		
	}
	else
	{
		cmdonopt=$("[name=cmdonopt"+datax+"]").val();	
		cmdoffopt=$("[name=cmdoffopt"+datax+"]").val();
		textbreak = $("#"+field3x+"").attr('cut');

		if ( cmdonopt.length > textbreak)
		{
			$("#"+field3x+"").text(""+$("#"+field3x+"").attr('text'));
		}
		else{
			$("#"+field3x+"").text("CMD1: cmd "+cmdonopt);
		}
		
		if ( cmdoffopt.length > textbreak)
		{
			$("#"+field6x+"").text(""+$("#"+field3x+"").attr('text'));
		}
		else{
			$("#"+field6x+"").text("CMD2: cmd "+cmdoffopt);
		}
	}
	
	var inhalt = generatesaved(data);
	var testfeld=datax+"-SAVE";
	var testinhalt =$("#"+testfeld).val();
	
	if( testinhalt != inhalt ) {
	field10=datax+"-SAVE-BUTTON";
	$("#"+field10).css("display","block");
	}
return;
}


function instconf()
{
	var nm = devicename;
	var def = nm+' createconf ';
	location = location.pathname+'?detail='+devicename+'&cmd=set '+addcsrf(def);
	return;
}

function openconf()
{
	var nm = CONFIGD;
	var co = location.pathname+'?detail='+nm;
    window.open(co);
return;
}


function undo()
{
	var nm = $(t).attr("nm");
	var  def = nm+" undo ";
	location = location.pathname+"?detail="+devicename+"&cmd=set "+addcsrf(def);
	return;
}


function restoreexperimental()
{
	var nm = $(t).attr("nm");
	var  def = nm+" restore_exp ";
	location = location.pathname+"?detail="+devicename+"&cmd=set "+addcsrf(def);
	return;
}


function Fullinf(data)
{
	
data = data.replace(/\./,'\\.');
	
condon=$("#conditionon"+data+"").val();
condoff=$("#conditionoff"+data+"").val();
cmd1=$("#"+data+"_plain1").text();
cmd2=$("#"+data+"_plain2").text();
onatdelay1=$("[name=onatdelay"+data+"] option:selected").text();
onatdelay2=$("#timeseton"+data).val();
offatdelay1=$("[name=offatdelay"+data+"] option:selected").text();
offatdelay2=$("#timesetoff"+data).val();
repeatcount=$("[name=repeatcount"+data+"]").val();
repeattime=$("[name=repeattime"+data+"]").val();

devicetypetest = $("[name=devicename"+data+"]").val();
let result = devicetypetest.match(/FreeCmd-AbsCmd.*/ig);

if( result == null ) 
	{	
condon=$("#conditionon"+data+"").val();
condoff=$("#conditionoff"+data+"").val();
	}
	else
	{
		condon=$("[name=cmdonopt"+data+"]").val();	
		condoff=$("[name=cmdoffopt"+data+"]").val();
	}

text="<table width='100%' border='0'>";
text="<tr>";
text+="<td>Cmd1:&nbsp;</td>";
text+="<td>"+cmd1+"</td>";
text+="</tr>"
text+="<td>Cmd2:&nbsp;</td>";
text+="<td>"+cmd2+"</td>";
text+="</tr>"
text+="<td>Condition1:&nbsp;</td>";
text+="<td>"+condon+"</td>";
text+="</tr>";
text+="<td>Condition2:&nbsp;</td>";
text+="<td>"+condoff+"</td>";
text+="</tr>";
text+="<td>delay1:&nbsp;</td>";
text+="<td>"+onatdelay1+" "+onatdelay2+"</td>";
text+="</tr>";
text+="<td>delay2:&nbsp;</td>";
text+="<td>"+offatdelay1+" "+offatdelay2+"</td>";
text+="</tr>";
text+="<td>repeats:&nbsp;</td>";
text+="<td>"+repeatcount+"</td>";
text+="</tr>";
text+="<td>repeats sec:&nbsp;</td>";
text+="<td>"+repeattime+"</td>";
text+="</tr>";
text+="</table>";
FW_okDialog(text);
return;	
}





function generatesaved(data)
{
datax = data.replace(/\./,'\\.');

devicetypetest = $("[name=devicename"+datax+"]").val();
let result = devicetypetest.match(/FreeCmd-AbsCmd.*/ig);

//return;
if( result == null ) 
	{
	condon=$("#conditionon"+datax+"").val();
	condoff=$("#conditionoff"+datax+"").val();

	cmd1=$("#"+datax+"_plain1").text();
	cmd2=$("#"+datax+"_plain2").text();

	showreihe=$("[name=showreihe"+datax+"] option:selected").text();
	idreihe=$("[name=idreihe"+datax+"] option:selected").text();
	prioreihe=$("[name=reihe"+datax+"] option:selected").text();
	onatdelay1=$("[name=onatdelay"+datax+"] option:selected").text();
	onatdelay2=$("#timeseton"+datax).val();
	offatdelay1=$("[name=offatdelay"+datax+"] option:selected").text();
	offatdelay2=$("#timesetoff"+data).val();
	
	repeatcount=$("[name=repeatcount"+datax+"]").val();
	repeattime=$("[name=repeattime"+datax+"]").val();
	//cmdonopt=$("[name=cmdonopt"+data+"]").text();
	data1 = "ID:"+idreihe+"_Anzeige:"+showreihe+"_Prio"+prioreihe+"_"+condon+condoff+cmd1+cmd2+onatdelay1+offatdelay1+onatdelay2+offatdelay2+repeatcount+repeattime;

	}
	else
	{
	cmdonopt=$("[name=cmdonopt"+datax+"]").val();
	cmdoffopt=$("[name=cmdoffopt"+datax+"]").val();
	showreihe=$("[name=showreihe"+datax+"] option:selected").text();
	idreihe=$("[name=idreihe"+datax+"] option:selected").text();
	prioreihe=$("[name=reihe"+datax+"] option:selected").text();
	onatdelay1=$("[name=onatdelay"+datax+"] option:selected").text();
	onatdelay2=$("#timeseton"+data).val();
	offatdelay1=$("[name=offatdelay"+datax+"] option:selected").text();
	offatdelay2=$("#timesetoff"+data).val();
	repeatcount=$("[name=repeatcount"+datax+"]").val();
	repeattime=$("[name=repeattime"+datax+"]").val();
	data1 = "ID:"+idreihe+"_Anzeige:"+showreihe+"_Prio"+prioreihe+"_"+cmdonopt+cmdoffopt+onatdelay1+offatdelay1+onatdelay2+offatdelay2+repeatcount+repeattime;
	}
	data1 = data1.replace(/[^0-9a-zA-Z]/g, "");
return data1;
}


function testfeld(data)
{
	alert($("[name=cmdonopt"+data+"]").val());	
	$("[name=cmdonopt"+data+"]").val("changed");
	
return;	
}


function editall()
{
 $.each( $("[name$='-BUTTON']"), function (key) {
  var feld = this.id;
  feld = feld.replace(/-BUTTON/g, "");
  showedit(feld);
  return;
  
});
return;
}

function closeall()
{
 $.each( $("[name$='-BUTTON']"), function (key) {
  var feld = this.id;
  feldx = feld.replace(/\./,'\\.');
  //alert(feld);
  var tfeld = feldx.replace(/-BUTTON/g, "");
  var field1=tfeld+"-PLAIN";
  var css =$("[name="+field1+"]").css('display');
  
  if (css == 'none'){
  tfeld = tfeld.replace(/\\\./,'.');
  hideedit(tfeld);
  }
  return;
});
return;
}


function forum()
{
	cmd ='get '+devicename+' support_info ';
	FW_cmd(FW_root+'?cmd='+encodeURIComponent(cmd)+'&XHR=1');
	return;
}


function execbottomline(data)
{
 if (data == 'rawDef'){
	 raw();
	$('#moreCmds option').removeAttr('selected');
 }
  if (data == 'reset'){
	 reset('check')
	$('#moreCmds option').removeAttr('selected');
 }
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


