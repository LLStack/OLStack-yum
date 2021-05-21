#!/bin/bash
#
#
# CentOS 8 OLStack-yum
# Author: ivmm <cjwbbs@gmail.com>
# Home: https://www.llstack.com
# Blog: https://www.mf8.biz
#
# * LiteSpeed Enterprise Web Server
# * MySQL 8.0 (MariaDB 10.3/10.4/10.5)
# * PHP 5.6/7.0/7.1/7.2/7.3/7.4/8.0
# * phpMyAdmin(Adminer)
#
# https://github.com/LLStack/OLStack-yum/
#
# Usage: sh install.sh
#

# check root
[ "$(id -g)" != '0' ] && die 'Script must be run as root.'

# declare variables
envType='master'
ipAddress=`curl -s -4 https://api.ip.sb/ip`
mysqlPWD=$(echo -n ${RANDOM} | md5sum | cut -b -16)

mysqlUrl='http://repo.percona.com'
mariaDBUrl='http://yum.mariadb.org'
phpUrl='http://rpms.remirepo.net'
LiteSpeedUrl='http://rpms.litespeedtech.com'
GitUrl='https://github.com/LLStack/OLStack-yum/archive/refs/heads'
phpMyAdmin='https://files.phpmyadmin.net'
mysqlUrl_CN='http://mirrors.ustc.edu.cn/percona'
mariaDBUrl_CN='http://mirrors.ustc.edu.cn/mariadb/yum'
phpUrl_CN='https://mirrors.ustc.edu.cn/remi'
LiteSpeedUrl_CN='http://litespeed-rpm.mf8.biz'
GitUrl_CN='https://gitee.com/LLStack/OLStack-yum/repository/archive'
phpMyAdmin_CN='https://phpmyadminfile.llstack.com'
isUpdate='0'

OpenLiteSpeedVersionStable='openlitespeed-1.6.21-1'
OpenLiteSpeedVersionEdge='openlitespeed-1.7.10-1'

# show success message
showOk(){
  echo -e "\\033[34m[OK]\\033[0m $1"
}

# show error message
showError(){
  echo -e "\\033[31m[ERROR]\\033[0m $1"
}

# show notice message
showNotice(){
  echo -e "\\033[36m[NOTICE]\\033[0m $1"
}

# install
runInstall(){
  showNotice 'Installing...'

  showNotice '(Step 1/7) Update YUM packages'

  while true; do
    read -p "Please answer yes or no. [Y/n]" yn
    case $yn in
      [Yy]* ) isUpdate='1'; break;;
      [Nn]* ) isUpdate='0'; break;;
    esac
  done

  showNotice '(Step 2/7) Input server IPv4 Address'
  read -p "IP address: " -r -e -i "${ipAddress}" ipAddress
  if [ "${ipAddress}" = '' ]; then
    showError 'Invalid IP Address'
    exit
  fi

  showNotice "(Step 3/7) Select the MySQL version"
  echo "1) MariaDB-10.3"
  echo "2) MariaDB-10.4"
  echo "3) MariaDB-10.5"
  echo "4) MariaDB-10.6 unstable"
  echo "5) Percona Server 5.7(MySQL)"
  echo "6) Percona Server 8.0(MySQL)"
  echo "0) Not need"
  read -p 'MySQL [1-5,0]: ' -r -e -i 3 mysqlV
  if [ "${mysqlV}" = '' ]; then
    showError 'Invalid MySQL version'
    exit
  fi

  showNotice "(Step 4/7) Select the PHP version"
  echo "1) PHP-5.6"
  echo "2) PHP-7.0"
  echo "3) PHP-7.1"
  echo "4) PHP-7.2"
  echo "5) PHP-7.3"
  echo "6) PHP-7.4"
  echo "7) PHP-8.0"
  echo "0) Not need"
  read -p 'PHP [1-7,0]: ' -r -e -i 6 phpV
  if [ "${phpV}" = '' ]; then
    showError 'Invalid PHP version'
    exit
  fi

  showNotice "(Step 5/7) Install OpenLiteSpeed or Not?"
  echo "1) OpenLiteSpeed Stable"
  echo "2) OpenLiteSpeed Edge"
  echo "0) Not need"
  read -p 'LiteSpeed [1-2,0]: ' -r -e -i 1 LiteSpeedV
  if [ "${LiteSpeedV}" = '' ]; then
    showError 'Invalid LiteSpeed select'
    exit
  fi

  showNotice "(Step 6/7) Select the DB tool version"
  echo "1) AMySQL"
  echo "2) Adminer"
  echo "3) phpMyAdmin"
  echo "0) Not need"
  read -p 'DB tool [1-3,0]: ' -r -e -i 1 dbV
  if [ "${dbV}" = '' ]; then
    showError 'Invalid DB tool version'
    exit
  fi

  showNotice "(Step 7/7) Use a mirror server to download rpms"
  echo "1) Source station"
  echo "2) China Mirror station"
  read -p 'Proxy server [1-2]: ' -r -e -i 2 freeV
  if [ "${freeV}" = '' ]; then
    showError 'Invalid Proxy server'
    exit
  fi

