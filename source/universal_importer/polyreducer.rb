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
require 'universal_importer/assimp'
require 'universal_importer/meshlab'

# Universal Importer plugin namespace.
module UniversalImporter

  # 3D model polygon reducer.
  class PolyReducer

    # Returns absolute path to Universal Importer program data directory.
    #
    # @raise [StandardError]
    #
    # @return [String]
    def prog_data_dir

      if Sketchup.platform == :platform_osx

        return File.join(ENV['HOME'], '.UniversalImporter')

      elsif Sketchup.platform == :platform_win

        return File.join(ENV['PROGRAMDATA'], 'Universal Importer')

      else

        raise StandardError.new(
          'Unsupported platform: ' + Sketchup.platform.to_s
        )

      end

    end

    # Reduces polygons of current SketchUp model.
    def initialize

      begin

        # XXX Selection must be empty otherwise DAE export will be VERY slow.
        if !Sketchup.active_model.selection.empty?

          UI.messagebox(TRANSLATE['Selection must be empty!'])
          return

        end

        get_poly_reduc_params

        # Aborts if user cancelled operation.
        return if @poly_reduction_params == false

        face_count_before_reduc

        reset_prog_data_tmp_dir

        convert_from_skp_to_dae

        convert_from_dae_to_obj

        apply_polygon_reduction

        if Sketchup.platform == :platform_osx

          convert_from_obj_to_3ds

          convert_from_3ds_to_skp

        else

          convert_from_obj_to_dae

          convert_from_dae_to_skp

        end
        
      rescue StandardError => exception
        
        UI.messagebox(
          'Universal Importer Error: ' + exception.message +
          "\n" + exception.backtrace.first.to_s + "\n" +
          "\n" + 'Universal Importer Version: ' + VERSION
        )
        
      end

    end

    # Gets polygon reduction parameters.
    #
    # @return [nil]
    def get_poly_reduc_params

      @poly_reduction_params = UI.inputbox(

        [ TRANSLATE['Target face number'] + ' ' ], # Prompt
        [ 40000 ], # Default
        TRANSLATE['Polygon Reduction'] # Title

      )

      nil

    end

    # Memorizes face count before polygon reduction.
    #
    # @return nil
    def face_count_before_reduc

      SESSION[:faces_num_before_reduc] = Sketchup.active_model.number_faces

      nil

    end

    # Resets Universal Importer program data temporary directory.
    #
    # @return [nil]
    def reset_prog_data_tmp_dir

      FileUtils.mkdir_p(prog_data_dir)\
        unless File.exist?(prog_data_dir)

      SESSION[:temp_dir] = File.join(prog_data_dir, 'tmp')

      FileUtils.remove_dir(SESSION[:temp_dir])\
        if File.exist?(SESSION[:temp_dir])

      FileUtils.mkdir_p(SESSION[:temp_dir])

      nil

    end

    # Converts current SketchUp model to DAE format.
    #
    # @return [true, false]
    def convert_from_skp_to_dae

      @dae_export_file_path = File.join(SESSION[:temp_dir], 'export.dae')

      Sketchup.active_model.export(@dae_export_file_path, {

        :triangulated_faces   => true,
        :edges                => false,
        :hidden_geometry      => false,
        :preserve_instancing  => false,
        :texture_maps         => true

      })

    end

    # Converts current SketchUp model to OBJ format.
    #
    # @return [nil]
    def convert_from_dae_to_obj

      @obj_export_file_path = File.join(SESSION[:temp_dir], 'export.obj')

      Assimp.convert_model(
        @dae_export_file_path,
        @obj_export_file_path,
        File.join(SESSION[:temp_dir], 'assimp.log')
      )

    end

    # Applies polygon reduction on OBJ export...
    #
    # @return [nil]
    def apply_polygon_reduction

      obj_mtl_export = File.read(File.join(SESSION[:temp_dir], 'export.mtl'))

      mlx = MeshLab.poly_reduction_script(
        obj_mtl_export.include?('map_Kd'),
        @poly_reduction_params[0].to_i
      )

      File.write(File.join(SESSION[:temp_dir], 'poly_reduction.mlx'), mlx)

      MeshLab.apply_script(
        @obj_export_file_path,
        @obj_export_file_path,
        File.join(SESSION[:temp_dir], 'poly_reduction.mlx'),
        File.join(SESSION[:temp_dir], 'meshlab.log')
      )

    end

    # Converts current SketchUp model to 3DS format.
    #
    # @return [nil]
    def convert_from_obj_to_3ds

      @tds_import_file_path = File.join(SESSION[:temp_dir], 'import.3ds')

      Assimp.convert_model(
        @obj_export_file_path,
        @tds_import_file_path,
        File.join(SESSION[:temp_dir], 'assimp.log')
      )

    end

    # Converts current SketchUp model to SKP format.
    #
    # @return [true, false]
    def convert_from_3ds_to_skp

      Sketchup.active_model.import(@tds_import_file_path)

    end

    # Converts current SketchUp model to DAE format.
    #
    # @return [nil]
    def convert_from_obj_to_dae

      @dae_import_file_path = File.join(SESSION[:temp_dir], 'import.dae')

      Assimp.convert_model(
        @obj_export_file_path,
        @dae_import_file_path,
        File.join(SESSION[:temp_dir], 'assimp.log')
      )

    end

    # Converts current SketchUp model to SKP format.
    #
    # @return [true, false]
    def convert_from_dae_to_skp

      Sketchup.active_model.import(@dae_import_file_path)

    end

  end

end
