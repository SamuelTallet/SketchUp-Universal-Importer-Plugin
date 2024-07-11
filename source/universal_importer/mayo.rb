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

  # A wrapper for the Mayo Conv(erter) CLI.
  # 
  # @see https://github.com/fougue/mayo
  module Mayo

    # Absolute path to Mayo Conv executable.
    #
    # @type [String, nil]
    @@executable_path = nil

    # Sets absolute path to Mayo Conv executable.
    # Ensures it has correct permission on macOS.
    #
    # @raise [RuntimeError]
    def self.set_executable_path
      app_dir = File.join(__dir__, 'Applications', 'Mayo')
  
      if Sketchup.platform == :platform_osx
        @@executable_path = File.join(app_dir, 'Mac', 'mayo-conv')
        FileUtils.chmod('+x', @@executable_path)
      elsif Sketchup.platform == :platform_win
        @@executable_path = File.join(app_dir, 'Win', 'mayo-conv.exe')
      else
        raise ('unsupported platform: ' + Sketchup.platform.to_s)
      end
    end

    # Exports a 3D model file with Mayo Conv.
    #
    # @param [String] input_model_path Absolute
    # @param [String] output_model_path Absolute
    # @raise [ArgumentError]
    #
    # @raise [RuntimeError]
    def self.export_model(input_model_path, output_model_path)
      raise ArgumentError, 'input model path must be a string' \
        unless input_model_path.is_a?(String)
      raise ArgumentError, 'output model path must be a string' \
        unless output_model_path.is_a?(String)

      raise 'executable path must be set' if @@executable_path.nil?

      command = '"' + @@executable_path + '"'
      command += ' --export "' + output_model_path + '"'
      command += ' "' + input_model_path + '"'

      status = system(command)

      raise ('command failed: ' + command) unless true == status
    end

  end

end