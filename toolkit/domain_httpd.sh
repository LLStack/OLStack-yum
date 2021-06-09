#!/usr/bin/env bash
CK_RESULT=''
LSDIR='/usr/local/lsws'
OLS_HTTPD_CONF="${LSDIR}/conf/httpd_config.conf"
LSV='openlitespeed'
EPACE='        '

echow(){
    FLAG=${1}
    shift
    echo -e "\033[1m${EPACE}${FLAG}\033[0m${@}"
}

help_message(){
    echo -e "\033[1mOPTIONS\033[0m"
    echow '-A, --add [DOMAIN_NAME]'
    echo "${EPACE}${EPACE}Will add domain to listener and creat a virtual host from template"
    echow '-H, --help'
    echo "${EPACE}${EPACE}Display help."    
}

dot_escape(){
    ESCAPE=$(echo ${1} | sed 's/\./\\./g')
}  

check_duplicate(){
    CK_RESULT=$(grep -E "${1}" ${2})
}

fst_match_line(){
    FIRST_LINE_NUM=$(grep -n -m 1 ${1} ${2} | awk -F ':' '{print $1}')
}
fst_match_after(){
    FIRST_NUM_AFTER=$(tail -n +${1} ${2} | grep -n -m 1 ${3} | awk -F ':' '{print $1}')
}
lst_match_line(){
    fst_match_after ${1} ${2} ${3}
    LAST_LINE_NUM=$((${FIRST_LINE_NUM}+${FIRST_NUM_AFTER}-1))
}

check_input(){
    if [ -z "${1}" ]; then
        help_message
        exit 1
    fi
}

check_www(){
    CHECK_WWW=$(echo ${1} | cut -c1-4)
    if [[ ${CHECK_WWW} == www. ]] ; then
        echo 'www domain shoudnt be passed!'
        exit 1
    fi
}

www_domain(){
    check_www ${1}
    WWW_DOMAIN=$(echo www.${1})
}

line_change(){
    LINENUM=$(grep -v '#' ${2} | grep -n "${1}" | cut -d: -f 1)
    if [ -n "$LINENUM" ] && [ "$LINENUM" -eq "$LINENUM" ] 2>/dev/null; then
        sed -i "${LINENUM}d" ${2}
        sed -i "${LINENUM}i${3}" ${2}
    fi  
}

line_insert(){
    LINENUM=$(grep -n "${1}" ${2} | cut -d: -f 1)
    ADDNUM=${4:-0} 
    if [ -n "$LINENUM" ] && [ "$LINENUM" -eq "$LINENUM" ] 2>/dev/null; then
        LINENUM=$((${LINENUM}+${4}))
        sed -i "${LINENUM}i${3}" ${2}
    fi  
}

