# Milestone 7 - Deploying and Post Provisioning of BlueX Linux Servers

## 7.1 - Rocky Base VM

1. Created a new VM called `rocky-base` using Rocky Linux 9.7 minimal ISO, thin provisioned
2. Created `deployer` user during installation
3. Ran sysprep to prep for cloning:
   - Cleared machine-id: `echo -n > /etc/machine-id`
   - Removed SSH host keys: `rm /etc/ssh/ssh_host_*`
   - Reset network to DHCP
4. Shut down and took snapshot called `base`

---

## 7.2 - DHCP on blue27-fw and Static Route on 480-fw

1. Logged into `480-fw` and added a static route:

```
set protocols static route 10.0.5.0/24 next-hop 10.0.17.200
commit
save
```

<img alt="Screenshot 2026-04-08 154902" src="https://github.com/user-attachments/assets/8a7da470-b917-404c-94c7-9704fab961c2" />

2. Created `blue-fw.yaml` yml inventory file and `blue-playbook.yaml` to configure DHCP on `blue27-fw` using the `vyos_config` module with the following settings:
   - Subnet: `10.0.5.0/24`
   - Range: `10.0.5.75` to `10.0.5.125`
   - Gateway: `10.0.5.2`
   - Nameserver: `10.0.5.5`
   - Domain: `blue27.local`

3. Cloned `rocky-base` three times using `New-480LinkedClone`, all landing on the blue27 network
5. All three VMs picked up DHCP addresses from the pool

<img alt="Screenshot 2026-04-08 170158" src="https://github.com/user-attachments/assets/f3d0e9e3-be26-4d7a-be92-2d897d870b9f" />
<img alt="Screenshot 2026-04-08 170411" src="https://github.com/user-attachments/assets/4f691f86-04e4-4d09-b049-28cf2be00595" />
<img alt="Screenshot 2026-04-08 170335" src="https://github.com/user-attachments/assets/95772121-6e06-41bc-a128-5f29a62b44cc" />

**Deliverable 1 video goes here.**

---

## 7.3 - Post Provisioning Rocky 1-3

1. Generated SSH keypair on xubuntu-wan:

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/deployer -C "deployer"
```

<img alt="Screenshot 2026-04-08 004234" src="https://github.com/user-attachments/assets/d19c76ec-4fa9-4dcf-b6a4-73cfdabdd1b7" />

2. Copied public key to each Rocky VM with `ssh-copy-id`
3. Confirmed all three reachable via Ansible:

```bash
ansible rocky -i blue-fw.yaml -m ping
```

<img alt="Screenshot 2026-04-08 175009" src="https://github.com/user-attachments/assets/977c648b-0897-48e2-8fc6-fb83d4bff595" />

4. Created `post-playbook.yml` with the following tasks:
   - Add deployer public key via `authorized_key`
   - Drop sudoers file at `/etc/sudoers.d/deployer` for `NOPASSWD: ALL`
   - Set hostname via `hostname` module
   - Set static IP via `nmcli` shell command
   - Bring connection up

5. Ran the playbook, static IPs assigned:
   - rocky-1: `10.0.5.11`
   - rocky-2: `10.0.5.10`
   - rocky-3: `10.0.5.12`

6. Updated inventory with new static IPs

<img width="852" height="636" alt="post1" src="https://github.com/user-attachments/assets/791f73d6-08e6-42c4-9e8f-cec6617dcd9c" />   
<img width="928" height="655" alt="post2" src="https://github.com/user-attachments/assets/4aa24797-5a9c-4e92-bacf-e39e9e346192" />
<img width="860" height="793" alt="post3" src="https://github.com/user-attachments/assets/0f639a2e-02e0-4290-a076-4e7eaa68ef78" />

**Deliverable 2 video goes here.**

---

## 7.4 - Post Provisioning Ubuntu 1-2

1. Built `ubuntu-base` using Ubuntu 25.10 server ISO, created `deployer` user
2. Ran sysprep:
   - Removed SSH host keys: `rm /etc/ssh/ssh_host_*`
   - Removed netplan config: `rm /etc/netplan/00-installer-config.yaml`
   - Cleared machine-id: `echo -n > /etc/machine-id`
3. Shut down and took snapshot called `base`

<img alt="Screenshot 2026-04-13 135047" src="https://github.com/user-attachments/assets/a6dc2bb8-f77f-499e-a96a-1a04796e52da" />

4. Cloned twice using `New-480LinkedClone` onto the blue27 network

<img alt="Screenshot 2026-04-13 135516" src="https://github.com/user-attachments/assets/c3637734-29a8-48ef-a626-ad667af31ac7" />

5. After cloning, regenerated SSH host keys on each VM from the console:

```bash
sudo ssh-keygen -A
sudo systemctl start ssh
```

6. Manually created a temporary netplan config on each clone using `tee` (no text editor available, no internet)
7. Both VMs came up on DHCP and were reachable via Ansible ping

<img alt="Screenshot 2026-04-13 152108" src="https://github.com/user-attachments/assets/7883df4e-9b11-4117-82f7-6e09ff636bc8" />

8. Created `templates/netplan.j2` as a Jinja2 template for static IP config
9. Created `ubuntu-playbook.yml` with the following tasks:
   - Add deployer public key via `authorized_key`
   - Set hostname via `hostname` module
   - Deploy netplan template to `/etc/netplan/01-netcfg.yaml`
   - Reboot with `async: 1, poll: 0`

10. Before running the playbook, manually wrote the sudoers entry on each VM from the console since the base image did not have passwordless sudo:

```bash
echo "Towerhill0!" | sudo -S bash -c 'echo "deployer ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/deployer'
```

11. Ran the playbook, both VMs rebooted and came up on their static IPs
12. Verified over SSH:

```bash
ssh deployer@10.0.5.30
ip a
hostname

ssh deployer@10.0.5.31
ip a
hostname

```

<img alt="Screenshot 2026-04-13 172338" src="https://github.com/user-attachments/assets/112ade7f-4008-4cd4-a170-289df535b334" />
<img alt="Screenshot 2026-04-13 172413" src="https://github.com/user-attachments/assets/6c4af5b2-467a-484e-8b92-764a853da18b" />


**Deliverable 3 video goes here.**
