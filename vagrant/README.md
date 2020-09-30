# TP2 : Déploiement automatisé

Le but de ce TP est d'effectuer le même déploiement que lors du [TP1]() mais en automatisant le déploiement de la machine virtuelle, sa configuration basique, ainsi que l'install et la conf des services.

Au menu :

- réutilisation du [TP1]()
- utilisation de [Vagrant](https://www.vagrantup.com/)
- premiers pas dans l'automatisation

- \0. Prérequis
  - [Install Vagrant](#install-vagrant)
  - [Init Vagrant](#init-vagrant)
- [I. Déploiement simple](#i-déploiement-simple)
- [II. Re-package](#ii-re-package)
- [III. Multi-node deployment](#iii-multi-node-deployment)
- [IV. Automation here we (slowly) come](#iv-automation-here-we-slowly-come)

# 0. Prérequis

## Install Vagrant

Téléchargez [Vagrant](https://www.vagrantup.com/) depuis le site officiel. Une fois téléchargé, assurez-vous que vous avez la commande `vagrant` dans votre terminal.

Vous aurez aussi besoin de VirtualBox. **Je n'apporterai aucun support si vous utilisez un autre hyperviseur.**

Vagrant est un outil qui sert de surcouche à un hyperviseur ; dans notre cas, il pilotera VirtualBox.

Le fonctionnement de Vagrant est simple :

- on décrit une ou plusieurs VM(s) dans un fichier appelé `Vagrantfile`
- on demande à Vagrant d'allumer la ou les VM(s)

La description des VMs se fait dans un langage spécifique, dérivé de Ruby.

## Init Vagrant

```shell
# Créez vous un répertoire de travail
$ mkdir vagrant
$ cd vagrant

# Initialisez un Vagrantfile
$ vagrant init centos/7
A `Vagrantfile` has been placed in this directory. You are now
ready to `vagrant up` your first virtual environment! Please read
the comments in the Vagrantfile as well as documentation on
`vagrantup.com` for more information on using Vagrant.
```

> Je vous invite à **lire** le fichier Vagrantfile qui a été généré automatiquement pour voir une partie de ce que Vagrant est capable de réaliser.

Une fois le Vagrantfile généré, épurez-le en enlevant les commentaires, et ajoutez des lignes afin qu'il ressemble à ça :

```shell
Vagrant.configure("2")do|config|
  config.vm.box="centos/7"

  ## Les 3 lignes suivantes permettent d'éviter certains bugs et/ou d'accélérer le déploiement. Gardez-les tout le temps sauf contre-indications.
  # Ajoutez cette ligne afin d'accélérer le démarrage de la VM (si une erreur 'vbguest' est levée, voir la note un peu plus bas)
  config.vbguest.auto_update = false
  # Désactive les updates auto qui peuvent ralentir le lancement de la machine
  config.vm.box_check_update = false 
  # La ligne suivante permet de désactiver le montage d'un dossier partagé (ne marche pas tout le temps directement suivant vos OS, versions d'OS, etc.)
  config.vm.synced_folder ".", "/vagrant", disabled: true
end
```

> Si vous avez l'erreur `Unknown configuration section 'vbguest'`, lancez la commande `vagrant plugin install vagrant-vbguest` AVANT le `vagrant up`.

Test du bon fonctionnement :

```powershell
# Toujours dans le dossier où a été généré le Vagrantfile
$ vagrant up
[...]

# Voir l'état de la machine
$ vagrant status
# Vous pouvez aussi jeter un oeil dans votre VirtualBox : une VM devrait avoir pop

# Se connecter à la machine
$ vagrant ssh

# Détruire la VM et les fichiers associés
$ vagrant destroy -f
```

# I. Déploiement simple

🌞 Créer un `Vagrantfile` qui :

- utilise la box `centos/7`

```powershell
➜  vm_2 git:(master) ✗ vagrant init centos/7
A `Vagrantfile` has been placed in this directory. You are now
ready to `vagrant up` your first virtual environment! Please read
the comments in the Vagrantfile as well as documentation on
`vagrantup.com` for more information on using Vagrant.
```

- crée une seule VM
  - 1Go RAM
  - ajout d'une IP statique `192.168.2.11/24`
  - définition d'un nom (interne à Vagrant)
  - définition d'un hostname

🌞 Modifier le `Vagrantfile`

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  config.vm.box = "b2-tp2-centos"

   # adding a second disk
  CONTROL_NODE_DISK='./disk2.vdi'

  config.vbguest.auto_update = false
  config.vm.box_check_update = false
  config.vm.synced_folder ".", "/vagrant", disabled: true

  config.vm.define "vm1" do |vm1|
     vm1.vm.provider "virtualbox" do |vb|
        vb.memory = "1024"
        vb.name = "b2_tp2_patron"
        unless File.exist?(CONTROL_NODE_DISK)
          vb.customize ['createhd', '--filename', CONTROL_NODE_DISK, '--variant', 'Fixed', '--size', 5 * 1024]
         end
         # Attache le disque à la VM
        vb.customize ['storageattach', :id,  '--storagectl', 'IDE', '--port', 1, '--device', 0, '--type', 'hdd', '--medium', CONTROL_NODE_DISK]
    end
    vm1.vm.network "private_network", ip: "192.168.2.11"
    vm1.vm.hostname = "tp2.vagrant"
  end

   config.vm.provision "shell", inline: <<-SHELL
    yum update -y
   SHELL
end
```

- la machine exécute un script shell au démarrage qui install le paquet `vim`
- ajout d'un deuxième disque de 5Go à la VM

```powershell
[vagrant@tp2 ~]$ lsblk
NAME   MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
sda      8:0    0  40G  0 disk
`-sda1   8:1    0  40G  0 part /
sdb      8:16   0   5G  0 disk
```

Pour exécuter un script shell au démarrage, la syntaxe recommandée est :

```powershell
# Exécution d'un script au démarrage de la VM
config.vm.provision "shell", path: "script.sh"
```

# II. Re-package

Il est possible de packager soi-même une *box* Vagrant afin d'avoir une VM sur-mesure dès qu'elle s'allume.

On peut la créer depuis le fichier `.iso` correspondant à l'image officielle d'un OS donné.
 Il est aussi possible de la générer à partir d'une *box* existante, c'est ce que nous allons faire ici.

La démarche est la suivante :

- on allume une VM de base
- à l'intérieur de la VM, on effectue les modifications souhaitées
  - création de fichiers
  - ajout de paquets
  - config système
  - etc.
- on exit la VM, en la gardant allumée
- utilisation d'une commande `vagrant` pour créer une nouvelle box à partir de la VM existante

En CLI, ça donne :

```
# Allumage de la  VM
$ vagrant up

# Connexion dans la VM + modifications souhaitées
$ vagrant ssh
[...]

# On se déconnecte de la VM, et on repackage
$ exit
$ vagrant package --output centos7-custom.box
$ vagrant box add centos7-custom centos7-custom.box
```

Repackager une box, **que vous appelerez `b2-tp2-centos`** en partant de la box `centos/7`, qui comprend :

- une mise à jour système
  - `yum update`
- l'installation de paquets additionels
  - `vim`
  - `epel-release`
  - `nginx`
- désactivation de SELinux

```powershell
[vagrant@tp1 ~]$ sudo setenforce 0
[vagrant@tp1 ~]$ cd /etc/selinux/
[vagrant@tp1 selinux]$ sudo vi config
[vagrant@tp1 selinux]$ cat config

# This file controls the state of SELinux on the system.
# SELINUX= can take one of these three values:
#     enforcing - SELinux security policy is enforced.
#     permissive - SELinux prints warnings instead of enforcing.
#     disabled - No SELinux policy is loaded.
SELINUX=permissive
# SELINUXTYPE= can take one of three values:
#     targeted - Targeted processes are protected,
#     minimum - Modification of targeted policy. Only selected processes are protected.
#     mls - Multi Level Security protection.
SELINUXTYPE=targeted
```

- firewall (avec 

  ```
  firewalld
  ```

  , en utilisant la commande 

  ```
  firewall-cmd
  ```

  )

  ```powershell
  [vagrant@tp1 selinux]$ sudo systemctl start firewalld
  [vagrant@tp1 selinux]$ sudo systemctl enable firewalld
  Created symlink from /etc/systemd/system/dbus-org.fedoraproject.FirewallD1.service to /usr/lib/systemd/system/firewalld.service.
  Created symlink from /etc/systemd/system/multi-user.target.wants/firewalld.service to /usr/lib/systemd/system/firewalld.service.
  ```

  - activé au boot de la VM

  ```powershell
  [vagrant@tp1 selinux]$ sudo firewall-cmd --add-port=22/tcp --permanent
  success
  [vagrant@tp1 selinux]$ sudo firewall-cmd --reload
  success
  [vagrant@tp1 selinux]$ sudo firewall-cmd --list-all
  public (active)
    target: default
    icmp-block-inversion: no
    interfaces: eth0 eth1
    sources:
    services: dhcpv6-client ssh
    ports: 22/tcp
    protocols:
    masquerade: no
    forward-ports:
    source-ports:
    icmp-blocks:
    rich rules:
  ```

  - ne laisse passser que le strict nécessaire (SSH)

  ```powershell
  ➜  vm_2 git:(master) ✗ vagrant package --output centos7-custom.box
  ==> default: Attempting graceful shutdown of VM...
  ==> default: Clearing any previously set forwarded ports...
  ==> default: Exporting VM...
  ==> default: Compressing package to: /Users/marie/Documents/ynov_2020_2021/ynov_linux_b2/vagrant/vm_2/centos7-custom.box
  ➜  vm_2 git:(master) ✗ vagrant box add centos7-custom centos7-custom.box
  ==> box: Box file was not detected as metadata. Adding it directly...
  ==> box: Adding box 'centos7-custom' (v0) for provider:
      box: Unpacking necessary files from: file:///Users/marie/Documents/ynov_2020_2021/ynov_linux_b2/vagrant/vm_2/centos7-custom.box
  ==> box: Successfully added box 'centos7-custom' (v0) for 'virtualbox'!
  ```

# III. Multi-node deployment

Il est possible de déployer et gérer plusieurs VMs en un seul `Vagrantfile`.

Exemple :

```
Vagrant.configure("2") do |config|
  # Configuration commune à toutes les machines
  config.vm.box = "centos/7"

  # Config une première VM "node1"
  config.vm.define "node1" do |node1|
    # remarquez l'utilisation de 'node1.' défini sur la ligne au dessus
    node1.vm.network "private_network", ip: "192.168.56.11"
  end

  # Config une première VM "node2"
  config.vm.define "node2" do |node2|
    # remarquez l'utilisation de 'node2.' défini sur la ligne au dessus
    node2.vm.network "private_network", ip: "192.168.56.12"
  end
end
```

🌞 Créer un `Vagrantfile` qui lance deux machines virtuelles, **les VMs DOIVENT utiliser votre box repackagée comme base** :

| x           | `node1.tp2.b2` | `node2.tp2.b2` |
| ----------- | -------------- | -------------- |
| IP locale   | `192.168.2.21` | `192.168.2.22` |
| Hostname    | `node1.tp2.b2` | `node1.tp2.b2` |
| Nom Vagrant | `node1`        | `node2`        |
| RAM         | 1Go            | 512Mo          |

```ruby
➜  vm_2 git:(master) ✗ cat Vagrantfile
# -*- mode: ruby -*-
# vi: set ft=ruby :
#
Vagrant.configure("2") do |config|
  # https://docs.vagrantup.com.
  # boxes at https://vagrantcloud.com/search.

  config.vm.box = "b2-tp2-centos"

   # adding a second disk
  CONTROL_NODE_DISK='./disk2.vdi'

  config.vbguest.auto_update = false
  config.vm.box_check_update = false
  config.vm.synced_folder ".", "/vagrant", disabled: true


  config.vm.define "node1" do |nd1|
     nd1.vm.provider "virtualbox" do |nd|
        nd.memory = "1024"
        nd.name = "node1"
        unless File.exist?(CONTROL_NODE_DISK)
          nd.customize ['createhd', '--filename', CONTROL_NODE_DISK, '--variant', 'Fixed', '--size', 5 * 1024]
         end
         # Attache le disque à la VM
        nd.customize ['storageattach', :id,  '--storagectl', 'IDE', '--port', 1, '--device', 0, '--type', 'hdd', '--medium', CONTROL_NODE_DISK]
    end
    nd1.vm.network "private_network", ip: "192.168.2.21"
    nd1.vm.hostname = "node1.tp2.b2"
  end

  config.vm.define "node2" do |nd2|
     nd2.vm.provider "virtualbox" do |nd|
        nd.memory = "512"
        nd.name = "node2"
    end
    nd2.vm.network "private_network", ip: "192.168.2.22"
    nd2.vm.hostname = "node2.tp2.b2"
  end

  # Exécution d'un script au démarrage de la VM
  config.vm.provision "shell", path: "script.sh"
end
```

# IV. Automation here we (slowly) come

Cette dernière étape vise à automatiser la résolution du TP1 à l'aide de Vagrant et d'un peu de scripting.

**Le but :**

- remettre en place le TP1

  - une VM serveur Web
  - une VM cliente

- les confs doivent être identiques au TP1

  - sauf pour le partitionnement, je vous l'épargne
  - TOUT le reste doit y figurer
  - les actions seront réalisées à l'aide d'un script qui se lance au démarrage de la VM

- en plus

  , le client doit trust le certificat du serveur

  - c'est à dire que vous n'avez pas besoin d'ajouter le `-k`  à `curl` pour que vos requêtes HTTPS passent

🌞 Créer un `Vagrantfile` qui automatise la résolution du TP1

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :
#
Vagrant.configure("2") do |config|
  # https://docs.vagrantup.com.
  # boxes at https://vagrantcloud.com/search.
 
  config.vm.box = "b2-tp2-centos"
  
   # adding a second disk
  CONTROL_NODE_DISK='./disk2.vdi'

  config.vbguest.auto_update = true
  config.vm.box_check_update = false
  config.vm.synced_folder ".", "/vagrant", disabled: true
  
  
  config.vm.define "node1" do |nd1|
     nd1.vm.provider "virtualbox" do |nd|
        nd.memory = "1024"
        nd.name = "node1"
        unless File.exist?(CONTROL_NODE_DISK)
          nd.customize ['createhd', '--filename', CONTROL_NODE_DISK, '--variant', 'Fixed', '--size', 5 * 1024]
         end
         # Attache le disque à la VM
        nd.customize ['storageattach', :id,  '--storagectl', 'IDE', '--port', 1, '--device', 0, '--type', 'hdd', '--medium', CONTROL_NODE_DISK]
    end
    nd1.vm.network "private_network", ip: "192.168.2.21"
    nd1.vm.hostname = "node1.tp2.b2"
    nd1.vm.provision "file", source: "./nginx.conf", destination: "/tmp/nginx.conf"
    nd1.vm.provision "file", source: "./server.crt", destination: "/tmp/server.crt"
    nd1.vm.provision "file", source: "./server.key", destination: "/tmp/server.key"
     # Exécution d'un script au démarrage de la VM
    nd1.vm.provision "shell", path: "script1.sh"
  end 

  config.vm.define "node2" do |nd2|
     nd2.vm.provider "virtualbox" do |nd|
        nd.memory = "512"
        nd.name = "node2"
    end
    nd2.vm.network "private_network", ip: "192.168.2.22"
    nd2.vm.hostname = "node2.tp2.b2"
    nd2.vm.provision "file", source: "./server.crt", destination: "/tmp/server.crt"
    nd2.vm.provision "shell", path: "script3.sh"
  end
  
  # Exécution d'un script au démarrage de la VM
  config.vm.provision "shell", path: "script2.sh"
end

```

- je vais aussi créer la box `b2-tp2-centos` sur ma machine
- si tout se passe bien, pour tester que tout est fonctionnel, j'ai juste besoin de :

```
$ vagrant up
$ vagrant ssh node2
$ curl https://node1.tp2.b2
```