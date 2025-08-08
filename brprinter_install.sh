#!/bin/bash
# Script d'installation pour imprimantes Brother
# ecrit par @demonipuch .
# re-ecrit par ubuntu team : https://forum.ubuntu-fr.org/viewtopic.php?id=2091835&p=2

# todo :
# verification de l' installation des dependances / paquets sur version ubuntu 24.04 et superieures
# multiarch-support , libsane etc ...

. /lib/lsb/init-functions

valid_ip() {
    IFS='.' read -ra ip <<< "$1"
    [[ ${ip[0]} -gt 0 ]] && [[ ${ip[0]} -le 255 ]] && [[ ${ip[1]} -ge 0 ]] && [[ ${ip[1]} -le 255 ]] && [[ ${ip[2]} -ge 0 ]] && [[ ${ip[2]} -le 255 ]] && [[ ${ip[3]} -ge 0 ]] && [[ ${ip[3]} -le 255 ]]
}

control_ip() {
	if [[ -n "$IP" ]]; then
		if ( (valid_ip "$IP") ); then
			if ping -c2 "$IP"; then log_action_end_msg 0
			else
				log_action_begin_msg "Votre IP ne permet pas de joindre l ' hote. Eclairer votre imprimante si celle-ci est eteinte , ou bien , corriger votre adresse IP."
				unset IP
				log_action_end_msg 1
			fi
		else
			log_action_begin_msg "L ' adresse IP que vous avez entrée est incorrecte"
			unset IP
			log_action_end_msg 1
		fi
	fi
}

install_pkg() {
	for pkg do
		log_action_begin_msg "Recherche du paquet : ' $pkg ' sur votre système"
		if dpkg-query -f '${binary:Package}\n' -W "$pkg" &>/dev/null; then
			echo " - Paquet ' $pkg ' deja installé" &>> "$Logfile"
			log_action_end_msg 0
		else
			echo " - Paquet ' $pkg ' non installé" &>> "$Logfile"
			log_action_end_msg 1
			log_action_begin_msg "Installation du paquet : ' $pkg ' sur votre système"
			apt-get install -qq "$pkg" &>> "$Logfile"
			log_action_end_msg $?
		fi
	done
}

verif_rep() {
	for dir do
	log_action_begin_msg "Recherche du dossier ' $dir ' sur votre système"
		if [[ -d "$dir" ]]; then log_action_end_msg 0;
		else
			log_action_end_msg 1
			log_action_begin_msg "Creation du dossier ' $dir '"
			mkdir -pv "$dir" &>> "$Logfile"
			log_action_end_msg $?
		fi
	done
}

verif_lien() { # utilisation : # verif_lien "lien" "cible" . affichage de ls -l ' lien : /etc/init.d/lpd ~> /etc/init.d/cups : cible '
	# Musique -> /datas/iznobe/Musique
	# lien -> cible

	# ln -s /datas/$USER/{Bureau,Documents,Images,Scripts,Ressources,Photos,Musique,Téléchargements,Vidéos_famille}  /home/$USER/
	# ln -s cible    lien
	lien=$1
	cible=$2

	log_action_begin_msg "Recherche du lien ' $lien ' sur votre système"
	if ! test -L "$lien"; then
		log_action_end_msg 1
		log_action_begin_msg "Creation du lien ' $lien '"
		ln -s "$cible" "$lien" &>> "$Logfile"
		log_action_end_msg $?
	else log_action_end_msg $?;
	fi
}

Model_Name="$1"
if [ -n "$2" ]; then
	if [ "$2" = "1" ]; then Connection="Réseau"; elif [ "$2" = "0" ]; then Connection="USB"; fi
fi
IP="$3"
User="$SUDO_USER"
Temp_Dir="/tmp/packages"
Codename="$(lsb_release -cs)"
Arch="$(uname -m)"
date=$(date +%F_%T)
Logfile="/home/$User/brprinter-installer.log"
#Logfile="/home/$User/brprinter-installer.$date.log"
Lib_Dir="/usr/lib/$Arch-linux-gnu"
Url_Info="http://www.brother.com/pub/bsc/linux/infs"
# Packages :
# https://download.brother.com/pub/com/linux/linux/packages/
Url_Pkg="http://www.brother.com/pub/bsc/linux/packages"

