FROM vertx/vertx3



ENV VERTICLE_NAME start.rb
ENV VERTICLE_HOME /usr/verticles
ENV JRUBY_HOME /usr/share/jruby
ENV GEM_PATH=/usr/share/jruby/lib/ruby/gems/shared/gems
ENV PATH=$PATH:$JRUBY_HOME/bin


#ENV JAVA_OPTS "${JAVA_OPTS} -server -Xms512M -Xmx4096M"
ENV JAVA_OPTS "${JAVA_OPTS} -Xms512M -Xmx1G"
ENV JRUBY_OPTS "${JRUBY_OPTS} -J-Xms512M -J-Xmx1G"
ENV JVM_ARGS "-Xms512M -Xmx1G"

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

#RUN curl http://www.imagemagick.org/download/ImageMagick.tar.gz > install.tar && \
#    tar xvzf install.tar && \
#    cd ImageMagick-7.0.3-1 && \
#    ./configure && \
#    make && \
#    make install  && \
#    ldconfig /usr/local/lib


#jruby -S gem install rmagick4j
#jruby -S gem install image_magick
#jruby -S gem install mini_magick
#jruby -S gem install fileutils
#jruby -S gem install quick_magick    # no tiff support

#RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories && \
#    apk update && \
#    jruby -S gem install  json redis rsolr elasticsearch logger \
#    mini_magick \
#    oai nokogiri orchard
#    # fileutils image_magick rmagick json_pure

RUN jruby -S gem install --no-rdoc --no-ri bundler


RUN mkdir -p $VERTICLE_HOME/lib

WORKDIR /

COPY Gemfile $VERTICLE_HOME/Gemfile
COPY Gemfile.lock $VERTICLE_HOME/Gemfile.lock
COPY lib/*.jar $VERTICLE_HOME/lib/
COPY start.rb $VERTICLE_HOME/start.rb

WORKDIR $VERTICLE_HOME


RUN jruby -S bundle install

WORKDIR $VERTICLE_HOME
ENTRYPOINT ["sh", "-c"]
CMD ["vertx run -cp $VERTICLE_HOME/lib/*  $VERTICLE_NAME"]
#CMD ["tail -f /bin/true"]



