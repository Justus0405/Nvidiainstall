#!/bin/bash

# //////////////////////////////////////////////////////////////////////////////////////////
# Nvidiainstall by Justus0405
# Source : https://github.com/Justus0405/Nvidiainstall
# License: MIT
# //////////////////////////////////////////////////////////////////////////////////////////

VERSION="1.0"

# Color variables
RED="\e[1;31m"
GREEN="\e[1;32m"
YELLOW="\e[1;33m"
CYAN="\e[1;36m"
ENDCOLOR="\e[0m"

# Info variables
SUCCSESS="${GREEN}[✓]${ENDCOLOR}"
ERROR="${RED}Error:${ENDCOLOR}"
SECTION="${YELLOW}[!]${ENDCOLOR}"
INFO="${CYAN}[i]${ENDCOLOR}"

#
# CHECKS
#

check_args() {
    # This Function reads the launch arguments
    # in a loop and processes each one of them
    #
    while [[ "$1" != "" ]]; do
        case "$1" in
            -h | --help)
                echo -e "Usage: nvidiainstall.sh [options]"
                echo -e ""
                echo -e "Options:"
                echo -e "  -h, --help      Show this help message"
                echo -e "  -d, --debug     Run the script with logging"
                echo -e "  -f, --force     Disable nvidia check and force install"
                exit 0
                ;;
            -d | --debug)
                LOG_FILE="/var/log/nvidia_install.log"
                DEBUG_MODE=true
                ;;
            -f | --force)
                FORCED_MODE=true
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

check_sudo() {
    #
    # Checks EUID to see if the script is running as sudo
    #
    if [[ "$EUID" -ne 0 ]]; then
        echo -e "${ERROR} This script must be run as root. Use sudo."
        exit 1
    fi

    # Looks if the root user is permitted to execute
    # commands as sudo, this is needed because executing
    # commands with privilges in a bash script is a bit weird
    # or it may be just a skill issue ¯\_(ツ)_/¯
    if ! groups root | grep -q "\bwheel\b"; then
        echo -e "${INFO} Root is not in the wheel group. Adding root to the wheel group."
        usermod -aG wheel root

        if [[ $? -eq 0 ]]; then
            echo -e "${INFO} Root has been successfully added to the wheel group."
        else
            echo -e "${ERROR} Failed to add root to the wheel group."
            exit 1
        fi
    else
        echo -e "${INFO} Root is already in the wheel group."
    fi
}

check_nvidia() {
    # Looks for any PCI device with the name "Nvidia" in it
    # This is to prevent something idk, saftey and such
    # stuff
    if lspci | grep -i nvidia &>/dev/null; then
        echo -e "${GREEN}NVIDIA card detected.${ENDCOLOR}"
    else
        echo -e "${ERROR} No NVIDIA card detected."
        exit 1
    fi
}

#
# TERMINAL INTERFACE
#

show_menu() {
    # This is the main function with renders the selection menu
    # Waiting for the input of the user for running further functions
    # The function runs itself at the end ensuring coming back to it
    # when the selected option finished running
    clear
    echo -e "\t┌──────────────────────────────────────────────────┐"
    echo -e "\t│                                                  │"
    echo -e "\t│ Choose option:                                   │"
    if [[ "$DEBUG_MODE" = true ]]; then
    echo -e "\t│ [i] Debug Mode Enabled                           │"
    fi
     if [[ "$FORCED_MODE" = true ]]; then
    echo -e "\t│ [i] Forced Mode Enabled                          │"
    fi
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
    echo -e "\t${GREEN}Choose a menu option using your keyboard [1,2,3,4,0]${ENDCOLOR}"

    # Use -n1 to read a single character without the need to press enter
    read -rsn1 option

    case "$option" in
        "1")
            conrfirm_installation
            ;;
        "2")
            confirm_uninstallation
            ;;
        "3")
            show_device_information
            ;;
        "4")
            show_about
            ;;
        "0")
            clear
            exit 0
            ;;
    esac

    # Loop back to menu after an option is handled
    show_menu
}