Udev_Rules="/lib/udev/rules.d/60-libsane1.rules"
Udev_Deb_Name="brother-udev-rule-type1-1.0.2-0.all.deb"
Udev_Deb_Url="http://download.brother.com/welcome/dlf006654/"
Scankey_Drv_Deb_Name="brscan-skey-0.3.4-0.amd64.deb"

Blue="\\033[1;34m"
Red="\\033[1;31m"
Resetcolor="\\033[0;0m"

declare -A printer

#########################
# PRÉPARATION DU SCRIPT #
#########################
do_init_script() {
	# On vérifie qu'on lance le script en root
	if ((EUID)); then
		echo -e "$Red Vous devez lancer ce script en tant que root : sudo bash $0 $Resetcolor"; exit 0;fi
	if [[ $Arch != "i386" ]] && [[ $Arch != "i686" ]] && [[ $Arch != "x86_64" ]] ; then
		echo " - Architecture : $Arch" &>> "$Logfile"
		echo -e "$Red Achitecture $Arch non prise en charge ! script interrompu. $Resetcolor"
		log_action_end_msg 1
		exit 1
	fi
	# Si un log existe déjà on le renomme
	if [[ -f $Logfile ]]; then mv "$Logfile" "$Logfile".old; fi

	# Si le premier argument est vide on demande le modèle de l'imprimante
	while [[ -z "$Model_Name" ]]; do read -rp "Entrez votre modèle d' imprimante : " Model_Name;done
	Model_Name=${Model_Name^^}
	# Si le 2eme argument est vide on demande comment est connectée l'imprimante
	while [[ -z "$Connection" ]]; do
		read -rp "Sélectionner le type de connectivité : [0] USB - [1] Réseau , votre choix : "
		case $REPLY in
			0)
				Connection="USB"
			;;
			1)
				Connection="Réseau"
				echo -e "$Red Vous devez d' abord vous assurer que votre imprimante possède une adresse IP fixe. $Resetcolor"
				echo -e "$Red Veuillez consulter le manuel de votre imprimante pour plus de détails : http://support.brother.com/g/b/productsearch.aspx?c=fr&lang=fr&content=ml $Resetcolor"
			;;
		esac
	done

	# Si le 3eme argument est vide on demande l' IP de l'imprimante
	if [[ "$Connection" == "Réseau" ]]; then control_ip "$IP";
		while [[ -z "$IP" ]]; do
			read -rp "Entrez l'adresse IP de votre imprimante : " IP
			control_ip "$IP"
	    done
	fi
	# On transforme le nom de l'imprimante ( enleve le " - " )
	Printer_Name="${Model_Name//-/}"
	# On construit l'URL du fichier contenant les informations
	Printer_Url_Info="$Url_Info/$Printer_Name"
	# On vérifie l'URL
	Printer_dl_url="https://support.brother.com/g/b/downloadtop.aspx?c=fr&lang=fr&prod=""$Printer_Name""_us_eu_as"

	if ! wget -q --spider "$Printer_Url_Info"; then
		log_action_end_msg 1
		echo " - Aucun pilote trouvé" &>> "$Logfile"
		echo -e "$Red Aucun pilote trouvé. Veuillez verifier votre connexion internet .
		Veuillez vérifier le modèle de votre imprimante ou
		visitez la page suivante : $Printer_dl_url
		afin de télécharger les pilotes et les installer manuellement. $Resetcolor"
		exit 2
	fi
	# On vérifie que le fichier fournit les informations
	# ???????? pas compris a quoi sert ce controle , ni quelles infos il est censé recuperé
	Lnk=$(wget -q "$Printer_Url_Info" -O - | grep LNK - | cut -d= -f2)
	if [[ "$Lnk" ]]; then Printer_Url_Info="$Url_Info/$Lnk"; fi

	echo "                              $date
			# Ubuntu Codename : $Codename
			# Architecture : $Arch
			# Modèle de l'imprimante : $Model_Name
			# Type de connexion : $Connection
			# Adresse IP : $IP
			# Repertoire courant : $Temp_Dir
			# Repertoire de telechargement des pilotes : $Temp_Dir
			# Fichier d'informations : $Printer_Url_Info
			# page de telechargement des pilotes : $Printer_dl_url
			" &>> "$Logfile"
}

