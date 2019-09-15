# Creates a Docker container for Amazon AWS DynamoDB-local
# specifically for the armhf architecture (e.g. Raspberry Pi 4)
FROM debian:10.0

MAINTAINER Gareth Randall <gareth@garethrandall.com>

# Create our main application folder.
RUN mkdir -p /home/dynamodblocal
WORKDIR /home/dynamodblocal

# gant, gcc and swig are for building sqlite4java.
# git and wget are used in this Dockerfile.
# openjdk-11-jdk-headless is used to compile sqlite4java (hence jdk not jre)
#    and is also used in the container at runtime.
RUN apt-get update \
 && apt-get install -y gant gcc swig git wget openjdk-11-jdk-headless

# A patch to specify building for the armhf architecture rather than i386 and amd64.
COPY patch-for-ant_linux.properties /home/dynamodblocal

# Using a specific revision of the sqlite4java because it is know to work.
# As it doesn't have a named git tag we are using the exact revision instead.
RUN git clone https://bitbucket.org/almworks/sqlite4java.git \
 && cd sqlite4java \
 && git checkout 7b55b3eab6901a0e49d6e1129431fa92c4206c0b \
 && patch -p 1 < ../patch-for-ant_linux.properties \
 && cd ant \
 && export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-armhf \
 && gant -v -Djdk.home=/usr/lib/jvm/java-11-openjdk-armhf -Djre.linux-armhf=/usr/lib/jvm/java-11-openjdk-armhf dist

# Download and unpack dynamodb.
# Links are at: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/DynamoDBLocal.html
# Using a specific version here because it is known to work as part of this build.
# To get the latest, use: https://s3-us-west-2.amazonaws.com/dynamodb-local/dynamodb_local_latest.tar.gz
RUN wget https://s3-us-west-2.amazonaws.com/dynamodb-local/dynamodb_local_2019-02-07.tar.gz -q -O - | tar -xz

# Note that we remove the "hf" letters from library filename as we copy it.
RUN cp -p /home/dynamodblocal/sqlite4java/build/dist/sqlite4java.jar /home/dynamodblocal/DynamoDBLocal_lib/ \
 && cp -p /home/dynamodblocal/sqlite4java/build/dist/libsqlite4java-linux-armhf.so /home/dynamodblocal/DynamoDBLocal_lib/libsqlite4java-linux-arm.so

# The entrypoint is the dynamodb jar. Default port is 8000.
EXPOSE 8000

# DynamoDB option arguments that can be added in to the following list:
# -sharedDb = use the same database tables regardless of what region the client asks for.
#             This is useful for testing, or for diagnosing problems with setting the region.
# -inMemory = keep all data in memory. Do not write it to disk. Useful to speed up unit tests.
ENTRYPOINT ["java", "-jar", "DynamoDBLocal.jar"]