conrfirm_installation() {
    # This is just a sanity check for the user
    # Also used to initiate the logging if
    # DEBUG_MODE is set to true
    # The weird [yY][eE][sS]|[yY] syntax makes it
    # possible to answer either with y or yes in
    # any capitalization
    clear
    echo -e "${INFO} This script will install NVIDIA drivers and modify system configurations."
    echo -e "${INFO} Note: This script only supports generation Maxwell or newer, Use at your own risk!"
    read -rp "Do you want to proceed? (y/N): " confirm
    case "$confirm" in
        [yY][eE][sS]|[yY])
            echo -e "${GREEN}Proceeding with installation...${ENDCOLOR}"
            if [[ "$DEBUG_MODE" = true ]]; then
                echo -e "${INFO} Started logging at $LOG_FILE${ENDCOLOR}"
                exec > >(tee -i "$LOG_FILE") 2>&1
            fi
            installation_steps
            ;;
        *)
            echo -e "${RED}Installation cancelled.${ENDCOLOR}"
            exit 0
            ;;
    esac
}

installation_steps() {
    # Just a simple function handling each steps because
    # handling it everywere else looked ugly
    #

    # Step 1
    update_system

    # Step 2
    check_kernel_headers

    # Step 3
    install_nvidia_packages

    # Step 4
    configure_mkinitcpio

    # Step 5
    configure_modprobe

    # Step 6
    configure_grub_default

    # Step 7
    regenerate_initramfs

    # Step 8
    update_grub_config

    # Step 9
    confirm_reboot
}

confirm_uninstallation() {
    # This is just a sanity check for the user, Part 2
    # Also used to initiate the logging if
    # DEBUG_MODE is set to true
    # The weird [yY][eE][sS]|[yY] syntax makes it
    # possible to answer either with y or yes in
    # any capitalization
    clear
    echo -e "${INFO} This will completely uninstall all NVIDIA drivers and modify system configurations."
    echo -e "${INFO} Note: This script only supports the arch repo not the AUR, Use at your own risk!"
    read -rp "Do you want to proceed? (y/N): " confirm
    case "$confirm" in
        [yY][eE][sS]|[yY])
            echo -e "${GREEN}Proceeding with uninstallation...${ENDCOLOR}"
            if [[ "$DEBUG_MODE" = true ]]; then
                echo -e "${INFO} Started logging at $LOG_FILE${ENDCOLOR}"
                exec > >(tee -i "$LOG_FILE") 2>&1
            fi
            uninstallation_steps
            ;;
        *)
            echo -e "${RED}Uninstallation cancelled.${ENDCOLOR}"
            exit 0
            ;;
    esac
}

uninstallation_steps() {
    # Just a simple function handling each steps because
    # handling it everywere else looked ugly, Part 2
    #

    # Step 1
    remove_nvidia_packages

    # Step 2
    remove_mkinitcpio

    # Step 3
    remove_modprobe

    # Step 4
    remove_grub_default

    # Step 5
    regenerate_initramfs

    # Step 6
    update_grub_config

    # Step 7
    confirm_reboot
}

show_device_information() {
    # Looks for any PCI device with the name "Nvidia" in it
    # and lists them here
    #
    clear
    echo -e ""
    echo -e "\tDevice Information:"
    echo -e ""
    GPU=$(lspci | grep -i 'nvidia' || true)
    if [[ -z "$GPU" ]]; then
        GPU="No NVIDIA card detected"
    fi
    echo -e "$GPU"
    echo -e ""
    echo -e "\t${GREEN}Press any button to return${ENDCOLOR}"

    # Use -n1 to read a single character without the need to press enter
    read -rsn1 option

    case "$option" in
        *)
            ;;
    esac
}

show_about() {
    # Just a bit of info
    # Also fetches the list of contributers regarding this project and
    # displays them in a list
    github_response=$(curl -s "https://api.github.com/repos/Justus0405/Nvidiainstall/contributors")
    clear
    echo -e ""
    echo -e "\tAbout Nvidiainstall:"
    echo -e ""
    echo -e "\tVersion: $VERSION"
    echo -e "\tAuthor : Justus0405"
    echo -e "\tSource : https://github.com/Justus0405/Nvidiainstall"
    echo -e "\tLicense: MIT"
    echo -e "\tContributers:"

    echo "$github_response" | grep '"login":' | awk -F '"' '{print $4}' | while read -r contributors; do
            echo -e "\t\t\e[0;35m${contributors}\e[m"
    done

    echo -e ""
    echo -e "\t${GREEN}Press any button to return${ENDCOLOR}"

    # Use -n1 to read a single character without the need to press enter
    read -rsn1 option

    case "$option" in
        *)
            ;;
    esac
}

