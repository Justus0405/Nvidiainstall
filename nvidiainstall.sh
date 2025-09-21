#!/usr/bin/env bash
#
# Automated NVIDIA Driver Installer for Arch Linux
#
# Author: Justus0405
# Date: 12.10.2024
# License: MIT

export scriptVersion="2.2"

### COLOR CODES ###
export black="\e[1;30m"
export red="\e[1;31m"
export green="\e[1;32m"
export yellow="\e[1;33m"
export blue="\e[1;34m"
export purple="\e[1;35m"
export cyan="\e[1;36m"
export lightGray="\e[1;37m"
export gray="\e[1;90m"
export lightRed="\e[1;91m"
export lightGreen="\e[1;92m"
export lightYellow="\e[1;93m"
export lightBlue="\e[1;94m"
export lightPurple="\e[1;95m"
export lightCyan="\e[1;96m"
export white="\e[1;97m"
export bold="\e[1m"
export faint="\e[2m"
export italic="\e[3m"
export underlined="\e[4m"
export blinking="\e[5m"
export reset="\e[0m"

### FUNCTIONS ###
logMessage() {
    local type="$1"
    local message="$2"
    case "${type}" in
    "info" | "INFO")
        echo -e "${gray}[${cyan}i${gray}]${reset} ${message}"
        ;;
    "done" | "DONE")
        echo -e "${gray}[${green}✓${gray}]${reset} ${message}"
        exit 0
        ;;
    "warning" | "WARNING")
        echo -e "${gray}[${red}!${gray}]${reset} ${message}"
        ;;
    "error" | "ERROR")
        echo -e "${red}ERROR${reset}: ${message}"
        exit 1
        ;;
    *)
        echo -e "[UNDEFINED] ${message}"
        ;;
    esac
}

checkSudo() {
    # Checks EUID to see if the script is running as sudo.

    if [[ "$EUID" != 0 ]]; then
        logMessage "error" "This script must be run as root. Use sudo."
    fi

    # Looks if the root user is permitted to execute ommands as sudo,
    # this is needed because executing commands with privilges in a bash script is a bit weird.
    # Or it may be just a skill issue. ¯\_(ツ)_/¯

    usermod -aG wheel root || logMessage "error" "Failed to add root to the wheel group."
}

checkAurHelper() {
    # Checking if yay is installed.

    if command -v yay >/dev/null 2>&1; then
        logMessage "info" "Yay is installed."
    else
        logMessage "info" "Yay is not installed."
        installAurHelper
    fi
}

installAurHelper() {
    # Installing yay as aur helper for the executing user.
    # Makepkg crashes if its not running as a non-root user

    targetUser="${SUDO_USER:-$(whoami)}"

    logMessage "info" "Installing yay..."
    sudo -u "${targetUser}" bash <<'EOF'
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
EOF
    logMessage "info" "Sucessfully installed yay."
}

aurHelperInstall() {
    # Install with yay using a non-root user.
    # This is because yay complains when running as root.

    local packages="$1"
    local targetUser="${SUDO_USER:-$(whoami)}"

    # shellcheck disable=SC2086
    sudo -u "${targetUser}" yay -S --needed --noconfirm ${packages}
}

aurHelperUninstall() {
    # Uninstall with yay using a non-root user.
    # This is because yay complains when running as root.

    local packages="$1"
    local targetUser="${SUDO_USER:-$(whoami)}"

    # shellcheck disable=SC2086
    sudo -u "${targetUser}" yay -R --noconfirm ${packages}
}

