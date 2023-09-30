#!/bin/bash

PIVOT_Ip="hovercricket"
PIVOT_ForwardIp="37.120.207.132"
PIVOT_ForwardPort="46944"
PIVOT_User="root"
PIVOT_Password="segfault"

USER_Uid="1001";

PIVOT_Services="${PIVOT_ForwardPort}:localhost:22";

SSH_Bin="/bin/ssh";
SSHFS_Bin="/bin/sshfs"
CHISEL_Bin="./chisel"

SSHFS_Install_Path="/media/Installation";
SSHFS_Exfil_Path="/media/Exfiltration";
SSHFS_Data_Path="/media/Datas";

function Usage()
{
	local Pivot="$1";
	echo "=========================================================="
	echo "Setup Pivot server";
	echo "=========================================================="
	echo "Ip		: $PIVOT_Ip";
	echo "Port		: $PIVOT_ForwardPort";
	echo "User		: $PIVOT_User ($PIVOT_Password)";
	echo


}

function Setup()
{
	echo "Requirements	:"
	echo "			* create local user 'alcane' (useradd alcane)";
	echo "			* allow him in sudosers";

	echo "Setup pivot	: ";
	if [ -f "${PIVOT_Ip}.setup" ]; then
		echo "			Pivot already setup.";
	else
		echo -n "			* Create initial folders on pivot :";
	        $SSH_Bin -l $PIVOT_User $PIVOT_Ip "mkdir /media/Install; mkdir /media/Exfil; mkdir /media/Datas; chown -R alcane:alcane /media"
       		echo "Done.";

		echo -n "			* Setup sshd to avoid timeout session :"
	        $SSH_Bin -l $PIVOT_User $PIVOT_Ip "echo 'TCPKeepAlive no\nClientAliveInterval 30\nClientAliveCountMax 240'>>/etc/ssh/sshd_config; /etc/init.d/ssh restart" 

		InstallPackages;
		RemoteExecute;

		touch ${PIVOT_Ip}.setup
	fi
}

function InstallPackages()
{
	echo "Install		:";

	echo  "			* Chisel :";
	$SSH_Bin -l $PIVOT_User $PIVOT_Ip "wget -q https://github.com/jpillora/chisel/releases/download/v1.7.6/chisel_1.7.6_linux_amd64.gz -O /media/Install/chisel.gz"
	$SSH_Bin -l $PIVOT_User $PIVOT_Ip "gzip -d /media/Install/chisel.gz; chmod a+x /media/Install/chisel*"
	echo "				Downloaded and installed.";
}

function ChiselConnecting()
{
        echo "=========================================================="
        echo "Connecting to chisel on $PIVOT_Ip:$PIVOT_ForwardPort"
        echo "=========================================================="

	$CHISEL_Bin client --keepalive 60s  $PIVOT_ForwardIp:$PIVOT_ForwardPort $PIVOT_Services &
	sleep 2;

	echo
}

function SSHFS_Shares()
{
	echo "			* SSHFS sharing";
	echo -n "				Exfil :"
	$SSHFS_Bin -p $PIVOT_ForwardPort -o uid=$USER_Uid alcane@localhost:/media/Exfil "$SSHFS_Exfil_Path"
	echo "OK";

	echo -n "				Install :"
	$SSHFS_Bin -p $PIVOT_ForwardPort -o uid=$USER_Uid alcane@localhost:/media/Install "$SSHFS_Install_Path"
	echo "OK";

	echo -n "				Datas :"
	$SSHFS_Bin -p $PIVOT_ForwardPort -o uid=$USER_Uid alcane@localhost:/media/Datas "$SSHFS_Data_Path"
	echo "OK";
}

function ConnectingServices()
{
	echo "Connecting	:";
	SSHFS_Shares;
}

function RemoteExecute()
{
	echo "				Running on port ($PIVOT_ForwardPort).";
	$SSH_Bin -l $PIVOT_User $PIVOT_Ip "/media/Install/chisel server --reverse --port $PIVOT_ForwardPort &" 2>/dev/null
}

function RemoteShell()
{
	echo "=========================================================="
	echo "Remote SSH to pivot ($PIVOT_ForwardPort)"
	echo "=========================================================="
	$SSH_Bin -l root -o "ServerAliveInterval 30" $PIVOT_Ip


}


function Go()
{
	local Pivot="$1";
	Usage "$1";

	Setup;
	ChiselConnecting;
	ConnectingServices;

	RemoteShell;
}

if [ "$1" == "RemoteShell" ]; then
	RemoteShell;
else
	Go
fi
