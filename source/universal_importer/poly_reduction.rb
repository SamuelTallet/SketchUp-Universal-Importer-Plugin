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
require 'fileutils'
require 'universal_importer/assimp'
require 'universal_importer/mtl'
require 'universal_importer/meshlab'
require 'universal_importer/collada'

# Universal Importer plugin namespace.
module UniversalImporter

  # 3D model polygon reducer.
  class PolyReduction

    # Completion status and materials names.
    #
    # @see ModelObserver#onPlaceComponent
    attr_reader :completed, :materials_names

    # Reduces polygons of current SketchUp model.
    def initialize

      @completed = false
      
      @temp_dir = File.join(Sketchup.temp_dir, 'Universal Importer')
      @model = Sketchup.active_model

      # Selection must be empty otherwise DAE export will be VERY slow.
      if !@model.selection.empty?
        UI.messagebox(TRANSLATE['Selection must be empty!'])
        return
      end

      UI.messagebox(
        TRANSLATE['Current face count:'] + ' ' + @model.number_faces.to_s
      )

      ask_poly_reduc_params

      # Aborts if user cancelled...
      return if @poly_reduction_params == false

      # Faces number before polygon reduction.
      # @type [Integer]
      @faces_num_before_reduc = @model.number_faces

      recreate_temp_dir

      convert_from_skp_to_dae
      convert_from_dae_to_obj

      # It's crucial to save the materials names now as MeshLab renames them.
      backup_materials_names

      apply_polygon_reduction

      convert_from_obj_to_dae
      COLLADA.fix_double_sided_faces(@dae_import_file_path)
      convert_from_dae_to_skp

      @completed = true

    rescue StandardError => exception
      
      UI.messagebox(
        'Universal Importer Error: ' + exception.message +
        "\n" + exception.backtrace.first.to_s + "\n" +
        "\n" + 'Universal Importer Version: ' + VERSION
      )

      # Deletes temporary directory and files possibly left.
      delete_temp_dir
      
    end

    # Asks user for polygon reduction parameters.
    def ask_poly_reduc_params

      @poly_reduction_params = UI.inputbox(
        [ TRANSLATE['Target face number'] + ' ' ], # Prompt
        [ 40000 ], # Default
        TRANSLATE['Polygon Reduction'] # Title
      )

    end

    # Recreates temporary directory.
    def recreate_temp_dir

      delete_temp_dir
      FileUtils.mkdir_p(@temp_dir)

    end

    # Converts current SketchUp model to DAE format.
    #
    # @return [Boolean]
    def convert_from_skp_to_dae

      @model.export(File.join(@temp_dir, 'export.dae'), {
        :triangulated_faces   => true,
        :edges                => false,
        :hidden_geometry      => false,
        :preserve_instancing  => false,
        :texture_maps         => true
      })

    end

    # Converts current SketchUp model to OBJ format.
    def convert_from_dae_to_obj
      Assimp.convert_model(@temp_dir, 'export.dae', 'export.obj', 'assimp.log')
    end

    # Backups, from the exported OBJ MTL file, the materials names to fix them later.
    #
    # @see ModelObserver#onPlaceComponent
    # @see COLLADA.fix_materials_names
    def backup_materials_names
      exported_obj_mtl = MTL.new(File.join(@temp_dir, 'export.mtl'))

      # Materials names indexed by texture path or color.
      @materials_names = {}

      # For each material in the exported OBJ MTL file...
      exported_obj_mtl.materials.each { |material_name, material|
        # Indexes current material name by texture path:
        if material[:diffuse_texture]
          # The entire path, extension included, to match `Sketchup::Texture#filename`
          texture_absolute_path = File.join(@temp_dir, material[:diffuse_texture])
          @materials_names[texture_absolute_path] = material_name
        # or by color:
        elsif material[:diffuse_color]
          # 4 integer values (RGBA) between 0 and 255, to match `Sketchup::Color#to_a`
          texture_color_integers = [
            (material[:diffuse_color][0] * 255).round, # Red
            (material[:diffuse_color][1] * 255).round, # Green
            (material[:diffuse_color][2] * 255).round, # Blue
            255 # Alpha (opaque)
          ]
          @materials_names[texture_color_integers] = material_name
        end
      }
    end

    # Applies polygon reduction onto OBJ export...
    def apply_polygon_reduction

      # @type [String]
      obj_mtl_export = File.read(File.join(@temp_dir, 'export.mtl'))

      mlx = MeshLab.poly_reduction_script(
        obj_mtl_export.include?('map_Kd'),
        @poly_reduction_params[0].to_i
      )

      File.write(File.join(@temp_dir, 'poly_reduction.mlx'), mlx)

      MeshLab.apply_script(
        @temp_dir,
        'export.obj', # in_filename
        'export.obj', # out_filename
        'poly_reduction.mlx',
        'meshlab.log'
      )

      obj_mtl_export = File.read(File.join(@temp_dir, 'export.obj.mtl'))
      # Disables transparency (Tr 1) in MTL file generated by MeshLab.
      obj_mtl_export.gsub!("\nTr ", "\n# Tr ")
      File.write(File.join(@temp_dir, 'export.obj.mtl'), obj_mtl_export)

    end

    # Converts current SketchUp model to DAE format.
    def convert_from_obj_to_dae
      Assimp.convert_model(@temp_dir, 'export.obj', 'import.dae',  'assimp.log')
      @dae_import_file_path = File.join(@temp_dir, 'import.dae')
    end

    # Converts current SketchUp model to SKP format.
    #
    # @return [Boolean]
    def convert_from_dae_to_skp
      # This option avoids a bad texture mapping and an unexpected face count.
      if Sketchup.version.to_i >= 18
        dae_importer_options = {
          :merge_coplanar_faces => false
        }
      else
        dae_importer_options = false
      end

      @model.import(@dae_import_file_path, dae_importer_options)
    end

    # Last instance of PolyReduction class.
    #
    # @see ModelObserver#onPlaceComponent
    @@last = nil

    # Gets last instance of PolyReduction class.
    #
    # @return [UniversalImporter::PolyReduction, nil]
    def self.last
      @@last
    end

    # Sets or forgets last instance of PolyReduction class.
    #
    # @param [UniversalImporter::PolyReduction, nil] instance
    #
    # @raise [ArgumentError]
    def self.last=(instance)
      raise ArgumentError, 'Instance must be an UniversalImporter::PolyReduction or nil'\
        unless instance.is_a?(PolyReduction) || instance.nil?

      @@last = instance
    end

    # Deletes temporary directory.
    #
    # @see ModelObserver#onPlaceComponent
    def delete_temp_dir
      FileUtils.remove_dir(@temp_dir) if File.exist?(@temp_dir)
    end

    # Displays a summary about face count...
    #
    # @see ModelObserver#onPlaceComponent
    def show_face_count_summary

      UI.messagebox(
        TRANSLATE['Face count before reduction:'] + ' ' +
        @faces_num_before_reduc.to_s + "\n" +
        TRANSLATE['Face count after reduction:'] + ' ' +
        (@model.number_faces - @faces_num_before_reduc).to_s
      )

    end
    
  end

end
