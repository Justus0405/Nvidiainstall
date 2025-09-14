#!/usr/bin/env bash
#
# Automated NVIDIA Driver Installer for Arch Linux
#
# Author: Justus0405
# Date: 12.10.2024
# License: MIT

export scriptVersion="2.0"

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

    if [[ "$EUID" -ne 0 ]]; then
        logMessage "error" "This script must be run as root. Use sudo."
    fi

    # Looks if the root user is permitted to execute ommands as sudo,
    # this is needed because executing commands with privilges in a bash script is a bit weird.
    # Or it may be just a skill issue. ¯\_(ツ)_/¯

    # If grep returns a non zero exit status, add root to the weel group.
    if ! groups root | grep -q "\bwheel\b"; then
        logMessage "info" "Root is not in the wheel group. Adding root to the wheel group."
        usermod -aG wheel root || logMessage "error" "Failed to add root to the wheel group."
        logMessage "info" "Root has been successfully added to the wheel group."
    else
        logMessage "info" "Root is already in the wheel group."
    fi
}

checkAurHelper() {
    # Checking if yay is installed.

    if command -v yay >/dev/null 2>&1; then
        logMessage "info" "Yay is installed."
        export aurHelper="yay"
    else
        logMessage "info" "Yay is not installed."
        installAurHelper
    fi
}

installAurHelper() {
    # Installing yay as aur helper.

    logMessage "info" "Installing yay..."
    git clone https://aur.archlinux.org/yay.git || logMessage "error" "Failed to download yay, are you connected to the internet?"
    cd yay || logMessage "error" "Failed to enter the yay path"
    makepkg -si --noconfirm || logMessage "error" "Failed to install yay"
    logMessage "info" "Sucessfully installed yay."
}

