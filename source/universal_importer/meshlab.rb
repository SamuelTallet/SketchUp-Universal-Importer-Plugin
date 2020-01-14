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

require 'sketchup'
require 'fileutils'

# Universal Importer plugin namespace.
module UniversalImporter

  # MeshLab wrapper.
  #
  # @see https://github.com/cnr-isti-vclab/meshlab
  module MeshLab

    # Returns absolute path to MeshLab application directory.
    #
    # @raise [StandardError]
    #
    # @return [String]
    def self.dir

      if Sketchup.platform == :platform_osx

        return File.join(__dir__, 'MeshLab', 'Mac')

      elsif Sketchup.platform == :platform_win

        return File.join(__dir__, 'MeshLab', 'Win')

      else

        raise StandardError.new(
          'Unsupported platform: ' + Sketchup.platform.to_s
        )

      end

    end

    # Returns absolute path to MeshLab command-line executable.
    #
    # @raise [StandardError]
    #
    # @return [String]
    def self.exe

      if Sketchup.platform == :platform_osx

        return File.join(dir, 'MacOS', 'meshlabserver')

      elsif Sketchup.platform == :platform_win

        return File.join(dir, 'meshlabserver.exe')

      else

        raise StandardError.new(
          'Unsupported platform: ' + Sketchup.platform.to_s
        )

      end

    end

    # Returns a polygon reduction script to apply with MeshLab.
    #
    # @param [Boolean] with_texture
    # @param [Integer] target_face_num
    # @raise [ArgumentError]
    # 
    # @return [String]
    def self.poly_reduction_script(with_texture, target_face_num)

      raise ArgumentError, 'With Texture parameter must be true or false.'\
        unless [true, false].include?(with_texture)

      raise ArgumentError, 'Target Face Num. parameter must be an Integer.'\
        unless target_face_num.is_a?(Integer)

      mlx = '<!DOCTYPE FilterScript>' + "\n"
      mlx += '<FilterScript>' + "\n"
      mlx += '<filter name="Simplification: Quadric Edge Collapse Decimation'

      if with_texture

        mlx += ' (with texture)">' + "\n"

      else

        mlx += '">' + "\n"

      end

      mlx += '<Param type="RichInt" value="'
      mlx += target_face_num.to_s + '" name="TargetFaceNum"/>' + "\n"
      mlx += '<Param type="RichFloat" value="0" name="TargetPerc"/>' + "\n"
      mlx += '<Param type="RichFloat" value="1" name="QualityThr"/>' + "\n"
      mlx += '<Param type="RichInt" value="1" name="TextureWeight"/>' + "\n"
      mlx += '<Param type="RichBool" value="true" name="PreserveBoundary"/>'
      mlx += "\n"
      mlx += '<Param type="RichFloat" value="1" name="BoundaryWeight"/>' + "\n"
      mlx += '<Param type="RichBool" value="true" name="OptimalPlacement"/>'
      mlx += "\n"
      mlx += '<Param type="RichBool" value="true" name="PreserveNormal"/>'
      mlx += "\n"
      mlx += '<Param type="RichBool" value="true" name="PlanarSimplification"/>'
      mlx += "\n"
      mlx += '</filter>' + "\n"
      mlx += '</FilterScript>'

      mlx

    end

    # Applies a MeshLab script.
    #
    # @param [String] in_path
    # @param [String] out_path
    # @param [String] script_path
    # @param [String] log_path
    # @raise [ArgumentError]
    #
    # @raise [StandardError]
    #
    # @return [nil]
    def self.apply_script(in_path, out_path, script_path, log_path)

      raise ArgumentError, 'In Path parameter must be a String.'\
        unless in_path.is_a?(String)

      raise ArgumentError, 'Out Path parameter must be a String.'\
        unless out_path.is_a?(String)

      raise ArgumentError, 'Script Path parameter must be a String.'\
        unless script_path.is_a?(String)

      raise ArgumentError, 'Log Path parameter must be a String.'\
        unless log_path.is_a?(String)

      if Sketchup.platform == :platform_osx

        # XXX First, we move to MeshLab application directory to load plugins.
        command =\
          'cd "' + dir + '" && ' + 
          '"' + exe + '" -i "' + 
          in_path + '" -o "' + out_path + '" -m wt' +
          ' -s "' + script_path + '"'
        
      else

        command =\
          '"' + exe + '" -i "' + 
          in_path + '" -o "' + out_path + '" -m wt' +
          ' -s "' + script_path + '"'
        
      end

      status = system(command)

      if status != true

        system(command + ' > "' + log_path + '"')

        result = 'No log available.'

        result = File.read(log_path) if File.exist?(log_path)

        raise StandardError.new('Command failed: ' + command + "\n\n" + result)

      end

      nil

    end

  end

end
