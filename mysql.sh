#!/bin/bash

# DDS : DailyDigtalSKiills
# This script will guide you through the process of setting up Marzban on MySQL.
# It will install the necessary dependencies and create the necessary files.
# After that, you will be prompted to provide the necessary information.
# YOUTUBE LINK: https://www.youtube.com/@DailyDigtalSKiills
#Telegram: @DailyDigtalSKiills


# Set up colors
# Colors
colors=(
    "\033[38;2;255;105;180m"  # Foreground (#EA549F)
    "\033[38;2;255;20;147m"   # Red (#E92888)
    "\033[38;2;0;255;144m"    # Green (#4EC9B0)
    "\033[38;2;0;191;255m"    # Blue (#579BD5)
    "\033[38;2;102;204;255m"  # Bright Blue (#9CDCFE)
    "\033[38;2;242;242;242m"  # Bright White (#EAEAEA)
    "\033[38;2;0;255;255m"    # Cyan (#00B6D6)
    "\033[38;2;255;215;0m"    # Bright Yellow (#e9ad95)
    "\033[38;2;160;32;240m"   # Purple (#714896)
    "\033[38;2;255;36;99m"    # Bright Red (#EB2A88)
    "\033[38;2;0;255;100m"    # Bright Green (#1AD69C)
    "\033[38;2;0;255;255m"    # Bright Cyan (#2BC4E2)
    "\033[0m"                 # Reset
)
foreground=${colors[0]} red=${colors[1]} green=${colors[2]} blue=${colors[3]} brightBlue=${colors[4]} brightWhite=${colors[5]} cyan=${colors[6]} brightYellow=${colors[7]} purple=${colors[8]} brightRed=${colors[9]} brightGreen=${colors[10]} brightCyan=${colors[11]} reset=${colors[12]}

# Helper functions
print() { echo -e "${cyan}$1${reset}"; }
error() { echo -e "${red}✗ $1${reset}"; }
success() { echo -e "${green}✓ $1${reset}"; }
log() { echo -e "${blue}! $1${reset}"; }
input() { read -p "$(echo -e "${brightYellow}▶ $1${reset}")" "$2"; }
confirm() { read -p "$(echo -e "\n${purple}Press any key to continue...${reset}")"; }

check_success() {
    if [ $? -eq 0 ]; then
        success "$1"
    else
        error "$2"
        exit 1
    fi
}


# Function to install essentials with logging and debugging
install_essentials() {
    log "Starting the update and upgrade process."
    
    # Update and upgrade system packages with error handling
    apt update -y > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        log "System packages updated successfully."
    else
        error "Failed to update system packages."
        exit 1
    fi

    apt upgrade -y > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        log "System packages upgraded successfully."
    else
        error "Failed to upgrade system packages."
        exit 1
    fi

    # Install sqlite3 with error handling
    log "Installing SQLite3..."
    apt install -y sqlite3 > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        success "SQLite3 installed successfully."
    else
        error "Failed to install SQLite3."
        exit 1
    fi
}