#  showNotice "Use Triay Key or Serial No. to activate LiteSpeed"
#  echo "1) Triay Key, Please put The Trial.key in /root/trial.key"
#  echo "2) Serial No. Recommend"
#  read -p 'Activation method [1-2]: ' -r -e -i 2 acV
#  if [ "${acV}" = '2' ]; then
#      showNotice "Enter The Serial No. here."
#      read -p 'Serial No.: ' -r -e acnoV
#        if [ "${acnoV}}" = '' ]; then
#          showError 'Invalid Serial No.'
#          exit
#        fi
#    elif [ "${acV}" = '' ]; then
#      showError 'Invalid Activation method'
#      exit
#  fi

  echo 'Detecting Dependencies'
  [ "${isUpdate}" = '1' ] && yum update -y
  [ ! -x "/usr/bin/wget" ] && yum install wget -y
  [ ! -x "/usr/bin/curl" ] && yum install curl -y
  [ ! -x "/usr/bin/unzip" ] && yum install unzip -y
  echo 'Disable SELINUX'
  [ -s /etc/selinux/config ] && sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
  setenforce 0 >/dev/null 2>&1

  yumRepos=$(find /etc/yum.repos.d/ -maxdepth 1 -name "*.repo" -type f | wc -l)

  startDate=$(date)
  startDateSecond=$(date +%s)

  showNotice 'Installing'

  mysqlRepoUrl=${mysqlUrl}
  mariaDBRepoUrl=${mariaDBUrl}
  phpRepoUrl=${phpUrl}
  LiteSpeedRepoUrl=${LiteSpeedUrl}
  GitFileUrl=${GitUrl}
  phpMyAdminURL=${phpMyAdmin}

  if [ "${freeV}" = "2" ]; then
    mysqlRepoUrl=${mysqlUrl_CN}
    mariaDBRepoUrl=${mariaDBUrl_CN}
    phpRepoUrl=${phpUrl_CN}
    LiteSpeedRepoUrl=${LiteSpeedUrl_CN}
    GitFileUrl=${GitUrl_CN}
    phpMyAdminURL=${phpMyAdmin_CN}
    touch /root/llstack-china-speed-tag.txt
  fi
  echo 'Check OLStack-yum-envtype.zip'
  if [ ! -d "/tmp/OLStack-yum-${envType}" ]; then
    cd /tmp || exit
    if [ ! -f "OLStack-yum-${envType}.zip" ]; then
      if ! curl -L --retry 3 -o "OLStack-yum-${envType}.zip" "${GitFileUrl}/${envType}.zip"
      then
        showError "OLStack-yum-${envType} download failed!"
        exit
      fi
    fi
    unzip -q "OLStack-yum-${envType}.zip" 
    if [ -d "/tmp/OLStack-yum" ]; then
      mv /tmp/OLStack-yum /tmp/OLStack-yum-${envType}
    fi
  fi
  echo 'Install EPEL & Firewalld'

  if [ -f "/etc/alinux-release" ]; then
    yum install -y yum-utils firewalld firewall-config
  else
    yum install -y epel-release yum-utils firewalld firewall-config
  fi

  if [ "${mysqlV}" != '0' ]; then
  echo 'Remove Native DB'
  yum -y remove mariadb*
  
    if [[ "${mysqlV}" = "1" || "${mysqlV}" = "2" || "${mysqlV}" = "3" || "${mysqlV}" = "4" ]]; then
      mariadbV='10.5'
      installDB='mariadb'
      echo 'Disable Native MariaDB'
      yum module disable mariadb -y
      case ${mysqlV} in
        1)
        mariadbV='10.3'
        ;;
        2)
        mariadbV='10.4'
        ;;
        3)
        mariadbV='10.5'
        ;;
        4)
        mariadbV='10.6'
        ;;
      esac
      echo 'Enable MariaDB REPO'
      rpm --import ${mariaDBRepoUrl}/RPM-GPG-KEY-MariaDB
      echo -e "[mariadb]\\nname = MariaDB\\nbaseurl = ${mariaDBRepoUrl}/${mariadbV}/centos/8/x86_64/\\ngpgkey=file:///etc/pki/rpm-gpg/MariaDB-Server-GPG-KEY\\ngpgcheck=1\\nenabled=1\\nmodule_hotfixes=1" > /etc/yum.repos.d/mariadb.repo
    #elif [[ "${mysqlV}" = "5" ]]; then
    elif [[ "${mysqlV}" = "5" || "${mysqlV}" = "6" ]]; then
      echo 'Enable PerconaDB REPO'
      #rpm -Uvh ${mysqlRepoUrl}/yum/percona-release-latest.noarch.rpm
      #rpm --import /tmp/OLStack-yum-${envType}/keys/RPM-GPG-KEY-Percona
      rpm --import /tmp/OLStack-yum-${envType}/keys/PERCONA-PACKAGING-KEY
      yum module disable mysql -y
      installDB='mysqld'
      
      case ${mysqlV} in
        5)
        echo 'Setup PerconaDB 5.7'
        cp -a /tmp/OLStack-yum-${envType}/repo/percona-ps-57-release.repo /etc/yum.repos.d/percona-ps-57-release.repo
        if [ "${freeV}" = "2" ]; then
          sed -i "s@${mysqlUrl}@${mysqlRepoUrl}@g" /etc/yum.repos.d/percona-ps-57-release.repo
        fi
        ;;
        6)
        echo 'Setup PerconaDB 8.0'
        cp -a /tmp/OLStack-yum-${envType}/repo/percona-ps-80-release.repo /etc/yum.repos.d/percona-ps-80-release.repo
        if [ "${freeV}" = "2" ]; then
          sed -i "s@${mysqlUrl}@${mysqlRepoUrl}@g" /etc/yum.repos.d/percona-ps-80-release.repo
        fi
        ;;
      esac
            find /etc/yum.repos.d/ -maxdepth 1 -name "percona-*.repo" -type f -print0 | xargs -0 sed -i "s@${mysqlUrl}@${mysqlRepoUrl}@g"
    fi
  fi

    if [ "${mysqlV}" != '0' ]; then
    if [ "${installDB}" = "mariadb" ]; then
      echo 'Install MariaDB'
      yum install -y MariaDB-server MariaDB-client MariaDB-common
      mysql_install_db --user=mysql
    elif [ "${installDB}" = "mysqld" ]; then
      echo 'Install PerconaDB'
      if [ "${mysqlV}" = "5" ]; then
        yum install -y Percona-Server-client-57 Percona-Server-server-57
      elif [ "${mysqlV}" = "6" ]; then
        yum install -y percona-server-client percona-server-server
      fi
      echo 'Initialize Insecure'
        mysqld --initialize-insecure --user=mysql

      if [ "${mysqlV}" = "6" ]; then
      echo 'Setting Mysql Native Password'
      sed -i "s@# default-authentication-plugin=mysql_native_password@default-authentication-plugin=mysql_native_password@g" /etc/my.cnf
      fi
    fi
  fi

  if [ "${phpV}" != '0' ]; then
    sedPhpRepo() {
      find /etc/yum.repos.d/ -maxdepth 1 -name "remi*.repo" -type f -print0 | xargs -0 sed -i "$1"
    }
    echo 'Enable REMI REPO'
    rpm -Uvh ${phpRepoUrl}/enterprise/remi-release-8.rpm

    sedPhpRepo "s@${phpUrl}@${phpRepoUrl}@g"

    if [ "${freeV}" = "1" ]; then
      sedPhpRepo "/\$basearch/{n;s/^baseurl=/#baseurl=/g}"
      sedPhpRepo "/\$basearch/{n;n;n;s/^#mirrorlist=/mirrorlist=/g}"
    elif [ "${freeV}" = "2" ]; then
      sedPhpRepo "/\$basearch/{n;s/^#baseurl=/baseurl=/g}"
      sedPhpRepo "/\$basearch/{n;n;n;s/^mirrorlist=/#mirrorlist=/g}"
    fi

    case ${phpV} in
      1)
      echo 'Install PHP56'
      yum install -y php56-php-litespeed php56-php-cli php56-php-bcmath php56-php-gd php56-php-mbstring php56-php-mcrypt php56-php-mysqlnd php56-php-opcache php56-php-pdo php56-php-pecl-crypto php56-php-pecl-geoip php56-php-pecl-zip php56-php-recode php56-php-snmp php56-php-soap php56-php-xml
      mkdir -p /usr/local/lsws/lsphp56/bin/
      ln -s /opt/remi/php56/root/usr/bin/lsphp /usr/local/lsws/lsphp56/bin/lsphp
      ln -s /opt/remi/php56/root/usr/bin/php /usr/bin/php
      touch /usr/share/lsphp-default-version
      echo "lsphp56" > /usr/share/lsphp-default-version
      ;;
      2)
      echo 'Install PHP70'
      yum install -y php70-php-litespeed php70-php-cli php70-php-bcmath php70-php-gd php70-php-json php70-php-mbstring php70-php-mcrypt php70-php-mysqlnd php70-php-opcache php70-php-pdo php70-php-pecl-crypto php70-php-pecl-geoip php70-php-pecl-zip php70-php-recode php70-php-snmp php70-php-soap php70-php-xml
      mkdir -p /usr/local/lsws/lsphp70/bin/
      ln -s /opt/remi/php70/root/usr/bin/lsphp /usr/local/lsws/lsphp70/bin/lsphp
      ln -s /opt/remi/php70/root/usr/bin/php /usr/bin/php
      touch /usr/share/lsphp-default-version
      echo "lsphp70" > /usr/share/lsphp-default-version
      ;;
      3)
      echo 'Install PHP71'
      yum install -y php71-php-litespeed php71-php-cli php71-php-bcmath php71-php-gd php71-php-json php71-php-mbstring php71-php-mcrypt php71-php-mysqlnd php71-php-opcache php71-php-pdo php71-php-pecl-crypto php71-php-pecl-geoip php71-php-pecl-zip php71-php-recode php71-php-snmp php71-php-soap php71-php-xml
      mkdir -p /usr/local/lsws/lsphp71/bin/
      ln -s /opt/remi/php71/root/usr/bin/lsphp /usr/local/lsws/lsphp71/bin/lsphp
      ln -s /opt/remi/php71/root/usr/bin/php /usr/bin/php
      touch /usr/share/lsphp-default-version
      echo "lsphp71" > /usr/share/lsphp-default-version
      ;;
      4)
      echo 'Install PHP72'
      yum install -y php72-php-litespeed php72-php-cli php72-php-bcmath php72-php-gd php72-php-json php72-php-mbstring php72-php-mcrypt php72-php-mysqlnd php72-php-opcache php72-php-pdo php72-php-pecl-crypto php72-php-pecl-mcrypt php72-php-pecl-geoip php72-php-pecl-zip php72-php-recode php72-php-snmp php72-php-soap php72-php-xml
      mkdir -p /usr/local/lsws/lsphp72/bin/
      ln -s /opt/remi/php72/root/usr/bin/lsphp /usr/local/lsws/lsphp72/bin/lsphp
      ln -s /opt/remi/php72/root/usr/bin/php /usr/bin/php
      touch /usr/share/lsphp-default-version
      echo "lsphp72" > /usr/share/lsphp-default-version
      ;;
      5)
      echo 'Install PHP73'
      yum install -y php73-php-litespeed php73-php-cli php73-php-bcmath php73-php-gd php73-php-json php73-php-mbstring php73-php-mcrypt php73-php-mysqlnd php73-php-opcache php73-php-pdo php73-php-pecl-crypto php73-php-pecl-mcrypt php73-php-pecl-geoip php73-php-pecl-zip php73-php-recode php73-php-snmp php73-php-soap php73-php-xml
      mkdir -p /usr/local/lsws/lsphp73/bin/
      ln -s /opt/remi/php73/root/usr/bin/lsphp /usr/local/lsws/lsphp73/bin/lsphp
      ln -s /opt/remi/php73/root/usr/bin/php /usr/bin/php
      touch /usr/share/lsphp-default-version
      echo "lsphp73" > /usr/share/lsphp-default-version
      ;;
      6)
      echo 'Install PHP74'
      yum install -y php74-php-litespeed php74-php-cli php74-php-bcmath php74-php-gd php74-php-json php74-php-mbstring php74-php-mcrypt php74-php-mysqlnd php74-php-opcache php74-php-pdo php74-php-pecl-crypto php74-php-pecl-mcrypt php74-php-pecl-geoip php74-php-pecl-zip php74-php-recode php74-php-snmp php74-php-soap php74-php-xml
      mkdir -p /usr/local/lsws/lsphp74/bin/
      ln -s /opt/remi/php74/root/usr/bin/lsphp /usr/local/lsws/lsphp74/bin/lsphp
      ln -s /opt/remi/php74/root/usr/bin/php /usr/bin/php
      touch /usr/share/lsphp-default-version
      echo "lsphp74" > /usr/share/lsphp-default-version
      ;;
      7)
      echo 'Install PHP80'
      yum install -y php80-php-litespeed php80-php-cli php80-php-bcmath php80-php-gd php80-php-json php80-php-mbstring php80-php-mcrypt php80-php-mysqlnd php80-php-opcache php80-php-pdo php80-php-pecl-crypto php80-php-pecl-mcrypt php80-php-pecl-geoip php80-php-pecl-zip php80-php-snmp php80-php-soap php80-php-xml
      mkdir -p /usr/local/lsws/lsphp80/bin/
      ln -s /opt/remi/php80/root/usr/bin/lsphp /usr/local/lsws/lsphp80/bin/lsphp
      ln -s /opt/remi/php80/root/usr/bin/php /usr/bin/php
      touch /usr/share/lsphp-default-version
      echo "lsphp80" > /usr/share/lsphp-default-version
      ;;
    esac
  fi

  if [ "${LiteSpeedV}" != '0' ]; then
  echo 'Enable LiteSpeedTech REPO'
    rpm -Uvh ${LiteSpeedRepoUrl}/centos/litespeed-repo-1.2-1.el8.noarch.rpm

    LiteSpeedRepo=/etc/yum.repos.d/litespeed.repo

    sed -i "s@${LiteSpeedUrl}@${LiteSpeedRepoUrl}@g" ${LiteSpeedRepo}
  fi

  yum clean all

  if [ "${LiteSpeedV}" != '0' ]; then
    cd /tmp
    echo 'Download OpenLiteSpeed RPM Package'
    if [ "${LiteSpeedV}" = '1' ]; then
      OpenLiteSpeedVersionD=${OpenLiteSpeedVersionStable}
      wget ${LiteSpeedRepoUrl}/centos/8/x86_64/RPMS/${OpenLiteSpeedVersionD}.el8.x86_64.rpm
    elif [ "${LiteSpeedV}" = '2' ];then
      OpenLiteSpeedVersionD=${OpenLiteSpeedVersionEdge}
      wget ${LiteSpeedRepoUrl}/edge/centos/8/x86_64/RPMS/${OpenLiteSpeedVersionD}.el8.x86_64.rpm
    fi
    echo 'Install OLS and libnsl'
    rpm -ivh --nodeps ${OpenLiteSpeedVersionD}.el8.x86_64.rpm
    yum install libnsl -y

    if [ -d "/usr/local/lsws/" ]; then
      echo 'Mkdir vhosts config'
      mkdir -p /usr/local/lsws/conf/vhosts/
    fi

    echo 'Copy OLS config'
    cp -a /tmp/OLStack-yum-${envType}/conf/httpd_config.xml /usr/local/lsws/conf/httpd_config.xml
    cp -a /tmp/OLStack-yum-${envType}/conf/httpd_config.conf /usr/local/lsws/conf/httpd_config.conf
    cp -a /tmp/OLStack-yum-${envType}/conf/docker.conf /usr/local/lsws/conf/templates/docker.conf
    chown -R lsadm:nobody /usr/local/lsws/conf/

    echo 'Mkdir localhost'
    mkdir -p /var/www/vhosts/localhost/{html,logs,certs}
    chown nobody:nobody /var/www/vhosts/localhost/ -R
    cp -a /tmp/OLStack-yum-${envType}/home/demo/public_html/* /var/www/vhosts/localhost/html/

    echo 'Setting Default LSPHP Version'
    case ${phpV} in
      1)
      sed -i "s@lsphp73@lsphp56@g" /usr/local/lsws/conf/httpd_config.conf
      ;;
      2)
      sed -i "s@lsphp73@lsphp70@g" /usr/local/lsws/conf/httpd_config.conf
      ;;
      3)
      sed -i "s@lsphp73@lsphp71@g" /usr/local/lsws/conf/httpd_config.conf
      ;;
      4)
      sed -i "s@lsphp73@lsphp72@g" /usr/local/lsws/conf/httpd_config.conf
      ;;
      5)
      sed -i "s@lsphp73@lsphp73@g" /usr/local/lsws/conf/httpd_config.conf
      ;;
      6)
      sed -i "s@lsphp73@lsphp74@g" /usr/local/lsws/conf/httpd_config.conf
      ;;
      7)
      sed -i "s@lsphp73@lsphp80@g" /usr/local/lsws/conf/httpd_config.conf
      ;;
    esac

  fi

  if [[ "${phpV}" != '0' && "${LiteSpeedV}" != '0' ]]; then
    if [ "${dbV}" = "1" ]; then
      echo 'Install AMySQL'
      cd /var/www/vhosts/localhost/html/
      wget http://amh.sh/file/AMS/amysql-1.6.zip
      unzip -q amysql-1.6.zip
      rm -rf amysql-1.6.zip
      mv amysql-1.6 amysql
      sed -i "s/phpMyAdmin/AMysql/g" /var/www/vhosts/localhost/html/index.html
    elif [ "${dbV}" = "2" ]; then
      echo 'Install Adminer'
      cp -a /tmp/OLStack-yum-${envType}/DB/Adminer /var/www/vhosts/localhost/html/
      sed -i "s/phpMyAdmin/Adminer/g" /var/www/vhosts/localhost/html/index.html
    elif [ "${dbV}" = "3" ]; then
      ## PHP 5.4 仅 PMA 4.0 LTS 支持
      if [[ "${phpV}" = "1" || "${phpV}" = "2" ]]; then
        echo 'Install phpMyAdmin 4.9'
        cd /var/www/vhosts/localhost/html/
        wget ${phpMyAdminURL}/phpMyAdmin/4.9.7/phpMyAdmin-4.9.7-all-languages.tar.gz
        tar xzf phpMyAdmin-4.9.7-all-languages.tar.gz
        rm -rf phpMyAdmin-4.9.7-all-languages.tar.gz
        mv phpMyAdmin-4.9.7-all-languages phpMyAdmin
      ## PHP 5.5-7.0 仅 PMA 4.8 LTS 支持
      #elif [ "${phpV}}" = "3" || "${phpV}" = "4" || "${phpV}" = "5" ]; then
      #  cd /home/demo/public_html
      #  wget ${phpMyAdminURL}/phpMyAdmin/4.8.5/phpMyAdmin-4.8.5-all-languages.zip
      #  https://files.phpmyadmin.net/phpMyAdmin/5.1.0/phpMyAdmin-5.1.0-all-languages.zip
      #  unzip phpMyAdmin-4.8.5-all-languages.zip
      #  rm -rf phpMyAdmin-4.8.5-all-languages.zip
      #  mv phpMyAdmin-4.8.5-all-languages phpMyAdmin
      ## PHP 7.1+ 支持 4.8，5.0+
      else
        echo 'Install phpMyAdmin 5.1'
        cd /var/www/vhosts/localhost/html/
        wget ${phpMyAdminURL}/phpMyAdmin/5.1.0/phpMyAdmin-5.1.0-all-languages.tar.gz
        tar xzf phpMyAdmin-5.1.0-all-languages.tar.gz
        rm -rf phpMyAdmin-5.1.0-all-languages.tar.gz
        mv phpMyAdmin-5.1.0-all-languages phpMyAdmin
      fi
    fi
  fi

  if [ "${dbV}" = "2" ]; then
  echo 'Setup phpMyAdmin'
  mkdir -p /var/www/vhosts/localhost/html/phpMyAdmin/tmp/
  chmod 0777 /var/www/vhosts/localhost/html/phpMyAdmin/tmp/
  cp /var/www/vhosts/localhost/html/phpMyAdmin/libraries/config.default.php /var/www/vhosts/localhost/html/phpMyAdmin/config.inc.php
  #sed -i "s@UploadDir.*@UploadDir'\] = 'upload';@" /var/www/vhosts/localhost/html/phpMyAdmin/config.inc.php
  #sed -i "s@SaveDir.*@SaveDir'\] = 'save';@" /var/www/vhosts/localhost/html/phpMyAdmin/config.inc.php
  #sed -i "s@host'\].*@host'\] = '127.0.0.1';@" /var/www/vhosts/localhost/html/phpMyAdmin/config.inc.php
  sed -i "s@blowfish_secret.*;@blowfish_secret\'\] = \'$(cat /dev/urandom | head -1 | base64 | head -c 45)\';@" /var/www/vhosts/localhost/html/phpMyAdmin/config.inc.php
  fi
  
  showNotice "Start service"

  echo 'Start FirewallD'
  systemctl enable firewalld.service
  systemctl restart firewalld.service

  firewall-cmd --permanent --zone=public --add-service=http
  firewall-cmd --permanent --zone=public --add-service=https
  firewall-cmd --permanent --zone=public --add-port=7080/tcp
  firewall-cmd --reload

  if [ "${mysqlV}" != '0' ]; then
    #if [[ "${mysqlV}" = '1' || "${mysqlV}" = '2' ]]; then
    #  service mysql start
    #else
    echo 'Start DB'
    systemctl enable ${installDB}.service
    systemctl start ${installDB}.service
    #fi
    echo 'Setting DB Root Password'
    mysqladmin -u root password "${mysqlPWD}"
    mysqladmin -u root -p"${mysqlPWD}" -h "localhost" password "${mysqlPWD}"
    mysql -u root -p"${mysqlPWD}" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');DELETE FROM mysql.user WHERE User='';DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';FLUSH PRIVILEGES;"
    if [ "${mysqlV}" = "6" ]; then
    mysql -u root -p"${mysqlPWD}" -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY \"${mysqlPWD}\";FLUSH PRIVILEGES;"
    fi
    ehco 'Add DB Root Password to initialPWD'
    echo "${mysqlPWD}" > /var/www/vhosts/initialPWD.txt
    rm -rf /var/lib/mysql/test
  fi

  if [ "${LiteSpeedV}" != '0' ]; then
    echo 'Setting OLS Admin Password'
    LSPASSRAND=`head -c 100 /dev/urandom | tr -dc a-z0-9A-Z |head -c 16`
    if [ -e /usr/local/lsws/admin/fcgi-bin/admin_php ]; then \
        ENCRYPT_PASS=`/usr/local/lsws/admin/fcgi-bin/admin_php -q /usr/local/lsws/admin/misc/htpasswd.php $LSPASSRAND`
        else ENCRYPT_PASS=`/usr/local/lsws/admin/fcgi-bin/admin_php5 -q /usr/local/lsws/admin/misc/htpasswd.php $LSPASSRAND`
    fi
    echo "llstackadmin:$ENCRYPT_PASS" > /usr/local/lsws/admin/conf/htpasswd 
    touch /root/defaulthtpasswd
    echo "llstackadmin:$LSPASSRAND" > /root/defaulthtpasswd
    /usr/local/lsws/bin/lswsctrl restart >/dev/null
  fi

  #wget -P /root/ https://raw.githubusercontent.com/ivmm/LLStack/master/vhost.sh

  if [[ -f "/usr/sbin/mysqld" || -f "/usr/share/lsphp-default-version" || -f "/usr/local/lsws/bin/openlitespeed" ]]; then
    echo "================================================================"
    echo -e "\\033[42m [OLStack-yum] Install completed. \\033[0m"

    if [ "${LiteSpeedV}" != '0' ]; then
      echo -e "\\033[34m Web Demo Site: \\033[0m http://${ipAddress}"
      echo -e "\\033[34m Web Demo Dir: \\033[0m /home/demo/public_html"
      echo -e "\\033[34m LiteSpeed: \\033[0m /usr/local/lsws/"
      echo -e "\\033[34m LiteSpeed WebAdmin Console URL: \\033[0m http://${ipAddress}:7080"
      echo -e "\\033[34m LiteSpeed WebAdmin Console Username: \\033[0m llstackadmin"
      echo -e "\\033[34m LiteSpeed WebAdmin Console Paasword: \\033[0m $LSPASSRAND"
    fi

    if [ "${phpV}" != '0' ]; then
      case ${phpV} in
      1)
      echo -e "\\033[34m PHP: \\033[0m /etc/opt/remi/php56/"
      ;;
      2)
      echo -e "\\033[34m PHP: \\033[0m /etc/opt/remi/php70/"
      ;;
      3)
      echo -e "\\033[34m PHP: \\033[0m /etc/opt/remi/php71/"
      ;;
      4)
      echo -e "\\033[34m PHP: \\033[0m /etc/opt/remi/php72/"
      ;;
      5)
      echo -e "\\033[34m PHP: \\033[0m /etc/opt/remi/php73/"
      ;;
      6)
      echo -e "\\033[34m PHP: \\033[0m /etc/opt/remi/php74/"
      ;;
      7)
      echo -e "\\033[34m PHP: \\033[0m /etc/opt/remi/php80/"
      ;;
    esac
    fi

    if [[ "${mysqlV}" != '0' && -f "/usr/sbin/mysqld" ]]; then
      if [ "${installDB}" = "mariadb" ]; then
        echo -e "\\033[34m MariaDB Data: \\033[0m /var/lib/mysql/"
        echo -e "\\033[34m MariaDB User: \\033[0m root"
        echo -e "\\033[34m MariaDB Password: \\033[0m ${mysqlPWD}"
      elif [ "${installDB}" = "mysqld" ]; then
        echo -e "\\033[34m MySQL Data: \\033[0m /var/lib/mysql/"
        echo -e "\\033[34m MySQL User: \\033[0m root"
        echo -e "\\033[34m MySQL Password: \\033[0m ${mysqlPWD}"
      fi
    fi

    echo "Start time: ${startDate}"
    echo "Completion time: $(date) (Use: $((($(date +%s)-startDateSecond)/60)) minute)"
    echo "Use: $((($(date +%s)-startDateSecond)/60)) minute"
    echo -e "For more details see \\033[34m https://llstack.com \\033[0m"
    echo "================================================================"
  else
    echo -e "\\033[41m [LLStack] Sorry, Install Failed. \\033[0m"
    echo "Please contact us: https://github.com/LLStack/OLStack-yum/issues"
  fi
}

while :
do
clear 
  echo '    /\  \     /\__\     /\  \     /\  \     /\  \     /\  \     /\__\  '
  echo '   /::\  \   /:/  /    /::\  \    \:\  \   /::\  \   /::\  \   /:/ _/_ '
  echo '  /:/\:\__\ /:/__/    /\:\:\__\   /::\__\ /::\:\__\ /:/\:\__\ /::-"\__\'
  echo '  \:\/:/  / \:\  \    \:\:\/__/  /:/\/__/ \/\::/  / \:\ \/__/ \;:;-",-"'
  echo '   \::/  /   \:\__\    \::/  /   \/__/      /:/  /   \:\__\    |:|  |  '
  echo '    \/__/     \/__/     \/__/               \/__/     \/__/     \|__|  '
  echo ''
  echo -e "For more details see \033[4mhttps://llstack.com\033[0m"
  echo ''
  showNotice 'Please select your operation:'
  echo '1) Install'
  echo '2) Upgrade packages'
  echo '3) Exit'
  read -p 'Select an option [1-3]: ' -r -e operation
  case ${operation} in
    1)
      clear
      runInstall
    exit
    ;;
    2)
      clear
      showNotice "Checking..."
      yum upgrade
    exit
    ;;
    3)
      showNotice "Nothing to do..."
    exit
    ;;
  esac
done
