#!/bin/bash
set -e
# Exit on error
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
# Version 0.7.0 30.01.2017          Michael Adjusted to knxd 0.12 => lib pthsem to libev
#                                           Changed the Compiler options to build dynamic linked binaries, because the standard libev library is used.
#                                           if parameter -S is set and error "initialization of the EIBnet/IP server failed: No such device " occurs => The Multicast route 224.0.23.12/32 is missing (route add 224.0.23.12/32 eth0)
#                                           New command line Option -E/--client-addrs 
#                                           Creates a /run/knxd folder for pid file
#                                           Script exits immediately on error
#                                           Some housekeeping :-)
# Version 0.7.1 03.02.2017          Michael /usr/local to ld path
#                                           Removed duplicate /etc/tmpfiles.d/knxd.conf
# Version 0.7.2 08.02.2017          Michael --with-pth removed from configure
# Version 0.7.3 08.02.2017          Michael added switch -b for Layer2 driver 
#                                           The USB device ID is no longer necessary   
# Version 0.7.4 12.02.2017          Michael chmod on knxd-findusb.sh remove
# Version 0.7.5 12.02.2017          Michael The knxd Master Branch is currently under heavy development. Always checkout last stable Version v0.12
# Version 0.7.6 19.02.2017          Michael Check if User knxd already exists.
#                                           Switching from v0.12 to stable
#                                           Preparation for libfmt
# Version 0.7.7 03.07.2017                  Removed libsystemd-daemon0 from installed packages
# Version 0.7.8 18.09.2017          Michael Configure options. remove: --enable-ncn5120  changed: --enable-tpuarts => --enable-tpuart new: --enable-busmonitor --enable-eibnetserver 
#                                           Number of client address increased 1 => 8
#                                           Still installing libfmt from github due to compatibility with Debian 8
#                                           Due to changes in 0.14 changed systemd type from forked to simple
# Version 0.7.9 21.09.2017          Michael systemd knxd.service file changed. Insert Parameters (commented, therefore disabled) for systemd-networkd-wait-online.service
#                                           Also added dependency WantedBy=...network-online.target
#                                           /etc/default/knxd Backend tpuarts renamed to tpuart
# Version 0.7.10 25.09.2017         Michael Backendname of tpuart is still tpuarts. Rollback..
# Version 0.7.11 11.10.2017         Michael Temp Patch for issues with USB devices see https://github.com/knxd/knxd/issues/290
# Version 0.7.12 11.10.2017         Michael Patchmessage text modified
# Version 0.7.13 29.11.2017         Michael low_latency for BusWare USB TPUART, see https://github.com/knxd/knxd/issues/301
# Version 0.7.14 23.01.2018         Michael Due to commit 356be34 changed the knxd.service Type to Type=forking
# Version 0.7.15 30.03.2018         Michael Change knxd to master branch
# Version 0.7.16 12.08.2019         Michael Builting of libfmt removed. knxd gets and compiles libfmt
# Version 0.7.17 26.05.2020         Michael Path of systemd unit file changed
# Version 0.7.18 26.05.2020         Michael Default Timrout in knxd is changed from 500ms -> 2000ms. Patch removed
# Version 0.7.19 26.05.2020         Michael Checkout branch master -> main
###############################################################################
if [ "$(id -u)" != "0" ]; then
   echo "     Attention!!!"
   echo "     Start script must run as root" 1>&2
   echo "     Start a root shell with"
   echo "     sudo su -"
   exit 1
fi
# define environment
export BUILD_PATH=$HOME/knxdbuild
export BUSSDK_PATH=${BUILD_PATH}/bussdk
export INSTALL_PREFIX=/usr/local
export IS_RASPBERRY_3=0
export EIB_ADDRESS_KNXD="1.1.128"
export EIB_START_ADDRESS_CLIENTS_KNXD="1.1.129"
export EIB_NUMBER_OF_CLIENT_KNX_CLIENT_ADDRESSES=8

