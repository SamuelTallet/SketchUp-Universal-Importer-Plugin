# Universal Importer extension for SketchUp 2017 or newer.
# Copyright: © 2023 Samuel Tallet <samuel.tallet at gmail dot com>
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
require 'fileutils'

# Universal Importer plugin namespace.
module UniversalImporter

  # Assimp wrapper.
  #
  # @see https://github.com/assimp/assimp
  module Assimp

    # Returns absolute path to Assimp executable.
    #
    # @param [Boolean] shell_escape Escape executable path with double quotes?
    # @raise [StandardError]
    #
    # @return [String]
    def self.exe(shell_escape = true)

      raise ArgumentError, 'Shell Escape must be a Boolean'\
        unless shell_escape == true || shell_escape == false

      if Sketchup.platform == :platform_osx

        exe_path = File.join(__dir__, 'Applications', 'Assimp', 'Mac', 'assimp')

      elsif Sketchup.platform == :platform_win

        exe_path = File.join(__dir__, 'Applications', 'Assimp', 'Win', 'assimp.exe')

      else
        raise StandardError.new(
          'Unsupported platform: ' + Sketchup.platform.to_s
        )
      end

      if shell_escape
        exe_path = '"' + exe_path + '"'
      end
      
      exe_path

    end

    # Ensures Assimp is executable. Relevant only to macOS.
    def self.make_executable

      FileUtils.chmod('+x', exe(shell_escape = false))

    end

    # Converts a 3D model.
    #
    # @param [String] working_dir
    # @param [String] in_filename
    # @param [String] out_filename
    # @param [String] log_filename
    # @raise [ArgumentError]
    #
    # @raise [StandardError]
    def self.convert_model(working_dir, in_filename, out_filename, log_filename)

      raise ArgumentError, 'Working Dir must be a String' unless working_dir.is_a?(String)
      raise ArgumentError, 'In Filename must be a String' unless in_filename.is_a?(String)
      raise ArgumentError, 'Out Filename must be a String' unless out_filename.is_a?(String)
      raise ArgumentError, 'Log Filename must be a String' unless log_filename.is_a?(String)

      log_path = File.join(working_dir, log_filename)

      # Escapes paths with double quotes, since they can contain spaces.
      working_dir = '"' + working_dir + '"'; in_filename = '"' + in_filename + '"';
      out_filename = '"' + out_filename + '"'; log_filename = '"' + log_filename + '"';

      # We change current directory to workaround Assimp issue with non-ASCII chars in paths.
      if Sketchup.platform == :platform_win
        command = "cd /d #{working_dir} && #{exe} export #{in_filename} #{out_filename} -tri"
      else
        command = "cd #{working_dir} && #{exe} export #{in_filename} #{out_filename} -tri"
      end

      status = system(command)

      if status != true
        system("#{command} > #{log_filename}")

        if File.exist?(log_path)
          result = File.read(log_path) 
        else
          result = 'No log available.'
        end

        raise StandardError.new('Command failed: ' + command + "\n\n" + result)
      end

    end

    # If they exist: extracts embedded textures from a 3D model.
    #
    # @param [String] working_dir
    # @param [String] in_filename
    # @param [String] log_filename
    # @raise [ArgumentError]
    #
    # @raise [StandardError]
    def self.extract_textures(working_dir, in_filename, log_filename)

      raise ArgumentError, 'Working Dir must be a String' unless working_dir.is_a?(String)
      raise ArgumentError, 'In Filename must be a String' unless in_filename.is_a?(String)
      raise ArgumentError, 'Log Filename must be a String' unless log_filename.is_a?(String)

      log_path = File.join(working_dir, log_filename)

      # Escapes paths with double quotes, since they can contain spaces.
      working_dir = '"' + working_dir + '"'; in_filename = '"' + in_filename + '"';
      log_filename = '"' + log_filename + '"'

      if Sketchup.platform == :platform_win
        command = "cd /d #{working_dir} && #{exe} extract #{in_filename}"
      else
        command = "cd #{working_dir} && #{exe} extract #{in_filename}"
      end

      status = system(command)

      if status != true
        system("#{command} > #{log_filename}")

        if File.exist?(log_path)
          result = File.read(log_path) 
        else
          result = 'No log available.'
        end

        raise StandardError.new('Command failed: ' + command + "\n\n" + result)
      end

    end

    # If they exist: gets external texture references of a 3D model.
    #
    # @param [String] working_dir
    # @param [String] in_filename
    # @param [String] log_filename
    # @raise [ArgumentError]
    #
    # @raise [StandardError]
    #
    # @return [Array<String>]
    def self.get_texture_refs(working_dir, in_filename, log_filename)

      raise ArgumentError, 'Working Dir must be a String' unless working_dir.is_a?(String)
      raise ArgumentError, 'In Filename must be a String' unless in_filename.is_a?(String)
      raise ArgumentError, 'Log Filename must be a String' unless log_filename.is_a?(String)

      log_path = File.join(working_dir, log_filename)

      # Escapes paths with double quotes, since they can contain spaces.
      working_dir = '"' + working_dir + '"'; in_filename = '"' + in_filename + '"';
      log_filename = '"' + log_filename + '"'

      texture_refs = []

      if Sketchup.platform == :platform_win
        command = "cd /d #{working_dir} && #{exe} info #{in_filename} > #{log_filename}"
      else
        command = "cd #{working_dir} && #{exe} info #{in_filename} > #{log_filename}"
      end

      status = system(command)

      if status != true
        if File.exist?(log_path)
          result = File.read(log_path) 
        else
          result = 'No log available.'
        end

        raise StandardError.new('Command failed: ' + command + "\n\n" + result)
      end

      info = File.read(log_path)

      if info.include?('Texture Refs:')

        if info.include?('Named Animations:')

          tex_nfo = info.split('Texture Refs:')[1].split('Named Animations:')[0]

        else
          tex_nfo = info.split('Texture Refs:')[1].split('Node hierarchy:')[0]
        end

        tex_nfo.lines.each do |line|

          cleaned_line = line.strip.sub("'", '').sub(/.*\K'/, '')

          # Skips references to embedded textures. Examples: *0, *1
          if !cleaned_line.empty? && !cleaned_line.start_with?('*')
            texture_refs.push(cleaned_line)
          end

        end

      end

      texture_refs.uniq

    end

    # Gets face count of a 3D model.
    #
    # @param [String] working_dir
    # @param [String] log_filename
    # @raise [ArgumentError]
    #
    # @raise [StandardError]
    #
    # @return [Integer]
    def self.get_face_count(working_dir, log_filename)

      raise ArgumentError, 'Working Dir must be a String' unless working_dir.is_a?(String)
      raise ArgumentError, 'Log Filename must be a String' unless log_filename.is_a?(String)

      log_path = File.join(working_dir, log_filename)

      raise "Can't get model face count because following file doesn't exist: #{log_path}"\
        unless File.exist?(log_path)

      face_count = 0
      info = File.read(log_path)

      info.lines.each do |line|

        if line.start_with?('Faces:')
          return line.gsub(/[^0-9]/, '').to_i
        end

      end

      face_count

    end

  end

end