checkNvidia() {
    # Detect NVIDIA GPU and decide driver package.
    # Index: https://www.techpowerup.com/gpu-specs/

    # Default values.
    gpuGen="Unknown"
    gpuDriver="Unknown"

    gpuInfo=$(lspci -nn | grep -i 'VGA.*NVIDIA')
    gpuName=$(echo "${gpuInfo}" | sed -E 's/.*NVIDIA Corporation //; s/ \[.*//')

    case "${gpuName}" in
    *"GB10"* | *"GB20"*)
        gpuGen="Blackwell"
        gpuDriver="manual"
        ;;
    *"GH10"*)
        gpuGen="Hopper"
        gpuDriver="manual"
        ;;
    *"AD10"*)
        gpuGen="Ada Lovelace"
        gpuDriver="manual"
        ;;
    *"GA10"*)
        gpuGen="Ampere"
        gpuDriver="manual"
        ;;
    *"TU10"* | *"TU11"*)
        gpuGen="Turing"
        gpuDriver="manual"
        ;;
    *"GV10"*)
        gpuGen="Volta"
        gpuDriver="nvidia-dkms"
        ;;
    *"GP10"*)
        gpuGen="Pascal"
        gpuDriver="nvidia-dkms"
        ;;
    *"GM10"* | *"GM20"*)
        gpuGen="Maxwell"
        gpuDriver="nvidia-dkms"
        ;;
    *"EXK107"* | *"GK10"* | *"GK11"* | *"GK18"* | *"GK20"* | *"GK21"*)
        gpuGen="Kepler"
        gpuDriver="nvidia-470xx-dkms"
        ;;
    *"EXMF1"* | *"GF10"* | *"GF11"*)
        gpuGen="Fermi"
        gpuDriver="nvidia-390xx-dkms"
        ;;
    *"Kal-El"* | *"Tegra 2"* | *"Wayne"*)
        gpuGen="VLIW Vec4"
        gpuDriver="nvidia-390xx-dkms"
        ;;
    *"C77"* | *"C78"* | *"C79"* | *"C7A"* | *"G80"* | *"G84"* | *"G86"* | *"G92"* | *"G94"* | *"G96"* | *"G98"* | *"ION"* | *"C87"* | *"C89"* | *"GT20"* | *"GT21"*)
        # C7A-ION, NVIDIA ION
        gpuGen="Tesla"
        gpuDriver="nvidia-340xx-dkms"
        ;;
    *"C51"* | *"C61"* | *"C67"* | *"C68"* | *"C73"* | *"G70"* | *"G71"* | *"G72"* | *"G73"* | *"NV40"* | *"NV41"* | *"NV42"* | *"NV43"* | *"NV44"* | *"NV45"* | *"NV48"* | *"RSX"*)
        gpuGen="Curie"
        gpuDriver="unsupported"
        ;;
    *"NV30"* | *"NV31"* | *"NV34"* | *"NV35"* | *"NV36"* | *"NV37"* | *"NV38"* | *"NV39"*)
        gpuGen="Rankine"
        gpuDriver="unsupported"
        ;;
    *"NV20"* | *"NV25"* | *"NV28"* | *"NV2A"*)
        gpuGen="Kelvin"
        gpuDriver="unsupported"
        ;;
    *"Crush1"* | *"NV10"* | *"NV11"* | *"NV15"* | *"NV17"* | *"NV18"*)
        gpuGen="Celsius"
        gpuDriver="unsupported"
        ;;
    *"NV4"* | *"NV5"*)
        gpuGen="Fahrenheit"
        gpuDriver="unsupported"
        ;;
    *)
        gpuGen="Unknown"
        gpuDriver="unidentified"
        ;;
    esac

    if [[ ${gpuDriver} == "unsupported" ]]; then
        logMessage "error" "${gpuGen} is not supported anymore."
    fi

    if [[ ${gpuDriver} == "unidentified" ]]; then
        chooseGpuDriver
    fi

    if [[ ${gpuDriver} == "manual" ]]; then
        chooseProprietaryOrOpen
    fi

    if [[ -z ${gpuName} ]]; then
        gpuName="Unkown"
    fi
}

checkInstalledDriver() {
    # This function checks if any nvidia drivers are installed and serves them
    # inside a variable in order for the uninstallation step to know which packages to remove.
    # Is also used in showDeviceInformation().

    legacyDriver=$(pacman -Qq | grep -E '^nvidia$')
    installedDriver=$(pacman -Qq | grep -E 'nvidia-(dkms|open-dkms|470xx-dkms|390xx-dkms|340xx-dkms)')

    if [[ -n ${legacyDriver} ]]; then
        installedDriver="nvidia"
    fi

    if [[ -z ${installedDriver} ]]; then
        installedDriver="none"
    fi
}

