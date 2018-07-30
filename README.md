MSwitch ist ein Hilfsmodul. Es erlaubt das ''gleichzeitige'' Schalten von mehreren Devices. Zudem sind weitere Abhängigkeiten und Bedingungen wie ereignisgesteuertes und/oder zeitgesteuertes Schalten einzelner Devices einstellbar. Konfiguriert wird das Modul durch ein Webinterface. 

MSwitch kann damit die Funktionen von mehreren Hilfsmodulen wie Notify, at, Watchdog, DOIF etc. ersetzen.

{{Infobox Modul
|ModPurpose=MSwitch
|ModType=h
|ModForumArea=
|ModTechName=98_MSwitch.pm
|ModOwner=Byte09}}

== Grundsätzliche Überlegungen ==

Die Übernahme des Moduls in das offizielle Fhem SVN ist derzeit nicht geplant.<br>

Um das Modul zu nutzen, muss man zuerst folgende Fragen beantworten:<br>

* ''Welches Gerät soll auslösen?'' Dies ist der Trigger. Jedes sichtbare Event im Eventmonitor kann als Trigger dienen. Will man mehrere Geräte als gleichzeitige Auslöser betreiben, so muss das Device GLOBAL gewählt und die entsprechenden Geräte angegeben werden (dies erzeugt dann höhere Systemlast). Damit kann auch zu fest definierten Zeiten oder Zufallszeiten, unabhängig von einem Trigger, geschaltet werden; auch eine Kombination beider Varianten ist möglich. Den trigger bzw. die mehreren Geräte werden im ersten Teil des Webinterfaces (siehe unten) angegeben.
* ''Welche Bedingungen sollen bei Auslösung erfüllt sein?'' Wenn diese Bedingungen erfüllt sind, werden Kommandos ausgelöst. Die Bedingungen werden im zweiten Teil des Webinterfaces eingegeben. Dabei unterscheidet das Modul zwischen zwei Kommandokanälen (cmd1 und cmd2) und den dazugehörigen Geräten.
* ''Welche Kommandos sollen ausgelöst werden?'' Im dritten Teil des Webinterfaces werden dann die konkreten Kommandos eingegeben. Typischerweise wählt man dabei aus einer Liste der Kommandos aus, die die zugehörigen Geräte insgesamt aufweisen (also so, wie man auf den Geräteseiten selber Kommandos auswählt). Es gibt zudem ein so genanntes FreeCmd, das ein geräteunabhängiges Kommando zulässt, beispielsweise reinen Perl-Code.  
* ''Welche weiteren Bedingungen sollen noch gelten?'' Hier sind ereignisgesteuerte wie auch zeitgesteuerte Bedingungen möglich. Diese Bedingungen werden auch in dem dritten Teil des Webinterfaces eingetragen. So sind Verzögerungen und Wiederholungen und weitere Bedingungen möglich.

== Voraussetzungen, Installation und Grundbefehle ==

Das MSwitch-Modul benötigt keine Voraussetzungen. Es wird ''nicht'' über das FHEM Update verteilt. Die in der Entwicklung befindliche Version kann mit den nachfolgenden Befehlen geladen werden.<br>

MSwitch Modul einmalig installieren/aktualisieren mit folgendem Befehl im WebCMD:<br>
 <small>update all https://raw.githubusercontent.com/Byte009/FHEM-MSwitch/master/controls_mswitch.txt</small>

Um das Modul permanent in das FHEM Update aufzunehmen, ist folgender Befehl in das WebCMD einzugeben:<br>
 <small>update add https://raw.githubusercontent.com/Byte009/FHEM-MSwitch/master/controls_mswitch.txt</small>

=== Definition und Einrichtung ===
Mit Hilfe von MSwitch kann man mehrere Devices gleichzeitig schalten. Diese Schaltungen befinden sich in zwei möglichen Zweigen bei MSwitch. Dabei unterscheidet man im Modul zwischen den beiden Kommandos cmd1 und cmd2. Die zu einem Kommando gehörenden Geräte werden wir auch Zweig nennen. Die einzelnen Devices jedes Zweiges können mit weiteren Schaltbedingungen versehen werden (zeit- oder ereignisgesteuert). 

Folgende Möglichkeiten zum definieren des MSwitch Devices stehen zur Verfügung:

 <small>define <name> MSwitch</small>
Es wird ein leeres Device angelegt, das dann komplett über das Webinterface konfigurierbar ist.

 <small>define <name> MSwitch <DEVICE></small>
Hier wird ein Device angelegt, bei welchen das rechts angegebene <DEVICE> als Trigger fungiert. Der Trigger kann später jederzeit geändert werden.

Das define eines MSwitch Devices generiert lediglich eine 'leere Hülle'. Alle relevante Einstellungen werden in Readings und/oder Hashes gespeichert. Daher stehen relevanten Daten ''nicht'' in der fhem.cfg! Vielmehr finden sich diese Daten in der Datei fhem.save (die Speicherung erfolgt durch den Befehl Fhemsave).

=== set-Befehle ===
Es sind derzeit die folgenden set-Befehle implementiert.

 <small>set on</small>
Setzt das Device in den Status 'on'. Alle Befehle der 'on-Zweige' werden ausgeführt.

 <small>set off</small> 
Setzt das Device in den Status 'off'. Alle Befehle der 'off-Zweige' werden ausgeführt.

 <small>MSwitch_backup</small>

Erstellt eine Backup-Datei aller MSwitch Devices unter ./fhem/MSwitch_backup.cfg.<br>
Daten dieser Datei können im Bedarfsfall für einzelne oder gleichzeitig alle MSwitch Devices wieder zurück gespielt (hergestellt) werden.

 <small>del_delays</small>
Löscht alle anstehenden Timer und es wird eine Neuberechnung durchgeführt, falls 'on' oder 'off' Zeiten gesetzt sind.

 <small>fakeevent ab (V1.52)</small>
