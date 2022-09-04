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
require 'fileutils'

# Universal Importer plugin namespace.
module UniversalImporter

  # Assimp wrapper.
  #
  # @see https://github.com/assimp/assimp
  module Assimp

    # Returns absolute path to Assimp executable.
    #
    # @raise [StandardError]
    #
    # @return [String]
    def self.exe

      if Sketchup.platform == :platform_osx

        return File.join(__dir__, '3rd-Party Apps', 'Assimp', 'Mac', 'assimp')

      elsif Sketchup.platform == :platform_win

        return File.join(__dir__, '3rd-Party Apps', 'Assimp', 'Win', 'assimp.exe')

      else

        raise StandardError.new(
          'Unsupported platform: ' + Sketchup.platform.to_s
        )

      end

    end

    # Converts a 3D model.
    #
    # @param [String] in_path
    # @param [String] out_path
    # @param [String] log_path
    # @raise [ArgumentError]
    #
    # @raise [StandardError]
    #
    # @return [nil]
    def self.convert_model(in_path, out_path, log_path)

      raise ArgumentError, 'In Path parameter must be a String.'\
        unless in_path.is_a?(String)

      raise ArgumentError, 'Out Path parameter must be a String.'\
        unless out_path.is_a?(String)

      raise ArgumentError, 'Log Path parameter must be a String.'\
        unless log_path.is_a?(String)

      command = '"' + exe + '" export "' + in_path + '" "' + out_path + '" -tri'
      
      status = system(command)

      if status != true

        system(command + ' > "' + log_path + '"')

        result = 'No log available.'

        result = File.read(log_path) if File.exist?(log_path)

        raise StandardError.new('Command failed: ' + command + "\n\n" + result)

      end

      nil

    end

    # If they exist: extracts embedded textures from a 3D model.
    #
    # @param [String] in_path
    # @param [String] log_path
    # @raise [ArgumentError]
    #
    # @raise [StandardError]
    #
    # @return [nil]
    def self.extract_textures(in_path, log_path)

      raise ArgumentError, 'In Path parameter must be a String.'\
        unless in_path.is_a?(String)

      raise ArgumentError, 'Log Path parameter must be a String.'\
        unless log_path.is_a?(String)

      command = '"' + exe + '" extract "' + in_path + '"'
      
      status = system(command)

      if status != true

        system(command + ' > "' + log_path + '"')

        result = 'No log available.'

        result = File.read(log_path) if File.exist?(log_path)

        raise StandardError.new('Command failed: ' + command + "\n\n" + result)

      end

      nil

    end

    # If they exist: gets texture references of a 3D model.
    #
    # @param [String] in_path
    # @param [String] log_path
    # @raise [ArgumentError]
    #
    # @raise [StandardError]
    #
    # @return [Array<String>]
    def self.get_texture_refs(in_path, log_path)

      raise ArgumentError, 'In Path parameter must be a String.'\
        unless in_path.is_a?(String)

      raise ArgumentError, 'Log Path parameter must be a String.'\
        unless log_path.is_a?(String)

      texture_refs = []

      command = '"' + exe + '" info "' + in_path + '"' + ' > "' + log_path + '"'
      
      status = system(command)

      if status != true

        result = 'No log available.'

        result = File.read(log_path) if File.exist?(log_path)

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

          if !cleaned_line.empty? && !cleaned_line.start_with?('*')

            texture_refs.push(cleaned_line)

          end

        end

      end

      texture_refs.uniq

    end

    # Gets face count of a 3D model.
    #
    # @param [String] log_path
    # @raise [ArgumentError]
    #
    # @raise [StandardError]
    #
    # @return [Integer]
    def self.get_face_count(log_path)

      raise ArgumentError, 'Log Path parameter must be a String.'\
        unless log_path.is_a?(String)

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
