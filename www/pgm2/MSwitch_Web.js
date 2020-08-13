// MSwitch_Web.js
// Autor:Byte09
// #########################

	var version = '1.1';
	var info = '';
	var debug ='off';
	
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
	var myRegEx = new RegExp('<strong>'+inhalt+'(.*?)</strong>(.*?)(<strong)');  
	treffer = text.match(myRegEx);
	if( treffer == null){
	out = inhalt+" - dieser Hilfetext ist nicht vorhanden";
	}else{
	out = treffer[2];	
	}
	$( "[name=attrhelp]" ).html(out);
	return;
	}); 



function teststart(){
// alle startfunktionen ausführen 



// funktion rename aktivieren
if (debug == 'on'){ alert(devicename+' Debug MSwitchweb an') };
//alert(RENAME);

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


// quickedit anpassen
if (QUICKEDIT == '0'){
	$("#devices").prop("disabled", false);
	document.getElementById('aw_great').value='schow greater list';
	document.getElementById('lockedit').checked = false  ;
	}
	
// devhelp ersetzen

r3 = $('<a href=\"javascript: reset(\'check\')\">Reset this device ('+devicename+')</a>&nbsp;&nbsp;<a href=\"javascript: fullhelp()\">Device specific help</a>');
$( "[class=\"detLink devSpecHelp\"]" ).html(r3);


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
	

// //####################################################################################################
// // init Logging
  // var olddest;
// // Konfiguration des Observers: alles melden - Änderungen an Daten, Kindelementen und Attributen
// //	var config = { attributes: true, childList: true, characterData: true };
// // test observer
// // zu überwachende Zielnode (target) auswählen
	// // var target = document.querySelector('div[informid="'+devicename+'-Debug"]');
// // eine Instanz des Observers erzeugen
	// observer = new MutationObserver(function(mutations) {
		// mutations.forEach(function(mutation) {
	// var test = $( "div[informId|='"+devicename+"-Debug']" ).text();
	// test= test.substring(0, test.length - 19);
	// var old = document.getElementById("log").value;
	// if (olddest != test)
		// {
		// olddest = test;
		// document.getElementById("log").value=old+'\n'+test;
		// var textarea = document.getElementById('log');
		// //var testautoscroll= $("[name=autoscroll]").prop("checked") ? "ja":"nein");
		// testautoscroll = $("[name=autoscroll]").prop("checked") ? "ja":"nein";
		// if (testautoscroll == 'ja')
			// {
			// textarea.scrollTop = textarea.scrollHeight;
			// }
		// }
	// return;
  // });    
// }); 
/* 

	if (DEBUGMODE ==3 || DEBUGMODE == '4')
	{
	observer.observe(target, config);
	} 
	 */
	
	
 	var olddest;
	// init reaktion auf auf Änderungen der INFORMID
	$("body").on('DOMSubtreeModified', "div[informId|='"+devicename+"-Debug']", function() {
	var test = $( "div[informId='"+devicename+"-Debug']" ).text();
	
	//alert(test);
	//test= test.substring(0, test.length - 19);
	
	
	var old = document.getElementById("log").value;
	if (olddest != test)
		{
		olddest = test;
		document.getElementById("log").value=old+'\n'+test;
		var textarea = document.getElementById('log');
		testautoscroll = $("[name=autoscroll]").prop("checked") ? "ja":"nein";
		if (testautoscroll == 'ja')
			{
			textarea.scrollTop = textarea.scrollHeight;
			}
		}
	return;
	}) 
	

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
	//alert('changed');
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
		[ "aw_dist1","aw_dist2","aw_dist","aw_trig","aw_md1","aw_md20","aw_addevent","aw_dev"].forEach (lock,);
		randomdev.forEach (lock);
		}
	if( changedetails == globaldetails)
		{
		[ "aw_dist1","aw_dist2","aw_dist","aw_trig","aw_md1","aw_md20","aw_addevent","aw_dev"].forEach (unlock,);
			randomdev.forEach (unlock);
		}
	}

	}
	

// next   ##################################################
	

