# =============================================================================
# REQUIRED VARIABLES
# =============================================================================

set :application, "deepisoursoul"
set :domain,      "deepisoursoul.fr"
set :user,        "p85003"
set :deploy_to,   "/home/p85003"

set :keep_releases,  3
set :deploy_via, :remote_cache

# =============================================================================
# SCM OPTIONS
# =============================================================================

default_run_options[:pty] = true
set :scm, :git
set :git_enable_submodules, 1
set :repository,  "git@github.com:polem/deepisoursoul.fr.git"

# =============================================================================
# SSH OPTIONS
# =============================================================================

ssh_options[:forward_agent] = true
set :use_sudo, false           # optional

role :web,        domain
role :app,        domain
role :db,         domain, :primary => true

set :php_bin,           "php"

# Symfony application path
set :app_path,            ""

# Symfony web path
set :web_path,            "www"

# Symfony log path
set :log_path,            app_path + "/log"

# Symfony cache path
set :cache_path,          app_path + "/cache"

# Use AsseticBundle
set :dump_assetic_assets, false

# Whether to use composer to install vendors. This needs :update_vendors to false
set :use_composer, true

# Assets install
set :assets_install, true 

# Dirs that need to remain the same between deploys (shared dirs)
set :shared_children,     [log_path, 'vendor']

# Files that need to remain the same between deploys
set :shared_files,        false

# Asset folders (that need to be timestamped)
set :asset_children,      [web_path + "/css", web_path + "/images", web_path + "/js"]


namespace :deploy do
  desc "Overwrite the start."
  task :start do ; end

  desc "Overwrite the restart."
  task :restart do ; end

  desc "Overwrite the stop task."
  task :stop do ; end


  desc "Symlink static directories and static files that need to remain between deployments."
  task :share_childs do
    if shared_children
      shared_children.each do |link|
        run "mkdir -p #{shared_path}/#{link}"
        run "if [ -d #{release_path}/#{link} ] ; then rm -rf #{release_path}/#{link}; fi"
        run "ln -nfs #{shared_path}/#{link} #{release_path}/#{link}"
      end
    end
    if shared_files
      shared_files.each do |link|
        link_dir = File.dirname("#{shared_path}/#{link}")
        run "mkdir -p #{link_dir}"
        run "touch #{shared_path}/#{link}"
        run "ln -nfs #{shared_path}/#{link} #{release_path}/#{link}"
      end
    end
  end

  desc "Update latest release source path."
  task :finalize_update, :except => { :no_release => true } do
    run "chmod -R g+w #{latest_release}" if fetch(:group_writable, true)
    run "if [ -d #{latest_release}/#{cache_path} ] ; then rm -rf #{latest_release}/#{cache_path}; fi"
    run "mkdir -p #{latest_release}/#{cache_path} && chmod -R 0777 #{latest_release}/#{cache_path}"
    run "mkdir -p #{latest_release}/www/css && chmod -R 0777 #{latest_release}/www/css"
    run "mkdir -p #{latest_release}/www/js && chmod -R 0777 #{latest_release}/www/js"
    run "chmod -R g+w #{latest_release}/#{cache_path}"

    share_childs

    if fetch(:normalize_asset_timestamps, true)
      stamp = Time.now.utc.strftime("%Y%m%d%H%M.%S")
      asset_paths = asset_children.map { |p| "#{latest_release}/#{p}" }.join(" ")
      run "find #{asset_paths} -exec touch -t #{stamp} {} ';'; true", :env => { "TZ" => "UTC" }
    end
  end

  desc "Deploy the application and start it."
  task :cold do
    update
    start
    silex.composer.install
  end

  desc "Override the migrate task;"
  task :migrate do ; end

end

namespace :silex do

  namespace :composer do
    desc "Runs composer install to install vendors from composer.lock file"
    task :install do
      run "cd #{latest_release} && curl -s http://getcomposer.org/installer | #{php_bin}"
      run "cd #{latest_release} && #{php_bin} composer.phar install"
    end
    desc "Runs composer install to install vendors from composer.lock file"
    task :update do
      run "cd #{latest_release} && curl -s http://getcomposer.org/installer | #{php_bin}"
      run "cd #{latest_release} && #{php_bin} composer.phar update"
    end
  end

end

# After finalizing update:
after "deploy:finalize_update" do
end
