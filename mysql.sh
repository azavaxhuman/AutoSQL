#!/bin/bash
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



# Function to display a progress bar
show_progress() {
    local duration=$1
    local steps=100
    local step_duration=$((duration / steps))
    for ((i = 0; i <= steps; i++)); do
        echo $i
        sleep $step_duration
    done
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

# Main menu function
menu() {
    while true; do
        print ""

        success " Welcome to the SQLite3 to MySQL migration (Marzban) setup script."
        log " "
        log " ________________________________________________________________________"
        log " "
                
        success "@DailyDigtalSKiills" 
        log " This script will guide you through the process of setting up Marzban on MySQL."
        log " It will install the necessary dependencies and create the necessary files."
        log " After that, you will be prompted to provide the necessary information."
        log " Finally, you will be prompted to choose an option to start the migration."
    
        log " "
        error "Please choose an option:"
        print "1. Start Migration"
        print "0. Exit"

        input "Enter your choice: " choice
        case $choice in
            1)
                install_essentials
                get_input
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

# Function to get user input with logging
get_input() {
    default_docker_compose_path="/opt/marzban/docker-compose.yml"
    default_env_file_path="/opt/marzban/.env"

    print "Please provide the following information:"
    input "Enter MySQL root password: " DB_PASSWORD
    log "MySQL root password provided."

    input "Enter the path for docker-compose.yml [${default_docker_compose_path}]: " DOCKER_COMPOSE_PATH
    DOCKER_COMPOSE_PATH=${DOCKER_COMPOSE_PATH:-$default_docker_compose_path}
    log "docker-compose.yml path set to: $DOCKER_COMPOSE_PATH"

    input "Enter the path for .env file [${default_env_file_path}]: " ENV_FILE_PATH
    ENV_FILE_PATH=${ENV_FILE_PATH:-$default_env_file_path}
    log ".env file path set to: $ENV_FILE_PATH"

    input "Do you want to install phpMyAdmin? (yes/no) [no]: " INSTALL_PHPMYADMIN
    INSTALL_PHPMYADMIN=${INSTALL_PHPMYADMIN:-no}
    log "phpMyAdmin installation set to: $INSTALL_PHPMYADMIN"

    if [ "$INSTALL_PHPMYADMIN" = "yes" ]; then
        input "Enter the port for phpMyAdmin [8010]: " PHPMYADMIN_PORT
        PHPMYADMIN_PORT=${PHPMYADMIN_PORT:-8010}
        log "phpMyAdmin port set to: $PHPMYADMIN_PORT"
    fi
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

    success "docker-compose.yml created at $DOCKER_COMPOSE_PATH"

    if [[ ! -f $ENV_FILE_PATH ]]; then
        error "The file $ENV_FILE_PATH does not exist."
        exit 1
    fi

    # Backup the original .env file
    cp "$ENV_FILE_PATH" "${ENV_FILE_PATH}.bak"


        # Check if the SQLALCHEMY_DATABASE_URL line exists
        if grep -q '^SQLALCHEMY_DATABASE_URL' "$ENV_FILE_PATH"; then
            # If SQLALCHEMY_DATABASE_URL exists, comment it out
            sed -i 's/^SQLALCHEMY_DATABASE_URL.*/#&/' "$ENV_FILE_PATH"
            success "Commented out existing SQLALCHEMY_DATABASE_URL line."
        else
            error "No SQLALCHEMY_DATABASE_URL line found to comment out."
        fi
        # Check if the MYSQL_ROOT_PASSWORD line exists
        if grep -q '^MYSQL_ROOT_PASSWORD' "$ENV_FILE_PATH"; then
            # If MYSQL_ROOT_PASSWORD exists, comment it out
            sed -i 's/^MYSQL_ROOT_PASSWORD.*/#&/' "$ENV_FILE_PATH"
            success "Commented out existing MYSQL_ROOT_PASSWORD line."
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
            docker rmi -f mysql:latest
            sudo rm -rf /var/lib/marzban/mysql/*
            success "MySQL data directory removed successfully."
        else
            echo "MySQL image not found."
        fi

        # Remove old MySQL and phpMyAdmin images
        if docker images | grep -q "phpmyadmin/phpmyadmin"; then
            echo "phpMyAdmin image found. Removing..."
            docker rmi -f phpmyadmin/phpmyadmin:latest
        else
            echo "phpMyAdmin image not found."
        fi

    log "Restarting Marzban services..."
    docker compose -f $DOCKER_COMPOSE_PATH up -d mysql
    docker compose -f $DOCKER_COMPOSE_PATH up -d phpmyadmin
    docker compose -f $DOCKER_COMPOSE_PATH up -d marzban
    docker compose -f $DOCKER_COMPOSE_PATH restart marzban
    docker compose -f $DOCKER_COMPOSE_PATH restart 
    
    if [ $? -eq 0 ]; then
        success "Marzban service restarted successfully."
    else
        error "Failed to restart Marzban service."
        exit 1
    fi
}

# Function to wait for Marzban to be fully operational



# Function to migrate the database with logging and error handling
migrate_database() {
    log "Transferring data from SQLite to MySQL..."
    
    sqlite3 /var/lib/marzban/db.sqlite3 '.dump --data-only' | sed "s/INSERT INTO \([^ ]*\)/REPLACE INTO \`\1\`/g" > /tmp/dump.sql
    if [ $? -eq 0 ]; then
        log "SQLite dump created successfully."
    else
        error "Failed to create SQLite dump."
        exit 1
    fi

    docker compose -f $DOCKER_COMPOSE_PATH cp /tmp/dump.sql mysql:/dump.sql


    if [ $? -eq 0 ]; then
        log "Dump file copied to MySQL container successfully."
    else
        error "Failed to copy dump file to MySQL container."
        exit 1
    fi

    docker compose -f $DOCKER_COMPOSE_PATH  exec mysql mysql -u root -p"${DB_PASSWORD}" -h 127.0.0.1 marzban -e "SET FOREIGN_KEY_CHECKS = 0; SET NAMES utf8mb4; SOURCE /dump.sql;"
    if [ $? -eq 0 ]; then
        log "Data imported into MySQL successfully."
    else
        error "Failed to import data into MySQL."
        exit 1
    fi

    rm /tmp/dump.sql
    if [ $? -eq 0 ]; then
        log "Temporary dump file removed successfully."
    else
        error "Failed to remove temporary dump file."
        exit 1
    fi
    docker compose -f $DOCKER_COMPOSE_PATH down 
    docker compose -f $DOCKER_COMPOSE_PATH up -d 
    docker compose -f $DOCKER_COMPOSE_PATH restart 


    if [ $? -eq 0 ]; then
        success "Marzban restarted successfully."
    else
        error "Failed to restart Marzban."
        exit 1
    fi

    success "Data transfer and Marzban restart completed successfully."
    confirm
}

# Start the script
clear
menu
