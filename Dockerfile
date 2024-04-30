FROM pihole/pihole:latest
RUN curl -sSLN https://github.com/ipitio/pihole-speedtest/ipitio/mod | sudo bash