checkNvidia() {
    # Detect NVIDIA GPU and decide driver package.

    # Default values.
    gpuInfo="Unknown"
    gpuName="Unknown"
    gpuGen="Unknown"
    gpuDriver="Unknown"

    gpuInfo=$(lspci -nn | grep -i 'VGA.*NVIDIA')
    gpuName=$(echo "${gpuInfo}" | sed -E 's/.*NVIDIA Corporation //; s/ \[.*//')

    case "${gpuName}" in
    *"AD"*"Lovelace"* | *"Ada"*)
        gpuGen="Ada Lovelace"
        gpuDriver="nvidia-dkms"
        ;;
    *"GA"* | *"Ampere"*)
        gpuGen="Ampere"
        gpuDriver="nvidia-dkms"
        ;;
    *"TU"* | *"Turing"*)
        gpuGen="Turing"
        gpuDriver="nvidia-dkms"
        ;;
    *"GV"* | *"Volta"*)
        gpuGen="Volta"
        gpuDriver="nvidia-dkms"
        ;;
    *"GP"* | *"Pascal"*)
        gpuGen="Pascal"
        gpuDriver="nvidia-dkms"
        ;;
    *"GM"* | *"Maxwell"*)
        gpuGen="Maxwell"
        gpuDriver="nvidia-dkms"
        ;;
    *"GK"* | *"Kepler"*)
        gpuGen="Kepler"
        gpuDriver="nvidia-470xx-dkms"
        ;;
    *"GF"* | *"Fermi"*)
        gpuGen="Fermi"
        gpuDriver="nvidia-390xx-dkms"
        ;;
    *"GT2"* | *"G9"* | *"G8"* | *"Tesla"*)
        gpuGen="Tesla"
        gpuDriver="nvidia-340xx-dkms"
        ;;
    *"G7"* | *"Curie"*)
        gpuGen="Curie"
        gpuDriver="unsupported"
        ;;
    *)
        gpuGen="Unknown"
        gpuDriver="manual"
        ;;
    esac

    if [[ ${gpuDriver} == "unsupported" ]]; then
        logMessage "error" "Curie and older are not supported anymore :/"
    fi

    if [[ ${gpuDriver} == "manual" ]]; then
        chooseGpuDriver
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
    echo -e "\t│ [1] nvidia-dkms         [Ada Lovelace and newer] │"
    echo -e "\t│ [2] nvidia-470xx-dkms                   [Kepler] │"
    echo -e "\t│ [3] nvidia-390xx-dkms                    [Fermi] │"
    echo -e "\t│ [4] nvidia-340xx-dkms                    [Tesla] │"
    echo -e "\t│                                                  │"
    echo -e "\t├──────────────────────────────────────────────────┤"
    echo -e "\t│ [0] Quit                                         │"
    echo -e "\t└──────────────────────────────────────────────────┘"
    echo -e ""
    echo -e "\t${green}Choose a menu option using your keyboard [1,2,3,4,0]${reset}"

    read -rsn1 option

    case "${option}" in
    "1")
        gpuDriver="nvidia-dkms"
        ;;
    "2")
        gpuDriver="nvidia-470xx-dkms"
        ;;
    "3")
        gpuDriver="nvidia-390xx-dkms"
        ;;
    "4")
        gpuDriver="nvidia-340xx-dkms"
        ;;
    "0")
        exitScript "Quit."
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
    echo -e "\t│ [4] About                                        │"
    echo -e "\t│                                                  │"
    echo -e "\t├──────────────────────────────────────────────────┤"
    echo -e "\t│ [0] Quit                                         │"
    echo -e "\t└──────────────────────────────────────────────────┘"
    echo -e ""
    echo -e "\t${green}Choose a menu option using your keyboard [1,2,3,4,0]${reset}"

    read -rsn1 option

    case "${option}" in
    "1")
        confirmInstallation
        ;;
    "2")
        confirmUninstallation
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
    echo -e "\tRecommended driver: ${gpuDriver}"
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
    read -rp "Do you want to proceed? (y/N): " confirm
    case "${confirm}" in
    [yY][eE][sS] | [yY])
        echo -e "${green}Proceeding with installation...${reset}"
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
    "nvidia-dkms")
        sudo pacman -S --needed --noconfirm nvidia-dkms nvidia-utils opencl-nvidia nvidia-settings libglvnd lib32-nvidia-utils lib32-opencl-nvidia egl-wayland || logMessage "error" "Could not install NVIDIA packages."
        ;;
    "nvidia-470xx-dkms")
        checkAurHelper
        yay -S --needed --noconfirm nvidia-470xx-dkms nvidia-470xx-utils opencl-nvidia-470xx nvidia-470xx-settings libglvnd lib32-nvidia-470xx-utils lib32-opencl-nvidia-470xx egl-wayland || logMessage "error" "Could not install NVIDIA packages."
        ;;
    "nvidia-390xx-dkms")
        checkAurHelper
        yay -S --needed --noconfirm nvidia-390xx-dkms nvidia-390xx-utils opencl-nvidia-390xx nvidia-390xx-settings libglvnd lib32-nvidia-390xx-utils lib32-opencl-nvidia-390xx egl-wayland || logMessage "error" "Could not install NVIDIA packages."
        ;;
    "nvidia-340xx-dkms")
        checkAurHelper
        yay -S --needed --noconfirm nvidia-340xx-dkms nvidia-340xx-utils opencl-nvidia-340xx nvidia-340xx-settings libglvnd lib32-nvidia-340xx-utils lib32-opencl-nvidia-340xx egl-wayland || logMessage "error" "Could not install NVIDIA packages."
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
    logMessage "Configuring ${config}..."

    # Remove any lines that are commented out and contain nothing
    logMessage "Cleaning up ${config}..."
    sudo sed -i '/^#/d;/^$/d' "${config}"

    # Remove any occurrences of nvidia-related modules in case some already exist.
    # We dont want double arguments.
    sudo sed -i 's/\b\(nvidia\|nvidia_modeset\|nvidia_uvm\|nvidia_drm\)\b//g' "${config}"

    # Ensure exactly one space between words and no space after '(' or before ')'
    logMessage "Cleaning up brackets..."
    sudo sed -i 's/ ( /(/g; s/ )/)/g; s/( */(/; s/ *)/)/; s/ \+/ /g' "${config}"

    # Add nvidia nvidia_modeset nvidia_uvm nvidia_drm add the end of HOOKS=()
    logMessage "info" "Adding NVIDIA modules..."
    sudo sed -i 's/^MODULES=(\([^)]*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' "${config}"

    # Ensure exactly one space between words and no space after '(' or before ')'
    logMessage "Cleaning up brackets..."
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
    logMessage "Configuring ${config}..."

    echo "options nvidia_drm modeset=1 fbdev=1" | sudo tee "${config}" >/dev/null
    logMessage "info" "Configured ${config}."
}

