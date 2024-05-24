#!/bin/bash

# Load environment variables
source .env

# Check if a file name is provided as an argument, otherwise use the DOMAIN from .env
if [ -n "$1" ]; then
  DOMAIN_FILE=$1
  USE_DOMAIN_FILE=true
else
  DOMAIN_FILE=.env
  USE_DOMAIN_FILE=false
fi

# Create necessary directories and files
mkdir -p "$(pwd)/data"
touch "$(pwd)/data/recon.log"
mkdir -p "$(pwd)/home/gau"
touch "$(pwd)/home/gau/.gau.toml"

# Set permissions
chmod -R 777 "$(pwd)/data"

# Define log file
LOGFILE="$(pwd)/data/recon.log"

# Function to log errors
log_error() {
  echo "[ERROR] $1" >> $LOGFILE
}

process_domain() {
  local DOMAIN=$1
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

  # Update the .env file with the current domain if it exists, otherwise append
  if grep -q "DOMAIN=" .env; then
    sed -i "s/^DOMAIN=.*/DOMAIN=$DOMAIN/" .env
  else
    echo "DOMAIN=$DOMAIN" >> .env
  fi

  # Run Subfinder
  echo "Running Subfinder for $DOMAIN..."
  if ! docker compose run --rm subfinder; then
    log_error "Subfinder failed for $DOMAIN"
  fi

# Run Amass Enum. Disabled for now, speed issues.
#  echo "Running Amass Enum for $DOMAIN..."
#  if ! docker compose run --rm amass_enum; then
#    log_error "Amass Enum failed for $DOMAIN"
#  fi

  # Combine results and check live hosts with HTTPX
  echo "Probing with HTTPX for $DOMAIN..."
  cat "$(pwd)/data/$DOMAIN_DIR/subfinder_output.txt" "$(pwd)/data/$DOMAIN_DIR/amass_enum_output.txt" | sort -u > "$(pwd)/data/$DOMAIN_DIR/final_subdomains.txt"
  if ! docker compose run --rm httpx; then
    log_error "HTTPX failed for $DOMAIN"
  fi

  # Run Gau
  echo "Running Gau for $DOMAIN..."
  if ! docker compose run --rm gau; then
    log_error "Gau failed for $DOMAIN"
  fi

  # Organize directories
  echo "Organizing directories for $DOMAIN..."
  mkdir -p "$(pwd)/data/$DOMAIN_DIR/recon/subdomains" "$(pwd)/data/$DOMAIN_DIR/recon/urls" "$(pwd)/data/$DOMAIN_DIR/recon/ips"
  mv "$(pwd)/data/$DOMAIN_DIR/urls.txt" "$(pwd)/data/$DOMAIN_DIR/recon/urls/"

  # Sort and filter URLs
  echo "Sorting and filtering URLs for $DOMAIN..."
  sort -u "$(pwd)/data/$DOMAIN_DIR/recon/urls/urls.txt" -o "$(pwd)/data/$DOMAIN_DIR/recon/urls/urls.txt"

  # Create individual .txt files for each IP, subdomain, and URL
  awk '{print > "'$(pwd)'/data/'$DOMAIN_DIR'/recon/subdomains/"$1".txt"}' "$(pwd)/data/$DOMAIN_DIR/final_subdomains.txt"
  awk '{print > "'$(pwd)'/data/'$DOMAIN_DIR'/recon/ips/"$1".txt"}' "$(pwd)/data/$DOMAIN_DIR/live_hosts.txt"
  awk '{print > "'$(pwd)'/data/'$DOMAIN_DIR'/recon/urls/"$1".txt"}' "$(pwd)/data/$DOMAIN_DIR/recon/urls/urls.txt"

  # Run Nuclei
  echo "Running Nuclei for $DOMAIN..."
  if ! docker compose run --rm nuclei; then
    log_error "Nuclei failed for $DOMAIN"
  fi

  # Run Arjun
  echo "Running Arjun for $DOMAIN..."
  if ! docker compose run --rm arjun; then
    log_error "Arjun failed for $DOMAIN"
  fi

  # Run Dalfox
  echo "Running Dalfox for $DOMAIN..."
  if ! docker compose run --rm dalfox; then
    log_error "Dalfox failed for $DOMAIN"
  fi

  # Run GetJS
  echo "Running GetJS for $DOMAIN..."
  if ! docker compose run --rm getjs; then
    log_error "GetJS failed for $DOMAIN"
  fi

  # Run ParamSpider
  echo "Running ParamSpider for $DOMAIN..."
  if ! docker compose run --rm paramspider; then
    log_error "ParamSpider failed for $DOMAIN"
  fi

  # Extract URLs from JavaScript files
  echo "Extracting URLs from JavaScript files for $DOMAIN..."
  grep -Eo "(http|https)://[a-zA-Z0-9./?=_-]*" "$(pwd)/data/$DOMAIN_DIR/js_urls.txt" > "$(pwd)/data/$DOMAIN_DIR/filtered_urls.txt"

  # Check for open Amazon S3 buckets
  echo "Checking for open Amazon S3 buckets for $DOMAIN..."
  if ! docker compose run --rm nuclei -l "$(pwd)/data/$DOMAIN_DIR/recon/urls/urls.txt" -t /root/nuclei-templates/technologies/s3-detect.yaml -o "$(pwd)/data/$DOMAIN_DIR/recon/urls/s3_output.txt"; then
    log_error "Nuclei S3 detection failed for $DOMAIN"
  fi

  echo "Recon process completed for $DOMAIN. Check the log file for any errors."
}

if [ "$USE_DOMAIN_FILE" = true ]; then
  # Iterate over each domain in the domain file
  while read -r DOMAIN; do
    process_domain $DOMAIN
  done < "$DOMAIN_FILE"
else
  # Use the DOMAIN from .env file
  process_domain $DOMAIN
fi

