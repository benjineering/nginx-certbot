# NGINX Certbot

## Dockerised NGINX + Certbot + a Zig program to handle creating and renewing SSL certs.

‼️Disclaimer‼️: super noob first attempt at Zig.

### Zig program behaviour

- for each domain:
  - ensure we have both a live and a provisioning NGINX config
  - check if a cert has been issued. If not:
    - disable the live config and enable the provisioning config
    - start nginx
    - create a cert with certbot
    - enable the live config
    - restart nginx
  - else:
    - renew cert
- send a notification