###############################
# VERIFICATION DES PRÉ-REQUIS #
###############################
do_check_prerequisites() {
	echo -e "$Blue Vérification des pré-requis $Resetcolor"
	echo "# Vérification des pré-requis" &>> "$Logfile"
	log_action_begin_msg "Mise à jour de la liste des paquets"
	apt-get update -qq
	log_action_end_msg $?
	# On vérifie que la liste des paquets est installée et on l'installe le cas échéant
	install_pkg "multiarch-support" "lib32stdc++6" "cups" "curl" "wget"

	# Si un pilote pour le scanner a été trouvé on vérifie que la liste des paquets est installée
	if [[ -n $Scanner_Deb ]]; then install_pkg "libusb-0.1-4:amd64" "libusb-0.1-4:i386" "sane-utils"; fi

	# On vérifie que le paquet csh est installé et on l'installe le cas échéant (uniquement pour certaines imprimantes)
	for i in DCP-110C DCP-115C DCP-117C DCP-120C DCP-310CN DCP-315CN DCP-340CW FAX-1815C FAX-1820C FAX-1835C FAX-1840C FAX-1920CN FAX-1940CN FAX-2440C MFC-210C MFC-215C MFC-3220C MFC-3240C MFC-3320CN MFC-3340CN MFC-3420C MFC-3820CN MFC-410CN MFC-420CN MFC-425CN MFC-5440CN MFC-5840CN MFC-620CN MFC-640CW MFC-820CW; do
		if [[ "$Model_Name" == "$i" ]]; then install_pkg "csh";	fi
	done
	# On vérifie que le dossier /usr/share/cups/model et /var/spool/lpd existent et on les crée le cas échéant
	verif_rep "/usr/share/cups/model" "/var/spool/lpd"

	# On vérifie que le lien symbolique /etc/init.d/lpd existe et on le crée le cas échéant (uniquement pour certaines imprimantes)
	for i in DCP-1000 DCP-1400 DCP-8020 DCP-8025D DCP-8040 DCP-8045D DCP-8060 DCP-8065DN FAX-2850 FAX-2900 FAX-3800 FAX-4100 FAX-4750e FAX-5750e HL-1030 HL-1230 HL-1240 HL-1250 HL-1270N HL-1430 HL-1440 HL-1450 HL-1470N HL-1650 HL-1670N HL-1850 HL-1870N HL-5030 HL-5040 HL-5050 HL-5070N HL-5130 HL-5140 HL-5150D HL-5170DN HL-5240 HL-5250DN HL-5270DN HL-5280DW HL-6050 HL-6050D MFC-4800 MFC-6800 MFC-8420 MFC-8440 MFC-8460N MFC-8500 MFC-8660DN MFC-8820D MFC-8840D MFC-8860DN MFC-8870DW MFC-9030 MFC-9070 MFC-9160 MFC-9180 MFC-9420CN MFC-9660 MFC-9700 MFC-9760 MFC-9800 MFC-9860 MFC-9880; do
		if [[ "$Model_Name" == "$i" ]]; then verif_lien "/etc/init.d/lpd" "/etc/init.d/cups"; # verif_lien "lien" "cible" 'lien : /etc/init.d/lpd ~> /etc/init.d/cups : cible'
			# On crée un lien symbolique vers cups.service si systemd est utilisé : ln -s /lib/systemd/system/cups.service /lib/systemd/system/lpd.service
			if [[ -L /sbin/init ]]; then
				verif_lien "/lib/systemd/system/cups.service" "/lib/systemd/system/lpd.service" # ' lien : /lib/systemd/system/cups.service ~> /lib/systemd/system/lpd.service: cible'
				systemd daemon-reload
			fi
		fi
	done
	echo " " &>> "$Logfile"
}

