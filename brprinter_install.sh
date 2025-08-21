#!/bin/bash -x
# > vim search whole line : `yy / <Ctrl-F> p <Enter>'
 # définitions de variables
 # gestion des arguments
 # infos Brother
 # quelques fonctions
 # quelques vérifications
 # prérequis pour le script
 # initialisation du tableau associatif `printer'
 # vérification de variables disponibles dans `printer'
 # préparation du système
 # téléchargement des pilotes
 # configuration de l'imprimante
 # configuration du scanner
# <

shopt -s extglob nullglob globstar

#############################
 # définitions de variables #
#############################
if test -f /etc/lsb-release
then
	. /etc/lsb-release
	DistroName="$DISTRIB_ID"
	VersionYear="${DISTRIB_RELEASE::2}"
	codeName="$DISTRIB_CODENAME"
elif test -f /usr/lib/os-release
then
	. /usr/lib/os-release
	DistroName="$NAME"
	VersionYear="${VERSION_ID::2}"
	codeName="$VERSION_CODENAME"
fi
user="$SUDO_USER"
arch="$(uname -m)"
date=$(date +%F_%T)
tmpDir="/tmp/packages"
Logfile="/home/$user/brprinter_install.log"
libDir="/usr/lib/$arch-linux-gnu"
declare -u modelName=$1
declare -A printer
declare -i err
declare -a printer_IP printer_name

##################
 # infos Brother #
##################
# Infos
Url_Info="https://download.brother.com/pub/com/linux/linux/infs"
# Packages :
Url_Pkg="https://download.brother.com/pub/com/linux/linux/packages"

Udev_Rules="/lib/udev/rules.d/60-libsane1.rules"
Udev_Deb_Name="brother-udev-rule-type1-1.0.2-0.all.deb"
Udev_Deb_Url="http://download.brother.com/welcome/dlf006654"
Scankey_Drv_Deb_Name="brscan-skey-0.3.4-0.amd64.deb"
Printer_dl_url="https://support.brother.com/g/b/downloadtop.aspx?c=fr&lang=fr&prod=${printerName}_us_eu_as"

#######################
 # quelques fonctions #
#######################
errQuit()
{
	>&2 echo "$@"
	exit 1
}
verif_lien()
{ # pour faire un boucle, suffit-il vérifier que le nombre d'arguments est pair ?
	local lien=$1 cible=$2
	if ! test -L "$lien"
	then
		ln -s "$cible" "$lien"
	fi
}
install_pkg()
{
	for pkg do
		if ! dpkg-query -f '${binary:Package}\n' -W "$pkg" &>/dev/null
		then
			apt-get install -qq "$pkg"
		fi
	done
}

###########################
 # quelques vérifications #
###########################
if test "$DistroName" != "Ubuntu"; then errQuit "La distribution n’est pas Ubuntu ou une des ses variantes officielles."; fi
if test "$SHELL" != "/bin/bash"; then errQuit "Shell non compatible. utilisez : bash"; fi
if test "$arch" != "x86_64"; then errQuit "Système non compatible."; fi
if ((EUID)); then errQuit "Vous devez lancer le script en root : sudo $0"; fi
if ! nc -z -w5 'brother.com' 80; then errQuit "le site \"brother.com\" n'est pas joignable."; fi

#############################
 # prérequis pour le script #
#############################
# a remettre le script en service
# if test -f "$Logfile"; then
#     Old_Date="$(head -n1 "$Logfile")"
#     mv -v "$Logfile" "$Logfile"."$Old_Date".log
# fi
# echo "$date" >> "$Logfile" # indispensable pour la rotation du log .
apt-get update -qq
sleep 1
# script : "wget" "nmap"( - ) "libxml2-utils" " gawk" "avahi-utils"
# imprimantes : "multiarch-support" "lib32stdc++6" "cups"
# scanner : "libusb-0.1-4:amd64" "libusb-0.1-4:i386" "sane-utils"
install_pkg "wget" "libxml2-utils" "gawk" "avahi-utils"

