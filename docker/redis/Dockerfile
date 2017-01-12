FROM redis:3.0


ENV USER_UID=10003
ENV USER_GID=10000
#ENV JAVA_OPTS "${JAVA_OPTS} -Xms256M -Xmx1G"
#ENV JRUBY_OPTS "${JRUBY_OPTS} -J-Xms512M -J-Xmx1G"
#ENV JVM_ARGS "-Xms512M -Xmx1G"

RUN echo $USER_UID
RUN echo $USER_GID


RUN groupmod --gid $USER_GID redis > /dev/null
RUN usermod  --uid $USER_UID redis > /dev/null


USER redis
