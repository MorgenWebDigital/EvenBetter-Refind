#!/usr/bin/env bash
set -euo pipefail
# An installer for EvenBetter rEFInd by MorgenWebDigital

#Check if root
[[ $EUID -ne 0 ]] && echo "This script must be run as root." && exit 1

clear

#Check if git is installed
if ! command -v git &> /dev/null
then
    echo "git not found, please install it."
    echo "On ubuntu it can be done with 'sudo apt install git'"
    exit 1
fi

#Clone the theme
theme_source_directory=$(mktemp -d -t evenbetter-refind-XXXXXX)
cd "${theme_source_directory}"
echo -n "Downloading EvenBetter rEFInd to ${theme_source_directory}"
git clone https://github.com/MorgenWebDigital/EvenBetter-Refind.git &> /dev/null
echo " - [DONE]"

#Useful formatting tags
bold=$(tput bold)
normal=$(tput sgr0)
refind_dir_default="/boot/efi/EFI/refind"
#Set install path
echo "Enter rEFInd install location"
read -e -p "Default - ${bold}${refind_dir_default}${normal}: " refind_dir
if test -z "$refind_dir"; then
refind_dir="${refind_dir_default}" # If empty string passed above, set to default
fi
if [[ ! -d "${refind_dir}" ]]; then
    echo "Specified rEFInd install location does not exist. Aborting install."
    exit 1
fi
# remove trailing slash
refind_dir=$(realpath -s "$refind_dir")

#Set icon size
echo "Pick an icon size: (larger icons look better on bigger and denser displays)"
read -p "${bold}1: small (128px-48px)${normal}, 2: medium (256px-96px), 3: large (384px-144px), 4: extra-large (512px-192px): " size_select
if test -z "$size_select";
then
    size_select=1
fi
case "$size_select" in
    1)
        size_big="128"
        size_small="48"
        ;;
    2)
        size_big="256"
        size_small="96"
        ;;
    3)
        size_big="384"
        size_small="144"
        ;;
    4)
        size_big="512"
        size_small="192"
        ;;
    *)
        echo "Incorrect choice. Exiting."
        exit 1
        ;;
esac
echo
echo "Selected size - ${bold}big icons: $size_big px, small icons: $size_small px${normal}"
echo

#Set theme color
echo "Select a theme color"
read -p "${bold}1: light${normal}, 2: dark: " theme_select
if test -z "$theme_select";
then
    theme_select=1
fi
case "$theme_select" in
    1)
        theme_name="light"
        theme_path=""
        ;;
    2)
        theme_name="dark"
        theme_path="_dark"
        ;;
    *)
        echo "Incorrect choice. Exiting."
        exit 1
        ;;
esac
echo
echo "Selected theme - ${bold}$theme_name${normal}"
echo
#Uncomment relevant lines from src/theme.conf
echo -n "Generating theme file theme.conf"
cd EvenBetter-Refind
cp src/theme.conf theme.conf
sed -i "s/#icons_dir themes\/refind-theme-regular\/icons\/$size_big-$size_small/icons_dir themes\/refind-theme-regular\/icons\/$size_big-$size_small/" theme.conf
sed -i "s/#big_icon_size $size_big/big_icon_size $size_big/" theme.conf
sed -i "s/#small_icon_size $size_small/small_icon_size $size_small/" theme.conf
sed -i "s/#banner themes\/refind-theme-regular\/icons\/$size_big-$size_small\/bg$theme_path.png/banner themes\/refind-theme-regular\/icons\/$size_big-$size_small\/bg$theme_path.png/" theme.conf
sed -i "s/#selection_big themes\/refind-theme-regular\/icons\/$size_big-$size_small\/selection$theme_path-big.png/selection_big themes\/refind-theme-regular\/icons\/$size_big-$size_small\/selection$theme_path-big.png/" theme.conf
sed -i "s/#selection_small themes\/refind-theme-regular\/icons\/$size_big-$size_small\/selection$theme_path-small.png/selection_small themes\/refind-theme-regular\/icons\/$size_big-$size_small\/selection$theme_path-small.png/" theme.conf
cd ..
echo " - [DONE]"

#Clean up
echo -n "Removing unused directories"
rm -rf EvenBetter-Refind/{src,.git}
rm -rf EvenBetter-Refind/install.sh
echo " - [DONE]"

#Remove previous installs
echo -n "Deleting older installed versions (if any)"
rm -rf "${refind_dir}"/{regular-theme,refind-theme-regular}
rm -rf "${refind_dir}"/themes/{regular-theme,refind-theme-regular}
echo " - [DONE]"

#Copy theme setup folders
echo -n "Copying theme to ${refind_dir}/themes"
mkdir -p "${refind_dir}/themes"
cp -r EvenBetter-Refind "${refind_dir}/themes/refind-theme-regular"
echo " - [DONE]"

