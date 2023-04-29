#Script de instalação de bacula,mysql e baculum no debian 11.
#Skykeer- 27/04/2023
#Versão 1.3

#!/bin/bash

# INSTALANDO DEPENDENCIAS

apt install vim make gcc build-essential perl unp mc mtx zlib1g-dev lzop liblzo2-dev sudo gawk gdb libacl1 libacl1-dev libssl-dev lsscsi apt-transport-https pkg-config wget curl -y 

# COLETANDO INFORMAÇÔES DE SENHA

# SENHA DO ROOT NO BANCO MYSQL
while true; do
    senha1=$(whiptail --title "Informe a senha do root para o Banco MYSQL" --passwordbox "Digite sua senha e escolha OK para continuar." --fb 10 50 3>&1 1>&2 2>&3)
    retorno=$?
    if [ $retorno -ne 0 ]; then
      echo "Script encerrado pelo usuário."
      exit
    fi

    senha2=$(whiptail --title "Confirme sua senha" --passwordbox "Digite novamente para confirma-la." --fb 10 50 3>&1 1>&2 2>&3)
    retorno=$?
    if [ $retorno -ne 0 ]; then
      echo "Script encerrado pelo usuário."
      exit
    fi

    if [ $senha1 = $senha2 ]; then
      DBPASSWD=$senha1
      break
    else
      whiptail --title "Senhas diferentes" --msgbox "As senhas não coincidem. Por favor, tente novamente." --fb 10 50
    fi
done

sleep 2

# COLETA SENHA DO BACULA NO BANCO MYSQL
while true; do
    senha1=$(whiptail --title "Informe a senha para o usuario Bacula do banco Mysql" --passwordbox "Digite sua senha e escolha OK para continuar." --fb 10 50 3>&1 1>&2 2>&3)
    retorno=$?
    if [ $retorno -ne 0 ]; then
      echo "Script encerrado pelo usuário."
      exit
    fi

    senha2=$(whiptail --title "Confirme sua senha" --passwordbox "Digite novamente para confirma-la." --fb 10 50 3>&1 1>&2 2>&3)
    retorno=$?
    if [ $retorno -ne 0 ]; then
      echo "Script encerrado pelo usuário."
      exit
    fi

    if [ $senha1 = $senha2 ]; then
      DBPASSWDBACULA=$senha2
      break
    else
      whiptail --title "Senhas diferentes" --msgbox "As senhas não coincidem. Por favor, tente novamente." --fb 10 50
    fi
done

sleep 2

# COLETA IP DO SERVIDOR
IP_SERVIDOR=$(whiptail --title "IP do servidor" --inputbox "Digite o IP do servidor" --fb 10 50 3>&1 1>&2 2>&3)
retorno=$?
if [ $retorno -ne 0 ]; then
  echo "Script encerrado pelo usuário."
  exit
fi

#DEFININDO VERSÃO DO BACULA A SER INSTALADO

