#!/bin/bash

echo "      :::::::::  :::    :::  ::::::::  :::    ::: :::    ::: ::::    ::: ::::::::::: "
echo "     :+:    :+: :+:    :+: :+:    :+: :+:    :+: :+:    :+: :+:+:   :+:     :+:      "
echo "    +:+    +:+ +:+    +:+ +:+        +:+    +:+ +:+    +:+ :+:+:+  +:+     +:+       "
echo "   +#++:++#+  +#+    +:+ :#:        +#++:++#++ +#+    +:+ +#+ +:+ +#+     +#+        "
echo "  +#+    +#+ +#+    +#+ +#+   +#+# +#+    +#+ +#+    +#+ +#+  +#+#+#     +#+         "
echo " #+#    #+# #+#    #+# #+#    #+# #+#    #+# #+#    #+# #+#   #+#+#     #+#          "
echo "#########   ########   ########  ###    ###  ########  ###    ####     ###           "

# Set default value for RUN_NUCLEI
RUN_NUCLEI=false
DOMAIN_FILE=$1

# Function to normalize a domain
normalize_domain() {
  local DOMAIN=$1
  DOMAIN=$(echo $DOMAIN | sed -e 's~http[s]*://~~g')
  DOMAIN=$(echo $DOMAIN | cut -d '/' -f 1)
  DOMAIN=$(echo $DOMAIN | cut -d ':' -f 1)
  DOMAIN=$(echo $DOMAIN | sed -e 's/*\.//g' -e 's/\.\*//g')
  echo $DOMAIN
}

