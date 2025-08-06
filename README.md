this script ( still in devellopement ) , can be used to install easily a printer and / or scanner from brother .
execute the script without argument and answer when it prompt you .
example :
[code]sudo su -c "bash <(wget -qO- https://raw.githubusercontent.com/iznobe/brother_printer_install/refs/heads/main/brprinter_install.sh)"[/code]

if you use your brother printer connected via USB , you can do like this :
[code]
wget https://raw.githubusercontent.com/iznobe/brother_printer_install/refs/heads/main/brprinter_install.sh

chmod +x brprinter_install.sh

sudo bash brprinter_install.sh   PRINTER_NAME   0[/code]

if you use your printer on network you can give to script argument this way :
[code]
wget https://raw.githubusercontent.com/iznobe/brother_printer_install/refs/heads/main/brprinter_install.sh

chmod +x brprinter_install.sh

sudo bash brprinter_install.sh   PRINTER_NAME   1 IP[/code]
example , if in your box you have put 192.168.1.18 as fixed IP for your printer :
[code]sudo bash brprinter_install.sh MFC-L2710DW 1 192.168.1.18[/code]