# baixa a página e extrai as versões
versions=$(curl -s https://sourceforge.net/projects/bacula/files/bacula/ | grep -Po '(?<=title=")[0-9]{1,2}\.[0-9]{1,2}\.[0-9]{1,2}' | sort -rV)

# filtra as versões para obter apenas as mais recentes de cada série
filtered_versions=$(echo "$versions" | sort -t. -k1,1nr -k2,2nr -k3,3nr | awk -F. '!a[$1"."$2]++' | awk -F. '!b[$1]++')

# armazena cada versão em uma variável
ver_1=$(echo "$filtered_versions" | sed -n '1p')
ver_2=$(echo "$filtered_versions" | sed -n '2p')
ver_3=$(echo "$filtered_versions" | sed -n '3p')

# exibe as versões armazenadas nas variáveis
echo "Versão 1: $ver_1"
echo "Versão 2: $ver_2"
echo "Versão 3: $ver_3"

# mostra a caixa de diálogo com as opções
while true; do
  OPCOES_SELECIONADAS=$(whiptail --title "Escolha uma opção" --separate-output --radiolist "Selecione a versão do Bacula:" 15 60 3 \
  "$ver_1" "" OFF \
  "$ver_2" "" OFF \
  "$ver_3" "" OFF 3>&1 1>&2 2>&3)

  if [ $? -ne 0 ]; then
    exit
  fi

  if [ -z "$OPCOES_SELECIONADAS" ]; then
    whiptail --title "Erro" --msgbox "Por favor, selecione pelo menos uma opção antes de continuar." 10 60
  else
    VERS_BACULA=$(echo "$OPCOES_SELECIONADAS" | tr -d -c '[:digit:].')
    break
  fi
done

# BAIXAR PACOTE .DEB DO MYSQL

#cd /tmp
wget https://dev.mysql.com/get/mysql-apt-config_0.8.22-1_all.deb

# INSTALAR REPOSITORIO DO MYSQL

apt install ./mysql-apt-config_0.8.22-1_all.deb
apt update

# INSTALAR MYSQL

apt install mysql-server libmysqlclient-dev -y

# INSTALAR O MYSQL SECURE INSTALLATION

mysql_secure_installation --password="$DBPASSWD"<< EOF

        y
        0
        n
        y
        y
        y
        y
EOF
sleep 2

# CRIAR USUARIO E DAR PRIVILEGIOS NO MYSQL

mysql -u root -p"$DBPASSWD" -e "CREATE USER 'bacula'@'%' IDENTIFIED BY '$DBPASSWDBACULA';"
mysql -u root -p"$DBPASSWD" -e "GRANT ALL PRIVILEGES ON *.* TO 'bacula'@'%';"
mysql -u root -p"$DBPASSWD" -e "FLUSH PRIVILEGES;"

# REINICIAR O SERVIÇO MYSQL

systemctl restart mysql.service

# COLOCAR O SERVIÇO DO MYSQL PARA INICIAR JUNTO COM O SISTEMA

systemctl enable mysql.service

# BAIXAR E DESCOMPACTAR PACOTE BACULA

cd /tmp
wget --no-check-certificate https://sourceforge.net/projects/bacula/files/bacula/$VERS_BACULA/bacula-$VERS_BACULA.tar.gz
tar xvzf bacula-$VERS_BACULA.tar.gz

# PREPARE AS CONFIGURAÇÔES DO BACULA

cd bacula-$VERS_BACULA
./configure \
--enable-smartalloc \
--with-mysql \
--with-db-user=bacula \
--with-db-password=$DBPASSWDBACULA \
--with-db-port=3306 \
--with-openssl \
--with-readline=/usr/include/readline \
--sysconfdir=/etc/bacula \
--bindir=/usr/bin \
--sbindir=/usr/sbin \
--with-scriptdir=/etc/bacula/scripts \
--with-plugindir=/etc/bacula/plugins \
--with-pid-dir=/var/run \
--with-subsys-dir=/etc/bacula/working \
--with-working-dir=/etc/bacula/working \
--with-bsrdir=/etc/bacula/bootstrap \
--with-basename=bacula \
--with-hostname=$IP_SERVIDOR \
--with-systemd \
--disable-conio \
--disable-nls \
--with-logdir=/var/log/bacula

# COMPILE E INSTALE O BACULA

make -j 8
make install

# DE PERMISSÔES NO DIRETORIO DO BACULA

chmod -R 775 /etc/bacula

# CRIE AS TABELAS DO BANCO DO BACULA

/etc/bacula/scripts/create_mysql_database -u root --password="$DBPASSWD"
/etc/bacula/scripts/make_mysql_tables -u root --password="$DBPASSWD"
/etc/bacula/scripts/grant_mysql_privileges -u root --password="$DBPASSWD"

# RESTARTE O BACULA

bacula restart
bacula status

##INSTALAÇÂO BACULUM

#MOVER PARA O DIRETORIO TMP
cd /tmp

#INSTALAR PHP 7.3 OUTROS PACOTES

apt install php7.3-{common,bcmath,bz2,intl,gd,mbstring,mysql,zip,curl,xml,ldap} -y
apt install apache2 libapache2-mod-php7.3 -y

#BAIXAR O REPOSITORIO DO BACULUM
wget -qO - http://bacula.org/downloads/baculum/baculum.pub | apt-key add -

cat <<EOF >/etc/apt/sources.list.d/baculum.list
deb [ arch=amd64 ] http://bacula.org/downloads/baculum/stable-11/debian bullseye main
deb-src http://bacula.org/downloads/baculum/stable-11/debian bullseye main
EOF

#ATUALIAR PACOTES
apt update

#INSTALAR BACULUM
apt install baculum-api baculum-api-apache2 baculum-common bacula-console baculum-web baculum-web-apache2 -y

#DAR AS DEVIDAS PERMISSÔES
cat <<EOF >/etc/sudoers.d/baculum
www-data ALL=NOPASSWD: /usr/sbin/bconsole
www-data ALL=NOPASSWD: /etc/bacula/confapi
www-data ALL=NOPASSWD: /usr/sbin/bdirjson
www-data ALL=NOPASSWD: /usr/sbin/bbconsjson
www-data ALL=NOPASSWD: /usr/sbin/bfdjson
www-data ALL=NOPASSWD: /usr/sbin/bsdjson
www-data ALL=NOPASSWD: /usr/bin/systemctl
EOF

usermod -aG bacula www-data 
chown -R www-data:bacula /etc/bacula

a2enmod rewrite ldap
a2ensite baculum-web baculum-api
systemctl restart apache2
