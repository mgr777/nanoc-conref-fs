require 'yaml'
require 'active_support/core_ext/hash'

require_relative 'conrefifier'

module NanocConrefFS
  module Datafiles
    def self.apply_conditionals(config, path:, content:, rep: :default)
      vars = Conrefifier.file_variables(config[:data_variables], path, rep)
      data_vars = { :page => vars, :site => { :config => config } }

      content = obfuscate_liquid(content, data_vars)
      begin
        doc = YAML.load(content)
      rescue Psych::SyntaxError => e
        STDERR.puts "Could not convert \n#{content}"
        raise "#{e.message}: #{e.inspect}"
      end

      path = path.dup
      path.slice!('data/')
      path.sub!(/\.[yaml]{3,4}\z/, '')
      data_keys = path.split('/')

      # we don't need to create a nested hash for root-level data files
      if data_keys.length == 1
        { data_keys.first => doc }
      else
        create_nested_hash(data_keys, doc)
      end
    end

    def self.create_nested_hash(keys, final)
      keys.reverse.inject do |mem, var|
        if mem == keys.last
          { var => { mem => final } }
        else
          { var => mem }
        end
      end
    end

    def self.collect_data(dir)
      data_files = {}
      Dir["#{dir}/**/*.{yaml,yml}"].each do |filename|
        data_files[filename] = File.read(filename)
      end
      data_files
    end

    def self.process(data_files, config, rep)
      data = {}
      data_files.each_pair do |filename, content|
        conditionals = apply_conditionals(config, path: filename, content: content, rep: rep)
        data = data.deep_merge(conditionals)
      end
      data
    end

    def self.obfuscate_liquid(content, data_vars)
      content.gsub(Conrefifier::BLOCK_SUB) do |match|
        # We must obfuscate Liquid variables while replacing conditionals
        match = match.gsub(/{{/, '~~#~~')
        match = Conrefifier.apply_liquid(match, data_vars)
        match.gsub('~~#~~', '{{')
      end
    end
  end
end