# Function to get user input with logging
get_input() {
    default_docker_compose_path="/opt/marzban/docker-compose.yml"
    default_env_file_path="/opt/marzban/.env"

    print "Please provide the following information:"
    #password not empty
    while true; do
    input "Enter MySQL root password: " DB_PASSWORD
    if [ -z "$DB_PASSWORD" ]; then
        error "Password cannot be empty."
    else
        log "MySQL root password provided."
        break
    fi
    done
    log "MySQL root password provided."

    while true; do
        input "Enter the path for docker-compose.yml [${default_docker_compose_path}]: " DOCKER_COMPOSE_PATH
        DOCKER_COMPOSE_PATH=${DOCKER_COMPOSE_PATH:-$default_docker_compose_path}
        if [[ ! -f $DOCKER_COMPOSE_PATH ]]; then
            error "The file $DOCKER_COMPOSE_PATH does not exist."
        else
            log "docker-compose.yml path set to: $DOCKER_COMPOSE_PATH"
            break
        fi
    done

    while true; do
        input  "Enter the path for .env file [${default_env_file_path}]: " ENV_FILE_PATH
        ENV_FILE_PATH=${ENV_FILE_PATH:-$default_env_file_path}
        if [[ ! -f $ENV_FILE_PATH ]]; then
            error "The file $ENV_FILE_PATH does not exist."
        else
            log ".env file path set to: $ENV_FILE_PATH"
            break
        fi
    done

while true; do
    input "Do you want to install phpMyAdmin? (yes / no) [yes]:" INSTALL_PHPMYADMIN
    INSTALL_PHPMYADMIN=${INSTALL_PHPMYADMIN:-yes}
    
    if [ "$INSTALL_PHPMYADMIN" = "yes" ]; then
        input "Enter the port for phpMyAdmin [8010]: " PHPMYADMIN_PORT
        PHPMYADMIN_PORT=${PHPMYADMIN_PORT:-8010}
        
        if ! [[ "$PHPMYADMIN_PORT" =~ ^[0-9]+$ ]]; then
            error "The port $PHPMYADMIN_PORT is not valid."
            continue
        fi

        if lsof -i :$PHPMYADMIN_PORT > /dev/null; then
            error "The port $PHPMYADMIN_PORT is already in use."
            continue
        fi

        log "phpMyAdmin installation set to: $INSTALL_PHPMYADMIN"
        break
    
    elif [ "$INSTALL_PHPMYADMIN" = "no" ]; then
        log "phpMyAdmin installation set to: $INSTALL_PHPMYADMIN"
        break
    
    else
        error "Invalid input. Please enter either 'yes' or 'no'."
    fi
done


}