# Function to create combinations of root domain with TLDs
enumerate_wildcard_tlds() {
  local ROOT_DOMAIN=$1
  local TLD_FILE="/tld_list.txt"
  while read -r TLD; do
    echo "${ROOT_DOMAIN}.${TLD}"
  done < "$TLD_FILE"
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

echo "Using domain file: $DOMAIN_FILE"

# Ensure the data directory exists and has correct permissions
mkdir -p "/data"
chmod -R 755 "/data"
touch "/data/recon.log"

# Define log file
LOGFILE="/data/recon.log"

# Function to log errors
log_error() {
  echo "[ERROR] $1" >> $LOGFILE
}

process_domain() {
  local RAW_DOMAIN=$1
  echo "Processing domain: $RAW_DOMAIN"
  local DOMAIN=$(normalize_domain $RAW_DOMAIN)
  local DOMAIN_DIR=$(echo $DOMAIN | tr -d '*')

  export DOMAIN
  export DOMAIN_DIR

  # Create domain-specific directories
  mkdir -p "/data/$DOMAIN_DIR/recon/subdomains"
  mkdir -p "/data/$DOMAIN_DIR/recon/urls"
  mkdir -p "/data/$DOMAIN_DIR/recon/ips"

  # Create necessary files for each domain
  touch "/data/$DOMAIN_DIR/urls.txt"
  touch "/data/$DOMAIN_DIR/js_urls.txt"
  touch "/data/$DOMAIN_DIR/arjun_output.txt"
  touch "/data/$DOMAIN_DIR/dalfox_output.txt"
  touch "/data/$DOMAIN_DIR/params.txt"
  touch "/data/$DOMAIN_DIR/subfinder_output.txt"
  touch "/data/$DOMAIN_DIR/amass_enum_output.txt"
  touch "/data/$DOMAIN_DIR/final_subdomains.txt"
  touch "/data/$DOMAIN_DIR/live_hosts.txt"

  echo "Running Subfinder for $DOMAIN..."
  if ! subfinder -silent -d $DOMAIN -o "/data/${DOMAIN_DIR}/subfinder_output.txt"; then
    log_error "Subfinder failed for $DOMAIN"
  fi

  # Combine results and check live hosts with HTTPX
  echo "Probing with HTTPX for $DOMAIN..."
  cat "/data/${DOMAIN_DIR}/subfinder_output.txt" 2>/dev/null | sort -u > "/data/${DOMAIN_DIR}/final_subdomains.txt"
  if [ -s "/data/${DOMAIN_DIR}/final_subdomains.txt" ]; then
    if ! httpx -silent -l "/data/${DOMAIN_DIR}/final_subdomains.txt" -o "/data/${DOMAIN_DIR}/live_hosts.txt"; then
      log_error "HTTPX failed for $DOMAIN"
    fi
  else
    log_error "No subdomains found for $DOMAIN"
  fi

  # Run Gau
  echo "Running Gau for $DOMAIN..."
  if ! gau $DOMAIN --subs --threads 5 --providers wayback,commoncrawl,otx,urlscan --o "/data/${DOMAIN_DIR}/urls.txt"; then
    log_error "Gau failed for $DOMAIN"
  fi

  # Organize directories
  echo "Organizing directories for $DOMAIN..."
  mkdir -p "/data/${DOMAIN_DIR}/recon/subdomains" "/data/${DOMAIN_DIR}/recon/urls" "/data/${DOMAIN_DIR}/recon/ips"
  mv "/data/${DOMAIN_DIR}/urls.txt" "/data/${DOMAIN_DIR}/recon/urls/"

  # Sort and filter URLs
  echo "Sorting and filtering URLs for $DOMAIN..."
  sort -u "/data/${DOMAIN_DIR}/recon/urls/urls.txt" -o "/data/${DOMAIN_DIR}/recon/urls/urls.txt"

  # Create individual .txt files for each IP, subdomain, and URL
  awk '{print > "/data/'${DOMAIN_DIR}'/recon/subdomains/"$1".txt"}' "/data/${DOMAIN_DIR}/final_subdomains.txt"
  awk '{print > "/data/'${DOMAIN_DIR}'/recon/ips/"$1".txt"}' "/data/${DOMAIN_DIR}/live_hosts.txt"
  awk '{print > "/data/'${DOMAIN_DIR}'/recon/urls/"$1".txt"}' "/data/${DOMAIN_DIR}/recon/urls/urls.txt"

  # Optionally run Nuclei
  if [ "$RUN_NUCLEI" = true ]; then
    echo "Running Nuclei for $DOMAIN..."
    if ! nuclei -silent -l "/data/${DOMAIN_DIR}/live_hosts.txt" -t /root/nuclei-templates -o "/data/${DOMAIN_DIR}/nuclei_output.txt" -rl 50 -c 25; then
      log_error "Nuclei failed for $DOMAIN"
    fi
  fi

  # Run Arjun
  echo "Running Arjun for $DOMAIN..."
  if ! arjun -i "/data/${DOMAIN_DIR}/recon/urls/urls.txt" -o "/data/${DOMAIN_DIR}/arjun_output.txt"; then
    log_error "Arjun failed for $DOMAIN"
  fi

  # Run Dalfox
  echo "Running Dalfox for $DOMAIN..."
  if ! dalfox file "/data/${DOMAIN_DIR}/recon/urls/urls.txt" --silence --no-spinner -o "/data/${DOMAIN_DIR}/dalfox_output.txt"; then
    log_error "Dalfox failed for $DOMAIN"
  fi

  # Run ParamSpider
  echo "Running ParamSpider for $DOMAIN..."
  if ! paramspider -d $DOMAIN -o "/data/${DOMAIN_DIR}/params.txt"; then
    log_error "ParamSpider failed for $DOMAIN"
  fi

  echo "Finished processing domain: $RAW_DOMAIN"
}

# Initialize queue
> queue.txt

# Read the domain file and add domains to the queue
while IFS= read -r DOMAIN; do
  if [[ $DOMAIN == *".*" ]]; then
    echo "Processing wildcard TLD domain: $DOMAIN"
    ROOT_DOMAIN=$(echo $DOMAIN | sed -e 's/\.\*$//' -e 's/*\.//g')
    TLD_LIST_FILE="/tld_list.txt"
    if [ ! -f "$TLD_LIST_FILE" ]; then
      echo "TLD list file not found: $TLD_LIST_FILE"
      log_error "TLD list file not found: $TLD_LIST_FILE"
      exit 1
    fi
    enumerate_wildcard_tlds $ROOT_DOMAIN "$TLD_LIST_FILE" > "/possible_domains.txt"
    while IFS= read -r POSSIBLE_DOMAIN; do
      if check_domain_exists "$POSSIBLE_DOMAIN"; then
        echo "$POSSIBLE_DOMAIN" >> queue.txt
      fi
    done < "/possible_domains.txt"
  else
    echo "Adding non-wildcard domain: $DOMAIN to queue"
    echo "$DOMAIN" >> queue.txt
  fi
done < "$DOMAIN_FILE"

# Debug: Output the queue contents before processing
echo "Queue contents:"
cat queue.txt

# Process the queue
while IFS= read -r DOMAIN; do
  echo "Starting processing for domain: $DOMAIN"
  process_domain "$DOMAIN" || log_error "Processing failed for $DOMAIN"
  echo "Finished processing for domain: $DOMAIN"
done < queue.txt

echo "Recon process completed."

