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

  # MeshLab wrapper.
  #
  # @see https://github.com/cnr-isti-vclab/meshlab
  module MeshLab

    # Returns absolute path to MeshLab command-line executable.
    #
    # @raise [StandardError]
    #
    # @return [String]
    def self.exe

      if Sketchup.platform == :platform_osx

        return File.join(__dir__, 'Applications', 'MeshLab', 'Mac', 'MacOS', 'meshlabserver')

      elsif Sketchup.platform == :platform_win

        return File.join(__dir__, 'Applications', 'MeshLab', 'Win', 'meshlabserver.exe')

      else
        raise StandardError.new('Unsupported platform: ' + Sketchup.platform.to_s)
      end

    end

    # Ensures MeshLab is executable. Relevant only to macOS.
    def self.make_executable

      FileUtils.chmod('+x', exe)

    end

    # Returns a polygon reduction script to apply with MeshLab.
    #
    # @param [Boolean] with_texture
    # @param [Integer] target_face_num
    # @raise [ArgumentError]
    # 
    # @return [String]
    def self.poly_reduction_script(with_texture, target_face_num)

      raise ArgumentError, 'With Texture must be a Boolean' unless [true, false].include?(with_texture)
      raise ArgumentError, 'Target Face Num. must be an Integer' unless target_face_num.is_a?(Integer)

      mlx = '<!DOCTYPE FilterScript>' + "\n"
      mlx += '<FilterScript>' + "\n"
      mlx += '<filter name="Remove Unreferenced Vertices"/>' + "\n"
      mlx += '<filter name="Remove Duplicate Vertices"/>' + "\n"
      mlx += '<filter name="Remove Duplicate Faces"/>' + "\n"
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
      mlx += '<Param type="RichBool" value="true" name="PreserveBoundary"/>' + "\n"
      mlx += '<Param type="RichFloat" value="1" name="BoundaryWeight"/>' + "\n"
      mlx += '<Param type="RichBool" value="true" name="OptimalPlacement"/>' + "\n"
      mlx += '<Param type="RichBool" value="true" name="PreserveNormal"/>' + "\n"
      mlx += '<Param type="RichBool" value="true" name="PlanarSimplification"/>' + "\n"
      mlx += '<Param type="RichBool" value="true" name="AutoClean"/>' + "\n"
      mlx += '</filter>' + "\n"
      mlx += '</FilterScript>'

      mlx

    end

    # Applies a MeshLab script.
    #
    # @param [String] working_dir
    # @param [String] in_filename
    # @param [String] out_filename
    # @param [String] mlx_filename
    # @param [String] log_filename
    # @raise [ArgumentError]
    #
    # @raise [StandardError]
    def self.apply_script(working_dir, in_filename, out_filename, mlx_filename, log_filename)

      raise ArgumentError, 'Working Dir must be a String' unless working_dir.is_a?(String)
      raise ArgumentError, 'In Filename must be a String' unless in_filename.is_a?(String)
      raise ArgumentError, 'Out Filename must be a String' unless out_filename.is_a?(String)
      raise ArgumentError, 'MLX Filename must be a String' unless mlx_filename.is_a?(String)
      raise ArgumentError, 'Log Filename must be a String' unless log_filename.is_a?(String)

      # We change current directory to workaround MeshLab issue with non-ASCII chars in paths.
      if Sketchup.platform == :platform_win
        command = 'cd /d "' + working_dir + '" && ' + 
        '"' + exe + '" -i "' + in_filename +
        '" -o "' + out_filename + '" -m wt' +
        ' -s "' + mlx_filename + '"'
      else
        command = 'cd "' + working_dir + '" && ' + 
        '"' + exe + '" -i "' + in_filename +
        '" -o "' + out_filename + '" -m wt' +
        ' -s "' + mlx_filename + '"'
      end

      status = system(command)

      if status != true
        system(command + ' > "' + log_filename + '"')

        log_path = File.join(working_dir, log_filename)

        if File.exist?(log_path)
          result = File.read(log_path) 
        else
          result = 'No log available.'
        end

        raise StandardError.new('Command failed: ' + command + "\n\n" + result)
      end

    end

  end

end
