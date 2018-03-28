FROM ruby:2.5-alpine

ENV BUNDLER_VERSION="1.16.1"

RUN apk update && \
	apk add \
		postgresql \
		postgresql-libs \
		tzdata \
		&& \
	apk add \
		git \
		gcc \
		g++ \
		make \
		linux-headers \
		postgresql-dev

# DB setup
RUN adduser -D -h /home/postgresql postgresql
RUN mkdir -p /run/postgresql && \
	chown -R postgresql:postgresql /run/postgresql
USER postgresql
RUN mkdir /home/postgresql/db && \
	initdb /home/postgresql/db

USER root
RUN mkdir /app
RUN gem install bundler --version "${BUNDLER_VERSION}"

WORKDIR /app
COPY . /app
RUN bundle install --jobs 8 --retry 3 --with docker

RUN apk add git \
	gcc \
	g++ \
	make \
	linux-headers \
	postgresql-dev

CMD ["/app/docker-start.sh"]
