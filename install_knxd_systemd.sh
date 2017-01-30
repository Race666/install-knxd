#!/bin/bash
###############################################################################
# Script to compile and install knxd on a debian jessie (8) based systems
# 
# Michael Albert info@michlstechblog.info
# 09.06.2016
# Changes
# Version: 0.1
# This is the first release of the try to install knxd
# Currently state is experimental
#
# Version 0.2						Michael Add USB Support, some improvments
# Version 0.3						Michael New Raspbian Version use serial0 instead of ttyAMA0
# Version 0.4	12.07.2016			Michael Serial device in Raspberry Pi 3 and latest raspbian is ttyS0
# Version 0.5	12.07.2016			Michael Raspberry Pi 3 needs to enable UART1. Set enable_uart=1 /boot/cmdline.txt	 	
# Version 0.6	14.07.2016			Michael Disable Bluetooth module on Raspberry Pi 3
# Version 0.6.1	01.08.2016			Michael Disable Disable bash error handling
# Version 0.6.2 05.09.2016          Michael USB devices were not recognized: Removed Quote \ before ^ in $INSTALL_PREFIX/bin/knxd-findusb.sh. Thanks to michael pophal for submitting the bug.
# Version 0.6.3 01.12.2016          Michael Add support for ncn5120 backend
#
###############################################################################
# Exit on error
# set -e
if [ "$(id -u)" != "0" ]; then
   echo "     Attention!!!"
   echo "     Start script must run as root" 1>&2
   echo "     Start a root shell with"
   echo "     sudo su -"
   exit 1
fi
# define environment
export BUILD_PATH=$HOME/knxdbuild
export PTHSEM_PATH=${BUILD_PATH}/pthsem
export BUSSDK_PATH=${BUILD_PATH}/bussdk
export INSTALL_PREFIX=/usr/local
export IS_RASPBERRY_3=0
dmesg |grep -i "Raspberry Pi 3" > /dev/null
if [ $? -eq 0 ]; then
	echo Raspberry 3 found!
	export IS_RASPBERRY_3=1
fi
# Sources

apt-get update 
apt-get -y upgrade
apt-get -y install build-essential
apt-get -y install automake autoconf libtool 
apt-get -y install git 
apt-get -y install debhelper cdbs 
apt-get -y install libsystemd-dev libsystemd-daemon-dev libsystemd-daemon0 libsystemd0 pkg-config libusb-dev libusb-1.0-0-dev

# For accessing serial devices => User knxd dialout group
useradd knxd -s /bin/false -U -M -G dialout
# User pi to group knxd
usermod -a -G knxd pi
# And eibd himself to group eibd too
usermod -a -G knxd knxd


mkdir -p $PTHSEM_PATH
cd $PTHSEM_PATH
wget https://www.auto.tuwien.ac.at/~mkoegler/pth/pthsem_2.0.8.tar.gz
tar -xvzf pthsem_2.0.8.tar.gz
cd pthsem-2.0.8
# dpkg-buildpackage -b -uc
# dpkg -i libpthsem*.deb
./configure --enable-static=yes --prefix=$INSTALL_PREFIX CFLAGS="-static -static-libgcc -static-libstdc++" LDFLAGS="-static -static-libgcc -static-libstdc++" 
make && make install
# Add pthsem library to libpath
export LD_LIBRARY_PATH=$INSTALL_PREFIX/lib:$LD_LIBRARY_PATH
cd $BUILD_PATH
if [ -d "$BUILD_PATH/knxd" ]; then
	echo "knxd repository found"
	cd "$BUILD_PATH/knxd"
	git pull
else
	git clone https://github.com/knxd/knxd knxd
	cd knxd
fi

bash bootstrap.sh

# make clean
./configure \
    --enable-tpuarts \
    --enable-ft12 \
	--enable-ncn5120 \
    --enable-eibnetip \
	--disable-systemd \
    --enable-eibnetiptunnel \
    --enable-eibnetipserver \
    --enable-groupcache \
	--enable-usb \
    --enable-static=yes --prefix=$INSTALL_PREFIX --with-pth=$INSTALL_PREFIX CFLAGS="-static -static-libgcc -static-libstdc++" LDFLAGS="-static -static-libgcc -static-libstdc++ -s" CPPFLAGS="-static -static-libgcc -static-libstdc++"
	
# For USB Debugging add -DENABLE_LOGGING=1 and -DENABLE_DEBUG_LOGGING=1 to CFLAGS and CPPFLAGS:
# 	CFLAGS="-static -static-libgcc -static-libstdc++ -DENABLE_LOGGING=1 -DENABLE_DEBUG_LOGGING=1" \
#	CPPFLAGS="-static -static-libgcc -static-libstdc++ -DENABLE_LOGGING=1 -DENABLE_DEBUG_LOGGING=1" 
make clean && make && make install

