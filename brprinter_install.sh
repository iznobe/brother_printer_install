#!/bin/bash
# MFC-L2710DW
# > vim search whole line : `yy / <Ctrl-F> p <Enter>'
 # définitions de variables
 # infos Brother
 # quelques fonctions
 # gestion des options
 # quelques vérifications
 # initialisation du tableau associatif `t_printer'
 # vérification de variables disponibles dans `t_printer'
 # préparation du système
 # téléchargement des pilotes
 # configuration de l’imprimante
 # configuration du scanner
# <

shopt -s extglob nullglob globstar # Cette ligne est-elle toujours d’actualité ?

#############################
 # définitions de variables #
#############################
if test -f /etc/lsb-release
then
    . /etc/lsb-release
    distroName="$DISTRIB_ID"
    versionYear="${DISTRIB_RELEASE::2}"
    version="${DISTRIB_RELEASE}"
    codeName="$DISTRIB_CODENAME"
elif test -f /usr/lib/os-release
then
    . /usr/lib/os-release
    distroName="$NAME"
    versionYear="${VERSION_ID::2}"
    version="${DISTRIB_ID}"
    codeName="$VERSION_CODENAME"
fi
user="$SUDO_USER"
arch="$(uname -m)"
date=$(date +%F_%T)
tmpDir="/tmp/packages"
logFile="/home/$user/brprinter_install.log"
libDir="/usr/lib/$arch-linux-gnu"

declare -u modelName
declare -A t_printer
declare -i err
declare -a t_printer_IP t_printer_name

##################
 # infos Brother #
##################
# Infos
urlInfo="https://download.brother.com/pub/com/linux/linux/infs"
# Packages :
urlPkg="https://download.brother.com/pub/com/linux/linux/packages"

udevRules="/lib/udev/rules.d/60-libsane1.rules"
udevDebName="brother-udev-rule-type1-1.0.2-0.all.deb"
urlUdevDeb="http://download.brother.com/welcome/dlf006654"
scankeyDrvDebName="brscan-skey-0.3.4-0.amd64.deb"

#######################
 # quelques fonctions #
#######################
usage()
{
    echo "
    Usage : sudo $0 [-h] [-m <Nom_Modèle>] [-u|-i <adresse_IP>]
    
    Options :
        
        -h
            Affiche cette aide et quitte.
        
        -m <Nom_Modèle>
            Renseigne <Nom_Modèle> comme nom du modèle de l’imprimante.
            Le paramètre <Nom_Modèle> est obligatoire pour cette option.
        
        -u
            Choisissez cette option pour une installation en USB.
            Vous ne pouvez pas l’utiliser en même temps que l’option -i.
        
        -i <adresse_IP>
            Choisissez cette option pour une installation en réseau.
            <adresse_IP> sera alors considérée comme l’adresse de l’imprimante.
            Le paramètre <adresse_IP> est obligatoire pour cette option.
            Vous ne pouvez pas l’utiliser en même temps que l’option -u.
    "
}
errQuit()
{
    chown -R "$user": "$tmpDir" "$logFile"
    >&2 echo -e "\\033[1;31m Erreur : $* \\033[0;0m"
    exit 1
}
verif_lien()
{
    local lien=$1 cible=$2
    if ! test -L "$lien"
    then
        ln -s "$cible" "$lien"
    fi
}
install_pkg()
{
    for pkg do
        log "Recherche du paquet : ' $pkg ' sur votre système"
        if dpkg-query -l "$pkg" | grep -q "^[hi]i"
        then
            log2file_o "Paquet ' $pkg ' deja installé"
            log_action_end_msg 0
        else
            log2file_o "Paquet ' $pkg ' non installé"
            log_action_end_msg 1
            log "Installation du paquet : ' $pkg ' sur votre système"
            apt-get install -qq "$pkg" &>> "$logFile"
            log_action_end_msg $?
        fi
    done
}
log() {
    message="$1"
    if test -z "$2"; then
        log_action_begin_msg "$message"
        log2file_o "$message"
    else
        if test "$2" == "Blue"; then color="\\033[1;34m";fi
        if test "$2" == "Red"; then color="\\033[1;31m";fi
            echo -e "$color $message \\033[0;0m" # Resetcolor
            echo -e "# $message" &>> "$logFile"
    fi
}
log2file_o() {
    echo -e " - $1" &>> "$logFile"
}

########################
 # gestion des options #
