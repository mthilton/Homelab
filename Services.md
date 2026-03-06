# Services

The following services are critical to the network stack, so I described them and their configuration in detail in other sections. To view these details click on any of the following services:

- [Pi-Hole DNS](./Network.md#dns-stack)
- [Unbound Recursive DNS](./Network.md#dns-stack)
- [Wireguard](./Network.md#dns-stack)
- [DHCP Windows Server 2022](./Network.md#windows-server-with-dhcp)

## TrueNAS

TrueNAS is the my NAS software of choice. To be honest, the main reason I chose it was due to the cost and support for ZFS. Initally I wanted to build my storage pool up with a RAIDZ1 stripe. The main reason I didn't is because I knew I only had 2 drives and based on my research if I wanted to add two more drives in the future, my best bet would be to do a stripe of mirrors.

Once TrueNAS was installed, the first thing I did was configure the networking. I ensured that my 2.5 gig card had a static ip address, that way in the DNS, I could set my own Name for the 2.5 gig link. This name will be what I use to access the SMB shares later down the line.

After networking was comfigured, the next thing I did was create a Pool. This is how we aggragate all of our drives together.

1. In the Left-hand menu I clicked on `Storage`
2. In the top-right of the `Storage` dashboard I clicked `Create Pool`
3. Then I followed the steps in the Pool Creation Wizard

Most of the options like `encryption`, `hot-spare`, `L2 ARC-Cache`, etc I skipped over becuase I don't really have the hardware to do all of those things. I'm just looking for something basic for right now.

Once you have your pool, then you need to create a `dataset`. This will be where we create our Samba Share. Why Samba? The main computers that i would be interested in backing up are Windows devices. SMB was designed with Windows in mind and is accessable by all major operating systems (MacOS, Windows, and Linux).

In the Dataset Manager dashboard just click `Add Dataset` and follow the on-screen prompts. Be sure to select SMB as the Dataset type. Once we create our SMB Share, next we have to create users that would be able to access these shares.

In the `Credentials` Tab on the left-hand side, Click on `users`. Then in the top right click `Add`. For my personal user, I made sure to add full access (SMB, TrueNAS, Shell, and SSH Access). I had to set a password and a Home Directory since I had SSH access. The Home direcrty gave me a bit of problems until I realized that I could just create a "home" folder in my SMB share. I also made sure my TrueNAS role was set to Full Access. At this point, I copied my SSH key for my desktop in order to access the shell from my desktop. The only other thing I did was set my UID that way I could make it the same across all of my Unix-like Services.

I created another user with the default password being `ch4ng3m3!` to remind me to change it later. This is just going to be a normal user, so they don't need access to the TrueNAS web interface, shell, or SSH access.

The last thing I did was actaully enable the SSH daemon in the `Services` tab under `System` in the left hand side. This is what will allow me to actually SSH into the VM should I need to.

## Portainer

Portainer is very easy to get running. Basically you just follow the [documentation](https://docs.portainer.io/start/install-ce/server/docker/linux#docker-run). Essentially, [assuming docker is installed](./Virtualization-Containerizaion.md#containerization-with-docker), you are going to run the following command in order to create a volume for portainer to store data:

```bash
docker volume create portainer_data
```

Then using the cli you can run the following:

```bash
docker run -d -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:lts
```

- `-d` to run in detached mode
- `-p 9443:9443` the port to access the webGUI
- `--name portainer` sets the container name to be portainer
- `--restart=always` Docker will always try to start this container if it is stopped
- `-v /path/on/host/:/path/in/continer` bind the path from the host into the path on the container.

The first thing that will happen when we access the websties @ `<host-machine-ip>:9443` is a prompt for you to create a user account to manage Portainer. From here we can manage the rest of the containers that we make from Portainer.

## Nginx

Nginx Proxy Manager is a proxy manager that acts as a reverse proxy. We are deploying this for two main reasons:

1) To control network traffic, espcially to the web UI's for all of my services.
2) To provide SSL certificates from an Authoritative root server to prevent our browsers from complaining about self-signed certificates.
3) To utilize the wildcard certificate to access my services using one united domain under different subdomains.

To explain lets use an easy example, my NAS. My NAS will have effectivly two records in the DNS: a local A record and a CNAME record. We can use the A record to access the NAS for things like SMB. Then we will use the CNAME record to access the Web Interface for the NAS. The A record will point directly to the IP address of the NAS while the CNAME record will point to NGINX. The following is a table that describes the records.

| Name | Resolves To | Description |
| ------ | ------------- | ------------- |
| nas.local | 192.168.0.20 | 'A' Record for NAS |
| nginx.host.local | 192.168.0.21 | 'A' Record for host machine that runs the Nginx Proxy Manager Container |
| nas.userID.duckdns.org | nginx.host.local | CNAME record pointing our nas' duckdns name to nginx. |

Once the requests hit the Nginx, nginx will route `nas.userID.duckdns.org` to `nas.local` on the proper port. This will go back to the DNS server to resolve down to the NAS' IP address (192.168.0.20) and then go to the server, with a valid SSL certificate thus prevening the self-sign certificate warning in the browser. Meanwhile, we can still use `nas.local` to map the share on our Windows Clients.

### Nginx Docker/Portainer Configuration

In Portainer, go to your local docker instance. Then go to `Containers`. Click `Add Container`. Then we are going to add the following configurations. I have it here as a docker-compose file but I set this up using the GUI:

```yaml
services:
  app:
    container_name: nginex-proxy-manager
    image: 'jc21/nginx-proxy-manager:latest'
    restart: unless-stopped
    environment:
      TZ: "<your-unix-timezone>"
    ports:
      - '80:80'                               # Public HTTP Port
      - '443:443'                             # Public HTTPS Port
      - '81:81'                               # Admin Web Port
    volumes:
      - /path/to/host/nginx/data:/data
      - /path/to/host/nginx:/etc/letsencrypt
```

In Portainer, the `container_name` and `image` fields are here:

![Name and Image](./img/name_and_image.png)

The `ports` section goes here:

![Ports](./img/ports_location.png)

Scrolling down to the `Advanced Container Settings`, we can bind our volumes in the `volumes` tab:

![Volumes](./img/volumes.png)

Also we can find the `Restart Policy` Section:

![Restart Policy](./img/restart_policy.png)

Finally we get to `Environment`. This section is where we can set the enviornment variables. In this image, you see the already complete container up and running. There are more variables that get loaded after the creation of the container. Just know that this is where you would put your env variables like the timezone:

![Enviornment Variables](./img/env.png)

### Nginx Certificate setup

After the container is spun up, we can go to the web interface @ <docker_host_ip:81>. From here we can set up our user account. After we get our account set up, we need to set up our certificates. First, we are going to click on the `Certificates` Tab in the top bar. Next we are going to click `Add Certificate` on the right hand side. In my case, I will be using Let's Encrypt via DNS. This is becuase I am getting wildcard certificates from DuckDNS. For the most part I am going to leave the defaults; however I will set my DNS provider and include my DuckDNS key in the credential file. I will save this configuration and now we should have a valid wildcard cert on this server.

### Nginx Proxy setup

From the `Dashboard` Tab, click the `Proxy Hosts` button. This is where all your proxies will live. Click on `Add Proxy Host` in the top right. Enter your domain.

> [!NOTE]
> Rememmber we have a wildcard cert from duckdns. That means we can enter nas.userID.duckdns.org and it will still work.

Next make sure to select the proper scheme (http/s). Regardless of which scheme you use, we can set up the proxy to force HTTPS and use SSL to encrypt our connection. Then like described at the begining, we will enter the local name for the website. (In the example above we used `nas.local`) Finally, we will put the port the service is listning on. Optionally, your service may need websocket support, so enable that if its needed. An example of a service that wants Websocket support is Proxmox's web interface. If we do not enable websocket support, the noVNC Remote desktop tools built into Proxmox will not work. Before we save, we can move to the `SSL` tab and we should select `Force SSL` and `HTTP/2 Support` this will route all traffic whether its HTTP or HTTPS as HTTPS.

## iVentoy

Originally, I planned to run this on bare metal on the Raspberry Pi. However, I found a container was easier to maintain and provided extra security. At this time, I am choosing to accpet the risk of running iVentoy raised by [Gary Bowers](https://github.com/garybowers/iventoy_docker?tab=readme-ov-file#%EF%B8%8F-beware-security-concerns).

> [!CAUTION]
> iVentoy is not fully open source. According to Bowers (and the documention on [iVentoy's github](https://github.com/ventoy/PXE)), there are some Kernel-Level drivers injected at runtime. These drivers are the closed-source portion of iVentoy. iVentoy states that the driver "...is used to mount the ISO file in the server side as a local drive (e.g. Y:) throug http." (From iVentoy on [Github](https://github.com/ventoy/PXE#:~:text=This%20driver%20is%20used%20to%20mount%20the%20ISO%20file%20in%20the%20server%20side%20as%20a%20local%20drive%20%28e%2Eg%2E%20Y%3A%29%20throug%20http)) They also state that the driver is only loaded into RAM and not into the actual kernal.

With that being said, I decided to use Bowers depricated contianer to host iVentoy. While, I typically just use portainer to spin up new containers, here's what a docker-compose file would look like for this container:

```yaml
services:
  iVentoy:
    image: garybowers/iventoy:latest
    network_mode: host                   # Required so iVentoy can receive DHCP requests from Upstream DHCP
    container_name: iventoy
    restart: unless-stopped
    privileged: true                     # Must run as root since iVentoy requires root
    hostname: iventoy
   volumes:
      - /path/to/host/data:/iventoy/data # Config/License file
      - /path/to/host/iso:/iventoy/iso   # iso directory
      - /path/to/host/log:/iventoy/log   # Log files
      - /path/to/host/user:/iventoy/user # Autoisntall script locaiton
    ports:
      - 26000:26000                      # iVentoy Config UI
      - 16000:16000                      # iVentoy PXE service
      - 10809:10809                      # Network Block Device serive
      - 69:69                            # TFTP 
      - 67:67                            # DHCP
    environment:
      - AUTO_START_PXE: true
```

***
Return to [Readme](./README.md)
