# FHEM Docker Base

## Contains

- FHEM + haus-automatisierung.com FHEM frontend style + Tablet UI + ABFALL Module
- MQTT configured
- mySQL-Logging

## Requirements

- Docker
- Docker-Compose

## Install

```
git clone https://github.com/Cooper81/fhem-docker.git fhem-docker
cd fhem-docker
docker-compose up -d
```

- FHEM: http://[ip]:8083/fhem
- Node-Red: http://[ip]:1880/

## Defaults

- FHEM-WEB: 8083 (8084 and 8085 have been deleted)
- mySQL-User: dennis
- mySQL-Password: fhem