########################
while getopts "hm:ui:" opt
do
    case "$opt" in
        "h")
            usage
            exit 0
            ;;
        "m")
            modelName="$OPTARG"
            ;;
        "u")
            if test -z "$IP"
            then
                IP="USB"
            else
                usage
                errQuit "Vous ne pouvez pas utiliser l’option -u en même temps que l’option -i."
            fi
            ;;
        "i")
            if test "$IP" = "USB"
            then
                usage
                errQuit "Vous ne pouvez pas utiliser l’option -i en même temps que l’option -u."
            else
                IP="$OPTARG"
            fi
            ;;
        "?")
            usage
            errQuit "Erreur : mauvaise option ou argument manquant."
            ;;
    esac
done
shift $((OPTIND -1))
if (($#))
then
    usage
    errQuit "Erreur : trop d’arguments ou argument manquant dans une option."
fi

###########################
 # quelques vérifications #
###########################
if test -f /lib/lsb/init-functions; then . /lib/lsb/init-functions; else errQuit "/lib/lsb/init-functions manquant.";fi
if test "$distroName" != "Ubuntu"; then errQuit "La distribution n’est pas Ubuntu ou une des ses variantes officielles.";fi
if test "$SHELL" != "/bin/bash"; then errQuit "Shell non compatible. utilisez : bash";fi
if test "$arch" != "x86_64"; then errQuit "Système non compatible.";fi
if test -z "$versionYear"; then errQuit "Impossible d’évaluer la version de la distribution.";fi
if ((EUID)); then errQuit "Vous devez lancer le script en root : sudo $0";fi

#############################
 # prérequis pour le script #
#############################
if test -f "$logFile"; then
    Old_Date="$(head -n1 "$logFile")"
    mv -v "$logFile" "$logFile"."$Old_Date".log
fi
echo "$date" > "$logFile" # indispensable pour la rotation du log .

log "   # Ubuntu Codename : $codeName
        # Ubuntu Name : $distroName
        # Ubuntu Version : $version

        # Repertoire courant : $PWD
        # Repertoire de telechargement des pilotes : $tmpDir
        # Fichier journal : $logFile" "Blue"

log "verification de la connecion au site Brother"
if nc -z -w3 'brother.com' 80;then
log_action_end_msg $?
else errQuit "Site brother injoignable."; fi
log "Mise à jour des paquets"
apt-get update -qq
log_action_end_msg $?
install_pkg "wget" "libxml2-utils" "gawk" "avahi-utils"

if ! test -d "$tmpDir"
then
    mkdir -pv "$tmpDir"
    log2file_o "création du répertoire $tmpDir"
fi

if test -z "$modelName"
then # DÉTECTION AUTOMATIQUE ##### VERSION AVAHI-BROWSE #####
    mapfile -t t_printers < <(avahi-browse -d local _http._tcp -tkrp | gawk -F';' '/^=/ && /IPv4/ && /Brother/')
    for p in "${t_printers[@]}"
    do
        t_printer_name+=( "$(echo "$p" | grep -oP 'Brother\\032\K[^\\]+')" )
        if [[ "$p" =~ '=;lo;' ]]; then # USB
            t_printer_IP+=( "USB" )
        else # reseau
            t_printer_IP+=( "$(echo "$p" | grep -oP '\.local\;\K[^\;]+')" )
        fi
    done

    case ${#t_printer_name[*]} in
        0) log "Aucune imprimante détectée !
           Êtes vous sûr de l’avoir connectée au port USB de votre ordinateur ou à votre réseau local ?" "Red"
           log_action_end_msg 1
           # on repart donc avec les questions de base : modèle etc.
            ;;
        1)  log "Une seule imprimante détectée."
            modelName=${t_printer_name[0]} # ! t_printer_name != printerName
            IP=${t_printer_IP[0]}
            log_action_end_msg 0
            # pas besoin de poser de question, il ne reste plus qu’à installer
            ;;
        *)  log "Plusieurs imprimantes ont été détectées."
            # il faut presenter sous forme de liste les éléments recupérés :
            # modèle du materriel : IP ou USB
            # et demander à l’utilisateur de choisir un numéro dans cette liste
            log_action_end_msg 0
            n_print=$(("${#t_printer_name[@]}"))
            for n in "${!t_printer_name[@]}"
            do
                echo " $((n+1))  ⇒  ${t_printer_name[$n]}  :  ${t_printer_IP[$n]}"
            done
            while test -z "$choix"
            do
                read -rp "Choisissez le numéro qui correspond à l’imprimante que voulez installer : " choix
                if ! ((choix > 0 && choix <= n_print))
                then
                    log "Choix invalide !" "Red"
                    unset choix
                fi
            done
            modelName="${t_printer_name[$choix-1]}"
            IP=${t_printer_IP[$choix-1]}
            ;;
    esac
    until test -n "$modelName"
    do
        read -rp 'Entrez le modèle de votre imprimante : ' modelName
    done
fi

