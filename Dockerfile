from openjdk:11-slim AS builder

RUN apt-get --quiet --yes update && apt-get install -yqq wget vim

ARG NONROOT_USER=sysml
ARG NONROOT_UID=1000
ENV NONROOT_USER ${NONROOT_USER}
ENV NONROOT_UID ${NONROOT_UID}
ENV HOME /home/${NONROOT_USER}

RUN adduser --disabled-password \
    --gecos "Default user" \
    --uid ${NONROOT_UID} \
    ${NONROOT_USER}

USER root
RUN chown -R ${NONROOT_UID} ${HOME}

USER ${NONROOT_USER}
WORKDIR ${HOME}

ARG SBT_RELEASE=1.10.11
RUN wget -q https://github.com/sbt/sbt/releases/download/v${SBT_RELEASE}/sbt-${SBT_RELEASE}.tgz
RUN tar xfz sbt-${SBT_RELEASE}.tgz

COPY . . 

RUN sed s/key=.whatever./key=\"longersecretnowarnings\"/ -i conf/application.conf
RUN sed s/value=.create-drop./value=\"update\"/ -i conf/META-INF/persistence.xml

RUN ${HOME}/sbt/bin/sbt clean
RUN ${HOME}/sbt/bin/sbt update
RUN ${HOME}/sbt/bin/sbt compile

RUN sed 's/play.http.parser.maxMemoryBuffer = 1G/play.http.parser.maxMemoryBuffer = 1048576K/' -i conf/application.conf
RUN echo "\nplay.filters.hosts { allowed = [\".\"] }" >> conf/application.conf
RUN echo "parsers.anyContent.maxLength = 100MB" >> conf/application.conf
RUN echo "play.http.parser.maxDiskBuffer = 100MB" >> conf/application.conf

EXPOSE 9000
ENTRYPOINT /bin/sh -c "sed s/localhost:5432/$POSTGRES_HOSTNAME:$POSTGRES_PORT/ -i conf/META-INF/persistence.xml && $HOME/sbt/bin/sbt stage && ./target/universal/stage/bin/sysml-v2-api-services"