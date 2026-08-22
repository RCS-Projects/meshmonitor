# MeshMonitor development workflow

This repository is the standalone project at
`github.com/renfrewcountyscanner/meshmonitor`.

## Local source image

Use the existing development Compose configuration for source builds:

```sh
cp .env.example .env
docker compose -f docker-compose.dev.yml build
docker compose -f docker-compose.dev.yml up -d
```

The existing Raspberry Pi configuration remains available in
`docker-compose.rpi.yml`. Production data is stored in a dedicated Docker
volume and must be backed up before replacing the current MeshMonitor
container.

## Remotes

- `origin`: `https://github.com/renfrewcountyscanner/meshmonitor.git`
- `upstream`: `https://github.com/Yeraze/meshmonitor.git`

Meshtastic and MeshMonitor are intentionally separate projects. Changes to
one must not require copying source files into the other.
