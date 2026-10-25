# Use Ubuntu 20.04 as base image
FROM ubuntu:20.04

LABEL org.opencontainers.image.authors="Yannick Fricke"

# Install required system packages
RUN apt-get update && apt-get upgrade -y && apt-get install -y curl software-properties-common && rm -rf /var/lib/apt/lists/*

# Add support for the 32bit architecture
RUN add-apt-repository multiverse && dpkg --add-architecture i386

# Install required SteamCMD dependencies, plus tini as the init process
RUN apt-get update && apt-get upgrade -y && apt-get install -y lib32gcc1 tini && rm -rf /var/lib/apt/lists/*

# Add an unprivileged user
# Running things in Docker as root is a security risk and should be avoided
RUN useradd -ms /bin/bash steam

# Switch to the new user
USER steam

# Switch to the HOME directory of the new user
WORKDIR /home/steam

# Create the "Steam" subdirectory
RUN mkdir -p Steam

# Switch to the new directory
WORKDIR /home/steam/Steam

# Download SteamCMD and extract it
RUN curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -

# Log in once so SteamCMD finishes self-updating and fetches the client config.
# Installing on a fresh SteamCMD otherwise fails with "Missing configuration".
RUN /home/steam/Steam/steamcmd.sh +login anonymous +quit

# Install the Satisfactory dedicated server
RUN /home/steam/Steam/steamcmd.sh +force_install_dir SatisfactoryDedicatedServer +login anonymous +app_update 1690800 +quit

# Run the server binary directly under tini instead of FactoryServer.sh.
# The script starts the server without exec, so /bin/sh became PID 1 and
# silently ignored SIGTERM: "docker stop" waited out its timeout and then
# SIGKILLed the server. tini forwards signals and reaps child processes
# such as crashpad_handler. The server doesn't save on SIGTERM, so save
# through the server API (SaveGame) before stopping.
ENTRYPOINT [ "/usr/bin/tini", "--", "/home/steam/Steam/SatisfactoryDedicatedServer/Engine/Binaries/Linux/FactoryServer-Linux-Shipping", "FactoryGame" ]

# for documentation purposes
EXPOSE 15777/udp
EXPOSE 15000/udp
EXPOSE 7777/udp
