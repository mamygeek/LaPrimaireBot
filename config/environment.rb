ENV['RACK_ENV'] ||= :production
DEBUG=(ENV['RACK_ENV']!='production')

require File.expand_path('../application', __FILE__)