chooseGpuDriver() {
    # In case the script couldnt identify the needed driver,
    # ask the user which one they want to install.

    clear
    echo -e "\t┌──────────────────────────────────────────────────┐"
    echo -e "\t│    / \                                           │"
    echo -e "\t│   / | \     We could not identify your GPU.      │"
    echo -e "\t│  /  #  \    Please select which driver you       │"
    echo -e "\t│ /_______\   want to manage.                      │"
    echo -e "\t│                                                  │"
    echo -e "\t│ [!] Curie and older are not supported anymore!   │"
    echo -e "\t├──────────────────────────────────────────────────┤"
    echo -e "\t│                                                  │"
    echo -e "\t│ [1] nvidia-open-dkms          [Turing and newer] │"
    echo -e "\t│ [2] nvidia-dkms              [Maxwell and newer] │"
    echo -e "\t│ [3] nvidia-470xx-dkms                   [Kepler] │"
    echo -e "\t│ [4] nvidia-390xx-dkms                    [Fermi] │"
    echo -e "\t│ [5] nvidia-340xx-dkms                    [Tesla] │"
    echo -e "\t│                                                  │"
    echo -e "\t├──────────────────────────────────────────────────┤"
    echo -e "\t│ [0] Quit                                         │"
    echo -e "\t└──────────────────────────────────────────────────┘"
    echo -e ""
    echo -e "\t${green}Choose a menu option using your keyboard [1,2,...,0]${reset}"

    read -rsn1 option

    case "${option}" in
    "1")
        gpuDriver="nvidia-open-dkms"
        ;;
    "2")
        gpuDriver="nvidia-dkms"
        ;;
    "3")
        gpuDriver="nvidia-470xx-dkms"
        ;;
    "4")
        gpuDriver="nvidia-390xx-dkms"
        ;;
    "5")
        gpuDriver="nvidia-340xx-dkms"
        ;;
    "0")
        exitScript "Quit."
        ;;
    *)
        chooseGpuDriver
        ;;
    esac
}

chooseProprietaryOrOpen() {
    # When the detected gpu supports either the nvidia-dkms or nvidia-open-dkms package.
    # Let the user choose

    clear
    echo -e "\t┌──────────────────────────────────────────────────┐"
    echo -e "\t│    / \                                           │"
    echo -e "\t│   / | \     Your GPU supports both proprietary   │"
    echo -e "\t│  /  #  \    and open-source driver packages.     │"
    echo -e "\t│ /_______\   Which one do you want to install?    │"
    echo -e "\t│                                                  │"
    echo -e "\t├──────────────────────────────────────────────────┤"
    echo -e "\t│                                                  │"
    echo -e "\t│ [1] nvidia-open-dkms                             │"
    echo -e "\t│ [2] nvidia-dkms                                  │"
    echo -e "\t│                                                  │"
    echo -e "\t├──────────────────────────────────────────────────┤"
    echo -e "\t│ [0] Quit                                         │"
    echo -e "\t└──────────────────────────────────────────────────┘"
    echo -e ""
    echo -e "\t${green}Choose a menu option using your keyboard [1,2,...,0]${reset}"

    read -rsn1 option

    case "${option}" in
    "1")
        gpuDriver="nvidia-open-dkms"
        ;;
    "2")
        gpuDriver="nvidia-dkms"
        ;;
    "0")
        exitScript "Quit."
        ;;
    *)
        chooseProprietaryOrOpen
        ;;
    esac
}

backupConfig() {
    # Create a copy of the given file with the .bak extention.

    local config="$1"
    logMessage "info" "Creating backup of ${config}"
    sudo cp "${config}" "${config}.bak"
    logMessage "info" "Backup of ${config} created."
}

