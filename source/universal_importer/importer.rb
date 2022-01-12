# Universal Importer (UIR) extension for SketchUp 2017 or newer.
# Copyright: © 2022 Samuel Tallet <samuel.tallet arobase gmail.com>
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
require 'universal_importer/gltf'
require 'universal_importer/obj'
require 'universal_importer/utils'
require 'universal_importer/assimp'
require 'universal_importer/mtl'
require 'universal_importer/meshlab'

# Universal Importer plugin namespace.
module UniversalImporter

  # 3D model importer.
  class Importer

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

    # Imports a 3D model.
    def initialize

      begin

        import_from_any_format

        # Aborts if user cancelled operation.
        return if @import_file_path.nil?

        ask_for_model_height

        copy_to_prog_data_dir

        export_to_obj_format

        fix_e_tex_in_obj_export

        fix_m_tex_in_obj_export

        ask_for_poly_reduction

        apply_polygon_reduction

        if Sketchup.platform == :platform_osx

          export_to_3ds_format

          import_from_3ds_format

        else

          export_to_dae_format

          fix_faces_in_dae_export

          import_from_dae_format

        end
        
      rescue StandardError => exception
        
        UI.messagebox(
          'Universal Importer Error: ' + exception.message +
          "\n" + exception.backtrace.first.to_s + "\n" +
          "\n" + 'Universal Importer Version: ' + VERSION
        )
        
      end

    end

    # Imports "any" 3D model.
    #
    # @return [nil]
    def import_from_any_format

      @import_file_path = UI.openpanel(

        TRANSLATE['Select a 3D Model'], nil, TRANSLATE['3D Models'] +
        '|' +
        '*.3d;*.3ds;*.3mf;*.ac;*.ac3d;*.acc;*.amf;*.ase;*.ask;*.assbin;*.b3d;*.blend;*.bsp;*.bvh;*.cob;*.csm;*.dae;*.dxf;*.enff;*.fbx;*.glb;*.gltf;*.hmp;*.ifc;*.ifczip;*.irr;*.irrmesh;*.lwo;*.lws;*.lxo;*.md2;*.md3;*.md5anim;*.md5camera;*.md5mesh;*.mdc;*.mdl;*.mesh;*.mesh.xml;*.mot;*.ms3d;*.ndo;*.nff;*.obj;*.off;*.ogex;*.pk3;*.ply;*.pmx;*.prj;*.q3o;*.q3s;*.raw;*.scn;*.sib;*.smd;*.step;*.stl;*.stp;*.ter;*.uc;*.vta;*.x;*.x3d;*.x3db;*.xgl;*.xml;*.zae;*.zgl' +
        ';||'

      )

      SESSION[:source_filename] = File.basename(@import_file_path)\
        unless @import_file_path.nil?

      nil

    end

    # Asks user for model height.
    #
    # @return [nil]
    def ask_for_model_height

      model_height_in_mm = UI.inputbox(

        [ TRANSLATE['Model height (mm)'] + ' ' ], # Prompt
        [ 1800 ], # Default
        NAME # Title

      )

      if model_height_in_mm.is_a?(Array)

        SESSION[:model_height_in_mm] = model_height_in_mm[0].to_i

      else

        SESSION[:model_height_in_mm] = 1800

      end

      nil

    end

    # Copies textures, 3D model & associated files to
    # Universal Importer program data temp directory.
    #
    # XXX Required to avoid invalid characters in path.
    #
    # @return [nil]
    def copy_to_prog_data_dir

      # Memorizes source directory.

      @source_dir = File.dirname(@import_file_path)

      # Resets temp directory.

      FileUtils.mkdir_p(prog_data_dir)\
        unless File.exist?(prog_data_dir)

      SESSION[:temp_dir] = File.join(prog_data_dir, 'tmp')

      FileUtils.remove_dir(SESSION[:temp_dir])\
        if File.exist?(SESSION[:temp_dir])

      FileUtils.mkdir_p(SESSION[:temp_dir])

      # Copies 3D model to temp directory.

      FileUtils.cp(
        @import_file_path, # source
        SESSION[:temp_dir] # destination
      )

      # Renames 3D model without whitespace.
      # XXX Assimp doesn't support whitespaces in path (macOS).

      temp_import_file_path = File.join(
        SESSION[:temp_dir],
        File.basename(@import_file_path)
      )

      @import_file_path = File.join(
        SESSION[:temp_dir],
        'import' + File.extname(File.basename(temp_import_file_path))
      )

      File.rename(temp_import_file_path, @import_file_path)

      # If they exist: copies glTF binary buffers to temp directory.

      if @import_file_path.downcase.end_with?('.gltf')

        gltf = GlTF.new(@import_file_path)

        gltf_buffers_paths = gltf.buffers_paths

        if !gltf_buffers_paths.empty?

          gltf_buffers_paths.each do |buffer_path|

            Utils.mkdir_and_copy_file(
              File.join(@source_dir, buffer_path),
              File.join(SESSION[:temp_dir], buffer_path) # destination
            )

          end

        end

      end

      # If it exists: copies OBJ material library to temp directory.

      if @import_file_path.downcase.end_with?('.obj')

        obj = OBJ.new(@import_file_path)

        obj_mtl_path = obj.mtl_path

        if obj_mtl_path.is_a?(String)

          Utils.mkdir_and_copy_file(
            File.join(@source_dir, obj_mtl_path),
            File.join(SESSION[:temp_dir], obj_mtl_path) # destination
          )

        end

      end

      # If they exist: copies referenced textures to temp directory.

      texture_refs = Assimp.get_texture_refs(
        @import_file_path,
        File.join(SESSION[:temp_dir], 'assimp.nfo')
      )

      if !texture_refs.empty?

        texture_refs.each do |texture_path|

          next unless File.exist?(File.join(@source_dir, texture_path))

          Utils.mkdir_and_copy_file(
            File.join(@source_dir, texture_path),
            File.join(SESSION[:temp_dir], texture_path) # destination
          )

        end

      end

      nil

    end

    # Exports 3D model to OBJ format.
    #
    # @return [nil]
    def export_to_obj_format

      @obj_export_file_path = File.join(SESSION[:temp_dir], 'export.obj')

      Assimp.convert_model(
        @import_file_path,
        @obj_export_file_path,
        File.join(SESSION[:temp_dir], 'assimp.log')
      )

    end

    # If they exist: fixes embedded textures in Assimp OBJ export.
    #
    # @return [nil]
    def fix_e_tex_in_obj_export

      obj_mtl_export_file_path = File.join(SESSION[:temp_dir], 'export.mtl')

      obj_mtl_export = File.read(obj_mtl_export_file_path)

      # If MTL file references at least one embedded texture:
      if obj_mtl_export.include?('*0')

        Assimp.extract_textures(
          @import_file_path,
          File.join(SESSION[:temp_dir], 'assimp.log')
        )

        texture_index = 1000

        1000.times do

          texture_index -= 1

          next if !obj_mtl_export.include?('*' + texture_index.to_s)

          texture_image_base_path = File.join(
            SESSION[:temp_dir], 'import_img' + texture_index.to_s
          )

          if File.exist?(texture_image_base_path + '.jpg')

            obj_mtl_export.gsub!(
              '*' + texture_index.to_s,
              'import_img' + texture_index.to_s + '.jpg'
            )

          elsif File.exist?(texture_image_base_path + '.png')

            obj_mtl_export.gsub!(
              '*' + texture_index.to_s,
              'import_img' + texture_index.to_s + '.png'
            )

          elsif File.exist?(texture_image_base_path + '.bmp')

            obj_mtl_export.gsub!(
              '*' + texture_index.to_s,
              'import_img' + texture_index.to_s + '.bmp'
            )

          elsif File.exist?(texture_image_base_path + '.tga')

            obj_mtl_export.gsub!(
              '*' + texture_index.to_s,
              'import_img' + texture_index.to_s + '.tga'
            )

          elsif File.exist?(texture_image_base_path + '.tif')

            obj_mtl_export.gsub!(
              '*' + texture_index.to_s,
              'import_img' + texture_index.to_s + '.tif'
            )

          end

        end

        File.write(obj_mtl_export_file_path, obj_mtl_export)

      end

      nil

    end

    # If they exist: fixes missing textures in Assimp OBJ export.
    #
    # @return [nil]
    def fix_m_tex_in_obj_export

      obj_mtl_export_file_path = File.join(SESSION[:temp_dir], 'export.mtl')

      mtl = MTL.new(obj_mtl_export_file_path)

      mtl_materials_wo_textures = mtl.materials_wo_textures

      return if mtl_materials_wo_textures.empty?

      mtl_materials_wo_textures.each do |material_name|

        texture_path = UI.openpanel(

          TRANSLATE['Select a Texture for Material:'] + ' ' + material_name,
          nil, TRANSLATE['Images'] + '|*.jpg;*.png;*.bmp;*.tga;*.tif;||'

        )

        # Skips if user cancelled...
        next if texture_path.nil?

        FileUtils.cp(
          texture_path, # source
          SESSION[:temp_dir] # destination
        )

        mtl.set_material_texture(material_name, File.basename(texture_path))

      end

      File.write(obj_mtl_export_file_path, mtl.rebuilt_file_contents)

      nil

    end

    # Asks user for polygon reduction.
    #
    # @return [nil]
    def ask_for_poly_reduction

      @poly_reduction_params = nil

      model_face_count = Assimp.get_face_count(
        File.join(SESSION[:temp_dir], 'assimp.nfo')
      )

      poly_reduction_answer = UI.messagebox(
        TRANSLATE['Model has'] + ' ' + model_face_count.to_s +
        ' ' + TRANSLATE['faces'] + '.' + "\n" +
        TRANSLATE['Reduce polygon count?'], MB_YESNO
      )

      if poly_reduction_answer == IDYES

        @poly_reduction_params = UI.inputbox(

          [ TRANSLATE['Target face number'] + ' ' ], # Prompt
          [ 40000 ], # Default
          TRANSLATE['Polygon Reduction'] + ' - ' + NAME # Title

        )

      end

      nil

    end

    # Applies polygon reduction on Assimp OBJ export.
    #
    # @return [nil]
    def apply_polygon_reduction

      return nil unless @poly_reduction_params.is_a?(Array)

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

    # Exports 3D model to 3DS format.
    #
    # @return [nil]
    def export_to_3ds_format

      @tds_export_file_path = File.join(SESSION[:temp_dir], 'export.3ds')

      Assimp.convert_model(
        @obj_export_file_path,
        @tds_export_file_path,
        File.join(SESSION[:temp_dir], 'assimp.log')
      )

    end

    # Imports 3D model from 3DS format.
    #
    # @return [true, false]
    def import_from_3ds_format

      Sketchup.active_model.import(@tds_export_file_path)

    end

    # Exports 3D model to DAE format.
    #
    # @return [nil]
    def export_to_dae_format

      @dae_export_file_path = File.join(SESSION[:temp_dir], 'export.dae')

      Assimp.convert_model(
        @obj_export_file_path,
        @dae_export_file_path,
        File.join(SESSION[:temp_dir], 'assimp.log')
      )
      
    end

    # Fix faces in DAE export.
    #
    # @return [nil]
    def fix_faces_in_dae_export

      dae_export = File.read(@dae_export_file_path)

      double_sided_face_fix = '<extra><technique profile="GOOGLEEARTH">'
      double_sided_face_fix += '<double_sided>1</double_sided>'
      double_sided_face_fix += "</technique></extra>\n</profile_COMMON>"

      dae_export.gsub!('</profile_COMMON>', double_sided_face_fix)

      File.write(@dae_export_file_path, dae_export)

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
