# TP3 : systemd

Le but ici c'est d'explorer un peu systemd.

systemd est un outil qui a été très largement adopté au sein des distributions GNU/Linux les plus répandues (Debian, RedHat, Arch, etc.). systemd occupe plusieurs fonctions :

- système d'init
- gestion de services
- embarque plusieurs applications très proche du noyau et nécessaires au bon fonctionnement du système
  - comme par exemple la gestion de la date et de l'heure, ou encore la gestion des périphériques
- PID 1

Ce TP3 a donc pour objectif d'explorer un peu ces différentes facettes. La finalité derrière tout ça est de vous faire un peu mieux appréhender comment marche un OS GNU/Linux ; mais aussi de façon plus générale vous faire mieux appréhender en quoi consiste l'application qu'on appelle "système d'exploitation" (car ui, c'est juste une application).

Au menu :

- manipulation des *unités systemd*, et en particulier les *services*
- analyse (succincte) du boot d'une machine GNU/Linux
- appréhension de certains des éléments embarqués avec systemd
  - tâche planifiées (alternative à cron)
  - gestion de l'heure
  - gestion des noms
- bonus frappe : on va réviser un peu la manipulation de la ligne de commande n_n
  - les lignes précédées d'un **|CLI|** font appel à vos talents sur la ligne de commande
  - en réponse à ces lignes, une seule ligne de commande est attendue