Syntax: set <device> fakeevent [<device>]:<reading>:<arg><br>
Beispiel: <device> fakeevent state:on<br>

Ob der Name ( <device> ) angegeben werden muss, oder nicht, ist abhängig davon, ob auf ein einzelnes Device, oder GLOBAL getriggert wird. Bei GLOBALEN Triggern muss das Device mit angegeben werden, Wird auf ein Device getriggert, so wird das Device automatisch gesetzt.<br>

Mit diesem Befehl kann das MSwitch Device neu getriggert werden, indem hier ein Event 'gefaked' wird. Das MSwitch Device reagiert dann so, als wäre dieses Event vom getriggerten Gerät generiert worden. 

Dieses kann nötig sein, um z.B einen Watchdog zu realisieren, in dem es nötig ist, das sich das MSwitch Device mit einem bestimmten Event selber neu triggert - ggf. mit einem entsprechenden Delay ( affected Device muss dafür u.A. des MSwitch Device selber sein ).

<small>Bei dem Einsatz dieser Möglichkeit sollte das Attribut 'MSwitch_Safemode' UNBEDINGT aktiviert sein, da 'Experimente' hier schnell in einer Endlosschleife enden können, die nur durch ein Reboot unterbrochen werden kann.<br>Ggf. werde ich hier sogar eine entsprechende Änderung vornehmen, das dieser Befehl nur zur Verfügung steht, wenn Safemode aktiviert ist.</small>
Es wird hierbei KEIN echtes Event generiert welches das System beeinflusst, sondern ausschließlich ein ein MSwitch-Interner Befehl umgesetzt !

=== get-Befehle ===

 <small>active_timer</small>

 <small>show_timer</small>
Zeigt alle anstehenden (gesetzten) Timer des Devices, die aus zeitabhängigen oder verzögerten Schaltbefehlen resultieren.

 <small>delete_timer</small>
Löscht alle anstehenden (gesetzten) Timer des Devices, die aus zeitabhängigen oder verzögerten Schaltbefehlen resultieren. Schaltbefehle, basierend auf rein zeitabhängigen Angaben, werden neu berechnet und gesetzt.

 <small>restore_MSwitch_data</small> 

 <small>this_Device</small>
Stellt die Daten des Devices aus der Backupdatei wieder her, sofern diese in der Backupdatei gefunden werden (gesucht wird hier nach dem Namen des Devices).

 <small>all_Devices</small> 
Stellt die Daten aller MSwitch Devices wieder her, sofern diese in der Backupdatei vorhanden sind. Diese Aktion kann einige Zeit in Anspruch nehmen und wird daher im Hintergrund (nonblocking) ausgeführt. Nach Beendigung erfolgt eine Benachrichtigung.

 <small>Die Devices sind nach einem Restore funktionsfähig. Empfohlen wird ein Neustart von FHEM.</small>

 <small>get_config</small> 
Zeigt den Konfigurationsfile des MSwitchdevices an, dieser kann in dem Fenster editiert werden. Das sollte nur von Erfahrenen Usern getan werden ! Eine falsche Konfiguration kann hier zu einem FHEM Absturz führen.

= Webinterface =

MSwitch wird wesentlich über das Webinterface eingerichtet. Wählt man das folgende Attribut
 attr <name> MSwitch_Help 1
so wird im Modul selber eine sehr umfangreiche Hilfe angezeigt. Über das gesamte Webinterface hinweg erscheinen kleine Fragezeichen, die man anklicken kann und die beschreiben, was in dem jeweiligen Textfeld sinnvollerweise einzugeben ist bzw. was das Modul an dieser Stelle erwartet.

Das Webinterface besteht aus vier Teilen. Änderungen in jedem Abschnitt müssen in dem jeweiligen Teil bestätigt werden und auch nur diese werden gespeichert. Bevor ein weiterer Teil bearbeitet wird, sollten Änderungen gespeichert werden, sie gehen sonst verloren.<br>

== Trigger device/time ==
===== Trigger Device =====
In diesem Feld wird das Device ausgewählt, dessen Events eine Aktion auslösen sollen. Dazu werden alle verfügbaren Devices in einem Dropdownfeld angeboten.
<br>
Zusätzlich gibt es eine Auswahl 'GLOBAL', wenn das Attribut 'MSwitch_Expert' gesetzt ist. Bei Auswahl dieser Option werden '''alle''' von FHEM generierten Events durch das MSwitch Device weiterverarbeitet, eine weitere Begrenzung der aktivierenden Events kann (und sollte) dann in einem folgenden Eingabefeld erfolgen, um die Systemlast zu reduzieren.<br>

===== Trigger Device Global Whitelist =====
Dieses Feld ist nur verfügbar, wenn als Trigger 'GLOBAL' gewählt wurde.<br>
<br>
Hier kann die Liste eingehender Events weiter eingeschränkt werden. Es handelt sich um eine Whitelist, d.h. wenn es keine Einträge gibt, werden Events aller Devices verarbeitet. Sobald ein oder mehrere Einträge gemacht werden, werden nur noch Events der hier benannten Devices verarbeitet. Als Angabe können hier Devices benannt werden oder ganze DeviceTypen (z.B TYPE=FS20). Mehrere Angaben sind durch Komma zu trennen.