##############################
# TÉLÉCHARGEMENT DES PILOTES #
##############################
do_download_drivers() {
    # On crée le dossier de téléchargement des paquets si il n' existe pas deja
    verif_rep "$Temp_Dir"

    echo -e "$Blue Recherche des pilotes $Resetcolor"
    echo "# Recherche des pilotes de l'imprimante" &>> "$Logfile"
    log_action_begin_msg "Recherche des pilotes pour l' imprimante"

    Printer_Info="$Temp_Dir/Printer_Info.html"
    wget -q "$Printer_Url_Info" -O "$Printer_Info"
    printer=(
        [prn_lpd]="$(grep PRN_LPD_DEB "$Printer_Info"  | cut -d= -f2)"
        [prn_cups]="$(grep PRN_CUP_DEB "$Printer_Info" | cut -d= -f2)"
        [prn_drv]="$(grep PRN_DRV_DEB "$Printer_Info"  | cut -d= -f2)"
    )
    log_action_end_msg 0

    Scanner_Deb=$(grep SCANNER_DRV "$Printer_Info" | cut -d= -f2)
    if test -n "$Scanner_Deb"; then
    	printer+=(
    		[udev_rules]="$Udev_Deb_Name"
    	)
        echo "# Recherche des pilotes du scanner" &>> "$Logfile"
        log_action_begin_msg "Recherche des pilotes pour le scanner"

        Scankey_Deb=$(grep SCANKEY_DRV "$Printer_Info" | cut -d= -f2)

        Scanner_Url_Info="$Url_Info/$Scanner_Deb.lnk"
        Scankey_Url_Info="$Url_Info/$Scankey_Deb.lnk"
        echo " - Scanner infos :
        	$Scanner_Url_Info
        	$Scankey_Url_Info" &>> "$Logfile"

        Scanner_Info="$Temp_Dir/Scanner_Url_Info.html"
        wget -q "$Scanner_Url_Info" -O "$Scanner_Info"
        Scankey_Info="$Temp_Dir/Scankey_Url_Info.html"
		wget -q "$Scankey_Url_Info" -O "$Scankey_Info"

        # On récupère les pilotes du scanner en fonctionnement de l'architecture du système (32-bits ou 64-bits)
        case "$Arch" in
            i386|i686)
                printer+=(
                    [scanner_drv]="$(grep DEB32 "$Scanner_Info" | cut -d= -f2)"
                    [scanKey_drv]="$(grep DEB32 "$Scankey_Info" | cut -d= -f2)"
                )
                log_action_end_msg 0
                ;;
            x86_64)
                printer+=(
                    [scanner_drv]="$(grep DEB64 "$Scanner_Info" | cut -d= -f2)"
                    [scanKey_drv]="$(grep DEB64 "$Scankey_Info" | cut -d= -f2)"
                )
                # pour ubuntu 24.04 et superieurs
                if test "${printer[scanKey_drv]}" = "brscan-skey-0.3.2-0.amd64.deb"; then printer[scanKey_drv]="$Scankey_Drv_Deb_Name";fi
                log_action_end_msg 0
                ;;
            *)
				Arch="inconnue"
                ;;
        esac
 #       if test $Arch=="inconnue"; then