### TERMINAL INTERFACE ###
showMenu() {
    # This is the main function which renders the selection menu.
    # Waiting for the input of the user for running further functions.
    # The function runs itself at the end ensuring coming back to it
    # when the selected option finished running.

    clear
    echo -e "\t┌──────────────────────────────────────────────────┐"
    echo -e "\t│                                                  │"
    echo -e "\t│ Choose option:                                   │"
    echo -e "\t│                                                  │"
    echo -e "\t│ [1] Install                                      │"
    echo -e "\t│ [2] Uninstall                                    │"
    echo -e "\t│ [3] Device Information                           │"
    echo -e "\t│ [4] About Nvidiainstall                          │"
    echo -e "\t│                                                  │"
    echo -e "\t├──────────────────────────────────────────────────┤"
    echo -e "\t│ [0] Quit                                         │"
    echo -e "\t└──────────────────────────────────────────────────┘"
    echo -e ""
    echo -e "\t${green}Choose a menu option using your keyboard [1,2,...,0]${reset}"

    read -rsn1 option

    case "${option}" in
    "1")
        if [[ ${installedDriver} == "none" ]]; then
            confirmInstallation
        else
            showDriverInstalled
        fi
        ;;
    "2")
        if [[ ${installedDriver} == "none" ]]; then
            showNoDriverInstalled
        else
            confirmUninstallation
        fi
        ;;
    "3")
        showDeviceInformation
        ;;
    "4")
        showAbout
        ;;
    "0")
        exitScript "Quit."
        ;;
    esac

    # Loop back to menu after an option is handled.
    showMenu
}

showDeviceInformation() {
    # Show information about gpu name, generation and recommended driver.

    clear
    echo -e ""
    echo -e "\tDevice Information:"
    echo -e ""
    echo -e "\tDetected GPU: ${gpuName}"
    echo -e "\tGeneration: ${gpuGen}"
    echo -e "\tInstalled Driver: ${installedDriver}"
    echo -e ""
    echo -e "\tSelected Driver: ${gpuDriver}"
    echo -e ""
    echo -e "\t${green}Press any button to return${reset}"

    read -rsn1 option

    case "${option}" in
    *) ;;

    esac
}

showAbout() {
    # Just a bit of info.
    # Also fetches the list of contributers regarding this project and displays them in a list.

    githubResponse=$(curl -s "https://api.github.com/repos/Justus0405/Nvidiainstall/contributors")
    clear
    echo -e ""
    echo -e "\tAbout Nvidiainstall:"
    echo -e ""
    echo -e "\tVersion: ${scriptVersion}"
    echo -e "\tAuthor : Justus0405"
    echo -e "\tSource : https://github.com/Justus0405/Nvidiainstall"
    echo -e "\tLicense: MIT"
    echo -e "\tContributors:"

    echo "${githubResponse}" | grep '"login":' | awk -F '"' '{print $4}' | while read -r contributors; do
        echo -e "\t\t\e[0;35m${contributors}\e[m"
    done

    echo -e ""
    echo -e "\t${green}Press any button to return${reset}"

    read -rsn1 option

    case "${option}" in
    *) ;;

    esac
}

showDriverInstalled() {
    # Screen for when the user wants to install nvidia drivers but others are found.

    clear
    echo -e "\t┌──────────────────────────────────────────────────┐"
    echo -e "\t│    / \                                           │"
    echo -e "\t│   / | \     You already have other NVIDIA dkms   │"
    echo -e "\t│  /  #  \    packages Installed!                  │"
    echo -e "\t│ /_______\                                        │"
    echo -e "\t└──────────────────────────────────────────────────┘"
    echo -e ""
    echo -e "\tInstalled Package: ${installedDriver}"
    echo -e ""
    echo -e "\t${green}Press any button to return${reset}"

    read -rsn1 option

    case "${option}" in
    *) ;;

    esac
}

showNoDriverInstalled() {
    # Screen for when the user wants to uninstall nvidia drivers but none could be found.

    clear
    echo -e "\t┌──────────────────────────────────────────────────┐"
    echo -e "\t│    / \                                           │"
    echo -e "\t│   / | \     We could not find any installed      │"
    echo -e "\t│  /  #  \    NVIDIA dkms packages!                │"
    echo -e "\t│ /_______\                                        │"
    echo -e "\t└──────────────────────────────────────────────────┘"
    echo -e ""
    echo -e "\t${green}Press any button to return${reset}"

    read -rsn1 option

    case "${option}" in
    *) ;;

    esac
}

