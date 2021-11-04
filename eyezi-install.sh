#!/bin/bash
#
# eyezimonit Agent Installation Script
#
# @version		1.0.6
# @date			2014-07-30
# @copyright	(c) 2014 http://eyezimonit.com
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# Set environment
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Prepare output
echo -e "|\n|   Eyezimonit Installer\n|   ===================\n|"

# Root required
if [ $(id -u) != "0" ];
then
	echo -e "|   Error: You need to be root to install the eyezimonit agent\n|"
	echo -e "|          The agent itself will NOT be running as root but instead under its own non-privileged user\n|"
	exit 1
fi

# Parameters required
if [ $# -lt 1 ]
then
	echo -e "|   Usage: bash $0 'token'\n|"
	exit 1
fi

# Check if crontab is installed
if [ ! -n "$(command -v crontab)" ]
then

	# Confirm crontab installation
	echo "|" && read -p "|   Crontab is required and could not be found. Do you want to install it? [Y/n] " input_variable_install

	# Attempt to install crontab
	if [ -z $input_variable_install ] || [ $input_variable_install == "Y" ] || [ $input_variable_install == "y" ]
	then
		if [ -n "$(command -v apt-get)" ]
		then
			echo -e "|\n|   Notice: Installing required package 'cron' via 'apt-get'"
		    apt-get -y update
		    apt-get -y install cron
		elif [ -n "$(command -v yum)" ]
		then
			echo -e "|\n|   Notice: Installing required package 'cronie' via 'yum'"
		    yum -y install cronie
		    
		    if [ ! -n "$(command -v crontab)" ]
		    then
		    	echo -e "|\n|   Notice: Installing required package 'vixie-cron' via 'yum'"
		    	yum -y install vixie-cron
		    fi
		elif [ -n "$(command -v pacman)" ]
		then
			echo -e "|\n|   Notice: Installing required package 'cronie' via 'pacman'"
		    pacman -S --noconfirm cronie
		fi
	fi
	
	if [ ! -n "$(command -v crontab)" ]
	then
	    # Show error
	    echo -e "|\n|   Error: Crontab is required and could not be installed\n|"
	    exit 1
	fi	
fi

# Check if cron is running
if [ -z "$(ps -Al | grep cron | grep -v grep)" ]
then
	
	# Confirm cron service
	echo "|" && read -p "|   Cron is available but not running. Do you want to start it? [Y/n] " input_variable_service

	# Attempt to start cron
	if [ -z $input_variable_service ] || [ $input_variable_service == "Y" ] || [ $input_variable_service == "y" ]
	then
		if [ -n "$(command -v apt-get)" ]
		then
			echo -e "|\n|   Notice: Starting 'cron' via 'service'"
			service cron start
		elif [ -n "$(command -v yum)" ]
		then
			echo -e "|\n|   Notice: Starting 'crond' via 'service'"
			chkconfig crond on
			service crond start
		elif [ -n "$(command -v pacman)" ]
		then
			echo -e "|\n|   Notice: Starting 'cronie' via 'systemctl'"
		    systemctl start cronie
		    systemctl enable cronie
		fi
	fi
	
	# Check if cron was started
	if [ -z "$(ps -Al | grep cron | grep -v grep)" ]
	then
		# Show error
		echo -e "|\n|   Error: Cron is available but could not be started\n|"
		exit 1
	fi
fi

# Attempt to delete previous agent
if [ -f /etc/eyezimonit/eyezi-agent.sh ]
then
	# Remove agent dir
	rm -Rf /etc/eyezimonit

	# Remove cron entry and user
	if id -u eyezimonit >/dev/null 2>&1
	then
		(crontab -u eyezimonit -l | grep -v "/etc/eyezimonit/eyezi-agent.sh") | crontab -u eyezimonit - && userdel eyezimonit
	else
		(crontab -u root -l | grep -v "/etc/eyezimonit/eyezi-agent.sh") | crontab -u root -
	fi
fi

# Create agent dir
mkdir -p /etc/eyezimonit

# Download agent
echo -e "|   Downloading eyezi-agent.sh to /etc/eyezimonit\n|\n|   + $(wget -nv -o /dev/stdout -O /etc/eyezimonit/eyezi-agent.sh --no-check-certificate https://raw.githubusercontent.com/antare74/an-agent/master/eyezi-agent.sh)"
# echo -e "|   Downloading eyezi-agent.sh to /etc/eyezimonit\n|\n|   + $(wget -nv -o /dev/stdout -O /etc/eyezimonit/eyezi-agent.sh --no-check-certificate https://raw.github.com/antare74/eyezi-agent/master/eyezi-agent.sh)"

if [ -f /etc/eyezimonit/eyezi-agent.sh ]
then
	# Create auth file
	echo "$1" > /etc/eyezimonit/an-auth.log
	
	# Create user
	useradd eyezimonit -r -d /etc/eyezimonit -s /bin/false
	
	# Modify user permissions
	chown -R eyezimonit:eyezimonit /etc/eyezimonit && chmod -R 700 /etc/eyezimonit
	
	# Modify ping permissions
	chmod +s `type -p ping`

	# Configure cron
	crontab -u eyezimonit -l 2>/dev/null | { cat; echo "*/3 * * * * bash /etc/eyezimonit/eyezi-agent.sh > /etc/eyezimonit/an-cron.log 2>&1"; } | crontab -u eyezimonit -
	
	# Show success
	echo -e "|\n|   Success: The eyezimonit agent has been installed\n|"
	
	# Attempt to delete installation script
	# if [ -f $0 ]
	# then
	# 	rm -f $0
	# fi
else
	# Show error
	echo -e "|\n|   Error: The eyezimonit agent could not be installed\n|"
fi
