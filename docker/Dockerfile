FROM vertx/vertx3



ENV VERTICLE_NAME start.rb
ENV VERTICLE_HOME /usr/verticles
ENV JRUBY_HOME /usr/share/jruby
ENV GEM_PATH=/usr/share/jruby/lib/ruby/gems/shared/gems
ENV PATH=$PATH:$JRUBY_HOME/bin

RUN echo "ipv6" >> /etc/modules

RUN echo "http://dl-cdn.alpinelinux.org/alpine/v3.3/main" >> /etc/apk/repositories
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories


RUN apk update && \
    apk add jruby jruby-irb jruby-minitest jruby-rdoc jruby-rake


RUN apk update && \
    apk add curl vim \
    jruby jruby-irb jruby-minitest jruby-rdoc jruby-rake && \
    rm -rf /var/cache/apk/*


RUN jruby -S gem install --no-rdoc --no-ri bundler

WORKDIR /

COPY Gemfile $VERTICLE_HOME/Gemfile
COPY Gemfile.lock $VERTICLE_HOME/Gemfile.lock

WORKDIR $VERTICLE_HOME


RUN jruby -S bundle install

WORKDIR $VERTICLE_HOME
ENTRYPOINT ["sh", "-c"]
CMD ["vertx run $VERTICLE_HOME/$VERTICLE_NAME"]



