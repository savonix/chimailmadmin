###
# Program:: http://www.docunext.com/wiki/Sinatra
# Component:: chimailmadmin.rb
# Copyright:: Savonix Corporation
# Author:: Albert L. Lash, IV
# License:: Gnu Affero Public License version 3
# http://www.gnu.org/licenses
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this program; if not, see http://www.gnu.org/licenses
# or write to the Free Software Foundation, Inc., 51 Franklin Street,
# Fifth Floor, Boston, MA 02110-1301 USA
##
require 'sinatra/base'
require 'rack/contrib/config'
require 'rack-rewrite'
require 'builder'
require 'sass'
require 'xml/xslt'
require 'rack-xslview'
require 'rack/cache'
require 'sinatra/xslview'
require 'sinatra/simplerdiscount'
require 'rexml/document'
require 'memcache'
require 'json'
require 'dbi'
require 'net/ssh'
require File.dirname(File.dirname(__FILE__)) + '/svxbox/lib/svxbox' if ENV['RACK_ENV'] == 'development'
require 'svxbox' unless ENV['RACK_ENV'] == 'development'
require File.dirname(File.dirname(__FILE__)) + '/sinatra-stuff/sinatra-bundles/lib/sinatra/bundles' if ENV['RACK_ENV'] == 'development'
require 'sinatra/bundles' unless ENV['RACK_ENV'] == 'development'

module Sinatra
  module ModBox
    include SvxBox::Sinatricus
    include SvxBox::MarkupGuppy
  end
  helpers ModBox
end

