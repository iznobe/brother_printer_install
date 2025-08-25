this script ( still in devellopement ) , can be used to install easily a printer and / or scanner from brother .
execute the script without argument and answer when it prompt you .
example :
<code>
sudo su -c "bash <(wget -qO- https://raw.githubusercontent.com/iznobe/brother_printer_install/refs/heads/main/brprinter_install.sh)"</code>

if you use your brother printer connected via USB , you can do like this :
<code>
wget https://raw.githubusercontent.com/iznobe/brother_printer_install/refs/heads/main/brprinter_install.sh
sudo ./brprinter_install.sh -m PRINTER_NAME</code>

if you use your printer on network you can give to script argument this way :
<code>
wget https://raw.githubusercontent.com/iznobe/brother_printer_install/refs/heads/main/brprinter_install.sh
chmod +x brprinter_install.sh
sudo bash brprinter_install.sh   PRINTER_NAME   1   PRINTER_IP</code>

For example , if in your box you have put 192.168.1.18 as fixed IP for your printer :
<code>
sudo bash brprinter_install.sh MFC-L2710DW 1 192.168.1.18</code>

And , the top , if you want to install a brother printer from another place in your computer , you can do :
<code>
sudo bash brprinter_install.sh MFC-L2710DW 1 IP_FROM_ANOTHER_PLACE</code>
example :
<code>
sudo bash brprinter_install.sh MFC-L2710DW 1 1.1.1.1</code>
if 1.1.1.1 is the IP of your external brother printer .
