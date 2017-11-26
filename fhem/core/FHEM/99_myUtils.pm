##############################################
# $Id: myUtilsTemplate.pm 7570 2015-01-14 18:31:44Z rudolfkoenig $
#
# Save this file as 99_myUtils.pm, and create your own functions in the new
# file. They are then available in every Perl expression.

package main;

use strict;
use warnings;
use POSIX;
use Time::Local;

sub
myUtils_Initialize($$)
{
  my ($hash) = @_;
}

# Enter you functions below _this_ line.

###################################################
###     SpritpreisÃƒÂ¼bersicht - Farbsortierung    ###
###################################################

sub Werte($$) {
  my ($name, $wert) = @_;
# Log(3,"$name $wert");
  if ($name eq "Diesel") {
    return 'style="color:red"' if($wert >= 1.39); 
    return 'style="color:blue"' if(($wert >= 1.33) && ($wert < 1.39));
    return 'style="color:green;;font-weight:bold"' if($wert <= 1.32);
  }elsif ($name eq "SuperE10") {
    return 'style="color:crimson"' if($wert >= 1.70); 
    return 'style="color:yellow"' if(($wert >= 1.55) && ($wert < 1.70));
    return 'style="color:lightgreen;;font-weight:bold"' if($wert < 1.55);
  }elsif ($name eq "SuperE5") {
    return 'style="color:red"' if($wert >= 1.59); 
    return 'style="color:blue"' if(($wert >= 1.49) && ($wert < 1.59));
    return 'style="color:green;;font-weight:bold"' if($wert <= 1.48);
  }  
}

#
# Anruf Funktionen
#
sub CheckAnrufe($)
{
   my ($aktion) = @_;
 
   #bei ausgehenden Anrufen wird der Dummy hochgezÃƒÂ¤hlt
   if (ReadingsVal("fbCallMonitor", "direction", "outgoing") eq "incoming")
   {
      fhem("set duVerpassteAnrufe ".(Value("duVerpassteAnrufe")+1));
   }
}

#
# aktuelle Sonos Playlists ermitteln und im Dummy als Liste speichern
# evtl. noch einen regelmäßigen Trigger erstellen, aktuell nur bei manuellem Aufruf
#
sub
MeinePlayList()
{
   #Buero ist am Rooter und immer an, daher Playlist hier ermitteln
   #manchmal dauert es etwas länger, die Playlisten zu ermitteln. Hier müsste man eigentlich noch ein "sleep" einfügen
   #bisher nur durch manuellen Neuaufruf realisiert
   fhem("get Sonos_Wohnzimmer Playlists;");
   my $Playlist = ReadingsVal("Sonos_Wohnzimmer", "LastActionResult", "Keine");
   my @Playlists = split('GetPlaylists: ', $Playlist);
   
   #zusätzllich noch unseren einzigen Radiosender dazu packen
   my $playlistneu = 'Radio Bochum'.$Playlists[1];
 
   #playlist für TABUI select aufbereiten
   $playlistneu =~ s/,/:/g;
   $playlistneu =~ s/\"//g;
 
   fhem("setreading duSonosPlaylists Playlist ".$playlistneu);
}
 
#
# Bei Aufruf aus TabUI die ausgewählte Sonos Playlist auf dem gewünschten Gerät starten
#
sub SonosPlaylistStarten($)
{
   my ($Playlist) = @_;
   my @player = split(' ',$Playlist);
   my @Liste = split($player[0]." ", $Playlist);
 
   $Liste[1] =~ s/ /%20/g;
 
   # falls der Radiosender gewählt wurde
   if($Playlist =~ /SWR3/)
   {
      fhem("set $player[0] StartRadio $Liste[1]");
   }
   else
   {
      fhem("set $player[0] StartPlaylist $Liste[1]");
   }
}

sub call_mpd1_getcover() {
    Log 1, "call_mpd1_getcover";
    BlockingCall("mpd_getcover","MPD1","done_mpd1_getcover",60);
}

sub done_mpd1_getcover($) {
    my $url = shift;
    Log 1, "done_mpd1_getcover";
    fhem ("setreading MPD1 cover ".$url);
}

sub call_mpd1_playlistinfo() {
    Log 1, "call_mpd1_playlistinfo";
    BlockingCall("mpd_playlistinfo","MPD1","done_mpd1_playlistinfo",120);
}

sub done_mpd1_playlistinfo($) {
    my $playlist = shift;
    Log 1, "done_mpd1_playlistinfo";
    fhem ("setreading MPD1 playlistinfo ".$playlist);
}

