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
require 'universal_importer/gltf'
require 'universal_importer/obj'
require 'universal_importer/utils'
require 'universal_importer/fs'
require 'universal_importer/assimp'
require 'universal_importer/mtl'
require 'universal_importer/meshlab'
require 'universal_importer/donate'

# Universal Importer plugin namespace.
module UniversalImporter

  # 3D model importer.
  class Importer

    # Initializes options with default values.
    @@options = {
      :propose_polygon_reduction? => true,
      :claim_missing_textures? => false
    }

    # Sets "Propose polygon reduction" option.
    # 
    # @param [Boolean] yes_or_no
    #
    # @raise [ArgumentError]
    def self.propose_polygon_reduction=(yes_or_no)
      raise ArgumentError, 'Yes or No must be a Boolean'\
        unless yes_or_no == true || yes_or_no == false

      @@options[:propose_polygon_reduction?] = yes_or_no
    end

    # Gets "Propose polygon reduction" option.
    #
    # @return [Boolean]
    def self.propose_polygon_reduction?
      @@options[:propose_polygon_reduction?]
    end

    # Sets "Claim missing textures" option.
    # 
    # @param [Boolean] yes_or_no
    #
    # @raise [ArgumentError]
    def self.claim_missing_textures=(yes_or_no)
      raise ArgumentError, 'Yes or No must be a Boolean'\
        unless yes_or_no == true || yes_or_no == false

      @@options[:claim_missing_textures?] = yes_or_no
    end

    # Gets "Claim missing textures" option.
    #
    # @return [Boolean]
    def self.claim_missing_textures?
      @@options[:claim_missing_textures?]
    end

    # Returns absolute path to Universal Importer program data directory.
    #
    # @deprecated
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
        raise StandardError.new('Unsupported platform: ' + Sketchup.platform.to_s)
      end

    end

    # Imports a 3D model.
    def initialize

      begin

        import_from_any_format

        # Aborts if user cancelled import.
        return if @import_file_path.nil?

        @source_dir = File.dirname(@import_file_path)
        copy_to_program_data_dir

        export_to_obj_format
        fix_embedded_tex_in_obj_export
        fix_referenced_tex_in_inter_mtl

        ask_for_missing_tex_in_obj_export if @@options[:claim_missing_textures?]

        if @@options[:propose_polygon_reduction?]
          ask_for_polygon_reduction
          apply_polygon_reduction
        end

        # @todo Remove this @deprecated hack?
        #ask_for_model_height

        export_to_dae_format
        fix_faces_in_dae_export
        import_from_dae_format

        increment_imports_counter

        # Invites user to donate after 5, 25, 50 and every 100 completed imports.
        if [5, 25, 50].include?(@imports_counter) || (@imports_counter % 100) == 0
          Donate.invitation_planned = true
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
    def import_from_any_format

      @import_file_path = UI.openpanel(

        TRANSLATE['Select a 3D Model'], nil, TRANSLATE['3D Models'] +
        '|' +
        '*.3d;*.3ds;*.3mf;*.ac;*.ac3d;*.acc;*.amf;*.ase;*.ask;*.assbin;*.b3d;*.blend;*.bsp;*.bvh;*.cob;*.csm;*.dae;*.dxf;*.enff;*.fbx;*.glb;*.gltf;*.hmp;*.ifc;*.ifczip;*.irr;*.irrmesh;*.lwo;*.lws;*.lxo;*.md2;*.md3;*.md5anim;*.md5camera;*.md5mesh;*.mdc;*.mdl;*.mesh;*.mesh.xml;*.mot;*.ms3d;*.ndo;*.nff;*.obj;*.off;*.ogex;*.pk3;*.ply;*.pmx;*.prj;*.q3o;*.q3s;*.raw;*.scn;*.sib;*.smd;*.step;*.stl;*.stp;*.ter;*.uc;*.vta;*.x;*.x3d;*.x3db;*.xgl;*.xml;*.zae;*.zgl' +
        ';||'

      )

      SESSION[:source_filename] = File.basename(@import_file_path)\
        unless @import_file_path.nil?

    end

    # Copies textures, 3D model & associated files to
    # Universal Importer program data temp directory.
    #
    # @deprecated
    # @see https://github.com/SamuelTallet/SketchUp-Universal-Importer-Plugin/issues/8
    #
    # XXX Required to avoid invalid characters in path.
    def copy_to_program_data_dir

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

    end

    # Exports 3D model to OBJ format.
    def export_to_obj_format

      @obj_export_file_path = File.join(SESSION[:temp_dir], 'export.obj')

      Assimp.convert_model(
        @import_file_path,
        @obj_export_file_path,
        File.join(SESSION[:temp_dir], 'assimp.log')
      )

      # Disables transparency (d) in intermediate MTL file produced by Assimp.
      obj_mtl_export = File.read(File.join(SESSION[:temp_dir], 'export.mtl'))
      obj_mtl_export.gsub!("\nd ", "\n# d ")
      File.write(File.join(SESSION[:temp_dir], 'export.mtl'), obj_mtl_export)

    end

    # If they exist: fixes embedded textures in Assimp OBJ export.
    def fix_embedded_tex_in_obj_export

      obj_mtl_export_file_path = File.join(SESSION[:temp_dir], 'export.mtl')
      obj_mtl_export = File.read(obj_mtl_export_file_path)

      # If MTL file references at least one embedded texture:
      if obj_mtl_export.include?('*0')

        Assimp.extract_textures(
          @import_file_path,
          File.join(SESSION[:temp_dir], 'assimp.log')
        )

        texture_extensions = ['jpg', 'png', 'bmp', 'tga', 'tif']
        texture_index = 1000
        
        1000.times do

          texture_index -= 1

          next if !obj_mtl_export.include?('*' + texture_index.to_s)

          texture_image_base_path = File.join(
            SESSION[:temp_dir], 'import_img' + texture_index.to_s
          )

          texture_extensions.each do |texture_extension|

            if File.exist?(texture_image_base_path + '.' + texture_extension)

              obj_mtl_export.gsub!(
                '*' + texture_index.to_s,
                'import_img' + texture_index.to_s + '.' + texture_extension
              )
  
            end

          end

        end

        File.write(obj_mtl_export_file_path, obj_mtl_export)

      end

    end

    # Fixes, in intermediate MTL file, path of each referenced texture.
    def fix_referenced_tex_in_inter_mtl

      intermediate_mtl_file_path = File.join(SESSION[:temp_dir], 'export.mtl')
      intermediate_mtl = File.read(intermediate_mtl_file_path)

      texture_refs = Assimp.get_texture_refs(
        @import_file_path,
        File.join(SESSION[:temp_dir], 'assimp.nfo')
      )

      if !texture_refs.empty?

        source_parent_dir = File.expand_path(File.join(@source_dir, '..'))
        # Dir.glob() only uses "/" to separate dirs, so we fix that (on Windows).
        source_parent_dir.gsub!('\\', '/') if Sketchup.platform == :platform_win

        texture_refs.each do |texture_path|

          # Skips normal maps, etc since SketchUp supports only a texture assimilable to diffuse map.
          next unless intermediate_mtl.include?("map_Kd #{texture_path}")

          found_texture_path = nil

          texture_path_in_source_dir = File.join(@source_dir, FS.normalize_separator(texture_path))
          texture_basename = File.basename(FS.normalize_separator(texture_path))

          if File.exist?(texture_path_in_source_dir)
            found_texture_path = texture_path_in_source_dir
          else
            texture_glob_pattern = "#{source_parent_dir}/**/#{texture_basename}"
            # From source's parent dir, scans tree to find missing texture by filename...
            texture_scan_result = Dir.glob(texture_glob_pattern)

            if !texture_scan_result.empty?
              found_texture_path = texture_scan_result.first
            end
          end

          # @todo if texture not found and "Claim missing textures" option is On, ask user.

          if !found_texture_path.nil?
            texture_copy_or_link_path = File.join(SESSION[:temp_dir], "uir-#{texture_basename}")

            unless FS.create_hard_link(texture_copy_or_link_path, found_texture_path)
              Utils.mkdir_and_copy_file(found_texture_path, texture_copy_or_link_path)
            end

            intermediate_mtl.gsub!("map_Kd #{texture_path}", "map_Kd uir-#{texture_basename}")
          end
          
        end

        File.write(intermediate_mtl_file_path, intermediate_mtl)

      end

    end

    # If they exist: asks user for missing textures in Assimp OBJ export.
    def ask_for_missing_tex_in_obj_export

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

    end

    # Asks user for polygon reduction.
    def ask_for_polygon_reduction

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

    end

    # Applies polygon reduction on Assimp OBJ export.
    def apply_polygon_reduction

      return unless @poly_reduction_params.is_a?(Array)

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

      # Disables transparency (Tr) in intermediate MTL file generated by MeshLab.
      obj_mtl_export = File.read(File.join(SESSION[:temp_dir], 'export.obj.mtl'))
      obj_mtl_export.gsub!("\nTr ", "\n# Tr ")
      File.write(File.join(SESSION[:temp_dir], 'export.obj.mtl'), obj_mtl_export)

    end

    # Asks user for model height.
    def ask_for_model_height

      model_height_in_mm = UI.inputbox(
        [ TRANSLATE['Model height (mm)'] + ' ' ], # Prompt
        [ 1800 ], # Default
        NAME # Title
      )

      if model_height_in_mm.is_a?(Array)
        # Model will be resized according to user input.
        SESSION[:model_height_in_mm] = model_height_in_mm[0].to_i
      end

    end

    # Exports 3D model to 3DS format. @deprecated
    def export_to_3ds_format

      @tds_export_file_path = File.join(SESSION[:temp_dir], 'export.3ds')

      Assimp.convert_model(
        @obj_export_file_path,
        @tds_export_file_path,
        File.join(SESSION[:temp_dir], 'assimp.log')
      )

    end

    # Imports 3D model from 3DS format. @deprecated
    def import_from_3ds_format

      Sketchup.active_model.import(@tds_export_file_path)

    end

    # Exports 3D model to DAE format.
    def export_to_dae_format

      @dae_export_file_path = File.join(SESSION[:temp_dir], 'export.dae')

      Assimp.convert_model(
        @obj_export_file_path,
        @dae_export_file_path,
        File.join(SESSION[:temp_dir], 'assimp.log')
      )
      
    end

    # Fix double sided faces in DAE export.
    def fix_faces_in_dae_export

      dae_export = File.read(@dae_export_file_path)

      dae_export.insert(0, "<!-- File modified by Universal Importer plugin for SketchUp. -->\n")

      faces_fix = '<extra><technique profile="GOOGLEEARTH">'
      faces_fix += '<double_sided>1</double_sided>'
      faces_fix += "</technique></extra>\n</profile_COMMON>"

      dae_export.gsub!('</profile_COMMON>', faces_fix)

      File.write(@dae_export_file_path, dae_export)

    end

    # Imports 3D model from DAE format.
    def import_from_dae_format

      Sketchup.active_model.import(@dae_export_file_path)

    end

    # Increments "imports.count" file.
    # Used to know if it's time to plan a donate invitation.
    def increment_imports_counter

      imports_count_file = File.join(__dir__, 'imports.count')

      File.write(imports_count_file, '0') unless File.exist?(imports_count_file)
      @imports_counter = File.read(imports_count_file).to_i

      @imports_counter += 1
      File.write(imports_count_file, @imports_counter.to_s)

    end

  end

end
