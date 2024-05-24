```


      :::::::::  :::    :::  ::::::::  :::    ::: :::    ::: ::::    ::: ::::::::::: 
     :+:    :+: :+:    :+: :+:    :+: :+:    :+: :+:    :+: :+:+:   :+:     :+:      
    +:+    +:+ +:+    +:+ +:+        +:+    +:+ +:+    +:+ :+:+:+  +:+     +:+       
   +#++:++#+  +#+    +:+ :#:        +#++:++#++ +#+    +:+ +#+ +:+ +#+     +#+        
  +#+    +#+ +#+    +#+ +#+   +#+# +#+    +#+ +#+    +#+ +#+  +#+#+#     +#+         
 #+#    #+# #+#    #+# #+#    #+# #+#    #+# #+#    #+# #+#   #+#+#     #+#          
#########   ########   ########  ###    ###  ########  ###    ####     ###           

by b3mt3vi

```

## Overview

This project is a comprehensive reconnaissance framework designed to automate the process of gathering information about target domains. It leverages various tools to collect subdomains, live hosts, URLs, parameters, and other relevant data, organizing the results into directories for further analysis and utilization.

## Features

- **Automated Subdomain Enumeration**
- **Passive and Active Reconnaissance**
- **Live Host Detection**
- **URL Discovery and Filtering**
- **Vulnerability Scanning**
- **Parameter Discovery**
- **JavaScript File Analysis**
- **Amazon S3 Bucket Detection**

## Tools 

- **Subfinder**: Passive subdomain enumeration
- **Amass**: Subdomain enumeration with additional data sources
- **Httpx**: Probing for live hosts
- **Gau****: Fetching known URLs
- **Arjun**: HTTP parameter discovery
- **Dalfox**: XSS vulnerability scanning
- **GetJS**: Extracting URLs from JavaScript files
- **ParamSpider**: Discovery of GET parameters
- **Nuclei**: Vulnerability scanning based on templates
- **Testssl**: SSL/TLS configuration analysis
- **Gowitness**: Screenshotting web pages

## Directory Structure

The project maintains a structured directory for data organization:

    - `data/`: Main directory for storing output files
    - `recon/`: Subdirectory for categorized data
    - `subdomains/`: Contains .txt files for each discovered subdomain
    - `urls/`: Contains .txt files for each discovered URL
    - `ips/`: Contains .txt files for each discovered IP

## Prerequisites

    - Docker
    - Docker Compose

## Setup

1. **Clone the repository**:

```bash

git clone <repository-url>
cd <repository-directory>

```
   
Create a domain list file:
Create a file (e.g., domains.txt) and list the target domains, one per line.

Build Docker images for tools that require custom builds:

```bash
docker-compose build arjun getjs paramspider
```

Usage

    Run the reconnaissance script:

```bash
./run_recon.sh domains.txt
```

This script will:
- Run Subfinder to gather subdomains.
- Run Amass for additional subdomain enumeration.
- Probe for live hosts using Httpx.
- Fetch known URLs using Gau.
- Discover HTTP parameters using Arjun.
- Scan for XSS vulnerabilities using Dalfox.
- Extract URLs from JavaScript files using GetJS.
- Discover GET parameters using ParamSpider.
- Scan for vulnerabilities using Nuclei.
- Analyze SSL/TLS configurations using Testssl.
- Take screenshots of web pages using Gowitness.

    Check the data/recon/ directory for the organized results.

## Logging

Errors encountered during the execution of the script are logged to data/recon.log.

## Customization

You can customize the tools and their configurations by modifying the docker-compose.yml and run_recon.sh files according to your needs.

## Troubleshooting

If you encounter any issues, refer to the data/recon.log file for error messages. Ensure that all required API keys are correctly set in the .env file and that Docker and Docker Compose are properly installed and configured.
## License

This project is licensed under the MIT License. See the LICENSE file for more details.
