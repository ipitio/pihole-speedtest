FROM pihole/pihole:latest
RUN curl -sSLN https://github.com/ipitio/pihole-speedtest/raw/ipitio/mod | sudo bash -s -- -s
