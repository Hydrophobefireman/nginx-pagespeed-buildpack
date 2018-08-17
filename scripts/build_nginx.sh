#!/bin/bash
# Build NGINX and modules on Heroku.
# This program is designed to run in a web dyno provided by Heroku.
# We would like to build an NGINX binary for the builpack on the
# exact machine in which the binary will run.
# Our motivation for running in a web dyno is that we need a way to
# download the binary once it is built so we can vendor it in the buildpack.
#
# Once the dyno has is 'up' you can open your browser and navigate
# this dyno's directory structure to download the nginx binary.
NGINX_VERSION=${NGINX_VERSION-1.15.2}
PCRE_VERSION=${PCRE_VERSION-8.37}
HEADERS_MORE_VERSION=${HEADERS_MORE_VERSION-0.261}
NPS_VERSION=1.13.35.2
nginx_tarball_url=http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz
pcre_tarball_url=http://iweb.dl.sourceforge.net/project/pcre/pcre/${PCRE_VERSION}/pcre-${PCRE_VERSION}.tar.bz2
headers_more_nginx_module_url=https://github.com/openresty/headers-more-nginx-module/archive/v${HEADERS_MORE_VERSION}.tar.gz
nps_url=https://github.com/apache/incubator-pagespeed-ngx/archive/v${NPS_VERSION}-beta.zip

temp_dir=$(mktemp -d /tmp/nginx.XXXXXXXXXX)
mkdir -p /tmp/pagespeed
echo "Serving files from /tmp on $PORT"
cd /tmp
python -m SimpleHTTPServer $PORT &

cd $temp_dir
echo "Temp dir: $temp_dir"

echo "Downloading $nginx_tarball_url"
curl -L $nginx_tarball_url | tar xzv

echo "Downloading $pcre_tarball_url"
(cd nginx-${NGINX_VERSION} && curl -L $pcre_tarball_url | tar xvj )

echo "Downloading $headers_more_nginx_module_url"
(cd nginx-${NGINX_VERSION} && curl -L $headers_more_nginx_module_url | tar xvz )

echo "Downloading $nps_url"
(
NPS_RELEASE_NUMBER=${NPS_VERSION}
cd nginx-${NGINX_VERSION} && curl -L $nps_url --output NPS_X.zip
unzip NPS_X.zip
cd incubator-pagespeed-ngx-${NPS_VERSION}-beta/
psol_url=https://dl.google.com/dl/page-speed/psol/${NPS_RELEASE_NUMBER}-x64.tar.gz
  echo "Downloading $psol_url"
  wget ${psol_url}
  tar -xzvf $(basename ${psol_url})
)
PS_NGX_EXTRA_FLAGS="--with-cc=/usr/lib/gcc  --with-ld-opt=-static-libstdc++" 
export cc=gcc
export CC=gcc
(	
  cd nginx-${NGINX_VERSION}
./configure \
--with-pcre=pcre-${PCRE_VERSION} \
--prefix=/tmp/nginx \
--with-cc=/usr/lib/gcc \
--with-ld-opt=-static-libstdc++
--add-module=/${temp_dir}/nginx-${NGINX_VERSION}/headers-more-nginx-module-${HEADERS_MORE_VERSION}\
--add-module=${temp_dir}/nginx-${NGINX_VERSION}/incubator-pagespeed-ngx-${NPS_VERSION}-beta\
--with-http_gzip_static_module \
--with-cc-opt='-g -O2 -fstack-protector --param=ssp-buffer-size=4 -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2' \
--with-ld-opt='-Wl,-Bsymbolic-functions -Wl,-z,relro -Wl,--as-needed'
make install
)