### INSTALLATION STEPS ###
confirmInstallation() {
    # Ask the user for consent :3

    clear
    echo -e "\t┌──────────────────────────────────────────────────┐"
    echo -e "\t│    / \                                           │"
    echo -e "\t│   / | \     This script will install NVIDIA      │"
    echo -e "\t│  /  #  \    drivers and modify system            │"
    echo -e "\t│ /_______\   configurations.                      │"
    echo -e "\t│                                                  │"
    echo -e "\t│ [!] Proceed with caution!                        │"
    echo -e "\t└──────────────────────────────────────────────────┘"
    echo -e ""
    read -rp "Do you want to install ${gpuDriver}? (y/N): " confirm
    case "${confirm}" in
    [yY][eE][sS] | [yY])
        echo -e "${green}Installing ${gpuDriver}...${reset}"
        installationSteps
        ;;
    *)
        exitScript "Installation cancelled."
        ;;
    esac
}

installationSteps() {
    # Just a simple function handling each steps because
    # handling it everywere else looked ugly.

    # Step 1
    updateSystem

    # Step 2
    checkKernelHeaders

    # Step 3
    installNvidiaPackages

    # Step 4
    configureMkinitcpio

    # Step 5
    configureModprobe

    # Step 6
    configureGrubDefault

    # Step 7
    regenerateInitramfs

    # Step 8
    updateGrubConfig

    # Step 9
    confirmReboot
}

updateSystem() {
    # Updating system because why not?

    logMessage "info" "Updating System..."
    sudo pacman -Syyu || logMessage "error" "Could not update system, are you connected to the internet?"
    logMessage "info" "Updated System."
}

checkKernelHeaders() {
    # Check the installed kernel and installs the associated headers.
    # this is needed for the kernel to load the nvidia modules.

    logMessage "info" "Installing Kernel Modules..."
    kernel=$(uname -r)
    if [[ "${kernel}" == *"zen"* ]]; then
        # Zen
        logMessage "info" "Detected Kernel: linux-zen"
        sudo pacman -S --needed --noconfirm linux-zen-headers || logMessage "error" "Could not install kernel modules."
    elif [[ "${kernel}" == *"lts"* ]]; then
        # LTS
        logMessage "info" "Detected Kernel: linux-lts"
        sudo pacman -S --needed --noconfirm linux-lts-headers || logMessage "error" "Could not install kernel modules."
    elif [[ "$kernel" == *"hardened"* ]]; then
        # "HARDENED" ~Debitor
        logMessage "info" "Detected Kernel: linux-hardened"
        sudo pacman -S --needed --noconfirm linux-hardened-headers || logMessage "error" "Could not install kernel modules."
    else
        # Regular Linux Kernel
        logMessage "info" "Detected Kernel: linux"
        sudo pacman -S --needed --noconfirm linux-headers || logMessage "error" "Could not install kernel modules."
    fi
    logMessage "info" "Installed Kernel Modules."
}

installNvidiaPackages() {
    # Install the nvidia drivers and needed dependencies, if not present.

    logMessage "info" "Identified Generation: ${gpuGen}"
    logMessage "info" "Installing ${gpuDriver} and dependencies..."

    case "${gpuDriver}" in
    "nvidia-open-dkms")
        sudo pacman -S --needed --noconfirm nvidia-open-dkms nvidia-utils opencl-nvidia nvidia-settings libglvnd lib32-nvidia-utils lib32-opencl-nvidia egl-wayland || logMessage "error" "Could not install NVIDIA packages. Do you have multilib enabled?"
        ;;
    "nvidia-dkms")
        sudo pacman -S --needed --noconfirm nvidia-dkms nvidia-utils opencl-nvidia nvidia-settings libglvnd lib32-nvidia-utils lib32-opencl-nvidia egl-wayland || logMessage "error" "Could not install NVIDIA packages. Do you have multilib enabled?"
        ;;
    "nvidia-470xx-dkms")
        checkAurHelper
        aurHelperInstall "nvidia-470xx-dkms nvidia-470xx-utils opencl-nvidia-470xx nvidia-470xx-settings libglvnd lib32-nvidia-470xx-utils lib32-opencl-nvidia-470xx egl-wayland" || logMessage "error" "Could not install NVIDIA packages. Do you have multilib enabled?"
        ;;
    "nvidia-390xx-dkms")
        checkAurHelper
        aurHelperInstall "nvidia-390xx-dkms nvidia-390xx-utils opencl-nvidia-390xx nvidia-390xx-settings libglvnd lib32-nvidia-390xx-utils lib32-opencl-nvidia-390xx egl-wayland" || logMessage "error" "Could not install NVIDIA packages. Do you have multilib enabled?"
        ;;
    "nvidia-340xx-dkms")
        checkAurHelper
        aurHelperInstall "nvidia-340xx-dkms nvidia-340xx-utils opencl-nvidia-340xx libglvnd lib32-nvidia-340xx-utils lib32-opencl-nvidia-340xx egl-wayland" || logMessage "error" "Could not install NVIDIA packages. Do you have multilib enabled?"
        # The nvidia-340xx-settings fails to install because its denied access to /usr/local/share/man/ ...
        ;;
    esac

    logMessage "info" "Installed NVIDIA packages and dependencies."
}

