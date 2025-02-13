#!/bin/bash

# //////////////////////////////////////////////////////////////////////////////////////////
# Nvidiainstall by Justus0405
# Source : https://github.com/Justus0405/Nvidiainstall
# License: MIT
# //////////////////////////////////////////////////////////////////////////////////////////

# Version
export version="1.1"

# Color variables
export red="\e[1;31m"
export green="\e[1;32m"
export yellow="\e[1;33m"
export cyan="\e[1;36m"
export gray="\e[1;90m"
export endColor="\e[0m"

# Info variables
export section="${gray}[${yellow}!${gray}]${endColor}"
export info="${gray}[${cyan}i${gray}]${endColor}"
export success="${gray}[${green}✓${gray}]${endColor}"
export warning="${gray}[${red}!${gray}]${endColor}"
export error="${red}error:${endColor}"

#########################
# CHECKS                #
#########################

checkArgs() {
    # This Function reads the launch arguments
    # in a loop and processes each one of them
    #
    while [[ "$1" != "" ]]; do
        case "$1" in
        -h | --help)
            echo -e "Usage: nvidiainstall.sh [option] [option]"
            echo -e ""
            echo -e "Options:"
            echo -e "  -h, --help      Show this help message"
            echo -e "  -d, --debug     Run the script with logging"
            echo -e "  -f, --force     Disable Nvidia check and force install"
            exit 0
            ;;
        -d | --debug)
            export logFile="/var/log/nvidiainstall.log"
            export debugMode=true
            ;;
        -f | --force)
            export forcedMode=true
            ;;
        *)
            echo -e "Unknown option: $1"
            echo -e "Use -h or --help for help."
            exit 0
            ;;
        esac
        shift
    done
}

checkSudo() {
    #
    # Checks EUID to see if the script is running as sudo
    #
    if [[ "$EUID" -ne 0 ]]; then
        echo -e "${error} This script must be run as root. Use sudo."
        exit 1
    fi

    # Looks if the root user is permitted to execute
    # commands as sudo, this is needed because executing
    # commands with privilges in a bash script is a bit weird
    # or it may be just a skill issue ¯\_(ツ)_/¯
    if ! groups root | grep -q "\bwheel\b"; then
        echo -e "${info} Root is not in the wheel group. Adding root to the wheel group."
        usermod -aG wheel root || {
            echo -e "${error} Failed to add root to the wheel group."
            exit 1
        }
        echo -e "${info} Root has been successfully added to the wheel group."
    else
        echo -e "${info} Root is already in the wheel group."
    fi
}

checkNvidia() {
    # Looks for any PCI device with the name "nvidia" in it
    # This is to prevent something idk, saftey and such
    # stuff
    if lspci | grep -i nvidia &>/dev/null; then
        echo -e "${green}Nvidia card detected.${endColor}"
    else
        echo -e "${error} No Nvidia card detected."
        exit 1
    fi
}

#########################
# TERMINAL INTERFACE    #
#########################

showMenu() {
    # This is the main function with renders the selection menu
    # Waiting for the input of the user for running further functions
    # The function runs itself at the end ensuring coming back to it
    # when the selected option finished running
    clear
    echo -e "\t┌──────────────────────────────────────────────────┐"
    if [[ "$debugMode" = true ]]; then
        echo -e "\t│ [i] Debug Mode Enabled                           │"
    fi
    if [[ "$forcedMode" = true ]]; then
        echo -e "\t│ [i] Forced Mode Enabled                          │"
    fi
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
    echo -e "\t${green}Choose a menu option using your keyboard [1,2,3,4,0]${endColor}"

    # Use -n1 to read a single character without the need to press enter
    read -rsn1 option

    case "$option" in
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
        clear
        exit 0
        ;;
    esac

    # Loop back to menu after an option is handled
    showMenu
}

