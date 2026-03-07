# Homelab Documentation

This repo describes what services I run in my homelab and how everything works. This repo serves to document my work and showcase it to anybody curious.

## Hardware

There are two main computers/servers in this set up. The first machine is a [Raspberry Pi 5](./Hardware.md#raspberry-pi). This is primarily responsible for the [DNS Stack](./Network.md#dns-stack) and [Wireguard](./Network.md#wireguard). The second server is an recycled [Dell Optiplex 9020](./Hardware.md#dell). This machine is responsible for hosting the Hypervisor for all of my [VM's and Containers](./Virtualization-Containerizaion.md). The first VM is for Mass Storage for the rest of the homelab running TrueNAS. The Docker containers live in a Debian VM. Docker hosts the other services that are containerized. Most of the machines in this Homelab have 2.5 Gig [networking](./Network.md).

## Services

While I have a lot going on in the homelab, I am only hosting a few Services:

- [Pi-Hole DNS](./Network.md#dns-stack)
- [Unbound Recursive DNS](./Network.md#dns-stack)
- [Wireguard](./Network.md#wireguard)
- [TrueNAS](./Services.md#truenas)
- [Portainer](./Services.md#portainer)
- [Nginx Proxy Manager](./Services.md#nginx)
- [DHCP Windows Server 2022](./Network.md#dhcp)
- [iVentoy](./Services.md#iventoy)

These are a list of Services that I may add in the future:

- Jellyfin/Plex
- Immich
- Opencloud
- TimeMachine Backup
- Gitlab

## Sections

To learn more about my Homelab here are the various files that have explantions:

- [Hardware](Hardware.md)
- [Network](Network.md)
- [Virtualization/Containerization](Virtualization-Containerizaion.md)
- [Services](Services.md)

## TODO

These are Task that I would like to complete. Eventually this will move into the issues tab that way I can merge it like a real repo.

- Add section about how to create vm's in proxmox
- Set up automatic backups for all machines
- Add SSO with Authilia?
- Reconfigure raspberry pi to host NPM, Pi-Hole, Unbound, PiVPN, and Authila? all in docker
- set up GitLab for issue tracking and general repo
- set up Immich for photo backup on my girlfriend and my's phones
- Figure out Opencloud
- Set up a torent pipeline for Jellyfin/Plex