configureMkinitcpio() {
    # This was just pure insanity to impliment with the intent
    # of not breaking previous configurations. (But it works :3)
    # This is for adding the nvidia modules to the /etc/mkinitcpio.conf file.
    # Firstly it creates a backup of the original file.
    # Then it removes any lines that are commented out and contain nothing. (Not necessary but pretty)
    # Then removes any previously added nvidia modules, this could fix previously wrong configurations.
    # Ensures the () dont have any spaces at the beginning and at the end.
    # Then the modules get added in the correct formatting and order without deleting previous modules not related to nvidia.
    # At the end the kms hook gets removed, which is a recommeded step because it disables any other non-nvidia gpu.

    local config="/etc/mkinitcpio.conf"
    backupConfig "${config}"
    logMessage "info" "Configuring ${config}..."

    # Remove any lines that are commented out and contain nothing
    logMessage "info" "Cleaning up ${config}..."
    sudo sed -i '/^#/d;/^$/d' "${config}"

    # Remove any occurrences of nvidia-related modules in case some already exist.
    # We dont want double arguments.
    sudo sed -i 's/\b\(nvidia\|nvidia_modeset\|nvidia_uvm\|nvidia_drm\)\b//g' "${config}"

    # Ensure exactly one space between words and no space after '(' or before ')'
    logMessage "info" "Cleaning up brackets..."
    sudo sed -i 's/ ( /(/g; s/ )/)/g; s/( */(/; s/ *)/)/; s/ \+/ /g' "${config}"

    # Determine if either installing nvidia-340xx-dkms or later
    logMessage "info" "Adding NVIDIA modules..."
    if [[ ${gpuDriver} == "nvidia-340xx-dkms" ]]; then
        # Add nvidia nvidia_uvm at the end of HOOKS=()
        sudo sed -i 's/^MODULES=(\([^)]*\))/MODULES=(\1 nvidia nvidia_uvm)/' "${config}"
    else
        # Add nvidia nvidia_modeset nvidia_uvm nvidia_drm at the end of HOOKS=()
        sudo sed -i 's/^MODULES=(\([^)]*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' "${config}"
    fi

    # Ensure exactly one space between words and no space after '(' or before ')'
    logMessage "info" "Cleaning up brackets..."
    sudo sed -i 's/ ( /(/g; s/ )/)/g; s/( */(/; s/ *)/)/; s/ \+/ /g' "${config}"

    # Remove kms from HOOKS=()
    logMessage "info" "Removing kms hook..."
    sudo sed -i 's/\bkms \b//g' "${config}"

    logMessage "info" "Configured ${config}."
}

configureModprobe() {
    # "options nvidia_drm modeset=1 fbdev=1" straight from Hyprland Wiki.
    # This isnt needed but still good for compatibility.

    local config="/etc/modprobe.d/nvidia.conf"
    backupConfig "${config}"
    logMessage "info" "Configuring ${config}..."

    echo "options nvidia_drm modeset=1 fbdev=1" | sudo tee "${config}" >/dev/null
    logMessage "info" "Configured ${config}."
}

