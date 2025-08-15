#!/bin/bash
# Script d'installation pour imprimantes Brother
# ecrit par @demonipuch .
# re-ecrit par ubuntu team : https://forum.ubuntu-fr.org/viewtopic.php?id=2091835&p=2

# todo :
# verification de l' installation des dependances / paquets sur version ubuntu 24.04 et superieures
# multiarch-support , libsane etc ...


if test -f /lib/lsb/init-functions; then . /lib/lsb/init-functions;fi
shopt -s nullglob globstar extglob

############################
# définitions de variables #
############################
User="$SUDO_USER"
Codename="$(lsb_release -cs)"
Arch="$(uname -m)"
date=$(date +%F_%T)
Temp_Dir="/tmp/packages"
Lib_Dir="/usr/lib/""$Arch""-linux-gnu"
Logfile="/home/""$User""/brprinter_install.log"
#Logfile="/home/$User/brprinter_install.$date.log"

declare -A printer

###################
# LES FONCTIONS : #
###################
control_ip() {
	log "Controle de l' adresse IP entrée"
	IFS='.' read -ra ip <<< "$1"
	if (( ${#ip[*]} == 4 )); then
	    for i in "${ip[@]}"; do
	        ((n++ ? i >=0 && i<=255 : i>0 && i<=255))
	    done
		if ping -qc2 "$1"; then
			IP="$1"
			log_action_end_msg 0
		else
			log "Votre IP ne permet pas de joindre l ' hote. Eclairer votre imprimante si celle-ci est eteinte , ou bien , corriger votre adresse IP." "Red"
			unset IP
			log_action_end_msg 1
		fi
	else
		log "L ' adresse IP que vous avez entrée est incorrecte" "Red"
		unset IP
		log_action_end_msg 1
	fi
}
install_pkg() {
	for pkg do
		log "Recherche du paquet : ' $pkg ' sur votre système"
		if dpkg-query -f '${binary:Package}\n' -W "$pkg" &>/dev/null; then
			echo " - Paquet ' $pkg ' deja installé" &>> "$Logfile"
			log_action_end_msg 0
		else
			echo " - Paquet ' $pkg ' non installé" &>> "$Logfile"
			log_action_end_msg 1
			log "Installation du paquet : ' $pkg ' sur votre système"
			apt-get install -qq "$pkg" &>> "$Logfile"
			log_action_end_msg $?
		fi
	done
}
verif_rep() {
	for dir do
	log "Recherche du dossier ' $dir ' sur votre système"
		if [[ -d "$dir" ]]; then log_action_end_msg 0;
		else
			log_action_end_msg 1
			log "Creation du dossier ' $dir '"
			mkdir -pv "$dir" &>> "$Logfile"
			log_action_end_msg $?
		fi
	done
}
verif_lien() { # utilisation : # verif_lien "lien" "cible" . affichage de ls -l ' lien : /etc/init.d/lpd ~> /etc/init.d/cups : cible '
	# Musique -> /datas/iznobe/Musique
	# lien -> cible
	lien=$1
	cible=$2

	log "Recherche du lien ' $lien ' sur votre système"
	if ! test -L "$lien"; then
		log_action_end_msg 1
		log "Creation du lien ' $lien '"
		ln -s "$cible" "$lien" &>> "$Logfile"
		log_action_end_msg $?
	else log_action_end_msg $?;
	fi
}
log() {
	message="$1"
	if test -z "$2"; then
		log_action_begin_msg "$message"
		echo -e " - $message" &>> "$Logfile"
	else
		if test "$2" == "Blue"; then color="\\033[1;34m";fi
		if test "$2" == "Red"; then color="\\033[1;31m";fi
			echo -e "$color $message \\033[0;0m" # Resetcolor
			echo -e "
			# $message" &>> "$Logfile"
	fi
}

#################
 # infos Brother
#################
# ancienne adresse d' obtention des infos :
#Url_Info="http://www.brother.com/pub/bsc/linux/infs"
# nouvelle adresse :
Url_Info="https://download.brother.com/pub/com/linux/linux/infs"
# FULL_PATH="https://download.brother.com/pub/com/linux/linux/infs/$Model_Name
# Packages :
# FULL_PATH="https://download.brother.com/pub/com/linux/linux/packages/$Model_Name
Url_Pkg="https://download.brother.com/pub/com/linux/linux/packages"
Url_Pkg2="http://www.brother.com/pub/bsc/linux/packages" # ancienne adresse d' obtention des paquets

Udev_Rules="/lib/udev/rules.d/60-libsane1.rules"
Udev_Deb_Name="brother-udev-rule-type1-1.0.2-0.all.deb"
Udev_Deb_Url="http://download.brother.com/welcome/dlf006654/"
Scankey_Drv_Deb_Name="brscan-skey-0.3.4-0.amd64.deb"

#########################
# PRÉPARATION DU SCRIPT #
#########################
# controles pour que le script s ' execute dans les bonnes conditions
if test -f "$Logfile"; then
	Old_Date="$(head -n1 "$Logfile")"
	mv "$Logfile" "$Logfile"."$Old_Date".log
fi
echo "$date" >> "$Logfile" # indispensable pour la rotation du log .
if test "$SHELL" != "/bin/bash"; then
	log "shell incompatible ! executez ce script avec bash . script interrompu." "Red"
	exit 1
fi
# On vérifie qu'on lance le script en root
if ((EUID)); then
	log "Vous devez lancer ce script en tant que root : sudo bash $0" "Red"
	exit 1
fi
if test "$Arch" != "x86_64"; then
	log "Achitecture $Arch non prise en charge ! script interrompu." "Red"
	exit 1
fi
# on verifie la connection au serveur
if ! nc -z -w5 'brother.com' 80; then
	log "serveur brother injoignable ! script interrompu." "Red"
	log "Veuillez verifier votre connexion internet." "Red"
	exit 1
fi
# gestion des arguments
Model_Name="$1"
# Si le premier argument est vide on demande le modèle de l'imprimante
while [[ -z "$Model_Name" ]]; do read -rp "Entrez votre modèle d' imprimante : " Model_Name;done
Model_Name=${Model_Name^^}

if test -n "$2"; then
 	if control_ip "$2"; then Connection="Réseau";fi
fi
# Si le 2eme argument est vide on demande comment est connectée l'imprimante
while [[ -z "$Connection" ]]; do
	read -rp "Sélectionner le type de connectivité : [0] USB - [1] Réseau , votre choix : "
	case $REPLY in
		0)
			Connection="USB"
		;;
		1)
			Connection="Réseau"
			log "Vous devez d' abord vous assurer que votre imprimante possède une adresse IP fixe." "Red"
			log "Veuillez consulter le manuel de votre imprimante pour plus de détails : http://support.brother.com/g/b/productsearch.aspx?c=fr&lang=fr&content=ml" "Red"
		;;
	esac
done
# Si connection == reseau on demande l' IP de l'imprimante ou si elle a étée entrée en tant qu' argument .
if [[ "$Connection" == "Réseau" ]]; then
	while [[ -z "$IP" ]]; do
		read -rp "Entrez l'adresse IP de votre imprimante : " IP
    done
    control_ip "$IP"
fi
# On transforme le nom de l'imprimante ( enleve le " - " )
Printer_Name="${Model_Name//-/}"
# On construit l'URL du fichier contenant les informations
Printer_Url_Info="$Url_Info/$Printer_Name"
Printer_dl_url="https://support.brother.com/g/b/downloadtop.aspx?c=fr&lang=fr&prod=""$Printer_Name""_us_eu_as"
# resumé pour logfile
log "
		# Ubuntu Codename : $Codename
		# Architecture : $Arch
		# Modèle de l'imprimante : $Model_Name
		# Type de connexion : $Connection
		# Adresse IP : $IP
		# Repertoire courant : $Temp_Dir
		# Repertoire de telechargement des pilotes : $Temp_Dir
		# Fichier d'informations : $Printer_Url_Info
		# page de telechargement des pilotes : $Printer_dl_url" "Blue"
log "initialisation du script." "Blue"
# on cree le repertoire temporaire de travail.
verif_rep "$Temp_Dir"
# On vérifie l'URL
Printer_Info="$Temp_Dir/Printer_Info.html"
log "Obtention des infos de l' imprimante"
wget -q "$Printer_Url_Info" -O "$Printer_Info"
#while IFS='=' read -r k v; do printer[$k]=$v; done < <(wget -qO - "$Printer_Url_Info" | sed '/\(]\|rpm\|=\)$/d')

log_action_end_msg $?
# On vérifie que le fichier fournit les informations
log "Vérification du fichier obtenu"
#if test "${printer[PRINTERNAME]}" == "$Printer_Name"; then log_action_end_msg 0
if test "$(grep PRINTERNAME "$Printer_Info" | cut -d= -f2)" == "$Printer_Name"; then log_action_end_msg 0
	else
		log_action_end_msg 1
		log "Aucun pilote trouvé. Veuillez vérifier le modèle de votre imprimante ou
		visitez la page suivante : $Printer_dl_url
		afin de télécharger les pilotes et les installer manuellement." "Red"
		exit 2
fi
# ???????? pas compris a quoi sert ce controle , ni quelles infos il est censé recuperé . peut etre certaines URL comporte des liens vers d' autres pages
#if test -n "${printer[LNK]}"; then Printer_Url_Info="$Url_Info/${printer[LNK]}";log "LNK = ${printer[LNK]}" "Red";fi
Lnk="$(grep LNK "$Printer_Info" | cut -d= -f2)"
if test -n "$Lnk"; then Printer_Url_Info="$Url_Info/$Lnk";log "LNK = $Lnk" "Red";fi


###############################
# VERIFICATION DES PRÉ-REQUIS #
###############################
do_check_prerequisites() {
	log "Vérification des pré-requis" "Blue"
	log "Mise à jour de la liste des paquets"
	apt-get update -qq
	log_action_end_msg $?
	# On vérifie que la liste des paquets est installée et on l'installe le cas échéant
	log "installation des paquets requis"
	if ! install_pkg "multiarch-support" "lib32stdc++6" "cups" "curl" "wget" "gawk"; then
		log "impossible d' installer les paquets indispensables" "Red"
		exit 4
	fi

	# Si un pilote pour le scanner a été trouvé on vérifie que la liste des paquets est installée
	if [[ -n $Scanner_Deb ]]; then install_pkg "libusb-0.1-4:amd64" "libusb-0.1-4:i386" "sane-utils"; fi

	# On vérifie que le paquet csh est installé et on l'installe le cas échéant (uniquement pour certaines imprimantes)
	for i in DCP-110C DCP-115C DCP-117C DCP-120C DCP-310CN DCP-315CN DCP-340CW FAX-1815C FAX-1820C FAX-1835C FAX-1840C FAX-1920CN FAX-1940CN FAX-2440C MFC-210C MFC-215C MFC-3220C MFC-3240C MFC-3320CN MFC-3340CN MFC-3420C MFC-3820CN MFC-410CN MFC-420CN MFC-425CN MFC-5440CN MFC-5840CN MFC-620CN MFC-640CW MFC-820CW; do
		if [[ "$Model_Name" == "$i" ]]; then install_pkg "csh";	fi
	done
	# On vérifie que le dossier de téléchargement temporaire et /usr/share/cups/model et /var/spool/lpd existent et on les crée le cas échéant
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
	echo "" &>> "$Logfile"
}

##############################
# TÉLÉCHARGEMENT DES PILOTES #
##############################
do_download_drivers() {
    log "Recherche des pilotes" "Blue"
    log "Recherche des pilotes pour l' imprimante"
    printer=(
        [prn_lpd]="$(grep PRN_LPD_DEB "$Printer_Info"  | cut -d= -f2)"
        [prn_cups]="$(grep PRN_CUP_DEB "$Printer_Info" | cut -d= -f2)"
        [prn_drv]="$(grep PRN_DRV_DEB "$Printer_Info"  | cut -d= -f2)"
    )
    log_action_end_msg $?

    Scanner_Deb=$(grep SCANNER_DRV "$Printer_Info" | cut -d= -f2)
    if test -n "$Scanner_Deb"; then
    	printer+=(
    		[udev_rules]="$Udev_Deb_Name"
    	)
        log "Recherche des pilotes pour le scanner"

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
                if [[ $(grep DISTRIB_RELEASE= /etc/lsb*release | cut -d= -f2 | cut -c1-2) -ge 24 ]]; then
                	if test "${printer[scanKey_drv]}" = "brscan-skey-0.3.2-0.amd64.deb"; then printer[scanKey_drv]="$Scankey_Drv_Deb_Name";fi
                fi
                log_action_end_msg 0
                ;;
                *)
					log "Architecture inconnue: $Arch" "Red"
				;;
        esac
    else
        log "Pas de scanner détecté" "Red"
        log_action_end_msg 1
    fi

    log "Téléchargement des pilotes" "Blue"
    for pkg in "${printer[@]}"; do
        # On ajoute la liste des pilotes trouvés au fichier de journalisation
        if test -n "$pkg"; then
            echo " - Paquet trouvé : $pkg" &>> "$Logfile"
            # On télécharge les pilotes trouvés si ils ne le sont pas deja
            if [[ ! -f "$Temp_Dir"/"$pkg" ]]; then
                Url_Deb="$Url_Pkg"/"$pkg"
                # le paquet 'udev-rules' est situé a un autre emplacement
                if test "$pkg" == "${printer[udev_rules]}"; then Url_Deb="$Udev_Deb_Url"/"$pkg"; fi
                log "Téléchargement du paquet : $pkg"
                wget -cP "$Temp_Dir" "$Url_Deb" &>> "$Logfile"
                if [[ ! -f "$Temp_Dir"/"$pkg" ]]; then
                  Url_Deb2="$Url_Pkg2"/"$pkg"
                  wget -cP "$Temp_Dir" "$Url_Deb2" &>> "$Logfile"
                fi
                log_action_end_msg $?
            else
                log "Le paquet : $pkg a deja été telechargé"
                log_action_end_msg 0
            fi
        fi
    done
}

