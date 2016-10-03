FROM redis:3.0


ENV USER_UID=10003
ENV USER_GID=10000

RUN echo $USER_UID
RUN echo $USER_GID


RUN groupmod --gid $USER_GID redis > /dev/null
RUN usermod  --uid $USER_UID redis > /dev/null


USER redis
