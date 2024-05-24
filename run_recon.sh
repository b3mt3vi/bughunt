#!/bin/bash

source .env

# Ensure all necessary directories and files exist
mkdir -p data
echo "example.com" > data/amass_input.txt
touch data/final_subdomains.txt
touch data/live_hosts.txt
touch data/urls.txt

# Subfinder
echo "Running Subfinder..."
docker compose run subfinder

# Amass Intel
echo "Running Amass Intel..."
docker compose run amass_intel

# Amass Enum
echo "Running Amass Enum..."
docker compose run amass_enum

# Combine results and check live hosts with HTTPX
echo "Probing with HTTPX..."
cat data/subfinder_output.txt data/amass_intel_output.txt data/amass_enum_output.txt | sort -u > data/final_subdomains.txt
docker compose run httpx

# TheHarvester
echo "Running TheHarvester..."
docker compose run theharvester

# Gau
echo "Running Gau..."
docker compose run gau

# Organize directories
echo "Organizing directories..."
mkdir -p data/recon/{subdomains,urls,ips}
mv data/urls.txt data/recon/urls/

# Sort and filter URLs
echo "Sorting and filtering URLs..."
sort -u data/recon/urls/urls.txt -o data/recon/urls/urls.txt

# Nuclei
echo "Running Nuclei..."
docker compose run nuclei

# Arjun
echo "Running Arjun..."
docker compose run arjun

# Dalfox
echo "Running Dalfox..."
docker compose run dalfox

# GetJS
echo "Running GetJS..."
docker compose run getjs

# Extract URLs from JavaScript files
echo "Extracting URLs from JavaScript files..."
cat data/js_urls.txt | grep -Eo "(http|https)://[a-zA-Z0-9./?=_-]*" > data/filtered_urls.txt

# Check for Domain TakeOver
echo "Checking for Domain TakeOver..."
takeover -l data/final_subdomains.txt -v -t 10

# Check for open Amazon S3 buckets
echo "Checking for open Amazon S3 buckets..."
docker compose run nuclei -l data/recon/urls/urls.txt -t /root/nuclei-templates/technologies/s3-detect.yaml -o data/recon/urls/s3_output.txt

# ParamSpider
echo "Running ParamSpider..."
docker compose run paramspider

# Clean parameters for XSS
echo "Cleaning parameters for XSS..."
sed 's/FUZZ/XSS/g' data/params.txt > data/xss_params.txt

# TestSSL.sh for SSL/TLS testing
echo "Running TestSSL.sh..."
docker compose run testssl

# Gowitness
echo "Running Gowitness..."
docker compose run gowitness
