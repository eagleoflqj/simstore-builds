#!/usr/bin/env ruby
# Read recipe YAML without evaluating shell text or allowing YAML objects/aliases.
require 'json'
require 'optparse'
require 'pathname'
require 'psych'
require 'uri'

module Manifest
  class Error < StandardError; end

  def self.mapping(value, required, context, optional = [])
    raise Error, "#{context} must be a mapping" unless value.is_a?(Hash)
    required.each do |key|
      raise Error, "#{context}.#{key} is required" unless value.key?(key)
    end
    unknown = value.keys - required - optional
    raise Error, "#{context}: unknown fields #{unknown.join(', ')}" unless unknown.empty?
  end

  def self.string(value, context)
    unless value.is_a?(String) && !value.strip.empty? && value == value.strip && !value.match?(/[\r\n\x00]/)
      raise Error, "#{context} must be a nonempty string"
    end
    value
  end

  def self.version(value, context)
    string(value, context)
    raise Error, "#{context} must be an OS version string" unless value.match?(/\A[1-9]\d*(?:\.\d+){0,2}\z/)
    parts = value.split('.').map(&:to_i)
    parts + [0] * (3 - parts.length)
  end

  def self.check_yaml(node)
    raise Error, 'YAML aliases are not allowed' if node.is_a?(Psych::Nodes::Alias)
    if node.is_a?(Psych::Nodes::Mapping)
      keys = node.children.each_slice(2).map do |key, _|
        raise Error, 'YAML mapping keys must be scalar strings' unless key.is_a?(Psych::Nodes::Scalar)
        key.value
      end
      raise Error, 'Duplicate YAML mapping key' unless keys.uniq.length == keys.length
    end
    (node.children || []).each { |child| check_yaml(child) }
  end

  def self.load(path)
    text = File.read(path)
    tree = Psych.parse_stream(text)
    raise Error, 'Expected exactly one YAML document' unless tree.children.length == 1
    check_yaml(tree)
    data = Psych.safe_load(text, aliases: false)
    mapping(data, %w[id name source build], 'manifest', %w[compatibility])
    id = string(data['id'], 'id')
    raise Error, 'id must contain lowercase letters, digits or hyphens' unless id.match?(/\A[a-z][a-z0-9-]*\z/)
    raise Error, 'id must match the application directory' unless id == File.basename(File.dirname(File.expand_path(path)))
    string(data['name'], 'name')

    source = data['source']
    mapping(source, %w[repository version revision], 'source')
    repository = URI.parse(string(source['repository'], 'source.repository'))
    unless repository.is_a?(URI::HTTPS) && repository.host && !repository.path.empty? &&
           !repository.userinfo && !repository.query && !repository.fragment
      raise Error, 'source.repository must be an HTTPS repository URL without credentials/query/fragment'
    end
    release_version = string(source['version'], 'source.version')
    unless release_version.match?(/\Av?(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\z/)
      raise Error, 'source.version must be a stable [v]MAJOR.MINOR.PATCH version without leading zeros'
    end
    revision = string(source['revision'], 'source.revision')
    raise Error, 'source.revision must be a full 40-character lowercase Git commit' unless revision.match?(/\A[0-9a-f]{40}\z/)

    build = data['build']
    mapping(build, %w[script deploymentTarget], 'build')
    script = string(build['script'], 'build.script')
    relative = Pathname.new(script)
    if relative.absolute? || relative.each_filename.any? { |part| ['.', '..'].include?(part) }
      raise Error, 'build.script must stay inside the application directory'
    end
    directory = File.realpath(File.dirname(path))
    target = File.realpath(File.join(directory, script))
    unless target.start_with?(directory + File::SEPARATOR) && File.file?(target)
      raise Error, 'build.script must be a file inside the application directory'
    end
    deployment = version(build['deploymentTarget'], 'build.deploymentTarget')

    if data.key?('compatibility')
      compatibility = data['compatibility']
      mapping(compatibility, %w[minSimulatorOS], 'compatibility')
      minimum = version(compatibility['minSimulatorOS'], 'compatibility.minSimulatorOS')
      raise Error, 'minSimulatorOS must not be below build.deploymentTarget' if (minimum <=> deployment) < 0
    end
    data
  end
end

if $PROGRAM_NAME == __FILE__
  field = nil
  parser = OptionParser.new do |options|
    options.banner = 'Usage: ruby manifest.rb manifest.yaml [--field source.revision]'
    options.on('--field PATH', 'Print one scalar field without shell evaluation') { |value| field = value }
  end
  begin
    parser.parse!
    raise Manifest::Error, parser.banner unless ARGV.length == 1
    data = Manifest.load(ARGV.first)
    if field
      value = field.split('.').reduce(data) do |node, key|
        raise Manifest::Error, "Unknown field: #{field}" unless node.is_a?(Hash) && node.key?(key)
        node[key]
      end
      raise Manifest::Error, '--field requires a string scalar' unless value.is_a?(String)
      puts value
    else
      puts JSON.pretty_generate(data)
    end
  rescue Manifest::Error, Psych::Exception, URI::InvalidURIError, SystemCallError, OptionParser::ParseError => error
    warn "Manifest FAILED: #{error.message}"
    exit 1
  end
end
