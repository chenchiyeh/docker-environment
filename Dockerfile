# syntax=docker/dockerfile:1

#Requirement 1 - Minimal Ubuntu 26.04 Base Image( Stage base )
FROM ubuntu:26.04

#Requirement 2 - Add Environment Settings in Stage base
ENV TZ=Asia/Taipei
ENV DEBIAN_FRONTEND=noninteractive

#Changing Container Timezone 
RUN apt-get update && apt-get install -y --no-install-recommends tzdata && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone 

#Setting Non-root user
ARG UID=2414
ARG GID=2414

RUN groupadd -g $GID customgroup && useradd -m -u $UID -g customgroup customuser

USER customuser