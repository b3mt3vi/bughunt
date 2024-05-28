#!/bin/bash

# Check for the required argument
if [ -z "$1" ]; then
    echo "Usage: ./bughunt.sh <domain list>"
    exit 1
fi

# File containing the domain list
DOMAIN_LIST="$1"
DATA_DIR="data"

# Create the data directory if it doesn't exist
mkdir -p "$DATA_DIR"

# Function to check if a domain exists
domain_exists() {
    if dig +short "$1" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Trap for handling Ctrl+C interrupt
trap 'echo "Interrupted! Moving to the next module..."; continue' SIGINT

echo "Starting subdomain enumeration..."

# Process each domain from the domain list
while IFS= read -r domain; do
    echo "Processing $domain..."

    if domain_exists "$domain"; then
        echo "Enumerating: $domain"

        # Create a folder for the domain inside the data directory
        domain_dir="$DATA_DIR/$domain"
        mkdir -p "$domain_dir"

        # Run Amass and Subfinder
        amass enum -passive -d "$domain" > "$domain_dir/output_amass" 2>/dev/null || { echo "Amass interrupted for $domain"; continue; }
        subfinder -d "$domain" -silent -o "$domain_dir/output_subfinder" || { echo "Subfinder interrupted for $domain"; continue; }

        # Combine and sort results
        cat "$domain_dir/output_amass" "$domain_dir/output_subfinder" | sort -u > "$domain_dir/all_subs"
        rm "$domain_dir/output_amass" "$domain_dir/output_subfinder"

        echo "Domains sorted and saved under $domain_dir/all_subs"

        # Probe for alive hosts
        echo "Probing for alive hosts..."
        httpx -silent -l "$domain_dir/all_subs" -o "$domain_dir/urls_alive" || { echo "HTTPX probing interrupted for $domain"; continue; }
        echo "Probing has been completed, alive hosts and URLs saved under $domain_dir/urls_alive"

        # Convert subdomains to IP addresses
        echo "Converting subdomains to IP addresses..."
        dig +short -f "$domain_dir/all_subs" | sort -u > "$domain_dir/ip_addr_sorted.txt"
        echo "IP addresses saved under: $domain_dir/ip_addr_sorted.txt"
    else
        echo "$domain does not exist. Skipping."
    fi
done < "$DOMAIN_LIST"

echo "Subdomain enumeration completed."