#			echo " - Architecture : $Arch" &>> "$Logfile"
#			echo -e "$Red Achitecture $Arch non prise en charge ! script interrompu. $Resetcolor"
#			log_action_end_msg 1
#			exit 2
#		fi
    else
        echo "$Red Pas de scanner détecté $Resetcolor"
        echo " - Pas de scanner détecté" &>> "$Logfile"
        log_action_end_msg 1
    fi

    echo -e "$Blue Téléchargement des pilotes $Resetcolor"
    for pkg in "${printer[@]}"; do
        # On ajoute la liste des pilotes trouvés au fichier de journalisation
        if test -n "$pkg"; then
            echo " - Paquet trouvé : $pkg" &>> "$Logfile"
            # On télécharge les pilotes trouvés si ils ne le sont pas deja
            if [[ ! -f "$Temp_Dir"/"$pkg" ]]; then
                Url_Deb="$Url_Pkg"/"$pkg"
                # le paquet 'udev-rules' est situé a un autre emplacement
                if test "$pkg" == "${printer[udev_rules]}"; then Url_Deb="$Udev_Deb_Url"/"$pkg"; fi
                echo " - Téléchargement du paquet : $pkg" &>> "$Logfile"
                log_action_begin_msg "Téléchargement du paquet : $pkg"
                wget -cP "$Temp_Dir" "$Url_Deb" &>> "$Logfile"
                log_action_end_msg $?
            else
                log_action_begin_msg "Le paquet : $pkg a deja été telechargé"
                log_action_end_msg 0
            fi
        fi
    done
    echo " " &>> "$Logfile"
}
############################
# INSTALLATION DES PILOTES #
############################
do_install_drivers() {
	echo -e "$Blue Installation des pilotes $Resetcolor"
	echo "# Installation des pilotes" &>> "$Logfile"
	for pkg in "${printer[@]}"; do
		if [[ -n "$pkg" ]] && [[ -f "$Temp_Dir/$pkg" ]]; then
			log_action_begin_msg "Installation du paquet : $pkg"
			echo " - Installation par 'dpkg' du paquet : $pkg" &>> "$Logfile"
			dpkg -i --force-all "$Temp_Dir/$pkg" &>> "$Logfile"
			log_action_end_msg $?
		fi
	done
	echo " " &>> "$Logfile"
}

#################################
# CONFIGURATION DE L'IMPRIMANTE #
#################################
do_configure_printer() {
	echo -e "$Blue Configuration de l'imprimante $Resetcolor"
	echo "# Configuration de l'imprimante" &>> "$Logfile"
	for pkg in "${printer[prn_cups]}" "${printer[prn_drv]}"; do
		if [[ -n "$pkg" ]] && [[ -f "$Temp_Dir/$pkg" ]]; then
			Ppd_File=$(dpkg --contents "$Temp_Dir/$pkg" | grep ppd | awk '{print $6}' | sed 's/^.//g')
		fi
	done
	if [[ -z "$Ppd_File" ]]; then
		for file in $(find /usr/share/cups/model -type f); do
			if grep -qi Brother "$file" | grep -E "$Model_Name|$Printer_Name"; then
				Ppd_File="$file"
			fi
		done
	fi
	log_action_begin_msg "Recherche d'un fichier PPD sur votre système"
	echo " - Recherche d'un fichier PPD" &>> "$Logfile"
	if [[ -n "$Ppd_File" ]]; then
		echo " - Fichier PPD : ' $Ppd_File ' trouvé" &>> "$Logfile"
		log_action_end_msg 0;
	else
		echo " - Fichier PPD : $Ppd_File non trouvé !" &>> "$Logfile"
		log_action_end_msg 1
	fi
	# On ajoute la nouvelle imprimante
	log_action_begin_msg "Ajout de l'imprimante $Model_Name"
	{
		echo " - Ajout de l'imprimante $Model_Name"
		echo " - Backup du fichier /etc/cups/printers.conf.O"
		cp /etc/cups/printers.conf.O "$Temp_Dir"
		echo " - Arret du service CUPS"
		echo " - Restauration du fichier printers.conf"
		systemctl stop cups
		cp "$Temp_Dir"/printers.conf.O /etc/cups/printers.conf
		echo " - Redémarrage du service CUPS"
		systemctl restart cups
		sleep 1
	} &>> "$Logfile"
	case "$Connection" in
	"USB")
		lpadmin -p "$Model_Name" -E -v usb://dev/usb/lp0 -P "$Ppd_File" &>> "$Logfile"
	;;
	"Réseau")
		lpadmin -p "$Model_Name" -E -v lpd://"$IP"/binary_p1 -P "$Ppd_File" &>> "$Logfile"
	;;
	esac
	log_action_end_msg $?
	{
		cp "$Temp_Dir"/printers.conf.O /etc/cups/printers.conf.O
		echo " - Restauration du fichier printers.conf.O"
		echo ""
	} &>> "$Logfile"
}