configureGrubDefault() {
    # Function to add "nvidia_drm.modeset=1" to /etc/default/grub.
    # The weird sed syntax ensures that the argument only gets added
    # and not replacing the line, keeping previous configuration safe.

    local config="/etc/default/grub"
    backupConfig "${config}"
    logMessage "info" "Configuring ${config}..."

    # Remove nvidia_drm.modeset=1 from GRUB_CMDLINE_LINUX in case it exists.
    # We dont want double arguments.
    sudo sed -i 's/nvidia_drm\.modeset=1//g' "${config}"

    # Add nvidia_drm.modeset=1 to GRUB_CMDLINE_LINUX
    logMessage "info" "Adding NVIDIA modeset to ${config}..."
    sudo sed -i '/GRUB_CMDLINE_LINUX_DEFAULT=/!b;/nvidia_drm.modeset=1/!s/\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)/\1 nvidia_drm.modeset=1/' "${config}"
    logMessage "info" "Configured ${config}."
}

regenerateInitramfs() {
    # Regenerates the initramfs to load the nvidia modules.
    # Prepare for high CPU usage.

    logMessage "info" "Regenerating initramfs... (this may take a while)"
    sudo mkinitcpio -P || logMessage "error" "Failed to regenerate the initramfs."
    logMessage "info" "Regernerated initramfs."
}

updateGrubConfig() {
    # Updates the grub config at /boot/grub/grub.cfg
    # After /etc/default/grub was changed

    local config="/boot/grub/grub.cfg"
    backupConfig "${config}"
    logMessage "info" "Configuring ${config}..."

    sudo grub-mkconfig -o "${config}" || logMessage "error" "Failed to update ${config}."
    logMessage "info" "Configured ${config}"
}

confirmReboot() {
    # Asks the user to reboot to apply changes.

    echo -e ""
    echo -e "${green}Action complete.${reset}"
    read -rp "Would you like to reboot now? (y/N): " rebootNow
    case "${rebootNow}" in
    [yY][eE][sS] | [yY])
        sudo reboot now
        ;;
    *)
        logMessage "info" "Please reboot your system later to apply changes."
        echo -e ""
        echo -e "\t${green}Press any button to return${reset}"

        read -rsn1 option

        case "${option}" in
        *) ;;

        esac
        ;;
    esac
}

### UNINSTALLATION STEPS ###
confirmUninstallation() {
    # Same as confirmInstallation

    clear
    echo -e "\t┌──────────────────────────────────────────────────┐"
    echo -e "\t│    / \                                           │"
    echo -e "\t│   / | \     This script will ${red}uninstall${reset} NVIDIA    │"
    echo -e "\t│  /  #  \    drivers and modify system            │"
    echo -e "\t│ /_______\   configurations.                      │"
    echo -e "\t│                                                  │"
    echo -e "\t│ [!] Proceed with caution!                        │"
    echo -e "\t└──────────────────────────────────────────────────┘"
    echo -e ""
    read -rp "Do you want to uninstall ${installedDriver}? (y/N): " confirm
    case "${confirm}" in
    [yY][eE][sS] | [yY])
        echo -e "${green}Uninstalling ${installedDriver}...${reset}"
        uninstallationSteps
        ;;
    *)
        exitScript "Uninstallation cancelled."
        ;;
    esac
}

uninstallationSteps() {
    # Just a simple function handling each steps because
    # handling it everywere else looked ugly, Part 2.

    # Step 1
    removeNvidiaPackages

    # Step 2
    removeMkinitcpio

    # Step 3
    removeModprobe

    # Step 4
    removeGrubDefault

    # Step 5
    regenerateInitramfs

    # Step 6
    updateGrubConfig

    # Step 7
    confirmReboot
}

