#!/bin/bash

echo "      :::::::::  :::    :::  ::::::::  :::    ::: :::    ::: ::::    ::: ::::::::::: "
echo "     :+:    :+: :+:    :+: :+:    :+: :+:    :+: :+:    :+: :+:+:   :+:     :+:      "
echo "    +:+    +:+ +:+    +:+ +:+        +:+    +:+ +:+    +:+ :+:+:+  +:+     +:+       "
echo "   +#++:++#+  +#+    +:+ :#:        +#++:++#++ +#+    +:+ +#+ +:+ +#+     +#+        "
echo "  +#+    +#+ +#+    +#+ +#+   +#+# +#+    +#+ +#+    +#+ +#+  +#+#+#     +#+         "
echo " #+#    #+# #+#    #+# #+#    #+# #+#    #+# #+#    #+# #+#   #+#+#     #+#          "
echo "#########   ########   ########  ###    ###  ########  ###    ####     ###           "

# Load environment variables if needed
# source .env

# Set default value for RUN_NUCLEI
RUN_NUCLEI=false

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --run-nuclei) RUN_NUCLEI=true ;;
        *) DOMAIN_FILE=$1 ;;
    esac
    shift
done

# Function to normalize a domain
normalize_domain() {
  local DOMAIN=$1
  # Remove any protocol (http, https)
  DOMAIN=$(echo $DOMAIN | sed -e 's~http[s]*://~~g')
  # Remove any path or query parameters
  DOMAIN=$(echo $DOMAIN | cut -d '/' -f 1)
  # Remove any port numbers
  DOMAIN=$(echo $DOMAIN | cut -d ':' -f 1)
  # Handle wildcards and subdomains
  DOMAIN=$(echo $DOMAIN | sed -e 's/*\.//g' -e 's/\.\*//g')
  # Extract root domain
  DOMAIN=$(echo $DOMAIN | awk -F'.' '{if (NF>2) print $(NF-1)"."$NF; else print $0}')
  echo $DOMAIN
}

# Function to create combinations of root domain with TLDs
enumerate_wildcard_tlds() {
  local ROOT_DOMAIN=$1
  local TLD_FILE=$2
  local OUTPUT_FILE=$3
  while read -r TLD; do
    echo "${ROOT_DOMAIN}.${TLD}"
  done < "$TLD_FILE" > "$OUTPUT_FILE"
}

# Function to check if the domain exists using dig
check_domain_exists() {
  local DOMAIN=$1
  if dig +short "$DOMAIN" | grep -q "."; then
    echo "Domain $DOMAIN exists."
    return 0
  else
    echo "Domain $DOMAIN does not exist."
    return 1
  fi
}

# Check if a domain file is provided
if [ -z "$DOMAIN_FILE" ]; then
  echo "No domain file provided."
  exit 1
fi

# Create necessary directories and files
mkdir -p "$(pwd)/data"
touch "$(pwd)/data/recon.log"
mkdir -p "$(pwd)/home/gau"
touch "$(pwd)/home/gau/.gau.toml"

# Define log file
LOGFILE="$(pwd)/data/recon.log"

# Function to log errors
log_error() {
  echo "[ERROR] $1" >> $LOGFILE
}

process_domain() {
  local RAW_DOMAIN=$1
  local DOMAIN=$(normalize_domain $RAW_DOMAIN)
  local DOMAIN_DIR=$(echo $DOMAIN | tr -d '*')

  # Create domain-specific directories
  mkdir -p "$(pwd)/data/$DOMAIN_DIR"

  # Create necessary files for each domain
  touch "$(pwd)/data/$DOMAIN_DIR/urls.txt"
  touch "$(pwd)/data/$DOMAIN_DIR/js_urls.txt"
  touch "$(pwd)/data/$DOMAIN_DIR/arjun_output.txt"
  touch "$(pwd)/data/$DOMAIN_DIR/dalfox_output.txt"
  touch "$(pwd)/data/$DOMAIN_DIR/params.txt"
  touch "$(pwd)/data/$DOMAIN_DIR/subfinder_output.txt"
  touch "$(pwd)/data/$DOMAIN_DIR/amass_enum_output.txt"
  touch "$(pwd)/data/$DOMAIN_DIR/final_subdomains.txt"
  touch "$(pwd)/data/$DOMAIN_DIR/live_hosts.txt"

  # Enumerate TLDs if the domain has a TLD wildcard
  if [[ $RAW_DOMAIN == *"*" && $RAW_DOMAIN == *.* ]]; then
    echo "Enumerating TLDs for $DOMAIN..."
    ROOT_DOMAIN=$(echo $RAW_DOMAIN | sed -e 's/\.\*$//' -e 's/*\.//g')
    TLD_LIST_FILE="$(pwd)/tld_list.txt"
    if [ ! -f "$TLD_LIST_FILE" ]; then
      echo "TLD list file not found: $TLD_LIST_FILE"
      log_error "TLD list file not found: $TLD_LIST_FILE"
      return 1
    fi
    enumerate_wildcard_tlds $ROOT_DOMAIN "$TLD_LIST_FILE" "$(pwd)/data/$DOMAIN_DIR/possible_domains.txt"
    if [ ! -f "$(pwd)/data/$DOMAIN_DIR/possible_domains.txt" ]; then
      echo "Failed to create possible_domains.txt"
      log_error "Failed to create possible_domains.txt"
      return 1
    fi
    while read -r POSSIBLE_DOMAIN; do
      if check_domain_exists "$POSSIBLE_DOMAIN"; then
        process_valid_domain "$POSSIBLE_DOMAIN" "$DOMAIN_DIR"
      fi
    done < "$(pwd)/data/$DOMAIN_DIR/possible_domains.txt"
  else
    if check_domain_exists "$DOMAIN"; then
      process_valid_domain "$DOMAIN" "$DOMAIN_DIR"
    fi
  fi
}