confirmInstallation() {
    # This is just a sanity check for the user
    # Also used to initiate the logging if
    # debugMode is set to true
    # The weird [yY][eE][sS]|[yY] syntax makes it
    # possible to answer either with y or yes in
    # any capitalization
    clear
    echo -e "${info} This script will install Nvidia drivers and modify system configurations."
    echo -e "${warning} Note: This script only supports generation Maxwell or newer, Use at your own risk!"
    read -rp "Do you want to proceed? (y/N): " confirm
    case "$confirm" in
    [yY][eE][sS] | [yY])
        echo -e "${green}Proceeding with installation...${endColor}"
        if [[ "$debugMode" = true ]]; then
            echo -e "${info} Started logging at $logFile${endColor}"
            exec > >(tee -i "$logFile") 2>&1
        fi
        installationSteps
        ;;
    *)
        echo -e "${red}Installation cancelled.${endColor}"
        exit 0
        ;;
    esac
}

installationSteps() {
    # Just a simple function handling each steps because
    # handling it everywere else looked ugly
    #

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

confirmUninstallation() {
    # This is just a sanity check for the user, Part 2
    # Also used to initiate the logging if
    # debugMode is set to true
    # The weird [yY][eE][sS]|[yY] syntax makes it
    # possible to answer either with y or yes in
    # any capitalization
    clear
    echo -e "${warning} This will completely uninstall all Nvidia drivers and modify system configurations."
    echo -e "${warning} Note: This script only supports the arch repo not the AUR, Use at your own risk!"
    read -rp "Do you want to proceed? (y/N): " confirm
    case "$confirm" in
    [yY][eE][sS] | [yY])
        echo -e "${green}Proceeding with uninstallation...${endColor}"
        if [[ "$debugMode" = true ]]; then
            echo -e "${info} Started logging at $logFile${endColor}"
            exec > >(tee -i "$logFile") 2>&1
        fi
        uninstallationSteps
        ;;
    *)
        echo -e "${red}Uninstallation cancelled.${endColor}"
        exit 0
        ;;
    esac
}

uninstallationSteps() {
    # Just a simple function handling each steps because
    # handling it everywere else looked ugly, Part 2
    #

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

showDeviceInformation() {
    # Looks for any PCI device with the name "nvidia" in it
    # and lists them here
    #
    clear
    echo -e ""
    echo -e "\tDevice Information:"
    echo -e ""
    gpu=$(lspci | grep -i 'nvidia' || true)
    if [[ -z "$gpu" ]]; then
        gpu="No Nvidia card detected"
    fi
    echo -e "$gpu"
    echo -e ""
    echo -e "\t${green}Press any button to return${endColor}"

    # Use -n1 to read a single character without the need to press enter
    read -rsn1 option

    case "$option" in
    *) ;;

    esac
}

showAbout() {
    # Just a bit of info
    # Also fetches the list of contributers regarding this project and
    # displays them in a list
    githubResponse=$(curl -s "https://api.github.com/repos/Justus0405/Nvidiainstall/contributors")
    clear
    echo -e ""
    echo -e "\tAbout Nvidiainstall:"
    echo -e ""
    echo -e "\tVersion: $version"
    echo -e "\tAuthor : Justus0405"
    echo -e "\tSource : https://github.com/Justus0405/Nvidiainstall"
    echo -e "\tLicense: MIT"
    echo -e "\tContributers:"

    echo "$githubResponse" | grep '"login":' | awk -F '"' '{print $4}' | while read -r contributors; do
        echo -e "\t\t\e[0;35m${contributors}\e[m"
    done

    echo -e ""
    echo -e "\t${green}Press any button to return${endColor}"

    # Use -n1 to read a single character without the need to press enter
    read -rsn1 option

    case "$option" in
    *) ;;

    esac
}

#########################
# INSTALLATION STEPS    #
#########################

updateSystem() {
    #
    # Stay up to date folks
    #
    echo -e "${section} Updating system..."
    sudo pacman -Syyu || {
        echo -e "${error} Could not update system."
        exit 1
    }
    echo -e "${success} System updated."
}

