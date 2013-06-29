require 'railsless-deploy'

set :application, "aaronsmith.co"
set :repository,  "git@bitbucket.org:username/repo.git"

set :scm, :git # You can set :scm explicitly or Capistrano will make an intelligent guess based on known version control directory names
# Or: `accurev`, `bzr`, `cvs`, `darcs`, `git`, `mercurial`, `perforce`, `subversion` or `none`
# set :deploy_via, :remote_cache

role :web, "enter_ip_address"                        # Your HTTP server, Apache/etc
role :app, "enter_ip_address"                          # This may be the same as your `Web` server
role :db,  "enter_ip_address", :primary => true 

set :deploy_to, "/var/www/site_root/"
set :app_path, "/var/www/site_root/current"

set :use_sudo, false

set :user, "sshuser" # user to ssh and act as on remote server
set :runner, "www-data" # user your webserver is running as

set :keep_releases, 3

namespace :wp do
  task :restart_servers do
    run "sudo service apache2 graceful && sudo service varnish restart"
  end
  desc "Symlink settings and files to shared directory. This allows the settings.php and \
    and sites/default/files directory to be correctly linked to the shared directory on a new deployment."
  task :symlink_shared do
    run "ln -nfs #{shared_path}/uploads #{release_path}/wp-content/uploads"
    run "ln -nfs #{shared_path}/wp-config.php #{release_path}/wp-config.php"
  end
  task :permissions do
  	run "sudo chown -R #{user}:#{runner} #{release_path}"
  	run "find #{release_path}/ -type d -exec chmod 0755 {} \\;"
  	run "find #{release_path}/ -type f -exec chmod 0644 {} \\;"
  end
end

before "wp:symlink_shared", "wp:permissions"

before "deploy:finalize_update", "wp:symlink_shared", "wp:restart_servers"

after "deploy:finalize_update", "deploy:cleanup"
