#Use script below to install terraform on gitpod

#1.)Give the file executable permissions with chmod +x install_terraform.sh
#2.)Next, run the file with ./install_terraform.sh

#!/bin/bash

# Define the desired Terraform version
TERRAFORM_VERSION="1.12.2" # <--- **UPDATE THIS TO THE LATEST VERSION**

# Define the download URL for Linux AMD64 (most common Gitpod architecture)
TERRAFORM_URL="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"

echo "Downloading Terraform version ${TERRAFORM_VERSION}..."
wget ${TERRAFORM_URL} -O terraform.zip

# Check if wget was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to download Terraform."
    exit 1
fi

echo "Unzipping Terraform..."
unzip -o terraform.zip # Use -o to overwrite existing files without prompting

# Check if unzip was successful and the terraform executable exists
if [ $? -ne 0 ] || [ ! -f terraform ]; then
    echo "Error: Failed to unzip Terraform or executable not found."
    rm -f terraform.zip # Clean up
    exit 1
fi

echo "Moving Terraform to /usr/local/bin/..."
# Use sudo to move the binary to a directory in the system's PATH
sudo mv terraform /usr/local/bin/

# Check if mv was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to move Terraform to /usr/local/bin/. Permission denied or directory issue?"
    rm -f terraform.zip # Clean up
    rm -f terraform # Clean up the extracted file if it exists
    exit 1
fi


echo "Cleaning up downloaded files..."
rm terraform.zip

echo "Terraform installed successfully!"

echo "Verifying Terraform installation:"
terraform --version

# Check if terraform --version was successful
if [ $? -ne 0 ]; then
    echo "Error: Terraform command not found or failed after installation."
    exit 1
fi

exit 0 # Indicate successful execution