checkKernelHeaders() {
    # Check the installed kernel and installs
    # the associated headers, this is needed
    # for the kernel to load the nvidia modules
    echo -e "${section} Installing kernel modules..."
    kernelVersion=$(uname -r)
    if [[ "$kernelVersion" == *"zen"* ]]; then
        echo -e "${info} Detected kernel: zen"
        sudo pacman -S --needed --noconfirm linux-zen-headers || {
            echo -e "${error} Could not install kernel modules."
            exit 1
        }
    elif [[ "$kernelVersion" == *"lts"* ]]; then
        echo -e "${info} Detected kernel: lts"
        sudo pacman -S --needed --noconfirm linux-lts-headers || {
            echo -e "${error} Could not install kernel modules."
            exit 1
        }
    elif [[ "$kernelVersion" == *"hardened"* ]]; then
        echo -e "${info} Detected kernel: hardened"
        sudo pacman -S --needed --noconfirm linux-hardened-headers || {
            echo -e "${error} Could not install kernel modules."
            exit 1
        }
    else
        echo -e "${info} Detected kernel: regular"
        sudo pacman -S --needed --noconfirm linux-headers || {
            echo -e "${error} Could not install kernel modules."
            exit 1
        }
    fi
    echo -e "${success} Kernel modules installed."
}

installNvidiaPackages() {
    #
    # Install the nvidia drivers and needed dependencies if not present
    #
    echo -e "${section} Installing Nvidia packages..."
    sudo pacman -S --needed --noconfirm nvidia-dkms libglvnd nvidia-utils opencl-nvidia nvidia-settings lib32-nvidia-utils lib32-opencl-nvidia egl-wayland || {
        echo -e "${error} Could not install Nvidia packages."
        exit 1
    }
    echo -e "${success} Nvidia packages installed."
}

configureMkinitcpio() {
    # This was just pure insanity to impliment with the intent
    # of not breaking previous configurations (But it works :3)
    # This is for adding the nvidia modules to the /etc/mkinitcpio.conf file
    # Firstly it creates a backup of the original file
    # Then it removes any lines that are commented out and contain nothing (Not necessary but pretty)
    # Then removes any previously added nvidia modules, this could fix previously wrong configurations
    # Ensures the () dont have any spaces at the beginning and at the end
    # Then the modules get added in the correct formatting and order without deleting previous modules
    # not related to nvidia
    # At the end the kms hook gets removed, which is a recommeded step because it disables any other
    # non-nvidia gpu
    echo -e "${section} Configuring mkinitcpio..."
    mkinitcpioConf="/etc/mkinitcpio.conf"

    if [[ -f "$mkinitcpioConf" ]]; then
        # Backup existing configuration file if it exists
        sudo cp "$mkinitcpioConf" "$mkinitcpioConf.bak"
        echo -e "${info} Backup of $mkinitcpioConf created."

        # Remove any lines that are commented out and contain nothing
        echo -e "${info} Cleaning up $mkinitcpioConf structure..."
        sudo sed -i '/^#/d;/^$/d' "$mkinitcpioConf"

        if grep -q 'MODULES=.*nvidia' "$mkinitcpioConf"; then
            # Remove any occurrences of nvidia-related modules
            echo -e "${info} Cleaning up existing Nvidia modules..."
            sudo sed -i 's/\b\(nvidia\|nvidia_modeset\|nvidia_uvm\|nvidia_drm\)\b//g' "$mkinitcpioConf"

            # Ensure exactly one space between words and no space after '(' or before ')'
            sudo sed -i 's/ ( /(/g; s/ )/)/g; s/( */(/; s/ *)/)/; s/ \+/ /g' "$mkinitcpioConf"
        fi

        # Now, append the nvidia modules in the correct order if they are not already there
        if ! grep -q 'MODULES=.*nvidia nvidia_modeset nvidia_uvm nvidia_drm' "$mkinitcpioConf"; then
            echo -e "${info} Adding Nvidia modules..."
            sudo sed -i 's/^MODULES=(\([^)]*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' "$mkinitcpioConf"

            # Ensure exactly one space between words and no space after '(' or before ')'
            sudo sed -i 's/ ( /(/g; s/ )/)/g; s/( */(/; s/ *)/)/; s/ \+/ /g' "$mkinitcpioConf"
        else
            echo -e "${info} Nvidia modules are already present in the correct order."
        fi

        # Removing kms hook if it exists
        if grep -q '\bkms\b' "$mkinitcpioConf"; then
            echo -e "${info} Removing kms hook..."
            sudo sed -i 's/\bkms \b//g' "$mkinitcpioConf"
        else
            echo -e "${info} kms hook is not present."
        fi

        echo -e "${success} $mkinitcpioConf updated."
    else
        echo -e "${error} $mkinitcpioConf not found."
        exit 1
    fi
}

