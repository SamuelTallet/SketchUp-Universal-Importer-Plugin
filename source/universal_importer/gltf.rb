# Universal Importer extension for SketchUp 2017 or newer.
# Copyright: © 2019 Samuel Tallet <samuel.tallet arobase gmail.com>
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3.0 of the License, or
# (at your option) any later version.
# 
# If you release a modified version of this program TO THE PUBLIC,
# the GPL requires you to MAKE THE MODIFIED SOURCE CODE AVAILABLE
# to the program's users, UNDER THE GPL.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
# 
# Get a copy of the GPL here: https://www.gnu.org/licenses/gpl.html

raise 'The UIR plugin requires at least Ruby 2.2.0 or SketchUp 2017.'\
  unless RUBY_VERSION.to_f >= 2.2 # SketchUp 2017 includes Ruby 2.2.4.

require 'fileutils'
require 'json'

# Universal Importer plugin namespace.
module UniversalImporter

  # Minimal glTF parser.
  class GlTF

    # Parses a glTF file.
    def initialize(file_path)

      raise ArgumentError, 'File Path parameter must be a String.'\
        unless file_path.is_a?(String)

      file_contents = File.read(file_path)

      @json = JSON.parse(file_contents)

    end

    # Returns buffers paths if they exist.
    #
    # @return [Array<String>]
    def buffers_paths

      output = []

      if @json.key?('buffers')

        @json['buffers'].each do |buffer|

          if buffer.key?('uri') && !buffer['uri'].start_with?('data:')

            output.push(buffer['uri'])

          end

        end

      end

      output

    end

  end

end
