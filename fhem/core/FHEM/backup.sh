#!/bin/bash
 
mountIp="192.168.2.110"
mountDir="Benutzer\FHEM\backup"
mountUser="FHEM"
mountPass="backup"
mountSubDir="rpi/fhem"
localMountPoint="/Q/backup"
 
#optional
backupsMax="0"
localBackupDir="/backup"
pushoverUser="uudf1cw9eiik8gmjf5m5g3sh41arak"
pushoverToken="a4tt76kv6trdtgpi5ag5sehgnzdctz"
###################################
 
perl /opt/fhem/fhem.pl 7072 "setreading FHEM.Backup info backup starting now"
 
if [ ! -e "$localBackupDir" ]
then
echo "$localBackupDir wird erstellt"
mkdir -p "$localBackupDir"
else
echo "$localBackupDir bereits vorhanden"
fi
 
tar --exclude=backup -cvzf "/$localBackupDir/$(date +%y%m%d_%H%M%S)_fhem_backup.tar.gz" "/opt/fhem" &>/dev/null
 
if ! ping -c 1 $mountIp
then
echo "$mountIp nicht erreichbar, stop"
perl /opt/fhem/fhem.pl 7072 "set FHEM.Backup error"
perl /opt/fhem/fhem.pl 7072 "setreading FHEM.Backup info $mountIp not found"
exit
else
echo "$mountIp erreichbar"
fi
 
localIp=$(hostname -I|sed 's/\([0-9.]*\).*/\1/')
 
if [ ! -e "$localMountPoint" ]
then
echo "$localMountPoint wird erstellt"
mkdir -p "$localMountPoint"
else
echo "$localMountPoint bereits vorhanden"
fi
 
if [ "$(ls -A $localMountPoint)" ]
then
echo "$localMountPoint nicht leer, kein Mounten notwendig"
else
echo "$localMountPoint leer, Mounten starten"
vorhanden="0"
while read line
do
mountComplete="//$mountIp/$mountDir $localMountPoint cifs username=$mountUser,password=$mountPass,iocharset=utf8,sec=ntlm 0 0"
echo "mountComplete: $mountComplete"
if [ `echo "$line" | grep -c "$mountComplete"` != 0 ]
then
echo "/etc/fstab: Eintrag bereits vorhanden: $mountComplete"
vorhanden="1"
break
fi
done < "/etc/fstab"
if [ "$vorhanden" != "1" ]
then
echo "/etc/fstab: Eintrag wird ergänzt: $mountComplete"
echo "$mountComplete" >> "/etc/fstab"
fi
echo "Mounts werden aktualisiert"
mount -a
sleep 3
fi
 
if [ "$(ls -A $localMountPoint)" ]
then
if [ ! -e "$localMountPoint/$mountSubDir/$localIp" ]
then
mkdir -p "$localMountPoint/$mountSubDir/$localIp"
else
echo "$localMountPoint/$mountSubDir/$localIp existiert bereits"
fi
find "$localBackupDir" -name '*fhem_backup.tar.gz' | while read file
do
fileSize="0"
fileSizeMB=$(du -h $file)
fileSizeMB=${fileSizeMB%%M*}
filename=${file##*/}
echo "$filename ($fileSizeMB MB) wird in den Backupordner verschoben"
if [[ "$pushoverToken" != "" && "pushoverUser" != "" ]]
then
curl -s -F "token=$pushoverToken" -F "user=$pushoverUser" -F "title=FHEM $localIp" -F "message=Backup mit $fileSizeMB MB wird erstellt" https://api.pushover.net/1/messages.json
fi
#mv "$file" "$localMountPoint/$mountSubDir/$localIp/$filename"
cp "$file" "$localMountPoint/$mountSubDir/$localIp/$filename"
rm "$file"
perl /opt/fhem/fhem.pl 7072 "set FHEM.Backup off"
perl /opt/fhem/fhem.pl 7072 "setreading FHEM.Backup backup $filename"
perl /opt/fhem/fhem.pl 7072 "setreading FHEM.Backup backupMB $fileSizeMB"
perl /opt/fhem/fhem.pl 7072 "setreading FHEM.Backup info backup done"
done
else
echo "Mounten hat anscheinend nicht geklappt, skip."
exit
fi
 
#Löschen alter Backups
if [[ "$backupsMax" != "" && "$backupsMax" != "0" ]]
then
perl /opt/fhem/fhem.pl 7072 "setreading FHEM.Backup backupFilesMax $backupsMax"
backupsCurrent=`ls -A "$localMountPoint/$mountSubDir/$localIp" | grep -c "_fhem_backup.tar.gz"`
backupsDelete=$(($backupsCurrent-$backupsMax))
if [ "$backupsDelete" -gt "0" ]
then
echo "$backupsCurrent Backups vorhanden - nur $backupsMax aktuelle Backups werden vorgehalten - $backupsDelete Backups werden gelöscht"
ls -d "/$localMountPoint/$mountSubDir/$localIp/"* | grep "_fhem_backup.tar.gz" | head -$backupsDelete | xargs rm
else
echo "$backupsCurrent Backups vorhanden - bis $backupsMax aktuelle Backups werden vorgehalten"
fi
else
perl /opt/fhem/fhem.pl 7072 "setreading FHEM.Backup backupFilesMax no limit"
fi
 
backupsCurrent=`ls -A "$localMountPoint/$mountSubDir/$localIp" | grep -c "_fhem_backup.tar.gz"`
perl /opt/fhem/fhem.pl 7072 "setreading FHEM.Backup backupFiles $backupsCurrent"
 
 
echo "Mount wieder unmounten"
umount "$localMountPoint"
