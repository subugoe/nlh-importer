FROM vertx/vertx3



ENV VERTICLE_NAME start.rb
ENV VERTICLE_HOME /usr/verticles
ENV JRUBY_HOME /usr/share/jruby
ENV GEM_PATH=/usr/share/jruby/lib/ruby/gems/shared/gems
ENV PATH=$PATH:$JRUBY_HOME/bin


RUN apk update && \
    apk upgrade && \
#RUN apk add --update gem bundler vim && rm -rf /var/cache/apk/*
    apk add curl \
    # ruby ruby-dev ruby-io-console ruby-bundler ruby-json \
    libxml2 libxml2-dev libxml2-utils \
    libgcrypt-dev \
    libxslt libxslt-dev \
    vim gcc yaml yaml-dev build-base \
    libtool pcre-dev \
    ghostscript libpng libjpeg \
    imagemagick imagemagick-dev
    # libmagickwand-dev

RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories && \
    apk update && \
    apk add jruby jruby-irb jruby-minitest jruby-rdoc jruby-rake jruby-testunit

RUN jruby -S gem install --no-rdoc --no-ri bundler

#RUN mkdir -p $VERTICLE_HOME/lib

WORKDIR /

COPY Gemfile $VERTICLE_HOME/Gemfile
COPY Gemfile.lock $VERTICLE_HOME/Gemfile.lock
#COPY lib/*.jar $VERTICLE_HOME/lib/
#COPY start.rb $VERTICLE_HOME/start.rb

WORKDIR $VERTICLE_HOME

RUN jruby -S bundle install

WORKDIR $VERTICLE_HOME
ENTRYPOINT ["sh", "-c"]
CMD ["vertx run $VERTICLE_HOME/$VERTICLE_NAME"]
#CMD ["vertx run -cp $VERTICLE_HOME/lib/*  $VERTICLE_HOME/$VERTICLE_NAME"]
#CMD ["tail -f /bin/true"]



