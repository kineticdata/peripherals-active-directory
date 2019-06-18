# Require the necessary standard libraries
require 'rexml/document'

# Load the JRuby Open SSL library unless it has already been loaded.  This
# prevents multiple handlers using the same library from causing problems.
if not defined?(Jopenssl)
  # Calculate the location of this file
  handler_path = File.expand_path(File.dirname(__FILE__))
  # Calculate the location of our library and add it to the Ruby load path
  library_path = File.join(handler_path, 'vendor/jruby-openssl-0.6/lib')
  $:.unshift library_path
  # Require the library
  require 'openssl'
  # Require the version constant
  require 'jopenssl/version'
end

# Validate the the loaded openssl library is the library that is expected for
# this handler to execute properly.
if not defined?(Jopenssl::Version::VERSION)
  raise "The Jopenssl class does not define the expected VERSION constant."
elsif Jopenssl::Version::VERSION != '0.6'
  raise "Incompatible library version #{Jopenssl::Version::VERSION} for Jopenssl.  Expecting version 0.6."
end

# Load the ruby LDAP library unless it has already been loaded.  This prevents
# multiple handlers using the same library from causing problems.
if not defined?(Net::LDAP)
  # Calculate the location of this file
  handler_path = File.expand_path(File.dirname(__FILE__))
  # Calculate the location of our library and add it to the Ruby load path
  library_path = File.join(handler_path, 'vendor/net-ldap-0.1.1/lib')
  $:.unshift library_path
  # Require the library
  require 'net/ldap'
end

# Validate the the loaded ldap library is the library that is expected for this
# handler to execute properly.
if not defined?(Net::LDAP::VERSION)
  raise "The Net::LDAP class does not define the expected VERSION constant."
elsif Net::LDAP::VERSION != '0.1.1'
  raise "Incompatible library version #{Net::LDAP::VERSION} for Net::LDAP.  Expecting version 0.1.1."
end