# WILL BE DEPRICATED WITH LATEST MAJOR RELEASE
configureModprobe() {
    # This function looks for an nvidia.conf file at /etc/modprobe.d/
    # If it exists, backs it up and creates a new one with the content
    # "options nvidia_drm modeset=1 fbdev=1" straight from Hyprland Wiki
    # This isnt needed but still good for compatibility
    echo -e "${section} Creating Nvidia modprobe file..."
    nvidiaConf="/etc/modprobe.d/nvidia.conf"

    # Backup existing configuration file if it exists
    if [[ -f "$nvidiaConf" ]]; then
        sudo cp "$nvidiaConf" "${nvidiaConf}.bak"
        echo -e "${info} Backup of $nvidiaConf created."
    fi

    # Create new configuration file
    echo -e "${info} Creating $nvidiaConf..."
    echo "options nvidia_drm modeset=1 fbdev=1" | sudo tee "$nvidiaConf" >/dev/null || {
        echo -e "${error} Failed to create Nvidia modprobe file."
        exit 1
    }
    echo -e "${success} Nvidia modprobe file created."

}

configureGrubDefault() {
    # Function to add "nvidia_drm.modeset=1" to /etc/default/grub
    # only if it not exists, also backs up the grub config before
    # making these changes
    # The weird sed syntax ensures that the argument only gets added
    # and not replacing the line, keeping previous configuration safe
    echo -e "${section} Configuring GRUB default..."
    grubConf="/etc/default/grub"

    if [[ -f "$grubConf" ]]; then
        # Backup existing configuration file if it exists
        sudo cp "$grubConf" "$grubConf.bak"
        echo -e "${info} Backup of $grubConf created."

        # Update the GRUB configuration
        echo -e "${info} Adding Nvidia modeset to $grubConf..."
        sudo sed -i '/GRUB_CMDLINE_LINUX_DEFAULT=/!b;/nvidia_drm.modeset=1/!s/\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)/\1 nvidia_drm.modeset=1/' "$grubConf"
        echo -e "${success} $grubConf updated."
    else
        echo -e "${error} $grubConf not found."
        exit 1
    fi
}

regenerateInitramfs() {
    # Regenerates the initramfs
    # to load the nvidia modules
    # Prepare for high CPU usage
    echo -e "${section} Regenerating initramfs..."
    sudo mkinitcpio -P || {
        echo -e "${error} Failed to regenerate the initramfs."
        exit 1
    }
    echo -e "${success} initramfs regenerated."
}

updateGrubConfig() {
    # Updates the grub config at /boot/grub/grub.cfg
    # After /etc/default/grub was changed
    #
    bootConf="/boot/grub/grub.cfg"
    echo -e "${section} Updating GRUB config..."
    sudo grub-mkconfig -o "$bootConf" || {
        echo -e "${error} Failed to update $bootConf."
        exit 1
    }
    echo -e "${success} $bootConf updated."
}

confirmReboot() {
    # Asks the user to reboot to apply changes
    # properly, if no is selected the script
    # will return to showMenu
    echo -e ""
    echo -e "${green}Action complete.${endColor}"
    if [[ "$debugMode" = true ]]; then
        echo -e "${info} Log saved at $logFile${endColor}"
    fi
    read -rp "Would you like to reboot now? (y/N): " rebootNow
    case "$rebootNow" in
    [yY][eE][sS] | [yY])
        sudo reboot now
        ;;
    *)
        echo -e "${info} Please reboot your system later to apply changes."
        echo -e ""
        echo -e "\t${green}Press any button to return${endColor}"

        # Use -n1 to read a single character without the need to press enter
        read -rsn1 option

        case "$option" in
        *) ;;

        esac
        ;;
    esac
}

#########################
# UNINSTALLATION STEPS  #
#########################

removeNvidiaPackages() {
    #
    # Uninstall the nvidia drivers, configs and unused dependencies
    #
    echo -e "${section} Uninstalling Nvidia packages..."
    sudo pacman -Rn nvidia-dkms nvidia-settings || {
        echo -e "${error} Could not uninstall Nvidia packages."
        exit 1
    }
    echo -e "${success} Nvidia packages uninstalled."
}