#
# INSTALLATION STEPS
#

update_system() {
    #
    # Stay up to date folks
    #
    echo -e "${SECTION} Updating system..."
    sudo pacman -Syyu
}

check_kernel_headers() {
    # Check the installed kernel and installs
    # the associated headers, this is needed
    # for the kernel to load the nvidia modules
    kernel_version=$(uname -r)
    if [[ "$kernel_version" == *"zen"* ]]; then
        echo -e "${INFO} Detected kernel: zen"
        sudo pacman -S --needed --noconfirm linux-zen-headers
    elif [[ "$kernel_version" == *"lts"* ]]; then
        echo -e "${INFO} Detected kernel: lts"
        sudo pacman -S --needed --noconfirm linux-lts-headers
    elif [[ "$kernel_version" == *"hardened"* ]]; then
        echo -e "${INFO} Detected kernel: hardened"
        sudo pacman -S --needed --noconfirm linux-hardened-headers
    else
        echo -e "${INFO} Detected kernel: regular"
        sudo pacman -S --needed --noconfirm linux-headers
    fi
}

install_nvidia_packages() {
    #
    # Install the nvidia drivers and needed dependencies if not present
    #
    echo -e "${SECTION} Installing NVIDIA packages..."
    sudo pacman -S --needed --noconfirm nvidia-dkms libglvnd nvidia-utils opencl-nvidia nvidia-settings lib32-nvidia-utils lib32-opencl-nvidia egl-wayland
}

configure_mkinitcpio() {
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
    # non-nvidia GPU
    echo -e "${SECTION} Configuring mkinitcpio..."
    MKINITCPIO_CONF="/etc/mkinitcpio.conf"

    if [[ -f $MKINITCPIO_CONF ]]; then
        # Backup existing configuration file if it exists
        sudo cp "$MKINITCPIO_CONF" "$MKINITCPIO_CONF.bak"
        echo -e "${SUCCSESS} Backup of $MKINITCPIO_CONF created."

        # Remove any lines that are commented out and contain nothing
        echo -e "${INFO} Cleaning up $MKINITCPIO_CONF."
        sudo sed -i '/^#/d;/^$/d' "$MKINITCPIO_CONF"

        if grep -q 'MODULES=.*nvidia' "$MKINITCPIO_CONF"; then
            echo -e "${INFO} Cleaning up existing NVIDIA modules."
            # Remove any occurrences of nvidia-related modules
            sudo sed -i 's/\b\(nvidia\|nvidia_modeset\|nvidia_uvm\|nvidia_drm\)\b//g' "$MKINITCPIO_CONF"

            # Ensure exactly one space between words and no space after '(' or before ')'
            sudo sed -i 's/ ( /(/g; s/ )/)/g; s/( */(/; s/ *)/)/; s/ \+/ /g' "$MKINITCPIO_CONF"
        fi

        # Now, append the NVIDIA modules in the correct order if they are not already there
        if ! grep -q 'MODULES=.*nvidia nvidia_modeset nvidia_uvm nvidia_drm' "$MKINITCPIO_CONF"; then
            echo -e "${INFO} Adding NVIDIA modules in the correct order."
            sudo sed -i 's/^MODULES=(\([^)]*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' "$MKINITCPIO_CONF"

            # Ensure exactly one space between words and no space after '(' or before ')'
            sudo sed -i 's/ ( /(/g; s/ )/)/g; s/( */(/; s/ *)/)/; s/ \+/ /g' "$MKINITCPIO_CONF"
        else
            echo -e "${INFO} NVIDIA modules are already present in the correct order."
        fi

        # Removing kms hook if it exists
        if grep -q '\bkms\b' "$MKINITCPIO_CONF"; then
            echo -e "${INFO} Removing kms hook"
            sudo sed -i 's/\bkms \b//g' "$MKINITCPIO_CONF"
        else
            echo -e "${INFO} kms hook is not present."
        fi

        echo -e "${SUCCSESS} mkinitcpio.conf updated."
    else
        echo -e "${ERROR} $MKINITCPIO_CONF not found."
        exit 1
    fi
}

