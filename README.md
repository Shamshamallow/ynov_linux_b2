# TP1 : Déploiement classique

Le but de ce TP est d'effectuer le déploiement de services réseau assez classiques, ainsi que réaliser une configuration système élémentaire (réseau, stockage, utilisateurs, etc.).

Au menu :

- partitionnement de disque
- gestion d'utilisateurs et de permissions
- gestion de firewall
- installation et configuration de services
  - serveur web
  - backup
  - monitoring + alerting

- [0. Prérequis](#0-prérequis)
- [I. Setup serveur Web](#i-setup-serveur-web)
- [II. Script de sauvegarde](#ii-script-de-sauvegarde)
- [III. Monitoring, alerting](#iii-monitoring-alerting)

# 0. Prérequis

> **POUR RAPPEL** pour chacune des opérations, vous devez fournir dans le compte-rendu : comment réaliser l'opération ET la preuve que l'opération a été bien réalisée

🌞 **Setup de deux machines CentOS7 configurée de façon basique.**

- partitionnement
  - ajouter un deuxième disque de 5Go à la machine

```shell
[mdugoua@localhost ~]$ lsblk
NAME            MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda               8:0    0    8G  0 disk
|-sda1            8:1    0    1G  0 part /boot
`-sda2            8:2    0    7G  0 part
  |-centos-root 253:0    0  6.2G  0 lvm  /
  `-centos-swap 253:1    0  820M  0 lvm  [SWAP]
sdb               8:16   0    5G  0 disk
sr0              11:0    1 1024M  0 rom
```

```shell
[mdugoua@localhost ~]$ sudo pvcreate /dev/sdb
[sudo] password for mdugoua:
  Physical volume "/dev/sdb" successfully created.
  
[mdugoua@localhost ~]$ sudo pvs
  PV         VG     Fmt  Attr PSize  PFree
  /dev/sda2  centos lvm2 a--  <7.00g    0
  /dev/sdb          lvm2 ---   5.00g 5.00g
```

*Ci dessus on peut voir le disque sdb de 5Go comme demandé.*

- partitionner le nouveau disque avec LVM

  ```shell
  [mdugoua@localhost ~]$ sudo vgcreate site /dev/sdb
  [sudo] password for mdugoua:
    Volume group "site" successfully created
    
  [mdugoua@localhost ~]$ sudo vgs
    VG     #PV #LV #SN Attr   VSize  VFree
    centos   1   2   0 wz--n- <7.00g     0
    site     1   0   0 wz--n- <5.00g <5.00g
  ```

  - deux partitions, une de 2Go, une de 3Go
  - la partition de 2Go sera montée sur `/srv/site1`

  ```shell
  [mdugoua@localhost ~]$ sudo lvcreate -l 100%FREE site  -n site1
    Logical volume "site1" created.
  [mdugoua@localhost ~]$ sudo lvs
    LV    VG     Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
    root  centos -wi-ao----  <6.20g
    swap  centos -wi-ao---- 820.00m
    site1 site   -wi-a-----  <2.00g
    site2 site   -wi-a-----   3.00g
  ```

  ```shell
  [mdugoua@localhost ~]$ sudo mkfs -t ext4 /dev/site/site1
  mke2fs 1.42.9 (28-Dec-2013)
  Filesystem label=
  OS type: Linux
  Block size=4096 (log=2)
  Fragment size=4096 (log=2)
  Stride=0 blocks, Stripe width=0 blocks
  130816 inodes, 523264 blocks
  26163 blocks (5.00%) reserved for the super user
  First data block=0
  Maximum filesystem blocks=536870912
  16 block groups
  32768 blocks per group, 32768 fragments per group
  8176 inodes per group
  Superblock backups stored on blocks:
  	32768, 98304, 163840, 229376, 294912
  
  Allocating group tables: done
  Writing inode tables: done
  Creating journal (8192 blocks): done
  Writing superblocks and filesystem accounting information: done
  ```

  ```shell
  [mdugoua@localhost ~]$ dfsudo mkdir /srv/site1
  [mdugoua@localhost ~]$ sudo mount /dev/site/site1 /srv/site1
  ```

  - la partition de 3Go sera montée sur `/srv/site2`

  ``` shell
  [mdugoua@localhost ~]$ sudo lvcreate -L 3G site  -n site2
    Logical volume "site2" created.
  [mdugoua@localhost ~]$ sudo lvs
    LV    VG     Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
    root  centos -wi-ao----  <6.20g
    swap  centos -wi-ao---- 820.00m
    site2 site   -wi-a-----   3.00g
  ```

  ```shell
  [mdugoua@localhost ~]$ sudo mkfs -t ext4 /dev/site/site2
  mke2fs 1.42.9 (28-Dec-2013)
  Filesystem label=
  OS type: Linux
  Block size=4096 (log=2)
  Fragment size=4096 (log=2)
  Stride=0 blocks, Stripe width=0 blocks
  196608 inodes, 786432 blocks
  39321 blocks (5.00%) reserved for the super user
  First data block=0
  Maximum filesystem blocks=805306368
  24 block groups
  32768 blocks per group, 32768 fragments per group
  8192 inodes per group
  Superblock backups stored on blocks:
  	32768, 98304, 163840, 229376, 294912
  
  Allocating group tables: done
  Writing inode tables: done
  Creating journal (16384 blocks): done
  Writing superblocks and filesystem accounting information: done
  ```

  ```shell
  [mdugoua@localhost ~]$ sudo mkdir /srv/site2
  [mdugoua@localhost ~]$ sudo mount /dev/site/site2 /srv/site2
  ```

- les partitions doivent être montées automatiquement au démarrage (fichier `/etc/fstab`)

```shell
[mdugoua@localhost ~]$ cat /etc/fstab
#
# /etc/fstab
# Created by anaconda on Tue Mar 10 16:03:15 2020
#
# Accessible filesystems, by reference, are maintained under '/dev/disk'
# See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info
#
/dev/mapper/centos-root /                       xfs     defaults        0 0
UUID=68ef5c46-322d-49d0-8eb4-e8f8de10c475 /boot                   xfs     defaults        0 0
/dev/mapper/centos-swap swap                    swap    defaults        0 0
/dev/mapper/site-site1 /srv/site1 ext4 defaults 0 0
/dev/mapper/site-site2 /srv/site2 ext4 defaults 0 0
```

```shell
[mdugoua@localhost ~]$ sudo umount /srv/site1
[mdugoua@localhost ~]$ sudo umount /srv/site2
[mdugoua@localhost ~]$ sudo mount -av
/                        : ignored
/boot                    : already mounted
swap                     : ignored
mount: /srv/site1 does not contain SELinux labels.
       You just mounted an file system that supports labels which does not
       contain labels, onto an SELinux box. It is likely that confined
       applications will generate AVC messages and not be allowed access to
       this file system.  For more details see restorecon(8) and mount(8).
/srv/site1               : successfully mounted
mount: /srv/site2 does not contain SELinux labels.
       You just mounted an file system that supports labels which does not
       contain labels, onto an SELinux box. It is likely that confined
       applications will generate AVC messages and not be allowed access to
       this file system.  For more details see restorecon(8) and mount(8).
/srv/site2               : successfully mounted
```

- un accès internet

  - carte réseau dédiée

  ```shell
  [mdugoua@localhost ~]$ ip a
  [. . .]
  2: enp0s3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
      link/ether 08:00:27:c2:38:77 brd ff:ff:ff:ff:ff:ff
      inet 10.0.2.15/24 brd 10.0.2.255 scope global noprefixroute dynamic enp0s3
         valid_lft 78777sec preferred_lft 78777sec
      inet6 fe80::2a03:f67f:7355:380/64 scope link noprefixroute
         valid_lft forever preferred_lft forever
  [. . .]
  ```

  - route par défaut

  ```shell
  [mdugoua@localhost ~]$ ip route show
  default via 10.0.2.2 dev enp0s3 proto dhcp metric 100
  10.0.2.0/24 dev enp0s3 proto kernel scope link src 10.0.2.15 metric 100
  192.168.59.0/24 dev enp0s8 proto kernel scope link src 192.168.59.11 metric 101
  ```

- un accès à un réseau local (les deux machines peuvent se 

  ```
  ping
  ```

  )

  ```shell
  [mdugoua@localhost ~]$ dig google.com@8.8.8.8
  
  ; <<>> DiG 9.11.4-P2-RedHat-9.11.4-9.P2.el7 <<>> google.com@8.8.8.8
  ;; global options: +cmd
  ;; Got answer:
  ;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 12544
  ;; flags: qr rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1
  
  ;; OPT PSEUDOSECTION:
  ; EDNS: version: 0, flags:; udp: 4000
  ;; QUESTION SECTION:
  ;google.com\@8.8.8.8.		IN	A
  
  ;; AUTHORITY SECTION:
  .			900	IN	SOA	a.root-servers.net. nstld.verisign-grs.com. 2020092300 1800 900 604800 86400
  
  ;; Query time: 196 msec
  ;; SERVER: 10.33.10.148#53(10.33.10.148)
  ;; WHEN: Wed Sep 23 17:54:44 CEST 2020
  ;; MSG SIZE  rcvd: 122
  ```

  - carte réseau dédiée

  ```shell
  [mdugoua@localhost ~]$ ip a
  [. . .]
  3: enp0s8: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
      link/ether 08:00:27:4a:3f:1c brd ff:ff:ff:ff:ff:ff
      inet 192.168.59.11/24 brd 192.168.59.255 scope global noprefixroute enp0s8
         valid_lft forever preferred_lft forever
      inet6 fe80::a00:27ff:fe4a:3f1c/64 scope link
         valid_lft forever preferred_lft forever
  ```

  - route locale

  ```shell
  [mdugoua@localhost ~]$ ip route show
  default via 10.0.2.2 dev enp0s3 proto dhcp metric 100
  10.0.2.0/24 dev enp0s3 proto kernel scope link src 10.0.2.15 metric 100
  192.168.59.0/24 dev enp0s8 proto kernel scope link src 192.168.59.11 metric 101
  ```

- les machines doivent avoir un nom

  - `/etc/hostname`

  ```shell
  [mdugoua@localhost ~]$ cat /etc/hostname
  localhost.localdomain
  node1.tp1.b2
  ```

  ```shell
  [mdugoua@localhost ~]$ cat /etc/hostname
  localhost.localdomain
  node2.tp1.b
  ```

  - commande `hostname`)

  ```shell
  [mdugoua@localhost ~]$ sudo hostname node1.tp1.b2
  ```

  ```shell
  [mdugoua@localhost ~]$ sudo hostname node2.tp1.b2
  ```

- les machines doivent pouvoir se joindre par leurs noms respectifs

  - fichier `/etc/hosts`

  ```shell
  [mdugoua@localhost ~]$ cat /etc/hosts
  127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
  ::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
  192.168.1.12 node2.tp1.b2
  ```

  ```shell
  [mdugoua@localhost ~]$ cat /etc/hosts
  127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
  ::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
  192.168.1.11 node1.tp1.b2
  ```

- un utilisateur administrateur est créé sur les deux machines (il peut exécuter des commandes 

  ```
  sudo
  ```

   en tant que 

  ```
  root
  ```

  )

  - création d'un user

  ```shell
  [mdugoua@node2 ~]$ sudo useradd node1
  ```

  ```shell
  [mdugoua@node2 ~]$ sudo useradd node2
  ```

  - modification de la conf sudo

  ```shell
  [mdugoua@node1 ~]$ sudo usermod -a -G wheel node1
  ```

  ```shell
  [mdugoua@node2 ~]$ sudo usermod -a -G wheel node2
  ```

- vous n'utilisez QUE 

  ```
  ssh
  ```

   pour administrer les machines

  - création d'une paire de clés (sur VOTRE PC)

  ```powershell
  ➜  ~ ssh-keygen
  Generating public/private rsa key pair.
  Enter file in which to save the key (/Users/marie/.ssh/id_rsa): yes
  Enter passphrase (empty for no passphrase):
  Enter same passphrase again:
  Your identification has been saved in yes.
  Your public key has been saved in yes.pub.
  The key fingerprint is:
  SHA256:IT7Cu/aoUfcuTpMrWWZJX9Pa7RV8Flb8W6vEMHvl6hg marie@MacBook-Pro-de-Marie.local
  The key's randomart image is:
  +---[RSA 2048]----+
  |               .o|
  |               o.|
  |      . .  .  o o|
  |   . ... .oo.  +=|
  |    +.+oS. +=.o.*|
  |   . +=+. ...+.+.|
  |  . .=+ .  Eo.o. |
  |   .++.+    oo.  |
  |  .oo++..  ...   |
  +----[SHA256]-----+
  ```

  - déposer la clé publique sur l'utilisateur de destination

  ```powershell
  ➜  ~ ssh-copy-id  mdugoua@192.168.1.11 //node1
  ```

  ```powershell
  ➜  ~ ssh-copy-id  mdugoua@192.168.1.12 //node2
  ```

- le pare-feu est configuré pour bloquer toutes les connexions exceptées celles qui sont nécessaires

  - commande `firewall-cmd` ou `iptables`
  
  ```shell
  [mdugoua@node1 ~]$ sudo firewall-cmd --list-all
  public (active)
    target: default
    icmp-block-inversion: no
    interfaces: enp0s3 enp0s8
    sources:
    services: dhcpv6-client ssh
    ports: 80/tcp 443/tcp
    protocols:
    masquerade: no
    forward-ports:
    source-ports:
    icmp-blocks:
    rich rules:
  ```

Pour le réseau des différentes machines :

| Name           | IP             |
| -------------- | -------------- |
| `node1.tp1.b2` | `192.168.1.11` |
| `node2.tp1.b2` | `192.168.1.12` |

# I. Setup serveur Web

🌞 Installer le serveur web NGINX sur `node1.tp1.b2` (avec une commande `yum install`).

🌞 Faites en sorte que :

- NGINX servent deux sites web, chacun possède un fichier unique `index.html`

- les sites web doivent se trouver dans 

  ```
  /srv/site1
  ```

   et 

  ```
  /srv/site2
  ```

  - les permissions sur ces dossiers doivent être le plus restrictif possible
  - ces dossiers doivent appartenir à un utilisateur et un groupe spécifique

  ``` shell
  [admin@node1 ~]$ ls -la /srv/
  total 8
  drwxr-xr-x.  4 root  root    32 Sep 23 17:32 .
  dr-xr-xr-x. 17 root  root   224 Mar 10  2020 ..
  drwxr-x---.  3 admin admin 4096 Sep 24 16:11 site1
  drwxr-x---.  3 admin admin 4096 Sep 24 16:11 site2
  [admin@node1 ~]$ ls -la /srv/site1
  total 24
  drwxr-x---. 3 admin admin  4096 Sep 24 16:11 .
  drwxr-xr-x. 4 root  root     32 Sep 23 17:32 ..
  -r--------. 1 admin admin    15 Sep 24 16:11 index.html
  drwx------. 2 root  root  16384 Sep 23 17:24 lost+found
  [admin@node1 ~]$ ls -la /srv/site2
  total 24
  drwxr-x---. 3 admin admin  4096 Sep 24 16:11 .
  drwxr-xr-x. 4 root  root     32 Sep 23 17:32 ..
  -r--------. 1 admin admin    15 Sep 24 16:11 index.html
  drwx------. 2 root  root  16384 Sep 23 17:25 lost+found
  [admin@node1 ~]$ cat /srv/site1/index.html
  <h1>site1</h1>
  [admin@node1 ~]$ cat /srv/site2/index.html
  <h1>site2</h1>
  ```

- NGINX doit utiliser un utilisateur dédié que vous avez créé à cet effet

- les sites doivent être servis en HTTPS sur le port 443 et en HTTP sur le port 80

  - n'oubliez pas d'ouvrir les ports firewall

Voici un exemple d'une unique fichier de configuration `nginx.conf` qui ne sert qu'un seul site, sur le port 8080, se trouvant dans `/tmp/test`:

```
#
# Run in the foreground locally
# nginx -p . -c nginx.conf
#

worker_processes 1;
daemon off;
error_log nginx_error.log;
events {
    worker_connections 1024;
}

http {
    server {
        listen 8080;

        location / {
            root /tmp/test;
        }
    }
}
```

```bash
      1 # For more information on configuration, see:
      2 #   * Official English Documentation: http://nginx.org/en/docs/
      3 #   * Official Russian Documentation: http://nginx.org/ru/docs/
      4
      5 user admin;
      6 worker_processes 1;
      7 error_log /var/log/nginx/error.log;
      8 pid /run/nginx.pid;
      9
     10 include /usr/share/nginx/modules/*.conf;
     11
     12 events {
     13     worker_connections 1024;
     14 }
     15
     16 http {
     17         server {
     18                 listen       80;
     19                 server_name  node1.tp1.b2;
     20
     21                 location / {
     22                         return 301 /site1;
     23                 }
     24
     25                 location /site1 {
     26                         alias /srv/site1;
     27                 }
     28
     29                 location /site2 {
     30                         alias /srv/site2;
     31                 }
     32         }
     33 }
```

🌞 Prouver que la machine `node2` peut joindre les deux sites web.

```shell
[mdugoua@node2 ~]$ curl node1.tp1.b2
<html>
<head><title>301 Moved Permanently</title></head>
<body>
<center><h1>301 Moved Permanently</h1></center>
<hr><center>nginx/1.16.1</center>
</body>
</html>

[mdugoua@node2 ~]$ curl -L node1.tp1.b2
<h1>site1</h1>
```

# II. Script de sauvegarde

**Yup. Again.**

🌞 Ecrire un script qui :

- s'appelle `tp1_backup.sh`

```bash
1 #!/bin/sh
2 # mdugoua
3 # 28/09/2020
4 # Backup script
5
6 # date du jour
7 backupDate=$(date +%Y%m%d_%H%M%S)
8
9 #archive name
10 pathDirectory="$1"
11 pathTarget=${pathDirectory##*/}
12 backupName="${pathTarget}_${backupDate}.tar.gz"
13
14 #where to save
15 destination="/srv/backup/${backupName}"
16
17 save(){
18          tar -cvzf $destination $pathDirectory
19 }
20 deleteFile(){
21         olderFile=$(ls -tp backup/ | tail -4)
22         for file in ${olderFile};
23         do
24                 rm -f ${file}
25         done;
26 }
27
28 if [[ -n $1 ]]
29 then
30         countBackup=$(ls -l backup/ | wc -l)
31         if [[ $countBackup -gt 8 ]]
32         then
33                 echo "Les sauvegarde les plus ancienne vont etre supprime"
34                 deleteFile
35         else
36                 echo "Vous avez $countBackup sauvegarde"
37                 echo "Sauvegarge de $pathTarget vers $destination"
38                 save
39         fi
40 else
41         echo "Vous n'avez pas données d'arguments">&2
42         exit 1i
43 fi

```

- sauvegarde les deux sites web
  - c'est à dire qu'il crée une archive compressée pour chacun des sites
  - je vous conseille d'utiliser le format `tar` pour l'archivage et `gzip` pour la compression
  
- les noms des archives doivent contenir le nom du site sauvegardé ainsi que la date et heure de la sauvegarde
  
  - par exemple `site1_20200923_2358` (pour le 23 Septembre 2020 à 23h58)
  
- vous ne devez garder que 7 exemplaires sauvegardes
  
  - à la huitième sauvegarde réalisée, la plus ancienne est supprimée
  
- le script ne sauvegarde qu'un dossier à la fois, le chemin vers ce dossier est passé en argument du script
  
  - on peut donc appeler le script en faisant `tp1_backup.sh /srv/site1` afin de déclencher une sauvegarde de `/srv/site1`
  
  ```shell
  [backup@localhost srv]$ ./tp1_backup.sh /srv/site1
  Vous avez 1 sauvegarde
  Sauvegarge de site1 vers /srv/backup/site1_20200928_225247.tar.gz
  tar: Removing leading `/' from member names
  /srv/site1/
  
  [backup@localhost srv]$ ./tp1_backup.sh /srv/site2
  Vous avez 2 sauvegarde
  Sauvegarge de site2 vers /srv/backup/site2_20200928_225250.tar.gz
  tar: Removing leading `/' from member names
  /srv/site2/
  ```

🌞 Utiliser la `crontab` pour que le script s'exécute automatiquement toutes les heures.

🌞 Prouver que vous êtes capables de restaurer un des sites dans une version antérieure, et fournir une marche à suivre pour restaurer une sauvegarde donnée.

**NB** : votre script

- doit s'exécuter sous l'identité d'un utilisateur dédié appelé `backup`
- ne doit comporter **AUCUNE** commande `sudo`
- doit posséder des permissions minimales à son bon fonctionnement

```shell
[backup@localhost srv]$ ll
total 12
drwxrwxr-x. 2 backup backup   78 Sep 28 22:52 backup
dr-xr-x---. 2 admin  admin  4096 Sep 28 21:05 site1
dr-xr-x---. 2 admin  admin  4096 Sep 28 21:05 site2
-rwxr-----. 1 backup backup  775 Sep 28 22:50 tp1_backup.sh
```

- doit utiliser des variables et des fonctions, **avec des noms explicites**

🐙 Créer une unité systemd qui permet de déclencher le script de backup

- c'est à dire, faire en sorte que votre script de backup soit déclenché lorsque l'on exécute `sudo systemctl start backup`

# III. Monitoring, alerting

🌞 Mettre en place l'outil Netdata en suivant [les instructions officielles](https://learn.netdata.cloud/docs/agent/packaging/installer) et s'assurer de son bon fonctionnement.

🌞 Configurer Netdata pour qu'ils vous envoient des alertes dans un salon Discord dédié

- c'est à dire que Netdata vous informera quand la RAM est pleine, ou le disque, ou autre, *via* Discord