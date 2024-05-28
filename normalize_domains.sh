#!/bin/bash

# Usage: ./normalize_domains.sh wildcard_domains.txt potential_tlds.txt output.txt

WILDCARD_DOMAINS_FILE=$1
POTENTIAL_TLDS_FILE=$2
OUTPUT_FILE=$3

# Function to normalize a domain
normalize_domain() {
    local domain=$1
    # Remove any wildcard prefixes and suffixes, keeping only the core domain
    normalized=$(echo "$domain" | sed -E 's/^\*\.//g' | sed -E 's/^\w+\.\*\.//g' | sed -E 's/\.\*$//g')
    echo "$normalized"
}

# Check if a domain exists
domain_exists() {
    local domain=$1
    # Use dig to check if the domain has any DNS records
    if dig +short "$domain" | grep -q .; then
        return 0
    else
        return 1
    fi
}

# Read potential TLDs into an array
mapfile -t POTENTIAL_TLDS < "$POTENTIAL_TLDS_FILE"

# Process each wildcard domain
while IFS= read -r domain; do
    echo "Processing domain: $domain"  # Debug info
    # Normalize the domain
    normalized=$(normalize_domain "$domain")
    echo "Normalized domain: $normalized"  # Debug info

    # If the TLD is a wildcard, test each potential TLD
    if [[ "$domain" == *.*.\* ]]; then
        base_domain=$(echo "$normalized" | sed -E 's/\.\*$//')
        echo "Base domain for wildcard TLD: $base_domain"  # Debug info
        for tld in "${POTENTIAL_TLDS[@]}"; do
            full_domain="$base_domain.$tld"
            echo "Testing domain: $full_domain"  # Debug info
            if domain_exists "$full_domain"; then
                echo "Domain exists: $full_domain"  # Debug info
                echo "$full_domain" >> "$OUTPUT_FILE"
            else
                echo "Domain does not exist: $full_domain"  # Debug info
            fi
        done
    else
        # Just normalize the domain and add to output
        echo "Adding normalized domain to output: $normalized"  # Debug info
        echo "$normalized" >> "$OUTPUT_FILE"
    fi
done < "$WILDCARD_DOMAINS_FILE"

echo "Normalization complete. Output written to $OUTPUT_FILE."