############################
# INSTALLATION DES PILOTES #
############################
do_install_drivers() {
	log "Installation des pilotes" "Blue"
	for pkg in "${printer[@]}"; do
		if [[ -n "$pkg" ]] && [[ -f "$Temp_Dir/$pkg" ]]; then
			log "Installation du paquet : $pkg"
			dpkg -i --force-all "$Temp_Dir/$pkg" &>> "$Logfile"
			log_action_end_msg $?
		fi
	done
	echo "" &>> "$Logfile"
}

#################################
# CONFIGURATION DE L'IMPRIMANTE #
#################################
do_configure_printer() {
	log "Configuration de l'imprimante" "Blue"
	log "Recherche d'un fichier PPD sur votre système"
	for pkg in "${printer[prn_cups]}" "${printer[prn_drv]}"; do
		if [[ -n "$pkg" ]] && [[ -f "$Temp_Dir/$pkg" ]]; then
			Ppd_File=$(dpkg --contents "$Temp_Dir/$pkg" | gawk '/ppd/{sub(".","",$NF); print $NF}')
		fi
	done
	if test -z "$Ppd_File"; then
		for file in /usr/share/cups/model/**/brother*@($Model_Name|$Printer_Name)*.ppd; do Ppd_File="$file";done
	fi
	if test -n "$Ppd_File"; then
		log_action_end_msg 0
		echo " - Fichier PPD : ' $Ppd_File ' trouvé" &>> "$Logfile"
	else
		echo " - Fichier PPD : $Ppd_File non trouvé !" &>> "$Logfile"
		log_action_end_msg 1
	fi
	# On ajoute la nouvelle imprimante
	log "Ajout de l'imprimante $Model_Name"
	{
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
	log "Configuration du scanner" "Blue"
	if [[ -n "$Scanner_Deb" ]]; then
		if [[ $Connection == "USB" ]]; then
			log "Configuration du scanner USB"
			# On ajoute une entrée au fichier /lib/udev/rules.d/60-libsane1.rules
			if grep -q "ATTRS{idVendor}==\"04f9\", ENV{libsane_matched}=\"yes\"" "$Udev_Rules"; then
				log_action_end_msg $?
				echo " - Règle udev deja presente dans le fichier $Udev_Rules" &>> "$Logfile"

			else
				# ?????????? n ' ajoute pas la regle correctement .
				sed -i "/LABEL=\"libsane_usb_rules_begin\"/a\
				\n# Brother\nATTRS{idVendor}==\"04f9\", ENV{libsane_matched}=\"yes\"" "$Udev_Rules"
				log_action_end_msg $?
				echo " - Règle udev ajoutée dans le fichier $Udev_Rules" &>> "$Logfile"
				# On recharge les règles udev
				# udevadm control --reload
				udevadm control --reload-rules
			fi
		elif [[ $Connection == "Réseau" ]]; then
			log "Configuration du scanner réseau"
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
		# On copie les bibliotheques # Lib_Dir="/usr/lib/$Arch-linux-gnu"
		if [[ "$Arch" == "x86_64" ]] && [[ -d $Lib_Dir ]]; then
			if [[ -e /usr/bin/brsaneconfig ]]; then cd "$Lib_Dir" || exit;
				log "Copie des bibliotheques nécessaires brsaneconfig"
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
				log "Copie des bibliotheques nécessaires brsaneconfig2"
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
				log "Copie des bibliotheques nécessaires brsaneconfig3"
				cp --force /usr/lib64/libbrscandec3.so.1.0.0 .
				ln -sf libbrscandec3.so.1.0.0 libbrscandec3.so.1
				ln -sf libbrscandec3.so.1 libbrscandec3.so
				cd "$Lib_Dir"/sane || exit
				cp --force /usr/lib64/sane/libsane-brother3.so.1.0.7 .
				ln -sf libsane-brother3.so.1.0.7 libsane-brother3.so.1
				ln -sf libsane-brother3.so.1 libsane-brother3.so
				log_action_end_msg 0
			elif [[ -e /usr/bin/brsaneconfig4 ]]; then cd "$Lib_Dir"/sane || exit
				log "Copie des bibliotheques nécessaires brsaneconfig4"
				ln -sf libsane-brother4.so.1.0.7 libsane-brother4.so.1
				ln -sf libsane-brother4.so.1 libsane-brother4.so
				log_action_end_msg 0
			elif [[ -e /usr/bin/brsaneconfig5 ]]; then cd "$Lib_Dir"/sane || exit
				log "Copie des bibliotheques nécessaires brsaneconfig5"
				ln -sf /usr/lib/x86_64-linux-gnu/sane/libsane-brother5.so.1.0 libsane-brother5.so.1
				ln -sf /usr/lib/x86_64-linux-gnu/sane/libsane-brother5.so.1.0.7 libsane-brother5.so.1.0
				ln -sf /opt/brother/scanner/brscan5/libsane-brother5.so.1.0.7 libsane-brother5.so.1.0.7
				log_action_end_msg 0
			else
				log_action_end_msg 1
				log "No config binary found." "Red"
			fi
		fi
	fi
	echo "" &>> "$Logfile"
}

#################
# FIN DU SCRIPT #
#################
do_clean() {
	cd || exit
	# On réattribue les droits des dossiers/fichiers crées à l'utilisateur
	chown -R "$User": "$Temp_Dir" "$Logfile"
	log "Configuration de votre imprimante Brother $Model_Name terminée. Bye :D" "Blue"
  	log "Vous pouvez supprimer le dossier $Temp_Dir avec la commande suivante :  rm -r $Temp_Dir" "Blue"
	exit 0
}

do_check_prerequisites
do_download_drivers
#do_install_drivers
do_configure_printer
do_configure_scanner
do_clean