configureGrubDefault() {
    # Function to add "nvidia_drm.modeset=1" to /etc/default/grub.
    # The weird sed syntax ensures that the argument only gets added
    # and not replacing the line, keeping previous configuration safe.

    local config="/etc/default/grub"
    backupConfig "${config}"
    logMessage "Configuring ${config}..."

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
    logMessage "Configuring ${config}..."

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
    read -rp "Do you want to proceed? (y/N): " confirm
    case "${confirm}" in
    [yY][eE][sS] | [yY])
        echo -e "${green}Proceeding with uninstallation...${reset}"
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

    logMessage "info" "Identified Generation: ${gpuGen}"
    logMessage "info" "Uninstalling ${gpuDriver} and dependencies..."

    case "${gpuDriver}" in
    "nvidia-dkms")
        sudo pacman -Rns --noconfirm nvidia-dkms nvidia-utils opencl-nvidia nvidia-settings libglvnd lib32-nvidia-utils lib32-opencl-nvidia egl-wayland || logMessage "error" "Could not uninstall NVIDIA packages."
        ;;
    "nvidia-470xx-dkms")
        checkAurHelper
        yay -Rns --noconfirm nvidia-470xx-dkms nvidia-470xx-utils opencl-nvidia-470xx nvidia-470xx-settings libglvnd lib32-nvidia-470xx-utils lib32-opencl-nvidia-470xx egl-wayland || logMessage "error" "Could not uninstall NVIDIA packages."
        ;;
    "nvidia-390xx-dkms")
        checkAurHelper
        yay -Rns --noconfirm nvidia-390xx-dkms nvidia-390xx-utils opencl-nvidia-390xx nvidia-390xx-settings libglvnd lib32-nvidia-390xx-utils lib32-opencl-nvidia-390xx egl-wayland || logMessage "error" "Could not uninstall NVIDIA packages."
        ;;
    "nvidia-340xx-dkms")
        checkAurHelper
        yay -Rns --noconfirm nvidia-340xx-dkms nvidia-340xx-utils opencl-nvidia-340xx nvidia-340xx-settings libglvnd lib32-nvidia-340xx-utils lib32-opencl-nvidia-340xx egl-wayland || logMessage "error" "Could not uninstall NVIDIA packages."
        ;;
    esac

    logMessage "info" "Uninstalled NVIDIA packages and dependencies."
}

removeMkinitcpio() {
    # Same as the configureMkinitcpio() function but without adding the nvidia modules.
    # Also adds back the kms hook.

    local config="/etc/mkinitcpio.conf"
    backupConfig "${config}"
    logMessage "Configuring ${config}..."

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
    logMessage "Deleting ${config}..."

    # Delete configuration file
    sudo rm -f "${config}" || logMessage "warning" "Failed to delete NVIDIA modprobe file."
    logMessage "info" "Deleted ${config}."
}

removeGrubDefault() {
    # Creates a backup of the /etc/default/grub file
    # Removes nvidia_drm.modeset=1 from GRUB_CMDLINE_LINUX

    local config="/etc/default/grub"
    backupConfig "${config}"
    logMessage "Configuring ${config}..."

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

# Step 4: Show main selection menu
showMenu
