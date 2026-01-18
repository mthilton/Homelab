# Homelab Documentation

This repo describes what services I run in my homelab and how everything works. This repo serves to document my work and showcase it to anybody curious.

## Network Stack {#Network}

The first thing I want to talk about is the network stack. I've learned that homelabbing is like 70% services and 30% networking. Without the network there is no way for any of these services to communicate. 

![Network Diagram](./img/NetworkDiagram.png "Network Diagram")

I have internet coming from the ISP piped directly to my router. Then from the router I go directly into an unmanaged 2.5 Gig switch. This connects my two computers and two server to the internet. All links are 2.5 Gig links except for the Pi and one from Server 1. DNS is handled by [Pi-Hole](#DNS_Stack) and [Unbound](#DNS_Stack). DHCP is handled by [Windows Server 2022](#WindowsServer). In order to access all of my services, I use [Nginx](#Nginx) to route all of my service traffic to the proper endpoint. Finally, my mobile devices, such as my phone and laptop, are tunneled in though a private [WireGuard Virtual Private Network](#Wireguard). 

## Services

While I have a lot going on in the homelab, I am only hosting a few Services:

   - Pi-Hole DNS
   - Unbound Recursive DNS
   - Wireguard
   - TrueNAS
   - Portainer
   - Nginx
   - Windows Server 2022
   - iVentoy

These are a list of Services that I may add in the future:

   - Jellyfin/Plex
   - Immich
   - Opencloud
   - TimeMachine Backup

## DNS Stack {#DNS_Stack}

In my homelab I have a different DNS's running. The primary DNS is Pi-Hole, an ad-blocking DNS Server that sinks known ad cdn domains. Since the requests for these sites never reach the internet, the website/program is unable to load their ad. Then to handle all requests that are not in the DNS cache we use Unbound. This is a Recursive DNS that we seek out the Authoritative Name Server for the requested Name. We could use Google or Cloudflares DNS server for unknown names but using Unbound will prevent those services from creating profiles on our searches. Finally, we use DuckDNS as our dynamic DNS provider. The main reason I chose this is becuase I was not ready to purchase a domain and use Cloudflare's DDNS service to provide real valid SSL certificates for the Names that I create for the different services on my homelab. 

### Pi-Hole Configuration


## Virtualizaion and Contaninerization 

In this homelab, I utilize both virtualization and containerization. On Server 1, the host OS is Proxmox. This hypervisor has three Virtual Machines: TrueNAS, Debian, and Windows Server 2022. TrueNAS contains all the volumes for mass storage. Debian is the host operating system for all of my Docker containers and the host that iVentoy is running on. Windows Server is for hosting my DHCP server.

### Server Hardware

The two servers in the Homelab are run on very different hardware. At first I started with just a few Raspberry Pi's. Now I only have the Pi 5 deployed. The Pi is used for the DNS stack and Wireguard. For the other server, I have a Dell Optiplex 9020 with a few hardware modifcations. First, the CPU is upgraded to the 4790. The RAM has been upgraded to the maximum 32 GB that Dell supports. There is a 2.5 Gigabit network card. Finally, I added an HBA card that will be passed into the NAS VM.  

### Virtualization with Proxmox

Before I installed Proxmox, I went into the BIOS and ensured that the following options were selected:

```bash
intel-VTd: enabled
virtualization: enabled
NIC_Config: Enabled
```

Then once I had Proxmox installed, I added `intel_iommu=on` that way I was able to pass the network card and HBA to the NAS VM. 

In my DHCP server, I set up a static IP address for this machine. Then in PiHole, I added a Local DNS record to give this server a URL that I could reach it by. Now we can access the web interface by going to `<Your-Proxmox-Url>:8006`

**Important:** In order to enable updates, we need to disable the enterprise components and enable the two no-subscription compenets. This way we can actually get updates if we did not pay for Proxmox. To change this, click on your server under Datacenter once you are signed into the Proxmox Web Interface. This can be changed in the `Updates` Tab. Click `Repos` and disable any URIs that say *enterprise* in the `Compnents` column. Then make sure to add the to analagus URIs where it says *no-subscription* in the `Compnents` column.

Finally I added my ssh key for my PC to the server and disabled SSH with Password Login. This way only verified ssh keys can access the server. Make these changes:

   1. `vim /etc/ssh/sshd_config`
   2. change the following options to `no`:
      - ChallengeResponseAuthentication
      - PasswordAuthentication
      - UsePAM

You can optionally prevent root login by setting `PermitRootLogin` to `No`. On this server I did not do that since I only have the root user account and there is no way to log into this computer without my ssh key. Furthermore this machine is not directly accessable from the web so in this case it should not be an issue. On all other servers I did set this option to no.

### Containerization with Docker

First we need to make the VM that will be the host for docker. While I am aware that Proxmox supports LXC contianers, I wanted to learn more about Docker. This is the reason I chose to use Docker inside a VM. 

The Host OS for the VM is Debian. I chose debian becuase it was what the guide I was watching was doing. However, debian is a good choice because its pretty bare-bones but it widely suported. 

After Debian was installed I made sure to set a static IP in my DHCP server and make a Local DNS record for this VM. Then I copied my ssh key and disabled SSH w/ password. Next I installed a few utilites (cifs-uitls, curl, ca-certificates) using apt. These utilites will allow me to mount my Samba Share from TrueNAS when the VM boots. 

First there are a few files that we should prepare:

   1. A Credentials file: This will allow us to hide our log in credentials for the SMB share.
   2. A Custom Systemd Script: This script ensures that we do not attempt to mount the SMB share until after we establish a connection to the NAS. 

For the credentials file, we want to have the following information:

```bash
user=<Samba-Username>
pass=<Password-for-Samba-User>
```

We can save this as a dotfile in the `/root/` directory. Then we can use the following command to make it read-only by root: `chmod 400 /root/path/to/credentials/`. This will prevent anybody from being able to access the password without becoming root.

For the Systemd Script, we want to create a service that will ping our NAS once a second until we actually get a reply. We can make a service called `wait-for-ping.service` in `/etc/systemd/system/`. The contents of this file would be:

```bash
# /etc/systemd/system/wait-for-ping.service
[Unit]
Description=Blocks until it successfully pings <your-NAS-IP>
After=network-online.target

[Service]
ExecStartPre=/usr/bin/bash -c "while ! ping -c1 <your-NAS-IP>; do sleep 1; done"
ExecStart=/usr/bin/bash -c "echo good to go"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

Once we have these files, we are ready to mount the Network Share. We are going to update our `/etc/fstab` file that is responsible for getting drives mounted in the right place. At the end of your `fstab` file you will add the following:

```bash
//ip-for-NAS/Name-of-share /path/to/share cifs vers=3,credentials=/path/to/.smbcredentials,uid=<your-uid>,forceuid,gid=<your-gid>,forcegid,noauto,_netdev,x-systemd.automount,x-systemd.after=wait-for-ping.service 0 0
```

   - `//ip-for-NAS/Name-of-share`: IP or DNS name of NAS then the name of the share on the NAS
   - `/path/to/share`: path on your local machine that you would like to mount the share to. Make sure that it is an empty directory.
   - `cifs`: the filesystem we are to mount. In this case we are using cifs becuase this is a samba share.
   - `vers`: Verison of cifs to use, we use verison 3 becuase it has some added support for the options we are using.
   - `credentials`: path the the credentials file that we made earlier
   - `uid, gid`: Your userID and GroupID for the share. This is set when you create the user for this share.
   - `forceuid/gid`: requires the share to be mounted with the permissions of the uid/gid
   - `noauto`, `x-systemd.automount`: changes the auto mount to happen when systemd does it. This allows us to use our custom ping service.
   - `_netdev`: ensures that we have networking before this atempts to run
   - `x-systemd.after=wait-for-ping.service`: our custom service that prevents the VM from finishing boot until we can ping our NAS. This ensures that we always have our NAS for our docker containers.

Now we need to reboot for the drive to be mounted. Now we can install Docker. For info on how to install we can go to the [docker installer](https://docs.docker.com/engine/install/debian/). We will ensure that there are no conflicting packages using the following command:

```bash
sudo apt remove $(dpkg --get-selections docker.io docker-compose docker-doc podman-docker containerd runc | cut -f1)
```

Next we need to add dockers GPG keys:

```bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

Finally, add the docker repo to apt's srcs so we can get updates:

```bash
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $( /etc/os-releases && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyring/docker.asc
EOF
```

Then we are ready to install docker:

```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-bildx-plugin docker-comose-plugin
```

Once apt is complete we just need to verify that it works by running the hello world container and adding your user to the docker group.

```bash
sudo docker run hello-world # Runs the Hello World container
sudo usermod -aG docker <your-user> # Adds your user the docker group
```