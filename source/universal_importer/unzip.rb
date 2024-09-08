# Universal Importer extension for SketchUp 2017 or newer.
# Copyright: © 2024 Samuel Tallet <samuel.tallet at gmail dot com>
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

  # A wrapper for the Info-ZIP's UnZip utility.
  module UnZip

    # UnZip executable.
    #
    # @raise [RuntimeError]
    # @return [String] Absolute path (escaped for the shell) on Windows, name on macOS.
    def self.executable
      if Sketchup.platform == :platform_win
        path = File.join(__dir__, 'Applications', 'UnZip', 'Win', 'unzip.exe')
        '"' + path + '"'
      elsif Sketchup.platform == :platform_osx
        'unzip' # is available natively on macOS, no need to rely on a local UnZip application.
      else
        raise "unsupported platform: #{Sketchup.platform.to_s}"
      end
    end

    # Extracts a ZIP file. Note: existing files are overwritten during extract.
    #
    # @param [String] zip_file Path (ideally absolute) of the ZIP file to extract.
    # @param [String] directory Path (ideally absolute) of directory where extract the ZIP file.
    # @param [Array<String>] only_files Filenames to extract from the ZIP. Default: all.
    # @param [Array<Integer>] ignore_errors Error codes to ignore if extract fails. Default: none.
    # @raise [ArgumentError]
    #
    # @raise [RuntimeError]
    # @return [Integer]
    def self.extract(zip_file, directory, only_files = [], ignore_errors = [])
      raise ArgumentError, 'zip_file must be a string' unless zip_file.is_a?(String)
      raise ArgumentError, 'directory must be a string' unless directory.is_a?(String)
      raise ArgumentError, 'only_files must be an array' unless only_files.is_a?(Array)

      if !only_files.empty?
        raise ArgumentError, 'only_files must be an array of strings' \
          unless only_files.all? { |filename| filename.is_a?(String) }
      end

      raise ArgumentError, 'ignore_errors must be an array' unless ignore_errors.is_a?(Array)

      if !ignore_errors.empty?
        raise ArgumentError, 'ignore_errors must be an array of integers' \
          unless ignore_errors.all? { |error_code| error_code.is_a?(Integer) }
      end

      # Command and args escaped for the shell.
      command = executable + ' -o "' + zip_file + '"'

      unless only_files.empty?
        # @type [Array<String>]
        files_to_extract = only_files.map { |filename| '"' + filename + '"' }
        command += ' ' + files_to_extract.join(' ')
      end

      command += ' -d "' + directory + '"'
      status = system(command)

      raise "#{command} failed" if nil == status

      if false == status
        if !ignore_errors.empty? && ignore_errors.include?($?.exitstatus)
          return $?.exitstatus # Error ignored.
        end

        raise "#{command} failed with error code #{$?.exitstatus.to_s}"
      end

      0 # No error encountered.
    end

  end

end