# Disable error handling
set +e
dmesg |grep -i "Raspberry Pi 3" > /dev/null
if [ $? -eq 0 ]; then
	echo Raspberry 3 found!
	export IS_RASPBERRY_3=1
fi
# Enable error handling
set -e
# Requiered packages
apt-get update 
apt-get -y upgrade
apt-get -y install build-essential cmake
apt-get -y install automake autoconf libtool 
apt-get -y install git 
apt-get -y install debhelper cdbs 
apt-get -y install libsystemd-dev libsystemd0 pkg-config libusb-dev libusb-1.0-0-dev
apt-get -y install libev-dev 
apt-get -y install setserial

# New User knxd 
# For accessing serial devices => User knxd dialout group
set +e
getent passwd knxd
if [ $? -ne 0 ]; then
	useradd knxd -s /bin/false -U -M -G dialout
fi	
set -e

# On Raspberry add user pi to group knxd
set +e
getent passwd pi
if [ $? -eq 0 ]; then
	usermod -a -G knxd pi
fi	
set -e

# And knxd himself to group knxd too
usermod -a -G knxd knxd

# Add /usr/local library to libpath
export LD_LIBRARY_PATH=$INSTALL_PREFIX/lib:$LD_LIBRARY_PATH
if [ ! -d "$BUILD_PATH" ]; then mkdir -p "$BUILD_PATH"; fi

cd $BUILD_PATH
if [ -d "$BUILD_PATH/knxd" ]; then
	echo "knxd repository found"
	cd "$BUILD_PATH/knxd"
	git pull
else
	git clone https://github.com/knxd/knxd knxd
	cd knxd
fi

git checkout main

#git checkout master
# All previously installed libraries have to be removed
set +e
rm $INSTALL_PREFIX/lib/libeibclient* > /dev/null 2>&1
set -e

bash bootstrap.sh

./configure \
    --enable-tpuart \
    --enable-ft12 \
	--enable-dummy \
    --enable-eibnetip \
    --enable-eibnetserver \
	--disable-systemd \
	--enable-busmonitor \
    --enable-eibnetiptunnel \
    --enable-eibnetipserver \
    --enable-groupcache \
    --enable-usb \
    --prefix=$INSTALL_PREFIX \
	CPPFLAGS="-I$BUILD_PATH/fmt"
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
# Siemens 148/12 KNX Interface
SUBSYSTEM=="usb", ATTR{idVendor}=="0908", ATTR{idProduct}=="02dd", ACTION=="add", GROUP="knxd", MODE="0664"
# Low Latency for  Busware TUL TPUART USB
ACTION=="add", SUBSYSTEM=="tty", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="204b", KERNELS=="1-4", SYMLINK+="ttyTPUART", RUN+="/bin/setserial /dev/%k low_latency", GROUP="dialout", MODE="0664"
# Test rules example:
# udevadm info --query=all --attribute-walk --name=/dev/ttyS0
# udevadm test /dev/ttyS0 
# ACTION=="add",SUBSYSTEM=="tty", ATTR{port}=="0x3F8",SYMLINK+="ttyTPUART1",RUN+="/bin/setserial /dev/%k low_latency", GROUP="dialout", MODE="0664"
EOF


cat > /etc/default/knxd <<EOF
# Command line parameters for knxd. TPUART Backend
# Serial device Raspberry
KNXD_OPTIONS="--eibaddr=$EIB_ADDRESS_KNXD --client-addrs=$EIB_START_ADDRESS_CLIENTS_KNXD:$EIB_NUMBER_OF_CLIENT_KNX_CLIENT_ADDRESSES -d -D -T -R -S -i --listen-local=/tmp/knx -b tpuarts:/dev/ttyAMA0"
# Serial device PC
# KNXD_OPTIONS="--eibaddr=$EIB_ADDRESS_KNXD --client-addrs=$EIB_START_ADDRESS_CLIENTS_KNXD:$EIB_NUMBER_OF_CLIENT_KNX_CLIENT_ADDRESSES -d -D -T -R -S -i --listen-local=/tmp/knx -b tpuarts:/dev/ttyS0"
# Tunnel Backend
# KNXD_OPTIONS="--eibaddr=$EIB_ADDRESS_KNXD --client-addrs=$EIB_START_ADDRESS_CLIENTS_KNXD:$EIB_NUMBER_OF_CLIENT_KNX_CLIENT_ADDRESSES -d -D -T -R -S -i --listen-local=/tmp/knx -b ipt:192.168.56.1"
# USB Backend
# KNXD_OPTIONS="--eibaddr=$EIB_ADDRESS_KNXD --client-addrs=$EIB_START_ADDRESS_CLIENTS_KNXD:$EIB_NUMBER_OF_CLIENT_KNX_CLIENT_ADDRESSES -d -D -T -R -S -i --listen-local=/tmp/knx -b usb:"
EOF

