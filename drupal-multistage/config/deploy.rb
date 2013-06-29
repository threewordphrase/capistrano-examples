require 'capistrano/ext/multistage'
require 'rubygems'
require 'railsless-deploy'

set :theme_folder, "theme_folder_name"
set :scm, :git
set :repository,  "git@github.com:user/repo_name.git"
set :deploy_via, :remote_cache
set :stages, %w(staging production)
set :default_stage, "staging"
role :web, "enter_ip_address"                          # Your HTTP server, Apache/etc
role :app, "enter_ip_address"                          # This may be the same as your `Web` server
role :db,  "enter_ip_address", :primary => true 
# set :port, '4022'
set :user, "sshuser"#the user to ssh into the server and act as
set :runner, "www-data"#the user your webserver is running as
set :use_sudo, false
set :keep_releases, 3

default_run_options[:pty] = true
default_run_options[:shell] = false

namespace :deploy do
  task :cleanup, :except => { :no_release => true } do
    count = fetch(:keep_releases, 5).to_i
    try_sudo "ls -1dt #{releases_path}/* | tail -n +#{count + 1} | #{try_sudo} xargs rm -rf"
  end
end

namespace :drupal do
  task :backup_db do
  	run "cd #{current_release} && drush cc all && drush sql-dump -y --result-file=#{current_release}/cap_backup.sql"
  end
  task :rollback_db do
  	run "cd #{previous_release} && drush sql-cli < #{previous_release}/cap_backup.sql && rm #{previous_release}/cap_backup.sql"
  end
  task :restart_apache do
    run "sudo service apache2 graceful"
  end
  desc "Symlink settings and files to shared directory. This allows the settings.php and \
    and sites/default/files directory to be correctly linked to the shared directory on a new deployment."
  task :symlink_shared do
    ["files", "settings.php"].each do |asset|
      run "ln -nfs #{shared_path}/#{asset} #{release_path}/sites/default/#{asset}"
    end
  end
  task :compile_sass do
  	run "compass compile #{release_path}/sites/all/themes/#{theme_folder}"
  end
  task :migrations do
  	run "cd #{release_path} && drush updb -y"
  end
  task :feature_updates do
  	run "cd #{release_path} && drush cc all && drush fra -y"
  end
  task :permissions do
    run "sudo chown -R #{user}:#{runner} #{release_path}"
    run "find #{release_path}/ -type d -exec chmod u=rwx,g=rx,o= '{}' \\;"
    run "find #{release_path}/ -type f -exec chmod u=rw,g=r,o= '{}' \\;"
  end
end

before "deploy", "drupal:backup_db"

before "drupal:symlink_shared", "drupal:permissions"

before "deploy:finalize_update", "drupal:symlink_shared", "drupal:compile_sass"

after "drupal:symlink_shared", "drupal:migrations", "drupal:feature_updates"

after "deploy:rollback", "drupal:rollback_db", "drupal:restart_apache"

after "deploy:finalize_update", "drupal:restart_apache", "deploy:cleanup"
