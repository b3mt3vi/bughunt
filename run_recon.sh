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
# Set permissions
chmod -R 777 "$(pwd)/data"

# Define log file
LOGFILE="$(pwd)/data/recon.log"
# Function to log errors
log_error() {
  echo "[ERROR] $1" >> $LOGFILE
}


# Subfinder
echo "Running Subfinder..."
docker compose run --rm subfinder || { echo 'Subfinder failed'; exit 1; }

# Amass Enum
echo "Running Amass Enum...(skipping for now)"
# docker compose run --rm amass_enum || { echo 'Amass Enum failed'; exit 1; }
if ! docker compose run --rm amass_enum; then
  log_error "Amass failed"
fi

# Combine results and check live hosts with HTTPX
echo "Probing with HTTPX..."
cat "$(pwd)/data/subfinder_output.txt" "$(pwd)/data/amass_enum_output.txt" | sort -u > "$(pwd)/data/final_subdomains.txt"
if ! docker compose run --rm httpx; then
  log_error "Httpx failed"
fi

# Gau
echo "Running Gau..."
docker compose run --rm gau || { echo 'Gau failed'; exit 1; }
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

# Nuclei
echo "Running Nuclei..."
# docker compose run --rm nuclei || { echo 'Nuclei failed'; exit 1; }
if ! docker compose run --rm nulcei; then
  log_error "nuclei failed"
fi
# Arjun
echo "Running Arjun..."
# docker compose run --rm arjun || { echo 'Arjun failed'; exit 1; }
if ! docker compose run --rm arjun; then
  log_error "arjun failed"
fi
# Dalfox
echo "Running Dalfox..."
# docker compose run --rm dalfox || { echo 'Dalfox failed'; exit 1; }
if ! docker compose run --rm dalfox; then
  log_error "dalfox failed"
fi
# GetJS
echo "Running GetJS..."
# docker compose run --rm getjs || { echo 'GetJS failed'; exit 1; }
if ! docker compose run --rm getjs; then
  log_error "getjs failed"
fi
# Extract URLs from JavaScript files
echo "Extracting URLs from JavaScript files..."
grep -Eo "(http|https)://[a-zA-Z0-9./?=_-]*" "$(pwd)/data/js_urls.txt" > "$(pwd)/data/filtered_urls.txt"

# Check for open Amazon S3 buckets
echo "Checking for open Amazon S3 buckets..."
docker compose run --rm nuclei -l "$(pwd)/data/recon/urls/urls.txt" -t /root/nuclei-templates/technologies/s3-detect.yaml -o "$(pwd)/data/recon/urls/s3_output.txt"
