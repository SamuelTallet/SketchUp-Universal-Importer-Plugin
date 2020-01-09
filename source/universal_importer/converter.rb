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

  # 3D model converter.
  class Converter

    # Returns absolute path to Assimp executable.
    #
    # @see https://github.com/assimp/assimp
    #
    # @raise [StandardError]
    #
    # @return [String]
    def assimp_exe

      if Sketchup.platform == :platform_osx

        return File.join(__dir__, 'Assimp', 'Mac', 'assimp')

      elsif Sketchup.platform == :platform_win

        return File.join(__dir__, 'Assimp', 'Win', 'assimp.exe')

      else

        raise StandardError.new(
          'Unsupported platform: ' + Sketchup.platform.to_s
        )

      end

    end

    # Returns absolute path to MeshLab application directory.
    #
    # @see https://github.com/cnr-isti-vclab/meshlab
    #
    # @raise [StandardError]
    #
    # @return [String]
    def meshlab_dir

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
    def meshlab_cmd_exe

      if Sketchup.platform == :platform_osx

        return File.join(meshlab_dir, 'MacOS', 'meshlabserver')

      elsif Sketchup.platform == :platform_win

        return File.join(meshlab_dir, 'meshlabserver.exe')

      else

        raise StandardError.new(
          'Unsupported platform: ' + Sketchup.platform.to_s
        )

      end

    end

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

    # Converts a 3D model.
    def initialize

      begin

        return unless import_from_any_format

        import_texture_atlas

        ask_for_poly_reduction

        ask_for_model_height

        prepare_meshlab_script

        copy_to_prog_data_dir

        export_to_obj_format

        fix_atlas_in_obj_export

        apply_polygon_reduction

        if Sketchup.platform == :platform_osx

          export_to_3ds_format

          import_from_3ds_format

        else

          export_to_dae_format

          import_from_dae_format

        end
        
      rescue StandardError => exception
        
        UI.messagebox(
          'Error: ' + exception.message + "\n" + exception.backtrace.first.to_s
        )
        
      end

    end

    # Imports "any" 3D model.
    #
    # @return [Boolean]
    def import_from_any_format

      @import_file_path = UI.openpanel(

        TRANSLATE['Select a 3D Model'], nil, TRANSLATE['3D Models'] +
        '|*.3d;*.3ds;*.3mf;*.ac;*.ac3d;*.acc;*.amf;*.ase;*.ask;' +
        '*.assbin;*.b3d;*.blend;*.bvh;*.cob;*.csm;*.dae;*.dxf;' +
        '*.enff;*.fbx;*.glb;*.gltf;*.hmp;*.ifc;*.ifczip;*.irr;' +
        '*.irrmesh;*.lwo;*.lws;*.lxo;*.md2;*.md3;*.md5anim;' +
        '*.md5camera;*.md5mesh;*.mdc;*.mdl;*.mesh;*.mesh.xml;' +
        '*.mot;*.ms3d;*.ndo;*.nff;*.obj;*.off;*.ogex;*.pk3;' +
        '*.ply;*.pmx;*.prj;*.q3o;*.q3s;*.raw;*.scn;*.sib;*.smd;' +
        '*.stl;*.stp;*.ter;*.uc;*.vta;*.x;*.x3d;*.x3db;*.xgl;' +
        '*.xml;*.zae;*.zgl;||'

      )

      !@import_file_path.nil?

    end

    # Imports optional texture atlas of 3D model.
    #
    # @return [nil, String]
    def import_texture_atlas

      @import_texture_atlas_file_path = UI.openpanel(

        TRANSLATE['Select a Texture Atlas (Optional)'], nil,
        TRANSLATE['Images'] + '|*.jpg;*.png;*.bmp;||'

      )

    end

    # Asks user for polygon reduction.
    #
    # @return [nil]
    def ask_for_poly_reduction

      @poly_reduction_params = nil

      poly_reduction_answer = UI.messagebox(
        TRANSLATE['Do you want to reduce polygon count?'], MB_YESNO
      )

      if poly_reduction_answer == IDYES

        @poly_reduction_params = UI.inputbox(

          [ TRANSLATE['Target face number'] + ' ' ], # Prompt
          [ 60000 ], # Default
          TRANSLATE['Polygon Reduction'] + ' - ' + NAME # Title

        )

      end

      nil

    end

    # Asks user for model height.
    #
    # @return [nil]
    def ask_for_model_height

      model_height_in_cm = UI.inputbox(

        [ TRANSLATE['Model height (cm)'] + ' ' ], # Prompt
        [ 180 ], # Default
        NAME # Title

      )

      if model_height_in_cm.is_a?(Array)

        SESSION[:model_height_in_cm] = model_height_in_cm[0].to_i

      else

        SESSION[:model_height_in_cm] = 180

      end

      nil

    end

    # Prepares "Polygon Reduction" MeshLab script?
    #
    # @return [nil, String]
    def prepare_meshlab_script

      @poly_reduction_meshlab_script = nil

      return nil unless @poly_reduction_params.is_a?(Array)

      mlx = '<!DOCTYPE FilterScript>' + "\n"
      mlx += '<FilterScript>' + "\n"
      mlx += '<filter name="Simplification: Quadric'
      mlx += ' Edge Collapse Decimation (with texture)">' + "\n"
      mlx += '<Param type="RichInt" value="'
      mlx += @poly_reduction_params[0].to_s
      mlx += '" name="TargetFaceNum"/>' + "\n"
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

      @poly_reduction_meshlab_script = mlx

    end

    # Copies 3D model, texture atlas and meshlab script
    # to Universal Importer program data temp directory.
    #
    # XXX Required to avoid invalid characters in path.
    # Assimp doesn't support whitespaces in path (mac).
    #
    # @return [nil]
    def copy_to_prog_data_dir

      FileUtils.mkdir_p(prog_data_dir)\
        unless File.exist?(prog_data_dir)

      SESSION[:temp_dir] = File.join(prog_data_dir, 'tmp')

      FileUtils.remove_dir(SESSION[:temp_dir])\
        if File.exist?(SESSION[:temp_dir])

      FileUtils.copy_entry(
        File.dirname(@import_file_path), # source
        SESSION[:temp_dir] # destination
      )

      if !@import_texture_atlas_file_path.nil?

        FileUtils.cp(
          @import_texture_atlas_file_path,
          SESSION[:temp_dir]
        )

      end

      if @poly_reduction_meshlab_script.is_a?(String)

        File.write(
          File.join(SESSION[:temp_dir], 'poly_reduction.mlx'),
          @poly_reduction_meshlab_script
        )

      end

      temp_import_file_path = File.join(
        SESSION[:temp_dir],
        File.basename(@import_file_path)
      )

      @import_file_path = File.join(
        SESSION[:temp_dir],
        'import' + File.extname(File.basename(temp_import_file_path))
      )

      File.rename(temp_import_file_path, @import_file_path)

      nil

    end

    # Exports 3D model to OBJ format.
    #
    # @raise [StandardError]
    #
    # @return [nil]
    def export_to_obj_format

      @obj_export_file_path = File.join(SESSION[:temp_dir], 'export.obj')

      command =\
        '"' + assimp_exe + '" export "' + 
        @import_file_path + '" "' + @obj_export_file_path + '"'
      
      status = system(command)

      if status != true

        raise StandardError.new('Following command failed: ' + command)

      end

      nil

    end

    # Fixes texture atlas in OBJ export?
    #
    # @return [nil]
    def fix_atlas_in_obj_export

      return if @import_texture_atlas_file_path.nil?

      obj_mtl_export_file_path = File.join(SESSION[:temp_dir], 'export.mtl')

      obj_mtl_export = File.read(obj_mtl_export_file_path)

      obj_mtl_export += "\n"

      obj_mtl_export += 'map_Kd '
      obj_mtl_export += File.basename(@import_texture_atlas_file_path)

      File.write(obj_mtl_export_file_path, obj_mtl_export)

      nil

    end

    # Applies polygon reduction on OBJ export thanks to MeshLab?
    #
    # @raise [StandardError]
    #
    # @return [nil]
    def apply_polygon_reduction

      return nil unless @poly_reduction_meshlab_script.is_a?(String)

      if Sketchup.platform == :platform_osx

        # XXX First, we move to MeshLab application directory to load plugins.
        command =\
          'cd "' + meshlab_dir + '" && ' + 
          '"' + meshlab_cmd_exe + '" -i "' + 
          @obj_export_file_path + '" -o "' + @obj_export_file_path + '" -m wt' +
          ' -s "' + File.join(SESSION[:temp_dir], 'poly_reduction.mlx') + '"'
        

      else

        command =\
          '"' + meshlab_cmd_exe + '" -i "' + 
          @obj_export_file_path + '" -o "' + @obj_export_file_path + '" -m wt' +
          ' -s "' + File.join(SESSION[:temp_dir], 'poly_reduction.mlx') + '"'
        

      end

      status = system(command)

      if status != true

        raise StandardError.new('Following command failed: ' + command)

      end

      nil

    end

    # Exports 3D model to 3DS format.
    #
    # @raise [StandardError]
    #
    # @return [nil]
    def export_to_3ds_format

      @tds_export_file_path = File.join(SESSION[:temp_dir], 'export.3ds')

      command =\
        '"' + assimp_exe + '" export "' +
        @obj_export_file_path + '" "' + @tds_export_file_path + '" -tri'

      status = system(command)

      if status != true

        raise StandardError.new('Following command failed: ' + command)

      end

      nil
      
    end

    # Imports 3D model from 3DS format.
    #
    # @return [Boolean]
    def import_from_3ds_format

      Sketchup.active_model.import(@tds_export_file_path)

    end

    # Exports 3D model to DAE format.
    #
    # @raise [StandardError]
    #
    # @return [nil]
    def export_to_dae_format

      @dae_export_file_path = File.join(SESSION[:temp_dir], 'export.dae')

      command =\
        '"' + assimp_exe + '" export "' +
        @obj_export_file_path + '" "' + @dae_export_file_path + '" -tri'

      status = system(command)

      if status != true

        raise StandardError.new('Following command failed: ' + command)

      end

      nil
      
    end

    # Imports 3D model from DAE format.
    #
    # @return [Boolean]
    def import_from_dae_format

      Sketchup.active_model.import(@dae_export_file_path)

    end

  end

end
