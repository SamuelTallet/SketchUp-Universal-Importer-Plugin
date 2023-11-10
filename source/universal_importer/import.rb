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
require 'universal_importer/fs'
require 'universal_importer/assimp'
require 'universal_importer/mtl'
require 'universal_importer/meshlab'
require 'universal_importer/donate'

# Universal Importer plugin namespace.
module UniversalImporter

  # 3D model importer.
  class Import

    # Completion status and source filename.
    #
    # @see ModelObserver#onPlaceComponent
    attr_reader :completed, :source_filename

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

      # Deletes temporary files possibly left by a previous import fail.
      delete_temp_files

      @source_filename = File.basename(@source_file_path)
      
      create_link_to_source_file

      convert_source_to_intermediate
      fix_embedded_tex_in_inter_mtl
      fix_external_tex_in_inter_mtl

      ask_for_missing_tex_in_inter_mtl if @@options[:claim_missing_textures?]

      if @@options[:propose_polygon_reduction?]
        ask_for_polygon_reduction
        apply_poly_reduction_to_inter_obj
      end

      convert_intermediate_to_final
      fix_faces_in_final_dae
      Sketchup.active_model.import(@final_dae_file_path)

      # From now, SketchUp waits for user to place imported model as component.
      # @see ModelObserver#onPlaceComponent
      
      # Import complete.
      @completed = true

      self.class.increment_counter
      
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
        ';||'
      )

    end

    # Creates a hard link to source model file.
    # This workarounds Assimp issue with non-ASCII chars in filenames.
    def create_link_to_source_file

      source_file_ext = File.extname(@source_filename)
      @source_link_name = 'uir-source' + source_file_ext
      source_link_path = File.join(@source_dir, @source_link_name)

      FS.create_hard_link(source_link_path, @source_file_path)

    end

    # Converts source model to intermediate OBJ/MTL files.
    def convert_source_to_intermediate

      Assimp.convert_model(@source_dir, @source_link_name, 'uir-inter.obj', 'uir-assimp.log')

      @inter_mtl_file_path = File.join(@source_dir, 'uir-inter.mtl')
      inter_mtl = File.read(@inter_mtl_file_path)
      # Disables transparency (d) in intermediate MTL file produced by Assimp.
      inter_mtl.gsub!("\nd ", "\n# d ")
      File.write(@inter_mtl_file_path, inter_mtl)

    end

    # Fixes, in intermediate MTL file, filename of each texture embedded in model.
    def fix_embedded_tex_in_inter_mtl

      inter_mtl = File.read(@inter_mtl_file_path)

      # If intermediate MTL file references at least one embedded texture:
      if inter_mtl.include?('*0')

        Assimp.extract_textures(@source_dir, @source_link_name, 'uir-assimp.log')

        texture_extensions = ['jpg', 'png', 'bmp', 'tga', 'tif']
        texture_index = 1000
        
        # Let's say there are 1000 textures because we don't know how many have been extracted...
        1000.times do

          texture_index -= 1
          # We go counter-wise to avoid incorrect replacement of references that contain smaller ones.
          # For example: if *1 were replaced before *12, then 2 would become a broken reference!

          next unless inter_mtl.include?('*' + texture_index.to_s)

          texture_image_base_path = File.join(
            @source_dir, 'uir-source_img' + texture_index.to_s
          )

          # And we don't know texture file extension...
          texture_extensions.each do |texture_extension|

            if File.exist?(texture_image_base_path + '.' + texture_extension)

              # Replaces embedded reference with matching texture filename.
              inter_mtl.gsub!(
                '*' + texture_index.to_s,
                'uir-source_img' + texture_index.to_s + '.' + texture_extension
              )
  
            end

          end

        end

        File.write(@inter_mtl_file_path, inter_mtl)

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

      mtl = MTL.new(@inter_mtl_file_path)
      mtl_materials_wo_textures = mtl.materials_wo_textures

      return if mtl_materials_wo_textures.empty?

      mtl_materials_wo_textures.each do |material_name|

        texture_path = UI.openpanel(

          TRANSLATE['Select a Texture for Material:'] + ' ' + material_name,
          nil, TRANSLATE['Images'] + '|*.jpg;*.png;*.bmp;*.tga;*.tif;||'

        )

        # Skips if user cancelled...
        next if texture_path.nil?

        texture_basename = File.basename(texture_path)
        texture_link_or_copy_path = File.join(@source_dir, "uir-#{texture_basename}")

        unless FS.create_hard_link(texture_link_or_copy_path, texture_path)
          # Knowing that the texture file selected by the user may be in a different
          # partition than the source directory and that a hard link cannot point to
          # a file on a different partition, it is safer to fall back on a file copy.
          FileUtils.copy(texture_path, texture_link_or_copy_path)
        end

        mtl.set_material_texture(material_name, "uir-#{texture_basename}")

      end

      File.write(@inter_mtl_file_path, mtl.rebuilt_file_contents)

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

    # Fixes double sided faces in final DAE file.
    def fix_faces_in_final_dae

      final_dae = File.read(@final_dae_file_path)

      final_dae.insert(0, "<!-- File modified by Universal Importer plugin for SketchUp. -->\n")

      # Thanks to Piotr Rachtan for workaround.
      # @see https://github.com/SketchUp/api-issue-tracker/issues/414
      faces_fix = '<extra><technique profile="GOOGLEEARTH">'
      faces_fix += '<double_sided>1</double_sided>'
      faces_fix += "</technique></extra>\n</profile_COMMON>"

      final_dae.gsub!('</profile_COMMON>', faces_fix)

      File.write(@final_dae_file_path, final_dae)

    end

    # Increments "imports.count" file.
    def self.increment_counter

      imports_count_file = File.join(__dir__, 'imports.count')

      File.write(imports_count_file, '0') unless File.exist?(imports_count_file)
      imports_counter = File.read(imports_count_file).to_i

      imports_counter += 1
      File.write(imports_count_file, imports_counter.to_s)

    end

    # Gets imports count.
    #
    # @see Donate.invite_user
    def self.count

      imports_count_file = File.join(__dir__, 'imports.count')

      return 0 unless File.exist?(imports_count_file)

      File.read(imports_count_file).to_i

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
