# First stage: Build Go tools
FROM golang:latest AS builder

# Set environment variables
ENV GO111MODULE=on
ENV GOPATH=/go

# Install Subfinder
RUN go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest

# Install HTTPX
RUN go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest

# Install Gau
RUN go install github.com/lc/gau/v2/cmd/gau@latest

# Install Nuclei
RUN go install -v github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest

# Install Dalfox
RUN go install github.com/hahwul/dalfox/v2@latest

# Second stage: Set up the final image
FROM debian:latest

# Install dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    git \
    curl \
    wget \
    build-essential \
    dnsutils \
    ca-certificates \
    && apt-get clean

# Copy binaries from the builder stage
COPY --from=builder /go/bin/subfinder /usr/local/bin/subfinder
COPY --from=builder /go/bin/httpx /usr/local/bin/httpx
COPY --from=builder /go/bin/gau /usr/local/bin/gau
COPY --from=builder /go/bin/nuclei /usr/local/bin/nuclei
COPY --from=builder /go/bin/dalfox /usr/local/bin/dalfox

# Create a virtual environment and install Python packages
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --upgrade pip
RUN pip install arjun
RUN git clone https://github.com/devanshbatham/paramspider
RUN pip install paramspider/

# Copy the script into the container
COPY bughunt.sh /usr/local/bin/bughunt.sh

# Make the script executable
RUN chmod +x /usr/local/bin/bughunt.sh

# Define the entrypoint
ENTRYPOINT ["/usr/local/bin/bughunt.sh"]