# http://knx-user-forum.de/342820-post9.html
cat > /etc/udev/rules.d/90-knxusb-devices.rules <<EOF
# Siemens KNX
SUBSYSTEM=="usb", ATTR{idVendor}=="0e77", ATTR{idProduct}=="0111", ACTION=="add", GROUP="knxd", MODE="0664"
SUBSYSTEM=="usb", ATTR{idVendor}=="0e77", ATTR{idProduct}=="0112", ACTION=="add", GROUP="knxd", MODE="0664"
SUBSYSTEM=="usb", ATTR{idVendor}=="0681", ATTR{idProduct}=="0014", ACTION=="add", GROUP="knxd", MODE="0664"
# Merlin Gerin KNX-USB Interface
SUBSYSTEM=="usb", ATTR{idVendor}=="0e77", ATTR{idProduct}=="0141", ACTION=="add", GROUP="knxd", MODE="0664"
# Hensel KNX-USB Interface 
SUBSYSTEM=="usb", ATTR{idVendor}=="0e77", ATTR{idProduct}=="0121", ACTION=="add", GROUP="knxd", MODE="0664"
# Busch-Jaeger KNX-USB Interface
SUBSYSTEM=="usb", ATTR{idVendor}=="145c", ATTR{idProduct}=="1330", ACTION=="add", GROUP="knxd", MODE="0664"
SUBSYSTEM=="usb", ATTR{idVendor}=="145c", ATTR{idProduct}=="1490", ACTION=="add", GROUP="knxd", MODE="0664"
# ABB STOTZ-KONTAKT KNX-USB Interface
SUBSYSTEM=="usb", ATTR{idVendor}=="147b", ATTR{idProduct}=="5120", ACTION=="add", GROUP="knxd", MODE="0664"
# Feller KNX-USB Data Interface
SUBSYSTEM=="usb", ATTR{idVendor}=="135e", ATTR{idProduct}=="0026", ACTION=="add", GROUP="knxd", MODE="0664"
# JUNG KNX-USB Data Interface
SUBSYSTEM=="usb", ATTR{idVendor}=="135e", ATTR{idProduct}=="0023", ACTION=="add", GROUP="knxd", MODE="0664"
# Gira KNX-USB Data Interface
SUBSYSTEM=="usb", ATTR{idVendor}=="135e", ATTR{idProduct}=="0022", ACTION=="add", GROUP="knxd", MODE="0664"
# Berker KNX-USB Data Interface
SUBSYSTEM=="usb", ATTR{idVendor}=="135e", ATTR{idProduct}=="0021", ACTION=="add", GROUP="knxd", MODE="0664"
# Insta KNX-USB Data Interface
SUBSYSTEM=="usb", ATTR{idVendor}=="135e", ATTR{idProduct}=="0020", ACTION=="add", GROUP="knxd", MODE="0664"
# Weinzierl KNX-USB Interface
SUBSYSTEM=="usb", ATTR{idVendor}=="0e77", ATTR{idProduct}=="0104", ACTION=="add", GROUP="knxd", MODE="0664"
# Weinzierl KNX-USB Interface (RS232)
SUBSYSTEM=="usb", ATTR{idVendor}=="0e77", ATTR{idProduct}=="0103", ACTION=="add", GROUP="knxd", MODE="0664"
# Weinzierl KNX-USB Interface (Flush mounted)
SUBSYSTEM=="usb", ATTR{idVendor}=="0e77", ATTR{idProduct}=="0102", ACTION=="add", GROUP="knxd", MODE="0664"
# Tapko USB Interface
SUBSYSTEM=="usb", ATTR{idVendor}=="16d0", ATTR{idProduct}=="0490", ACTION=="add", GROUP="knxd", MODE="0664"
# Hager KNX-USB Data Interface
SUBSYSTEM=="usb", ATTR{idVendor}=="135e", ATTR{idProduct}=="0025", ACTION=="add", GROUP="knxd", MODE="0664"
# preussen automation USB2KNX
SUBSYSTEM=="usb", ATTR{idVendor}=="16d0", ATTR{idProduct}=="0492", ACTION=="add", GROUP="knxd", MODE="0664"
# Merten KNX-USB Data Interface
SUBSYSTEM=="usb", ATTR{idVendor}=="135e", ATTR{idProduct}=="0024", ACTION=="add", GROUP="knxd", MODE="0664"
# b+b EIBWeiche USB
SUBSYSTEM=="usb", ATTR{idVendor}=="04cc", ATTR{idProduct}=="0301", ACTION=="add", GROUP="knxd", MODE="0664"
# MDT KNX_USB_Interface
SUBSYSTEM=="usb", ATTR{idVendor}=="16d0", ATTR{idProduct}=="0491", ACTION=="add", GROUP="knxd", MODE="0664"
EOF