#Install ISO9660 driver for booting Live-ISOs and USB sticks
echo -n "Installing ISO9660 driver"
mkdir -p "${refind_dir}/drivers_x64"
driver_src=""
driver_src=$(find /usr/share/refind -name "iso9660_x64.efi" 2>/dev/null | head -1) || true
if [ -n "$driver_src" ]; then
    cp "$driver_src" "${refind_dir}/drivers_x64/iso9660_x64.efi"
    echo " - [DONE]"
else
    echo " - [SKIPPED: iso9660_x64.efi not found]"
fi

#Edit refind.conf - remove older themes
echo -n "Removing old themes from refind.conf"
echo
echo
read -p "Do you have a secondary config file to preserve? Default: N (y/${bold}N${normal}): " config_confirm
if test -z "$config_confirm";
then
    config_confirm="n"
fi
case "$config_confirm" in
    y|Y)
        read -p "Enter the name of the config file to be preserved in full eg: manual.conf: " configname
        # Checking for enter key. If so it has the same effect having no files to preserve.
        if [[ $configname == "" ]]; then
	configname='^#'
	fi
        #Excludes line with entered config file then ^\s*include matches lines starting with any nuber of spaces and then include.
        sed --in-place=".bak" "/$configname/! s/^\s*include/# (disabled) include/" "${refind_dir}"/refind.conf
        ;;
    n|N)
        # ^\s*include matches lines starting with any nuber of spaces and then include.
        sed --in-place=".bak" 's/^\s*include/# (disabled) include/' "${refind_dir}"/refind.conf
        ;;
    *)
        ;;
esac
echo " - [DONE]"

#Edit refind.conf - comment out built-in example menuentries
echo -n "Commenting out example menuentries from refind.conf"
sed --in-place \
    -e '/^menuentry Linux {/,/^}/s/^/#/' \
    -e '/^menuentry "Arch Linux" {/,/^}/s/^/#/' \
    -e '/^menuentry Ubuntu {/,/^}/s/^/#/' \
    -e '/^menuentry "ELILO" {/,/^}/s/^/#/' \
    -e '/^menuentry "Windows 7" {/,/^}/s/^/#/' \
    -e '/^menuentry "Windows via shell script" {/,/^}/s/^/#/' \
    -e '/^menuentry "My macOS" {/,/^}/s/^/#/' \
    -e '/^menuentry "macOS via BootNext" {/,/^}/s/^/#/' \
    "${refind_dir}"/refind.conf
echo " - [DONE]"

#Edit refind.conf - remove all previous EvenBetter-Refind entries to avoid duplicates on reinstall
echo -n "Cleaning previous EvenBetter rEFInd entries from refind.conf"
sed --in-place '/# Load EvenBetter rEFInd theme/,/^$/d' "${refind_dir}"/refind.conf
sed --in-place '/fold_linux_kernels/d' "${refind_dir}"/refind.conf
sed --in-place '/^dont_scan_files /d' "${refind_dir}"/refind.conf
sed --in-place '/dont_scan_dirs EFI\/boot/d' "${refind_dir}"/refind.conf
sed --in-place '/also_scan_dirs/d' "${refind_dir}"/refind.conf
sed --in-place '/^scan_all_linux_kernels/d' "${refind_dir}"/refind.conf
sed --in-place '/^scanfor /d' "${refind_dir}"/refind.conf
# Remove leftover manual menuentry blocks from previous installs
sed --in-place '/^menuentry "Ubuntu" {/,/^}/d' "${refind_dir}"/refind.conf
sed --in-place '/^menuentry "Windows" {/,/^}/d' "${refind_dir}"/refind.conf
sed --in-place '/^menuentry "VaultOS" {/,/^}/d' "${refind_dir}"/refind.conf
echo " - [DONE]"

#Edit refind.conf - patch scanfor to enable all scan types
echo -n "Patching refind.conf scanfor"
sed --in-place 's/^#\?\s*scanfor\s.*/scanfor manual,external,internal,optical/' "${refind_dir}"/refind.conf
echo " - [DONE]"

#Edit refind.conf - add new theme and fix duplicate entries
echo -n "Updating refind.conf"
printf '\n# Load EvenBetter rEFInd theme\ninclude themes/refind-theme-regular/theme.conf\n\n# Hide duplicate boot entries\nfold_linux_kernels true\ndont_scan_files shimx64.efi,mmx64.efi,fbx64.efi,bootx64.efi\ndont_scan_dirs EFI/boot\n\n# Auto-scan /live on external volumes (VaultOS)\nalso_scan_dirs +live\n' | tee -a "${refind_dir}"/refind.conf &> /dev/null
echo " - [DONE]"

#Clean up - remove download
read -p "Delete download? (${bold}Y${normal}/n): " del_confirm
if test -z "$del_confirm";
then
    del_confirm="y"
fi
case "$del_confirm" in
    y|Y)
        echo -n "Deleting download folder ${theme_source_directory}"
        rm -r "${theme_source_directory}"
        echo " - [DONE]"
        ;;
    *)
        ;;
esac

echo "Thank you for installing EvenBetter rEFInd."
echo "NOTE: If you're not getting your full resolution or have color issues then try disabling the CSM in your UEFI settings."
