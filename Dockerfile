FROM ubuntu

ENV DEBIAN_FRONTEND noninteractive

RUN dpkg-divert --local --rename --add /sbin/initctl

RUN apt-get update; apt-get -y -q install lsb-release python-software-properties

# Add Sources
RUN add-apt-repository -y ppa:git-core/ppa;\
  apt-add-repository -y ppa:brightbox/ruby-ng;\
  apt-add-repository -y ppa:chris-lea/node.js;\
  echo deb http://us.archive.ubuntu.com/ubuntu/ $(lsb_release -cs) universe multiverse >> /etc/apt/sources.list;\
  echo deb http://us.archive.ubuntu.com/ubuntu/ $(lsb_release -cs)-updates main restricted universe >> /etc/apt/sources.list;\
  echo deb http://security.ubuntu.com/ubuntu $(lsb_release -cs)-security main restricted universe >> /etc/apt/sources.list

# Run upgrades
RUN  echo udev hold | dpkg --set-selections;\
  echo initscripts hold | dpkg --set-selections;\
  echo upstart hold | dpkg --set-selections;\
  apt-get update

# Install dependencies
RUN apt-get install -y -q nginx ruby2.1 ruby2.1-dev ruby-switch make git-core openssh-server redis-server checkinstall libxml2-dev libxslt-dev libicu-dev logrotate libpq-dev sudo git openssl nodejs

RUN echo "install: --no-rdoc --no-ri" > /etc/gemrc;\
  echo "update: --no-rdoc --no-ri " >> /etc/gemrc;\
  ruby-switch --set ruby2.1

# Install bundler
RUN gem install bundler

# Create Git user
RUN adduser --disabled-login --gecos 'GitLab' git

# Install GitLab Shell
RUN cd /home/git;\
  su git -c "git clone https://github.com/gitlabhq/gitlab-shell.git";\
  cd gitlab-shell;\
  su git -c "git checkout v1.9.1";\
  su git -c "cp config.yml.example config.yml";\
  su git -c "./bin/install"

# Install GitLab
RUN cd /home/git;\
  su git -c "git clone https://github.com/gitlabhq/gitlabhq.git gitlab";\
  cd /home/git/gitlab;\
  su git -c "git checkout 6-7-stable"

# Misc configuration stuff
RUN cd /home/git/gitlab;\
  chown -R git tmp/;\
  chown -R git log/;\
  chmod -R u+rwX log/;\
  chmod -R u+rwX tmp/;\
  su git -c "mkdir /home/git/gitlab-satellites";\
  su git -c "mkdir tmp/pids/";\
  su git -c "mkdir tmp/sockets/";\
  chmod -R u+rwX tmp/pids/;\
  chmod -R u+rwX tmp/sockets/;\
  su git -c "mkdir public/uploads";\
  chmod -R u+rwX public/uploads;\
  su git -c "cp config/unicorn.rb.example config/unicorn.rb";\
  su git -c 'sed -ie "s/127.0.0.1:8080/0.0.0.0:8080/g" config/unicorn.rb';\
  su git -c "cp config/initializers/rack_attack.rb.example config/initializers/rack_attack.rb";\
  su git -c 'sed -ie "s/# config.middleware.use Rack::Attack/config.middleware.use Rack::Attack/" config/application.rb';\
  su git -c "git config --global user.name 'GitLab'";\
  su git -c "git config --global user.email 'gitlab@localhost'";\
  su git -c "git config --global core.autocrlf input"

# Limit the number of sidekiq background jobs
RUN cd /home/git/gitlab;\
  sed -i -e 's/\$@/-c 5 \$@/g' script/background_jobs

RUN cd /home/git/gitlab;\
  su git -c "bundle install --deployment --without development test mysql aws"

#Precompile assets, hack workaround because acts_as_taggable tries to initialize database connection
RUN cd /home/git/gitlab;\
  cp config/database.yml.postgresql config/database.yml ;\
  cp config/gitlab.yml.example config/gitlab.yml ;\
  sed -ie "/acts_as_taggable_on/d" app/models/issue.rb ;\
  sed -ie "/acts_as_taggable_on/d" app/models/project.rb ;\
  su git -c "bundle exec rake assets:clean RAILS_ENV=production";\
  su git -c "bundle exec rake assets:precompile RAILS_ENV=production";\
  su git -c "git checkout app/models/issue.rb" ;\
  su git -c "git checkout app/models/project.rb"

# Install init scripts
RUN cd /home/git/gitlab;\
  cp lib/support/init.d/gitlab /etc/init.d/gitlab;\
  chmod +x /etc/init.d/gitlab;\
  update-rc.d gitlab defaults 21

RUN cd /home/git/gitlab;\
  cp lib/support/logrotate/gitlab /etc/logrotate.d/gitlab

EXPOSE 80
EXPOSE 22

ADD gitlab/database.yml /home/git/gitlab/config/database.yml
ADD gitlab/gitlab.yml /home/git/gitlab/config/gitlab.yml
ADD gitlab-shell/config.yml /home/git/gitlab-shell/config.yml
RUN chown git:git /home/git/gitlab/config/database.yml /home/git/gitlab/config/gitlab.yml /home/git/gitlab-shell/config.yml
ADD nginx/nginx.conf /etc/nginx/nginx.conf
ADD start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
