#!/bin/bash

# Assert that user is root
function assert_root()
{
	if [ "$(id -u)" != 0 ]
	then
		echo "This must be run as root!"
		exit 1
	fi
}

# Assert that user is NOT root
function assert_not_root()
{
	if [ "$(id -u)" == 0 ]
	then
		echo "This must NOT be run as root!"
		exit 1
	fi
}

# Setup pacman
function setup_pacman()
{
	assert_root
	
	if ! grep -q "\[multilib\]" /etc/pacman.conf
	then
		echo "Add multilib repo"
		echo "[multilib]" >> /etc/pacman.conf
		echo "Include = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
	fi

	pacman -Syu	
}

# Setup Users
function create_user()
{
	assert_root

	useradd -m hauke
	passwd hauke
	echo "hauke ALL=(ALL) ALL" >> /etc/sudoers/
}

# Setup AUR
function setup_aur()
{
	assert_not_root

	# This is the only command here that should be executed as root
	sudo pacman -S --needed git
	
	export BUILDDIR=/tmp/makepkg
	export PKGDEST=.
	export SRCDEST=.
	
	git clone https://aur.archlinux.org/yay.git
	cd yay
	makepkg -sci
	
	cd ..
	rm -rf yay
}

# Graphics driver
function install_driver_graphics()
{
	assert_root

	pacman -Sy --needed \
		mesa \
		lib32-mesa\
		xf86-video-amdgpu \
		vulkan-radeon \
		lib32-vulkan-radeon \
		libva-mesa-driver \
		lib32-libva-mesa-driver \
		libva-vdpau-driver \
		mesa-vdpau \
		lib32-mesa-vdpau
}

# Printer driver. Uses KDE's kcm_printer_manager.
function install_driver_printer()
{
	assert_root

	LOG=${0##*/}.log
	PRINT_MANAGER="kcmshell5 kcm_printer_manager"
	
	su hauke -c "yay -S --needed brother-hl5450dn"
	
	systemctl enable cups-browsed.service
	systemctl start cups-browsed.service
	
	echo "Hinweis:"
	echo "Drucker muss noch eingerichtet werden! Wie folgt vorgehen:"
	echo 
	echo "==="
	echo "1. Drucker-URL finden (z.B. 'lpd://BRN30055C8ADAEE/BINARY_P1'):"
	echo "==="
	lpinfo -v
	echo
	echo "==="
	echo "2. Gleich öffnet sich die Verwaltung, da dann einen neuen Drucker hinzufügen"
	echo "==="
	echo "3. Für den Drucker die 'driverless' Variante wählen und URL eintragen (die von Schritt 1)"
	echo "==="
	echo "4. Treiber auswählen"
	echo "==="
	echo "5. Fertig, ggf. Testseite drucken"
	echo "==="
	echo
	echo "Weiter mit zu '$PRINT_MANAGER' ENTER..."
	read
	$PRINT_MANAGER
}

# Driver
function install_driver()
{
	assert_root

	install_driver_graphics
	install_driver_printer	
}

# Xorg
function install_xorg()
{
	assert_root

	pacman -S --needed xorg-server xorg xorg-apps 
}

# SDDM, KDE and the KDE-apps
function install_kde()
{
	assert_root

	pacman -S --needed plasma kde-applications sddm sddm-kcm
	
	systemctl enable sddm
	
	# Set locales correctly, because that doesn't work always correctly
	echo "de_DE.UTF-8 UTF-8" >> /etc/locale.gen
	locale-gen
	
	echo 'LANG="de_DE.UTF-8"' > /etc/locale.conf
	echo 'LC_DATE="de_DE.UTF-8"' >> /etc/locale.conf
	echo 'LC_NUMERIC="de_DE.UTF-8"' >> /etc/locale.conf
	echo 'LC_COLLATE=C' >> /etc/locale.conf
}

# Apps
function install_apps()
{
	assert_root

	# System
	pacman -S --needed \
		htop \
		baobab \
		mtr \
		openssh \
		gnu-netcat \
		gnome-calculator \
		ufw \
		zip
	
	# Development
	pacman -S --needed \
		git \
		tk \
		go \
		openjdk8-src \
		jdk8-openjdk \
		hugo \
		eclipse-java \
		liteide \
		atom \
		hunspell-de \
		hunspell-en_US \
		virt-manager \
		qemu texlive-core \
		texlive-bibtexextra \
		texlive-fontsextra \
		texlive-langextra \
		texlive-latexextra \
		texlive-science \
		texstudio
	yay -S --needed latex-pgfplots
	su hauke -c "yay -S qemu-kvm"

	# Internet
	pacman -S --needed \
		openvpn \
		firefox \
		thunderbird \
		telegram-desktop \
		hexchat \
		rsync \
		wget \
		keepassxc \
		xdotool \
		filezilla \
		ktorrent \
		kdeconnect \
		sshfs
	su hauke -c "yay -S --needed signal"

	# Gaming
	pacman -S --needed \
		steam \
		lib32-libxtst \
		lib32-libxrandr \
		lib32-glib2 \
		lib32-libpulse \
		lib32-gtk2 \
		lib32-libva \
		lib32-libvdpau \
		lib32-openal

	# Multimedia
	pacman -S --needed \
		vlc \
		gimp \
		darktable \
		gwenview \
		okular \
		imagemagick \
		ffmpeg \
		pavucontrol
	su hauke -c "yay -S --needed spotify"
}

function install_theme()
{
	assert_not_root

	mkdir -p ~/.local/share/color-schemes/
	mkdir -p ~/.local/share/plasma/desktoptheme/

	cp kde-greeze-dark-green/BreezeDarkGreen.colors ~/.local/share/color-schemes/BreezeDarkGreen.colors
	cp -r kde-greeze-dark-green/breeze-dark-green ~/.local/share/plasma/desktoptheme/
}

function install_configs()
{
	mkdir -p ~/.gnupg
	cp ./gpg-agent.conf ~/.gnupg/
}

function usage()
{
	cat<<END
Sets up my system base configuration.

Usage: setup.sh [--all][-upadxkAh]

Options:
 --all  $(echo -n "Installs everything. This has to be the first option and all following options will be ignored" | fold -s -w $(echo "$(tput cols) - 8" | bc -l) | sed -z -e "s|\n|\n        |g")
  -u    Creates the user
  -p    Configures pacman
  -a    Configures the aur with yay
  -d    Installs all drivers
  -x    Installs X
  -k    Installs KDE
  -A    Installs the basic applications
  -t    Configured the "Breeze Dark Green" theme
  -c    Installs all configs and dot-files
  -h    Shows this message

All feedback to: 
END
}

# getopts for bash cannot handle long arguments:
if [ $1 == "--all" ]
then
	assert_root

	create_user
	setup_pacman
	su hauke -c "setup_aur"
	install_driver
	install_xorg
	install_kde
	install_apps
	install_theme
	install_configs
	su hauke -c "install_theme"

	exit
fi

while getopts "upadxkAth" opt; do
	case $opt in
	u)
		create_user
		;;
	p)
		setup_pacman
		;;
	a)
		setup_aur
		;;
	d)
		install_driver
		;;
	x)
		install_xorg
		;;
	k)
		install_kde
		;;
	A)
		install_apps
		;;
	t)
		install_theme
		;;
	c)
		install_configs
		;;
	h)
		usage
		;;
	\?)
		echo "Invalid option: -$OPTARG" >&2
		;;
	esac
done

# TODO: copy dot files
