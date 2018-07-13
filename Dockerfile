# Adapted from
# https://github.com/kraih/mojo/wiki/Bundling-application-into-Docker-image
FROM alpine:3.4
MAINTAINER ade ishs

RUN mkdir -p /opt/wordfinder
COPY cpanfile wordfinder.pl wordfinder.conf \
    /opt/wordfinder/

WORKDIR /opt/wordfinder/

RUN apk update && \
  apk add perl perl-io-socket-ssl perl-dbd-pg perl-dev g++ make wget curl && \
  wget -O words https://raw.githubusercontent.com/eneko/data-repository/master/data/words.txt && \
  curl -L https://cpanmin.us | perl - App::cpanminus && \
  cpanm --installdeps . -M https://cpan.metacpan.org && \
  apk del perl-dev g++ make wget curl && \
  rm -rf /root/.cpanm/* /usr/local/share/man/*

EXPOSE 80

CMD ["morbo", "-l", "http://*:80/", "wordfinder.pl"]
