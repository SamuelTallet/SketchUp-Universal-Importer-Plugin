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
    # @param [String] target
    # @raise [ArgumentError]
    #
    # @raise RuntimeError
    # @return [Boolean, nil] `true` on success, `false` or `nil` on fail.
    def self.create_hard_link(link, target)
      
      raise ArgumentError, 'Link must be a String' unless link.is_a?(String)
      raise ArgumentError, 'Target must be a String' unless target.is_a?(String)

      # Wraps link and target with double quotes. Maybe they contain spaces.
      link = '"' + link + '"'; target = '"' + target + '"'

      if Sketchup.platform == :platform_win
        # mklink.exe is only available through cmd.exe
        command = "cmd /C mklink /H #{link} #{target}"
      elsif Sketchup.platform == :platform_osx
        command = "ln #{target} #{link}"
      else
        raise RuntimeError, "Unsupported platform: #{Sketchup.platform.to_s}"
      end

      system(command)

    end

  end

end
