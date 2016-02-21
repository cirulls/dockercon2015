FROM platform_base
MAINTAINER Sandro Cirulli <sandro.cirulli@oup.com>

# Install nginx
RUN rpm -Uvh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
RUN yum install -y nginx

# Install libmemcached and headers
RUN yum install -y libmemcached libmemcached-devel

# Install requirements
COPY requirements.txt /usr/src/api/requirements.txt
RUN mkdir /usr/src/api/app && \
    pip3 install -r /usr/src/api/requirements.txt && \
    pip3 install uwsgi pylibmc

VOLUME /storage

EXPOSE 80
EXPOSE 1717

# environment variables
ENV FLASK_CONFIG docker
ENV MEMCACHED_SERVER memcached:11211

# add HTTP authentication for custom user
RUN yum install -y httpd-tools
ADD nginx/htpasswd-setup.cmd /tmp/htpasswd-setup.cmd
RUN expect -f /tmp/htpasswd-setup.cmd
RUN rm /tmp/htpasswd-setup.cmd

# Install nginx configuration file
COPY nginx/nginx.conf /etc/nginx/nginx.conf

# Install uWSGI ini file
COPY uwsgi/app.ini /tmp/app.ini

# Copy api application files
COPY app /usr/src/api/app
COPY *.py /usr/src/api/

WORKDIR /usr/src/api

CMD /usr/sbin/nginx && \
    uwsgi /tmp/app.ini
