FROM pihole/pihole:latest
RUN curl -sSLN https://github.com/ipitio/pi-hole/raw/ipitio/advanced/Scripts/speedtestmod/mod.sh | sudo bash