if ! test -d "$tmpDir"
then
	mkdir -pv "$tmpDir"
fi

if test -z "$modelName"
then
	##########################
	 # DETECTION AUTOMATIQUE #
	##########################
	# NET_printer_name= ???
	##### VERSION NMAP #####
	# my_IP="$(hostname -I | cut -d ' ' -f1)"
	# mapfile -t printer_IP < <(nmap -sn -oG - "$my_IP"/24 | gawk 'tolower($3) ~ /brother/{print $2}')
	# #printer_IP=( $(nmap -sn -oG - "$my_IP"/24 | gawk 'tolower($3) ~ /brother/{print $2}') )
	# #echo "${printer_IP[*]}"
	# for p_ip in "${printer_IP[@]}"; do
	#     if wget -E "$p_ip" -O "$tmpDir/index.html"; then
	#         printer_name+=( "$(xmllint --html --xpath '//title/text()' "$tmpDir/index.html" 2>/dev/null | cut -d ' ' -f2)" )
	#         #echo "printer_name == ${printer_name[*]}"
	#     fi
	# done

	##### VERSION AVAHI-BROWSE ( plus rapide et plus simple que nmap )#####
	mapfile -t printer_IP < <(avahi-browse -d local _http._tcp -tkrp | gawk -F';' '/^=/ && /IPv4/ && /Brother/ && !/USB/ {print $8}')
	mapfile -t printer_name < <(avahi-browse -d local _http._tcp -tkrp | gawk -F';' '/^=/ && /IPv4/ && /Brother/ && !/USB/ {sub(/Brother\\032/,"",$4); sub(/\\032.*/,"",$4); print $4}')

	# USB_printer_name= ???
	# mapfile -t printer_IP < <(avahi-browse -d local _http._tcp -tkrp | gawk -F';' '/^=/ && /IPv4/ && /Brother/ && /USB/ {sub(/Brother\\032/,"",$4); sub(/\\032.*/,"",$4); print $4}')
	if lsusb | grep -q 04f9:
	then
		mapfile -t printer_usb < <(lsusb | gawk '/04f9:/ {print $10}')
		for p_usb in "${printer_usb[@]}"
		do
			printer_name+=( "$p_usb" )
			printer_IP+=("USB")
		done
	fi

	case ${#printer_name[*]} in
		0) echo "Aucune imprimante détectée !
			Êtes vous sûr de l’avoir connectée au port USB de votre ordinateur ou à votre réseau local ?"
			# on repars donc avec les questions de base : modele etc ...
			;;
		1)  echo "Une seule imprimante détectée."
			modelName=${printer_name[0]} # ! printer_name != printerName
			IP=${printer_IP[0]}
			# pas besoin de poser de question , il ne reste plus qu ' a installer
			;;
		*)  echo "Plusieurs imprimantes ont été détectées."
			# il faut presenter sous forme de liste les éléments recupérés :
			# modele du materriel : IP ou USB
			# et demander à l' utilisateur de choisir un numero dans cette liste
			n_print=$(("${#printer_name[@]}"))
			for n in "${!printer_name[@]}"
			do
				echo " $((n+1))  ⇒  ${printer_name[$n]}  :  ${printer_IP[$n]}"
			done
			while test -z "$choix"
			do
				read -rp "Choisissez le numéro qui correspond à l’imprimante que voulez installer : " choix
				echo "$choix"
				if ! ((choix > 0 && choix <= n_print))
				then
					echo "Choix invalide !"
					unset choix
				fi
			done
			modelName="${printer_name[$choix-1]}"
			IP=${printer_IP[$choix-1]}
			;;
	esac
	##########################
	 # gestion des arguments #
	##########################
	until test -n "$modelName"
	do
		read -rp 'Entrez le modèle de votre imprimante : ' modelName
	done
fi

printerName="${modelName//-/}" # ! printer_name != printerName
#check IP
if test "$IP" = "USB"
then
	unset IP
	echo "Installation en USB."