[[Datei:MSwitchWebinterface1.png|400px|thumb|left|Webinterface, oben]]
Im gezeigten Beispiel wurde GLOBAL gewählt, weil nicht ein einziges Device, sondern eine Kombination aus zwei Geräten auslösen soll. Es werden also alle Ereignisse betrachtet, wobei die Whitelist dann auf die Devices Schlafzimmer (ein Temperaturmessgerät) und Schlafzimmerfenster (ein optischer Kontakt, siehe [https://wiki.fhem.de/wiki/HM-Sec-SCo_T%C3%BCr-Fensterkontakt,_optisch Link]) einschränkt. 


===== Trigger time ===== 
Es besteht die Möglichkeit, das Modul (neben den Events) zu festen Zeiten auszulösen. Dann wären in die leer stehenden Zeilen bei "at" entsprechende Termine einzutragen. Zeitangaben erfolgen durch [STUNDEN:MINUTEN|TAGE], wobei die Tage von 1-7 gezählt werden (1 steht für Montag, 7 für Sonntag usw.). 
Mehrere Zeitvorgaben können direkt aneinandergereiht werden.

Beispielsweise würde [17:00|1][18:30|23] den Trigger montags um 17 Uhr auslösen und dienstags sowie mittwochs um 18:30 Uhr.
Bei [00:10*20:00-21:00] würde der Schaltbefehl von 21 Uhr bis 21 Uhr alle 10 Minuten ausgeführt. Bei [?20:00-21:00] würde der Schaltbefehl zu einem zufälligen Zeitpunkt zwischen 20 und 21 Uhr ausgeführt.  [20:00|$we] bedeutet, dass nur am Wochenende um 20:00 geschaltet wird.

===== Trigger conditions =====

Hier kann die Angabe von Bedingungen erfolgen, die zusätzlich zu dem triggernden Device erfüllt sein müssen.
Diese Bedingungen sind eng an DOIF-Syntax angelehnt. Die Kombination mehrerer Bedingungen und Zeiten ist durch AND oder OR möglich.<br>
Wird in diesem Feld keine Angabe gemacht, so erfolgt der Schaltvorgang nur durch das triggernde Device ohne weitere Bedingungen.<br>

- Zeitabhängigkeit<br>

[19:10-23:00] - Trigger des Devices erfolgt nur in angegebenem Zeitraum<br>

- Readingabhängige Trigger<br>

[Devicename:Reading] =/>/< X oder [Devicename:Reading] eq "x" - Trigger des Device erfolgt nur bei erfüllter Bedingung.<br>
Werden Readings mit Strings abgefragt (on,off,etc.), ist statt des Gleichheitszeichens "=" der Operator "eq" zu nutzen, der String muss in Anführungszeichen "" gesetzt werden.

- mehrere Beispiele<br> 
[19:10-23:00] AND [Devicename:Reading] = 10 - beide Bedingungen müssen erfüllt sein.<br>
[19:10-23:00] OR [Devicename:Reading] = 10 - eine der Bedingungen muss erfüllt sein.<br>
[10:00-11:00|13] - schaltet Montag und Mittwoch zwischen 10 Uhr und 11 Uhr.<br>
[{ sunset() }-23:00] - von Sonnenuntergang bis 23:00 Uhr.<br>
{ !$we } löst den Schaltvorgang nur Werktagen an aus.<br>
{ $we } löst den Schaltvorgang nur an Wochenenden, Feiertagen aus.<br>

Es ist auf korrekte Eingabe der Leerzeichen zu achten.

Überschreitet die Zeitangabe die Tagesgrenze (24:00 Uhr), so gelten die angegebenen Tage noch bis zum Ende der angegebenen Schaltzeit (beispielsweise würde dann am Mittwoch noch der Schaltvorgang erfolgen, obwohl als Tagesvorgabe Dienstag gesetzt wurde).<br>

Bedingungen in diesem Feld gelten nur für auslösende Trigger eines Devices und haben keinen Einfluss auf zeitgesteuerte Auslöser.

== Trigger details ==
[[Datei:MSwitchWebinterface2.png|600px|thumb|left|Webinterface, Mitte]]
Während im obigen Feld das Device ausgewählt  werden konnte, wird hier das Ereignis festgelegt. Das Eingabefeld besteht aus mehreren Einzelfeldern.

Im abgebildeten Fall wird cmd1 ausgelöst, wenn der Zustand des Schlafzimmerfenster-Sensor meldet, dass das Fenster offen ist. Cmd2 wird ausgelöst, wenn die Temperatur des Schlafzimmersensors unter einen bestimmten Wert fallen wird.

===== execute 'cmd1/cmd2'  =====
Hier kann  aus einer vorbelegten Dropdownliste ausgewählt werden, welches ankommende Event den entsprechenden Befehlszweig auslösen soll. In dieser Liste werden bei entsprechender Einstellung alle ankommenden Events eines vorher definierten Devices gespeichert. In einem weiteren Feld (siehe unten) können Events manuell zugefügt werden.

===== Save incomming events =====
Bei Aktivierung dieser Option werden alle ankommenden Events des oben definierten Devices (oder Global) gespeichert und in entsprechenden Dropdownlisten angeboten.<br>
Da hier doch erhebliche Datenmengen anfallen können (je nach Device) wird empfohlen, diese Option nach der Konfiguration des Devices zu deaktivieren.

===== add event =====
hier besteht die Möglichkeit, unabhängig von der Option, ankommende Events automatisch zu speichern, manuell Events anzulegen, die in den Dropdownliste zur Auswahl angeboten werden, ohne das entsprechendes Event erst vom Device geliefert werden muss.<br>
Es können mehrere Events gleichzeitig eingegeben werden, eine Trennung erfolgt durch " , "<br>
Hier ist zu unterscheiden, ob das gewählte triggernde Device ein einfaches Device ist oder ob der Trigger 'GLOBAL' ist.<br>
Bei triggernden Devices können Events in folgendem Formaten zugefügt werden:<br>
<br>
- *                                                    - Aktion erfolgt auf alle auftretende Events des entsprechenden Device<br>
- reading:wert   (z.b. state:on )                      - Aktion erfolgt nur auf das Event "state:on"<br>
- reading:*      (z.b. state:* )                       - Aktion erfolgt auf die Events "state:(on,off,etc.)<br>
- reading:(wert1/wert2/wert3) (z.b. state:(left/right) - Aktion erfolgt nur auf Events "state:left" oder "state:right" etc.<br>
<br>
Falls auf 'GLOBALE' Events getriggert wird, muss das auslösende Device vorangestellt werden:<br>
<br>
- *                                                           - Aktion erfolgt auf alle auftretende Events des entsprechenden Device<br>
- device:reading:wert   (z.b. device:state:on )                      - Aktion erfolgt nur auf das Event "device:state:on"<br>
- device:reading:*      (z.b. device:state:* )                       - Aktion erfolgt auf die Events "device:state:(on,off,etc.)<br>
- device:reading:(wert1/wert2/wert3) (z.b. device:state:(left/right) - Aktion erfolgt nur auf Events "device:state:left" oder "devicestate:right" etc.<br><br>

Das Device kann auch hier gegen "*" ersetzt werden (*:state:on). In diesem Fall erfolgt eine Aktion auf alle Events die z.B "state:on" enthalten, egal welches Device triggert.

===== test event =====
Dieses Feld wird angeboten, wenn entsprechende vom Triggerdevice gelieferte Events gespeichert wurden.<br>
Durch Auslösen dieser Funktion wird das Event simuliert und entsprechende definierte Aktionen ausgelöst. Diese Funktion dient ausschließlich zum Testen der eingestellten Konfiguration. Alle entsprechenden Befehle werden ausgeführt, als würde das Event real eintreffen.

===== apply filter to saved events =====

Beschreibung folgt

===== clear saved event =====

Es werden alle gespeicherten Events gelöscht.<br>
Ausnahme: Events, die als Trigger eingestellt sind, bleiben erhalten.

== Affected devices ==
[[Datei:MSwitch_Screen_5.png|mini|rechts|affected devices]]
Dieser Abschnitt beinhaltet die Auswahl der Devices, die auf ein Event reagieren sollen.

In dem Auswahlfeld werden alle Devices angeboten, die eines der folgenden Kriterien erfüllen:
# Die Abfrage "set Device ?" liefert einen Befehlssatz
# Das Attribut 'webcmd' des Devices enthält Einträge
# Das Attribut 'MSwitch_Activate_MSwitchcmds' ist aktiviert und das Attribut 'MSwitchcmds' des betreffenden Devices enthält einen Befehlssatz

Einzige Ausnahme ist der erste Listeneintrag 'FreeCMD'. Die Auswahl dieses Eintrages bietet später die Möglichkeit Befehle auszuführen, die nicht an ein Device gebunden sind. Der Code in einem FreeCmd kann entweder reiner FHEM-Code sein ( set device on ) oder reiner Perl-Code. Wenn es sich um reinen Perl-Code handelt, ist dieser in geschweifte Klammen zu setzen { Perl-Code } .

== Device actions ==
[[Datei:Webinterface3.png|mini|rechts|device_actions]]
Hier stellt man die auszuführenden Aktionen der eingestellten Devices ein. Im ersten Abschnitt oben befindet sich ein FreeCmd, mit dem beliebige Kommandos eingetragen werden können. Im abgebildeten Beispiel ist dies sogar selbst definierter Perl-Code (die Funktion DebianMail sendet eine Mail). 

===== MSwitch cmd1/cmd2:  =====
Man wählt den Befehl aus dem betreffenden Device aus. Bei freien Textfeldern (wie im Fall des FreeCmd) wird der Befehl eingegeben.<br>
Es werden alle verfügbaren Befehle des Devices zur Auswahl angeboten. Je nach Attribut-Einstellungen werden Einträge aus entsprechenden 'webcmds" oder 'MSwitchcmds' einbezogen. In Abhängigkeit des Befehls stehen unter Umständen weitere Felder oder Widgets zur Verfügung.

05.04.2018 NEU: Auswahlfeld 'MSwitchtoggle' -> Beschreibung wird noch ergänzt !

===== cmd1/cmd2 condition  =====
Mit diesem Feld kann die Ausführung des Befehls von weiteren Bedingungen abhängig gemacht werden. Bei der Abfrage von Readings nach Strings (on, off, etc.) ist statt "=" "eq" zu nutzen und der String muss in "x" gesetzt werden. Es ist auf korrekte Eingabe der Leerzeichen zu achten.<br><br>

#Zeitabhängiges schalten: [19:10-23:00] - Schaltbefehl erfolgt nur in angegebenem Zeitraum
#Readingabhängiges schalten [Devicename:Reading] =/>/< X oder [Devicename:Reading] eq "x" - Schaltbefehl erfolgt nur bei erfüllter Bedingung.<br><br>

Soll nur an bestimmten Wochentagen geschaltet werden, muss eine Zeitangabe gemacht werden.<br>
Beispielsweise würde [10:00-11:00|13] den Schaltvorgang nur Montag und Mittwoch zwischen 10 Uhr und 11 Uhr auslösen. Hierbei zählen die Wochentage von 1-7 für Montag-Sonntag.<br><br>

Die Kombination mehrerer Bedingungen und Zeiten ist durch AND oder OR möglich:<br>
[19:10-23:00] AND [Devicename:Reading] = 10 - beide Bedingungen müssen erfüllt sein.<br>
[19:10-23:00] OR [Devicename:Reading] = 10 - eine der Bedingungen muss erfüllt sein.<br>
[{sunset()}-23:00] - von Sonnenuntergang bis 23:00 Uhr.<br>
{ !$we } löst den Schaltvorgang nur Werktagen aus<br>
{ $we } löst den Schaltvorgang nur Wochenenden, Feiertagen aus<br>

'''Achtung:''' Bei Anwendung der geschweiften Klammern zur Einleitung eines Perl Ausdrucks ist unbedingt auf die Leerzeichen hinter und vor der Klammer zu achten.

Überschreitet die Zeitangabe die Tagesgrenze (24:00 Uhr), so gelten die angegebenen Tage noch bis zum Ende der angegebenen Schaltzeit (zum Beispiel würde auch am Mittwoch noch der Schaltvorgang erfolgen, wenn als Tagesvorgabe Dienstag gesetzt wurde).

$EVENT:<br>
Die Variable EVENT enthält den auslösenden Trigger, d.h. es kann eine Reaktion in direkter Abhängigkeit zum auslösenden Trigger erfolgen.<br>

[$EVENT] eq "state:on" würde den Kommandozweig nur dann ausführen, wenn der auslösende Trigger "state:on" war.
Wichtig ist dieses, wenn bei den Triggerdetails nicht schon auf ein bestimmtes Event getriggert wird, sondern hier durch die Nutzung eines Wildcards (*) auf alle Events getriggert wird, oder auf alle Events eines Readings z.B. (state:*)

===== cmd1/cmd2 delay  =====

Ein Eintrag in diesem Feld führt zur verzögerten Ausführung des Befehls nach eintreffen des Events. Dabei kann der Befehl ohne weitere Prüfung der Bedingung ausgelöst werden. Es ist aber auch möglich, dass die Bedingung bei Ausführung erneut geprüft wird. Die Zeitangabe muss im Format hh:mm:ss vorliegen.
<br>

Statt einer unmittelbaren Zeitangabe kann hier auch ein Verweis auf ein Reading eines Devices erfolgen :<br>
[NAME.reading] des Devices ->z.B. [dummy.state]<br>

===== add action  =====
Mit diesem Button kann ein weiteres Eingabefeld für das entsprechende Device angelegt werden, um z.B einen weiteren Befehl (ggf.) zeitverzögert auszuführen.

===== delete this action  =====
Mit diesem Button wird der entsprechende Befehl für das Device gelöscht.

===== check condition  =====
[[Datei:MSwitch_Screen_7.png|mini|rechts|check]]
Die angegebenen 'conditions' werden in Zusammenhang mit ggf. ausgewählten Devices auf Syntax und Ergebnis geprüft. Es erfolgt eine Ausgabe des Prüfungsergebnisses.<br>

===== Repeat und Repeatdelay =====
Man kann mehrfache Wiederholungen erzwingen. Repeat gibt dabei an, wie oft das Kommando wiederholt wird (Anzahl). Repeatdelay gibt an, wie viel Sekunden zwischen einzelnen Wiederholungen liegen sollen.

== Konfigurationsbeispiele ==

===== IT-Fernbedienung -> Sonoff  =====

 - [[MSwitch_Konfigurationsbeispiele#MSwitch_IT_to_Sonoff|IT Fernbedienung_Sonoff schalten]]

===== Dashbuttons  =====

 - [[MSwitch_Konfigurationsbeispiele#Dashbuttons|Dashbuttons]]

= Attribute =

Folgende Attribute stehen zur Verfügung:


Schaltet Hilfebuttons zu den einzelnen Eingabefeldern an oder aus.

==== MSwitch_Debug (0:1:2) ====
0 - Abgeschaltet<br>
1 - Schaltet Felder zum testen der Conditionstrings etc. an<br>
2 - erweiterte Debugfunktion (nur für Entwicklung)<br>

==== MSwitch_Expert (0:1) ====
In der Liste der möglichen Trigger erscheint das Selectfeld 'GLOBAL'. Dieses ermöglicht das Setzen eines Triggers auf alle Events und damit nicht nur auf einzelne Devices. In einem weiteren Feld kann eine weitere Selektion der triggernden Events erfolgen.

Es stehen weitere Felder 'Repeats' und 'Repeatdelay in sec' zur Verfügung. Eine hier getätigte Einstellung bewirkt X-fache Wiederholung von gesetzten Befehlen im Abstand der gesetzten Sekunden.

==== MSwitch_Extensions (0:1) ====
Es wird eine zusätzliche Schaltoption 'MSwitchToggle' in den Geräten angeboten. Diese kann genutzt werden, wenn zuschaltende Geräte eine Togglefunktion nicht von Haus aus anbieten.<br>
<br>
Eine Angabe muss in folgendem Format gemacht werden :<br>
on/off/state/suchmuster1/suchmuster2, wobei diel letzten 3 Angaben Optional sind.

Funktion: Bei Ausführung des Befehls wird das Gerät 'on' oder 'off' geschaltet (on/off), Voraussetzung ist, das der 'state' dieses Gerätes auch den 'state on' oder 'off' annimmt. Sollte dieses nicht der Fall sein, so kann mit dem Feld 'state' angegeben werden, in welchen Reading der aktuelle Status vorkommt und wie dieser lautet (suchmuster1/suchmuster2). Dieses 'state' kann mehrere Angaben enthalten, das Vorkommen der Suchmuster ist aber Voraussetzung.

==== MSwitch_Delete_Delays (0:1) ====
Bewirkt das Löschen aller anstehende Timer (Delays) bei dem Auftreten eines erneuten, passenden Events. Bei der Option '0' bleiben bereits gesetzte Delays aus einem vorherigen, getriggertem Event erhalten und werden ausgeführt.<br>
Empfohlene Einstellung (1)

==== MSwitch_Include_Devicecmds (0:1) ====
Bewirkt die Aufnahme aller Devices in die Auswahlliste 'Affected Devices', die einen eigenen Befehlssatz liefern (bei Abfrage set DEVICE ?).<br>
Bei gesetzter Option (0) werden diese Devices nicht mehr berücksichtigt und somit nicht mehr angeboten.<br>
Empfohlene Einstellung (1).

==== MSwitch_Include_Webcmds (0:1) ====
Bewirkt die Aufnahme aller Devices in die Auswahlliste 'Affected Devices', die einen eigenen Befehlssatz in dem Attribut Webcmd hinterlegt haben. Die in Webcmd hinterlegten 'Befehle' werden in den Auswahlfeldern angeboten.

Bei gesetzter Option (0) werden diese Devices nicht mehr berücksichtigt und somit nicht mehr angeboten, wenn sie nicht zusätzlich einen eigenen Befehlssatz (set DEVICE ?) liefern.<br>
Empfohlene Einstellung (0), Einsatz nach Bedarf.

==== MSwitch_Activate_MSwitchcmds (0:1) ====
Fügt jedem vorhandenen Device as Attribut 'MSwitchcmd' hinzu.

==== MSwitch_Include_MSwitchcmds (0:1) ====
Bewirkt die Aufnahme aller Devices in die Auswahlliste 'Affected Devices', die einen eigenen Befehlssatz in dem Attribut MSwitchcmds hinterlegt haben. Die in MSwitchcmds hinterlegten 'Befehle' werden in den Auswahlfeldern angeboten. Bei gesetzter Option (0) werden diese Devices nicht mehr berücksichtigt und somit nicht mehr Angeboten, wenn sie nicht zusätzlich einen eigenen Befehlssatz (set DEVICE ?) liefern.<br>
Empfohlene Einstellung (0), Einsatz nach Bedarf.

==== MSwitch_Lock_Quickedit (0:1) ====
Voreinstellung für die Auswahlliste 'Affected Devices'. Bei der Option (1) ist diese voreingestellt gesperrt und kann nur über einen zusätzlichen Button geändert werden. Da es sich hier um ein Feld mit der Möglichkeit einer Mehrfacheingabe handelt handelt ist die Voreinstellung 1, um versehentliche nicht gewünschte Änderungen zu vermeiden (Auswahl einer Option ohne 'Strg' bewirkt das löschen aller bereits gesetzten Optionen).<br>
Empfohlene Einstellung (1).

==== MSwitch_Ignore_Types ====
Beinhaltet eine Liste von Device''typen'', die in den Auswahllisten ''nicht'' dargestellt werden. Hier ist es sinnvoll, Devicetypen einzutragen, die in aller Regel nicht geschaltet werden oder nicht geschaltet werden können, um die Auswahllisten übersichtlicher zu halten. Einzelne Devicetypen sind durch Leerzeichen zu trennen.<br>
Voreinstellung: notify allowed at watchdog doif fhem2fhem telnet FileLog readingsGroup FHEMWEB autocreate eventtypes readingsproxy svg cul.

==== MSwitch_Trigger_Filter ====
Beinhaltet eine Liste von Events, die bei eingehenden Events unberücksichtigt bleiben. Diese werde dann auch nicht gespeichert.<br>
Hier kann mit Wildcards (*) gearbeitet werden. Einzelne Events sind durch Komma ',' zu trennen.<br>
Empfohlene Einstellung (keine).

==== MSwitch_Wait (sec)====
Bei gesetztem Attribut (Zeit in Sekunden) nimmt Das MSwitch Device für den eingestellten Zeitraum keine Befehle mehr entgegen und ignoriert eingehende Events

==== MSwitch_Mode (Notify,Full,Toggle)====
Schaltet das Modul zwischen verschiedenen Modi um, mit entsprechend angepasster Weboberfläche<br>
Notify - Das Device kann nicht manuell umgeschaltet werden, es gibt nur 2 ausführbare Zweige ( ececote 'on' commands und execute 'off' commands). Der Status des Devices wird nicht als 'on' oder 'off' angezeigt, sondern lediglich als 'active'<br>Dieser Mode ist am ehesten mit einem Notify zu Vergleichen.<br><br>

Full - Es stehen alle Funktionen zur Verfügung.<br><br>

Toggle - Seher vereinfachter Mode. Es stehen keine verschiedenen Zweige zur Verfügung. Hier wird das Device bei jedem definierten Event 'Umgeschaltet', entsprechend definierte Befehle für 'on' oder 'off' werden ausgeführt.

==== MSwitch_Condition_Time (0,1)====
In der Grundeinstellung (0) werden für das zeitgesteuerte Schalten keine definierten Conditionen im Feld 'Trigger condition' überprüft, sondern die Schaltbefehle werden in jedem Fall ausgeführt. Mit der Einstellung (1) wird diese Überprüfung auch für zeitgesteuerte Befehle zugeschaltet.

==== MSwitch_Random_Time (HH:MM:SS-HH:MM:SS)====
Bei Aktivierung wird vor jedem Ausführen eines verzögerten Befehls ( Delay ) eine Zufallszeit generiert, die im Rahme der hier angegebenen Zeitspanne liegt. Auf diese Zufallszahl kann in de Delays zugegriffen werden, durch die Angabe '[random' statt einer direkten Zeitangabe. Bei nicht gesetztem Attribut ergibt die Angabe von ' [random] ' hier immer '00:00:00'

==== MSwitch_Random_Number ====
bei Aktivierung dieses Attributes ( der Inhalt kann einen beliebige Zahl sein ) werden vom Device 2 Readings angelegt (Device:RandomNr) und (Device:RandomNr1). RandomNr wird vor jedem Ausführen eines Befehls aktualisiert und neu generiert, d.H wenn ein MSwitch Device mehrere Geräte schaltet, wird ( auch in einem Durchgang ) vor jedem Befehl dieses Reading neu gesetzt. RandomNr1 wird lediglich bei Ausführung des MSwitch Devices einmal neu gesetzt, d.H nicht vor jedem Befehl der Ausgeführt wird.
Die Readings werden mit einer Zufallszahl zwischen 0 und dem hier eingestellten Wert gesetzt. <br>
Auf diese Readings kann in jeder Condition mit z.B '[$NAME:ReadingNr1] = 1' zugegriffen werden. <br>
D.h. das in der Condition angegebene Reading ( [$NAME:ReadingNr1] ) muss in diesem Fall den Wert 1 angenommen haben, ansonsten wird der Befehl nicht ausgeführt. 
Der Befehl wird somit nur mit einer Wahrscheinlichkeit von 1 zu ( gesetzter Wert im Attr. ) ausgeführt.

==== MSwitch_Safemode (0:1)====
Bietet einen ( gewissen ) Schutz vor falschen Konfigurationen und somit entstehenden Endlosschleifen.
Bei aktiviertem Attribut (1) erkennt das Modul Endlosschleifen eines Devices und beendet Diese.<br>
In diesem Fall erfolgt ein Logeintrag und das Device wird par Attribut auf 'Disabled' gesetzt.<br>
Es wird ein letztes Event generiert, auf das reagiert werden kann:
 <small>2018-05-31 09:39:21 MSwitch <NAME> Safemode: on</small>
Im Webinterface erfolgt bei betroffenem Device ein entsprechender Hinweis.<br>
<br>In der Grundkonfiguration ist dieses Attribut nicht gesetzt, es empfiehlt sich aber, bei neuen (komplizierten) Devices, Dieses - zumindest anfänglich - zu aktivieren.

==== MSwitch_Inforoom ====
Mit diesem Attribut wird die Raumansicht eines mit dem Attribut bestimmten Raumes verändert. Dadurch sollen die wichtigsten Informationen aller MSwitch-Devices auf eine Seite dargestellt werden. Zur Nutzung sollten alle MSwitch-Devices (zusätzlich) in einen Raum sortiert werden und dieser Raum im Attribut eingestellt werden.<br>
<br>
Wichtig: Eine Änderung dieses Attributes bewirkt immer eine Änderung dieses Attributes in ''allen'' MSwitch devices: Es muss nur in einem Device gesetzt oder gelöscht werden um alle Devices zu erfassen.<br>

<gallery>
MSwitch_Screen_1.png|Raumansicht des Raumes MSwitch mit gesetztem Attribut 'MSwitch'
MSwitch_Screen_2.png|Raumansicht des Raumes MSwitch ohne gesetztes Attribut
</gallery>

Es werden folgende Informationen bereitgestellt:<br>

- Infobutton zeigt den im Device gespeicherten Textes des Attributes 'comment'<br>
- Device und Events, die das Device triggern<br>
- Zeiten, zu denen verschiedene Zweige des Devices ausgeführt werden<br>
- Devices, die durch das MSwitch Device geschaltet werden
- State des Devices

= Tipps, Tricks, Kurzbeispiele =
wird stetig ergänzt .

== Daten zwischenspeichern ==
- In einem MSwitch Device besteht relativ einfach die Möglichkeit, Werte ( z.B readings oder states anderer Devices ) zwischenzuspeichern. (ab V1.45 !)<br>
Hierzu ist ein FreeCmd mit folgendem Inhalt anzulegen :<br>
{ readingsSingleUpdate( $hash, "readingname", ReadingsVal( "dummy1", "state", "undef" ), 1 ); }<br>
Hiermit wird im MSwitchdevice ein eigenes Reading angelegt, was den Inhalt des 'states' von 'Dummy1' zum Zeitpunkt des MSwitch-Aufrufes erhält.<br>
Dieses Reading steht dann in weiteren Befehlen mit [$NAME:<readingname>] sofort (noch im selben Durchlauf) zur Verfügung, da Freecmds immer zuerst abgearbeitet werden.<br>
<br>
Ein FreeCmd mit folgendem Inhalt löscht dieses Reading wieder:<br>
deletereading <MSwitchdevice> readingname<br><br>

Bezug z.B. auf:  https://forum.fhem.de/index.php/topic,87938.0.html <br> wäre auch hier ein Ansatz:https://forum.fhem.de/index.php/topic,87957.0.html<br>

Ich habe an dieser Stelle nicht diesen Lösungsvorschlag gewählt, sondern erst später versucht es nur mit MSwitch zu lösen.<br>
<br>
<br>

== Blinken - falls nicht im Device vorhanden ==

[[Datei:MSwitch MSwitchblink.png|center|704px]]
<br clear=all>
lässt ein beliebiges Device 5 mal togglen, mit einem Intervall von 0.5 Sekunden (Blinkzeit somit 2,5 Sekunden)<br>
Die MSwitchtoggle-Funktion muss per ATTR aktiviert werden.<br>
Die Repeatfunktion ist nur im Expertmode verfügbar, auch per ATTR einstellbar.

== Linearschalter ==


Umsetzung eines Linearschalters mit MSwitch.<br>
Eingang: beliebiges Reading als numerischer Wert<br>
Ausgang: wird entsprechend Linear / oder umgekehrt Linear zum Eingang geschaltet.<br>
Folgend die Rawdefinition des MSwitchdevices und zweier Dummys ( selbst erklärend )<br>
Alle Devices werden im Raum Lineartest angelegt, die Dummy müssen zuerst angelegt werden.<br>

<pre>defmod linearausgang dummy
attr linearausgang room Lineartest
attr linearausgang setList state:slider,0,1,100
attr linearausgang webCmd state
setstate linearausgang state 57
setstate linearausgang 2018-06-06 18:06:12 state state 57</pre>

<pre>defmod lineareingang dummy
attr lineareingang room Lineartest
attr lineareingang setList state:slider,0,1,15000
attr lineareingang webCmd state
setstate lineareingang 6422
setstate lineareingang 2018-06-06 18:06:12 state 6422</pre>

<pre>defmod Linearschalter MSwitch lineareingang  # linearausgang FreeCmd
attr Linearschalter MSwitch_Debug 0
attr Linearschalter MSwitch_Delete_Delays 1
attr Linearschalter MSwitch_Expert 0
attr Linearschalter MSwitch_Extensions 0
attr Linearschalter MSwitch_Help 0
attr Linearschalter MSwitch_Ignore_Types notify allowed at watchdog doif fhem2fhem telnet FileLog readingsGroup FHEMWEB autocreate eventtypes readingsproxy svg cul
attr Linearschalter MSwitch_Include_Devicecmds 1
attr Linearschalter MSwitch_Include_MSwitchcmds 0
attr Linearschalter MSwitch_Include_Webcmds 0
attr Linearschalter MSwitch_Inforoom MSwitch
attr Linearschalter MSwitch_Lock_Quickedit 1
attr Linearschalter MSwitch_Mode Notify
attr Linearschalter room Lineartest

setstate Linearschalter active
setstate Linearschalter 2018-06-06 18:03:50 .Device_Affected FreeCmd-AbsCmd1,FreeCmd-AbsCmd2,linearausgang-AbsCmd1
setstate Linearschalter 2018-06-06 18:04:35 .Device_Affected_Details FreeCmd-AbsCmd1,cmd,cmd,{my $eingang =ReadingsVal( "lineareingang"## "state"## 0 );;my $emin=0;;my $emax=15000;;my $amin=100;;my $amax=0;;$eingang = $emin if $eingang < $emin;;$eingang = $emax if $eingang > $emax;;my $y= (($amax-$amin)/($emax-$emin)*($eingang-$emin))+$amin;;readingsSingleUpdate( $hash## "to_set"## int ($y)## 1 );;},,delay1,delay1,000000,000000,,,0,0|FreeCmd-AbsCmd2,cmd,cmd,,,delay1,delay1,000000,000000,,,0,0|linearausgang-AbsCmd1,state,no_action,[Linearschalter:to_set],,delay1,delay1,000000,000000,,,0,0
setstate Linearschalter 2018-06-06 18:06:12 .Device_Events no_trigger
setstate Linearschalter 2018-06-04 18:24:21 .First_init done
setstate Linearschalter 2018-06-06 18:00:47 .Trigger_cmd_off no_trigger
setstate Linearschalter 2018-06-06 18:00:47 .Trigger_cmd_on *
setstate Linearschalter 2018-06-06 17:58:56 .Trigger_condition 
setstate Linearschalter 2018-06-06 18:00:47 .Trigger_off no_trigger
setstate Linearschalter 2018-06-06 18:00:47 .Trigger_on no_trigger
setstate Linearschalter 2018-06-06 17:58:56 .Trigger_time 
setstate Linearschalter 2018-06-04 18:24:21 .V_Check V 0.3
setstate Linearschalter 2018-06-06 18:06:12 EVENT state: 6422
setstate Linearschalter 2018-06-06 18:06:12 EVTFULL lineareingang:state: 6422
setstate Linearschalter 2018-06-06 18:06:12 EVTPART1 lineareingang
setstate Linearschalter 2018-06-06 18:06:12 EVTPART2 state
setstate Linearschalter 2018-06-06 18:06:12 EVTPART3  6422
setstate Linearschalter 2018-06-06 18:06:12 Exec_cmd set linearausgang state [Linearschalter:to_set]
setstate Linearschalter 2018-06-06 17:58:56 Trigger_device lineareingang
setstate Linearschalter 2018-06-06 18:00:47 Trigger_log off
setstate Linearschalter 2018-06-06 18:06:12 last_event state: 6422
setstate Linearschalter 2018-06-04 18:39:56 state active
setstate Linearschalter 2018-06-06 18:06:12 to_set 57</pre>

MSwitch -Configfile ( bei Bedarf )
<pre>#V V1.54
#S .Device_Affected -> FreeCmd-AbsCmd1,FreeCmd-AbsCmd2,linearausgang-AbsCmd1
#S .Device_Affected_Details -> FreeCmd-AbsCmd1,cmd,cmd,{my $eingang =ReadingsVal( "lineareingang"## "state"## 0 )[S]my $emin=0[S]my $emax=15000[S]my $amin=100[S]my $amax=0[S]$eingang = $emin if $eingang < $emin[S]$eingang = $emax if $eingang > $emax[S]my $y= (($amax-$amin)/($emax-$emin)*($eingang-$emin))+$amin[S]readingsSingleUpdate( $hash## "to_set"## int ($y)## 1 )[S]},,delay1,delay1,000000,000000,,,0,0|FreeCmd-AbsCmd2,cmd,cmd,,,delay1,delay1,000000,000000,,,0,0|linearausgang-AbsCmd1,state,no_action,[Linearschalter.to_set],,delay1,delay1,000000,000000,,,0,0
#S .Device_Events -> no_trigger
#S .First_init -> done
#S .Trigger_Whitelist -> undef
#S .Trigger_cmd_off -> no_trigger
#S .Trigger_cmd_on -> *
#S .Trigger_condition -> 
#S .Trigger_off -> no_trigger
#S .Trigger_on -> no_trigger
#S .Trigger_time -> 
#S .V_Check -> V 0.3
#S Trigger_device -> lineareingang
#S Trigger_log -> off
#S last_event -> state: 6422
#S state -> active
#A MSwitch_Ignore_Types -> notify allowed at watchdog doif fhem2fhem telnet FileLog readingsGroup FHEMWEB autocreate eventtypes readingsproxy svg cul
#A MSwitch_Include_MSwitchcmds -> 0
#A MSwitch_Debug -> 0
#A MSwitch_Help -> 0
#A MSwitch_Include_Devicecmds -> 1
#A MSwitch_Extensions -> 0
#A MSwitch_Include_Webcmds -> 0
#A room -> Lineartest
#A MSwitch_Inforoom -> MSwitch
#A MSwitch_Expert -> 0
#A MSwitch_Lock_Quickedit -> 1
#A MSwitch_Mode -> Notify
#A MSwitch_Delete_Delays -> 1
</pre>
Folgende Variablen stehen im Freecmd1 zur Verfügung und können/müssen angepasst werden:<br>
$eingang = Eingehender Wert aus Reading<br>
$emin=0 - minimal zur berücksichtigender Eingangswert<br>
$emax=15000 - maximal zur berücksichtigender Eingangswert<br>
$amin=100 - Ausgang bei maximalem Eingang<br>
$amax=0 - Ausgang bei minimalem Eingang<br>

Die Funktion sollte beim Probieren klar werden, Fragen gerne im Forum.
