FROM platform_base
MAINTAINER Sandro Cirulli <sandro.cirulli@oup.com>

# set home directory for jenkins
ENV JENKINS_HOME /var/jenkins_home

# set JAVA_HOME
ENV JAVA_HOME /usr/lib/jvm/java-1.7.0-openjdk
ENV PATH ${PATH}:/usr/lib/jvm/java-1.7.0-openjdk

# add user jenkins 
RUN useradd -d "$JENKINS_HOME" -u 102 -m -s /bin/bash jenkins 

# Create docker group with gid = 497 and add jenkins to the group
# This will allow the jenkins user to run docker commands
RUN groupadd -g 497 docker && \
    usermod -a -G docker jenkins

# Install the docker client
RUN yum install -y docker

# install docker-compose
RUN pip install -U docker-compose==1.2.0

# Jenkins home directoy is a volume, so configuration and build history 
# can be persisted and survive image upgrades
VOLUME /var/jenkins_home

# volume for RDF data dumps
VOLUME /rdf

# volume for debugging
VOLUME /tmp

# `/usr/share/jenkins/ref/` contains all reference configuration we want 
# to set on a fresh new installation. Use it to bundle additional plugins 
# or config file with your custom jenkins Docker image.
RUN mkdir -p /usr/share/jenkins/ref/init.groovy.d
COPY init.groovy /usr/share/jenkins/ref/init.groovy.d/tcp-slave-angent-port.groovy

# set Jenkins version to install
ENV JENKINS_VERSION 1.619

# could use ADD but this one does not check Last-Modified header 
# see https://github.com/docker/docker/issues/8331
RUN curl -L http://mirrors.jenkins-ci.org/war/${JENKINS_VERSION}/jenkins.war -o /usr/share/jenkins/jenkins.war

ENV JENKINS_UC https://updates.jenkins-ci.org
RUN chown -R jenkins "$JENKINS_HOME" /usr/share/jenkins/ref

# for main web interface:
EXPOSE 8080

# will be used by attached slave agents:
EXPOSE 50000

USER jenkins

# volume for API data (json files for the sitemap)
VOLUME /storage

# Copy RDFUnit
COPY rdfunit /usr/local/rdfunit

# copy root configuration files
COPY *.xml /usr/share/jenkins/ref/

# copy updates centres
COPY updates /usr/share/jenkins/ref/updates

# copy users
COPY users /usr/share/jenkins/ref/users

COPY jenkins.sh /usr/local/bin/jenkins.sh

# ENTRYPOINT ["/usr/local/bin/jenkins.sh"]
CMD ["/usr/local/bin/jenkins.sh"]
