#!/usr/bin/env bash
CK_RESULT=''
LSDIR='/usr/local/lsws'
OLS_HTTPD_CONF="${LSDIR}/conf/httpd_config.conf"
LSV='openlitespeed'
EPACE='        '
letencryptD=''
self_ssl_crtD=''
change_self_sslD=''

echow(){
    FLAG=${1}
    shift
    echo -e "\033[1m${EPACE}${FLAG}\033[0m${@}"
}

echoR() {
    echo -e "\e[31m${1}\e[39m"
}

help_message(){
    echo -e "\033[1mOPTIONS\033[0m"
    echow '-A, --add [DOMAIN_NAME]'
    echo "${EPACE}${EPACE}Will add domain to listener and creat a virtual host from template"
    echow '-S, --ssl'
    echo "${EPACE}${EPACE}Will use the acme ssl cert,but you should use the acme.sh to issue the cert first!" 
    echow '-K, --key [SSLKey_Dir]'
    echo "${EPACE}${EPACE}Use you own SSL key to enable SSL,Please fill in the path of the ssl Privite Key" 
    echow '-C, --crt [SSLCrt_dir]'
    echo "${EPACE}${EPACE}Use you own SSL Crt to enable SSL,Please fill in the path of the ssl certificate"  
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

set_server_conf() {
    echoR "set_server_conf"
    NEWKEY="map                     ${DOMAIND} ${DOMAIND}, ${WWW_DOMAIN}" 

    line_insert "443"  /usr/local/lsws/conf/httpd_config.conf "${NEWKEY}" 2
}

issue_cert(){
    echoR "issue_cert"
    if [[ "${acme_checkD}" = 1 || "${letencryptD}" = 1 ]]; then
        curl -Is http://${DOMAIND}/ | grep -i LiteSpeed > /dev/null 2>&1
        if [ ${?} = 0 ]; then
            echo -e "[O] The domain name \033[32m${DOMAIND}\033[0m is accessible."
            TYPE=1
            curl -Is http://${WWW_DOMAIN}/ | grep -i LiteSpeed > /dev/null 2>&1
            if [ ${?} = 0 ]; then
                echo -e "[O] The domain name \033[32m${WWW_DOMAIN}\033[0m is accessible."
                TYPE=2
            else
                echo -e "[!] The domain name ${WWW_DOMAIN} is inaccessible." 
            fi
        else
            echo -e "[X] The domain name \e[31m${DOMAIND}\e[39m is inaccessible, please verify."
            exit 1    
        fi

        echo '[Start] Apply Lets Encrypt Certificate'
        DOC_PATH="/var/www/vhosts/${DOMAIND}/html"
        if [ ${TYPE} = 1 ]; then
            /root/.acme.sh/acme.sh --issue -d ${DOMAIND} -w ${DOC_PATH} --server letsencrypt
        elif [ ${TYPE} = 2 ]; then
            /root/.acme.sh/acme.sh --issue -d ${DOMAIND} -d www.${DOMAIND} -w ${DOC_PATH}  --server letsencrypt
        else
            echo 'unknown Type!'
            exit 2
        fi
        echo '[End] Apply Lets Encrypt Certificate'
    fi
}

add_ssl_domain(){
    cat >> /etc/httpd/conf.d/vhosts/${DOMAIND}.conf << EOF
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
}

change_self_ssl(){
    echoR "change_self_ssl"
    if [ "${change_self_sslD}" = "1" ]; then
        sed -i "s@SSLCertificateFile.*@SSLCertificateFile '${self_ssl_crt}@g" /etc/httpd/conf.d/vhosts/${DOMAIND}.conf 
        sed -i "s@SSLCertificateKeyFile.*@SSLCertificateKeyFile ${self_ssl_key}@g" /etc/httpd/conf.d/vhosts/${DOMAIND}.conf
        sed -i "s@keyFile.*@keyFile                 ${self_ssl_key}@g" /usr/local/lsws/conf/vhosts/${DOMAIND}/vhconf.conf
        sed -i "s@certFile.*@certFile               ${self_ssl_crt}@g" /usr/local/lsws/conf/vhosts/${DOMAIND}/vhconf.conf
    fi
}

check_ssl_acme(){
    echoR "check_ssl_acme"
    if [ "${letencryptD}" = "1" ]; then
        if [ ! -f "/root/.acme.sh/acme.sh" ]; then
            bash ./acme.sh --install --no-email
            acme_checkD='1'
        else
            acme_checkD='1'
        fi
    fi
}

#echo_things(){
#    echow  "letencryptD $letencryptD"
#    echow  "self_ssl_crtD $self_ssl_crtD"
#    echow  "change_self_sslD $change_self_sslD"
#}

add_domain(){
    echow  "letencryptD：${letencryptD}"
    dot_escape ${1}
    DOMAIN=${ESCAPE}
    DOMAIND=${1}
    www_domain ${1}
    #echo_things
    check_ssl_acme
    check_duplicate ${DOMAIND} /usr/local/lsws/conf/httpd_config.conf
    if [ "${CK_RESULT}" = '' ]; then
        echo "# You should run the domain_httpd.sh first."
        exit 1
    fi
    issue_cert
    add_ssl_domain
    set_server_conf
    change_self_ssl
    bash /usr/local/lsws/bin/lswsctrl restart
    echow  "Restart LiteSpeed"
    systemctl restart httpd.service
    echow  "Restart HTTPD"
    echow  "${acme_checkD}"
    echow  "${letencryptD}"
}


check_input ${1}
while [ ! -z "${1}" ]; do
    case ${1} in
        -[hH] | -help | --help)
            help_message
            ;;
        -[lL] | -letencrypt | --letencrypt) shift
            letencryptD=${1}
            ;;
        -[kK] | -key | --KEY) shift
            self_ssl_key=${1}
            ;;
        -[cC] | -crt | --CRT) shift
            self_ssl_crt=${1}
            self_ssl_crtD='1'
            change_self_sslD='1'
            ;;
        -[aA] | -add | --add) shift
            add_domain ${1}
            ;;      
        *) 
            help_message
            ;;
    esac
    shift
done