# The container for the Chimailmadmin application
module Chimailmadmin

  class << self
    attr_accessor(:conf, :memcdb)
  end

  # Create the app which will run
  def self.new(conf)
    self.conf = conf
    if self.conf[:ccf]
      if File.exists?(self.conf[:ccf])
        myconf = File.open(self.conf[:ccf]) { |f| f.read }
        customconf = eval(myconf)
        self.conf.merge!(customconf)
      end
    end
    if self.conf[:memc_srv]
      self.memcdb = MemCache.new self.conf[:memc_srv], :namespace => self.conf[:memc_ns]
    end
    Main
  end

  # The sub-classed Sinatra application
  class Main < Sinatra::Base

    set :js => 's/js'
    set :css => 's/css'
    register Sinatra::Bundles

    configure do
      set :static => true, :public => 'public'
      set :xslviews => 'views/xsl/'
      set :uripfx => Proc.new { Chimailmadmin.conf[:uripfx] }
      set :started_at => Time.now.to_i

      # Set request.env with application mount path
      use Rack::Config do |env|
        env['analytics_key'] = Chimailmadmin.conf[:analytics_key] if Chimailmadmin.conf[:analytics_key]
        env['RACK_ENV'] = ENV['RACK_ENV']
        env['path_prefix'] = uripfx
        env['link_prefix'] = uripfx
        env['TS'] = Time.now.to_i
      end

      myxslfile = File.open('views/xsl/html_main.xsl') { |f| f.read }
      myxsl = XML::XSLT.new()
      myxsl.xsl = REXML::Document.new myxslfile
      set :xsl, myxsl
      set :xslfile, myxslfile
      set :noxsl, ['/raw/', '/s/img/', '/s/js/']
      set :passenv, ['PATH_INFO', 'RACK_MOUNT_PATH', 'RACK_ENV','link_prefix','path_prefix','analytics_key','TS']

    end
    configure :development do
      set :logging => false, :reload_templates => true
    end
    configure :demo do
      set :logging => true, :reload_templates => false
    end

    # Rewrite app url patterns to static files
    use Rack::Rewrite do
      rewrite Chimailmadmin.conf[:uripfx]+'welcome', '/s/xhtml/welcome.html'
      rewrite Chimailmadmin.conf[:uripfx]+'cma-alias-edit', '/s/xhtml/alias_form.html'
      rewrite %r{#{Chimailmadmin.conf[:uripfx]}cma-mailbox-edit/(.*)}, '/s/xhtml/mailbox_form.html?email=$1'
      rewrite %r{#{Chimailmadmin.conf[:uripfx]}cma-import-(.*)}, '/s/xhtml/import_form.html?type=$1'
      rewrite %r{#{Chimailmadmin.conf[:uripfx]}cma-spamassassin-edit}, '/s/xhtml/spam_spamassassin_form.html?type=$1'
      rewrite %r{#{Chimailmadmin.conf[:uripfx]}cma-access-edit}, '/s/xhtml/spam_acl_form.html?type=$1'
      rewrite Chimailmadmin.conf[:uripfx]+'cma-mailbox-edit', '/s/xhtml/mailbox_form.html'
      rewrite Chimailmadmin.conf[:uripfx]+'cma-server-edit', '/s/xhtml/server_form.html'
      rewrite Chimailmadmin.conf[:uripfx]+'cma-domain-edit', '/s/xhtml/domain_form.html'
      rewrite %r{#{Chimailmadmin.conf[:uripfx]}cma-domain-edit\/(.*)}, '/s/xhtml/domain_form.html?domain=$1'
      rewrite Chimailmadmin.conf[:uripfx]+'cma-access-edit', '/s/xhtml/spam_acl_form.html'
    end

    if ENV['RACK_ENV'] == 'production' && Chimailmadmin.conf[:cache_base]
      use Rack::Cache,
        :verbose     => true,
        :metastore   => Chimailmadmin.conf[:cache_base]+'/meta',
        :entitystore => Chimailmadmin.conf[:cache_base]+'/body'
    end

    # Use Rack-XSLView
    use Rack::XSLView,
      :myxsl => xsl,
      :noxsl => noxsl,
      :passenv => passenv,
      :xslfile => xslfile,
      :reload => ENV['RACK_ENV'] == 'development' ? true : false

    set(:bundle_cache_time,0)
    set(:warm_bundle_cache,0)
    set(:cache_bundles,0)
 
    #stylesheet_bundle(:all, %w(droppy yui-reset-min thickbox))
    javascript_bundle(:all, %w(jquery/jquery jquery/plugins/jquery.url jquery/plugins/jquery.cookiejar jquery/plugins/jquery.metadata jquery/plugins/jquery.tablesorter.min jquery/plugins/jquery.tablesorter.pager jquery/plugins/jquery.cookie jquery/plugins/jquery.tablesorter.cookie jquery/plugins/jquery.droppy))


    # Sinatra Helper Gems
    helpers Sinatra::XSLView
    helpers Sinatra::ModBox
    helpers Sinatra::SimpleRDiscount

    helpers do
      # These should be different based upon development vs. production
      def get_passlist
        ['example.com','example.org','example.net']
      end
      def get_aliases(domain=nil)
        aliases = []
        myalias = Hash.new
        myalias[:id] = 1
        myalias[:alias] = 'bob_hope'
        myalias[:destination] = 'bob.hope'
        myalias[:modified] = Time.now.to_i
        aliases << myalias
        return aliases
      end
      def get_servers(domain=nil)
        servers = []
        server = Hash.new
        server[:id] = 1
        server[:server] = 'Franklin'
        server[:host_name] = 'mx2.example.com'
        server[:modified] = Time.now.to_i
        servers << server
        return servers
      end
      def get_mailboxes(domain=nil)
        if Chimailmadmin.conf[:memc_srv]
          idx_json = Chimailmadmin.memcdb.get('name_index')
        else
          idx_json = '["bill.gates","steve.jobs"]'
        end
        index = JSON.parse(idx_json)
        updex = index.map do |name|
          name.gsub('.',' ').gsub(/\b\w/){$&.upcase}
        end
        return [index, updex]
      end
      def get_domains(domain_group=nil)
        if Chimailmadmin.conf[:memc_srv]
          idx_json = Chimailmadmin.memcdb.get('dig_index')
        else
          idx_json = '["docunext.com"]'
        end
        return JSON.parse(idx_json)
      end
      def get_access_lists
        {'example.com'=>'allow','example.org'=>'allow','microsoft.com'=>'deny'}
      end
    end

    get '/' do
      mredirect 'welcome'
    end

    get '/cma-mailbox-list' do
      @index, @updex = get_mailboxes
      xml = builder :'xml/mailboxes'
      xslview xml, 'mailbox_list.xsl'
    end
    post '/cma-mailbox-post' do
      index = get_mailboxes[0]
      index << params[:email_address]
      Chimailmadmin.memcdb.set('name_index',index.uniq.to_json)
      mredirect 'cma-mailbox-list/'
    end
    get '/cma-mailbox-list/*' do
      @index, @updex = get_mailboxes
      @domain = params[:splat].first
      xml = builder :'xml/mailboxes'
      xslview xml, 'mailbox_list.xsl'
    end
    get '/cma-alias-list' do
      mredirect 'cma-alias-list/'
    end
    get '/cma-alias-list/*' do
      @index = get_aliases
      @domain = params[:splat].first
      xml = builder :'xml/aliases'
      xslview xml, 'alias_list.xsl'
    end
    get '/cma-domain-list' do
      @index = get_domains
      xml = builder :'xml/domains'
      xslview xml, 'domain_list.xsl'
    end
    get '/cma-domain-groups' do
      xml = '<root />'
      xslview xml, 'domain_groups.xsl'
    end
    get '/cma-server-list' do
      @index = get_servers
      xml = builder :'xml/servers'
      xslview xml, 'server_list.xsl'
    end
    get '/cma-access-lists' do
      @index = get_access_lists
      xml = builder :'xml/access_lists'
      xslview xml, 'spam_access_list.xsl'
    end
    get '/cma-sa-prefs' do
      @index = { 'whitelist_to' => get_passlist }
      xml = builder :'xml/sa_prefs'
      xslview xml, 'sa_prefs.xsl'
    end
    # Experiment
    get '/dnu-cma-sa-:pipeline' do
      @prefs = { 'whitelist_to' => get_passlist }
      xml = builder :"xml/sa_#{params[:pipeline]}"
      xslview xml, "sa_#{params[:pipeline]}.xsl"
    end
    get '/cma-info-:info' do
      cache_control :public, :must_revalidate, :max_age => 600
      markdown :"md/cma-#{params[:info]}"
    end
    get '/cma-admin' do
      xslview '<root />', 'admin.xsl', { 'link_prefix' => "#{Chimailmadmin.conf[:uripfx]}"  }
    end
    get '/cma-admin-rr' do
      stdout = '<pre>' << Chimailmadmin.conf[:user] << '@' << Chimailmadmin.conf[:pfhost] << "\n"
      Net::SSH.start(Chimailmadmin.conf[:pfhost], Chimailmadmin.conf[:user]) do |ssh|
        ssh.exec!('sudo cat /etc/postfix/relay_recipients') do |channel, stream, data|
          stdout << data if stream == :stdout
        end
      end
      stdout << '</pre>'
    end
    get '/cma-admin-sa' do
      stdout = '<pre>' << Chimailmadmin.conf[:user] << '@' << Chimailmadmin.conf[:sahost] << "\n"
      Net::SSH.start(Chimailmadmin.conf[:sahost], Chimailmadmin.conf[:user]) do |ssh|
        ssh.exec!('sudo cat /etc/spamassassin/local.cf') do |channel, stream, data|
          stdout << data if stream == :stdout
        end
      end
      stdout << '</pre>'
    end
    get '/runtime/info' do
      cache_control :public, :must_revalidate, :max_age => 60
      @uptime   = (0 + Time.now.to_i - settings.started_at).to_s
      index   = builder :'xml/runtime'
      xslview index, 'runtime.xsl'
    end

    get '/raw/json/cma-mailbox-list' do
      content_type :json
      idx_json, names = get_mailboxes
      idx_json.to_json
    end
    get '/raw/json/cma-domain-list' do
      content_type :json
      idx_json = get_domains.to_json
      idx_json
    end
    not_found do
      cache_control :'no-store', :max_age => 0
      %(<div class="block"><div class="hd"><h2>Error</h2></div><div class="bd">This is nowhere to be found. <a href="#{Chimailmadmin.conf[:uripfx]}">Start over?</a></div></div>)
    end

    get '/s/css/stylesheet.css' do
      cache_control :public, :max_age => 600
      content_type 'text/css', :charset => 'utf-8'
      sass 'css/chimailmadmin'.to_sym
    end
  end

end
