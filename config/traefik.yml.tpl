api:
  dashboard: true
  insecure: true

entryPoints:
  web:
    address: ':80'
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ':443'

certificatesResolvers:
  letsencrypt:
    acme:
      email: admin@${vars.domain_name}
      storage: /letsencrypt/acme.json
      httpChallenge:
        entryPoint: web

providers:
  docker:
    endpoint: 'unix:///var/run/docker.sock'
    exposedByDefault: false
    network: traefik-network

