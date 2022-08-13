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

require 'sketchup'

# Universal Importer plugin namespace.
module UniversalImporter

  # File system utilities.
  module FS

    # Creates a hard link.
    #
    # @see https://docs.microsoft.com/en-us/windows/win32/fileio/hard-links-and-junctions
    # @see https://discussions.apple.com/thread/251599508
    #
    # @param [String] link
    # @param [String] original_file
    # @raise [ArgumentError]
    #
    # @raise RuntimeError
    # @return [Boolean, nil] `true` on success, `false` or `nil` on fail.
    def self.create_hard_link(link, original_file)
      
      raise ArgumentError, 'Link must be a String' unless link.is_a?(String)
      raise ArgumentError, 'Original file must be a String' unless original_file.is_a?(String)

      # Wraps paths to link and original file with double quotes, since they can contain spaces.
      link = '"' + link + '"'; original_file = '"' + original_file + '"'

      case Sketchup.platform
      when :platform_win
        # mklink.exe is only available through cmd.exe
        command = "cmd /C mklink /H #{link} #{original_file}"
      when :platform_osx
        command = "ln #{original_file} #{link}"
      else
        raise "Unsupported platform: #{Sketchup.platform.to_s}"
      end

      system(command)

    end

    # Normalizes directory separator in a path depending on current platform.
    #
    # @param [String] path
    # @raise [ArgumentError]
    #
    # @raise RuntimeError
    # @return [String] normalized path.
    def self.normalize_separator(path)

      raise ArgumentError, 'Path must be a String' unless path.is_a?(String)

      case Sketchup.platform
      when :platform_win
        path.gsub('/', '\\')
      when :platform_osx
        path.gsub('\\', '/')
      else
        raise "Unsupported platform: #{Sketchup.platform.to_s}"
      end

    end

  end

end