sub mpd_playlistinfo($) {
  my $device = shift;
  my ($all) = fhem("get $device mpdCMD playlistinfo");
  $all =~ s/"/\\"/g;  
  my @artist = ($all=~/\nArtist:\s(.*)\n/g);
  my @title = ($all=~/\nTitle:\s(.*)\n/g);
  my @album = ($all=~/\nAlbum:\s(.*)\n/g);
  my @time = ($all=~/\nTime:\s(.*)\n/g);
  my @file = ($all=~/\nfile:\s(.*)\n/g);
  my @track = ($all=~/\nTrack:\s(.*)\n/g);
  my @albumUri = ($all=~/\nX-AlbumUri:\s(.*)\n/g);

  my $ret = '[';
  my $ua = LWP::UserAgent->new( ssl_opts => { verify_hostname => 1 } );
  my $lastUri = '';
  my $url;

  for my $i (0 .. $#artist)
  {
     if ( $lastUri ne $albumUri[$i]) {
       my $response = $ua->get("https://embed.spotify.com/oembed/?url=".$albumUri[$i]);
       my $data = '';
       if ( $response->is_success ) {
         $data = $response->decoded_content;
         $url = decode_json( $data );
         $lastUri = $albumUri[$i];
       }
     }

      $ret=$ret.'{"Artist":"'.$artist[$i].'",';
      $ret=$ret.'"Title":"'.$title[$i].'",';
      $ret=$ret.'"Album":"'.$album[$i].'",';
      $ret=$ret.'"Time":"'.$time[$i].'",';
      $ret=$ret.'"File":"'.$file[$i].'",';
      $ret=$ret.'"Track":"'.$track[$i].'",';
      $ret=$ret.'"Cover":"'.$url->{'thumbnail_url'}.'"}';

      if ($i<$#artist) {$ret=$ret.',';}
  }
  $ret =~ s/;//g;
  $ret =~ s/\\n//g;
  return $ret.']';
}

sub mpd_getcover($) {
  my $device = shift;
  my $file = ReadingsVal($device, 'file', '');
  my $url = 'na';
  my $ua = LWP::UserAgent->new( ssl_opts => { verify_hostname => 1 } );
  my $response = $ua->get("https://embed.spotify.com/oembed/?url=".$file);
  my $data = '';
  if ( $response->is_success ) {
     $data = $response->decoded_content;
     $url = decode_json( $data )->{'thumbnail_url'};
  }
  return $url;
}

sub
OnMpdPlayPressed()
{
 my $val=ReadingsVal('AvReceiver', 'input', 'Webradio');
 if(($val ne 'SAT') && ($val ne 'BD/DVD') && ($val ne 'Game')) {
  fhem "set AvReceiver input Airplay";
 }
 fhem "get MPD1 playlists";
}

#
# Hilfsfunktion fÃ¼r Kalenderauswertungen
#
#
# Hilfsfunktion fÃ¼r Kalenderauswertungen
#
 
sub
KalenderDatum($$)
{
   my ($KalenderName, $KalenderUid) = @_;
   my $dt = fhem("get $KalenderName start uid=$KalenderUid 1");
   my $ret = time - (2*86400);  #falls kein Datum ermittelt wird RÃ¼ckgabewert auf "vorgestern" -> also vergangener Termin;
 
   if ($dt and $dt ne "")
   {
      my @SplitDt = split(/ /,$dt);
      my @SplitDate = split(/\./,$SplitDt[0]);
      $ret = timelocal(0,0,0,$SplitDate[0],$SplitDate[1]-1,$SplitDate[2]);
   }
 
   return $ret;
}
 
 
#
# Abfall Kalender auswerten / Google Kalender: "Abfall"
#
 
sub
Abfalltermine()
{
   my $t  = time;
   my @Tonnen = ("BlaueTonne", "GelbeTonne", "Restmuell");
   my @SuchTexte = (".*Blau.*", ".*Gelb.*", ".*Grau.*");
   my $uid;
   my $dayDiff;
  
   for(my $i=0; $i<4; $i++)
   {
      $dayDiff = -1; #BUG behoben
      my @uids = split(/;/,fhem("get Abfallkalender find $SuchTexte[$i]"));
       
      # den nÃ¤chsten Termine finden
      foreach $uid (@uids)
      {
         my $eventDate = KalenderDatum('Abfallkalender', $uid);
         my $dayDiffNeu = floor(($eventDate - $t) / 60 / 60 / 24 + 1);
         if ($dayDiffNeu >= 0 && ($dayDiffNeu < $dayDiff || $dayDiff == -1)) #BUG behoben
         {
            $dayDiff = $dayDiffNeu;
         }
      }
       
      fhem("setreading MuellterminDummy $Tonnen[$i] $dayDiff");
   }
}


#
#Alle Funktionen fÃ¼r das Aufstehen
#
sub Aufstehen($)
{
   my ($we) = @_;
 
   #hier kÃ¶nnen alle Schaltaktionen aufgerufen werden, die beim Aufstehen zu starten sind
   fhem("set Morgens on");
}


#
# Hilfsfunktion fÃ¼r den Wecker: Stellt den "Wecker Dummy", der alle Weckzeiten enthÃ¤lt auf Basis der Einstellung im TabUI
#
sub WeckerStellen()
{
   my $timer = ReadingsVal("duWeckerTabUI", "Timer", "Aufstehen");
   my $Tag = ReadingsVal("duWeckerTabUI","Tag","Reset");
   my $Zeit = sprintf("%02d",ReadingsVal("duWeckerTabUI","Stunde","09")).":".sprintf("%02d",ReadingsVal("duWeckerTabUI","Minute","00"));
 
   #jeden Wochentag zur gleichen Zeit wecken
   if($Tag eq "Wochentag")
   {
      fhem("setreading duWeckzeit wzMontag ".$Zeit);
      fhem("setreading duWeckzeit wzDienstag ".$Zeit);
      fhem("setreading duWeckzeit wzMittwoch ".$Zeit);
      fhem("setreading duWeckzeit wzDonnerstag ".$Zeit);
      fhem("setreading duWeckzeit wzFreitag ".$Zeit);
   }
   elsif ($Tag eq "Wochenende") #Weckzeit fÃ¼r Wochenende
   {
      fhem("setreading duWeckzeit wzSamstag ".$Zeit);
      fhem("setreading duWeckzeit wzSonntag ".$Zeit);
   }
   elsif ($Tag eq "Reset") #Default Weckzeiten setzen
   {
      if($timer eq "Aufstehen")
      {
         fhem("setreading duWeckzeit wzMontag 06:10");
         fhem("setreading duWeckzeit wzDienstag 06:10");
         fhem("setreading duWeckzeit wzMittwoch 06:10");
         fhem("setreading duWeckzeit wzDonnerstag 06:10");
         fhem("setreading duWeckzeit wzFreitag 06:10");
         fhem("setreading duWeckzeit wzSamstag 10:30");
         fhem("setreading duWeckzeit wzSonntag 10:30");
      }
      elsif($timer eq "?") #Funktion fÃ¼r weitere Timer
      {
          # fhem('modify WeekdayTimer oder at');
      }
   }
   else #Weckzeit fÃ¼r einen bestimmten Tag
   {
      fhem("setreading duWeckzeit wz".ReadingsVal("duWeckerTabUI","Tag","Montag")." ".$Zeit);
   }
    
   if($timer eq "Aufstehen") #WeekdayTimer fÃ¼r Aufstehen modifizieren
   {
      fhem("modify Aufstehen Bewohner 0|".ReadingsVal("duWeckzeit","wzSonntag","09:00")."|awoken 1|".ReadingsVal("duWeckzeit","wzMontag","09:00")."|awoken 2|".ReadingsVal("duWeckzeit","wzDienstag","09:00")."|awoken 3|".ReadingsVal("duWeckzeit","wzMittwoch","09:00")."|awoken 4|".ReadingsVal("duWeckzeit","wzDonnerstag","09:00")."|awoken 5|".ReadingsVal("duWeckzeit","wzFreitag","09:00")."|awoken 6|".ReadingsVal("duWeckzeit","wzSamstag","09:00").'|awoken (ReadingsVal("duUrlaub","state","ja") eq "nein")');
   }
   elsif($timer eq "?") #Modify Funktion fÃ¼r weitere Timer
   {
      # fhem('modify WeekdayTimer oder at');
   }
 
   fhem("save config");
}

sub checkFritzMACpresent($$) {
  # Benötigt: Name der zu testenden Fritzbox ($Device),
  #           zu suchende MAC ($MAC), 
  # Rückgabe: 1 = Gerät gefunden
  #           0 = Gerät nicht gefunden
  my ($Device, $MAC) = @_;
  my $Status = 0;
  $MAC =~ tr/:/_/;
  $MAC = "mac_".uc($MAC);
  my $StatusFritz = ReadingsVal($Device, $MAC, "weg");
  if ($StatusFritz eq "weg") {
    Log 1, ("checkFritzMACpresent ($Device): $MAC nicht gefunden, abwesend.");
    $Status = 0;
  } elsif ($StatusFritz eq "inactive") {
    Log 1, ("checkFritzMACpresent ($Device): $MAC ist >inactive<, also abwesend.");
    $Status = 0;
  } else {
    # Reading existiert, Rückgabewert ist nicht "inactive", also ist das Gerät per WLAN angemeldet.
    Log 1, ("checkFritzMACpresent ($Device): $MAC gefunden, Gerät heißt >$StatusFritz<.");
    $Status = 1;
  }
  return $Status
}

# Replace 127.0.0.1 with your ip-address
sub http_request($$$)
{
  my ($name, $characteristic, $value) = @_;
  my $data = sprintf('{"topic": "set", "payload": {"name": "%s", "characteristic": "%s", "value": %s}}', $name, $characteristic, $value); 
  #Log 1, ($data);
  my $ip = "192.168.2.3";
  my $url = sprintf("http://%s:1880/fhem", $ip);
  
  # method: POST
  HttpUtils_NonblockingGet({
    url       =>$url,
    timeout   => 5,
    header    =>"Content-Type: application/json",
    data      =>$data,
    name      =>$name,
    callback   =>sub($$$) {
      if ($_[1] ne "") {Log 1,"$_[0]->{name} ERR:$_[1] DATA:$_[2]";}
    }
  });
}

1;
# This template file can be used for layout creation
# needed by 02_RSS.pm and 55_InfoPanel.pm
#
# Use "save as" once to create the file with your desired name
#
