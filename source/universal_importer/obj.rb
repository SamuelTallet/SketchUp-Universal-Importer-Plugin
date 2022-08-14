# Universal Importer extension for SketchUp 2017 or newer.
# Copyright: © 2022 Samuel Tallet <samuel.tallet at gmail dot com>
# 
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation, either version 3.0 of the License, or (at your option) any later version.
# 
# If you release a modified version of this program TO THE PUBLIC, the GPL requires you to MAKE THE MODIFIED SOURCE CODE
# AVAILABLE to the program's users, UNDER THE GPL.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# 
# Get a copy of the GPL here: https://www.gnu.org/licenses/gpl.html

require 'fileutils'

# Universal Importer plugin namespace.
module UniversalImporter

  # Minimal OBJ parser. @deprecated
  class OBJ

    # Parses an OBJ file.
    def initialize(file_path)

      raise ArgumentError, 'File Path parameter must be a String.'\
        unless file_path.is_a?(String)

      @file_contents = File.read(file_path)

    end

    # Returns MTL path if it exists.
    #
    # @return [String, nil]
    def mtl_path

      @file_contents.lines.each do |line|

        if line.start_with?('mtllib')
        
          return line.sub('mtllib', '').strip.sub('./', '')

        end

      end

      nil

    end

  end

end
