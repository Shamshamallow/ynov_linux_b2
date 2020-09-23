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

# 0. Prérequis

> **POUR RAPPEL** pour chacune des opérations, vous devez fournir dans le compte-rendu : comment réaliser l'opération ET la preuve que l'opération a été bien réalisée

🌞 **Setup de deux machines CentOS7 configurée de façon basique.**

- partitionnement

  - ajouter un deuxième disque de 5Go à la machine
  - partitionner le nouveau disque avec LVM
    - deux partitions, une de 2Go, une de 3Go
    - la partition de 2Go sera montée sur `/srv/data1`
    - la partition de 3Go sera montée sur `/srv/data2`
  - les partitions doivent être montées automatiquement au démarrage

- un accès internet

  - carte réseau dédiée
  - route par défaut

- un accès à un réseau local (les deux machines peuvent se 

  ```
  ping
  ```

  )

  - carte réseau dédiée
  - route locale

- les machines doivent avoir un nom

  - `/etc/hostname`
  - commande `hostname`)

- les machines doivent pouvoir se joindre par leurs noms respectifs

  - fichier `/etc/hosts`

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
  - modification de la conf sudo

- vous n'utilisez QUE 

  ```
  ssh
  ```

   pour administrer les machines

  - création d'une paire de clés (sur VOTRE PC)
  - déposer la clé publique sur l'utilisateur de destination

- le pare-feu est configuré pour bloquer toutes les connexions exceptées celles qui sont nécessaires

  - commande `firewall-cmd` ou `iptables`

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

🌞 Prouver que la machine `node2` peut joindre les deux sites web.

# II. Script de sauvegarde

**Yup. Again.**

🌞 Ecrire un script qui :

- s'appelle `tp1_backup.sh`
- sauvegarde les deux sites web
  - c'est à dire qu'il crée une archive compressée pour chacun des sites
  - je vous conseille d'utiliser le format `tar` pour l'archivage et `gzip` pour la compression
- les noms des archives doivent contenir le nom du site sauvegardé ainsi que la date et heure de la sauvegarde
  - par exemple `site1_20200923_2358` (pour le 23 Septembre 2020 à 23h58)
- vous ne devez garder que 7 exemplaires sauvegardes
  - à la huitième sauvegarde réalisée, la plus ancienne est supprimée
- le script ne sauvegarde qu'un dossier à la fois, le chemin vers ce dossier est passé en argument du script
  - on peut donc appeler le script en faisant `tp1_backup.sh /srv/site1` afin de déclencher une sauvegarde de `/srv/site1`

🌞 Utiliser la `crontab` pour que le script s'exécute automatiquement toutes les heures.

🌞 Prouver que vous êtes capables de restaurer un des sites dans une version antérieure, et fournir une marche à suivre pour restaurer une sauvegarde donnée.

**NB** : votre script

- doit s'exécuter sous l'identité d'un utilisateur dédié appelé `backup`
- ne doit comporter **AUCUNE** commande `sudo`
- doit posséder des permissions minimales à son bon fonctionnement
- doit utiliser des variables et des fonctions, **avec des noms explicites**

🐙 Créer une unité systemd qui permet de déclencher le script de backup

- c'est à dire, faire en sorte que votre script de backup soit déclenché lorsque l'on exécute `sudo systemctl start backup`

# III. Monitoring, alerting

🌞 Mettre en place l'outil Netdata en suivant [les instructions officielles](https://learn.netdata.cloud/docs/agent/packaging/installer) et s'assurer de son bon fonctionnement.

🌞 Configurer Netdata pour qu'ils vous envoient des alertes dans un salon Discord dédié

- c'est à dire que Netdata vous informera quand la RAM est pleine, ou le disque, ou autre, *via* Discord