configure_modprobe() {
    # This function looks for an nvidia.conf file at /etc/modprobe.d/
    # If it exists, backs it up and creates a new one with the content
    # "options nvidia_drm modeset=1 fbdev=1" straight from Hyprland Wiki
    # This isnt needed but still good for compatibility
    echo -e "${SECTION} Creating NVIDIA configuration file..."
    NVIDIA_CONF="/etc/modprobe.d/nvidia.conf"

    # Backup existing configuration file if it exists
    if [[ -f $NVIDIA_CONF ]]; then
        sudo cp "$NVIDIA_CONF" "${NVIDIA_CONF}.bak"
        echo -e "${SUCCSESS} Backup of $NVIDIA_CONF created."
    fi

    # Create new configuration file
    if echo "options nvidia_drm modeset=1 fbdev=1" | sudo tee "$NVIDIA_CONF" > /dev/null; then
        echo -e "${SUCCSESS} NVIDIA configuration file created."
    else
        echo -e "${ERROR} Failed to create NVIDIA configuration file."
        exit 1
    fi
}

configure_grub_default() {
    # Function to add "nvidia_drm.modeset=1" to /etc/default/grub
    # only if it not exists, also backs up the grub config before
    # making these changes
    # The weird sed syntax ensures that the argument only gets added
    # and not replacing the line, keeping previous configuration safe
    echo -e "${SECTION} Configuring GRUB default..."
    GRUB_CONF="/etc/default/grub"

    if [[ -f $GRUB_CONF ]]; then
        # Backup existing configuration file if it exists
        sudo cp "$GRUB_CONF" "$GRUB_CONF.bak"
        echo -e "${SUCCSESS} Backup of $GRUB_CONF created."

        # Update the GRUB configuration
        sudo sed -i '/GRUB_CMDLINE_LINUX_DEFAULT=/!b;/nvidia_drm.modeset=1/!s/\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)/\1 nvidia_drm.modeset=1/' "$GRUB_CONF"
    else
        echo -e "${ERROR} $GRUB_CONF not found."
        exit 1
    fi
}

regenerate_initramfs() {
    # Regenerates the initramfs
    # to load the nvidia modules
    # Prepare for high CPU usage
    echo -e "${SECTION} Regenerating initramfs..."
    sudo mkinitcpio -P
}

update_grub_config() {
    # Updates the grub config at /boot/grub/grub.cfg
    # After /etc/default/grub was changed
    #
    echo -e "${SECTION} Updating GRUB config..."
    sudo grub-mkconfig -o /boot/grub/grub.cfg
}

confirm_reboot() {
    # Asks the user to reboot to apply changes
    # properly, if no is selected the script
    # will return to show_menu
    echo -e "${GREEN}Action complete.${ENDCOLOR}"
    read -rp "Would you like to reboot now? (y/N): " reboot_now
    case "$reboot_now" in
        [yY][eE][sS]|[yY])
            sudo reboot now
            ;;
        *)
            echo -e "${INFO} Please reboot your system later to apply changes."
            echo -e ""
            echo -e "\t${GREEN}Press any button to return${ENDCOLOR}"

            # Use -n1 to read a single character without the need to press enter
            read -rsn1 option

            case "$option" in
                *)
                    ;;
            esac
            ;;
    esac
}

#
# UNINSTALLATION STEPS
#

remove_nvidia_packages() {
    #
    # Uninstall the nvidia drivers, configs and unused dependencies
    #
    echo -e "${SECTION} Uninstalling NVIDIA packages..."
    sudo pacman -Rn nvidia-dkms nvidia-utils opencl-nvidia nvidia-settings lib32-nvidia-utils lib32-opencl-nvidia
}

