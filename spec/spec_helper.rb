require File.join(File.dirname(__FILE__), '..', 'chimailmadmin.rb')

require 'rubygems'
require 'sinatra'
require 'rack/test'
require 'spec'
require 'spec/autorun'
require 'spec/interop/test'


ENV['RACK_ENV'] = 'test'