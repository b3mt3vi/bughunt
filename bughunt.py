import subprocess
import os
import re
import argparse
import socket

def load_tlds(tlds_file_path):
    if not os.path.exists(tlds_file_path):
        print(f"TLDs file {tlds_file_path} does not exist.")
        return []

    with open(tlds_file_path, 'r') as file:
        tlds = file.read().splitlines()
    return tlds

def normalize_url(url):
    # Normalize URL by removing wildcards and ensuring correct format
    url = re.sub(r'\*\.', '', url)
    return url

def domain_exists(domain):
    try:
        socket.gethostbyname(domain)
        return True
    except socket.error:
        return False

def run_subfinder(domain):
    try:
        print(f"Running Subfinder for {domain}...")
        subfinder_output = subprocess.check_output(
            ['subfinder', '-d', domain],
            stderr=subprocess.STDOUT
        )
        results = subfinder_output.decode('utf-8').split('\n')
        results = [result for result in results if result]  # Remove empty lines
        print(f"Subfinder results for {domain}: {results}")
        return results
    except subprocess.CalledProcessError as e:
        print(f"Subfinder failed for {domain}: {e.output.decode('utf-8')}")
        return []

def save_results(domain, subfinder_results):
    if subfinder_results:
        # Create a directory for the domain if it doesn't exist
        if not os.path.exists(domain):
            os.makedirs(domain)

        # Save results to a file in the domain directory
        file_path = os.path.join(domain, "subdomains.txt")
        with open(file_path, 'w') as file:
            file.write("\n".join(set(subfinder_results)))
        print(f"Results saved to {file_path}")
    else:
        print(f"No subdomains found for {domain}")

def process_url(url, tlds):
    if re.search(r'\.\*$', url):
        base_domain = re.sub(r'\.\*$', '', normalize_url(url))
        for tld in tlds:
            full_domain = f"{base_domain}.{tld}"
            print(f"Checking existence of {full_domain}...")

            if domain_exists(full_domain):
                print(f"{full_domain} exists. Running Subfinder...")
                subfinder_results = run_subfinder(full_domain)
                save_results(full_domain, subfinder_results)
                print(f"Finished processing {full_domain}")
            else:
                print(f"{full_domain} does not exist. Skipping.")
    else:
        normalized_url = normalize_url(url)
        print(f"Processing {normalized_url}...")

        if domain_exists(normalized_url):
            print(f"{normalized_url} exists. Running Subfinder...")
            subfinder_results = run_subfinder(normalized_url)
            save_results(normalized_url, subfinder_results)
            print(f"Finished processing {normalized_url}")
        else:
            print(f"{normalized_url} does not exist. Skipping.")

def process_urls(file_path, tlds):
    if not os.path.exists(file_path):
        print(f"File {file_path} does not exist.")
        return

    with open(file_path, 'r') as file:
        urls = file.readlines()

    for url in urls:
        url = url.strip()
        if not url:
            continue

        process_url(url, tlds)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Automated passive enumeration workflow for bug bounty.")
    parser.add_argument("file_path", help="Path to the file containing wildcard URLs")
    parser.add_argument("tlds_file_path", help="Path to the file containing TLDs")
    args = parser.parse_args()

    tlds = load_tlds(args.tlds_file_path)
    if tlds:
        process_urls(args.file_path, tlds)

