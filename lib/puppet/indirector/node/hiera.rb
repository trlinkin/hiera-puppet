require 'puppet'
require 'puppet/node'
require 'puppet/indirector/plain'
require 'rubygems'
require 'hiera'
require 'hiera/scope'

class Puppet::Node::Hiera < Puppet::Indirector::Plain
  desc "Get node information from Hiera"
  include Puppet::Util

  # Look for external node definitions.
  def find(request)
    node = super or return nil

    setup_hiera()

    populate_node(request.key, node)
  end

  private

# init Hiera
  def setup_hiera()
    configfile = File.join([File.dirname(Puppet.settings[:config]), "hiera.yaml"])

    raise "Hiera config file #{configfile} not readable" unless File.exist?(configfile)
    raise "You need rubygems to use Hiera" unless Puppet.features.rubygems?

    config = YAML.load_file(configfile)
    config[:logger] = "puppet"

    @hiera = Hiera.new(:config => config)
  end

# pull in scoped Hiera results
  def populate_node(key, node)
    hscope = populate_scope(key, node)    

  # get classes
    classes = @hiera.lookup('classes', nil, hscope, nil, :hash) || {}

  # translate namespace resolution operators
    classes.each do |k,v|
      classes[k.gsub('.', '::')] = v
      classes.delete(k) if k =~ /\./
    end    

  # put the things Hiera discovered into our node
    node.classes     = classes
    node.parameters  = @hiera.lookup('parameters', nil, hscope, nil, :hash) || {}

    # TODO: the Hiera lookup for this keeps failing.  debug it
    #node.environment = env if env

  # merge new facts into existing facts
    node.fact_merge
    node
  end

# create a new scope and populate it with facts pulled from the indirector
  def populate_scope(key, node)
  # create a new scope because i'm not sure if/how any existing scope
  # for this node can be retreived
    scope = Puppet::Parser::Scope.new

  # get facts from REST API, or empty hash
    facts = Puppet::Node::Facts.indirection.find(key).values rescue {}

  # add node facts to our bootleg scope
    facts.each do |fact, value|
      scope.setvar(fact, value)
    end

  # return the Hierafied scope
    Hiera::Scope.new(scope)
  end
end