cat > /etc/default/knxd <<EOF
# Command line parameters for knxd. TPUART Backend
# Serial device Raspberry
KNXD_OPTIONS="--eibaddr=1.1.128 -d -D -T -R -S -i --listen-local=/tmp/knx tpuarts:/dev/ttyAMA0"
# Serial device PC
# KNXD_OPTIONS="--eibaddr=1.1.128 -d -D -T -R -S -i --listen-local=/tmp/knx tpuarts:/dev/ttyS0"
# Tunnel Backend
# KNXD_OPTIONS="--eibaddr=1.1.128 -d -D -T -R -S -i --listen-local=/tmp/knx ipt:192.168.56.1"
# USB Backend
# KNXD_OPTIONS="--eibaddr=1.1.128 -d -D -T -R -S -i --listen-local=/tmp/knx usb:%DEVICEID%"
EOF

chown knxd:knxd /etc/default/knxd
chmod 644 /etc/default/knxd


cat > /etc/tmpfiles.d/knxd.conf <<EOF
D    /run/knxd 0744 knxd knxd
EOF

cat >  /lib/systemd/system/knxd.service <<EOF
[Unit]
Description=KNX Daemon
After=network.target

[Service]
EnvironmentFile=/etc/default/knxd
ExecStartPre=$INSTALL_PREFIX/bin/knxd-findusb.sh
ExecStart=/usr/local/bin/knxd -p /run/knxd/knxd.pid \$KNXD_OPTIONS
Type=forking
PIDFile=/run/knxd/knxd.pid
User=knxd
Group=knxd

[Install]
WantedBy=multi-user.target
EOF

# For autodetecting USB devices
cat > $INSTALL_PREFIX/bin/knxd-findusb.sh <<EOF
#!/bin/bash
grep -e "^\s*KNXD_OPTIONS\=.*usb\:" /etc/default/knxd
# USB Enabled?
if [ \$? -ge 1 ]; then
	exit 0
fi
export USBID=""
export TIMEOUT=30
while [ "\$USBID" == "" ] && [ \$TIMEOUT -ge 0 ]; do
  export USBID=\$(/usr/local/bin/findknxusb | grep device: | cut -d' ' -f2)
  let TIMEOUT-=1
  sleep 1
done
sed -e"s/usb:.*\\\$/usb:\$USBID\"/" /etc/default/knxd > /tmp/knxd.env
cp /tmp/knxd.env /etc/default/knxd
EOF

chmod 755 $INSTALL_PREFIX/bin/knxd-findusb.sh


# Enable at Startup
systemctl enable knxd.service
sync
# Modify /boot/cmdline.txt to disable boot screen over serial interface
# sed -e's/ console=ttyAMA0,115200 kgdboc=ttyAMA0,115200//g' /boot/cmdline.txt --in-place=.bak
# Disable Console and Raspberry Pi 3 needs to enable UART1 (http://raspberrypi.stackexchange.com/questions/45570/how-do-i-make-serial-work-on-the-raspberry-pi3)
# https://www.raspberrypi.org/forums/viewtopic.php?f=28&t=141195
# https://www.hackster.io/fvdbosch/uart-for-serial-console-or-hat-on-raspberry-pi-3-5be0c2
# http://www.fhemwiki.de/w/index.php?title=Raspberry_Pi_3:_GPIO-Port_Module_und_Bluetooth&redirect=no
# Restore ttyAMA0 (dtoverlay=pi3-disable-bt in /)https://openenergymonitor.org/emon/node/12311
# dtoverlays https://raspberry.tips/faq/raspberry-pi-device-tree-aenderung-mit-kernel-3-18-x-geraete-wieder-aktivieren/
if [ $IS_RASPBERRY_3 -eq 1 ]; then
	sed -e's/ console=ttyAMA0,115200/ enable_uart=1 dtoverlay=pi3-disable-bt/g' /boot/cmdline.txt --in-place=.bak
	sed -e's/ console=serial0,115200/ enable_uart=1 dtoverlay=pi3-disable-bt/g' /boot/cmdline.txt --in-place=.bak2
	sed -e's/ console=ttyS0,115200/ enable_uart=1 dtoverlay=pi3-disable-bt/g' /boot/cmdline.txt --in-place=.bak2
	systemctl disable hciuart
else
	sed -e's/ console=ttyAMA0,115200//g' /boot/cmdline.txt --in-place=.bak
	sed -e's/ console=serial0,115200//g' /boot/cmdline.txt --in-place=.bak2
	sed -e's/ console=ttyS0,115200//g' /boot/cmdline.txt --in-place=.bak2
fi
sed -e's/ kgdboc=ttyAMA0,115200//g' /boot/cmdline.txt --in-place=.bak1
sed -e's/ kgdboc=serial0,115200//g' /boot/cmdline.txt --in-place=.bak3
sed -e's/ kgdboc=ttyS0,115200//g' /boot/cmdline.txt --in-place=.bak5

# Disable serial console
systemctl disable serial-getty@ttyAMA0.service > /dev/null 2>&1
systemctl disable serial-getty@ttyS0.service > /dev/null 2>&1
systemctl disable serial-getty@.service> /dev/null 2>&1