- [0. Prérequis](#0-prérequis)
- I. Services systemd
  - [1. Intro](#1-intro)
  - [2. Analyse d'un service](#2-analyse-dun-service)
  - \3. Création d'un service
    - [A. Serveur web](#a-serveur-web)
    - [B. Sauvegarde](#b-sauvegarde)
- II. Autres features
  - [1. Gestion d'interfaces](#1-gestion-dinterfaces)
  - [2. Gestion de boot](#2-gestion-de-boot)
  - [3. Gestion de l'heure](#3-gestion-de-lheure)
  - [4. Gestion des noms et de la résolution de noms](#4-gestion-des-noms-et-de-la-résolution-de-noms)
- [Structure du dépôt attendu](#structure-du-dépôt-attendu)

# 0. Prérequis

> De toute évidence, vous utiliserez désormais Vagrant systématiquement pour créer votre environnement de travail.

Une VM suffira pour le TP. Je vous conseille d'utiliser une box `centos/7` comme base, et de la repackager avec :

- une mise à jour complète du système (pas obligé si la connexion dont vous bénéficiez a deux de tension)
- NGINX installé
- d'autres trucs si vous le souhaitez (comme `vim` :D)

**HA** et on va se reservir du script de backup du [TP1]().

# I. Services systemd

## 1. Intro

Section d'intro aux services systemd. Ui c'est ces trucs qu'on lance avec des commandes `systemctl start` par exemple.

Pour voir une liste de tous les services actuellement disponibles sur la machine, on peut interroger systemd :

```shell
# Liste les services actifs
$ sudo systemctl -t service

# Liste les services et leur état au boot
$ sudo systemctl list-unit-files -t service

# Liste tous les services
$ sudo systemctl list-unit-files -t service -a
```

🌞 Utilisez la ligne de commande pour sortir les infos suivantes :

- **|CLI|** afficher le nombre de *services systemd* dispos sur la machine

```shell
[vagrant@b2 ~]$ systemctl list-unit-files --type=service --all | wc -l
160
```

- **|CLI|** afficher le nombre de *services systemd* actifs et en cours d'exécution *("running")* sur la machine

```shell
[vagrant@b2 ~]$ sudo systemctl -t service | grep 'running' | wc -l
18
```

- **|CLI|** afficher le nombre de *services systemd* qui ont échoué *("failed")* ou qui sont inactifs *("exited")* sur la machine

```shell
[vagrant@b2 ~]$ sudo systemctl list-units -t service | grep -E 'failed|exited' | wc -l
18
```

- **|CLI|** afficher la liste des *services systemd* qui démarrent automatiquement au boot *("enabled")*

```shell
[vagrant@b2 ~]$ systemctl list-unit-files -t service | grep 'enabled'
auditd.service                                enabled
autovt@.service                               enabled
chronyd.service                               enabled
crond.service                                 enabled
dbus-org.fedoraproject.FirewallD1.service     enabled
dbus-org.freedesktop.nm-dispatcher.service    enabled
firewalld.service                             enabled
getty@.service                                enabled
irqbalance.service                            enabled
NetworkManager-dispatcher.service             enabled
NetworkManager-wait-online.service            enabled
NetworkManager.service                        enabled
postfix.service                               enabled
qemu-guest-agent.service                      enabled
rhel-autorelabel-mark.service                 enabled
rhel-autorelabel.service                      enabled
rhel-configure.service                        enabled
rhel-dmesg.service                            enabled
rhel-domainname.service                       enabled
rhel-import-state.service                     enabled
rhel-loadmodules.service                      enabled
rhel-readonly.service                         enabled
rpcbind.service                               enabled
rsyslog.service                               enabled
sshd.service                                  enabled
systemd-readahead-collect.service             enabled
systemd-readahead-drop.service                enabled
systemd-readahead-replay.service              enabled
tuned.service                                 enabled
vboxadd-service.service                       enabled
vboxadd.service                               enabled
vgauthd.service                               enabled
vmtoolsd-init.service                         enabled
vmtoolsd.service                              enabled
```

------

**Okay mais un service c'est quoi ?**

Un service c'est juste un truc pratique pour lancer des processus ou des tâches simplement. Par "simplement", ça veut dire qu'une fois qu'on utilise une gestion de service, commes les *services systemd*, on a plus besoin de (entre autres) :

- connaître par coeur la commande pour lancer un truc
- connaître par coeur quelles applications doivent se lancer dans quel ordre pour que tout fonctionne
- gérer à la main l'environnement pour lancer une application
  - l'utilisateur qui lance l'app
  - les droits qu'a l'application
  - etc.
- écrire des scripts shell inmaintenables pour maintenir tout ça n_n

**Donc concrètement, un service ça permet de lancer un processus ET gérer son environnement.**

## 2. Analyse d'un service

Pour voir le contenu d'un service existant :

```
# Affiche le path du fichier qui définit un service donné
$ systemctl status <SERVICE>

# Affiche le contenu de l'unité directement
$ systemctl cat <SERVICE>
```

**La ligne la plus importante est celle qui commence par `ExecStart=` :** c'est elle qui indique le binaire à exécuter quand le service est démarré (c'est à dire la commande à lancer pour que le service soit considéré comme "actif").

🌞 Etudiez le service `nginx.service`

- déterminer le path de l'unité `nginx.service`

```shell
[vagrant@b2 ~]$ systemctl status nginx.service
● nginx.service - The nginx HTTP and reverse proxy server
   Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; vendor preset: disabled)
   Active: inactive (dead)
# ----------------------------------------------------------------
[vagrant@b2 ~]$ systemctl show -p FragmentPath nginx.service
FragmentPath=/usr/lib/systemd/system/nginx.service
```

- afficher son contenu et expliquer les lignes qui comportent :

  - `ExecStart`

  ```shell
  [vagrant@b2 ~]$ systemctl cat nginx.service | grep 'ExecStart='
  ExecStart=/usr/sbin/nginx
  ```

  - `ExecStartPre`

  ```shell
  [vagrant@b2 ~]$ systemctl cat nginx.service | grep 'ExecStartPre'
  ExecStartPre=/usr/bin/rm -f /run/nginx.pid
  ExecStartPre=/usr/sbin/nginx -t
  ```

  - `PIDFile`

  ```shell
  [vagrant@b2 ~]$ systemctl cat nginx.service | grep 'PIDFile'
  PIDFile=/run/nginx.pid
  ```

  - `Type`

  ```shell
  [vagrant@b2 ~]$ systemctl cat nginx.service | grep 'Type'
  Type=forking
  ```

  - `ExecReload`

  ```shell
  [vagrant@b2 ~]$ systemctl cat nginx.service | grep 'ExecReload'
  ExecReload=/bin/kill -s HUP $MAINPID
  ```

  - `Description`

  ```shell
  [vagrant@b2 ~]$ systemctl cat nginx.service | grep 'Description'
  Description=The nginx HTTP and reverse proxy server
  ```

  - `After`

  ```shell
  [vagrant@b2 ~]$ systemctl cat nginx.service | grep 'After'
  After=network.target remote-fs.target nss-lookup.target
  ```

> Les mans de systemd sont très complets : `man systemd.unit` et `man systemd.service` par exemple. Une recherche ggl ça marche aussi, la meilleure doc étant [la doc officielle](https://www.freedesktop.org/software/systemd/man/systemd.service.html) (PS : c'est la même chose que dans le `man` n_n)

🌞 **|CLI|** Listez tous les services qui contiennent la ligne `WantedBy=multi-user.target`

```shell

```

## 3. Création d'un service

Pour créer un service, il suffit de créer un fichier au bon endroit, avec une syntaxe particulière.

L'endroit qui est dédié à la création de services par l'administrateur est `/etc/systemd/system/`. Les services système (installés par des paquets par exemple) se place dans d'autres dossiers.

Une fois qu'un service a été ajouté, il est nécessaire de demander à systemd de relire tous les fichiers afin qu'il découvre le vôtre :

```
$ sudo systemctl daemon-reload
```

### A. Serveur web

🌞 Créez une unité de service qui lance un serveur web

- la commande pour lancer le serveur web est `python3 -m http.server <PORT>`
- quand le service se lance, le port doit s'ouvrir juste avant dans le firewall
- quand le service se termine, le port doit se fermer juste après dans le firewall
- un utilisateur dédié doit lancer le service
- le service doit comporter une description
- le port utilisé doit être défini dans une variable d'environnement (avec la clause `Environment=`)

```shell
[vagrant@b2 system]$ cat nginx.service
[Unit]
Description=The NGINX HTTP and reverse proxy servert

[Service]
Type=simple
Environment="PORT=1050"

ExecStartPre=/usr/bin/sudo /usr/bin/firewall-cmd --add-port=${PORT}/tcp --permanent
ExecStartPre=/usr/bin/sudo /usr/bin/firewall-cmd --reload
ExecStart=/usr/bin/python2 -m SimpleHTTPServer 1050
ExecStartPost=/usr/bin/sudo /usr/bin/firewall-cmd --remove-port=${PORT}/tcp --permanent
ExecStartPost=/usr/bin/sudo /usr/bin/firewall-cmd --reload

User=web
Group=web

[Install]
WantedBy=multi-user.target
```

🌞 Lancer le service

- prouver qu'il est en cours de fonctionnement pour systemd

```shell
[web@b2 vagrant]$ sudo systemctl start nginx.service
[web@b2 vagrant]$ systemctl status nginx.service
● nginx.service - The NGINX HTTP and reverse proxy servert
   Loaded: loaded (/etc/systemd/system/nginx.service; disabled; vendor preset: disabled)
   Active: active (running) since Wed 2020-10-07 12:48:06 UTC; 6s ago
  Process: 3799 ExecStartPost=/usr/bin/sudo /usr/bin/firewall-cmd --reload (code=exited, status=0/SUCCESS)
  Process: 3793 ExecStartPost=/usr/bin/sudo /usr/bin/firewall-cmd --remove-port=${PORT}/tcp --permanent (code=exited, status=0/SUCCESS)
  Process: 3760 ExecStartPre=/usr/bin/sudo /usr/bin/firewall-cmd --reload (code=exited, status=0/SUCCESS)
  Process: 3755 ExecStartPre=/usr/bin/sudo /usr/bin/firewall-cmd --add-port=${PORT}/tcp --permanent (code=exited, status=0/SUCCESS)
 Main PID: 3792 (python2)
   CGroup: /system.slice/nginx.service
           └─3792 /usr/bin/python2 -m SimpleHTTPServer 1050
```

- faites en sorte que le service s'allume au démarrage de la machine

```shell
[web@b2 vagrant]$ sudo systemctl enable nginx.service
Created symlink from /etc/systemd/system/multi-user.target.wants/nginx.service to /etc/systemd/system/nginx.service.
```

- prouver que le serveur web est bien fonctionnel

```shell
[web@b2 vagrant]$ systemctl status nginx.service
● nginx.service - The NGINX HTTP and reverse proxy servert
   Loaded: loaded (/etc/systemd/system/nginx.service; enabled; vendor preset: disabled)
   Active: active (running) since Wed 2020-10-07 12:48:06 UTC; 23s ago
 Main PID: 3792 (python2)
   CGroup: /system.slice/nginx.service
           └─3792 /usr/bin/python2 -m SimpleHTTPServer 1050
```

> N'oubliez pas de tester votre service : le lancer avec `systemctl start <SERVICE>` et vérifier que votre serveur web fonctionne avec un navigateur ou un `curl` par exemple.

### B. Sauvegarde

Ici on va réutiliser votre script de sauvegarde du [TP1]() que vous avez *bien évidemment* gardé.

🌞 Créez une unité de service qui déclenche une sauvegarde avec votre script

- le script doit se lancer sous l'identité d'un utilisateur dédié
- le service doit utiliser un PID file
- le service doit posséder une description
- vous éclaterez votre script en trois scripts :
  - un script qui se lance AVANT la sauvegarde, qui effectue les tests
  - script de sauvegarde
  - un script qui s'exécute APRES la sauvegarde, et qui effectue la rotation (ne garder que les 7 sauvegardes les plus récentes)
  - une fois fait, utilisez les clauses `ExecStartPre`, `ExecStart` et `ExecStartPost` pour les lancer au bon moment

🐙 Améliorer la sécurité du service de sauvegarde

```
# Commande permettant de mettre en évidence des faiblesses de sécurité au sein d'un service donné
$ systemd-analyze security <SERVICE>
```

- **NB** : la version de systemd livré avec CentOS 7 est trop vieille pour cette feature, il vous CentOS 8 (ou un autre OS)
- mettre en place des mesures de sécurité pour avoir un score inférieur à 7

- # II. Autres features

  **Pour cette section, il sera nécessaire d'utiliser une version plus récente de systemd**. Vous devrez donc changer de box Vagrant, et utiliser une box possédant une version plus récente (par exemple une box CentOS8 ou une box Fedora récente).

  ------

  ## 1. Gestion de boot

  🌞 Utilisez `systemd-analyze plot` pour récupérer une diagramme du boot, au format SVG

  - il est possible de rediriger l'output de cette commande pour créer un fichier 

    ```
    .svg
    ```

    - un `.svg` ça peut se lire avec un navigateur

    ```shell
    [vagrant@centos8 ~]$ systemd-analyze plot >  analyze.svg
    [vagrant@centos8 ~]$ ls
    analyze.svg
    ```

  - déterminer les 3 **services** les plus lents à démarrer

  ```shell
  [vagrant@centos8 ~]$ systemd-analyze blame
           14.659s vboxadd.service
            3.288s dnf-makecache.service
            2.118s dracut-initqueue.service
  # [. . .]
  ```

  ## 2. Gestion de l'heure

  🌞 Utilisez la commande `timedatectl`

  - déterminer votre fuseau horaire

  ```shell
  [vagrant@centos8 ~]$ timedatectl status | grep "Time zone"
                  Time zone: Europe/Paris (CEST, +0200)
  ```

  - déterminer si vous êtes synchronisés avec un serveur NTP

  ```shell
  [vagrant@centos8 ~]$ timedatectl status | grep NTP
                NTP service: active
  ```

  - changer le fuseau horaire

    ```shell
    [vagrant@centos8 ~]$ sudo timedatectl set-timezone Europe/Paris
    [vagrant@centos8 ~]$ timedatectl
                   Local time: Fri 2020-10-09 13:51:17 CEST
               Universal time: Fri 2020-10-09 11:51:17 UTC
                     RTC time: Fri 2020-10-09 13:51:17
                    Time zone: Europe/Paris (CEST, +0200)
    System clock synchronized: no
                  NTP service: active
              RTC in local TZ: yes
    ```

  ## 3. Gestion des noms et de la résolution de noms

  🌞 Utilisez `hostnamectl`

  - déterminer votre hostname actuel

    ```shell
    [vagrant@centos8 ~]$ hostnamectl status | grep hostname
       Static hostname: centos8.localdomain
    ```

  - changer votre hostname

  ```shell
  [vagrant@centos8 ~]$ sudo hostnamectl set-hostname b2-tp3-centos8 --static
  [vagrant@centos8 ~]$ hostnamectl status | grep hostname
     Static hostname: b2-tp3-centos8
  ```

  # 