ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup"
require "bootsnap/setup" unless ENV["DISABLE_BOOTSNAP"] == "1"
