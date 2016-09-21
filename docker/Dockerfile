FROM vertx/vertx3


RUN apk update && \
    apk upgrade && \
#RUN apk add --update gem bundler vim && rm -rf /var/cache/apk/*
    apk add curl ruby ruby-dev ruby-io-console ruby-bundler ruby-json \
        libxml2 libxml2-dev libxml2-utils \
        libgcrypt-dev \
        libxslt libxslt-dev \
        vim gcc yaml yaml-dev build-base


ENV VERTICLE_NAME start.rb
ENV VERTICLE_HOME /usr/verticles


ENV JAVA_OPTS "${JAVA_OPTS} -server -Xms512M -Xmx4096M"

COPY lib/*.jar $VERTICLE_HOME/lib/

COPY Gemfile /
WORKDIR /

RUN bundle install

WORKDIR $VERTICLE_HOME
ENTRYPOINT ["sh", "-c"]
#CMD ["vertx run $VERTICLE_NAME -cp $VERTICLE_HOME/lib/*"]
CMD ["tail -f /bin/true"]