removeMkinitcpio() {
    # Same as the configureMkinitcpio() function but without
    # adding the nvidia modules
    # Adds back the kms hook
    echo -e "${section} Removing mkinitcpio modules..."
    mkinitcpioConf="/etc/mkinitcpio.conf"

    if [[ -f "$mkinitcpioConf" ]]; then
        # Backup existing configuration file if it exists
        sudo cp "$mkinitcpioConf" "$mkinitcpioConf.bak-uninstall"
        echo -e "${info} Backup of $mkinitcpioConf created."

        # Remove any lines that are commented out and contain nothing
        echo -e "${info} Cleaning up $mkinitcpioConf structure..."
        sudo sed -i '/^#/d;/^$/d' "$mkinitcpioConf"

        if grep -q 'MODULES=.*nvidia' "$mkinitcpioConf"; then
            # Remove any occurrences of nvidia-related modules
            echo -e "${info} Removing Nvidia modules..."
            sudo sed -i 's/\b\(nvidia\|nvidia_modeset\|nvidia_uvm\|nvidia_drm\)\b//g' "$mkinitcpioConf"

            # Ensure exactly one space between words and no space after '(' or before ')'
            sudo sed -i 's/ ( /(/g; s/ )/)/g; s/( */(/; s/ *)/)/; s/ \+/ /g' "$mkinitcpioConf"
        fi

        # Add back the kms hook
        if grep -q '\bkms\b' "$mkinitcpioConf"; then
            echo -e "${info} kms hook is already present."
        else
            echo -e "${info} Adding kms hook..."
            sudo sed -i 's/modconf/& kms/' "$mkinitcpioConf"
        fi

        echo -e "${success} $mkinitcpioConf updated."
    else
        echo -e "${error} $mkinitcpioConf not found."
        exit 1
    fi
}

# WILL BE DEPRICATED WITH LATEST MAJOR RELEASE
removeModprobe() {
    # Creates a backup of the /etc/modprobe.d/nvidia.conf file
    # and deletes the original one
    #
    echo -e "${section} Deleting Nvidia modprobe file..."
    nvidiaConf="/etc/modprobe.d/nvidia.conf"

    # Backup existing configuration file if it exists
    if [[ -f "$nvidiaConf" ]]; then
        sudo cp "$nvidiaConf" "${nvidiaConf}.bak-uninstall"
        echo -e "${info} Backup of $nvidiaConf created."
    fi

    # Delete configuration file
    sudo rm -f "$nvidiaConf" || {
        echo -e "${warning} Failed to delete Nvidia modprobe file."
    }
    echo -e "${success} Nvidia modprobe file deleted."

}

removeGrubDefault() {
    # Creates a backup of the /etc/default/grub file
    # Removes nvidia_drm.modeset=1 from
    # GRUB_CMDLINE_LINUX
    echo -e "${section} Configuring GRUB default..."
    grubConf="/etc/default/grub"

    if [[ -f "$grubConf" ]]; then
        # Backup existing configuration file if it exists
        sudo cp "$grubConf" "$grubConf.bak-uninstall"
        echo -e "${info} Backup of $grubConf created."

        # Remove nvidia_drm.modeset=1 from GRUB_CMDLINE_LINUX
        echo -e "${info} Removing nvidia modeset from $grubConf..."
        sudo sed -i 's/nvidia_drm\.modeset=1//g' "$grubConf"
        echo -e "${success} $grubConf updated."
    else
        echo -e "${error} $grubConf not found."
        exit 1
    fi
}

#########################
# PROGRAMM START        #
#########################

# Step 1: Set up trap for SIGINT (CTRL+C)
trap 'echo -e "${red}Exited${endColor}"; exit 0' SIGINT

# Step 2: Check launch arguments for extra functionality
checkArgs "$@"

# Step 3: Check if running as sudo
checkSudo

# Step 4: Check if nvidia card is present
if [[ "$forcedMode" != true ]]; then
    checkNvidia
fi

# Step 5: Show selection menu
showMenu
