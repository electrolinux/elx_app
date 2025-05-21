# frozen_string_literal: true

require "wisper"
require "elx_app/path_utils"

module ElxApp
  # Helper class to update a section of a file between markers
  class FileSectionUpdater
    include PathUtils
    include Wisper::Publisher

    attr_reader :file_path, :section, :prefix, :begin_marker, :end_marker, :content

    def initialize(file_path:, section:, prefix: "#", content: [])
      raise ArgumentError, "Content must be an array of strings" unless content.is_a?(Array) && content.all? do |line|
        line.is_a?(String) || (line.respond_to?(:to_s) && line.to_s.match?(/\A[^#].+\z/))
      end

      @file_path = file_path
      @section = section
      @prefix = prefix
      @content = content.map(&:to_s)
      @begin_marker, @end_marker = validate_args
    end

    def validate_args
      validate_file_path
      validate_section
      validate_prefix
      validate_content_markers
      ["#{prefix} BEGIN #{section}", "#{prefix} END #{section}"]
    end

    def update
      ensure_writable_file(file_path)
      current_content = File.exist?(file_path) ? File.readlines(file_path, chomp: true) : []
      new_content = update_content(current_content)
      File.write(file_path, "#{new_content.join("\n")}\n")
      broadcast(:after_update, { updated_content: new_content, file_path: file_path })
    end

    private

    def validate_file_path
      raise ArgumentError, "File path must be specified" if file_path.nil? || file_path.empty?
    end

    def validate_section
      raise ArgumentError, "Section must be specified" if section.nil? || section.empty?
    end

    def validate_prefix
      raise ArgumentError, "Prefix must be specified" if prefix.nil? || prefix.empty?
    end

    def validate_content_markers
      marker_regex = /#{Regexp.escape(prefix)} (BEGIN|END) #{Regexp.escape(section)}/
      return unless content.any? { |line| line.to_s.match?(marker_regex) }

      raise ArgumentError, "Content cannot contain markers (#{prefix} BEGIN #{section} or #{prefix} END #{section})"
    end

    def update_content(current_content)
      start_idx, end_idx = find_markers(current_content)
      new_content = prepare_updated_content(current_content, start_idx, end_idx)
      build_updated_content(current_content, start_idx, end_idx, new_content)
    end

    def find_markers(content)
      [content.index(begin_marker), content.index(end_marker)]
    end

    def prepare_updated_content(current_content, start_idx, end_idx)
      event = { existing_content: [], new_content: content.dup, file_path: file_path }
      event[:existing_content] = current_content[start_idx + 1...end_idx] if valid_markers?(start_idx, end_idx)
      broadcast(:before_update, event)
      event[:new_content]
    end

    def valid_markers?(start_idx, end_idx)
      start_idx && end_idx && start_idx < end_idx
    end

    def build_updated_content(current_content, start_idx, end_idx, new_content)
      if valid_markers?(start_idx, end_idx)
        replace_section(current_content, start_idx, end_idx, new_content)
      elsif !start_idx && !end_idx
        current_content + [begin_marker] + new_content + [end_marker]
      else
        raise Error, "Invalid markers: #{begin_marker} and #{end_marker} must both exist and be in correct order"
      end
    end

    def replace_section(current_content, start_idx, end_idx, new_content)
      current_content[0...start_idx] + [begin_marker] + new_content + [end_marker] + current_content[(end_idx + 1)..-1]
    end
  end
end
