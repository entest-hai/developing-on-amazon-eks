# Go Web Demo Application Setup Guide

This document provides instructions for setting up and running the Go web demo application.

## Prerequisites

- Linux-based operating system (Amazon Linux, Ubuntu, etc.)
- Internet connection for package installation
- Basic command line knowledge

## Installing Go

### For Amazon Linux / RHEL / CentOS

```bash
# Update package lists
sudo yum update -y

# Install Go
sudo yum install -y golang
```

### For Ubuntu / Debian

```bash
# Update package lists
sudo apt-get update

# Install Go
sudo apt-get install -y golang
```

### Verify Go Installation

After installation, verify that Go is installed correctly:

```bash
go version
```

This should display the installed Go version.

## Running the Go Web Application

1. Navigate to the application directory:

```bash
cd /path/to/go-web-demo
```

2. Run the application:

```bash
go run main.go
```

3. The application will start and listen on port 3000.

4. Access the application in your web browser:
   - If running locally: http://localhost:3000
   - If running on a remote server: http://server-ip:3000

## Application Structure

- `main.go` - The main application entry point
- `index.html` - The main HTML page served by the application
- `static/` - Directory containing static assets

## Stopping the Application

To stop the running application, press `Ctrl+C` in the terminal where the application is running.

## Building for Production

To build the application for production:

```bash
go build -o web-app main.go
```

This creates an executable file named `web-app` that can be run directly:

```bash
./web-app
```

## Troubleshooting

- If you encounter permission issues, ensure you have the necessary permissions to install packages and create files.
- If the application fails to start, check if port 3000 is already in use by another application.
- For any Go-related errors, ensure your Go installation is correct and up-to-date.
