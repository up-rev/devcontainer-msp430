FROM uprev/base:ubuntu-18.04 as dev_stage

######################################################################################################
#                           Stage: jenkins                                                           #
######################################################################################################

# Install base packages
RUN apt-get update &&  apt-get install -y \
        apt-utils \
        zlib1g-dev \
        ca-certificates \
        apt-transport-https \
        gnupg software-properties-common \
        libusb-0.1-4 \
        libgconf-2-4 \
        gdb

# Install MSP430-GCC and support files
ENV MSP430_GCC_VERSION 9.3.1.11
RUN mkdir -p /opt/ti
ADD msp430-gcc-${MSP430_GCC_VERSION}_linux64.tar.bz2 /tmp/
ADD msp430-gcc-support-files-1.212.zip /tmp/
WORKDIR /tmp
RUN     tar xf msp430-gcc-${MSP430_GCC_VERSION}_linux64.tar.bz2 && \
        unzip msp430-gcc-support-files-1.212.zip && \
        mv msp430-gcc-${MSP430_GCC_VERSION}_linux64 /opt/ti/msp430-gcc && \
        mkdir -p /opt/ti/msp430-gcc/include && \
        mv msp430-gcc-support-files/include/* /opt/ti/msp430-gcc/include/ && \
        rm msp430-gcc-${MSP430_GCC_VERSION}_linux64.tar.bz2 && \
        rm msp430-gcc-support-files-1.212.zip && \
        rm -rf msp430-gcc-support-files
ENV PATH /opt/ti/msp430-gcc/bin:$PATH
ENV MSP430_TOOLCHAIN_PATH /opt/ti/msp430-gcc

# Install UniFlash
ENV UNIFLASH_VERSION=5.2.0.2519
RUN wget "http://software-dl.ti.com/ccs/esd/uniflash/uniflash_sl.${UNIFLASH_VERSION}.run" && \
        chmod +x uniflash_sl.${UNIFLASH_VERSION}.run && \
        ./uniflash_sl.${UNIFLASH_VERSION}.run --unattendedmodeui none --mode unattended --prefix /opt/ti/uniflash && \
        rm uniflash_sl.${UNIFLASH_VERSION}.run && \
        cd /opt/ti/uniflash/TICloudAgentHostApp/install_scripts && \
        mkdir -p /etc/udev/rules.d && \
        cp 70-mm-no-ti-emulators.rules /etc/udev/rules.d/72-mm-no-ti-emulators.rules && \
        cp 71-ti-permissions.rules /etc/udev/rules.d/73-ti-permissions.rules && \
        ln -sf /lib/x86_64-linux-gnu/libudev.so.1 /lib/x86_64-linux-gnu/libudev.so.0

WORKDIR /

######################################################################################################
#                           Stage: jenkins                                                           #
######################################################################################################

FROM dev_stage as jenkins_stage

ARG JENKINS_PW=jenkins  
RUN apt-get update && apt-get install -y --no-install-recommends \ 
    openssh-server \
    openjdk-8-jdk  \
    openssh-server \
    ca-certificates 

RUN apt-get clean all && rm -rf /var/lib/apt/lists/*

RUN adduser --quiet jenkins && \
    echo "jenkins:$JENKINS_PW" | chpasswd && \
    mkdir /home/jenkins/.m2 && \
    mkdir /home/jenkins/jenkins && \
    chown -R jenkins /home/jenkins 


# Setup SSH server
RUN mkdir /var/run/sshd
RUN echo 'root:password' | chpasswd
RUN sed -i 's/#*PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config

# SSH login fix. Otherwise user is kicked off after login
RUN sed -i 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' /etc/pam.d/sshd

ENV NOTVISIBLE="in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

ENV PATH="/opt/stm32cubeide:${PATH}"

EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]