process_valid_domain() {
  local DOMAIN=$1
  local DOMAIN_DIR=$2

  echo "Running Subfinder for $DOMAIN..."
  if ! DOMAIN=$DOMAIN DOMAIN_DIR=$DOMAIN_DIR docker compose run --rm -T subfinder -d $DOMAIN -o /app/data/${DOMAIN_DIR}/subfinder_output.txt; then
    log_error "Subfinder failed for $DOMAIN"
  fi

  # Combine results and check live hosts with HTTPX
  echo "Probing with HTTPX for $DOMAIN..."
  cat "$(pwd)/data/${DOMAIN_DIR}/subfinder_output.txt" 2>/dev/null | sort -u > "$(pwd)/data/${DOMAIN_DIR}/final_subdomains.txt"
  if [ -s "$(pwd)/data/${DOMAIN_DIR}/final_subdomains.txt" ]; then
    if ! DOMAIN=$DOMAIN DOMAIN_DIR=$DOMAIN_DIR docker compose run --rm -T httpx -l /app/data/${DOMAIN_DIR}/final_subdomains.txt -o /app/data/${DOMAIN_DIR}/live_hosts.txt; then
      log_error "HTTPX failed for $DOMAIN"
    fi
  else
    log_error "No subdomains found for $DOMAIN"
  fi

  # Run Gau
  echo "Running Gau for $DOMAIN..."
  if ! DOMAIN=$DOMAIN DOMAIN_DIR=$DOMAIN_DIR docker compose run --rm -T gau -o /app/data/${DOMAIN_DIR}/urls.txt; then
    log_error "Gau failed for $DOMAIN"
  fi

  # Organize directories
  echo "Organizing directories for $DOMAIN..."
  mkdir -p "$(pwd)/data/${DOMAIN_DIR}/recon/subdomains" "$(pwd)/data/${DOMAIN_DIR}/recon/urls" "$(pwd)/data/${DOMAIN_DIR}/recon/ips"
  mv "$(pwd)/data/${DOMAIN_DIR}/urls.txt" "$(pwd)/data/${DOMAIN_DIR}/recon/urls/"

  # Sort and filter URLs
  echo "Sorting and filtering URLs for $DOMAIN..."
  sort -u "$(pwd)/data/${DOMAIN_DIR}/recon/urls/urls.txt" -o "$(pwd)/data/${DOMAIN_DIR}/recon/urls/urls.txt"

  # Create individual .txt files for each IP, subdomain, and URL
  awk '{print > "'$(pwd)'/data/'${DOMAIN_DIR}'/recon/subdomains/"$1".txt"}' "$(pwd)/data/${DOMAIN_DIR}/final_subdomains.txt"
  awk '{print > "'$(pwd)'/data/'${DOMAIN_DIR}'/recon/ips/"$1".txt"}' "$(pwd)/data/${DOMAIN_DIR}/live_hosts.txt"
  awk '{print > "'$(pwd)'/data/'${DOMAIN_DIR}'/recon/urls/"$1".txt"}' "$(pwd)/data/${DOMAIN_DIR}/recon/urls/urls.txt"

  # Optionally run Nuclei
  if [ "$RUN_NUCLEI" = true ]; then
    echo "Running Nuclei for $DOMAIN..."
    if ! DOMAIN=$DOMAIN DOMAIN_DIR=$DOMAIN_DIR docker compose run --rm -T nuclei -l /app/data/${DOMAIN_DIR}/live_hosts.txt -t /root/nuclei-templates -o /app/data/${DOMAIN_DIR}/nuclei_output.txt -rl 50 -c 25; then
      log_error "Nuclei failed for $DOMAIN"
    fi
  fi

  # Run Arjun
  echo "Running Arjun for $DOMAIN..."
  if ! DOMAIN=$DOMAIN DOMAIN_DIR=$

