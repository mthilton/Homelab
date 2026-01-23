# Hardware
Here is a detailed breakdown of my hardware: 

## Raspberry Pi

The Raspberry Pi 5 primarily exists in the homelab because it is what I started out with. Once my Homelab endevors grew, I decided to keep the Pi running for two main reasons. 

   1. It was already set up with my Wireguard and DNS solutions so why tear it down if I had no other use for the Pi. 
   2. I knew that the other machine would need troubleshooting and as long as I knew my DNS was solid I could keep that out of the equation. In summary it just made sense to keep it deployed. 

### Pi Configurarion

For the most part, the RPi has a standard configuration. Its using the latest verison of PiOS, running without a GUI. It is meant to be run headless so I disabled the GUI.

## Dell 

The [Dell Optiplex 9020](https://www.dell.com/support/product-details/en-us/product/optiplex-9020-desktop/overview) is a ~10 year old machine. Originally I purchased this machine to flip about 5 years ago. Originally it had an Intel i5-4560, 2x4Gb of RAM, and a 128 GB SSD + 500 GB HDD. The SSD was added when I purchased the machine years ago. I never got around to purchasing a entry level GPU for flipping the machine so it sat in my place for years. Then I pulled out the SSD+HDD after I found a crazy deal on 2 10TB Hard Drives. 

Once I purchased those drives, I knew that I wanted to turn this machine into a server. That being the case, I knew that I would need a few things. 

   1. A "higher" core count CPU
   2. More RAM
   3. Faster Networking
   4. An HBA so I can make good use of ZFS

So thats what I did

   1. i5-4560 -> i7-4790. Technically, this isn't more cores, however 4th Generation Intel i5 CPUs did not support Hyperthreading where the i7's did.
   2. 2x4GB -> 4x8GB. Went from 8 total Gigs to 32. This will help tremendously with the storage server. As I understand it, TrueNAS will cache recently accessed files in ram, then in L2 ARC. Unfortunatly, this server will not be recieveing an SSD cache. NAND is not cheap right now.
   3. I added a 2.5 Gig Networking card that will be passed directly into the storage server. All of the other [services](./Services.md) will either have the very fast VirtIO networking between one another, or they won't need fast networking. This means that the storage server, which will need fast networking to the other computers on the network, can monopolize the card. 
   4. LSI 9207-8i. This is so I can connect 8 Hard Drives. In this particuar footprint, I would only add 4 HDDs. That's all I can comfortably mount in the 9020. I could mount more, but then we start stacking HDDs directly on top of each other causing them to vibrate one another. This would be pretty bad. 

### The LSI 9270-8i

A lot of LSI cards are already flashed to the "IT Mode". What is "IT Mode", honestly I don't fully understand it myself. What I understand is that in IT Mode, the card effectively acts as extra SATA ports rather than trying to provide RAID-like functions. The upside to this approach is that recovering from hardware failure is easier to recover from in comparison to acting as a RAID controller. The reason being, that software RAIDs are easier to rebuild; if the RAID controller dies, since it was responsible for maintaing the parity, it is a lot harder to rebuild your array. The downside is that software RAID is quite a bit slower. Instead of relying on the card to calculate the parity, it is up to the CPU/the software to figure it out, which will take more time. 

That beings said when I recieved this card and installed it into the computer, I noticed my boot times skyrocketed. I know this isn't a new platform by any stretch of the imagination but when passed through to the [TrueNAS VM](./Services.md) it would take more than 15 mins to boot. The simple solution was to remove the BIOS & UEFI from the card. 

Since my desktop was designed to have an OS always present, I found the easist way was to follow [this guide](https://www.youtube.com/watch?v=CZt0mGOoba4) from the Art of Server Channel on YouTube. You will need two peices of software that they have compiled for use on linux. ***USE AT YOUR OWN RISK***. In order to use this software, I SSH'd into the TrueNAS VM and did the following:

```bash
sudo su                               # Switched to Root to add files to 
                                      # the /etc/ dir
mkdir /etc/lsiutil                    # Made a new dir to store the binaries

# Download the lsiutil and optionally sas2flash.
# Using sas2flash is only used to verify the BIOS and the UEFI are gone.
curl -O https://https://artofserver.com/downloads/lsi/utilities/linux/lsiutil
curl -O https://https://artofserver.com/downloads/lsi/utilities/linux/sas2flash

chmod +x ./*                          # Made any file in this dir executable
./sas2flash -list                     # Check your BIOS/UEFI verision is

./lsiutil -s                          # verified the port number. Indexing 
                                      # starts at 0
                                      # but the port number start at 1
./lsiutil -p <your-port-number> -e 4  # run adv task 4 on port <your-port-number>
./sas2flash -list                     # Verify that you have no BIOS/UEFI
```
When we run `lsiutil` on `<your-port-number>` you will be taken through a series of prompts. Essentially, you want to leave everything blank except when they ask yes or no questions. You will generally answer 'No'. This will write an empty BIOS/UEFI to their respective sections effectively deleting the BIOS/UEFI. The reason you would say 'no' when it asks if you want to save is up to personal preference; if you want to save the BIOS/UEFI ROM you can, I just saw no need to. Now my boot times are back to normal.

***
Return to [Readme](./README.md)
