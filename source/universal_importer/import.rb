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
require 'universal_importer/mayo_conv'
require 'universal_importer/fs'
require 'universal_importer/assimp'
require 'universal_importer/mtl'
require 'universal_importer/meshlab'
require 'universal_importer/collada'
require 'universal_importer/donate'
require 'universal_importer/imports'

# Universal Importer plugin namespace.
module UniversalImporter

  # 3D model importer.
  class Import

    # Supported texture image file extensions.
    SUPPORTED_TEXTURE_EXTS = ['jpg', 'png', 'bmp', 'tga', 'tif']

    # CAD model file extensions (better) supported by Mayo Conv.
    CAD_MODEL_FILE_EXTS = ['step', 'stp', 'iges', 'igs', 'brep']

    # Completion status, source filename and materials names.
    #
    # @see ModelObserver#onPlaceComponent
    attr_reader :completed, :source_filename, :materials_names

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

    # Imports a model.
    def initialize()

      Donate.invite_user

      @completed = false

      select_source_file
      return unless @source_file_path.is_a?(String)

      @source_dir = File.dirname(@source_file_path)

      # Deletes temporary files possibly left in source directory by a previous import fail.
      delete_temp_files

      @source_filename = File.basename(@source_file_path)
      @source_file_ext = File.extname(@source_filename).delete('.').downcase

      @inter_mtl_file_path = File.join(@source_dir, 'uir-inter.mtl')
      # Materials names indexed by texture path or color.
      @materials_names = {}

      if CAD_MODEL_FILE_EXTS.include?(@source_file_ext)
        # Import source file with Mayo:

        convert_cad_source_to_intermediate
        backup_materials_names_for_later

        # @todo handle polygon reduction.

        convert_intermediate_to_final

        # @fixme There are cases when up axis is wrong.
        COLLADA.replace_up_axis(@final_dae_file_path, :Y, :Z)

      else
        # Import source file with Assimp:

        create_link_to_source_file

        convert_source_link_to_intermediate
        fix_embedded_tex_in_inter_mtl
        fix_external_tex_in_inter_mtl

        ask_for_missing_tex_in_inter_mtl if @@options[:claim_missing_textures?]

        # It's crucial to save the materials names now as MeshLab renames them.
        backup_materials_names_for_later

        if @@options[:propose_polygon_reduction?]
          ask_for_polygon_reduction
          apply_poly_reduction_to_inter_obj
        end

        convert_intermediate_to_final

      end

      COLLADA.fix_double_sided_faces(@final_dae_file_path)
      Sketchup.active_model.import(@final_dae_file_path)

      # From now, SketchUp waits for user to place imported model as component.
      # @see ModelObserver#onPlaceComponent

      # Import complete.
      @completed = true

      Imports.increment_counter

    rescue StandardError => exception

      UI.messagebox(
        'Universal Importer Error: ' + exception.message + "\n" +
        "\n" + exception.backtrace.first.to_s + "\n" +
        "\n" + 'Universal Importer Version: ' + VERSION
      )

      # Deletes temporary files possibly left.
      delete_temp_files

    end

    # Prompts user to select source model file.
    def select_source_file

      @source_file_path = UI.openpanel(
        TRANSLATE['Select a 3D Model'], nil, TRANSLATE['3D Models'] +
        '|' +
        '*.3d;*.3ds;*.3mf;*.ac;*.ac3d;*.acc;*.amf;*.ase;*.ask;*.assbin;*.b3d;*.blend;*.bsp;*.bvh;*.cob;*.csm;*.dae;*.dxf;*.enff;*.fbx;*.glb;*.gltf;*.hmp;*.ifc;*.ifczip;*.irr;*.irrmesh;*.lwo;*.lws;*.lxo;*.md2;*.md3;*.md5anim;*.md5camera;*.md5mesh;*.mdc;*.mdl;*.mesh;*.mesh.xml;*.mot;*.ms3d;*.ndo;*.nff;*.obj;*.off;*.ogex;*.pk3;*.ply;*.pmx;*.prj;*.q3o;*.q3s;*.raw;*.scn;*.sib;*.smd;*.step;*.stl;*.stp;*.ter;*.uc;*.vta;*.x;*.x3d;*.x3db;*.xgl;*.xml;*.zae;*.zgl' +
        ';*.iges;*.igs;*.brep' +
        ';||'
      )

    end

    # Converts CAD source model to intermediate OBJ/MTL files with Mayo.
    def convert_cad_source_to_intermediate

      MayoConv.export_model(
        @source_file_path, File.join(@source_dir, 'uir-inter.obj')
      )

    end

    # Creates a hard link to source model file.
    # This workarounds Assimp issue with non-ASCII chars in filenames.
    def create_link_to_source_file

      @source_link_name = 'uir-source.' + @source_file_ext
      source_link_path = File.join(@source_dir, @source_link_name)

      FS.create_hard_link(source_link_path, @source_file_path)

    end

    # Converts linked source model to intermediate OBJ/MTL files.
    def convert_source_link_to_intermediate

      Assimp.convert_model(@source_dir, @source_link_name, 'uir-inter.obj', 'uir-assimp.log')

      inter_mtl = File.read(@inter_mtl_file_path)
      # Disables transparency (d) in intermediate MTL file produced by Assimp.
      inter_mtl.gsub!("\nd ", "\n# d ")
      File.write(@inter_mtl_file_path, inter_mtl)

    end

    # Fixes, in intermediate MTL file, filename of each texture embedded in model.
    def fix_embedded_tex_in_inter_mtl
      # The embedded textures have been already extracted?
      textures_extracted = false
      intermediate_mtl = MTL.new(@inter_mtl_file_path)

      # For each material in the intermediate MTL file:
      intermediate_mtl.materials.each_value do |material|

        # If current diffuse texture path is a reference to an embedded texture: e.g. *2
        if material[:diffuse_texture] && material[:diffuse_texture] =~ /\*(\d+)/
          texture_reference_number = $1

          unless textures_extracted
            # Extracts once for all, to the disk, the textures embedded in the model.
            Assimp.extract_textures(@source_dir, @source_link_name, 'uir-assimp.log')
            textures_extracted = true
          end

          # It's easy to deduce the filename of a texture extracted by Assimp...
          texture_relative_path = 'uir-source_img' + texture_reference_number
          texture_absolute_path = File.join(@source_dir, texture_relative_path)

          # but we don't know the file extension of the extracted texture, so we try each:
          SUPPORTED_TEXTURE_EXTS.each do |texture_extension|

            if File.exist?(texture_absolute_path + '.' + texture_extension)
              # Replaces embedded diffuse texture reference with matching texture filename.
              material[:diffuse_texture] = texture_relative_path + '.' + texture_extension
              break # Jumps to the next material.
            end

          end

        end

      end

      if textures_extracted
        # In this case, an update of the intermediate MTL file is required.
        File.write(@inter_mtl_file_path, intermediate_mtl.to_s)
      end

    end

    # Fixes, in intermediate MTL file, path of each referenced external texture.
    def fix_external_tex_in_inter_mtl

      inter_mtl = File.read(@inter_mtl_file_path)

      external_texture_paths = Assimp.get_texture_refs(@source_dir, @source_link_name, 'uir-assimp.nfo')

      if !external_texture_paths.empty?

        source_parent_dir = File.expand_path(File.join(@source_dir, '..'))
        # Dir.glob() only uses "/" to separate dirs, so we fix that (on Windows).
        source_parent_dir.gsub!('\\', '/') if Sketchup.platform == :platform_win

        external_texture_paths.each do |texture_path|

          # Skips normal maps, etc since SketchUp supports only a texture assimilable to diffuse map.
          next unless inter_mtl.include?("map_Kd #{texture_path}")

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
            texture_link_path = File.join(@source_dir, "uir-#{texture_basename}")

            FS.create_hard_link(texture_link_path, found_texture_path)

            inter_mtl.gsub!("map_Kd #{texture_path}", "map_Kd uir-#{texture_basename}")
          end
          
        end

        File.write(@inter_mtl_file_path, inter_mtl)

      end

    end

    # Asks user for missing textures in intermediate MTL file.
    def ask_for_missing_tex_in_inter_mtl
      user_provided_texture = false
      mtl = MTL.new(@inter_mtl_file_path)

      mtl.materials.each do |material_name, material|

        if !material[:diffuse_texture]
          texture_path = UI.openpanel(
            TRANSLATE['Select a Texture for Material:'] + ' ' + material_name,
            nil, TRANSLATE['Images'] + '|*.jpg;*.png;*.bmp;*.tga;*.tif;||'
          )

          # Skips current material if user cancelled...
          next if texture_path.nil?

          user_provided_texture = true
          texture_basename = File.basename(texture_path)
          texture_link_or_copy_path = File.join(@source_dir, "uir-#{texture_basename}")

          unless FS.create_hard_link(texture_link_or_copy_path, texture_path)
            # Knowing that the texture file selected by the user may be in a different
            # partition than the source directory and that a hard link cannot point to
            # a file on a different partition, it is safer to fall back on a file copy.
            FileUtils.copy(texture_path, texture_link_or_copy_path)
          end

          material[:diffuse_texture] = "uir-#{texture_basename}"
        end

      end

      if user_provided_texture
        # In this case, an update of the intermediate MTL file is required.
        File.write(@inter_mtl_file_path, mtl.to_s)
      end
    end

    # Backups, from the intermediate MTL file, the materials names to fix them later.
    #
    # @see ModelObserver#onPlaceComponent
    # @see COLLADA.fix_materials_names
    def backup_materials_names_for_later
      # Sometimes Mayo Conv doesn't output a MTL file.
      return unless File.exist?(@inter_mtl_file_path)

      intermediate_mtl = MTL.new(@inter_mtl_file_path)
      # For each material in the intermediate MTL file...
      intermediate_mtl.materials.each { |material_name, material|
        # Indexes current material name by texture path:
        if material[:diffuse_texture]
          # The entire path, extension included, to match `Sketchup::Texture#filename`
          texture_absolute_path = File.join(@source_dir, material[:diffuse_texture])
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

    # Asks user for polygon reduction.
    def ask_for_polygon_reduction

      @poly_reduction_params = nil

      model_face_count = Assimp.get_face_count(@source_dir, 'uir-assimp.nfo')

      poly_reduction_answer = UI.messagebox(
        TRANSLATE['Model has'] + ' ' + model_face_count.to_s +
        ' ' + TRANSLATE['faces'] + '.' + "\n" +
        TRANSLATE['Reduce polygon count?'], MB_YESNO
      )

      if poly_reduction_answer == IDYES

        @poly_reduction_params = UI.inputbox(
          [ TRANSLATE['Target face number'] + ' ' ], # Prompt
          [ 40000 ], # Default
          TRANSLATE['Polygon Reduction'] + ' - ' + PLUGIN_NAME # Title
        )

      end

    end

    # Applies polygon reduction to intermediate OBJ file, if user wanted it.
    def apply_poly_reduction_to_inter_obj

      return unless @poly_reduction_params.is_a?(Array)

      inter_mtl = File.read(@inter_mtl_file_path)

      mlx = MeshLab.poly_reduction_script(
        inter_mtl.include?('map_Kd'),
        @poly_reduction_params[0].to_i
      )
      File.write(File.join(@source_dir, 'uir-poly_reduction.mlx'), mlx)

      # At this stage, "uir-inter.obj" references "uir-inter.mtl".
      MeshLab.apply_script(
        @source_dir,
        'uir-inter.obj', # in_filename
        'uir-inter.obj', # out_filename
        'uir-poly_reduction.mlx',
        'uir-meshlab.log'
      )
      # Since now, "uir-inter.obj" references "uir-inter.obj.mtl".
      
      @inter_mtl_file_path = File.join(@source_dir, 'uir-inter.obj.mtl')
      inter_mtl = File.read(@inter_mtl_file_path)
      # Disables transparency (Tr) in intermediate MTL file generated by MeshLab.
      inter_mtl.gsub!("\nTr ", "\n# Tr ")
      File.write(@inter_mtl_file_path, inter_mtl)

    end

    # Converts intermediate OBJ/MTL files to final DAE file.
    def convert_intermediate_to_final

      Assimp.convert_model(@source_dir, 'uir-inter.obj', 'uir-final.dae', 'uir-assimp.log')
      @final_dae_file_path = File.join(@source_dir, 'uir-final.dae')

    end

    # Last instance of Import class.
    #
    # @see ModelObserver#onPlaceComponent
    @@last = nil

    # Gets last instance of Import class.
    #
    # @return [UniversalImporter::Import, nil]
    def self.last
      @@last
    end

    # Sets or forgets last instance of Import class.
    #
    # @param [UniversalImporter::Import, nil] instance
    #
    # @raise [ArgumentError]
    def self.last=(instance)
      raise ArgumentError, 'Instance must be an UniversalImporter::Import or nil'\
        unless instance.is_a?(Import) || instance.nil?

      @@last = instance
    end

    # Deletes temporary files (prefixed with "uir-").
    #
    # @see ModelObserver#onPlaceComponent
    def delete_temp_files

      temp_files_pattern = @source_dir

      # Dir.glob() only uses "/" to separate dirs, so we fix that (on Windows).
      temp_files_pattern.gsub!('\\', '/') if Sketchup.platform == :platform_win

      temp_files_pattern.chomp!('/')
      temp_files_pattern += '/uir-*'

      Dir.glob(temp_files_pattern) do |temp_file_path|
        File.delete(temp_file_path)
      end

    end

  end

end