if ( DEVICETYP != 'dummy')
{
	var triggerdetails = document.getElementById('MSwitchWebTRDT').innerHTML;
	var saveddevice = TRIGGERDEVICEHTML;
	var sel = document.getElementById('trigdev');
	sel.onchange = function() 
	{
	trigdev = this.value;
	if (trigdev != TRIGGERDEVICEHTML)
		{
		globallock =' unsaved trigger';
		["aw_md1","aw_md20","aw_md","aw_dist1","aw_dist2","aw_dist","aw_dev", "aw_det"].forEach (lock);
		randomdev.forEach (lock,);
		}
	else
		{	
		["aw_md1","aw_md20","aw_md","aw_dist1","aw_dist2","aw_dist","aw_dev", "aw_det"].forEach (lock);
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


// next   ##################################################


	// eventmonitor
	var o = new Object();
	var atriwaaray = new Object();
	var atriwaaray = { SCRIPTTRIGGERS };

	// init reaktion auf Änderungen der INFORMID
	$("body").on('DOMSubtreeModified', "div[informId|='"+devicename+"-EVENT']", function() {
	
	// abbruch wenn checkbox nicht aktiv
	
	var check = $("[name=eventmonitor]").prop("checked") ? "1":"0";
	if (check == 0)
		{
/* 		$( "#log2" ).text( "" );
		$( "#log1" ).text( "" );
		$( "#log3" ).text( "" ); */
		return;
		}

	// neustes event aus html extrahieren
	var test = $( "div[informId|='"+devicename+"-EVENT']" ).text();
 
	// datum entfernen
	test= test.substring(0, test.length - 19);
	o[test] = test;

	// löschen der anzeige
	
	$( "#log2" ).text( "" );
	$( "#log1" ).text( "eingehende events:" );
	$( "#log3" ).text( "" );
	 
	var field = $('<br><select style="width: 30em;" size="5" id ="lf" multiple="multiple" name="lf" size="6"  onchange="javascript:transferevent()" ></select>');
	
	$(field).appendTo('#log2');
	
	//var field = $('<input id ="editevent" type="button" value="'+editevent+'"/>');   // !!!!! #######
	
	//$(field).appendTo('#log3');
	
	
	//$("#editevent").click(function(){
	//transferevent();
	//return;
	//});
 
	// umwandlung des objekts in standartarray
	var a3 = Object.keys(o).map(function (k) { return o[k];})
 
	// array umdrehen
	a3.reverse();
/*  
	// eintrag in dropdown
	if (atriwaaray[test] != 1)
		{
		atriwaaray[test]=1;
		var newselect = $('<option value="'+test+'">'+test+'</option>');
		$(newselect).appendTo('#trigcmdon');
		var newselect = $('<option value="'+test+'">'+test+'</option>');
		$(newselect).appendTo('#trigcmdoff');
		var newselect = $('<option value="'+test+'">'+test+'</option>');
		$(newselect).appendTo('#trigon');
		var newselect = $('<option value="'+test+'">'+test+'</option>');
		$(newselect).appendTo('#trigoff');
		}
  */
	// aktualisierung der divx max 5
	var i;
	for (i = 0; i < 10; i++) 
		{
		if (a3[i])
			{
			var newselect = $('<option value="'+a3[i]+'">'+a3[i]+'</option>');
			$(newselect).appendTo('#lf'); 
			}
		else{
			break;
		}			
			
		}  
 
});

// next   ##################################################
	
	
	
	
	if (HASHINIT != 'define')
	{
		
		for (i=0; i<auswfirst.options.length; i++)
			{
			var pos=auswfirst.options[i];
				if(pos.selected)
				{
				//alert (pos.value);
				globalaffected +=pos.value;
				}
			}
		//alert (globalaffected);
		 var sel1 = document.getElementById('devices');
			
			if (UNLOCK == '1')
			{
				globallock =' this device is locked !';
				["aw_dist1","aw_dist2", "aw_dist","aw_dev","aw_det","aw_trig","aw_md","aw_md1","aw_md20","aw_addevent"].forEach (lock,);
				randomdev.forEach (lock);
			}
			
			if (UNLOCK == '2')
			{
				globallock =' only trigger is changeable';
				[ "aw_dist1","aw_dist2","aw_dist","aw_dev","aw_det","aw_md","aw_md1","aw_md20","aw_addevent"].forEach (lock,);
				randomdev.forEach (lock);
			}
			
		sel1.onchange = function() 
		{
			var actaffected;
			var auswfirst=document.getElementById('devices');
			for (i=0; i<auswfirst.options.length; i++)
				{
				var pos=auswfirst.options[i];
				if(pos.selected)
					{
					//alert (pos.value);
					actaffected +=pos.value;
					}
				}

			if (actaffected != globalaffected)
				{
				globallock =' unsaved affected device';
				[ "aw_dist1","aw_dist2","aw_dist","aw_det","aw_trig","aw_md","aw_md1","aw_md20","aw_addevent"].forEach (lock,);
				randomdev.forEach (lock);
				}
			else
				{
				[ "aw_dist1","aw_dist2","aw_dist","aw_det","aw_trig","aw_md","aw_md1","aw_md20","aw_addevent"].forEach (unlock,);
				randomdev.forEach (unlock);
				}
		}	 
	}
	
	
return;
} // ende startfunktionen


//#####################################################################################################

function deletedistributor(line){
	//alert(line);
	if (debug == 'on'){ alert('deletedistributor') };
	document.getElementById('line1-'+line).innerHTML = '';
	document.getElementById('line2-'+line).innerHTML = '';
	checkdistricode()
	return;
	
	
}

function adddistributor(){
	if (debug == 'on'){ alert('adddistributor') };	//alert('line');
	//alert(DISTRIBUTLINES);
	var add = $( "#rawcode" ).html();
	//
	
	add = add.replace(/LINENUMBER/gi,DISTRIBUTLINES);
	add = add.replace(/line1-/gi,"line1-"+DISTRIBUTLINES);
	add = add.replace(/line2-/gi,"line2-"+DISTRIBUTLINES);
	add = add.replace(/ideventNR/gi,"ideventNR"+DISTRIBUTLINES);
	add = add.replace(/ideventCMD/gi,"ideventCMD"+DISTRIBUTLINES);
	add = add.replace(/ideventID/gi,"ideventID"+DISTRIBUTLINES);

	//alert(add);
	DISTRIBUTLINES++;
	
	
	
	//alert(add);
	//alert(DISTRIBUTLINES);
	var old = $( "#Distributor" ).html();
	old = old.replace(/<!--newline-->/gi,add+"<!--newline-->");
	$( "#Distributor" ).html(old);
	
	
	checkdistricode()
	return;
}




function savedistributor(){
	if (debug == 'on'){ alert('savedistributor') };
	
	//alert('savedistributor')
	
	//alert(DISTRIBUTLINES);
	var newidfile='';
	for (i=0; i<DISTRIBUTLINES; i++)
		{
			aktline =  $("#ideventNR"+i).val();
			
			
			//alert(aktline);
			
			
			
			if (aktline === undefined) { continue; }
			if (aktline == 'undefined') { continue; }
			aktcmd=  $("#ideventCMD"+i).val();
			aktid=  $("#ideventID"+i).val();
			newidfile +=aktline+"=>cmd"+aktcmd+"[SP]ID[SP]"+aktid+"[NL]";		
		}
		
		
		//alert(newidfile);
		
	//if 	(newidfile =="")
	//{
		
		// alert('?cmd=deletereading '+devicename+' .Distributor&XHR=1');
		
		
		// FW_cmd(FW_root+'?cmd=deletereading '+devicename+' .Distributor&XHR=1');
	
		//[ "aw_md","aw_trig","aw_md1","aw_md20","aw_addevent","aw_dev"].forEach (unlock,);
		//randomdev.forEach (unlock);
		
	//}else{
		

	 // FW_cmd(FW_root+'?cmd=setreading '+devicename+' .Distributor '+newidfile+'&XHR=1');
	
	
	// } 
	
	//alert(newidfile);
	//return;
	 
	FW_cmd(FW_root+'?cmd=set '+devicename+' setbridge '+newidfile+'&XHR=1');
	[ "aw_md","aw_trig","aw_md1","aw_md20","aw_addevent","aw_dev"].forEach (unlock,);
	randomdev.forEach (unlock);
	 
	 
	
	//var nm = $(t).attr("nm");
	//var  def = nm+" setbridge "+newidfile;
	//location = location.pathname+"?detail="+devicename+"&cmd=set "+addcsrf(def);
	
	return;
}









function checkdistricode(){
	
	// blockiert alles butttons wenn districode verändert
	//var ORGdistricode = $( "#Distributor" ).html();
	//var CHECKdistricode = $( "#Distributor" ).html();
	
	
	//if (CHECKdistricode != ORGdistricode){
		//alert('ungleich');
				globallock =' unsaved disributor ';
				[ "aw_md","aw_trig","aw_md1","aw_md20","aw_addevent","aw_dev"].forEach (lock,);
				randomdev.forEach (lock);
	/*	}
	 	else
			{
				alert('gleich');
			[ "aw_md","aw_trig","aw_md1","aw_md20","aw_addevent","aw_dev"].forEach (unlock,);
					randomdev.forEach (unlock);
			} */
			
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
	//alert(field);
	var text = HELP;
	text = text.replace(/#\[LINE\]/gi,"<br>");
	text = text.replace(/#\[A\]/gi,"'");
	text = text.replace(/#\[DA\]/gi,"\"");
	//treffer = text.match(/<-.field(.*?)(->)/);
	var myRegEx = new RegExp('<-.'+field+'-(.*?)(->)');  
	treffer = text.match(myRegEx);
	
	
	//alert (treffer);
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
	//var selectfield = "<input type='text' id='" + target +"_opt' size='3' value='' readonly>&nbsp;&nbsp;&nbsp;" + first +"<input type='range' min='" + first +"' max='" + last + "' value='" + selected +"' step='" + step + "' onchange=\"javascript: showValue(this.value,'" + copytofield + "','" + target + "')\">" + last  ;
	
	var selectfield = "<div class='col3'><div class='fhemWidget' cmd='pct' reading='state' dev='webtestdummy' arg='slider,1,10,100' current='farbe test1'></div></div>";
	
	
	document.getElementById(target).innerHTML = selectfield + '<br>';
	
	FW_replaceWidgets();
	//var opt = target + '_opt';
	//document.getElementById(opt).value=selected;
	return;
	}  
	
	
	
	
	
	
	

 function colorpicker(aktuell,target,copytofield){
	if (debug == 'on'){ alert('slider') };
	var selected =document.getElementById(copytofield).value;
	
	
	//var selectfield = "<input type='text' id='" + target +"_opt' size='3' value='' readonly>&nbsp;&nbsp;&nbsp;" + first +"<input type='range' min='" + first +"' max='" + last + "' value='" + selected +"' step='" + step + "' onchange=\"javascript: showValue(this.value,'" + copytofield + "','" + target + "')\">" + last  ;
	
	
	
	var selectfield = "<input type='color' id='favcolor' name='favcolor' value='#ff0000'>";
	
	document.getElementById(target).innerHTML = selectfield + '<br>';
	//var opt = target + '_opt';
	//document.getElementById(opt).value=selected;
	return;
	}  


function textfieldlong(copytofield,target)
	{
	if (debug == 'on'){ alert('textfield') };
		var selected =document.getElementById(copytofield).value;
		var ID = Math.random();
		var ID1 = Math.random();
		var IDFinish =ID1+ID;
		//alert(IDFinish);
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



function textfield(copytofield,target)
	{
	if (debug == 'on'){ alert('textfield') };
		var selected =document.getElementById(copytofield).value;
	
		if (copytofield.indexOf('cmdonopt') != -1) {
		var selectfield = "<input type='text' size='30' value='" + selected +"' onfocus=\"javascript: showtextfield(this.value,'" + copytofield + "','" + target + "')\"     onchange=\"javascript: showtextfield(this.value,'" + copytofield + "','" + target + "')\"  >"  ;
		document.getElementById(target).innerHTML = selectfield + '<br>';	
		}
		else{
		var selectfield = "<input type='text' size='30' value='" + selected +"' onfocus=\"javascript: showtextfield(this.value,'" + copytofield + "','" + target + "')\" onchange=\"javascript: showtextfield(this.value,'" + copytofield + "','" + target + "')\">"  ;
		document.getElementById(target).innerHTML = selectfield + '<br>';
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
				[ "aw_dist1","aw_dist2","aw_dist","aw_trig","aw_md1","aw_md20","aw_addevent","aw_dev"].forEach (lock,);
				randomdev.forEach (lock);
			}
		else
			{
			[ "aw_dist1","aw_dist2","aw_dist","aw_trig","aw_md1","aw_md20","aw_addevent","aw_dev"].forEach (unlock,);
					randomdev.forEach (unlock);
			}
		}
	if (state == 'no_action')
		{
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
	
	
	
	
	//alert(devicecmd[0]);
	if (devicecmd[0] == 'noArg')
		{
		noarg(target,copytofield);
		return;
		}
		
	else if (devicecmd[0] == 'textfieldLong'){textfieldlong(copytofield,target);return;}	
		
	else if (devicecmd[0] == 'slider'){textfield(copytofield,target);return;}
	//else if (devicecmd[0] == 'slider'){slider(devicecmd[1],devicecmd[2],devicecmd[3],target,copytofield);return;}
	else if (devicecmd[0] == 'undefined'){textfield(copytofield,target);return;}
	else if (devicecmd[0] == 'textField'){textfield(copytofield,target);return;}
	//else if (devicecmd[0] == 'colorpicker'){colorpicker(devicecmd[1],target,copytofield);return;}
	else if (devicecmd[0] == 'colorpicker'){textfield(copytofield,target);return;}
	else if (devicecmd[0] == 'RGB'){textfield(copytofield,target);return;}
	else if (devicecmd[0] == 'no_Action'){noaction();return;}
	else {selectfield(werte[state],target,copytofield);return;}
	//alert('beende activate');
	return;
	}
	
	
	
	
	
	
	
	
	
	
	

function testcmd(field,devicename,opt){
if (debug == 'on'){ alert('testcmd') };
	comand = $("[name="+field+"]").val();
 	if (comand == 'no_action')
		{
		return;
		}
	comand1 = $("[name="+opt+"]").val()
	if (devicename != 'FreeCmd')
		{
		comand =comand+" "+comand1;
		}
	comand = comand.replace(/$SELF/g, devicename); // !!!!
	//alert(comand);
	if (devicename != 'FreeCmd')
		{
		cmd ='set '+devicename+' '+comand;
		FW_cmd(FW_root+'?cmd='+encodeURIComponent(cmd)+'&XHR=1');
		FW_okDialog(EXECCMD+' '+cmd); // !!!
		FW_errmsg(cmd, 5);
		} 
	 else
		{
			comand = comand.replace(/;;/g,'[DS]');
			comand = comand.replace(/;/g,';;');
			comand = comand.replace(/\\[DS\\]/g,';;');
			var t0 = comand.substr(0, 1);
			var t1 = comand.substr(comand.length-1,1 );
			if (t1 == ' ')
				{
				var space = '".$NOSPACE."'; // !!!
				var textfinal = "<div style ='font-size: medium;'>"+space+"</div>";
				FW_okDialog(textfinal);
				return;
				}
			
			if (t0 == '{' && t1 == '}') 
				{
				}
			else
				{
				comand = '{fhem("'+comand+'")}';
				}
			
			cmd = comand;
			FW_cmd(FW_root+'?cmd='+encodeURIComponent(cmd)+'&XHR=1');
			FW_okDialog(EXECCMD+' '+cmd);
		} 
	}



function  switchlock()
{	
	if (debug == 'on'){ alert('switchlock') };
	test = document.getElementById('lockedit').checked ;	
	if (test)
		{
		$("#devices").prop("disabled", 'disabled');
			if (LANGUAGE == 'DE')
				{
				document.getElementById('aw_great').value='Liste editieren';
				}
			else
				{
				document.getElementById('aw_great').value='edit list';
				}
		}
	else
		{
		$("#devices").prop("disabled", false);
			if (LANGUAGE == 'DE')
				{
				document.getElementById('aw_great').value='öffne grosse Liste';
				}
			else
				{
				document.getElementById('aw_great').value='schow greater list';
				}
		}
}
	

function closetrigger(){
	if (debug == 'on'){ alert('closetrigger') }
			globallock =' unsaved trigger details';
			["aw_dist1","aw_dist2","aw_dist","aw_dev", "aw_det","aw_trig","aw_md1","aw_md20","aw_addevent"].forEach (lock,);
			randomdev.forEach (lock);
	}
	
function opentrigger(){
	if (debug == 'on'){ alert('opentrigger') }
			["aw_dist1","aw_dist2","aw_dist", "aw_dev","aw_det","aw_trig","aw_md1","aw_md20","aw_addevent"].forEach (unlock,);
			randomdev.forEach (unlock);
	}


function reload(){
if (debug == 'on'){ alert('reload') }
	window.location.href="/fhem?detail="+devicename;
	}




function newname(){
if (debug == 'on'){ alert('newname') }
	newname = document.getElementById('newname').value;
	//comand = 'rename+Timer1+'+newname;
	if (devicename == newname){return;}
	if (newname == ''){return;}
	comand = 'rename'+devicename+newname;
	
	cmd = comand;
	
	window.location.href="/fhem?cmd=rename "+devicename+" "+newname+"&detail="+newname+""+CSRF;
	} 
	

function lock(elem, text){
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
if (debug == 'on'){ alert('unlock') }
//alert('unlock: '+elem+' --- '+index) ;
	if (document.getElementById(elem)){
	//alert(elem+' '+document.getElementById(elem).model);
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
function bigwindow(targetid,fromsc){
if (debug == 'on'){ alert('bigwindow') };

if(typeof fromsc == 'undefined'){
	fromsc = "noweb";
}


	targetval =document.getElementById(targetid).value;
	
	targetval = targetval.replace(/\u2424/g,'\n');
	
	//alert (targetval);
	
	sel ='<div style="white-space:nowrap;"><br>';
	sel = sel+'<textarea id="valtrans" cols="80" name="TextArea1" rows="10" onChange="bigwindowformat(\''+targetid+'\',\''+fromsc+'\')">'+targetval+'</textarea>';
	sel = sel+'</div>';
	FW_okDialog(sel,''); 
	}	


function bigwindowformat(targetid,fromsc){
	//return;
	// alert(fromsc);
	var value = document.getElementById('valtrans').value
	
	if (fromsc == "web"){
	value = value.replace(/\n/g, '\u2424');
	}
	
	//alert(targetid+"-"+value);
	
	
	
 document.getElementById(targetid).value=value; 
 
}

// Deviceauswahl
function  deviceselect(){
if (debug == 'on'){ alert('deviceselect') };
	sel ='<div style="white-space:nowrap;"><br>';
	var ausw=document.getElementById('devices');
	for (i=0; i<ausw.options.length; i++)
		{
		var pos=ausw.options[i];
			if(pos.selected)
			{
			sel = sel+'<input id ="Checkbox-'+i+'" checked="checked" name="Checkbox-'+i+'" type="checkbox" value="test" /> '+pos.value+'<br />';
			}
			else 
			{
			sel = sel+'<input id ="Checkbox-'+i+'" name="Checkbox-'+i+'" type="checkbox" /> '+pos.value+'<br />';
			}
		} 
	sel = sel+'</div>';
	FW_okDialog(sel,'',removeFn) ; 
	}
	 
	 function  showgroup(group){
		//alert(group);
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
 
	/*  conf='';
	 var nm = $(t).attr("nm");
	 var  def = nm+" clearlog "+encodeURIComponent(conf);
	 lo */cation = location.pathname+"?detail="+devicename+"&cmd=set "+addcsrf(def);
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
	conf = conf.replace(/:/g,'#[dp]');
	conf = conf.replace(/;/g,'#[se]');
	conf = conf.replace(/ /g,'#[sp]');
	conf = conf.replace(/'/g,'#[st]');
	conf = conf.replace(/\t/g,'#[tab]');
	var nm = $(t).attr("nm");
	var  def = nm+" savesys "+encodeURIComponent(conf);
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
function showtextfield(newValue,copytofield,target)
	{
	if (debug == 'on'){ alert('showtextfield') };
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
	selected = selected.replace(/\|/g,'(DAYS)'); // !!!
	selected = selected.replace(/\./g,'#[pt]'); // !!!
	selected = selected.replace(/:/g,'#[dp]');
	selected= selected.replace(/~/g,'#[ti]');
	selected = selected.replace(/ /g,'#[sp]');
	event = event.replace(/~/g,'#[ti]');
	event = event.replace(/ /g,'#[sp]');
	cmd ='get '+devicename+' checkcondition '+selected+'|'+event;
	FW_cmd(FW_root+'?cmd='+encodeURIComponent(cmd)+'&XHR=1', function(resp){FW_okDialog(resp);});
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
	// alert(check);
	if (check == 1)
		{
		$( "#log2" ).text( "" );
		$( "#log1" ).text( "eingehende events:" );
		$( "#log3" ).text( "" );
		var field = $('<br><select style="width: 30em;" size="5" id ="lf" multiple="multiple" name="lf" size="6"  ></select>');
		$(field).appendTo('#log2');
		//var field = $('<input id ="editevent" type="button" value="'+editevent+'"/>');
		//$(field).appendTo('#log3');
		return;
		}
	});
	

// next
	
	$("#activelog").click(function(){
	var checka = $("[name=activelogging]").prop("checked") ? "1":"0";
	// alert(checka);
	var arg = "set eventtest logging";
	FW_cmd(FW_root+'?cmd=set '+devicename+' logging '+checka+'&XHR=1');
	return;
	
/* 	if (checka == 1)
		{
		observer.observe(target, config);
		return;
		}
		
	if (checka == 0)
		{
			
		//$("body").on('DOMSubtreeModified', "div[informId|='"+devicename+"-Debug']", function()	{}) ;
			
		observer.disconnect();
		return;
		}	
		 */
		
	});
	
	

// clickfunktions


// details speichern
/* 	$("#aw_det").click(function(){
	var nm = $(t).attr("nm");
	devices = '';
	eval(JAVAFORM);
	devices = devices.replace(/:/g,'#[dp]');
	devices = devices.replace(/;/g,'#[se]');
	devices = devices.replace(/ /g,'#[sp]');
	devices = devices.replace(/%/g,'#[pr]');
	devices =  encodeURIComponent(devices);
	var  def = nm+" details "+devices+" ";
	location = location.pathname+"?detail="+devicename+"&cmd=set "+addcsrf(def);
	});
	 */

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
	FW_cmd(FW_root+'?cmd=setreading '+devicename+' Trigger_log '+trigsave+'&XHR=1');
	
	
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
	
// unbekannt
	$("#aw_dev").click(function(){
	if (debug == 'on'){ alert('#aw_dev') };
	var nm = $(t).attr("nm");
	devices = $("[name=affected_devices]").val();
	var  def = nm+" devices "+devices+" ";
	location = location.pathname+"?detail="+devicename+"&cmd=set "+addcsrf(def);
	}); 
	
//unbekannt
	$("#aw_show").click(function(){
	if (debug == 'on'){ alert('#aw_show') };
	$("[name=noshow]").css("display","block");
	$("[name=noshowtask]").css("display","none");
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
	
//aplly filter to trigger
	$("#aw_md1").click(function(){
	if (debug == 'on'){ alert('#aw_md1') };	
	var nm = $(t).attr("nm");
	var  def = nm+" filter_trigger ";
	location = location.pathname+"?detail="+devicename+"&cmd=set "+addcsrf(def);
	});

//unbekannt
	$("#aw_trig").click(function(){
	if (debug == 'on'){ alert('#aw_trig') };	
	var nm = $(t).attr("nm");
	trigdev = $("[name=trigdev]").val();
	timeon =  $("[name=timeon]").val();
	timeoff =  $("[name=timeoff]").val();
	timeononly =  $("[name=timeononly]").val();
	timeoffonly =  $("[name=timeoffonly]").val();
	if(typeof(timeoffonly)=="undefined"){timeoffonly=""}
	timeonoffonly =  $("[name=timeonoffonly]").val();
	if(typeof(timeonoffonly)=="undefined"){timeonoffonly=""}
	trigdevcond = $("[name=triggercondition]").val();
	trigdevcond = trigdevcond.replace(/\\./g,'#[pt]');
	trigdevcond = trigdevcond.replace(/:/g,'#[dp]');
	trigdevcond= trigdevcond.replace(/~/g,'#[ti]');
	trigdevcond = trigdevcond.replace(/ /g,'#[sp]');
	trigdevcond = trigdevcond+':';
	timeon = timeon.replace(/ /g, '');
	timeoff = timeoff.replace(/ /g, '');
	timeononly = timeononly.replace(/ /g, '');
	timeoffonly = timeoffonly.replace(/ /g, '');
	timeonoffonly = timeonoffonly.replace(/ /g, '');
	timeon = timeon.replace(/:/g, '#[dp]');
	timeoff = timeoff.replace(/:/g, '#[dp]');
	timeononly = timeononly.replace(/:/g, '#[dp]');
	timeoffonly = timeoffonly.replace(/:/g, '#[dp]');
	timeonoffonly = timeonoffonly.replace(/:/g, '#[dp]');
	timeon = timeon+':';
	timeoff = timeoff+':';
	timeononly = timeononly+':';
	timeoffonly = timeoffonly+':';
	timeonoffonly = timeonoffonly+':';
	trigwhite = $("[name=triggerwhitelist]").val();
	var  def = nm+" set_trigger  "+trigdev+" "+timeon+" "+timeoff+" "+timeononly+" "+timeoffonly+" "+timeonoffonly+" "+trigdevcond+" "+trigwhite+" " ;
	def =  encodeURIComponent(def);
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
	return
	
	
	
}