Backup_Database() {
    local ENV_FILE_PATH="$1"
    local DOCKER_COMPOSE_PATH="$2"

    # Backup the original .env file with time stamp
    cp "$ENV_FILE_PATH" "${ENV_FILE_PATH}_$(date +%Y%m%d_%H%M%S).bak" > /dev/null 2>&1
    check_success "Original .env file backed up successfully on $(date +%Y%m%d_%H%M%S)." "Failed to backup original .env file."
    cp "$DOCKER_COMPOSE_PATH" "${DOCKER_COMPOSE_PATH}_$(date +%Y%m%d_%H%M%S).bak" > /dev/null 2>&1
    check_success "Original docker-compose.yml file backed up successfully on $(date +%Y%m%d_%H%M%S)." "Failed to backup original docker-compose.yml file."
    cp /var/lib/marzban/db.sqlite3 /var/lib/marzban/db.sqlite3_$(date +%Y%m%d_%H%M%S).bak > /dev/null 2>&1
    check_success "Original db.sqlite3 file backed up successfully on $(date +%Y%m%d_%H%M%S)." "Failed to backup original db.sqlite3 file."

}
# Function to upgrade to MySQL with logging
upgrade_to_mysql() {
    # Detect CPU architecture
    ARCHITECTURE=$(uname -m)
    if [[ "$ARCHITECTURE" == "arm64" || "$ARCHITECTURE" == "aarch64" ]]; then
        PHPMYADMIN_IMAGE="arm64v8/phpmyadmin:latest"
        log "Detected ARM architecture. Using $PHPMYADMIN_IMAGE for phpMyAdmin."
    else
        PHPMYADMIN_IMAGE="phpmyadmin/phpmyadmin:latest"
        log "Detected non-ARM architecture. Using $PHPMYADMIN_IMAGE for phpMyAdmin."
    fi

    log "Creating docker-compose.yml at $DOCKER_COMPOSE_PATH..."
    cat <<EOF > $DOCKER_COMPOSE_PATH
services:
  marzban:
    image: gozargah/marzban:latest
    restart: always
    env_file: .env
    network_mode: host
    volumes:
      - /var/lib/marzban:/var/lib/marzban
    depends_on:
      - mysql

  mysql:
    image: mysql:latest
    restart: always
    env_file: .env
    network_mode: host
    command: --bind-address=127.0.0.1 --mysqlx-bind-address=127.0.0.1 --disable-log-bin
    environment:
      MYSQL_DATABASE: marzban
    volumes:
      - /var/lib/marzban/mysql:/var/lib/mysql
EOF

    if [ "$INSTALL_PHPMYADMIN" = "yes" ]; then
        log "Adding phpMyAdmin to docker-compose.yml..."
        cat <<EOF >> $DOCKER_COMPOSE_PATH

  phpmyadmin:
    image: $PHPMYADMIN_IMAGE
    restart: always
    env_file: .env
    network_mode: host
    environment:
      PMA_HOST: 127.0.0.1
      APACHE_PORT: ${PHPMYADMIN_PORT}
      UPLOAD_LIMIT: 1024M
    depends_on:
      - mysql
EOF
    fi

    check_success "docker-compose.yml created at $DOCKER_COMPOSE_PATH" "Failed to create docker-compose.yml."

    if [[ ! -f $ENV_FILE_PATH ]]; then
        error "The file $ENV_FILE_PATH does not exist."
        exit 1
    fi



    # Comment out existing SQLALCHEMY_DATABASE_URL and MYSQL_ROOT_PASSWORD lines


        # Check if the SQLALCHEMY_DATABASE_URL line exists
        if grep -q '^SQLALCHEMY_DATABASE_URL' "$ENV_FILE_PATH"; then
            # If SQLALCHEMY_DATABASE_URL exists, comment it out
            sed -i 's/^SQLALCHEMY_DATABASE_URL.*/#&/' "$ENV_FILE_PATH" > /dev/null 2>&1
            check_success "Commented out existing SQLALCHEMY_DATABASE_URL line."  "Failed to comment out existing SQLALCHEMY_DATABASE_URL line."
        else
            error "No SQLALCHEMY_DATABASE_URL line found to comment out."
        fi
        # Check if the MYSQL_ROOT_PASSWORD line exists
        if grep -q '^MYSQL_ROOT_PASSWORD' "$ENV_FILE_PATH"; then
            # If MYSQL_ROOT_PASSWORD exists, comment it out
            sed -i 's/^MYSQL_ROOT_PASSWORD.*/#&/' "$ENV_FILE_PATH" > /dev/null 2>&1
            check_success "Commented out existing MYSQL_ROOT_PASSWORD line."  "Failed to comment out existing MYSQL_ROOT_PASSWORD line."
        else
            error "No MYSQL_ROOT_PASSWORD line found to comment out."
        fi

    # Append the new lines
    {
        echo "SQLALCHEMY_DATABASE_URL=\"mysql+pymysql://root:${DB_PASSWORD}@127.0.0.1/marzban\""
        echo "MYSQL_ROOT_PASSWORD=${DB_PASSWORD}"
    } >> "$ENV_FILE_PATH"

       
        docker compose -f $DOCKER_COMPOSE_PATH down 
        # Function to remove old MySQL and phpMyAdmin images with logging and error handling
        if docker images | grep -q "mysql"; then
            echo "MySQL image found. Removing..."
            docker rmi -f mysql:latest > /dev/null 2>&1
            check_success "MySQL image removed successfully." "Failed to remove MySQL image."
            sudo rm -rf /var/lib/marzban/mysql/* > /dev/null 2>&1
            check_success "MySQL data directory removed successfully." "Failed to remove MySQL data directory."
        else
            echo "MySQL image not found."
        fi

        # Remove old MySQL and phpMyAdmin images
        if docker images | grep -q "phpmyadmin/phpmyadmin"; then
            echo "phpMyAdmin image found. Removing..."
            docker rmi -f phpmyadmin/phpmyadmin:latest > /dev/null 2>&1
            check_success "phpMyAdmin image removed successfully." "Failed to remove phpMyAdmin image."
        else
            echo "phpMyAdmin image not found."
        fi

    log "Restarting Marzban services..."
    docker compose -f $DOCKER_COMPOSE_PATH up -d mysql > /dev/null 2>&1
    check_success "MySQL service started successfully." "Failed to start MySQL service."
    docker compose -f $DOCKER_COMPOSE_PATH up -d phpmyadmin >/dev/null 2>&1
    check_success "phpMyAdmin service started successfully." "Failed to start phpMyAdmin service."
    docker compose -f $DOCKER_COMPOSE_PATH up -d marzban >/dev/null 2>&1
    check_success "Marzban service started successfully." "Failed to start Marzban service."
    docker compose -f $DOCKER_COMPOSE_PATH restart marzban >/dev/null 2>&1
    check_success "Marzban service restarted successfully." "Failed to restart Marzban service."
    docker compose -f $DOCKER_COMPOSE_PATH restart > /dev/null 2>&1
    check_success "All Marzban services restarted successfully." "Failed to restart AllMarzban services."
    
}

# Function to wait for Marzban to be fully operational



# Function to migrate the database with logging and error handling
migrate_database() {
    log "Transferring data from SQLite to MySQL..."
    
    sqlite3 /var/lib/marzban/db.sqlite3 '.dump --data-only' | sed "s/INSERT INTO \([^ ]*\)/REPLACE INTO \`\1\`/g" > /tmp/dump.sql
    check_success "SQLite dump created successfully." "Failed to create SQLite dump."

    docker compose -f $DOCKER_COMPOSE_PATH cp /tmp/dump.sql mysql:/dump.sql>/dev/null 2>&1
    check_success "SQLite dump copied to MySQL container successfully." "Failed to copy SQLite dump to MySQL container."

    docker compose -f $DOCKER_COMPOSE_PATH  exec mysql mysql -u root -p"${DB_PASSWORD}" -h 127.0.0.1 marzban -e "SET FOREIGN_KEY_CHECKS = 0; SET NAMES utf8mb4; SOURCE /dump.sql;" >/dev/null 2>&1
    check_success "Data transfer completed successfully." "Failed to transfer data from SQLite to MySQL."

    rm /tmp/dump.sql > /dev/null 2>&1
    check_success "SQLite dump removed successfully." "Failed to remove SQLite dump."
    check_success "Data transfer completed successfully." "Failed to transfer data from SQLite to MySQL."
    docker compose -f $DOCKER_COMPOSE_PATH down  > /dev/null 2>&1
    check_success "Marzban service STOPPED successfully." "Failed to Stop Marzban service."
    docker compose -f $DOCKER_COMPOSE_PATH up -d > /dev/null 2>&1
    check_success "Marzban service Started successfully." "Failed to Start Marzban service."
    docker compose -f $DOCKER_COMPOSE_PATH restart > /dev/null 2>&1
    check_success "Marzban service restarted successfully." "Failed to restart Marzban service."

    success "Data transfer and Marzban restart completed successfully."
    log " "
    log " _"
    if [ "$INSTALL_PHPMYADMIN" = "yes" ]; then
        log " |${brightGreen} Marzban is now running on MySQL with phpMyAdmin.${reset}"
    else
        log " |${brightGreen} Marzban is now running on MySQL.${reset}"
    fi
    log " |"
    success " |${brightCyan} Please visit http://IP:${PHPMYADMIN_PORT} to access PHPMyAdmin.${reset}"
    log " |"
    log " |${brightYellow} Username: root${reset}"
    log " |${brightYellow} Password: ${DB_PASSWORD}${reset}"
    log " |"
    success " Backups of the original .env and docker-compose.yml files have been created in the same directory with a timestamp."
    confirm
}


# Main menu function
menu() {
    local choice_Option=''
    while true; do
        print ""
        print ""
        log " __________________GITHUB :@azavaxhuman__________________"
        print ""
        print ""
        success " Welcome to the SQLite3 to MySQL migration (Marzban) setup script."
        print ""           
        success "@DailyDigtalSKiills"
        print ""
        error "Please choose an option:"
        print ""
        print "1. Start Migration"
        print "0. Exit"
        print ""
        input "Enter your choice: " choice_Option
        case $choice_Option in
            1)
                install_essentials
                get_input 
                Backup_Database "$ENV_FILE_PATH" "$DOCKER_COMPOSE_PATH"
                if [ $? -ne 0 ]; then
                error "Backup failed. Exiting."
                exit 0
                fi
                upgrade_to_mysql
                migrate_database
                ;;
            0)
                print "Exiting setup script. Goodbye!"
                exit 0
                ;;
            *)
                error "Invalid choice. Please try again."
                ;;
        esac
    done
}












# Start the script
clear
menu