else
	until test -n "$IP"
	do
		if test -n "$2"; then
			IP=$2
			shift $#
		else
			read -rp "Voulez-vous configurer votre imprimante pour qu’elle fonctionne en réseau ? [o/N] "
			echo "$REPLY"
			if [[ $REPLY == [YyOo] ]]; then
				read -rp "Entrez l’adresse IP de votre imprimante : " IP
			else
				echo "Installation en USB."
				break
			fi
		fi
		if test -n "$IP"; then
			IFS='.' read -ra ip <<< "$IP"
			for i in "${ip[@]}"; do
				((n++ ? i >=0 && i<=255 : i>0 && i<=255)) || err+="1"
			done
			if (( ${#ip[*]} != 4 )) || ((err)) || ! ping -qc2 "$IP"; then
				err=0
				unset IP
				echo "Adresse erronée !"
			fi
			echo "Installation en réseau."
		fi
	done
fi

###################################################
 # initialisation du tableau associatif `printer' #
###################################################
# creation $Url_PrinterInfo
Url_PrinterInfo="$Url_Info/$printerName"

while IFS='=' read -r k v
do
	printer[$k]=$v
done < <(wget -qO- "$Url_PrinterInfo" | sed '/\(]\|rpm\|=\)$/d')

#########################################################
 # vérification de variables disponibles dans `printer' #
#########################################################
if test -n "${printer[LNK]}"; then # on telecharge le fichier donné en lien
	Url_PrinterInfo="$Url_Info/${printer[LNK]}" # ????
	while IFS='=' read -r k v
	do
		printer[$k]=$v
	done < <(wget -qO- "$Url_PrinterInfo" | sed '/\(]\|rpm\|=\)$/d')
fi
if ! test "${printer[PRINTERNAME]}" == "$printerName"
then
	errQuit "Les données du fichier info récupéré et le nom de l’imprimante ne correspondent pas."
fi
if test -n "${printer[SCANNER_DRV]}"
then
	install_pkg "libusb-0.1-4:amd64" "libusb-0.1-4:i386" "sane-utils"
	printer[udev_rules]="$Udev_Deb_Name"
	. <(wget -qO- "$Url_Info/${printer[SCANNER_DRV]}.lnk" | sed -n '/^DEB/s/^/scanner_/p')
	. <(wget -qO- "$Url_Info/${printer[SCANKEY_DRV]}.lnk" | sed -n '/^DEB/s/^/scanKey_/p')
	printer[SCANNER_DRV]="$scanner_DEB64"
	printer[SCANKEY_DRV]="$scanKey_DEB64"

	if test -n "$VersionYear"; then
		if (( VersionYear >= 24 )) && test "${printer[SCANKEY_DRV]}" = "brscan-skey-0.3.2-0.amd64.deb"
		then
			printer[SCANKEY_DRV]="$Scankey_Drv_Deb_Name"
		fi
	else
		errQuit "Impossible d’évaluer la version de la distribution."
	fi
else
	err+="1"
	echo "Pas de pilote pour le scanner."
fi

###########################
 # préparation du système #
###########################
install_pkg "multiarch-support" "lib32stdc++6" "cups"

for d in "/usr/share/cups/model" "/var/spool/lpd"
do
	if ! test -d "$d"
	then
		mkdir -pv "$d"
	fi
done

for i in \
	DCP-{11{0,5,7}C,120C,31{0,5}CN,340CW} \
	FAX-{18{15,20,35,40}C,19{2,4}0CN,2440C} \
	MFC-{21{0,5}C,32{2,4}0C,33{2,4}0CN,3420C,3820CN,4{1,2}0CN,425CN,5440CN,5840CN,620CN,640CW,820CW}
do
		if test "$i" = "$modelName"
		then
				install_pkg "csh"
		fi
done
for i in \
	DCP-{1{0,4}00,80{{20,25D},{40,45D},{60,65DN}}} \
	FAX-{2{850,900},3800,4{100,750e},5750e} \
	HL-{1{030,230,2{4,5}0,270N,4{3,4,5}0,470N,650,670N,850,870N},5{0{3,4,5}0,070N,1{3,4}0,150D,170DN,240,2{5,7}0DN,280DW},6050{,D}} \
	MFC-{4800,6800,8{4{20,40,60N},500,660DN,8{20D,40D,60DN,70DW}},9{0{3,7}0,1{6,8}0,420CN,660,7{0,6}0,8{0,6,8}0}}
do
	if test "$i" = "$modelName"
	then
		verif_lien "/etc/init.d/lpd" "/etc/init.d/cups"
		if test -L /sbin/init
		then
			verif_lien "/lib/systemd/system/cups.service" "/lib/systemd/system/lpd.service"
			systemd daemon-reload
		fi
	fi
done

###############################
 # téléchargement des pilotes #
###############################
for drv in "${printer[@]}"
do
	if [[ $drv == @($printerName|no|yes) ]]; then continue;fi
	if ! test -f "$tmpDir/$drv"
	then
		Url_Deb="$Url_Pkg/$drv"
		if test "$drv" = "${printer[udev_rules]}"
		then
			Url_Deb="$Udev_Deb_Url/$drv"
		fi
		wget -cP "$tmpDir" "$Url_Deb"
	fi
	pkg2install+=( "$tmpDir/$drv" )
done
# installation des pilotes
if (( ${#pkg2install[*]} == 0 ))
then
	errQuit "Rien à installer."
else
	dpkg --install --force-all  "${pkg2install[@]}"
fi

##################################
 # configuration de l'imprimante #
##################################
#retrouver le fichier `.ppd' pour l'imprimante
for drv in "PRN_CUP_DEB" "PRN_DRV_DEB"
do
	pkg=${printer[$drv]}
	if test -n "$pkg" -a -f "$tmpDir/$pkg"
	then
		while read -rd '' fileName
		do
			PPDs+=( "$fileName" )
		done < <(dpkg --contents "$tmpDir/$pkg" | gawk 'BEGIN{ORS="\0"} /ppd/{sub(".","",$NF); print $NF}')
	fi
done

if test -z "$Ppd_File"
then
	PPDs=( /usr/share/cups/model/**/*brother*@($printerName|$modelName)*.ppd )
fi
case ${#PPDs[*]} in
	0) echo "no ppd"
		err+="1"
		;;
	1)  echo one ppd
		Ppd_File=${PPDs[0]}
		;;
	*)  err+="1"
		echo "plus d'un fichier ppd trouvé , utilisation du 1er."
		Ppd_File=${PPDs[0]}
		;;
esac

cp /etc/cups/printers.conf.O /etc/cups/printers.conf "$tmpDir"
systemctl restart cups
sleep 1

if test -n "$IP"
then
	lpadmin -p "$modelName" -E -v "lpd://$IP/binary_p1" -P "$Ppd_File"
else
	lpadmin -p "$modelName" -E -v 'usb://dev/usb/lp0' -P "$Ppd_File"
fi

#############################
 # configuration du scanner #
#############################
if test -z "$IP"
then #USB
	if grep -q "ATTRS{idVendor}==\"04f9\", ENV{libsane_matched}=\"yes\"" "$Udev_Rules"
	then
		echo " - Règle udev deja presente dans le fichier $Udev_Rules"
	else
		sed -i "/LABEL=\"libsane_usb_rules_begin\"/a\
			\n# Brother\nATTRS{idVendor}==\"04f9\", ENV{libsane_matched}=\"yes\"" "$Udev_Rules"
		udevadm control --reload-rules
	fi
else #network
		for saneConf in /usr/bin/brsaneconfig{,{2..5}}
		do
			test -x "$saneConf" && cmd=$saneConf
		done
		if test -z "$cmd"
		then
			errQuit "no brsaneconfig found."
		elif test "$cmd" = '/usr/bin/brsaneconfig4'
		then
			sed -i '/Support Model/a\
				0x029a, 117, 1, "MFC-8690DW", 133, 4\
				0x0279, 14, 2, "DCP-J525W"\
				0x027b, 13, 2, "DCP-J725DW"\
				0x027d, 13, 2, "DCP-J925DW"\
				0x027f, 14, 1, "MFC-J280W"\
				0x028f, 13, 1, "MFC-J425W"\
				0x0281, 13, 1, "MFC-J430W"\
				0x0280, 13, 1, "MFC-J435W"\
				0x0282, 13, 1, "MFC-J625DW"\
				0x0283, 13, 1, "MFC-J825DW"\
				0x028d, 13, 1, "MFC-J835DW"' /opt/brother/scanner/brscan4/Brsane4.ini
		fi
		$cmd -a name=SCANNER model="$modelName" ip="$IP"
fi

if test -d "$libDir"
then
	case $cmd in
		/usr/bin/brsaneconfig)
			cd "$libDir" || exit;
			cp --force /usr/lib64/libbrcolm.so.1.0.1 .
			ln -sf libbrcolm.so.1.0.1 libbrcolm.so.1
			ln -sf libbrcolm.so.1 libbrcolm.so
			cp --force /usr/lib64/libbrscandec.so.1.0.0 "$libDir"
			ln -sf libbrscandec.so.1.0.0 libbrscandec.so.1
			ln -sf libbrscandec.so.1 libbrscandec.so
			cd "$libDir"/sane || exit
			cp --force /usr/lib64/sane/libsane-brother.so.1.0.7 .
			ln -sf libsane-brother.so.1.0.7 libsane-brother.so.1
			ln -sf libsane-brother.so.1 libsane-brother.so
			;;
		/usr/bin/brsaneconfig2)
			cd "$libDir" || exit
			cp --force /usr/lib64/libbrscandec2.so.1.0.0 .
			ln -sf libbrscandec2.so.1.0.0 libbrscandec2.so.1
			ln -sf libbrscandec2.so.1 libbrscandec2.so
			cp --force /usr/lib64/libbrcolm2.so.1.0.1 .
			ln -sf libbrcolm2.so.1.0.1 libbrcolm2.so.1
			ln -sf libbrcolm2.so.1 libbrcolm2.so
			cd "$libDir"/sane || exit
			cp --force /usr/lib64/sane/libsane-brother2.so.1.0.7 .
			ln -sf libsane-brother2.so.1.0.7 libsane-brother2.so.1
			ln -sf libsane-brother2.so.1 libsane-brother2.so
			;;
		/usr/bin/brsaneconfig3)
			cd "$libDir" || exit
			cp --force /usr/lib64/libbrscandec3.so.1.0.0 .
			ln -sf libbrscandec3.so.1.0.0 libbrscandec3.so.1
			ln -sf libbrscandec3.so.1 libbrscandec3.so
			cd "$libDir"/sane || exit
			cp --force /usr/lib64/sane/libsane-brother3.so.1.0.7 .
			ln -sf libsane-brother3.so.1.0.7 libsane-brother3.so.1
			ln -sf libsane-brother3.so.1 libsane-brother3.so
			;;
		/usr/bin/brsaneconfig4)
			cd "$libDir"/sane || exit
			ln -sf libsane-brother4.so.1.0.7 libsane-brother4.so.1
			ln -sf libsane-brother4.so.1 libsane-brother4.so
			;;
		/usr/bin/brsaneconfig5)
			cd "$libDir"/sane || exit
			ln -sf /usr/lib/x86_64-linux-gnu/sane/libsane-brother5.so.1.0 libsane-brother5.so.1
			ln -sf /usr/lib/x86_64-linux-gnu/sane/libsane-brother5.so.1.0.7 libsane-brother5.so.1.0
			ln -sf /opt/brother/scanner/brscan5/libsane-brother5.so.1.0.7 libsane-brother5.so.1.0.7
			;;
	esac
fi