printerName="${modelName//-/}"
# check IP
until test -n "$IP"
do
    read -rp "Voulez-vous configurer votre imprimante pour qu’elle fonctionne en réseau ? [o/N] "
    case "${REPLY,,}" in
        "o"|"oui"|"y"|"yes"|"O"|"Y")
            echo "o"
            until test -n "$IP"
            do
                read -rp "Entrez l’adresse IP de votre imprimante : " IP
            done
            ;;
        *)
            echo "N"
            IP="USB"
            break
            ;;
    esac
done
if test "$IP" = "USB"
then
    log "Installation en USB."
    log_action_end_msg 0
    connection="USB"
    unset IP
else
    log "Installation en réseau."
    log_action_end_msg 0
    connection="réseau"
    IFS='.' read -ra ip <<< "$IP"
    for i in "${ip[@]}"; do
        ((n++ ? i >=0 && i<=255 : i>0 && i<=255)) || err+="1"
    done
    if (( ${#ip[*]} != 4 )) || ((err)) || ! ping -qc2 "$IP"
    then
        errQuit "Adresse erronée !"
    fi
fi

if test -z "$IP"; then IP="Aucune"; fi
urlPrinterDl="https://support.brother.com/g/b/downloadtop.aspx?c=fr&lang=fr&prod=${printerName}_us_eu_as"
urlPrinterInfo="$urlInfo/$printerName"
log "    # Modèle de l'imprimante : $modelName
     # Type de connexion : $connection
     # Adresse IP : $IP
     # Fichier d'informations : $urlPrinterInfo
     # page de telechargement des pilotes : $urlPrinterDl" "Blue"
if test "$IP" = "Aucune"; then unset IP;fi

###################################################
 # initialisation du tableau associatif `t_printer' #
###################################################
urlPrinterInfo="$urlInfo/$printerName"

while IFS='=' read -r k v
do
    t_printer[$k]=$v
done < <(wget -qO- "$urlPrinterInfo" | sed '/\(]\|rpm\|=\)$/d')

#########################################################
 # vérification de variables disponibles dans `t_printer' #
#########################################################
if test -n "${t_printer[LNK]}"; then # on telecharge le fichier donné en lien
    urlPrinterInfo="$urlInfo/${t_printer[LNK]}" # ????
    while IFS='=' read -r k v
    do
        t_printer[$k]=$v
    done < <(wget -qO- "$urlPrinterInfo" | sed '/\(]\|rpm\|=\)$/d')
fi
if ! test "${t_printer[PRINTERNAME]}" == "$printerName"
then
    errQuit "Les données du fichier info récupéré et le nom de l’imprimante ne correspondent pas."
fi
if test -n "${t_printer[SCANNER_DRV]}"
then
    install_pkg "libusb-0.1-4:amd64" "libusb-0.1-4:i386" "sane-utils"
    t_printer[udev_rules]="$udevDebName"
    . <(wget -qO- "$urlInfo/${t_printer[SCANNER_DRV]}.lnk" | sed -n '/^DEB/s/^/scanner_/p')
    . <(wget -qO- "$urlInfo/${t_printer[SCANKEY_DRV]}.lnk" | sed -n '/^DEB/s/^/scanKey_/p')
    t_printer[SCANNER_DRV]="$scanner_DEB64"
    t_printer[SCANKEY_DRV]="$scanKey_DEB64"

    if (( versionYear >= 24 )) && test "${t_printer[SCANKEY_DRV]}" = "brscan-skey-0.3.2-0.amd64.deb"
    then
        t_printer[SCANKEY_DRV]="$scankeyDrvDebName"
        log2file_o "changement de ${t_printer[SCANKEY_DRV]} pour $scankeyDrvDebName"
    fi
else
    err+="1"
    log "Pas de pilote pour le scanner." "Red"
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
        log2file_o "Création du répertoire $d"
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
for drv in "${t_printer[@]}"
do
    if [[ $drv == @($printerName|no|yes) ]]; then continue;fi
    if ! test -f "$tmpDir/$drv"
    then
        Url_Deb="$urlPkg/$drv"
        if test "$drv" = "${t_printer[udev_rules]}"
        then
            Url_Deb="$urlUdevDeb/$drv"
        fi
        log "Telechargement du pilote : $drv"
        wget -cP "$tmpDir" "$Url_Deb"
        log_action_end_msg $?
    fi
    pkg2install+=( "$tmpDir/$drv" )
done
log2file_o "Paquets à installer : ${pkg2install[*]}"

# installation des pilotes
if (( ${#pkg2install[*]} == 0 ))
then
    errQuit "Rien à installer."
else
    log "installation des paquets précédemment récupérés"
    wich "${pkg2install[@]}" || dpkg --install --force-all "${pkg2install[@]}"
    log_action_end_msg $?
fi

##################################
 # configuration de l’imprimante #
##################################
# retrouver le fichier `.ppd' pour l'imprimante
# for drv in "PRN_CUP_DEB" "PRN_DRV_DEB"
# do
#     pkg=${t_printer[$drv]}
#     if test -n "$pkg" -a -f "$tmpDir/$pkg"
#     then
#         while read -rd '' fileName
#         do
#             PPDs+=( "$fileName" )
#         done < <(dpkg --contents "$tmpDir/$pkg" | gawk 'BEGIN{ORS="\0"} /ppd/{sub(".","",$NF); print $NF}')
#     fi
# done
# if test -z "$Ppd_File"
# then
#     PPDs=( /usr/share/cups/model/**/*brother*@($printerName|$modelName)*.ppd )
# fi
# if test -n "$IP"; then
#     case ${#PPDs[*]} in
#         0) log "Pas de fichier ppd trouvé." "Red"
#            err+="1"
#            ;;
#         1) log "Un fichier ppd trouvé."
#            Ppd_File=${PPDs[0]}
#            ;;
#         *) err+="1"
#            log "Plusieurs fichier ppd trouvés."
#            Ppd_File=${PPDs[0]}
#            ;;
#     esac
# else

# if test -n "$IP" -a -n "$Ppd_File";then
#     log "Installation de l'imprimante en réseau"
#     lpadmin -p "$modelName" -E -v "lpd://$IP/binary_p1" -P "$Ppd_File"
#     log_action_end_msg $?
# elif test -z "$IP" -a -n "$Ppd_File";then
#     log "Installation de l'imprimante USB"
#     lpadmin -p "$modelName" -E -v 'usb://dev/usb/lp0' -P "$Ppd_File"
#     log_action_end_msg $?
# elif test -z "$IP" -a -z "$Ppd_File";then
#     log "Installation de l'imprimante USB"
#     lpadmin -p "$modelName" -E -v 'usb://dev/usb/lp0'
#     log_action_end_msg $?
# elif test -n "$IP" -a -z "$Ppd_File";then
#     log "Installation de l'imprimante en réseau"
#     lpadmin -p "$modelName" -E -v "lpd://$IP/binary_p1"
#     log_action_end_msg $?
# else
#     errQuit "Impossible d'installer l'imprimante"
# fi

if test -z "$IP";then
    log "Installation de l'imprimante USB"
    lpadmin -p "$modelName" -c brother -E -v 'usb://dev/usb/lp0'
    log_action_end_msg $?
elif test -n "$IP";then
    log "Installation de l'imprimante en réseau"
    lpadmin -p "$modelName" -c brother -E -v "lpd://$IP/binary_p1"
    log_action_end_msg $?
else
    errQuit "Impossible d'installer l'imprimante"
fi

cp /etc/cups/printers.conf.O /etc/cups/printers.conf "$tmpDir"
log2file_o "Sauvegarde des fichiers de configuration : /etc/cups/printers.conf.O /etc/cups/printers.conf dans $tmpDir"
log "Redémarrage du service cups"
systemctl restart cups
log_action_end_msg $?

#############################
 # configuration du scanner #
#############################

if test -z "$IP"
then #USB
    if grep -q "ATTRS{idVendor}==\"04f9\", ENV{libsane_matched}=\"yes\"" "$udevRules"
    then
        log "Règle udev deja presente dans le fichier $udevRules"
    else
        log "Installation du scanner USB"
        sed -i "/LABEL=\"libsane_usb_rules_begin\"/a\
            \n# Brother\nATTRS{idVendor}==\"04f9\", ENV{libsane_matched}=\"yes\"" "$udevRules"
        log_action_end_msg $?
        udevadm control --reload-rules
    fi
else #network
    for saneConf in /usr/bin/brsaneconfig{,{2..5}}
    do
        test -x "$saneConf" && cmd=$saneConf
    done
    if test -z "$cmd"
    then
        errQuit "Pas de dossier brsaneconfig trouvé."
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
    log "Installation du scanner réseau"
    $cmd -a name=SCANNER model="$modelName" ip="$IP"
    log_action_end_msg $?
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
else
    errQuit "Impossible de copier les bibliohèques pour le scanner , pas de dossier $libDir trouvé"
fi

echo -e "\\033[1;34m Vous pouvez consulter le avec journal la commande : cat $logFile \\033[0;0m"
echo -e "\\033[1;34m il est possible de supprimer le dossier temporaire du script avec la commande : rm -rf $tmpDir \\033[0;0m"
chown -R "$user": "$tmpDir" "$logFile"