remove_mkinitcpio() {
    # Same as the configure_mkinitcpio() function but without
    # adding the nvidia modules
    # Adds back the kms hook
    echo -e "${SECTION} Removing mkinitcpio modules..."
    MKINITCPIO_CONF="/etc/mkinitcpio.conf"

    if [[ -f $MKINITCPIO_CONF ]]; then
        # Backup existing configuration file if it exists
        sudo cp "$MKINITCPIO_CONF" "$MKINITCPIO_CONF.bak-uninstall"
        echo -e "${SUCCSESS} Backup of $MKINITCPIO_CONF created."

        # Remove any lines that are commented out and contain nothing
        echo -e "${INFO} Cleaning up $MKINITCPIO_CONF."
        sudo sed -i '/^#/d;/^$/d' "$MKINITCPIO_CONF"

        if grep -q 'MODULES=.*nvidia' "$MKINITCPIO_CONF"; then
            echo -e "${INFO} Cleaning up existing NVIDIA modules."
            # Remove any occurrences of nvidia-related modules
            sudo sed -i 's/\b\(nvidia\|nvidia_modeset\|nvidia_uvm\|nvidia_drm\)\b//g' "$MKINITCPIO_CONF"

            # Ensure exactly one space between words and no space after '(' or before ')'
            sudo sed -i 's/ ( /(/g; s/ )/)/g; s/( */(/; s/ *)/)/; s/ \+/ /g' "$MKINITCPIO_CONF"
        fi

        # Add back the kms hook
        if grep -q '\bkms\b' "$MKINITCPIO_CONF"; then
            echo -e "${INFO} kms hook is already present."
        else
            echo -e "${INFO} Adding kms hook"
            sudo sed -i 's/modconf/& kms/' "$MKINITCPIO_CONF"
        fi

        echo -e "${SUCCSESS} mkinitcpio.conf updated."
    else
        echo -e "${ERROR} $MKINITCPIO_CONF not found."
        exit 1
    fi
}

remove_modprobe() {
    # Creates a backup of the /etc/modprobe.d/nvidia.conf file
    # and deletes the original one
    #
    echo -e "${SECTION} Deleting NVIDIA configuration file..."
    NVIDIA_CONF="/etc/modprobe.d/nvidia.conf"

    # Backup existing configuration file if it exists
    if [[ -f $NVIDIA_CONF ]]; then
        sudo cp "$NVIDIA_CONF" "${NVIDIA_CONF}.bak-uninstall"
        echo -e "${SUCCSESS} Backup of $NVIDIA_CONF created."
    fi

    # Delete configuration file
    if sudo rm -f "$NVIDIA_CONF"; then
        echo -e "${SUCCSESS} NVIDIA configuration file deleted."
    else
        echo -e "${ERROR} Failed to delete NVIDIA configuration file."
        exit 1
    fi
}

remove_grub_default() {
    # Creates a backup of the /etc/default/grub file
    # Removes nvidia_drm.modeset=1 from
    # GRUB_CMDLINE_LINUX
    echo -e "${SECTION} Configuring GRUB default..."
    GRUB_CONF="/etc/default/grub"

    if [[ -f $GRUB_CONF ]]; then
        # Backup existing configuration file if it exists
        sudo cp "$GRUB_CONF" "$GRUB_CONF.bak-uninstall"
        echo -e "${SUCCSESS} Backup of $GRUB_CONF created."

        # Remove nvidia_drm.modeset=1 from GRUB_CMDLINE_LINUX
        sudo sed -i 's/nvidia_drm\.modeset=1//g' "$GRUB_CONF"
    else
        echo -e "${ERROR} $GRUB_CONF not found."
        exit 1
    fi
}

#
# INITIATE START
#

# Step 1: Set up trap for SIGINT (CTRL+C)
trap "echo -e '${RED}Exited${ENDCOLOR}' ;exit 0" SIGINT

# Step 2: Check launch arguments for extra functionality
check_args "$@"

# Step 3: Check if running as sudo
check_sudo

# Step 4: Check if NVIDIA card is present
if [[ "$FORCED_MODE" != true ]]; then
    check_nvidia
fi

# Step 5: Show selection menu
show_menu