############################
# CONFIGURATION DU SCANNER #
############################
do_configure_scanner() {
	echo -e "$Blue Configuration du scanner $Resetcolor"
	echo "# Configuration du scanner" &>> "$Logfile"
	if [[ -n "$Scanner_Deb" ]]; then
		if [[ $Connection == "USB" ]]; then
			log_action_begin_msg "Configuration du scanner USB"
			echo " - Configuration du scanner USB" &>> "$Logfile"
			# On ajoute une entrée au fichier /lib/udev/rules.d/60-libsane1.rules
			if grep -q "ATTRS{idVendor}==\"04f9\", ENV{libsane_matched}=\"yes\"" "$Udev_Rules"; then
				echo " - Règle udev deja presente dans le fichier $Udev_Rules" &>> "$Logfile"
			else
				# ?????????? n ' ajoute pas la regle correctement .
				sed -i "/LABEL=\"libsane_usb_rules_begin\"/a\
				\n# Brother\nATTRS{idVendor}==\"04f9\", ENV{libsane_matched}=\"yes\"" "$Udev_Rules"
				echo " - Règle udev ajoutée dans le fichier $Udev_Rules" &>> "$Logfile"
				# On recharge les règles udev
				# udevadm control --reload
				udevadm control --reload-rules
			fi
		elif [[ $Connection == "Réseau" ]]; then
			log_action_begin_msg "Configuration du scanner réseau"
			echo " - Configuration du scanner réseau" &>> "$Logfile"
			if [[ -x /usr/bin/brsaneconfig ]]; then
				brsaneconfig -a name="SCANNER" model="$Model_Name" ip="$IP" &>> "$Logfile"
				log_action_end_msg $?
			elif [[ -x /usr/bin/brsaneconfig2 ]]; then
				brsaneconfig2 -a name="SCANNER" model="$Model_Name" ip="$IP" &>> "$Logfile"
				log_action_end_msg $?
			elif [[ -x /usr/bin/brsaneconfig3 ]]; then
				brsaneconfig3 -a name="SCANNER" model="$Model_Name" ip="$IP" &>> "$Logfile"
				log_action_end_msg $?
			elif [[ -x /usr/bin/brsaneconfig4 ]]; then
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
				brsaneconfig4 -a name=SCANNER model="$Model_Name" ip="$IP" &>> "$Logfile"
				log_action_end_msg $?
			elif [[ -x /usr/bin/brsaneconfig5 ]]; then
				# ??????????????
				brsaneconfig5 -a name=SCANNER model="$Model_Name" ip="$IP" &>> "$Logfile"
				log_action_end_msg $?
			fi
		fi
		# On copie les bibliotheques
		if [[ "$Arch" == "x86_64" ]] && [[ -d $Lib_Dir ]]; then
			if [[ -e /usr/bin/brsaneconfig ]]; then cd "$Lib_Dir" || exit;
				log_action_begin_msg "Copie des bibliotheques nécessaires brsaneconfig"
				echo " - Copie des bibliotheques nécessaires brsaneconfig" &>> "$Logfile"
				cp --force /usr/lib64/libbrcolm.so.1.0.1 .
				ln -sf libbrcolm.so.1.0.1 libbrcolm.so.1
				ln -sf libbrcolm.so.1 libbrcolm.so
				cp --force /usr/lib64/libbrscandec.so.1.0.0 "$Lib_Dir"
				ln -sf libbrscandec.so.1.0.0 libbrscandec.so.1
				ln -sf libbrscandec.so.1 libbrscandec.so
				cd "$Lib_Dir"/sane || exit
				cp --force /usr/lib64/sane/libsane-brother.so.1.0.7 .
				ln -sf libsane-brother.so.1.0.7 libsane-brother.so.1
				ln -sf libsane-brother.so.1 libsane-brother.so
				log_action_end_msg 0
			elif [[ -e /usr/bin/brsaneconfig2 ]]; then cd "$Lib_Dir" || exit
				log_action_begin_msg "Copie des bibliotheques nécessaires brsaneconfig2"
				echo " - Copie des bibliotheques nécessaires brsaneconfig2" &>> "$Logfile"
				cp --force /usr/lib64/libbrscandec2.so.1.0.0 .
				ln -sf libbrscandec2.so.1.0.0 libbrscandec2.so.1
				ln -sf libbrscandec2.so.1 libbrscandec2.so
				cp --force /usr/lib64/libbrcolm2.so.1.0.1 .
				ln -sf libbrcolm2.so.1.0.1 libbrcolm2.so.1
				ln -sf libbrcolm2.so.1 libbrcolm2.so
				cd "$Lib_Dir"/sane || exit
				cp --force /usr/lib64/sane/libsane-brother2.so.1.0.7 .
				ln -sf libsane-brother2.so.1.0.7 libsane-brother2.so.1
				ln -sf libsane-brother2.so.1 libsane-brother2.so
				log_action_end_msg 0
			elif [[ -e /usr/bin/brsaneconfig3 ]]; then cd "$Lib_Dir" || exit
				log_action_begin_msg "Copie des bibliotheques nécessaires brsaneconfig3"
				echo " - Copie des bibliotheques nécessaires brsaneconfig3" &>> "$Logfile"
				cp --force /usr/lib64/libbrscandec3.so.1.0.0 .
				ln -sf libbrscandec3.so.1.0.0 libbrscandec3.so.1
				ln -sf libbrscandec3.so.1 libbrscandec3.so
				cd "$Lib_Dir"/sane || exit
				cp --force /usr/lib64/sane/libsane-brother3.so.1.0.7 .
				ln -sf libsane-brother3.so.1.0.7 libsane-brother3.so.1
				ln -sf libsane-brother3.so.1 libsane-brother3.so
				log_action_end_msg 0
			elif [[ -e /usr/bin/brsaneconfig4 ]]; then cd "$Lib_Dir"/sane || exit
				log_action_begin_msg "Copie des bibliotheques nécessaires brsaneconfig4"
				echo " - Copie des bibliotheques nécessaires brsaneconfig4" &>> "$Logfile"
				ln -sf libsane-brother4.so.1.0.7 libsane-brother4.so.1
				ln -sf libsane-brother4.so.1 libsane-brother4.so
				log_action_end_msg 0
			elif [[ -e /usr/bin/brsaneconfig5 ]]; then cd "$Lib_Dir"/sane || exit
				log_action_begin_msg "Copie des bibliotheques nécessaires brsaneconfig5"
				echo " - Copie des bibliotheques nécessaires brsaneconfig5" &>> "$Logfile"
				ln -sf /usr/lib/x86_64-linux-gnu/sane/libsane-brother5.so.1.0 libsane-brother5.so.1
				ln -sf /usr/lib/x86_64-linux-gnu/sane/libsane-brother5.so.1.0.7 libsane-brother5.so.1.0
				ln -sf /opt/brother/scanner/brscan5/libsane-brother5.so.1.0.7 libsane-brother5.so.1.0.7
				log_action_end_msg 0
			else
				log_action_end_msg 1
				echo -e "$Red No config binary found. $Resetcolor"
			fi
		fi
	fi
	echo " " &>> "$Logfile"
}

#################
# FIN DU SCRIPT #
#################
do_clean() {
	cd || exit
	# On réattribue les droits des dossiers/fichiers crées à l'utilisateur
	chown -R "$User": "$Temp_Dir" "$Logfile"
	echo -e "$Blue Configuration de votre imprimante Brother $Model_Name terminée. Bye :D $Resetcolor"
	echo "# Configuration imprimante terminée" &>> "$Logfile"
	exit 0
}

do_init_script
do_check_prerequisites
do_download_drivers
do_install_drivers
do_configure_printer
do_configure_scanner
do_clean
