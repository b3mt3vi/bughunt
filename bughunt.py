import subprocess
import os
import re
import argparse
import socket
import tempfile

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
            ['subfinder', '-d', domain, '-silent'],
            stderr=subprocess.STDOUT
        )
        results = subfinder_output.decode('utf-8').split('\n')
        # Filter out lines that are not valid subdomains
        results = [result.strip() for result in results if re.match(r'^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$', result.strip())]
        print(f"Subfinder results for {domain}: {results}")
        return results
    except subprocess.CalledProcessError as e:
        print(f"Subfinder failed for {domain}: {e.output.decode('utf-8')}")
        return []
    except KeyboardInterrupt:
        print(f"Subfinder interrupted for {domain}. Moving to Amass...")
        return []

def run_amass(domain):
    try:
        print(f"Running Amass for {domain}...")
        amass_output = subprocess.check_output(
            ['amass', 'enum', '-passive', '-d', domain],
            stderr=subprocess.STDOUT
        )
        results = amass_output.decode('utf-8').split('\n')
        # Filter out lines that are not valid subdomains
        valid_results = [line.split(' ')[0].strip() for line in results if re.match(r'^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$', line.split(' ')[0].strip())]
        print(f"Amass results for {domain}: {valid_results}")
        return valid_results
    except subprocess.CalledProcessError as e:
        print(f"Amass failed for {domain}: {e.output.decode('utf-8')}")
        return []
    except KeyboardInterrupt:
        print(f"Amass interrupted for {domain}. Moving to the next step...")
        return []

def probe_alive_hosts(subdomains):
    if not subdomains:
        print("No subdomains to probe for alive hosts.")
        return []

    try:
        print(f"Probing for alive hosts...")
        with tempfile.NamedTemporaryFile(delete=False) as temp_file:
            temp_file.write('\n'.join(subdomains).encode('utf-8'))
            temp_file_path = temp_file.name
        
        httpx_output = subprocess.check_output(
            ['httpx', '-silent', '-l', temp_file_path],
            stderr=subprocess.STDOUT
        )
        
        os.remove(temp_file_path)  # Clean up temporary file

        alive_hosts = httpx_output.decode('utf-8').split('\n')
        alive_hosts = [host.strip() for host in alive_hosts if host.strip()]  # Remove empty lines
        print(f"Alive hosts: {alive_hosts}")
        return alive_hosts
    except subprocess.CalledProcessError as e:
        print(f"HTTPX probing failed: {e.output.decode('utf-8')}")
        return []
    except KeyboardInterrupt:
        print(f"HTTPX probing interrupted. Moving to IP conversion...")
        return []

def convert_to_ips(subdomains):
    ips = set()
    for subdomain in subdomains:
        try:
            answers = socket.gethostbyname_ex(subdomain)
            ips.update(answers[2])
        except socket.error:
            continue
    return list(ips)

def save_results(domain, subfolder, combined_results, alive_hosts, ips):
    if not os.path.exists(subfolder):
        os.makedirs(subfolder)

    if combined_results:
        file_path = os.path.join(subfolder, "subdomains.txt")
        with open(file_path, 'w') as file:
            file.write("\n".join(set(combined_results)))
        print(f"Subdomains results saved to {file_path}")
    
    if alive_hosts:
        file_path = os.path.join(subfolder, "alive_hosts.txt")
        with open(file_path, 'w') as file:
            file.write("\n".join(set(alive_hosts)))
        print(f"Alive hosts results saved to {file_path}")

    if ips:
        file_path = os.path.join(subfolder, "ips.txt")
        with open(file_path, 'w') as file:
            file.write("\n".join(set(ips)))
        print(f"IP addresses saved to {file_path}")

def process_domain(full_domain, subfolder):
    print(f"Processing {full_domain}...")

    subfinder_results = []
    amass_results = []

    # Run Subfinder
    subfinder_results = run_subfinder(full_domain)

    # Run Amass
    amass_results = run_amass(full_domain)

    # Combine results
    combined_results = list(set(subfinder_results + amass_results))

    if combined_results:
        # Probe for alive hosts
        alive_hosts = probe_alive_hosts(combined_results)

        # Convert to IPs
        ips = convert_to_ips(alive_hosts)

        # Save results
        save_results(full_domain, subfolder, combined_results, alive_hosts, ips)
    else:
        print(f"No subdomains found for {full_domain}")

    print(f"Finished processing {full_domain}")

def process_url(url, tlds):
    if re.search(r'\.\*$', url):
        base_domain = re.sub(r'\.\*$', '', normalize_url(url))
        for tld in tlds:
            full_domain = f"{base_domain}.{tld}"
            subfolder = os.path.join(base_domain, tld)
            if domain_exists(full_domain):
                process_domain(full_domain, subfolder)
            else:
                print(f"{full_domain} does not exist. Skipping.")
    else:
        normalized_url = normalize_url(url)
        subfolder = normalized_url
        if domain_exists(normalized_url):
            process_domain(normalized_url, subfolder)
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

