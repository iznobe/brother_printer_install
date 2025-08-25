Ce script ( toujours en devellopement ) , peut etre utilisé pour installer facilement un imprimante et / ou un scanner de marque brother.</br>
exemple en direct en une seule commande :</br>
<code>sudo su -c "bash <(wget -qO- https://raw.githubusercontent.com/iznobe/brother_printer_install/refs/heads/main/brprinter_install.sh)"</code></br>
il suffira ensuite de répondre aux questions.</br>

Si votre imprimante est connectée en USB , il est possible de faire comme ça :</br>
telecharger d ' abord le script :</br>
<code>wget https://raw.githubusercontent.com/iznobe/brother_printer_install/refs/heads/Watael/brprinter_install.sh</code></br>
executer le script en lui donnant le nom de votre imprimante en parametre :</br>
<code>sudo  bash brprinter_install.sh -m PRINTER_NAME</code></br>
remplacer " PRINTER_NAME " par le vrai nom du materiel , par exemple : mfc-2710dw .</br>

Si l' imprimante est connectée en réseau , telecharger le script ( commande ci-dessus ) puis passer les arguments de cette maniere :</br>
<code>sudo bash brprinter_install.sh -m PRINTER_NAME -i PRINTER_IP</code></br>
remplacer " PRINTER_NAME " par le vrai nom du materiel , par exemple : mfc-2710dw , et " PRINTER_IP " par la véritable IP <b>FIXE</b> .</br>
Par exemple , si vous avez defini un bail statique dans votre box pour l' IP <b>FIXE</b>  de votre imprimante , ça donnerait :</br>
<code>sudo bash brprinter_install.sh -m MFC-L2710DW -i 192.168.1.18</code></br>

De cette maniere il est possible d ' installer une imprimante externe à votre réseau local situé a un emplacement different , tant qu ' il y a une <b>IP FIXE</b></br> pour la joindre .

  ----------------------------------------------------------------------------------------------------------------
  
this script ( still in devellopement ) , can be used to install easily a printer and / or scanner from brother .</br>
execute the script without argument and answer when it prompt you .</br>
example :</br>
<code>sudo su -c "bash <(wget -qO- https://raw.githubusercontent.com/iznobe/brother_printer_install/refs/heads/main/brprinter_install.sh)"</code></br>

if you use your brother printer connected via USB , you can do like this :</br>
<code>wget https://raw.githubusercontent.com/iznobe/brother_printer_install/refs/heads/Watael/brprinter_install.sh</br>
sudo  bash brprinter_install.sh -m PRINTER_NAME</code></br>
replace " brprinter_install.sh " by your real device name for example : mfc-2710dw .</br>

if you use your printer on network you can give to script argument this way :</br>
<code>wget https://raw.githubusercontent.com/iznobe/brother_printer_install/refs/heads/Watael/brprinter_install.sh
sudo bash brprinter_install.sh -m PRINTER_NAME -i PRINTER_IP</code></br>
replace " PRINTER_NAME " by your real device name for example : mfc-2710dw , and " PRINTER_IP " by your real <b>FIXED</b> device IP .</br>

For example , if in your box you have put 192.168.1.18 as <b>FIXED</b> IP for your printer :</br>
<code>sudo bash brprinter_install.sh -m MFC-L2710DW -i 192.168.1.18</code></br>

And , the top , if you want to install a brother printer from another place in your computer , you can do :</br>
<code>sudo bash brprinter_install.sh -m MFC-L2710DW -i IP_FROM_ANOTHER_PLACE</code></br>
replace " brprinter_install.sh " by your real device name for example : mfc-2710dw , and PRINTER_IP by your real <b>FIXED</b> device IP .</br>
example :
<code>sudo bash brprinter_install.sh MFC-L2710DW 1 1.1.1.1</code></br>
if 1.1.1.1 is the IP of your external brother printer .</br>
