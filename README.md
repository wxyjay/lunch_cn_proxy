# Lunch Proxy Installation Guide

This guide will walk you through the installation of Lunch Proxy on your Linux system.

## Prerequisites

* You need to have `sudo` privileges.
* Your system needs to be connected to the internet.

## Installation Steps

Follow these steps to execute the commands in your terminal:

1.  **Update package lists and install unzip:**

    Open your terminal and paste and execute the following command:

    ```bash
    sudo apt update && sudo apt install -y unzip
    ```

    This command will first update your system's package lists and then automatically install the `unzip` tool, which is required to decompress the Lunch Proxy archive.

2.  **Download the installation script:**


    ```bash
    wget https://raw.githubusercontent.com/wxyjay/lunch_cn_proxy/refs/heads/main/install.sh -O lunch_proxy_install.sh
    ```

    This command will download the `install.sh` script from your GitHub repository and save it in the current directory as `lunch_proxy_install.sh`.

3.  **Grant execute permission:**

    Execute the following command to make the downloaded script executable:

    ```bash
    chmod +x lunch_proxy_install.sh
    ```

4.  **Run the installation script:**

    Finally, execute the following command to run the installation script:

    ```bash
    ./lunch_proxy_install.sh
    ```

    The installation script will automatically handle the creation of directories, extraction of files, compilation of the program, creation of the system service, and setting up auto-start. During the installation, you will be prompted to choose the server address and HTTP proxy port.

## Using the Lunch Proxy Menu

After the installation is complete, you can open the Lunch Proxy menu by entering the following command in your terminal:

```bash
lunch_proxy