add_ols_domain(){
    mkdir -p /usr/local/lsws/conf/vhosts/${DOMAIND}
    if [ ! -f "/usr/local/lsws/conf/vhosts/${DOMAIND}/vhconf.conf" ]; then
        cat > /usr/local/lsws/conf/vhosts/${DOMAIND}/vhconf.conf << EOF
docRoot                   $VH_ROOT/html/
vhDomain                  example.llstack.com
vhAliases                 www.$VH_DOMAIN
enableGzip                1

errorlog \$SERVER_ROOT/logs/\$VH_NAME.error_log {
useServer               0
logLevel                ERROR
rollingSize             10M
}

accesslog $SERVER_ROOT/logs/$VH_NAME.access.log {
  useServer               0
  rollingSize             100M
  keepDays                7
  compressArchive         1
}

index  {
  useServer               0
  indexFiles              index.html, index.php
  autoIndex               0
  autoIndexURI            /_autoindex/default.php
}

expires  {
  enableExpires           1
}

accessControl  {
  allow                   *
}

extprocessor apachehttp {
  type                    proxy
  address                 http://127.0.0.1:81
  maxConns                100
  initTimeout             50
  retryTimeout            0
  respBuffer              0
}

context / {
  location                $DOC_ROOT/
  allowBrowse             1

  rewrite  {
RewriteFile .htaccess
  }
}

rewrite  {
  enable                  1
  autoLoadHtaccess        1
  logLevel                0
  rules                   <<<END_rules
RewriteCond %{HTTPS} !=on
RewriteRule ^(.*)$ http://apachehttp/$1 [P,L,E=proxy-host:example.llstack.com]
  END_rules

}

vhssl  {
  keyFile                 /root/.acme.sh/certs/$VH_NAME/$VH_NAME.key
  certFile                /root/.acme.sh/certs/$VH_NAME/fullchain.cer
  certChain               1
}
EOF
        chown -R lsadm:lsadm /usr/local/lsws/conf/vhosts/*
    else
        echoR "Targeted file already exist, skip!"
    fi

    if [ ! -f "/etc/httpd/conf.d/vhosts/${DOMAIND}.conf" ]; then
        if [ "${add_domain_ssl}" = 1]; then
        cat > /etc/httpd/conf.d/vhosts/${DOMAIND}.conf << EOF
<VirtualHost *:81>
    ServerAdmin webmaster@llstack.com
    DocumentRoot "/var/www/vhosts/${DOMAIND}/html/"
    ServerName ${DOMAIND}
    ServerAlias www.${DOMAIND} 
    #errorDocument 404 /404.html
    ErrorLog "/var/log/httpd/${DOMAIND}-error.log"
    CustomLog "/var/log/httpd/${DOMAIND}-access.log" combined
    
    #DENY FILES
     <Files ~ (\.user.ini|\.htaccess|\.git|\.svn|\.project|LICENSE|README.md)$>
       Order allow,deny
       Deny from all
    </Files>

    #PATH
    <Directory "/var/www/vhosts/${DOMAIND}/html/">
        SetOutputFilter DEFLATE
        Options FollowSymLinks
        AllowOverride All
        Require all granted
        DirectoryIndex index.php index.html index.htm default.php default.html default.htm
    </Directory>
    Include /etc/httpd/conf.d/php00-php.conf
</VirtualHost>
<VirtualHost *:445>
    ServerAdmin webmaster@llstack.com
    DocumentRoot "/var/www/vhosts/${DOMAIND}/html/"
    ServerName ${DOMAIND}
    ServerAlias www.${DOMAIND} 
    #errorDocument 404 /404.html
    ErrorLog "/var/log/httpd/${DOMAIND}-error.log"
    CustomLog "/var/log/httpd/${DOMAIND}-access.log" combined
    
    #SSL
    SSLEngine On
    SSLCertificateFile /root/.acme.sh/certs/${DOMAIND}/fullchain.cer
    SSLCertificateKeyFile /root/.acme.sh/certs/${DOMAIND}/${DOMAIND}.key
    SSLCipherSuite TLS13-AES-256-GCM-SHA384:TLS13-CHACHA20-POLY1305-SHA256:TLS13-AES-128-GCM-SHA256:TLS13-AES-128-CCM-8-SHA256:TLS13-AES-128-CCM-SHA256:EECDH+CHACHA20:EECDH+CHACHA20-draft:EECDH+ECDSA+AES128:EECDH+aRSA+AES128:RSA+AES128:EECDH+ECDSA+AES256:EECDH+aRSA+AES256:RSA+AES256:EECDH+ECDSA+3DES:EECDH+aRSA+3DES:RSA+3DES:!MD5;
    SSLProtocol All -SSLv2 -SSLv3 -TLSv1
    SSLHonorCipherOrder On

    #DENY FILES
     <Files ~ (\.user.ini|\.htaccess|\.git|\.svn|\.project|LICENSE|README.md)$>
       Order allow,deny
       Deny from all
    </Files>

    #PATH
    <Directory "/var/www/vhosts/${DOMAIND}/html/">
        SetOutputFilter DEFLATE
        Options FollowSymLinks
        AllowOverride All
        Require all granted
        DirectoryIndex index.php index.html index.htm default.php default.html default.htm
    </Directory>
    Include /etc/httpd/conf.d/php00-php.conf
</VirtualHost>
EOF
        else
        cat > /etc/httpd/conf.d/vhosts/${DOMAIND}.conf << EOF
<VirtualHost *:81>
    ServerAdmin webmaster@llstack.com
    DocumentRoot "/var/www/vhosts/${DOMAIND}/html/"
    ServerName ${DOMAIND}
    ServerAlias www.${DOMAIND} 
    #errorDocument 404 /404.html
    ErrorLog "/var/log/httpd/${DOMAIND}-error.log"
    CustomLog "/var/log/httpd/${DOMAIND}-access.log" combined
    
    #DENY FILES
     <Files ~ (\.user.ini|\.htaccess|\.git|\.svn|\.project|LICENSE|README.md)$>
       Order allow,deny
       Deny from all
    </Files>
    
    #PATH
    <Directory "/var/www/vhosts/${DOMAIND}/html/">
        SetOutputFilter DEFLATE
        Options FollowSymLinks
        AllowOverride All
        Require all granted
        DirectoryIndex index.php index.html index.htm default.php default.html default.htm
    </Directory>
    Include /etc/httpd/conf.d/php00-php.conf
</VirtualHost>
EOF
        fi
    else
        echoR "Targeted file already exist, skip!"
    fi
}

changephp() {
    NEWKEY="Include /etc/httpd/conf.d/php${phpVer}-php.conf"
    line_change 'Include /etc/httpd/conf.d/' /etc/opt/remi/php${phpInsVer}/php-fpm.d/www.conf "${NEWKEY}"
    systemctl restart httpd.service
}

set_server_conf() {
    NEWKEY="map                     ${DOMAIND} ${WWW_DOMAIN}" 
    PORT_ARR=$(grep "address.*:[0-9]"  /usr/local/lsws/conf/httpd_config.conf | awk '{print substr($2,3)}')
    if [  ${#PORT_ARR[@]} != 0 ]; then
        for PORT in ${PORT_ARR[@]}; do 
            line_insert ":${PORT}$"  /usr/local/lsws/conf/httpd_config.conf "${NEWKEY}" 2
        done
    else
        echoR 'No listener port detected, listener setup skip!'    
    fi
    echo "
virtualhost ${DOMAIND} {
vhRoot                  /var/www/vhosts/${DOMAIND}
configFile              /usr/local/lsws/conf/vhosts/${DOMAIND}/vhconf.conf
allowSymbolLink         1
enableScript            1
restrained              1
}" >>/usr/local/lsws/conf/httpd_config.conf
}

update_vh_conf(){
    sed -i 's|example.llstack.com|'${DOMAIND}'|g' /usr/local/lsws/conf/vhosts/${DOMAIND}/vhconf.conf
}
check_ssl_acme(){
    if [ ! -d "/root/.acme.sh/certs/${DOMAIND}" ]; then
        echoR 'Please use acme.sh to issue the certificate first'
    fi
}


add_domain(){
    dot_escape ${1}
    DOMAIN=${ESCAPE}
    DOMAIND=${1}
    www_domain ${1}
    check_duplicate ${DOMAIND} /usr/local/lsws/conf/httpd_config.conf
    if [ "${CK_RESULT}" != '' ]; then
        echo "# It appears the domain already exist! Check the ${OLS_HTTPD_CONF} if you believe this is a mistake!"
        exit 1
    fi
    if [[ "${add_domain_ssl}" = "1" || "${self_ssl_key}" = '' || "${self_ssl_crt}" = '' ]]; then
        check_ssl_acme
    fi
    add_ols_domain
    set_server_conf
    update_vh_conf
    if [ ! -d "/var/www/vhosts/${1}" ]; then 
        mkdir -p /var/www/vhosts/${1}/{html,logs,certs}
    fi
    bash /usr/local/lsws/bin/lswsctrl restart
    systemctl restart httpd.service
}

check_input ${1}
while [ ! -z "${1}" ]; do
    case ${1} in
        -[hH] | -help | --help)
            help_message
            ;;
        -[aA] | -add | --add) shift
            add_domain ${1}
            ;;      
        -[sS] | -ssl | --SSL) shift
            add_domain_ssl='1'
            ;;
        -[kK] | -key | --KEY) shift
            self_ssl_key=${1}
            ;;
        -[cC] | -crt | --CRT) shift
            self_ssl_crt=${1}
            ;;
        -[pP] | -php | --PHP) shift
            phpVer=${1}
            changephp
            ;;    
        *) 
            help_message
            ;;
    esac
    shift
done