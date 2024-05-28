#!/bin/bash

# Check for the required arguments
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: ./bughunt.sh <domain list> <tld list>"
    exit 1
fi

# Files containing the domain list and TLDs
DOMAIN_LIST="$1"
TLD_LIST="$2"

# Function to normalize a domain by removing wildcard characters
normalize_domain() {
    echo "$1" | sed 's/\*\.\?//g'
}

# Function to check if a domain exists
domain_exists() {
    if dig +short "$1" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Read TLDs into an array
TLDs=()
while IFS= read -r tld; do
    TLDs+=("$tld")
done < "$TLD_LIST"

echo "Starting subdomain enumeration..."

# Process each domain from the domain list
while IFS= read -r domain; do
    normalized_domain=$(normalize_domain "$domain")
    wildcard_tld=false

    # Check if the domain contains a wildcard TLD
    if [[ "$domain" == *.* && "$domain" == *\.* ]]; then
        wildcard_tld=true
    fi

    if [[ "$wildcard_tld" == true ]]; then
        echo "Processing $domain with wildcard TLD..."
        base_domain=$(echo "$normalized_domain" | awk -F'.' '{print $1}')

        for tld in "${TLDs[@]}"; do
            full_domain="$base_domain.$tld"
            if domain_exists "$full_domain"; then
                echo "Enumerating: $full_domain"

                # Create a folder for the domain
                mkdir -p "$full_domain"

                # Run Amass and Subfinder
                amass enum -passive -d "$full_domain" > "$full_domain/output_amass" || { echo "Amass interrupted for $full_domain"; continue; }
                subfinder -d "$full_domain" -silent -o "$full_domain/output_subfinder" || { echo "Subfinder interrupted for $full_domain"; continue; }

                # Combine and sort results
                cat "$full_domain/output_amass" "$full_domain/output_subfinder" | sort -u > "$full_domain/all_subs"
                rm "$full_domain/output_amass" "$full_domain/output_subfinder"

                echo "Domains sorted and saved under $full_domain/all_subs"

                # Probe for alive hosts
                echo "Probing for alive hosts..."
                httpx -silent -l "$full_domain/all_subs" -o "$full_domain/urls_alive" || { echo "HTTPX probing interrupted for $full_domain"; continue; }
                echo "Probing has been completed, alive hosts and URLs saved under $full_domain/urls_alive"

                # Convert subdomains to IP addresses
                echo "Converting subdomains to IP addresses..."
                dig +short -f "$full_domain/all_subs" | sort -u > "$full_domain/ip_addr_sorted.txt"
                echo "IP addresses saved under: $full_domain/ip_addr_sorted.txt"
            else
                echo "$full_domain does not exist. Skipping."
            fi
        done
    else
        echo "Processing $normalized_domain..."

        if domain_exists "$normalized_domain"; then
            echo "Enumerating: $normalized_domain"

            # Create a folder for the domain
            mkdir -p "$normalized_domain"

            # Run Amass and Subfinder
            amass enum -passive -d "$normalized_domain" > "$normalized_domain/output_amass" || { echo "Amass interrupted for $normalized_domain"; continue; }
            subfinder -d "$normalized_domain" -silent -o "$normalized_domain/output_subfinder" || { echo "Subfinder interrupted for $normalized_domain"; continue; }

            # Combine and sort results
            cat "$normalized_domain/output_amass" "$normalized_domain/output_subfinder" | sort -u > "$normalized_domain/all_subs"
            rm "$normalized_domain/output_amass" "$normalized_domain/output_subfinder"

            echo "Domains sorted and saved under $normalized_domain/all_subs"

            # Probe for alive hosts
            echo "Probing for alive hosts..."
            httpx -silent -l "$normalized_domain/all_subs" -o "$normalized_domain/urls_alive" || { echo "HTTPX probing interrupted for $normalized_domain"; continue; }
            echo "Probing has been completed, alive hosts and URLs saved under $normalized_domain/urls_alive"

            # Convert subdomains to IP addresses
            echo "Converting subdomains to IP addresses..."
            dig +short -f "$normalized_domain/all_subs" | sort -u > "$normalized_domain/ip_addr_sorted.txt"
            echo "IP addresses saved under: $normalized_domain/ip_addr_sorted.txt"
        else
            echo "$normalized_domain does not exist. Skipping."
        fi
    fi
done < "$DOMAIN_LIST"

echo "Subdomain enumeration completed."