chown knxd:knxd /etc/default/knxd
chmod 644 /etc/default/knxd

# Systemd knxd unit
cat >  /etc/systemd/system/knxd.service <<EOF
[Unit]
Description=KNX Daemon
After=network.target

[Service]
EnvironmentFile=/etc/default/knxd
# Wait for all interfaces, systemd-networkd-wait-online.service must be enabled
#ExecStartPre=/lib/systemd/systemd-networkd-wait-online --timeout=60
# Wait for a specific interface
#ExecStartPre=/lib/systemd/systemd-networkd-wait-online --timeout=60 --interface=eth0
ExecStart=/usr/local/bin/knxd -p /run/knxd/knxd.pid \$KNXD_OPTIONS
Type=forking
PIDFile=/run/knxd/knxd.pid
User=knxd
Group=knxd
#TimeoutStartSec=60

[Install]
WantedBy=multi-user.target network-online.target
EOF

# Create knxd folder under /run
cat > /etc/tmpfiles.d/knxd.conf <<EOF
D    /run/knxd 0744 knxd knxd
EOF

# Library Path
cat > /etc/ld.so.conf.d/knxd.conf <<EOF
/usr/local/lib
EOF

ldconfig


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
set +e
if [ $IS_RASPBERRY_3 -eq 1 ]; then
    sed -e's/ console=ttyAMA0,115200/ enable_uart=1 dtoverlay=pi3-disable-bt/g' /boot/cmdline.txt --in-place=.bak
    sed -e's/ console=serial0,115200/ enable_uart=1 dtoverlay=pi3-disable-bt/g' /boot/cmdline.txt --in-place=.bak2
    sed -e's/ console=ttyS0,115200/ enable_uart=1 dtoverlay=pi3-disable-bt/g' /boot/cmdline.txt --in-place=.bak4
	sed -e's/ console=ttyACM0,115200/ enable_uart=1 dtoverlay=pi3-disable-bt/g' /boot/cmdline.txt --in-place=.bak6
    systemctl disable hciuart
else
    sed -e's/ console=ttyAMA0,115200//g' /boot/cmdline.txt --in-place=.bak
    sed -e's/ console=serial0,115200//g' /boot/cmdline.txt --in-place=.bak2
    sed -e's/ console=ttyS0,115200//g' /boot/cmdline.txt --in-place=.bak4
	sed -e's/ console=ttyACM0,115200//g' /boot/cmdline.txt --in-place=.bak6
fi
sed -e's/ kgdboc=ttyAMA0,115200//g' /boot/cmdline.txt --in-place=.bak1
sed -e's/ kgdboc=serial0,115200//g' /boot/cmdline.txt --in-place=.bak3
sed -e's/ kgdboc=ttyS0,115200//g' /boot/cmdline.txt --in-place=.bak5
sed -e's/ kgdboc=ttyACM0,115200//g' /boot/cmdline.txt --in-place=.bak7

# Disable serial console
systemctl disable serial-getty@ttyAMA0.service > /dev/null 2>&1
systemctl disable serial-getty@ttyS0.service > /dev/null 2>&1
systemctl disable serial-getty@.service> /dev/null 2>&1

echo "Please reboot your device!"