removeNvidiaPackages() {
    # Uninstall the nvidia drivers, configs and unused dependencies.

    logMessage "info" "Uninstalling ${installedDriver} and dependencies..."

    case "${installedDriver}" in
    "nvidia")
        sudo pacman -R --noconfirm nvidia nvidia-utils opencl-nvidia nvidia-settings lib32-nvidia-utils lib32-opencl-nvidia || logMessage "error" "Could not uninstall NVIDIA packages."
        ;;
    "nvidia-open-dkms")
        sudo pacman -R --noconfirm nvidia-open-dkms nvidia-utils opencl-nvidia nvidia-settings lib32-nvidia-utils lib32-opencl-nvidia || logMessage "error" "Could not uninstall NVIDIA packages."
        ;;
    "nvidia-dkms")
        sudo pacman -R --noconfirm nvidia-dkms nvidia-utils opencl-nvidia nvidia-settings lib32-nvidia-utils lib32-opencl-nvidia || logMessage "error" "Could not uninstall NVIDIA packages."
        ;;
    "nvidia-470xx-dkms")
        checkAurHelper
        aurHelperUninstall "nvidia-470xx-dkms nvidia-470xx-utils opencl-nvidia-470xx nvidia-470xx-settings lib32-nvidia-470xx-utils lib32-opencl-nvidia-470xx" || logMessage "error" "Could not uninstall NVIDIA packages."
        ;;
    "nvidia-390xx-dkms")
        checkAurHelper
        aurHelperUninstall "nvidia-390xx-dkms nvidia-390xx-utils opencl-nvidia-390xx nvidia-390xx-settings lib32-nvidia-390xx-utils lib32-opencl-nvidia-390xx" || logMessage "error" "Could not uninstall NVIDIA packages."
        ;;
    "nvidia-340xx-dkms")
        checkAurHelper
        aurHelperUninstall "nvidia-340xx-dkms nvidia-340xx-utils opencl-nvidia-340xx lib32-nvidia-340xx-utils lib32-opencl-nvidia-340xx" || logMessage "error" "Could not uninstall NVIDIA packages."
        ;;
    esac

    logMessage "info" "Uninstalled NVIDIA packages and dependencies."
}

removeMkinitcpio() {
    # Same as the configureMkinitcpio() function but without adding the nvidia modules.
    # Also adds back the kms hook.

    local config="/etc/mkinitcpio.conf"
    backupConfig "${config}"
    logMessage "info" "Configuring ${config}..."

    # Remove any lines that are commented out and contain nothing
    logMessage "info" "Cleaning up ${config} structure..."
    sudo sed -i '/^#/d;/^$/d' "${config}"

    # Remove any occurrences of nvidia-related modules
    logMessage "info" "Removing NVIDIA modules..."
    sudo sed -i 's/\b\(nvidia\|nvidia_modeset\|nvidia_uvm\|nvidia_drm\)\b//g' "${config}"

    # Ensure exactly one space between words and no space after '(' or before ')'
    sudo sed -i 's/ ( /(/g; s/ )/)/g; s/( */(/; s/ *)/)/; s/ \+/ /g' "${config}"

    # Remove kms from HOOKS=() in case it already exists.
    # We dont want double arguments.
    sudo sed -i 's/\bkms \b//g' "${config}"

    # Add kms to HOOKS=()
    logMessage "info" "Adding kms hook..."
    sudo sed -i 's/modconf/& kms/' "${config}"

    logMessage "info" "Configured ${config}."
}

removeModprobe() {
    # Creates a backup of the /etc/modprobe.d/nvidia.conf file and deletes the original one.

    local config="/etc/modprobe.d/nvidia.conf"
    backupConfig "${config}"
    logMessage "info" "Deleting ${config}..."

    # Delete configuration file
    sudo rm -f "${config}" || logMessage "warning" "Failed to delete NVIDIA modprobe file."
    logMessage "info" "Deleted ${config}."
}

removeGrubDefault() {
    # Creates a backup of the /etc/default/grub file
    # Removes nvidia_drm.modeset=1 from GRUB_CMDLINE_LINUX

    local config="/etc/default/grub"
    backupConfig "${config}"
    logMessage "info" "Configuring ${config}..."

    # Remove nvidia_drm.modeset=1 from GRUB_CMDLINE_LINUX
    sudo sed -i 's/nvidia_drm\.modeset=1//g' "${config}"
    logMessage "info" "Configured ${config}."
}

exitScript() {
    local message="$1"
    echo -e ""
    echo -e "${red}${message}${reset}"
    exit 0
}

### PROGRAM START ###

# Step 1: Set up trap for SIGINT (CTRL+C)
trap 'exitScript "Aborted!"' SIGINT

# Step 2: Check if running as sudo
checkSudo

# Step 3: Identify NVIDIA card, if that fails prompt the user to select a driver
checkNvidia

# Step 4: Detect if a driver is already installed, needed for uninstallation handling.
checkInstalledDriver

# Step 5: Show main selection menu
showMenu
