FROM registry.theopencloset.net/opencloset/node:latest as builder
MAINTAINER Hyungsuk Hong <aanoaa@gmail.com>

WORKDIR /build

# npm -> bower -> grunt 순서대로
COPY package.json package.json
RUN npm install

COPY .bowerrc .bowerrc
COPY bower.json bower.json
RUN bower --allow-root install

COPY public/assets/coffee/ public/assets/coffee
COPY public/assets/jst/ public/assets/jst/
COPY public/assets/less/ public/assets/less/
COPY Gruntfile.coffee Gruntfile.coffee
RUN grunt


# https://docs.docker.com/engine/userguide/eng-image/multistage-build/
FROM registry.theopencloset.net/opencloset/perl:latest

RUN groupadd opencloset && useradd -g opencloset opencloset

WORKDIR /tmp
COPY cpanfile cpanfile
RUN cpanm --notest \
    --mirror http://www.cpan.org \
    --mirror http://cpan.theopencloset.net \
    --installdeps .

# Everything up to cached.
WORKDIR /home/opencloset/service/volunteer.theopencloset.net
COPY --from=builder /build .
# explicit copy
COPY . .
RUN mkdir db
RUN chown -R opencloset:opencloset .
RUN mv volunteer.conf.sample volunteer.conf

USER opencloset
ENV MOJO_HOME=/home/opencloset/service/volunteer.theopencloset.net
ENV MOJO_CONFIG=volunteer.conf

ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["hypnotoad"]

EXPOSE 5000
