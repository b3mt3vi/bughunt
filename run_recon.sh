#!/bin/bash

# Load environment variables
source .env

# Create necessary directories and files
mkdir -p "$(pwd)/data"
touch "$(pwd)/data/subfinder_output.txt"
touch "$(pwd)/data/amass_enum_output.txt"
touch "$(pwd)/data/final_subdomains.txt"
touch "$(pwd)/data/live_hosts.txt"
touch "$(pwd)/data/urls.txt"
touch "$(pwd)/data/js_urls.txt"
touch "$(pwd)/data/arjun_output.txt"
touch "$(pwd)/data/dalfox_output.txt"
touch "$(pwd)/data/params.txt"
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

# Run Subfinder
echo "Running Subfinder..."
if ! docker compose run --rm subfinder; then
  log_error "Subfinder failed"
fi

# Run Amass Enum
echo "Running Amass Enum..."
if ! docker compose run --rm amass_enum; then
  log_error "Amass Enum failed"
fi

# Combine results and check live hosts with HTTPX
echo "Probing with HTTPX..."
cat "$(pwd)/data/subfinder_output.txt" "$(pwd)/data/amass_enum_output.txt" | sort -u > "$(pwd)/data/final_subdomains.txt"
if ! docker compose run --rm httpx; then
  log_error "HTTPX failed"
fi

# Run Gau
echo "Running Gau..."
if ! docker compose run --rm gau; then
  log_error "Gau failed"
fi

# Organize directories
echo "Organizing directories..."
mkdir -p "$(pwd)/data/recon/subdomains" "$(pwd)/data/recon/urls" "$(pwd)/data/recon/ips"
mv "$(pwd)/data/urls.txt" "$(pwd)/data/recon/urls/"

# Sort and filter URLs
echo "Sorting and filtering URLs..."
sort -u "$(pwd)/data/recon/urls/urls.txt" -o "$(pwd)/data/recon/urls/urls.txt"

# Run Nuclei
echo "Running Nuclei..."
if ! docker compose run --rm nuclei; then
  log_error "Nuclei failed"
fi

# Run Arjun
echo "Running Arjun..."
if ! docker compose run --rm arjun; then
  log_error "Arjun failed"
fi

# Run Dalfox
echo "Running Dalfox..."
if ! docker compose run --rm dalfox; then
  log_error "Dalfox failed"
fi

# Run GetJS
echo "Running GetJS..."
if ! docker compose run --rm getjs; then
  log_error "GetJS failed"
fi

# Run ParamSpider
echo "Running ParamSpider..."
if ! docker compose run --rm paramspider; then
  log_error "ParamSpider failed"
fi

# Extract URLs from JavaScript files
echo "Extracting URLs from JavaScript files..."
grep -Eo "(http|https)://[a-zA-Z0-9./?=_-]*" "$(pwd)/data/js_urls.txt" > "$(pwd)/data/filtered_urls.txt"

# Check for open Amazon S3 buckets
echo "Checking for open Amazon S3 buckets..."
if ! docker compose run --rm nuclei -l "$(pwd)/data/recon/urls/urls.txt" -t /root/nuclei-templates/technologies/s3-detect.yaml -o "$(pwd)/data/recon/urls/s3_output.txt"; then
  log_error "Nuclei S3 detection failed"
fi

echo "Recon process completed. Check the log file for any errors."

