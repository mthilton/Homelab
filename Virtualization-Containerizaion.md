# Virtualizaion and Contaninerization 

In this homelab, I utilize both virtualization and containerization. On the [9020](./Hardware.md#dell), the host OS is Proxmox. This hypervisor has three Virtual Machines: [TrueNAS](./Services.md#truenas), [Debian](#containerization-with-docker), and [Windows Server 2022](./Network.md#dhcp). TrueNAS contains all the volumes for mass storage. Debian is the host operating system for all of my Docker containers and the host that iVentoy is running on. Windows Server is for hosting my DHCP server.

## Virtualization with Proxmox

Before I installed Proxmox, I went into the BIOS of the [9020](./Hardware.md#dell) and ensured that the following options were selected:

```yaml
intel-VTd: Enabled       # Ensures Intel's Virtual platform is enabled
virtualization: Enabled  # Ensures Virtualization is enabled
NIC_Config: Enabled      # Ensures the Network interface card (NIC) is avalible at boot
```

Then once I had Proxmox installed, I added `intel_iommu=on` to the grub command line arguments. This way, I can pass the network card and HBA to the NAS VM. To make this changed I edited `/etc/default/grub`:

```json
GRUB_CMDLINE_LINUX_DEFUALT="quiet intel_iommu=on"
```

In my [DHCP server](./Network.md#dhcp), I set up a static IP address for this machine. Then in PiHole, I added a Local DNS record to give this server a URL that I could reach it by. Now we can access the web interface by going to `<Your-Proxmox-Url>:8006`

**Important:** In order to enable updates, we need to disable the enterprise components and enable the two no-subscription compenets. This way we can actually get updates if we did not pay for Proxmox. To change this, click on your server under Datacenter once you are signed into the Proxmox Web Interface. This can be changed in the `Updates` Tab. Click `Repos` and disable any URIs that say *enterprise* in the `Compnents` column. Then make sure to add the to analagus URIs where it says *no-subscription* in the `Compnents` column.

Finally I added my ssh key for my PC to the server and disabled SSH with Password Login. This way only verified ssh keys can access the server. To do so make the following changes to `vim /etc/ssh/sshd_config`:

```yaml
ChallengeResponseAuthentication: no
PasswordAuthentication:          no
UsePAM:                          no
```  

You can optionally prevent root login by setting `PermitRootLogin` to `No`. On this server I did not do that since I only have the root user account and there is no way to log into this computer without my ssh key. Furthermore this machine is not directly accessable from the web so in this case it should not be an issue. On all other servers I did set this option to no.

## Containerization with Docker

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
//ip-for-NAS/Name-of-share /path/to/share cifs vers=3,credentials=/path/to/.smbcredentials,uid=<your-uid>,forceuid,gid=<your-guid>,forcegid,noauto,_netdev,x-systemd.automount,x-systemd.after=wait-for-ping.service 0 0
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
sudo docker run hello-world         # Runs the Hello World container
sudo usermod -aG docker <your-user> # Adds your user the docker group
```